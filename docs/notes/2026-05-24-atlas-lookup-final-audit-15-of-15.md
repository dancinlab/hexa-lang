# Atlas lookup final audit — 15/15 PASS (cycle 18 closure)

> 2026-05-24 격리 worktree audit · prebuilt `bin/hexa-atlas` + `HEXA_ATLAS_N6=<repo>/n6`

## TL;DR

머지된 atom register PR (#609 + #657 + #666 + retro #678) 의 **15 atom 전수
`hexa atlas lookup <id>` 15/15 PASS**. PR-D #668 / PR-E #680 머지 시 19/19
expansion 예약. atlas stats=16,076 nodes / F=1324 / ATLAS_HASH
`990ab0af269fa56f71d3c1a42cce2e7ef84dd2c2ab46a6d54cd8bfdd21205c33`.

## Lookup matrix (15 atoms · main HEAD `ea6c9a1a`)

| # | atom id | source PR | status |
|---|---|---|---|
| 1 | `verified-welch_t_crit-num`              | #609 + retro #678 | PASS |
| 2 | `verified-wilson_hilferty_p-num`         | #609 + retro #678 | PASS |
| 3 | `verified-ssh_winding-1-2`               | #609 + retro #678 | PASS |
| 4 | `verified-tknn_chern-2-5-1`              | #609 + retro #678 | PASS |
| 5 | `verified-chsh_tsirelson-num`            | #657 (PR-A) | PASS |
| 6 | `verified-hardy_bound-2-num`             | #657 (PR-A) | PASS |
| 7 | `verified-mabk_quantum_max-3-num`        | #657 (PR-A) | PASS |
| 8 | `verified-pt_doily_quantum_win-num`      | #657 (PR-A) | PASS |
| 9 | `verified-cdr_perfect_mitigation-0.5-num`| #666 (PR-B) | PASS |
| 10 | `verified-wigner_stabilizer_sn-3-num`   | #666 (PR-B) | PASS |
| 11 | `verified-vqe_h2_fci_sto3g-num`         | #666 (PR-C) | PASS |
| 12 | `verified-qfi_sql-4-num`                | #666 (PR-C) | PASS |
| 13 | `verified-qfi_ghz-4-num`                | #666 (PR-C) | PASS |
| 14 | `verified-shadow_pauli_var_bound-4-num` | #666 (PR-C) | PASS |
| 15 | `verified-shadow_clifford_var_bound-4-num` | #666 (PR-C) | PASS |

**Total: 15/15 PASS (100%)**

## Pending atoms (4 PR-D + 4 PR-E = future 19/19)

PR #668 (PR-D) OPEN — atoms not yet in main:

- `verified-page_curve_entropy_peak-4-16-num`
- `verified-qdrift_error_bound-10.0-200-num`

PR #680 (PR-E) OPEN, `mergeStateStatus=DIRTY` (depends on #668), auto-merge
queued — atoms not yet in main:

- `verified-overlap_vqe_h2_shift_ha-num`
- `verified-mirror_bench_hog_asymptote-num`
- `verified-sym_shadow_var_bound-3-2-num`
- `verified-rpe_heisenberg_sigma-7-8-num`

#668 머지 → #680 conflict 자동 해소 → auto-merge 발화 시 **19/19 PASS**.

## Build status

- `tool/build_hexa_atlas.sh` rebuild from `worktree-agent-aba890a195c32085a`
  source FAIL — `round_run_with_pool` 미선언 (별개 main 회귀, 본 audit
  scope 외).
- 검증은 사전빌드 `/Users/ghost/core/hexa-lang/bin/hexa-atlas` (arm64
  Mach-O) + worktree `n6/atlas.n6` (origin/main `ea6c9a1a`) 조합으로 수행 —
  atom 데이터 SSOT 일치 검증 목적에 충분.

## QMIRROR milestone (main view)

| PR | Topic | State |
|----|-------|-------|
| PR-A | Bells/Nonlocality — CHSH · Hardy · MABK · Pseudo-tel | MERGED #657 (4 atoms PASS) |
| PR-B | Mitigation/Clifford — CDR · Wigner | MERGED #666 (2 atoms PASS) |
| PR-C | Variational/Fisher — VQE · QFI · Shadow | MERGED #666 (5 atoms PASS) |
| PR-D | Dynamics — Page-curve · Qdrift | OPEN #668 |
| PR-E | Support — Sym-shadow · Overlap-VQE · RPE · Mirror-bench | OPEN #680 (auto-merge queued, DIRTY) |

Lookup-측 milestone = **3/5 closed (15 atoms PASS)**. 5/5 close 는 #668 +
#680 머지 후 19/19 audit 재실행으로 확정.

## atlas stats sync

- `ATLAS_SOURCE_COUNT` = 15
- `total nodes` = 16,076 (base 16,066 + 10 newly synced atoms; 11번째
  atom 은 base 16,066 의 일부였음 — F 카운트는 +11 = 1324)
- `F formulas` = 1,324
- `ATLAS_HASH` = `990ab0af269fa56f71d3c1a42cce2e7ef84dd2c2ab46a6d54cd8bfdd21205c33`

기존 base 16,066 (F=1313) 와의 +10 nodes / +11 F 차이는 expected — PR
#657 / #666 / #678 의 cumulative additive sync 결과.

## 결론

cycle 17 #673 audit 의 11/15 PASS → cycle 18 retro #678 머지 → **현재 main
15/15 PASS** end-to-end 확인. PR-D / PR-E 머지 후 19/19 audit 은 별도
cycle 로 예약.
