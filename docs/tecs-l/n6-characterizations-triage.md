# TECS-L M4 — n=6 characterizations g5 triage

> archive-TECS-L (`dancinlab/archive-TECS-L`) 의 자기보고 메트릭
> **"n=6 characterizations: 206"** 을 hexa-lang `hexa verify` (g5) 게이트로
> triage 한 문서. SSOT 출처 = `~/core/archive-TECS-L/math/README.md`
> (numbered 시리즈 `#1`…`#206`, line 4437 `🎯 206 CHARACTERIZATIONS!`
> `+42 (#165-206)` 가 206 도달 마일스톤) + master summary box (line ~70-218)
> + `math/characterization_verifier.py` `KNOWN_CHARS`.
>
> **거버넌스**: 아카이브 자기보고는 증거가 아님 (TECS-L.md §3). g5 재계산
> 통과 atom 만 🔵/🟢. 검증 불가 항목은 정직하게 🟡 citation / 🟠 deferred.
> 판정문 verbatim = `.verdicts/tecs-l-n6-characterizations/<id>.txt`.

---

## 0 · 헤드라인 (정직한 카운트)

아카이브 "206" 은 numbered 특성 시리즈 `#1`…`#206` 의 누적 tally 다
(line 4437 가 206 도달 마일스톤; `#207`+ 는 그 이후 추가분). 이 시리즈는
math/README.md 안에 **압축 master-summary 표 + 산발적 `#N` 항목**으로
표시돼 있고, 기계가독 형태로 전수 나열돼 있지는 않다 (124 개의 distinct
`#N` 마커만 본문에 물리적으로 등장). 따라서 본 triage 는 **읽을 수 있는
대표 catalogue 항목을 tier 별로 분류**하고, 그 결과를 206 헤드라인 대비로
프레이밍한다 — 206 을 채우려고 항목을 날조하지 않는다.

| tier | 의미 | 본 triage 분류 수 | 비고 |
|------|------|------------------|------|
| 🔵 verifiable-now (FORMAL) | calc fn 으로 닫힌형 재계산 가능 | **15** | 아래 §1, 전부 영속화됨 |
| 🟡 citation-only | 참이나 hexa recompute 경로 없음 (심볼릭 ⟺ 유일성 / 외부 문헌 / 근사 물리) | 대다수 (≈170+) | §2 |
| 🟠 deferred | 외부 데이터/하드웨어/API 필요 | 소수 (물리 측정 의존) | §3 |

**검증 영속화 카운트: 15 atom** (`.verdicts/tecs-l-n6-characterizations/` 15 파일,
`CLAIMS.tape` group=TECS-L slug=`tecs-l-n6-characterizations` 15 `@C`).

### 왜 🔵 가 15 개뿐인가 (정직한 한계)

calc fn (`sigma/tau/phi/mu/is_perfect/aliquot/sigma_0/sigma_2/sigma_k/
gamma0_*/first_cusp_form_weight/dim_cusp_forms/pair_threshold_factor`) 은
**단일 n 에서의 산술함수 값**을 닫힌형으로 계산한다. 그러나 아카이브
특성의 압도적 다수는 **`f(n)=g(n) ⟺ n=6` 형태의 심볼릭 유일성 주장**이다
(예: `σ-rad=n⟺n=6`, `(τ-1)!=n⟺n=6`). hexa verify 는 `[2,N]` 전역
유일성을 닫힌형으로 판정하는 경로가 없으므로 (그건 아카이브 Python
`characterization_verifier.py` 의 `[2,10000]` brute-force 가 하던 일), 그
"⟺n=6" 전칭 부분은 🟡 citation 으로 남는다 (M1 의 σφ=nτ 유일성과 동일
처리). 본 M4 는 **각 특성을 구성하는 n=6 ground 산술값**을 닫힌형으로
재근거화한다 — 이게 calc fn 이 defensibly 지지하는 표면이다. quality
over quantity (M4 method §2 cap).

