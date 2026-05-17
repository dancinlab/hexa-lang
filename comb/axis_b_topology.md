# comb/ Axis B — hexagonal spatial fabric (the theorem-anchored backbone)

> Status: DESIGN (backbone axis) · 2026-05-18
> Anchor: Hales Honeycomb Conjecture (2001) + 2D kissing number = 6.
> Evidence: `research/SURVEY.md` §Axis B.

---

## Concept card

```
🧊 HEXA-FABRIC.B — "벌집 배선"

- 하는 일: 연산+메모리 타일을 육각으로 깔고, 각 타일이 6개 이웃과
           직결 — 중앙 버스 없이 옆으로 데이터가 흐름
- 비유: 벌집 — 방 하나가 이웃 6칸과 벽을 공유 (틈/낭비 최소)
```

```
   4-neighbor mesh (현행 전부)        degree-6 hex (comb)
   ┌──┬──┬──┐                          ⬡ ⬡ ⬡
   ├──┼──┼──┤   각 타일 4이웃          ⬡ ⬡ ⬡ ⬡   각 타일 6이웃
   ├──┼──┼──┤   diameter 큼            ⬡ ⬡ ⬡     wire dist ↓
   └──┴──┴──┘                          ⬡ ⬡ ⬡ ⬡
   Cerebras·SambaNova·Groq·            상용 0건 / UCDavis 65nm
   Tenstorrent·Loihi·NorthPole         1건만 측정 존재
```

vs 현행: 모든 상용 spatial accelerator는 degree-3/4 직사각 mesh/torus.
comb.B = degree-6 hex tiling. **타일 로직은 이진-디지털 유지** (A축 다치논리
아님 — SURVEY 반증 근거).

---

## Why 6 here is a theorem, not a number-fit (governance g1/g2)

| 정리 | 진술 | 무엇을 bound 하나 |
|---|---|---|
| Honeycomb Conjecture (Hales 2001) | 등면적 평면 분할 중 정육각형이 둘레 최소 | 타일당 경계길이(=배선 둘레) 기하 |
| 2D kissing number = 6 | 평면 단위원은 최대 6개와 접촉 | 한 타일의 물리적 직결 이웃 상한 |
| Thue / Fejes Tóth | 육각격자가 등원 최밀 패킹 (밀도 π/2√3≈0.907) | 타일 면적 효율 |

**정직 caveat (필수):** 위 정리들은 *기하*(둘레·접촉수·밀도)를 bound 할
뿐, latency·energy 를 bound 하지 **않는다**. degree-6 라우터는 포트가 많아
타일당 면적이 늘고, 배선 지연은 둘레가 아니라 길이·crosstalk 로 정해진다.
"정육각형이 최소둘레" → "최소지연" 은 비약. 이 캐비엇을 모든 주장에 동반.

## Real-limit anchor (g3)

- **B1** Hales 2001 — least-perimeter equal-area tiling (기하 상한).
- **B2** 2D kissing number = 6 — degree-6 = 평면 직결 이웃의 물리적 최대.
- **B3** Leighton 1992 — degree-d 평면 그래프의 bisection/diameter 하한.
  degree-6 vs degree-4 이득의 *비-tautology* 한계는 여기서 계산.
- **측정 1건** UC Davis VCL 65 nm 2012: hex tile = +2.9% tile area /
  −21% app area / −17% power / −19% wire distance vs 4-neighbor mesh.
  → 13년 stale·소규모 DSP·미재현. **modern-node 재검증 전까지 인용 시
  반드시 EDA-cost + staleness caveat 동반.**

## Skeleton design

```
tile (셀):
  ├── 6 ports  : NE NW E W SE SW  (hex axial 좌표 (q,r))
  ├── local mem: SRAM block (PIM — C축과 연결)
  ├── ALU      : binary-digital (NOT multi-valued)
  └── router   : dimension-order on hex axial; deflection 옵션

addressing : axial (q, r), s = −q−r ; 6-neighbor = {(±1,0),(0,±1),(+1,−1),(−1,+1)}
flow model : C축 dataflow 가 owner (compiler-placed, no dynamic arbitration 옵션)
edge       : 직사각 die ↔ hex tiling 경계 손실 → brick-offset 행 배치로 흡수
```

## Open questions → C/A 연계

1. degree-6 이득이 B3 하한 대비 실제 얼마인가 (modern node 시뮬 필요).
2. 직사각 reticle/EDA 와 hex P&R 충돌 비용 — UC Davis 침묵의 이유.
3. 타일 실행 모델 = C축; 타일 로직 radix = 이진 고정 (A는 WALL).

## Verdict

**채택 — comb 의 backbone.** 단, "정리-최적"은 기하에 한정하고
성능 주장은 B3 + modern-node 측정으로만. number-fit 아님 (Hales 2001 정리).
