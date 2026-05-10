# schematic_v0 — thrust acquisition (HEXA-PROPULSION-FW-01)

> Phase C.5 schematic block-spec for **F-AM-4**.  16-channel waveform
> digitizer (12-bit @ 10 GS/s per ch via JESD204C) + Watt-balance
> 24-bit ADC + BGO/ToF coincidence trigger + DDR4 burst buffer +
> PCIe Gen4 ×16 to host.  XCVU13P FPGA centerpiece.

**Status**: paper schematic v0 (2026-05-08) · **Sim**: thrust_acquisition.hexa (10/10 PASS) · **HDL**: thrust_acq.v + thrust_acq.xdc · **MCU**: thrust_bench.rs · **PCB**: TBD (highest-cost board, ~$30-50K fab+assy)

---

## §1 Block diagram

```
   ┌────────────────────────────────────────────────────────────────┐
   │   ATX 24-pin (J1) + 12 V EPS ×2 (J2)                            │
   └─┬─────┬─────┬─────┬─────┬─────────────────────────────────────┘
     │5V   │12V  │3.3V │1.2V │ 0.85V (FPGA core, ~150 W)
     │     │     │     │     │
   ┌─▼─────▼─────▼─────▼─────▼─────────────────────────────────┐
   │   PMIC stack (TPS54620 + LTM4677 ×3 + LTM4644)            │
   │   Power-good sequencer (TPS3R10) for XCVU13P              │
   └─┬─────────────────────────────────────────────────────────┘
     │
     │      ┌──────────────────────────────────────────┐
     │      │  XCVU13P-FLGA2577-1                      │
     │      │  ┌──────────────────────────────────┐    │
     │      │  │ 128 GTYE4 SerDes (32 Gbps each)  │    │
     │      │  └─────┬────────────────────┬───────┘    │
     │      │        │                    │            │
     │      │  ┌─────▼──────┐    ┌────────▼────────┐   │
     │      │  │ JESD204C   │    │ PCIe Gen4 ×16   │   │
     │      │  │ ADC link   │    │ to host         │   │
     │      │  └─────┬──────┘    └─────────────────┘   │
     │      │        │                                 │
     │      │  ┌─────▼─────────────────────────┐       │
     │      │  │ DDR4 burst buffer ×4 banks    │       │
     │      │  │  64-bit @ 2400 MHz = 19 GB/s  │       │
     │      │  └───────────────────────────────┘       │
     │      └──────────────────────────────────────────┘
     │           │           │            │
     │           │           │            │
     ▼           ▼           ▼            ▼
   16× ADC     BGO trig    ToF trig    NIM/CAMAC
   AD9213         AD8615      AD8615   ×8 (general)
   12-bit        discrim     discrim
   10 GS/s        thresh      thresh
   ─────         ─────       ─────
   J4-J19        J20         J21      J22-J29
   (LEMO)        (LEMO)      (LEMO)   (NIM)

   Watt-balance: LTC2387 24-bit, J30 (DB-9) → calibrated mass + force
   readback at 1 kSa/s.
```

## §2 Power tree

| Rail | Source | Current | Decoupling | Notes |
|:-----|:-------|--------:|:-----------|:------|
| 12 V | J2 EPS ×2 | 25 A total | 12× 470 µF AlPo | FPGA + ADC pre-reg |
| 5 V | ATX | 15 A | 8× 220 µF | PMIC + analog board |
| 3.3 V | TPS54620 | 6 A | 12× 22 µF | I/O bank VCC |
| 1.8 V | LTM4677-A | 8 A | 16× 22 µF | DDR4 + JESD204C VCCAUX |
| 1.2 V | LTM4677-B | 12 A | 24× 22 µF | DDR4 VCCDDR |
| 1.0 V | LTM4677-C | 15 A | 32× 22 µF | FPGA VCCBRAM |
| 0.85 V | LTM4644 (×4 in parallel) | 180 A | 128× 22 µF + 64× 100 µF AlPo | FPGA VCCINT (~150 W peak) |

## §3 Net list (highlights)

| Net | Source | Destination | Length | Impedance | Layer |
|:----|:-------|:------------|------:|:----------|:------|
| ADC[0..15]_LANE[0..3] | J4-J19 → AD9213 → SerDes | < 50 mm | 100 Ω diff (32 Gbps GTYE4) | inner stripline, length-matched ±0.05 mm per lane |
| ADC_SYSREF | XCVU13P → AD9213 array | length-matched all 16 ADCs | 100 Ω diff | inner |
| TRIGGER_FANOUT[0..15] | XCVU13P → 16 ADC trigger inputs | length-matched ±5 mm (= 33 ps) for ≤ 1 ns total skew | 100 Ω diff | inner |
| BGO_TRIG_IN | J20 → discriminator → XCVU13P | < 30 mm | 50 Ω SE | top |
| ToF_TRIG_IN | J21 → discriminator → XCVU13P | < 30 mm | 50 Ω SE | top |
| WATT_BALANCE_SDO | LTC2387 → XCVU13P | < 60 mm | 100 Ω diff | inner |
| DDR4_DQ[0..63] | XCVU13P → DDR4 chip array | length-matched per byte lane (8 lanes) | POD12 1.2 V | inner stripline (impedance-controlled, T-topology) |
| PCIE_TX/RX[0..15] | XCVU13P SerDes → PCIe Gen4 connector (J35) | < 80 mm | 100 Ω diff (16 Gbps) | inner, length-matched ±0.05 mm |
| 10 MHz_REF | J3 (BNC, from atomic_clock board) → AD9528 | < 40 mm | 50 Ω SE | top |

