# HBM (HEXA-HBM) — Foundry-pitch Datasheet  v0.1

> Companion to `hbm/chip-hbm.md` (vision spec). This document is the
> Step-A paper-design enhancement (roadmap §A.6.1) — a foundry-/IDM-
> facing datasheet skeleton: **interface · μarch corners · PDK
> assumptions · safety/quality · ASCII block diagram · BOM/footprint**.
> No proprietary foundry data; all numbers are public spec or
> n=6 closed-form prediction explicitly tagged.
>
> Status: **paper design, pre-tape-out**. v2.0.0 (Stage-1+, .roadmap
> §A.6) gates fabrication.

## 0. Scope and conformance

| field          | value                                                       |
|:---------------|:------------------------------------------------------------|
| product class  | HBM-class memory die-stack (logic-base + DRAM cell tier)    |
| target spec    | JEDEC JESD238 (HBM3) + forward-compat hooks for HBM3E       |
| n=6 anchors    | σ(6)=12 hard ceiling · σ-φ=10 comfortable · 2^(σ-φ)=1024-bit bus |
| falsifier      | F-CHIP-3 (HBM stack height + bus width); 100% RSC closure   |
| scope at v0.1  | spec sheet only; no GDSII / PDK lib / DRC                   |
| out of scope   | DRAM cell process (DDR-class trade secret); proprietary I/O |

## 1. Top-level interface (foundry-agnostic)

```
                +-----------------------------+
                |   HBM stack (1...N-Hi)      |
                |   N ≤ σ-φ = 10 (comfort)    |
                |   N ≤ σ   = 12 (hard JEDEC) |
                +--+--+--+--+--+--+--+--+-----+
                   |  TSV: 1024 wires/stack  |
                   v
                +-----------------------------+
                |   Logic Base Die (LBD)      |
                |   1024-bit DDR @ JEDEC      |
                |   timing; ECC + RAS         |
                +--+-----------------------+--+
                   | uBump array (~600/stack)|
                   v                         v
                +-----------------------------+
                |   Interposer (Si or RDL)    |
                |   2.5D — host SoC adjacent  |
                +-----------------------------+
```

| pin group       | width   | direction | notes                              |
|:----------------|:--------|:----------|:-----------------------------------|
| DQ              | 1024    | bidir     | per-stack data; 8 channels × 128b  |
| DQS             | 32      | bidir     | strobe                             |
| ADDR/CMD        | per-channel as JEDEC | host→stack | 8 indep channels         |
| CK / CKE        | 16      | host→stack| diff clock + enable                |
| RESET_n / TEST  | 4       | host→stack| JTAG + boundary scan               |
| HBM_CATTRIP     | 1       | stack→host| thermal trip                       |
| RFU             | per JEDEC | -       | reserved for HBM3E/4 forward       |

Total uBump count target: 1024 DQ + DQS + ADDR/CMD + power/ground +
RFU ≈ 5400 / stack (HBM3 spec). Power/ground ≈ 50% of uBumps.

## 2. Microarchitecture corners (PVT)

Closed-form-only at v0.1. Real corners come from PDK characterization
post-§A.6 step 2 (foundry MOU + funding).

### 2.1 Process corners (P)

| corner       | nominal node target | deviation     |
|:-------------|:--------------------|:--------------|
| FF (fast)    | DRAM 1z-nm class    | -3σ (process) |
| TT (typical) | DRAM 1z-nm class    | center        |
| SS (slow)    | DRAM 1z-nm class    | +3σ (process) |

LBD process target = N6/N5 logic class (1.0–0.7V). Decoupling between
DRAM cell and LBD logic via stacked-die approach.

### 2.2 Voltage corners (V)

