# Phase E — PCB layout + fabrication plan (HEXA-FIRMWARE-PHASE-E-02)

> Companion to `phase_e_kicad_plan.md`.  Specifies the post-schematic
> route from KiCad PCB editor → fab vendor → assembled board on
> bench.  No PCBs exist yet; this is the cost/time/quality contract.

**Status**: paper plan (2026-05-08) · **First fab spin**: TBD (post-funding)

---

## §1 Per-board layout effort estimate

| Board | Est. layout time (SE-h) | DfM rounds | Spin budget | Per-spin cost |
|:------|:----------------------:|:----------:|:-----------:|:-------------:|
| pet_cyclotron | 30 | 1 | 2 | ~$50 (4L 100×80 mm) |
| atomic_clock  | 80 | 2 | 2 | ~$190 (6L 180×180 mm) |
| tabletop_penning | 160 | 2 | 2 | ~$1,800 (8L HDI 200×200 mm) |
| thrust_acquisition | 320 | 3 | 3 | ~$5,500 (14L HDI 300×250 mm) |
| **Aggregate** | **590 SE-h** | | **2.25 avg** | |

Spin budget = expected number of fab orders before clean DRC+SI+test
result.  thrust_acq gets 3 spins — XCVU13P + 16-channel JESD204C is
high-risk for first-pass routing.

## §2 Stackup details

### 4-layer (pet_cyclotron) — JLCPCB stock

| Layer | Material | Thickness | Use |
|:-----:|:---------|:---------:|:----|
| 1 (top)    | 1 oz Cu | 35 µm | sig + components |
| (prepreg)  | FR-4    | 0.21 mm | — |
| 2 (GND)    | 1 oz Cu | 35 µm | reference plane |
| (core)     | FR-4    | 0.71 mm | — |
| 3 (+3.3V)  | 1 oz Cu | 35 µm | power plane |
| (prepreg)  | FR-4    | 0.21 mm | — |
| 4 (bottom) | 1 oz Cu | 35 µm | sig (BGA escape, backside) |

Total = 1.6 mm.  Single-sided SMT (one flip avoidance saves $).

### 8-layer HDI (tabletop_penning) — PCBWay HDI Z-controlled

| Layer | Use | Notes |
|:-----:|:----|:------|
| 1 | sig (component side) | 0.5 oz Cu, micro-via fanout |
| 2 | GND | full pour |
| 3 | +1.0 V (FPGA core) | thermal-relief vias |
| 4 | +1.2 V (DDR4 + LVDS) | controlled-Z route layer |
| 5 | +1.8 V / +3.3 V | mixed pwr |
| 6 | GND | full pour |
| 7 | sig (LVDS critical) | inner stripline 100 Ω diff |
| 8 | sig (bottom side) | secondary route + connectors |

Cu thickness 0.5 oz inner / 1 oz outer.  HDI uses µVia + buried via
between L3–L6 for FPGA escape.

### 14-layer HDI back-drilled (thrust_acquisition) — PCBWay/AT&S

L1 sig | L2 GND | L3 +1.0V | L4 GND | L5 +0.9V (MGTAVCC) | L6 GND |
L7 sig CML diff | L8 GND | L9 +1.2V | L10 GND | L11 +1.8V | L12 +3.3V/+5V |
L13 GND | L14 sig.

Back-drill on PCIe Gen4 + JESD204C SerDes vias to remove stub.  This
is the only board that strictly needs back-drill.

## §3 Critical signal routing

| Signal class | Target spec | Failure mode |
|:-------------|:------------|:-------------|
| GbE diff pair | 100 Ω ±10% | link drops below 1 Gbps |
| LVDS DAC/ADC | 100 Ω ±5%, length-matched ±0.5 mm | data eye closure |
| PCIe Gen4 (thrust_acq) | 85 Ω ±5%, back-drilled vias, length ±0.25 mm | link train fails |
| JESD204C SerDes (thrust_acq) | 100 Ω ±5%, ±0.25 mm | sync_n drop, lane errors |
| DDR4 byte lane | 40 Ω ±5%, length-matched ±2 mm | DDR cal fail |
| Cs ref 10 MHz | 50 Ω microstrip, < 30 cm trace | jitter > 1 ps RMS |

## §4 Fabrication checklist (per spin)

1. **DRC clean** in KiCad (Edge Cuts, Clearance, Track Width, Hole)
2. **ERC clean** in schematic (no unconnected, no driver conflict)
3. **Stackup quote** from vendor (controlled-Z target verified)
4. **Gerber X2 export** (all layers + drill + paste mask + assembly)
5. **3D model export** (STEP) for mechanical fit-check
6. **Pick-and-place CSV** + **BOM CSV** for SMT assembly quote
7. **Fab DRC report** review (vendor side, return < 24 hr)
8. **Pre-fab DfM revision** (typically 1–2 changes)
9. **PO + fab** (lead time per §1)
10. **Receiving inspection** — bare board AOI, X-ray (BGA), continuity
11. **SMT assembly** → first-article inspection
12. **Bring-up per `board_v0_*.md §7`**

## §5 SMT assembly options

| Vendor | Cost (per board) | Lead | Strengths |
|:-------|:----------------:|:----:|:----------|
| JLCPCB SMT | $25–50 (one-sided 4L) / $200–500 (BGA + LFCSP) | 5–10 d after fab | cheapest for SMT-feasible parts |
| PCBWay Pro | $200–800 (one-sided 6–8L) / $1k–5k (HDI BGA) | 7–14 d | better BGA AOI; X-ray included |
| AT&S | $5k–20k | 4 wk | aerospace-class; required for thrust_acq |
| Kimball turnkey | quoted | 6 wk | single PO end-to-end (fab → SMT → bring-up) |

## §6 Bench-test logging

Each delivered board → entry in `firmware/doc/phase_e_procurement.md`:
- Receiving date + Po number
- Visual + AOI inspection result
- Power-on smoke test
- Bring-up checklist (per `board_v0_*.md §7`) — pass/fail per step
- Final sim-parity test (matches `firmware/sim/*.hexa`)
- Hand-off to lab integration team

## §7 Cross-link

- `firmware/doc/phase_e_kicad_plan.md`     — KiCad project setup
- `firmware/doc/phase_e_procurement.md`    — SKU receiving + tracking
- `firmware/doc/phase_e_test_report_template.md` — bench-test log template
- `firmware/doc/board_v0_*.md`              — Phase C.5 paper spec (input)
- `.roadmap.hexa_antimatter §A.6.1` Phase E — overall scope
