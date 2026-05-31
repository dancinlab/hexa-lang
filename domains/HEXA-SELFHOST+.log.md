# HEXA-SELFHOST+ — log

Append-only history sister of `HEXA-SELFHOST+.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.


## 2026-05-31 메타도메인 등록 (init + goal + 롤업 마일스톤)

세 self-host 도메인(BUILDFLOOR 0% · RUNTIME 80% · CC-NATIVE 12%)을 한 북극성
("hexa 가 C 없이 자기를 빌드")으로 묶어 메타도메인 HEXA-SELFHOST+ 등록.
의존 흐름: BUILDFLOOR(레시피) → RUNTIME(런타임) → CC-NATIVE(컴파일러).
메타 규약: 실제 flip 은 자식 SSOT 에서, 이 파일은 cross-domain 조율/차단/의존만.
4 milestone: 의존순서 박제 · 공통-벽 카탈로그 · 다음-칸 셀렉터 · 졸업 게이트.
HEXA-CC-ZERO(✅100% 커밋.c=0)의 자매 = 빌드산출.c=0 한 단계 더.

## 2026-05-31 CC-NATIVE 핸드오프 흡수 + 공통-벽 카탈로그 갱신

타세션이 CC-NATIVE 도메인을 중복 진행 → 사용자 중단 → 이 세션(메타)으로 일원화.
drafts/SESSION-HANDOFF-hexa-cc-native.md 참고. 타세션 결과(#2270 N6 phase-2)는
이미 main 박제: native print/stdout = IO-floor codegen 벽 honest-STOP.

- 공통-벽 카탈로그에 (4) native backend IO-floor 추가 — (1) codegen type-erasure 와
  같은 뿌리(codegen emit 단). RUNTIME 순수-fn · GPU 1b-cons · CC-NATIVE native-print
  = 동일 codegen emit 벽 3-자식 동시 차단. 레버 = emit 단 1회 개방(sign+in-process 검증).
- 다음-칸 셀렉터: 회전 이력 박제(3 codegen honest-STOP) → 현재 칸 BUILDFLOOR M1
  (.sh fix, codegen 벽 無, agent 진행 중)이 유일 grounded.
- 메타 milestone 2개([~]): 공통-벽 카탈로그 · 다음-칸 셀렉터 진전.
