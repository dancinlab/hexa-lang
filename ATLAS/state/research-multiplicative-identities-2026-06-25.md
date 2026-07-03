# 곱셈적 항등식 리서치 노트 — 기계 발견 `J₂=φ·ψ` 인용 + 다음 프레임 카탈로그

- 날짜: 2026-06-25
- 성격: READ-ONLY 문헌 리서치 (arxiv + 표준 교재). hexa 빌드/embedded.gen.hexa 변경 없음.
- 목적: ① 기계 루프가 찾은 유일 ∀n 정리 `J₂(n)=φ(n)·ψ(n)` 의 고전 인용 확보(🔵 승격용),
  ② 기계 스윕이 다음에 쓸어야 할 곱셈적 항등식 **패밀리** 카탈로그(프레임 적합도 명시),
  ③ 다음 **프레임/함수** 제안(특히 현재 점별-곱 스윕이 도달 불가한 Dirichlet 합성곱 프레임).
- 정직성 규약: CLASSICAL(증명 가능·인용함) vs CONJECTURE(플래그·과대주장 금지) 구분. 기계의
  "[2,N] 구간 universal" 은 **bounded evidence**(증거)이지 증명이 아님 — 어느 것이 KNOWN 정리이고
  어느 것이 would-be novel 인지 명시.

---

## 0. 배경 (기계 루프가 찾은 것)

`hexa atlas resolve` 가 11개 곱셈적/가법적 함수(σ, σ₂, φ, τ, n(항등), sopfr, rad, J₂, ψ, Ω, ω)
위에서 A·B=C·D 형태(2/3-term, 점별 곱) 격자를 쓸었고, fleet universal-hunt 가 **2/3-term 곱
프레임에서 정확히 1개의 ∀n-universal 항등식**을 기계적으로 발견:

