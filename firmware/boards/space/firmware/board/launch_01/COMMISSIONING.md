<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-LAUNCH-01 — Phase E commissioning checklist

> ZCU104-class Zynq US+ board bring-up.  More involved than ORBIT-01
> due to BGA-1156 + DDR4 + HDMI training.

---

## §0 Pre-bench

- [ ] X-ray BGA inspection (5 random samples at JLCPCB).
- [ ] Visual: HDMI connector orientation + DDR4 alignment.
- [ ] Continuity: DC jack → buck input.

## §1 Power-only

1. Apply 12 V at J1, current limit 500 mA.
2. Measure +5V0, +3V3, +1V8, +1V0 (VCCINT), +0V85 (VCCBRAM) at TPs.
3. Total quiescent ≤ 800 mA (FPGA un-configured).
4. **Gate**: rails in spec.

## §2 JTAG probe

1. Connect digilent SMT2 to J6.
2. Vivado HW Manager → expect IDCODE 0x14710093 (XCZU7EV).
3. **Gate**: device chain detected.

## §3 SD-card boot

1. Flash boot.bin + image.ub to micro-SD.
2. Insert J5, power-cycle, observe USB-UART (J7→host) for U-Boot prompt.
3. Linux (PetaLinux 2024.1) boot to login.
4. **Gate**: APU boots; PL bitstream loaded.

## §4 200 MHz OCXO

1. Probe Y1 output (post-LDO) with 1 GHz scope.
2. Verify 200.000 MHz ±1 ppb (Allan deviation 1e-9 at τ=1 s).
3. **Gate**: jitter rms ≤ 100 fs.

## §5 DDR4 calibration

1. PetaLinux boot: dmesg → DDR4 PHY calibration messages.
2. memtester 1G — 24 hour soak, expect 0 errors.
3. **Gate**: DDR4 stable.

## §6 HDMI input training

1. Connect SpaceX webcast simulator (HDMI source) to J2.
2. Vivado debug: HPD asserted, EDID exchanged, TMDS lock.
3. Capture 1 frame (1920×1080×24 bit ≈ 6.2 MB) to DDR4.
4. Verify pixel-clock 148.5 MHz @ 1080p60.
5. **Gate**: lock + frame integrity.

## §7 OCR pipeline

1. Render synthetic SpaceX overlay onto webcast input.
2. PL OCR core extracts T+/altitude/velocity from overlay region.
3. Compare extracted values to ground truth — error ≤ 1 LSB digit.
4. **Gate**: OCR accuracy ≥ 99 % across 10,000 frames.

## §8 Sim-firmware validation

1. Load PL bitstream + APU app implementing
   `firmware/sim/launch_telemetry.hexa` 7-state machine.
2. Compare board behaviour to Phase C sim — 11 sentinel items match.
3. **Gate**: sim ↔ board agreement.

## §9 Δv reconstruction (F-SPACE-2 closure event)

1. Feed real archived SpaceX webcast (Falcon 9 Block 5 launch capture).
2. APU runs Tsiolkovsky reconstruction on extracted T+/v_y telemetry.
3. Expect Δv_S1 ≈ 3.18 ± 0.16 km/s (within ±5 % of `numerics_falcon`).
4. **GATE — F-SPACE-2 T3 closure event**: if ±5 % met, F-SPACE-2 → 100 %.

## §10 Thermal + EMC

1. Thermal soak −10 °C to +60 °C (commercial range).
2. EMC FCC Part 15 Class B pre-scan.
3. **Gate**: spec ≥ 6 dB margin.

---

## Cost summary (Phase E)

| Item | USD |
|:-----|----:|
| 5× boards (qty discount) | 9,245 |
| Vivado Design Edition (annual) | 2,895 |
| Digilent SMT2 JTAG | 60 |
| HDMI test source | 350 |
| Bench instruments (lab share) | 0 |
| EMC pre-scan slot | 350 |
| **Total Phase E (per controller)** | **12,900** |

— provenance: drafted 2026-05-08, RSC iter 18.
