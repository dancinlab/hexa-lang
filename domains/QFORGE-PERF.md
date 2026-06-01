# QFORGE-PERF — current state

@title: 🚀 QFORGE-PERF — "큐포지 가속기" (QFORGE el-ph accelerator backlog)

@goal: hexa-native QFORGE el-ph 엔진(stdlib/qforge · SCF·DFPT·λ·Tc · g5 cross-val vs QE ref, d_qforge_engine)을 **두 개의 벽** 너머로 가속한다 — (1) **하드웨어 벽**: QE ph.x 의 no-GPU DFPT 한계(29-pod CPU teardown 의 원인) · (2) **알고리즘 벽**: O(N³) 대각화 + dense per-q DFPT 의 본질적 스케일링. 세 LANE(⚡hardware · 🧮algorithmic · 🧠paradigm)로 정렬. **각 아이디어는 PROPOSAL** — 실 `hexa bench` roofline + Δ-vs-baseline 으로 닫기 전에는 ⚡/🧮 closed 아님 (g6/g63 정직 scope). 이 보드의 *제안*들은 여전히 계획이지만, **CPU-scalar baseline + closed-form roofline 천장은 이제 측정·박제됨** ([[QFORGE-PERF.bench]] · 🟢) — 모든 ⚡/🧮 `🟢bench-needed` 항목의 Δ-baseline 분모가 채워졌다.

## baseline — measured anchor (2026-06-01 · [[QFORGE-PERF.bench]])

모든 ⚡/🧮 speedup 비율의 **분모**. 측정·박제 완료 (mini · Apple M4 · `hexa 0.1.0-dispatch`):

```
hot-path 커널           CPU-scalar baseline   RTX 5070 메모리 천장      headroom
────────────────────    ───────────────────   ────────────────────     ──────────
qforge_h_apply v↦H·v    0.140 GFLOP/s          fp64 139.88 · fp32 279.76  ~1000–2000×
(assembler.hexa:140)    (n=256/512/1024 평탄)  GFLOP/s (BW·AI)            (memory roof)
```

- 🟢 **MEMORY-BOUND** (closed-form, verdict 박제): `AI 0.25–0.5 ≪ ridge_fp32 60.96 ≪ ridge_tc 226.1` → 단일 GEMV 는 tensor-core peak(126 TFLOP/s) **도달 불가**. tensor roof 는 matvec 을 GEMM 으로 **batch** 할 때만 열림(Davidson-block 경로). 따라서 ⚡ 현실 천장 = 140–280 GFLOP/s 메모리 roof — 단일 GEMV 에 > ~2000× 주장은 roofline 위배.
- verdict: `.verdicts/qforge-perf-roofline/h-apply-membound.txt` (🟢 SUPPORTED-NUMERICAL).
- 측정치 평탄(n-독립 GFLOP/s) = memory-bound 지문 — `AI = 2/b` 가 n 독립이라 이론과 일치.

**네 hot loop 전부 grounding 완료** (per-call wall · user_s 기준 · [[QFORGE-PERF.bench]] §7):

```
hot loop (engine fn)        size sweep         per-call wall (user)   feeds
─────────────────────       ──────────────     ───────────────────    ──────────────────────
H_apply (matvec)            n 256/512/1024     0.140 GFLOP/s (평탄)    ⚡ H_apply GPU-GEMM
FFT-Poisson  vhartree…      nz 256/1024/4096   11.5 / 217 / 4180 ms   ⚡ cuFFT / NVPTX-FFT
Davidson     qforge_davidson n 128/256/512     15.2 / 54.7 / 169 ms   ⚡ Davidson VᵀHV · 🧮 CheFSI
Sternheimer  qforge_sternh… n 128/256/512      15.8 / 107 / 1372 ms   ⚡ Sternheimer CG resident
```

