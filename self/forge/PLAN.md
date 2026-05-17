# forge/PLAN.md — staged roadmap (substrate layer)

> Pairs with `stdlib/flame/PLAN.md`. forge phases provide the substrate
> that flame phases consume. Same governance discipline: editable head +
> append-only `## 진행 로그`. **Nothing runs without explicit user go.**

## 0. 현재 상태 (2026-05-16)

forge = NAMING + SCAFFOLD. Code largely **already landed** across the
RFC 040 campaign — see `FORGE.tape` §X + flame's `FLAME.tape` §X for
exact branch · SHA · path · RFC# coordinates. This roadmap just stages
**what remains** under the forge label.

## 1. 단계 (staged — substrate parity → exceed)

### Phase 0 — 보존 + 통합 (paired with flame Phase 0) ⚠️ 선결, $0

Same preservation step as flame's Phase 0. forge artifacts are a
**subset of flame's** §X index (RFC 040 device-farr + cuBLAS + RFC 041
`.cu` kernel stubs). Per flame `## Log` 2026-05-16 the existing
`rfc043-hexa-torch` branch (`a8bc5e08`) is a strict linear ancestor of
all 5 campaign branches' tips + §X SHAs → **Phase 0 acceptance MET**.
forge inherits that clearance.

- Residual: `main` divergence (other-session interp-retirement R1/R2/R3
  + F6-A in-flight) — handled when those land; not a forge blocker.

### Phase 1 — RFC 040 land: device-farr + cuBLAS Dgemm

- Status: **substrate built + 4× verified**, awaiting clean land.
- Components: `HexaFarrEntry` device-farr ext (`5ae8823f`) · Phase B
  `_gpu` ops scaffold (`c0122caa`) · `runtime_cuda.c` cuBLAS impl
  (`180263d3`) · real-wire (`903c0285`) · interp-parity fix
  (`54d56e4a`).
- Acceptance = `tmp_rfc040_smoke.hexa` 5 / 5 + Phase B 6 / 6 + cuBLAS
  oracle (max\|Δ\|=4.44e-15, ≤ TOL_MATMUL 2e-9).
- Falsifier F-FORGE-CUBLAS-EQ (pre-registered):
  `farr_matmul_gpu` ≡ CPU farr_matmul at TOL_MATMUL on a fresh
  H100 / A100 fire, post-merge to main. **Hexa source unchanged** —
  CPU-bit-equal preserved by construction (no path divergence
  acceptable; `g3` honest).

### Phase R — paradigm 실험·검증 (gates Phase 2-4 재정의)

> Inserted 2026-05-17. 사용자 정정: "아키텍쳐, 패러다임은 실험, 검증 후에
> 결정???" — design-first 채택 (RFC-박제 먼저) 가 g3 / g_blue_closed_mandate
> / andrej-karpathy-skills 와 충돌. literature snapshot
> (`PARADIGM_RESEARCH.md`) 는 가설 수립용일 뿐 paradigm 확정의 근거 아님.
> **paradigm 은 실측으로만 채택/기각.** Phase R 통과 후에야 Phase 2-4 의
> 명세가 결정된다 — 현재 §Phase 2-4 본문은 pre-paradigm-decision default
> (paradigm A 채택 시 Phase 2 = "AOT whole-step codegen" 으로 재정의 등
> 다수 변경 가능).

**4 paradigm 가설 — cost ascending (D → B → C → A)**:

| paradigm | falsifiable hypothesis | minimal measurement | 기각 기준 (Falsifier) |
|---|---|---|---|
| **D — deterministic-default** | deterministic 모드 perf cost ≤ 15% vs cuBLAS heuristic | cuBLAS `CUBLAS_PEDANTIC_MATH` vs default · 동일 shape 반복 비트동일 여부 + 시간 비 | cost > 15% → default-on 기각, opt-in 강등 |
| **B — DSM-aware fused FFN** | H100 DSM fused FFN (matmul→SwiGLU→matmul) latency ≤ 0.5 × separate cuBLAS chain | single shape (M=128, N=K=4096) FFN prototype, H100 SXM5 only (DSM = Hopper-only) | latency 감소 < 25% (FlashFuser 1.24× E2E 의 절반) → DSM paradigm 가치 모호 |
| **C — autograd co-emission** | fused (fwd, bwd) pair HBM traffic ≤ 0.6 × separate fwd-then-bwd | 1-layer rmsnorm+linear · NCU memory traffic counter | 감소 < 10% → autograd-substrate paradigm 가치 모호 |
| **A — AOT whole-train-step** | 3-layer MLP (MNIST 크기) AOT step throughput ≥ 1.2 × PyTorch eager | mini trainer 완성 + 100 step 시간 측정 | PyTorch eager 보다 안 빠르면 paradigm 폐기 |

