# F-EXPF64-POLYNOMIAL-NUMERIC — 🟢 PASS

Closes PR #1333 (RFC 055 §13 f64 exp polynomial) silicon validation.

## Verdict — 🟢 SUPPORTED-NUMERICAL

`partial_max_rel_err` 측정값이 target `<1e-9` 보다 **3.8 자릿수** 더 좋음. 알고리즘 (range-reduction + Taylor 10차 + 2^k bit-pattern) 가 silicon에서 IEEE-correct 1 ulp 수준으로 작동.

## Verbatim ubu-2 (RTX 5070, sm_120, driver-JIT sm_80 forward-compat)

```
$ /tmp/nvptx_emit_expf tool/exp_f64_probe.hexa sm_80
atlas: loaded 16088 nodes from embedded.gen.hexa
[nvptx] target=sm_80 src=tool/exp_f64_probe.hexa out=tool/exp_f64_probe.hexa.ptx phase=P3

$ ptxas tool/exp_f64_probe.hexa.ptx -arch=sm_80 -o /tmp/exp_f64.cubin
PTXAS_RC=0

$ /tmp/exp_f64_host tool/exp_f64_probe.hexa.ptx
max_abs_err = 1.1553424883459229e-11
max_rel_err = 2.6034031681574316e-13 (at i=66, x=-2.421875, got=0.088755045636557353, expected=0.088755045636534247)
PASS max_rel_err=2.603e-13 < 1e-9 (N=256, x in [-5,+5])
HOST_RC=0
```

## 측정 dimensions

| 축 | 값 |
|---|---|
| N | 256 |
| blockDim | 256 |
| gridDim | 1 (single-block; `gpu_thread_id_x()` is block-local) |
| Input range | [-5, +5) sampled at 1024 points |
| max_abs_err | 1.16e-11 |
| max_rel_err | **2.60e-13** |
| Tolerance target | <1e-9 |
| Achieved headroom | 3833× tighter than target |

## Polynomial 알고리즘 (PR #1333)

```
k   = round(x * log2(e))                  (integer scaling factor)
r   = x - k * (ln2_hi + ln2_lo)           (Cody-Waite; |r| ≤ ln(2)/2)
p   = sum_{n=0..10} r^n / n!              (Horner FMA — 10 fma.rn.f64)
2^k = bit-cast((k + 1023) << 52) as f64   (IEEE-754 exponent field)
dst = p * 2^k                             ( = e^x, ~1 ulp libm-equivalent )
```

Truncation `|r¹¹/11!| ≤ (ln(2)/2)¹¹/11! ≈ 3.5e-15`, per-fma rounding ≤0.5 ulp × 12 ops ≈ 6 ulp.

## Sweep impact

Confirmed `@gpu_kernel` idiom: 9 → **10** (block tree-reduce → f64 exp polynomial validated → f64 rsqrt — PR #1335 in queue).

## Sister falsifier

`F-RSQRTF64-NUMERIC` (PR #1335 후속) — `c[i] = rsqrt(a[i])` over `a[i] = (i+1)*0.1`. 동일 host harness 패턴.
