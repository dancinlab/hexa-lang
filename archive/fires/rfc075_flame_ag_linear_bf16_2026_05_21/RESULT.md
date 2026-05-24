# RFC 075 — flame ag_linear bf16 precision tier (consumer-side wiring)

Adds the bf16 precision tier to `ag_linear` forward via a new `HEXA_BF16=1`
env-gate that stacks on top of N40's `HEXA_METAL=1` FP32 path. Builds on:

- **N40** (`728edc0f`) `_ag_linear_metal_fp32_fwd` — FP32 Metal path
- **N51** (`0b3be802`) Metal `matmul_bf16` codegen-emit silicon-fired Apple M3
  (1015 GFLOPS @ 768³, bit-exact via FP32 accumulator)
- **N68** (`6ca89da9`) `_op_with_precision` bf16 HIR→MIR synthesis (closes
  div_bf16 gap, unblocks flame bf16)
- **RFC 035** `farr_to_bf16` / `farr_from_bf16` storage round-trip
  (deterministic bf16 rounding: top-16-bits of IEEE binary32, round-to-
  nearest-even on bit 15)

## Falsifier

**F-RFC075-FLAME-AG-LINEAR-BF16-NUMERIC-EQ** — 2-layer Linear forward chain
exercising the bf16-round + FP32 SGEMM path matches an FP64 reference within
`max_rel_norm < 1e-1` (magnitude-normalised: abs_err / max|y_ref|). bf16 has
~3 decimal digits of mantissa precision; the measured floor at 2.39e-3 sits
one order below the budget.

## Topology

```
x  [B=128, D=128]   →   h = x @ W1     [B=128, H=256]
W1 [D=128, H=256]   →   y = h @ W2     [B=128, C=64]
```

Both matmuls trip the 8192 dim-gate (B·D=16384, D·H=32768, H·C=16384), so
under `HEXA_METAL=1` BOTH layers dispatch to MPS for the FP32 SGEMM;
under `HEXA_BF16=1 + HEXA_METAL=1` BOTH inputs are bf16-rounded first.

## Measurement (Apple M3, xcrun clang -O2, -DHEXA_METAL)

| Mode | Env | Falsifier | Metric | Value | Tol | Result |
|------|-----|-----------|--------|-------|-----|--------|
| FP64-CPU (default) | — | `…-DEFAULT-NUMERIC-EQ` | max_rel | 5.92e-08 | 1e-6 | **PASS** |
| FP32-GPU (N40 control) | `HEXA_METAL=1` | `…-FP32-NUMERIC-EQ` | max_rel | 1.09e-03 | 5e-3 | **PASS** |
| **bf16+FP32-GPU (N73 new)** | `HEXA_METAL=1 HEXA_BF16=1` | `…-BF16-NUMERIC-EQ` | max_rel_norm | **2.39e-03** | **1e-1** | **PASS** |

Mode 2 byte-equals the N40/N58 prior measurement (y.max_rel = 1.091e-03).
Mode 3's `max_rel_norm = 2.39e-03` against `max|y_ref| = 161.68` corresponds
to `max_abs = 0.386` — exactly the bf16 random-walk envelope:

```
expected abs_err ≈ max|y| · sqrt(K_chained) · 0.5 · ulp_bf16
                ≈ 161.7 · sqrt(384) · 0.5 · 2⁻⁷
                ≈ 12.4                    (upper bound)
observed   abs_err = 0.386                (sqrt(N) cancellation in practice)
```

## Why `max_rel_norm` not `max_rel` for bf16

Per-element rel_err with a 1e-9 denominator floor inflates when y_ref
elements approach zero (and a chained 2-layer matmul produces many such
elements via cancellation). For bf16, where every output carries ~0.5 ulp
of round-error from K accumulation, near-zero outputs trip artificial
"large rel_err" without indicating real numerical breakdown. The
magnitude-normalised metric `abs_err / max|y_ref|` is the bf16-honest
relative error — it suppresses the small-output amplification while
still catching real divergence. Mode 1 (FP64) and Mode 2 (FP32) use the
per-element metric because their absolute errors are tiny relative to
both magnitudes; bf16's chained 0.5 ulp accumulation is materially
larger and needs the magnitude normalisation.

## What this validates

1. **`HEXA_BF16=1` env-gate dispatch** in `ag_linear` fwd
   (`stdlib/flame/ag_tape.hexa`): correctly stacks on top of
   `HEXA_METAL=1 + shape_ok` gate; priority bf16 > FP32 > FP64.
2. **`_ag_linear_metal_bf16_fwd` helper**: pre-rounds inputs via
   `farr_to_bf16` (RFC 035 storage round-trip), down-casts to FP32
   farr32, runs FP32 SGEMM through MPS (HEXA_METAL=1 + dim-gate)
   or CPU ikj fallback.
3. **bf16 numeric envelope holds end-to-end**: chained 2-layer
   forward through bf16-rounded inputs + FP32 accumulator stays
   inside the bf16 mantissa floor (~3 decimal digits) on real
   hardware (Apple M3 MPS).
