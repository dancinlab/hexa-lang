# comb/ research survey — prior art + honest counter-evidence

> 2026-05-18 · arxiv deep research + web deep research (2 parallel agents).
> Governance: real-limits-first, no over-claim, lattice-is-tool-not-target.
> This file is the evidence base for `../RFC.md` and the 3 axis docs.

---

## TL;DR (the one paragraph that drives every design decision)

**n=6 has a hard proven theorem behind it at exactly ONE axis: interconnect
topology (Axis B).** Hales' Honeycomb Conjecture (2001) + 2D kissing
number = 6 + Thue/Fejes Tóth densest-packing select the hexagon — but they
bound *geometry* (perimeter / contact count), NOT latency or energy.
Axis A (6-valued logic) is *provably suboptimal* on radix economy and is the
field's best-documented hype trap. Axis C (non-von-Neumann) is empirically
strong (memory wall) but radix-neutral — it does not select 6.
**Defensible architecture = "degree-6 hexagonal spatial fabric, binary-digital
tiles."** Multi-valued logic is de-scoped to a documented WALL, not a feature.

---

## Axis A — multi-valued / non-binary logic (radix)

| Item | Finding | Source |
|---|---|---|
| Radix economy | `E=b·ln N/ln b` minimized at b=e≈2.718; integer optimum **b=3** (3/ln3≈2.73 < 2/ln2≈2.89). **b=6≈3.35 — ~23% worse than 3** | Hayes, "Third Base", *American Scientist* 89(6), 2001 |
| Noise margin | margin ∝ `V/(M−1)`; ~6 dB SNR per added bit/level (Shannon–Hartley `C=B·log₂(1+S/N)`) | Maghami et al., *Circuits Syst. Signal Process.* 38, 2019 ("…Deceptive Matter") |
| NAND multi-level | SLC→QLC(16 lvl): endurance 100k→~100–1k P/E; QLC charge window ~6%, PLC ~3%; QLC read ~2–4 ms; **binary SLC-cache fallback is the universal mitigation** | YMTC/IBM/Tom's Hardware 2024 |
| PAM4 wire | 4-level signaling shipping (400/800G Eth, PCIe 6.0) but only on the WIRE; eye 1/3 height → **−9.5 dB SNR tax** | Samtec/Keysight/Synopsys 2023–24 |
| Setun | only non-binary machine to reach production (ternary, 1958, ~50 units); killed by **ecosystem/industrial policy, not physics** | Wikipedia/GMU history |
| Modern ternary | no commercial ternary *logic*; BitNet b1.58 (MS, 2025) runs ternary *math on binary HW* | arXiv / MS 2025 |
| Verdict | **A is the hype trap.** Multi-level works only where a channel/storage constraint forces it, always pays a geometric reliability/power price, binary fallback universal. Classify SOFT_WALL→HARD_WALL. | both agents converge |

## Axis B — interconnect topology / packing optimality (the theorem-anchored axis)

| Item | Finding | Source |
|---|---|---|
| 2D kissing number = 6 | unit circle touches ≤6 others in plane; hex achieves it | Conway & Sloane, *SPLAG* 3rd ed. 1999 |
| Densest packing | hex lattice densest equal-circle packing, density π/2√3≈0.9069 | Thue 1890 / Fejes Tóth 1953 |
| **Honeycomb Conjecture** | **regular hexagon = least-perimeter equal-area planar tiling** (proven) | **Hales, *Discrete Comput. Geom.* 25:1–22, 2001 (arXiv:math/9906042)** |
| Nomenclature trap | "honeycomb network" in NoC lit = **degree-3** (tiling vertices); "hexagonal mesh" = **degree-6** (tiling faces). Different graphs — cite carefully | Stojmenović, *IEEE TPDS* 8(10), 1997 |
| degree-6 silicon | UC Davis VCL 65 nm (2012): **+2.9% tile area, −21% app area, −17% power, −19% wire distance** vs 4-neighbor mesh | Stillmaker/Baas, VLSI-SoC 2012 |
| Commercial degree-6 | **ZERO.** Cerebras/SambaNova/Tenstorrent/Groq/Loihi/NorthPole/SpiNNaker all degree-3/4 mesh/torus | web agent, 7 systems checked |
| Systolic precedent | hex-connected systolic arrays for band-matrix multiply | Kung & Leiserson 1978/79 |
| Honesty caveat | least-perimeter ≠ least-latency; degree-6 router costs more ports/area; UC Davis result 13 yr stale, never productized → EDA-cost caveat mandatory | both agents |