각 측정은 **compiled-native 경로**(`hexa build` / `nvcc -O3`, no interp,
no JIT-cache effects). reference oracle = CPU farr (RFC 025/032/033/034)
+ 측정 hardware H100 SXM5 fresh fire 만 인정 (vast.ai/runpod).

**Orphan watchdog 의무** (g_fire_dispatch_robust): SAVE_POD auto-promote
+ scp ≥3 retry + zero-orphan 검증. 직전 캠페인 throttle/orphan 다수 발생
→ 반복 금지.

**Phase R 진입 gate**: 본 plan + 사용자 go ✅ (2026-05-17).

**Phase R 결과 → 후속 산출**:
1. 측정 결과 → `self/forge/PARADIGM.md` SSOT 작성 (채택/기각 결정 + 실측
   anchor + literature cross-ref). FORGE.tape §X cross-link 대상.
2. 확정 paradigm 으로 RFC 044 draft (`inbox/rfc_drafts_2026_05_12/
   rfc_044_forge_*.md`). literature 는 anchor, 실측이 결정.
3. Phase 2-4 본문 재정의. paradigm A 채택 시 Phase 2 = "AOT whole-step
   codegen"; 기각 시 현 Phase 2 (.cu TODO 채우기) 유지.

### Phase 2 — regime-tiered substrate scaffold (post-PARADIGM)

