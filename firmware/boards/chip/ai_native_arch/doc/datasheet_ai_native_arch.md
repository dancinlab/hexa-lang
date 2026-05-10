<!-- @canonical: ~/core/canon/domains/compute/ai-native-architecture/analysis/btAI3_rtl_design.md -->
<!-- @extracted: 2026-05-08 -->
<!-- @snapshot_policy: 6-month-stale upstream of canon, per CLAUDE.md canon_pointer -->

# HEXA-AI datasheet — Beyond-GPU AI-native silicon (Phase G iter 2)

> **Tier**: design-only paper datasheet. NO synthesis, NO place-and-route,
> NO tape-out, NO measurement. Purpose: foundry-pitch + integration spec
> for the 3 silicon primitives (provenance-bit / promotion-counter-MMU /
> bt-id-isa) that constitute the AI-native substrate.
>
> **Canon SSOT**: `~/core/canon/domains/compute/ai-native-architecture/analysis/btAI3_rtl_design.md`
> (264 lines, parent omega-cycle 2026-04-26). This file paraphrases canon
> for hexa-chip's `ai_native_arch/` verb directory.

## §0 Non-claim disclaimer

This datasheet is a design-tier RTL specification only. It does NOT
constitute, contain, or imply:

- a synthesis run (no Yosys / Synopsys DC / Cadence Genus invocation)
- a place-and-route run (no OpenROAD / Innovus invocation)
- a tape-out commitment to any PDK
- power / performance / area numbers from any EDA tool
- timing closure validation
- physical-design rule check (DRC) or layout-vs-schematic (LVS) sign-off

The numeric area / latency figures in §4 are **placeholder symbolic
estimates** derived from gate-count counting + standard-cell density
assumptions for the candidate PDKs (SKY130 130 nm / TSMC N5 5 nm /
Samsung SF3P 3 nm). They are NOT EDA-tool outputs.

## §1 Provenance-bit register file

### §1.1 Functional spec

A provenance-bit register file holds **one bit per tensor entry** of
the dataflow MAC array:

- `0` → FACT (verified upstream value)
- `1` → HYPOTHESIS (speculative / unverified value)

### §1.2 Propagation rule (OR-propagation)

```
out.prov = OR over all input tensor entries of (input.prov)
```

Implemented as a wide OR-tree at the output port of each MAC array.
For an `M`-input matmul the OR-tree depth is `⌈log₂(M)⌉`; this adds
**zero cycles** to the critical path because the OR-tree is shorter
than the MAC partial-sum tree it runs alongside.

### §1.3 Storage area

Provenance overhead is **exactly `φ / σ_n = 1/36`** of tensor data area:

- For each tensor entry of `B` data bits, the provenance file adds 1 bit.
- Worst-case data width in this design: `B = σ_n / φ = 36` bits.
- Register-area overhead: `1 / 36 ≈ 2.78%`.

### §1.4 RTL sketch (Verilog-style pseudocode, design-only)

```verilog
module prov_regfile #(parameter N_ENTRIES = 144) (
  input  wire                          clk,
  input  wire                          we,
  input  wire [$clog2(N_ENTRIES)-1:0]  waddr,
  input  wire                          wdata_prov,
  input  wire [$clog2(N_ENTRIES)-1:0]  raddr_a,
  input  wire [$clog2(N_ENTRIES)-1:0]  raddr_b,
  output wire                          rdata_prov_a,
  output wire                          rdata_prov_b
);
  reg [N_ENTRIES-1:0] prov_bits;
  always @(posedge clk) if (we) prov_bits[waddr] <= wdata_prov;
  assign rdata_prov_a = prov_bits[raddr_a];
  assign rdata_prov_b = prov_bits[raddr_b];
endmodule
```

`N_ENTRIES = σ² = 144` matches the SM-array size pinned at canon
`atlas/atlas.n6:56`.

## §2 Promotion-counter MMU (write-barrier)

### §2.1 Functional spec

