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
- [x] R5: drift 보정 — R3 reverify가 surface한 3노드(`allen_dynes_tc`·`mcmillan_tc`·`bcs_gap_ratio`)가 6 sig-fig 반올림 리터럴로 등록되어 full-precision 재계산과 ε 초과(|Δ|=4e-6~1.8e-4). stale 노드 제거 후 `register --from-verify`로 full-precision 재등록(IEEE-754 double, 17 sig-fig). dedup(kind,id)이 skip-on-dup이라 사전 삭제로 clean REPLACE 보장. reverify `numerical_seen=35 match=35 drift=0` 달성 · 노드수 불변(16101) · 3노드 lookup full-precision 확인 (META-SIGNAL ② drift→재등록 첫 적용)

## deferred (다음 라운드)

calc_dispatch recompute-helper 풀 이동(R4 잔여: `_recompute_float`의 ~99 per-fn 계산 helper ~2200줄 — g4 200-LOC·link-risk로 별도 PR; atlas register는 이미 `hexa verify --expr` shell-out 위임이라 register-side 미러는 dead-code, reverify만 live subset) · falsifier 구조화 필드 + cascade 무효화 · numerology 격리 tier · active-acquisition 랭킹(Q/🟡/🟠) · reverify 확장(비-F kind · drift→자동 재등록 옵션) · 신규역량(MCP/API·시맨틱검색·proof-chain export·auto-edge 추론·atlas diff)

## 방법

격리 worktree off origin/main → 최소 additive 편집 → `hexa parse` → bin/hexa-atlas 빌드 → 기능 테스트 → green일 때만 PR. disjoint 파일만 병렬 fan-out (머지 충돌 0). pool-route 훅이 worktree 빌드 거부 시 STOP+보고.
