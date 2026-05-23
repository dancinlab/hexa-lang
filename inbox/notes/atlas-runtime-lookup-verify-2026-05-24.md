---
kind: verify-finding
date: 2026-05-24
scope: atlas SSOT runtime lookup
related-prs: ["#609", "#626", "#657", "#666"]
related-memory: ["atlas SSOT = n6/atlas.n6 (no hxc)"]
---

# atlas_cli rebuild + runtime lookup PASS — session atom audit

## TL;DR

**11 / 15 PASS · 4 / 15 FAIL** — runtime `hexa atlas lookup` against this
session의 ~15 등록 atom. FAIL 4건은 모두 PR #609 (RFC 047+046) atom 이며 동일
root cause: **#609 가 n6/atlas.n6 sync step 누락**, embedded.gen.hexa +
by_kind/f.gen.hexa 만 fold 함. #657 / #666 의 4-step closure 패턴 (verify
dispatch + atlas_cli register + n6 sync + ATLAS_F_NODES) 이 PR #609 에는
적용 안 됨 → lookup-path SSOT 와 binary-builtin SSOT divergence.

## 작업

1. **bin/hexa-atlas rebuild** PASS (HEXA_MAC_BUILD_OK=1 bypass · main worktree
   에서 빌드 · `/tmp/hexa-atlas-built` 1334KB · 21 file warns 무관)
2. **runtime lookup matrix** PASS=11 / FAIL=4 / 15
3. **freshness gate** — main worktree `n6/atlas.n6` STALE (`b#312`-era 61649 lines)
   이라 fresh clone (`/tmp/atlas_verify_fresh/fresh/n6/atlas.n6` 16072 nodes)
   를 `HEXA_ATLAS_N6=<dir>` 로 명시 지정해 측정 (env var 가 dir 컨테이너 받음 ·
   trailing /n6 필수)

## PASS / FAIL matrix

| # | id | PR | n6 sync? | lookup |
|---|---|---|---|---|
| 1 | verified-chsh_tsirelson-num | #657 | ✅ | PASS |
| 2 | verified-hardy_bound-2-num | #657 | ✅ | PASS |
| 3 | verified-mabk_quantum_max-3-num | #657 | ✅ | PASS |
| 4 | verified-pt_doily_quantum_win-num | #657 | ✅ | PASS |
| 5 | verified-ssh_winding-1-2 | #609 | ❌ | **FAIL** |
| 6 | verified-tknn_chern-2-5-1 | #609 | ❌ | **FAIL** |
| 7 | verified-welch_t_crit-num | #609 | ❌ | **FAIL** |
| 8 | verified-wilson_hilferty_p-num | #609 | ❌ | **FAIL** |
| 9 | verified-cdr_perfect_mitigation-0.5-num | #666 | ✅ | PASS |
| 10 | verified-qfi_ghz-4-num | #666 | ✅ | PASS |
| 11 | verified-qfi_sql-4-num | #666 | ✅ | PASS |
| 12 | verified-shadow_clifford_var_bound-4-num | #666 | ✅ | PASS |
| 13 | verified-shadow_pauli_var_bound-4-num | #666 | ✅ | PASS |
| 14 | verified-vqe_h2_fci_sto3g-num | #666 | ✅ | PASS |
| 15 | verified-wigner_stabilizer_sn-3-num | #666 | ✅ | PASS |

## Root cause (4 FAIL)

PR #609 (`atlas(RFC 047+046): register welch_t · wilson · ssh_winding ·
tknn_chern`) 는 atom 4 종을 `compiler/atlas/embedded.gen.hexa` +
`compiler/atlas/by_kind/f.gen.hexa` 에 fold 했으나 **`n6/atlas.n6` lookup-path
sync step 을 누락**. 후속 PR #657 (PR-A 2nd) 가 이 누락 패턴을 발견하고 4-step
closure (verify + register + n6 sync + ATLAS_F_NODES) 를 표준화 — #666 가
verbatim 재사용. 그러나 #609 atom 4 종은 retroactive sync 안 됨.

### 영향

- `hexa atlas lookup <id>` (runtime n6 path) → not found
- `hexa atlas stats` count → -4
- compile-time `static_atlas()` binary-builtin path 는 정상 (embedded fold OK)
- 따라서 코드 `@cite verified-ssh_winding-1-2` 컴파일은 PASS, but contributor
  CLI lookup workflow 는 FAIL

## Carry-forward

**다음 cycle** = PR #609 의 4 atom 을 `n6/atlas.n6` 에 retroactive append
(merger.hexa::_discover regen OR direct `_atom_register` 호출). #657/#666
패턴 verbatim.

scope = `n6/atlas.n6` (+~44 lines, 4 atom × ~11 lines each, witness shard
형식). wipe_guard 무관.

## 검증 환경

- worktree: `verify/atlas-cli-runtime-lookup-2026-05-24` (isolated)
- atlas_cli binary: `/tmp/hexa-atlas-built` (rebuilt 2026-05-24 from main
  worktree HEAD `3abbab2d`)
- n6 reference: `/tmp/atlas_verify_fresh/fresh/n6/atlas.n6` (fresh
  `git clone --depth 1 https://github.com/dancinlab/hexa-lang` 2026-05-24)
- main worktree n6: STALE (`atlas-pr-20260523-222533` 브랜치 · pre-session)
  — verify 환경에 부적합

## g5 VERBATIM ledger

모든 PASS lookup 은 `^@F <id>` 패턴 grep 으로 판정 (text-equal). 4 FAIL 은
runtime stderr `# not found: <id>` 매칭. 합성 / 추정 / over-claim 0.
