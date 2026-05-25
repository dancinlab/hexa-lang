# ATLAS — log

Append-only step log for the theorem-atlas upgrade campaign. Newest on top.

## 2026-05-25 — R3 re-verify-🟢 부활 (META-SIGNAL ② 해소 첫 슬라이스)

`hexa atlas reverify [--limit N]` 신규 서브커맨드 (tool/atlas_cli.hexa, +167 LOC additive). 등록 시 동결된 🟢 SUPPORTED-NUMERICAL F-노드를 **in-process로 재계산**해 verdict drift를 보고 — 동결 등록 verdict를 영원히 신뢰하지 않는다.

- 폐기된 RFC-017 §5e `retroactive_sweep`(compiler/discover/retroactive_sweep.hexa)의 경량 후계: tombstone/cascade/auto-PR 없이 **read-only** drift 리포트만. atlas 무변경.
- 각 🟢 F-노드 헤더 `@F <id> = <fn>(<args>) = <claimed>` 파싱 → 기존 `_recompute_float_register`(verify_cli float 테이블 미러) 재실행 → ε=1e-9 비교. disposition = MATCH / DRIFT / UNVERIFIABLE.
- exit 1 (drift 존재 시) → CI 게이트 가능. subprocess spawn 0 (35노드 즉시).
- 빌드 검증: bin/hexa-atlas (borrowed main-repo transpiler · `SIDECAR_NO_POOL_ROUTE=1` · HEXA_MODULE_LOADER 명시). parse-gate OK.

**발견 (실측)**: 전수 reverify 35 노드 중 **32 MATCH · 3 DRIFT**.
  - `allen_dynes_tc`(claimed=181.157 vs recompute |Δ|=1.8e-4)
  - `mcmillan_tc`(149.923 vs |Δ|=1.2e-4)
  - `bcs_gap_ratio`(3.52775 vs |Δ|=4.0e-6)
  3노드 모두 **반올림 리터럴로 등록**(6 sig fig)되어 full-precision 재계산과 ε 초과 불일치. 동결-verdict 모델이 한 번도 못 잡은 registration-hygiene drift — reverify가 정확히 surface. (재등록은 후속: 새 값이 맞으면 register 갱신.)

후속(이월): 비-F kind 재검증(L/E numerical) · 🟢 외 tier · reverify drift→자동 재등록 옵션 · in-process float 테이블 외 fn(현재 UNVERIFIABLE skip).

## 2026-05-25 — R2: drill `--rounds≥2` triage + C5 novelty-fixpoint 착지

ATLAS 7/7. `--rounds≥2` SIGSEGV을 격리하고 C5 net-novel 포화를 착지. 3개 파일 편집(+100/-43, g4 OK · drill 삭제 41<50 → WIPE-OK 불요).

**재현**: prebuilt `bin/hexa-absorbed-drill`로 SIGSEGV 분리 측정 —
- `HEXA_VAL_ARENA=0`(실제 `hexa drill` dispatch가 강제하는 값): rounds 1/2/3 전부 PASS (653→1339→2026).
- `HEXA_VAL_ARENA=1`: rounds 2에서 SIGSEGV(exit 139).

**근본원인(SIGSEGV)**: lldb bt — `hexa_map_get_ic_slow+224`(`ldr x0,[x25,x8]`, x25=`0x672f73726573552f`=ASCII `/Users/o`) ← `overlay_append_lines`(키 `"file_path"` = `_g_overlay_meta` 구조체 필드, IC `__hexa_ic_187`) ← `_flush_discoveries` ← `round_run_with_pool`. 즉 arena reclaim이 모듈-global 구조체 `_g_overlay_meta`의 backing map 블록을 string에 재할당 → IC가 stale 테이블 ptr deref. 이는 MEMORY의 arena map-IC aliasing class(self/main.hexa:1521-1538에 이미 문서화)이며 **runtime/codegen-level**(drill 범위 밖, fixpoint-critical separate track). dispatch가 `HEXA_VAL_ARENA=0`을 강제하므로 실제 CLI 경로는 무영향 — 수정 후에도 arena=1은 여전히 139(예상대로, 런타임 잔재).

