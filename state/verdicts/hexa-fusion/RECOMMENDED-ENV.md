# RECOMMENDED-ENV — HEXA-FUSION clm_prod (E2: HEXA_FUSE_ALL meta-flag)

**One-line:** export `HEXA_FUSE_ALL=1` for the full **byte-eq** fused +
device-resident stack. Add `HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1` ONLY if you
also want the (TF32, **not fp32-exact**) own-GEMM fast path.

Supersedes the manual ~8-flag block in `H1D-ANIMA-ENV-WIRING.md` §3 (that doc
audited the gap; this is the shipped convenience default that closes it).

---

## 1. Byte-eq fused stack — the recommended default

```sh
export HEXA_FUSE_ALL=1
hexa run stdlib/flame/clm_prod.hexa
```

`HEXA_FUSE_ALL=1` makes the `clm_prod` trainer read every byte-eq lever as SET:

| lever (gated via `_fuse_on`) | what it turns on |
|---|---|
| `CLM_PROD_DEVRESIDENT` | MASTER device-resident chain (param/grad/moment/act FARR_DEVICE, host roundtrip 0) |
| `HEXA_EAGER_DEVRESIDENT` | P1B-a' byte-eq capstone: fwd glue (gelu/groupnorm/softmax) device-resident as SEPARATE launches WITHOUT the megastep — makes the eager byte-eq oracle share the megakernel's CUDA erf (`[EAGER-DEVGLUE-FIRED]`) |
| `CLM_PROD_DEVFEED` | device feed + device AdamW (`forge_dispatch_adamw`) |
| `CLM_PROD_BATCHED` | batched expert matmul (`forge_dispatch_matmul_batched`) |
| `HEXA_FUSE_GN_GELU` | L3-a groupnorm#1 → gelu#1 (one kernel) |
| `HEXA_FUSE_GELU2` | L3-b the 2 expert GELUs → one launch |
| `HEXA_FUSE_GN_GELU_RESID` | L3-c groupnorm#1 → gelu#1 → residual (one kernel) |
| `HEXA_FUSE_MOE_BLOCK2` | L3-d gelu2 + expert_pack2 + moe_router → one launch |
| `HEXA_CUDA_ASYNC` | async launch stream (runtime auto-follows the meta-flag) |

**Implementation:** `stdlib/flame/clm_prod.hexa::_fuse_on(flag)` returns
`env(flag) != "" || env("HEXA_FUSE_ALL") != ""`. Every lever gate routes through
it; the runtime `_forge_async_on()` (self/cuda/runtime_cuda_emit.hexa) also
consults `HEXA_FUSE_ALL`.

**Additive + override-preserving:** an individual flag set explicitly still
turns its own lever on independently — the meta-flag only ORs an extra "on"
source. It never forces a lever OFF, so no existing explicit-flag invocation
changes behaviour.

**Why byte-eq safe:** every lever above is verified **max|Δ|=0** vs the
host/eager reference and falls back to the proven host path on device-fail/rc≠0.
Verdicts: `.verdicts/hexa-fusion/F-FUSION-L3A-GN-GELU-AB.txt`,
`F-FUSION-L3B-GELU2-AB.txt`, `F-FUSION-L3C-GN-GELU-RESID-AB.txt`,
`F-FUSION-L3D-MOE-BLOCK2-AB.txt`; device-feed oracle `clm_conv_devfeed.hexa`
19/19 max|Δ|=0. **No precision risk** — safe for a training run.

---

## 2. + own-GEMM (TF32) — separate EXPLICIT opt-in

`HEXA_FUSE_ALL` deliberately does **NOT** include own-GEMM. Add it only when you
accept a TF32 GEMM (precision class = PyTorch `allow_tf32=True`):

```sh
export HEXA_FUSE_ALL=1
export HEXA_OWN_GEMM=1          # OUTER gate: hexa-emit kernel instead of cuBLAS
export HEXA_OWN_GEMM_WMMA2=1    # CUTLASS-grade TF32 128x64 tiled fast path
export HEXA_OWN_GEMM_SPLITK=1   # (optional) split-K for skinny LoRA GEMMs
hexa run stdlib/flame/clm_prod.hexa
```

**Why kept out of the meta-flag:** `HEXA_OWN_GEMM_WMMA2` runs Tensor-Core TF32
(~10-bit mantissa multiply, fp32 accumulate) — **not bit-exact** to cuBLAS Sgemm.
It is a launch-bound / GEMM-iso step-time lever, NOT a byte-eq fusion lever, so
folding it into a "byte-eq stack" meta-flag would silently change numerics.

fp32-exact own-GEMM alternative (slower): `HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_TILED=1`
(16×16 shared-mem fp32 oracle). Or omit `HEXA_OWN_GEMM*` entirely → cuBLAS Sgemm.
Do **not** set `HEXA_OWN_GEMM_BF16` for training unless bf16 convergence is
validated (bf16 ≈8-bit mantissa, tol rel-RMS ≤1e-2). See `H1D-ANIMA-ENV-WIRING.md`
§2/§5 for the full own-GEMM inner-flag dispatch table.

---

## 3. Status / scope (honest)

- **Wiring:** landed (this PR). `HEXA_FUSE_ALL` fires the full byte-eq stack from
  one export. Build+measure of the meta-flag actually firing on H100 is deferred
  to a GPU lane — correctness of the fused path itself is already verified by the
  L3-*-AB verdicts cited above; E2 is the env-wiring/convenience layer only.
- **Util reality (cite, do not over-promise):** per `H1D` §6 / the W2
  closed-negative (`.verdicts/hexa-fusion-w2-util/`), exporting these flags makes
  the fused path *fire* — but on the production dense shape the bottleneck is the
  interpreted per-step driver loop, not the glue ops, so do not expect
  util-GREEN ≥20% from env-wiring alone. The own-GEMM WMMA2 win is a launch-bound
  step-time lever.
