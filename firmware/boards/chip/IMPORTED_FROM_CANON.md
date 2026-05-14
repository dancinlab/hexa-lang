# Imported from canon (2026-05-10)

Files below were **moved** out of `dancinlab/canon` at `canon@a86ca143`
during the canon-minimization migration (research artifacts → domain standalones).
Canon no longer holds them; prior history is recoverable via `git log` in canon.

## papers/ — from canon `papers/`

- `papers/hexa-chip-6stage-unified.md`
- `papers/n6-advanced-packaging-integrated-paper.md`
- `papers/n6-advanced-packaging-paper.md`
- `papers/n6-chip-6stages-integrated-paper.md`
- `papers/n6-chip-design-ladder-paper.md`
- `papers/n6-chip-dse-convergence-paper.md`
- `papers/n6-cryptography-paper.md`
- `papers/n6-dram-paper.md`
- `papers/n6-exynos-paper.md`
- `papers/n6-hexa-3d-paper.md`
- `papers/n6-hexa-asic-paper.md`
- `papers/n6-hexa-chip-7dan-integrated-paper.md`
- `papers/n6-hexa-photon-paper.md`
- `papers/n6-hexa-pim-paper.md`
- `papers/n6-hexa-super-paper.md`
- `papers/n6-hexa-wafer-paper.md`
- `papers/n6-neuromorphic-computing-paper.md`
- `papers/n6-performance-chip-paper.md`
- `papers/n6-quantum-computing-paper.md`
- `papers/n6-unified-soc-paper.md`
- `papers/n6-vnand-paper.md`

## origins/ — from canon `bridge/origins/` (calculator/DSE tools)

- `origins/chip-n6-calc/`
- `origins/chip-perf-calc/`
- `origins/chip-power-calc/`
- `origins/gpu-arch-calc/`
- `origins/hexa-rtl/`
- `origins/interconnect-calc/`
- `origins/semiconductor-calc/`

## Wave Y absorption — 2026-05-14, hexa-chip HEAD

Vendored:
- chip-verify/ (24 scripts + reports, ~2,500 LOC) — empirical Xn6 micro-arch sandbox
- verify/run_all.hexa (Wave L green-core orchestrator)
- verify/chip_verify_bridge.hexa (Wave J chip-verify wiring)
- exynos/ (5 new files)

Not vendored (deliberately):
- terafab/, tsmc/, intel/ envelopes (Wave 3 SKIP — Python-heavy, R1 violation)
- 140 root spec .md files (canonical-link only — see ~/core/hexa-chip/ for full)

