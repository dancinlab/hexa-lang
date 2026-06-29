# hexa vs PyTorch — CLMConvMoE fwd+bwd step (summer RTX 5070, sm_120, CUDA 12.9)

Workload: d=512, T=256, L=2, K=3, V=256, **F64** (hexa default). N_WARM=3 + N_TIME=7,
isolated process, in-process median. PyTorch 2.11.0+cu130, torch.mm/F.conv1d/F.group_norm/
F.gelu/F.cross_entropy. Both bench scripts share the identical FLOP/step formula
(8·T·K·d²·L + 4·T·d·V ≈ 3.36 GFLOPs/step).

## Headline comparison table

### (A) Kernel-level GPU GEMM (the real GPU-compute headline)
| impl | 2048³ FP64 | GFLOP/s | ratio |
|------|-----------|---------|-------|
| hexa `_hx_k_gemm_splitk` (own, no cuBLAS) | — | 464.3 | **0.96×** |
| PyTorch `torch.mm` | — | 482.9 | 1.0× |

→ **hexa GPU compute is at 96% of PyTorch parity.** (state/hexa-vs-pytorch-gemm-verdict.md)
Correctness: rel_rms_vs_ikj ≈ 1.6e-15 (not zeros — sm_120 build fixed via #4213/#4216/#4220/#4221).

### (B) Full CLMConvMoE fwd+bwd step (NAIVE stdlib conv_lib path)
| impl | median step | GFLOP/s | ratio |
|------|------------|---------|-------|
| hexa naive `stdlib/flame/conv_lib` (host-scalar bwd) | **60325.0 ms** | 0.0556 | **~4750× SLOWER** |
| PyTorch F64 (cuDNN conv bwd) | 12.7 ms | 263.7 | 1.0× |
| PyTorch F32 (reference) | 0.9 ms | 3712.9 | — |

hexa median = 60325.0 ms over N_TIME=7 (timed 60547/60962/60181/60325/60058/59962/59707 ms;
warmup 60163/60300/59713 ms) — dead flat, no variance → not a transient/JIT artifact.
hexa/torch F64 ratio = 60325 / 12.7 = **4750×**.

## Banner-bar verdict
- **GPU compute (GEMM): hexa ≈ PyTorch (96%).** The own-GEMM device kernel is competitive.
- **Naive CLM step: hexa ~4760× behind — NOT a GPU-compute gap.** The gap is entirely the
  backward pass running as host-scalar code.

## Wall classification (break-walls)
NOT launch-bound, NOT GPU-mem-bound. **Algorithmic/path wall:**
`stdlib/flame/conv_lib.hexa:nn_conv1d_bwd` (and the offset twin) is a pure **host-scalar
quadruple-nested loop** — for this shape T·Cout·Cin·K = 256·512·512·3 ≈ **201M iterations
per call**, with `t_get`/`t_set` scalar accessors, ×4 conv-bwd calls/step. The forward uses
`t_matmul` (GPU, OWN-GEMM device path fired) but the **backward has no GPU kernel** —
conv_lib's own comment: "device routing = forge Phase 4 carve-out" (device path lives in
forge, not conv_lib). PyTorch's conv backward is a fused cuDNN GPU kernel. This is the known
flame "host-scalar / interpreted-glue backward" wall (memory: flame H100 closeout ~1656×;
decode host-dispatch gap → device-resident lever).

**Crucially: the bench measures the NAIVE path, not hexa's device-resident CLM path.** The
forge megakernel CLM (`forge_dispatch_clm_megafwd` / `clm_valley1/2` / `groupnorm_bwd`, in
`stdlib/flame/clm_prod.hexa`) IS compiled into the runtime and IS what anima's real trainer
uses — but it requires a quantized-weight fixed-architecture harness, so the generic
d=512/T=256 bench can't reach it.

## Next levers (honest, named)
1. **GPU conv1d backward kernel** in `conv_lib` — mirror the forward (im2col + t_matmul) for
   the gradient (dW = xcolᵀ@dY, dX = dY@Wᵀ via device GEMM + device col2im-scatter). The
   forge device col2im/im2col kernels already exist (`forge_dispatch_col2im`/`im2col`).
2. **Wire bench/anima trainer to the forge device-resident CLM path** (`clm_prod`
   megakernel) — the fair apples-to-apples comparison vs PyTorch, and the path anima should
   use in production.

