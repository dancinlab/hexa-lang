# RFC 075 P3+ — Metal unary family silicon-toolchain fire (2026-05-21)

Hand-emitted MSL counterparts of the codegen output for the three unary
shapes (vec-neg, vec-abs, vec-sqrt) successfully compiled through
Apple's `metal` compiler (MSL → AIR bytecode) and linked into a
metallib via `metallib` on macOS.

This is a **toolchain-acceptance** fire — Apple's MSL frontend accepts
the exact source-text fragments the codegen emits — not a runtime
silicon-execution fire (no Metal Performance Shaders dispatch, no
M-series GPU buffer round-trip yet; that remains follow-on USER-LOCAL
work as documented in `compiler/codegen/metal_target.hexa` §HONEST
SCOPE).

## Toolchain

```
xcrun -sdk macosx --find metal
# /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.5.188.0.TiBycL/Metal.xctoolchain/usr/bin/metal
xcrun -sdk macosx --find metallib
# /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.5.188.0.TiBycL/Metal.xctoolchain/usr/bin/metallib
```

## Reproduction

```
xcrun -sdk macosx metal -c vec_neg.metal -o vec_neg.air      # rc=0
xcrun -sdk macosx metal -c vec_abs.metal -o vec_abs.air      # rc=0
xcrun -sdk macosx metal -c vec_sqrt.metal -o vec_sqrt.air    # rc=0
xcrun -sdk macosx metallib vec_neg.air vec_abs.air vec_sqrt.air \
    -o unary_family.metallib                                 # rc=0
```

## Artifacts

- `vec_neg.metal` / `vec_abs.metal` / `vec_sqrt.metal` — hand-emitted
  MSL source, byte-identical to `codegen_emit_metal_msl` output for the
  vec-neg / vec-abs / vec-sqrt MIR fixtures in `compiler/codegen/
  metal_lower_test.hexa` Cases 9-11.
- `vec_neg.air` / `vec_abs.air` / `vec_sqrt.air` — Apple AIR
  intermediate produced by `metal -c`.
- `unary_family.metallib` — linked metallib containing all three
  kernels (10,824 bytes).

## What this falsifies

- F-RFC075-METAL-MSL-ACCEPT-UNARY: the emitted MSL source for the
  three unary kernels parses cleanly through Apple's `metal` frontend
  (it would refuse on any MSL syntax error or unknown builtin call).
  The MSL `abs(float)` and `sqrt(float)` builtins from `<metal_stdlib>`
  §5.10 are accepted by the production Apple toolchain.

## Not yet fired

- M-series GPU runtime execution + numeric byte-equality vs a CPU
  reference. Sqrt needs ULP tolerance (likely 1-ULP via MSL's
  IEEE-754 sqrt; not bit-equal to libm sqrt under FMA-contract).
- Metal Performance Shaders dispatch wrapper (Swift/ObjC harness).

These remain follow-on USER-LOCAL Mac cycles as documented in the
codegen target file.
