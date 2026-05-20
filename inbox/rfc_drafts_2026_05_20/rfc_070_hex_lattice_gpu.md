# RFC 070 -- n=6 hex-lattice GPU emit (bridge to north-star #3)

**Status:** DRAFT -- Shape-B 1st commit (RFC drafted + first-cycle P1
hand-emit PTX + host harness + silicon fire). Multi-cycle phased work.
Falsifier battery defined.

**Author session:** 2026-05-20, off origin/main HEAD `8765f301`.

**Successor to:** RFC 055 (`hexa-src -> NVPTX` codegen backend) -- the
hand-emit-from-text path lands first as proof the n=6 hex motif executes
on the GPU substrate at all. Source-level lowering follows in later
cycles once a `@gpu_kernel`-style hex-stencil DSL form is agreed.

**Predecessor lineage:** GPU.md `## 10 - Closure criteria` ledger item

> `[ ] n=6 lattice GPU emit smoke -- bridge to north-star #3`

This RFC's P1 cycle is the smoke fire that flips that box.

**North-star alignment:** north-star #3 ("n=6 lattice substrate; final
runtime = hexa-arch comb-chip") declares the n=6 hex-fabric as
hexa-lang's signature lattice (AGENTS.tape `@I id001`). GPU is the
INTERIM execution path until hexa-arch silicon ships
(`reference_pin_trap_pattern.md`, GPU.md sec 9 north-star table). Until
then, the GPU substrate MUST be able to express degree-6 hex-neighbor
operations -- otherwise the hexa-arch comb work has no fall-back
execution layer to dogfood against.

**Scope discipline:** Shape-B per `@D g_inbox_processing_loop`. RFC
drafted + minimum-viable smoke fire landed. Per `@D g3`
(honesty-obligation-external) the closure of this RFC requires the P2-P4
falsifiers (sec 7) to be silicon-measured against larger grids,
floating-point edge cases, and a hexa-source level lowering.

---

## sec 1 -- Background

`n=6` hex-fabric appears across the dancinlab lattice family (comb-chip
`/Users/ghost/core/hexa-arch/[chip]`, the n=6 invariant lattice in
AGENTS.tape, the perfect-number primitives in SPEC.md). Every consumer
of this lattice ultimately needs degree-6 neighbor lookup at compute
time. On the GPU substrate, that resolves to:

- **Connectivity model:** axial coordinates `(q, r)`. The 6 neighbors of
  `(q, r)` are `(q+1, r)`, `(q-1, r)`, `(q, r+1)`, `(q, r-1)`, `(q+1,
  r-1)`, `(q-1, r+1)` (compass: E, W, NE, SW, SE, NW).
- **Storage layout:** flat row-major store. `idx(q, r) = q * R + r`.
- **Edge policy:** out-of-bounds neighbors clamp to `(q, r)` itself
  (deterministic + branch-cheap).

This RFC's P1 cycle hand-emits one PTX kernel implementing the
degree-6 stencil
`out[q,r] = in[q,r] + sum_of_6_neighbors(in[q,r])` and fires it on
RTX 5070 (sm_120, driver 580) via the standard
`cuModuleLoadDataEx` + `cuLaunchKernel` driver path used by RFC 055 /
067 / 069 hand-emit work (`reference_gpu_fire_infra.md`).

## sec 2 -- Deferred work (carried over to P2+)

1. **Grid sweep** -- P1 hits one 8x8 grid (64 cells, 1 block, 1 warp
   doubled). P2 sweeps to 64x64 / 256x256 / 1024x1024 so the cell-per-
   thread fan-out is exercised.
2. **`.shared` staging** -- P1 reads global memory 7 times per cell
   (self + 6 neighbors); for large grids a `.shared` tile + halo + sync
   amortises the global reads. Deferred to P3.
3. **Source-level `@hex_kernel` form** -- `_nvptx_lower_stmt` does not
   yet recognise a hex-stencil op; lowering from a hexa-source DSL is
   deferred to P4 (depends on the `@gpu_kernel` source-level form RFC
   055 sec 12 P4+ identified).
4. **Multi-iteration relaxation** -- repeated stencil application
   (k-iterations) is the natural perf-bench shape; P1 is one shot.
   Deferred to P2.
5. **Boundary policies beyond self-clamp** -- toroidal / reflect /
   zero-pad. P1 uses self-clamp for byte-eq simplicity.
6. **Hexa-arch comb-chip cross-reference** -- once the hexa-arch
   layout RFC fixes `(q, r) -> physical_addr` mapping, the GPU emit
   should mirror that mapping so the same kernel source can target both
   substrates with only the backend swapped. Deferred to P4+.

## sec 3 -- Phasing (4 cycles MIN; falsifier-driven)

### P1 -- hand-emit PTX + smoke fire (this RFC's first cycle)

**This commit's deliverable:**

- this RFC file
- `inbox/fires/rfc070_p1_hex_neighbor_2026_05_20/hex_neighbor.ptx` --
  hand-emit PTX, 8x8 axial grid, 64 threads / 1 block.
- `tool/r070_hex_neighbor_host.c` -- standard
  `cuModuleLoadDataEx` host harness with CPU FP32 reference compare
  (matching gather order so byte-eq is well-defined).
- silicon fire on RTX 5070 (ubu-2) + `result.json` + `fire.log` in the
  fire directory.

