# ATLAS — log

Append-only step log for the theorem-atlas upgrade campaign. Newest on top.

## 2026-05-25 — R5 active-acquisition 랭킹 (Q / 🟡 / 🟠 프론티어 우선순위)

audit 축은 코퍼스를 **측정**만 했다. R5는 그 측정을 **우선순위 to-acquire 리스트**로 전환 —
동결-but-미검증/open 노드 중 "다음에 검증/획득할 최고가치 타깃"을 랭킹. 순수 read-only
(노드 무변경 · fold 없음). `compiler/atlas/audit.hexa` 소유 라운드.

**verdict-tier 매핑 (ATLAS.md 모델)**:
- 🟠 INSUFFICIENT — cite-bearing kind(F/L/P/R) · 인용증거 無(`cite=`/`|>`) · 검증등급[*] 無.
  가장 깊은 갭: provenance도 재계산도 없는 공식 주장.
- 🟡 CITATION-ONLY — cite-bearing & 인용有 but [*]-미검증. 등록됐으나 재계산 안 됨.
- Q OPEN-QUESTION — kind "Q" open question (discovery 프론티어).
- verified[*](🔵/🟢)는 프론티어 아님 → 제외.

**defensible composite priority** = tier_weight + domain_gap_weight + kind_weight:
- tier: 🟠=300 🟡=200 Q=100 (깊은 갭 우선). domain_gap: clamp(60-domain_size,0,60) —
  sparse 도메인(#958 coverage 축 활용) 우선 = 거기 획득이 under-covered 도메인을 더 움직임.
  kind: F=8 L=6 P=4 R=2 Q=0. 동률은 id-순(오래된=foundational 우선).

**구현(additive·minimal)**:
- [x] compiler/atlas/audit.hexa — `AcqItem`/`AcqReport` struct + `audit_acquisition_with_scope`
  (2패스: 도메인 sibling-count → 프론티어 아이템+priority, selection-sort desc, top_k slice) +
  `audit_acquisition_overlay` + `acquisition_to_text`/`acquisition_to_json`. 기존 헬퍼
  (`_kind_is_cite_bearing`/`_node_has_cite`/`_extract_domain`/`_bucket_bump`) 재사용.
- [x] compiler/atlas/audit_rodata.hexa — `audit_acquisition_rodata`/`_merged` rodata-aware 래퍼
  (`audit_rodata`/`_merged` 패턴 미러).
- [x] tool/atlas_cli.hexa — `cmd_stats`에 `--acquisition`/`--top=N` 플래그 + 1-블록 dispatch
  (`--audit` 분기 前 early-return, 기존 경로 무회귀) + help 2줄. (sibling R5가 같은 파일
  소유 → rebase 시 KEEP BOTH 예상).

**검증**: parse-gate 3파일 OK. bin/hexa-atlas 빌드 PASS(borrowed transpiler ·
`SIDECAR_NO_POOL_ROUTE=1` · HEXA_MODULE_LOADER 명시). 기능 실측(rodata):
- 프론티어 2152 = 🟠 1709 + 🟡 360 + Q 83 (서브카운트 합 = frontier_count ✓).
- 불변식: 🟡(360) ⊆ cite_present(458) · 🟠(1709) ⊆ cite_missing(8194) ·
  verified F/L/P/R 6583 정확히 제외 · priority 단조감소(sort 정합) · JSON well-formed.
- overlay scope = 0 clean-degrade · default=merged · `--audit`/plain stats 무회귀.
- top-1 = 🟠 F:L6-genetics-mutation-rate p=367 dom=genetics_applied(1) — sparse-domain
  미검증 공식이 정확히 최상위로 surface.

후속(이월): domain×tier 매트릭스 · 프론티어 → drill seed 자동 공급 (acquire 루프 클로즈).

## 2026-05-25 — R4 calc_dispatch SSOT (verify↔atlas float 미러 단일화 · META-SIGNAL ①)

float-recompute 미러 이중화가 drift 뿌리(R3 reverify 3노드 drift · wigner #957 동일 클래스).
조사 결과 이중화는 3층: (1) per-fn 계산 helper(`_welch_t_crit` vs `_welch_t_crit_register`, 79쌍
byte-동일), (2) dispatch 테이블(`_recompute_float` vs `_recompute_float_register`), (3) 멤버십 술어
+ε(`_is_float_fn`/`_is_zero_arg_float_fn`/`_VERIFY_EPS` vs `_register` 짝). R3 실측 갭 = verify 99-fn,
atlas-register 63-fn(36-fn subset drift) + zero-arg 8 vs 7 + atlas 코드주석에 "Extend this table
whenever verify_cli's float table grows"(수동-동기 = drift 근원) 명시.

핵심 발견: atlas register `--from-verify`는 이미 `hexa verify --expr` shell-out 위임(@D g20)
이라 register-side 미러(`_recompute_float_register`·`_is_float_fn_register`·`_adapt_verify_*`)는
**dead-code**(코드주석이 직접 "uncalled · safe to delete" 명시). 유일한 live 소비자 = `cmd_reverify`
(`_is_float_fn_register` 2364 + `_recompute_float_register` 2379).

랜딩 슬라이스(PURE·helper-비의존·byte-identical): 멤버십 술어 + ε만 SSOT로.

- [x] compiler/atlas/calc_dispatch.hexa (신규 131줄) — `pub calc_eps()`(1e-9) ·
  `pub calc_is_float_fn`(canonical 99-fn) · `pub calc_is_zero_arg_float_fn`(8-fn). canonical = verify 테이블.
- [x] verify_cli.hexa — `use calc_dispatch` + 호출부 3곳 repoint(`calc_is_float_fn`·`calc_is_zero_arg_float_fn`·
  `calc_eps`) + 로컬 `_is_float_fn`/`_is_zero_arg_float_fn`/`_VERIFY_EPS` 제거(WIPE-OK · 동작 불변=동일 테이블).
- [x] atlas_cli.hexa — `use calc_dispatch` + reverify 2곳 repoint(`calc_is_float_fn`·`calc_eps`) +
  dead `_is_float_fn_register`/`_is_zero_arg_float_fn_register`/`_VERIFY_EPS_REGISTER` 제거(WIPE-OK).
  reverify 술어가 63→99로 확장되지만 atlas의 어떤 numerical F-노드도 36-fn 갭 fn을 안 씀 → 카운트 불변.
- LINK GATE(핵심 위험): 양 바이너리 빌드 PASS — bin/hexa-atlas(42s) + bin/hexa-verify(6s). 공유 모듈
  dual-`use` 링크 정상(두 CLI 모두 이미 4+ 모듈 multi-use라 저위험 입증).
- 검증: reverify byte-identical(`numerical_seen=36 match=32 drift=3 unverifiable=1` · 동일 3 DRIFT 노드
  allen_dynes_tc/mcmillan_tc/bcs_gap_ratio 동일 Δ) · verify --expr byte-identical(0/1/2/4-arg + zero-arg
  routing transition_factor_1s2s=0.75 PASS) · register --from-verify 정상(falsified→refuse, embed 불변).
- 잔여(deferred): recompute-helper 풀 이동(~99 per-fn helper ~2200줄)은 g4 200-LOC·link-risk로 별도 PR.
  register-side 미러는 dead-code라 무해 · reverify만 local subset recompute 유지(거기서 갭 fn은
  NOCALC→UNVERIF로 안전 degrade, 현재 노드 셋엔 해당 없음).

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