- FFT-Poisson 은 radix-2 FFT(O(N log N))인데 per-call wall 은 ~O(N²) — butterfly 가 아니라 **call 당 O(N) scratch 할당** + 캐시 압박이 원인. cuFFT 이득이 mesh 크기에 따라 log-linear 예측보다 빠르게 커짐. 부차 관측(handoff): 큰 grid 반복 호출 시 메모리 누적 → 부하 하 OOM (stdlib/signal·runtime 영역 · 본 docs-only 도메인 범위 밖).
- 모든 ⚡/🧮 `🟢bench-needed` 항목이 이제 측정된 분모를 가짐. 구현 항목은 자기 GPU Δ 를 게시할 때 비로소 closed (g6/g63).

## 전제 — hot loops (선행 grounding, 2026-06-01)

QFORGE el-ph 의 측정된 hot path (재분석 금지, 사용):

```
hot loop                         위치                         성격
────────────────────────────    ─────────────────────────    ──────────────────────────────
qforge_h_apply                   assembler.hexa:140           dense O(n²) scalar matvec ·
                                                              Davidson + 모든 Sternheimer CG
                                                              iter 의 innermost kernel
  └ dense H build                 (structure-factor pass)      O(n³)-effective
dv_project (VᵀHV)                davidson.hexa:67             batched matvec + GEMM, scalar
Sternheimer CG                   sternheimer.hexa            per-pert projected CG
                                                              (H_apply + GS project_out / iter)
  └ elph_scf 가 호출               (m_occ× per SC iter,         **el-ph hot path**
                                   nested in max_iter)
FFT-Poisson V_H[ρ]               screening.hexa             CPU fft3_real/ifft3 (stdlib/signal)
                                                              매 SCF iter · **cuFFT path 없음**
```

```
현재 (CPU-scalar · dense-DFPT)          가속 목표 (이 도메인)
──────────────────────────────────    ───────────────────────────────────────
scalar O(n²) H_apply matvec       →    forge_dispatch_matmul GPU-GEMM (byte-eq 선례)
dense per-q DFPT Sternheimer      →    EPW-style coarse-q DFPT + Wannier interp (|g|)
CPU fft3_real Poisson (매 iter)   →    cuFFT / NVPTX-FFT V_H path
O(N³) Davidson 대각화             →    Chebyshev-filtered subspace iter (CheFSI)
finite-diff + Sternheimer LR      →    differentiable-DFT reverse-mode (AD) LR
seed-from-zero 매 candidate       →    MLIP/Δ-ML pre-screen + transfer across pool
```

## ── ⚡ LANE A · hardware accel (CPU/GPU) ──

> reuse: NVPTX target(compiler/codegen/nvptx_target.hexa · WMMA · RFC 055/071) · cuda_rtc(self/ml/cuda_rtc.hexa · rtc_launch · PTX cache) · `forge_dispatch_matmul`(CPU farr↔cuBLAS byte-eq) · FLAME GPU device-routing 선례([[FLAME-PERF]]) · 측정 roofline [[GPU-ROOFLINE]] (RTX 5070 · A100).

