# C3 milestone — `gpu_grid_sync` cooperative groups 디자인

## 목표

`gpu_barrier()` 는 block-internal (warp/block 단위). cross-block synchronization 은 cooperative groups (sm_70+) 가 필요. multi-block reduction / large-scale fan-in 패턴.

## CUDA 원형

```cpp
#include <cooperative_groups.h>
namespace cg = cooperative_groups;
__global__ void k() {
    cg::grid_group grid = cg::this_grid();
    // ... write phase ...
    grid.sync();   // ALL blocks synced
    // ... read phase ...
}
```

## hexa-lang API

```hexa
@gpu_kernel
fn k(a: [f64], n: i64) {
    let mut tid: i64 = to_i64(gpu_global_thread_id_x())
    // write phase
    a[to_i64(tid)] = compute()
    gpu_grid_sync()                  // grid-wide barrier
    // read phase
    let v = a[to_i64((tid + 1) % n)]   // safe — all blocks done writing
}
```

## PTX shape (sm_70+)

```
// %0 = lane id; emit via runtime call to cuda_grid_sync helper
// OR use PTX bar.sync.aligned.0 with cooperative-launch flag
bar.sync.aligned 0;                  // grid-wide if launched with cudaLaunchCooperativeKernel
```

핵심 — kernel **launch type** 가 cooperative이어야 함. 일반 `cuLaunchKernel` 은 sync silent fail.

## 구현 단계

| Step | 작업 |
|---|---|
| 1 | `gpu_grid_sync()` STMT_CALL recognizer + emit `bar.sync.aligned 0` |
| 2 | Kernel meta — `@gpu_kernel @cooperative` annotation 으로 host harness 가 `cudaLaunchCooperativeKernel` 호출하도록 표식 |
| 3 | Host driver wrapper — `cudaLaunchCooperativeKernel` (cuLaunchCooperativeKernel) |
| 4 | sm_70+ gate (sm_60 미만은 honest stub) |

## 다음 cycle

위 4 step + multi-block reduction fire kernel. 측정: cooperative vs 일반 kernel 의 cross-block synchronization 정확성.
