# comb/ Axis A — 6-valued logic (DE-SCOPED: documented WALL, not a feature)

> Status: AUDITED → WALL · 2026-05-18
> Verdict: **NOT the architecture's differentiator.** Filed as cautionary
> counter-evidence per LIMIT_BREAKTHROUGH discipline. Evidence:
> `research/SURVEY.md` §Axis A.

---

## Why this doc concludes against itself (governance honesty)

The user asked all 4 axes be developed. Developing Axis A *honestly* means
documenting why 6-valued logic is the field's best-evidenced trap — that IS
the deliverable. Real-limits-first forbids carrying it as a feature when both
deep-research agents independently converged on its refutation.

```
🧊 HEXA-FABRIC.A — "6-값 논리" (반증됨)

- 했을 일: 비트(0/1) 대신 6-값 헥싯을 논리 상태로
- 비유: 신호등을 2색→6색으로 — 색 구분은 빡세지고 오인은 폭증
```

```
binary             6-value
  ▁▔   margin 큼     ▁▂▃▅▆▔   margin ∝ 1/(M−1) → 1/5
  0  1              0 1 2 3 4 5   레벨↑ → 잡음창 붕괴 + SNR ~6dB/레벨
```

## The three independent kill-shots (each a real limit, g3)

| # | 한계 | 정량 | 출처 |
|---|---|---|---|
| A1 | radix economy | b=6 → 6/ln6≈**3.35**, 정수 최적 b=3(≈2.73)보다 ~23% 손해. **"6"을 radix 로 정당화 불가** | Hayes, *Am. Sci.* 2001 |
| A2 | noise margin + Shannon | margin ∝ `V/(M−1)` (6값→1/5); 레벨당 ~6 dB SNR; MVL 노이즈마진 논문 다수 "deceptive" | Maghami et al., *CSSP* 38, 2019 |
| A3 | 공정 편차 | deep-submicron Vt tolerance 악화 — 다치는 *더 빡빡한* 매칭 요구, 공정은 *더 느슨* 제공 (역방향) | web agent / 산업 |

## Empirical price (real silicon already pays it)

- **NAND**: SLC→QLC(16레벨) 내구 100k→~100–1k P/E, QLC 전압창 ~6%·PLC ~3%,
  QLC read ~2–4 ms. 보정책 = **이진 SLC-cache 로 fallback** (= 다치를 숨김).
- **PAM4**: 4-레벨이 이미 상용이나 *배선에만*; eye 1/3 → **−9.5 dB SNR 세금**.
  논리 캐스케이드(수천 단)에선 치명적, 짧은 SerDes 링크에서만 감수.
- **Setun (1958)**: 유일한 양산 비이진. 죽인 건 물리 아니라 **생태계/정책** —
  비이진의 가장 중요한 경고 데이터포인트.

## Classification (LIMIT_BREAKTHROUGH terms)

| 측면 | 분류 | 근거 |
|---|---|---|
| radix economy | **HARD_WALL** | 수학적으로 b=6 열위 (A1) |
| noise margin / SNR | **HARD_WALL** | 정보이론 한계, 고정 swing (A2) |
| 공정 편차 | **SOFT_WALL → 악화중** | 노드 미세화로 더 나빠짐 (A3) |
| EDA / 생태계 | **HARD_WALL** | 다치 P&R/합성/검증 툴 부재; Setun 선례 |

## What survives (narrow, honest)

- 다치 *표현*은 가치 있음 — 단 **이진 HW 위에서** (BitNet b1.58 ternary
  weights, MS 2025). → comb 의 ISA/데이터 인코딩 *옵션*으로는 가능,
  **물리 논리 상태로는 금지**.
- comb 타일 ALU = **이진-디지털 고정**. A축은 backbone(B)·motivation(C)에
  영향 주지 않음.

## Verdict

**DE-SCOPE.** 6-값 물리 논리는 comb 의 차별점이 아니며 금지. 본 문서는
경고용 audit 으로 보존. AGENTS.tape governance(no over-claim)와 정합.