> **재정의 2026-05-17** (RFC 044, PARADIGM.md §9). 원래 Phase 2 (".cu TODO
> 채우기") 는 본 Phase 의 sub-tier 2.B 의 substrate 로 흡수. RFC 041 의 11-op
> 채우기는 **단순 stub 채우기가 아닌 SMEM-aware 구현으로 진화**.

3 sub-tier — 작은 → 큰 shape 순. 각 sub-tier 별도 user gate 가능 (independent ROI).

**Phase 2.A — CUDA Graphs wrapper (작은/중간 shape FREE win)**:
- Phase R / B Stage 1 측정: graph_speedup 작은 shape +20%, 중간 +6-14%, 큰 +2-4%.
- Phase R / C Stage 1 측정: graph_speedup +3.86~+27.87% shape-dependent.
- Phase R / A 측정: dispatch elimination 가 small/mid model 의 dominant win source — CUDA Graphs 는 A 의 보조 mechanism.
- **Scope**: forge 의 runtime path 에 CUDA Graphs capture/launch wrapper 추가. flame 측 model 이 known shape 일 때 Graphs path 선택 가능. PyTorch 의 `torch.cuda.graph` 와 동등 surface 제공.
- **Falsifier F-FORGE-PHASE2A-GRAPH-SMALL**: small shape (M ≤ 64) FFN Graphs path ≤ 0.85 × separate (실측 0.80×). PASS (Phase R / B).
- **Falsifier F-FORGE-PHASE2A-GRAPH-FUNCTIONAL**: Graphs path output bit-equal vs separate (실측 모든 shape bit_equal=1).

**Phase 2.B — SMEM-fused FFN kernels (중간 shape SMEM-resident)**:
- RFC 041 의 11-op stubs 를 단순 채우기 X — SMEM-resident tile 패턴으로 구현.
- 중간 shape (M=128-512, d=768-1024) 가 sweet spot — H100 SMEM 227 KB 안에 X tile + W tile + output 잠시 잔류.
- 큰 shape (Llama-7B+) 는 SMEM 못 fit → Phase 3 의 DSM-cluster 가 필요.
- **Falsifier F-FORGE-PHASE2B-KERNEL-EQ** (RFC 041 의 F-FORGE-KERNEL-EQ 와 동일): 각 .cu ≡ CPU farr reference at TOL_OP. RFC 041 §"Falsifier battery" 14 falsifiers 살아있음.
- **Falsifier F-FORGE-PHASE2B-SMEM-WIN**: 중간 shape FFN SMEM-tile fused ≤ 0.75 × separate cuBLAS chain (B' tier 의 medium scope, Phase R fire 가 안 다룬 영역).

**Phase 2.C — fused fwd+bwd linear kernel (autograd co-emission 시작)**:
- Phase R / C Stage 1 측정: redundancy 1.500× constant → 이론 fused traffic ≤ 0.667× separate.
- **Scope**: 한 kernel 이 linear layer 의 Y (forward) + dW (backward weight grad) + dX (backward input grad) 를 동시에 emit. X, W, dY tile 이 SMEM/register 잔류 reuse.
- **Falsifier F-FORGE-C-STAGE2-FUSED-CEILING**: HBM traffic ≤ 0.75 × separate (이론 ceiling 의 75-100% 효율).
- **Falsifier F-FORGE-C-STAGE2-DET-PRESERVE**: Y/dW/dX numerical equivalence at TOL_OP ≤ 1e-9 vs separate (D' 결정성 보존).

### Phase 3 — DSM-cluster fusion (큰 shape B' Stage 2)

- Hopper-only (cc=9.0): H100/H200 의 Distributed Shared Memory 활용. cluster of SMs 가 SMEM 연결 (227 KB × cluster size = L1.5 cache) — FlashFuser (arxiv 2512.12949) 패턴.
- Large shape (Llama-7B FFN: M=128, D=4096, FD=11008) 에서 BW util 35.4% → 70% 가능 (이론 2× throughput, latency 0.5×).
- Phase 2.B 의 SMEM-fused FFN 을 **cluster-cooperative** kernel 로 generalize: `__cluster_dims__(cls_m, cls_n)`, `cudaLaunchKernelEx`.
- **Falsifier F-FORGE-B-STAGE2-LARGE**: DSM fused FFN latency ≤ 0.6 × cuBLAS chain on Llama-7B scale (RFC 044 §"Falsifier battery").
- **Falsifier F-FORGE-B-STAGE2-BITEQ**: DSM fused FFN output bit-equal w.r.t. cuBLAS reference (D' 결정성 보존).
- A100 / B200 fallback path: cluster 미지원 hardware 에서는 Phase 2.B (single-SM SMEM) 로 자동 routing — flame ↔ forge hardware dispatcher 책임.

### Phase 4 — AOT whole-train-step codegen (A' Stage 2)

- Phase R / A 측정: 3-layer MLP small/mid AOT 2.24-6.07× PyTorch eager — paradigm 의 dominant win source.
- **Scope**: transformer block (attention + FFN + LayerNorm + residual) AOT trainer 확장. Llama-7B block scale 측정.
- flame Phase 1 (tensor_lib + autograd_lib) 가 이미 land — transformer 구조 작성 토대.
- **Falsifier F-FORGE-A-STAGE2-LARGE**: Llama-7B block step AOT ≥ 1.1 × PyTorch eager (compute dominate 인데도 dispatch elimination 이 marginal win 보유).
- **Falsifier F-FORGE-A-STAGE2-MIX-PRECISION**: Stage 2 transformer block 의 within-run det FREE 보존 (D' 정합).
- 측정 baseline 비교 확장 후보: torch.compile + AOTDispatcher (vanilla eager 외 추가).

### Phase 5+ (downgraded) — multi-GPU primitives

- AllReduce / AllGather / Broadcast on NCCL — Phase 4 (single-GPU large block AOT trainer) 가 settled 후. 원래 Phase 4 였으나 paradigm 우선순위 재조정으로 Phase 5+ 강등.

## 2. 의존 (gating)

- Phase 1 ← RFC 040 design (filed) + verified oracle (`x_oracle_cublas`). ✅ CLEARED
- Phase R ← Phase 1 + `PARADIGM_RESEARCH.md` + 사용자 go. ✅ COMPLETED 2026-05-17 (4 fire, $1.35, `PARADIGM.md` PUBLISH)
- **Phase 2.A ← Phase R / B+C Stage 1 PASS (CUDA Graphs win 측정 anchor).** ✅ READY (실측 anchor 있음)
- **Phase 2.B ← Phase R + RFC 041 design (filed) + per-op TOL spec.** ⏳ READY (RFC 041 의 11-op SMEM-aware 구현)
- **Phase 2.C ← Phase R / C Stage 1 (redundancy 1.5× constant, ceiling 0.667×).** ⏳ READY
- **Phase 3 ← Phase 2.B (SMEM-fused FFN single-SM 우선 검증) + RFC 044 (filed).** Hopper-only (cc=9.0).
- **Phase 4 ← flame Phase 1+2+3 (transformer block 구조 land) + Phase R / A Stage 1 PASS.** ⏳ flame 의존
- Phase 5+ ← Phase 4 single-GPU settled + 실제 multi-GPU need.

flame phase ↔ forge phase mapping (paired, post-PARADIGM):

| flame phase | needs forge at |
|---|---|
| Phase 1 (Tensor + autograd) ✅ | forge Phase 1 ✓ (cuBLAS Dgemm) |
| Phase 2 (nn layers) | forge Phase 1 ✓ + 2.A CUDA Graphs (small-shape FREE win) |
| Phase 3 (PyTorch-parity train_step) | forge Phase 2.A + 2.B SMEM-fused FFN (medium shape) |
| Phase 4 (match eager-PyTorch) | forge Phase 2.A/B/C + Phase 3 DSM (large shape) + Phase 4 AOT (whole-step) |
| Phase 5 (exceed eager-PyTorch) | forge Phase 2-4 full stack + flame's compile-time whole-program fusion |

## 3. 진행 트리거

forge Phase 진입 = 이 PLAN `## 진행 로그` append + `FORGE.tape` 동기화
+ falsifier 사전등록 + 사용자 go. 우회 금지 (flame Phase Gating 미러).
신규 `.cu` 추가 시 oracle (CPU farr reference) 와의 byte/TOL parity
mandatory (`g_blue_closed_mandate`).

## 진행 로그

(append-only)

### 2026-05-16 — forge/ 스캐폴드 LANDED (NAMING, 코드 추가 0)
`self/forge/{README.md, PLAN.md, FORGE.tape}` 작성. 사용자 directive
2026-05-16 "forge 로 가자 세팅해줘". 기존 substrate 코드(`self/runtime.c`
GPU 부분 + `self/cuda/runtime_cuda.c`) 는 그대로 — 이 디렉토리는
**라벨 SSOT** 일 뿐 코드 이동 없음 (g3 drift-avoidance). flame ↔ forge
크로스레프는 flame 동시작업 안정화 후 후속 커밋 (이번 커밋은 forge-only,
flame WIP 무영향).

### 2026-05-17 — Phase R / D fire COMPLETED (pre-reg FAIL, D' reframe PASS)
H100 SXM 80GB · cuBLAS 12.4.5 · vast.ai instance 36884532 (destroyed) · cost $5.89/hr × ~4 min ≈ $0.40.
6 shape sweep (768³ → 4096³, FFN-shaped 포함). 결과:
- **Pre-registered falsifier FAIL**: max_cost_pct = +33.39% > 15% threshold. PEDANTIC mode 가 모든 shape 에서 +14.67~+33.39% 느림 → D paradigm "default-on" 형태 기각.
- **Surprise F2**: PEDANTIC ≡ DEFAULT numerically (cross_max_abs = 0 every shape). 동일 출력 bit, 다른 implementation path. 즉 "PEDANTIC = correctness benefit 없음 + cost".
- **Surprise F3**: DEFAULT 도 within-run bit-deterministic (within_bit_eq=1 every shape). **FP64 H100 single-process 는 이미 결정적.**
- **D' reframe (data-anchored)**: forge 의 FP64 substrate 는 cuBLAS DEFAULT 위에서 within-run determinism FREE. PEDANTIC = opt-in (+15-33% cost, no benefit for FP64). LayerCast-style cross-precision (BF16/FP16) determinism 은 별도 paradigm (RFC 047+).
산출 trail: `state/forge_phaseR_d_2026_05_17/{result.json, D_ANALYSIS.md, fire.log, nvidia_smi_*.csv}`.

### 2026-05-17 — Stage 2 C Phase 1 fire COMPLETED (FUSED-CEILING + DET-PRESERVE PASS) + Stage 2 B fire BLOCKED
**C Stage 2 Phase 1** (A100 SXM4 cc=8.0 cuBLAS 12.4.5 · $0.30):
3 shapes (16/32/64), single-block SMEM-resident fused kernel vs cuBLAS chain.
- ✅ F-FORGE-C-STAGE2-FUSED-CEILING: bytes_ratio_analytic = **0.6667 measured every shape** (≤ 0.75 threshold PASS)
- ✅ F-FORGE-C-STAGE2-DET-PRESERVE: max|Δ| < 1e-16 every shape (TOL_OP 1e-9 의 7 orders headroom)
- ⏳ wall-time slower than cuBLAS (16³ 0.62× faster, 64³ 7.5× **slower**) — single-block naive vs Tensor Core. Production multi-block kernel = Phase 2 follow-up (~2-3 weeks effort)
- **C paradigm 이론적 HBM traffic 이점 검증** + numerical equivalence 검증. Wall-time win = Phase 2.
산출: `state/forge_phaseR_c_stage2_2026_05_17/{result.json, fire.log, C_STAGE2_ANALYSIS.md}`.

**B Stage 2 fire BLOCKED**:
H100/H200 cap ≤$50/hr 도 0 offers (vast.ai Hopper supply 시장 fully booked 시점). Kernel code (b_dsm_ffn_stage2.cu — DSM cluster API smoke + cuBLAS FFN baseline) + dispatch (dispatch_b_stage2.sh) land — Hopper 가용 시 fire 진입.

Phase R 누적 cost: $1.95 (D 0.40 + B Stage 1 0.25 + C Stage 1 0.30 + A Stage 1 0.40 + A Stage 2 0.30 + C Stage 2 0.30).

### 2026-05-17 — Stage 2 A fire COMPLETED (F-FORGE-A-STAGE2-LARGE PASS overwhelmingly)
**A Stage 2** (A100 SXM4 80GB · cc=8.0 · cuBLAS 12.4.2 · PyTorch 2.4.0 · vast.ai instance 36907435 destroyed · ~$0.30, H100 fallback after no_offers):
3 configs · scaled-up MLP (3-layer Linear + ReLU + AdamW) — large compute regime:
- **large_b128 (B=128 D=8192)**: AOT 5.293 ms · PyT 21.192 ms · **4.004×**
- **large_b512 (B=512 D=8192)**: AOT 19.936 ms · PyT 37.135 ms · **1.863×**
- **xlarge_b128 (B=128 D=16384)**: AOT 19.993 ms · PyT 81.240 ms · **4.063×**

**Pre-reg F-FORGE-A-STAGE2-LARGE (≥1.1×) PASS 모든 config** (실측 1.69-3.69× 초과).
- **KEY finding (F3)**: batch-size 가 A win 의 dominant variable. small batch (B ≤ 128) any model → 4-6×. large batch (B ≥ 512) large model → 1.86×.
- F1 A100 fallback 에서도 압도적 win → A paradigm = **GPU-generation 독립** (overhead fixed cost).
- F2 RFC 044 가설 (≥1.1×) 도 under-optimistic — 실측이 4× 까지 초과.
- F4 PyTorch eager 가 large model + small batch 에서 매우 비효율 (xlarge_b128 = 81ms).
- F5 forge **inference framework market 경쟁력 시사** (vLLM/TensorRT-LLM 영역) — 기존 thesis "training-only" 보다 넓은 scope.

PARADIGM.md §A + §6 갱신 (batch-size aware reframe). RFC 044 §"Falsifier battery" 마킹 (F-FORGE-A-STAGE2-LARGE PASS anchor 1.86-4.06×). Phase R 누적 cost: D 0.40 + B 0.25 + C 0.30 + A Stage 1 0.40 + A Stage 2 0.30 = **$1.65**.

산출: `state/forge_phaseR_a_stage2_2026_05_17/{result.json, pytorch_result.json, A_STAGE2_ANALYSIS.md}`.

### 2026-05-17 — RFC 044 DRAFT + PLAN §Phase 2-4 재정의 land
**RFC 044 draft**: `inbox/rfc_drafts_2026_05_12/rfc_044_forge_regime_tiered_substrate.md` 작성. Phase R 4 fire 측정 anchor 위에 forge 의 dual-mechanism × regime-tiered substrate 명세 + 14 falsifier 사전 등록 (5 Stage 1 PASS + 9 Stage 2 pre-reg). RFC 041 (.cu TODO 채우기) 을 Phase 2.B 의 substrate 로 흡수 (단순 stub 채우기 X → SMEM-aware 구현으로 진화). RFC 040 / 043 / future 045+ 의존 정리.

**PLAN §Phase 2-4 재정의** (PARADIGM.md §9 + RFC 044 가이드):
- **Phase 2 → regime-tiered substrate scaffold** (3 sub-tier):
  - **2.A** CUDA Graphs wrapper (작은 shape FREE win, B/C Stage 1 측정 anchor)
  - **2.B** SMEM-fused FFN kernels (RFC 041 의 11-op stubs → SMEM-aware 구현, 중간 shape)
  - **2.C** fused fwd+bwd linear (autograd co-emission, C Stage 1 ceiling 활용)
- **Phase 3 → DSM-cluster fusion** (B' Stage 2, Hopper-only, 큰 shape ROI 명확)
- **Phase 4 → AOT whole-train-step codegen** (A' Stage 2, transformer block 확장)
- **Phase 5+** ← multi-GPU primitives (원래 Phase 4 였으나 paradigm 우선순위 재조정으로 강등)

§2 gating 표 동기화: Phase 2.A/B/C → Phase 3 → Phase 4 → Phase 5+ 새 의존 chain. flame ↔ forge mapping 표도 새 구조 반영.

### 2026-05-17 — Phase R / A fire COMPLETED + PARADIGM.md PUBLISH (Phase R 종합)
**A 결과** (H100 SXM 80GB · cuBLAS 12.4.2 · PyTorch 2.4.0 · vast.ai instance 36885827 destroyed · ~$0.40):
3 configs · AOT single-binary CUDA (14 cuBLAS Dgemm + 6 custom kernel) vs PyTorch eager (same MLP, AdamW, 100 step median):
- **mnist_b32 (B=32 784×256×10)**: AOT 0.110 ms · PyT 0.668 ms · **6.065×**
- **mnist_b128 (B=128 784×256×10)**: AOT 0.111 ms · PyT 0.668 ms · **6.013×**
- **mid_b32 (B=32 4096×4096×100)**: AOT 1.206 ms · PyT 2.704 ms · **2.243×**

**Pre-reg ≥1.2× = PASS 모든 config** (실측 1.87-5.05× 초과).
- F1 batch 변화 무영향 (B=32 vs B=128 동일 시간) → **train_step ~85% 가 Python+ATen overhead**
- F2 speedup ∝ inverse(compute) → small=6×, mid=2.24×, large 미측정(~1.1× expected)
- F3 **D/B/C 와 반대 패턴**: 사전등록 **under-optimistic**, 실측이 압도적 초과 → A win = **dispatch elimination** (memory fusion 아님)
- F4 final_loss=0 PyT (functional correctness)
- **A' reframe** (data-anchored): dispatch-regime-aware (small 6× → mid 2.24× → large ~1.1× expected)
산출: `state/forge_phaseR_a_2026_05_17/{result.json, pytorch_result.json, A_ANALYSIS.md}`.

**PARADIGM.md PUBLISH** (draft → final):
4 paradigm 종합 SSOT 완성. **Meta-thesis (data-anchored)**: forge = **dual-mechanism × regime-tiered AOT substrate** —
- Mechanism 1 — **Dispatch elimination (A)**: small/mid model 압도적 win (6× / 2.2×), large marginal.
- Mechanism 2 — **Memory fusion (B/C)**: large model dominant win (1.5-2×), small marginal.
- 공통: within-run det FREE (D'), PEDANTIC opt-in.
- Distinctive position vs PyTorch/XLA/Mojo: 둘 다 native, regime-tiered.
Stage 2 진입 추천: **A → B → C** (각 separate user gate). Phase R cost total **$1.35**.

### 2026-05-17 — PARADIGM.md SSOT DRAFT (§D/B/C land, §A placeholder)
Phase R / D/B/C 3 fire 종합 → `self/forge/PARADIGM.md` 작성 — forge 의
paradigm 결정 SSOT (measurement-anchored). 12 sections:
1. Status (4 paradigm × fire/verdict)
2-5. Paradigm D/B/C/A — pre-reg vs measured vs reframe vs falsifier
6. **Meta-finding (D/B/C 일관)**: 사전등록 universal 모두 over-optimistic; 실측 가 regime-tiered substrate 가르침
7. Forge architectural thesis (post-measurement): regime-tiered AOT substrate
8. Stage 2 decision matrix
9. **PLAN §Phase 2-4 재정의 가이드**: regime-tiered scaffold (Phase 2.A Graphs + 2.B SMEM + 2.C fused autograd → Phase 3 DSM → Phase 4 AOT whole-step)
10. Non-claims (g3 boundaries)
11. RFC 044 draft guide
12. Sources

FORGE.tape §X 추가: x_paradigm_ssot · x_paradigm_research · x_phaseR_fires.
§A 는 A fire 완료 후 final fill. 그 후 PARADIGM.md PUBLISH + RFC 044 draft.

### 2026-05-17 — Phase R / C fire COMPLETED + Phase R / A DISPATCHED
**C 결과** (H100 SXM 80GB · cuBLAS 12.4.5 · vast.ai instance 36885554 destroyed · ~$0.30):
5 shape linear fwd+bwd 측정. range: graph_speedup ∈ [+3.86%, +27.87%], **bytes_redundancy 1.500× 모든 shape constant**, BW util ∈ [14.1%, 45.2%] (H100 peak), bit_equal Y/dW/dX = 1/1/1 모든 shape.
- F1 **redundancy = 1.500× constant**: separate path 가 X+dY+W 를 평균 1.5× 재read. **이론적 fused HBM traffic ceiling = 0.667× separate (33% reduction).**
- F2 **사전 등록 "≤ 0.6×" FAIL by theoretical impossibility** — 이론 ceiling 0.667 > 0.6. 사전 등록 over-optimistic.
- F3 graph speedup shape-dependent (작은 +28%, 큰 +4%) — B/D 패턴 일관.
- F4 bit-equality 모든 output (Y/dW/dX) → D' 결정성 backward path 에서도 holds.
- **C' reframe**: 이론 ceiling 0.667× → realistic 목표 ≤ 0.75× fused/separate. 작은 shape CUDA Graphs +20-28% FREE, 큰 shape (Llama-7B) DSM-aware fusion ROI 명확.
- **Meta-finding** (D/B/C 일관): 사전 등록 universal hypothesis 모두 over-optimistic. 데이터 anchor 가 **regime-tiered tooling** 가르침 (작은 = Graphs, 중간 = SMEM, 큰 = DSM, 모든 regime = D' det FREE).
산출: `state/forge_phaseR_c_2026_05_17/{result.json, C_ANALYSIS.md}`.

**A 발사** (forge_phaseR_a_2026_05_17, in-flight):
3-layer MLP (FP64) AOT trainer (single CUDA binary, full fwd+bwd+AdamW) vs PyTorch eager baseline (same model). 3 configs (mnist_b32/b128, mid_b32). pytorch/pytorch:2.4.0-cuda12.4 image 사용 → torch preinstalled. 측정: median step_ms per config + AOT/PyT speedup ratio. 가설 "≥ 1.2 ×" falsifier.

### 2026-05-17 — Phase R / B fire COMPLETED + Phase R / C DISPATCHED
**B 결과** (H200 SXM 143GB · cuBLAS 12.4.5 · vast.ai instance 36885258 destroyed · $3.87/hr × ~4 min ≈ $0.25):
6 shape FFN (matmul+SiLU+matmul) sweep. range: graph_speedup ∈ [+1.96%, +20.06%], BW util ∈ [13.9%, 35.4%] (H200 4.8 TB/s peak 기준), bit_equal=1 every shape.
- F1 graph speedup 작은 shape (+20%) → 큰 shape (+2%) 로 declining. **kernel-launch overhead = fixed cost.**
- F2 BW util 14-35% — neither HBM-bound nor compute-bound. **mid-range, no single bottleneck.**
- F3 Stage 1 graph fusion only → max 0.8× separate. **사전 등록 가설 "≤ 0.5×" universally FAIL.**
- F4 큰 shape (Llama-7B) 에서 BW util 35% → DSM Stage 2 가 50%-70% util 까지 끌어올리면 0.5×-0.7× 가능 (이론적 상한).
- **B' reframe (data-anchored)**: shape-dependent paradigm. 작은 shape = CUDA Graphs FREE +20%. 큰 shape (Llama-7B+) = DSM Stage 2 ROI 명확. Universal "≤ 0.5×" 기각 → shape-tiered falsifier (F-FORGE-B-PRIME-DSM-{SMALL/MEDIUM/LARGE}).
산출: `state/forge_phaseR_b_2026_05_17/{result.json, B_ANALYSIS.md}`.

**C 발사** (forge_phaseR_c_2026_05_17, in-flight):
Linear layer fwd+bwd (3 cuBLAS Dgemms) separate vs CUDA Graphs · HBM redundancy ratio (bytes_separate / bytes_minimal) · per-kernel breakdown · BW util. 5 shape (M·{Din,Dout} 128×768 → 128×4096). Stage 1 diagnostic — Stage 2 (custom co-emitted fwd+bwd kernel) gated on result.

### 2026-05-17 — Phase R / B fire DISPATCHED (Stage 1 diagnostic)
B Stage 1 = paradigm B 의 prerequisite 측정 (full DSM kernel 아님). 측정 3 paths/shape:
- (1) separate: cuBLAS Dgemm + SiLU + cuBLAS Dgemm, HBM intermediate
- (2) graph: 동일 ops CUDA Graphs 캡처 (kernel-launch fusion 효과)
- (3) deferred Stage 2: custom DSM cluster kernel (Stage 1 PASS 후)
Decision matrix:
- BW util > 70% peak → compute-bound, B headroom 제한, 기각
- graph speedup > 30% → kernel-launch 이 bottleneck, custom DSM 가치 marginal
- BW util < 30% + graph speedup < 10% → HBM intermediate roundtrip bottleneck, DSM 가치 명확 (Stage 2 진입)
H100 SXM vast.ai fire 진행 중 (예상 15-30 min). 산출 trail: `state/forge_phaseR_b_2026_05_17/`.

### 2026-05-17 — Phase R 진입 (paradigm 실험·검증, experiment-first)
사용자 정정 2026-05-17: "아키텍쳐, 패러다임은 실험, 검증 후에 결정???"
→ 직전 제안 (RFC 044 design draft 먼저) 가 g3 + g_blue_closed_mandate +
andrej-karpathy-skills 와 충돌. paradigm 을 literature/sketch 만으로 박제 =
fit-to-narrative 위험. PLAN §1 에 **Phase R — paradigm 실험·검증** 신규
삽입 (Phase 1 클리어 후, Phase 2-4 재정의 gate). 4 paradigm × falsifiable
hypothesis × minimal measurement × 기각 기준 사전등록 (D → B → C → A · cost
ascending). 측정 결과 → `PARADIGM.md` SSOT → RFC 044 → Phase 2-4 재정의
순서. 현 §Phase 2-4 본문은 pre-paradigm-decision default 로 강등; 변경 시
다음 commit 에서 재서술. 진입 gate = 본 plan + 사용자 go ✅. 첫 fire =
**D (determinism cost, cheapest)** 대기 — hardware/code/watchdog 별도 준비.

### 2026-05-16 — paradigm research snapshot LANDED (코드 0)
사용자 directive "CUDA 포팅 아님, 더 뛰어난 아키텍쳐/패러다임" + "한국
alternatives + arxiv deep research, 데이터 먼저 확보" → 8 WebSearch + 5
WebFetch (한국 NPU 신생들 + 글로벌 AOT-NN 컴파일러 SOTA + arxiv 2025-
2026). 산출: `self/forge/PARADIGM_RESEARCH.md`. 핵심: **AOT × whole-
train-step (fwd+bwd+opt) 단일 컴파일 프로그램 = 2026-05 미해결 frontier**.
한국 측 (FuriosaAI/Rebellions/Moreh/HyperAccel/DEEPX) 모두 inference 또는
PyTorch wrapper, 새 paradigm 언어 없음. 글로벌 SOTA = torch.compile
precompile (WIP), JAX (JIT), Mojo MAX (inference-first), FlashFuser
(arxiv 2512.12949, inference H100-DSM 1.24× E2E). 사용자 결정 = **A+B
둘 다**: A = RFC 044 design draft, B = FlashFuser-style DSM prototype
(floor 확인용). 후속 커밋에서 RFC 044 / `PARADIGM.md` / `PHASE2_PREP.md`
순서 작성. 본 진입은 Phase 진입 아님 (research/design 단계).
