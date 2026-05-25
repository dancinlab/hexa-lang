# GPU 축-A 모트 확장 — NN elementwise/norm 표면 (2026-05-25)

전체-프로그램 융합(whole-program fusion) 모트를 **단일 워크로드(launch-amort 5-op 체인)**에서
**NN elementwise/reduction 표면 전반(LayerNorm · RMSNorm · Softmax · SwiGLU)**으로 확장한 라운드.
GPU.md §10 모트 박스는 이미 `[x]`(PR #1028, F-FUSION-LAUNCH-AMORT-WALL로 73~76% wall flip);
이번 라운드는 **승리 축(§5f launch-overhead / §5a memory-bound 융합)을 더 많은 실제 NN 연산자로 일반화**한다.

## 원리

cuBLAS/cuDNN는 튜닝된 GEMM을 제공하지만, **norm/activation/elementwise glue**는 융합이 소유하는 영역이다.
eager(per-op) 스택은 각 elementwise+reduction 연산을 **별도 커널 런치**로 돌리고, 그때마다 텐서를 HBM으로
왕복시킨다. 전체-프로그램 융합은 **하나의 커널**에서 sub-step 간 값을 레지스터/shared-mem로 유지하여
HBM 1-read + 1-write로 끝낸다. memory-bound 연산에서 승리 = 런치-수 + HBM-트래픽 절감 = wall 가속.

(GEMM-융합 축은 별도로 이미 특성화된 closed-negative — 이번엔 attention/GEMM 미접촉.)

## 측정 환경

- 호스트: ubu-2 RTX 5070 (sm_120, driver-JIT forward-compat) · CUDA 12.0 · $0 (로컬)
- 방법: 융합 1-커널 vs eager 다중-런치 baseline; `cuLaunchKernel` + `cuEvent`; 20 warmup + 200 timed median
- 수치 게이트: f64 CPU 레퍼런스 대비 **정직한 per-row-scaled RMS rel** 지표 (naive `|err|/(|want|+eps)`는
  softmax 확률이 0에 가까울 때 폭발 — 그래서 per-row RMS 사용). tol 1e-2
- 경합 게이트: 매 워크로드 직전 `nvidia-smi` = 0% util 확인 후 **직렬(serial)** 타이밍
- g5: `hexa verify`는 두 ubu 호스트 모두 BROKEN → 정확성은 컴파일된 f64-ref 하네스로 settle,
  stdout은 `.verdicts/fusion-axisA-<workload>/`에 verbatim 저장

## 모트-너비 표 (g63 — 모든 워크로드가 측정 verdict 도달, 손실 보존)

| 워크로드  | 사이즈              | 런치비 | HBM비  | pct_faster | >=30% |
|-----------|---------------------|--------|--------|------------|-------|
| LayerNorm | large 4096x4096     | 4.0x   | 2.00x  | **66.2%**  | PASS  |
| LayerNorm | small 256x512       | 4.0x   | 2.00x  | **72.7%**  | PASS  |
| RMSNorm   | large 4096x4096     | 3.0x   | 1.67x  | **59.5%**  | PASS  |
| RMSNorm   | small 256x512       | 3.0x   | 1.67x  | **58.6%**  | PASS  |
| Softmax   | large 4096x4096     | 4.0x   | 1.50x  | **65.9%**  | PASS  |
| Softmax   | small 256x512       | 4.0x   | 1.50x  | **56.3%**  | PASS  |
| SwiGLU    | large n=16.78M      | 3.0x   | 2.67x  | **63.0%**  | PASS  |
| SwiGLU    | small n=131072      | 3.0x   | 2.67x  | **47.8%**  | PASS  |

**4/4 워크로드 모두 양쪽 regime에서 >=30% 통과** (8/8 measurement PASS, 8/8 numeric PASS).

## 워크로드별 대표 수치

- **LayerNorm**: 융합 0.232ms vs eager 0.687ms (large, 2.96x) — 66.2%. small 3.67x, 72.7%. rel err <=1.5e-7.
- **RMSNorm (LLaMA)**: 융합 0.232ms vs eager 0.573ms (large, 2.47x) — 59.5%. small 58.6%. rel err <=1.4e-7.
- **Softmax (online)**: 융합 0.238ms vs eager 0.698ms (large, 2.93x) — 65.9%. small 56.3%. rel err <=1.9e-7.
  (정직한 per-row RMS 지표로 near-zero 확률 false-FAIL 회피.)
- **SwiGLU**: 융합 0.334ms vs eager 0.903ms (large, 2.70x) — 63.0%. small 47.8%. rel err <=3.4e-7.
  HBM 트래픽 8->3 (가장 큰 절감, eager가 s/t 중간텐서 두 개를 HBM에 materialize).

## 결과 — 모트 일반화

§10 모트는 이제 **단일 데이터포인트가 아니라 N+1=5개 워크로드의 강건한 일반 결과**다:
LayerNorm 66% · RMSNorm 59% · Softmax 66% · SwiGLU 63% (large regime), launch-amort 73~76%.
모든 ptxas 모듈 0 spill. 사전등록 falsifier(워크로드당 >=30% wall)가 8/8 over-satisfied.

## 아티팩트

- 원시 측정: `archive/fires/fusion_axisA_breadth_2026_05_25/` (PTX 8쌍 + 하네스 4 + result.json + fire.log)
- verdict (verbatim stdout): `.verdicts/fusion-axisA-{layernorm,rmsnorm,softmax,swiglu}/`
- discovery 로그: `.discoveries/fusion-axisA-breadth.tape`
- CLAIMS.tape: GPU 그룹 4개 엔트리
