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

## GAP — 🏁 전부 CLOSED (2026-06-28 · 레버 고갈 달성)

원래 갭 전 항목이 BigInt 위 native 구현 + summer reference-match 로 닫혔다. 아래 §γ 의 "ln/exp substrate
측정벽" 예상은 **falsified** — atanh 고정소수점 ln/exp(#4186)로 돌파되어 γ·digamma·e 가 연쇄 언락됐다.

| 항목 | stdlib 현황 (CLOSED) | PR |
|------|---------------------|-----|
| **Möbius μ(n)** | `mobius(n)` (core/math.hexa·OEIS A008683) | #4183 |
| **Riemann ζ(s) 일반** | `zeta_int_scaled(s)` (Euler-Maclaurin·임의 정수 s≥2) + ζ(2~7) 고정밀 | #4188 (+#4172/#4173/#4185) |
| **Euler-Mascheroni γ** | `gamma_euler_scaled` (Brent–McMillan·25자리) | #4186 |
| **digamma ψ(x)** | `digamma_scaled`/`digamma_int_scaled` (DLMF 5.11.2·ψ(1)=−γ) | #4188 |
| **π/e 고정밀** | `pi_scaled`(Machin·40자리) · e=`exp_scaled(1)`(25자리) | #4166·#4186 |
| **BigInt ln/exp/√** | `ln_scaled`·`exp_scaled`·`sqrt_scaled` (ln2 48자리·reference-match) | #4186 |
| **임의정밀 산술 substrate** | full BigInt÷BigInt `bi_divmod` + `bi_gcd` (exact rational) | #4180 |

독립경로 cross-check: `zeta_int_scaled(2/3/4)` == 기존 `zeta2/3/4_scaled`(π²/6·Apéry·π⁴/90) 18자리 일치 →
Euler-Maclaurin 과 closed/accelerated 두 독립 고정소수점 경로가 같은 값(verdict-integrity 강화).

> 남은 후속(이 캠페인 범위 밖): atlas C 5763개 상수의 임의정밀 공식 보유 여부 전수 census · 임의 실수 s(비정수)
> ζ(s) · 추가 특수함수(Bessel·polylog 등)는 별도 라운드. 위 표 = atlas n6 P-primitive + 핵심 해석 상수 갭의 closure.

### (역사) 원래 GAP 표 — 측정 시점(닫히기 전)
| 항목 | atlas 등재 | (당시) stdlib 현황 |
|------|-----------|------------|
| Möbius μ(n) | af idx12 | `fn mobius` 없음 |
| Riemann ζ(s) 일반 | ζ(2)basel·ζ(3)apéry | 짝수·ζ(3)·ζ(5)·ζ(7) 고정밀만 |
| Euler-Mascheroni γ | BIG-Euler-mascheroni | 없음 (substrate 벽 예상·아래 §γ) |
| digamma ψ(x) | — | private(quantum 1곳)만 |
| π/e 고정밀 급수 | PI-* 26개 | π Machin만 |
| 임의정밀 e/특수함수 | 상수 40+자리 등재 | e는 float64만 |

## §γ — Euler-Mascheroni γ break-walls 측정 분류 (2026-06-28)

> 🏁 **RESOLVED (#4186)**: 아래 "BigInt ln/exp substrate 부재 = 측정벽" 분류는 같은 날 **falsified·돌파**됐다 —
> AGM 정밀도 한계를 우려했으나 atanh 고정소수점 ln/exp 가 ln2 48자리로 동작, γ 는 Brent–McMillan(렌즈 1)으로
> `gamma_euler_scaled` 25자리 구현·머지. 아래는 돌파 전 측정 기록(예상 벽≠실제 벽의 사례로 보존).

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

## 🏁 캠페인 종결 — substrate 사다리 + 후속 + 신규상수 전부 closed (2026-06-28)

GAP 테이블·후속·신규상수 캠페인이 모두 닫혔다. 위 "최고가치 다음 구현"으로 제시했던
**BigInt ln/exp substrate 는 예상벽이었으나 #4186 에서 falsified·돌파**(atanh 고정소수점) —
이후 사다리가 측정벽까지 진행됐다.

### 구현 완료 (전부 native BigInt·byteeq-neutral·summer reference-match)
- **substrate 13-PR 사다리**: π · ζ(2~7) · 일반 ζ(s) · Catalan · Bernoulli · Möbius μ · γ(Euler–
  Mascheroni·Brent–McMillan) · digamma ψ · ln/exp/sqrt/ln2 · full BigInt÷(Knuth Alg D) · gcd
  (#4161→#4188). 레버 연쇄 = i64한계→BigInt→full÷/gcd→ln/exp/sqrt→γ→digamma/일반ζ.
- **후속 특수함수 7종**(#4191/#4192/#4194): 실수-s ζ(s) · Bessel I₀/K₀ · lgamma/gamma ·
  erf/erfc · polylog Li_s · beta B(a,b) · 하부 불완전감마 P(s,x). DLMF reference-first.
- **신규상수 4종**(#4197·atlas 미등재 classical 초월상수): Lemniscate ϖ=Γ(1/4)²/2√(2π)(OEIS
  A062539)·Gauss G=ϖ/π(A014549) = **18자리 닫힌형** / Khinchin K₀(A002210)·Mertens
  M=γ+Σμ(k)lnζ(k)/k(A077761) = **~16자리**.

### 측정벽 (정직 분류 · 억지 fudge 금지)
- **K₀/M = ~16자리 정밀도 floor**: `ln_scaled` near-1 인자 상대정밀 한계 + 긴 급수(K₀ 74항·M
  146항) 누적오차. dd=44≡dd=56(printed digits 동일)으로 **dd-독립 = guard-truncation 아님** 입증.
  honest-next = atanh 가드자리↑(별도 substrate 개선 라운드).
- **polylog 단위원 경계**(|z|=1·z≠1): 멱급수 1/k² 수렴 → 18자리에 ~10⁹항. 가속/reflection 미구현
  honest-next(게이트 제외·결함 아님).
- **Glaisher–Kinkelin A = ζ'(−1)**: ζ 도함수 substrate 부재 → 1상수만 열려 투자부족 측정벽.
- **Feigenbaum δ/α · Conway · Madelung**: 단순 닫힌공식 부재(반복사상/결정격자합) = 별도 알고리즘
  라운드.

### atlas C-atom census ⓑ=∅ (읽기전용 measured)
embedded.gen.hexa `kind:"C"` atom 5763개 = dev-process 로그(omega_cycle_* ~4000)+meta+정수
divisor-arith+측정 물리상수(planck/boltzmann CODATA)뿐. **임의정밀 공식 있는데 미구현인 초월상수
= ∅**. 정준 해석상수(π·e·ζ·γ·Catalan·Bernoulli)는 C atom 아닌 highprec native fn 거주.
신규상수의 **atlas @F fold 등록은 별도 라운드**(`HEXA_ATLAS_EMBED` worktree + `hexa verify`
인프라 필요 = byteeq-RELEVANT). 재현 grep = `grep 'kind: "C"' embedded.gen.hexa | grep -oE
':: [a-z_-]+ '|sort|uniq -c`.

reference-match: numpy/scipy/mpmath(특수함수) · DLMF · OEIS. 빌드/검증=pool(summer/aiden·
mini=git/gh). SSOT = memory `project_hexa_native_bigint_substrate`. 갭은 measured(grep census
재실행 가능).
