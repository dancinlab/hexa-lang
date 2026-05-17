# flame Phase 4-D-9 — device-chain fwd+bwd conversion design

> The campaign body. 100% closure (F-RFC046-WALL: d768·12L 1 step wall
> ≤ 437.9 s) requires this and only this. 15 d768 fires completed 0 steps
> because every block op round-trips Bc through the host; the substrate
> analysis below proves there is **no wall-moving partial increment** —
> it is strictly all-or-nothing across fwd AND bwd.

## 1. Root cause (substrate-confirmed, not hypothesised)

`tool/flame_phase4d7_block_fwd_primitive.c::flame_block_generic_fwd_
primitive_gpu` — every GPU sub-op is:

```
Bc[host] ─copy→ scratch[host] ─H2D→ dev ─compute→ dev ─D2H→ scratch[host] ─copy→ Bc[host]
```

RMSNorm · RoPE · attention (Q·Kᵀ/softmax/P·V) · SwiGLU · residual — each
one full host round-trip. The matmul primitive (`flame_proj_batch_
generic_primitive`) is the same shape (host transpose-scatter). "Persistent
device residency" is nominal only (per-op scratch). This host round-trip
volume IS the measured d768 wall bound (fire #9–#15, A100 and H100
cross-checked — wall compute-independent).

## 2. Substrate byte-safe lever (runtime_cuda.c, FORBIDDEN to modify)

Read in full 2026-05-18. The hard constraints:

- `_ensure_dev_alloc_out` (L560-564): a non-owning **view is rejected as a
  kernel output**. Forge row/elementwise ops (rmsnorm_rows / softmax_rows
  / silu / mul / add) **cannot write into a Bc dev_view**.
- `_hx_cuda_farr_matmul_gpu` (L433): reallocs C's **own** device buffer —
  if C were a view it would `cudaFree` the base (corruption).
- ∴ **"Bc as the device accumulator ops write into" is impossible** without
  modifying the verified substrate (forbidden).

The ONE byte-safe device-residency lever:

- `_d2h_out` under `FORGE_OUT_DEVICE_KEEP` keeps the op output device-
  resident but sets `dirty_host=1` (L608). The next op's `_h2d` §6.1 skip
  (L190) requires `!dirty_host` → **raw by-id chaining re-uploads STALE
  host bytes (wrong, not just slow)**.
- BUT `_h2d` view path (L173 `if (s->view_base>=0 && s->d_buf)`) skips H2D
  **unconditionally**, ignoring `dirty_host`. So: keep op A's output
  device-resident (DEVICE_KEEP) → take a **`hexa_farr_dev_view` of op A's
  output** → feed that view to op B → op B reads op A's device bytes
  directly, zero host round-trip, byte-safe. The SwiGLU silu→mul chain
  (fwd primitive L899-940) is the proven instance of exactly this pattern.

## 3. The conversion = op-output dev_view chain dataflow

Forward, expressed as a device-resident farr-id chain (`→` = dev_view
bridge under DEVICE_KEEP, no host materialisation between):

```
X ─rmsnorm_rows→ x̂ ─mul(γ)→ rin ─proj(cuBLAS)→ Q,K,V ─rope→ Qr,Kr
   ─attn(Q·Kᵀ→softmax→P·V)→ ctx ─proj→ attn_out ─add(X)→ hstate
   ─rmsnorm_rows→ x̂2 ─mul(γ2)→ rin2 ─proj→ swA,swB ─silu⊙→ swS
   ─proj→ sw_o ─add(hstate)→ Xout
```

Host materialisation ONLY where a Bc cache field is read by the BACKWARD
pass AND bwd is not itself device-chained. **The honest blocker**: bwd
reads nearly every cache field (rm1xn, rm1inv, rin, Q, K, V, P, ctx, swA,
swB, swS, hstate, rm2xn, r2inv). A fwd-only chain that D2Hs all of those
keeps ≈ the full per-op round-trip volume → wall does not move. This is
why it is all-or-nothing across fwd **and** bwd: the cache fields must
stay device-resident from fwd and bwd must `dev_view`-consume them.

## 4. The two real gaps (g3 — not faked)

1. **attention causal-masked softmax**: no byte-eq-verified forge kernel.
   `_hx_cuda_farr_softmax_rows_gpu` softmaxes the FULL row; the causal
   per-row L-prefix mask is currently a host loop. Closure needs either a
   new additive forge kernel (RFC, like RFC 058's 13th kernel — additive,
   12 verified kernels untouched) or this stays host (then it is the
   residual bound and wall cannot reach the gate).
2. **matmul → device Bc slice**: RFC 058 transpose-scatter kernel exists
   (`_hx_cuda_kern_transpose_scatter`, pure index permutation, 0 fp ops)
   but its wrapper still full-`_d2h`s Bc (verified substrate; the D2H drop
   "lands once all Bc readers are dev_view" — i.e. only as part of THIS
   conversion, not standalone). Reviving it in isolation moves no wall.

## 5. Gates (hard falsifiers — every step)

- **F-RFC056-D32-BYTEEQ** (absolute hard gate): `tool/flame_phase4b3_
  verify_all.sh` 26+ sections all `max|Δ|=0.0`. d=32 takes the `_cpu`
  path (d ≤ FLAME_GPU_RESIDENT_THRESHOLD) so byte-eq is by construction
  — but any refactor that perturbs the `_cpu` body fails this. NON-
  NEGOTIABLE.
- **F-RFC058-GPU-PATH-ORACLE** (d768 GPU-path byte-eq, cheap): `tool/
  dispatch_phase4d7_oracle_cuda.sh` — localised `max|Δ| ≤ 3e-11` vs a
  verified CPU reference at the GPU-gated config (d=96). Replaces the
  600 s d768 fire as the per-change verification. Every GPU-path change
  is oracle-verified BEFORE any d768 fire.
- **F-RFC046-WALL** (closure): d768·12L 1 step wall ≤ 437.9 s, measured
  by `tool/dispatch_phase4d7_gpu_fire.sh`. Only fired when the full
  conversion passes the two gates above.

## 6. Execution model

- Worktree-isolated sub-agent, base `origin/rfc043-flame-camp`. Parent
  cherry-picks → pushes (origin = SSOT; shared main is reset-hostile).
- Verified substrate (`self/cuda/runtime_cuda.c` 12-kernel math + the
  RFC 058 13th, `self/runtime.c`) NOT modified. New attention-softmax
  kernel, if needed, is an ADDITIVE RFC (precedent: RFC 058 12→13).
- design-first forbidden — experiment + measure, byte-eq falsifier every
  step (oracle is now the cheap instrument that makes this affordable).
- g3: measured-not-met recorded as not-met. No over-claim. The honest
  scope is that this is multi-milestone; fwd-chain and bwd-chain are
  separately oracle-verifiable but only the COMPLETE pair moves the wall.