**Falsifier:** F-RFC070-HEX-NEIGHBOR-NUMERIC.

**Scope discipline:** smoke fire only. No grid sweep, no perf number,
no source-level lowering. P1's question is exactly one bit:
"can the GPU substrate carry the n=6 hex-neighbor motif at all?"

### P2 -- grid sweep + multi-block

Scale P1's kernel to 64x64 and 256x256 grids via multi-block grids.
Falsifier F-RFC070-HEX-GRID-SWEEP -- numeric byte-eq vs CPU on each
shape.

### P3 -- `.shared` tile + halo

Re-emit the kernel using shared memory + halo, so each cell loads its
6 neighbors from `.shared`. Falsifier F-RFC070-HEX-SHARED-PERF --
TFLOPS / cell-throughput improvement vs P2 baseline.

### P4 -- source-level form + cross-substrate mirror

Hexa-source `@hex_kernel { neighbors=6 }` form lowering through
`_nvptx_lower_stmt`. Falsifier F-RFC070-HEX-SOURCE-EQ -- source-emit
PTX numeric byte-eq vs P1 hand-emit PTX (proves the lowering preserves
the motif).

## sec 4 -- ABI

| field         | type         | note                              |
| ------------- | ------------ | --------------------------------- |
| `in_ptr`      | `.param .u64`| device pointer, FP32 input grid   |
| `out_ptr`     | `.param .u64`| device pointer, FP32 output grid  |
| grid layout   | flat         | `idx(q, r) = q * R + r`           |
| block layout  | 1-D          | one thread per cell, tid.x = idx  |
| dtype         | FP32         | no FMA contract; pure `add.f32`   |

## sec 5 -- Byte-eq preconditions

For F-RFC070-HEX-NEIGHBOR-NUMERIC to PASS with `max|d| = 0` (the
strongest gate), the GPU + CPU paths MUST agree on:

1. **No FMA contraction.** The accumulation is `acc + in[k]`, never
   `acc * 1.0 + in[k]`. PTX uses `add.f32` directly. CPU code path
   uses `acc = acc + in[k]` separated stmts; `-ffp-contract=off`
   (default behaviour on `nvcc` host C, but worth verifying via PTX
   diff `reference_ptx_diff_perf_oracle.md`).
2. **Same accumulation order.** GPU + CPU traverse: self, E, W, NE,
   SW, SE, NW. Reordering changes rounding.
3. **Same input encoding.** Integer-valued FP32 (`(float)i`).
4. **Same edge policy.** Out-of-bounds neighbors -> self.

## sec 6 -- Cheap-first oracle (per `feedback_instrument_first_methodology`)

Before firing on silicon, the kernel was statically verified:

- ASCII-only PTX comments (driver JIT rejects non-ASCII --
  `reference_gpu_fire_infra.md`).
- Single-precision `add.f32` instructions (no `fma.rn.f32`, no
  `mad.f32`).
- Edge-clamp via `selp` (constant-time, no branch divergence).
- One-block fire (no cross-block sync needed).

## sec 7 -- Falsifiers

| ID                                   | claim                                                      | cycle |
| ------------------------------------ | ---------------------------------------------------------- | ----- |
| F-RFC070-HEX-NEIGHBOR-NUMERIC        | max abs delta vs CPU FP32 ref = 0 on 8x8 grid              | P1    |
| F-RFC070-HEX-GRID-SWEEP              | byte-eq on 64x64 / 256x256 / 1024x1024 grids               | P2    |
| F-RFC070-HEX-SHARED-PERF             | `.shared` tile + halo strictly faster than P2 global-only  | P3    |
| F-RFC070-HEX-SOURCE-EQ               | source-emit PTX byte-eq to hand-emit PTX                   | P4    |

## sec 8 -- Cross-references

- AGENTS.tape `@I id001` -- n=6 hex-fabric as hexa-lang signature.
- GPU.md sec 10 -- "n=6 lattice GPU emit smoke" closure box.
- RFC 055 (`inbox/rfc_drafts_2026_05_19/rfc_055_hexa_src_nvptx_codegen.md`)
  -- the source-to-PTX backend P4 cycle will consume the
  `@hex_kernel` form.
- `reference_gpu_fire_infra.md` -- ubu-2 + PTX driver-JIT + ASCII-only
  rules.
- `reference_pin_trap_pattern.md` -- north-star #3 hexa-arch interim
  positioning.
- `project_comb_closure.md` -- `~/core/hexa-arch[chip]` consumer that
  this GPU substrate dogfoods against.

## sec 9 -- Honest scope

Per `@D g3` (verification-anchor-real-limit) and the
`feedback_instrument_first_methodology` memory:

- P1 is **64 cells, one fire, one shape**. It does not claim perf, it
  does not claim hexa-source level integration, it does not claim
  multi-vendor portability. It claims exactly one thing: the GPU
  substrate carries the n=6 hex-neighbor motif with `max|d|=0` numeric
  equivalence to the CPU FP32 reference.
- Cross-substrate mirroring with the eventual hexa-arch comb-chip is
  P4+ work. The `(q, r) -> physical_addr` mapping there is not yet
  fixed -- this RFC takes the simplest row-major flat mapping; the
  hexa-arch RFC will dictate any remap.
- This is not a benchmark. Throughput is not measured. P2 + P3 are the
  cycles that introduce timing.
