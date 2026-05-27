<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-RAPTOR-01 — board-level schematic (F-SPACE-4)

> Xilinx Kintex UltraScale XCKU040 (KCU105 dev-kit derivative) + HDMI
> 1080p60 capture + 33-channel deconv data-path FIFOs + DDR4-2400.
> Same HDMI capture process as LAUNCH-01 + per-engine deconv channels.

---

## §1 Block diagram

```
                         ┌──────────────────────────────────┐
                         │  XCKU040-2FFVA1156I               │
                         │  ─ 530K LUT, 19 Mb BRAM           │
                         │  ─ 16× GTH 16.3 Gbps              │
                         │  ─ DDR4 controller via MIG        │
                         └──────────────────────────────────┘
   200 MHz Wenzel OCXO Y1                │ JTAG / cfg
        ┌──┘                             │
   ┌────┴───┐  ┌────────┐  ┌─────────┐  ┌────────┐
   │HDMI in │  │33-ch   │  │DDR4-2400│  │SD-card │
   │TMDS    │  │FIFO    │  │×32-bit  │  │boot    │
   │U2 PI3HD│  │(in PL) │  │U4 ×4    │  │J5      │
   └───┬────┘  └────────┘  └──┬──────┘  └────────┘
       │                       │
       └───────────────────────┘
                          │
                  +12V barrel J1 → U6 multi-rail buck (similar to LAUNCH-01)
```

## §2 Net list (key nets)

Identical pattern to `firmware/board/launch_01/SCHEMATIC.md §2` with
substitutions:
- FPGA U1: XCZU7EV → XCKU040 (no PS — no DDR4-PS, no APU, FPGA-only)
- No HDMI TX (J3 omitted) — RAPTOR-01 is capture-only
- 33-channel deconv data is internal to PL; no external connector
  (channels arrive via HDMI demux + OCR)

Key differing nets:
| Net | From → To | Notes |
|:----|:----------|:------|
| `+1V0_VCCINT` | U6c → FPGA.VCCINT (~4 A typ) | smaller than ZU7EV |
| `+1V8_VCCAUX` | U6d → FPGA.VCCAUX | aux |
| `+0V95_VCCBRAM` | U6e → FPGA.VCCBRAM | (note 0.95V vs 0.85V on ZU7EV) |
| `JTAG_TCK/...` | J6 → FPGA.TCK | JTAG-only config (no PS_JTAG) |
| `BOOT_FLASH_SPI` | FPGA.M[2:0] tied for SPI flash boot | U9 (S25FL256) 256 Mb QSPI |

## §3 Power tree

Same multi-rail buck as LAUNCH-01.  VCCINT current budget ~4 A (vs 6 A
for ZU7EV).  Same OCXO 200 MHz reference + isolated LDO.

## §4 Decoupling strategy
Same as LAUNCH-01 §4, scaled down for smaller VCCINT load (16× 22 µF
vs 24× on LAUNCH-01).

## §5 Connector pinout

- **J1** 12 V DC barrel
- **J2** HDMI Type-A (input from Starship webcast capture)
- **J4** RJ45 GigE (FPGA PL Tri-mode MAC)
- **J5** microSD (alt boot fallback)
- **J6** JTAG 14-pin Xilinx
- **J7** SMA pair (200 MHz ref I/O)
- **J9** Pmod 12-pin (debug — UART + SPI + GPIO)

## §6 Compliance / safety

- Same TVS + polyfuse as LAUNCH-01.
- Boot flash redundancy: SPI flash U9 primary; microSD J5 fallback.
- Master closure register `HEXA_REG_ID = 0x060C0402` written to FPGA
  configuration BBRAM (Vivado MCS injection).

— provenance: drafted 2026-05-08, RSC iter 18.  Spec source `firmware/sim/raptor_cluster.hexa` (11/11 PASS).
