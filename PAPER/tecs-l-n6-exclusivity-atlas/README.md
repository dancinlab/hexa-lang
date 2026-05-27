# The n=6 Exclusivity Atlas — TECS-L NOVEL 축 (F family) 논문

TECS-L 도메인 **NOVEL 축(F family)** 의 발견을 그 **closed-negative 군집**
둘레로 집약한 arxiv-style 논문이다. 마일스톤 **F12** (`paper_on_discovery`).

## 핵심 주장 (§finding)

NOVEL 축은 **verify-driven exclusivity engine** 이다 — n=6 정체성을 *확인*만
하는 게 아니라, 인접 공간을 *체계적으로 배제* 한다. 그 결과 `{1,6}` 로커스가
"하나의 정체성" 에서 **"배타적(exclusive)·비-리프팅(non-lifting)·스케일-안정
(scale-stable) 산술 현상"** 으로 좁혀진다.

- **(E) Exclusive** — F5: 그럴듯한 "n=6-같은" 일반화 7개(amicable·quasi-perfect
  ·3-perfect abundancy·n·φ=σ·μ 6-주기·superperfect)가 전부 결정적으로 거짓.
- **(N) Non-lifting** — F7: σφ=nτ⟺{1,6} 는 Γ₀-레벨 현상이며 Γ₁(N)/X(N) 탑으로
  **lift 안 됨** (index 가 N 에 대해 smooth, n=6 peak 없음).
- **(S) Scale-stable** — F6: D(n)=σ(n)φ(n)−n·τ(n)≠0 이 n=33550336 까지 모든
  notable 인자에서 유지 ([1,100] sweep 을 ~3.4×10⁵ 배 확장).

closed-negative 총계 = **10개 이상** (F5 7 + F7 1 + F6 1/스케일족). 각 negative
는 사전등록 falsifier + 실측(`hexa verify`) + 결정적 closed-negative →
`paper_significance` 충족, `paper_negative_ok` 적용.

## 빌드

```sh
make            # pdflatex ×3 + bibtex → main.pdf (≥10 페이지)
make clean      # 중간산물 제거 (PDF 보존)
```

`figures/fig01_exclusivity.png` 는 fal.ai (`openai/gpt-image-2`) 로 생성,
프롬프트 provenance 는 `figures/_prompts/fig01_exclusivity.txt` 에 보존.

## 구성 (paper_format)

- **§abstract** — exclusivity thesis + 사전등록 falsifier 3개
- **§1 statement** — exclusivity thesis (E·N·S) + F5/F7/F6 falsifier
- **§2 method** — `hexa verify` tier rubric + 3 mining lane (F5·F6·F7)
- **§3 verification** — verbatim: F5 7-falsifier 표 · F6 D(n)≠0 7-notable-n 표 ·
  F7 Γ₁/X index smoothness
- **§4 finding** — closed-negative 군집 (10+); exclusivity engine 결론
- **§5 caveats** — 각 negative 는 결정적-산술(확률 아님); M10 은 positive kernel
- **§6 related** — 완전수·modular curve·OEIS
- **appendices** — F5 7-falsifier 표 · F6 notable-n 표 · Γ₁/X index 표 · raw
  verdict ASCII

## 검증 SSOT

- `CLAIMS.tape` slug=`tecs-l-n6-exclusivity-atlas` group=TECS-L (method=paper)
- verdict: `.verdicts/tecs-l-closed-neg-miner/` (F5) ·
  `.verdicts/tecs-l-beyond-n6/` (F6) ·
  `.verdicts/tecs-l-modform-other-curves/` (F7)
- positive kernel: atlas atom `tecs_l_up_theorem` (M10, σφ=nτ⟺{1,6})
