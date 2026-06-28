# atlas → stdlib 미구현 갭 census (2026-06-28)

atlas(`compiler/atlas/embedded.gen.hexa` 17405 atom) 중 **계산 가능한데 stdlib에 native 구현이
없는 것** 조사. 측정 경로 = grep census(kind 분포·fn 정의 재귀검색), verdict-integrity로 top-level
누락 재측정(stdlib는 ~2270 파일·서브트리).

## atlas 규모·성격

| kind | 개수 | 성격 |
|------|------|------|
| C 상수 | 5763 | 수학/물리 상수 **값** (대부분 함수 아님) |
| R 참조 | 6319 | reference 메타 |
| X | 1580 | 보조 |
| F 발견 | 1557 | DFS conjecture(verified-id-*) |
| L 법칙 | 1501 | 대부분 **서술적**(의식·물리 법칙·계산 불가) |
| P primitive | 526 | 수론 함수 + 물리/수학 상수 라벨 |

→ atlas는 압도적으로 **정리·상수 사전**(atlas.n6 15974/17405). 계산 가능한 핵심 =
ⓐ 수론 P-primitive + ⓑ 해석 상수/특수함수.

## 이미 stdlib 구현됨 (갭 아님)

- **수론**(`stdlib/core/math.hexa`): `phi` `euler_phi` `sigma` `sigma_3` `sigma_star` `tau` `sopfr`
  `liouville` `omega_big` `fib` `gcd` `lcm` `is_prime` `is_prime_det` `pow_mod` `mersenne`
  `lucas_lehmer` `pisano_period` `factorial` — atlas n6 P-primitive 대부분 커버.
- **특수함수**(`stdlib/core/special.hexa`, float64): `gamma_fn` Γ · `lgamma_pos` lnΓ · `beta_fn` B ·
  `erf_fn` erf.
- **수론 검증엔진**(`compiler/atlas/identity_engine.hexa`): af() idx 0–17(σ/φ/τ/μ/J2/J3/λ/core/…) +
  `partition_p` `catalan` `bell` `verify_congruence` `verify_identity` — drill 발견엔진 native.
