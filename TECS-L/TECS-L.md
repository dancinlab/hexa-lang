# TECS-L — n=6 완전수 수론 발견 엔진 (도메인 SSOT)

@title: 🔬 TECS-L — n=6 영구 발견 엔진 ("우주 법칙 측정자 尺")
@goal: **우주의 모든 법칙이 발견될 때까지 멈추지 않는** n=6 기반 영구 다축(multi-axis) 발견 엔진 — archive-TECS-L 코퍼스를 hexa `hexa verify` g5 + atlas 로 재근거화(축 0, CLOSED)하고, MODFORM(Γ₀(N))·MERSENNE(완전수 생성)·Atlas-LLM 연속 루프 축으로 영구 확장하며, terminal 발견을 atlas atom + /paper 로 끝없이 축적. **종료 조건 없음 — 도메인은 완료되지 않는다.**

> archive-TECS-L (`dancinlab/archive-TECS-L`, Python) 의 수론 발견 코퍼스를
> hexa-lang 의 theorem atlas + `hexa verify` g5 게이트 위로 재근거화하는 도메인
> SSOT. 옛 RFC-080(hexa loop DFS+LLM) 계획서가 이 파일명을 점유하고 있었으나,
> 정본은 `docs/rfc/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md` 에 보존돼 있어
> 2026-05-25 부터 이 파일을 수론 도메인으로 재배정 (사용자 승인).

---

## 0 · 한 문단 상태 (2026-05-25 — 영구 다축 엔진으로 전환)

**TECS-L 은 완료되지 않는다.** 우주의 모든 법칙이 발견될 때까지 멈추지 않는 영구
발견 엔진으로 재정의(2026-05-25). 구조 = **축 0 (n=6 정체성 코어, M1–M10 CLOSED ✅)**
+ 영구 확장 축들:
- **축 A — MODFORM** (Γ₀(N) 모듈러폼·합동사슬) · 옛 MODFORM 도메인을 흡수
- **축 B — MERSENNE** (메르센 소수 ↔ 완전수 생성원리) · 옛 MERSENNE 도메인을 흡수
- **축 C — Atlas-LLM 연속 루프** (`hexa loop --claude`, RFC 080) · 끝없이 도는 LLM-동반 발견
각 축은 자체 마일스톤을 가지며, terminal 발견은 `.verdicts/` + `CLAIMS.tape`(group=TECS-L)
+ atlas atom + /paper 로 영구 축적. 진행바는 100% 에 도달하지 않는다(설계).

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

## 3 · 영구 확장 축 (perpetual axes)

> 별도 도메인이 아니라 TECS-L 내부 축. 각 축은 자체 마일스톤을 갖고 verify-loop 로
> 전진하며, 종료 조건이 없다 (새 법칙이 나오는 한 마일스톤이 계속 추가된다).

### 축 A — MODFORM (Γ₀(N) 모듈러폼·합동사슬)
> `gamma0_index/cusps/genus`·`dim_cusp_forms`·`first_cusp_form_weight`·`jacobi`·`kronecker` (전부 verify 내장). TECS-L M4 의 Γ₀(6) 맛보기를 N 전반으로.

