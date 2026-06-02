# HEXA-FUSION — current state

@title: 🔥 HEXA-FUSION — whole-program train-step fusion (match PyTorch+CUDA → exceed)

@goal: hexa codegen 이 CLMConvMoE train step 전체(fwd → CE → bwd → AdamW)를 단일 device-resident 그래프로 fuse 해 (1) 인터프리터를 per-step hot path 에서 제거 → util-GREEN(MEAN≥20%) = PyTorch+CUDA 수준 따라잡기, (2) library-call 스택이 구조적으로 못 하는 op-boundary fusion + compile-time 특화로 그 이상을 연다. 실현 능력은 [[GPU]] whole-program-fusion North-Star(§5d/§5f/§5g), 적용 대상은 [[FLAME-PERF]] 트레이너, cure 대상은 [[FORGE-UTILGREEN]] option-B. 잣대 = [[GPU-ROOFLINE]]. **정직 경계 (g5)**: raw GEMM 우위 주장 금지 — cuBLAS = roofline, larger-tile/wgmma/split-K/warp-spec 전부 falsified(GPU.md:84). moat = **경계 제거**(launch + op-boundary), NOT 커널 한 장 속도.

## 전제 — 왜 fusion 인가 (host-feed 축이 닫힌 뒤)

FORGE-UTILGREEN lever-1~5 가 GEMM repack 을 전부 device 化했어도 util MEAN 은 0.6% 에 PINNED — 8× workload sweep 에서 PEAK 38→78% 배증, MEAN flat → binding constraint = **인터프리트 per-step 드라이버 루프 wall-time**(F-RFC046 root). host-feed 축은 CLOSED-NEGATIVE TERMINAL. 유일 cure = 인터프리터를 hot path 에서 빼는 것 = train step 을 device-resident 그래프로 fuse = 이 도메인.

```
🐍 PyTorch eager — "전문 기계 조립라인"        🔥 HEXA-FUSION — "한 기계 안에서"
─────────────────────────────────         ─────────────────────────────────
 Python ─launch→[cuBLAS]→[cuDNN]→...         codegen →[ fwd→CE→bwd→AdamW
   op 마다 최고속 기계, 기계 사이                       = ONE device 그래프 ]
   = 컨베이어 이동·대기(launch+boundary)         컨베이어(launch/op 경계) 자체 없음
```

- PyTorch 약점 = **library-call 경계**(cuBLAS/cuDNN monolithic black-box, op-by-op dispatch). torch.compile/Inductor 가 일부 fuse 하나 Python tracing + Triton 한계.
- hexa 강점 = 컴파일러가 train step 전체를 **한 IR** 로 봄 → op 경계 넘는 fusion + compile-time 특화 가능.

## ── 사다리: match (L1) → graph (L2) → exceed (L3) ──

### L1 — device-resident (= PyTorch eager 수준, util-GREEN)

- [ ] **device-resident tensor lifetime** — param/grad/moment 를 step 전체에 GPU-resident 유지(host roundtrip 0). falsifier: 기존 오라클 byte-eq max|Δ|=0 ∧ nvidia-smi devmem persist across step.
- [ ] **async kernel-launch pipeline** — step body 가 host 인터프리터 블로킹 없이 device 커널을 비동기 디스패치(GPU 안 굶음). falsifier: `F-RFC046-GPU-UTILIZATION` util MEAN≥20% @ d1536/T512 (= FORGE-UTILGREEN endgame gate, single-driver H100 sm_90 fire).
- [ ] **fwd-only fused device kernel 프로토타입 + util Δ probe** (safe falsifier — 풀포트 전) — fwd path 만 device-resident fuse 해 util Δ 측정(lever-4 fire pod 재사용). 풀 train-step fusion 의 ROI 를 싸게 검증.

### L2 — graph capture (= torch.compile / CUDA-graph 수준)

- [ ] **per-step CUDA-graph capture/replay** — step 커널 시퀀스를 1회 캡처 → 매 step replay 로 launch overhead ~0. falsifier: replay 출력 byte-eq ∧ per-step launch-count Δ(측정).

### L3 — fusion moat (= PyTorch 초과 · 구조적)

- [ ] **fwd+bwd autograd-aware fusion** (GPU.md §5d) — forward + backward 커널을 한 device 그래프로 fuse. falsifier: `F-FUSION-TRAINSTEP-EQ` max|Δ|=0 (fused == op-by-op reference).
- [ ] **compile-time specialization** (GPU.md §5b) — known-(M,N,K) shape 특화 · dead-output elimination · layer 별 mixed-precision auto-select. falsifier: 특화 emit Δ vs generic ∧ byte-eq 무회귀.
- [ ] **operator-specific surgical override** (GPU.md §5g) — per-call-site precision · custom layout/stride · 파이프라인 중간 커널 1개 교체(cuBLAS monolithic 이 못 하는 것). falsifier: override 경로 byte-eq + emit Δ.
- [ ] **launch-overhead amortization 우위 측정** (GPU.md §5f · R12) — sub-threshold launch-bound regime 에서 library 스택 대비 실측 wall 우위. falsifier: vs cuBLAS-call wall Δ < 1.0× @ launch-bound shape.

### closure — vs PyTorch+CUDA 벤치

- [ ] **vs-PyTorch+CUDA wall 벤치** — 동일 모델 device-resident, step/s + util 을 torch eager + torch.compile 와 나란히. **정직**: cuBLAS GEMM = roofline(못 이김 ≠ 실패) — 우위는 fusion/launch-amort regime 에서만 주장. closure = util-GREEN ∧ descent-GREEN ∧ vs-PyTorch wall Δ 기록.

## ── 상속: 이미 측정된 fusion 승리 (재유도 금지, cite) ──

이 도메인은 GPU 도메인의 fusion 캠페인이 측정한 교두보를 상속한다 (재측정 아님 · g5 verbatim 인용):
- **attention fusion R14 ≤1.0× vs cuBLAS-TC 3-launch** (GPU.md §1p, F-FUSION-ATTN-BM32-OCCUPANCY) — launch-bound 영역에서 라이브러리 스택을 실제로 앞지른 측정 beachhead.
- **F-FUSION-LAUNCH-AMORT $0 oracle** (GPU.md §1h, R12) — launch-overhead amortization 정적 증명.
- **whole-program-fusion epilogue GEMM+bias+GeLU** structural finding (GPU.md §1h, 2026-05-25).

## ── 정직 가드 (a_scale_honest_scope · g5) ──

- raw GEMM/커널 한 장으로 cuBLAS 우위 주장 = 즉시 falsified(GPU.md:84 박제). 이 도메인의 win 은 **오직** 경계 제거(launch + op-boundary fusion + compile-time 특화).
- util≥20% 는 항상 single-driver pod fire verdict 소유 — 소스 단독 주장 금지.
- byte-eq(max|Δ|=0) 는 모든 fusion milestone 의 hard gate — 정확성 없는 가속은 무효.
