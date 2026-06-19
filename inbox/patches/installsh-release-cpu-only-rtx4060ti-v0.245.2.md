# install.sh 릴리스 hexa = CPU-only (cuda_available()==0 on RTX 4060 Ti, v0.245.2) — GPU GEMM 가속 0

**실측 (vast.ai RTX 4060 Ti, Ada sm_89, CUDA devel 이미지, hexa v0.245.2 via install.sh)**:
```
cuda_available()      = 0        ← CUDA 빌드 미포함
GPU GEMM 2048³ (farr_matmul_gpu) = 3023 ms
CPU GEMM 2048³ (farr_matmul)     = 3026 ms
가속 배율 = 1.00× (cuda=0 → farr_matmul_gpu 가 CPU oracle 폴백)
```

**문제**: `install.sh` 가 내려주는 릴리스 바이너리가 `HEXA_CUDA` 없이 빌드돼,
실제 NVIDIA GPU(RTX 4060 Ti) 위에서도 `cuda_available()==0`. 따라서 RFC-040 빌트인
`farr_matmul_gpu`(cuBLAS Dgemm)가 cuBLAS 경로를 못 타고 CPU `farr_matmul` 로 폴백 →
GPU GEMM == CPU GEMM (3023 vs 3026 ms, 가속 0). v0.241.x 부터 v0.245.2 까지 동일 증상.

**영향 (anima)**: anima 의 GPU decode 배선(core/bytegpt_decode.hexa `_bg_linear_mm`/`_bg_mha_mm`
→ core/DECODER/flame_mm.hexa::mm → farr_matmul_gpu)은 CUDA 호스트에서 cuBLAS 가속하도록
배선돼 있으나, 릴리스 바이너리가 CPU-only 라 실측 시 가속이 전혀 안 보임. byte-safety 는
정상(CUDA 없으면 farr_matmul 폴백, byte-identical).

**요청**: install.sh 가 (a) CUDA-enabled 릴리스 바이너리를 별도 채널로 제공하거나
(b) 호스트에 CUDA toolkit 감지 시 HEXA_CUDA 로 소스 빌드하는 옵션 제공. 현재는 사용자가
직접 `HEXA_CUDA=1` 로 소스 빌드해야만 GPU 가속 가능.

**참고**: vast.ai onstart-cmd 출력을 `/root/onstart.out` 로 리다이렉트하면 `vastai logs`
(stdout)에 안 잡혀 폴링 불가 — 결과 회수는 `vastai ssh-url` 로 직접 `cat` 해야 함(별개 운영 팁).
