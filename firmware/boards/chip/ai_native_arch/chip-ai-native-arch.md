<!-- @canonical: ~/core/canon/domains/compute/ai-native-architecture/ai-native-architecture.md -->
<!-- @extracted: 2026-05-08 -->
<!-- @snapshot_policy: 6-month-stale upstream of canon, per CLAUDE.md canon_pointer -->
<!-- gold-standard: shared/harness/sample.md -->
---
domain: chip-ai-native-arch
requires:
  - to: chip-architecture
  - to: chip-isa-n6
  - to: chip-npu-n6
  - to: chip-accel
  - to: compiler-os
---

<!-- @own(sections=[WHY, COMPARE, REQUIRES, STRUCT, FLOW, VERIFY, EVOLVE], strict=false, order=sequential, prefix="§") -->

# AI-native architecture — beyond-GPU silicon for honesty-triad enforcement (HEXA-AI)

> **Verb group**: accelerator. **Sister verbs**: `npu_n6/` (MAC array), `gpgpu_n6/`
> (programming-model projection), `pim/` (in-memory), `photonic/` (optical).
>
> **Distinction**: other accelerator verbs are *throughput* substrates. AI-native
> is a **provenance-aware** substrate — silicon primitives that make the honesty
> triad (banner / write-barrier / falsifier) a hardware property rather than a
> process discipline. Targets the AI accelerator class **beyond GPU**.
>
> **Canon SSOT**: `~/core/canon/domains/compute/ai-native-architecture/ai-native-architecture.md`
> (1420 lines, parent omega-cycle session 2026-04-26). This file is a 6-month
> snapshot; treat canon as authoritative.

## §1 WHY (n=6 invariant kernel for the post-GPU AI substrate)

GPU silicon optimises **dense matrix throughput**. AI workloads have a different
critical path: not throughput per se, but the **trustworthiness of each tensor
that flows through the pipeline** — fact vs. hypothesis, audited provenance,
gated promotion, BT-ledger reproducibility.

Layered on top of a GPU, this enforcement costs:

1. Software validation passes (overhead 10-30%, easy to skip silently).
2. Per-call boundary checks (overhead 1-5%, no rollback on bypass).
3. No hardware refusal — bad writes complete unless trapped by software.

**AI-native architecture moves the honesty triad into silicon**:
- `provenance-bit` — 1-bit FACT/HYPOTHESIS flag carried *with the tensor*.
  OR-propagated through the dataflow at zero software cost.
- `promotion-counter-MMU` — write-barrier register file. Refuses any write
  whose `(prov, grade)` pair fails the policy. Hardware-rejected, not
  software-warned.
- `bt-id-isa` — ISA opcode field carrying the breakthrough-theorem
  identifier. Each MAC issuance is auditable to the BT ledger by chip-trace.

These three primitives are **inseparable**: removing any one collapses the
honesty triad back into process discipline. Together they're the smallest
substrate that makes honesty a hardware invariant.

## §2 STRUCT (n=6 derivation — 10 EXACT constants)

All constants below are derived from the n=6 number-theoretic primitives:

```
σ = 12   φ = 2   n = 6   τ = 4   σ_n = 72   J₂ = 24   sopfr(n) = 5
```

Each row has a Python-verifiable source-of-truth (atlas string, sim constant,
or JSON measurement). PASS criterion: `symbolic == observed` for all 10.

| # | Constant                        | n=6 derivation       | Value | Source-of-truth         |
|:-:|:--------------------------------|:--------------------|:-----:|:------------------------|
|  1 | provenance_bit_overhead         | φ / σ_n             | 1/36  | atlas line 526          |
|  2 | n6_native_tiles                 | σ / φ               | 6     | btAI2 N_TILES           |
|  3 | pipeline_stages                 | τ                   | 4     | btAI2 TAU_STAGES        |
|  4 | peak_macs_per_tile_per_cycle    | σ · φ               | 24    | atlas J₂ line 446       |
|  5 | peak_macs_per_array_per_cycle   | σ² · φ              | 288   | atlas σ²·φ              |
|  6 | provenance_threshold_max        | σ                   | 12    | sweep upper bound       |
|  7 | provenance_threshold_min        | φ²                  | 4     | sweep lower bound       |
|  8 | legit_reject_rate_theoretical   | 0                   | 0.0   | _maybe_false_positive   |
|  9 | h1_speculative_drop_floor       | 0                   | 0.0   | btAI2c_h1_results.json  |
| 10 | bt_coverage_count               | sopfr(n) + φ        | 7     | BT_541..547             |

