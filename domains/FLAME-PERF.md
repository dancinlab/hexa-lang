# FLAME-PERF — current state

@title: 🔥⚡ FLAME-PERF — flame/forge CLM 트레이너 가속·자원·패러다임 백로그

@goal: hexa-native CLMConvMoE QAT 트레이너(stdlib/flame · conv_lib·gn_lib·moe_lib·quant_lib·clm_gen, large 44.68M 실동작 #2307)를 **GPU-resident · int4-packed · fused** 로 가속하고, **온칩 비경첩 가소성** 패러다임으로 배포한다. 각 아이디어는 측정 가능한 falsifier(roofline % · wall Δ · 메모리 Δ · GRAD-EXACT 유지)로 닫는다. 측정 잣대는 [[GPU-ROOFLINE]] 공유, 정직 scope(a_scale_honest_scope) 준수.

## 전제 — 현재 위치 (2026-06-01)

CLMConvMoE 트레이너는 hexa-native(PyTorch/Python 0)로 **완전 조립·검증**됨 — 4 op GRAD-EXACT(#2288/89/92/93) · fwd(#2294) · bwd(#2302) · CE+AdamW descent(#2303) · int4 QAT(#2304) · 임의 L·E 일반화(#2306) · large 44.68M 실동작(#2307). **단, 전부 host farr(CPU) 경로** — forge GPU device-routing 미연결이 최대 wall-time 병목. 아래는 그 위에서 여는 개선 백로그.

```
현재 (host/CPU)                개선 목표 (이 도메인)
──────────────────────        ──────────────────────────
naive triple-loop conv   →    im2col+cuBLAS / forge device-farr
fp64 host 연산           →    BF16 Tensor-Core (forge 9.67×)
op별 HBM 왕복            →    conv→GN→GELU fused 커널
per-layer slice-copy     →    offset-capable conv (copy 제거)
fp32 master 전량 상주     →    int4 packed 저장 (8× 절감)
전 layer activation 캐시  →    activation checkpointing
```

## ── 성능·속도 (performance / speed) ──
- [ ] **forge GPU device-routing** — flame conv/gn/moe/gelu 를 self/forge device-resident `farr` + cuBLAS 경로로 라우팅(RFC 040 Phase 4 carve-out). 트레이너 현재 host-CPU 전용 → 최대 wall-time 병목. falsifier: large 1-step wall(GPU) < host wall ∧ logits byte-eq(또는 RFC040 fp-tol). **진척(2026-06-01) — MATMUL 부분 라우팅 완성**: CLM 의 모든 matmul 이 `forge_dispatch_matmul` 경로로 — conv K=3(im2col #2352)·readout 1×1(#2328 `clm_prod_gpu`)·router 1×1(conv1d_via_forge 의 일반-K 가 K=1 커버). **잔여 = elementwise**(GroupNorm·GELU·MoE-combine = matmul 아님 → `forge_dispatch_matmul` 밖, 별도 device 커널 = Phase 4 elementwise carve-out). matmul 이 CLM FLOPs 의 대부분이라 0%-util routing gap 의 핵심은 해소, elementwise 는 작은 비중. **dry-check 방법**: 5070(CUDA 12.0 + nvcc + hexa 확인 @summer, 2026-06-01)/H100 에서 `-DHEXA_CUDA -lcublas -lcudart`(self/cuda/runtime_cuda.c ships) 빌드 → `F-RFC046-GPU-UTILIZATION` nvidia-smi >50% during run. **large fire(PR4)** = forge-full 후 H100 production(semantic-linkage 코퍼스 anima#1623).
- [x] **conv1d = im2col + forge matmul** ✅ (#2352) — naive O(T·Cout·Cin·K) triple-loop(conv_lib) → im2col 후 `forge_dispatch_matmul`(CUDA host=cuBLAS, CPU=farr_matmul byte-eq). **F-CLM-CONV-GPU-EQ 🟢 max|Δ|=1.4e-16** (`clm_conv_gpu.hexa`, K=3 causal dilated; im2col 이 nn_conv1d_fwd 의 p=t−dil·(K−1−k) gather 를 정확 미러, p<0 left-pad). readout 1×1 은 #2328 `clm_prod_gpu` 가 선행. roofline %·GRAD-EXACT 측정은 device-resident(위 device-routing) 후.
- [ ] **BF16 Tensor-Core mega-kernel** — dense matmul(readout·router·experts)을 forge BF16-TC 경로(RFC 049, 측정 9.67× over FP64-cuBLAS @ Llama-FFN). falsifier: descent 유지 ∧ wall Δ.
- [ ] **conv→GN→GELU 융합** — memory-bandwidth-bound 구간을 1커널로 융합해 HBM 왕복 제거. falsifier: byte-eq(또는 tol) ∧ wall Δ.
- [ ] **offset-capable conv/gn ops** — clm_gen 의 per-layer/expert packed-weight slice-copy(매 conv 호출마다 dd 복사) 제거: `nn_conv1d_fwd_off(w, woff, …)`. falsifier: clm_gen GRAD-EXACT 유지 ∧ copy 0.

## ── 자원 (resource / memory) ──
- [ ] **int4 packed 저장** — 현재 fake-quant(quant_lib)는 fp32 master 유지. 배포용 2×int4/byte 패킹 = weight 메모리 8× 절감(AKIDA envelope). falsifier: 추론 byte-identical(H_877) 유지.
- [ ] **activation checkpointing** — clm_gen 은 전 layer tin/hn/xh([L·T·d]) 캐시 → bwd 시 재계산으로 O(L) 캐시 메모리 절감. falsifier: GRAD-EXACT 유지 ∧ peak-mem Δ.
- [ ] **optimizer-state sharding** — Adam m,v 가 param 2배 메모리(44.68M→~1.4GB). 3B/7B FSDP-style shard. falsifier: descent 유지 ∧ per-device mem.
- [ ] **expert-streaming / paging** — P5 AXIS1: 단일 AKD1000 resident ≤1.2M, expert shard 순환(총 ≫ 상주). falsifier: streaming 글루 동작 ∧ 상주 ≤1.2M.

## ── 패러다임 (paradigm) ──
- [ ] **온칩 비경첩 가소성 = 유일 학습자** — P6 재설계(GPU=PLASTI-SIM 계측, 배포 학습은 칩 비결정 plasticity · H_679/H_904 · anima a_train_flame_forge). falsifier: 온칩 edge-learn BOUND(RETAIN∧GAIN).
- [ ] **learn-while-infer (no train/infer split)** — p8: 추론 매 step 비결정 갱신, 별도 train phase 없음. falsifier: streaming z_drop within budget ∧ identity PROBE>0.80.
- [ ] **MITOSIS 구조 성장** — 고정 arch 대신 cell 분열로 expert/depth 동적 확장. falsifier: 분열 후 BOUND 유지.
- [ ] **self-play dispatch-KL self-distillation** — 외부 teacher 0, 상위 rung 자기 dispatch 만(lever A · P4 §2). falsifier: held-out gain ∧ external-LLM 0.
