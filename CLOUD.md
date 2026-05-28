# CLOUD — current state
@title: 🛰️ CLOUD — 원격 GPU 안전망

@goal: hexa cloud 개선 — M5 사망 패턴 재발 방지: bounded SSH-readiness gate · pod TTL deadman · cost cap · orphan reaper · agent-crash-safe pod registry · 자원 카탈로그 SSOT (M8-M11, INBOX 글로벌 SSOT 트랙 흡수 2026-05-29)

canonical state 디렉토리 = `~/.hx/cloud/` (모든 cloud state 한 곳):
  · `active-pods.json` — 작업 상태 manifest (M5 · update-form work view)
  · `pods.jsonl`       — 청구 장부 (append-only billing · 현 `~/.hexa-cloud/pods.jsonl` 에서 이관)
  · `providers.json`   — 자원 카탈로그 (M8 · demiurge PROVIDERS.json 패턴 흡수)

(edit me — describe current state in completed-form; no history, no changelog inside this file)
- [x] M1 — `cloud rent --max-wait-sec <N>` bounded SSH-readiness gate (default 180s); timeout → auto-teardown + non-zero exit + 명시 verdict ("SSH never ready, pod destroyed")
- [ ] M2 — pod TTL deadman: `cloud rent --ttl 30m` starts a background watchdog that force-terminates the pod when wall exceeds · agent-crash-safe  ⏳ active-pods.json 에 `ttl_sec` 필드 준비됨 · watchdog 로직 미구현 · 정확성(올바른 pod·정확 시점 종료) = live-pod 검증 필요
- [ ] M3 — cost cap watchdog: `cloud rent --max-cost-usd 5` polls cumulative spend every 5min · cap 도달 = auto-teardown + verdict log  ⏳ active-pods.json 에 `max_cost_usd`·`cumulative_cost_usd` 필드 준비됨 · poll/teardown 로직 미구현 · live-pod 검증 필요
- [x] M4 — `cloud rm <id>` canonical teardown verb · 현 down/destroy/forget 흩어진 surface 통합 · --force gate · RunPod + vast 둘 다 지원  (`_cloud_rm` · down/destroy = legacy alias)
- [x] M5 — agent-crash-safe pod registry: `~/.hx/cloud/active-pods.json` single SSOT · 모든 rent/rm 이 atomic update · 외부 reader 만으로 정리 가능  (`pod_registry.hexa` `_m5_*`)
- [x] M6 — `cloud reap` orphan finder · provider 에 alive 인데 registry 에 없는 pod 자동 발견 + teardown 제안 · bare = dry-run · --apply = 실행
- [x] M7 — RunPod API key auto-bootstrap: 모든 cloud verb 가 `secret get runpod.api_key` 자동 lookup + env passthrough · 401 발생시 명시 hint · pool-route bypass  (`must_have_api_key`)
- [x] M8 — 자원 카탈로그 SSOT `~/.hx/cloud/providers.json` 신설 · demiurge `PROVIDERS.json` 4-tier 패턴 흡수 (vast_alternatives_cpu · hpc_tier_walltime_killers · gpu_accelerated_dft · academic_free) + walltime_optimizations + hexa_cloud_integration_status · 항목 메타 cost_usd_per_hr · walltime_speedup · fit_score (1-3) · highlight · notes  ✅ PR #1970 MERGED · `providers_catalog.hexa` · full Mac build + 기능 검증 (CI 인프라-깨짐 우회 admin · sign-local 로컬 full-build proof)
- [x] M9 — `cloud providers [list|fit|recommend]` verb (read-only initial) · list = 전체 카탈로그 · fit = fit_score=3 · recommend = 캠페인 추천  ✅ PR #1970 MERGED · 4-tier 렌더 검증 완료
- [x] M10 — sidecar hook 정합: commons `_pods_snapshot()` 가 `~/.hx/cloud/active-pods.json` 를 읽도록 (현 cwd `./pods.json` 기반에서 전환) · commons `_providers_snapshot()` 신설 (M8 providers.json 한 줄 inject)  ✅ sidecar commons 0.13.0 (commit 2bba720) · pods-route `--register` 는 per-project ./pods.json 작업뷰 유지 (M5 글로벌 registry 와 별 축)
- [ ] M11 — demiurge 정리: `pods.temp.json` 은 글로벌 manifest 흡수 후 archive · demiurge `PROVIDERS.json` 은 `~/.hx/cloud/providers.json` 의 캠페인 특화 superset 으로 정합 (RTSC 특화 추천표 유지, 공용 카탈로그는 글로벌 SSOT 참조)  ⏳ M8 (#1970) 머지 후 — 글로벌 providers.json canonical 화 선행
