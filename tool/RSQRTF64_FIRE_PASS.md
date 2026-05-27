# F-RSQRTF64-NUMERIC — 🟢 PASS (max_rel_err = 0 EXACT)

Closes PR #1335 (RFC 055 §13 f64 rsqrt = sqrt.rn.f64 + rcp.rn.f64) silicon validation.

## Verdict — 🟢 SUPPORTED-NUMERICAL (BYTE-EXACT)

GPU output == CPU libm `1.0/sqrt(x)` for ALL N=256 inputs. max_abs_err = 0, max_rel_err = 0.

이건 사실 예상된 결과 — PTX `sqrt.rn.f64`와 `rcp.rn.f64` 모두 IEEE round-to-nearest. CPU libm의 `1.0/sqrt(x)`도 동일 2-step (sqrt + reciprocal) with same rounding. 그래서 byte-exact match.

## Verbatim ubu-2 (RTX 5070 driver-JIT sm_120 forward-compat sm_80)

```
$ ptxas tool/rsqrt_f64_probe.hexa.ptx -arch=sm_80 -o /tmp/rsqrt.cubin
PTXAS=0

$ /tmp/rsqrt_f64_host tool/rsqrt_f64_probe.hexa.ptx
max_abs_err = 0
max_rel_err = 0
PASS max_rel_err=0.000e+00 < 1e-14 (N=256, x in [0.1, 25.6])
HOST_RC=0
```

PTX excerpt (post-PR #1335):
```
sqrt.rn.f64 %fd11, %fd10;  // rsqrt f64: dst = sqrt(x)
rcp.rn.f64 %fd11, %fd11;   // rsqrt f64: dst = 1.0 / sqrt(x)
```

## 측정 dimensions

| 축 | 값 |
|---|---|
| N | 256 |
| Input range | [0.1, 25.6], step 0.1 |
| max_abs_err | **0** |
| max_rel_err | **0** (BYTE-EXACT) |
| Tolerance target | <1e-14 |

## Sweep impact

10 → **11** confirmed `@gpu_kernel` idioms.

| # | Idiom | Verdict |
|---|---|---|
| 1-7 | vec-add / saxpy / relu / 2D / serial-reduce / sqrt / iadd | ✅ (세션 1) |
| 8 | block tree-reduce + @shared | ✅ #1323 |
| 9 | f64 exp polynomial | ✅ #1336 (max_rel_err=2.6e-13) |
| 10 | **f64 rsqrt** | ✅ **THIS PR** (max_rel_err=0, byte-exact) |
| 11 | f64 sqrt (companion, already wired) | ✅ |

## RFC 055 §13 honest-stub family

| Stub | Status |
|---|---|
| f32 exp | ✅ Pre-PR (already had ex2.approx.f32) |
| f64 exp | ✅ PR #1333 (polynomial) |
| f64 rsqrt | ✅ PR #1335 (sqrt+rcp) |

**Honest stubs remaining**: 0 (family CLOSED).
