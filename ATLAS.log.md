# ATLAS — log

Append-only step log for the theorem-atlas upgrade campaign. Newest on top.

## 2026-05-25 — R1 fan-out 착지 (cycle-full)

`/gap full` 40-렌즈 스윕 → 8패밀리 갭 리포트 → 5-way 병렬 fan-out. 4/5 머지, 1 블록.

- [x] #948 register fold dedup(kind,id)+atomic write (embed_fold.hexa + atlas_cli.hexa)
- [x] #945 cite_missing_count audit metric — 8194 미인용 / 456 인용 (audit.hexa)
- [x] #946 atlas-consistency CI (.github/workflows/atlas-consistency.yml)
- [x] #950 static_atlas() process-cache — 파싱 9→1/proc (static_index.hexa)
- [ ] C5 drill novelty-fixpoint — 수정 작성(yields.total→overlay_lines_emitted)·parse-clean이나 `--rounds≥2` SIGSEGV(선재 의심)로 검증 막힘 → R2 이월

선행 작업: #935 RTSC supercon 13노드(10 verified @F + 3 measured-Tc @E), atlas 16088→16101.

발견: drill `--rounds≥2` SIGSEGV(seed-pool smash 경로 선재 의심) · pool-route 훅이 agent worktree에서 `hexa build` 거부.