## Axis C — non-von-Neumann execution / processing-in-memory

| Item | Finding | Source |
|---|---|---|
| von Neumann bottleneck | "word-at-a-time" CPU↔store path | Backus, Turing lecture, *CACM* 21(8), 1978 |
| Memory wall | CPU ~60%/yr vs DRAM ~7%/yr | Wulf & McKee, *SIGARCH CAN* 23(1), 1995 |
| Modern refresh | 20 yr: FLOPS **3.0×/2yr** vs DRAM BW **1.6×/2yr** → 60,000× vs ~100× | Gholami et al., *IEEE Micro* / arXiv:2403.14123, 2024 |
| PIM systems | ISAAC, PRIME (ISCA 2016); UPMEM (commercial DDR4 PIM) | Shafiee/Chi 2016; Gómez-Luna 2022 |
| Why not displaced | analog drift/ADC cost; digital PIM wins only memory-bound kernels; **programming-model/toolchain wall**; memory wall attacked instead by HBM/chiplets within vN | both agents |
| Verdict | empirically strong motivation, but **radix-neutral — does not select 6** | both agents |

---

## Strongest real limits to anchor each axis (governance g3)

- **B1 — Honeycomb Conjecture (proven theorem).** Hales 2001. Strongest legit "6" anchor; bounds perimeter/wire-per-cell geometry, NOT latency/energy — state scope explicitly.
- **B2 — 2D kissing number = 6 + Thue/Fejes Tóth (proven).** "6 neighbors = planar contact maximum."
- **B3 — degree-d planar network bisection/diameter bounds.** Leighton 1992 — the real (non-tautological) limit on what degree-6 buys over degree-4.
- **C1 — memory wall scaling law (measured).** Gholami 2024. Strongest empirical non-vN justification. Radix-neutral.
- **C2 — c / RC wire-delay (physics).** latency ≥ dist/c; on-chip RC ∝ L². Deepest "compute where the data is" anchor.
- **A2 — Shannon–Hartley + noise margin (info theory/physics).** Hard wall on level count at fixed swing. Anchors A as a WALL, not a feature.
- **A1 — radix economy (math).** b=6 provably suboptimal. Forbids anchoring "6" on radix economy.

## Net read

Real opening = **degree-6 hexagonal interconnect, binary-digital tiles**, motivated
by the memory wall (C), backbone-anchored by Hales 2001 (B), with multi-valued
logic (A) explicitly forbidden as the differentiator and filed as cautionary
counter-evidence in LIMIT_BREAKTHROUGH terms. Validate B at a modern node;
carry the EDA-cost caveat in every claim.

## Sources (primary)

Hayes *Am. Sci.* 2001 · Maghami et al. *CSSP* 38 2019 · Hales *DCG* 25 2001
(arXiv:math/9906042) · Conway & Sloane *SPLAG* 1999 · Fejes Tóth 1953 ·
Stojmenović *IEEE TPDS* 8(10) 1997 · Stillmaker/Baas VLSI-SoC 2012 · Kung &
Leiserson 1978 · Backus *CACM* 21(8) 1978 · Wulf & McKee *SIGARCH CAN* 23(1)
1995 · Gholami et al. arXiv:2403.14123 2024 · Shafiee (ISAAC)/Chi (PRIME) ISCA
2016 · web agent industry scan (Cerebras WSE-3, SambaNova SN40L, Tenstorrent
Tensix, Groq LPU, Loihi 2, NorthPole, SpiNNaker; NAND QLC/PLC; PAM4; Mythic/IBM
analog). Full URL list in agent transcripts.
