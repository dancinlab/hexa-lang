# flame: flame_stdp_pair_gpu — device CUDA kernel for O(N²) STDP at scale

**Filed by**: anima (downstream consumer) — LEGO arc §141 GPU spiking design
(2026-05-20). anima edits NO hexa-lang source per
`g_train_flame_not_pytorch upstream_downstream_invariant`; patch-request only.

**Status**: `resolved-ssot 2026-05-20` — kernel landed at
`self/cuda/runtime_cuda.c::_hx_cuda_kern_stdp_pair` + launcher
`_hx_cuda_farr_stdp_pair_gpu`; hexa-callable seam at
`self/runtime.c::hexa_forge_dispatch_stdp_pair` (runtime.h prototype
included; bare-wrapper seam follows `forge_dispatch_matmul` /
`forge_dispatch_ffn_fp64_via_bf16` pattern — no bootstrap rebuild
required); 8-arg codegen registration at
`self/codegen_c2.hexa::len(node.args) == 8`; flame-side wrapper
`flame_stdp_pair_gpu` at `stdlib/flame/spiking_lib.hexa`. CPU fallback
byte-identical to `flame_stdp_pair` enforced by construction (same
scalar order, fma-free).

**Falsifier results** (ubu-2 RTX 5070, sm_80 PTX driver JIT):
- F-STDP-GPU-1 BYTE-EQUAL-VS-CPU **PASS** (N=256 mismatch=0 max|Δ|=0.000e+00; N=4096 mismatch=0 max|Δ|=0.000e+00) — required `__dmul_rn`/`__dadd_rn`/`__dsub_rn` to defeat nvcc auto-fma fusion (heritage: `feedback_flame_transcendental_byteeq_hazard.md` mechanism (3))
- F-STDP-GPU-2 DIAGONAL-ZERO **PASS** (N=256, N=4096)
- F-STDP-GPU-3 CLIP-BOUNDED **PASS** (N=256, N=4096)
- F-STDP-GPU-4 SCALE-SPEEDUP **PASS** (N=4096: CPU 30.57 ms vs GPU 0.64 ms = **47.9× speedup**; N=256: 9.8×)

Binary promote = standard separate deploy step per 22c27a05/e5c4c0ef
pattern. Companion to
`flame-spiking-substrate-primitives.md` (§138/§139, the CPU primitives —
PR #77, merged/pending). This patch is the **GPU** follow-up.

**Tier flag**: this is a **runtime-kernel** change (`self/cuda/runtime_cuda.c`
+ codegen wire), heavier than the CPU spiking primitives which landed as a
pure-hexa stdlib lib. Flagged honestly for upstream priority triage.

## Problem

PR #77 (`stdlib/flame/spiking_lib.hexa`) gave flame 3 CPU spiking primitives
as a pure-hexa stdlib composition — no builtin, no codegen change. anima's
LEGO arc (§115–§140) runs the LIF spiking substrate on CPU with them.

The LEGO arc measured up to N=2048; §126/§127 showed N=2048 already takes
~5 min/replicate on CPU. The interesting spiking regimes (§137: the
n_stim-gradient steepens with N) live at larger N. A GPU LIF would unlock
N=16k–100k.

The O(N) primitives (`flame_event_threshold`, `flame_refractory_step`) are
cheap — they can stay CPU even in a large-N run. The bottleneck is the **one
O(N²) primitive**:

`flame_stdp_pair` does an N×N outer-product weight update:
```
dW[i][j] = A_plus·spike[i]·tr_pre[j] − A_minus·tr_post[i]·spike[j]
W'[i][j] = clip(W[i][j] + dW[i][j], −w_max, w_max),  dW[i][i] = 0
```
At N=16k that is 256M weight updates per step — minutes/step on CPU. The
outer-product + clip is embarrassingly parallel; on GPU it is ~milliseconds.

## Requested primitive

```
flame_stdp_pair_gpu(farr W, farr tr_pre, farr tr_post, farr spike,
                    scalar A_plus, scalar A_minus, scalar w_max) -> farr
```

Device CUDA kernel — one thread per (i,j) weight cell. W / tr_pre / tr_post /
spike are device-resident `farr`s; output is a new device `farr`. Semantics
byte-identical to the CPU `flame_stdp_pair` (PR #77 `spiking_lib.hexa`).

## Pre-registered falsifiers

```
F-STDP-GPU-1  BYTE-EQUAL-VS-CPU   flame_stdp_pair_gpu output == flame_stdp_pair
                                  (CPU) byte-equal on a fixed N=256 case.
F-STDP-GPU-2  DIAGONAL-ZERO       dW[i][i] = 0 on device (no self-connection).
F-STDP-GPU-3  CLIP-BOUNDED        all output ∈ [−w_max, w_max].
F-STDP-GPU-4  SCALE-SPEEDUP       at N≥4096, GPU wall < CPU wall (the point of
                                  the kernel — measured, not assumed).
```

## Scope note

One concept per file (`inbox-patches-pipeline`): this file is *only*
`flame_stdp_pair_gpu`. The O(N) primitives (`event_threshold`, `refractory`)
do NOT need GPU kernels — they stay CPU. anima-side reference oracle:
`HEXAD/LEGO/lego_engine.py` `LIFNet.step` (numpy) + the CPU `flame_stdp_pair`
(PR #77). LEGO arc §141 DESIGN.md
(`HEXAD/LEGO/state/lego_gpu_spiking_design_s141_2026_05_20/DESIGN.md`) records
the full anima-side analysis.

Once `flame_stdp_pair_gpu` lands, a `lego_engine_gpu.hexa` + large-N (N≥16k)
GPU LIF fire becomes fire-ready — that is the LEGO GPU fire the anima LEGO
arc has been building toward.