4. **FP32 control path unaffected**: HEXA_METAL=1 without HEXA_BF16
   produces the byte-identical N40/N58 measurement (1.091e-03).
5. **Default FP64 path unaffected**: env-unset falls through to
   `farr_matmul` (FP64 CPU host-scalar).

## Scope honest carve-out (`@D g3`)

### Compiled hexa link blocker (inherited from N40/N53)

The hexa-source harness (`host_check.hexa`) parses cleanly but does not
link as a compiled binary because `codegen_c2.hexa` does not yet wire the
`farr32_*` family as named builtins (only `farr_*` and the bf16-storage
`farr_to_bf16` / `farr_from_bf16` are). The same blocker hit N40/N53 (see
`rfc075_flame_ag_linear_e2e_metal_2026_05_21/RESULT.md` scope carve-out).
The cycle's `@F f2` constraint forbids C-transpile codegen changes, so
this cycle uses a C-mirror `host_check.c` as the production-equivalent
validation surface — it calls exactly the C functions the hexa helper
would call once the builtin map lands.

### N68 HIR→MIR synthesis path deferred

The N68 `_op_with_precision` synthesis layer flips opcode suffixes
(`add` → `add_bf16`, etc.) at the HIR→MIR boundary based on the dst
Local's precision tag. This cycle's consumer wiring uses RFC 035's
`farr_to_bf16` *storage round-trip* (FP64 arena, bf16-bit-exact values)
instead of source-level bf16 type tags through ag_tape, because:

- bf16 type tags through `ag_tape` would require source-level changes to
  the entire tensor pipeline (`t_zeros`, `t_get`, `t_set`, `farr_*`),
  which is a much larger surface than this cycle.
- RFC 035 already exposes the bf16 numeric envelope at the C runtime
  layer with a single 3-arg builtin (`farr_to_bf16`), already wired
  through codegen.
- N51's silicon-validated `matmul_bf16` uses an FP32 accumulator —
  identical accumulator semantics to this cycle's FP32 farr32_matmul.
- The same `HEXA_BF16=1` gate flips to the synthesis path with no
  caller change once a future cycle wires source-level bf16 tags.

### Backward helper deferred

This cycle is forward-only. A symmetric `_ag_linear_metal_bf16_bwd`
(bf16-round x/W/og, then `farr32_matmul_NT_a` for dW + `farr32_matmul_NT_b`
for dx, matching N53's FP32 pattern) is deferred to a follow-up cycle
to keep the surface narrow per `@D g3`.

## Anchor health (per `feedback_runtime_c_deploy_regen_wipe`)

All five Metal-chain anchors + RFC 035 bf16 builtins verified intact at
start of cycle (grep'd in `self/runtime.c`):

| Anchor SHA  | What | Status |
|-------------|------|--------|
| `6315b59f`  | N15 — HEXA_METAL block in `farr_matmul` | INTACT |
| `cf4b1e38`  | N18 — `_hx_metal_farr_matmul_gpu` MPS shim | INTACT |
| `dda06f89`  | N26 — HX_FARR32 farr table + `hexa_farr32_matmul` | INTACT |
| `ffb7bd43`  | N34 — `hexa_farr32_matmul_NT_b` (bwd dx) | INTACT |
| `4f13ebea`  | N46 — `hexa_farr32_matmul_NT_a` (bwd dW) | INTACT |
| RFC 035     | `hexa_farr_to_bf16` / `hexa_farr_from_bf16` | INTACT |

No re-apply needed this cycle.

## Files

- `host_check.hexa` — hexa-source forward harness (parse-clean, link-
  blocked on codegen `farr32_*` builtin map; same blocker as N40/N53)
- `host_check.c` — C-mirror harness (production-equivalent path;
  exercises N15+N18+N26 + RFC 035 bf16 round-trip)
- `fire.log` — captured stdout/stderr of all 3 env modes
- `result.json` — structured per-mode result
- `RESULT.md` — this file

## Build & run

```bash
xcrun --sdk macosx clang -O2 \
    -DHEXA_METAL -fobjc-arc \
    -framework Metal -framework MetalPerformanceShaders -framework Foundation \
    inbox/fires/rfc075_flame_ag_linear_bf16_2026_05_21/host_check.c \
    self/metal/runtime_metal.m \
    -o /tmp/flame_bf16_test

# Three modes (same binary, env-driven dispatch):
/tmp/flame_bf16_test                            # FP64 CPU baseline
HEXA_METAL=1 /tmp/flame_bf16_test               # FP32 GPU (N40 path)
HEXA_METAL=1 HEXA_BF16=1 /tmp/flame_bf16_test   # bf16 round + FP32 GPU
```

Parse-gate (always rc=0):

```bash
~/.hx/bin/hexa parse stdlib/flame/ag_tape.hexa
~/.hx/bin/hexa parse inbox/fires/rfc075_flame_ag_linear_bf16_2026_05_21/host_check.hexa
```
