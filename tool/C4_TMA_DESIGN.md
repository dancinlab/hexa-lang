# C4 milestone — TMA (Tensor Memory Accelerator) sm_90+ 디자인

## 목표

Hopper (sm_90+) Tensor Memory Accelerator — 2D/3D tile copy 를 single instruction 으로 (cp.async보다 빠름, 더 큰 tile). cuDNN/FlashAttention 등이 사용.

## PTX shape (sm_90+ only)

```
cp.async.bulk.tensor.2d.shared::cluster.global
    [%shared_addr], [%tensor_desc], {%coord_x, %coord_y};
cp.async.bulk.commit_group;
cp.async.bulk.wait_group 0;
```

## hexa-lang API (먼 미래)

```hexa
@gpu_kernel
@tensor_desc(desc: TensorDesc)   // host-side setup
fn k(input: TensorRef, output: TensorRef) {
    @shared let tile: [bf16; 256 * 256] = []  // 128KB shared (sm_90 max)
    gpu_tma_load_2d(tile, desc, x_offset, y_offset)
    gpu_tma_commit()
    gpu_tma_wait(0)
    // tile에서 직접 WMMA / FlashAttention 컴퓨트
}
```

## 핵심 의존성

- Tensor descriptor host-side setup (cuTensorMapEncode)
- Cluster cooperative groups (sm_90 multi-CTA)
- Distributed shared memory (`shared::cluster` address space)

## 구현 차단

| 차단 | 해소 시점 |
|---|---|
| RTX 5070 = sm_120 (Blackwell) — TMA는 sm_90 (Hopper) 부터, sm_120 backward-compat 미확정 | NVIDIA confirmation 필요 |
| Cluster groups 동기화 ABI | Cuda 12.0+ |
| TensorDesc host setup boilerplate | host runtime API 별도 layer |

## g0 권고

Hopper-only feature, RTX 5070 sm_120 호환성 미확인. 현재 cycle에서는 design note 만 유지 + Hopper hardware access 확보 후 별도 multi-cycle 작업.

## 우선순위

low — sm_80 path (cp.async — B2) 가 먼저. TMA는 sm_90 mass-market 후 cycle.
