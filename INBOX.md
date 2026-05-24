# INBOX — current state

@goal: cross-project handoff 수신함 — 다른 repo가 hexa-lang으로 넘긴 gap·request를 추적하고 해소

(현재 상태만 기록 — 열린 handoff는 `- [ ]` 로, 처리 이력은 `INBOX.log.md` 로)

- [x] **hexa cloud pod 생성(provision) verb 부재** (from: demiurge RTSC) — 수신·라우팅 완료 (g48): **기 추적 갭**(신규 아님). provisioning verb = `archive/patches/archive/hexa-cloud-preflight-stub-and-provisioning-gap` gap#2 (→ RFC 088 P-series) · DFT/HPC preflight = **RFC 091**. RTSC SrAuH₃를 RFC 091 witness로 보강 권고. 상세 → `INBOX.log.md`
- [ ] **stdlib 2건 (combined): FFT O(n²·log n) per-frame + 3+ module 동시 import silent-exit** (from: anima STDLIB sweep 2026-05-25) — (1) `stdlib/signal/core_fft.hexa::fft_native` butterfly 가 trippe-apply 마다 O(n) immutable list rebuild 수행 → single-FFT O(n²·log n), STFT-frame O(frames · n²·log n) · griffin-lim downstream 측정에서 n_fft=32 cap 강제(paper-grade 512–1024 불가). (2) `import` 3+ stdlib 모듈 동시 사용 시 toolchain silent-exit — `synth_probe.hexa` header 가 명시적으로 "Self-contained — NO cross-file imports" 라벨, stdlib refactor 차단. 상세 → `INBOX.log.md`

> 참고: hexa-lang 내부 upstream-patch staging `inbox/` 폴더는 폐기됐다(rehome → `archive/patches/` · `archive/fires/` · `docs/notes/` · `docs/rfc/`). upstream 변경은 일반 PR 워크플로로 흐른다. 이 INBOX 도메인은 다른 repo 가 넘긴 cross-repo handoff 전용으로 별개 시스템이며 그대로 유지된다.
