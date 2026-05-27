# B2 milestone — `cp.async.shared.global` sm_80+ 비동기 복사 디자인

## 목표

H→D (host→device) 가 아닌 **G→S (global→shared)** 비동기 복사. GEMM 등에서 다음 tile 데이터를 미리 fetch 해 compute / memory overlap → 2× perf.

## PTX shape

```
cp.async.ca.shared.global [%shared_addr], [%global_addr], 16;
cp.async.commit_group;
cp.async.wait_group 0;        // 대기
// 또는 mbarrier.arrive/wait 로 fine-grained 동기화
```

## hexa-lang API 디자인

```hexa
@gpu_kernel
fn gemm_async(a: [f64], b: [f64], c: [f64], m: i64, n: i64, k: i64) {
    @shared let sm_a: [f64; 256] = []
    @shared let sm_b: [f64; 256] = []
    let mut tid: i64 = to_i64(gpu_thread_id_x())
    let mut tile: i64 = 0
    while tile < k_tiles {
        // 다음 tile 비동기 fetch — 컴퓨트와 overlap
        gpu_cp_async_shared_global(sm_a, tid, a, tile * 16 + tid)
        gpu_cp_async_shared_global(sm_b, tid, b, tile * 16 + tid)
        gpu_cp_async_commit()                  // commit-group
        gpu_cp_async_wait(0)                   // wait
        gpu_barrier()
        // 현재 tile 컴퓨트
        // ...
        tile = tile + 1
    }
}
```

## 구현 단계

1. `gpu_cp_async_shared_global(dst, dst_idx, src, src_idx)` STMT_CALL recognizer
2. Emit: 2-step addr compute (shared addr + global addr) + `cp.async.ca.shared.global [s], [g], 16`
3. `gpu_cp_async_commit()` — single instr `cp.async.commit_group`
4. `gpu_cp_async_wait(n)` — `cp.async.wait_group <n>`
5. sm_80+ gate — emit `// honest stub` for sm_70 / older

## 다음 사이클

3-instr emit + tile-overlap GEMM fire kernel — sm_80 vs sm_70 byte-eq baseline 비교 → 2× speedup 측정.
