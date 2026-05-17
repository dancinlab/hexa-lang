# comb T1-A — analytical anchor (sim-free, consumer-side)

> 2026-05-18 · RFC 057 §6 T1 sub-step A · comb-side · sim 불요.
> 표준 NoC 문헌의 기존 결과를 *인용·정리* (새 정리 주장 아님; g3).
> Caveat 필수: **least-perimeter ≠ least-latency** (Hales 2001 = 둘레 한계,
> 지연 한계 아님; RFC 057 §2). 본 표는 *그래프 기하* 만 bound.

---

## 1. 위상 파라미터 (precise)

### degree-4 2D mesh
- N = k², k = √N (k×k rect 영역)
- degree d = 4 (interior); 좌표 (x,y) ∈ {0,…,k−1}²
- 이웃 = {(±1,0),(0,±1)}

### degree-6 hex (triangular lattice) on hex region
- "hex region of radius R": **N(R) = 3R² + 3R + 1 ≈ 3R²** (표준 조합:
  중심 1 + 6 ring 의 R(R+1)/2·... = 1 + 3R(R+1))
- 좌표 axial (q,r), s = −q−r; 이웃 = {(±1,0),(0,±1),(+1,−1),(−1,+1)}
- degree d = 6 (interior)
- 거리: `d_hex(Δq,Δr) = (|Δq| + |Δr| + |Δq+Δr|) / 2`

## 2. 핵심 metric 비교 (asymptotic, N→∞)

| metric | degree-4 mesh | degree-6 hex (hex region) | hex/mesh 비율 | 근거 |
|---|---|---|---|---|
| degree d | 4 | 6 | **1.5×** (router port 비용 ↑) | 정의 |
| diameter D | 2(k−1) ≈ 2√N | 2R ≈ 2√(N/3) ≈ 1.155 √N | **≈ 0.577 = 1/√3** | Leighton 1992 §1.4; R = √(N/3) |
| avg dist d̄ | (2/3)k ≈ 0.667 √N | (2/3)R ≈ 0.385 √N | **≈ 0.577** | Dally & Towles 2004 §3 (E[\|X1−X2\|] = (k²−1)/(3k)) |
| bisection B | k ≈ √N | ≳ √N (region-shape 의존, hex ≳ mesh) | **≳ 1** (Ω(√N) tight) | Leighton 1992 §1.4 (planar bisection 하한) |
| #links E | 2k(k−1) ≈ 2N | ≈ 3N | **1.5×** (wire 수 ↑) | dN/2; d=4 vs d=6 |

산술 확인 (전부 elementary, sympy/Wolfram 인용 없음 — 정직):
- `R = √(N/3)` ← N(R) = 3R² 의 inverse, asymptotic
- `D_hex / D_mesh = (2√(N/3)) / (2√N) = 1/√3 ≈ 0.5774`
- `2 − 2/√3 = 2(√3−1)/√3 ≈ 0.8453` (hop 절감, asymptotic)

## 3. 승리 부등식 (symbolic — F1 operationalize)

```
Net win (degree-6 > degree-4) ⟺
    (D_mesh − D_hex) · Ē_hop  >  Δ_router  +  Δ_wire,diag

   (D_mesh − D_hex) ≈ (2 − 2/√3) √N  ≈  0.845 √N    [hop 절감, 고정]
   Δ_router         ≈ (d_hex − d_mesh)/d_mesh · cost(router_baseline)
                    ≈ +50% × router_baseline       [d 선형 가정]
   Δ_wire,diag      = 대각 link(예: (+1,−1)) 의 RC 페널티 (∝ L²)
                      [placement / process P 의존 — T1-B sim 채움]
```

좌변(이득)은 그래프 상수 **고정**. 우변(비용)은 **node-process / placement
의존**, T1-A 만으로 결판 불가. 부등식 부호 = **T1-B sim 출력** (F1 verdict).

## 4. F2 (Hales 기하 이득의 EDA 잠식) operationalize

- 측정 1건: Stillmaker & Baas, "Hexagonal-Based Many-Core Processor",
  VLSI-SoC 2012 / IEEE 2015 — **65nm CMOS**: −17% power, −21% app area,
  −19% wire distance vs 4-neighbor 2D mesh (+2.9% tile area).
- **F2 반증** if: ≤7nm hex P&R 오버헤드 ≥ 위 이득 (modern node 의 wire-RC
  · clock distribution · DRC 비용이 65nm 보다 hex 불리).
- 분석 단독 결판 불가 — placement·EDA 비용은 그래프 정리에서 안 나옴
  (T1-B 핵심 측정점).

## 5. caveat 체크리스트 (모든 주장에 동반)

- [x] *그래프 기하* 만 bound (latency·energy 는 sim 필요)
- [x] Hales 2001 = 둘레 한계, 지연/에너지 한계 ❌ (RFC 057 §2)
- [x] hex 대각 link 의 물리 RC 페널티는 §3 부등식 우변
- [x] honeycomb(degree-3) vs hexagonal mesh(degree-6) 명칭 혼동 금지
  (Stojmenović *IEEE TPDS* 8(10) 1997 = degree-3, 별개 그래프)
- [x] 상용 degree-6 실리콘 0건 (Cerebras·SambaNova·Tenstorrent·Groq·
  Loihi·NorthPole·SpiNNaker 전부 degree-3/4)

## 6. 출처 (primary)

- Leighton, F.T. *Introduction to Parallel Algorithms and Architectures*,
  Morgan Kaufmann, 1992 — mesh diameter/bisection/planar 하한 표준
- Dally, W.J. & Towles, B. *Principles and Practices of Interconnection
  Networks*, Morgan Kaufmann, 2004 — NoC avg-distance / 토폴로지 표준
- Stojmenović, "Honeycomb Networks: Topological Properties and
  Communication Algorithms", *IEEE TPDS* 8(10), 1997 — 명명 caveat
- Hales, T.C. "The Honeycomb Conjecture", *Discrete & Comput. Geom.* 25,
  1—22 (2001); arXiv:math/9906042 — 둘레 한정 정리
- Conway, J.H. & Sloane, N.J.A. *Sphere Packings, Lattices and Groups*,
  3rd ed., Springer 1999 — 2D kissing # = 6 / Thue / Fejes Tóth
- Stillmaker, A. & Baas, B. *Hexagonal-Based Many-Core Processor*,
  VLSI-SoC 2012 (UC Davis VCL) — 유일한 65nm 측정 datapoint

## 7. 상태 / 다음

- **T1-A = 완료** (sim 불요, 본 cycle). 인용·정리·산술 확인 모두 1차 문헌
  권위에 anchor; 새 이론 주장 0; caveat 5건 모두 동반.
- 다음 = **T1-B**: `~/core/hexa-arch[chip]` NoC sim 흡수 → §3 부등식 부호
  결정 + F1/F2 verdict. blocked-on-hexa-arch (별도 repo 진행).
- comb 단독 다음 액션: T1-A 표를 `comb/COMB.tape` 의 `@N t1a_constants`
  entry 로 archive (산출물 인덱스에 고정).