---

## 1 · 🔵 verifiable-now (영속화된 15 atom)

각 행은 `hexa verify --expr <fn> <n> <v>` 로 재계산 → 🔵 SUPPORTED-FORMAL.
"characterization" 열은 해당 ground 값이 등장하는 아카이브 특성 (`#N` / 본문 line).

| # | characterization (archive) | tier | calc fn | id |
|---|----------------------------|------|---------|----|
| C1 | σ(6)=12 — 약수합, σφ=nτ master (#1) · σ=nφ (#81) · 2σ=nτ (#60) · X₀(36) cusps=σ (line 1285) 의 공통 인자 | 🔵 | `sigma 6 12` | `n6_sigma` |
| C2 | τ(6)=4 — 약수개수, n-2=τ Cayley (#59) · σφ=nτ (#1) · τ=2φ 의 인자 | 🔵 | `tau 6 4` | `n6_tau` |
| C3 | φ(6)=2 — 오일러 토션트, φ²=τ (#33) · σ=nφ (#81) · self-mirror CY₃ h11=h21=φ (#208) 의 인자 | 🔵 | `phi 6 2` | `n6_phi` |
| C4 | μ(6)=1 — 뫼비우스, μ·s=n (#86, Möbius×aliquot) 의 인자 (μ(6)=+1, 짝수개 소인수) | 🔵 | `mu 6 1` | `n6_mu` |
| C5 | is_perfect(6)=1 — 6 = 1st 완전수, σ(6)=2·6 (모든 완전수 특성의 anchor) | 🔵 | `is_perfect 6 1` | `n6_is_perfect` |
| C6 | aliquot(6)=6 — 진약수합 s(6)=σ-n=6=n (완전수의 정의: s(n)=n) · s(n)=6⟺{6,25} (#72) 의 값 | 🔵 | `aliquot 6 6` | `n6_aliquot` |
| C7 | σ₀(6)=4 — σ_0=τ (약수개수의 σ_k k=0 표현) | 🔵 | `sigma_0 6 4` | `n6_sigma0` |
| C8 | σ₂(6)=50 — 제곱약수합 1+4+9+36; σ₂=φ·sopfr² (#92, =2·25) · σ₂=2·sopfr² (#152) 의 LHS | 🔵 | `sigma_2 6 50` | `n6_sigma2` |
| C9 | σ₃(6)=252 — 세제곱약수합 1+8+27+216; σ_k 일반화 (k=3) · σ₃=τ(2ⁿ-1) (#H-CODE-1 family) 의 값 | 🔵 | `sigma_k 6 3 252` | `n6_sigma3` |
| C10 | Γ₀(6) index = 12 = σ(6) — modular curve X₀(6) 의 지표 = σ (line 1285/677 family) | 🔵 | `gamma0_index 6 12` | `n6_gamma0_index` |
| C11 | Γ₀(6) cusps = 4 = τ(6) — X₀(6) 첨점 개수 = τ | 🔵 | `gamma0_cusps 6 4` | `n6_gamma0_cusps` |
| C12 | genus X₀(6) = 0 — "unique genus-0 modular curve among perfect numbers" (line 2612/416) | 🔵 | `gamma0_genus 6 0` | `n6_gamma0_genus` |
| C13 | first cusp form weight (Γ₀(6)) = 4 — Γ₀(6) 에서 nonzero cusp form 이 처음 나타나는 weight (calc fn 정의) | 🔵 | `first_cusp_form_weight 6 4` | `n6_first_cusp_form_weight` |
| C14 | dim S₂(Γ₀(6)) = 0 — weight-2 cusp form 차원 0 (genus 0 와 정합; line 2612) | 🔵 | `dim_cusp_forms 6 2 0` | `n6_dim_cusp_forms` |
| C15 | conductor(6) = 36 = n² — X₀ 도관 = n² (line 677 "Conductor = n²=36"); calc `pair_threshold_factor(6)=36` | 🔵 | `pair_threshold_factor 6 36` | `n6_conductor` |

> **C13 정직성 주석**: 아카이브 line 1550 은 "first cusp form weight = lcm(4,6)=12=σ(6)"
> 라 주장하나, hexa calc `first_cusp_form_weight(6)` 은 **4** (Γ₀(6) 에서
> nonzero 컵스폼이 처음 나타나는 weight) 를 반환한다 — 정의가 다르다.
> 본 atom 은 calc fn 이 실제 계산하는 값 (=4=τ(6)) 만 🔵 로 주장하고,
> 아카이브의 lcm(4,6)=12 읽기는 채택하지 않는다 (over-claim 금지, g3).

---

## 2 · 🟡 citation-only (hexa recompute 경로 없음)

아카이브 catalogue 의 대다수. 두 부류:

### 2a · 심볼릭 유일성 (⟺ n=6 전역 주장)

calc fn 은 단일 n 값만 계산 — `[2,N]` 전역 유일성 판정 경로 없음. 따라서
n=6 ground 값은 🔵 (§1) 로 잡되, "⟺n=6" 전칭은 🟡. 예 (math/README.md):

| characterization | archive ref | 왜 🟡 |
|------------------|-------------|-------|
| σ-rad=n ⟺ n=6 (unique sqfree perfect, proof!) | #77 | 전역 유일성, rad fn 없음 |
| (τ-1)!=n ⟺ n=6 (3!=6, factorial!) | #79 | 전역 유일성, factorial fn 없음 |
| σ=n·φ ⟺ n=6 (abundancy=totient) | #81 | 전역 유일성 (n=6 값은 C1·C3 으로 🔵) |
| n mod τ=φ ⟺ n=6 | #83 | 전역 유일성, mod 비교 fn 없음 |
| τ\|σ ∧ φ\|τ ∧ n\|σ ⟺ n=6 (triple divisibility) | #85 | 전역 유일성, divisibility 술어 없음 |
| μ·s=n ⟺ n=6 (Möbius×aliquot) | #86 | 전역 유일성 (n=6 값은 C4·C6 으로 🔵) |
| Σ\|d-n/d\|=n ⟺ n=6 | #89 | 전역 유일성, divisor-pair sum fn 없음 |
| AM-HM=1 ⟺ n=6 (divisor mean diff) | #90 | 전역 유일성, 약수 조화/산술평균 fn 없음 |
| φ²=τ ⟺ {1,3,10,30} | #33 | 유한집합 멤버십, 전역 판정 경로 없음 |
| sopfr·ω=σ+φ-τ, n>2 ⟺ n=6 | #53 | sopfr·ω fn 없음 |
| ψ(n)=σ(n)=2n ⟺ n=6 (Dedekind psi) | #51 | Dedekind ψ fn 없음 (M3 으로 이관) |
| sin(π/n)=φ/τ ⟺ n=6 (trig) | #54 | trig-divisor 닫힌형 verify 경로 없음 |
| C(σ-τ,φ)=P₂=28 ⟺ n=6 (P₁→P₂) | #82 | 이항계수 fn 없음 |
| 1/2+1/3+1/6=1 (φ/τ+τ/σ+1/n) | #183 | 유리수 등식, calc fn 외 |

(이 부류가 numbered 시리즈 #1-#206 + #H-XXX named 의 절대다수 — 모두
"⟺n=6" 또는 "⟺유한집합" 심볼릭 유일성.)

### 2b · 외부 문헌 / 위상수학 carry (값 일치이나 hexa fn 부재)

| characterization | archive ref | 왜 🟡 |
|------------------|-------------|-------|
| π₆(S³)=ℤ/12=ℤ/σ(6) (Toda 1962) | line ~391 | 호모토피군, 외부 정리 carry |
| \|im(J)₇\|=240=στ·sopfr (Adams e-invariant) | H-TOP-8 | K-이론 carry |
| kiss(Λ₂₄)=στ(2^σ-1)=196560 (Leech lattice) | #H-SPOR-1 | 격자 kissing number carry |
| G₂₄=[σφ,σ,σ-τ] (Golay code) | #H-CODE-1 | 부호이론 carry |
| σ-τ=8=rank(E₈) (McKay) | #64 | Lie 대수 carry |
| N(6) MOLS=1 (Tarry 1901, no GL pair order 6) | H-COMB-2 | 조합설계 외부 정리 |

### 2c · 근사 물리 매칭 (정량이나 근사·자유모수)

| characterization | archive ref | 왜 🟡 (deferred 아님) |
|------------------|-------------|----------------------|
| 페르미온 질량 avg ~1.9-2.2% error (9 입자, 5 자유모수) | line 747 | 근사 일치, 닫힌형 아님 |
| Koide δ=2/9=φτ²/σ² (5 ppm) | line 1584 | 실험 Koide 각 대비 근사 |
| m_μ/m_e ≈ P₂×e²=28×e²=206.89 (0.06%) | line 1691 | 근사 (≈), 닫힌형 등식 아님 |
| 끈이론 차원 = σφ=12 | README headline | σφ=24 (#172) 와 충돌하는 frame; 차원 매핑은 문헌 carry |

> 끈이론 σφ 매칭은 M5 에서 별도 다룸 (`hexa verify --expr` 🟢 NUMERICAL
> 시도 대상). 본 M4 에선 citation 으로 둠.

---

## 3 · 🟠 deferred (외부 데이터/하드웨어/API)

순수 수론 특성은 외부 자원 의존이 없어 🟠 는 드물다. 물리 측정에 직접
의존하는 항목만 해당:

| characterization | archive ref | 왜 🟠 |
|------------------|-------------|-------|
| CERN 5.26σ combined / QCD resonance ladder 3.8σ | README Level 4 | 가속기 실측 데이터 의존 |
| 핵 magic number = σ,τ,φ 매핑 | README Level 4 | 실험 핵물리 데이터 carry |

---

## 4 · 검증 명령 + 판정문 인덱스

전체 15 atom 은 `hexa verify --expr` (g5) → `.verdicts/tecs-l-n6-characterizations/<id>.txt`
verbatim 영속화 → `CLAIMS.tape` `[slug=tecs-l-n6-characterizations group=TECS-L]`.
모든 `.verdicts` 파일은 `CLAIMS.tape` 의 `raw =` 포인터와 1:1 (orphan 없음).

| id | cmd | tier |
|----|-----|------|
| n6_sigma | `hexa verify --expr sigma 6 12` | 🔵 |
| n6_tau | `hexa verify --expr tau 6 4` | 🔵 |
| n6_phi | `hexa verify --expr phi 6 2` | 🔵 |
| n6_mu | `hexa verify --expr mu 6 1` | 🔵 |
| n6_is_perfect | `hexa verify --expr is_perfect 6 1` | 🔵 |
| n6_aliquot | `hexa verify --expr aliquot 6 6` | 🔵 |
| n6_sigma0 | `hexa verify --expr sigma_0 6 4` | 🔵 |
| n6_sigma2 | `hexa verify --expr sigma_2 6 50` | 🔵 |
| n6_sigma3 | `hexa verify --expr sigma_k 6 3 252` | 🔵 |
| n6_gamma0_index | `hexa verify --expr gamma0_index 6 12` | 🔵 |
| n6_gamma0_cusps | `hexa verify --expr gamma0_cusps 6 4` | 🔵 |
| n6_gamma0_genus | `hexa verify --expr gamma0_genus 6 0` | 🔵 |
| n6_first_cusp_form_weight | `hexa verify --expr first_cusp_form_weight 6 4` | 🔵 |
| n6_dim_cusp_forms | `hexa verify --expr dim_cusp_forms 6 2 0` | 🔵 |
| n6_conductor | `hexa verify --expr pair_threshold_factor 6 36` | 🔵 |
