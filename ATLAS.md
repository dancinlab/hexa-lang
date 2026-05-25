# ATLAS — theorem-atlas system upgrade campaign

@goal: `/gap` 40-렌즈 스윕에서 발굴한 아틀라스 업그레이드 갭(무결성·비용·구조·증거·시간)을 origin/main에 체계적으로 클로즈. 메타 신호 = 두 뿌리(① verify_cli↔atlas_cli 미러 이중화, ② 등록 시 동결·재검증 없음) 우선 해소.

SSOT = `compiler/atlas/embedded.gen.hexa` (런타임 TEXT-parse). 등록 = `hexa atlas register`. 검증 = bin/hexa-atlas 단일 툴 빌드(~5s) + 기능 테스트. 랜딩 = 격리 worktree → PR(auto-merge 훅).

## 진행 (milestones)

- [x] R1: register fold dedup(kind,id)+skip + atomic temp-rename write (#948)
- [x] R1: cite_missing_count audit 커버리지 메트릭 — 8194/8650 미인용 확정 (#945)
- [x] R1: 표현 일관성 CI — embedded↔n6-export 노드수 동등 게이트 (#946)
- [x] R1: static_atlas() 프로세스-수명 파싱 캐시 — 파싱 9→1/proc (#950)
- [x] R2: drill `--rounds≥2` SIGSEGV triage+fix + C5 novelty-fixpoint(net-novel 포화) 착지 — compiler/drill/*
- [x] R2: audit domain-coverage 축 — `:: <domain>` 파싱 → domain×kind 매트릭스 + 0-cell 플래그 (#958)
- [x] R2: wigner_stabilizer_sn 미러 발산 fix — atlas_cli register 미러를 verify_cli 실제 소수 sieve와 일치(d>13) (#957)
- [x] R3: re-verify-🟢 부활 — `hexa atlas reverify [--limit N]` read-only drift 리포트(35노드 중 3 DRIFT 실측). 동결 등록 verdict in-process 재계산 (META-SIGNAL ② 첫 슬라이스)
- [x] R3: lookup on-disk offset 색인 — 단일 `lookup <id>`가 16k-노드 풀파싱 회피, 해당 노드 1줄만 seek+파싱. byte-identical(47-id 샘플 PASS) + unhealthy-index 풀파싱 폴백. ~3.9x user-CPU 가속 (offset_index.hexa)
- [x] R4: calc_dispatch.hexa SSOT 모듈 신설 — float 멤버십 술어(`calc_is_float_fn` 99-fn · `calc_is_zero_arg_float_fn` 8-fn) + ε(`calc_eps`=1e-9)를 단일 홈으로 호이스팅. verify_cli·atlas_cli 양쪽 `use` (META-SIGNAL ① 멤버십+ε 슬라이스). 양 바이너리 LINK PASS(핵심 위험 해소) · reverify byte-identical(36/32/3/1) · verify --expr·register 동작 불변. R3 실측 36-fn 멤버십 갭(99 vs 63) 제거 — float fn 추가는 이제 verify↔atlas 미러 동기 불필요, calc_dispatch 1곳만 편집
- [x] R5: falsifier 구조화 accessor + cascade 무효화 query — additive·read-only (compiler/atlas/cascade.hexa 신설). hexa 구조체 리터럴이 누락 필드를 default 안 함(codegen `missing_field` 컴파일 에러 실측) → `AtlasNode` 필드 추가는 16101 embedded.gen 리터럴 전부 재작성 강제(데이터 파일 금지) → **스키마 변경 0**. 대신 (1) `node_falsifier`/`node_has_falsifier` = `raw`의 `falsifier:`/`= `/`=` 연속줄을 구조화 추출(필드 없이 타입드 surface), (2) `cascade_candidates` = 기존 edge 모델(`<-`depends_on·`|>`verified_by·`==`equivalents·`->`derives) 재사용해 falsified-id 인용 노드 read-only 리스트(tombstone/PR 無 — RFC-017 §5e 중량 머신은 RETIRED discover/cascade.hexa에 격리 유지). 16101 노드 byte-identical 로드 PASS(`n`·`sigma` 룩업 불변) · 실데이터 cascade(`n`→26 노드 인용) · cascade_test 19/19 PASS
- [x] R5: active-acquisition 랭킹(Q/🟡/🟠) — `hexa atlas stats --acquisition [--top=N] [--scope] [--format=json]` 신규 read-only 축. 동결-but-미검증/open 노드를 composite priority(tier+domain-gap+kind)로 정렬한 "다음 검증/획득 프론티어" 출력. 실측 rodata 프론티어 2152 = 🟠 1709(cite-bearing·무인용·무재계산) + 🟡 360(인용·미재계산) + Q 83. 검증 불변식 PASS(서브카운트 합=총, 🟡⊆cite_present, 🟠⊆cite_missing, verified[*] 6583 제외, priority 단조감소). audit.hexa 소유 + atlas_cli 1-블록 dispatch wire

## deferred (다음 라운드)

calc_dispatch recompute-helper 풀 이동(R4 잔여: `_recompute_float`의 ~99 per-fn 계산 helper ~2200줄 — g4 200-LOC·link-risk로 별도 PR; atlas register는 이미 `hexa verify --expr` shell-out 위임이라 register-side 미러는 dead-code, reverify만 live subset) · numerology 격리 tier · reverify 확장(비-F kind · drift→자동 재등록) · cascade CLI verb 노출(현 R5는 라이브러리 surface만; `hexa atlas cascade <id>` dispatch는 atlas_cli sibling rebase 후) · acquisition 랭킹 후속(domain×tier 매트릭스 · 프론티어→drill seed 자동 공급) · 신규역량(MCP/API·시맨틱검색·proof-chain export·auto-edge 추론·atlas diff)

## 방법

격리 worktree off origin/main → 최소 additive 편집 → `hexa parse` → bin/hexa-atlas 빌드 → 기능 테스트 → green일 때만 PR. disjoint 파일만 병렬 fan-out (머지 충돌 0). pool-route 훅이 worktree 빌드 거부 시 STOP+보고.
