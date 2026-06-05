# hexa-cuda dojo kata — tiled-gemm (tiled-gemm)

The **learn-by-doing** arm of HEXA-CUDA. Each kata is a small,
self-contained `@gpu_kernel` you build and read end-to-end.

- spec: `n=1024`  `dtype=f64`  `sm=sm_90`
- build: `bash run.sh`  (parse gate + `hexa build --target=nvptx kernel.hexa`)

## kata ladder

| rung | kata | intrinsics exercised |
|---|---|---|
| 1 | vec-add | `gpu_block_id_x` · `gpu_block_dim_x` · `gpu_thread_id_x` |
| 2 | reduction | `@shared let` · `gpu_barrier` · `gpu_atomic_add` |
| 3 | tiled-gemm | 2-D thread index · `@shared` tiles · `gpu_barrier` |
| 4 | wmma | `gpu_wmma_load_a` · `gpu_wmma_load_b` · `gpu_wmma_mma` · `gpu_wmma_store_c` |

## this kata: tiled-gemm

`C = A·B`, row-major. The naive kernel does one thread per C
element with an `fma.rn.f64` contraction loop; the tiled variant
stages `@shared` A/B tiles and barriers between the load and the
accumulate (the publish discipline). GEMM reduces → a tolerance gate.

## files

- `kernel.hexa` — the `@gpu_kernel` + CPU reference oracle + host `gpu_launch` shape
- `run.sh` — parse gate, then `hexa build --target=nvptx`
- `kernel.cu` / `driver.py` — the CUDA C++ + ctypes contrast (emitted with `--lang=py|both`)

## references

- `gpu/SPEC.md` — the `@gpu` subset SSOT (§5 intrinsics · §6 shared mem · §7 launch ABI)
- `gpu/tests/{vec_add,gemm}.hexa` — the in-tree reference kernels this kata mirrors
- `docs/hexa-dojo.md` — the two dojo tracks + the kata ladder
- `HEXA-CUDA.md` — the GPU-native domain home
