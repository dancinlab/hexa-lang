# H1D — anima clm_prod env-wiring audit (HEXA-FUSION fusion + own-GEMM)

**Question:** Does anima's `clm_prod` invocation actually RECEIVE the HEXA-FUSION
fusion + own-GEMM env flags? If not, the landed levers never fire for anima's
3B/7B forge and they silently get the un-fused baseline.

**Verdict: WIRING GAP = YES (opt-in only, no default/auto, no shipped recommended-env block).**

Date: 2026-06-05 · base: origin/main @ 7dc27c8b9 · method: source read of the
actual `env(...)` / `getenv(...)` gates (NO guessed flag names — every flag below
is quoted from the line that reads it).

---

## 1. How clm_prod is invoked

anima has **no own forge driver** — it runs the stdlib trainer directly:

```
[ENV...] hexa run stdlib/flame/clm_prod.hexa
```

`stdlib/flame/clm_prod.hexa:1018` carries its own `fn main()`. There is **no CLI
flag surface** for fusion/own-GEMM — every lever is read from the **process
environment** at the call site. So the ONLY channel anima has to turn the levers
on is `export`-ing the env vars before `hexa run`. If anima's invocation does not
export them, the fused path is dead code for anima and they see the un-fused
baseline.

---

## 2. Flags found (verbatim from the gates)

All read-only `env()` / `getenv()`. **No `setenv`/`putenv` anywhere** → no auto /
default-on path. Every flag **defaults OFF** (OFF == cuBLAS / eager / host-glue,
byte-identical to the pre-fusion reference).

### Fusion + device-resident (stdlib/flame/clm_prod.hexa)

| env flag | line | gates |
|---|---|---|
| `CLM_PROD_DEVRESIDENT` | 140, 395, 411, 431, 449, 482, 532, 548, 571, 607, 626, 642, 662, 679, 693, 711, 733, 931 + **co-required by every fuse flag below** | MASTER device-resident chain — keeps param/grad/moment/activations FARR_DEVICE (host roundtrip 0). **Co-gate**: every L3 fuse flag is `if env("HEXA_FUSE_*") != "" && env("CLM_PROD_DEVRESIDENT") != ""` — a fuse flag does NOTHING without this also set. |
| `HEXA_FUSE_GN_GELU` | 497 | L3-a: groupnorm#1 → gelu#1 in one device kernel |
| `HEXA_FUSE_GN_GELU_RESID` | 516 | L3-c: groupnorm#1 → gelu#1 → residual-add fused (one kernel) |
| `HEXA_FUSE_GELU2` | 464 | L3-b: the 2 expert GELUs fused into one launch |
| `HEXA_FUSE_MOE_BLOCK2` | 589 | L3-d: gelu2 + expert_pack2 + moe_router fused (3 launches → 1) |
| `CLM_PROD_DEVFEED` | 55, 78, 101, 935 | device feed; gates `forge_dispatch_adamw` (device AdamW) at 935 |
| `CLM_PROD_BATCHED` | 243 | batched expert matmul (`forge_dispatch_matmul_batched`) |

### Async launch pipeline (self/cuda/runtime_cuda_emit.hexa)

| env flag | line | gates |
|---|---|---|
| `HEXA_CUDA_ASYNC` | 195, 206–215 | async launch stream. **Precedence**: explicit `HEXA_CUDA_ASYNC` wins (1=force on, 0=kill switch); UNSET → follows `CLM_PROD_DEVRESIDENT`. So with `CLM_PROD_DEVRESIDENT=1` async is already ON unless you set `HEXA_CUDA_ASYNC=0`. |

### Own-GEMM (self/native/hxqwen14b_cuda.cu)

Two-level dispatch. **Outer gate** `HEXA_OWN_GEMM` (line 1158, `hxqwen_sgemm_base`)
chooses own-vs-cuBLAS. The inner flags pick the kernel WITHIN the own path
(no-op unless `HEXA_OWN_GEMM` is also set):

