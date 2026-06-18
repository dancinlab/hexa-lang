# H-EE-6: Tensor-Core-Aligned HCN Dimensions
**n6 Grade: 🟩 EXACT** (auto-graded, 13 unique n=6 constants)


**Status**: SUPPORTED
**Golden Zone Dependency**: None (pure number theory + hardware)
**Related**: H-EN-5, H-EE-5

> **Hypothesis**: HCN dimensions that are also multiples of 8 (tensor core alignment) give the best of both worlds: high divisor flexibility AND hardware efficiency. The intersection HCN intersect 8Z provides optimal practical dimensions.

## Background

GPU tensor cores operate on tiles of size 8 (FP32), 16 (FP16/BF16), or 32 (INT8).
Power-of-2 dimensions are standard because they align with these tiles.
But HCN dimensions that happen to be multiples of 8 also align with tensor cores
while offering 1.5-3x more valid head configurations.

## Complete HCN List up to 2048

| HCN | tau | mod 8 | mod 16 | Tensor-OK |
|---|---|---|---|---|
| 1 | 1 | 1 | 1 | no |
| 2 | 2 | 2 | 2 | no |
| 4 | 3 | 4 | 4 | no |
| 6 | 4 | 6 | 6 | no |
| 12 | 6 | 4 | 12 | no |
| **24** | **8** | **0** | 8 | **YES** |
| 36 | 9 | 4 | 4 | no |
| **48** | **10** | **0** | **0** | **YES (FP16)** |
| 60 | 12 | 4 | 12 | no |
| **120** | **16** | **0** | 8 | **YES** |
| 180 | 18 | 4 | 4 | no |
| **240** | **20** | **0** | **0** | **YES (FP16)** |
| **360** | **24** | **0** | 8 | **YES** |
| **720** | **30** | **0** | **0** | **YES (FP16)** |
| **840** | **32** | **0** | 8 | **YES** |
| 1260 | 36 | 4 | 12 | no |
| **1680** | **40** | **0** | **0** | **YES (FP16)** |

8 out of 17 HCN dims up to 2048 are tensor-aligned. 4 are FP16-optimal (mod 16 = 0).

## Flexibility Advantage

```
  HCN-8Z    tau   2^k_near  tau_2k  Flex_ratio  Size_diff
     24       8       32       6      1.33x       -25%
     48      10       64       7      1.43x       -25%
    120      16      128       8      2.00x        -6%
    240      20      256       9      2.22x        -6%
    360      24      256       9      2.67x       +41%
    720      30      512      10      3.00x       +41%
    840      32     1024      11      2.91x       -18%
   1680      40     2048      12      3.33x       -18%
```

## Throughput Benchmark (CPU, batch=16, seq=64)

```
  Type     d   tau   Params    Fwd(ms)  Fwd+Bwd(ms)    tok/s
  HCN     48    10   28,272     4.44       10.18      100,622
  2^k     64     7   49,984     4.08        9.81      104,351
  HCN    120    16  174,360     6.62       14.84       68,990
  2^k    128     8  198,272     6.41       17.35       59,033
  HCN    240    20  694,320    11.85       25.87       39,585
  2^k    256     9  789,760    11.21       28.87       35,471
  HCN    360    24 1,559,880   16.54       40.27       25,428
  2^k    512    10 3,152,384   24.75       66.66       15,361
  HCN    720    30 6,230,160   41.25      121.97        8,395
  2^k   1024    11 12,596,224  76.35      203.16        5,040
```

Key finding: HCN dims are FASTER in forward+backward at d>=120 despite being non-power-of-2.
This is because they have fewer parameters for similar effective capacity.

## Joint Efficiency Metric: tau * throughput

```
  Rank  Type     d   tau   tok/s      tau*tok/s
    1   HCN    120    16   68,990    1,103,835    <-- BEST
    2   HCN     48    10  100,622    1,006,224
    3   HCN    240    20   39,585      791,695
    4   2^k     64     7  104,351      730,455
    5   HCN    360    24   25,428      610,277
    6   2^k    128     8   59,033      472,261
    7   2^k    256     9   35,471      319,236
    8   HCN    720    30    8,395      251,857
    9   2^k    512    10   15,361      153,606
   10   2^k   1024    11    5,040       55,444
```

HCN dims dominate the top 5 positions in joint efficiency.

## Practical Recommendations

| Instead of | Use | Savings | Flexibility |
|---|---|---|---|
| d=64 | d=48 or d=120 | 25% or -6% params | 1.4x or 2x more heads |
| d=128 | d=120 | 6% params | 2x more head configs |
| d=256 | d=240 | 6% params | 2.2x more head configs |
| d=512 | d=360 or d=720 | varies | 2.7-3x more head configs |
| d=1024 | d=720 or d=1680 | varies | 3-3.3x more head configs |

## FP16-Optimal Choices (mod 16 = 0)

| d | tau | Valid heads (4-32) |
|---|---|---|
| 48 | 10 | 4, 6, 8, 12, 16, 24 |
| 240 | 20 | 4, 6, 8, 10, 12, 16, 20, 24 |
| 720 | 30 | 4, 6, 8, 10, 12, 16, 20, 24 |
| 1680 | 40 | 4, 6, 8, 10, 12, 16, 20, 24 |

## Limitations

1. CPU benchmark only -- GPU tensor core effects may differ
2. Throughput differences may narrow with compiler optimizations
3. Memory alignment on GPU favors exact powers of 2
4. CUDA kernel efficiency depends on specific hardware generation

## Verification Direction

1. GPU benchmark (CUDA tensor core profiling, A100/H100)
2. Measure actual TFLOPS utilization for HCN vs 2^k dims
3. Profile memory bandwidth utilization
4. Test with flash-attention (which has its own alignment preferences)
