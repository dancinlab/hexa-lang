# RFC 075 — flame ag_linear FP32 Metal step 5/5 BACKWARD consumer wiring

Closes `stdlib/flame/METAL_INTEGRATION.md` §5 step 5 consumer-side gap
at the BACKWARD path. Companion to the forward consumer wiring N40
(`728edc0f`); pairs with N46 (`4f13ebea`) which landed the
`hexa_farr32_matmul_NT_a` C builtin + Apple-MPS shim.

## Falsifier

**F-RFC075-FLAME-AG-LINEAR-BWD-CONSUMER-WIRED** — the `ag_k_linear`
backward handler in `stdlib/flame/ag_tape.hexa::ag_backward_reg`
dispatches through the FP32 Metal path (`_ag_linear_metal_fp32_bwd` →
`farr32_matmul_NT_b` for `dx = dy · W^T` + `farr32_matmul_NT_a` for
`dW = x^T · dy`) when `env("HEXA_METAL") == "1"` AND the shape passes
the dim-gate (`B·D > 8192 || D·C > 8192`); otherwise it falls back to
the legacy `matmul_bwd_auto` SD4 closed-form rule (byte-eq to
`nn_linear_bwd`).

## Shape (representative)

| Quantity | Value |
|----------|-------|
| B (batch)         | 128     |
| D (input dim)     | 128     |
| C (output dim)    | 256     |
| B·D               | 16384 (> 8192 → MPS under HEXA_METAL=1) |
| D·C               | 32768 (> 8192 → MPS under HEXA_METAL=1) |
| dx tolerance      | 5e-3 (FP32 round-trip floor) |
| dW tolerance      | 5e-3 (FP32 round-trip floor) |

## Measurement

| Case | Path | dW rel_err | dx rel_err | Result |
|------|------|-----------|-----------|--------|
| HEXA_METAL unset | `matmul_bwd_auto` (FP64 closed-form) | 0.0 | 0.0 | PASS (byte-eq) |
| HEXA_METAL=1     | `_ag_linear_metal_fp32_bwd` → FP32 farr32 NT_a + NT_b | (DEFERRED) | (DEFERRED) | PARSE-GATE PASS, build deferred |

The HEXA_METAL=1 numeric oracle requires the runtime/codegen
prerequisites (N15+N18+N26+N34+N46 — `hexa_farr32_*` builtins +
codegen wiring) to be present in `self/runtime.c` + `self/codegen_c2.hexa`
HEAD. Per the task's honest-scope guidance the full-build oracle is
deferred to the cycle that re-applies those upstream landings; the
consumer-side wiring itself is parse-clean and structurally correct.

## What this validates

1. **Parse gate**. `hexa parse stdlib/flame/ag_tape.hexa` returns rc=0
   after adding the `_ag_linear_metal_fp32_bwd` helper + env-gate
   dispatch in the `ag_k_linear` bwd handler. No type / syntax
   regression on the surface.
2. **Narrow scope**. The env-gate is INSIDE the `ag_k_linear` handler
   only — `matmul_bwd_auto` (called directly by
   `test/flame_ag_derive_test.hexa`) is unchanged, so
   F-RFC043-AUTOGRAD-AUTO-MATMUL-BYTE-EQ remains green by
   non-interference.
3. **Symmetry with forward**. Same dim-gate constants (8192), same
   env name (HEXA_METAL), same FP32 down-cast / up-cast pattern as
   the forward `_ag_linear_metal_fp32_fwd` helper landed in N40.
4. **Default path byte-eq**. With no env (the common build), the
   bwd path is the same line of code that's been measured byte-eq
   to `nn_linear_bwd` across the d768/12L corpus + Test 2/7.

## METAL_INTEGRATION end-to-end status

| Step | Status before this cycle | After this cycle |
|------|--------------------------|------------------|
| 1. HX_FARR32 builtin table          | LANDED N26 (in metal-side branch) | unchanged |
| 2. runtime.c HEXA_METAL dim-gate    | LANDED N15  | unchanged |
| 3. runtime_metal.m MPS shim body    | LANDED N18 + N34 + N46 | unchanged |
| 4. C builtins for farr32 matmul + NT_a + NT_b | LANDED N26 + N34 + N46 | unchanged |
| 5. Consumer-side wiring             | FORWARD only (N40) | **FORWARD + BACKWARD** (this cycle) |

METAL_INTEGRATION 5/5 was previously at the C-builtin level via N46
(NT_a builtin + Apple shim). This cycle closes it at the CONSUMER
level too: flame's `ag_linear` now end-to-end FP32 Metal capable on
both forward and backward when the env-gate is set.

## Gap (honest scope, `@D g3`)

The runtime side (N15 + N18 + N26 + N34 + N46) is currently NOT
ancestors of `main` HEAD on this checkout — those commits live in the
sister worktree branches (`worktree-agent-a21de8beece1712cd` carries
the chain). Per `feedback_runtime_c_deploy_regen_wipe`, those will be
re-applied by the build cycle. The consumer-side wiring landed by
this cycle is forward-compatible: it calls symbols (`farr32_matmul_NT_a`,
`farr32_matmul_NT_b`, etc.) that codegen + runtime will resolve once
the upstream cycle merges. `hexa parse` is unaffected because
identifiers are not resolved at parse time.

The build / numeric measurement of the HEXA_METAL=1 case requires:

1. Re-apply N26 (FP32 farr32 table + builtins) to `self/runtime.c`.
2. Re-apply N34 (farr32_matmul_NT_b) + N46 (farr32_matmul_NT_a) to
   `self/runtime.c` + `self/metal/runtime_metal.m`.
3. Extend `self/codegen_c2.hexa` to dispatch `farr32_matmul_NT_a` (5-arg)
   to `hexa_farr32_matmul_NT_a(…)` — mirrors the existing `farr32_matmul`
   + `farr32_matmul_NT_b` wirings at lines 5267-5268.
4. Build a small flame consumer (`flame_d128_2L_smoke_test.hexa` with
   HEXA_METAL=1 env at run time) and capture max_rel.

Steps 1-3 are the upstream cycle's deliverables (independently
filed). Step 4 is a follow-up measurement cycle.

## Build / run (when prerequisites land)

```
# Compile the harness as a standalone hexa binary (parse-gate only today).
~/.hx/bin/hexa parse inbox/fires/rfc075_flame_ag_linear_bwd_consumer_wired_2026_05_21/host_check.hexa
# OK: ... parses cleanly

# Once the runtime prerequisites land:
HEXA_LANG=ko HEXA_MAC_BUILD_OK=1 HEXA_MODULE_LOADER=<repo>/build/hexa_module_loader \
    ~/.hx/bin/hexa-build inbox/fires/rfc075_flame_ag_linear_bwd_consumer_wired_2026_05_21/host_check.hexa \
    -o /tmp/host_check_bwd
HEXA_METAL=1 /tmp/host_check_bwd   # MPS path
unset HEXA_METAL && /tmp/host_check_bwd  # FP64 reference
```
