# O6 — DLMF 카탈로그 미러 확장 타당성 프로브

@slug: oeis-dlmf-probe · group=OEIS · method=feasibility/synthesis
@verdict: 🔴 FALSIFIED (closed-negative) — OEIS 패턴은 DLMF 로 일반화되지 않는다.
@date: 2026-05-25 (UTC)

> 한 줄 결론: OEIS 의 "exact-integer hash-intersect" 카탈로그-미러 패턴은
> DLMF (NIST 특수함수 디지털 라이브러리) 로 **그대로(as-is) 재사용 불가**.
> 3개 전제조건 중 2개가 결정론적으로 FAIL — (P1) bulk 수치 corpus 부재,
> (P3) hexa 에 고전 특수함수 부재. 닫힌-부정 결과 (paper_negative_ok).

---

## §1 · OEIS 패턴 복기 — 무엇이 작동했나 (3 전제조건)

OEIS 미러(O1)가 성립한 이유는 세 조건이 **동시에** 충족됐기 때문이다.

| # | 전제 | OEIS 의 충족 형태 |
|---|------|------------------|
| **P1** BULK CORPUS | 단일 다운로드 가능한 기계판독 dump | `stripped.gz` (~14MB packed / ~77MB unpacked). 한 줄 = `{Annnnnn → 정수 tuple}`. `awk` 로 O(N) 파싱. |
| **P2** UNIFORM REPR | 모든 항목이 **균일·해시 가능** | 모든 entry = **정수 tuple** (첫 ~80항). tuple 은 그대로 **exact-equality 해시 키**. tolerance 불필요. |
| **P3** HEXA COVERAGE | hexa 가 같은 shape 를 precompute | ~20개 정수론 fn (σ/τ/φ/μ/σ_k/aliquot/is_perfect/…) 의 첫 K 항 = 동일 shape 의 정수 tuple. match = **정확 tuple-hash 충돌**. |

O1 POC 실측: 첫 1000 A-line 중 6/899 hit (~0.67%), wall ~수 초.
핵심은 **정확(exact)·bulk·hashable 정수 corpus** ↔ **hexa 정수 fn** 의 직접 교집합이다.

---

## §2 · DLMF 의 구조 — 무엇이 다른가

WebFetch (`dlmf.nist.gov/about`, `/help`, 2026-05-25) + 알려진 사실:

- 콘텐츠는 **수식 단위(per-formula)로 웹페이지** 에 제공. 수식 = MathML (+ LaTeX 소스).
  브라우즈 + 검색 UI. **bulk 다운로드 없음, 공개 API 없음, 다운로드 가능한 수식 corpus 없음,
  bulk 수치-테이블 dump 없음.**
- 정식 형태는 둘뿐: 인쇄본 *NIST Handbook of Mathematical Functions* (Cambridge UP) +
  무료 per-page 전자판. 어느 쪽도 **dataset 이 아니다**.
- DLMF 콘텐츠의 본질:
  - **특수함수 + 항등식**: Bessel J_ν/Y_ν, Gamma(z), 오차함수 erf,
    Hermite/Legendre/Laguerre/Chebyshev 직교다항식, Airy Ai/Bi, Riemann ζ,
    초기하 ₚFq, 타원적분, …
  - 한 "entry" = **기호 항등식(symbolic identity)** (점화식·적분표현·생성함수) 또는
    실/복소 정의역 위의 **연속함수 f(x)** — **고정된 정수 tuple 이 아니다.**
  - 일부 수치 테이블은 예시용 sample point 일 뿐, 균일 bulk corpus 도 아니고
    다운로드 가능한 dataset 으로 제공되지도 않는다.

### 구조적 차이 (한눈에)

```
OEIS:  id → 정수 tuple              (균일·유한·EXACT-HASHABLE)
DLMF:  id → 기호 항등식  OR  연속함수 f : R/C → R/C
                                    (이질적·tuple 해시 불가)
```

각 전제가 그대로 FAIL 로 매핑된다:

| 전제 | DLMF | 판정 |
|------|------|------|
| P1 BULK CORPUS | stripped.gz 등가물 없음; per-page MathML 만 | **FAIL** |
| P2 UNIFORM REPR | 기호/연속 → 정확 정수-tuple 해시 키가 **존재하지 않음**. float 샘플링은 **tolerance(ε) 매칭** 이 필요 = OEIS exact-hash 와 다른 메커니즘 | **FAIL** |
| P3 HEXA COVERAGE | hexa verify --expr 에 고전 특수함수 **0개** (§5) | **FAIL** |

---

## §3 · 세 가지 sub-option 평가 (A / B / C)

### (A) numeric-table intersect — DLMF 테이블 f(x) sample 을 hexa 특수함수와 (해시 또는 tolerance) 매칭

**두 개의 독립적 FAIL 로 차단:**

