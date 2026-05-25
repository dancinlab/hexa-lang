# tecs-l-mersenne-exponent-primality — 지수 소수성 ⇏ 메르센 소수성

> TECS-L 도메인 MERSENNE 축(B: MR1-MR7)을 하나의 사전등록 falsifier 둘레로
> 집약한 arxiv-스타일 논문. 검증된 Euclid-Euler 완전수 코어(완전수 ↔ 메르센
> 소수 · σ(P)=2P · τ=2p) 위에 **closed-negative** 헤드라인 발견을 올린다.

## 헤드라인 발견 (사전등록 + 측정 + closed-negative — paper_significance 충족)

**MR6 (지수 소수성 ⇏ 메르센 소수성)** — "p 소수 ⟹ M_p = 2^p−1 소수" 는
**거짓**이다. p=11(소수) 에서 M_11 = 2047 = 23×89 **합성수**
(σ(2047)=2160≠2048 · τ(2047)=4≠2; 두 인수 23·89 는 각각 σ=n+1·τ=2 로 소수
검증 → 정확 인수분해). 사전등록 falsifier 기각 🔴 — Euclid 구성
2^(p−1)·M_p 가 **모든 소수 지수에서 완전수를 낳지는 않는다** (메르센-소수
가설은 필수). 추가 합성 증인 M_23=47×178481 · M_29=233×1103×2089 로
"p=11 우연이 아님" 확정. **배제된 axis = 지수 소수성만으로 완전수 생성**.
verdict: `.verdicts/tecs-l-mersenne-composite/`.

## 검증된 positive 배경 (Euclid-Euler 코어, 🔵)

- **MR1 (Euclid-Euler 🔵)** — 짝완전수 n ⟺ n = 2^(p−1)·M_p (M_p 메르센 소수).
  perfect ↔ Mersenne 다리. verdict `.verdicts/tecs-l-mersenne-euclid-euler/`.
- **MR3 (abundancy 닫힌형 🔵)** — σ(P)=2P (σ 곱셈성 + 2^(p−1)·M_p 서로소 +
  소수멱/소수 σ 공식). 첫 7 완전수 P_1..P_7 cross-check.
  verdict `.verdicts/tecs-l-mersenne-abundancy-closed/`.
- **MR2/MR5** — P_6=8589869056 · P_7=137438691328 `is_perfect`=1 + σ=2P (🔵)
  + τ(2^(p−1)·M_p)=2p 첫 7 완전수 닫힌형 (🔵).
  verdict `.verdicts/tecs-l-mersenne-{perfect,tau-2p}/`.

## 정직하게 열린 frontier (🟠, NOT 닫힘)

- **MR7 (odd-perfect 🟠 OPEN)** — 홀완전수 존재 여부는 미해결. 알려진 것은
  **하한·필요조건**(n>10^1500 Ochem-Rao 2012 · ω≥9 Nielsen 2015 · 최대소인수
  >10^8 Goto-Ohno 2008 · Ω≥101 Ochem-Rao 2014 · Euler 형식)뿐 — 존재/비존재
  증명 아님. **논문에서 finding 으로 절대 쓰지 않음**; 헤드라인은 MR6
  closed-negative. verdict `.verdicts/tecs-l-mersenne-odd-perfect-open/`.

## 구성

- `main.tex` — 단일 컬럼 arxiv-스타일 LaTeX (article, 11pt A4), ≥10 페이지.
  §abstract · §1 statement (MR6 falsifier: 지수-소수성 ⇏ 메르센-소수성) · §2
  method (M_p 소수성 테스트 p≤13 · M_11=2047 정확 인수분해 · Euclid-Euler
  다리 · abundancy σ=2n) · §3 verification (실제 hexa-verify — M_11 합성 ·
  perfect↔Mersenne 다리 · σ(P_k)=2P_k for P_5/P_6/P_7) · §4 finding (MR6
  closed-negative + 검증된 Euclid-Euler 코어) · §5 caveats + open frontier
  (MR7 odd-perfect OPEN — 잔여, 닫힌 것 아님) · §6 related (Mersenne primes ·
  perfect numbers · GIMPS) · 부록 A/B/C/D/E (M_p 표 p≤13 인수분해 ·
  완전수 abundancy 표 · τ=2p 표 · abundancy 닫힌형 유도 · raw verdict ASCII).
- `references.bib` — BibTeX (Euclid · Euler 1849 · Hardy-Wright · Lucas-Lehmer ·
  GIMPS · odd-perfect 하한들 + TECS-L 체인). 전부 DOI/URL.
- `figures/fig01_mersenne.png` — fal.ai (gpt-image-2) 생성. 지수-소수성 ⇏
  메르센-소수성 break (p=11 소수지만 M_11 합성) + Euclid-Euler perfect↔Mersenne
  다리 도식. 프롬프트 출처 `figures/_prompts/fig01_mersenne.txt`.
- `Makefile` — `make` = pdflatex × 3 + bibtex.

## 빌드

```bash
make            # → main.pdf
make clean      # .aux/.log/.bbl 제거 (PDF 보존)
make distclean  # PDF 도 제거
```

## 정직성 입장 (paper governance)

- 모든 수치는 `hexa verify --expr` closed-form 재계산 →
  `.verdicts/tecs-l-mersenne-*/` 에 verbatim 영속 → `CLAIMS.tape`
  (group TECS-L) 에 1:1 verdict 포인터로 색인.
- 헤드라인 발견은 **closed-negative** — paper_negative_ok 거버넌스상
  publishable. MR6 은 Euclid-Euler 정리의 *역명제 과확장*("p 소수 ⟹ M_p 소수")을
  기각한 것이지 정리 자체를 기각한 게 아님 (§5 caveats 명시).
- 사전등록 falsifier 는 method 절(§2)에 측정 전에 고정.
- **MR7 odd-perfect 는 정직하게 OPEN 으로 표기 — finding 으로 쓰지 않음**.