| rail     | nominal | min     | max     | notes                    |
|:---------|:--------|:--------|:--------|:-------------------------|
| VDDQ     | 0.40 V  | 0.36 V  | 0.44 V  | DDR I/O — JEDEC HBM3 tab  |
| VDD      | 1.10 V  | 1.05 V  | 1.20 V  | DRAM core                 |
| VPP      | 1.80 V  | 1.70 V  | 1.90 V  | DRAM peripheral           |
| VDD_LBD  | 0.85 V  | 0.80 V  | 0.95 V  | logic base die            |

### 2.3 Temperature corners (T)

| corner     | T_J range      | use case        |
|:-----------|:---------------|:----------------|
| C (cold)   | -40 …  0 °C    | qual / military |
| N (nominal)|   0 … 85 °C    | commercial      |
| H (hot)    |  85 … 110 °C   | server / HPC    |
| TRIP       |       115 °C   | CATTRIP fires   |

n=6 thermal solver (`verify/numerics_hbm_solver.hexa`) predicts steady-
state Δ across N=σ-φ=10 interior layers in [σ², σ²·n]=[144, 864]
Jacobi iters at convergence; matches 244 measured iters in canonical
test fixture.

## 3. PDK assumptions (foundry-agnostic)

| assumption                    | value                                  |
|:------------------------------|:---------------------------------------|
| DRAM cell process             | 1z-nm class (~12 nm half-pitch)        |
| LBD logic process             | N5/N6 class                            |
| TSV pitch                     | 40–55 µm (HBM2/3 class; HBM4 down to 25 µm) |
| TSV count per stack           | 1024 data + RFU ≈ 1100                 |
| stack-Hi options              | 4 / 8 / 12 (v1.x); 16 = trend (.roadmap §A.4 F-CHIP-3.b) |
| package class                 | 2.5D Si or RDL interposer; CoWoS-class |
| ECC                           | on-die (single-bit correction) + host (DECTED) |

**Foundry-portability**: spec is foundry-agnostic. Mapping to Samsung
1α / SK Hynix 1z / Micron 1β requires PDK contract (§A.6 step 1).

## 4. Safety / quality / reliability

| domain            | requirement                                       |
|:------------------|:--------------------------------------------------|
| BIST coverage     | ≥ 99% cell + 100% TSV + 100% logic-base           |
| burn-in           | 24h @ 110 °C, full ECC scan post-burn             |
| MTTF              | ≥ 10⁷ device-hours @ T_N (commercial)             |
| thermal trip      | CATTRIP @ T_J ≥ 115 °C; latency ≤ 100 µs to host  |
| JEDEC compliance  | JESD238 mandatory; HBM3 RAS profile               |
| soft-error rate   | DRAM cell + ECC → SER ≤ 100 FIT / Mbit            |
| ESD               | HBM model 2 kV all uBumps; CDM 500 V              |
| qual              | AEC-Q100 grade-2 path optional (auto/edge)        |

## 5. Top-level block diagram (textual)

```
+-------------------------------------------------------------------+
|                    HBM stack (12-Hi commercial v1.x)              |
|                                                                   |
|  L0  [DRAM cell 0]  —————————————————————— 1z-nm DRAM             |
|  L1  [DRAM cell 1]                                                |
|  ...  (N-2 cell layers, N ≤ σ=12 hard, N ≤ σ-φ=10 comfortable)    |
|  L_{N-2}  [DRAM cell N-2]                                         |
|  L_{N-1}  [DRAM cell N-1]                                         |
|  ─────────── TSV array (1024 data + ≈100 RFU/aux) ─────────────── |
|  LBD     [Logic Base Die]    ──── N5/N6 logic                     |
|              ├── DQ ↔ uBump array (× 1024)                        |
|              ├── 8-channel controller (per-channel addr/cmd)      |
|              ├── RAS/ECC engine (on-die SBC + host DECTED)        |
|              ├── thermal sensor + CATTRIP gating                  |
|              └── JTAG + boundary-scan (RESET / TEST)              |
+-------------------------------------------------------------------+
       │  uBump array (~5400 total: 1024 DQ + 32 DQS + ...)
       v
+-------------------------------------------------------------------+
|    Si/RDL interposer (2.5D)  ──── shared with host SoC adjacent   |
+-------------------------------------------------------------------+
       │
       v
+-------------------------------------------------------------------+
|    Substrate / package (BGA-class)                                |
+-------------------------------------------------------------------+
```

