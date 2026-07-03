# r3 lever1 — GELU GPU default (CLM step) — VERDICT

Workload: full CLMConvMoE fwd+bwd train step, `bench/vs_pytorch/bench_hexa_clm_step.hexa`
(d=512, T=256, L=1, K=3, E=2, V=256, F64). Host: summer RTX 5070 (sm_120, CUDA 12.9,
driver 580.159.03), **current hexat (`HEXA_VERSION=test`)**, cuda_available()=1,
`[OWN-GEMM-FIRED] _hx_k_gemm DEVICE path` confirmed each run. N_WARM=3 + N_TIME=7
internal median, 3 isolated processes per config (cache cleared between each to defeat
the closure-cache-key staleness, see below).

## What changed (the lever)

`stdlib/flame/nn_lib.hexa` `nn_gelu_fwd` / `nn_gelu_bwd` device-GELU seam was double-gated
behind `HEXA_DEVRESIDENT_NN` + `CLM_PROD_DEVRESIDENT` (a CONFIG gap — the device kernel
`_hx_k_gelu` was already wired by #4193). Re-wired to **native-canonical-default polarity**
via new `_nn_gelu_dev_on()`:
- `HEXA_DET` set (and != "0") → host loop (OP-19b dt_erf/dt_exp, the cross-platform
  byte-identical reproducibility reference). Det safety pin honored.
- else `cuda_available()==1` → own `_hx_k_gelu` device kernel fires by DEFAULT (no flag).
- else legacy `HEXA_DEVRESIDENT_NN`+`CLM_PROD_DEVRESIDENT` still force it on (additive).
- `cuda_available()==0` (CPU-only / byteeq builds) → host loop UNCHANGED → byteeq-neutral.

(First attempt used `extern fn hexa_forge_is_deterministic() -> int` to honor the #4214
`set_deterministic()` API; the shipped `hexa run` codegen mis-lowers that extern to a
HexaVal-returning stub conflicting with runtime.h's `static inline int`, so it returned a
truthy value and the gate never fired. Switched to the working `env("HEXA_DET")` idiom —
acceptable because the naive nn_lib GELU seam is NOT the production eval path, anima routes
through clm_prod's forge megakernel.)

## Measured (median of 3 isolated runs)

| config | median step | device GELU | gap vs PyTorch F64 (16.78 ms) |
|--------|------------:|:-----------:|------------------------------:|
| BEFORE (old double-gate, host GELU) | 996.3 ms | no | 59.4× |
| AFTER  (cuda-default, device GELU)  | **632.9 ms** | **yes — `[EAGER-DEVGLUE-FIRED]`** | **37.7×** |
| AFTER + HEXA_DET=1 (det → host)     | 1007.0 ms | no | 60.0× |

raw BEFORE: 996.3 / 994.4 / 1008.1 ms · raw AFTER: 632.9 / 632.9 / 627.6 ms ·
raw AFTER_DET: 1001.7 / 1007.0 / 1017.4 ms.

**Result: ~363 ms removed (1.57×, 36.5% faster). Gap 59.4× → 37.7×** (predicted 60→41×, beat it).
The 323 ms GELU host-loop (r3 profile #2, 33.8%) is eliminated. HEXA_DET=1 falls back to
host (no EAGER, == BEFORE) → determinism regimen intact.

## Parity (GPU device GELU vs host dt_erf/dt_exp, direct probe)

forge_dispatch_gelu / _bwd called directly on n=131072 spread over [-6,6], compared to the
host `x·0.5·(1+dt_erf(x/√2))` / `cdf + x·pdf` reference:
- **fwd max|Δ| = 4.44e-16** (~2 ULP)
- **bwd max|Δ| = 2.22e-16** (~1 ULP)

Within nvcc-FMA ε (#4193 noted ~1 ULP) and far inside GELU numeric tolerance / fast-nondet.

## byteeq

`nn_lib.hexa` is byteeq-NEUTRAL — not in the self-host closure (grep `self/` hits are
comment/string false-positives only). CPU-only / byteeq-target builds have
`cuda_available()==0` → host loop is byte-for-byte UNCHANGED. No 3-target byteeq gate
required (stdlib/CLAUDE.md neutral-module convention); only the CUDA runtime path changes.

## Measurement gotchas (for the next session)

1. `HEXA_STDLIB_ROOT` must point at the **stdlib dir** (`$REPO/stdlib`), not the repo root
   — `ml_resolve_stdlib` strips the `stdlib/` prefix before joining. Wrong root silently
   falls through to the bundled `~/.hx/src/stdlib`. (First two measurement rounds were
   invalid for exactly this reason — they re-ran the bundled old nn_lib.) The reliable
   method used here: swap the bundled `~/.hx/src/stdlib/flame/nn_lib.hexa` and run the
   bench from a neutral dir.
2. LATENT BUG (separate, not fixed here): `self/main.hexa:_closure_resolve` resolves
   `HEXA_STDLIB_ROOT` LAST (after the install dir) for the run-cache key, while
   `module_loader` resolves it FIRST for the actual compile. So editing a stdlib module
   under `HEXA_STDLIB_ROOT` can hit a stale `~/.hexa-cache/hexa_run.<key>` binary. Workaround:
   `rm -f ~/.hexa-cache/hexa_run.*` between runs (done here).

## Honest next (r3 lever 2)

conv1d im2col host-loop (r3 profile #1: 491.8 ms, 51.5%) → CUDA im2col kernel +
device-resident `x_col` (forge already has `forge_dispatch_im2col`/`col2im`). Expected
gap 37.7× → ~12×.
