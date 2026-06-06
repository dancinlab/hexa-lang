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

## 2026-06-07 — DOJO-A1 closed (🟢 emit-step verified · partial closed-negative)
- Recovered the 2 proven laneg fixes via `git fetch` + `git show 27535d93d bb10154fb`:
  #3a `27535d93d` = HEXA_NO_CUDA=1 guard on the nested runtime_cuda.c emit (kills the
  fork-bomb recursion under HEXA_CUDA_LINK=1); #3b `bb10154fb` = write_file builtin
  instead of a cat-heredoc-via-exec (the ~100KB write was silently dropped at E2BIG).
- FINDING vs current main (9b4f2c143): #3b is **already on main** — landed independently
  as #2630 (`8409117e2`); `runtime_cuda_emit.hexa::main()` already does
  `write_file(out_path, c_text)`. #3a targets `cuda_link_decision()` + the
  `HEXA_CUDA_LINK=1` OPT-IN link path, which was **never merged** to main
  (`grep HEXA_CUDA_LINK self/main.hexa` → rc=1; `cmd_build` reads neither env, has no
  nested emit). The opt-in path lived only on the lane-g/forge-gpu lineage
  (4f64ed119/8312a8cae), on-device fire BLOCKED-OUTAGE (0904b972d), never landed.
  → fork-bomb is STRUCTURALLY IMPOSSIBLE on main; nothing to port for #3a here.
- GATE (local, emit-step = the exact step that fork-bombed on laneg):
  `hexa run self/cuda/runtime_cuda_emit.hexa /tmp/out.c` → rc=0, **308919 B** written
  (≫100KB, not dropped), single short-lived process (no 1800+ proc storm).
  fork-bomb gone = YES · runtime_cuda.c full = YES. Verdict verbatim at
  `.verdicts/dojo-a1-cudalink-forkbomb/DOJO-A1.txt`.
- TODO (named): full `HEXA_CUDA_LINK=1 hexa build clm_prod.hexa` end-to-end nvcc/pod
  link not run — the opt-in link path is absent from main so there is nothing to link
  via that env. If the lane-g opt-in feature ever merges, re-port BOTH guards together
  and fire full-link confirm on a CUDA pod.

## 2026-06-07 — DOJO-A2 + DOJO-A3 absorbed (build-trap advisories)
- A2 (4a7841fe) DONE: added `dojo_glibc_advisory` to tool/dojo_rent_preflight.sh — pre-rental static inference from the image tag (ubuntu22.04 → glibc ≤2.35 → WARN + recommend ubuntu24.04/from-source) AND on-pod live `ldd --version` detection that BLOCKs (returns 1) on a real < GLIBC_2.38 mismatch; clears ubuntu24.04 (glibc 2.39). + `_dojo_glibc_lt` numeric comparator. docs/hexa-dojo.md "forge-CUDA build traps" subsection + references handoff cite.
- A3 (d751e2c4) DONE: added `dojo_stack_advisory` — reads `ulimit -s`, WARNs at the ~8 MB default + prints the exact `ulimit -s 65536` (64 MB) raise to run in the same shell BEFORE tool/stage_build_hexa; advisory-only (never blocks). docs subsection shows the on-pod build flow. references handoff cite.
- Verify: `bash -n tool/dojo_rent_preflight.sh` SYNTAX-OK; `--self-test` ALL GREEN (6 fixes + recipe + A2/A3 = new tests for static/live/comparator + cite/raise/non-block).
- Milestones A2 + A3 flipped to [x] in HEXA-DOJO.md. Remaining LAYER-A: A1 (fork-bomb, branch land), A4 (nvptx exp underflow, codegen), A5 (shfl FP64, codegen) — all codegen/land, not dojo-doc.

## 2026-06-07 — DOJO-A5 CLOSED (already-landed, verified by source audit + emit-inspection)
- Branch `domain/dojo-a5-shfl-fp64` off origin/main (9b4f2c143). Task: fix gpu_warp_shuffle_xor FP64 NVPTX lowering (FP64 src spelled as `%r<id>` u32 → ptxas 'Arguments mismatch for shfl').
- FINDING: the fix is ALREADY in origin/main — `b1564fa37 fix(codegen): NVPTX FP64 warp-shuffle composition (N71-B / N70 GAP-C) (#1200)`. The milestone cited a non-existent commit `0a848320` (RFC071 GAP-C label); the real landing is N70/N71-B GAP-C #1200. No new codegen edit needed.
- The FP64 split-shfl machinery is complete across 3 sites of `compiler/codegen/nvptx_target.hexa`:
  - body lowering L1700-1756: `gpu_warp_shuffle_xor` f64 src → `mov.b64 {lo,hi}, %fd<src>` decompose → `shfl.sync.bfly.b32` ×2 (lane/mask u64-narrowed via `cvt.u32.u64` to a `.b32` scratch) → `mov.b64 %fd<dst>, {lo_out,hi_out}` recompose.
  - classifier dst-kind override L4087-4092: when shuffled value (args[0]) classifies F64, the shuffle dst inherits the `%fd` (F64) bank instead of the hardcoded U32 — so the recompose target reg is declared correctly.
  - Pass-4 scratch-half decl L4277-4297: 4 `.reg .b32` halves (`%shfl_lo/hi/lo_out/hi_out_<id>`) + optional `%shfl_mask_<id>` u32 narrow, keyed on dst id.
- GATE(g5) = emit-inspection (no local ptxas/nvcc; local hexa is stale Jun-1 oracle, full self/main.hexa build from source did not converge → relied on committed fixture). Committed `compiler/codegen/nvptx_p9_warp_reduce_test.hexa.ptx` shows the ptxas-valid form: `cvt.u32.u64 %r_shfl_mask_18, %rd16` → `mov.b64 {%r_shfl_lo_18,%r_shfl_hi_18}, %fd9` → `shfl.sync.bfly.b32` ×2 → `mov.b64 %fd18, {%r_shfl_dlo_18,%r_shfl_dhi_18}` → `add.f64`. Split-shfl present, operands `.b32`/`%fd`, NO f64-src-as-`%r`, NO Arguments-mismatch. ptxas-compile: Y (by inspection — no `%r`-typed f64 shfl operand remains).
- bit-correct on silicon = TODO: no safely-rentable leak-0 sm_90/120 pod this round (did NOT fake g5). Next session can fire `warp_reduce_sum` on an H100/sm_90 vs CPU FP64 LCG reference (falsifier F-RFC071-E2E-WARP-REDUCE-SUM-NUMERIC-EQ, ≤4 ULP) to flip the TODO.
