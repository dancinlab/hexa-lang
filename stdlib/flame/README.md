# flame — hexa-native, compiler-only PyTorch-equivalent NN stdlib

## Benchmark — current measured basis (vs PyTorch / CUDA), 2026-05-19

> g3 / LATTICE_POLICY: **measured numbers only.** Unmeasured = not
> claimed; falsified = recorded as falsified. No over-claim.

**Canonical config: d=768 · 12 layer · T=1024 — per-step wall.**

> CORRECTION 2026-05-19: the prior table reported flame "2.95x /
> 1.26-1.76x faster than PyTorch eager". That divided PyTorch's
> 336.85 s (a full 2500-step run) by flame's 1-step wall — a unit
> mismatch, RETRACTED. flame has no measured PyTorch-speedup. Detail:
> `PERF.md` "GPU dispatch path".

| path | d768·12L wall | unit | status |
|---|---|---|---|
| PyTorch eager (anima A100 fire) | 336.85 s / 2500 steps ≈ **0.135 s/step** | T=128, bf16 autocast | baseline |
| **flame** hand-fused (`28e9d648`) | **191-268 s/step** | T=1024, FP64 | MEASURED |
| **flame** generic `ag_tape` (mk2, `e030fa31`) | **114 s/step** (step 1) · 133/120 (2/3) | T=1024, FP64 | MEASURED |

flame is currently ~3 orders of magnitude slower per step than
PyTorch eager (FP64 vs bf16 tensor cores; young GPU codegen). Not
apples-to-apples — T / batch / precision differ.

**Correctness / substrate (A100, byte-eq oracles — all MEASURED PASS):**

| item | result |
|---|---|
| `flame_ag_tape_test` (generic autograd) | 19/19 ALL PASS — leaf 12/12 `max|D|=0`, decoder e2e <=1e-16, train_step gn2 bit-identical, shape-generic 5/5, `ag_spec` DSL |
| CUDA substrate forge kernels (12) | byte-eq A100 (cuBLAS Dgemm + Phase B kernels) |
| RoPE GPU kernel fwd/bwd | `4.441e-16` (nvcc `--fmad` FMA) -> `__dmul_rn`/`__dadd_rn` fix (`b73269ea`) -> `max|D|=0` ALL-PASS (T=128 & T=1024) |
| CPU-only path (historical, d=32·3L) | flame 18.5 s vs anima ~30 s — Phase 4-B 3.23x (different config/axis) |

**mk1 / mk2 framing (mk2 CLOSED 2026-05-19, commit `e030fa31`):**

- **mk1 (shipped):** two-path, mirroring PyTorch's own `eager` vs
  `compiled` split.
  - generic `ag_tape` = correctness + expressiveness path
    (autograd · shape-generic · `ag_spec` model DSL · kernel
    byte-eq) — **5/5 measured-closed**.
  - device-resident hand-fused = performance path — d768·12L
    per-step wall 191-268 s (`28e9d648`, FP64).
- **mk2 (CLOSED 2026-05-19):** the generic `ag_tape` path is now
  device-resident end-to-end and **faster than the hand-fused
  path** (114 s vs 191-268 s/step — a flame-internal comparison,
  NOT a PyTorch comparison). One trainer, two measurement points; the
  abstraction layer no longer pays a wall tax. Closure took 4
  measured A100 fires + 4 byte-eq oracle PASS, each round
  localising a different binding bottleneck (host-scalar M-load
  prelude → single-thread LCG on GPU → `nn_linear_bwd` host-scalar
  matmul + `_ag_reg_acc` per-element loop → all collapsed to forge
  dispatches). Rationale/timeline: `PLAN.md` section "mk2 cycle".

> _History (Phase 4-B / Phase 3, superseded as the headline;
> preserved as the measured audit trail):_

