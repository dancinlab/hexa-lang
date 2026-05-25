# M8 — discovery_loop.py → hexa-native 발견 엔진 (RFC 065 + RFC 080)

> archive-TECS-L 의 `discovery_loop.py` (DFS→Converge→Verify→Grow→Paper 흡수 루프)는
> hexa-lang 에 **이미 hexa-native 로 이식·shipped** 돼 있다 — RFC 065(self-growing
> atlas) + RFC 080(`--dfs` 포트). M8 = 그 통합을 스모크 검증 + 매핑 문서화 (g0 Occam:
> 새로 짓지 않고 기존 통합 확인). 옛 루트 `TECS-L.md` 자체가 RFC 080 계획서였음.

## 스모크 (실증)

`hexa loop --once` (격리 worktree) → 8-stage 사이클 완주:
```
[1/8 SCAN] corpus snapshot   [2/8 LENS] 36 lens → 153 candidate
[3/8 DEDUP] 153 survive       [4/8 GATE] 0 fire / 153 settled
[5/8 FIRE] --no-fire          [6/8 DRAFT] 148 → archive/atlas_candidates/
[7/8 AUDIT] chain += 153       [8/8 EXHAUST] continue
```
원문: `.verdicts/tecs-l-discovery-engine/loop_once_smoke.txt`.

## 매핑: archive `discovery_loop.py` → hexa-native

| archive 단계 | hexa-native 등가 | SSOT |
|--------------|------------------|------|
| DFS Engine (`dfs_engine.py`) | `hexa loop --dfs` (beam search + LLM pluggable) | `stdlib/loop/dfs.hexa` · RFC 080 |
| Convergence / Quantum / Perfect 엔진 | `hexa loop` 36 lens (8 family) + `hexa kick`/`hexa drill` (gap 엔진) | `stdlib/loop/cycle.hexa` · RFC 065 |
| Verify | `hexa verify` (g5 tier) | self/verify |
| Grow (atlas 흡수) | RFC 065 self-growing atlas (`archive/atlas_candidates/` emit → PR → embedded.gen) | `compiler/atlas/embedded.gen.hexa` |
| Paper | `/paper` (paper_on_discovery) — M9 에서 실증 | `PAPER/` |
| `results/loop/discoveries.jsonl` | `chain.jsonl` + `archive/atlas_candidates/<slug>.md` | `state/loop/` |

## 결론

M8 통합은 RFC 065 + RFC 080 으로 **이미 완료·shipped** 이며 본 스모크로 end-to-end
동작을 재확인했다. archive 의 Python 발견 루프 6+엔진이 hexa-native `hexa loop`(36 lens)
+ `hexa loop --dfs` + `hexa kick`/`drill` + `hexa verify` + `/paper` 로 1:1 대응된다.
LLM 동반 모드는 `hexa loop --claude` (RFC 080, opt-in · 비용 cap · cite-verify gate).