Tile count `n6_native_tiles = σ/φ = 6` is the structural baseline of HEXA-AI;
each tile has `peak_macs_per_tile = σ·φ = 24` MAC slots and is pipelined to
`τ = 4` stages. Across `n6_native_tiles = 6` tiles, peak throughput is
`σ²·φ = 288` MAC/cycle (= the same 288 that GPGPU's J₂′ extension reaches —
the lattices intersect at the array-level peak, but diverge in **how each
MAC is gated**).

## §3 FLOW (provenance + write-barrier + bt-id per MAC)

```
                ┌──────────────────────────────────────────────┐
                │  Tile (one of 6;  σ/φ = 6 native tiles)      │
                │                                              │
   tensor in ──→│  prov-bit lane (φ/σ_n = 1/36 overhead)       │
   (FACT/HYP)   │  ↓                                           │
                │  τ-stage pipeline                            │
                │     stage 0: decode (with bt-id-isa field)   │
                │     stage 1: load (provenance OR-propagate)  │
                │     stage 2: MAC (σ·φ = 24 slots)            │
                │     stage 3: writeback                       │
                │  ↓                                           │
   tensor out ──│  → promotion-counter-MMU gate                │
   + prov bit   │     IF (prov == FACT ∧ grade ≥ threshold)    │
                │        write commits                         │
                │     ELSE                                     │
                │        write refused (banner: hardware-rejected)│
                │                                              │
                └──────────────────────────────────────────────┘
                              │  bt-id-isa audit trail
                              ↓
                        BT ledger (off-chip)
```

**Write-barrier semantics** (§F-AI2-B falsifier target):
- Threshold field is a register-set programmable knob (range `[φ², σ] = [4, 12]`).
- legit-write reject rate (false-positive on FACT writes) bounded at 0% theoretical;
  empirical sweep across 900 cells / 1000 seeds (canon §3) shows 0 breaches.

**Speculative path** (§F-AI2c-A — H1 schedule):
- Eager scheduler proceeds with HYPOTHESIS prov writes to scratch. If a
  downstream BT promotes the result to FACT, scratch is committed atomically.
  Otherwise, scratch is squashed; `h1_speculative_drop_floor = 0`.
- Throughput cost vs. baseline: ≤ 5% (PASS at H1; F-AI2-A PARTIAL → amended
  by F-AI2c-A).

## §4 VERIFY (falsifier ledger, canon §3 mirror)

| ID         | Predicate                                                        | Verdict (canon) | hexa-chip (Phase G) |
|:-----------|:------------------------------------------------------------------|:----------------|:---------------------|
| F-AI1      | MPS / tensor-network surrogate matches NPU within 2%              | HOLD-PROXY      | iter 1 import; iter 4 deferred placeholder |
| F-AI2-A    | provenance ON drops throughput ≤ 5% vs. baseline                  | PARTIAL → amended | iter 1 import; iter 4 numerical sim |
| F-AI2-B    | promotion-counter MMU refuses ≤ 1% legit writes                   | PASS robust     | iter 1 import; iter 4 numerical sim |
| F-AI2c-A   | H1 speculative-eager scheduler keeps drop ≤ 5%                    | PASS at H1      | iter 1 import; iter 4 numerical sim |

**F-AI2-A note**: PARTIAL because single-seed worst-case throughput drop
hit 7.7% (canon `btAI2_results.json`). Amended by F-AI2c-A H1 schedule
which restores the ≤ 5% bound via rollback_rate=0 design move (without
weakening the falsifier itself).

## §5 EVOLVE (closure status, canon §4 mirror)

| Tier        | State (canon) | Rationale                                                        |
|:------------|:-------------:|:-----------------------------------------------------------------|
| design      | MEDIUM (amended) | F-AI2-B robust + F-AI2c-A H1 PASS clear the 5% bound          |
| sim         | MEDIUM        | 1000-seed sweeps + workload coverage on full + matmul + softmax  |
| silicon     | LOW           | RTL stub absent at canon@2026-04-26; only architectural spec     |
| literature  | LOW           | no SC publication; absorption pending nexus                      |

**Alien score path 6 → 10** (canon §4 closing) requires:
- silicon-LOW → MEDIUM via BT-AI3 RTL candidate spec (canon
  `analysis/btAI3_rtl_design.md`).
