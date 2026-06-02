# F-RFC046 lever-3 — batched-expert GEMM-feed repack → device (DESIGN-AHEAD)

status: **DESIGN-AHEAD** (forward lever, authored from the COMMITTED profile —
NOT from a live re-run). The live util-RED next-bottleneck diagnosis on the
in-flight verify fire belongs to the Lane-G fire agent; this doc is the
forward lever-3 plan so the util-GREEN endgame is not gated on one fire.
ref: forge-rfc046-host-feed-residual-resolution.md (the committed profile);
     #2515 (lever-1 im2col route) · 403735b29 (lever-2 transpose-aware GEMM, un-batched path).

## why a lever-3 exists AFTER lever-2 (read the committed profile + source)

The committed profile (`d=1536/T=512/K=3/E=2`, ~13.4 ns/interpreted-op,
104.08M host scalar-op/step) splits the host hot path into:

    expert batched-path host repack/im2col/col2im : 67,633,152  (65.0%)  ← DOMINANT
    conv Wt-transpose + bias + db (4 convs ea way) : 32,514,048  (31.2%)
    residual/copy/sum glue                         :  3,932,160  ( 3.8%)

**lever-2 (commit 403735b29) patched ONLY the un-batched path** —
`conv1d_via_forge` / `conv1d_bwd_via_forge` (clm_prod.hexa L46–160). Those carry
the 4 trunk/router/output convs (ec, tc, router r, output ro) = the **31.2%**
`conv Wt-transpose + bias + db` term. lever-2 routes them through
`forge_dispatch_matmul_bt` (cuBLAS `OP_T` on the weight, no host `Wt` transpose
loop) and `forge_dispatch_matmul_atb` (`OP_T` on `dy`, dW lands already in
`[Cout,Kdim]`, no dW-unpack repack), both `CLM_PROD_DEVFEED` env-gated. Good.

**But the production trainer (`clm_prod_fwd`/`clm_prod_bwd`) drives the 2 MoE
ConvExperts through the BATCHED path** — `conv2_fwd_via_forge_batched` (L199–247)
and `conv2_bwd_via_forge_batched` (L251–325) — which lever-2 did **NOT** touch.
That batched path is the **DOMINANT 65% term** and STILL carries inline host
`t_set` scalar loops for every repack:

| host loop in the batched path | clm_prod.hexa lines | what it repacks |
|---|---|---|
| `b_all` weight pack (w0,w1 → `[2,Kdim,Cout]`, transposed) | L223–233 | fwd Wt-transpose ×2 experts |
| `a_all` xcol duplication (`xcol` → `[2,T,Kdim]`) | L218–222 | fwd input stage ×2 |
| `c_all` unpack + bias add (`[2,T,Cout]` → y0,y1) | L236–245 | fwd output stage ×2 |
| `dwA` xcolT duplication (`[2,Kdim,T]`) | L271–273 | bwd dW-input ×2 |
| `dwB` dy pack (`[2,T,Cout]`) | L274–276 | bwd dW-input ×2 |
| `dW_flat_all` unpack (`[2,Kdim,Cout]` → dW0,dW1 `[Cout,Kdim]`) | L279–288 | bwd dW-unpack repack ×2 |
| `dxA`/`dxB` dy/w pack | L289–294 | bwd dX-input ×2 |

