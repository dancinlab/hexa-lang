<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-RAPTOR-01 — Phase E commissioning checklist

> Kintex US XCKU040 board for Starship 33-Raptor cluster ingest.
> Similar process to LAUNCH-01 (Zynq US+) minus the PS Linux boot
> (FPGA-only, SPI-flash boot).

---

## §0 Pre-bench
Same as LAUNCH-01 §0.

## §1 Power-only
Same as LAUNCH-01 §1.  Note: +0V95 (vs +0V85) — recheck VCCBRAM rail spec.

## §2 JTAG probe

1. Connect digilent SMT2 to J6.
2. Vivado HW Manager → expect IDCODE 0x13822093 (XCKU040).
3. **Gate**: device chain detected.

## §3 SPI-flash boot

1. Program SPI flash U9 with placeholder bitstream via Vivado.
2. Power-cycle, observe DONE LED assert within 100 ms.
3. **Gate**: bitstream loads from QSPI flash; DONE asserts.

## §4 200 MHz OCXO
Same as LAUNCH-01 §4.

## §5 DDR4 calibration
Same as LAUNCH-01 §5.  Note: MIG IP must target XCKU040 (not ZU7EV).

## §6 HDMI input training
Same as LAUNCH-01 §6.

## §7 33-channel deconv pipeline

1. Render synthetic Starship cluster overlay onto webcast input.
2. PL deconv core extracts 33 per-engine telemetry channels from overlay.
3. Verify each channel reports correct virtual thrust value.
4. **Gate**: 33/33 channels operational, deconv RMS error ≤ 1 % per channel.

## §8 Sim-firmware validation

1. Compare board state machine to `firmware/sim/raptor_cluster.hexa` 11
   sentinel items.
2. **Gate**: sim ↔ board agreement.

## §9 Cluster scaling validation (F-SPACE-4 closure event)

1. Feed real archived Starship IFT (Integrated Flight Test) webcast.
2. PL deconv pipeline extracts 33-engine telemetry timeseries.
3. Compute cluster total thrust = sum(per-engine thrust).
4. Compare to published Starship total thrust ≈ 87 MN within ±5 %.
5. Verify cluster degradation cases (engine-out scenarios) match
   σ·n/φ−3 = 33 → 32 → 31 ... predicted closed-form behavior.
6. **GATE — F-SPACE-4 T3 closure event**: if ±5 % thrust + correct
   degradation, F-SPACE-4 → 100 %.

## §10 Thermal + EMC
Same as LAUNCH-01 §10.

---

## Cost summary (Phase E)

| Item | USD |
|:-----|----:|
| 5× boards (qty discount) | 7,309 |
| Vivado Design Edition (shared with LAUNCH-01) | 0 |
| Digilent SMT2 (shared) | 0 |
| HDMI test source (shared) | 0 |
| Bench instruments (shared) | 0 |
| EMC pre-scan slot | 350 |
| **Total Phase E (per controller)** | **7,659** |

---

## Stage-1 program total (4 controllers)

| Controller | Phase E cost (per) | 5× boards |
|:-----------|-------------------:|----------:|
| HEXA-ORBIT-01    | 1,178   | 658     |
| HEXA-LAUNCH-01   | 12,900  | 9,245   |
| HEXA-DXA-01      | 1,553   | 893     |
| HEXA-RAPTOR-01   | 7,659   | 7,309   |
| **Subtotal (1 board each + tools)** | **23,290** |  |
| **Subtotal (5× boards qty discount)** | | **18,105** |
| **+ Vivado (shared)** | 2,895 | 2,895 |
| **TOTAL Stage-1 program** | **~$26 k** | **~$21 k (qty 5)** |

Within .roadmap §A.6 ~$25 k envelope.  Order of magnitude sized.

— provenance: drafted 2026-05-08, RSC iter 18.
