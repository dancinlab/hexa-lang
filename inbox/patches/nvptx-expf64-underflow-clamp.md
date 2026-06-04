# nvptx f64 exp() — underflow garbage below x ≈ −745 (missing 2^k clamp)

**Surfaced by**: QFORGE M27 NVPTX α²F BZ-sum kernel (GPU parity on sm_120).

## Symptom (measured, RTX PRO 6000 Blackwell, driver 580.95, CUDA 12.4)

The #1215 f64 `exp()` polynomial intrinsic (range-reduction + degree-10 Taylor
+ `2^k` via `(k+1023)<<52` bit-pattern) is accurate to ~1e-15 rel down to
x ≈ −700, but returns GARBAGE below the f64 underflow boundary:

```
exp(-700.0)  ref=9.860e-305  gpu=9.860e-305   rel 0       OK
exp(-745.0)  ref=4.94e-324   gpu=-9.12e+292   rel inf     BROKEN
exp(-746.0)  ref=0.0         gpu=-3.36e+292               BROKEN
exp(-1012.0) ref=0.0         gpu=-1.01e+177               BROKEN
exp(-2000.0) ref=0.0         gpu=-8.33e-253               BROKEN
```

## Root cause

For x ≲ −745, `k = round(x·log2e)` is ≲ −1075, so `b = k + 1023` goes
**negative**. `shl.b64 b, 52` then shifts a negative value into the exponent
field, and `mov.b64 (bit-cast)` reinterprets the corrupted bits as a large
finite f64 (sign bit set → negative) instead of `+0.0`. There is no
denormal/underflow clamp on the `2^k` path. (The overflow side, x ≳ +710,
likely has the mirror problem → should return +inf.)

## Fix (codegen, `compiler/codegen/nvptx_target.hexa` exp f64 arm)

After computing `k`, clamp the result to the IEEE range before the bit-pattern
build, e.g.:
- if `k < -1074` → emit `+0.0` (true underflow, matches libm),
- if `k >  1024` → emit `+inf`,
otherwise the existing `(k+1023)<<52` path.

A branchless form: `setp.lt.s64` on `k` vs −1074 → `selp.f64` the poly·2^k
result against `0d0000000000000000`. One predicate + one select, no divergence.

## Workaround in place (kernel-side, correct regardless)

QFORGE's BZ-sum guards each Gaussian: `if (-0.5·z²) > -700 { exp() } else { 0 }`
— physically a δ-tail that far out is zero, so this is the right numerics for
the histogram and matches the CPU-ref libm. The codegen clamp above would let
callers drop the guard, but the guard is independently correct.

Parity after the guard: max_rel_err 2.455136e-14 (gate ≤ 1e-5), PASS.
