# tecs-l-modform-n6-nonlift — MODFORM 축의 두 closed-negative

> TECS-L 도메인 MODFORM 축(A: MF1-MF7)을 두 개의 사전등록 falsifier 둘레로
> 집약한 arxiv-스타일 논문. 검증된 Γ₀(N) 배경(index ψ · cusp · genus · weight ·
> Atkin-Lehner) 위에 두 **closed-negative** 발견을 올린다.

## 두 발견 (둘 다 사전등록 + 측정 + closed-negative — paper_significance 충족)

1. **MF4 (dim ≠ genus)** — hexa `dim_cusp_forms(N,2)` 가 고전 정리
   dim S₂(Γ₀(N)) = genus(X₀(N)) 를 실현하지 **않는다**. N∈[1,30] sweep 에서
   20/30 mismatch (N=11 hexa=0/고전=1, N=30 hexa=6/고전=3). 사전등록 falsifier
   기각 🔴 — 단, **수학 거짓이 아니라 hexa 함수의 정의 갭** (업스트림 PR #1083 보고).
   verdict: `.verdicts/tecs-l-modform-dim-genus/`.
2. **F7 (n=6 non-lift)** — σφ=nτ ⟺ {1,6} 는 Γ₀ 레벨의 산술-항등식 현상으로,
   modular-curve 탑으로 **lift 안 됨**. Γ₁(N)/X(N) index 는 N 에 대해 smooth
   (multiplicative) — n=6 peak 없음. 사전등록 falsifier 기각 🔴.
   verdict: `.verdicts/tecs-l-modform-other-curves/`.

## 구성

- `main.tex` — 단일 컬럼 arxiv-스타일 LaTeX (article, 11pt A4), ≥10 페이지.
  §abstract · §1 statement (두 falsifier) · §2 method · §3 verification (실제
  hexa-verify 결과 — 20/30 mismatch, Γ₁ smoothness) · §4 finding (두 closed-negative)
  · §5 caveats · §6 related · 부록 A/B/C (30-N dim/genus 표 · Γ₁/X index 표 ·
  raw verdict transcript ASCII-sanitized).
- `references.bib` — BibTeX (Diamond-Shurman · Shimura · Atkin-Lehner +
  TECS-L 체인). 전부 DOI/URL.
- `figures/fig01_lift.png` — fal.ai (gpt-image-2) 생성. modular-curve 탑의
  n=6 non-lift + dim-vs-genus 발산 도식. 프롬프트 출처
  `figures/_prompts/fig01_lift.txt`.
- `Makefile` — `make` = pdflatex × 3 + bibtex.

## 빌드

```bash
make            # → main.pdf
make clean      # .aux/.log/.bbl 제거 (PDF 보존)
make distclean  # PDF 도 제거
```

## 정직성 입장 (paper governance)

- 모든 수치는 `hexa verify --expr` closed-form 재계산 → `.verdicts/tecs-l-modform-*/`
  에 verbatim 영속 → `CLAIMS.tape` (group TECS-L) 에 1:1 verdict 포인터로 색인.
- 두 발견은 **closed-negative** — paper_negative_ok 거버넌스상 publishable.
  Finding 1 은 수학 거짓이 아니라 hexa 함수 정의 갭(PR #1083); Finding 2 의 n=6
  특수성은 Γ₀ 레벨에서 실재하나 탑으로 lift 안 됨. 둘 다 §5 caveats 에 명시.
- 사전등록 falsifier 는 method 절(§2)에 측정 전에 고정.
