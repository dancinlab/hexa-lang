# 🧪 GPU next-list — anima 학습 (transformer step) wall 영향 순위

> 이 문서는 `GPU.md` (SSOT) 의 anima(LLM transformer) 학습-우선순위 사이드. 같은 next-list 후보를 *학습 step wall 에 얼마나 영향* 주는지로 재정렬.

## Transformer 한 step wall 분포 (대략, d=768·12L 기준)

```
한 step wall 분포 (작은 모델 기준):
 ┌──────────────────────────────────────────────┐
 │ attention fwd+bwd        ~40-50 %  ★★★★★      │  ← FlashAttn 영역
 │ FFN (GEMM-bias-act-GEMM) ~25-35 %  ★★★★       │  ← epilogue fusion 영역
 │ norm (LN/RMSNorm pre+post) ~5-10 % ★★         │  ← norm fusion 영역
 │ AdamW step              ~3-5 %    ★          │  ← launch-bound
 │ embed/output proj       ~5-10 %   ★★         │  ← 1 큰 GEMM
 │ overhead (Python+ATen)  ~5-15 %   ★★★ (PyTorch)│ ← compiler-only 가 0
 └──────────────────────────────────────────────┘
```

## anima 학습 영향순 next-list

| 순위 | 항목 | 학습 wall 영향 | 이유 |
|---|---|---|---|
| 🥇 1 | **BC4 round-14 wedge** (register-O + BM=32 + cp.async) | ★★★★★ | attention fwd+bwd 직타격, step 의 40-50% |
| 🥈 2 | **RFC 049 BF16-TC mega-kernel Stage 2** | ★★★★★ | 학습 전체 GEMM 영역 — 측정된 9.67× FP64-cuBLAS, attention+FFN 동시 단축 |
| 🥉 3 | §5a **LayerNorm + GEMM fusion** (pre-LN ↔ FFN 입구) | ★★★★ | depth × 2 = 24 layer norm, 매 block 입구 |
| 4 | §5a **GEMM+bias+activation epilogue fused** (FFN 안 SwiGLU/GeLU) | ★★★★ | FFN 25-35%, BC3 falsified 이지만 register-resident path 재시도 가치 |
| 5 | §5a **AdamW step fusion** (grad·m·v·param 1 kernel) | ★★★ | launch-bound dominated, layer 수만큼 작은 op chain |
| 6 | §5k **flame layer-fused training** (fwd+bwd+AdamW 1 kernel) | ★★★★★ long-term | 위 1-5 의 ultimate fusion. 시간 큼 |
| 7 | §5a **MoE dispatch+GEMM+reduce** (Qwen-MoE 등) | ★★ | MoE 모델만 해당 |
| 8 | **unop literal-neg close** (INBOX #1665, keystone 풀림) | ★★ indirect | softmax max-shift 같은 음수 리터럴 kernel 직접 작성 unblock |
| 9 | §5g **per-call-site precision** (BF16/FP32 혼합) | ★★ | BC4·RFC 049 시너지 — embed FP32 + GEMM BF16 |
| 10 | §5j **top-k + GEMM fusion** | ★ | 학습은 거의 영향 없음 (inference sampling 영역) |
| 11 | §5l **standalone cubin embed** | ☆ | 학습 wall 무관 (deploy 후속) |
| 12 | §5e **AMD ROCm 백엔드** | ☆ | A100/H100 학습은 무관 |
| 13 | §5c **posit/interval** | ☆ | LLM 학습 안 씀 |

## 🎯 anima 학습 진짜 격차 라인 (1-3 차순)

```
1차 (가장 큰 한 발):
  BC4 wedge fire ─→ attention fwd+bwd wall 측정
                 ─→ flame d=768·12L step 의 40-50% 영역 직타격
                    plan 끝났고 cost ≤ $0.50

2차 (메모리+compute 동시):
  RFC 049 Stage 2 land ─→ BF16-TC mega-kernel 학습 전체에 적용
                       ─→ 9.67× FP64-cuBLAS 측정값 학습 wall 로 흘림
                          (현재는 FFN-shape 만 fire, 학습 loop integration 잔여)

3차 (norm + FFN 입구):
  §5a LN+GEMM fusion ─→ 매 block 입구 pre-LN+첫 GEMM 묶음
                     ─→ memory-bound norm 의 HBM round-trip 제거
                        forge 위에서 fusion path 잘 깔려있어 1 fire 로 측정 가능
```

## 한 줄 추천

🥇 **BC4 round-14 wedge fire 먼저** — attention 이 학습 wall 의 가장 큰 단일 block 이고, plan 정량 정찰 끝나서 cost-bearing fire 만 남았다. 측정 결과에 따라 다음 라인 (RFC 049 Stage 2 vs §5a LN+GEMM) 결정.

비유: anima 학습이라는 *코스 요리* 에서, attention 은 가장 시간 오래 걸리는 *메인 디시* — 이 디시 한 팬 요리 (FlashAttn-style fusion) 부터 잡는 게 wall 단축 최대.

---

원본 SSOT = `GPU.md` + `GPU.log.md`. 본 anima-우선순위 사이드는 학습 step wall 영향 기준의 next-list 재정렬용. PyTorch+cuBLAS 가치제안 사이드 = `GPU.easy.md`.
