# forge/PLAN.md — staged roadmap (substrate layer)

> Pairs with `stdlib/flame/PLAN.md`. forge phases provide the substrate
> that flame phases consume. Same governance discipline: editable head +
> append-only `## 진행 로그`. **Nothing runs without explicit user go.**

## 0. 현재 상태 (2026-05-19 — forge 일단완성 milestone)

forge = **SUBSTRATE-VERIFIED + PARADIGM-ANCHORED + ABI-LANDED**. 기존 plan
의 정의된 범위 내에서 coherent 완성 milestone 도달 — 잔여는 모두
multi-week Stage 2 GPU 캠페인 (§0.1, 별도 user-gated).

**완성된 것 (measured, 이 milestone)**:

| 축 | 상태 | 근거 |
|---|---|---|
| **Phase 1 substrate** | ✅ verified | RFC 040 device-farr + cuBLAS Dgemm, 4× 검증 (max\|Δ\|=4.44e-15) · RFC 041 11-op `.cu` 커널 |
| **Phase R paradigm 탐색** | ✅ closed | 14 fire $2.91 — D'/A/B/C 측정 verdict (`PARADIGM.md`). FP64 substrate ceiling 실험적 bound, BF16(RFC 049) = wall path 검증 (9.67× FP64 cuBLAS @ Llama-7B FFN) |
| **RFC 050 v1 ABI** | ✅ Stage A LANDED | `self/forge/forge_tier_v1.{h,c}` — flame↔forge dispatch surface, runtime.c 통합, smoke 10/10 PASS (2026-05-19) |
| **RFC 060 new-paradigm** | ✅ 100% closure | 3 falsifier measured — mega-kernel FP64 KILL (1.8-4.4× slower), poly-feasible PASS, verified-chain downgrade. CUDA kernel-per-op 돌파는 FP64 에서 measured-falsified, BF16 substrate 로 measured-deferred |
| **endgame 문서화** | ✅ | RFC 055 (hexa→NVPTX) = Phase 6 long-arc. `@D g_forge_endgame_hexa_native` |

