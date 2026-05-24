> **status: cross-repo (demiurge)** — 2026-05-25 handoff registered in demiurge
> `inbox/patches/noreflow-clinical-calc-libs-handoff-from-hexa-lang.md` + `inbox/INDEX.md`
> (branch `inbox/noreflow-clinical-calc-libs-handoff-2026-05-25`, commit `35e63e1`). The driver
> is demiurge's `CARDIO+/NOREFLOW` domain (M11 formal grade-up / V2 🔵 push dependency); this
> patch is the RFC for the actual atlas absorption which lands via hexa-lang's own atlas PR
> cycle (@D g_atlas_binary_builtin). Archive-ready on the hexa-lang side — kept here as the
> RFC of record for the 5 clinical calc fns.

# NOREFLOW clinical calc atlas extension — Hill · exp-decay · 2-comp PK · Cox · Fick

## TL;DR
demiurge NOREFLOW 도메인 (PCI no-reflow / IRI 보호) 가 🔵 SUPPORTED-FORMAL
trajectory 에 도달하려면, `hexa verify` atlas 가 임상/약리 산식 5종 (Hill ·
exponential decay · 2-compartment PK · Cox proportional hazards · Fick's first
law) 을 closed-form calc fn 으로 흡수해야 한다. 본 RFC 는 5개 fn 의 정의 ·
closed-form identity · atlas 등록 form · verify dispatch · test vectors 를
제안한다.

## §1 motivation — atlas 가 number-theory only 라 임상 산식 verify 불가

현재 `hexa verify` atlas 는 number-theoretic / signal-processing 계열에 한정
되어 있다 (sigma · phi · mu · tau · gamma0_index · welch_t · wilson 등 cycle
RFC 046/047 까지). demiurge NOREFLOW 도메인은 bio/clinical 산식에 의존하므로
verify 경로가 atlas 밖이라 🟠 INSUFFICIENT 에 머무른다:

- **M4 (delivery PK)** — arm-to-heart compartmental → 2-comp PK 필요
- **M5 (endpoint)** — IMR / TIMI flow / infarct size HR → Cox hazards 필요
- **M6 (off-target safety)** — drug-receptor binding · Ca²⁺ Hill (mPTP) 필요
- **M7 (ranking)** — endpoint × HR aggregate → cox_h composite 필요
- **재관류 lethal window** — τ ≈ 5 min decay → exp_decay 필요
- **IC vs IV diffusion** — arm-to-heart drug front → Fick's law 필요

5종 calc fn 이 atlas 에 흡수되어야 demiurge NOREFLOW M11 (formal grade-up)
이 🔵 SUPPORTED-FORMAL 으로 진행 가능. 본 patch 는 5종 등록 + verify
dispatch + test vectors 를 일괄 제안한다.

## §2 신규 calc fns proposal (5개)

### §2.1 `hill_eq(n, K, x)` — Hill equation