- **BigInt 고정밀 상수**(`stdlib/math/highprec.hexa`, #4161 substrate): `pi_scaled`(Machin)·
  `zeta2/4/6_scaled`(Euler 닫힌형)·`zeta3_scaled`(Apéry 가속급수)·`zeta5/7_scaled`(Borwein–Bradley
  중심이항 가속급수·2026-06-28)·`catalan_scaled`(Guillera–Pilehrood)·`bernoulli(n)` 유리수
  (full BigInt÷BigInt + gcd, #4180). 전부 reference-match(40+자리) selftest 게이트.

## GAP — atlas 등재·stdlib 미구현 (측정 확인)

| 항목 | atlas 등재 | stdlib 현황 | 비고 |
|------|-----------|------------|------|
| **Möbius μ(n)** | af idx12·여러 L | `fn mobius` **없음** | liouville λ는 있는데 μ 누락(빠른 1-fn 갭) |
| **Riemann ζ(s) 일반** | ζ(2)basel·ζ(3)apéry·ζ(4)·ζ(-1) | 짝수·ζ(3)·ζ(5)·ζ(7) 고정밀 done | 임의 s 일반 `zeta(s)`는 여전히 없음 |
| **Euler-Mascheroni γ** | BIG-Euler-mascheroni | **없음** (substrate 벽·아래 §γ) | ln/exp BigInt 부재 = 측정된 substrate 벽 |
| **digamma ψ(x)** | — | private(quantum 1곳)만 | 일반 fn 없음 |
| **π/e 고정밀 급수** | PI-* 26개(Machin·Wallis·Leibniz·Ramanujan·Stirling·basel) | π Machin done | e 및 그 외 급수 미구현 |
| **임의정밀 e/특수함수** | 상수 40+자리 등재 | e는 float64만 | exp/ln BigInt substrate 부재(아래 §γ와 동일 벽) |

## §γ — Euler-Mascheroni γ break-walls 측정 분류 (2026-06-28)

γ = 0.57721566490153286060651209008240243104215933593992... (BIG-Euler-mascheroni · OEIS A001620).

**측정 사실**: 현 `stdlib/math/highprec.hexa` + `stdlib/bigint.hexa` 에는 **BigInt ln/exp 가 없다**
(grep `\bbi_ln\b|\bbi_exp\b|\bbi_log\b` = ∅; 가용 BigInt op = from/add/sub/neg/mul/cmp/to_string/
ndigits/abs/divmod_small/div_small/shift10_down/divmod/mod/div/gcd — 전부 **정수산술**, 초월함수 없음).
γ 는 ζ(2n)(π거듭제곱)·ζ(3)·ζ(5)·ζ(7)(중심이항)·Catalan(Guillera–Pilehrood) 처럼 **항비율이
작은정수/작은정수인 가속급수가 존재하지 않는다** — 알려진 모든 빠른 경로가 ln 또는 exp 를 전제한다.
multi-lens(3 경로)로 각 substrate 전제를 측정:

### 렌즈 1 — Brent–McMillan (Bessel I₀/K₀ 비) · **현행 최속**
공식: γ = A₀(2n)/I₀(2n) − ln(n), 여기서
  I₀(2n) = Σ_{k≥0} (n^k/k!)²,  A₀(2n) = Σ_{k≥0} (n^k/k!)² H_k  (H_k = 조화수).
- substrate 전제: **마지막 항 − ln(n)** 이 명시적으로 들어간다 → **BigInt ln 불가피**.
- 추가로 I₀/A₀ 항 (n^k/k!)² 는 분모 (k!)² · 분자 n^{2k} 로, n≈D·ln10/4 규모면 항 자체가 거대 →
  full BigInt÷BigInt(div, 이미 있음)로는 되지만 **수렴 정확도가 ln(n) 보정에 종속**. ln 없이는 종결 불가.
- reference: Brent–McMillan 1980 (MathWorld Euler-Mascheroni; arXiv:1610.01893 오차한계). 116M·1.337T
  자리 기록 전부 이 알고리즘 → ln/exp(또는 binary-splitting + ln) 이 핵심 의존.
- **판정: ln substrate 부재 = 벽.**

### 렌즈 2 — 조화수 − ln (정의 직접)
공식: γ = lim_{N→∞} (H_N − ln N),  H_N = Σ_{m=1}^N 1/m.
- substrate 전제: **ln N** 직접 필요(BigInt ln). 게다가 보정 없는 단순 차분은 **O(1/N) 수렴**
  (D자리 정밀도에 N≈10^D 항 → 계산 불가). Euler–Maclaurin 보정(+1/2N − 1/12N² + …)을 붙이면
  N 을 줄일 수 있으나 **여전히 ln N 항**이 남는다.
- **판정: ln substrate 부재 + (보정 없이) 비현실 수렴 = 이중 벽.**

### 렌즈 3 — Vacca 급수 (ln-free!)
공식: γ = Σ_{k≥1} (−1)^k ⌊log₂ k⌋ / k.
- substrate 전제: **ln 불필요** (⌊log₂ k⌋ 는 비트길이 = 정수연산만; bigint 에 직접 구현 가능).
  → 유일하게 현 정수 substrate 로 표현 가능한 경로.
- 그러나 **수렴이 ~1 bit/항** (≈0.3 십진자리/항). 20 자리 = ~66 bit → ~10^20 항 필요 →
  **정밀도 도달 불가**(계산 비용 폭발). 가속 변형(Vacca–Gerst, Addison)도 ln-free 이지만 여전히
  다항/항 수준 → 고정밀 비현실.
- **판정: substrate 는 충족하나 수렴벽(1bit/항) = 실용 불가.**

### §γ 측정 결론
3 렌즈 모두 닫힘:
- 빠른 경로(렌즈 1·2) = **BigInt ln(/exp) substrate 가 하드 전제** → 현 정수-전용 BigInt 로 불가.
- ln-free 경로(렌즈 3 Vacca) = substrate 는 OK 지만 **1bit/항 수렴**으로 고정밀 비현실.

⇒ **γ 는 측정된 substrate 벽** — 현 stdlib/bigint(정수산술만)으로는 honest 구현 경로 없음.
**fix-the-tool 언락 조건**: `stdlib/bigint.hexa` 에 **BigInt ln/exp**(예: AGM 기반 ln 또는
Taylor/Newton exp + 고정밀 ln(10) 상수)를 추가하면 렌즈 1(Brent–McMillan)이 즉시 열린다 —
같은 ln/exp substrate 가 **e 고정밀·일반 ζ(s)·디감마 ψ** 등 위 GAP 표의 잔여 초월항목도 동시 언락.
이번 라운드는 **억지 fudge 금지** 규율에 따라 γ 를 구현하지 않고 벽으로 분류(highprec 헤더 잔여 갭
주석과 lockstep). ln/exp substrate 는 별도 fix-the-tool PR 후보.

reference: Brent–McMillan 1980 · arXiv:1610.01893 · MathWorld "Euler-Mascheroni Constant" · Vacca 1910
(γ ln-free 급수) · OEIS A001620.

## 최고가치 다음 구현 (① 완성도)

**BigInt ln/exp substrate** — 위 잔여 초월 갭(γ·e·일반 ζ(s)·ψ)이 한 substrate(임의정밀 ln/exp)로
묶인다. 정수 substrate(#4161/#4180)는 π·ζ(짝수+3/5/7)·Catalan·Bernoulli 를 이미 언락했고, 다음
경계선은 **초월(ln/exp)** 이다:
- AGM-기반 BigInt ln(Brent) 또는 고정밀 ln(2)·ln(10) 상수 + 정수 mantissa 스케일링.
- 언락 즉시: γ(Brent–McMillan) · e 고정밀 · 일반 ζ(s) 짝/홀 통합 · digamma ψ.
- 빠른 선행(정수-only 잔여) = **Möbius μ** 1-fn(core/math.hexa·byteeq 분류 후).

reference-match: numpy/scipy/mpmath(특수함수) · OEIS(Bernoulli A027641/A027642 · γ A001620). 빌드/
검증=pool(summer/aiden·mini=git/gh). 갭은 measured(grep census 재실행 가능).