**META-FINDING (Phase R + RFC 060 통합)**: forge 의 measured wall path =
**BF16 Tensor Core** (RFC 049). FP64 substrate 는 두 번 측정으로 ceiling
확인 — (1) Phase R: FP64 hand-kernel 200-300× slower, (2) RFC 060: FP64
mega-kernel 1.8-4.4× slower. dispatch elimination 은 unique 하지 않음
(CUDA graphs 동등). True forge distinctive = BF16 TC substrate quality +
within-run det FREE (D').

**잔여 = 전부 multi-week Stage 2 (§0.1)**. forge 의 "일단완성" 은
substrate + paradigm + ABI surface 가 coherent 하게 닫혔다는 뜻 — 추가
성능은 BF16 production 캠페인 (RFC 049 Stage 2) 의 별도 cycle.

**SSOT**: [`PARADIGM.md`](PARADIGM.md) §1 (CUDA-paradigm 측정표) ·
[`PARADIGM_C_RESEARCH.md`](PARADIGM_C_RESEARCH.md) (new-paradigm 측정) ·
[`FORGE.tape`](FORGE.tape) §X cross-link · `state/forge_rfc060_2026_05_19/`
(RFC 060 측정 trail, gitignored).

## 0.1 다음 progression 영역 (post-milestone, multi-week multi-team)

| Phase | Scope | Effort | Gate |
|---|---|---|---|
| **RFC 049 Phase R' Stage 2** | Production BF16 kernels (DSM + WMMA combined, sm_90 Hopper). Llama-7B full FFN BF16 fused single-kernel + numerical validation at scale | 2-4 weeks | user (cost-bearing fire campaign) |
| **RFC 050 Stage 2** | v1 ABI Stage A 는 LANDED (2026-05-19, `forge_tier_v1.{h,c}`). Stage 2 = specialized tier kernel 등록 + flame Phase 4-C lowering 이 dispatch site emit. 7 falsifier 검증 | 2-3 weeks | flame session 협력 |
| **RFC 060 ∩ RFC 049 — BF16-TC mega-kernel** | RFC 060 closure 가 가리킨 곳 — mega-kernel 실행 모델 + BF16 Tensor Core. FP64 mega-kernel 은 measured-killed; BF16 substrate 에서 in-kernel GEMM 이 vendor lib 와 경쟁 가능 (literature Mirage/Stanford 전부 BF16) | 2-4 weeks | RFC 049 Stage 2 land 후 |
| **C Phase 4 CUTLASS-grade** | FP64 production tiling (close hand-WMMA 43% → cuBLAS 87% gap). 별도 effort, RFC 049 보다 ROI 작음 | 3-6 weeks | low priority post-RFC 049 |
| **A Phase 3 torch.compile-equivalent** | torch.compile reduce-overhead = CUDA graphs 동등 path. AOT가 진정 win 하려면 custom kernel quality 가 dispatch elim 보다 dominant 해야 | Open scope | RFC 049 land 후 재평가 |
| **flame Phase 4-D GPU dispatch land** | flame 측 책임, forge 의 RFC 050 dispatch API 통해 BF16 kernel 호출 | flame session 진행 중 | flame 세션 직접 |

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

### RFC 060 exploration track — new compute paradigm (CUDA kernel-per-op 돌파)

> **Goal (user 2026-05-19)**: new paradigm 으로 CUDA 성능·자원·속도
> 돌파 — 100% closure (measured). Phase 6 (hexa-native) 와 직교 —
> RFC 055 = "forge in hexa", RFC 060 = "forge breaks kernel-per-op".
> 합집합 = hexa-native mega-kernel.

- **paradigm under test**: mega-kernel 실행 모델 — train step 전체를
  단일 persistent GPU kernel + in-kernel scheduler 로 컴파일, host
  kernel-stream 제거 (per-op launch + per-op HBM round-trip 둘 다
  제거). research SSOT = `PARADIGM_C_RESEARCH.md`, RFC = RFC 060.
- **method under test**: verified rewrite-chain codegen (Exo-style) —
  forge codegen 을 atlas-law-cited equivalence-preserving rewrite
  chain 으로. strict-lint stage 7/8 와 직결.

| Step | Scope | Gate | Cost |
|---|---|---|---|
| RFC 060-A | F-RFC060-VERIFIED-CHAIN paper test (1 FFN kernel → rewrite chain) | $0, no GPU | ~$0 |
| RFC 060-B | F-RFC060-POLY-FEASIBLE feasibility (1 block → isl/Pluto/Tempo) | $0, no GPU | ~$0 |
| RFC 060-C | F-RFC060-MEGAKERNEL-WALL cheap test (forward-only persistent kernel) | 1 H100 fire | ~$0.40 |
| RFC 060-D | full training-step mega-kernel (fwd+bwd+opt) — RFC 060-C ≥ 1.1× 시에만 | user gate | multi-fire |

- A·B 는 $0 — 즉시 가능. C 는 Phase-R 단위 fire 1발. D 는 C 게이트.
- "100% closure" = A/B/C 전부 resolved (pass-and-proceed 또는
  measured-kill). 측정된 kill 도 closure (g3 — RFC 060 §8.6).

### Phase 6 (endgame, long-arc) — forge becomes hexa-native (RFC 055)

> **forge 의 최종 형태는 hexa-native 다.** 현재 C/CUDA substrate 는
> *과도기* — hexa-lang 에 GPU codegen target 이 없어서 C/CUDA 가 GPU
> 커널을 산출하는 *유일한* 경로이기 때문. `AGENTS.tape §3 @D g5`
> (hexa-native-only) 의 GPU lane closure 가 곧 forge 의 closure.

- **seam**: RFC 055 — hexa-src → NVPTX codegen backend
  (`inbox/rfc_drafts_2026_05_12/rfc_055_hexa_nvptx_codegen_backend.md`,
  design draft 2026-05-17). deliverable 은 `compiler/codegen/nvptx_*.hexa`
  (arm64_darwin.hexa / x86_64_linux.hexa 의 sibling target) — **forge 가
  아니라 compiler 도메인**. forge 는 그 capability 의 *소비자*.
- **transition**: RFC 055 backend 가 충분한 kernel coverage 를 확보하면
  `self/cuda/runtime_cuda.c` 의 `.cu` 커널이 `.hexa` 로 재유도됨 (여전히
  `self/forge/` 아래 — `g_forge_substrate_role` 의 *디렉토리* 경계는
  유지, *언어*만 flip). cuBLAS Dgemm 은 raw-GEMM fallback 으로 잔존
  (vendor-library win, hexa-native 가 추월 비목표).
- **ABI 안정성**: RFC 050 `_v1` 표면이 transition 의 stable surface —
  flame source 는 커널이 C/CUDA → hexa-emitted PTX 로 바뀌어도
  재컴파일 불요 (same dispatch, different substrate).
- **honest scope (g3)**: P2 — 어떤 현재 shipping fire 도 막지 않음.
  forge Phase R (C Stage 2 Phase 3, hand-WMMA 41-43% TC peak) 가
  hexa-emitted 커널이 *correct* 함은 anchor 하지만 cuBLAS raw-GEMM
  throughput 추월은 비목표 (CUTLASS-급 tuning = multi-week). 닫는
  조건 = RFC 055 backend 가 forge 측정 oracle 무회귀 substitute 가능
  (`g_blue_closed_mandate`).
- **gate**: Phase 6 ← RFC 055 land (compiler 도메인) + forge 측정
  oracle 재현 battery. flame/forge 의 현재 critical chain 과 독립.

## 2. 의존 (gating)

- Phase 1 ← RFC 040 design (filed) + verified oracle (`x_oracle_cublas`). ✅ CLEARED
- Phase R ← Phase 1 + `PARADIGM_RESEARCH.md` + 사용자 go. ✅ COMPLETED 2026-05-17 (4 fire, $1.35, `PARADIGM.md` PUBLISH)
- **Phase 2.A ← Phase R / B+C Stage 1 PASS (CUDA Graphs win 측정 anchor).** ✅ READY (실측 anchor 있음)
- **Phase 2.B ← Phase R + RFC 041 design (filed) + per-op TOL spec.** ⏳ READY (RFC 041 의 11-op SMEM-aware 구현)
- **Phase 2.C ← Phase R / C Stage 1 (redundancy 1.5× constant, ceiling 0.667×).** ⏳ READY
- **Phase 3 ← Phase 2.B (SMEM-fused FFN single-SM 우선 검증) + RFC 044 (filed).** Hopper-only (cc=9.0).
- **Phase 4 ← flame Phase 1+2+3 (transformer block 구조 land) + Phase R / A Stage 1 PASS.** ⏳ flame 의존
- Phase 5+ ← Phase 4 single-GPU settled + 실제 multi-GPU need.
- **Phase 6 (endgame) ← RFC 055 land (compiler 도메인, hexa-src→NVPTX) + forge 측정 oracle 재현 battery.** 현재 critical chain 과 독립 (P2).

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

### 2026-05-19 — forge 일단완성 milestone 선언 (기존 plan 범위 내 coherent closure)

User directive "기존 plan 으로 forge 일단완성". §0 현재 상태를 2026-05-17 (stale) → 2026-05-19 milestone 스냅샷으로 갱신. forge 가 기존 PLAN 의 정의된 범위 내에서 coherent 완성점 도달함을 명문화 — substrate(Phase 1 verified) + paradigm(Phase R closed + RFC 060 new-paradigm 100% closure) + integration ABI(RFC 050 v1 Stage A landed) 3축이 닫힘. 잔여는 전부 multi-week Stage 2 GPU 캠페인 (§0.1) — 별도 user-gated cycle. README.md + FORGE.tape status 줄 동기화. 측정 변화 0 — 상태 문서 consolidation. "일단완성" = 추가 성능(BF16 production) 은 RFC 049 Stage 2 의 별도 cycle 이라는 honest 경계 설정.

### 2026-05-19 — RFC 060 falsifier 측정 — 100% closure (mega-kernel FP64 KILL, poly PASS, verified-chain downgrade)

RFC 060 의 3 falsifier 를 정초 당일 전부 측정 (user goal: "new paradigm 으로 CUDA 성능·자원·속도 돌파 — 100% closure measured"). 측정 SSOT = `state/forge_rfc060_2026_05_19/RFC060_FALSIFIER_RESULTS.md` (gitignored, Phase-R convention).

- **F-RFC060-POLY-FEASIBLE — PASS** ($0, isl). `tool/forge_rfc060b_poly_feasible.c` — transformer-block FFN+RMSNorm loop nest (5 statement) 의 affine schedule 을 libisl 이 0.0114s 에 계산 (gate <1s, 88× 여유), normalize 를 matmul-1 에 fuse 까지. whole-step polyhedral 은 feasible — 장기 연구방향 생존.
- **F-RFC060-VERIFIED-CHAIN — KILL → downgrade** ($0 paper). `_hx_k_rmsnorm_rows` 를 sequential reference 에서 6-rewrite chain 으로 분해 — 4/6 (fission·row-parallel·scalar-hoist·elementwise) exact bit-equal, 2/6 (reduction strip-mine·block-tree) 는 FP reduction 재결합 → bit-equal 아님. "fully verified bit-equal codegen" FALSIFIED. method 는 "verified skeleton + TOL-bounded reassociation" 형태로 downgrade 생존.
- **F-RFC060-MEGAKERNEL-WALL — KILL (FP64)** (2 A100 fire). `rfc060_megakernel_fwd.cu` — transformer block forward, kernel-stream(cuBLAS) vs single persistent mega-kernel(in-kernel tiled GEMM). fire 1 (A100-SXM4-40GB) 이 attention S-block Bs-tile 인덱싱 버그 노출 (max|Δ| 0.19-2.9) → 수정 (`cf181933`) → fire 2 (A100 80GB PCIe) clean: max|Δ| 1.6e-14, mega **1.8× (small) / 4.4× (medium) 느림**. 원인 (clean diagnostic `mm_cublas_ms` 입증): mega-kernel 은 cuBLAS Dgemm 을 in-kernel GEMM 으로 대체해야 하고 FP64 in-kernel GEMM 은 cuBLAS 추월 불가 (Phase R C-V3 hand-WMMA 41-43% 와 정합) — matmul 회귀가 launch/HBM 절감을 압도.

**측정 headline**: FP64 substrate 에서 mega-kernel 패러다임은 CUDA kernel-per-op 모델을 돌파하지 못함 — measured-FALSIFIED. RFC 060 §8.2 사전등록 예측 그대로 (literature mega-kernel win 은 전부 BF16 Tensor Core). closure 가 가리키는 곳 = **RFC 060 ∩ RFC 049 — BF16-TC mega-kernel** (forge Phase R 이 BF16 을 "wall path" 로 이미 검증, 9.67× FP64 cuBLAS). FP64 kill 은 막다른 길 아니라 BF16 substrate 로 탐색을 좁힌 측정. 100% closure = 3 falsifier 전부 측정-resolved (1 pass, 2 measured-kill — g3 §8.6: measured-kill 도 closure).

### 2026-05-19 — RFC 060 정초: new compute paradigm 조사 (CUDA kernel-per-op 모델 돌파) — directive 갭 해소

사용자 goal 2026-05-19: *"new paradigm 으로 CUDA 성능·자원·속도 돌파 — 100% closure (measured)"*. forge 의 Phase R 은 *CUDA-paradigm* 질문 (NVIDIA GPU 를 어떻게 잘 쓰나) 을 측정으로 닫았지만, 원 directive 2026-05-16 의 *new-paradigm* 절반 (kernel-per-op 모델 자체를 벗어나는 실행 모델) 은 미이행 상태였음 — `PARADIGM_RESEARCH.md` 가 그 directive 를 자칭하면서 §1-§8 본문은 100% NVIDIA-실리콘 SW 전략만 조사. g3 정직성 갭.

**해소 — 3 산출물**:
- **`PARADIGM_C_RESEARCH.md`** (신규) — genuinely-new compute/execution model 8-paradigm 전수 조사 (dataflow · CGRA · spatial · polyhedral · verified-scheduling · AMT · PIM · mega-kernel) + ranked synthesis. deep research (web, 2024-2026 arxiv/vendor 출처 인라인 인용). 결론: **mega-kernel 실행 모델** (Mirage MPK arXiv:2512.22219 + Stanford megakernels, 측정 1.5-2.5×) = kernel-per-op 을 측정으로 돌파하는 유일한 genuinely-new 모델 — forge 가 이미 가진 GPU 위에서 돌고, $0.40 fire 1발로 kill/confirm 가능. method = verified rewrite-chain codegen (Exo-style, hexa atlas/strict-lint 와 직결).
- **`PARADIGM_RESEARCH.md`** — §9 scope-note 추가. 본 문서가 directive 의 "CUDA 아님" 절반만 이행했음을 g3 정직하게 명시 + `PARADIGM_C_RESEARCH.md` cross-link. 본 문서는 그대로 CUDA-paradigm snapshot 으로 보존.
- **RFC 060** (`inbox/rfc_drafts_2026_05_12/rfc_060_forge_new_compute_paradigm.md`, 신규) — verified mega-kernel execution model. 12-section. 3 falsifier 사전등록 (F-RFC060-MEGAKERNEL-WALL ≥1.3× training step, F-RFC060-VERIFIED-CHAIN ≤8 cited rewrites, F-RFC060-POLY-FEASIBLE 장기 게이트). 각각 cheap first measurement ($0 paper test ×2 + $0.40 fire ×1). g3: paradigm 선언 0 — 측정 falsifier 통과시에만 채택.

측정 변화 0 — 순수 정초 (research + RFC scaffold + 문서 갭 해소). forge 현재 상태 (C/CUDA substrate, Phase R closed) untouched. RFC 060 exploration track 은 §1 staged roadmap 의 RFC 060-A/B/C/D 참조.

### 2026-05-19 — endgame 문서화: forge 의 최종 형태 = hexa-native (RFC 055) — 문서 갭 해소

사용자 지적 — forge SSOT 문서 (README / PLAN / PARADIGM / FORGE.tape) 어디에도 "forge 의 최종은 hexa-native" 가 명시돼 있지 않았음. 현재 C/CUDA substrate 가 *영구* 형태로 읽힐 위험. g3 정직성 + `@D g5` (hexa-native-only) 정합을 위해 endgame 을 명문화:

- **README.md** — 신규 `## Endgame — forge becomes hexa-native (RFC 055)` 섹션. today(C/CUDA) vs after-RFC-055(hexa-native) 5-axis 비교표 + 왜 아직 critical chain 아닌지 (P2, g3 honest) + transition 시 forge 내부 변화 (`.cu` → `.hexa` 재유도, 디렉토리 경계 유지·언어만 flip, cuBLAS fallback 잔존, RFC 050 `_v1` ABI 가 stable surface). "What forge is NOT" 의 오해유발 bullet 정정 — "Not a GPU codegen backend" → "RFC 055 는 `compiler/codegen/` sibling deliverable, forge 는 소비자".
- **PLAN.md** — 신규 `### Phase 6 (endgame, long-arc) — forge becomes hexa-native (RFC 055)`. §2 gating 에 Phase 6 dependency 추가 (RFC 055 land + oracle 재현 battery, 현재 chain 과 독립).
- **FORGE.tape** — `@D g_forge_endgame_hexa_native` governance entry + `@X x_rfc055` citation.

측정 변화 0 — 순수 문서 (g3 over-claim 없음, "RFC 055 = design draft, 미구현" 명시). forge 현재 상태 (C/CUDA substrate, PARADIGM-anchored) 는 untouched. SSOT: `inbox/rfc_drafts_2026_05_12/rfc_055_hexa_nvptx_codegen_backend.md`.

### 2026-05-19 — RFC 050 v1 ABI Stage A LANDED — header + stub dispatcher + smoke 10/10 PASS

flame ↔ forge integration API (RFC 050) 의 stable public surface 코드로 land. Stage A 는 **API surface only** — Stage 2 substrates (RFC 044 A'/B'/C', RFC 049 BF16, RFC 048 fused) 가 kernel-by-kernel 로 같은 `_v1` entry point 를 통해 추가됨. ABI lockstep mandate (`AGENTS.tape §0 nn_stack`) 의 부재해소 첫걸음.

**파일** (모두 신규, 0 regen risk):
- `self/forge/forge_tier_v1.h` — public ABI: kernel families (MATMUL/FFN_FUSED/FWD_BWD_LINEAR/ATTN_DT_FWD/ATTN_DT_BWD/RMSNORM_MH/SILU_GATE/ROPE_MH) · regime tiers (AUTO/SMALL/MEDIUM/LARGE) · precision policy (FP64/LAYERCAST_BF16_FP32/PURE_BF16) · det mode (DEFAULT/PEDANTIC) · return codes (OK/FALLBACK_USED/KERNEL_UNSUPPORTED/REGIME_UNSUPPORTED/PRECISION_UNSUPPORTED/INVALID_ARGS/ABI_MISMATCH) · structs `ForgeShapeInfo` + `ForgeArgs` · 3 function signatures (`forge_api_version_v1` · `forge_tier_dispatch_v1` · `forge_register_specialized_v1`).
- `self/forge/forge_tier_v1.c` — stub dispatcher: MATMUL+FP64 path delegates to existing `hexa_farr_matmul` (RFC 040 baseline, always-available fallback at chain bottom per RFC 050 §6.6) returning `FORGE_FALLBACK_USED` (honest — specialized tier registry empty). Non-MATMUL kernels return `FORGE_KERNEL_UNSUPPORTED`. BF16 precisions return `FORGE_PRECISION_UNSUPPORTED` (RFC 049 Stage 2 gated). PEDANTIC + non-FP64 returns `FORGE_PRECISION_UNSUPPORTED` per RFC 049 §3.3. Specialized registry (`_forge_reg_table[256]`) stores entries; v1 dispatch does NOT consult it yet (Stage 2 wiring). Live MATMUL call gated by `#ifdef FORGE_TIER_V1_LIVE` so the .c file unit-tests standalone.
- `tool/forge_tier_v1_smoke.c` — standalone smoke (no GPU, no runtime link): 10 assertions covering version, register NULL/valid, dispatch BF16/LAYERCAST/FFN_FUSED/invalid-family/invalid-regime fallback paths. Build: `clang -std=gnu11 -DFORGE_SMOKE_STANDALONE -o /tmp/forge_tier_v1_smoke tool/forge_tier_v1_smoke.c self/forge/forge_tier_v1.c`.

**Wiring** (1-line change to `self/runtime.c`):
```c
#define FORGE_TIER_V1_LIVE 1
#include "forge/forge_tier_v1.c"
```
`runtime.c` TU compile clean (`clang -c -O2 -arch arm64 -std=gnu11 -D_GNU_SOURCE -I self self/runtime.c`, 380544 B object, 3 public symbols exported: `_forge_api_version_v1` · `_forge_tier_dispatch_v1` · `_forge_register_specialized_v1`).

**Measured (g3)**:
- runtime.c full TU compile: PASS, no warnings, no new errors
- standalone smoke: **10 / 10 PASS** (`exit=0`, prints `forge_tier_v1 smoke: 10/10 PASS`)
- nm symbols verified: 3 T entries (text) + 2 b entries (registry storage)

**What this is NOT** (g3 honest scope):
- NOT a perf claim — every dispatch returns FORGE_FALLBACK_USED or _UNSUPPORTED, no Stage 2 tier is actually faster than the existing path yet.
- NOT a flame consumer integration — flame Phase 4-D still calls direct `hexa_farr_matmul` / `farr_*_gpu` builtins; switching to `forge_tier_dispatch_v1` is a separate cycle once Stage 2 specialized kernels land.
- NOT BF16 substrate land — RFC 049 Stage 2 is independent multi-week work.
- NOT a falsifier discharge — `F-FORGE-RFC050-DISPATCH-API-MATCH` and the other 6 falsifiers from RFC 050 §7 are still pre-registered. They become verifiable only when flame Phase 4-D wires the call sites AND Stage 2 kernels register specialized fn_ptrs.

**Next cycle (downstream blockers cleared)**: Stage 2 substrate work (per-kernel) can now land into the same `_v1` entry points without touching the public surface. The `_v1` suffix is the lockstep marker; any future ABI break = `_v2` bump (RFC 050 §6.7).

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

### 2026-05-17 — Phase R+ 진정 cycle 종결 (9 sub-agents · 14 fires · $2.91 · RFC 049 wall path VALIDATED)
**최종 cycle 추가 작업** (이전 2026-05-17 4 sub-agent entry 이후, 3 추가 sub-agent + cleanup):

**Agent #19 RFC 050 (DESIGN, $0)**: flame ↔ forge integration API. 353 lines, 7 falsifier 사전등록 (DISPATCH-API-MATCH, REGIME-CORRECT, PRECISION-D-PRESERVE, FORGE-BACKWARD-FUSE, PERF-INHERITANCE, FALLBACK-CHAIN, VERSION-API). RFC 044 패턴 따라 12-section. Merged `e5fc6497`.

**Agent #18 A vs torch.compile baseline ($0.09)**: PyTorch.eager 대신 진정 SOTA (torch.compile.default + reduce-overhead = CUDA graphs) 비교.
- **MLP universal AOT 4-13× WIN** (FP64 Inductor codegen 약함)
- **transformer small + reduce-overhead → compile 1.41× FASTER** (CUDA graphs = dispatch elimination 동등 path) — **F-FORGE-A-TORCHCOMPILE FAIL at small transformer**
- transformer medium → compile 1.05× faster (Inductor RMSNorm/softmax/SiLU fused Triton wins)
- transformer large → AOT 1.14× WIN marginal
- 정직 nuance: A paradigm dispatch elimination 가 UNIQUE 아님 — torch.compile.reduce-overhead 가 동등 mechanism. 진정한 forge 차별점 = FP64 substrate quality + custom kernel selective. Cherry-picked `5dd78eec`.

**Agent #17 RFC 049 Phase R' Stage 1 BF16 ($0.10) — THE WALL PATH VALIDATED**:
- **F-FORGE-RFC049-BF16-TC-PERF: 9.67× FP64 cuBLAS at Llama-7B FFN** (LARGE M=128 D=4096 FD=11008), pre-reg ≥ 5× PASS with 1.93× headroom
- F-FORGE-RFC049-LAYERCAST-DET: within-run bit-equal 3/3 PASS
- F-FORGE-RFC049-LAYERCAST-MEM: 0.250× exact PASS (target ≤ 0.3×)
- F-FORGE-RFC049-LAYERCAST-DIVERGE: max 1.51% vs FP32 PASS (paper anchor ≤ 3.4%, target ≤ 5%)
- 정직 caveats: small/medium shapes launch-overhead-dominated (5× threshold not hit); cuBLAS 12.4 GemmEx FP32+BF16 NOT_SUPPORTED → fallback path; Hopper sm_90 + BF16 + DSM combined = future RFC 052. Cherry-picked `f01cbdb5`.

**Cleanup (2026-05-17 final)**: 7 forge sub-agent worktrees + 6 branches removed (cleaned: agent-{a28c7491930dc6fb1, a654a3ece3f47bb46, a681a0112d3db04f9, a703d1fd340716af2, a878ec8720149706b, addbef8b2c5c1bf6d, adeb90ed0d8431ed8}). flame session 4 worktrees 보존.

**Phase R+ 진정 META-FINDING (post all sub-agents)**:
1. **forge wall path = RFC 049 BF16 precision pivot** (실측 검증 9.67× FP64 cuBLAS at Llama-7B)
2. FP64 substrate ceiling experimentally bound (B Phase 2 200-300× SLOWER, C Phase 3 1.80× SLOWER best)
3. **dispatch elimination NOT unique to AOT** — torch.compile.reduce-overhead (CUDA graphs) = equivalent at small transformer
4. True forge distinctive: (a) BF16 TC substrate (Inductor 못 따라옴, MLP 4-13× win anchor), (b) custom kernels per regime (case-by-case), (c) within-run det FREE (D' anchor)
5. flame ↔ forge integration RFC 050 design land (Phase 4-C lowering ↔ forge tier dispatch API)

Phase R+ 총 비용: **$2.91** · 총 fire: 14 (Stage 1 D/B/C/A + Stage 2 A/B/C Phase 1/Phase 2 + RFC 049 BF16 + A torch.compile) · 총 sub-agent: 9 (4 first cycle + 3 second cycle + 2 prior single-agent ops).

flame ↔ forge concurrent safety verified: 양 세션 commits interleave 정상, 직접 file overlap 없음, AGENTS.tape 다른 section 편집 공존. 모든 forge 작업 in rfc043-hexa-torch branch, push 미수행 (user gate).

### 2026-05-17 — 4 sub-agent parallel cycle: RFC 049 + A Transformer + C Phase 3 + B Phase 2 (FP64 wall ceiling 노출)
**4 sub-agents (worktree-isolated, parallel background)** launched per user "all sub agent multiple background go":

**Agent #16 RFC 049 (DESIGN, $0)** — mixed-precision substrate. RFC 047 number collision → 049. 7 falsifier 사전등록 (BF16 TC perf 5×, LayerCast det 보존, BF16 mem ≤0.3× FP64, etc). literature anchors (LayerCast arxiv 2506.09501, BFLOAT16 1905.12322, cuBLAS 12.9 BF16x9, H100 datasheet). Merged commit `2f9a11c2`.

**Agent #15 A Phase 2 Transformer (FP64 Llama-style block, $0.09)**:
- F-FORGE-A-STAGE2-TRANSFORMER: PASS ✅
- small (D=512 L=64): 1.81× PyT eager
- **large (Llama-7B block D=4096 L=512): 1.18× PyT eager** (대형 dispatch elimination 검증)
- medium (D=2048 L=128): 1.05× FAIL marginal (sweet spot for PyTorch cuDNN)
- 1032 lines CUDA + 190 lines PyTorch baseline. Merged commit `4bd645f3`.

**Agent #14 C Phase 3 production tiling ($0.32, 4 iterations)**:
- F-FORGE-C-STAGE2-FUSED-CEILING + DET-PRESERVE ✅ PASS (bit-equal 0.000e+00 모든 15 datapoints)
- F-FORGE-C-STAGE2-WALL-LARGE ❌ FAIL: best 1.80× SLOWER (v3c WMMA bigtile at 4096³)
- Iteration progression: v2 naive 25-32× → v3 register tiling 4.1× → v3b WMMA 1.92× → v3c bigtile 1.80×
- Root cause (honest): hand-WMMA achieves 41-43% FP64 TC peak, cuBLAS 77-87% peak. CUTLASS-grade pipelining + autotune weeks 단위 effort. Merged commit `6d5e4ba7`.

**Agent #13 B Phase 2 DSM-fused FFN (Hopper-only, $0.10)**:
- Initial agent build error (Y/dY identifier) → my manual fix + re-fire
- F-FORGE-B-STAGE2-BITEQ ✅ PASS (max|Δ| 4.6e-16 모든 shape)
- F-FORGE-B-STAGE2-{LARGE/MEDIUM/SMALL} ❌ wall **200-300× SLOWER** (FP64 hand-kernel ceiling 같은 root cause as C Phase 3)
- DSM mechanism 자체 검증 (cross-block SMEM intermediate works numerically), 단 hand-kernel 가 cuBLAS TC 추월 불가능.

**Meta-finding (4 sub-agent cycle 종합)**: **FP64 hand-written kernels = wall FAIL across the board** (B Phase 2 200-300×, C Phase 3 1.80× SLOWER). Theoretical advantages (DSM traffic reduction, fused autograd ceiling 0.667×) all maintained numerically. **forge wall path = precision pivot RFC 049 (BF16/FP16 Tensor Core)**.

A paradigm 만 universal PASS (dispatch elimination = hardware-independent overhead reduction, Mech 1 confirmed via Llama-7B block 1.18×).

Phase R 누적 cost: **$2.51** (10 fires + 4 sub-agents).

### 2026-05-17 — Stage 2 B Phase 1 SMOKE PASS + Stage 2 C Phase 2 multi-block PASS (traffic+det) wall FAIL
**B Stage 2 Phase 1** (H200 SXM 143GB cc=9.0 · $0.12, Hopper supply 변동 후 가용 시점에 fire):
- SMOKE 1 cluster API ✅ PASS: block0 sees [own=7, other=107], block1 sees [own=107, other=7], cluster_size=2
- SMOKE 2 cuBLAS FFN baseline (M=128 D=4096 FD=11008): **0.4461 ms** — Phase 2 perf anchor
- Build error 첫 fire 후 fix (cudaLaunchAttribute init memset) → re-fire success
- F-FORGE-B-STAGE2-API-SMOKE PASS ✅
- Phase 2 plan: real DSM-fused FFN kernel (cluster.map_shared_rank cross-block SMEM reuse, 1-2 weeks effort)
산출: `state/forge_phaseR_b_stage2_2026_05_17/{result.json, fire.log, B_STAGE2_PHASE1_ANALYSIS.md}`.

**C Stage 2 Phase 2** (A100 PCIe 80GB cc=8.0 · $0.02 — vast.ai 가장 cheap A100 picked):
3 shapes (128/256/512), multi-block + chunked K + atomic_add for dW/dX vs cuBLAS chain.
- ✅ traffic: bytes_ratio = 0.6667 모든 shape (Phase 1 anchor multi-block 에 보존)
- ✅ det: max|Δ| < 1e-15 모든 shape (TOL_OP 1e-6 의 9 orders headroom) — atomic_add 가 실용적으로 deterministic
- ❌ **wall FAIL**: fused 5.99-32.3× slower than cuBLAS (per-thread loop + atomic overhead vs cuBLAS Dgemm)
- 결론: theoretical anchor + numerical equivalence multi-block scaling 확인. Wall win = Phase 3 (production CUDA tiling 또는 RFC 047 mixed-precision Tensor Core 활용)
산출: `state/forge_phaseR_c_stage2_v2_2026_05_17/{result.json, C_STAGE2_V2_ANALYSIS.md}`.

Phase R 누적 cost: **$2.09** (8 fires + 1 blocked-then-completed).

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

### 2026-05-18 — flame fire #19b 측정 → forge RoPE kernel gap = wall 의 leverage 점

flame Phase 4-D-9 closure 정밀화 cycle (commit `9aeccbd1`) 의 fire #18/#19b
host 분산 측정이 forge 측 우선순위 시사:

**측정 (g3 정직 — 2 vast.ai A100_SXM4 호스트 사이)**:
- fire #18 host A: step wall **267s**, F-RFC046 마진 ~170s
- fire #19b host B: step wall **359.7s ± 1.6s** (15 sample), F-RFC046 마진 ~76s
- **delta ~35%** — 같은 GPU 모델, vast.ai 호스트 차이로만 발생
- 양쪽 모두 게이트 PASS

**forge 측 시사점**: cuBLAS Dgemm 부분은 GPU 모델 (A100) 가 결정 — host
간 변동 없음. 35% delta 는 **비-matmul ops (RoPE step 등) 의 host CPU
loop 가 wall 의 leverage 점**임을 측정 입증. PHASE4D9 retro §6 의
"RoPE forge kernel gap (RFC 041)" 가 단순 cosmetic 부재가 아니라
**측정 가능한 wall 손실 (호스트 평균 가정 시 ~30-90s/step)** 이다.

**Phase R 패러다임 work 에 대한 함의**: AOT × whole-train-step
paradigm 의 wall 우위 측정 시, host CPU 영향을 거른 비교가 필요. 동일
호스트에서 PyTorch vs flame baseline + flame-with-RoPE-forge-kernel
3-way 측정 시 forge kernel landing 효과 의 isolate 가능.

**파생 작업 후보** (Phase R 외 본체 leverage):
- **RFC 041 RoPE forge kernel** 우선 구현 (gap 메우면 host-CPU
  bottleneck 완화 → wall variance 축소 + 평균 wall 단축).
- 다른 비-matmul CPU loop (mask gen, residual?) 의 forge 흡수 후보 식별.

**g3 over-claim 0**: 35% delta 는 2-호스트 sample, 통계 의미 미약.
더 많은 vast.ai 호스트로 재측정해야 RoPE kernel 의 marginal wall
유효성을 확정 가능. 그 측정 = benchmarking cycle 의 일부
([[flame-forge-benchmark-pending]] 참조 — flame/forge 작업 완료 후).
