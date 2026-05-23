# HEXA_LANG — log

Append-only history sister of `HEXA_LANG.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-24 — cloud(diag) verb 3-layer stack 랜딩

inbox/patches/hexa-cloud-pod-status-diagnose-verbs.md (anima 2026-05-24 R8a incident) closure.
`hexa cloud` 에 pod 상태 진단 verb 5개 추가 — 모두 read-only, runpodctl-backed.

- [x] L1 (PR #612) — `cloud list` + `cloud status` · `RunPodPodInfo` + `runpod_list_detailed` + `runpod_pod_info` + `runpod_parse_owner_tag`
- [x] L2 (PR #614) — `cloud orphans` + `cloud owner-tag` · name suffix `<base>::owner=<tag>` 컨벤션 활용
- [x] L3 — `cloud diag <host> [--pid N] [--log path]` · nvidia-smi + ps + tail 한방 (각 섹션 1 ssh 트립, structured-argv 유지)
- [ ] follow-up: anima dispatch_p21h_v3.hexa 가 fire 시 pod name 에 `::owner=` suffix 자동 부착 (anima 측 patch)
- [ ] follow-up: live e2e smoke against real RunPod pod (3 orphan + 2 tagged 환경)

