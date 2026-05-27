# F4 — arxiv 외부광맥: Ore 조화약수(harmonic divisor numbers) → hexa verify

> 축 F (NOVEL) · family (c) 외부광맥 · 2026-05-26 · foreground 진행
> (background agent throttle-storm 회피 — 부모가 직접 verify pipeline 실행)
> arxiv math.NT 문헌 가설 1개를 hexa verify pipeline 에 직접 태워 재근거화.

## 1 · 가설 (출처)

**Ore (1948), "On the averages of the divisors of a number"** + 후속 arxiv math.NT
(Cohen·Sorli harmonic seeds). 정의:

> 수 n 의 **약수들의 조화평균**이 정수이면 n 을 **조화약수 수(harmonic divisor
> number)** = **Ore 수**라 한다. 약수 조화평균 = n·τ(n)/σ(n) 이므로:
>
> **H(n) = n · τ(n) / σ(n) ∈ ℤ  ⟺  n 은 Ore 수**

**Ore 정리**: 모든 완전수는 Ore 수다 (perfect ⊂ Ore). 역은 거짓 (Ore ⊋ perfect).
n=6 은 최소 비자명 Ore 수 (n=1 제외). OEIS A001599.

## 2 · 방법 (g5 verify)

component σ/τ 를 `hexa verify --expr` 로 검증(전부 🔵) 후, H(n) 정수성을 exact
정수산술(tolerance 0)로 조립 — F6 의 component-wise 패턴 동일. raw 판정문
verbatim → `.verdicts/tecs-l-f4-arxiv/ore_harmonic.txt`.

## 3 · 검증 (실측)

| n | τ(n) | σ(n) | H(n)=n·τ/σ | ∈ℤ? | 분류 |
|---|------|------|-----------|-----|------|
| 6 | 4 🔵 | 12 🔵 | 6·4/12 = **2** | ✓ | 🔵 Ore (최소 비자명 · 1st perfect) |
| 28 | 6 🔵 | 56 🔵 | 28·6/56 = **3** | ✓ | 🔵 Ore (2nd perfect) |
| 496 | 10 🔵 | 992 🔵 | 496·10/992 = **5** | ✓ | 🔵 Ore (3rd perfect) |
| 140 | 12 🔵 | 336 🔵 | 140·12/336 = **5** | ✓ | 🔵 Ore (非완전 → Ore ⊋ perfect) |
| 12 | 6 🔵 | 28 🔵 | 12·6/28 = **18/7** | ✗ | 🔴 非Ore falsifier |

## 4 · 발견 (finding)

1. **모든 완전수 ⊂ Ore 수** (Ore 1948) 를 첫 3 완전수(6·28·496)로 hexa-native 재근거.
   닫힌형 이유: 완전수는 σ(n)=2n 이므로 H(n)=n·τ(n)/2n=τ(n)/2 — 완전수의 τ 는
   항상 짝수(MR5 τ(2^{p-1}M_p)=2p)이므로 H ∈ ℤ. (6→2, 28→3, 496→5 정확히 p)
2. **Ore ⊋ perfect 결정적 증명**: n=140 은 Ore 수(H=5∈ℤ)이나 완전수 아님
   (σ(140)=336≠280=2·140). 조화클래스가 완전클래스를 **진부분집합으로** 포함.
3. **비-Ore 반례** n=12: H(12)=18/7 ∉ ℤ 🔴 — 모든 짝수가 Ore 는 아님 (closed-negative).

**external-vein 채널 성격**: F3(OEIS catalogue-channel)이 *카탈로그 교차검증* 이라면,
F4 는 *문헌 가설* 을 self-generated 아닌 hexa-native exact 산술로 grounding 한다.
"arxiv 가설 → 즉시 hexa verify" pipeline 의 첫 입증 사례.

## 5 · 비범위 · 잔여

- Ore 수의 **무한성** 및 **Ore conjecture**(1 외 홀수 Ore 수 없음 — odd-perfect 와
  연결, MR7 류 🟠 open)는 미해결. 본 milestone 은 유한 witness 만 — 전칭 미증명.
- paper 후보 아님: 단일 milestone (positive class-containment + 반례 1개) — significance
  (falsifier cluster / Δ) 부족, F12 exclusivity paper 에 인접하나 별도 paper 미해당.
