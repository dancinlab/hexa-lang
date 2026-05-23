# RFC 045 QMIRROR PR-A — atlas_cli register mirror + n6 sync (다음 사이클)

## 한 줄 요약
QMIRROR PR-A 1차 분리: `tool/verify_cli.hexa` dispatch 4 fn (chsh_tsirelson · hardy_bound
· mabk_quantum_max · pt_doily_quantum_win) + `compiler/atlas/embedded.gen.hexa`
4 atom splice 까지 landed. 남은 surface 2건은 다음 사이클로 분리:
1. `tool/atlas_cli.hexa` 의 `_recompute_float_register` / `_is_float_fn_register`
   mirror table 확장 (현재 welch_t_crit / wilson_hilferty_p 만; chsh/hardy/mabk/ptd
   미동기화). 0-arg float dispatch 도 atlas_cli 에는 없음.
2. n6 sync — `embedded.gen.hexa::ATLAS_F_NODES` 의 신규 4 atom 을 `n6/atlas.n6`
   에 반영해야 `hexa atlas lookup F verified-chsh_tsirelson-num` 같은 lookup
   이 실제로 PASS 한다. 현재 atlas 바이너리는 atlas.n6 에서 16,061 노드 로드,
   embedded.gen.hexa::ATLAS_F_NODES (현 8 atom) 는 lookup view 에 wire 안 됨
   (`stdlib/loop/cycle.hexa::build_atlas_view` 의 `f_nodes: []`).

## status
RESOLVED 2026-05-24 — PR-A 2차 (cycle 14 lane) 에서 두 surface 모두 닫음.
end-to-end PR-A QMIRROR atom 4종 (verify VERBATIM ✅ + atlas_cli register mirror ✅
+ atlas lookup ✅) 완결.

closure 작업:
- `tool/atlas_cli.hexa::_recompute_float_register` 4 atom mirror 추가
  (chsh_tsirelson · hardy_bound · mabk_quantum_max · pt_doily_quantum_win,
  verbatim port of verify_cli; pt_doily_classical_bound 도 dispatch 만 포함)
- `_is_float_fn_register` / `_is_zero_arg_float_fn_register` 화이트리스트 동기화
- `cmd_register` float 분기에 0-arg dispatch (`<fn> <v>`) 처리 추가
- `_adapt_verify_float` argc=0 echo 처리 (`fn_name()=v`)
- `n6/atlas.n6` 4 atom append (`@F verified-{chsh_tsirelson,hardy_bound-2,
  mabk_quantum_max-3,pt_doily_quantum_win}-num`)
- `compiler/atlas/by_kind/f.gen.hexa` ATLAS_F_NODES 8 atom (cycle 10 + cycle 13
  cumulative) sync — 기존 빈 array → 8 entries
- `stdlib/loop/cycle.hexa::build_atlas_view` `f_nodes: ATLAS_F_NODES` wire

검증 (prebuilt `bin/hexa-atlas` + `HEXA_ATLAS_N6=$(pwd)/n6`)
- `hexa atlas lookup F verified-chsh_tsirelson-num` → @F PASS (atlas.n6:61653)
- `hexa atlas lookup F verified-hardy_bound-2-num` → @F PASS (atlas.n6:61659)
- `hexa atlas lookup F verified-mabk_quantum_max-3-num` → @F PASS (atlas.n6:61665)
- `hexa atlas lookup F verified-pt_doily_quantum_win-num` → @F PASS (atlas.n6:61671)
- `hexa atlas stats` → total 16061 → 16065 (F 1309 → 1313, 정확히 4 atom 반영)
- `hexa parse` 3 파일 (tool/atlas_cli, stdlib/loop/cycle, compiler/atlas/by_kind/f.gen) PASS

## 이번 PR 에서 닫은 부분 (g5 VERBATIM 4 atom)
- chsh_tsirelson()=2.8284271247461903 → 🟢 SUPPORTED-NUMERICAL (|Δ|=0.0)
- hardy_bound(2)=0.09016994374947425 → 🟢 SUPPORTED-NUMERICAL (|Δ|=1.4e-17)
- mabk_quantum_max(3)=2.0 → 🟢 SUPPORTED-NUMERICAL (|Δ|=4.4e-16)
- pt_doily_quantum_win()=1.0 → 🟢 SUPPORTED-NUMERICAL (|Δ|=0.0)

🔴 FALSIFIED gate 실재 확인:
- mabk_quantum_max(3)=5.0 → 🔴 FALSIFIED (|Δ|=3 > ε=1e-9)
- pt_doily_quantum_win()=0.5 → 🔴 FALSIFIED (|Δ|=0.5 > ε=1e-9)

## 인용 (소스 verbatim)
- CHSH Tsirelson: `stdlib/quantum/chsh/module/chsh.hexa` 의 analytic identity
  `S = 4*sqrt(2)/2 = 2*sqrt(2)`. Cirel'son 1980 LMP 4 93.
- Hardy multipartite: `stdlib/quantum/hardy-multipartite/module/hardy_multipartite.hexa`
  ::_hm_solve_tr + _hm_pmax_closed (Newton-Raphson on `x^{N+1}-2x+1=0`,
  naive powi). Adhikary-Mandal Eq.5 (arXiv:2505.10170).
- MABK quantum max: `stdlib/quantum/mabk-ardehali/module/mabk_ardehali.hexa`
  ::_mabk_quantum_max — `2^((N-1)/2)` via sqrt(2)-product loop. Mermin 1990 /
  Ardehali 1992 / Belinskii-Klyshko 1993.
- PT-doily quantum win: `stdlib/quantum/pseudo-telepathy-doily/module/pseudo_telepathy_doily.hexa`
  pseudo-tel 정리 = quantum win prob EXACTLY 1.0. Brassard-Broadbent-Tapp 2005
  Found. Phys. 35 1877 (arXiv:quant-ph/0407221) / Mermin 1990 PRL 65 3373.

## 분해 — cycle 12 lane 1 truncated 회피
원 작업 (verify dispatch + atlas_cli register mirror + n6 sync 동시) 은 응답
truncated 위험으로 분할:
- PR-A 1차 (이 PR): verify dispatch + embedded.gen.hexa fold
- PR-A 2차 (다음 사이클): atlas_cli register mirror + n6 sync (lookup 완결)
