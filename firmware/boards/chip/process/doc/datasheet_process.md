# Process Node σ-cascade (HEXA-PROCESS) — Foundry Datasheet  v0.1

> Companion to `process/chip-process.md` (vision spec). Step-A
> paper-design enhancement (.roadmap §A.6.1) — foundry-/IDM-facing
> datasheet skeleton: **node ladder · process corners · PDK
> assumptions · safety/quality · ASCII flow · BOM cost-class**.
>
> Status: **paper specification, no fab affiliation**. v2.0.0
> (Stage-1+, .roadmap §A.6) gates any actual wafer run.

## 0. Scope and conformance

| field          | value                                                       |
|:---------------|:------------------------------------------------------------|
| product class  | foundry process-node organising taxonomy + density predictor |
| target spec    | foundry-portable; IRDS roadmap-aligned; ITRS legacy-compatible|
| n=6 anchors    | σ(6)=12 commercial-node generations · τ(6)=4 design stages   |
| falsifier      | F-CHIP-1 (process node σ scaling); 100% RSC closure          |
| scope at v0.1  | spec + density ladder; no PDK lib / SPICE deck / DRC         |
| out of scope   | foundry-proprietary device models; PDK schematics            |

## 1. n=6 commercial-node ladder (σ = 12)

The σ(6)=12 commercial process generations spanning ~25 years
(180 nm → 2 nm class). Density doubling per generation (Moore's law)
within Δlog₂ ∈ [0.5, 1.5] per `verify/empirical_process.hexa`.

| gen idx | node label  | TSMC class | Samsung class | Intel class | density (MTr/mm²) range |
|:-------:|:------------|:-----------|:--------------|:------------|:------------------------|
|   0     | 180 nm      | CL018      | LG-180        | P858        | ~0.04                   |
|   1     | 130 nm      | CL013      | -             | P860        | ~0.1                    |
|   2     |  90 nm      | N90        | 90LP          | P1262       | ~0.4–1.0                |
|   3     |  65 nm      | N65        | 65LP          | P1264       | ~2–3                    |
|   4     |  45 nm      | N45/40     | 45LP          | P1266       | ~3–6                    |
|   5     |  32 nm      | N32/28     | 32LP          | P1268       | ~5–10                   |
|   6     |  22 nm      | N22        | 22LP          | P1270 (22FF)| ~10–15                  |
|   7     |  16 nm FF+  | N16        | 14LPP         | 14nm        | ~25–40                  |
|   8     |  10 nm      | N10        | 10LPP         | Intel-7     | ~50–100                 |
|   9     |   7 nm      | N7         | 7LPP          | Intel-4     | ~90–160                 |
|  10     |   5 nm      | N5         | 5LPE          | -           | ~125–175                |
|  11     |   3 nm      | N3         | 3GAE          | -           | ~290                    |

Cardinality: max(gen_idx) + 1 = 12 = σ(6). 2 nm class (Intel 18A, TSMC
N2) sits at gen_idx=11 boundary; pushing to gen_idx=12 would add a
generation, which would empirically falsify σ=12 cardinality (tracked
in `verify/empirical_process.hexa` `check_sigma_cardinality_anchor`).

## 2. τ(6) = 4 design stages

```
   stage 0          stage 1           stage 2           stage 3
   RTL              SYNTH             P&R               SIGN-OFF
   ────────         ─────────         ──────────        ────────────
   - HDL design    - logic synth     - placement       - DRC / LVS
   - simulation    - tech mapping    - routing         - timing closure
                   - constraint     - clock tree      - PV (process)
                   - DFT insertion  - parasitics      - power closure
```

Each stage is a τ-projection of design closure. `verify/calc_process.hexa`
enumerates these and asserts count = τ(6).

## 3. Process corners (PVT + reliability)

### 3.1 Per-node corner set (typical N5/N3-class)

| corner       | deviation       | use case                |
|:-------------|:----------------|:-------------------------|
| FF (fast)    | -3σ process     | speed-bin / hi-perf      |
| FS (mixed)   | NFET fast / PFET slow | mismatch test     |
| TT (typical) | center          | nominal yield model      |
| SF (mixed)   | NFET slow / PFET fast | mismatch test     |
| SS (slow)    | +3σ process     | leakage / low-power      |

### 3.2 Voltage corners (V)

| rail        | nominal (N5) | min (N5) | max (N5)  | scaling per node |
|:------------|:-------------|:---------|:----------|:-----------------|
| VDD_LOGIC   | 0.75 V       | 0.65 V   | 0.85 V    | -10% per gen     |
| VDDQ_IO     | 0.80 V       | 0.75 V   | 0.85 V    | flat for legacy  |
| VPP_PERIPH  | 1.80 V       | 1.70 V   | 1.90 V    | flat             |

### 3.3 Temperature corners (T)

| corner      | T_J range       | use case          |
|:------------|:----------------|:-------------------|
| C (cold)    | -40 …  0 °C     | qual / military    |
| N (nominal) |   0 … 85 °C     | commercial         |
| H (hot)     |  85 … 110 °C    | server / HPC       |
| TRIP        |       125 °C    | thermal trip       |

### 3.4 Reliability corners

| metric                  | requirement                                |
|:------------------------|:-------------------------------------------|
| HCI                     | ≤ 10% Vt shift @ 10 yr / use case          |
| BTI (NBTI/PBTI)         | ≤ 5% Vt shift @ T_H / 10 yr                |
| TDDB                    | MTTF ≥ 10⁷ hr @ T_N / V_max                |
| EM (electromigration)   | J × A / J_max = ≤ 1.0 (Black's eq compliant)|

## 4. PDK assumptions (foundry-agnostic)

| assumption                    | value                                           |
|:------------------------------|:------------------------------------------------|
| transistor type               | FinFET (N7→N4) → GAA / nanosheet (N3 → N2)       |
| metal stack                   | ≥ 14 metal layers (N5+); BEOL ULK                |
| std cell library              | 9-track / 7.5-track (N5+); 6-track (N3 GAA)      |
| SRAM cell                     | 6T high-density + 8T high-perf                   |
| analog support                | ≥ 1 thick-oxide IO option per node               |
| EDA flow                      | Cadence Innovus / Synopsys ICC2 / Siemens Solido  |

**Foundry-portability**: spec is foundry-agnostic. Mapping requires
an actual PDK contract (§A.6 step 1). Density numbers in §1 are
public spec or n=6 closed-form prediction; not foundry-confidential.

## 5. Safety / quality / reliability framework

| domain            | requirement                                         |
|:------------------|:----------------------------------------------------|
| BIST coverage     | ≥ 99% logic, 100% SRAM (ECC SECDED), 100% scan-chain |
| burn-in           | 12–24h @ T_H + V_max                                 |
| MTTF              | ≥ 10⁷ device-hours @ T_N (commercial)                |
| qual              | JEDEC JESD22 baseline; AEC-Q100 grade-2/3 optional   |
| FuSa (auto)       | ASIL-B path requires LBIST + ECC + MISR + diag soft  |
| security          | PUF + secure boot + tamper detection (foundry IP)    |
| ESD               | HBM model 2 kV all I/O; CDM 500 V                    |
| latch-up          | -100/+100 mA per JEDEC                                |

## 6. Top-level process flow (textual)

```
+-------------------------------------------------------------------+
|                Wafer (300 mm Si starting material)                |
|                                                                   |
|  ┌─────────────────────────────────────────────────────────────┐  |
|  │ Front-End-of-Line (FEOL)                                    │  |
|  │ ├── well + isolation (STI)                                  │  |
|  │ ├── transistor formation (FinFET / GAA — node-dependent)    │  |
|  │ │    - gate stack (HKMG)                                    │  |
|  │ │    - source/drain epi                                     │  |
|  │ │    - work-function metal                                  │  |
|  │ └── contact + barrier                                       │  |
|  └─────────────────────────────────────────────────────────────┘  |
|                                                                   |
|  ┌─────────────────────────────────────────────────────────────┐  |
|  │ Middle-of-Line (MOL)                                        │  |
|  │ └── local interconnect + via0                               │  |
|  └─────────────────────────────────────────────────────────────┘  |
|                                                                   |
|  ┌─────────────────────────────────────────────────────────────┐  |
|  │ Back-End-of-Line (BEOL) — ≥ 14 metal layers @ N5+           │  |
|  │ ├── ULK dielectric (k ≤ 2.5)                                │  |
|  │ ├── Cu damascene (M0 → Mn)                                  │  |
|  │ ├── Co/Ru cap (advanced nodes)                              │  |
|  │ └── top metal + RDL + uBump pads                            │  |
|  └─────────────────────────────────────────────────────────────┘  |
|                                                                   |
|  ┌─────────────────────────────────────────────────────────────┐  |
|  │ Wafer test (parametric) → bin out → dicing → packaging      │  |
|  └─────────────────────────────────────────────────────────────┘  |
+-------------------------------------------------------------------+
```

## 7. BOM / cost-class estimate (paper)

| line item                              | v1.x cost class                |
|:---------------------------------------|:--------------------------------|
| 300 mm wafer (N5, fully processed)     | ~$15–20 K / wafer (foundry quote)|
| MPW shuttle slot (N5, ~6 mm² die)      | ~$0.5–1.5 M (1 wafer reticle)    |
| PDK access (N5)                        | ~$1–3 M / year (foundry license) |
| Mask set (full, single-customer N5)    | ~$30–50 M                        |
| EDA license (Cadence/Synopsys/Siemens) | ~$1–5 M / year (multi-tool)      |
| Single tape-out (N5, ~50 mm² die)      | ~$10–30 M (mask + verification)  |

Cost ladder (.roadmap §A.6 step 2 funding):

- IP-only paper qualification: in scope of this repo
- MPW shuttle (small die, N5): ~$0.5–1.5 M
- Single full tape-out (N5): ~$10–30 M
- Volume production: vertical-integration scope; out of single-repo scope

## 8. Conformance to RSC closure

| tier         | source                                         | status            |
|:-------------|:-----------------------------------------------|:------------------|
| T1 algebraic | `verify/calc_process.hexa`                     | ✓ σ=12 + τ=4      |
| T2 numerical | `verify/numerics_process{,_parity,_solver}.hexa`| ✓ ×3 stack       |
| T3 archival  | `verify/empirical_process.hexa`                | ✓ 10 rows / 3 vendors / 5 gens |
| T3 bench     | (this document is its prereq)                  | ✗ Stage-1+ §A.6   |

## 9. Provenance

- Vision spec: `process/chip-process.md`
- Verification floor: `verify/calc_process.hexa` + `numerics_process_*.hexa`
  + `empirical_process.hexa`
- Roadmap: `.roadmap.hexa_chip` §A.4 F-CHIP-1 + §A.6 / §A.6.1
- IRDS / ITRS: International Roadmap for Devices and Systems (public)
- Public density references: WikiChip TSMC/Samsung/Intel pages,
  ISSCC plenaries 2017–2024, IEDM tech symposia
- n=6 lattice: σ(6)=12, τ(6)=4, φ(6)=2, J₂=24

## 10. Open issues / next-step gates

| gate | needs                                              | resolves    |
|:-----|:---------------------------------------------------|:------------|
| G1   | foundry partner MOU + NDA (§A.6 step 1)           | PDK access  |
| G2   | EDA toolchain access (Cadence / Synopsys / Siemens) | RTL → GDSII |
| G3   | PDK-bound corner extraction                        | real corners|
| G4   | gen_idx=12 (2 nm class) commercial mainstream qual  | F-CHIP-1.a  |
| G5   | Stage-1 SPICE-corner sweep numerics (Step B)       | sim parity  |

v0.1 freeze: 2026-05-08. Next revision tag: v0.2 after Step B
(SPICE-corner numerics scripts) lands.