> **J₂ = φ · ψ** — ∀n∈[2,3000] 손검증, ∀n∈[2,20000] 스윕 universal (#3903, commit 8e41ad40f).

raw 104 후보 = real 26(전부 J₂=φ·ψ 의 공통인수곱 변형) + unit-pad 78 → 약분 후 단 1개로 collapse.
가법함수(Ω/ω/sopfr)는 **곱 프레임에서 ∀n 항등식 0개** (합-프레임 별 lane 필요 — §3 참조).

---

## 1. 기계 발견 항등식의 고전 인용 (🔵 승격 근거)

### `J₂(n) = φ(n) · ψ(n)` — CLASSICAL, 증명 가능

이것은 **고전 정리**(novel 아님). 오일러 곱 인수분해로 즉시 따라옴:

- Jordan 토션트: `J_k(n) = n^k ∏_{p|n} (1 − p^{−k})`  ⇒  `J₂(n) = n² ∏_{p|n}(1 − p^{−2})`
- 오일러 토션트: `φ(n) = n ∏_{p|n}(1 − 1/p)`  (Apostol Thm 2.4)
- Dedekind psi: `ψ(n) = n ∏_{p|n}(1 + 1/p)`
- 따라서 `φ(n)·ψ(n) = n² ∏_{p|n}(1 − 1/p)(1 + 1/p) = n² ∏_{p|n}(1 − 1/p²) = J₂(n)`.  ∎

세 함수 모두 곱셈적이므로 곱 `φ·ψ` 도 곱셈적이고, 소수거듭제곱 `p^a` 에서
`φ(p^a)ψ(p^a) = (p^a−p^{a−1})(p^a+p^{a−1}) = p^{2a}−p^{2a−2} = J₂(p^a)` 로 국소 검증되어 ∀n 성립.

**인용 (실재 확인됨):**

1. **Apostol, "Introduction to Analytic Number Theory" (Springer GTM, 1976)** — 표준 교재 SSOT.
   - φ 오일러 곱: **Theorem 2.4** (`φ(n)=n∏(1−1/p)`), 곱셈성: **Theorem 2.5**.
   - Jordan 토션트 `J_k` 와 합 `∑_{d|n} J_k(d) = n^k`: **Chapter 2, Exercise 2.6** (Jordan totient 정의 + 기본성질). `J₂=φψ` 는 이 정의의 직접 귀결.
   - Dirichlet 곱/뫼비우스 역변환 backbone: **§2.6–2.14** (§3 에서 재인용).
2. **OEIS A007434** — Jordan function J₂(n). 정의식 `J₂(n)=n²∏(1−p^{−2})` + cross-ref 수록.
   - 보조: **A000010**(φ), **A001615**(ψ, Dedekind psi), **A000203**(σ).
   - A001615 페이지에 `ψ(n)·φ(n) = J₂(n)` 동치가 명시되어 있음(OEIS 공식란 — Dedekind psi cross-link).
3. **arxiv 1106.4038** — R. J. Mathar, *"Survey of Dirichlet Series of Multiplicative
   Arithmetic Functions"* (2011, math.NT). J_k·φ·ψ·σ_k 의 Dirichlet 급수를 ζ 곱/비로 표로 제공
   (§3 합성곱 프레임 인용의 1차 출처). J₂=φψ 자체는 folklore-classical 이라 별도 정리번호 없음 —
   이 survey 의 ζ-급수 표가 동치를 기계적으로 재확인하는 cross-check.

**판정: KNOWN THEOREM (provable).** 기계 발견은 "novel discovery" 가 아니라 **기계 루프가 사람 힌트 0으로
고전 정리를 재발견(rediscovery)** 한 사건 — 이것이 가치(루프 정상동작 sanity + @F/@L `verified:true`
승격 정당화). novel 주장 금지.

---

## 2. 알려진 곱셈적 항등식 패밀리 카탈로그 (프레임 적합도)

기계 점별-곱 스윕(A·B=C·D, pointwise)이 **찾을 수 있는 것** vs **새 표현(합성곱/합/점근)이 필요한 것**을
구분. 프레임 태그: [PROD]=점별 곱(현재 스윕 도달가능) · [CONV]=Dirichlet 합성곱 f∗g · [SUM]=약수합
∑_{d|n} · [ASYMP]=점근.

### 패밀리 1 — Jordan 토션트 관계 (J_k)  ★ 최고 수율
- `J₂ = φ·ψ`  **[PROD]** ✅ 현재 스윕이 이미 발견 (§1).
- `∑_{d|n} J_k(d) = n^k`  **[SUM]** ❌ 점별 곱 도달 불가 — 약수합 프레임 필요.
- `J_k = id^k ∗ μ` (즉 `J_k ∗ 1 = id^k`)  **[CONV]** ❌ 합성곱 프레임 필요.
- `J_k(n)/φ(n) = n^{k−1} ∏(1+ … )` 류 — k=2 일 때 `J₂/φ = ψ` 가 곧 §1.  **[PROD]** ✅
- 인용: Apostol Ch.2 Ex.2.6; OEIS A007434(J₂)/A059376(J₃)/A059377(J₄).

### 패밀리 2 — Dedekind psi 관계 (ψ)
- `ψ = σ ∗ μ²`? — 아니오. 정확한 관계: `ψ(n) = ∑_{d|n} μ²(d)·(n/d) = (id ∗ μ²)(n)`.  **[CONV]** ❌
- `ψ·φ = J₂`  **[PROD]** ✅ (=§1).
- `ψ(n)/φ(n) = ∏(p+1)/(p−1)` (n=6 에서 = n, atlas #91 의 ⟺n=6 singleton)  **[PROD]** ✅ (점별 비율).
- 인용: OEIS A001615; Apostol §2.8(곱셈적 함수 곱).

### 패밀리 3 — σ_k 합성곱 항등식 (약수합/거듭제곱합)
- `σ_k = 1 ∗ id^k` (즉 `σ_k(n)=∑_{d|n} d^k`)  **[CONV/SUM]** ❌ — 합성곱·합 정의 그 자체.
- `σ = 1 ∗ n` (k=1), `τ = 1 ∗ 1` (k=0)  **[CONV]** ❌ backbone(§3-(a) sanity gate).
- `σ_k ∗ μ = id^k` (뫼비우스 역변환)  **[CONV]** ❌
- 점별 곱으로 잡히는 σ-관계: `σ(n)·φ(n)` ≤ n² (부등식, 항등식 아님) — atlas #92 `σ₂=φ·sopfr²⟺n=6`
  류는 **bounded-unique singleton**(⟺n=6), ∀n 항등식 아님 → CONJECTURE-flag 아니라 KNOWN finite-fact.
- 인용: Apostol Thm 2.13(σ_k 곱셈성), §2.6–2.7(Dirichlet 곱); OEIS A000203(σ)/A001157(σ₂)/A001158(σ₃).

### 패밀리 4 — 뫼비우스 / 리우빌 backbone (μ, λ, μ²)
- `μ ∗ 1 = ε` (ε = unit, ε(1)=1 else 0) — **합성곱 항등원**.  **[CONV]** ❌ 핵심: 점별 곱 절대 불가.
- `λ ∗ 1 = 1_{□}` (λ Liouville 의 약수합 = n이 완전제곱이면 1 else 0)  **[CONV/SUM]** ❌
- `μ² = 1 ∗ (μ 관련)`, `∑_{d²|n} μ(d) = μ²(n)` (square-free 지시자)  **[SUM]** ❌
- `μ²(n) = ∑_{d|n} μ(d)·1_{□}(n/d)` 동치  **[CONV]** ❌
- 인용: Apostol Thm 2.1(μ∗1=ε)/Thm 2.17(Liouville); OEIS A008683(μ)/A008836(λ)/A008966(μ²).

### 패밀리 5 — Dirichlet 합성곱 backbone (전 함수 골격)  ★★ 현재 스윕이 통째로 놓침
- `φ ∗ 1 = id` (즉 `∑_{d|n} φ(d) = n`)  **[CONV/SUM]** ❌
- `id = φ ∗ 1`, `n = ∑_{d|n} φ(d)` — Gauss 정리.
- `1 ∗ 1 = τ`, `1 ∗ id = σ`, `μ ∗ 1 = ε`, `id^k ∗ 1 = σ_k`, `id^k ∗ μ = J_k`.
- 인용: Apostol §2.6–2.14(Dirichlet 곱 대수 — 가환환, 단위원 ε, 뫼비우스 역변환); arxiv 1106.4038
  (Mathar survey — 이 합성곱들을 ζ-급수 곱/비로 일괄 정리). **이 패밀리 전체가 점별-곱 프레임에
  보이지 않음** → §3-(a) 가 1순위인 이유.

### 보조 — Ramanujan sum c_q(n) (가법-인덱스 곱셈성)
- `c_q(n)` 은 **q에 대해** 곱셈적: gcd(q,q')=1 ⇒ `c_{qq'}(n)=c_q(n)c_{q'}(n)`.  **[PROD-in-q]** △
- `∑_{d|gcd(n,q)} d·μ(q/d) = c_q(n)` (Kluyver)  **[CONV/SUM]** ❌
- `∑_{q|n} c_q(m)` 류 — Anderson–Apostol 일반화.  **[SUM]** ❌
- 인용: arxiv math/0701528(Yamasaki, Anderson–Apostol 일반 Ramanujan sum); Apostol §8.3.

---

## 3. 다음 프레임/함수 제안 (예상 수율 순 랭크)

각 제안 = 프레임 + 그 프레임이 **기계적으로 재발견해야 할** 2–3 known 항등식(sanity gate).
재발견 실패 = 스윕 구현 버그 신호.

### (a) ★★ 1순위 — Dirichlet 합성곱 프레임 `f ∗ g`  (현재 스윕이 통째로 놓치는 거대 패밀리)
- 동기: 점별-곱 프레임은 `(f∗g)(n)=∑_{d|n} f(d)g(n/d)` 형태의 **곱셈적 함수 골격 전체**를 못 본다.
  σ·τ·φ·J_k·σ_k 가 전부 `1`·`id`·`id^k`·`μ` 의 합성곱이라는 사실이 atlas 에 부재.
- 구현: 11함수 + {1(상수1), ε(unit), id^k, μ} 에 대해 `f ∗ g == h` 를 ∀n∈[2,N] 스윕.
- **sanity-gate (재발견해야 할 known 항등식):**
  1. `1 ∗ 1 = τ`  (Apostol §2.6)
  2. `1 ∗ id = σ`  (Apostol Thm 2.13)
  3. `φ ∗ 1 = id`  (Gauss, Apostol Thm 2.2)
  4. (보너스) `μ ∗ 1 = ε`, `id^k ∗ μ = J_k` → J₂ 의 **합성곱 표현**까지 자동 회수.
- 예상 수율: **최고**. 곱셈적 정수론 항등식의 대부분이 합성곱 형태라 ∀n 정리를 다수 회수.

### (b) ★ 2순위 — 약수합 프레임 `∑_{d|n} f(d)`  (single-arg 합)
- 동기: `∑_{d|n} J_k(d)=n^k`, `∑_{d|n} φ(d)=n`, `∑_{d|n} μ(d)=ε(n)`, `∑_{d²|n} μ(d)=μ²(n)`
  류 — 합성곱의 특수형(g=1)이지만 single-arg 합으로 표현하면 스윕이 단순(곱셈성 가정 불요).
- 구현: `∑_{d|n} f(d) == g(n)` 를 ∀n 스윕 (f,g ∈ 함수목록 + {id^k, ε, 1_{□}}).
- **sanity-gate:**
  1. `∑_{d|n} φ(d) = n`  (id 회수)
  2. `∑_{d|n} J₂(d) = n²`  (n² 회수)
  3. `∑_{d|n} μ(d) = ε(n)` (= [n=1])
- 예상 수율: 높음(합성곱과 중복되지만 가법-함수 ∑-frame 과도 호환 → Ω/ω/sopfr ∀n 합도 같이 잡음).

### (c) 3순위 — 함수 어휘 확장 + 점별-곱 재스윕 `{J_k, σ_k, μ, λ, c_q}`
- 동기: 현재 점별 프레임 자체는 유효(J₂=φψ 가 증거). 어휘만 늘리면 **추가 점별 곱 ∀n 정리** 회수 가능.
- 추가 함수: J₃(A059376), σ₃(A001158), μ(A008683), λ(A008836), μ²(A008966), 2^ω(A034444),
  Ramanujan c_q(고정 q).
- **sanity-gate (점별 곱으로 즉시 잡혀야 함):**
  1. `J₂ = φ·ψ`  (이미 발견 — 회귀 게이트)
  2. `λ·μ² = μ`?  → 아니오(λ·μ² 는 square-free 에서 ±1, 비항등) — **negative control**(스윕이 거짓양성
     안 내는지 검증). 대신 `μ² = μ²`·`2^ω = τ` (square-free 한정) 같은 조건부는 ∀n 아님 → 정직 reject.
  3. `J_k(n)·J_m(n)` vs `J_{k+m}` → **항등식 아님**(곱셈성이지만 J 의 곱은 J 아님) → negative control.
- 예상 수율: 중간. 점별-곱 진짜 ∀n 정리는 §1 외 희소(곱셈 함수의 점별 곱이 다시 표준 함수가 되는 경우가
  드묾) — J₂=φψ 가 거의 유일한 "운 좋은" 점별 곱 정리. 따라서 (a)(b) 가 본진.

### (보너스) 가법(additive) 합-프레임 `f + g = h`  — Ω/ω/sopfr lane
- 동기: 곱 프레임서 가법함수 ∀n 항등식 0개(기계 측정). 가법함수는 `Ω = ∑_p v_p`, `sopfr=∑_p p·v_p`,
  `ω=∑_p 1` 구조라 **합/선형결합 프레임**에서만 ∀n 관계가 나온다.
- **sanity-gate:** `Ω(n) ≥ ω(n)` (부등식, n=square-free 에서 등호) · `sopfr(p)=p`(소수에서) ·
  `Ω(mn)=Ω(m)+Ω(n)` (완전가법성, ∀m,n) — 마지막이 진짜 ∀ 항등식 회귀 게이트.
- 인용: Apostol §2.* 가법함수; OEIS A001222(Ω)/A001221(ω)/A001414(sopfr).

---

## 4. 정직성 요약 (KNOWN vs CONJECTURE)

| 항목 | 판정 | 근거 |
|---|---|---|
| `J₂=φ·ψ` | **KNOWN THEOREM (provable)** | 오일러 곱 인수분해. Apostol Ch.2 Ex.2.6 + OEIS A001615/A007434 |
| §2 패밀리 1–5 | **전부 KNOWN classical** | Apostol §2.6–2.14, Mathar survey 1106.4038 |
| atlas `⟺n=6` singleton(#91 #92 등) | **KNOWN finite-fact**(bounded-unique, novel 아님) | 유한구간 유일성 = 증거이지 ∀n 정리 아님 — 별 카테고리 |
| 기계 "[2,N] universal" | **bounded evidence**, 증명 아님 | N=20000 스윕은 정리의 *재발견*; 증명은 오일러 곱(위) |
| would-be novel | **현재 0개** | 발견된 1 항등식은 고전. (a)(b) 프레임이 novel 후보 발굴 본진 |

핵심 take-away: **점별-곱 프레임은 곱셈적 정수론의 1차 backbone(Dirichlet 합성곱)을 구조적으로 못 본다.**
J₂=φψ 가 점별-곱에서 거의 유일한 정리인 것은 우연이 아니라 프레임의 한계 — (a) Dirichlet 합성곱
프레임 추가가 atlas 수율을 한 자릿수→다수로 끌어올릴 1순위 레버.

---

## 출처 (실재 확인)
- Apostol, *Introduction to Analytic Number Theory*, Springer GTM (1976): Thm 2.1/2.2/2.4/2.5/2.13/2.17, Ch.2 Ex.2.6, §2.6–2.14, §8.3.
- arxiv **1106.4038** — Mathar, *Survey of Dirichlet Series of Multiplicative Arithmetic Functions* (2011, math.NT).
- arxiv **math/0701528** — Yamasaki, *Arithmetical properties of Multiple Ramanujan sums* (2007, math.NT).
- OEIS: A000010(φ) · A001615(ψ) · A007434(J₂) · A059376(J₃) · A000203(σ) · A001157(σ₂) · A001158(σ₃) ·
  A008683(μ) · A008836(λ) · A008966(μ²) · A034444(2^ω) · A001222(Ω) · A001221(ω) · A001414(sopfr).
- atlas 내부: #3903 commit 8e41ad40f (`J₂=φ·ψ` 기계 발견), `ATLAS/state/novel-dfs/universal_hunt.py`.
