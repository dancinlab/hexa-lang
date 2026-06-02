# lever-4 forward-design — fused on-device per-step driver (the F-RFC046 root)

substrate = GPU / Lane-G / FORGE-UTILGREEN · status = DESIGN-AHEAD (NOT authored) ·
$0 (design only) · author target = a later unit, NOT this PR.

## where lever-3 leaves us

byte-eq GREEN (mac, $0):
- F-RFC046-BATCHED-GEMMFEED-EQ = 1 (BT/ATB/per-problem, max|Δ|=0.0) — lever-3 NEW
- F-RFC046-GEMMFEED-EQ = 1 (max|Δ|=0.0) — lever-2 re-green (drift fixed this PR)
- F-CLM-DEVFEED-{IM2COL,FWD,BWD,ADAM}-EQ = 1 · F-CLM-CONV2-BATCHED-{FWD,BWD}-EQ = 1

lever-2 dropped the un-batched conv host repack (profile 31.2%); lever-3 drops the
DOMINANT 65% BATCHED `conv2_*_via_forge_batched` host repack (b_all Wt-transpose +
dW_flat unpack + a_all/dwA xcol duplication). Fire-confirmed: pod 39082940 lever-2
util fire = DESCENT 🟢 (CE 0.818→0.059) · util 🔴 (PEAK 19% MEAN 0.4999% n=147863).

## the RESIDUAL after lever-3 (= the lever-4 target)

Two residual host-cost classes remain, both per training step (`clm_prod.hexa`
`while step <= steps` body, L771–L803):

1. **glue ~3.8%** — the small host scatter/gather + reshape/copy between the
   compiled forge builtins (e.g. window slice `tok`/`tgt` fill L774–778, the
   per-call temp-farr staging, the layernorm/softmax host residue not yet on a
   device builtin).

2. **the INTERPRETED per-step driver loop (the F-RFC046 ROOT)** — the entire step
   body is INTERPRETED hexa that dispatches ~30 separate compiled-builtin calls
   per step (1× fwd, 1× ce, 1× ce-grad, 1× bwd, **20× separate `_adam`** L793–801),
   each a distinct hexa→C boundary crossing with host-side HexaVal marshalling +
   (on a naive device path) a potential H2D/D2H bounce around every call. The GPU
   sits idle between kernels while the interpreter walks to the next op. This is
   why util stays low even with every GEMM on cuBLAS: the kernels are fast but
   SPARSE in wall time — the gaps are interpreter + glue, not compute.

## lever-4 design — fuse the step into ONE device-resident driver

Collapse the per-step op-chain into a single compiled, device-resident step so the
GPU stays hot across the whole fwd→loss→bwd→AdamW chain with NO host round-trip and
NO interpreter re-entry per op.

### L1 — `forge_dispatch_train_step` (one fused builtin)

New 1-call builtin that takes the device-resident param/grad/moment handle set +
the step window and runs fwd + ce + ce-grad + bwd + AdamW **entirely on device**,
returning only the scalar loss to the host. The 20 separate `_adam` calls collapse
into ONE fused `forge_dispatch_adamw_group` over a packed param-block descriptor
(offset/len table for the 20 tensors), so AdamW is a single grid launch, not 20.

- params/grads/moments stay device-resident across steps (allocated ONCE before the
  loop, never re-H2D); only the input-window IDs + the scalar loss cross the boundary.
- the interpreted `while step` loop shrinks to: fill window → `forge_dispatch_train_step(...)`
  → accumulate loss. One boundary crossing per step instead of ~30.

### L2 — packed param-block descriptor (kills the 20× AdamW boundary)

A device-side struct-of-arrays {param_id[], grad_id[], m_id[], v_id[], len[], count}
so `forge_dispatch_adamw_group` updates all 20 tensors in one launch with the shared
step/β1/β2/lr/eps. Mirrors the existing single-tensor `forge_dispatch_adamw` (lever-a)
— same RNE/bias-correction math, just batched over the descriptor.

## projected host-op reduction

| path                         | host boundary crossings / step | host glue ops / step |
|------------------------------|-------------------------------:|---------------------:|
| pre-lever-2 (all host repack)|                            ~30 | im2col+repack+20 adam |
| post-lever-3 (this PR)       |                            ~30 | repack DROPPED; glue ~3.8% |
| **lever-4 (fused driver)**   |                          **~2** | window-fill + loss-read only |

→ ~30 → ~2 boundary crossings/step (≈15× fewer hexa→C re-entries); the 20× AdamW
collapses to 1 launch. Expected effect: the inter-kernel idle gaps that hold MEAN
util at 0.4999% close, because the GPU runs the full step without returning to the
interpreter. util≥20% is a HELD pod fire (NOT claimed from source).

## byte-eq oracle (to author with lever-4)

`F-RFC046-FUSED-STEP-EQ` — CPU host-reference vs the fused-driver path:
- run N=5 deterministic steps through (a) the current op-by-op `clm_prod` step body
  and (b) `forge_dispatch_train_step` over the SAME seeded params/window;
- assert max|Δ| = 0.0 on every param tensor AND on the per-step scalar loss after
  each of the 5 steps (so the fused AdamW-group trajectory is bit-identical to the
  20 separate `_adam` calls).
- secondary oracle `F-RFC046-ADAMW-GROUP-EQ`: `forge_dispatch_adamw_group` over the
  20-tensor descriptor == 20 separate `forge_dispatch_adamw` calls, max|Δ|=0.0.

Same delegate-to-reference discipline as lever-2/3: the no-CUDA host fallback of the
fused builtin must DELEGATE to the existing op-by-op helpers (NOT re-implement the
math) so byte-eq is exact by construction; the CUDA path fuses the launches.

## NOT in scope for lever-4

- changing any numeric (precision, accumulation order, AdamW math) — byte-eq stays
  the HARD gate.
- Lane A / AKIDA — separate substrate (a_lane_akida_gpu_split).