- F-AI1 HOLD-PROXY → PASS via MPS surrogate (next omega-cycle).
- 6-vendor convergence audit (current cycle item C4).

The **10/10 EXACT closure** documented in §2 is the **design-tier closure**:
every quantitative claim about the silicon primitives is derivable from
n=6 primitives and machine-checkable by the verify script (canon
`verify_ai-native-architecture.hexa`).

## §6 COMPARE (vs. sister accelerator verbs)

| verb              | substrate                  | optimisation target               | honesty triad                  |
|:------------------|:---------------------------|:----------------------------------|:-------------------------------|
| `npu_n6/`         | MAC array (24 sigma slot)  | dense matrix throughput           | software-enforced              |
| `pim/`            | in-memory compute (DRAM)   | bandwidth × locality              | software-enforced              |
| `photonic/`       | optical mesh (J₂ = 24 ch)  | low-energy long-range             | software-enforced              |
| `gpgpu_n6/`       | programming-model layer    | vendor-agnostic dispatch          | software-enforced (host-side)  |
| **`ai_native_arch/`** | **provenance-aware silicon** | **trustworthy tensor flow**   | **hardware-enforced**          |

AI-native is the **first verb where honesty is a hardware invariant**, not a
software pattern. It targets the same peak-MAC throughput as npu_n6 (288 = σ²·φ)
but adds the provenance gate as a non-bypassable layer.

## §7 REQUIRES (cross-verb dependencies)

- **chip-architecture** — invariant lattice (n=6 with σ=12, τ=4, φ=2, J₂=24).
- **chip-isa-n6** — opcode field for `bt-id-isa` slot. Compatible with the
  existing 24-opcode ISA n=6 layout.
- **chip-npu-n6** — peak throughput parity (σ²·φ = 288 MAC/cycle); AI-native
  inherits the 6-tile / σ·φ-MAC microarchitecture.
- **chip-accel** — accelerator group membership (proposed §G.5: option A).
- **compiler-os** — toolchain support for the `bt-id-isa` audit field
  (downstream; canon §6).

## §8 References

- canon SSOT: `~/core/canon/domains/compute/ai-native-architecture/ai-native-architecture.md`
- canon RTL design notes: `~/core/canon/domains/compute/ai-native-architecture/analysis/btAI3_rtl_design.md`
- canon verify (Python-tier): `~/core/canon/domains/compute/ai-native-architecture/verify_ai-native-architecture.hexa`
- parent omega-cycle session: `reports/sessions/omega-cycle-ai-native-arch-beyond-gpu-2026-04-26.md`
- F-AI2c-A summary: `reports/anomaly/btAI2c_h1_summary.md`
- BT ledger range: BT_541..547 (`bt_coverage_count = sopfr(n) + φ = 7`)
- hexa-chip roadmap §G: `.roadmap.hexa_chip §G` (full 9-iter sequence)
- hexa-chip sister verb: `gpgpu_n6/chip-gpgpu-n6.md` (programming-model axis;
  AI-native is the silicon-axis sibling).

## §9 Phase G iteration plan (hexa-chip side; mirror of roadmap §G.4)

| iter | deliverable                                                  | status   |
|:----:|:--------------------------------------------------------------|:---------|
| G 1  | this file (canon snapshot extraction)                         | ✓ this commit |
| G 2  | `doc/datasheet_ai_native_arch.md` — 3 primitive RTL stubs     | pending  |
| G 3  | `verify_ai_native_arch.hexa` (T1 algebraic; 10 EXACT)         | pending  |
| G 4  | `numerics_ai_native_arch.hexa` (T2; F-AI2 sim fixtures)       | pending  |
| G 5  | `empirical_ai_native_arch.hexa` (T3; 1000-seed sweep)         | pending  |
| G 6  | `firmware/mcu/ai_native_host.hexa` (stdlib/hal consumer)      | pending  |
| G 7  | hexa-lang `stdlib/hal/ai.hexa` (provenance-bit dispatch)      | pending (hexa-lang repo) |
| G 8  | `cli/hexa-chip.hexa` `verify ai-native` subcmd                | pending  |
| G 9  | `accel/hexa_ai_native_n6.hexa` (30th verb; accelerator wire)  | pending  |

Closure target: design tier 10/10 EXACT (all 10 §2 constants verifiable via
verify script) by iter 4. Silicon LOW → MEDIUM bridge is downstream of this
verb (BT-AI3 RTL design landing in canon).