## §4 KiCad library map

| Component | Library | Symbol | Footprint |
|:----------|:--------|:-------|:----------|
| XCVU13P | FPGA_Xilinx_Virtex_UltraScale_Plus | XCVU13P-FLGA2577 | Package_BGA:BGA-2577_52.5x52.5mm_P1.0mm |
| AD9213 | Analog_ADC | AD9213BBPZ-RL7 | Package_BGA:BGA-196_15x15mm |
| LTC2387 | Analog_ADC | LTC2387-24 | Package_DFN_QFN:DFN-16_3x4mm |
| AD8615 | Analog_OpAmp | AD8615-EJP | Package_SO:TSOT-23-5 |
| LTM4677 | Power_Management | LTM4677EY | Package_BGA:BGA-77_15x9mm |
| AD9528 | Analog_Clock | AD9528BCPZ | Package_DFN_QFN:LFCSP-72 |
| DDR4 (×4) | Memory_RAM | MT40A1G4HS-093E | Package_BGA:BGA-78_9x14mm |

## §5 PCB stackup + layout

- **20 layers** (HDI mandatory):
  - 4 high-speed signal layers for SerDes (impedance-controlled)
  - 4 power planes (0.85 V, 1.0 V, 1.2 V, 1.8 V — separate islands)
  - 6 ground reference planes (alternating)
  - 6 routing/control layers
- **Outline**: 280 × 230 mm (full 6U Eurocard)
- **Min trace/space**: 0.05/0.05 mm (2 mil) under XCVU13P
- **HDI**: blind/buried vias (≥ 4 lamination cycles)
- **Diff pair impedance**: 100 Ω with ±5 % tolerance, length-matched to ±0.05 mm

## §6 EMI / signal integrity

- **GTYE4 lanes**: separate signal layer with continuous reference plane, no via-stitched return path breaks
- **DDR4 byte lanes**: T-topology with stub-matched return path
- **PCIe edge connector**: backplate with EMI gasket
- **ADC analog frontend**: top-side shielded enclosure (50 × 200 mm) over all 16 LEMO inputs + AD9213 array
- **BGO/ToF discriminator**: separate analog ground island; opto-isolated trigger output to FPGA logic ground
- **Watt-balance**: separate analog 1.8 V LDO (TPS7A47) with star-ground topology

## §7 Bring-up checklist

1. Bare board: continuity + insulation R > 1 GΩ.
2. Power sequence per XCVU13P PG requirements (must be deterministic).
3. JTAG XCVU13P + DDR4 controller.
4. Vivado bitstream (thrust_acq.bit).
5. AD9528 PLL lock at 10 MHz Cs ref input.
6. Per-ADC JESD204C link bring-up (16 channels, sequential).
7. DDR4 BIST.
8. PCIe link train at Gen4 ×16 (16 GT/s × 16 = 64 GB/s peak, sustained ~50 GB/s).
9. Trigger fan-out skew measurement (LECROY oscilloscope at 16 ADC trigger inputs simultaneously).
10. Cosmic-ray run: BGO + ToF coincidence rate ~ 1 Hz / cm² (matches sim).
11. Watt-balance: known calibration mass → ADC readback compared to physical reference.

## §8 Acceptance gates

- All 10 sim invariants reproducible
- ADC SNR ≥ 9 ENOB at 5 GHz Nyquist
- Trigger fan-out skew ≤ 1 ns across all 16 channels
- BGO ↔ ToF coincidence window ≤ 50 ns (verifiable with cosmic events)
- Sustained DAQ rate ≥ 2.4 GB/s (post-zero-suppression)
- PCIe sustained ≥ 30 GB/s to host

## §9 Forward path

| Step | Artefact | Gating |
|:-----|:---------|:-------|
| 1 | KiCad library entries (XCVU13P FLGA2577 — largest BGA in Xilinx UltraScale+) | export from Xilinx PinPlanner; ~12 hr import work |
| 2 | Schematic (.kicad_sch) | from §1 + §3, ~40-60 hr |
| 3 | PCB HDI layout | requires impedance-controlled HDI mfr (Sanmina, TTM); ~3-4 weeks |
| 4 | Gerber + drill + paste | from layout |
| 5 | Vivado synth + bitstream (XCVU13P is the largest device in Vivado; may require batch licensing) | requires `thrust_acq.xdc` (in repo) |
| 6 | Fab + assembly | $30-50 K (most expensive board in fleet); HDI manufacturer required (Sanmina, TTM, Würth) |
| 7 | Bring-up per §7 | post-board |

## §10 Cost note

This board is the single most expensive item in the Stage-1 build:
  - PCB fab + assembly: $30-50 K
  - XCVU13P FPGA: $25-35 K (single chip, distributor channel)
  - 16× AD9213 ADCs: 16 × $1.5 K = $24 K
  - PMIC + DDR4 + connectors + LEMO: ~$5 K
  - **Total**: ~$85-115 K

For Stage-1 prototype-only (not fleet), this is the cost gate.  An
alternative path uses 4× AD9213 instead of 16× (cuts ~$18 K + drops
total to ~$65 K) — sufficient for first-light p̄ thrust measurement at
reduced solid-angle coverage.
