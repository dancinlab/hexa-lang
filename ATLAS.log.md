# ATLAS — log

Append-only step log for the theorem-atlas upgrade campaign. Newest on top.

## 2026-05-25 — R3 lookup on-disk offset 색인

단일 `hexa atlas lookup <id>`가 16101-노드 전체를 파싱(unescape+grade+edge)한 뒤 1개 노드만
반환하던 비효율 해소. #950 프로세스-캐시는 같은 프로세스의 2번째 쿼리만 도왔지만 lookup은
one-shot subcommand라 캐시 효과 0이었음.

- [x] compiler/atlas/offset_index.hexa (신규) — embed 1패스 스캔으로 (kind,id)→물리줄+n6-stream
  source_line 인메모리 색인 빌드(줄당 substring 추출만; raw unescape/grade/edge 파싱 skip).
  lookup 시 해당 1줄만 seek → 그 노드 raw만 `parse_atlas_string` → full-parse와 byte-identical
  결과. 프로세스-수명 캐시(#950 패턴 미러, resolved-path 키).
- [x] static_index.hexa `lookup_static`/`atlas_lookup`에 fast-path 와이어 + 폴백 — hit은 즉시 반환,
  HEALTHY-index miss는 definitive(풀파싱 안 함, 9-kind CLI 루프에서 8개 non-match가 풀파싱
  트리거하던 버그 차단), UNHEALTHY-index(empty/read-fail/staleness)만 canonical 풀파싱 폴백.
- 검증: BASE(HEAD) vs NEW 바이너리 byte-identical — 47-id 풀코퍼스 샘플(P→Q 전 kind) PASS,
  explicit-kind 5/5, wrong-kind miss·prefix·unhealthy-fallback OK. 가속: 풀파싱 0.54s → 색인
  0.14s user (5-run, ~3.9x). deep-node(sm_blackwell)도 0.13s — 위치 무관 상수 비용.
- SSOT 불변(embedded.gen.hexa) · commit-time artifact 없음 · fold-path 미변경 (순수 derived accelerator).

## 2026-05-25 — R1 fan-out 착지 (cycle-full)

`/gap full` 40-렌즈 스윕 → 8패밀리 갭 리포트 → 5-way 병렬 fan-out. 4/5 머지, 1 블록.

- [x] #948 register fold dedup(kind,id)+atomic write (embed_fold.hexa + atlas_cli.hexa)
- [x] #945 cite_missing_count audit metric — 8194 미인용 / 456 인용 (audit.hexa)
- [x] #946 atlas-consistency CI (.github/workflows/atlas-consistency.yml)
- [x] #950 static_atlas() process-cache — 파싱 9→1/proc (static_index.hexa)
- [ ] C5 drill novelty-fixpoint — 수정 작성(yields.total→overlay_lines_emitted)·parse-clean이나 `--rounds≥2` SIGSEGV(선재 의심)로 검증 막힘 → R2 이월

선행 작업: #935 RTSC supercon 13노드(10 verified @F + 3 measured-Tc @E), atlas 16088→16101.

발견: drill `--rounds≥2` SIGSEGV(seed-pool smash 경로 선재 의심) · pool-route 훅이 agent worktree에서 `hexa build` 거부.
