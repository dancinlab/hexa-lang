# CHANGELOG.d/ — 조각파일 모드 (towncrier/changesets식 · 동시 다중 PR 충돌-free)

이 디렉터리가 존재하면 `sidecar changelog add`는 `CHANGELOG.jsonl`(공유 단일 파일)에
prepend하는 대신 **PR마다 자기 파일** `CHANGELOG.d/<sortable-id>-<slug>.jsonl`(JSON 1개)을
쓴다. 두 PR이 같은 줄을 건드리지 않으므로 **머지 충돌이 사라진다**(이전엔 append-only
CHANGELOG.jsonl이 multi-session에서 매 머지마다 충돌).

## 규율
- 항목 추가: `sidecar changelog add "<title>"`(stdin으로 body) → 여기 조각파일 1개 생성.
- 접기(fold): `sidecar changelog fold`(또는 `render`) → 조각들을 `CHANGELOG.jsonl`로 모으고
  소비된 조각 삭제. **default 브랜치(main)에서만** 접어 single-writer 유지(feature 브랜치서
  접으면 조기-fold로 충돌 재발). 릴리스 시점 또는 정기적으로 main에서 1회.
- `CHANGELOG.jsonl`은 여전히 history SSOT(접힌 결과). 조각은 미접힘 대기열.

이력은 git. capability SSOT = sidecar `modules/changelog.ts`(RFC: towncrier/changesets).
