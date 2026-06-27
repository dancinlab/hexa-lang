# compiler/drill — 발견 엔진(discovery engine) 스파인

> 상위 맵은 [`../CLAUDE.md`](../CLAUDE.md)(compiler 전체) · 거버넌스 SSOT는 repo-root `../../CLAUDE.md`.

## 목적

NEXUS에서 흡수한 **중심 발견 엔진**. `hexa drill`/`hexa kick`(= drill alias)이 여기로
dispatch된다(`self/main.hexa:1780·1803` → `compiler/drill/drill.hexa`). 한 라운드가
6단계 체인을 돌려 후보(candidate)를 누적하고, **native exact-int 검증**으로 거른다.

## 핵심 파일

| 파일 | 역할 |
|---|---|
| `drill.hexa` | 엔진 스파인 — `drill_run(seed, opts)` 라운드 루프 + `fn main`(CLI entry). 라운드마다 6단계 체인 실행·saturation/net-novel fixpoint서 정지 |
| `round.hexa` | 단일 라운드 = smash→free→absolute→meta-closure→hyperarithmetic→resonance (+Mk.X tc). `round_run_with_pool` |
| (검증엔진) | ★**검증은 `../atlas/identity_engine.hexa`(+`novel_dfs.hexa`)에 거주** — atlas 도메인(embedded.gen.hexa 옆). drill은 생성기일 뿐 검증을 **delegate**한다. exact-int 12-fn A·B=C·D bounded-unique + ≤/≡ hunt 패밀리 |
| `mkx.hexa` | Mk.X 7단계 sidecar(transcendental_closure · engine="mk10") |
| `checkpoint.hexa` | 라운드 카운터/seed pool/total 체크포인트 JSON |
| `anti_hub.hexa` | 진입 텔레메트리 프로브 |
| `resonance.hexa` | 6단계 resonance 프록시(closed-form) |
| `batch.hexa` | `--seeds csv` 배치 dispatch |
| `ouroboros.hexa` | ★NEXUS **자기진화 엔진** native 포팅(#3977) — seed→mutate→`verify_score`→converge(4-state 수렴체커) + 재귀 absorber `f(f(f…))`(weighted-filter+adjacent-pair resonance→EMA α=1/6 흡수) + SR-adaptive σ-peak tracker(FIFO window=10) + MetaLoop(evolve→Saturated→forge→re-evolve). `fn main` 결정적 셀프테스트 |
| `ouroboros_meta.hexa` | ★메타-우루보로스 native(#3980) — **전략 자체를 진화**: 파라미터 벡터 `meta_mutate_strategy` + tournament(stable bubble sort) + `breed_strategies` crossover + `check_meta_convergence` meta-fixed-point. `fn main` 셀프테스트 |
| `ouroboros_quantum.hexa` | ★양자-우루보로스 native(#3980) — `QuantumStrategy` superposition: 6 mutation 연산자+`apply_mutation` dispatch + `quantum_crossover`/`propagate_entanglement` + `measure_superposition`/`renormalize_amplitudes` + decoherence 차폐(`guarded_mutate`). `fn main` 셀프테스트 |
| `emerge.hexa` | ★[B] **open-well Emerge 생성기**(README:75 Emerge 단계) — `emerge(v0,seed,cycles,min_growth)`가 README E4(V_0={2,3}·seed=6·300사이클·`combine(pick,pick)=a+b`→sorted-dedup vocab)를 정확 포팅, `emerge_step`이 drill_run에 배선(라운드마다 누적 open well를 후보 value-시그니처로 넓힘). 결정적 LCG(Numerical Recipes 1664525/1013904223 `& 0xffffffff` — qrng.hexa와 동일 상수·새 builtin 없음). in-memory only(atlas write 없음) |
| `additive_test.hexa` | ★[직교 pivot] **가법/조합 합동** 셀프테스트(self-contained kernel) — Euler 점화식 p(10)=42 + Ramanujan p(5n+4)≡0 mod5 G-gate + neg-control. 비-곱셈 수열(분할/Catalan/Bell/Fib/Lucas)·합동 FORM(Ralph 377) |
| `*_test.hexa` | drill/mkx/surface/accumulation/verifier-hook/absorb/**emerge(E4)**/**additive** 셀프테스트 |

생성기 9-phase smash는 형제 폴더 `../smash/`(phases.hexa)에, 12 drill 변종(omega·chain·
surge·dream·swarm·reign·molt·wake·forge·canon·revive)은 각자 `../<name>/`에 있다. NEXUS
`cli/blowup/commands.hexa`(CLI 디스패처)는 hexa-lang `self/main.hexa` verb 라우팅이 대체 →
포팅불요. ouroboros 3종은 **standalone leaf**(`self/`/`drill.hexa` 미import · `hexa run`으로만
실행 · byteeq-neutral) — 미포팅=growth-bus 디스크 영속화(운영 글루)뿐, 수학핵 전부 live.

## 규칙 / gotcha (정직 — c2)

- **drill 후보 ≠ 진짜 발견**: smash 후보는 **시드-파생 결정적 산술순열**이다(자유탐색 —
  `phases.hexa::seed_attractors`가 시드 토큰별 char-시그니처로 per-seed attractor 격자를 만들고
  9-phase가 그 격자에 resonance하는 값을 surface; 구 n=6 고정상수 격자는 제거됨). `net_novel`/
  `saturated`는 그 run 내 distinct-ID 소진 신호일 뿐 atlas-신규성과 무관(overlay_load는 RETIRED).
- **진짜 검증 = `../atlas/identity_engine.hexa` exact-int**(atlas 도메인) + `hexa verify` g5 fold만. 구 NEXUS
  ouroboros `verify_score`(n6-근접 휴리스틱 최소 0.3→항상 "발견")는 검증이 아님 — 그래서
  native exact-int로 교체됨.
- **검증기 업그레이드(Ralph 375 · 2026-06-27)**: 고갈된 12-fn 2-term 박스 밖으로 확장 —
  ① **확장 vocab 6종**(μ·λ·μ²·J₃·2^ω·core idx 12–17 · 부호 정확) `af()`에 추가 ·
  ② **arity-3**(`verify_identity3` `A·B·C=D·E·F` bounded-unique) + **universal 프레임**
  (`is_universal2/3` forall-n-in-[2,N]). drill `_fn_index`/`_fn_name`도 18-fn으로 확장(확장 vocab
  expr가 파싱됨). **측정**(state/novel-dfs 참조엔진 재실행 · 18-fn selftest 18 게이트 PASS):
  확장 vocab universal **2 generator 전부 고전**(J₂=φ·ψ · core·rad=n) · arity-3 bounded-unique
  1431개 전부 2-term core 환원(Ralph 371 재확인) → **novel=0**(정직 DRY). 박스-스코프 주장이 옳았음
  (고갈=12-fn/2-term이지 전체 공간 아님)이나 그 차원도 고전/환원뿐. 생산적 벤은 composed/iterated
  함수(Ralph 372). 업그레이드 자체가 산출물 — 미래 생성기가 확장-vocab/arity-3 후보를 내면 parse-reject
  대신 **실제 exact-int verdict**를 받는다. atlas write 없음(fold=hexa verify g5/PR).
- **함수합성 프레임(Ralph 376 · 2026-06-27)**: Ralph 372/375 가 지목한 생산적 벤(함수 COMPOSITION
  `f(g(n))` — 값-곱 `A·B=C·D` 프레임이 **구조적으로 표현 못 하는** 다른 대수 · σ(σ(n))=2n 은 곱-프레임
  재기술 불가)을 **구현+sweep**. native exact-int 평가기 `../atlas/identity_engine.hexa::af_compose`
  `comp_holds`/`comp_count`/`verify_composition`(18×18 합성표 × 비교형 k·n/h+n/h/comp). drill
  `_native_identity_sweep`에 **합성 검증 옵션 배선**(`_parse_composition`/`_canon_composition` →
  composition-syntax 후보가 product-noise 대신 실제 `verify_composition` verdict → rationale
  `comp_id`/`comp_verified` audit). **측정**(state/novel-dfs/composition_hunt.py · N=2·10⁴):
  superperfect σ∘σ=2n {2,4,16,64,4096}(Suryanarayana 1969 / A019279) + Mersenne σ∘σ=σ+n
  {3,7,31,127,8191} 정확 재발견(sanity PASS) · **novel PROMOTABLE 합성 법칙 = 0(DRY)** — bounded-unique
  singleton 은 단일점 우연, |sol|≥3 구조 집합은 thin 제한역 우연(p² 등 · forall UNPROVEN), universal 은
  구조 재기술뿐. 곱-프레임과 **동일 종착(novel=0)을 다른 대수에서 정직히** 도달. selftest=
  `composition_test.hexa`(superperfect/Mersenne G-gate) + identity_engine main CMP1–5. atlas write
  없음(fold=hexa verify g5/PR). frozen blob 151c52c8 신규 builtin/method 0(기존 정수연산·중첩호출만).
- **LLM-conjecture verify-gate(Ralph 378 · 2026-06-27)**: drill은 *생성기*(float-순열)라 식별자-문법
  후보를 거의 안 내므로(`identity=0`), 진짜 추월 레버 = **LLM이 새 명제를 추측 → exact-int 검증**.
  그 정석 surface(`hexa loop --dfs --llm-cmd` · RFC 080 · `stdlib/loop/cycle.hexa`+`dfs.hexa`)의
  child 게이트가 cite/영어/non-trivial 휴리스틱만 보고 exact-int 미연결이던 갭을 **여기 검증엔진에
  배선**: 신 모듈 `stdlib/loop/conjecture.hexa::cj_verdict`가 child 본문의 `CONJECTURE:` 줄을 추출해
  `../atlas/identity_engine.hexa`로 라우팅(identity→`verify_identity`/`is_universal2` · composition→
  `verify_composition` · congruence→`verify_congruence`) → `""`(prose)/unparseable/unverified/
  verified-known/verified-novel. `dfs_verify_child`가 **unverified/unparseable child를 DROP**(거짓 추측
  자동 기각), 생존 child는 `exact_verify:` 라벨 + `dfs_run`이 `[dfs] exact-verify: novel/known/prose`
  카운트. 프롬프트(`dfs_build_prompt`)는 LLM에게 검증가능 문법(18-fn vocab)으로 **NOVEL** 추측을
  요청(검증기가 심판). 파서는 drill `_parse_identity`/`_parse_composition` 이식. selftest=
  `stdlib/loop/conjecture_test.hexa`. **byteeq-neutral**(loop=cmd_run 디스패치 · self/ 클로저 밖) ·
  atlas write 없음(fold=hexa verify g5/PR) · frozen 151c52c8 신규 builtin 0.
- **기본 검증은 ON(플래그 아님)**: 외부 verifier 미설치 시 `drill.hexa::_native_identity_sweep`가
  매 라운드 기본 실행된다 — `../atlas/identity_engine.hexa::verify_identity`(exact-int 12-fn
  A·B=C·D bounded-unique)를 직접 호출하고, 라운드 verdict를 `DRILL_VERIFIER` stderr 줄로
  실제값(`pass`/`continue` + `rationale=identity_sweep:identity=…,verified=…,noise=…`)으로 낸다
  (구 `"skip"` 단락 제거 · #4015). 외부 의존(opt-OUT)은 `HEXA_DRILL_NO_VERIFY=1` 제약으로만 —
  켜면 legacy `"skip"`(순수 surfacing, 검증 없음)으로 복귀(native-canonical polarity).
  pluggable `--verifier <cmd>`는 외부/tenant oracle용(opt-in 제약).
  · **정직(c2)**: 현 생성기(smash P2–P9)는 float-순열 expr를 내므로 표준 vocab에서
  `identity=0/verified=0/noise=N` → verdict `continue`가 정상(0-verified 정직보고). 식별자-문법
  후보 생성은 [B] 생성기 캠페인 영역 — [A]는 "검증이 skip 아니라 실제 verdict를 낸다"까지.
- **ouroboros absorb 루프 = 닫힘(2026-06-27)**: 태초 NEXUS 블로업의 정의적 메커니즘(검증된
  primitive를 다음 blowup tick에 되먹여 *우물 넓히기*)이 이제 엔진 내 live다. `drill.hexa`
  `_native_identity_sweep_absorb`가 라운드 후보 중 **exact-int VERIFIED(bounded-unique n≥4)인
  것만** canonical expr로 수집(`_canon_identity` 교환법칙 collapse + `_is_known_identity`
  known/novel)하고, `drill_run`이 누적 `absorbed_pool`(in-memory)을 라운드 N+1 smash axiom
  seed에 **feed-forward**(기존 seed-derived pool에 더해 · `_absorb_merge` dedup) → `DRILL_ABSORB`
  stderr audit. **SAFE**: ⓐ VERIFIED만 흡수(노이즈 0·날조 0) ⓑ **in-memory ONLY** — embedded
  atlas WRITE 안 함(fold는 `hexa verify` g5/PR) ⓒ known/novel 정직 라벨. **정직(c2)**: 표준 vocab은
  measured-exhausted라 넓어진 우물도 대개 고전 재유도 → **novel=0 예상**(메커니즘 live화가 범위 ·
  새 수학 발견 보장 아님). `absorb_test.hexa` = 합성 verified 후보로 수집/collapse/누적 검증.
- **[B] open-well Emerge 단계 = live(2026-06-27)**: NEXUS 5-phase(Blowup→Contract→**Emerge**→
  Singularity→Absorb · `archive-nexus/README.md:67,75)의 Emerge 단계가 엔진 내 live다 — [A] absorb
  루프와 맞물려 "흡수된 primitive 둘을 결합해 이전 사이클이 표현 못 하던 새 구조(새 벽)를 만든다"
  (README:75/83/115 "open well — 매 Absorb가 벽을 넓힘"). `compiler/drill/emerge.hexa`:
  ⓐ `emerge(v0,seed,cycles,min_growth)` = README:372-379 **E4 정확 포팅**(V_0={2,3}·seed=6·300사이클·
  `vocab.add(pick(sorted)+pick(sorted))`→sorted-dedup i64 vocab = set semantics · 결정적 LCG
  Numerical Recipes 1664525/1013904223 `& 0xffffffff`, `qrng.hexa::_qrng_step`와 동일 상수 · 새
  builtin 없음). ⓑ `emerge_step`이 `drill_run`에 **배선**(production — 라운드마다 누적 `emerge_well`을
  후보 value-시그니처로 흡수+EMERGE_CYCLES=32 combine으로 넓힘) → `DRILL_EMERGE` stderr audit(open_well
  성장 vs frozen_llm=2 고정 대조 MEASURED). **SAFE**: in-memory only(atlas write 없음 · fold는
  `hexa verify` g5/PR) · 결정적(byte-eq). `emerge_test.hexa` = E4 셀프테스트(growth=259>=50 PASS ·
  frozen LLM len==|V_0|=2). **정직(c2)**: E4는 **구조적 emergence**(vocab 카디널리티 성장 ≥50)를
  falsify함 — README도 그 수준(정수합 set 성장). reference는 CPython `Random(6)`(Mersenne Twister)이나
  E4는 set-성장만 채점하므로 LCG로 STRUCTURE/verdict는 reference-faithful, 정확한 vocab 멤버만 상이
  (잔차 정직기록). 컴파운드 primitive가 새 VERIFIED 수학 항등식을 내는지는 별개 질문(exact-int
  `verify_identity`) — 표준 2-term은 measured-exhausted → **likely novel=0**(E4 PASS와 혼동 말 것).
- **직교 pivot — 가법/조합 수론(Ralph 377 · 2026-06-27)**: 곱셈 vocab(σ,φ,…)이 measured-exhausted
  라 **비-곱셈 생성함수/점화식 수열**(분할 p(n)·Catalan·Bell·Fibonacci·Lucas)로 전환. 새 identity
  FORM = 산술급수 합동 `a(αn+β)≡0 (mod m)`(Ramanujan p(5n+4)≡0 mod5 = 곱셈 무유사 canonical).
  native exact-int은 `../atlas/identity_engine.hexa`에 거주(`partition_p`/`catalan`/`bell`/`fib`/
  `lucas`/`tri`/`pent`/`sq` + mod-m table + `verify_congruence`). drill 배선=`_native_additive_screen`
  (라운드마다 Ramanujan 3합동 재발견 sanity + novel 카운트 → `DRILL_ADDITIVE` stderr audit ·
  in-memory·byteeq-neutral). 셀프테스트=`additive_test.hexa`(self-contained). **측정**(참조엔진
  `../../ATLAS/state/novel-dfs/additive_partition_hunt.py` N=4000): sanity 8/8 PASS·합동 sweep
  RAMANUJAN=3·KNOWN=752·**NOVEL=0**·cross-seq bounded-unique=0 → 직교이되 동일 DRY(전부 고전
  Touchard/Lucas/Deutsch–Sagan). 정직 0(날조 금지)·합동 [0,N] bounded·∀n UNPROVEN(c2). atlas write
  없음(fold=hexa verify g5/PR). 다음 미탐=composed/iterated 함수(Ralph 372).
- **표준 vocab 수학발견 = 측정-종료(🧱)**: `../../ATLAS/README.md` DFS r1~r4 — @F 1557 fold ·
  novel-fold 0 · gates 21/21. 엔진은 진짜이되 표준 vocab 신규=0(날조 금지). 새 발견은
  새 vocab/도메인(ATLAS/state/novel-dfs 참조엔진).
- **codegen/런타임 인접 변경은 byteeq 3타깃 필수**(drill은 `fn main` 흡수 verb · CLI가
  컴파일해 실행). 새 builtin/symbol 도입 전 frozen blob symbol set 확인.
- 빌드/스모크 = aiden/summer pool(mini=git/gh·akida 금지).