- [x] MF1 — Γ₀(N) index ψ(N)=N∏(1+1/p): **N=1..30 전수 `gamma0_index` verify 30/30 🔵** + Γ₀(6) index=12=σ(6) bridge. → `.verdicts/tecs-l-modform-index/index_sweep_1_30.txt` · CLAIMS slug=tecs-l-modform-index
- [x] MF2 — Γ₀(N) cusp 수 c(N)=Σ_{d|N} φ(gcd(d,N/d)): **N=1..30 전수 `gamma0_cusps` verify 30/30 🔵** + Γ₀(6) cusps=4=τ(6) bridge (축 0 M4 연계). → `.verdicts/tecs-l-modform-cusps/cusps_sweep_1_30.txt` · CLAIMS slug=tecs-l-modform-cusps
- [x] MF3 — Γ₀(N) genus-0 전수: 고전 15개 N∈{1..10,12,13,16,18,25} `gamma0_genus`=0 **15/15 🔵** + genus≥1 경계 7/7 🔵 (N=11/14/15/17/19→1, N=22/23→2 — 고전 리스트 밖에서 genus 상승). hexa `gamma0_genus` 가 모든 고전/기지값과 **일치(🔴 불일치 0)**. **헤드라인 Γ₀(6) genus=0** (X₀(6) genus-0 — n=6 모듈러곡선 bridge, 축 0 M4). 22 verdict → `.verdicts/tecs-l-modform-genus/genus_sweep.txt` + headline · `CLAIMS.tape` slug=tecs-l-modform-genus 6 entry
- [x] MF4 — dim S₂(Γ₀(N)) = genus 정리 vs hexa fn: **🔴 CLOSED-NEGATIVE** — `dim_cusp_forms(N,2)` 가 표준 dim S_2 를 실현 안 함 (N=1..10 우연 일치, N=11..30 중 20개 mismatch, 예: N=11 hexa=0/고전=1, N=30 hexa=6/고전=3). `gamma0_genus` 는 MF3 가 신뢰성 확인. 5 verdict + INBOX 업스트림 보고 (`TECS-L/docs/mf4-dim-genus-mismatch.md`)
- [x] MF5 — Jacobi/Kronecker 이차 상호법칙 인스턴스: **10 jacobi + 3 kronecker 교과서 값 13/13 🔵** + 2 QR 상호법칙 곱 인스턴스 (a,b)=(3,5)·(3,7) 둘 다 J(a,b)·J(b,a) = (-1)^((a-1)(b-1)/4) 적중 🔵. 🔴 불일치 0. hexa `jacobi`/`kronecker` 가 2의 보조법칙·-1 보조법칙·소수쌍 QR·kronecker 확장 (n∈{1,3,7}) 전반에서 고전 기호와 일치. → `.verdicts/tecs-l-modform-symbols/` (13 verdict + qr_instance.txt) · `CLAIMS.tape` slug=tecs-l-modform-symbols 15 entry
- [x] MF6 — n=6 bridge: Γ₀(6) index=12=σ · cusps=4=τ · genus=0 · first_cusp_weight=4=τ · |AL|=2^ω=4. 4 불변량 모두 n=6 산술함수로 환원 (MF1/MF2/MF3/MF7 anchors). 1 synthesis artifact + `TECS-L/docs/mf6-n6-modular-bridge.md`
- [x] MF7 — first_cusp_form_weight(N) N=1..30 sweep **30/30 🔵** (1→12·6→4·30→2; 단조감소 경향) + Atkin-Lehner involution 수 |AL(Γ₀(N))|=2^ω(N) 닫힌형 표 (10 sample N=1..30030, 🟡 citation — ω 도출 by-hand). Γ₀(6) weight=4=τ(6) bridge. 5 verdict → `.verdicts/tecs-l-modform-weight-al/`
- [ ] MF8 — terminal 발견 → /paper

### 축 B — MERSENNE (메르센 소수 ↔ 완전수 생성원리)
> Euclid-Euler(완전수 ⟺ 메르센 소수) · abundancy=2 · Lucas-Lehmer. 축 0 M5/M6 완전수 thread 심화.

