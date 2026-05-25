# ATLAS — log

Append-only step log for the theorem-atlas upgrade campaign. Newest on top.

## 2026-05-25 — R7 auto-edge 추론 (`hexa atlas infer-edges <id>` · read-only · 미선언 edge 제안)

goal(deferred 신규역량): "auto-edge 추론". 노드 edge(`<-`depends_on·`->`derives·`==`equivalents·
`|>`verified_by)가 현재 **수동**이라 R6 proof-chain(#1044)이 많은 UNRESOLVED leaf를 보고했다(선언 edge
sparse). auto-edge는 노드 raw를 스캔해 **이미 선언되지 않은 다른 노드 id 참조**를 찾아 후보 edge를
제안 — proof-chain + cascade를 enrich.

**조사**: 노드 모델 = `compiler/atlas/parser.hexa` `AtlasNode`(kind·id·raw·grade·`edges:EdgeInfo`).
id charset = `[A-Za-z0-9_-]`(예: `n`·`phi`·`J2`·`L0-quark-flavors`·`sigma_n`). "참조" = 노드 raw
(헤더 수식 OR 연속줄) 안에 다른 실제 atlas id가 **온전한 식별자 토큰**으로 등장. 예: `sigma`의 raw에
`== phi * n` — `phi`는 실노드이나 선언 edge엔 없음(R6가 UNRESOLVED leaf로 보고한 바로 그 케이스).
런타임 = `atlas_lookup_enriched(id)`(edge 백필) + `atlas_list()`(전노드 id-set).

**설계**: raw를 **maximal `[A-Za-z0-9_-]` run**으로 토큰화 — 이것이 **false-positive guard**다.
`divisor_sum(6)`는 단일 토큰 `divisor_sum`이 되어 id `n`이 끝 글자에 절대 매치 안 함; `phi_tau`가 id
`phi`에 매치 안 함(strict word-boundary, 부분문자열 노이즈 차단). 제안 조건: (a) 실 atlas 노드로
resolve, (b) 자기 id 아님(self-edge 無), (c) 어느 edge 버킷에도 미선언, (d) target dedup. 추측 kind=
`depends_on`(수식 참조 = 기반). evidence = 토큰이 처음 나온 trimmed raw 줄. **READ-ONLY** — 제안만,
embedded.gen.hexa에 fold 절대 안 함(proposal surface; user/다음 라운드가 apply).

**구현**: `compiler/atlas/auto_edge.hexa` 신설(`EdgeProposal{source,target,kind,evidence}` +
`infer_edges_for(node,id_set)` + `infer_edges(id)` + `infer_proposals_to_text/json`). 파서/static_index
재사용(파서 미복제). atlas_cli 1-블록(`use auto_edge` + `cmd_infer_edges` + dispatch + help, cascade·
proof·diff verb KEEP).

**검증**: `hexa parse` OK(auto_edge + atlas_cli) → fresh `build/hexa_module_loader`(worktree
`self/module_loader.hexa`) → `bin/hexa-atlas` LINK PASS(새 `infer_edges` 심볼 resolve) → 기능:
(1) `infer-edges sigma` → `phi`(`== phi * n`) + 6 meta-closure id(`sm_ampere`·`perfect_number`·…) 제안,
선언된 `n`·`sigma_sq`·`sigma_tau`·`sigma_n`은 정확히 제외 · (2) `infer-edges phi_tau`/`phi` → 0 제안
(모든 참조 선언됨/실-id 없음 — 정확 negative) · (3) `infer-edges L0-quark-flavors` → `n`(헤더 `= n`,
미선언) 1개(hyphenated id 올바른 토큰화) · (4) **false-positive guard**: 1글자 id `n`이 `divisor_sum`·
`derivations`·`number`에 leak 안 됨 확인 · (5) `--format=json` python `json.load` PASS · (6) unknown id
→ `# unknown id` + exit 1 / no-arg → usage exit 2. auto_edge.hexa 본문 g4 내 + atlas_cli 1-블록.
embedded.gen.hexa·cascade.hexa·proof_chain.hexa·audit.hexa 무수정.

## 2026-05-25 — R7 numerology 격리 tier (`hexa atlas stats --numerology` · read-only quarantine)

