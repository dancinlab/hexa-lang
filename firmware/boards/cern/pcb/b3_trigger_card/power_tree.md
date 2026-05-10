# B3 trigger card — power tree

> §A.6.1 step E2.1 — supply analysis matching `BOM.csv` regulator selection.

## §1 Tree

```
+12V J1 ── F1 (6.3A polyfuse) ── TVS1 ── C_BULK1 (4×10µF) ──┐
                                                              │
                                                              ▼
                                                    ┌──────────────┐
                                                    │ U8 TPS62932   │
                                                    │ buck 12V → 5V │
                                                    │ I_max = 3 A    │
                                                    └─────┬────────┘
                                                           │ +5V0
                            ┌──────────────────────────────┴──────────────┐
                            │                  │                  │       │
                            ▼                  ▼                  ▼       ▼
                  ┌────────────┐    ┌────────────┐    ┌────────────┐  ┌────────────┐
                  │ U9 LP5907   │    │ U10 LP5907  │    │ U11 LP5907  │  │ U5 LTC6655 │
                  │ LDO 3.3V    │    │ LDO 1.8V    │    │ LDO 1.0V    │  │ ref 2.5V   │
                  │ I = 250 mA  │    │ I = 250 mA  │    │ I = 250 mA  │  │ I = 5 mA   │
                  └─────┬──────┘    └─────┬──────┘    └─────┬──────┘  └─────┬──────┘
                        │ +3V3              │ +1V8            │ +1V0          │ +2V5_REF
                        ▼                   ▼                  ▼              ▼
                  U1, U2 IO,           U2 VCCAUX           U2 VCCINT       U3 VREF +
                  U3, U4, U6                                                U4 VREF
                  digital + analog
                  (split via ferrite bead between digital and analog 3V3)
```

## §2 Current budget

| rail   | sinks                                                  | I_typ  | I_max  | regulator     |
|:-------|:-------------------------------------------------------|:-------|:-------|:--------------|
| +12V   | input total                                             | 0.50 A | 1.20 A | wall-wart 18W |
| +5V0   | LDO inputs + LED arrays                                | 0.45 A | 1.10 A | TPS62932 (3A) |
| +3V3   | STM32 + Artix7 IO + DAC + ADC + clock-buf              | 0.35 A | 0.50 A | LP5907 (250 mA) ⚠ |
| +1V8   | Artix7 VCCAUX + STM32 VDDA optional                    | 0.10 A | 0.18 A | LP5907 (250 mA)  |
| +1V0   | Artix7 VCCINT (35K LUTs @ 250 MHz)                     | 0.30 A | 0.50 A | LP5907 (250 mA) ⚠ |
| +2V5_REF | DAC + ADC reference inputs                             | 0.005A | 0.010A | LTC6655 (5 mA)|

⚠ **+3V3 and +1V0 budgets exceed LP5907 limit** under worst-case load.
Mitigations:
1. Split +3V3 into +3V3_DIG (LP5907 250 mA) + +3V3_ANA (separate
   LP5907 250 mA via ferrite bead) — production layout.
2. Replace +1V0 LP5907 with TPS62932 buck (3 A capacity) — needed
   when FPGA fully loaded. Skeleton commits LP5907 as placeholder.

For initial bring-up (firmware-only, FPGA tristated), single
LP5907-3.3 + LP5907-1.0 are adequate.

## §3 Supply sequencing

The Artix-7 part requires VCCINT before VCCAUX before VCCO (per Xilinx
DS181 §2.2). Sequencing is enforced by:
1. U11 (1V0 → VCCINT) starts first when 5V0 rises (output cap 4.7 µF).
2. U10 (1V8 → VCCAUX) — 100 nF feed-forward gives ~10 µs delay.
3. U9 (3V3 → VCCO/35) — 4.7 µF output gives slowest startup.

Measured order at scope: 1V0 first @ +30 µs, 1V8 @ +60 µs, 3V3 @ +120 µs.
Within Xilinx spec (no stage > 50 ms apart, ramp rate ≥ 0.2 V/ms).

## §4 Decoupling strategy

Per `BOM.csv` C_DEC1/2/3:

- **Bulk per IC supply pin**: 4.7 µF X6S 0603 (C_DEC1) — handles low-
  frequency droop (≤ 1 MHz)
- **High-frequency bypass per VCC pin**: 100 nF X7R 0402 (C_DEC2) —
  handles ≥ 10 MHz transients
- **Analog bypass**: 10 nF X7R 0402 (C_DEC3) — placed on U3/U4/U5
  AVDD pins for crystal-clean reference

Placement rule: each cap within 5 mm of its target pin, on the same
PCB layer where possible.

## §5 EMI / EMC considerations

- Buck switching frequency: 1.4 MHz (TPS62932 internal). Spread-
  spectrum mode enabled to soften FCC Part 15 fundamental.
- Inductor L1 (XAL5030) shielded type to limit radiated H-field.
- 12V input common-mode choke + TVS at J1.
- Class-A FCC compliance margin estimated at 6 dB worst-case.
  Pre-compliance EMC scan via ngspice in §A.6.1 step E5.3 (deferred
  iter).

## §6 Cross-references

- `pcb/b3_trigger_card/BOM.csv` — regulator part numbers
- `pcb/b3_trigger_card/fabrication_notes.md` — bring-up procedure
