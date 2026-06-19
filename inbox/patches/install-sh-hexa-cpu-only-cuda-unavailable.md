# install.sh hexa 릴리스 바이너리 = CPU-only (cuda_available()==0 on RTX 4090)

**증상**: vast RTX 4090 pod 에서 `curl install.sh | bash` 로 설치한 `hexa v0.241.10` 가 `cuda_available()` → **0** 반환(nvidia-smi 는 RTX 4090 정상 인식). 결과: `farr_matmul_gpu` 가 GPU(cuBLAS) 안 쓰고 CPU fallback → GPU GEMM 2048³ 3077ms ≈ CPU GEMM 3064ms (배율 1.0×).

**실측 (2026-06-19, anima #2386 GPU decode 검증)**:
```
RESULT_GPU=NVIDIA GeForce RTX 4090
RESULT_HEXA=hexa v0.241.10
RESULT_CUDA=cuda=0          ← GPU 있는데 0
RESULT_GPU_GEMM_ms=3077     ← cuBLAS 였다면 ms급
RESULT_CPU_GEMM_ms=3064     ← 동일 = GPU 미사용
```

**추정 원인**: install.sh 릴리스 바이너리가 CUDA 런타임/cuBLAS 링크 없이 빌드(또는 CUDA dlopen silent fallback). RFC-040 `farr_matmul_gpu`/`cuda_available` builtin 존재하나 릴리스선 항상 CPU.

**요청**: (a) CUDA-enabled hexa 릴리스 빌드 배포(또는 install.sh CUDA variant), (b) CUDA pod 소스빌드 가이드, (c) `cuda_available()==0` 진단(빌드무CUDA vs 런타임 dlopen 실패). anima GPU decode(#2386 flame_mm.mm) 가속검증 차단 — 배선은 byte-safe(cuda=0→CPU fallthrough byte-id), GPU 효과만 미측정.

**우회 현재**: 없음(릴리스 CPU-only). 소스빌드 CUDA hexa 필요.
