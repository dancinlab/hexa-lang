# M6 — 2,711 가설 코퍼스 g5 triage

> archive-TECS-L 의 가설 코퍼스(`docs/hypotheses/` 2,735 파일 + `math/docs/hypotheses/`
> 339)를 g5 tier 로 분류. **수론 A-tier 코어만 🔵 검증 가능**하고, 절대다수는
> 의식·ML·물리·생물·철학 사변으로 hexa 닫힌형 경로가 없어 🟡/🟠/⚪ 로 정직 분류.
> M4 (`n6-characterizations`) 와 동일 방법론 — 단일 atom 값만 🔵, 전칭/근사/외부의존 제외.

## tier 분포 (카테고리 기준 · 정직)

코퍼스는 단일 머신리더블 레지스트리가 아니라 도메인별 산재 마크다운이다. 개별
2,711건을 1행씩 분류하는 건 비현실적 — **카테고리 단위**로 g5 tier 를 매긴다:

| 카테고리 | 대략 규모 | tier | 사유 |
|----------|-----------|------|------|
| 수론 A-tier (완전수·약수함수·SM count) | ~18 (README) | 🔵 | σ/τ/φ/is_perfect 닫힌형 재계산 가능 (본 M6 + M1/M4/M5) |
| 모듈러폼·격자·위상 (Γ₀·키싱·j-invariant) | 수십 | 🔵/🟡 | 일부 calc fn 지원(M4) · 나머지는 인용 |
| 물리상수 매칭 (질량·α·우주상수) | 수백 | 🟡 | 실측값 인용 필요 — never auto-🔵 (M5 참조) |
| 의식·IIT·Φ·EEG·telepathy | 수백 | 🟠/⚪ | 외부 데이터 의존 / 메타포 — hexa scope 외 (도메인 비범위) |
| ML·MoE·golden-zone·training | 수백 | 🟠 | 학습 실험 의존 (외부 compute) |
| 생물·유전코드·진화 | 수백 | 🟡 | "Leu/Ser/Arg=6 codons" 류 — 6=n 인용 |
| 철학·brain-colony 동형 | 수백 | ⚪ | 사변/메타포 — verify N/A (g4 honest fence) |

> **정직 헤드라인**: 2,711 중 hexa 닫힌형 🔵 가능한 건 **수론 A-tier 코어(~18)뿐**.
> 본 M6 은 그 코어의 토대 정리(완전수 정의 항등식)를 7 atom 으로 검증·영속화한다.
> 나머지는 M1 σφ=nτ 유일성과 같은 🟡 (전칭·근사·외부) 처리 — over-claim 금지.

## 검증한 🔵 코어 (7 atom)

**H18 (known theorem): σ(n) = 2n ⟺ n 은 완전수.** 첫 5개 완전수에서 정의
항등식(abundancy index σ/n = 2)을 닫힌형 재계산:

```
   n              σ(n)          2n            σ(n)=2n?
   ───────        ─────────     ─────────     ────────
   6              12            12            ✓
   28             56            56            ✓
   496            992           992           ✓
   8128           16256         16256         ✓
   33550336       67100672      67100672      ✓   (σ=2^13·M13 항등)
```

- 5/5 🔵 SUPPORTED-FORMAL (`hexa verify --expr sigma n 2n`). Review 090/098/123 가
  반복 인용하는 "왜 6인가 = 완전수" 의 수학적 토대.
- μ(6)=1 (6=2·3 squarefree, ω 짝수) · aliquot(6)=6 (진약수합 s(n)=n = 완전수 정의)
  — 두 atom 추가 🔵.

## 정직성 메모

- 본 triage 는 **카테고리 단위** 분류 — "2,711건 전수 개별 검증" 을 주장하지 않음.
- 의식/EEG/telepathy 줄기는 TECS-L 도메인 **비범위**(`TECS-L.md §3`) — hexa-lang scope 외.
- 7 verdict 원문 → `.verdicts/tecs-l-hypotheses/` (raw stdout verbatim, 1:1).
