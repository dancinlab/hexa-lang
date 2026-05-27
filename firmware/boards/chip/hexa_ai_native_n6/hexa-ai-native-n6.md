<!-- @canonical: canon@c0f1f570:domains/compute/ai-native-architecture/ai-native-architecture.md -->
<!-- @extracted: 2026-05-08 -->
<!-- @snapshot_policy: 6-month-stale; canon SSOT is upstream -->
---
domain: hexa-ai-native-n6
requires:
  - to: chip-ai-native-arch        # ai_native_arch/ — full design doc
  - to: chip-npu-n6                # npu_n6/ — base τ=4 array
  - to: chip-pim                   # pim/ — memory tier
  - to: hexa-pim                   # hexa_pim/ — accelerator-group sister
---

<!-- @own(sections=[WHY, COMPARE, REQUIRES, STRUCT, FLOW, VERIFY, EVOLVE], strict=false, order=sequential, prefix="§") -->

# HEXA-AI-NATIVE-N6 (Beyond-GPU AI-native accelerator verb)

> Bridging-verb wrapper for the **AI-native silicon** primitive set. The
> substantive design lives in `ai_native_arch/`; this verb dir exists to wire
> the design into the **accelerator group** (npu_n6 · pim · photonic · accel ·
> asic · hexa_pim · hexa_3d · hexa_wafer · **hexa_ai_native_n6**) so the CLI
> 30-verb / 6-group registry stays consistent.

## §1 WHY (one paragraph)

Off-the-shelf GPUs cannot enforce factual provenance at the **silicon level** —
hallucinations propagate freely because the hardware has no native primitive
for marking a value as `FACT` vs `HYPOTHESIS`. HEXA-AI-NATIVE-N6 adds three
silicon primitives in a 1/36 area overhead envelope (canon §2 row 7):
**provenance-bit / promotion-counter-MMU / bt-id-isa**. The result is the
first hardware-enforced honesty triad — refuse-to-write becomes a silicon
event, not a software check.

## §2 STRUCT (n=6 lattice mirror)

| symbol | value | meaning |
|:--|:--:|:--|
| σ        | 12  | native MAC slots per tile |
| φ        | 2   | provenance kinds (FACT / HYPOTHESIS) |
| τ        | 4   | pipeline stages (configure / start / serve / report) |
| σ_n      | 72  | provenance-overhead denominator |
| J₂       | 24  | σ·φ — MAC/cycle per tile |
| n_tiles  | 6   | σ/φ — native tiles per HEXA-AI chip |
| sopfr(n) | 5   | n=6 sum of prime factors |
| BT_cov   | 7   | sopfr(n)+φ — BT_541..547 audit coverage |
| MAC_array| 288 | σ²·φ — peak MAC/cycle at array level |
| overhead | 1/36| φ/σ_n — provenance area cost per MAC |

## §3 FLOW (axis distinctness)

```
embedded peripheral lattice (σ=12)        — gpio/i2c/spi/uart/adc/dac/...
GPGPU σ=12 (6 vendors × 2 IRs)            — cuda/hip/sycl/opencl/metal/webgpu
AI-native σ=12 native MAC (φ=2 prov)      ← HEXA-AI-NATIVE-N6 (third axis)
```

Each axis is **independent**; a HEXA chip wires all three but their σ-slots do
not collide.

## §4 COMPARE (sister verbs in accelerator group)

| verb              | role                                             |
|:------------------|:-------------------------------------------------|
| npu_n6            | base τ=4 systolic array (no provenance silicon)  |
| pim               | processing-in-memory tier                        |
| photonic          | photonic compute tier                            |
| accel             | generic accelerator wrapper                      |
| asic              | per-domain ASIC carrier                          |
| hexa_pim          | n=6-organised PIM macros                         |
| hexa_3d           | n=6-organised 3D-stacked compute                 |
| hexa_wafer        | n=6-organised wafer-scale fabric                 |
| **hexa_ai_native_n6** | **n=6 provenance-aware silicon — Beyond-GPU** |

Distinction from npu_n6: same τ=4 pipeline, same σ=12 width, but adds
**φ=2 provenance bit** + **promotion-counter-MMU write-barrier** + **bt-id-isa
audit field** on every MAC issuance. F-AI1..F-AI2c-A falsifier ledger.

## §5 VERIFY (T1+T2+T3 design-tier closure)

Substantive verification artifacts live under `ai_native_arch/`:
- `verify_ai_native_arch.hexa`     — T1 algebraic (13/13)
- `numerics_ai_native_arch.hexa`   — T2 numerical (10 checks; F-AI2-A baseline + F-AI2-B robust + F-AI2c-A H1)
- `empirical_ai_native_arch.hexa`  — T3 archival (13/13; 1000-seed canon sweep fixture)

Plus this verb's own n=6 lattice sentinel: `verify_hexa-ai-native-n6.hexa`
(see file).

Silicon-tier (BT-AI3 RTL → tape-out) remains LOW per canon §4.

## §6 REQUIRES

- `chip-ai-native-arch` (`ai_native_arch/`) — substantive design + falsifier
  ledger + RTL stubs.
- `chip-npu-n6` (`npu_n6/`) — base τ=4 systolic array; HEXA-AI-NATIVE-N6 reuses
  this substrate.
- `chip-pim` (`pim/`) and `hexa-pim` (`hexa_pim/`) — memory tier; provenance
  bits flow through PIM banks for hypothesis-tagged speculative reads.

## §7 EVOLVE

| version | content |
|:--------|:--------|
| v0      | this bridging verb (Phase G iter 9; CLI accelerator-group wire) |
| v1      | RTL Verilog stub mirror of `ai_native_arch/doc/datasheet_ai_native_arch.md` §6 (prov_regfile + promotion_counter_mmu + bt_id_decoder) under `firmware/hdl/hexa_ai_native_n6_top.v` |
| v2      | per-PDK area sweep against TSMC N5 / Samsung SF3P / SKY130 fixtures (overhead < 3% target across 3 PDKs) |
| v3      | tape-out gating package — refuse_event silicon trace + BT ledger silicon mirror |

## §8 References

- canon: `~/core/canon/domains/compute/ai-native-architecture/ai-native-architecture.md`
- chip-projection: `ai_native_arch/chip-ai-native-arch.md`
- foundry-pitch: `ai_native_arch/doc/datasheet_ai_native_arch.md`
- T1/T2/T3 verifiers: `ai_native_arch/{verify,numerics,empirical}_ai_native_arch.hexa`
- first stdlib/hal consumer: `firmware/mcu/ai_native_host.hexa`
- stdlib/hal surface: `hexa-lang:stdlib/hal/ai.hexa` (v1.8.0)
- CLI verify subcmd: `hexa-chip verify ai-native` (cli iter 6 — 29581b5)
