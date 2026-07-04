# flame — folder guide (sub-CLAUDE)

> hexa-lang **governance SSOT is the repo-root `../../CLAUDE.md`**; the parent-dir map is
> `../CLAUDE.md` (stdlib guide — read it for the byteeq / pool-build / guard conventions that
> also apply here). This file is only a guide to `stdlib/flame/`; on conflict, root wins.
> Design SSOT = `../../ARCHITECTURE.json`; deep flame docs = `INDEX.md` (18-md hierarchy),
> `STATUS.md` (state), `PLAN.md` (roadmap), `PERF.md` (measurement). History = git + `../../CHANGELOG.md`.
> This file is a current-state map only — no accumulating versions/dates.

## What is flame

flame = the **hexa-native NN training + inference stack** — the `torch:ATen` analog for hexa
(`a_train_flame_forge`): the binary carries **no PyTorch/ATen/Python**. Production NN is authored
in `.hexa` and runs on **forge own-GEMM** (`_hx_k_gemm`, cuBLAS-independent) on a CUDA host, with a
**byte-identical CPU `farr` fallback** everywhere else. Two properties are load-bearing:
- **functional fwd/bwd** — every layer's `*_fwd` returns outputs + saved state; `*_bwd` takes upstream
  `dy` + that state and returns the closed-form analytic vjp. The closed algebra is inherited verbatim
  from anima `HEXAD/D/d_train3_lib.hexa` (c3_*) — **no vjp is reimplemented**, so byte-equality holds.
- **byte-eq is the correctness oracle** (not perplexity): each op has a finite-diff / host-reference
  `*_test.hexa` (`GRAD-EXACT`) and each device seam has a `*_eq.hexa` byte-eq oracle (29 of them).

## Key files (roles)

```
nn_lib.hexa           — NN primitives fwd+bwd: Linear·RMSNorm·GELU(erf-exact)·embedding·tied LM head
gn_lib.hexa           — GroupNorm fwd+bwd (CLM-ConvMoE op 2/4); _off variants take packed-affine offsets
conv_lib.hexa         — causal dilated Conv1d via im2col → forge_dispatch_matmul (op 1/4)
moe_lib.hexa          — MoE router: softmax gate + gate-weighted expert combine, fwd+bwd (op 3/4)
tensor_lib.hexa       — Tensor wrappers (t_zeros/t_get/…) over host farr
ag_tape.hexa          — generic reverse-mode autograd TAPE (RFC 034 successor, hexa-side, C-runtime-untouched);
                        each ag_<layer> node reuses the verified nn_lib bwd, ag_backward chains latest→first
autograd_lib.hexa     — ag_* thin wrappers over the tape
optim_lib.hexa        — AdamW (opt_*) over the RFC 034 `adamw_step` builtin (in-place on W,m,v)
train_lib.hexa        — train_step / run_steps driver (CE loss · AdamW · descent-verified)
flame_math.hexa       — dt_sqrt·dt_exp·dt_ln + d5_sin/d5_cos: bit-eq Taylor ports of the anima paths
decoder_block_lib / decoder_lib — block fwd+bwd + full decoder-stack composition
clm_prod.hexa · clm_conv_gpu · clm_elementwise_gpu · clm_step · clm_reexport · clm_mitosis …
                      — the production CLMConvMoE port (the anima 303M trunk); clm_elementwise_gpu adds the
                        device seam for the non-matmul ops (GN·GELU·MoE-combine)
*_selfcontained.hexa · *_eq.hexa · *_test.hexa — byte-eq ORACLES / falsifiers, NOT runtime deps
```
There is **no `flame_mm.hexa`** — the `mm()` forge seam is the `forge_dispatch_matmul` intrinsic (RFC-040),
resolved by the runtime, not a stdlib fn.

## Device-seam convention

- `forge_dispatch_*` intrinsics (`matmul`·`matmul_t`·`matmul_batched`·`groupnorm{,_bwd}`·`gelu{,_bwd}`·
  `moe_router{,_bwd}`·`moe_block`·`adamw`·`embedding{,_bwd_scatter}`·`residual_add`·`ce_grad`·…) are the
  single dispatch seam per op: on a CUDA host they route to a device / own-GEMM kernel; **otherwise the
  CPU body IS the host `farr` op** (same code path). Probe the host with `cuda_available()`.
- **Env gates:** `HEXA_CUDA` (enable device build) · `HEXA_DEVRESIDENT_NN` + `CLM_PROD_DEVRESIDENT`
  (keep NN buffers device-resident, kills host↔device copy glue) · `HEXA_EAGER_DEVRESIDENT` (capstone) ·
  `HEXA_OWN_GEMM*` (TF32 precision — do NOT flip casually) · `HEXA_METAL` · `HEXA_DET` · `HEXA_FUSE_*`
  (op-fusion toggles: GN_GELU, MOE_CONV, MOE_BLOCK, ALL, …). `nn_embedding` fwd/bwd is now device-seam
  **default-ON on CUDA** (was env-gated).

## Gotchas

- **The device path must byte-match the host libm.** Host ops use libm-free Newton-Raphson (`_nn_sqrt`
  / `_gn_sqrt`) and the `flame_math` bit-eq Taylor, chosen so the CUDA kernel and the CPU reduction emit
  **identical bytes**; the `*_eq.hexa` oracles assert `max|Δ| = 0` (`hexa run`, 0-GPU). Any new device op
  needs its byte-eq oracle before it can be trusted as a fallback.
- **`base` vs `_off` variants** — the zero-offset dispatcher (`forge_dispatch_groupnorm`) takes a
  contiguous `[C]` slice; the `_off` seam (`nn_groupnorm_fwd_off`) feeds it a `gamma[goff:goff+C]` window
  and copies grads back. Match the offset variant to whether the affine is packed.
- **Build / measure on pool** (aiden·summer·ghost RTX-5070), not mini — heavy 303M decode/train OOMs mini.
  Confirm the GPU actually fired (`cuda_available()` · `[OWN-GEMM-FIRED]`) before trusting a "GPU" run.
- **byteeq classification** — most flame modules are consumed via runtime dispatch (byteeq-neutral), but
  classify with the `../CLAUDE.md` grep before editing; relevant modules gate on pool 3-target byteeq.