## anima reflection
This is a **hexa-lang stdlib gap (conv_lib host-scalar backward), NOT an anima wiring bug.**
anima's CLM training should route through the forge device path (`clm_prod`), never the naive
`nn_conv1d_bwd`. No anima core/cli code change is warranted from this measurement —
"측정만" (measurement-only). Recommendation relayed: ensure anima's trainer uses the forge
device-resident CLM kernels, not the naive conv_lib bwd.

## DX/build goal — ACHIEVED (the original blocker)
GPU now activates in ONE command. `bash tool/build_cuda_runtime` on a CUDA host:
auto-detects CUDA_HOME (cuda-12.9), builds sm_120 objects, deploys clean (#4220 no-openssl)
archive to `~/.hx/bin/build/runtime.a`, clears cache → `cuda_available()=1`, GEMM correct
(rel_rms ≈ 1.6e-15, was all-zeros). Three merged fixes: #4213 (19× multidef), #4216
(CUDA_HOME sm_80 zeros), #4220 (EVP no-openssl host), #4221 (emitter bootstrap-poison fallback).

---

## r3 lever 2 — device-resident im2col/col2im (conv_lib) — MEASURED 2026-06-29

Branch `r3-lever2-conv-device` (PR pending). summer RTX 5070, sm_120, CUDA 12.9,
current `test` hexat, CUDA runtime.a deployed (`hexa run` cuda_available()=1,
`[OWN-GEMM-FIRED] _hx_k_gemm DEVICE path`). Same bench
`~/bench_anima/bench_hexa_clm_step.hexa` (d=512, T=256, L=2, K=3, V=256, F64),
N_WARM=3 + N_TIME=7, in-process median, fast non-det default.

| conv_lib path | median step | GFLOP/s | vs PyTorch F64 (12.7ms) |
|---------------|------------|---------|--------------------------|
| BEFORE — origin/main (host im2col/col2im + GPU GEMM) | **459 ms** (457/459/476) | 7.3 | 36.1× |
| AFTER  — device im2col/col2im + GPU GEMM            | **284 ms** (277/280/284×3) | 11.8 | **22.4×** |

→ **1.62× faster** (459→284 ms), ~175 ms host gather/scatter removed. The
forge device builtins (forge_dispatch_im2col / _im2col_t / _col2im / _db_colsum)
replace the host scalar loops; buffers stay FARR_DEVICE-resident feeding the GEMM
in place (cuDNN strategy). Gap vs PyTorch F64: 36.1× → 22.4×.

### Parity (device vs host, HEXA_DET=1) — EXACT
Both run the bench-shape conv1d fwd+bwd (~/conv_parity.hexa); checksums:

| checksum | HOST (main, DET=1) | DEVICE (branch, DET=1) | Δ |
|----------|--------------------|------------------------|---|
| ysum  | -89.774481499062855 | -89.774481499062855 | **0** |
| yabs  | 109372.9421875038   | 109372.9421875038   | **0** |
| dWabs | 2614968.865484383   | 2614968.865484383   | **0** |
| dXabs | 707990.6696253714   | 707990.6696253714   | **0** |
| dbabs | 9367.5996339024667  | 9367.5996339024667  | **0** |

→ **max|Δ| = 0 (byte-identical)** under HEXA_DET=1 (fixed-order non-atomic
col2im-gather + non-atomic split-K GEMM). Non-DET fast default drifts ~1e-13 ULP
(atomic split-K / atomic-scatter reassociation — the expected training fast path,
not a defect). byteeq-safe: conv_lib is byteeq-neutral; CPU-only (cuda_available()
==0) keeps the host path byte-identical to the pre-lever reference.

### honest gap notes
- BEFORE here = 459 ms (this host/hexat), not the 633 ms cited in the r3 lever-1
  framing — different measurement context; the 1.62× delta (same-host BEFORE/AFTER
  back-to-back) is the trustworthy figure.
- Remaining 284 ms = other host glue still on CPU (Wt-transpose, bias-add,
  GroupNorm/embedding seams, dW reshape) + own-FP64 GEMM vs cuDNN-F32. Next levers:
  device Wt-transpose / fused bias-epilogue / FP32 path.
