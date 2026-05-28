# CLOUD — log

Append-only history sister of `CLOUD.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-29 — M-list 실제 상태 정정 (M1/M4/M5/M6/M7 기구현 · M10 ✅ · M8/M9 PR #1970)

- [x] CLOUD.md 체크박스 stale 정정 — 도메인 신설 시 all-`[ ]` 였으나 origin/main 코드 스캔 결과 **M1·M4·M5·M6·M7 이미 구현됨** 확인: M1=`--max-wait-sec` SSH-gate · M4=`_cloud_rm` canonical (down/destroy alias) · M5=`pod_registry.hexa` `_m5_*` (`~/.hx/cloud/active-pods.json`) · M6=`reap` verb · M7=`must_have_api_key`.
- [x] M10 ✅ 완료 — sidecar commons 0.13.0 (commit 2bba720): `_pods_snapshot()` 를 M5 글로벌 registry `~/.hx/cloud/active-pods.json` 로 전환 (cwd-independent · cost-bearing · `<id>[<provider>,<status>]`+`$<cost>`) + `_providers_snapshot()` 신설. smoke 통과 (pool+pods+providers 3 snapshot). pods-route `--register` 는 per-project ./pods.json 작업뷰로 별 축 유지.
- [ ] M8/M9 🟡 PR #1970 (draft · CI build verify 대기) — `providers_catalog.hexa` + `cloud providers [list|fit|recommend]`. hexat codegen 통과 · full AOT link 는 CI 확정. `~/.hx/cloud/providers.json` seed = demiurge PROVIDERS.json (27 providers · 4-tier).
- [ ] M2/M3 ⏳ 미구현 — TTL deadman + cost-cap watchdog. active-pods.json 필드(ttl_sec·max_cost_usd·cumulative_cost_usd) 준비됨 · watchdog 종료 로직 정확성(올바른 pod·시점)은 live-pod 검증 필요 (blast-radius: 오종료) → 별도 세션 + pod 비용 승인.
- [ ] M11 ⏳ M8(#1970) 머지 후 — 글로벌 providers.json canonical 화 선행.

## 2026-05-29 — M8-M11 추가 (INBOX 글로벌 SSOT 트랙 흡수)

- [x] M8-M11 milestone 4개를 CLOUD.md 에 추가 — sidecar INBOX.log.md 2026-05-29 entry ("pods.json + PROVIDERS.json 글로벌 SSOT 통합 디자인 트랙") 의 (a)~(e) 구현 제안을 도메인 milestone 으로 흡수. 두 트랙 (CLOUD 안전망 M1-M7 + INBOX 자원/manifest SSOT) 이 상호보완이라 한 도메인 SSOT 로 합침 (DOMAIN.md = canonical).
- [x] 경로 결정 — 모든 cloud state 를 `~/.hx/cloud/` 디렉토리로 통일: `active-pods.json` (M5 작업 상태 manifest) · `pods.jsonl` (청구 장부, 현 `~/.hexa-cloud/pods.jsonl` 에서 이관) · `providers.json` (M8 자원 카탈로그). INBOX 의 초기 제안 (`~/.hexa-cloud/manifest.json`) 은 M5 가 박은 `active-pods.json` 으로 폐기.
- [x] 출처 — demiurge `PROVIDERS.json` (PR #488/#489 · RTSC compute services registry · 4-tier providers + walltime_optimizations + integration_status) 패턴이 M8 의 schema 원본. demiurge `pods.temp.json` (sidecar INBOX #193 origin) 이 작업 상태 manifest 의 실사용 reference.
- [x] 동반 — sidecar commons 0.12.0 (`_pods_snapshot()`) + pods-route 0.1.0 (`--register` auto-inject) 이 이미 ship 됨 (2026-05-28 · cwd `./pods.json` 기반). M10 에서 `~/.hx/cloud/active-pods.json` 로 전환 정합 예정.
- [ ] 우선순위 = M5 (SSOT) → M10 (sidecar 정합) → M1/M2/M3 (안전망) → M8/M9 (카탈로그) → M11 (정리).


## 2026-05-29 — M8/M9 MERGED (PR #1970 · full-build verified)

- [x] M8/M9 ✅ MERGED — `providers_catalog.hexa` + `cloud providers [list|fit|recommend]` verb. full Mac build (module_loader → hexat → clang link → smoke) + 기능 검증 (`cloud providers list` 4-tier 렌더 · `recommend` 캠페인) 통과 후 admin-merge. CI red 는 B9/F3 transient(`runtime_core.c` untracked)이라 sign-local 로컬 full-build proof 로 우회. → M* 9/11 (M1·M4·M5·M6·M7·M8·M9·M10 ✅).
- [ ] M11 unblocked (M8 머지 완료) — demiurge pods.temp.json archive + PROVIDERS.json superset 정합 가능 (단 live RTSC 캠페인 데이터라 migration 은 사용자 awareness 필요).
- [ ] M2/M3 잔여 — TTL/cost-cap watchdog · pod-kill 정확성 = live-pod 테스트 비용 승인 필요.

## 2026-05-29 — M2/M3 ✅ 완결 (live-verified) + M11 PROVIDERS superset note

- [x] M2 (TTL deadman) ✅ — PR #1983·#1988·#1990. 실 vast pod LIVE 검증 (rent --ttl 90s → watchdog 가 TTL 110s≥90s 감지 → teardown → 과금중단; podA1·미등록 pod 무시 = opt-in 불변식). async teardown false-negative robustness `_sweep_confirm_gone` (#1990).
- [x] M3 (cost-cap) ✅ — PR #1983·#1991·#1994. registry max_cost_usd+cost_per_hr_usd 저장 · sweep derived cumulative(rate×elapsed, float-free) ≥ cap → teardown. vast dph + runpod costPerHr 양쪽 rate 포착. dry-run cost-breach 검증.
- [x] M11 PROVIDERS.json superset 정합 ✅ — demiurge PR #500 (_meta.global_ssot → 글로벌 M8 ~/.hx/cloud/providers.json).
- [ ] M11 잔여 — PROVIDERS.json + pods.temp.json 완전 폐기 abolition 프롬프트 준비됨. pods.temp.json 은 rich+stale 라 캡처-후-폐기 권장 (사용자 confirm 대기).
- M* 현황: M1-M10 ✅ · M3 functional(vast+runpod) · M11 = superset note done, 완전폐기 pending.
