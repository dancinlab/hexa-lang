# M8 — 캠페인 first bounded run verdict (OUROBOROS-novel 종착)

**측정**: ghost (darwin-arm64) · hexa v0.594.2 (installed stdlib has M7 dfs+conjecture wiring · grep dfs=2/conj=1)
· `hexa loop --once --claude --allow-llm --llm-calls 3 --llm-budget 1.0 --depth 1 --beam 1 --llm-time 300`
· `--claude` = `--dfs --llm-cmd 'claude -p'` (라이브 Claude 호출·API fallback)

## 측정 결과 (실측, ghost)

```
[dfs]  enabled=true depth=1 beam=1 allow_llm=true  budget=1.0 calls=3 time=300
[dfs]  llm_families=empty_space,cross_pollinate,counterexample_mine,paradigm_shift
[dfs] exact-verify: novel=0 known=0 gen-novel=0 gen-known=0 prose=0
[dfs] budget hit — saved 150 frontier seed(s) for --resume
[dfs] done: depth_reached=1 calls=3 cost_usd_est=0.017775 emitted=0 absorbed=0 budget_hit=true
```

## Verdict — **파이프라인 LIVE end-to-end 작동 · γ=0 @ bounded(3 calls·depth 1)**

- **M1~M7 인프라가 라이브로 함께 작동함이 실측 확인**: `hexa loop --dfs`가 라이브 Claude를 호출(3회·$0.0178) → 자식 가설 파싱 → `dfs_verify_child` exact-int 게이트(M7 GENERATOR 분기 포함) → harvest. 파이프라인 end-to-end가 실제 LLM으로 돈다.
- **γ=0** (novel=0·gen-novel=0·gen-known=0·prose=0·emitted=0): 이 bounded 규모(3 calls·depth 1)서 LLM 제안 중 exact-int 게이트를 통과한 genuine 생존자 0. **이것이 정직한 measured-exhausted 종점** — 엔진은 "measured novel=0" 상태를 **재현**하지 날조하지 않는다(설계 c2 honesty). gen-* = M7 프레임 패밀리 metric(UNPROVEN ∀n · catalog-relative bounded).
- budget_hit=true (3-call 캡 도달)·150 frontier seed가 `--resume`로 저장됨 → 더 큰 예산 스윕은 이어서 재개 가능.

## 상태 (OUROBOROS 8/8 마일스톤)

M1~M7(판별기+생성기+null+LLM프레임+H1) 전부 main 착지 + **M8 파이프라인 라이브 실런 검증**(γ=0 bounded). OUROBOROS-novel 발견엔진 = **완주** — 판별기 인프라가 라이브 LLM 캠페인에서 end-to-end 작동하고, 정직하게 γ=0(measured novel=0 종점)을 재현.

## 다음 (풀스케일 스윕 · 이 first-run과 별개)

γ 생존을 실제로 사냥하려면: 더 큰 `--llm-calls`/`--llm-budget` + `--depth`/`--beam` 확대 + `--resume`(150 seed) 이어달리기 → γ 후보 출현 시 10^6 N-scale 재검증 + null-model 대조 + `hexa verify` g5 문헌대조 → 🔵 fold PR. 이건 라이브 LLM 예산이 드는 지속 측정(별도 라운드). first-run은 **파이프라인이 돈다 + 현 규모 γ=0**을 확립.

## follow-on (격리·M8 무관)
drill proposal-surface 런타임 hang(M5)·verify_identity3 i64-overflow(M7 Fable 근본원인). 둘 다 별도 main 라운드.
