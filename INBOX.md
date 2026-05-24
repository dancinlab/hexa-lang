# INBOX — current state

@goal: cross-project handoff 수신함 — 다른 repo가 hexa-lang으로 넘긴 gap·request를 추적하고 해소

(현재 상태만 기록 — 열린 handoff는 `- [ ]` 로, 처리 이력은 `INBOX.log.md` 로)

- [ ] **hexa cloud pod 생성(provision) verb 부재** — vast GPU dispatch 진입 불가 (from: demiurge RTSC). `hexa cloud up/down <provider>` (vast REST wrapped) + list/status provider-generic 필요. 상세 → `INBOX.log.md`

> 참고: hexa-lang 내부 upstream-patch staging `inbox/` 폴더는 폐기됐다(rehome → `archive/patches/` · `archive/fires/` · `docs/notes/` · `docs/rfc/`). upstream 변경은 일반 PR 워크플로로 흐른다. 이 INBOX 도메인은 다른 repo 가 넘긴 cross-repo handoff 전용으로 별개 시스템이며 그대로 유지된다.
