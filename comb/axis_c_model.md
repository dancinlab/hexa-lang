# comb/ Axis C — non-von-Neumann execution model (the empirical motivation)

> Status: DESIGN (motivation axis) · 2026-05-18
> Anchor: memory wall (Gholami 2024) + Backus 1978 + Wulf & McKee 1995.
> Honesty: this axis is **radix-neutral — it does NOT select 6.** "6" here
> is an inherited structural constant from B, a tool not a target.
> Evidence: `research/SURVEY.md` §Axis C.

---

## Concept card

```
🧊 HEXA-FABRIC.C — "데이터가 사는 곳에서 계산"

- 하는 일: CPU↔메모리 버스를 없애고, 메모리가 있는 그 타일에서
           바로 연산 (compiler 가 미리 배치한 dataflow)
- 비유: 공장 컨베이어 — 부품을 창고로 왕복시키지 않고 라인 위에서 가공
```

```
   von Neumann                     comb.C (PIM dataflow)
   CPU ──bus──▶ MEM               ⬡→⬡→⬡   토큰이 타일 사이로 흐름
       ◀──bus──                   ↘ ⬡ ↗    메모리=연산 같은 타일
   word-at-a-time 병목            ⬡→⬡→⬡   버스 없음, 동적중재 없음
```

vs von Neumann: 버스 word-at-a-time 제거. vs 양자: 결정론·상온.
comb.C = compiler-placed spatial dataflow + processing-in-memory.

## Why this axis is real (g3 anchor — empirical, not a theorem)

| 한계 | 정량 | 출처 |
|---|---|---|
| von Neumann bottleneck | CPU↔store "word-at-a-time" | Backus, Turing lecture, *CACM* 21(8), 1978 |
| memory wall (원형) | CPU ~60%/yr vs DRAM ~7%/yr | Wulf & McKee, *SIGARCH CAN* 23(1), 1995 |
| **현대 측정** | 20yr: FLOPS **3.0×/2yr** vs DRAM BW **1.6×/2yr** → 60,000× vs ~100× | **Gholami et al., *IEEE Micro* / arXiv:2403.14123, 2024** |
| c / RC wire-delay | latency ≥ dist/c; on-chip RC ∝ L² → 데이터이동이 에너지 지배 | 물리 (C2) |

**정직 caveat:** 이건 *정리*가 아니라 *측정된 추세*. 그리고 PIM 이 아직
von Neumann 을 대체 못한 이유 = 아날로그 drift/ADC 비용 + digital PIM 은
memory-bound 커널만 이득 + **프로그래밍모델/툴체인 벽**. 산업은 메모리월을
HBM/chiplet 로 *von Neumann 안에서* 막는 중. comb.C 의 진짜 장벽은
물리가 아니라 **컴파일러/ISA 생태계** (Monsoon dataflow 가 기술 아닌 툴링으로
죽은 선례).

## Execution model skeleton

```
model      : static dataflow (Dennis 1974) + tagged-token 옵션 (Arvind 1990)
placement  : compiler-owned, no dynamic arbitration (Groq-style 결정론)
tile       : {local SRAM, binary ALU, 6-port hex router}  ← B축 타일 재사용
token flow : hex axial neighbor 로만 (B축 위상이 dataflow 그래프 = HW 그래프)
"6" 의 역할: 6-phase skew clock / 6 token-class lane — 편의 상수일 뿐,
            성능을 6이 선택하지 않음 (radix-neutral). 격자=도구 (g2).
ISA sketch : place·route·fire·sink ; no PC, no central register file
PIM        : 연산이 메모리 타일에 in-situ — 버스 트래픽 = 0 (이웃 hop 만)
```

## Honesty ledger

- 6-phase clock / 6-lane 은 B 위상에서 *떨어지는* 구조 상수. 독립 정당화 없음.
- 이득 주장은 memory-wall 측정(C1) + 워크로드별 PIM 벤치로만. 일반화 금지.
- 툴체인 벽이 최대 리스크 — hexa-lang 컴파일러가 dataflow lowering 을
  낼 수 있느냐가 실현 게이트 (별도 RFC 스코프).

## Verdict

**채택 — comb 의 motivation.** memory wall 은 실재·악화중(C1). 단 radix-중립:
6을 선택하지 않음. comb.C 는 B의 hex 타일을 dataflow 실행면으로 쓰는 층.
실현 게이트 = 컴파일러 dataflow lowering (미래 RFC).
