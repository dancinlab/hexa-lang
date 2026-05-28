# CLOUD — current state
@title: 🛰️ CLOUD — 원격 GPU 안전망

@goal: hexa cloud 개선 — M5 사망 패턴 재발 방지: bounded SSH-readiness gate · pod TTL deadman · cost cap · orphan reaper · agent-crash-safe pod registry

(edit me — describe current state in completed-form; no history, no changelog inside this file)
- [ ] M1 — `cloud rent --max-wait-sec <N>` bounded SSH-readiness gate (default 180s); timeout → auto-teardown + non-zero exit + 명시 verdict ("SSH never ready, pod destroyed")
- [x] M2 — pod TTL deadman: `cloud rent --ttl 30m` starts a background watchdog that force-terminates the pod when wall exceeds · agent-crash-safe
- [ ] M3 — cost cap watchdog: `cloud rent --max-cost-usd 5` polls cumulative spend every 5min · cap 도달 = auto-teardown + verdict log
- [ ] M4 — `cloud rm <id>` canonical teardown verb · 현 down/destroy/forget 흩어진 surface 통합 · --force gate · RunPod + vast 둘 다 지원
- [ ] M5 — agent-crash-safe pod registry: `~/.hx/cloud/active-pods.json` single SSOT · 모든 rent/rm 이 atomic update · 외부 reader 만으로 정리 가능
- [ ] M6 — `cloud reap` orphan finder · provider 에 alive 인데 registry 에 없는 pod 자동 발견 + teardown 제안 · bare = dry-run · --apply = 실행
- [ ] M7 — RunPod API key auto-bootstrap: 모든 cloud verb 가 `secret get runpod.api_key` 자동 lookup + env passthrough · 401 발생시 명시 hint · pool-route bypass