- **(A.1) DLMF bulk source 부재** — 테이블이 bulk-downloadable 하지 않다(§2).
  OEIS 의 "O(N) 단일 fetch" 단계에 대응물이 없다.
- **(A.2) hexa 에 특수함수 부재** — §5. **교집합할 대상이 없다.** DLMF 데이터가
  있다 한들 hexa 는 Bessel/Gamma(x)/erf/Hermite/… 를 재계산해 hit 를 확인할 수 없다.
- **(A.3) 메커니즘 불일치** — exact 정수 해시 → float tolerance 매칭. 다른 알고리즘
  (ε-ball) 이며 OEIS hash-intersect 의 "재사용" 이 아니다. 새 샘플링 harness +
  tolerance 정책 + 정의역 grid spec 이 필요.
- ⇒ **오늘 기준 NOT viable.**

### (B) identity-citation — DLMF 수식 ID 를 🟡 citation 으로 등록 (hexa 재계산 없이)

- **거버넌스 위반으로 REJECTED.** `OEIS/OEIS.md` §2: *"naive dump 금지, 검증 통과만 fold"*
  + `claim_verify`: *"never auto-🔵 / LLM 자체판정 금지"*.
  hexa 재계산 없는 🟡 citation 행의 벽 = 도메인이 금지하는 **"카탈로그 정체성 표류"** 그 자체.
- 또한 `paper_gate` 도 위반 (🟡 는 non-terminal). ⇒ **거버넌스상 NOT viable.**

### (C) closed-negative — 패턴은 일반화되지 않는다

- **ADOPTED.** DLMF 는 OEIS exact-hash 미러와 **구조적으로 비호환**이다.
  기호-항등식 카탈로그는 근본적으로 다른 ingest (numeric 샘플링 + tolerance,
  혹은 기호-항등식 검증) **AND** 아직 존재하지 않는 hexa 특수함수 라이브러리가 필요하다.
- 이것이 정직하고 publishable 한 O6 결과다 (`paper_negative_ok`).

---

## §4 · 터미널 verdict + 배제된 축 (ruled-out axis)

### Verdict: 🔴 FALSIFIED (closed-negative)

falsified 된 **속성** = *"DLMF 가 OEIS 카탈로그-미러 패턴을 as-is 재사용할 수 있다."*
두 개의 독립적 근거로 FALSE:

1. **bulk 수치 corpus 없음** (P1) — DLMF 는 per-page MathML, dataset 이 아니다.
2. **hexa 특수함수 라이브러리 없음** (P3) — `hexa verify --expr` 가 노출하는 고전 특수함수 = 0개.

패턴은 **OEIS-shaped** 이다: 정확(exact)·bulk·hashable **정수** corpus +
대응하는 hexa **정수** fn 을 요구한다. DLMF 는 셋 다 아니다.

### 배제된 축 (deterministic ruled-out)

> "DLMF can reuse the OEIS catalogue-mirror pattern **as-is**." → **FALSE / RULED OUT.**

### (조건부) 미래 경로 — 같은 패턴 재사용이 아닌 *신규 메커니즘* 일 때만 성립

DLMF 미러는 다음 **신규 작업** 을 모두 갖췄을 때만 conceivable (이 패턴의 재사용 아님):

- **(i)** hexa 특수함수 라이브러리 구축 (Bessel/Gamma/erf/직교다항식 — libm 또는 급수) +
  `hexa verify --expr` 등록.
- **(ii)** exact 정수-tuple 해싱 → 고정 x-grid 위 **numeric 샘플링 + tolerance 매칭**
  (ε, 🟢 NUMERICAL tier; 🔵 exact 아님).
- **(iii)** DLMF 값 소싱 = per-formula scrape (bulk dump 없음) **또는** 독립 reference
  (mpmath/Boost) — O(N) 단일 다운로드가 아닌, 무거운 identity-by-identity ingest.

(i)–(iii) 는 모두 **상당한 신규 작업** 이며 "same-pattern" 재사용이 전혀 아니다.
따라서 O6 프로브는 **일반화에 대해 NEGATIVE 로 닫는다**.
(i)–(iii) 는 향후 "DLMF" 자매 도메인을 연다면 필요한 **선행조건 스택** 으로 로깅한다.

---

## §5 · hexa 특수함수 가용성 (option A 의 결정적 근거)

출처: `hexa verify rubric` — `hexa verify --expr` 를 뒷받침하는 calc-fn + float-fn 레지스트리
(검증-게이트된 유일한 재계산 surface).

- **정수 calc fns**: `sigma sigma_0 sigma_2 phi mu tau is_perfect aliquot
  gamma0_index gamma0_cusps gamma0_genus isotropy_lcm first_cusp_form_weight
  pair_threshold_factor recomb_3body_density_power` · 2-op `sigma_k jacobi
  kronecker dim_cusp_forms ssh_winding` · 3-op `tknn_chern`
