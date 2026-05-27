<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-DXA-01 — Phase E commissioning checklist

> STM32H7-based DXA scanner data ingester.  Same MCU process as ORBIT-01
> + USB host stack + LCD bring-up.

---

## §0 Pre-bench
Same as ORBIT-01 §0.

## §1 Power-only
Same as ORBIT-01 §1.  Plus: `+5V_HOST` rail measures 4.95 ± 0.05 V at TP4
(post U8 power switch, with EN low → no output expected).

## §2 SWD probe + flash
Same as ORBIT-01 §2.

## §3 Clock validation
Same as ORBIT-01 §3.

## §4 USB host bring-up

1. Plug USB stick (FAT32 formatted) into J3.
2. Verify enumeration via SWO trace: VID/PID detected, MSC class enumerated.
3. Verify file-write to USB stick → file readable on host PC.
4. **Gate**: USB host stack works; over-current GPIO does not assert.

## §5 LCD bring-up

1. Connect 5" TFT via FFC at J6.
2. Verify backlight (PWM at 1 kHz).
3. Display test pattern: color bars + checkerboard.
4. **Gate**: pixels display correctly; no artefacts.

## §6 microSD logger

1. Insert SD card (Class 10, FAT32).
2. Firmware writes 1 MB test pattern; read back, verify CRC.
3. **Gate**: write speed ≥ 4 MB/s, no I/O errors over 1 hour soak.

## §7 DXA scanner emulator

1. Flash DXA emulator USB device (USB stick simulating DXA file output).
2. Firmware reads emulated DXA file, parses, fits τ=4 phase exp-decay.
3. Display fit parameters on LCD: λ, t½, BMD% loss.
4. **Gate**: parsed values match emulator ground truth.

## §8 Sim-firmware validation

1. Compare board state machine to `firmware/sim/dxa_pipeline.hexa` 11
   sentinel items.
2. **Gate**: sim ↔ board agreement.

## §9 NASA Twin Study fit (F-SPACE-3 closure event)

1. Load real archived NASA Twin Study BMD timeseries (Garrett-Bakelman 2019).
2. Firmware fits τ=4 phase exp-decay model.
3. Compare half-life parameter to Sibonga 2007 published t½ = 6 mo.
4. **GATE — F-SPACE-3 T3 closure event**: if t½ ∈ [5.4, 6.6] mo (±10%),
   F-SPACE-3 → 100 %.

## §10 Thermal + EMC
Same as ORBIT-01 §9-10.

---

## Cost summary (Phase E)

| Item | USD |
|:-----|----:|
| 5× boards (qty discount) | 893 |
| ST-Link V3 (shared with ORBIT-01) | 0 |
| 5" TFT LCD ×5 | 260 |
| Bench supply (rental) | 50 |
| EMC pre-scan slot | 350 |
| **Total Phase E (per controller)** | **1,553** |

— provenance: drafted 2026-05-08, RSC iter 18.
