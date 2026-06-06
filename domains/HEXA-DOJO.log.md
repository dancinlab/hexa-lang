# HEXA-DOJO — step log (append-only)

## 2026-06-07 — domain init
- Tracks the dojo as the forge-CUDA build-trap absorption + kernel-authoring practice surface. 5 LAYER-A milestones from open handoffs: 677b84cd fork-bomb, 4a7841fe glibc, d751e2c4 stack-SIGKILL, d631a08f nvptx-exp-underflow, 0a848320 shfl-FP64.
- Honest scope (g5): dojo cures LAYER-A (build/toolchain); LAYER-B (serial kernel-DAG util ceiling) is HEXA-FUSION's fusion problem (graph-capture FALSIFIED, only lift = TF32 megakernel +5.5pp). dojo = recipe book, not oven.
- A1/A4/A5 = codegen/tooling fixes; A2/A3 = dojo-doc + preflight workarounds.

## 2026-06-07 — DOJO-A4 nvptx f64 exp() underflow clamp ✅
- ROOT: nvptx_target.hexa f64 exp arm builds 2^k via `bits_to_float((k+1023)<<52)`. For k<=-1023 (x<~-709, full underflow by x≈-745.13) the biased exponent b=k+1023 goes <=0, so `shl.b64 b,b,52` shifts a negative two's-complement value into the SIGN+exponent bits → garbage (e.g. -1.18e+269) instead of IEEE +0.0.
- FIX: one instruction `max.s64 b, b, 0` inserted between the `add.s64` (b=k+1023) and `shl.b64` (b<<=52). b clamps to 0 → 0<<52=0x0 = +0.0 → dst = p*+0.0 = +0.0 (p is finite positive ~[0.7,1.4], no NaN). No branch, no new scratch reg. compiler/codegen/nvptx_target.hexa ~L2008.
- VERIFY (local numerical vs libm, CPU model of the exact codegen seq w/ bits_to_float builtin): exp(-800)=0.0 / exp(0)=1.0 |Δ|=0 / exp(1)=2.71828 rel=7.3e-9. PASS. Bug-repro w/o clamp: exp(-800)=-1.18535e+269 FAIL → falsifier discriminates. probe = compiler/codegen/nvptx_expf64_underflow_clamp_probe.hexa; verdict = .verdicts/dojo-a4-nvptx-expf64-underflow/.
- STRUCTURAL GUARD: nvptx_expf64_polynomial_test.hexa now asserts emitted PTX contains `max.s64`.
- HONEST: GPU ptxas+driver-JIT round-trip on sm_80+ = open TODO (no pod safely rentable this unit). CPU model replays the EXACT instruction sequence so the numerical verdict is load-bearing; TODO is silicon attestation only.
