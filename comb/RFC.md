# RFC 057 — HEXA-FABRIC: a degree-6 hexagonal spatial compute fabric

> Status: **DRAFT** · 2026-05-18 · branch `rfc043-hexa-torch`
> RFC number: **057** — assigned above the active flame/forge chain
> (`inbox/rfc_drafts_2026_05_12/` reaches rfc_056) to guarantee zero
> collision with either the flame/forge chain or the `proposals/`
> absorption chain (which separately reuses 044–048). Canonical copy lives
> in `comb/` as its own SSOT (flame/forge precedent); discoverable via
> `comb/COMB.tape` index — not duplicated into `inbox/` (g3 drift-avoidance).
> Evidence: `research/SURVEY.md`. Axis docs: `axis_{a,b,c}_*.md`.

---

## 0. One-line claim

A non-von-Neumann, non-quantum compute fabric whose **only n=6 commitment is
interconnect topology (degree-6 hexagonal tiling), with binary-digital tiles**,
motivated by the memory wall, anchored by a proven geometry theorem — and
explicitly forbidding multi-valued logic as the differentiator.

```
🧊 HEXA-FABRIC — "벌집 컴퓨터"

- 하는 일: 연산+메모리 이진 타일을 육각 6이웃으로 직결,
           버스 없이 데이터가 옆으로 흐르는 spatial dataflow
- 비유: 벌집 — 방마다 이웃 6칸과 벽 공유, 중앙 복도(버스) 없음
```

```
von Neumann            quantum              HEXA-FABRIC
CPU──bus──MEM          |ψ⟩ 중첩·극저온       ⬡ ⬡ ⬡  이진 타일
0/1·순차 병목          확률·디코히어런스      ⬡ ⬡ ⬡ ⬡ 6이웃·결정론·상온
                                            ⬡ ⬡ ⬡  버스 없음
```

vs 기존: 폰노이만=비트+버스(순차) · 양자=큐비트(확률·극저온) ·
HEXA-FABRIC=이진 다치-아님 + 육각 인메모리 dataflow(결정론·상온).

## 1. Motivation (Axis C — empirical, real)

Memory wall measured: 20 yr FLOPS 3.0×/2yr vs DRAM BW 1.6×/2yr → 60,000×
vs ~100× (Gholami et al., *IEEE Micro* 2024; Backus 1978; Wulf & McKee 1995).
Data movement, not compute, dominates energy (c / RC wire-delay, L²). Answer:
compute where the data is — spatial PIM dataflow, no central bus.
**Caveat:** trend not theorem; PIM's true blocker is the compiler/ISA
ecosystem, not physics (Monsoon died on tooling).

## 2. Why n=6 — exactly one axis (Axis B — theorem)

| Anchor | Theorem | Scope it bounds |
|---|---|---|
| B1 | Honeycomb Conjecture (Hales, *DCG* 25, 2001) | least-perimeter equal-area tiling — wire-per-cell geometry |
| B2 | 2D kissing number = 6 (Conway & Sloane 1999) | max planar direct neighbors = 6 |
| B3 | degree-d planar bisection/diameter bounds (Leighton 1992) | the non-tautological degree-6 vs degree-4 delta |

**This is not number-fit:** Hales 2001 is a proven theorem that *selects the
hexagon*. Mandatory caveat carried everywhere: least-perimeter ≠ least-latency;
the theorems bound geometry, not energy/latency.

## 3. Non-goal (Axis A — de-scoped WALL)

6-valued physical logic is **forbidden as the differentiator**. Three
independent real limits kill it: radix economy (b=6 ≈23% worse than b=3,
Hayes 2001), noise margin ∝1/(M−1) + Shannon ~6 dB/level (Maghami 2019),
worsening process variability. Empirical price: NAND QLC/PLC endurance
collapse + binary-SLC fallback; PAM4 −9.5 dB tax (wire-only); Setun's
ecosystem death. Multi-valued *representation* on binary HW (BitNet-style)
is an optional ISA encoding only. See `axis_a_radix.md` (LIMIT_BREAKTHROUGH
classification: HARD_WALL ×3).

