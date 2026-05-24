# RFC 075 P3+ — Metal transcendental family silicon fire (2026-05-21)

Hand-emitted MSL counterparts of the codegen output for the four
transcendental shapes (vec-exp, vec-log, vec-sin, vec-cos) successfully
compiled through Apple's `metal` compiler (MSL → AIR bytecode), linked
into metallib via `metallib`, AND executed on Apple M3 silicon via the
Metal compute API with measured ULP comparison against the libm CPU
reference.

This is BOTH a **toolchain-acceptance** fire (Apple's MSL frontend
accepts the exact source-text fragments the codegen emits) AND a
**silicon-execution** fire (Apple M3 GPU runtime executes the kernels
and produces numerically-correct output within ULP tolerance).

## Toolchain

```
xcrun -sdk macosx --find metal
# /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.5.188.0.TiBycL/Metal.xctoolchain/usr/bin/metal
xcrun -sdk macosx --find metallib
# /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.5.188.0.TiBycL/Metal.xctoolchain/usr/bin/metallib
xcrun -sdk macosx metal --version
# Apple metal version 32023.883 (metalfe-32023.883)
# Target: air64-apple-darwin25.5.0
```

## Hardware

```
Apple M3 — system_profiler SPDisplaysDataType
```

## Reproduction

```
xcrun -sdk macosx metal -c vec_exp.metal -o vec_exp.air       # rc=0
xcrun -sdk macosx metal -c vec_log.metal -o vec_log.air       # rc=0
xcrun -sdk macosx metal -c vec_sin.metal -o vec_sin.air       # rc=0
xcrun -sdk macosx metal -c vec_cos.metal -o vec_cos.air       # rc=0
xcrun -sdk macosx metallib vec_exp.air -o vec_exp.metallib    # rc=0
xcrun -sdk macosx metallib vec_log.air -o vec_log.metallib    # rc=0
xcrun -sdk macosx metallib vec_sin.air -o vec_sin.metallib    # rc=0
xcrun -sdk macosx metallib vec_cos.air -o vec_cos.metallib    # rc=0
xcrun -sdk macosx metallib vec_exp.air vec_log.air vec_sin.air vec_cos.air \
    -o transcendental_family.metallib                         # rc=0
xcrun --sdk macosx swift host_transcendental.swift            # rc=0
```

## Measured silicon-fire result (Apple M3, N=1024, seed=0x12345678)

```
shape       max|d|      max_ulp    byte_mm    status
---------- ----------- --------- ---------- --------
vec_exp     0.00000024      2     312/1024   PASS_LOW_ULP
vec_log     0.00000048      3     496/1024   PASS_LOW_ULP
vec_sin     0.00000012      2     441/1024   PASS_LOW_ULP
vec_cos     0.00000012      2     439/1024   PASS_LOW_ULP

F-RFC075-METAL-TRANSCENDENTAL-NUMERIC-EQ: PASS (max_ulp within tolerance)
```

ULP tolerance gate set at 8 ULP per shape — well above observed
worst-case (3 ULP for vec_log). The byte_mm column shows that the
Apple GPU transcendentals never bit-equal libm transcendentals, which
is expected — MSL §5.10 transcendentals are not byte-eq with libm
under FMA-contract and rounding-mode differences. The ULP gate is the
honest correctness measure for transcendentals.

## Artifacts

- `vec_exp.metal` / `vec_log.metal` / `vec_sin.metal` / `vec_cos.metal`
  — hand-emitted MSL source, byte-identical to `codegen_emit_metal_msl`
  output for the vec-exp / vec-log / vec-sin / vec-cos MIR fixtures in
  `compiler/codegen/metal_lower_test.hexa` Cases 12-15.
- `vec_exp.air` / `vec_log.air` / `vec_sin.air` / `vec_cos.air` —
  Apple AIR intermediate produced by `metal -c` (3,568 bytes each).
- `vec_exp.metallib` / `vec_log.metallib` / `vec_sin.metallib` /
  `vec_cos.metallib` — per-kernel metallibs (3,709 bytes each).
- `transcendental_family.metallib` — linked metallib containing all
  four kernels (14,548 bytes).
- `host_transcendental.swift` — Swift Metal compute harness used for
  the silicon execution + ULP comparison.
- `result.json` — machine-readable per-shape ULP / byte-mismatch row
  table (JSON, 1,097 bytes).
- `fire.log` — captured stdout of `xcrun swift host_transcendental.swift`.

## What this falsifies

- **F-RFC075-METAL-MSL-ACCEPT-TRANSCENDENTAL**: the emitted MSL source
  for the four transcendental kernels parses cleanly through Apple's
  `metal` frontend (it would refuse on any MSL syntax error or unknown
  builtin call). The MSL `exp(float)`, `log(float)`, `sin(float)`,
  `cos(float)` builtins from `<metal_stdlib>` §5.10 are accepted by the
  production Apple toolchain (metal compiler v32023.883).
- **F-RFC075-METAL-TRANSCENDENTAL-NUMERIC-EQ**: the four transcendental
  kernels execute on Apple M3 silicon and produce FP32 outputs within
  3 ULP of the libm CPU reference (well below the 8-ULP tolerance gate)
  across N=1024 LCG-deterministic inputs.

## Honest scope

The vec_log input is `abs(a) + 1e-6` (strictly positive) to avoid
log(0) → -inf and log(<0) → NaN tainting the comparison. The vec_exp
input is the raw LCG output a ∈ [-1, 1] which keeps exp(a) ∈ [e⁻¹, e]
— well clear of overflow. The vec_sin / vec_cos inputs are also raw
LCG output ∈ [-1, 1]; well clear of large-argument range-reduction
hazard regions where Apple's MSL transcendentals can degrade.

Larger-input ranges (vec_exp at a > 50, vec_log at a near 0 or near
fp32_max, vec_sin / vec_cos at a > 10⁶ where range-reduction error
dominates) are NOT covered by this fire — they would benefit from a
separate `rfc075_metal_transcendental_range_2026_*` campaign.