| env flag | line | selects |
|---|---|---|
| `HEXA_OWN_GEMM` | 1158 | **OUTER GATE** — route every sgemm through hexa-emit kernel instead of cuBLAS. Required for ALL own-GEMM. |
| `HEXA_OWN_GEMM_WMMA2` | 1068 | CUTLASS-grade TF32 128×64 8-warp double-buffered cp.async kernel (the fast path) |
| `HEXA_OWN_GEMM_SPLITK` | 1079 | split-K for skinny+large-K GEMMs (min(m,n)≤64 ∧ k≥1024); needs WMMA2 too |
| `HEXA_OWN_GEMM_SPLITK_G` | 1083 | (tune) override split-K G factor |
| `HEXA_OWN_GEMM_BF16` | 1052 | **PRECISION CHANGE** BF16 kernel (bf16 in/frag, fp32 accum), highest priority in own path, tol rel-RMS ≤1e-2 |
| `HEXA_OWN_GEMM_WMMA` | 1123 | older single-warp TF32 WMMA |
| `HEXA_OWN_GEMM_TILED` | 1130 | 16×16 shared-mem tiled (fp32 oracle) |
| `HEXA_OWN_GEMM_NOSHAPE` | 1071 | disable skinny fallback (always WMMA2) |
| `HEXA_OWN_GEMM_SKINNY_NAIVE` | 1110 | (debug) naive kernel for skinny path |
| `HEXA_OWN_GEMM_SYNC` | 1061, 1147 | (debug) restore per-call cudaDeviceSynchronize |

---

## 3. EXACT env block anima must export (copy-paste)

To get the **full landed fusion + own-GEMM (TF32 WMMA2) stack** firing in
`clm_prod`:

```sh
# ── HEXA-FUSION full stack for anima's clm_prod forge ──
# device-resident master chain (REQUIRED — every fuse flag is a no-op without it)
export CLM_PROD_DEVRESIDENT=1
export CLM_PROD_DEVFEED=1          # device AdamW (forge_dispatch_adamw)
export CLM_PROD_BATCHED=1          # batched expert matmul

# L3 op-boundary fusion (each co-gated by CLM_PROD_DEVRESIDENT above)
export HEXA_FUSE_GN_GELU=1         # L3-a  groupnorm#1→gelu#1
export HEXA_FUSE_GN_GELU_RESID=1   # L3-c  groupnorm#1→gelu#1→residual
export HEXA_FUSE_GELU2=1           # L3-b  fuse the 2 expert GELUs
export HEXA_FUSE_MOE_BLOCK2=1      # L3-d  gelu2+pack2+router → 1 launch

# async launch stream (already ON because DEVRESIDENT is set; explicit for clarity)
export HEXA_CUDA_ASYNC=1

# CUDA-OWN GEMM — TF32 WMMA2 fast path (+ split-K for skinny LoRA GEMMs)
export HEXA_OWN_GEMM=1             # OUTER gate: own kernel instead of cuBLAS
export HEXA_OWN_GEMM_WMMA2=1       # CUTLASS-grade TF32 128x64 tiled
export HEXA_OWN_GEMM_SPLITK=1      # split-K skinny path (needs WMMA2)

# then:
#   hexa run stdlib/flame/clm_prod.hexa
```

**Conservative / numerics-strict variant** (drop own-GEMM, keep byte-eq fusion only):

```sh
export CLM_PROD_DEVRESIDENT=1
export CLM_PROD_DEVFEED=1
export CLM_PROD_BATCHED=1
export HEXA_FUSE_GN_GELU=1
export HEXA_FUSE_GN_GELU_RESID=1
export HEXA_FUSE_GELU2=1
export HEXA_FUSE_MOE_BLOCK2=1
export HEXA_CUDA_ASYNC=1
# (no HEXA_OWN_GEMM* — GEMM stays cuBLAS, fully fp32; everything else byte-eq)
```

---

## 4. Opt-in vs default

