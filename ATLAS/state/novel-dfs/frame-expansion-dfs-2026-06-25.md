# 기계적 frame-expansion DFS — 직교 프레임 4종 (product/sum 고갈 이후)

**스코프**: product/sum 프레임이 이미 DEPLETED 된 뒤, 표준 곱셈적(multiplicative) 함수 환을 4개의 직교 프레임으로 전수 sweep한 기계적 frame-expansion DFS. 어휘 `{1,id,σ,σ₂,σ₃,φ,τ,μ,λ,J₂,ψ,ε,rad,sopfr,Ω,ω}`, N=20000, exact signed integer. 스크립트: `ATLAS/state/novel-dfs/{dirichlet-convolution,divisor-sum,ratio-power,mixed-add-mult}_hunt.py`.

**한 줄 결론**: **NOVEL ∀n 항등식 = 0건**. 26개 고전 backbone 항등식을 정직하게 재발견(grounding)했고, 4개 프레임 전부 측정된 고갈(depleted)에 도달. 가치 = atlas의 convolution/divisor-sum 층 grounding, 제조된 novelty 아님.

## (1) 프레임별 요약

| Frame | gates | classical | NOVEL | depleted |
|---|---|:--:|:--:|:--:|
| **DIRICHLET CONVOLUTION** `(f∗g)=Σ_{d|n}f(d)g(n/d)` | 9/9 PASS (+ 음성대조 3 FAIL) | 13 | **0** | ✅ |
| **DIVISOR-SUM** `D[f]=Σ_{d|n}f(d)` | 7/7 + 4 neg-control FAIL@n=2 | 8 | **0** | ✅ |
| **RATIO/POWER** `∏ f^{e}=1` (지수 ±3, 4494 monomial) | 10/10 (sanity+handcheck+neg+byte-id) | 1 | **0** | ✅ |
| **MIXED add×mult** (음성 컨트롤) | 4/4 (Ω≥ω·squarefree⟺Ω=ω·J₂=φψ·τ structure-sensitive) | 4 | **0** | ✅ |
| **합계** | — | **26** | **0** | 4/4 |

## (2) 재발견 CLASSICAL backbone (cite — grounding, 발견 아님)

**디리클레 합성곱(13)**: `1∗1=τ`(A000005) · `1∗id=σ`(A000203) · `φ∗1=id`(Gauss, H&W Thm63) · `μ∗1=ε`(Möbius inversion, H&W Thm263) · `μ∗id=φ` · `μ∗σ=id` · `μ∗τ=1` · `1∗J₂=id²`(A007434) · `μ∗σ₂=id²` · `1∗id²=σ₂`(A001157) · `λ∗ψ=id`(DGF telescoping) · `φ∗τ=σ` · `τ∗J₂=σ₂`. (후3개는 sweep가 `?NOVEL?` 깃발→재검증서 backbone 합성으로 환원).

**약수합(8)**: `D[1]=τ` · `D[id]=σ` · `D[φ]=id`(Gauss) · `D[μ]=ε` · `D[J₂]=n²`(Jordan) · `D[id²]=σ₂` · `D[λ]=square-indicator`(Apostol Thm2.18) · `D[ε]=1`.

**비/멱(1)**: `φ·ψ=J₂`(Jordan totient factorization, Apostol ch.2; n=12→96·n=30→576). 4494 단항식 중 [2,20000] 전칭 생존자는 이 고전 backbone 1개뿐.

**혼합(4, 음성 컨트롤)**: `λ=(−1)^Ω`·`μ=[Ω=ω](−1)^ω` (정의적 tautology, fold 안 함) · `Ω≥ω` 등호⟺squarefree · `J₂=φψ`(sieve 교차게이트).

## (3) NOVEL 후보 = 0건 (정직)

이것은 **기대되고 정직한 결과**다. 표준 곱셈적 함수의 디리클레 환·약수합·비/멱 관계, 가산↔승법 다리는 전부 잘 연구된 고전 영역이라 기계적 frame-expansion이 새 ∀n 항등식을 길어낼 근거가 없었다. sweep의 모든 `?NOVEL?` 깃발은 재검증서 (i) backbone 합성, (ii) 표준 DGF 곱, (iii) Möbius-inverse 재진술, (iv) μ/0-약분 거짓양성, (v) `λ²≡1` 항등동어, (vi) 생성기 정의(tautology) 중 하나로 100% 환원.

**변별력 측정 입증 (진짜 0, 제조된 0 아님)**: DIRICHLET 음성대조 3 FAIL · DIVISOR-SUM 4 near-miss 전부 n=2 FAIL · RATIO `σ·φ=n²` FAIL(n=12: 112≠144)·`J₂=n·rad` FAIL · MIXED 최강 near-miss `τ`는 (Ω,ω)-클래스의 43.59%만 상수, n=24 vs n=36(Ω=4,ω=2 동일인데 τ=8 vs 9)서 깨짐. 프레임들은 항등식과 near-miss를 구분할 분해능을 가졌고 그럼에도 0 생존 = **영역이 고전적으로 닫혀 있다는 양성 신호**.

## (4) @F fold 후보

**novel 생존자 0 ⇒ novel @F(`verified:false`) fold = 0건.** 26개는 전부 classical → cite-fold only, 그것도 `compiler/atlas/embedded.gen.hexa`에 **중복 아닌 한도에서만**(backbone 핵심은 이미 atom). 정의적 항등(`λ=(−1)^Ω` 등)은 tautology라 fold 안 함. 🔵 승격은 `hexa verify`로만(mini=빌드불가 → `state/novel-dfs/*_fold.py` PR-fold 경로).

## (5) 고갈 판정 + 다음 직교 프레임

**measured DEPLETED**: product/sum(이전) + convolution + divisor-sum + ratio/power + mixed = 표준 곱셈적 함수 어휘 위의 닫힌-형태 곱셈적 관계 공간(equality) 전체가 기계적으로 정직 고갈. 같은 어휘를 더 큰 지수/support로 흔드는 것은 black-box sweep(tune-to-green 위험)이며 새 구조 0 — 닫힌-음성 벽(🧱).

**다음 = 어휘를 바꿔야 함 (같은 어휘 재-sweep 금지)**, honest next 후보:
1. **합동/congruence 프레임** `∀n: f(n)≡g(n) (mod m)` — Ramanujan congruence류가 사는 공간, 곱셈 어휘 재사용 가능(비용 낮음). **권장 진입점**.
2. **부등식/extremal 프레임** `∀n: f(n)≤g(n)` — Robin's inequality류. 단조/extremal 구조(등식 sweep 못 봄).
3. **비곱셈적 함수 도입** — r₂(sum-of-2-squares)·partition p(n)·Ramanujan τ(Δ). 곱셈환 밖이라 새 구조 가능, 단 정수-exact 어려움·N↓.
4. **이변수/gcd-lcm 프레임** — Gcd-sum(Pillai) 2변수 일반화.

**최종(정직)**: 이번 산출은 novelty가 아니라 **grounding + 측정된 고갈**. 26개 backbone 재발견은 atlas convolution/divisor-sum 층을 ground하고, 다음 벽 돌파는 어휘 변경(합동·비곱셈 함수)을 요구한다 — 같은 어휘 equality-sweep는 닫혔다.