> **Status (2026-05-17): Phase 4-B >=3x TARGET REACHED — 3.23x wall** (cool projection)
> (see `STATUS.md` sixth iteration for single-page consolidated state).
>
> **🎯 Phase 4-B FULLY SHIPPED with ≥3× ceiling**:
> - Path B fwd+bwd matmul primitive integration COMPLETE
> - **3.09× wall MEASURED** (thermal-elevated baseline 23.529s → 7.618s, 5-run avg)
> - **3.23× projected cool conditions** (baseline cool 16.170s → A2+B ~5.0s)
> - flame:anima ratio: **~0.226× (~4.4× faster than anima)**
> - ≥3× RFC 047 §137 target REACHED with **CPU-only architecture** (no GPU required)
> - Single-command reproducible: `tool/flame_phase4b3_a2_build.sh`
>
> **Cumulative wall progression**:
> | state | wall | speedup |
> |---|---|---|
> | baseline (Phase 4-A-bwd) | 12.574-16.170s | 1.00× |
> | Phase 4-B-2 IPCP | 9.814s | 1.28× |
> | Phase 4-B-3 A2 fwd+bwd | 5.908s | 2.74× |
> | Phase 4-B-3 A2 + Path B FULL | ~5.0s projected cool | **🎯 3.23×** |
>
> **Phase 4-B-2 IPCP SHIP** (intermediate, commit `55e29392`):
> - `tool/flame_phase4b_build.sh` produces byte-identical binary
> - 1.28× wall (12.574s → 9.814s 5-run avg, var 1.7%)
> - Production `./hexa build` path unchanged (F-RFC047-FALLBACK-PRESERVED)
> - Verified byte-id on 3 distinct configs (d=32·3L + d=8·toy)
>
> **Phase 4-B-3 mechanism measurements** (3/3 micro-bench probes):
> - boxing-elim: **4.00× MEASURED** (was 1.5-2.5× estimate)
> - allocator-elim: **1.00× MEASURED** (was 1.3-1.7× estimate)
> - fn-call-elim: **1.00× MEASURED** (was 1.2-1.5×, overlap-capped)
> - Cumulative A2 fwd+bwd: **2.74× FAR exceeded prior projection** —
>   bwd has more boxed ops (gradient accumulators) + clang -O2 NEON
>   vectorizes aggressively + synergistic fwd+bwd cumulative effect
>
> Original Phase 3 status preserved below.
>
> **Status (Phase 3 SHIPPED): 22 commits, 41+ falsifier PASS,
> regression 0, structural call_builtin = 0, ~6.4k LoC.**
>
> **Phase 3 correctness anchor — anima d_corpus_fire algorithm-byte-eq
> retry SUCCESS** (RFC 045 closure):
> - same hexa-lang toolchain, same Mac host, same corpus, same seed=42
> - **flame** init gn2 = `7.97113` → final `8.87256e-07`, acc 8/8, wall 18.5s
> - **anima** init gn2 = `7.97116` → final `3.73374e-07`, acc 8/8, wall ~30s
> - |Δ_init| = 3.12e-5 abs (~4e-6 rel) · |Δ_final| = 5.14e-7 (2.4× drift,
>   same shape, same order of magnitude)
> - acc 8/8 = 8/8 exact match — qualitative reproduction perfect
> - source #4 CONFIRMED: anima dict/list-based vs flame packed-farr-based
>   impl → different SSA assignments + different last-ulp non-associative
>   fp sum sequences (RFC 040 §2.2 TOL_MATMUL class). Strict bit-eq across
>   the two impls is not achievable without unifying storage rep, which
>   would defeat flame's compiler-only perf substrate goal.
>
> **Stack**: `tensor_lib` + `autograd_lib` + `nn_lib` (7 layers:
> Linear · RMSNorm · Embedding · LMHead · RoPE · SwiGLU · Attention-core)
> + `optim_lib` + `decoder_block_lib` + `decoder_lib` + `train_lib` +
> `flame_math` (dt_* hand-Taylor + d5_sin/cos). All decoder_block_lib
> projections farr_matmul-routed (Phase 3-J, same FMA fusion context as
> anima).
>
> **Sub-piece byte-id verified with anima** (Phase 3-A..3-J):
> - corpus byte stream: `read_file_bytes` ≡ `od -An -v -tu1` (Phase 3-F-3)
> - LCG sequence: `dt_lcg_next` ≡ anima d_train_lib (Phase 3-E + 3-H)
> - weight init values: tok_emb[0..10] max|Δ|=0.0 (Phase 3-H direct)
> - RMSNorm: `dt_sqrt` ≡ anima 24-iter Newton (Phase 3-E)
> - softmax: `dt_exp` ≡ anima Taylor + repeated-square (Phase 3-E)
> - CE: `dt_ln` ≡ anima atanh 24-term (Phase 3-E)
> - RoPE: `d5_sin` / `d5_cos` ≡ anima 14-term Taylor (Phase 3-G)
> - AdamW: same `adamw_step` builtin (Phase 3-A)
> - **per-window gn2 avg: 0.99640 ≡ anima 0.99640** byte-eq (Phase 3-I)
> - **nn_decoder_grad 8-probe libm-fd at full d=32·3L: max rel 2.19e-09** (Phase 3-I)
>
> **Cross-impl drift quantified** (RFC 045 source #4, RFC 040 §2.2 TOL_MATMUL class):
> - per-window: ~3.9e-6 (1 ulp × 256-element softmax floor)
> - epoch sum: 3.12e-5 (8× window compound; 7.97113 vs 7.97116)
> - gradient at deep weight: ~3× ratio + sign-flip (Phase 4-A-bwd batched amplification)
> - trajectory shape: qualitatively identical (step 25-40 main collapse + plateau)
> - corpus acc 8/8 = 8/8 (byte-eq); collapse 8.98e6× ≈ 2.13e7× (same order)
>
> **dt_ln bias quantified** (RFC 045 source #1, CE-loss-value only):
> - p ≥ 0.1: machine ε precision
> - V=256 uniform p≈4e-3: 13% absolute bias
> - CE clamp floor p=1e-6: 63% bias (atanh series asymptotic limit)
> - gn2 path UNAFFECTED (no log); gradient UNAFFECTED (dl = softmax−onehot)
>
> **GRAD-EXACT correctness anchors**:
> - block-level: 9-probe central-diff, max rel **3.59e-10** (Phase 3-B)
> - full-model: 10-probe central-diff, max rel **2.66e-08** (Phase 3-C;
>   covers head→tied→finalnorm→block-stack→RoPE→GQA→embed reverse)
> - closed math invariants: `Rᵀ · R = I` RoPE orthogonality (machine ε)
>   + `P[hh,i,j>i]=0` attention causal-mask (exact)
>
> **Next gates** (RFC 046, design-shipped):
> - Phase 4-A: epilogue fusion (~2× wall)
> - Phase 4-B: block fusion / IR pass (~5× wall)
> - Phase 4-C: fwd+bwd graph fusion (~10× wall)
> - Phase 4-D: GPU dispatch + eager-PyTorch comparison —
>   F-RFC046-EAGER-PYTORCH-MATCH falsifier: flame d=768·12L wall
>   ≤1.3× eager-PyTorch 336.85s on A100 (the measurable mid-term goal).
>
> **Pair**: `flame` (this directory — hexa NN stdlib) ↔ `self/forge/`
> (the GPU compute substrate: cuBLAS + .cu kernels). See AGENTS.tape §0
> `nn_stack`. Analog: `flame:forge :: torch:ATen`. The
> language-separation (hexa source vs C/CUDA runtime) is enforced by
> directory.

`flame` is to hexa-lang what `torch` is to Python: a cohesive
**Tensor + autograd + nn + optim + GPU** stack — but **compiler-only**
(`hexa build` native, ZERO `hexa_interp` dispatch; aligns with the
interpreter-deprecation directive).

| torch (PyTorch) | flame (hexa-native) | foundation already built |
|---|---|---|
| `Tensor` (GPU array) | `flame` Tensor | RFC 040 device-farr + cuBLAS (✅ verified) |
| `autograd` | reverse-mode tape | RFC 034 (✅ landed) → generalized |
| `nn` (layers) | nn layers | ConsciousDecoderV2 (anima HEXAD, 🔵) + d_train5 farr-refactor (✅ Phase E/E2) |
| `optim` | AdamW | RFC 040 B2 `farr_adamw` (✅ scaffold) |
| CUDA backend | cuBLAS Dgemm | RFC 040 (✅ 4× independent GPU verify, 51 TFLOPS) |

## Why this exists / what it preserves

The Phase D→E→E2 campaign **proved** the GPU substrate works and the
verified ConsciousDecoderV2 trainer is bit-equal correct, but the
pure-hexa interpreter cannot run LM-scale training to convergence
(named real limit, g3). `flame` = the structural answer: **fat native
stdlib + thin hexa orchestration**, so there is no heavy interpreted
driver loop. Interim, the same verified architecture trains via the
`.py` track (PyTorch) — see PLAN.md §dual-track.

**All campaign work is preserved as references in `FLAME.tape` §X**
(exact branch · commit SHA · path · RFC#). Nothing relies on memory;
nothing is duplicated (drift-avoidance, g3). The single biggest
preservation risk — 5 scattered hexa-lang branches holding the real
cuBLAS impl + 11 farr ops — is addressed as **PLAN.md Phase 0
(branch consolidation), explicitly the 물거품-방지 step**.

## Build & run (compile-native, M-Mac CPU)

### Quick smoke — full 80-step corpus benchmark vs anima oracle

```bash
HEXA_MAC_BUILD_OK=1 ./hexa build stdlib/flame/flame_d32_corpus_test.hexa -o build/flame_d32_corpus
./build/flame_d32_corpus
# expect: init gn2 ≈ 7.97113 vs anima 7.97116 (|Δ|=3.12e-5),
#         final gn2 ≈ 8.87e-7, acc 8/8, wall ~13s (Phase 4-A-bwd state)
```

### anima reference comparison (same hexa toolchain, same host)

```bash
HEXA_MAC_BUILD_OK=1 ./hexa build ~/core/anima/HEXAD/D/d_corpus_fire.hexa -o build/_anima_dcf
HEXA_MEM_UNLIMITED=1 ./build/_anima_dcf
# expect: init gn2 = 7.97116, final gn2 = 3.73374e-07, acc 8/8, wall ~22s
```

### Per-step wall breakdown (PERF.md 5-run × 8-iter convention)

```bash
HEXA_MAC_BUILD_OK=1 ./hexa build stdlib/flame/flame_perf_breakdown_test.hexa -o build/flame_perf_breakdown
./build/flame_perf_breakdown
# expect: fwd 4ms / bwd 12ms / AdamW ~0ms / total 16ms (range 16-17)
```

### Full Phase 1-3 regression battery (41+ falsifiers)

```bash
for s in flame.hexa flame_nn_test.hexa flame_optim_test.hexa flame_block_test.hexa \
         flame_decoder_test.hexa flame_train_test.hexa flame_math_test.hexa \
         flame_init_byteeq_test.hexa flame_d32_test.hexa flame_d32_corpus_test.hexa; do
    name=$(basename "$s" .hexa)
    HEXA_MAC_BUILD_OK=1 ./hexa build "stdlib/flame/$s" -o "build/$name" 2>&1 | tail -1
    "./build/$name" 2>&1 | grep -E '=== flame Phase|=== RFC' | tail -1
done
# expect: all PASS, structurally call_builtin = 0
```

## Current layout (Phase 3 LANDED)

```
stdlib/flame/
  README.md                   overview + status (this file)
  PLAN.md                     staged roadmap
  FLAME.tape                  tape v1.2 SSOT: identity · governance · §X
  flame.hexa                  ✅ Phase 1 entrypoint + selftest
  tensor_lib.hexa             ✅ Phase 1 — Tensor over RFC 040 farr
  autograd_lib.hexa           ✅ Phase 1 — RFC 034 ad_* wrapper
  nn_lib.hexa                 ✅ Phase 2 — 7 layers (fwd/bwd, closed vjp)
  optim_lib.hexa              ✅ Phase 3-A — AdamW thin wrapper
  decoder_block_lib.hexa      ✅ Phase 3-B/J — block fwd/bwd, farr_matmul-routed
  decoder_lib.hexa            ✅ Phase 3-C — full ConsciousDecoderV2 fwd/grad
  train_lib.hexa              ✅ Phase 3-D — train_step + 80-step driver + init
  flame_math.hexa             ✅ Phase 3-E/G — dt_lcg/sqrt/exp/ln + d5_sin/cos
  flame_<phase>_test.hexa     selftests (Phase 1/2/3-{A,B,C,D,E,F-3,H,J})
```

flame public API is fixed per `g_flame_api_fixed` — Phase 4 changes
only the C emission pattern under the hood, not the user-facing surface.

## API stays fixed; implementation matures (the staging answer)

One designed API surface (RFC 043). The "PyTorch-parity → exceed-PyTorch"
progression is **implementation maturity of the same API**, not new
files — exactly how PyTorch evolved (eager → Inductor under one API).
See PLAN.md phases.

## Performance thesis (honest — g1/g3/g4/f1/f2)

- **North-star (ULTIMATE, multi-cycle, NOT a near-term/measured claim)**:
  exceed eager-PyTorch (and torch.compile in specialized regimes) on
  END-TO-END training throughput for the fixed verified architecture.
- **Real mechanism**: whole-program AOT compilation (no interpreter /
  Python-dispatch / GIL) · compile-time kernel fusion (transformer
  bottleneck = memory bandwidth, not FLOPs) · static-shape specialization.
- **Honest floor**: raw dense GEMM = cuBLAS/NVIDIA roofline — flame
  MATCHES, does NOT beat (the win is *above* GEMM). Anchored to the
  campaign's measured 51.24 TFLOPS FP64 (76% H100 peak).
- **Forbidden (f1/f2, hard fail)**: NO n=6 lattice numerology in any
  performance assertion. Perf anchors = Shannon / memory-bandwidth /
  cuBLAS-measured roofline only.

## Cross-references (SSOT)

- Design SSOT: `docs/rfc/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md`
- Phase 3 closure: `docs/rfc/rfc_drafts_2026_05_12/rfc_045_flame_phase3_algorithmic_byte_eq_with_anima_oracle.md`
- Phase 4 design: `docs/rfc/rfc_drafts_2026_05_12/rfc_046_flame_phase4_compiler_fusion.md`
- Backing RFCs: 040 (tensor/cuBLAS) · 041 (kernels) · 042 (subsumed) · 034 (autograd)
- Full preservation index + verified oracles: **`FLAME.tape` §X**
- Roadmap + Phase 0 consolidation: **`PLAN.md`**
- anima dual-track + §9: `dancinlab/anima HEXAD/PLAN.md` §9
- Substrate sibling (GPU): `self/forge/` — README + PLAN + FORGE.tape
  (flame consumes forge's `farr_*_gpu` / `cuda_*` compiled builtins;
  Phase 3 uses host CPU `farr_matmul` per honest carve-out — device
  routing is Phase 4-D after RFC 044/046 codegen wiring lands)
