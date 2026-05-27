# TAPE-AUDIT — xeno

> Audit-class survey for `.tape` adoption (typed events + provenance edges + delivery grade).

## A. Audit-class ledgers
**DESIGN.** `state/anima_n_substrate_n6_clm_qrng_2026_05_01/{prng_floor_runs,phi_star_results}.jsonl` are real per-run event streams (PRNG floor runs, phi-star IIT results). `state/nexus_sentinel/qrng_2026_05_03.jsonl`, `state/anima_nexus_qmirror_cli_refactor/refactor_log.jsonl`. `state/anima_markers/` has dense per-substrate run markers (`hardware_qrng_*`, `ionq_*`, `mock_qrng_*`, `n_substrate_putnam_check_*` with `_FAILED` suffix). Dozens of per-experiment state directories: `anima_n_substrate_f1_composite_*`, `anima_n_substrate_n1_bridge_4gate_*`, `anima_n_substrate_n10_eeg_sim_loop_*`, `anima_n_substrate_n12_aws_exec_*`, `anima_n_substrate_n12_quantum_pivot_*`, ... `anima_akida_d0_d1_plan` + `anima_akida_evidence` + `akida_cloud_d0_2026_05_09` neuromorphic evidence trees.

## B. Identity surface
**Substrate identity** is the central abstraction. xeno's whole purpose = identify and measure non-GPU exotic compute substrates: silicon neuromorphic (Akida) + biological organoid + quantum (IBM / IonQ / Rigetti / Braket) + random (ANU / NIST / CURBy QRNG). Each substrate = an identifiable performer of measurement events. Maps cleanly to `.tape` `@S` (system) per substrate, with `@->` edges between substrate runs and verdicts.

## C. Domain.md files
Light surface — only `AGENTS.md`, `CLAUDE.md`, `README.md` at root. State-dir naming (`anima_<feature>_<date>`) is the de-facto domain convention but isn't lifted to root UPPERCASE.md files. Opportunity: hoist `ANIMA.md` / `AKIDA.md` / `ORGANOID.md` / `N_SUBSTRATE.md` to root.

## D. Per-run / per-event history
Dense. Each `anima_n_substrate_n<NN>_*` directory is a per-experiment event capsule. `anima_akida_d0_d1_plan` is a planned-event scaffold. The `_FAILED` marker convention carries delivery grade.

## E. Promotion candidates
- **`.tape` events (HIGH)**: every substrate run → `@R` typed event with substrate `@S` provenance + run params `@K`. The `_FAILED` markers map directly to grade. Per-substrate `.tape` files (`AKIDA.tape`, `IONQ.tape`, `QRNG.tape`) — natural placement.
- **n6 atoms (MED)**: phi-star IIT thresholds, Bell-test reference values, Akida benchmark results are atom-shaped.
- **n12 cube**: substrate × method × era × condition → multi-axis territory if forge-style federation is wanted.
- **hxc wire**: applicable for live substrate streaming (e.g., real-hw Akida).

## Verdict
**HEAVY** — xeno is the substrate-measurement-ledger archetype. Dense per-experiment state-dirs + .jsonl event streams + per-substrate markers with delivery-grade suffixes. `.tape` promotion = formalize per-substrate run events + lift state-dir naming to root UPPERCASE.md domain files. Sister of qmirror (benchmark) and forge (cube impl) under `ATLAS.n12+XENO+QMIRROR.md` meta-domain.
