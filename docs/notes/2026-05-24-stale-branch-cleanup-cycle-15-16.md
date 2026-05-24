# Stale branch + worktree cleanup audit — cycle 15-16 (2026-05-24)

g47 hygiene 점검 결과.

## 1. cycle 15-16 잔재

| branch | 상태 | 조치 |
|---|---|---|
| `feat/verify-page-curve-qdrift-dispatch-2026-05-24` | local-only · PR 없음 · main 에 squash-merged (PR #663 retry로 흡수) | active worktree (`agent-a5464376d091ef1fc`) 가 보유 → 미터치 |
| `atlas/qmirror-pr-d-register-2026-05-24` | local-only · PR 없음 · main 에 batch squash-merged (PR #666 batch로 흡수) | active worktree (`agent-a294cf146ec3956af`) 가 보유 → 미터치 |

두 branch 다 cycle 15/16 truncated dispatch 후 retry 가 `-retry-` suffix 로 우회한 원본. 컨텐츠는 squash 형태로 main 에 모두 흡수됨. 보유 worktree 가 종료될 때 자연 정리 가능.

## 2. 안전 cleanup 실행 결과 (가역)

- **로컬 머지 branch 삭제**: 40개 (`git branch -d` only, force 안 씀)
  - merged-via-PR + 비 worktree-held + git fast-forward-detect 가능한 것만
- **stale remote-tracking ref prune**: 18개 (`git remote prune origin`)
  - origin 에서 이미 삭제된 branch 의 local ref 정리
- **worktree prune**: 0개 (prunable 없음 — 모두 active locked)

## 3. 안전 audit 잔여 (cleanup 안 함)

- **merged-but-not-deletable local branch**: 34개
  - squash-merge 라 git 가 unmerged 로 판단 → `-d` 거부
  - `-D` force-delete 가 필요해서 보수적으로 미터치
- **active worktree**: 256개 (git) / 229개 (디렉토리)
  - 모두 다른 세션 lock — 미터치
- **이전 /end 시점 19 merged-but-undeleted** 보고와 비교:
  - 그 시점 이후 cycle 활성이 추가 발생 → 현재 시점 측정은 40 삭제 후 잔여 46 (squash undetectable + 신규 머지)

## 4. 제약 준수

- destructive operation 없음 (`-d` only, no `-D`, no force-push)
- 다른 세션 active worktree 미터치
- unmerged branch 미터치
- origin remote branch 삭제 없음 (gh PR 삭제로 이미 정리됨 — `git remote prune` 만)

## 5. 다음 사이클 권고

- 34개 squash-merged local branch 의 `-D` 정리: 별도 세션에서 squash-merge-detection 스크립트(`git cherry main <branch>` 기반)로 안전 검증 후 batch 처리
- active worktree 256개 → 다른 세션 종료 후 `git worktree prune` 으로 자연 감소
