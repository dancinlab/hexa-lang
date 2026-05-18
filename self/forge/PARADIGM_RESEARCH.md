# forge — paradigm research snapshot (2026-05-16)

> User directive 2026-05-16: forge 는 CUDA 포팅이 아니다. 더 뛰어난
> 아키텍쳐/패러다임. 위 명령에 따라 한국 alternatives + 글로벌 AOT-NN
> 컴파일러 SOTA + arxiv 2025-2026 deep research 수행 후, paradigm gap +
> forge 의 distinctive 위치를 데이터로 anchor 함. **결정 = A + B 둘 다
> 진행** (§6 참조). 이 문서는 paradigm 확정 전 단계의 데이터 캡처.

본 SSOT 는 `FORGE.tape` §X cross-link 대상이며 `PARADIGM.md` (paradigm
확정 시 작성될 SSOT) 의 evidence 토대. 자체는 SSOT 아닌 **research
snapshot** — paradigm 채택 후 핵심 인용만 RFC 044 / `PARADIGM.md` 로
이관.

> **⚠ Scope note (2026-05-19) — 이 문서가 directive 를 부분만 이행함.**
> 위 헤더는 directive *"CUDA 포팅 아님 — 더 뛰어난 아키텍쳐/패러다임"*
> 을 인용하지만, §1-§8 본문은 **NVIDIA 실리콘 위의 소프트웨어 전략만**
> 조사했다 (한국 NPU 벤더 · torch.compile · JAX · Mojo · arxiv kernel-
> fusion). 산출된 paradigm A/B/C/D (`PARADIGM.md`) 는 SIMT kernel-per-op
> 모델 *안의* dispatch/fusion/precision 전술이지, 새 *실행 모델*이
> 아니다. directive 의 "완전히 새로운 패러다임" 부분은 본 문서가
> 이행하지 않았다 — g3 정직성상 명시한다.
>
> 그 미이행 부분 (genuinely-new compute/execution model — dataflow ·
> spatial · polyhedral · verified-scheduling · mega-kernel) 의 조사는
> 별도 파일 **[`PARADIGM_C_RESEARCH.md`](PARADIGM_C_RESEARCH.md)** 가
> 담당한다 (2026-05-19, user goal "new paradigm 으로 CUDA 성능·자원·
> 속도 돌파"). 본 문서는 그대로 **CUDA-paradigm snapshot** 으로 보존 —
> 둘은 상보적: 본 문서 = "NVIDIA GPU 를 잘 쓰는 법", `PARADIGM_C_RESEARCH`
> = "kernel-per-op 모델 자체를 벗어나는 법".

---

## 1. 한국 CUDA 대안 신생들 — 전수 조사 (NPU 스택 + 자체 컴파일러)

| 기업 | 제품 | 컴파일러 스택 | 학습 지원 | paradigm distinctive? |
|---|---|---|---|---|
| **FuriosaAI** | RNGD ("Renegade") | Furiosa SDK = graph compiler + operator fusion + cross-layer data movement opt + `torch.compile` backend `FuriosaBackend`. Architecture: **Tensor Contraction Processor**. SDK 2025.3 = inter-chip tensor parallelism. | ❌ inference 전용 (2.25× perf/watt vs GPU on LG EXAONE) | NPU-target, AOT-or-JIT 미공개 |
| **Rebellions** | ATOM-Max / REBEL-Quad (Rebel100) | **RBLN SDK** = proprietary compiler + compute library + runtime. Frontend graph compile + backend codegen. PyTorch/TF/HF 통합. | ❌ inference 전용 (64 PFLOPS FP8 RebelRack) | NPU silicon focus; SDK = standard compiler architecture |
| **Moreh** | MoAI Platform | **Full-trace compiler** ★ — PyTorch → 다중 GPU 가상화 (수천 GPU = 1 device). AMD MI250 대상 221B 한국 LLM 학습 실증. | ✅ **학습 지원** (cross-vendor: H100 prefill + MI300X decode → 43% lower latency) | 한국 唯一 학습 paradigm; **다만 PyTorch frontend wrapper** (새 언어 아님) |
| **HyperAccel** | Bertha 100/500 | LLM-specific NPU | ❌ inference only | silicon, not compiler-paradigm |
| **DEEPX** | DX-H1 / DX-M1 V-NPU | Vision inference (30W) | ❌ | edge inference, off-topic |
| **SAPEON** | — | (자세한 컴파일러 정보 미발견) | — | — |

**결론**: 한국 측에서 "CUDA 같은거" 정확 일치 = **Moreh full-trace
compiler** (학습 paradigm 가장 distinctive). 단, **PyTorch frontend over
AMD GPU** = 새 언어가 아닌 wrapper. 새 paradigm 언어 = **없음**.

## 2. 글로벌 AOT-training 컴파일러 — 2026-05 SOTA

| 시스템 | paradigm | AOT? | 학습? | 정직 한계 |
|---|---|---|---|---|
| PyTorch + ATen eager | runtime dispatch | ❌ | ✅ | dispatch overhead, Python 비용 |
| **torch.compile + AOTDispatcher** (2025-08 state by ezyang) | JIT trace + AOT autograd 그래프 | "precompile" WIP — **AOT for training = 미해결** | ✅ JIT | **NOT bitwise-equivalent with eager** (fp16/bf16 fusion divergence). 그래디언트 streaming 불가 (대형 backward block 끝까지 누적). 권장 패턴 = per-Transformer-block regional compile, **whole-model 아님**. compile time scales w/ block count. |
| XLA / JAX | JIT-traced HLO | JIT (AOT-analysis layer = AXLearn) | ✅ JIT | dynamic shape 어려움, JIT cache cost |
| **Pallas/Mosaic** (JAX) | manual kernel + manual bwd | both | ✅ but 수동 bwd | **"JAX can't autograd through Pallas kernels"** → backward kernel 수동 작성 필요 |
| **Mojo MAX** (Modular 26.2, 2026-03) | MLIR compile-time + `model.compile()` | AOT==JIT 차이 무 | inference-first (training 미증명) | H100 7-point stencil = **CUDA의 87%**, Dot=78%. Hartree-Fock 1024-atom 큰 차이로 늦음. **static shape/type/layout mandatory** |
| CUTLASS / Triton / TVM | kernel JIT autotuner | per-kernel | partial | per-kernel, not whole-step |

**결론**: **AOT × whole-train-step (fwd + bwd + opt 한 프로그램)** =
**2026-05 현재 누구도 안 해결한 frontier.** torch.compile 의 "compiled
autograd" 가 가장 가깝지만 *"entirety of backwards must be compileable"*
라는 hard barrier 가 SOTA blocker.

## 3. 핵심 arxiv 발견 (forge 직결)

### ★ FlashFuser (arxiv 2512.12949, Dec 2025 — Yangjie Zhou)

- 첫 컴파일러 framework로 **H100 DSM (Distributed Shared Memory)** =
  cluster of SMs 의 SMEM 연결 (L1.5 cache, 227KB × cluster size) 활용
- Chimera/BOLT 한계 극복: 기존 fusion 은 단일-SM SMEM 한정 → DSM 으로
  FFN 같은 큰 intermediate 도 on-chip 잔류
- 비용 모델 + 5 pruning rules → 99.99% search space 축소
- **3.3× cuBLAS/TensorRT** · **4.1× Chimera (SOTA compiler)** · **5.4×
  BOLT** · **4.7× TVM Relay**
- **DRAM traffic 58% 감소** vs PyTorch
- **E2E LLM inference 1.24×** (SGLang/Llama3-70B/Qwen2.5-14B/32B)
- ⚠ **inference 전용** (training fusion 미해결 — 여기가 forge 의 빈 자리)

### ★ Numerical Nondeterminism LLM Inference (arxiv 2506.09501)

- BF16 → DeepSeek-R1-Distill-Qwen-7B 정확도 **9.15% 표준편차** (AIME'24)
- FP32 → 0% 표준편차 — but **2× 메모리 + 2× 시간**
- **LayerCast**: 가중치 16-bit + 연산 FP32 → FP32-level 결정성 +
  34% 메모리 감소
- forge Paradigm D (determinism-first) 직접 cited evidence

### Fused Kernel Library (arxiv 2508.07071)

- C++17 metaprogramming → nvcc 가 compile-time fused kernel 생성
  (custom compiler 불필요)
- **2× ~ 1000×** speedup (광범위 — anchor 모호)

### Mojo MAX HPC GPU Kernels (arxiv 2509.21039)

- 첫 fully-MLIR 언어, AOT==JIT (MLIR IR equivalent)
- H100 7-point stencil = CUDA의 87%, miniBUDE Φ̄=0.54
- **fast-math 없으면 compute-kernel 가 CUDA 대비 큰 격차** — forge 가
  이걸 못 피하면 floor 미달

### 기타

- **PyGraph** (arxiv 2503.19779v2): CUDA Graphs compiler support for
  PyTorch — automatic transformation + cost-benefit deployment
- **DeepCompile** (arxiv 2504.09983): distributed training fusion —
  all-gather grouping across layers
- **AXLearn** (arxiv 2507.05411): JAX AOT-analysis for memory/FLOPS
  prediction (전 실행 없이) — AOT-analysis vs AOT-execute 의 구분

## 4. forge 가 들어갈 빈 자리 — gap synthesis

| 차원 | 현 SOTA | forge 의 distinctive 위치 |
|---|---|---|
| AOT × training × whole-step | torch.compile precompile = WIP, JAX = JIT | **AOT × fwd+bwd+AdamW 한 .cu 프로그램** (RFC 040 + 041 위에서 RFC 044) |
| Backward 컴파일 | torch.compile "compiled autograd" = whole-bwd compileable 요구 hard barrier | **RFC 034 reverse-mode tape를 substrate 까지 내려** co-emit (Paradigm C 가 실제 SOTA blocker 직격) |
| Memory traffic (HBM ↔ SMEM/DSM) | FlashFuser inference 1.24× E2E, 58% DRAM↓ | **training 대상으로 동일 기법 확장 + AOT 시점 schedule** (FlashFuser 의 12-68× search 시간을 컴파일 cost 로 일회 지불) |
| 결정성 | LayerCast: BF16→FP32 cast로 정확도 안정, 2× memory cost | **forge default-deterministic + compile-time selectable precision policy** |
| 언어 통일 | Mojo MAX = MLIR 단일, 단 CUDA의 87% floor | **hexa-native, static shape mandate, no Python frontend** — Mojo 보다 strict (LLVM 안 씀이라 trade-off 다름) |

**실증된 honest 한계** (literature 직접 인용):

- Mojo MAX 가 H100 컴퓨트커널서 CUDA 의 78-87% — fully self-hosted +
  portable 의 비용. **forge 도 fast-math 없이 cuBLAS 매치 어려움**
  (cuBLAS는 closed-source 비결정 heuristic).
- FlashFuser 의 1.24× E2E (inference) — fusion-만으로 얻을 수 있는 현실
  상한 (anchor: training 에서도 비슷한 자릿수 기대).
- compile-time scaling (torch.compile): per-block compile 권장 → forge
  도 per-train_step compile cost 정직 catalog 필요.

## 5. forge 의 4 paradigm 후보 (research 가 confirm)

기존 sketch (FORGE.tape 외부, 채팅 trail) 가 데이터로 anchor 됨:

- **Paradigm A — AOT whole-train-step single program** ★
  - vs SOTA: torch.compile precompile WIP + 비-bitwise-equivalent;
    JAX = JIT; Mojo MAX = inference-first. **Whole-train-step AOT 는
    빈 자리.**
  - Real limit: 정적 shape mandatory, nvcc compile cost per (arch ×
    shape × optimizer) tuple
  - forge boundary 확장: FORGE.tape `not_what` "GPU codegen backend
    아님" 갱신 필요
- **Paradigm B — Register/SMEM/DSM-resident tile stream**
  - vs SOTA: FlashFuser 가 inference 에서 1.24× E2E, 58% DRAM↓ 실증.
    forge 는 training 적용 + AOT schedule
  - Real limit: H100 SM 당 64KB regs + 227KB SMEM × cluster (DSM
    Hopper-only). 대형 모델 (d≥4096) 은 부분 적용
- **Paradigm C — Reverse-mode-as-primitive (autograd at substrate)**
  - vs SOTA: PyTorch compiled autograd = whole-bwd compileable 요구 의
    hard barrier. JAX = Pallas 에서 manual bwd 필수. **substrate-level
    co-emit 은 빈 자리.**
  - Real limit: 일부 op (softmax bwd) 는 row 전체 필요 → fusion
    boundary 자연 발생. honest cataloguing 필요
  - flame ↔ forge 인터페이스 갱신 (RFC 034 의 일부 책임 이동)
- **Paradigm D — Determinism-first 숫자 (orthogonal feature)**
  - vs SOTA: LayerCast (arxiv 2506.09501) 가 BF16→FP32 cast 로 9.15%
    nondeterminism 해소 + 34% 메모리 감소. cuBLAS 는 비결정적.
  - Real limit: cuBLAS 비결정 best 대비 ~5-15% perf cost (literature
    anchor 필요)

**추천 = A + C 결합** (가장 distinctive — AOT × autograd-substrate
누구도 안 함) **+ B 부분 차용** (memory schedule) **+ D orthogonal
feature**.

## 6. 사용자 결정 (2026-05-16)

> A + B 둘 다.

- **A** = RFC 044 design draft (paradigm spec) —
  `inbox/rfc_drafts_2026_05_12/rfc_044_forge_aot_train_step.md`.
  paradigm A+C+D 명세 + falsifier 사전등록 + 위 §1-§4 literature
  anchor 그대로 인용. 코드 0, design only.
- **B** = FlashFuser-style DSM fusion **prototype experiment** —
  forge 의 floor 확인 (cuBLAS 위에서 single op 부터). 단, brief 의
  "CUDA 포팅 아님" 정신과 조화 = **paradigm 검증용 minimal experiment**,
  full kernel 풀-포팅 아님. 사용자 게이트 별도 필요 (`.cu` 작성 단계).

## 7. 다음 단계 (이 문서 commit 후)

1. **A 진입 — RFC 044 draft 작성**:
   `inbox/rfc_drafts_2026_05_12/rfc_044_forge_aot_train_step.md`. design
   only, hexa-lang 코드 0. 본 문서 §3 의 arxiv anchor + §1 의 한국
   alternatives 비교 + §4 의 gap matrix 를 그대로 reference.
2. **A 의존 — `self/forge/PARADIGM.md` SSOT 작성**:
   RFC 044 의 narrative summary (FORGE.tape §X cross-link 대상).
3. **B 사전 준비 — Phase 2 prep doc**:
   `self/forge/PHASE2_PREP.md` (이전 제안 그대로 — 11-op TOL spec +
   CPU reference harness + F-FORGE-KERNEL-EQ↔F-RFC041-* 매핑).
   FlashFuser-style DSM prototype 은 prep 단계에서 가능 op 식별.
4. **FORGE.tape `not_what` 갱신** (paradigm 확정 시):
   "NOT a GPU codegen backend" 항목이 paradigm A 와 충돌 → 갱신.
   hexa-src→PTX direct 는 여전히 forge scope 밖이나, **AOT whole-step
   .cu emission 은 forge scope 안으로 흡수**.
5. **flame 세션 settle 대기**: paradigm A+C 는 flame ↔ forge 인터페이스
   재정의 — flame 세션 in-flight 동안은 design-only 진행 (g_forge_substrate_role
   + flame 측 g_flame_compiler_only 양립). flame settle 후 인터페이스
   변경 RFC follow-up.

본 문서 후속: paradigm 확정 시 `self/forge/PARADIGM.md` SSOT 작성 + RFC
044 draft + FORGE.tape §X cross-link 추가.

## 8. Sources (literature anchor)

### 한국 alternatives

- MSAP — K-NPU vs GPU: https://www.msap.ai/blog/knpu-vs-gpu/
- FuriosaAI — LG AI 2.25× LLM inference: https://furiosa.ai/blog/lg-ai-research-taps-furiosaai-to-achieve-2-25x-better-llm-inference-in-production-vs-gpus
- FuriosaAI Developer Center 2026.1.0: https://developer.furiosa.ai/latest/en/overview/software_stack.html
- Rebellions Software Stack White Paper: https://rebellions.ai/wp-content/uploads/2024/08/WhitePaper_Issue2_ATOM_SoftwareStack.pdf
- Rebellions ATOM-MAX Server: https://rebellions.ai/rebellions-product/atom-max-server/
- Next Platform — Rebellions HBM + Arm Alliance (Dec 2025): https://www.nextplatform.com/2025/12/23/rebellions-ai-puts-together-an-hbm-and-arm-alliance-to-take-on-nvidia/
- Moreh — GPU Virtualization MoAI Platform: https://www.moreh.io/blog/gpu-virtualization-in-the-moai-platform-240819
- Moreh — 221B Korean LLM on 1200 MI250: https://moreh.io/blog/training-221b-parameter-korean-llm-on-1200-amd-mi250-gpu-cluster-230814/
- Korea AI Chip Startups 2026 — Seoulz: https://www.seoulz.com/korea-ai-chip-startups-2026/
- DEEPX DX-H1 V-NPU launch (Dec 2025): https://www.prnewswire.com/news-releases/deepx-launches-dx-h1-v-npu-the-30w-single-card-solution-that-challenges-gpu-dominance-302636052.html
- EE Times — HyperAccel LLM chip: https://www.eetimes.com/korean-startup-takes-on-cost-and-latency-with-llm-specific-chip/

### 글로벌 AOT-training compilers

- ezyang — State of torch.compile for Training (Aug 2025): https://blog.ezyang.com/2025/08/state-of-torch-compile-august-2025/
- PyTorch — AOTInductor docs: https://docs.pytorch.org/docs/stable/torch.compiler_aot_inductor.html
- PyTorch — torch.compile autograd semantics: https://docs.pytorch.org/docs/main/user_guide/torch_compiler/torch.compiler_backward.html
- PyTorch — AOT Autograd functorch: https://docs.pytorch.org/functorch/stable/notebooks/aot_autograd_optimizations.html
- JAX — Pallas Design: https://docs.jax.dev/en/latest/pallas/design/design.html
- Modular — Mojo MAX 2026 platform: https://www.modular.com/open-source/mojo

### arxiv 핵심

- arxiv 2512.12949 — FlashFuser: https://arxiv.org/html/2512.12949v1
- arxiv 2506.09501 — Nondeterminism in LLM Inference: https://arxiv.org/html/2506.09501v2
- arxiv 2508.07071 — Fused Kernel Library: https://arxiv.org/abs/2508.07071
- arxiv 2509.21039 — Mojo MLIR HPC GPU: https://arxiv.org/html/2509.21039v1
- arxiv 2503.19779 — PyGraph CUDA Graphs PyTorch: https://arxiv.org/html/2503.19779v2
- arxiv 2504.09983 — DeepCompile distributed training: https://arxiv.org/html/2504.09983v1
- arxiv 2507.05411 — AXLearn modular training: https://arxiv.org/html/2507.05411v2
