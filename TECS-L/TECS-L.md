# TECS-L — 범용 우주-법칙 발견 엔진 (도메인 SSOT · n=6 은 축 0 한 축)

@title: 🔬 TECS-L — 범용 우주-법칙 발견 엔진 ("측정자 尺" · n=6 은 여러 축 중 하나)
@goal: **우주의 모든 법칙이 발견될 때까지 멈추지 않는** 범용 다영역(multi-domain) 영구 발견 엔진 — **물리·수학·우주·생명** 등 각 영역을 대축(major axis)으로 삼아 hexa `hexa verify` g5 + atlas 로 재근거화하고, terminal 발견을 atlas atom + /paper 로 끝없이 축적. **n=6 완전수 lattice 는 여러 축 중 하나(축 0, CLOSED)일 뿐** — 발견 엔진의 첫 좌표계이지 유일 대상이 아니다. archive-TECS-L 다영역 코퍼스(수론·물리·우주·생명/의식 수학)를 흡수, MILLENNIUM(Clay 7)은 수학 대축으로 통합. **종료 조건 없음 — 도메인은 완료되지 않는다.**

> archive-TECS-L (`dancinlab/archive-TECS-L`, Python) 의 수론 발견 코퍼스를
> hexa-lang 의 theorem atlas + `hexa verify` g5 게이트 위로 재근거화하는 도메인
> SSOT. 옛 RFC-080(hexa loop DFS+LLM) 계획서가 이 파일명을 점유하고 있었으나,
> 정본은 `docs/rfc/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md` 에 보존돼 있어
> 2026-05-25 부터 이 파일을 수론 도메인으로 재배정 (사용자 승인).

---

## 0 · 한 문단 상태 (2026-05-26 — 범용 다영역 발견 엔진으로 격상)

**TECS-L 은 완료되지 않는다.** 우주의 모든 법칙(물리·수학·우주·생명·…)이 발견될
때까지 멈추지 않는 **범용 다영역 발견 엔진**으로 격상(2026-05-26). n=6 완전수 lattice
는 **여러 축 중 하나(축 0, M1–M10 CLOSED ✅)** — 발견 엔진의 첫 좌표계이지 유일 대상이
아니다. 구조:
- **축 0 — n=6 정체성 코어** (§2, CLOSED) · 첫 좌표계
- **대축 MATH (수학)** — MODFORM(축 A)·MERSENNE(축 B)·NOVEL(축 F)·MILLENNIUM(축 G, Clay 7)
- **대축 PHYSICS (물리)** — 물리상수·법칙 (축 0 M5 승격) [신규]
- **대축 COSMOS (우주)** — 우주론 스케일·상수 [신규]
- **대축 LIFE (생명)** — 생명/정보 수학·IIT Φ [신규]
- **메타 축** — Atlas-LLM 연속 루프(C)·Atlas 성장(E), 영역 무관 운전
각 축은 자체 마일스톤을 가지며, terminal 발견은 `.verdicts/` + `CLAIMS.tape`(group=TECS-L)
+ atlas atom + /paper 로 영구 축적. 진행바는 100% 에 도달하지 않는다(설계 — 새 영역이
나오는 한 대축·마일스톤 계속 추가). archive-TECS-L(`dancinlab/archive-TECS-L`, private)
다영역 코퍼스(수론·물리·우주·생명/의식 수학)가 출처.

**M1 CLOSED (2026-05-25)** — n=6 핵심 정체성 σ·φ=n·τ 를 hexa-native `hexa verify` 로
재근거화: n∈{1,6} 성립(🔵) + n=28(2nd 완전수) 닫힌-네거티브(🔴 σφ=672≠nτ=168) 로
"완전수 성질이 아니라 {1,6} 전용"임을 가름. 10 verdict 영속화.

**M3 CLOSED (2026-05-25)** — M1 이 미룬 유일성 잔여를 Dedekind ψ discrepancy
**D(n) = σ(n)·φ(n) − n·τ(n)** 로 재근거화. n=1..100 exhaustive 스윕(hexa-native
compiled 바이너리, load-bearing n 은 `hexa verify --expr` 와 component-wise 교차검증)
→ **zero-count=2, D(n)=0 zeros at {1,6}** (🔵) + 나머지 전부 D(n)≠0 (🔴 CLOSED-negative).
D(28)=504≠0 으로 "완전수도 D=0 아님" 확정. archive `dfs_dedekind_psi_discrepancy.py`
의 D(n)=σφ−nτ 정의와 동일. 16 verdict 영속화. **단, finite 스윕은 전칭(unbounded)
유일성의 증명이 아님** — 전칭 ⟺{1,6} 은 🟡 citation 잔여(아카이브 해석 논증).

archive-TECS-L 의 핵심은 n=6 완전수에서 산술함수
σ(약수합) · τ(약수개수) · φ(오일러 토션트) 만으로 물리상수를 조립하는 "수학 시(詩)"
엔진 (Gemini 평: Ramanujan-level). n=6 핵심 정체성 σ(n)·φ(n)=n·τ(n) 은 이미
hexa-lang `CLAUDE.md` @I + atlas 에 임베드돼 있다. 이 도메인은 그 코퍼스를
hexa-native 연산 + g5 verify 로 한 atom 씩 재근거화한다 — Python 엔진을 대체하고,
아카이브의 자기보고 메트릭을 결정적 판정문으로 승격한다.

## 1 · 출처 코퍼스 (archive-TECS-L · Python)

| 엔진 | 파일 | 역할 |
|------|------|------|
| Perfect Number | `perfect_number_engine.py` | n∈{6,28,496,8128} σ/τ/φ → 물리상수 표현식 |
| Convergence | `convergence_engine.py` | 8 도메인 × ~80 상수 → 수렴점 클러스터 |
| Quantum Formula | `quantum_formula_engine.py` | 양자수 ↔ 수학 타겟 매칭 (depth 2-3 + p-value) |
| Proof | `proof_engine.py` | 발견 수식 → Tier 0-3 등급 (g5 tier 의 선조) |
| DFS / Congruence | `dfs_engine.py` · `congruence_chain_engine.py` | cross-island 매칭 · modular form |
| Discovery loop | `discovery_loop.py` | DFS → Converge → Verify → Grow → Paper 흡수 루프 |

> 아카이브 자기보고 메트릭: 206 n=6 characterizations · 2,711 가설 · 300+ 상수맵 ·
> 49 Zenodo 논문. **본 도메인에서 g5 재검증 통과 전까지 전부 🟡 미검증 인용으로 취급.**

```
 archive-TECS-L (Python)              TECS-L 도메인 (hexa-native)
 ──────────────────────              ──────────────────────────
  σ,τ,φ 산술함수  ─┐                   stdlib 산술함수 모듈 (M2)
  Perfect Number  ─┼─▶ 발견 수식  ─▶  hexa verify (g5)  ─▶  .verdicts/
  Convergence     ─┤                        │
  Proof Tier 0-3  ─┘                        └─▶ atlas 등록  ─▶  /paper (terminal만)
```

## 2 · 축 0 — n=6 정체성 코어 (CLOSED ✅, M1–M10)

> 창립 축. n=6 완전수 정체성·유일성을 닫힌형 증명까지 완결한 코어. 이 축은 종결됐고,
> 도메인은 아래 영구 확장 축(A·B·C)으로 계속 전진한다.

