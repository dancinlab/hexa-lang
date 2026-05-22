# 인터프리터 잔재 doc 정리 권장

**출처**: anima 세션 cross-project 인터프리터 정리 (2026-05-23)
**kind**: notes — hexa-lang 자체 workflow 에서 처리 권장

## 배경

hexa 가 컴파일 언어로 정착 (인터프리터 폐기 방향). dancinlab 전 프로젝트에서
인터프리터 잔재를 정리하던 중 hexa-lang repo 에 stale 인터프리터 doc 2건 발견.

anima 세션에서 직접 삭제하지 않은 이유 — hexa-lang 이 feature 브랜치
(`cloud-dir-fetch-2026-05-23`) 에서 WIP 중이라 tracked doc 삭제 + commit 이
진행 작업과 간섭. hexa-lang 자체 workflow 에서 정리하는 게 맞음.

## 정리 대상

| 파일 | 성격 |
|---|---|
| `docs/interp_regression_20260424.md` | 인터프리터 회귀 테스트 doc (dated) |
| `docs/interpreter_stale_root_cause_20260423.md` | 인터프리터 stale root-cause 분석 doc (dated) |

→ 인터프리터 폐기가 확정됐다면 두 doc 은 stale. g15 (current-state docs ·
history → CHANGELOG/git log) 기준으로도 dated 분석 doc 은 정리 대상.

## 보존 (정리 대상 아님)

- `self/ml/mechanistic_interp.hexa` — mechanistic **interpretability** (ML
  해석성), 언어 인터프리터와 무관. false-positive, 유지.
- `hexa.real` · `self/native/hexa_v2*` · `build/` — 컴파일러 자산, 유지.
- bootstrap stage0 인터프리터 — README 상 "retires once stage3 hits byte-equal
  fixed point" — 아직 retire 안 됐으면 부트스트랩에 필요, 유지.

## 참고 — 이미 정리된 것

`.hexa-cache` (root + `.claude/worktrees/agent-*/` 11개, ~357M) 는 transient
compile cache 라 anima 세션에서 일괄 삭제 완료.
