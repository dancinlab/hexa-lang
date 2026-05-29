# MS#1 — hexa-emit 커널 직접 achieved/peak % (cuBLAS-INDEPENDENT)

GPU-ROOFLINE 도메인 batch D · 2026-05-30 · ubu-2 RTX 5070 sm_120 ($0 fire).

## 무엇

`wmma_256x256_grid` = **compiler-emitted** hexa WMMA HGEMM 커널(PR #214, `nvptx_target.hexa`
WMMA 경로, 256×256×256 shape-locked)의 처리량을 **device achieved tensor-core peak 를 분모로**
직접 환산. cuBLAS 와의 ratio 가 아니라 hexa codegen 이 직접 emit 한 커널의 절대 achieved/peak %.

## 파일

- `ms1_host.cu` — harness. `cuModuleLoad` 로 compiler-emit PTX 직접 로드 → median of 200 timing
  (20 warmup, cudaEventRecord per-launch) → byte-eq vs CPU FP64 ref → achieved-peak(cuBLAS HGEMM
  M=4096) 분모로 direct % 산출. pure-ASCII, /tmp 빌드.
- `wmma_256x256_grid.ptx` — compiler-emitted PTX (PR #214 / rfc067_p5 fire 에서 복사).
- `ms1_fire.log` — verbatim stdout (2 run).

## 결과

| 커널 | shape | hexa TFLOPS | DIRECT achieved/peak % |
|---|---|---|---|
| `wmma_256x256_grid` (compiler-emit) | 256³ | 3.53–3.59 | **2.79–2.84%** (분모 §peak 126.52 TF) · **4.96–5.05%** (same-process 71.13 TF) |

byte-eq hexa-vs-CPUref(FP64) **max|Δ|=0** (full 256×256).

## 빌드/실행 (ubu-2)

```
nvcc -O3 -arch=sm_90 ms1_host.cu -o ms1_host -lcuda -lcublas
./ms1_host                              # 기본 wmma_256x256_grid.ptx
./ms1_host <ptx> <entry>                # 다른 shape PTX 도 측정 가능
```

## 정직 노트

- **cuBLAS-INDEPENDENT numerator**: 분자 = compiler-emit hexa 커널 직접 측정. 분모만 device peak.
- 256³ 는 launch/occupancy-bound 영역 → M=4096-peak 분모 대비 % 가 작은 게 물리적 정직
  (shape-local cuBLAS S=256 조차 자기 peak 의 3.5%). hexa 는 shape-local cuBLAS 의 79–80%.
- **256-locked 1점만**. variable-shape compiler emission = multi-session codegen (MS#1 open,
  `domains/GPU-ROOFLINE.md ## MS#1 codegen sub-milestone` 1a-1d 분해).
