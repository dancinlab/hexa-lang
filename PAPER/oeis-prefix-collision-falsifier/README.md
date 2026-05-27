# oeis-prefix-collision-falsifier — 논문 (OEIS 도메인 O8)

OEIS 도메인 마일스톤 **O8**의 arxiv 스타일 논문. 닫힌-부정(closed-negative)
발견을 다룬다: **K=10 정수-튜플 prefix 일치는 sequence identity 의 신뢰할 수
있는 판정이 아니다.**

## 발견 한 줄 요약

사전등록(pre-registered) 가설 `H` = "K=10 prefix 일치 ⟹ sequence identity" 를
374,047개 OEIS sequence × 20개 저-엔트로피 산술 후보함수 sweep 으로 측정 →
**🔴 FALSIFIED**. 1,707개 K=10 hit 중 **1,334개(78.1%)** 가 K=20 에서 갈라지는
first-K 우연일치(coincidence). 배제된 축 = short-prefix(K=10) 튜플매치를 단독
identity 증거로 쓰는 것.

## 필수 caveat (paper_violation 회피)

78.1% 는 **candidate-set-relative** 수치다 — 20개 저-엔트로피 산술함수 +
단일 K=10→K=20 prefix-pair 기준. OEIS prefix 충돌에 대한 보편 주장이 **아니다**.
§5 caveat 에 전문 기술.

## 데이터 출처 (verbatim · 재측정 안 함)

- `.verdicts/oeis-full-sweep/ledger.json` — funnel 카운트 (1707 hit / 1334
  coincidence / 336 survivor / 37 na)
- `.verdicts/oeis-full-sweep/hits.tsv` — 전체 match 표 (per-fn breakdown 출처)
- `.verdicts/oeis-full-sweep/sweep_log.txt` — 실행 raw stdout
- `.verdicts/oeis-perhit-verify/tier_ledger.txt` — survivor 의 per-hit verify
  (🔵8 / 🟡41 / 🟠287)

## 빌드

```
make            # main.pdf 생성 (pdflatex ×3 + bibtex)
make clean      # 중간파일 제거 (PDF 유지)
```

`figures/fig01_funnel.png` 은 `/imagine` 스킬(fal.ai gpt-image-2)로 생성해
커밋했다 (selectivity funnel + prefix-collision 개념도). 별도 figure 빌드 단계
없음 (commons @D g51: ≥10페이지 + ≥1 fal.ai figure).

## 구조 (paper_format)

- §abstract · §1 statement(사전등록 falsifier H) · §2 method(374K sweep · 20-fn
  후보셋 · K=10 hash-intersect + K=20 2차패스) · §3 verification(실측 funnel +
  A000926↔n exemplar) · §4 finding(78.1% closed-negative · H FALSIFIED · 배제
  축) · §5 caveats · §6 related · 부록(funnel 표 · per-fn breakdown · sample
  collision list · 7 genuine survivor)
