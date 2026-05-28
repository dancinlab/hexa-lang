# CLOUD — log

Append-only history sister of `CLOUD.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-29 — M8-M11 추가 (INBOX 글로벌 SSOT 트랙 흡수)

- [x] M8-M11 milestone 4개를 CLOUD.md 에 추가 — sidecar INBOX.log.md 2026-05-29 entry ("pods.json + PROVIDERS.json 글로벌 SSOT 통합 디자인 트랙") 의 (a)~(e) 구현 제안을 도메인 milestone 으로 흡수. 두 트랙 (CLOUD 안전망 M1-M7 + INBOX 자원/manifest SSOT) 이 상호보완이라 한 도메인 SSOT 로 합침 (DOMAIN.md = canonical).
- [x] 경로 결정 — 모든 cloud state 를 `~/.hx/cloud/` 디렉토리로 통일: `active-pods.json` (M5 작업 상태 manifest) · `pods.jsonl` (청구 장부, 현 `~/.hexa-cloud/pods.jsonl` 에서 이관) · `providers.json` (M8 자원 카탈로그). INBOX 의 초기 제안 (`~/.hexa-cloud/manifest.json`) 은 M5 가 박은 `active-pods.json` 으로 폐기.
- [x] 출처 — demiurge `PROVIDERS.json` (PR #488/#489 · RTSC compute services registry · 4-tier providers + walltime_optimizations + integration_status) 패턴이 M8 의 schema 원본. demiurge `pods.temp.json` (sidecar INBOX #193 origin) 이 작업 상태 manifest 의 실사용 reference.
- [x] 동반 — sidecar commons 0.12.0 (`_pods_snapshot()`) + pods-route 0.1.0 (`--register` auto-inject) 이 이미 ship 됨 (2026-05-28 · cwd `./pods.json` 기반). M10 에서 `~/.hx/cloud/active-pods.json` 로 전환 정합 예정.
- [ ] 우선순위 = M5 (SSOT) → M10 (sidecar 정합) → M1/M2/M3 (안전망) → M8/M9 (카탈로그) → M11 (정리).

