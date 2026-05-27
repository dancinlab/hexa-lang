<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-ORBIT-01 — Phase E commissioning checklist

> Bench bring-up procedure once boards arrive from JLCPCB.  Each step
> has a PASS/FAIL gate; failures roll back to root-cause investigation.

---

## §0 Pre-bench (inspect-only, before powering)

- [ ] Visual: no shorts on USB-C VBUS, no missing 0402 components.
- [ ] Continuity: J1.VBUS → F1.IN, F1.OUT → U6.IN, U6.OUT → MCU.VDD (10 pins).
- [ ] Continuity: GND plane → MCU.VSS (8 pins) → all peripheral GND.
- [ ] Crystal: Y1 pads have C1/C2 fitted (check value 18 pF).
- [ ] Polarity: D1 TVS marker matches silkscreen.

## §1 Power-only test (no MCU activity)

1. Apply 5 V via bench supply at J1.VBUS, current limit 100 mA.
2. Measure +3V3 = 3.30 ±0.05 V at TP1.
3. Measure +1V2_CORE = 1.20 ±0.03 V at TP2.
4. Measure +3V3_A = 3.30 ±0.05 V at TP3.
5. Total quiescent current ≤ 50 mA (MCU not yet programmed).
6. **Gate**: all rails in spec — proceed to §2; else inspect U6/U7.

## §2 SWD probe + first flash

1. Connect ST-Link V3 to J2 (10-pin Cortex SWD).
2. Run `st-info --probe` → expect chip-id 0x450 (STM32H743).
3. Flash bootloader: `st-flash write firmware/build/orbit_01_boot.bin 0x08000000`.
4. Reset (SW1).  Watch SWO trace for "ORBIT-01 BOOT 0x060C0402" identity print.
5. **Gate**: identity register matches `HEXA_REG_ID` per spec; else
   re-check option-byte programming.

## §3 Clock validation

1. Probe TP5 (OSC_25M) with 500 MHz scope; expect 25.000 ±0.001 MHz sine.
2. Verify SYSCLK 480 MHz via MCO output: configure PA8 as MCO1 div 16
   → expect 30 MHz at PA8.
3. **Gate**: SYSCLK = J₂·σ·sopfr/3 = 480 MHz within 20 ppm; else recompute
   PLL coefficients (HSE → /5 → ×96 → /1 = 480).

## §4 GPS NMEA + 1 PPS

1. Plug magnetic GPS antenna (active, 3.3 V bias) into U2.ANT.
2. Wait ≤ 60 s for fix (cold start in clear sky).
3. Open virtual COM via ST-Link bridge; observe NMEA `$GPRMC` sentences
   at 9600 baud with `A` (active) status.
4. Probe TP6 (PA0/PPS) with scope; expect 1 Hz pulses, 100 ms wide,
   rising edge timestamp aligned to GPS UTC second.
5. Capture 100 PPS edges; verify edge-jitter σ ≤ 50 ns (2-σ).
6. **Gate**: GPS fix + PPS jitter — proceed to §5; else check antenna /
   sky view / cold-start.

## §5 ADC sensor input

1. Connect bench DC source to J5.ADC_IN, sweep 0 → 3.3 V in 100 mV steps.
2. Read raw ADC counts via SWO trace at each step; expect linear fit
   slope = 4096/3.3 = 1241 LSB/V within ±0.5 % full-scale.
3. INL ≤ 2 LSB across mid-band 0.5 – 2.8 V.
4. **Gate**: linearity + ENOB ≥ 11.5 effective bits.

## §6 DAC telemetry output

1. Configure firmware to ramp DAC output 0x0000 → 0xFFFF in 256 steps.
2. Probe J6.DAC_OUT with scope; expect monotonic ramp, no missing codes.
3. Settling time ≤ 10 µs to ½ LSB at full step transition.
4. **Gate**: monotonic ramp + settling spec.

## §7 Sim-firmware validation

1. Flash production firmware: `st-flash write firmware/build/orbit_01.bin 0x08000000`.
2. Open virtual COM → expect boot banner + state machine cycle through
   IDLE → TLE_LOAD → EPHEMERIS_READ → KEPLER_INTEGRATE → COMPARE →
   TELEMETRY → SAFE.
3. Compare board behaviour to `firmware/sim/orbit_pipeline.hexa` 13 sentinel
   PASS items — each must reproduce identical DAC/ADC values + state
   transitions within 1 LSB / 1 µs.
4. **Gate**: board sim ↔ Phase C sim agreement.

## §8 Mercury perihelion validation (F-SPACE-1 closure event)

1. Configure firmware to read Mercury ephemeris (USNO MICA 2024 baseline).
2. Run integrator for 1 century synthetic time.
3. Read perihelion advance from PA0/SWO; expect 43.0 ± 0.043 ″/century
   (recipe target ±0.1 %).
4. **GATE — F-SPACE-1 T3 closure event**: if ±0.1 % met, falsifier
   F-SPACE-1 closes 100 % (T1 ✓ T2 ✓ T3 ✓).  Update
   `verify/falsifier_check.hexa` F1_T3 anchor + commit.

## §9 Thermal soak

1. Place board in thermal chamber, sweep −20 °C → +85 °C.
2. Re-run §3 (clock), §4 (PPS jitter), §8 (perihelion) at each corner.
3. **Gate**: no spec degradation > 10 % across full temp range.

## §10 EMC pre-scan

1. Place board on plywood pad inside semi-anechoic chamber.
2. Sweep 30 MHz – 1 GHz E-field at 3 m distance.
3. Confirm peaks ≤ FCC Part 15 Class B limits (40 dBµV/m at 100 MHz).
4. **Gate**: pre-compliance margin ≥ 6 dB.

---

## Cost summary (Phase E)

| Item | USD |
|:-----|----:|
| 5× boards (qty discount) | 658 |
| ST-Link V3 debugger | 95 |
| Active GPS antenna | 25 |
| Bench supply (rental) | 50 |
| Scope time (lab share) | 0 |
| EMC pre-scan slot | 350 |
| **Total Phase E (per controller)** | **1,178** |

Stage-1 4-controller program: ~$5 k (well under §A.6 ~$25k envelope —
remainder for FPGA tooling licenses).

— provenance: drafted 2026-05-08, RSC iter 18.