goal(deferred): "numerology 격리 tier". g5 honesty 루브릭은 실검증(🔵/🟢)과 미지지 주장을 구분한다.
NUMEROLOGY 노드 = 유도/인용 없이 무관 상수간 수치 우연일치(비율·등식)를 주장하는 노드. 엄밀 노드와
silent-mix되면 안 됨 → DETECT + ISOLATE해 가시적 quarantine. READ-ONLY(노드 mutate·grade 변경 無).

**조사**: 노드 모델 = `parser.hexa` `AtlasNode`(kind·id·raw·grade·edges). audit.hexa 기존 헬퍼
재사용 — `_kind_is_cite_bearing`·`_node_has_cite`(`cite =` substring OR `|>`verified_by)·
`_raw_has_verified`(raw `*]` 폴백)·`_extract_domain`(헤더 `:: <domain>` 토큰)·`_au_ltrim/rtrim`.
실데이터 마이닝(16101 노드): 진짜 numerology = `MILL-V3-T4-n6-numerical-coincidence`(12/5=σ(6)/sopfr(6)
post-hoc) + `MILL-PX-A3-ym-beta0`(σ(6)-sopfr(6)=12-5=7, COINCIDENCE_NOT_PROOF 자기태그). 둘 다 [7]·
무인용. 함정: `coincidence`/`post-hoc`/`수치일치` 키워드가 **반증/진단** 노드에도 등장(clay
falsifier "ticks=12 was COINCIDENCE"는 우연을 *반증* · MCSP "수치일치 패턴조차 없음"은 link *부정*).

**설계(보수적 4-신호 AND)**: false-positive 평판 비용 高 → 4개 모두 충족해야 flag. (1) 우연일치 SHAPE를
헤더 **CLAIM BODY**(`id = ` 분리자 strip 후)에 한정: `≈`·숫자 비율-등식(`/` `=` 좌측)·숫자 `=…=…`
체인. body 한정이 토론 `=>` 엣지의 우연 언급을 제외(그들은 우연을 반증) · (2) numerolog/coincidence/
수치일치/coincidence_not_proof 키워드(일반 유도공식 부재) · (3) 무검증([*] 아님) · (4) 무인용
(`_node_has_cite`). **핵심 false-positive 차단**: `id = ` 분리자를 strip하지 않으면 `@R …-non-applicability
= n=6 … 연결 없음`(정직한 link-DENIAL [10])의 `id =` + `n=6`이 `=…=…` 체인으로 오탐 → strip 후 정확히 제외.

- [x] compiler/atlas/audit.hexa (+`NumerologyReport`/`NumItem` struct · `_nu_has_coinc_keyword`·
  `_nu_header_line`·`_nu_claim_body`·`_nu_header_has_coincidence_shape`·`_nu_has_second_eq`·
  `_nu_has_digit`·`_nu_is_verified`·`_nu_is_numerology` · `audit_numerology_with_scope/_overlay` ·
  `numerology_to_text/_to_json`). 기존 audit/acquisition 코드 무수정 — 순수 additive.
- [x] compiler/atlas/audit_rodata.hexa (+`audit_numerology_rodata`·`audit_numerology_merged` 래퍼 2).
- [x] tool/atlas_cli.hexa (`--numerology` 플래그 + 1-블록 dispatch + help 1줄; audit·acquisition verb KEEP).
- [x] 검증: `hexa parse` 3파일 clean → bin/hexa-atlas 빌드(worktree module_loader fresh build) →
  `stats --numerology --scope=rodata` → **scanned 16101 · quarantine 정확히 2**(둘 다 진짜 우연일치·
  무유도·무인용 cross-check) · `--format=json` python json.load PASS · 기존 모드 회귀 0(plain stats·
  `--audit` entries 16101 · `--acquisition` 프론티어 2150 불변). false-positive 0(MCSP non-applicability·
  clay falsifier 모두 제외 실측). g4: 순 추가 ~198 LOC(<200).

## 2026-05-25 — R6 proof-chain export (`hexa atlas proof <id>` · read-only · cascade INVERSE)

goal(deferred 신규역량): "proof-chain export". 아틀라스 노드의 edge 그래프를 walk해 그 claim이
의존하는 노드의 transitive 집합(증거 기반)을 audit 가능한 체인/DAG로 export — @goal의 "증거" 축.

