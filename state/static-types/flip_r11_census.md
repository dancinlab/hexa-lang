# Wall-A static-types — flip-criteria + r11 next-rung census (workflow w6jaifuf2)

## FLIP-ON 체크리스트 (HEXA_STATIC_TYPES default-ON) — verdict = NO-GO 오늘 (사다리 미머지)

| 게이트 | 상태 |
|---|---|
| **BLOCKER-0** stack 머지 | r7prep→r10 (#4457 gateway·#4507 r10) 아직 branch-only = MEASURED unmerged |
| **F0** HX3011 collision·HX3016 alloc·:348 explain | DONE · 단 flag-fold(ARRAY_LOWER→STATIC_TYPES) NOT DONE · r9b coercion arm(#4495) DONE |
| **F1** corpus-clean 0-HX3011/HX3016 census | NOT MEASURED (크래시 run만·재실행 안됨·scope도 69파일뿐→full corpus 확대 필요) |
| **F2** gen2-vs-native diag-stream parity + byteeq gen3≡gen4 flag-ON corpus-wide | NOT MEASURED (per-rung 주장만) |
| **F3** env-hoist refactor | DONE · ≤2% stage-1 wall delta NOT MEASURED |
| **F4** warn-first→error 2-step + grace waiver | DESIGNED not built (HX3011/HX3016 오늘 fatal) |
| **F5** flip-PR 메커닉 | not started |

**정정 (census)**: arg-count(HX3002)·arg-type(HX3003)·return-type(HX3004)는 **이미 default-ON** — r11 후보 아님(static-types 렁은 KNOWN 타입만 더 먹임).

**flip 최소 경로**: stack 머지 → 2 flag fold → F1 재실행+full corpus 확대(true-positive를 일반 PR로 수정=가치증명) → F2 dual-frontend diff=0 + byteeq 캡처 → F3 ≤2% 캡처 → F4 Warning band 한 사이클 후 Error 승격. (flip 자체는 native-canonical polarity상 user-go)

## r11 NEXT-RUNG = missing-required-field E0063 (HX3017 Warning-band)

r1~r10이 **아직 못잡는** 유일한 task-named 클래스 = missing-required-field(Rust E0063): `Point{ x: 1 }`인데 `Point`가 `x`/`y` 둘 다 요구. HX3016(struct has no field)의 쌍 — 존재하지 않는 필드는 HX3016, 빠진 필수 필드는 HX3017. census 권고 = **Warning-band**(SSOT F4 정합·기존 REJECT 클래스와 달리 non-fatal로 시작).

## 열린 질문 (사용자/후속)
- F1 census가 `|| true` fix(87bd65358) 후 재실행됐나? f1_first_run.md는 그 이전 — dirty-file 수/true-positive 목록 아직 미상.
- F1 scope 69파일 vs SSOT §B.2 full ~1.11M-LOC 코퍼스 — narrow가 의도(bootstrap subset)인지 flip 전 확대할 갭인지.
- r11 E0063 = Warning band(SSOT F4)인가 HX3016처럼 fatal REJECT인가? (endgame doc는 warning-band이나 r9d 착지 전 기록)