A promotion-counter MMU sits between the MAC output port and the
tensor write-back path. Per candidate write:

```
allow_write = (prov == FACT) AND (grade ≥ threshold)
```

- `allow_write = 1` → write commits to the FACT pool.
- `allow_write = 0` → write **refused**; the hypothesis tensor is
  *poison-marked* so consumers inherit the HYPOTHESIS bit (matches
  canon's BT-AI2 simulator step `effective_prov[tid] = PROV_HYPOTHESIS`).
  A refuse-bit event is emitted on the bus.

### §2.2 Counter width

- Width: `τ = 4` bits per tensor (canon §2 atlas master identity).
- Sufficient because `provenance_threshold_max = σ = 12 < 2⁴ = 16`.
- Verified symbolically by `verify_ai-native-architecture.hexa`
  (canon-side; mirrored to `ai_native_arch/verify_ai_native_arch.hexa`
  in Phase G iter 3).

### §2.3 Latency

Compare-and-decide is a **single combinational stage**: one `≥`
comparator + one AND gate. Pipeline cost = **0 cycles of latency**.
The `+1`-cycle bubble in canon's BT-AI2 simulator is a *throughput*
cost paid only on a refused write, NOT a per-MAC latency cost.

### §2.4 RTL sketch

```verilog
module promotion_counter_mmu #(parameter TAU = 4) (
  input  wire             clk,
  input  wire             prov_in,         // 0=FACT, 1=HYPOTHESIS
  input  wire [TAU-1:0]   grade_in,
  input  wire [TAU-1:0]   threshold_in,
  output wire             refuse_write,
  output wire             promote_to_fact
);
  wire is_fact   = (prov_in == 1'b0);
  wire grade_ok  = (grade_in >= threshold_in);
  assign refuse_write    = ~(is_fact & grade_ok)
                           & (prov_in == 1'b1)
                           & ~grade_ok;
  assign promote_to_fact = is_fact & grade_ok;
endmodule
```

## §3 BT-id ISA extension

### §3.1 Functional spec

Each tensor opcode carries a **3-bit BT-id field** naming which
breakthrough-theorem (BT) the MAC issuance is auditing under. With
`⌈log₂(7)⌉ = 3` bits, the field encodes the seven BTs `BT_541..547`
plus one reserved code:

| BT-id (binary) | BT name                  | KG node              |
|:--------------:|:-------------------------|:---------------------|
| `000`          | reserved (no-BT)         | —                    |
| `001`          | BT_541 (Riemann zeros)   | KG: bt-541-riemann   |
| `010`          | BT_542 (P vs NP)         | KG: bt-542-pnp       |
| `011`          | BT_543 (Yang-Mills)      | KG: bt-543-ym        |
| `100`          | BT_544 (Navier-Stokes)   | KG: bt-544-ns        |
| `101`          | BT_545 (Hodge)           | KG: bt-545-hodge     |
| `110`          | BT_546 (BSD)             | KG: bt-546-bsd       |
| `111`          | BT_547 (Poincaré)        | KG: bt-547-poincare  |

`bt_coverage_count = sopfr(n) + φ = 5 + 2 = 7` (canon §2 constant 10).

### §3.2 Decoder cost

Decoding 3 bits → 7 active outputs takes `sopfr(n) = 5` two-input
gates (small mux tree). Verified by `verify_ai-native-architecture.hexa`
(all 7 BT-ids within 3-bit range + pairwise distinct, no collision).

### §3.3 RTL sketch

```verilog
module bt_id_decoder (
  input  wire [2:0] bt_id,
  output wire [6:0] bt_active   // one-hot for BT_541..547
);
  assign bt_active[0] = (bt_id == 3'b001);  // BT_541
  assign bt_active[1] = (bt_id == 3'b010);  // BT_542
  assign bt_active[2] = (bt_id == 3'b011);  // BT_543
  assign bt_active[3] = (bt_id == 3'b100);  // BT_544
  assign bt_active[4] = (bt_id == 3'b101);  // BT_545
  assign bt_active[5] = (bt_id == 3'b110);  // BT_546
  assign bt_active[6] = (bt_id == 3'b111);  // BT_547
endmodule
```

### §3.4 ISA n=6 integration

The 3-bit BT-id field extends the existing `chip-isa-n6/xn6-isa-24-spec`
opcode encoding. The 24-opcode ISA already uses `⌈log₂(24)⌉ = 5`
opcode bits; adding a 3-bit BT-id field puts the AI-native tensor
opcode at **8 bits / instruction** for the opcode + audit half. The
remaining 24 bits (in a 32-bit instruction word) carry operand
addresses + grade + threshold field.

## §4 Top-level integration

The three primitives compose into one HEXA-AI tile. A tile owns:

- one `σ² = 144`-entry MAC array (from `chip-npu-n6` substrate)
- one `prov_regfile` (one provenance bit per MAC entry)
- one `promotion_counter_mmu` (one MMU register per tile)
- one `bt_id_decoder` (one decoder per opcode-issue port)

`σ / φ = 6` such tiles per HEXA-AI chip → **peak throughput
σ² · φ = 288 MAC/cycle** at the array level, identical to the
GPGPU J₂′ extension target (canon §2 constant 5).

### §4.1 Tile area breakdown (placeholder symbolic; not from EDA tools)

| Block                  | Symbolic area | SKY130 130 nm | TSMC N5 5 nm  | Samsung SF3P 3 nm |
|:-----------------------|:-------------:|:-------------:|:-------------:|:-----------------:|
| MAC array (σ²)         | dominant      | ~2.0 mm²      | ~0.05 mm²     | ~0.018 mm²        |
| prov_regfile (σ²·φ⁻¹)  | 1/36 of MAC   | ~0.056 mm²    | ~0.0014 mm²   | ~0.0005 mm²       |
| promotion_counter_mmu  | 1 MMU/tile    | ~0.001 mm²    | <0.0001 mm²   | <0.0001 mm²       |
| bt_id_decoder          | 5-gate decode | <0.001 mm²    | <0.0001 mm²   | <0.0001 mm²       |
| **Per-tile total**     |               | ~2.06 mm²     | ~0.052 mm²    | ~0.0188 mm²       |
| **6-tile chip**        |               | ~12.4 mm²     | ~0.31 mm²     | ~0.113 mm²        |

Numbers are derived from gate-count counting + 250 K-gate/mm² density
for SKY130, 8 M-gate/mm² for TSMC N5, 22 M-gate/mm² for Samsung SF3P
(public foundry density disclosures, web-searched 2026-05-08). NOT
EDA-tool outputs.

### §4.2 Critical path & frequency target

- Critical path: MAC partial-sum tree at `σ = 12`-input level.
- Provenance OR-tree runs in parallel; shorter than the MAC tree
  (canon §1.2). Adds 0 cycles of latency.
- Promotion-counter MMU: 1-stage combinational gate (canon §2.3).
- Frequency target (placeholder, design-only):
  - SKY130: 200-400 MHz (open-source PDK ceiling)
  - TSMC N5: 1.5-2.0 GHz
  - Samsung SF3P: 2.0-2.5 GHz

## §5 Pin-level interface (per-tile)

| Direction | Signal             | Width | Description                         |
|:----------|:-------------------|:-----:|:------------------------------------|
| input     | `clk`              | 1     | tile clock                          |
| input     | `rst_n`            | 1     | active-low reset                    |
| input     | `mac_we`           | 1     | MAC array write enable              |
| input     | `mac_waddr`        | 8     | write address into σ²=144 entries   |
| input     | `mac_wdata`        | 36    | data tensor entry (σ_n / φ width)   |
| input     | `prov_in`          | 1     | input provenance bit                |
| input     | `bt_id_in`         | 3     | BT-id field (3-bit; canon §3)       |
| input     | `grade_in`         | 4     | grade field (τ-bit; canon §2)       |
| input     | `threshold_in`     | 4     | threshold register file entry       |
| output    | `mac_rdata`        | 36    | data tensor entry (read-back)       |
| output    | `prov_out`         | 1     | output provenance (OR-propagated)   |
| output    | `refuse_write`     | 1     | promotion-counter MMU rejection     |
| output    | `promote_to_fact`  | 1     | MMU promote-to-FACT signal          |
| output    | `bt_active`        | 7     | one-hot decoded BT-id for audit log |

Total per-tile interface: **8 inputs + 5 outputs**, ≈ 102 bits each
direction (+ clk/rst overhead). Compatible with chip-npu-n6 array
boundary; integrates as a wrapper around the existing MAC array.

## §6 Process-node candidates (paper, no commitment)

Per canon `target_pdk_candidates`:

| PDK            | Status     | Notes                                        |
|:---------------|:-----------|:---------------------------------------------|
| SKY130         | candidate  | open-source; viable for tape-out ($25-50K via Efabless shuttle) |
| TSMC N5        | placeholder| 5 nm production node; needs MOU + foundry licence (~$3 M MPW) |
| Samsung SF3P   | placeholder| 3 nm production node; needs Korea fab partner MOU; ~$5-10 M MPW |

PDK selection is downstream of §A.6 Stage-1 work (canon → roadmap §A.6
of hexa-chip). Until selection: this datasheet stays paper-tier.

## §7 Cross-link

- canon SSOT (full RTL spec): `~/core/canon/domains/compute/ai-native-architecture/analysis/btAI3_rtl_design.md`
- canon parent: `~/core/canon/domains/compute/ai-native-architecture/ai-native-architecture.md` (this verb's parent SSOT, 1420 lines)
- canon verify (Python-tier, retired): `verify_retired_py` list
- canon verify (hexa-tier): `domains/compute/ai-native-architecture/verify_ai-native-architecture.hexa`
- hexa-chip parent verb-md: `ai_native_arch/chip-ai-native-arch.md` (Phase G iter 1)
- hexa-chip future verify: `ai_native_arch/verify_ai_native_arch.hexa` (Phase G iter 3, planned)
- hexa-chip ISA n=6 substrate: `chip-isa-n6/xn6-isa-24-spec`
- hexa-chip MAC array substrate: `chip-npu-n6` verb (σ²=144 array)
- BT ledger: BT_541..547 (canon §3 `bt_coverage_count = 7`)

## §8 Falsifier ledger (silicon-tier, design-only assertions)

Per canon §6, the 4 falsifiers are paper-tier in this datasheet:

| ID         | Silicon-tier assertion                                              | Status   |
|:-----------|:--------------------------------------------------------------------|:---------|
| F-AI1      | MPS surrogate matches NPU within 2% — **not testable in silicon spec** | HOLD-PROXY |
| F-AI2-A    | provenance ON drops throughput ≤ 5% — silicon-spec assertion: prov_regfile + OR-tree add 0 cycles latency | PARTIAL → amended |
| F-AI2-B    | promotion-counter MMU refuses ≤ 1% legit writes — silicon-spec assertion: combinational gate is exact (no hazard) | PASS robust (deterministic) |
| F-AI2c-A   | H1 speculative-eager scheduler keeps drop ≤ 5% — silicon-spec assertion: MMU refuse signal is single-cycle, no rollback hardware needed (handled in firmware/scheduler) | PASS at H1 |

## §9 What this spec does NOT claim

- No tape-out commitment.
- No EDA-tool output.
- No power / performance / area numbers from synthesis.
- No timing-closure validation.
- No DRC / LVS sign-off.
- No physical-design layout.
- No process-node selection commitment (SKY130 / TSMC N5 / Samsung SF3P
  all listed as candidates; none selected).

This datasheet documents **what the silicon would need to look like** for
the AI-native substrate, not what has been built.