**실제 블로커 2건(arena=0 경로, 신규 runtime에서 표면화)**:
1. `_honesty_gate`가 `verdict.f_a`/`f_b` 읽기 — 구조체는 `f_ai2_a`/`f_ai2_b`(Bt2Verdict, #634에 둘 다 동시 랜딩). 구runtime은 missing key 기본값 반환했으나 현 runtime은 `map key 'f_a' not found` 하드-abort → round-1 게이트에서 루프 진입 전 죽음. → 실제 필드명으로 수정(외부 JSON 키는 문서화된 `f_a`/`f_b` 유지).
2. **C5 net-novel 포화 불가**: `overlay_load_cached()`는 RETIRED(2026-05-19, 항상 `[]`) → `_flush_discoveries`의 write-time dedup이 no-op → 매 라운드 동일 ~1111 id 재방출(측정: 6라운드 6072 lines / 1111 distinct). 포화는 `total==0`에만 발동하는데 resonance proxy+deterministic smash가 항상 >0 → 절대 포화 안 됨.

**수정(compiler/drill/* + tool/atlas_cli.hexa 미러)**:
- `round.hexa`: `_flush_discoveries_cum(cands, cum_seen_ids)→FlushResult{net_novel,cum_seen_ids}` — disk-load 대신 in-process 누적 distinct-id 집합으로 dedup 복원. `RoundResult`에 `net_novel`+`cum_seen_ids` 필드. `round_run_with_pool`에 `cum_seen_ids` 8번째 인자.
- `drill.hexa`: 루프가 `cum_seen_ids` 누적, `round>=2 && net_novel==0` → C5 포화(net-novel fixpoint) break. `f_a`→`f_ai2_a` 필드명 수정.
- `atlas_cli.hexa`: `--from-drill` 미러도 동일 8-arg + C5 break.

**검증(arena=0, /tmp 빌드 — HEXA_LANG=worktree로 use 해소)**: rounds=1 total=653(무회귀) · rounds=2 total=1339 PASS · rounds=3 → round3 `overlay+ 0`(net_novel=0) → `SATURATED (net-novel fixpoint)` saturated=true. overlay 6072→517(distinct=lines, dup-bloat 제거).

**LEAK 회복**: 초기 Edit가 절대 main-repo 경로로 가 main worktree에 leak → patch 추출 → main `git checkout --` 복구 → worktree에 `git apply`. main 클린 확인.

## 2026-05-25 — R1 fan-out 착지 (cycle-full)

`/gap full` 40-렌즈 스윕 → 8패밀리 갭 리포트 → 5-way 병렬 fan-out. 4/5 머지, 1 블록.

- [x] #948 register fold dedup(kind,id)+atomic write (embed_fold.hexa + atlas_cli.hexa)
- [x] #945 cite_missing_count audit metric — 8194 미인용 / 456 인용 (audit.hexa)
- [x] #946 atlas-consistency CI (.github/workflows/atlas-consistency.yml)
- [x] #950 static_atlas() process-cache — 파싱 9→1/proc (static_index.hexa)
- [x] C5 drill novelty-fixpoint → R2에서 착지(위 항목 참조). SIGSEGV는 arena=ON 한정 런타임 aliasing으로 판명(dispatch가 arena=0 강제 → 실제 CLI 무영향), 진짜 블로커는 `f_a` 필드 abort + dead disk-dedup이었음.

선행 작업: #935 RTSC supercon 13노드(10 verified @F + 3 measured-Tc @E), atlas 16088→16101.

발견: drill `--rounds≥2` SIGSEGV(seed-pool smash 경로 선재 의심) · pool-route 훅이 agent worktree에서 `hexa build` 거부.