- [x] M1 — n=6 핵심 정체성 σ(n)·φ(n)=n·τ(n): hexa-native 재계산 🔵 (n=6·n=1 HOLDS) + n=28(2nd 완전수) 🔴 CLOSED-negative (σφ=672≠nτ=168 → "완전수 성질" 아님, {1,6} 전용). 10 verdict → `.verdicts/tecs-l-n6-identity/` · `CLAIMS.tape` group=TECS-L. 전칭 ⟺{1,6} 유일성은 🟡 citation 잔여(M3 Dedekind ψ로 이관)
- [x] M2 — 산술함수 stdlib 모듈 (σ · τ · φ · sopfr) hexa-native: `stdlib/core/math.hexa` 에 `sigma`/`tau`/`euler_phi`+`phi` 별칭/`sopfr` 공개 + 단위테스트 `stdlib/core/math_numtheory_test.hexa` (17 assert · `hexa parse` PASS) + σ/τ/φ n∈{1,6,12,28} 12 verdict 🔵 `hexa verify --expr` verbatim → `.verdicts/tecs-l-arith-stdlib/` · `CLAIMS.tape` slug=tecs-l-arith-stdlib. Python `model_utils.py` 대체
- [x] M3 — Dedekind ψ discrepancy D(n)=σφ−n·τ 유일성: n=1..100 exhaustive 스윕 hexa-native → zero-count=2, **D(n)=0 zeros at {1,6}** 🔵 + D(n)≠0 elsewhere 🔴 CLOSED-negative (D(28)=504≠0 → 2nd 완전수도 D≠0). 16 verdict → `.verdicts/tecs-l-dedekind-psi-uniqueness/` · `CLAIMS.tape`. 전칭(unbounded) ⟺{1,6} 유일성은 🟡 citation 잔여 (finite 스윕≠전칭 증명)
- [x] M4 — 206 n=6 characterizations g5 triage (`TECS-L/docs/n6-characterizations-triage.md`) + 검증 가능 부분집합 15 atom 영속화 (🔵 SUPPORTED-FORMAL: σ/τ/φ/μ/is_perfect/aliquot/σ₀/σ₂/σ₃ ground 값 + Γ₀(6) index=σ·cusps=τ·genus=0·dim S₂=0·conductor=n²). 헤드라인 206 = numbered #1…#206 시리즈; 절대다수는 "f=g⟺n=6" 심볼릭 유일성이라 hexa 전역 recompute 경로 없음 → 🟡 citation (M1 σφ=nτ 유일성과 동일 처리). 15 verdict → `.verdicts/tecs-l-n6-characterizations/` · `CLAIMS.tape` slug=tecs-l-n6-characterizations
- [x] M5 — 물리상수 조립: **τ(perfect_k)=끈이론 임계차원 (4,6,10,14,26)** 5/5 🔵 (τ(33550336)=26 보존끈 D) + SM 게이지합 8+3+1=σ(6)·σ/φ=n·Koide Q=τ/n=2/3·키싱수 6/12/24 🔵. 페르미온질량 1.9%·Koide 5ppm 등 관측매칭은 🟡, CERN·핵 magic은 🟠 (triage doc). 10 verdict → `.verdicts/tecs-l-physics-constants/`
- [x] M6 — 2,711 가설 g5 triage (카테고리 단위, `TECS-L/docs/m6-hypotheses-triage.md`): 🔵 코어 = H18 **σ(n)=2n ⟺ perfect** 첫 5개 완전수 abundancy=2 (σ(33550336)=67100672) + μ(6)=1·aliquot(6)=6, 7 atom. 의식/ML/물리매칭/생물 절대다수는 🟡/🟠/⚪ (hexa 닫힌형 경로 없음). 7 verdict → `.verdicts/tecs-l-hypotheses/`
- [x] M7 — Golden Zone (1/e) 닫힌형 유도 시도 → **🔴 CLOSED-NEGATIVE**: 1/e 는 초월수(Hermite)라 어떤 n=6 유리수와도 정확히 같을 수 없음 (최근접 τ/σ=1/3 9.4%·3/8 1.94% 빗나감; 아카이브 Review 010 자체 self-refute). EXACT 유리수 유도 axis 결정적 배제. 3 🔵 + 1 🔴 → `.verdicts/tecs-l-golden-zone/` (`TECS-L/docs/m7-golden-zone-closed-negative.md`)
- [x] M8 — discovery_loop → hexa-native 발견 엔진: **이미 RFC 065(self-growing atlas)+RFC 080(`--dfs` 포트)로 shipped**. `hexa loop --once` 스모크로 8-stage 사이클 end-to-end 실증(36 lens→153 candidate). archive 6+엔진 → `hexa loop`/`--dfs`/`hexa kick`·`drill`/`hexa verify`/`/paper` 1:1 매핑 (`TECS-L/docs/m8-discovery-engine-mapping.md`)
- [x] M9 — `/paper` 승격: **PAPER/tecs-l-n6-identity-locus/** (10p + fal.ai `fig01_locus.png`). "The {1,6} Identity Locus" — M1 σφ=nτ·M3 D(n)·M5 τ=string-dim·M6 σ=2n 의 terminal 🔵/🔴 발견 소비. pre-registered falsifier=n=28(2nd 완전수) → closed-negative. 전칭 유일성은 🟡 명시 제외(게이트 통과)
- [x] M10 — **전칭 유일성 닫힌형 증명** (🟡→🔵): σ(n)φ(n)=n·τ(n) ⟺ n∈{1,6} ∀n. 곱셈성→∏g(p,a)=1, g(p,a)=(p^{a+1}−1)/(p(a+1)); **g(2,1)=3/4만 <1, 나머지 모두 >1** → 해 {1,6} 뿐. base-case 10 🔵 + 정리 🔵 → `.verdicts/tecs-l-uniqueness-proof/`. M1/M3/M9 residual 승격, 유한 sweep 불요 (`TECS-L/docs/m10-uniqueness-closed-form-proof.md`)

## 3 · 영구 확장 대축 (perpetual multi-domain axes)

> n=6 (축 0) 은 여러 축 중 하나. 아래는 우주 법칙의 各 영역을 **대축(major axis)**
> 으로 삼는다 — 수학·물리·우주·생명… 각 대축은 하위 축/마일스톤을 갖고 verify-loop
> 로 전진하며, 종료 조건이 없다 (새 법칙이 나오는 한 대축·마일스톤이 계속 추가된다).
>
> **현 매핑**: 기존 MODFORM(축 A)·MERSENNE(축 B)·NOVEL(축 F)·MILLENNIUM(축 G) 는
> **수학 대축** 하위. **물리(PHYSICS)·우주(COSMOS)·생명(LIFE)** 대축은 신규 —
> archive-TECS-L 다영역 코퍼스 반영. Atlas-LLM(C)·Atlas 성장(E) 은 영역 무관 메타-운전
> 축. (n=6 축 0 = §2, 여기 §3 은 그 위의 다영역 확장.)

### 축 A — MODFORM (Γ₀(N) 모듈러폼·합동사슬)
> `gamma0_index/cusps/genus`·`dim_cusp_forms`·`first_cusp_form_weight`·`jacobi`·`kronecker` (전부 verify 내장). TECS-L M4 의 Γ₀(6) 맛보기를 N 전반으로.

- [x] MF1 — Γ₀(N) index ψ(N)=N∏(1+1/p): **N=1..30 전수 `gamma0_index` verify 30/30 🔵** + Γ₀(6) index=12=σ(6) bridge. → `.verdicts/tecs-l-modform-index/index_sweep_1_30.txt` · CLAIMS slug=tecs-l-modform-index
- [x] MF2 — Γ₀(N) cusp 수 c(N)=Σ_{d|N} φ(gcd(d,N/d)): **N=1..30 전수 `gamma0_cusps` verify 30/30 🔵** + Γ₀(6) cusps=4=τ(6) bridge (축 0 M4 연계). → `.verdicts/tecs-l-modform-cusps/cusps_sweep_1_30.txt` · CLAIMS slug=tecs-l-modform-cusps
- [x] MF3 — Γ₀(N) genus-0 전수: 고전 15개 N∈{1..10,12,13,16,18,25} `gamma0_genus`=0 **15/15 🔵** + genus≥1 경계 7/7 🔵 (N=11/14/15/17/19→1, N=22/23→2 — 고전 리스트 밖에서 genus 상승). hexa `gamma0_genus` 가 모든 고전/기지값과 **일치(🔴 불일치 0)**. **헤드라인 Γ₀(6) genus=0** (X₀(6) genus-0 — n=6 모듈러곡선 bridge, 축 0 M4). 22 verdict → `.verdicts/tecs-l-modform-genus/genus_sweep.txt` + headline · `CLAIMS.tape` slug=tecs-l-modform-genus 6 entry
- [x] MF4 — dim S₂(Γ₀(N)) = genus 정리 vs hexa fn: **🔴 CLOSED-NEGATIVE** — `dim_cusp_forms(N,2)` 가 표준 dim S_2 를 실현 안 함 (N=1..10 우연 일치, N=11..30 중 20개 mismatch, 예: N=11 hexa=0/고전=1, N=30 hexa=6/고전=3). `gamma0_genus` 는 MF3 가 신뢰성 확인. 5 verdict + INBOX 업스트림 보고 (`TECS-L/docs/mf4-dim-genus-mismatch.md`)
- [x] MF5 — Jacobi/Kronecker 이차 상호법칙 인스턴스: **10 jacobi + 3 kronecker 교과서 값 13/13 🔵** + 2 QR 상호법칙 곱 인스턴스 (a,b)=(3,5)·(3,7) 둘 다 J(a,b)·J(b,a) = (-1)^((a-1)(b-1)/4) 적중 🔵. 🔴 불일치 0. hexa `jacobi`/`kronecker` 가 2의 보조법칙·-1 보조법칙·소수쌍 QR·kronecker 확장 (n∈{1,3,7}) 전반에서 고전 기호와 일치. → `.verdicts/tecs-l-modform-symbols/` (13 verdict + qr_instance.txt) · `CLAIMS.tape` slug=tecs-l-modform-symbols 15 entry
- [x] MF6 — n=6 bridge: Γ₀(6) index=12=σ · cusps=4=τ · genus=0 · first_cusp_weight=4=τ · |AL|=2^ω=4. 4 불변량 모두 n=6 산술함수로 환원 (MF1/MF2/MF3/MF7 anchors). 1 synthesis artifact + `TECS-L/docs/mf6-n6-modular-bridge.md`
- [x] MF7 — first_cusp_form_weight(N) N=1..30 sweep **30/30 🔵** (1→12·6→4·30→2; 단조감소 경향) + Atkin-Lehner involution 수 |AL(Γ₀(N))|=2^ω(N) 닫힌형 표 (10 sample N=1..30030, 🟡 citation — ω 도출 by-hand). Γ₀(6) weight=4=τ(6) bridge. 5 verdict → `.verdicts/tecs-l-modform-weight-al/`
- [x] MF8 — MODFORM paper SHIPPED: dim≠genus + n=6 non-lift, g51 ≥10p+fal. MODFORM 축(MF1-MF7)을 **두 사전등록 closed-negative** 둘레로 집약한 arxiv-style 논문. (1) MF4 dim S₂≠genus (hexa `dim_cusp_forms` 정의 갭, 20/30 mismatch, PR #1083) + (2) F7 σφ=nτ⟺{1,6} 가 Γ₁/X(N) 로 **lift 안 됨** (index smooth). 검증된 Γ₀(N) backdrop(index/cusps/genus/dim/AL) 위에 안착. 11페이지 + fal.ai(gpt-image-2) figure 1장(g51 충족). → `PAPER/tecs-l-modform-n6-nonlift/` (main.tex·pdf·references.bib·Makefile·README) · `CLAIMS.tape` slug=tecs-l-modform-n6-nonlift 3 entry · verdict `.verdicts/tecs-l-modform-{dim-genus,other-curves}/`

### 축 B — MERSENNE (메르센 소수 ↔ 완전수 생성원리)
> Euclid-Euler(완전수 ⟺ 메르센 소수) · abundancy=2 · Lucas-Lehmer. 축 0 M5/M6 완전수 thread 심화.

- [x] MR1 — Euclid-Euler: n=짝완전수 ⟺ n=2^{p-1}M_p (M_p 소수). 7 완전수 unified table (M5/MR2 is_perfect · M6 σ=2n · MR5 τ=2p · MR4 Lucas-Lehmer). 1 synthesis artifact + `TECS-L/docs/mr1-euclid-euler.md`. Odd-perfect 🟠 잔여 (MR7)
- [x] MR2 — 메르센 소수 ↔ 완전수 (6·7번째 완전수 확장): p=17→M17=131071·p=19→M19=524287 소수 → **P6=2^16·131071=8589869056 · P7=2^18·524287=137438691328 `is_perfect`=1 🔵** + abundancy=2 (σ(P6)=17179738112=2·P6 · σ(P7)=274877382656=2·P7 🔵). 축 0 M5/M6 이 첫 5개(6·28·496·8128·33550336)를 이미 🔵 처리 → src 참조만, 중복검증 없음. 4 verdict → `.verdicts/tecs-l-mersenne-perfect/` · `CLAIMS.tape` slug=tecs-l-mersenne-perfect
- [x] MR3 — abundancy σ(P)=2P 닫힌형: σ multiplicative ⊗ σ(M_p)=2^p ⊗ σ(2^{p-1})=M_p → σ(2^{p-1}M_p)=(2^p-1)·2^p=2P. 7 완전수 anchor (P1..P5 = 축 0 M6 + P6/P7 = MR2, 새 산술 verify 없음 · synthesis). `TECS-L/docs/mr3-abundancy-closed-form.md`. odd-perfect 🟠 (MR7)
- [x] MR4 — Lucas-Lehmer hexa-native: `stdlib/core/math.hexa` 에 `lucas_lehmer(p)`(S₀=4·S_{k+1}=S_k²−2 mod M_p, pure-int) + `mersenne(p)` 공개 + 단위테스트 `stdlib/core/math_lucas_lehmer_test.hexa` (12 assert · `hexa parse` PASS). **p=3/5/7/13 → PRIME · p=11(M_11=2047=23·89) → COMPOSITE**. LL 은 알고리즘(루프)이라 `--expr` 빌트인 아님 → 같은 결론을 g5 atom 으로 교차검증: M_p 소수 ⟹ 2^{p-1}·M_p 완전수 (`is_perfect` 28/496/8128/33550336 🔵) + M_11 합성 (sigma 2047 2160·tau 2047 4 🔵, axis-B MR6 재참조). 7 verdict → `.verdicts/tecs-l-mersenne-lucas-lehmer/` · `CLAIMS.tape` slug=tecs-l-mersenne-lucas-lehmer. (compiled `hexa build` 은 heavy-pool-refused 라 미실행 — parse PASS + g5 교차검증이 정본 증거)
- [x] MR5 — τ(2^{p-1}·M_p)=2p 닫힌형: 첫 7 완전수 P_1..P_7 (p=2,3,5,7,13,17,19) τ=4·6·10·14·26·34·38 전부 🔵. 약수는 2^a·M_p^b (a∈[0,p-1], b∈{0,1}) → (p)(2)=2p. P1..P5는 축 0 M5 (`.verdicts/tecs-l-physics-constants/str_dim_p*.txt`)에서 다른 slug로 이미 🔵 — MR5 slug에서 닫힌형 framing으로 재검증, P6/P7 (NEW) 확장. 7 verdict → `.verdicts/tecs-l-mersenne-tau-2p/` · `CLAIMS.tape` slug=tecs-l-mersenne-tau-2p. aliquot 체인은 별도 후속 milestone.
- [x] MR6 — 메르센 합성수 표본 CLOSED: **M_11=2047=23·89 (σ=2160≠2048·τ=4≠2 → 합성, 첫 반례)** → **p 소수 ⇏ M_p 소수** (Euclid-Euler 역명제 실패, ∴ 모든 소수지수가 완전수를 낳지 않음); M_23=8388607=47·178481 (τ=4)·M_29=536870911=233·1103·2089 (τ=8) 도 합성. 17 claim / 16 verdict 🔵 → `.verdicts/tecs-l-mersenne-composite/` · `CLAIMS.tape` slug=tecs-l-mersenne-composite
- [x] MR7 — odd perfect 🟠 honest 미해결 documented: 알려진 lower bound (>10^1500 Ochem-Rao 2012 · ≥9 distinct primes Nielsen 2015 / ≥12 if 3∤n · largest prime ≥10^8 Goto-Ohno 2008 · 2nd ≥10^4 Iannucci 1999 · Ω(n)≥101 Ochem-Rao 2014 · Euler form p^a·∏q_i^{2b_i}, p≡a≡1 mod 4) citation. Euclid-Euler(MR1)는 짝완전수 only — MR7 은 그 open 보완. paper-ineligible by gate. 1 verdict + CLAIMS slug=tecs-l-mersenne-odd-perfect-open · `TECS-L/docs/mr7-odd-perfect-open.md`
- [x] MR8 — MERSENNE paper SHIPPED: 지수-소수성 non-implication, g51 ≥10p+fal. MERSENNE 축(MR1-MR7)을 **헤드라인 closed-negative MR6** 둘레로 집약한 arxiv-style 논문. MR6 사전등록 falsifier "p 소수 ⟹ M_p=2^p−1 소수" **기각 🔴** — p=11 에서 M_11=2047=23×89 합성(σ=2160≠2048·τ=4≠2; 두 인수 σ=n+1/τ=2 로 소수 검증 → 정확 인수분해), 추가 합성 증인 M_23=47×178481·M_29=233×1103×2089. **배제 axis = 지수-소수성만으로 완전수 생성** (메르센-소수 가설 필수). 검증된 Euclid-Euler 코어(MR1 perfect↔Mersenne · MR3 σ(P)=2P · MR2/MR5 P_6/P_7 is_perfect+τ=2p, 전부 🔵)가 positive 배경. **MR7 odd-perfect 는 정직하게 🟠 OPEN frontier 로 표기 — finding 으로 쓰지 않음**. 11페이지 + fal.ai(gpt-image-2) figure 1장(g51 충족). → `PAPER/tecs-l-mersenne-exponent-primality/` (main.tex·pdf·references.bib·Makefile·README) · `CLAIMS.tape` slug=tecs-l-mersenne-exponent-primality 2 entry · verdict `.verdicts/tecs-l-mersenne-{composite,euclid-euler,abundancy-closed,perfect,tau-2p,odd-perfect-open}/`

### 축 C — Atlas-LLM 연속 루프 (`hexa loop --claude` · RFC 080 · 영구)
> 끝없이 도는 LLM-동반 발견 엔진. RFC 080 pluggable `--llm-cmd` (claude/codex/local), 6단 cite-verify gate, 3-way budget cap (USD/calls/time), embedded.gen 자동수정 금지(PR-only). **이 축은 본질적으로 종료되지 않음** (마일스톤이 아니라 연속 운전).

- [ ] C1 — 활성화 게이트: `hexa loop --claude --llm-budget <USD> --llm-calls N` budget-capped 1회 bounded smoke (LLM 비용 go-ahead 필요)
- [ ] C2 — 연속 운전: `/schedule` (cloud cron) 또는 `/loop` (session) 으로 주기 실행 — verify-pass 후보만 `archive/atlas_candidates/` emit → PR → atlas fold
- [ ] C3 — telemetry 누적: per-cycle cost·emitted·pruned·cache-hit 집계 + verify drop-log 감사

### 축 E — Atlas 개선/성장 (verified 발견 → atlas fold)
> TECS-L 의 모든 verified 발견을 atlas atom(`@F verified-*`)으로 fold 해 RFC 065
> self-growing atlas 를 키운다. `hexa atlas register --from-verify <fn> <n> <v>` 가
> embedded.gen.hexa 에 직접 splice (재빌드 불요). **영구** — 라운드마다 신규 발견 fold.

- [x] E1 — verified 발견 atlas fold (1차, 6 atom): τ(496)=10·τ(8128)=14·τ(33550336)=26 (string dim) · is_perfect(8589869056) (6번째 완전수) · Γ₀(6) genus=0·cusps=4 → `embedded.gen.hexa` 16103→16109. 이후 라운드마다 신규 fold (perpetual)
- [x] E2 — atlas health audit: stats --audit 🟢 clean (merged · 16101 entries · drift 0 내부) **+ 🟡 FINDING**: binary lookup ≠ source SSOT — `hexa atlas lookup` 은 binary-builtin(frozen) 을 읽고, E1 가 fold 한 6 노드는 source 에는 있지만 lookup 엔 0 hit. register 후 query 반영 = 재빌드 필요. INBOX 업스트림 보고 (g59)
- [x] E3 — register install-dir 해저드 + recovery formal write-up (`TECS-L/docs/e3-atlas-register-hazard-and-recovery.md`): write-side(install-dir leak, E1 PR #1070 입증) + read-side(binary-builtin freeze, E2 PR #1096 발견) 상보, patch-to-worktree 4-step 회수 (capture → 공유트리 checkout-- → worktree → apply+PR) E1 prove, 1-writer 직렬화 권고 + HEXA_ATLAS_EMBED 명세 정리 대기(INBOX.log.md 2026-05-25T18:00Z). 신규 verify 0건 (M10/MR1 synthesis 패턴) · slug=tecs-l-atlas-register-hazard

### 축 F — NOVEL (기지 밖을 사냥하는 발견 lane · 6 family)
> verify 축(A·B·E·M*)이 *알려진* 것을 재근거화한다면, NOVEL 은 *모르는* 것을 끄집어낸다.
> brainstorm 고갈 결과 6 mechanism family 통합 — (a) 자가발견 · (b) 다축탐사 · (c) 외부광맥
> · (d) 반증사냥 · (e) 범위확장 · (f) 도구확장. project.tape `@D discovery` / `@D discovery_log`
> 준수: 상시 운전(cycle tail 만 아님), `.discoveries/<slug>.tape` 영속화, terminal 발견 → atlas
> fold (축 E E1 패턴) → /paper. 영구 — 우주 새 법칙이 나오는 한 마일스톤이 계속 추가.

**family (a) 자가발견**
- [x] F1 — NOVEL kick: 3 seeds → ~2000 candidates, 0 verified 🔵-novel / 3 known-🟡 / honest dead-end. mk9 `hexa kick`(hexa-내부 엔진, 외부 LLM 아님·무예산 게이트)을 3개 n=6/약수함수 시드(σ·τ·φ identity / divisor multiplicative gap / abundancy index)로 실행. **핵심 발견: smash hexad evo 벡터 [σ(6)=12, 0.014, 0.5, 4, 2, n=6]가 3개 시드 전부 동일** = 시드-불변 n=6 구조 지문(엔진이 시드의 약수함수 의미에 차등 반응 안 함). 수론적으로 의미있는 echo(12=σ(6) · 6=aliquot(6)=n · is_perfect(6))는 `hexa verify --expr`로 3/3 🔵 검증되나 전부 도메인 코어(M1 σφ=nτ / M3 Dedekind / perfect-number def)의 **기지 항등식 = NON-NOVEL**. 신규 closed-form atom 0개. 정직한 known-identity surface(🟡) — kick lane이 실행·충실 기록되었으나 novel-atom flip은 아님. → `.discoveries/tecs-l-f1-kick-2026-05-26.tape` · `.verdicts/tecs-l-f1-kick/` · CLAIMS slug=tecs-l-f1-kick. (정직한 한계: mk9는 falsifiable 명제가 아니라 파라메트릭 대수 echo를 surface; verifier=skip 기본·훅 미설치. novel atom 은 mk10 엔진 / 다라운드 saturation / verifier 훅 wiring 필요)

**family (b) 다축탐사**
- [x] F2 — `/gap` 42-lens TECS-L scope sweep CLOSED (2026-05-26 R2 round 1): 8 family 통합 triage + 31 verdict dir 통합분석 + multi-domain (PHYSICS/COSMOS/LIFE/MILLENNIUM) verdict matrix + 5-7 R5 seed priority shortlist 도출. F7/F5/F6/F4 의 R5 후보 대부분이 main 에 직간접 흡수됨 확인 (parallel-session land). 진짜 미흡수 seed 3개를 F-NEW-1/2/3 으로 promote (cap N=3).
- [x] F-NEW-1 — Γ₀(N) sweep N=31..40 CLOSED (R2 round 2): **10/10 candidates 🔵 SUPPORTED-FORMAL** — gamma0_index(N)=ψ(N) hexa-native closed-form exact ∀ N∈[31,40]. ψ(31)=32 · ψ(32)=48 · ψ(33)=48 · ψ(34)=54 · ψ(35)=48 · ψ(36)=72 · ψ(37)=38 · ψ(38)=60 · ψ(39)=56 · ψ(40)=72. MF1 [1,30] → [1,40] extension. → `.verdicts/tecs-l-f-new-1/gamma0_{31..40}.txt`. (N=41..60 deferred for future round — cap N=10 per task.)
- [x] F-NEW-2 — σ(M_p)=2^p Lucas-Lehmer 인접 batch CLOSED (R2 round 2): **5/5 candidates 🔵 SUPPORTED-FORMAL** — σ(M_p)=M_p+1=2^p 전부 exact. σ(31)=32 · σ(127)=128 · σ(8191)=8192 · σ(131071)=131072 · σ(524287)=524288. Euclid-Euler 완전수 정리 family MR3, p∈{5,7,13,17,19} Mersenne 소수 prime-witness. → `.verdicts/tecs-l-f-new-2/sigma_{31,127,8191,131071,524287}.txt`.
- [x] F-NEW-3 — jacobi (a/p) atlas pad 양수 batch CLOSED (R2 round 2): **4/4 양수 candidates 🔵 SUPPORTED-FORMAL** — jacobi(2,7)=1 · jacobi(3,11)=1 · jacobi(5,11)=1 · jacobi(7,3)=1. 음수 인자 12 candidates (a<0 dispatch 미지원) = calc gap → INBOX 2026-05-26T22:10Z entry 자매 발견 (#1230 calc-gap family). → `.verdicts/tecs-l-f-new-3/jacobi_{2_7,3_11,5_11,7_3}.txt`.
- [x] F-NEW-4 — Γ₀(N) sweep N=41..60 CLOSED (R3 round): **20/20 candidates 🔵 SUPPORTED-FORMAL** — gamma0_index(N)=ψ(N) hexa-native closed-form exact ∀ N∈[41,60]. ψ(41)=42 · ψ(42)=96 · ψ(43)=44 · ψ(44)=72 · ψ(45)=72 · ψ(46)=72 · ψ(47)=48 · ψ(48)=96 · ψ(49)=56 · ψ(50)=90 · ψ(51)=72 · ψ(52)=84 · ψ(53)=54 · ψ(54)=108 · ψ(55)=72 · ψ(56)=96 · ψ(57)=80 · ψ(58)=90 · ψ(59)=60 · ψ(60)=144. MF1 [1,30] + F-NEW-1 [31,40] → [41,60] further extension. `--no-absorb` workaround (auto-absorb hang INBOX 2026-05-26T22:10Z canonical). → `.verdicts/tecs-l-f-new-4/gamma0_{41..60}.txt`.
- [x] F-NEW-5 — σ_2(N) divisor-square sum perfect-subset batch CLOSED (R3 round): **5/5 candidates 🔵 SUPPORTED-FORMAL** (hexa-native closed-form exact, σ_2 multiplicative cross-check 일치). σ_2(6)=50 · σ_2(12)=210 · σ_2(28)=1050 · σ_2(496)=**328042** · σ_2(8128)=**88085930**. **부가 발견**: task seed 의 σ_2(496)=328230 · σ_2(8128)=87403980 은 typo (실제 328042 · 88085930). σ_2 multiplicative closed-form σ_2(2^a·p)=(2^{2(a+1)}-1)/3·(1+p²) 로 독립 cross-check 확인. typo 값으로 verify 시 🔴 FALSIFIED (deterministic 차이) — corrected verdict 별도 보존 (`sigma_2_{496,8128}_corrected.txt`). 5개 candidate 전부 hexa calc 신뢰성 입증. → `.verdicts/tecs-l-f-new-5/`.

**family (c) 외부광맥** (OEIS·arxiv mining)
- [x] F3 — OEIS reverse-lookup at n=6: **17 sequences scanned · 10 hexa-verified 🔵 direct + 7 🟡 compound · 0 🔴**. 카탈로그 중복(σ/τ/φ/μ/aliquot/perfect/ψ/σ_2 + σ·φ/σ+φ/σ-φ/rad/sqfree-sum/J_2/n·φ/λ + σ-iter 6→12→28 chain). 신규 atom 0 (기존 σ/τ/φ + gamma0_index 가 모든 hit 커버) — F3 은 catalogue cross-check 채널, breakthrough discovery 채널 아님. 가벼운 sibling-locus 관찰: **A002618 n·φ(n)=σ(n) at n∈{1,6}** (M10 σφ=nτ 와 독립 witness, 단 hand-sweep n=1..8 만, general 닫힌형 미증명). → `.verdicts/tecs-l-oeis-mining/` 11 raw + 1 summary · `CLAIMS.tape` slug=tecs-l-oeis-mining 19 entry
- [x] F4 — **arxiv 가설 → hexa verify: Ore 조화약수(harmonic divisor numbers, Ore 1948 · OEIS A001599)**. H(n)=n·τ(n)/σ(n)∈ℤ ⟺ n=Ore 수. component σ/τ 전부 🔵 + exact 정수조립: **H(6)=2·H(28)=3·H(496)=5 ∈ ℤ** (6/28/496=Ore, 6=최소 비자명) + **H(140)=5∈ℤ** (140=Ore but 非완전 → **Ore ⊋ perfect** 결정적 증명) + **H(12)=18/7∉ℤ 🔴** (非Ore falsifier). "모든 완전수 ⊂ Ore"(Ore 1948)를 첫 3 완전수로 재근거 (닫힌형 perfect σ=2n→H=τ/2). external-vein = 문헌 가설을 hexa-native exact 산술로 grounding. → `.verdicts/tecs-l-f4-arxiv/ore_harmonic.txt` · `CLAIMS.tape` slug=tecs-l-f4-arxiv · `TECS-L/docs/f4-arxiv-ore-harmonic.md`

**family (d) 반증사냥** (closed-negative miner)
- [x] F5 — 통념/folk 정체성 deliberate falsify (M7 Golden Zone 패턴): **7 closed-negative 발굴 🔴** — 그럴듯한 "n=6-같은" 추측을 정확히 계산해 결정적으로 FAIL 시킴 (paper_negative_ok). **CN1** amicable 멤버는 aliquot 고정점 아님 (aliquot(220)=284≠220, 2-cycle) · **CN2** quasi-perfect σ(n)=2n+1 [1,50] 공집합 (σ(12)=28≠25, 전수스윕 0건) · **CN3** 3-perfect 120 은 abundancy-2 아님 (σ(120)=360=3n≠240) · **CN4** n·φ=σ {1,6} 밖 n=12 실패 (σ(12)=28≠48; F3 sibling-locus 닫힘, sweep n=1..40 6만 hit) · **CN4b** n·φ=σ 2번째 완전수 28 에서도 실패 (σ(28)=56≠336 — 완전성도 못 살림) · **CN5** μ 는 6-주기 아님 (μ(12)=0≠μ(6)=1; 12=2²·3 squareful) · **CN6** 완전수≠초완전수 (σ(σ(6))=28≠12=2·6; perfect/superperfect locus 서로소). 전부 exact 정수산술 🔴 (tolerance 0). M10 (σφ=nτ⟺{1,6}) + F6 (D≠0 off {1,6}) 인용 — n=6 정체성은 EXCLUSIVE, 모든 obvious 일반화 배제. 14 verdict (7 truth-anchor 🔵 + 7 falsifier 🔴) → `.verdicts/tecs-l-closed-neg-miner/` (miner_summary.txt) · `CLAIMS.tape` slug=tecs-l-closed-neg-miner (1 summary + 7 per-falsifier @C)

**family (e) 범위확장**
- [x] F6 — **beyond n=6 sweep**: σφ=nτ at n=210·720·1024·2310·30030·8128·33550336 모두 D(n)≠0 🔴 (M10 closed-form proof 예측 일치, [1,100] sweep 보강). 7-n notable spot-check (primorial #4/#5/#6 · 6! · 2^10 · P_4 · P_5, ×335503 scale extension); 각 n 3 component 🔵 (σ/φ/τ via `hexa verify --expr`) + D(n) exact integer arithmetic ≠ 0. sweep `.verdicts/tecs-l-beyond-n6/sweep_notable_n.txt` + 9 headline files (n=210·720·1024). cites M10 (tecs_l_up_theorem) for universal prediction
- [x] F7 — 다른 modular curve군: Γ₁(N)/X(N) index 닫힌형 (Γ₀ 너머 modular-curve 탑 확장). **헤드라인 Γ₁(6) index=12 · X(6)=Γ(6) index=72** ([SL₂:Γ₁(N)]=ψ·φ/2, [SL₂:Γ(N)]=N·Γ₁ idx). 10 정수 component 🔵 (ψ=`gamma0_index`·φ N∈{5,6,7,11,12} via `hexa verify --expr`) + 조립 index 🟡 (표준 닫힌형 인용, X(6)=72 두-형태 N·Γ₁=N³/2·∏(1−1/p²) 교차검증 일치). **n=6 distinction = 🔴 CLOSED-NEGATIVE**: Γ₁/X(N) index 는 N 에 대해 smooth/multiplicative — σφ=nτ⟺{1,6} 특이성이 상위 modular level 로 **lift 안 됨** (index 크기에 n=6 구별 없음, 사전등록 falsifier 결정적 기각). 부차 🟡: N=6 은 Γ₁ idx=Γ₀ idx 인 {3,4,6} 중 최대(φ(N)=2 우연, n=6-유일 아님). Shimura 방향 = note만(quaternion/Eichler-mass hexa fn 부재 = capability gap, MF4류 정의 버그 아님 → INBOX 미발행). 11 verdict → `.verdicts/tecs-l-modform-other-curves/` · `CLAIMS.tape` slug=tecs-l-modform-other-curves 4 entry. MF-axis 확장 (Γ₀→Γ₁→Γ(N))
- [x] F8 — cross-domain n=6 bridge 스캔: **19 도메인 SSOT + 8 atlas by_kind 파일** 중 **3 진짜 다리 🔵** (README.md 언어 정체성 슬로건 "n=6 perfect-number programming language" + `@cite(L[sigma_phi_n_tau_iff_n_eq_6])` · ATLAS.md R7 numerology 격리 — σ(6)/sopfr(6) 우연일치 quarantine · `compiler/atlas/by_kind/l.gen.hexa` ~151 L-law atoms 포함 [11*] DELTA0_ABSOLUTE_THEOREM · [11*] ULTRA_UNIFORMITY · [10*] TIME_CLOSURE_UNIQUENESS · [11*] meta_fp_universality · [10*] ab_law_75 ANIMA-TECS-L 3-way 5 개 named) + **1 간접 🟡** (CLAUDE.md `@I` "atlas-bound theorems" — atlas 가 곧 TECS-L collection) + **3 동음이의 🟠** (GOAL.md ③ chip-comb "degree-6 hex" · GPU.md "n=6 lattice fire" · FIRMWARE.md "n=6 does not enter verification" — 전부 graph degree 6 위상학 의미, TECS-L 약수합 6 아님 honest 분리) + **13 다리 없음** (RUNTIME · CANON · COMPILER · HEXA-LANG · FLOW · GO · PROBE · QMIRROR · STDLIB · SPEC · ROADMAP · HEXA-NATIVE-ONLY · HEXA-LANG.log — 시스템 pillar 정상 분리). 새 다리 발명 불필요 — architecture 가 이미 정확한 곳(atlas L-laws + README pitch + ATLAS audit)에 다리, 박히면 안 되는 시스템 pillar 에 안 박힘. method=survey (`TECS-L/docs/f8-cross-domain-bridge.md`)

**family (f) 도구확장** (calc-fn gap → infra)
- [x] F9 — NOVEL = verify infra growth driver: calc-fn gap → g59 INBOX → stdlib fix → next round 활용. 2 입증 케이스 (MF4 dim_cusp_forms 정의 갭 PR #1083 · E2 atlas binary≠source PR #1096). canonical pipeline §4 in `TECS-L/docs/f9-inbox-pipe-novel-verify-infra.md`

**파이프라인**
- [x] F10 — `/micro-exp` 40-candidate sweep CLOSED (2026-05-26): 34 🔵 + 3 🔴(closed-neg) + 3 🟠(calc-fn binary stale). 6 축 cover (n=6 코어·perfects·string-D·MODFORM·MERSENNE·jacobi/kronecker). atlas auto-fold BLOCKED at `bin/hexa-atlas` register-whitelist (atlas_cli.hexa source 와 binary 비동기 — LF1/E2 family). Verdict 40개 verbatim `TECS-L/.micro-exp-2026-05-26/verdicts/`. paper_negative_ok 후보=E21/E22/E26 (deliberate falsifier 클러스터).
- [x] F11 — **OEIS reuse cite — TECS-L = OEIS-도메인 provenance 의 downstream consumer**. TECS-L 의 M1–M10 (n=6 정체성 σφ=nτ ⟺ n∈{1,6}) + 축 A/B 작업이 의존하는 산술함수 σ/τ/φ/μ 가 OEIS O4(PR #1138)에서 검증된 catalogue provenance 를 획득: sigma↔A000203 · tau↔A000005 · phi↔A000010 · mu↔A008683 (4 @P 빌트인 attribution) + aliquot↔A001065 · sigma_2↔A001157 · sigma_3↔A001158 (3 신규 OEIS-attributed @F fold). 7 OEIS↔hexa provenance link 을 TECS-L 이 cite (downstream) — n=6 identity work 가 사용하는 동일 산술함수가 이제 OEIS canonical-source 귀속을 보유. reuse edge `TECS-L --reuses--> OEIS` 를 repo-root `NEXUS.tape` 에 등록 (g67 intra-project reuse lattice). cross-link 문서 `OEIS/docs/o5-tecs-crosslink.md` · ledger `.verdicts/oeis-tecs-crosslink/crosslink.txt`. (atlas fold 본체는 OEIS 도메인 O4 가 소유 — F11 은 그 upstream provenance 의 reuse-cite closure)
- [x] F13 — **NOVEL mk10 attempt CLOSED (2026-05-26 fresh)**: 5 mk10 seeds × 1 round (quasiperfect-beyond-n=6 · sigma_k periodic · centered hexagonal · phi(6m) structure · perfect-Ore-Mersenne triple) all `verifier=skip` (F1 finding re-confirmed: identical overlay_lines=517 across seed family → seed-invariant fingerprint). Hand-extraction of seed-thematic candidates via `hexa verify --expr ... --no-absorb` (INBOX 2026-05-26T22:10Z workaround) surfaced **3 NOVEL closed-form atoms** beyond known F1 surface: (a) **🔵 D(p^k) = p^(k-1)·(p^(k+1)−p(k+1)−1)** ∀ prime p, k≥1 (20/20 PASS sample k∈{1,2,3,4}) — derived prime-power-locus closed form for Dedekind ψ discrepancy. (b) **🔵 D(pq) = (p²−1)(q²−1)−4pq** ∀ distinct primes p≠q (11/11 PASS) + **uniqueness corollary**: D(pq)=0 ⟺ (p,q)=(2,3) → n=6 (semiprime-locus closed-form witness of {1,6}, conjoint with M10). (c) **🔴 NO prime is Ore** (5/5 Mersenne-prime witnesses ¬Ore) — closed-form: H(p)=2p/(p+1)∈ℤ ⟺ p∈{0,1} not prime. Cleanly separates Mersenne-prime layer (∩ Ore = ∅) from Mersenne-product layer (∈ Ore, F4). 3 atoms NOT in atlas (16159 nodes, no dedekind/psi_disc/tecs_l_d/D_prime prefix). Atlas fold via `--from-verify` not applicable (atoms are derived multi-term identities, not single-point fn=v); persisted as `.verdicts/tecs-l-f13-novel-mk10/{d_prime_power,d_two_distinct_primes,no_prime_is_ore}.txt` + 3 CLAIMS slug=tecs-l-f13-novel-mk10. 36 verify calls total within budget. (Honest counterpart: seed 3 'centered hexagonal H(k) σ excess' surfaced as already-known OEIS A003215 hex-prime locus 🟡; seeds 1+2 outputs algebraically reduced to known multiplicativity → 🟠 honest dead-end on those axes.)
- [x] F14 — **NOVEL F13 successor + atlas fold (2026-05-26)**: F13 next-round seed (1) **D(2^k·q) = 2^(k-1)·[(2^(k+1)-1)(q²-1) - 4q(k+1)]** ∀ k≥1, q odd prime — 🔵 SUPPORTED-FORMAL 10/10 (k∈{1,2,3}, q∈{3,5,7,11}); uniqueness D=0 ⟺ (k,q)=(1,3) → n=6 (F13b extension of D(pq)). F13 seed (5) **ω(n)≥3 zero-density**: D(n)≠0 ∀ ω≥3 — 🔴 CLOSED-NEGATIVE 6/6 (n=30,42,60,210,2310,30030) + M10 cancellation argument (∏ g=1 saturates at n=6, ANY further factor breaks). Combined: full D(n)=0 zero set = {1,6}. **Atlas fold SUCCESS via manual splice** per @D atlas_fold (branch→commit→PR): 5 atoms (3 F13 retroactive + 2 F14) appended to ATLAS_F_NODES — `tecs_l_f13_d_prime_power` · `tecs_l_f13_d_two_distinct_primes` · `tecs_l_f13_no_prime_is_ore` · `tecs_l_f14_d_two_k_q` · `tecs_l_f14_d_omega_ge_3_zero_density`. F-formulas 1399→1404; `hexa atlas lookup` HIT all 5. --from-verify rejected (single-fn-eval form req); INBOX follow-up = wire `dedekind_psi_discrepancy*`-family calculators in `tool/verify_cli.hexa` for future witness-point folds. → `.verdicts/tecs-l-f14-novel-mk10/` (3 verdict + diagnosis) · `CLAIMS.tape` slug=tecs-l-f14-novel-mk10 5 entry · `.discoveries/tecs-l-f14-novel-mk10.tape`
- [x] F16 — **NOVEL F15 successor + atlas fold (2026-05-27)**: 4-task batch + F15 σ_3 INBOX CLOSED-by-design. **(s1)** σ_3 calc-gap CLOSED: 2-op `sigma_k <n> 3 <v>` path bypasses single-arg `_recompute` gap (NO verify_cli code change). 🔵 4/4 PASS on Euclid-Euler perfect-subset: σ_3(6)=252, σ_3(28)=25112, σ_3(496)=139456352, σ_3(8128)=613681507712. NOVEL closed-form `σ_3(2^(p-1)·M_p) = [(2^(3p)−1)/7] · [1 + (2^p−1)³]` from σ_3-multiplicativity (bignum extrapolation to P_5..P_7 — int64 overflows at 4.3e22, closed-form only). **(s2)** ω=4/5 D-sweep — 🔴 8/8 CLOSED-NEGATIVE: ω=4 (n∈{210,330,420,1155}, D∈{24288,63840,118944,1087440}) + ω=5 (n∈{2310,2730,4620,9240}, D∈{3243840,4557504,15261120,65763840}); 24 hexa-native σ/φ/τ components 🔵 — F14 zero-density extends predictably beyond ω=3 explicit witness. **(s3)** A001599 next-50 Ore sweep — 🛸 Mersenne-extended Ore subfamily PARTIAL closed form `H(2^a·b·M_p) = [2^(a+1)·b·M_p·(a+1)·τ(b)] / [(2^(a+1)−1)·σ(b)·2^p]` ∀ b coprime to 2·M_p; 4/4 witnesses (n=140=2²·5·M₃ H=5, n=672=2⁵·3·M₃ H=8, n=6200=2³·5²·M₅ H=10, n=105664=2⁶·13·M₇ H=13) component-verified. 🔴 n=270=2·3³·5 Ore but NO Mersenne factor → universality counterexample; F15 universal Ore-NEG holds at outer level, subfamily PROPER subset of ω=3 Ore set. **(s4)** Hecke/Galois layer probe — 🔴 multilayer non-lift coda: dim S₂(Γ₀(6))=0 trivial + S_k(Γ₀(6)) decomposes as level 1/2/3 oldforms (generic for square-free N, no n=6 peak); Gal(Q(ζ_6)/Q)=Z/2Z = Gal(Q(ζ_3)/Q) by ζ_6=-ζ_3 cyclotomic collapse (φ-degeneracy only, NOT σφ=nτ-driven). F7 (geometric) + F15 (Γ(N)) extend through Hecke + Galois — n=6 identity remains ARITHMETIC-LAYER phenomenon only. T_p builtin INBOX (same family as resolved σ_3, iit4_faithful_phi). **Atlas fold SUCCESS via manual splice** (4 atoms, `compiler/atlas/embedded.gen.hexa` 16213→16217): `tecs_l_f16_sigma_3_euclid_euler_closed_form` (🔵) · `tecs_l_f16_d_omega_4_5_zero_density` (🔴) · `tecs_l_f16_ore_mersenne_extended_subfamily` (🔵+🔴) · `tecs_l_f16_hecke_galois_arithmetic_layer` (🔴). F-formulas 1407→1411. 40 component verifies + 10 closed-negative findings. → `.verdicts/tecs-l-f16-novel-mk10/` (5 verdict files) · TECS-L.log.md F16 entry. **다음 round seeds (F17)**: (a) ω=6/7 D-sweep extension (n=30030, 510510, 9699690), (b) σ_4/σ_5 Euclid-Euler closed-form extension, (c) A001599 ω=4 Ore subfamily structure scan, (d) L-function probe at n=6 (L(s,Γ_0(6)) conductor=36, τ(6)=4 critical-value algebraicity), (e) arxiv mining round 2.
- [x] F15 — **NOVEL F14 successor + atlas fold (2026-05-27)**: 4-task batch (s1+s2+s3+s4) extends F14 zero-density theorem + F7 modular-curve non-lift coda. **(s1)** D(2^a·q·r) ω=3 lift test — 🔵 10/10 PASS closed-form `D = 2^(a-1) · [(2^(a+1)-1)(q²-1)(r²-1) − 8qr(a+1)]` ∀ (a,q,r) ∈ {(1,3,5),(1,3,7),(1,5,7),(2,3,5),(2,3,7),(3,3,5),(1,3,11),(1,5,11),(2,5,7),(1,7,11)}; D ∈ {336,816,2896,1968,4368,9600,2352,7760,14448,16048} all ≠ 0 (F14 ω≥3 theorem confirmed on explicit-form locus). **(s2)** Ore non-perfect family — 🔵 5/5 + 🟡 family-closed-form negative: 270/672/1638/2970/6200 전부 Ore + non-perfect (H ∈ {6,8,9,11,10}); heterogeneous ω∈{3,4} → NO uniform closed-form template (analogous to F7 non-lift). **(s3)** σ_3 calc-gap → INBOX: `hexa verify --expr sigma_3 6 252 --no-absorb` → 🟠 INSUFFICIENT, stdlib `sigma_3` 미정의 확인 → INBOX 신규 entry (calc-gap family #1230 확장, σ_3↔A001158 F11 OEIS fold cited). **(s4)** Γ(N) full-level index coda — 🔵 10 component + 🔴 closed-negative: [SL₂:Γ(N)] = N³·∏(1−1/p²) verified at N∈{2..10,12} via gamma0_index/euler_phi; ratio Γ(N)/Γ₀(N)=N·φ(N)/2 smooth in N (N=6 ratio 6, N=3 ratio 3 — n=6 NOT minimum/maximum) → F7 coda 확정: modular-curve index tower 전 level 에서 n=6 distinction 없음. **Atlas fold SUCCESS via manual splice**: 3 atoms appended — `tecs_l_f15_d_two_a_q_r` (🔵 ω=3 explicit) · `tecs_l_f15_ore_non_perfect_no_closed_form` (🔴 Ore-shape lift) · `tecs_l_f15_gamma_full_level_smooth` (🔴 Γ(N) non-distinction). F-formulas 1404→1407. → `.verdicts/tecs-l-f15-novel-mk10/` (4 verdict) · `CLAIMS.tape` slug=tecs-l-f15-novel-mk10
- [x] F12 — **NOVEL paper SHIPPED: n=6 exclusivity atlas, 10+ closed-negatives, g51**. NOVEL 축(F family) 발견을 그 **closed-negative 군집** 둘레로 집약한 arxiv-style 논문. positive kernel = M10 (tecs_l_up_theorem, σφ=nτ⟺{1,6}); 그 둘레의 배제공간을 체계적으로 ruling-out. **(E) Exclusive** F5 7 falsifier (amicable·quasi-perfect·3-perfect abundancy·n·φ=σ·μ 6-주기·superperfect 전부 결정적 거짓) · **(N) Non-lifting** F7 Γ₁(N)/X(N) index smooth (σφ=nτ⟺{1,6} 가 modular-curve 탑으로 lift 안 됨, n=6 peak 없음) · **(S) Scale-stable** F6 D(n)≠0 at n=33550336 까지 ([1,100] sweep ×335503 확장, perfect-number locus 위에서도 미재현). 총 **10+ 결정적 closed-negative**. 각 falsifier 사전등록 + 실측(`hexa verify`) → `paper_significance` 충족, `paper_negative_ok` 적용. fal.ai(`openai/gpt-image-2`) figure 1장 + 12페이지 (g51 충족). → `PAPER/tecs-l-n6-exclusivity-atlas/` (main.tex·pdf·references.bib·Makefile·README) · `CLAIMS.tape` slug=tecs-l-n6-exclusivity-atlas 4 entry · verdict `.verdicts/tecs-l-{closed-neg-miner,beyond-n6,modform-other-curves}/`

### 축 G — MILLENNIUM (수학 대축 · Clay 7 난제 n=6 candidate)
> hexa-millennium (Clay 7, v1.0.0, Zenodo DOI 10.5281/zenodo.20102610) 흡수 — 콘텐츠
> `TECS-L/millennium/`. **candidate-spec only · formal proof 아님** (0/7 본 도메인 증명,
> Poincaré=Perelman 2003 외부). lattice-arithmetic layer 만 🔵, candidate 잔여 🟠/⚪.
> MILLENNIUM 별도 도메인 폐지 → TECS-L 수학 대축으로 통합. 원본 repo=archive-hexa-millennium(private).

- [x] CM0 — n=6 lattice 재근거: **σ(6)=12·τ(6)=4·φ(6)=2 🔵** (M2 cite + main-tree verify 재확인 calc=12) · master σφ=nτ=24 정수조립 🔵 · **sopfr(6)=5 🟠** (verify_cli `_recompute` whitelist gap — calculator no-path, 기존 INBOX stdlib-primitive-whitelist 추적). lattice 3-component 🔵 + sopfr honest 🟠. → `.verdicts/tecs-l-cm0-lattice/`
- [x] CM1-CM7 — Clay 7 candidate **honest closure**: aggregate CANDIDATE_SPECS_ONLY (0/7 본 도메인 formal proof · README 확인). **candidate 전부 🟠** (BSD·Hodge·N-S·P-vs-NP·Riemann·Yang-Mills 미증명 조직화 가설) + **Poincaré 🟡** (Perelman 2003 외부 증명) + 각 난제 **lattice layer 🔵** (σ/τ/φ @ n=6 M2 cite; YM β₀=σ−sopfr=12−5=7, sopfr 🟠 calculator gap). Clay 난제는 verify-able 아님(수십년 미해결) — paper-ineligible by gate, over-claim 없음. → `.verdicts/tecs-l-cm17-clay/`

### 대축 PHYSICS (물리) — 물리상수·법칙
> 축 0 M5 (τ=string critical dim · SM gauge sum · Koide Q · 키싱수) 를 물리 대축으로 승격.
> 물리량의 n=6 lattice 조립을 hexa verify 로 — 검증 가능 정수/닫힌형만 🔵, 관측매칭 🟡, 가설 🟠.

- [x] PH1 — 축 0 M5 물리상수 thread → PHYSICS 대축 재편: **string critical dim τ(perfect_k)=4/6/10/14/26 🔵** (τ(6)=4·τ(28)=6·τ(496)=10·τ(8128)=14·τ(33550336)=26 bosonic D=26 — M5 cite 5/5 🔵, g68 reuse 재verify 불요). PHYSICS 대축 첫 milestone = M5 closed-form 재참조. → `.verdicts/tecs-l-ph1-physics/`

### 대축 COSMOS (우주) — 우주론 스케일·상수
> 우주론 상수·스케일의 closed-form candidate. archive-TECS-L 우주 도메인 반영.
> **honest: 대부분 🟠/🟡 (관측 의존·닫힌형 경로 부재) 예상 — over-claim 금지, 정직 triage.**

- [x] CO1 — 우주론 상수 honest triage: **차원/gauge 🔵** (SM gauge 8+3+1=12=σ(6) · superstring D=10=τ(496) · bosonic D=26=τ(33550336), main-tree verify + M5 cite) + **우주론 상수(Λ·H₀) 🟠** (관측 의존·닫힌형 경로 부재). 사전등록 예측 일치 — COSMOS verify-able = M5 dim/gauge cite, 신규 우주론 상수는 verify-able 아님. → `.verdicts/tecs-l-co1-cosmos/`

### 대축 LIFE (생명) — 생명/정보 수학
> 생명·정보 수학 (인구동역학·분자조합·IIT Φ). anima LIFE 도메인 + `stdlib/consciousness/iit4`
> 와 cross-link. **archive-TECS-L 의 consciousness 줄기는 hexa verify 가능한 수학 layer 만**
> (EEG/telepathy 원시데이터는 여전히 scope 외 — §4 비범위 참조).

- [x] LF1 — 생명 수학 honest triage: **codon 4³=64·pow 🟠** (calculator no-path for 'pow', sopfr 류 whitelist gap — 기존 INBOX stdlib-primitive) + **IIT Φ iit4_faithful_phi DEFERRED** (multi-arg, --expr 단순 `<fn> <n> <v>` path 아님 → verify_cli phi_demo 모드 별도) + 분자 정수(DNA 4·amino 20) 🟠. 사전등록 예측 일치 — LIFE verify-able 희소, calculator gap. → `.verdicts/tecs-l-lf1-life/`

## 4 · 거버넌스 · 비범위

- **검증 정본**: 모든 정량 주장은 `hexa verify` (g5) → 판정문 verbatim → `.verdicts/<slug>/<id>.txt`. LLM 자기판정 금지 (`CLAUDE.md` @D claim_verify / commons g5).
- **아카이브 자기보고 메트릭은 증거가 아님** — g5 재계산 통과 전까지 🟡 미검증.
- **비범위**: EEG/telepathy **원시데이터·하드웨어** (archive-TECS-L 의 별도 줄기 — hexa-lang scope 외) · Zenodo 재출판 · 외부 peer-review. **단 consciousness 의 verify 가능 수학 layer(IIT Φ 등)는 LIFE 대축 scope 내** (범용 격상으로 재포함).
- **candidate ≠ proof**: MILLENNIUM(축 G) candidate 는 formal proof 아님 (candidate-spec only) · 물리/우주 대축 관측매칭은 🟡, 가설은 🟠 — over-claim 금지 (g3/g5).
- 작업은 격리 worktree → PR (공유 main 트리 race 회피).