- [ ] **H_apply GPU-GEMM** ⚡hardware-PR 🟢bench-needed — `qforge_h_apply`(assembler.hexa:140) 의 scalar O(n²) matvec → `forge_dispatch_matmul` 경로(CUDA host=cuBLAS, byte-eq 선례). Davidson + 모든 Sternheimer CG iter 의 innermost → 최대 leverage. **Δ-baseline = 0.140 GFLOP/s · 현실 천장 140–280 GFLOP/s memory roof ([[QFORGE-PERF.bench]])**. falsifier: GPU 1-pod λ·Tc == CPU baseline (byte-eq 또는 fp-tol) ∧ wall Δ < 1.
- [ ] **Davidson VᵀHV GPU-GEMM** ⚡hardware-PR 🟢bench-needed — `dv_project`(davidson.hexa:67) batched-matvec + GEMM → BF16/TF32 Tensor-Core 경로(FLAME #2372 host-half 선례 · 측정 9.67× Llama-FFN GPU 속성). falsifier: 고유값 스펙트럼 tol 일치 ∧ wall Δ.
- [ ] **Sternheimer CG GPU-resident** ⚡hardware-PR 🟢bench-needed — per-pert projected CG(H_apply + GS project_out) 를 device-farr resident 로 — m_occ×·max_iter× 호출 = el-ph wall 지배. falsifier: 응답 ψ' tol 일치 ∧ host 왕복 0.
- [ ] **cuFFT / NVPTX-FFT Poisson V_H** ⚡hardware-PR 🟢bench-needed — screening.hexa 의 CPU `fft3_real`/`ifft3` → cuFFT(arxiv 2412.01695: 큰 mesh 에서 cuFFT > custom device) 또는 NVPTX-FFT. FFT 가 유일한 CPU-only 잔여 경로. falsifier: V_H[ρ] byte-eq(또는 fp-tol) ∧ 매-iter wall Δ. **Vast 발견 시 → hexa-lang inbox(d8)**.
- [ ] **mixed-precision inner / FP64 refine** ⚡hardware-PR ⚪speculative — TF32/FP32 inner H_apply·CG + FP64 정제(GAP-C FP64-shuffle 선례 · arxiv 2412.01695 mixed-prec DFPT 6×). falsifier: λ 수렴값이 FP64-only 와 tol 내 일치 ∧ wall Δ.
- [ ] **CPU SIMD band-loop vectorize** ⚡hardware-PR ⚪speculative — pool ubu-1/2 free 경로(d7 small-cell)용 band-loop SIMD. GPU 미가용 시 fallback 가속. falsifier: band-loop wall Δ ∧ 결과 불변.
- [ ] **k/q-loop threading + q-point batching** ⚡hardware-PR 🟢bench-needed — 독립 k/q-point 를 thread/batch (npool 류). embarrassingly-parallel. falsifier: N-thread scaling ∧ 합산 λ 불변.

## ── 🧮 LANE B · algorithmic (hardware-AGNOSTIC) ──

- [ ] **EPW-style Wannier |g| interpolation** 🧮algorithmic 🔬research-probe — **dense per-q DFPT 를 회피**: coarse-q DFPT 로 el-ph |g| 계산 → Wannier gauge 변환 → generalized Fourier 로 dense (k,q) interpolate (arxiv 1005.4418 · 1604.03525 · npj 2023). field 의 단일 최대 el-ph 속도향상 · 29-pod teardown 을 유발한 dense-DFPT 를 직접 죽임. falsifier: interpolated λ·Tc == dense-DFPT λ·Tc (LaH10·CaH6 cross-val) ∧ DFPT q-count Δ (coarse 4³ vs dense). **= priority #1**.
- [ ] **Chebyshev-filtered subspace iter (CheFSI)** 🧮algorithmic 🔬research-probe — Davidson 의 O(N³) 명시적 eigenvector 계산 회피 — 저차 Chebyshev 다항식으로 occupied subspace 정제 (arxiv cond-mat/0703239 · Saad/Zhou). 중간 SCF iter 는 정확 고유벡터 불필요. falsifier: 수렴 ρ == Davidson ρ ∧ matvec-count Δ.
- [ ] **better SCF preconditioner + mixing** 🧮algorithmic 🟢bench-needed — linear mixing → Pulay/Broyden DIIS(arxiv 1803.01763) + Teter-Payne-Allan(TPA) kinetic-energy preconditioner. metal/small-gap(d15 smear 영역)에서 SCF iter-count 직접 절감. falsifier: SCF iter-count Δ ∧ 수렴값 불변.
- [ ] **k/q symmetry reduction + Γ-only fast path** 🧮algorithmic 🟢bench-needed — irreducible BZ wedge 만 계산 + 작은셀 Γ-only fast path. falsifier: 대칭-복원 full-BZ 와 λ tol 일치 ∧ q-count Δ.
- [ ] **randomized / sketched eigensolver** 🧮algorithmic ⚪speculative — 큰 eigenproblem 에 randomized Rayleigh-Ritz / sketched-GMRES (arxiv 2111.00113). falsifier: 고유값 정확도 == 고전 ∧ wall/storage Δ.
- [ ] **Lanczos vs Davidson 비교** 🧮algorithmic ⚪speculative — Davidson 대안으로 Lanczos/block-Lanczos subspace. falsifier: 수렴 iter Δ at equal accuracy.
- [ ] **adaptive q-grid sampling** 🧮algorithmic ⚪speculative — α²F(ω) 기여 큰 q 영역 적응 조밀화, flat 영역 coarse. falsifier: λ tol 일치 at 더 적은 총 q.
- [ ] **real-space multigrid vs G-space Poisson** 🧮algorithmic ⚪speculative — G-space FFT-Poisson 대안 real-space multigrid V_H. falsifier: V_H tol 일치 ∧ scaling Δ.

## ── 🧠 LANE C · paradigm shift ──

- [ ] **differentiable-DFT reverse-mode LR** 🧠paradigm 🔬research-probe — finite-diff + Sternheimer linear-response 를 reverse-mode AD 로 대체 (Jrystal · Grad-DFT · QEX · JAX-XC · arxiv 2311.18727 · 2602.05345 LR-TDDFT through SCF fixed point). forces AND linear response 둘 다 autodiff. hexa 가 자체 AD 보유 시 hexa-native 경로. falsifier: AD-그래디언트 == finite-diff 응답 (tol) ∧ Sternheimer-call 제거.
- [ ] **equivariant GNN phonons + el-ph (MACE-class)** 🧠paradigm 🔬research-probe — E(3)-equivariant GNN 으로 phonon(Hessian 2nd-deriv) + α²F(ω) (arxiv 2403.11347 · BETE-NET arxiv 2401.16611 Tc MAE 2.5K · BEE-NET 0.87K). DFT seed/skip. falsifier: GNN α²F == DFPT α²F (held-out) ∧ Tc MAE.
- [ ] **Δ-ML correction (cheap + ML→DFT accuracy)** 🧠paradigm 🔬research-probe — 저렴한 method + ML 보정으로 DFT 정확도. HamGNN/DeepH = KS Hamiltonian 예측 + 변위-미분 AD el-ph (Nature Comp Sci s43588-024-00668-7). falsifier: Δ-ML λ == full-DFPT λ (tol) ∧ DFPT-call Δ.
- [ ] **MLIP foundation-model pre-screen** 🧠paradigm 🔬research-probe — MACE/CHGNet-class universal MLIP 로 candidate pool 사전선별(동적안정·phonon) → DFT 는 통과분만 (arxiv 2503.20005 AI-accel SC discovery workflow). falsifier: MLIP-pass 후보가 DFT 동적안정 recall ∧ pool DFT-fire Δ.
- [ ] **active-learning on-the-fly training** 🧠paradigm ⚪speculative — D-optimality uncertainty-driven 표본선택(arxiv 1611.09346) 으로 surrogate on-the-fly 학습. falsifier: extrapolation 0 ∧ DFPT-label budget Δ.
- [ ] **transfer / reuse across candidate pool** 🧠paradigm ⚪speculative — 검증된 후보(LaH10·CaH6)의 Wannier/surrogate 를 인접 화학종에 transfer (d19 reuse-lattice). falsifier: transfer-seed 수렴 iter Δ ∧ 정확도 유지.

## priority — 최고-leverage 상위 5 (lane 횡단)

prior-art 로 정당화된 랭킹:

1. **🧮 EPW-style Wannier |g| interpolation** (Lane B) — **field 의 단일 최대 el-ph 속도향상.** coarse-q DFPT(4³) → Wannier Fourier interp → dense (k,q). dense per-q DFPT(29-pod teardown 의 원인)를 **본질적으로 제거** — 하드웨어 가속이 아닌 *연산량 자체*를 죽임. 확립된 prior art: EPW(arxiv 1005.4418 · 1604.03525 · npj s41524-023-01107-3) 가 정확히 이 패턴으로 표준이 됨. **dense-DFPT killer 확정.**
2. **⚡ H_apply / Davidson GPU-GEMM** (Lane A) — innermost kernel(assembler.hexa:140)을 `forge_dispatch_matmul`(byte-eq 선례)로. EPW interp 후에도 잔존하는 coarse-DFPT + SCF 의 dense matvec 을 가속. FLAME-PERF 가 동일 경로(CLM matmul→forge)를 이미 H100 실증.
3. **🧠 differentiable-DFT reverse-mode LR** (Lane C) — Sternheimer finite-diff LR 를 AD 로 — 패러다임 교체. Jrystal/Grad-DFT/QEX 가 SCF fixed-point 통과 AD 를 실증(arxiv 2602.05345). hexa AD 보유 시 가장 hexa-native.
4. **🧮 CheFSI** (Lane B) — O(N³) Davidson 대각화의 sub-cubic 대안 (arxiv cond-mat/0703239). 셀이 커질 때(≥20 atom, d7 GPU 영역) 알고리즘 벽을 직접 완화. GPU-GEMM 과 직교 — 둘 다 적용 가능.
5. **🧠 MLIP foundation-model pre-screen** (Lane C) — pool 단계 leverage: DFT 를 *덜 자주* 실행. MACE/CHGNet pre-screen 으로 동적불안정 후보를 DFT 전에 탈락 (arxiv 2503.20005). λ·Tc 정밀도는 여전히 DFPT 가 닫지만, fire 횟수를 줄임.

랭킹 근거: 1·4 는 *연산 복잡도*를 줄이고(hardware-agnostic), 2 는 *상수항*을 줄이며(여전히 큰 win, 선례 확실), 3·5 는 *패러다임*을 바꾼다(최고 상한, 최고 불확실성). EPW 가 dense-DFPT killer 라는 가설은 prior art 로 **확정**.

## reuse — cross-domain / cross-repo (g67/g68 정직 scope)

- **intra-repo (g67)**: `forge_dispatch_matmul`(CPU farr↔cuBLAS byte-eq) · NVPTX target(compiler/codegen/nvptx_target.hexa · WMMA · RFC 055/071) · cuda_rtc(self/ml/cuda_rtc.hexa · rtc_launch · PTX cache) · FFT(stdlib/signal fft3_real/ifft3 — cuFFT path 미존재, Lane A 항목). 측정 잣대 [[GPU-ROOFLINE]] (RTX 5070 · A100 roofline). GPU device-routing 선례 [[FLAME-PERF]] (CLM matmul→forge H100 실증).
- **cross-repo (g68)**: demiurge PWFORGE/QFORGE 캠페인(RTSC el-ph)이 이 엔진의 down-stream 소비자 — 가속은 거기서 wall-time·$ 로 실현됨. **honest scope**: 이 도메인은 hexa-lang stdlib/qforge 의 PROPOSAL 백로그일 뿐, demiurge 캠페인 코드는 건드리지 않음(d3 canonical home · d9 worktree isolation). 별도 QFORGE CaH6-run agent 활성 — stdlib/qforge edit 회피, 이 도메인은 docs-only.

## scope — 정직 (g6/g63)

이 보드의 모든 *구현* 항목은 **PROPOSAL/backlog** 이지 측정된 speedup 이 아니다. ⚡/🧮 closed 표시는 실 `hexa bench` roofline + Δ-vs-baseline 동반 시에만. **예외 — 이제 측정·박제된 것**: (1) CPU-scalar baseline 0.140 GFLOP/s (2) closed-form roofline 천장(fp64 139.88 · fp32 279.76 GFLOP/s) (3) 🟢 MEMORY-BOUND verdict — 셋 다 [[QFORGE-PERF.bench]] + `.verdicts/qforge-perf-roofline/`. 이게 모든 ⚡/🧮 항목의 Δ-baseline 분모이며, 구현 항목은 자기 `hexa bench` Δ 를 여기 게시할 때 비로소 closed. cross-val gate(d_qforge_engine): QFORGE vs QE λ·Tc 가 LaH10·CaH6·Li2MgH16 에서 g5-일치할 때 full migration. NOVEL kick probe(2026-06-01) verdict = skip(⚪ unverified proposals — g63 정직, fold 된 atom 없음).