- **정의**: y = x^n / (K^n + x^n)
- **closed-form identity** (대수적 항등식):
  ```
  hill_eq(n, K, x) + hill_eq(n, K, K²/x) ≡ 1
  ```
  (대칭점 x · x' = K² 에서 fractional occupancy 합이 1)
- **atlas 등록 form**: `hill_eq` 3-operand calc fn
- **사용처**:
  - mPTP Ca²⁺ Hill (n=4-6, K≈200 nM) — mitochondrial permeability
    transition pore opening probability
  - drug-receptor binding (n=1 단순 Langmuir, n>1 cooperativity)
  - dose-response curve EC50/IC50
- **verify usage**:
  ```
  hexa verify --expr hill_eq 4 200 100 0.058823529411764705
  hexa verify --expr hill_eq 2 1 1 0.5
  ```

### §2.2 `exp_decay(λ, t)` — exponential decay

- **정의**: y = exp(-λ * t)
- **closed-form identity** (반군 property):
  ```
  exp_decay(λ, t₁) * exp_decay(λ, t₂) ≡ exp_decay(λ, t₁ + t₂)
  ```
- **atlas 등록 form**: `exp_decay` 2-operand calc fn
- **사용처**:
  - 재관류 lethal window decay (τ = 5 min, λ = 1/τ)
  - 1-compartment drug elimination (k_e * t)
  - radioactive tracer washout (PET imaging)
- **verify usage**:
  ```
  hexa verify --expr exp_decay 1 1   0.36787944117144233
  hexa verify --expr exp_decay 0.1 5 0.6065306597126334
  ```

### §2.3 `pk_2comp(D, k10, k12, k21, t)` — 2-compartment PK

- **정의** (closed-form, V=1 단위화):
  ```
  b = k10 + k12 + k21
  c = k10 * k21
  α = (b + √(b² - 4c)) / 2
  β = (b - √(b² - 4c)) / 2
  C(t) = D * [ (α-k21)/(α-β) · exp(-αt) + (k21-β)/(α-β) · exp(-βt) ]
  ```
- **closed-form identity** (AUC infinite integral, V=1):
  ```
  ∫₀^∞ C(t) dt = D / (k10 * k21) * (α + β - k21) / (α * β)
                = D / k10              (대수적 reduction — 모든 분포가
                                        결국 k10 으로 elimination)
  ```
  (즉 AUC ≡ D / k10 는 compartment topology 와 독립한 mass-balance
  invariant; verify oracle 로 강력)
- **atlas 등록 form**: `pk_2comp` 5-operand fn
- **사용처**:
  - IV vs IC compartmental PK — central + peripheral
  - arm-to-heart lag 모델 (central = systemic, peripheral = arm)
  - chemo / immunosuppressant distribution kinetics
- **verify usage**:
  ```
  hexa verify --expr pk_2comp 100 0.1 0.05 0.04 60  2.641331608
  ```
  (D=100, k10=0.1, k12=0.05, k21=0.04, t=60 → C ≈ 2.6413)

### §2.4 `cox_h(t, λ₀, β, x)` — Cox proportional hazards

- **정의**: h(t | x) = λ₀(t) * exp(β * x)
  (본 calc fn 은 constant baseline λ₀ 가정 → h = λ₀ * exp(β·x); time-varying
   λ₀ 는 별도 fn 으로 분리)
- **closed-form identity** (constant baseline survival):
  ```
  S(t | x) = exp(-λ₀ * t * exp(β * x))
  ⇒ -ln(S(t|x)) / (t * exp(β·x)) ≡ λ₀   (모든 (t,x) 에서 동일)
  ```
- **atlas 등록 form**: `cox_h` 4-operand fn
- **사용처**:
  - endpoint × outcome HR (hazard ratio)
  - IMR > 40 risk model (TIMI flow + IMR composite)
  - drug A vs B 비교의 HR + 95% CI
- **verify usage**:
  ```
  hexa verify --expr cox_h 10 0.01 0.5 2  0.027182818284590453
  ```
  (h = 0.01 * e^1 ≈ 0.02718)

### §2.5 `fick_law(D, A, dc, dx)` — Fick's first law diffusion

- **정의**: J = -D * A * (dc / dx)
- **closed-form identity** (steady-state finite slab):
  ```
  J * dx ≡ -D * A * Δc       (steady flux × thickness 가 보존)
  ```
- **atlas 등록 form**: `fick_law` 4-operand fn
- **사용처**:
  - drug arm-to-heart diffusion front (IC vs IV PK)
  - transdermal / arterial wall permeation
  - O₂ delivery gradient in ischemic tissue
- **verify usage**:
  ```
  hexa verify --expr fick_law 1e-5 1 1 1  -1e-5
  ```
  (J = -D·A·(Δc/Δx); D=1e-5, A=1, Δc=1, Δx=1 → J = -1e-5)

## §3 implementation 제안

### §3.1 코드 위치 (canonical home per @D d3)

```
hexa-lang/native/recompute_clinical.{rs,c}     ← closed-form numerical impl
hexa-lang/atlas/clinical_atoms.tape            ← atlas atom registration
hexa-lang/src/verify.rs ::CLINICAL_FNS         ← dispatch table extension
hexa-lang/tests/verify_clinical_test.hexa      ← test vectors (§4)
```

각 fn 에 대해:
1. **closed-form 정의** (recompute_clinical.{rs,c})
2. **verify routine** — operand count 별 dispatch (2/3/4/5-op)
3. **test vectors** — known closed-form points (§4)
4. **absorb 대상** — `atlas/inbox/verified_equations.tape` 에 fn name +
   closed-form identity 등록 후 PR-only landing (per @D
   g_atlas_binary_builtin)

### §3.2 dispatch table 확장 (verify.rs scaffold)

```rust
// hexa-lang/src/verify.rs
pub const CLINICAL_FNS: &[(&str, usize)] = &[
    ("hill_eq",    3),  // (n, K, x)
    ("exp_decay",  2),  // (lambda, t)
    ("pk_2comp",   5),  // (D, k10, k12, k21, t)
    ("cox_h",      4),  // (t, lam0, beta, x)
    ("fick_law",   4),  // (D, A, dc, dx)
];

// match arity → recompute_clinical::dispatch(name, &args) → f64
```

### §3.3 atlas atom 등록 form

```tape
@F clinical.hill_eq := "Hill equation fractional occupancy" :: calc-fn [active]
  arity    = 3
  operands = "n, K, x"
  formula  = "x^n / (K^n + x^n)"
  identity = "hill_eq(n,K,x) + hill_eq(n,K,K^2/x) ≡ 1"
  recompute = "native/recompute_clinical:hill_eq"

@F clinical.exp_decay := "exponential decay" :: calc-fn [active]
  arity    = 2
  operands = "λ, t"
  formula  = "exp(-λ·t)"
  identity = "exp_decay(λ,t1) · exp_decay(λ,t2) ≡ exp_decay(λ,t1+t2)"
  recompute = "native/recompute_clinical:exp_decay"

@F clinical.pk_2comp := "2-compartment PK biexponential" :: calc-fn [active]
  arity    = 5
  operands = "D, k10, k12, k21, t"
  formula  = "biexponential α/β roots of s²+(k10+k12+k21)s+k10·k21"
  identity = "∫₀^∞ C(t)dt ≡ D / k10  (V=1 normalization)"
  recompute = "native/recompute_clinical:pk_2comp"

@F clinical.cox_h := "Cox proportional hazards" :: calc-fn [active]
  arity    = 4
  operands = "t, λ₀, β, x"
  formula  = "λ₀ · exp(β·x)   (constant baseline)"
  identity = "-ln(S(t|x)) / (t·exp(β·x)) ≡ λ₀"
  recompute = "native/recompute_clinical:cox_h"

@F clinical.fick_law := "Fick's first law diffusion flux" :: calc-fn [active]
  arity    = 4
  operands = "D, A, dc, dx"
  formula  = "J = -D · A · (dc/dx)"
  identity = "J · dx ≡ -D · A · Δc   (steady-state)"
  recompute = "native/recompute_clinical:fick_law"
```

## §4 test vectors (atlas absorb 시 oracle 로 사용)

| fn         | operands                    | expected                          | basis        |
|------------|----------------------------|-----------------------------------|--------------|
| hill_eq    | (2, 1, 1)                  | 0.5                               | analytic     |
| hill_eq    | (4, 200, 100)              | 0.058823529411764705              | analytic     |
| hill_eq    | (n, K, K)                  | 0.5                               | x = K 대칭점 |
| exp_decay  | (1, 1)                     | 0.36787944117144233               | 1/e          |
| exp_decay  | (0.1, 5)                   | 0.6065306597126334                | e^-0.5       |
| exp_decay  | (λ, 0)                     | 1.0                               | t=0 boundary |
| pk_2comp   | (100, 0.1, 0.05, 0.04, 0)  | 100.0                             | t=0 → C=D/V  |
| pk_2comp   | (100, 0.1, 0.05, 0.04, 60) | 2.641331608                       | numerical    |
| pk_2comp   | (D, k10, k12, k21, ∞)      | 0.0                               | t→∞ → 0      |
| cox_h      | (10, 0.01, 0.5, 2)         | 0.027182818284590453              | 0.01·e^1     |
| cox_h      | (t, λ₀, 0, x)              | λ₀                                | β=0 → null   |
| cox_h      | (t, λ₀, β, 0)              | λ₀                                | x=0 baseline |
| fick_law   | (1e-5, 1, 1, 1)            | -1e-5                             | direct       |
| fick_law   | (D, A, 0, dx)              | 0.0                               | no gradient  |
| fick_law   | (D, A, Δc, Δc·dx/J)        | J (round-trip)                    | identity     |

closed-form identity check 는 random sampling 으로도 가능 (atlas reviewer
가 1000-sample tolerance test 추가 권장).

## §5 d2 wall + breakthrough connection

demiurge NOREFLOW 도메인은 다음 wall 에 직면:
- **wall**: bio/clinical 산식이 atlas 밖 → `hexa verify` 가 numerical
  recompute 를 수행할 수 없음 → 🟠 INSUFFICIENT 고정
- **demiurge 자체 breakthrough 시도**: hand-derived closed-form 만으로는
  reviewer cross-check 불가, 🟡 SUPPORTED-BY-CITATION 천장
- **본 patch 의 breakthrough**: 5종 fn 을 atlas 에 흡수 → demiurge 가
  closed-form identity + numerical recompute 양쪽으로 verify 통과 → 🔵
  SUPPORTED-FORMAL 도달 경로 확보

**d2 governance compliance**: "wall 에 부딪힐 때 2-3 breakthrough paths
surface" — 본 patch 자체가 breakthrough path (`hexa kick` + atlas 확장)
의 구체화.

## §6 timeline + acceptance

- **T+0**: patch land (본 PR)
- **T+24~72h**: reviewer review — closed-form identity 검토 · arity
  table 검토 · test vector tolerance 정의
- **merge 후**: hexa rebuild → atlas 자동 확장 → `hexa verify --expr
  <fn> <args> <expected>` 사용 가능
- **demiurge NOREFLOW M11 (formal grade-up)**: hexa rebuild 직후 즉시
  verify 통과 시도 가능 → 🔵 SUPPORTED-FORMAL trajectory 확보

**acceptance criteria**:
1. 5종 fn 모두 atlas atom 등록 + recompute_clinical 구현
2. §4 test vector 전부 통과 (tolerance: relative 1e-9 권장)
3. closed-form identity check (1000-sample random) 통과
4. demiurge NOREFLOW.log.md 에서 `hexa verify --expr hill_eq ...` 등
   직접 호출 성공

## §7 references

- Hill AV (1910) "The possible effects of the aggregation of the molecules
  of hæmoglobin on its dissociation curves" *J Physiol* 40:iv-vii — Hill
  equation 원조
- Wagner JG (1981) *Fundamentals of Clinical Pharmacokinetics* — 2-comp
  PK biexponential closed-form
- Cox DR (1972) "Regression Models and Life-Tables" *J R Stat Soc B*
  34(2):187-220 — proportional hazards
- Fick A (1855) "Ueber Diffusion" *Annalen der Physik* 170(1):59-86 —
  diffusion law
- demiurge NOREFLOW.md (target consumer)
- atlas RFC 046/047 (precedent — welch_t · wilson · ssh_winding · tknn_chern
  등록 패턴 참고)

## §8 metadata

```
status:    proposed
type:      atlas-extension
priority:  P1
           (demiurge NOREFLOW 8/8 milestones + 🔵 trajectory block 해소)
size:      5 calc fns + recompute_clinical + atom registration + tests
reviewer:  TBD
related:   demiurge/NOREFLOW.md
           hexa-lang atlas RFC 046/047 (precedent)
           hexa-lang/src/verify.rs CLINICAL_FNS dispatch
```

## §9 비고

- @D d3 (project.tape) — 구현 코드는 hexa-lang canonical home
  (`native/recompute_clinical`) 에만, demiurge 측 중복 금지
- @D d4 — generic dispatch (verify.rs 의 arity-dispatch table) 한 곳 추가만
  으로 5종 모두 흡수 — fn-name hardcoding 회피 (manifest=atom registration
  으로 추가)
- 본 patch 는 RFC 만, 구현 코드는 별도 PR 에서 land