(lever-1 #2515 routed the batched-expert **im2col gather** to `_clmp_im2col` —
that removed the gather; lever-2 left the surrounding **GEMM-feed REPACK** in the
batched path entirely on the host. So the 65% dominant term's repack survives
both prior levers. This is the honest residual the committed profile names:
"the DOMINANT remaining host cost is the GEMM-feed REPACK … intrinsic to the
matmul calling convention".)

## lever-3 design — transpose-aware BATCHED GEMM (`_bt`/`_atb` strided-batched)

Eliminate the batched-expert repack the same way lever-2 eliminated the
un-batched repack — push the transpose into the cuBLAS call rather than a host
`t_set` loop — but for the **strided-batched** dispatch the experts use.

### new builtins (self/runtime.c + self/cuda + self/codegen.hexa + self/runtime.h)

Mirror the lever-2 pair, batched:

    forge_dispatch_matmul_batched_bt (a_all,  M, K, b_all, N, batch, c_all)
        # c[g] = a[g][M,K] @ b[g][N,K]^T   (cuBLAS OP_T on B, strided-batched)
    forge_dispatch_matmul_batched_atb(a_all,  M, K, b_all, N, batch, c_all)
        # c[g] = a[g][M,K]^T @ b[g][M,N]   (cuBLAS OP_T on A, strided-batched)

GPU kernel: extend the existing `_hx_cuda_farr_matmul_batched_gpu` lowering with
the two transpose variants — same `cublasDgemmStridedBatched` call, flipping
`CUBLAS_OP_T` on B (bt) or A (atb), and swapping the leading-dim/stride
arithmetic. This is the batched analogue of lever-2's
`_hx_cuda_farr_matmul_{bt,atb}_gpu`; the un-batched kernels already prove the
transpose-stride math is correct, so the batched lowering reuses it per-slice.

### flame routing (stdlib/flame/clm_prod.hexa, CLM_PROD_DEVFEED-gated)

`conv2_fwd_via_forge_batched`:
- DROP the `b_all` weight-transpose pack (L223–233): feed `w0`/`w1` directly as
  `[Cout,Kdim]` into `forge_dispatch_matmul_batched_bt` (cuBLAS transposes
  per-slice). The expert weights need only be **stacked** `[2,Cout,Kdim]`
  (a contiguous device copy, no per-element transpose) — or, since RFC-056
  `FORGE_OUT_DEVICE_KEEP` keeps the stack device-resident, staged once.
- The `a_all` xcol duplication (L218–222) collapses: with `_clmp_im2col` already
  device-resident (lever-1) the two experts share ONE `xcol` — pass `batch=2`
  with a **zero inner-stride on A** (broadcast the single xcol across both
  slices) instead of materializing `[2,T,Kdim]` on the host. (cuBLAS strided-
  batched supports `strideA=0` for a shared operand — this removes the whole
  `a_all` loop.)
- `c_all` unpack + bias (L236–245): the bias add stays (it is `T*Cout*2` adds,
  small vs the repack), but emit straight into `y0_out`/`y1_out` from the
  device result via the existing device-keep path; no separate `c_all` host
  buffer.

`conv2_bwd_via_forge_batched`:
- dW: feed `dy`-stack as A^T via `forge_dispatch_matmul_batched_atb(dy_stack,
  Cout, T, xcol_shared, Kdim, batch=2)` → dW lands ALREADY in `[2,Cout,Kdim]`,
  DROPPING both the `dwA` xcolT duplication (L271–273) AND the
  `dW_flat_all` → `[Cout,Kdim]` unpack repack (L279–288). xcol shared via
  strideA=0 again (same as fwd).
- dX: feed `w`-stack via `_bt` so the col2im input lands without the `dxB`
  weight pack (L292–294); col2im scatter stays device-resident (lever-1).
- db reduction (L317–322) stays host (`Cout*T*2` adds, ~0.79M op — in the 3.8%
  glue, not worth a kernel; a later micro-lever if needed).

### host-op count delta (forward projection from the committed profile)

Removing the batched-expert repack loops (the 65% term, minus the small
bias/db adds that stay) takes the per-step host scalar-op count from the
post-lever-2 residual toward the **glue floor (~3.9M op ≈ 0.05 s/step)**.
Combined with lever-2's 31.2% removal, the host hot path after lever-3 is
dominated only by the residual/copy/sum glue + the CE-grad softmax + the
groupnorm/gelu elementwise (which are `nn_*` calls, not the conv repack). That
is the point at which the sub-ms GPU GEMM stops being SM-starved — i.e. the
first design where util≥20% is *structurally* reachable rather than capped by a
1.4 s host serial. **This is a PROJECTION from the op-count model, NOT a
measurement** — util≥20% remains the held verify fire's verdict (a_scale_honest_scope;
the source CANNOT confirm util≥20% without the fire, same discipline as lever-2).

## byte-eq oracle (the deliverable gate — CPU-local, $0 mac)

`stdlib/flame/clm_batched_gemmfeed_eq.hexa` (mirror lever-2's
`clm_gemmfeed_eq.hexa`):

    F-RFC046-BATCHED-GEMMFEED-EQ = 1   iff
      max|Δ| ( conv2_*_via_forge_batched  vs  the prior host-repack batched path ) == 0.0
      for the fwd c_all and the bwd dW0/dW1/dX0/dX1, dil ∈ {1,2}, E=2.

The CPU oracle for the new `_batched_bt`/`_batched_atb` builtins transposes
per-slice on CPU (same as lever-2's `_bt`/`_atb` CPU fallback) so the prebuilt
mac binary stays byte-eq while only the pod self-host rebuild engages the real
strided-batched transpose kernel. Existing oracles
(F-RFC046-HOSTFEED-{FWD,BWD}-EQ, F-CLM-CONV2-BATCHED-{FWD,BWD}-EQ,
F-RFC046-GEMMFEED-EQ, F-CLM-DEVFEED-*) must all stay max|Δ|=0.0 (dX FP64-ULP
≤5.55e-17 = #2383 class) — hard gate, revert on drift (g5 verbatim, no fake GREEN).

## why this is left as a DESIGN DOC, not authored on this branch

Authoring the `_batched_bt`/`_batched_atb` kernels touches **self/runtime.c +
self/cuda/runtime_cuda_emit.hexa + self/codegen.hexa + self/runtime.h** — a
runtime builtin signature change that is **NOT byte-eq-testable on the prebuilt
mac binary** (the mac binary lacks the batched-transpose builtin; only a pod
self-host rebuild has it). That is exactly the same constraint that made lever-2
a pod-rebuild change. Per the non-collision rule this prep MUST NOT trigger a
pod self-host build or race the live verify fire — so lever-3 is delivered as
this precise design (builtin signatures + flame routing + byte-eq oracle name +
op-count projection) ready to author the moment a pod is free, NOT as
half-authored source that cannot be byte-eq-verified here. The g22/s17 version
lockstep + the byte-eq oracle land together with the source in that follow-on.

## composition with the live fire (no race)

- If the in-flight lever-2 verify fire lands **util≥20% GREEN** → lever-3 is
  NOT needed for the util gate; it becomes a throughput headroom lever for 3B
  (smaller host serial = more room before the 3B host feed re-saturates).
- If the fire lands **util still RED** with the live nvidia-smi pinning the
  batched-expert repack as the residual (the diagnosis the fire agent owns),
  lever-3 is the pre-designed next swing — author immediately on the next free
  pod, no re-profiling needed.

Either way this design composes with, and never races, the live fire.
