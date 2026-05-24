# INBOX — current state

@goal: cross-project handoff 수신함 — 다른 repo가 hexa-lang으로 넘긴 gap·request를 추적하고 해소

(현재 상태만 기록 — 열린 handoff는 `- [ ]` 로, 처리 이력은 `INBOX.log.md` 로)

- [x] **hexa cloud pod 생성(provision) verb 부재** (from: demiurge RTSC) — 수신·라우팅 완료 (g48): **기 추적 갭**(신규 아님). provisioning verb = `archive/patches/archive/hexa-cloud-preflight-stub-and-provisioning-gap` gap#2 (→ RFC 088 P-series) · DFT/HPC preflight = **RFC 091**. RTSC SrAuH₃를 RFC 091 witness로 보강 권고. 상세 → `INBOX.log.md`
- [ ] **codegen: cross-scope const-fold collision (silent wrong-answer) ⚠** (from: anima MODERNIZE M6) — 서로 다른 함수의 **동명 immutable `let`** 바인딩이 const-fold 시 충돌. 한 함수의 `let m = 2147483648`이 다른 함수의 `let m = h * 2.0`로 접혀 `compute(5.0)` → **2147483648** (기대 `10.0`). 빌드 에러가 아닌 **silent 오답** → 더 위험. minimal repro + 부수 진단갭(immutable `let` 재대입이 clear error 대신 `0=0+1` invalid C 생성) + anima M6 13-file deferral 목록(missing builtin · runtime.h staleness · parse feature) → `INBOX.log.md`

> 참고: hexa-lang 내부 upstream-patch staging `inbox/` 폴더는 폐기됐다(rehome → `archive/patches/` · `archive/fires/` · `docs/notes/` · `docs/rfc/`). upstream 변경은 일반 PR 워크플로로 흐른다. 이 INBOX 도메인은 다른 repo 가 넘긴 cross-repo handoff 전용으로 별개 시스템이며 그대로 유지된다.