- [x] MR1 — Euclid-Euler: n=짝완전수 ⟺ n=2^{p-1}M_p (M_p 소수). 7 완전수 unified table (M5/MR2 is_perfect · M6 σ=2n · MR5 τ=2p · MR4 Lucas-Lehmer). 1 synthesis artifact + `TECS-L/docs/mr1-euclid-euler.md`. Odd-perfect 🟠 잔여 (MR7)
- [x] MR2 — 메르센 소수 ↔ 완전수 (6·7번째 완전수 확장): p=17→M17=131071·p=19→M19=524287 소수 → **P6=2^16·131071=8589869056 · P7=2^18·524287=137438691328 `is_perfect`=1 🔵** + abundancy=2 (σ(P6)=17179738112=2·P6 · σ(P7)=274877382656=2·P7 🔵). 축 0 M5/M6 이 첫 5개(6·28·496·8128·33550336)를 이미 🔵 처리 → src 참조만, 중복검증 없음. 4 verdict → `.verdicts/tecs-l-mersenne-perfect/` · `CLAIMS.tape` slug=tecs-l-mersenne-perfect
- [x] MR3 — abundancy σ(P)=2P 닫힌형: σ multiplicative ⊗ σ(M_p)=2^p ⊗ σ(2^{p-1})=M_p → σ(2^{p-1}M_p)=(2^p-1)·2^p=2P. 7 완전수 anchor (P1..P5 = 축 0 M6 + P6/P7 = MR2, 새 산술 verify 없음 · synthesis). `TECS-L/docs/mr3-abundancy-closed-form.md`. odd-perfect 🟠 (MR7)
- [x] MR4 — Lucas-Lehmer hexa-native: `stdlib/core/math.hexa` 에 `lucas_lehmer(p)`(S₀=4·S_{k+1}=S_k²−2 mod M_p, pure-int) + `mersenne(p)` 공개 + 단위테스트 `stdlib/core/math_lucas_lehmer_test.hexa` (12 assert · `hexa parse` PASS). **p=3/5/7/13 → PRIME · p=11(M_11=2047=23·89) → COMPOSITE**. LL 은 알고리즘(루프)이라 `--expr` 빌트인 아님 → 같은 결론을 g5 atom 으로 교차검증: M_p 소수 ⟹ 2^{p-1}·M_p 완전수 (`is_perfect` 28/496/8128/33550336 🔵) + M_11 합성 (sigma 2047 2160·tau 2047 4 🔵, axis-B MR6 재참조). 7 verdict → `.verdicts/tecs-l-mersenne-lucas-lehmer/` · `CLAIMS.tape` slug=tecs-l-mersenne-lucas-lehmer. (compiled `hexa build` 은 heavy-pool-refused 라 미실행 — parse PASS + g5 교차검증이 정본 증거)
- [x] MR5 — τ(2^{p-1}·M_p)=2p 닫힌형: 첫 7 완전수 P_1..P_7 (p=2,3,5,7,13,17,19) τ=4·6·10·14·26·34·38 전부 🔵. 약수는 2^a·M_p^b (a∈[0,p-1], b∈{0,1}) → (p)(2)=2p. P1..P5는 축 0 M5 (`.verdicts/tecs-l-physics-constants/str_dim_p*.txt`)에서 다른 slug로 이미 🔵 — MR5 slug에서 닫힌형 framing으로 재검증, P6/P7 (NEW) 확장. 7 verdict → `.verdicts/tecs-l-mersenne-tau-2p/` · `CLAIMS.tape` slug=tecs-l-mersenne-tau-2p. aliquot 체인은 별도 후속 milestone.
- [x] MR6 — 메르센 합성수 표본 CLOSED: **M_11=2047=23·89 (σ=2160≠2048·τ=4≠2 → 합성, 첫 반례)** → **p 소수 ⇏ M_p 소수** (Euclid-Euler 역명제 실패, ∴ 모든 소수지수가 완전수를 낳지 않음); M_23=8388607=47·178481 (τ=4)·M_29=536870911=233·1103·2089 (τ=8) 도 합성. 17 claim / 16 verdict 🔵 → `.verdicts/tecs-l-mersenne-composite/` · `CLAIMS.tape` slug=tecs-l-mersenne-composite
- [x] MR7 — odd perfect 🟠 honest 미해결 documented: 알려진 lower bound (>10^1500 Ochem-Rao 2012 · ≥9 distinct primes Nielsen 2015 / ≥12 if 3∤n · largest prime ≥10^8 Goto-Ohno 2008 · 2nd ≥10^4 Iannucci 1999 · Ω(n)≥101 Ochem-Rao 2014 · Euler form p^a·∏q_i^{2b_i}, p≡a≡1 mod 4) citation. Euclid-Euler(MR1)는 짝완전수 only — MR7 은 그 open 보완. paper-ineligible by gate. 1 verdict + CLAIMS slug=tecs-l-mersenne-odd-perfect-open · `TECS-L/docs/mr7-odd-perfect-open.md`
- [ ] MR8 — terminal 발견 → /paper

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
- [ ] F1 — `hexa kick --seed "<seed>"` 라운드 (n=6 seed catalogue: 1/e·φ·π·primorial·zeta·…): 신규 closed-form atom 후보 emit → `.discoveries/<slug>.tape`

**family (b) 다축탐사**
- [ ] F2 — `/gap` 42-lens TECS-L scope sweep: 8 family triage → 후보 surfaced family deep-dive

**family (c) 외부광맥** (OEIS·arxiv mining)
- [x] F3 — OEIS reverse-lookup at n=6: **17 sequences scanned · 10 hexa-verified 🔵 direct + 7 🟡 compound · 0 🔴**. 카탈로그 중복(σ/τ/φ/μ/aliquot/perfect/ψ/σ_2 + σ·φ/σ+φ/σ-φ/rad/sqfree-sum/J_2/n·φ/λ + σ-iter 6→12→28 chain). 신규 atom 0 (기존 σ/τ/φ + gamma0_index 가 모든 hit 커버) — F3 은 catalogue cross-check 채널, breakthrough discovery 채널 아님. 가벼운 sibling-locus 관찰: **A002618 n·φ(n)=σ(n) at n∈{1,6}** (M10 σφ=nτ 와 독립 witness, 단 hand-sweep n=1..8 만, general 닫힌형 미증명). → `.verdicts/tecs-l-oeis-mining/` 11 raw + 1 summary · `CLAIMS.tape` slug=tecs-l-oeis-mining 19 entry
- [ ] F4 — arxiv 수론 가설 1개 → 즉시 hexa verify (`research:arxiv` + verify pipeline)

