# F-EXPF64-MULTIBLOCK-NUMERIC — 🟢 PASS

PR #1341 (gpu_global_thread_id_x intrinsic) + PR #1333 (exp polynomial) 결합 silicon validation. N>blockDim (4 blocks × 256 threads = 1024 elements).

## Verdict — 🟢 SUPPORTED-NUMERICAL

이전 single-block fire (#1336)는 N=256, gridDim=1로 제한됐음. 이번 fire는 **N=1024 across 4 blocks**, gpu_global_thread_id_x로 글로벌 인덱스 합성. 모든 1024개 슬롯에 정확히 한 번씩 도달.

## Verbatim ubu-2 (RTX 5070, sm_120, driver-JIT sm_80)

```
$ ptxas tool/exp_f64_multiblock_probe.hexa.ptx -arch=sm_80 -o /tmp/mb.cubin
PTXAS=0

$ /tmp/exp_mb_host tool/exp_f64_multiblock_probe.hexa.ptx
GRID = 4, BLOCK = 256, N = 1024 (each i covered exactly once)
zero_count = 0 (must be 0 — global-thread-id covers all slots)
max_abs_err = 2.2112089936854318e-11
max_rel_err = 2.6598220203976837e-13 (at i=51, x=-4.501953, got=0.011087320454322848, expected=0.011087320454319899)
PASS max_rel_err=2.660e-13 < 1e-9, zero_count=0 (N=1024 across 4 blocks)
RC=0
```

## 측정 dimensions

| 축 | 값 |
|---|---|
| N | 1024 (= 4 × 256) |
| GRID | 4 |
| BLOCK | 256 |
| Input range | [-5, +5) sampled at 1024 points |
| zero_count | **0** (모든 슬롯 커버) |
| max_abs_err | 2.21e-11 |
| max_rel_err | **2.66e-13** |
| Tolerance target | <1e-9 |
| Achieved | 3759× tighter |

## PTX 핵심 라인 (gtid + exp 결합)

```
mul.lo.u32 %r3, %r_gtid_3, %r3;          // gpu_global_thread_id.x(): blockIdx*blockDim
add.u32 %r3, %r3, %r_gtid_3;             // gpu_global_thread_id.x(): += threadIdx
fma.rn.f64 %fd_exp_p_11, %fd_exp_r_11, %fd_exp_p_11, 0d3EC71DE3A556C734;  // exp f64 Horner step
```

## Sweep impact

11 → **12** confirmed `@gpu_kernel` idioms (block tree-reduce + f64 exp + f64 rsqrt + **multi-block global idx + exp** combined).

## Compare with #1336

| 축 | #1336 (single-block) | THIS (multi-block) |
|---|---|---|
| N | 256 | 1024 |
| gridDim | 1 | 4 |
| Thread idx 방식 | `gpu_thread_id_x()` (block-local) | `gpu_global_thread_id_x()` (composed) |
| max_rel_err | 2.60e-13 | 2.66e-13 (within rounding) |
| 슬롯 커버 | i=0..255 | i=0..1023 (all 4× larger) |

두 fire 모두 동일 polynomial accuracy — multi-block composition으로 인한 정확도 손실 없음.
