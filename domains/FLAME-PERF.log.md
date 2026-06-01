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

## 2026-06-01 — H100 large fire 실측 (clm_large 44.68M, pod teardown 완료)

runpod H100(80GB HBM3, nvcc/cuBLAS 12.4)에서 clm_large 를 `-DHEXA_CUDA` cuBLAS 빌드/실행.
빌드 blocker 4개 해소: ① public repo 는 runtime.c .c-graduated → 로컬 `~/.hx/src/self/` 전송
② linux hexat 는 `use` 안 펼침 → mac `hexa_module_loader` 로 flatten ③ `runtime_cuda.c` 는
bf16 `__nv_bfloat16` 커널 → `nvcc -x cu -DHEXA_CUDA` ④ driver API 위해 `-lcuda`.

| verdict | 결과 | 증거 |
|---|---|---|
| F-FLAME-CLM-LARGE-RUN | 🟢 GREEN | n_params=44678668, CE 4.81414→0.0132543 PASS (clm_out.log) |
| F-CLM-CUBLAS-ENGAGED | 🟢 GREEN | 108 real [CUBLAS-DGEMM] (100× M=4 K=2304 N=768 등; silent fallback 아님, cublas_trace.log) |
| F-RFC046-GPU-UTILIZATION | 🔴 RED | peak util 1%(T=4)/4%(T=512) — >50% 미달 (util.log) |

**정직한 negative**: forge matmul 라우팅은 기능적으로 검증(cuBLAS 108 Dgemm)되나 util 은 RED.
원인 = forward-only-partial-GPU + **backward 전체 host-only(설계: clm_large "Backward stays host")**
+ 작은 T → 각 Dgemm 마이크로초, host FP64 scalar(im2col·GN·GELU·backward)가 wall 지배.
T=512 로 키워도 O(T²) host 루프가 더 지배(4%). **util GREEN 전제 = backward forge(Phase-4
bwd-forge) + 큰 batch×T**. cuBLAS 자체는 PHASE_D_H100_EVIDENCE.md 에 51.24 TFLOPS(H100 76%)
선례 — gap 은 host 잔여. 증거 박제: `.verdicts/flame-perf-clm-forge-h100/`.

## 2026-06-01 — 세션 PR 13개 landing + 마일스톤 일괄 flip

main broken-pipe 게이트(#2381, runtime_core_emit seen-gate 복원)로 main GREEN 복구 후,
이 세션 검증 PR 13개를 CI-gated squash 로 일괄 landing. 마일스톤 정직 flip(g63):

CLOSED [x] (host falsifier 완전 폐쇄):
- offset-conv #2354 🟢 (GRAD-EXACT ∧ copy 0)
- int4 packed #2356 🟢 (byte-identical 0.0 · 8×)
- activation-ckpt #2357 🟢 (GRAD-EXACT · cache 3.0×)
- conv1d=im2col #2352/#2359 🟢 (forge + host 60×)
- conv→GN→GELU #2385 🟢 byte-eq (#2365 대체, #2357 no-cache 보존; wall→GPU defer)
- expert-streaming #2369 🟢 (resident ≤1.2M counting)
- self-play #2376 🔴 CLOSED-NEGATIVE (external-LLM 0 ✅, held-out gain 없음)

host-half ✅ / 하드웨어·GPU falsifier OPEN (defer, [ ] 유지):
- BF16-TC #2372 (host fp fallback 🟢 · 9.67× wall = GPU)
- optim-shard #2371 (descent bit-identical 🟢 · per-device mem = 다중 GPU)
- 온칩 plasticity #2373 · learn-while-infer #2375 · MITOSIS #2370 (host 🟢 · 실리콘 BOUND defer → anima ONCHIP-PARADIGM #1641)

forge GPU device-routing 진척: elementwise #2377 + backward-forge #2383 (둘 다 byte-eq 🟢).
util-RED(#2379) 근본해법 = backward-forge 코드상 완료, clm_large 배선 후 차기 H100 fire 재측정.
