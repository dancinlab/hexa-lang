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
| 8 | **unop literal-neg close** ✅ ALREADY-CLOSED (PR #1686 머지 2026-05-27) | ★★ indirect | codegen 4-layer silicon round-trip 종결 — 음수 리터럴 kernel 직접 작성 unblock |
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

원본 SSOT = `GPU.md` + `GPU.log.md`. 본 anima-우선순위 사이드는 학습 step wall 영향 기준의 next-list 재정렬용. PyTorch+cuBLAS 가치제안 사이드 = `GPU.easy.md`. anima-측 시간순 로그 = `GPU.anima.log.md`.

---

## 🩺 진단 — anima M4b 트레이너 production step-rate (2026-05-28)

`STEP_RATE_FINDING` 측정 (anima PR #1318, H100 SXM `4q2rab8ds2zhsr`) — 실측 wall 분포는 위 d=768·12L 표와 **다름**. anima M4b 디코더(d=64·V=151643·n_layer=1) 는 작은 d 때문에 matmul 이 GPU 를 못 띄우고 (GPU util 0%) **CPU 핫루프** 가 step 을 지배:

```
실측 한 step (~1 step/s):
 ┌────────────────────────────────────────────┐
 │ (a) zero dMg          29.16M farr_set/step │  ★★★ CPU
 │ (b) AdamW update      29.16M params/step    │  ★★★ CPU
 │ (c) softmax V=151643  ~3V farr_get          │  ★★ CPU
 │ (d) matmul fwd+bwd    cuBLAS (d=64 너무 작아 utility 0%) │ ★ transfer-bound
 └────────────────────────────────────────────┘
 → 토이 `dec_undertrain` 예측 "tens × V presentations" = ~9 GPU-days = 실현불가능
```

핵심: GPU kernel(`_hx_cuda_farr_*_gpu`)은 runtime_cuda.c 에 이미 다 있음. **hexa 빌트인 노출(codegen) 만 빠짐** — 트레이너가 CPU 루프 대신 빌트인을 호출하면 격차 해소 가능.

### 인벤토리

| 필요 GPU op | kernel | 빌트인 | 작업 |
|---|---|---|---|
| bulk zero (dMg) | `_hx_cuda_farr_zero_slice_gpu` (1356) | ✅ `farr_zero_slice_gpu` (runtime.c:12229) | anima wiring 만 |
| fused AdamW step | `_hx_cuda_farr_adamw_step_gpu` (1356) | 🟡 미등록 (12-arg) | codegen + 기준선 + dispatch |
| softmax over rows | `_hx_cuda_farr_softmax_rows_gpu` (1181) | 🟡 미등록 (4-arg) | codegen + 기준선 |
| CE seed | `_hx_cuda_farr_ce_seed_gpu` (1220) | 🟡 미등록 (5-arg) | codegen + 기준선 |
| FP64 matmul | cuBLAS Dgemm | ✅ `farr_matmul` (dispatch glue 완성) | (없음) |

---

## 📋 진행 마일스톤 (BC-ANIMA)

stacked PRs, g4 <200 LoC 씩.

- [ ] **M0 — anima 트레이너 `farr_zero_slice_gpu` wiring** (anima 단독). 트레이너의 dMg 재설정 루프를 빌트인 한 줄로 교체. hexa-lang 손 안 댐. 안전, 가장 작은 첫걸음. **단계비용 ~33% 즉시 제거 후보**
- [ ] **M1 — hexa-lang `farr_adamw_step` 빌트인 등록**. 12-arg codegen 슬롯 신설 + `hexa_farr_adamw_step` CPU 기준선 + HEXA_CUDA dispatch + byte-eq 테스트. bootstrap `hexa_cc.c` 재컴 필요
- [ ] **M2 — hexa-lang `farr_softmax_rows` 빌트인 등록**. 4-arg 슬롯 + CPU 기준선 + dispatch + 테스트 (M1 패턴)
- [ ] **M3 — hexa-lang `farr_ce_seed` 빌트인 등록**. 5-arg 슬롯 + 기준선 + dispatch + 테스트
- [ ] **M4 — anima 트레이너 full wiring**. Adam/softmax/CE 루프를 M1·M2·M3 빌트인 호출로 교체. H100 pod 에서 step-rate 측정 (목표 ≥10 step/s)
- [ ] **M5 — decisive long-train fire 재발사** (dec_undertrain 검증). M4 가 토이의 `tens × V` 예산을 가용 wall 안으로 끌어왔는지 확정. 결과를 `.discoveries/decoder_collapse_undertrain.tape` (anima) 에 흡수

### 종속 그래프 + 위험

```
 M0 (anima only)        ──┐
                          ├─→ M4 (full wiring) ──→ M5 (decisive fire)
 M1 (adamw) ─┐            │
 M2 (softmax)─┼ (병렬 가능)─┘
 M3 (ce)    ─┘
```

- M0 는 다른 마일스톤 독립 — 먼저 land 가능. M1/M2/M3 는 hexa-lang 안에서 병렬 (codegen 슬롯 분리, 함수 분리).
- **bootstrap 위험**: M1 의 codegen 변경 → `hexa_cc.c` 재컴 회귀 가능. byte-eq + 기존 테스트 매트릭스 통과 필수.
- **공유트리**: anima · hexa-lang 둘 다 다중 agent. 모든 landing 격리 worktree + PR.
- **toy→scale 미확정**: M5 결과 부정이어도 닫힌-부정으로 paper-able (a_paper_negative_ok).

### 참고 (배경)
- anima #1314 — capacity-cliff micro-exp (`dec_capfloor` + `dec_undertrain` 사전등록)
- anima #1315 — A/B/C 3-pod 실험 (capacity·routing 배제)
- anima #1316 — 토이 예측 production 확인
- anima #1318 — `STEP_RATE_FINDING` (본 트랙의 직접 동기)
- `.discoveries/decoder_collapse_undertrain.tape` (anima) — 누적 경로 SSOT
