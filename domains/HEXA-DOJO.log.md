# HEXA-DOJO — step log (append-only)

## 2026-06-07 — domain init
- Tracks the dojo as the forge-CUDA build-trap absorption + kernel-authoring practice surface. 5 LAYER-A milestones from open handoffs: 677b84cd fork-bomb, 4a7841fe glibc, d751e2c4 stack-SIGKILL, d631a08f nvptx-exp-underflow, 0a848320 shfl-FP64.
- Honest scope (g5): dojo cures LAYER-A (build/toolchain); LAYER-B (serial kernel-DAG util ceiling) is HEXA-FUSION's fusion problem (graph-capture FALSIFIED, only lift = TF32 megakernel +5.5pp). dojo = recipe book, not oven.
- A1/A4/A5 = codegen/tooling fixes; A2/A3 = dojo-doc + preflight workarounds.

## 2026-06-07 — DOJO-A2 + DOJO-A3 absorbed (build-trap advisories)
- A2 (4a7841fe) DONE: added `dojo_glibc_advisory` to tool/dojo_rent_preflight.sh — pre-rental static inference from the image tag (ubuntu22.04 → glibc ≤2.35 → WARN + recommend ubuntu24.04/from-source) AND on-pod live `ldd --version` detection that BLOCKs (returns 1) on a real < GLIBC_2.38 mismatch; clears ubuntu24.04 (glibc 2.39). + `_dojo_glibc_lt` numeric comparator. docs/hexa-dojo.md "forge-CUDA build traps" subsection + references handoff cite.
- A3 (d751e2c4) DONE: added `dojo_stack_advisory` — reads `ulimit -s`, WARNs at the ~8 MB default + prints the exact `ulimit -s 65536` (64 MB) raise to run in the same shell BEFORE tool/stage_build_hexa; advisory-only (never blocks). docs subsection shows the on-pod build flow. references handoff cite.
- Verify: `bash -n tool/dojo_rent_preflight.sh` SYNTAX-OK; `--self-test` ALL GREEN (6 fixes + recipe + A2/A3 = new tests for static/live/comparator + cite/raise/non-block).
- Milestones A2 + A3 flipped to [x] in HEXA-DOJO.md. Remaining LAYER-A: A1 (fork-bomb, branch land), A4 (nvptx exp underflow, codegen), A5 (shfl FP64, codegen) — all codegen/land, not dojo-doc.