## 4. Architecture (synthesis)

```
tile = { local SRAM (PIM), binary-digital ALU, degree-6 hex router }
addr = hex axial (q,r), s=−q−r ; neighbors {(±1,0),(0,±1),(+1,−1),(−1,+1)}
exec = compiler-placed static dataflow (Dennis 1974), no PC / no central RF,
       optional tagged-token (Arvind 1990), Groq-style no dynamic arbitration
"6"  = topology only. 6-phase clock / 6-lane = inherited convenience constant,
       NOT independently justified (radix-neutral; lattice = tool, g2)
edge = rectangular die ↔ hex tiling via brick-offset rows
```

## 5. Falsifiers (pre-registered, governance g3)

| # | Claim | Falsified if |
|---|---|---|
| F1 | degree-6 beats degree-4 mesh on wire-distance/energy at a modern node | sim at ≤7nm shows ≤0 net gain after router-port area cost |
| F2 | Hales-anchored geometry advantage survives EDA cost | hex P&R overhead ≥ the −17~21% UC-Davis-class gain |
| F3 | PIM dataflow beats von-Neumann+HBM on target workloads | memory-bound kernel still loses to HBM3 chiplet baseline |
| F4 | binary-digital tiles suffice (no MVL needed) | a workload provably needs >2-level logic to be competitive |
| F5 | "6" is topology-only, not perf-selecting | any perf claim traced to radix-6 rather than B1/B2/B3 |

UC Davis VCL 65 nm 2012 (+2.9% tile / −21% area / −17% power / −19% dist) is
the *only* prior measurement — 13 yr stale, small DSP, never productized;
F1/F2 exist precisely because that silence is itself evidence of EDA cost.

## 6. Ultimate goal & gated plan (T1 → T2 → T3)

**Ultimate goal:** prove a degree-6 hexagonal *binary-tile* spatial PIM fabric
beats a degree-4 mesh at a modern node on a real workload — or falsify it with
equal rigor — then deliver the physical-realization *design* (not fab) as a
hexa-native artifact.

| Tier | Deliverable | Gate |
|---|---|---|
| T1 ANSWERED | hex axial NoC cycle-sim, degree-6 vs degree-4, modern-node wire model → resolve F1/F2 (sim only; Leighton B3 bounds). NoC sim obtained **via the `~/core/hexa-arch` chip domain** (separate repo; it absorbs BookSim2 / gem5-Garnet) — comb consumes, does not absorb | user |
| T2 PROVEN | hexa-native cycle-accurate simulator + tapeout-ready RTL; degree-6 > degree-4 on a real workload, OR equal-rigor falsification | user |
| T3 DESIGN-ONLY | comb's physical-realization *design* produced by **using the `~/core/hexa-arch` chip domain** (separate standalone repo — *it* absorbs the external EDA stack: gem5-Garnet/BookSim2 · Yosys · OpenROAD/OpenLane2 · Verilator/SymbiYosys/OpenSTA · ngspice · SKY130/SG13G2 · Chisel/Amaranth). comb is a **consumer, NOT the EDA absorber**. **Actual fab/FPGA is a non-goal.** | user |

C-axis dataflow lowering = separate RFC if pursued. A-axis = no work (frozen
counter-evidence). Each tier a user gate; decisions logged in `comb/PLAN.md`.

## 7. Honesty summary (governance closure)

- n=6 theorem-optimal at B only; A disfavors 6; C is radix-neutral.
- Every B claim carries the least-perimeter≠least-latency + EDA-cost caveats.
- No over-claim: this is a *topology* contribution with one stale measurement
  and five live falsifiers, not a paradigm claim. Lattice = tool (g1/g2).
- T3 scope guard: comb *consumes* the **`~/core/hexa-arch` chip domain**
  (separate repo) for design realization — comb never absorbs EDA nor
  fabricates a chip. Keeps comb focused on n=6 topology; stays hexa-native (g5).
- hexa-arch decoupling: all EDA absorption (gem5-Garnet/Yosys/OpenROAD/…)
  lives in `~/core/hexa-arch`, not comb. comb = consumer only. No over-claim.