**조사**: 노드 모델 = `compiler/atlas/parser.hexa` `struct AtlasNode`(kind·id·raw·source_file·
source_line·grade·`edges`). `edges`=`EdgeInfo`(depends_on `<-`·derives `->`·applications `=>`·
equivalents `==`·converges `~>`·verified_by `|>`·breakthroughs `!!`). embedded.gen.hexa의 노드
리터럴은 edge가 **이미 파퓰레이트됨**(예: `sigma` = `depends_on: ["n"]`·`equivalents: ["1+2+3+6","phi * n"]`).
런타임 접근자 = `atlas_lookup_enriched(id)`(단일 노드, edge 백필) / sentinel `kind==""`(non-node).
R5 cascade.hexa(#1026/#1036)의 edge-traversal 패턴 미러 — 단 **방향 반전**.

**설계**: cascade("A falsified → 누가 A 인용?", 전노드 스캔 IN A)의 **dual** = proof("A는 무엇에
의존?", 노드에 저장된 SUPPORTING 엣지 OUT). SUPPORTING = `<-`depends_on(1차 기반)·`|>`verified_by
(검증 소스)·`==`equivalents(증명적 동치). `->`derives/`=>`applications/`~>`converges/`!!` = 다운스트림/
주석성이라 **미추적**(기반 아님). 전수 스캔 無 — depend 프론티어 따라 per-node lookup만.

- [x] compiler/atlas/proof_chain.hexa (신규 ~268줄 코드+주석; 코드본문 189줄 g4 내) —
  (1) `struct ProofLink {id,kind,grade_value,verified,via,parent,depth,resolved}` = 체인의 한 조상.
  (2) `proof_chain(root_id,max_depth)->ProofLink[]` = SUPPORTING 엣지 **BFS** + visited-set(cycle/
      diamond-safe) + depth-cap(-1=무제한·0=루트만·N=N홉). 각 홉이 parent id + 엣지 버킷 + depth 기록.
      노드 미해석 타깃(bare expr/스크립트)은 `resolved=false` UNRESOLVED leaf(crash 無, 더 안 확장).
  (3) `proof_bottoms_out(links)->bool` = 모든 leaf가 verified 실노드면 true(🔵/🟢 ground-out), 아니면
      🟡/🟠 gap. (4) `proof_to_text`/`proof_to_json`(verdict tier 🟢/🟡/🟠 포함, jq-valid).
- [x] tool/atlas_cli.hexa — `use compiler/atlas/proof_chain` + `cmd_proof` + main 1-블록 dispatch +
  `_slice_args` allowlist에 `proof` 추가 + help. **cascade verb KEEP-ALL**(sibling #1036 위에 rebase).
  `--depth=N`·`--depth N`·`--format=json`·`--json`·`--format=text` 파싱. unknown root → `# not a node`+exit 1.

**검증(ATLAS.md method)**: `hexa parse` 양파일 OK · bin/hexa-atlas 빌드 PASS(borrowed main-repo
transpiler hexa_v2→worktree build+self/native gitignored · `SIDECAR_NO_POOL_ROUTE=1` ·
`HEXA_MODULE_LOADER`=main build/hexa_module_loader · `HEXA_ATLAS_EMBED`=worktree compiler/atlas).
기능 테스트 실측:
  - WITH-edges `sigma` → `n`(via depends_on, 🟢 verified) · equiv `1+2+3+6`·`phi * n` = UNRESOLVED 🟠
  - leaf `n` → 자기 + `|> verify_primitives.py`(UNRESOLVED 스크립트 leaf)만(depends_on 無)
  - multi-hop transitive `probe_steps_cpgd` → `template_count`/`round_seed`(depth1) → `n_axis_cell`(depth2)
  - **diamond/cycle dedup**: `sigma_n`(←sigma,n)에서 sigma도 ←n → n이 2경로 도달하나 visited-set이
    정확히 **1회만** 방출(cycle/re-converge safe 입증)
  - `--depth=0`=루트 1노드(grounds-out yes) · `--depth=1`=직접 기반만 · `--format=json` jq `.chain|length` PASS
  - unknown id `zzz_not_a_node` → `# not a node (unresolved root)` + exit 1
  - cascade verb 동시 동작 확인(`cascade n`→26 노드, R5/R6 측정 일치) — KEEP-ALL
embedded.gen.hexa(데이터)·cascade.hexa·audit.hexa·calc_dispatch.hexa 무수정. proof_chain.hexa는
parser/static_index만 `use`(파서 중복 無).

## 2026-05-25 — R6 cascade CLI verb 노출 (`hexa atlas cascade <id>` · read-only)

R5 #1026이 라이브러리 surface(`compiler/atlas/cascade.hexa` — `cascade_candidates`/`cascade_candidates_static`/`cascade_to_text`/`node_falsifier`)만 랜딩하고 CLI verb는 dispatch가 당시 sibling 소유 `atlas_cli.hexa`라 DEFERRED했던 것을 이번 라운드에서 wire.

**조사**: cascade.hexa 공개 API = `cascade_candidates(falsified_id, nodes)` (enrich된 노드 배열 받아 `_scan_one`로 depends_on→verified_by→equivalents→derives edge 인용 first-hit 분류, self-cite 제외) + `cascade_candidates_static(id)` (atlas_list→atlas_enrich 자체 수행) + `cascade_to_text`. R5는 hexa 구조체 리터럴이 누락 필드 default 안 함(codegen `missing_field` 컴파일 에러)을 회피하려 스키마 변경 0 · `raw` 기반 구조화 accessor 채택.

**wire(atlas_cli.hexa, additive)**: (1) `use "compiler/atlas/cascade"`, (2) `_slice_args` 키워드 목록에 `cascade` 추가, (3) `cmd_cascade(rest)` — `<id>` + `--format=json`/`--format=text` 파싱; 정적 아틀라스를 `atlas_list`→`atlas_enrich` 1회만 enrich(edge 백필)하며 동일 패스에서 id 존재 확인 → `cascade_candidates(id, enriched)` 질의(static 래퍼 재사용 안 함 — 존재 확인과 enrich 중복 회피), (4) `main` dispatch 1-블록, (5) help 섹션. cascade.hexa 무수정.

**엣지케이스**: unknown id → `# unknown id: <id> (no such node in the atlas)` + exit 1 (json: `{"found":false,...}`) · 0-citer → `cascade: if <id> were FALSIFIED, no cascade candidates (0 nodes cite it).` · no-arg → usage + exit 2.

**검증**: `hexa parse tool/atlas_cli.hexa` 클린 · bin/hexa-atlas 재빌드 PASS (worktree self-built `build/hexa_module_loader`로 빌드 — stale main-repo 로더는 `acquisition_to_*`/`round_run_with_pool` 미해결로 실패 → worktree fresh 로더가 정답 · `SIDECAR_NO_POOL_ROUTE=1` · hyphenated 셸 우회). 기능: `cascade n`→**26 노드 인용**(R5 측정 일치, P/C/L/F/R/X 혼합) · `--format=json`→python `json.load` PASS(count=26, candidates len=26) · unknown id→exit 1 + 클린 메시지(json found=false) · 0-citer(`xpoll-n-material`·`six_carbon_consciousness`·`n6-bt-1392`)→"no cascade candidates" · no-arg→usage exit 2.

## 2026-05-25 — R6 신규역량 `hexa atlas diff <A> <B>` (atlas 판 git diff · READ-ONLY)

goal(deferred 신규역량): "atlas diff" — 두 atlas 상태를 비교해 added/removed/changed
노드를 리포트. 용도 = register/drill-fold가 무엇을 바꿨는지 리뷰 · embed↔n6-export 대조 ·
두 embed 파일 대조.

**조사**: read 경로 = `static_index.hexa::static_atlas`(embedded.gen.hexa를 TEXT-parse →
`_extract_raw_blocks`로 각 노드의 `raw: "..."` 블록을 .n6 스트림으로 추출 → `parser::
parse_atlas_string`). 노드 모델 = 단일 `AtlasNode{kind·id·raw·source_file·source_line·
grade·edges}`. 평문 `.n6` export(`hexa atlas export`)는 `parse_atlas_file`로 직접 파싱.
즉 두 소스 타입(embed vs 평문 n6)을 로드하는 두 경로가 이미 존재 — diff는 그 위에 keyed 비교만 얹음.

**설계**: `compiler/atlas/atlas_diff.hexa`(신규, 197 LOC) — `load_atlas_source(path)`가
`raw: "` 마커 유무로 embed/평문을 **자동 감지**(embed=추출 후 parse, 평문=직접 parse).
`diff_atlas(a,b)`는 (kind,id) 키로 비교: only-A=removed · only-B=added · both-but-raw-differs
=changed(raw가 header+grade+edge 전부 운반하므로 value/grade/edge 변경을 raw diff가 표면화) ·
identical=same(카운트). 출력 = `±~` 노드줄 + `removed N · added N · changed N · same N` 푸터;
`--format=json`은 버킷별 id 리스트 + counts. **파서 미복제** — 정규 `parse_atlas_string` +
`_extract_raw_blocks`(pub로 노출) 재사용.

**구현**: `compiler/atlas/atlas_diff.hexa`(신규) + `tool/atlas_cli.hexa`에 dispatch 1블록
(`cmd_diff` + `_slice_args`/`main`/help 배선) + `static_index.hexa::_extract_raw_blocks` pub화.

**검증**: parse-gate 3파일 OK → bin/hexa-atlas 빌드 PASS(borrowed main-repo transpiler ·
`SIDECAR_NO_POOL_ROUTE=1` · `HEXA_LANG`=worktree · hexa_v2/module_loader=main에서 gitignored
심링크). 기능: (1) **self-diff = 빈 diff** — A vs A-copy = `removed 0 · added 0 · changed 0 ·
same 3` ✓ · (2) **modified 감지** — A vs B(C alpha 값+grade 변경 · L conservation 제거 · F
energy 추가) = `removed 1(@L) · added 1(@F) · changed 1(@C) · same 1` 정확 ✓ · (3) embed
auto-detect — 실제 embedded.gen.hexa(16101 노드) vs 자기자신 = `0/0/0 · same 16101` ✓ ·
(4) JSON 출력 + usage-guard(exit 2) ✓ · (5) 회귀 stats/lookup/help 무영향 ✓.

## 2026-05-25 — R5 drift 보정 (rounded-literal 3노드 full-precision 재등록 · META-SIGNAL ②)

R3 reverify가 실측한 `numerical_seen=36 match=32 drift=3` 의 3 DRIFT 노드를 full-precision 재등록해 drift=0 클로즈. 등록 시 6 sig-fig 반올림 리터럴로 동결되어 in-process full-precision 재계산과 ε=1e-9 초과 불일치했던 registration-hygiene drift.

**재현(reverify)**: HEXA_ATLAS_EMBED=worktree compiler/atlas, bin/hexa-atlas(borrowed main-repo transpiler · `SIDECAR_NO_POOL_ROUTE=1` · `HEXA_MODULE_LOADER`=main build/hexa_module_loader · hexa_v2=main repo copy into worktree self/native, gitignored). `reverify` = 3 DRIFT 확정:
  - `verified-allen_dynes_tc-num` = allen_dynes_tc(2.5,1100.0,0.1): claimed=181.157 |Δ|=1.81689e-4
  - `verified-mcmillan_tc-num` = mcmillan_tc(2.5,1100.0,0.1): claimed=149.923 |Δ|=1.1588e-4
  - `verified-bcs_gap_ratio-num` = bcs_gap_ratio(): claimed=3.52775 |Δ|=3.97772e-6

**full-precision 값(IEEE-754 double, libm exp)**: 181.15681831111502 · 149.92288411954345 · 3.527753977724091. `hexa verify --expr <fn> <args> <v>` 로 사전 검증 — 3개 모두 `|Δ|=0.0 ≤ ε=1e-9 → 🟢 SUPPORTED-NUMERICAL`.

**REPLACE 보장**: register fold dedup(kind,id, #948)은 skip-on-dup(REPLACE 아님 — `embed_is_skip`). 따라서 동명 stale 노드 3개를 embedded.gen.hexa에서 먼저 삭제 후 `hexa atlas register --from-verify`(@D g20 `hexa verify --expr` shell-out 위임)로 fresh full-precision 노드 fold. 결과 = 각 ID 정확히 1회 출현 · 노드수 16101 불변(REPLACE, not ADD).

**검증**: `reverify` → `numerical_seen=35 match=35 drift=0 unverifiable=0`(R4 calc_dispatch가 float 테이블을 99-fn로 확장해 이전 1 UNVERIFIABLE도 흡수, 35 전수 MATCH) · `lookup` 3노드 full-precision 표시 확인 · bin/hexa-atlas 재빌드 PASS. SSOT(embedded.gen.hexa) diff는 data-only(3 노드 라인 교체 + 직전 노드 trailing comma) — 로직 무변경.

## 2026-05-25 — R5 falsifier 구조화 accessor + cascade 무효화 query (additive·read-only)

goal(deferred): "falsifier 구조화 필드 + cascade 무효화". 노드가 claim을 반증하는 조건
(falsifier)을 운반 + 어떤 노드가 falsified되면 그것을 인용하는 파생 노드를 cascade-플래그.

조사: 노드 모델 = `compiler/atlas/parser.hexa` 단일 `struct AtlasNode`(kind·id·raw·source_file·
source_line·grade·edges). edges=`EdgeInfo`(depends_on `<-`·derives `->`·applications `=>`·
equivalents `==`·converges `~>`·verified_by `|>`·breakthroughs `!!`) — **인용/의존 메커니즘 이미 존재**.
falsifier는 현재 비구조화 prose: 코퍼스 427 "falsifier" 히트 대부분 노드 id/도메인명
(`F19_F23_falsifier_expansion_*`), 실제 클로즈는 `=> "...falsifier:..."` 설명 prose 안 2건뿐
(구조화 `falsifier:` 연속줄 = 0). `falsifier_wellformed_audit.hexa`는 raw 전체 substring-anywhere로
@? 노드만 감사. RETIRED `compiler/discover/cascade.hexa`(RFC-017 §5e) = atlas.n6 디스크 읽기 +
normalized_form substring 휴리스틱 + tombstone/manifest write(fs_write·중량) — out of scope 유지.

**스키마-광역 위험 실측**: hexa 구조체 리터럴은 누락 필드를 default 하지 **않음** — codegen이
`hexa_codegen_error__missing_field__Foo__c` 의도적 컴파일 에러 방출(테스트 빌드로 확인). 따라서
`AtlasNode`에 필드 1개라도 추가 = embedded.gen.hexa의 16101 리터럴 + ~20 생성 파일 전부 재작성
강제(데이터 파일 편집 금지 위반). → **스키마 변경 0**으로 결정. additive accessor 패턴 채택:

- [x] compiler/atlas/cascade.hexa (신규 ~260줄, 코드+주석; 코드 본문 g4 내) —
  (1) `node_falsifier(node)->string` = `raw` 연속줄에서 `falsifier:`/`falsifier = `/`falsifier=` +
  quoted-prose 래핑을 구조화 추출(필드 없이 타입드 surface · 부재 시 "" · `=>` 설명 prose는 의도적
  非매칭 = false-positive 방지) · `node_has_falsifier` 술어.
  (2) `CascadeHit{id·kind·via}` + `cascade_candidates(falsified_id, nodes)` = 기존 edge 재사용,
  falsified-id를 depends_on/verified_by/equivalents/derives로 인용하는 他노드 read-only 리스트
  (self-cascade 제외 · 강한-의존 우선 probe 순). `cascade_candidates_static(id)` = atlas_list+enrich
  래퍼. `cascade_to_text` 렌더. **read-only — tombstone/mutate/PR/I-O 無**.
- [x] compiler/atlas/cascade_test.hexa (신규) — 19/19 PASS(node_falsifier 3형식+quoted+부재·
  cascade 4-edge-type 후보·self/lonely 제외·empty/unknown id→0·render count).
- 검증: `hexa parse` 양파일 clean · 격리 worktree 빌드(차용 transpiler symlink + 메인
  HEXA_MODULE_LOADER + SIDECAR_NO_POOL_ROUTE=1) PASS. **16101 노드 byte-identical 로드**
  (corpus harness: `loaded 16101` · `n`→kind=P · `sigma`→kind=P 불변) · 실데이터 cascade
  (`n` falsified 가정 → 26 노드 인용: sigma depends_on, n6-* 등) · 기존 parser_test 재빌드 PASS
  (파서 무손상). **스키마/데이터/sibling 파일(atlas_cli·audit) 미변경 — git status = 신규 2파일만.**
- 결론: structured falsifier 필드는 hexa no-default-field 의미론 + 16k 동결 데이터 때문에 깨끗한
  additive 슬라이스 아님(스키마 강제 안 함). accessor+cascade-query로 동일 목표(구조화 surface +
  cascade 무효화 후보)를 read-only·byte-preserving 달성. 현 코퍼스 structured-falsifier=0 = 정직한
  상태(이 마일스톤이 채울 갭). cascade CLI verb 노출은 atlas_cli sibling rebase 후 deferred.

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