## 6. BOM / footprint estimate (paper)

| line item                      | v1.x estimate (per stack)               |
|:-------------------------------|:----------------------------------------|
| DRAM cell die (× N-1)          | ~8–10 mm² each, N ∈ {4, 8, 12}          |
| Logic base die                 | ~6–8 mm²                                |
| TSV count                      | ~1100 / stack                           |
| uBumps                         | ~5400 / stack                           |
| 12-Hi stack height             | ~720 µm (after thinning, JEDEC-typ)     |
| 12-Hi stack pwr (peak)         | ~10 W (HBM3 spec; @ 6.4 Gb/s/pin)       |
| typical bandwidth (12-Hi HBM3) | 819 GB/s (= 6.4 × 1024 / 8)             |

Cost ladder (.roadmap §A.6 step 2 funding):
- MPW shuttle (LBD only, single die): ~$0.5–1.5 M (N5/N6 class)
- Full HBM stack tape-out + assembly: ~$10–30 M (foundry MOU required)
- Volume production: vertical-integration scope; out of single-repo scope

## 7. Conformance to RSC closure

| tier         | source                               | status                       |
|:-------------|:-------------------------------------|:-----------------------------|
| T1 algebraic | `verify/calc_hbm.hexa`               | ✓ σ-φ=10 + 1024 = 2^10       |
| T2 numerical | `verify/numerics_hbm{,_parity,_solver}.hexa` | ✓ ×3 stack            |
| T3 archival  | `verify/empirical_hbm.hexa`          | ✓ JEDEC HBM2→HBM3E 12-Hi      |
| T3 bench     | (this document is its prereq)        | ✗ Stage-1+ §A.6              |

Trend pressure (informational, F-CHIP-3.b/.c re-fit queue):

- HBM3E 16-Hi sampling (Samsung 36 GB) — exceeds σ=12 by 1.33×
- HBM4 2048-bit bus (JEDEC working draft) — doubles 2^(σ-φ)=1024
  anchor to 2^11

Both are tracked in `verify/empirical_hbm.hexa` `TRENDS` array as
v2.0.0 re-fit triggers.

## 8. Provenance

- Vision spec: `hbm/chip-hbm.md` (HEXA-HBM alien-index 10 frame)
- Verification floor: `verify/calc_hbm.hexa` + `numerics_hbm_*.hexa`
  + `empirical_hbm.hexa`
- Roadmap: `.roadmap.hexa_chip` §A.4 F-CHIP-3 + §A.6 / §A.6.1
- JEDEC references: JESD235A (HBM2), JESD235B (HBM2E), JESD238 (HBM3);
  HBM3E + HBM4 are vendor PR + working-draft (public) only at v0.1
- n=6 lattice: σ(6)=12, τ(6)=4, φ(6)=2, J₂=24

## 9. Open issues / next-step gates

| gate | needs                                           | resolves    |
|:-----|:------------------------------------------------|:------------|
| G1   | foundry/DRAM partner MOU (§A.6 step 1)          | PDK access  |
| G2   | funding for LBD MPW shuttle (§A.6 step 2)       | tape-out $$ |
| G3   | thermal solver ↔ benchtop measurement parity    | T3-bench    |
| G4   | HBM3E 16-Hi / HBM4 2048-bit closed-form re-fit  | F-CHIP-3.b  |
| G5   | Verilator/SystemC LBD model (§A.6.1 step C)     | sim-firmware|

v0.1 freeze: 2026-05-08. Next revision tag: v0.2 after Step B (sim
parity numerics scripts) lands.