**OPT-IN, 100%.** Every flag is a bare `env()`/`getenv()` read defaulting OFF;
there is no `setenv`/`putenv`/config-file/auto-detect path anywhere in
`clm_prod.hexa` or `hxqwen14b_cuda.cu`. README.md:133-136 confirms own-GEMM is
"OFF by default → cuBLAS stays the default path; flip the env." So **if anima does
not export these, the fusion + own-GEMM levers NEVER FIRE** and anima's forge runs
the un-fused cuBLAS/eager baseline. This is the actionable unblock gap.

There is **no shipped "recommended env" block** for the full stack — the only
env-block in the tree is the W2 closed-negative *measurement* recipe
(`CLM_PROD_DEVRESIDENT=1 DEVFEED=1 BATCHED=1`, HEXA-FUSION.md:270), which does NOT
include the L3 `HEXA_FUSE_*` flags or any `HEXA_OWN_GEMM*`. This file is that
recommended block.

---

## 5. Correctness caveats (anima MUST know for a TRAINING run)

- **byte-eq (safe for training):** ALL `HEXA_FUSE_*` flags + `CLM_PROD_DEVRESIDENT`
  + `DEVFEED` + `BATCHED` + `HEXA_CUDA_ASYNC` are **byte-identical** (max|Δ|=0)
  to the host/eager reference — verified oracle gates (e.g.
  `clm_conv_devfeed.hexa` 19/19 max|Δ|=0). On device-fail/rc≠0 each falls back to
  the proven host path. **No precision risk.**

- **`HEXA_OWN_GEMM_WMMA2` is TF32, NOT fp32-exact.** WMMA2 runs Tensor-Core TF32
  (≈10-bit mantissa on the multiply) with fp32 accumulate — it is a CUTLASS-grade
  *fp32-tolerance* kernel, not bit-exact to cuBLAS Sgemm. For a TRAINING run anima
  should treat this as a deliberate TF32 GEMM (same precision class as
  PyTorch `torch.backends.cuda.matmul.allow_tf32=True`). Acceptable for most
  training but **not** if anima needs fp64/fp32-exact reproducibility.
  - fp32-exact own-GEMM alternative: `HEXA_OWN_GEMM=1` + `HEXA_OWN_GEMM_TILED=1`
    (16×16 shared-mem fp32 oracle) — slower but fp32.
  - or simply omit `HEXA_OWN_GEMM*` → cuBLAS Sgemm (the conservative block above).

- **`HEXA_OWN_GEMM_BF16` is a stronger precision change** (bf16 ≈8-bit mantissa,
  tol rel-RMS ≤1e-2). Do NOT set it for training unless anima has explicitly
  validated bf16 convergence. (Not in the recommended block above.)

---

## 6. Util reality check (honest scope, cite — do not over-promise)

The landed device-resident + glue-fusion stack is **necessary infra** but the W2
fire verdict (`.verdicts/hexa-fusion-w2-util/`, HEXA-FUSION.md:270) is a
**🔴 CLOSED-NEGATIVE**: full fwd+bwd device-resident step measured util **MEAN
0.53%** on H100 — the per-op-device-化 axis does NOT close the util-MEAN floor
because the bottleneck is the **interpreted per-step driver loop**, not the glue
ops. So exporting these flags makes the fusion/own-GEMM path *fire* (which is the
H1D question — and the answer is it otherwise does NOT), but anima should not
expect a util-GREEN ≥20% from env-wiring alone on the production dense shape
(that's compute-bound; PyTorch already saturates it). The own-GEMM WMMA2 win is a
launch-bound / GEMM-iso step-time lever, not a magic util fix.

---

## TL;DR for anima

1. anima invokes `clm_prod` as `hexa run stdlib/flame/clm_prod.hexa` with **env only** — no CLI flags.
2. Fusion + own-GEMM are **opt-in, default OFF, no auto-path** → **without the exports they never fire** (wiring gap = YES).
3. Export the §3 block to fire the full stack. The `HEXA_FUSE_*` + DEVRESIDENT/DEVFEED/BATCHED/ASYNC subset is **byte-eq (training-safe)**.
4. **`HEXA_OWN_GEMM_WMMA2` is TF32 (not fp32-exact)** — for strict-precision training use `HEXA_OWN_GEMM_TILED` (fp32) or drop own-GEMM (cuBLAS).