- **float fns (libm)**: `welch_t_crit wilson_hilferty_p compound_coverage
  cycles_to_target chsh_tsirelson hardy_bound cdr_perfect_mitigation
  vqe_h2_fci_sto3g qfi_sql qfi_ghz …` (RFC 045 양자 bound) `… exp_release
  ldl_pct beer_lambert nnt arr ln_hr_to_hr …` (약동학)

레지스트리 전체에 대해 DLMF 고전 특수함수 grep:

```
bessel | erf | hermite | legendre | airy | zeta | hypergeom |
gamma(x)[연속] | tgamma | lgamma | elliptic | digamma | chebyshev |
laguerre | sin( | cos(   →   ZERO MATCHES
```

> ⚠ **주의:** `gamma0_index` 는 **모듈러 Γ₀(N) index** (정수론적 **정수**) 이지,
> 연속 Gamma 함수 Γ(z) 가 아니다. DLMF 특수함수 테이블과 무관.

**결론:** hexa verify 는 고전 특수함수를 **하나도** 노출하지 않는다.
도메인 거버넌스("fold scope = hexa-verify 가능한 것만")상 option A 는 — DLMF 데이터
가용성과 무관하게 — **검증 경로가 없으므로 불가능**하다.

---

## 부록 · 증거 trail

- `.verdicts/oeis-dlmf-probe/dlmf_assessment.txt` — 본 평가의 ASCII verbatim + WebFetch 근거 + hexa 특수함수 점검.
- WebFetch: `dlmf.nist.gov/about`, `dlmf.nist.gov/help` (2026-05-25) — bulk download/API/dataset 부재 확인.
- `hexa verify rubric` — calc-fn / float-fn 레지스트리 (특수함수 0개).
- OEIS 패턴 출처: `OEIS/OEIS.md` §0–§3, `OEIS/tool/scanner.hexa` (O1 POC), `CLAIMS.tape` slug=oeis-scanner-poc.

---

## §6 · 사후 갱신 — VERIFY-KIT V4 가 blocker (2) 를 (부분) 해소 (2026-05-26)

> ⚠ **이것은 O6 의 재오픈(reopen) 이 아니다.** O6 의 closed-negative verdict
> (🔴 FALSIFIED) 는 **그대로 유효**하다. 아래는 두 blocker 중 **(2) hexa
> 특수함수 부재** 가 VERIFY-KIT V4 로 (일부) 풀렸음을 정직하게 기록할 뿐이다.

VERIFY-KIT V4 (`CLAIMS.tape` slug=verify-kit-special) 가 `hexa verify` 에
**native libm 특수함수 primitive** 를 추가했다:

| fn | libm | 비고 |
|----|------|------|
| `gamma(x)` | `tgamma` | Γ(x). gamma(5)=24, gamma(0.5)=√π |
| `erf(x)` | `erf` | Gauss 오차함수. erf(1)=0.84270 |
| `bessel_j0(x)` | `j0` | Bessel J₀. j0(0)=1 (STRETCH) |
| `bessel_j1(x)` | `j1` | Bessel J₁. j1(0)=0 (STRETCH) |
| `erfc`/`tgamma`/`lgamma` | libm | 언어-레벨 primitive (lgamma 는 V4 이전부터) |

→ §5 의 "hexa verify 특수함수 ZERO" 점검은 **{gamma, erf, bessel} 에 한해 더 이상
참이 아니다.** blocker (P3 / 본문 (2)) 가 그만큼 해소됐다.

### 그럼에도 DLMF 흡수는 여전히 GATED — 정직한 경계

V4 는 **primitive 만** 제공한다 (DLMF 재흡수가 **아니다**). §4 미래경로 (i)–(iii)
중 **(i) 만 부분 충족**:

- **(i) hexa 특수함수 라이브러리** — gamma/erf/bessel landed. **zeta·직교다항식·
  Airy·초기하·타원적분 등은 미구현** (libm ζ 부재 → Euler-Maclaurin 빌드 리스크로
  V4 defer). 부분 충족.
- **(ii) numeric 샘플링 + tolerance 매칭 harness** — 미구현. (V3 `--tol` 가 단일-값
  tolerance 는 주지만, x-grid 샘플링 harness 는 아님.)
- **(iii) DLMF bulk corpus** — **여전히 부재** (blocker (1) = P1). DLMF 는 bulk
  download/API/dataset 없음 (§2). 이건 V4 가 건드리지 못한다 = **DLMF-specific**.

**결론:** blocker (1) bulk-corpus 가 OPEN 인 한 DLMF as-is 흡수는 계속 불가능하다.
V4 는 (2) 를 좁혀 미래 "DLMF" 자매 도메인의 선행조건 스택 (i) 을 진척시켰을 뿐,
O6 closed-negative 를 뒤집지 않는다.