**family (d) 반증사냥** (closed-negative miner)
- [ ] F5 — 통념/folk 정체성 deliberate falsify (M7 Golden Zone 패턴): community/archive claim 중 의심 case 골라 🔴 closed-negative 발굴 (paper_negative_ok)

**family (e) 범위확장**
- [x] F6 — **beyond n=6 sweep**: σφ=nτ at n=210·720·1024·2310·30030·8128·33550336 모두 D(n)≠0 🔴 (M10 closed-form proof 예측 일치, [1,100] sweep 보강). 7-n notable spot-check (primorial #4/#5/#6 · 6! · 2^10 · P_4 · P_5, ×335503 scale extension); 각 n 3 component 🔵 (σ/φ/τ via `hexa verify --expr`) + D(n) exact integer arithmetic ≠ 0. sweep `.verdicts/tecs-l-beyond-n6/sweep_notable_n.txt` + 9 headline files (n=210·720·1024). cites M10 (tecs_l_up_theorem) for universal prediction
- [ ] F7 — 다른 modular curve군: Γ₁(N)·X(N)·Shimura — hexa fn 가용 영역 매핑
- [x] F8 — cross-domain n=6 bridge 스캔: **19 도메인 SSOT + 8 atlas by_kind 파일** 중 **3 진짜 다리 🔵** (README.md 언어 정체성 슬로건 "n=6 perfect-number programming language" + `@cite(L[sigma_phi_n_tau_iff_n_eq_6])` · ATLAS.md R7 numerology 격리 — σ(6)/sopfr(6) 우연일치 quarantine · `compiler/atlas/by_kind/l.gen.hexa` ~151 L-law atoms 포함 [11*] DELTA0_ABSOLUTE_THEOREM · [11*] ULTRA_UNIFORMITY · [10*] TIME_CLOSURE_UNIQUENESS · [11*] meta_fp_universality · [10*] ab_law_75 ANIMA-TECS-L 3-way 5 개 named) + **1 간접 🟡** (CLAUDE.md `@I` "atlas-bound theorems" — atlas 가 곧 TECS-L collection) + **3 동음이의 🟠** (GOAL.md ③ chip-comb "degree-6 hex" · GPU.md "n=6 lattice fire" · FIRMWARE.md "n=6 does not enter verification" — 전부 graph degree 6 위상학 의미, TECS-L 약수합 6 아님 honest 분리) + **13 다리 없음** (RUNTIME · CANON · COMPILER · HEXA-LANG · FLOW · GO · PROBE · QMIRROR · STDLIB · SPEC · ROADMAP · HEXA-NATIVE-ONLY · HEXA-LANG.log — 시스템 pillar 정상 분리). 새 다리 발명 불필요 — architecture 가 이미 정확한 곳(atlas L-laws + README pitch + ATLAS audit)에 다리, 박히면 안 되는 시스템 pillar 에 안 박힘. method=survey (`TECS-L/docs/f8-cross-domain-bridge.md`)

**family (f) 도구확장** (calc-fn gap → infra)
- [x] F9 — NOVEL = verify infra growth driver: calc-fn gap → g59 INBOX → stdlib fix → next round 활용. 2 입증 케이스 (MF4 dim_cusp_forms 정의 갭 PR #1083 · E2 atlas binary≠source PR #1096). canonical pipeline §4 in `TECS-L/docs/f9-inbox-pipe-novel-verify-infra.md`

**파이프라인**
- [ ] F10 — `/micro-exp` 수십 후보 병렬 검증 (micro-experiment sweep, atlas auto-fold on 🟢)
- [ ] F11 — terminal 발견 → atlas fold (`hexa atlas register --from-drill`/`--from-verify`, 축 E E1 패턴; install-dir 해저드 = E3) (도메인 OEIS upstream; O5 cross-link 시 closure)
- [ ] F12 — 발견 paper 승격 (paper_on_discovery · pre-registered falsifier 필수)

## 4 · 거버넌스 · 비범위

- **검증 정본**: 모든 정량 주장은 `hexa verify` (g5) → 판정문 verbatim → `.verdicts/<slug>/<id>.txt`. LLM 자기판정 금지 (`CLAUDE.md` @D claim_verify / commons g5).
- **아카이브 자기보고 메트릭은 증거가 아님** — g5 재계산 통과 전까지 🟡 미검증.
- **비범위**: consciousness / EEG / telepathy 모듈 (archive-TECS-L 의 별도 줄기 — hexa-lang scope 외) · Zenodo 재출판 · 외부 peer-review.
- 작업은 격리 worktree → PR (공유 main 트리 race 회피).
