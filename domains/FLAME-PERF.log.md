# FLAME-PERF — append-only step log

## 2026-06-01 — 도메인 생성 (개선아이디어 백로그 시드)

hexa-native CLMConvMoE QAT 트레이너 완성 직후(4 op + fwd/bwd GRAD-EXACT + CE/AdamW
descent + int4 QAT + 임의 L·E 일반화 + large 44.68M 실동작, PR #2288–#2307) 도출된
성능·자원·속도·패러다임 개선 여지를 도메인으로 박제. 모든 작업이 host farr(CPU) 경로라
forge GPU device-routing 미연결이 최대 wall-time 병목 — 이 도메인의 1순위 lever.

시드 milestone 12개 (4축): 성능·속도 5 · 자원 4 · 패러다임 3. 각 아이디어는 측정 가능한
falsifier(roofline % · wall Δ · 메모리 Δ · GRAD-EXACT/byte-eq 유지)로 닫는다. 측정 잣대는
GPU-ROOFLINE 도메인과 공유. 날조 0 · a_scale_honest_scope 준수.

## 2026-06-01 — CLM matmul forge-routing 부분 완성 (conv im2col ✅)

CLM 의 모든 matmul 이 `forge_dispatch_matmul` 경로로 들어옴 — 0%-util routing gap 의
핵심(matmul = CLM FLOPs 대부분)이 해소됨:

| op | K | PR | verdict |
|---|---|---|---|
| conv1d | 3 | #2352 `clm_conv_gpu.hexa` | F-CLM-CONV-GPU-EQ 🟢 max\|Δ\|=1.4e-16 |
| readout | 1×1 | #2328 `clm_prod_gpu.hexa` | (선행) |
| router | 1×1 | conv1d_via_forge 일반-K 가 K=1 커버 | — |

conv 는 im2col(x_col[T, Cin·K] @ Wᵀ + b)로 GEMM 화 — im2col gather 가 nn_conv1d_fwd 의
p = t − dil·(K−1−k) (p<0 left-pad)를 정확 미러하여 max\|Δ\|=1.4e-16 (FP round-trip).
CUDA host 면 cuBLAS, CPU 면 farr_matmul 로 같은 함수 — measure⊥deploy.

milestone 상태: `conv1d = im2col + forge matmul` [x], `forge GPU device-routing` 는
**matmul 부분만** 완료(진척 노트 추가). **잔여 = elementwise**(GroupNorm·GELU·MoE-combine)
= `forge_dispatch_matmul` 밖 → 별도 device 커널 = Phase 4 elementwise carve-out (hexa-lang
forge 팀 대형 작업, 작은 FLOPs 비중).

dry-check 방법: 5070(CUDA 12.0 + nvcc + hexa @summer 확인 2026-06-01)/H100 에서
`-DHEXA_CUDA -lcublas -lcudart`(self/cuda/runtime_cuda.c ships) 빌드 → F-RFC046-GPU-UTILIZATION
nvidia-smi >50% during run. large fire(PR4) = forge-full 후 H100 production(semantic-linkage
코퍼스 anima#1623).
