# INBOX — current state

@goal: cross-project handoff 수신함 — 다른 repo가 hexa-lang으로 넘긴 gap·request를 추적하고 해소

(현재 상태만 기록 — 열린 handoff는 `- [ ]` 로, 처리 이력은 `INBOX.log.md` 로)

- [x] **hexa cloud pod 생성(provision) verb 부재** (from: demiurge RTSC) — 수신·라우팅 완료 (g48): **기 추적 갭**(신규 아님). provisioning verb = `archive/patches/archive/hexa-cloud-preflight-stub-and-provisioning-gap` gap#2 (→ RFC 088 P-series) · DFT/HPC preflight = **RFC 091**. RTSC SrAuH₃를 RFC 091 witness로 보강 권고. 상세 → `INBOX.log.md`
- [ ] **pool 호스트 hexa CLI stale — atlas-loop/drill 발사 불가** (from: this-session 2026-05-25T20:50Z) — ubu-1 drill `interp not found` · ubu-2 drill transpile SIGSEGV ([[reference_linux_transpiler_stale_build_recipe]] 잔존 가능성). pool routing 자체는 정상; ubu CLI 가 origin/main 대비 stale. 해결 = ubu 양쪽 `git pull + hexa cc --regen` + drill verb 컴파일 경로 마이그레이션 검토. 상세 → `INBOX.log.md`
- [x] **`hexa cloud nohup` 조기-사망 미감지 — silent class-1 launch 실패 ($3.92/158분 idle burn)** (from: anima `inbox/patches/cloud-launch-trainer-script-arg-missing.md`) — launcher 가 exec 직후 즉사(잘못된 script-path argv)해도 dispatcher 는 pid 만 받고 즉시 리턴 → watchdog 타임아웃까지 죽은 pod 가 과금. **해소(Option C, hexa-lang 측)**: `hexa cloud nohup … --early-life-check <sec>` 추가 — launch 후 `<sec>`초 sleep + pid 1회 poll, 이미 죽었으면 **exit 3** 으로 호출자가 즉시 teardown. Option A(dispatcher argv 수정)는 anima-local. 상세 → `INBOX.log.md`

> 참고: hexa-lang 내부 upstream-patch staging `inbox/` 폴더는 폐기됐다(rehome → `archive/patches/` · `archive/fires/` · `docs/notes/` · `docs/rfc/`). upstream 변경은 일반 PR 워크플로로 흐른다. 이 INBOX 도메인은 다른 repo 가 넘긴 cross-repo handoff 전용으로 별개 시스템이며 그대로 유지된다.
