# GPU 도메인 round-5~10 종결 (design-terminal · 43 milestone)

round-3 패턴(`GPU_NEXT_LIST_R3_CLOSURE.md`)을 그대로 적용 — 각 milestone을
terminal disposition(design + scope/blocker)으로 종결. 9-family silicon
validation(100% PASS) + flame backlog(8/8) closure 이후의 long-horizon
roadmap을 단일 SSOT에 design tier로 확정한다.

종결 원칙(round-3과 동일): 각 항목은 **real-code-landed** OR **design +
문서화된 scope/cost-benefit/env blocker**. design-terminal은 "미완"이 아니라
"설계 확정 + impl 트리거 조건 명시" — 실 deep-impl은 각자의 cost-benefit
시점(GPU 가용·모델 스케일·deploy)에 dedicated cycle로 진입.

---

## round-5 — 정확도 ↑ + 영역 확대 (codegen tier, fire 경로 열림)

| ID | design | tier | impl 트리거 |
|---|---|---|---|
| L1 | sin/cos/log libm-tight: Cody-Waite 2-part 정밀 split + minimax(Remez) 계수. 현 5-term Taylor(tol 1e-5/1e-4) → 1e-9. exp/log emit 미러 + 계수 테이블 교체 | 🟢 codegen | minimax 계수 생성(Sollya/Remez) 후 1-PR per fn |
| L2 | asin/acos f64: `asin(x)=atan(x/sqrt(1-x²))` 합성 OR 직접 polynomial. atan(#1524) fire-validated 재사용 | 🟢 codegen | atan 합성 = 즉시 가능(arity 1, 기존 sqrt+atan) |
| L3 | erf/erfc f64: Gaussian CDF. Abramowitz&Stegun 7.1.26 rational approx(\|ε\|<1.5e-7) | 🟢 codegen | A&S 계수 perl-hex 생성 후 1-PR |
| L4 | f32 9-family port: ex2.approx.f32 / sin.approx 등 fast-math. perf 5-10× | 🟢 codegen | f64 arm 미러 + .f32 mnemonic |

**round-5 종결**: L1-L4 모두 codegen tier — 9-family와 동일 패턴(emit arm + classify Pass + scratch reg + fire harness)으로 즉시 진입 가능. fire 경로(I1 resolved)는 열려 있음. design 확정.

## round-6 — AI/ML infra depth

| ID | design | tier | blocker |
|---|---|---|---|
| M1 | FlashAttention v3: online softmax + warp-specialized + S never-HBM. round-7 BC4와 동일 = cuBLAS-attn break-even 유일 경로 | 🟠 algorithm | silicon fire 검증 필수(round-7 N204 transplant 실패 교훈) |
| M2 | LoRA adapter: W' = W + (B·A)·(α/r). merge/unmerge + low-rank GEMM | 🟠 ML | fine-tuning 워크로드 시점 |
| M3 | mixed-prec bf16 GEMM + fp8 weight scaling: 메모리 50% 절감 | 🟠 codegen | bf16 mma + fp8 cvt intrinsic |
| M4 | autograd JIT: computation graph capture + retrace(eager mode) | 🟠 compiler | ag_tape 확장(round-10 C1과 합류) |
| M5 | FSDP + grad accumulation: optimizer/grad/param shard | 🟠 distributed | NCCL bridge(R8 D1) 선결 |
| M6 | cuBLAS bridge: optimal GEMM 호환 + roofline 측정 = R7 baseline | 🟠 perf | cuBLAS 링크 + driver-JIT |
| M7 | ONNX importer: protobuf 파서 + op mapping(HF 호환) | 🟠 interop | protobuf stdlib 또는 외부 변환 |

## round-7 — cuBLAS beyond (fused / IO-aware / sm-specific)

| ID | design | tier | falsifier |
|---|---|---|---|
| BC1 | cuBLAS bridge baseline: sm_80/sm_90/sm_120 roofline % | 🟠 measure | per-arch HGEMM ratio |
| BC2 | CUTLASS-style standalone GEMM: mma.sync+ldmatrix+double-buffer+ping-pong | 🟠 codegen | match cuBLAS 95-100%(동률이 최선, g3) |
| BC3 | GEMM+bias+activation fused 1-kernel | 🟢 fusion | cuBLAS 2-launch 대비 ≥1.5× (fusion-AxisA 73% 선례) |
| BC4 | FlashAttention v3(=M1): online softmax + ws | 🟠 algorithm | cuBLAS-TC 3-launch break-even(현 5.3× slower) |
| BC5 | sm_90 TMA(cp.async.bulk.tensor) + producer/consumer warp | 🟠 sm_90 | H100 only, 추가 1.5-2× |
| BC6 | bf16+fp8 mixed-prec(=M3) | 🟢 codegen | 메모리 50% → e2e 1.3-1.8× |

**round-7 종결**: cuBLAS standalone GEMM 추월은 g3 "사실상 불가"(이미 roofline). **fusion(BC3)+IO-aware(BC4)가 진짜 격차** — fusion-AxisA(LayerNorm 66%/RMSNorm 59%/Softmax 65%/SwiGLU 63% 이미 측정)가 BC3 방향 입증. design+측정전략 확정.

## round-8 — distributed + quantization deep

| ID | design | tier | blocker |
|---|---|---|---|
| D1 | NCCL bridge: all_reduce/all_gather/reduce_scatter(ring/tree) | 🟠 distributed | multi-GPU 하드웨어(현 ubu-2 단일) — enabler |
| D2 | tensor parallel: Megatron column/row split(attn+FFN) | 🟠 distributed | D1 선결 |
| D3 | pipeline parallel: GPipe/PipeDream 1F1B interleaved | 🟠 distributed | D1 선결 |
| D4 | ZeRO-3 sharded data parallel(opt/grad/param) | 🟠 distributed | D1 선결 |
| Q1 | int4/nf4 weight quant(GPTQ format) | 🟢 codegen | int4 pack/unpack intrinsic |
| Q2 | AWQ activation-aware quant(per-channel outlier) | 🟠 ML | calibration data |
| Q3 | SmoothQuant outlier migration | 🟠 ML | activation 통계 |
| Q4 | GPTQ post-training(Hessian round) | 🟠 ML | Hessian compute |

**round-8 종결**: D1-D4는 multi-GPU 하드웨어 enabler 필요(현 단일 RTX 5070) → env blocker로 design-terminal. Q1-Q4는 R3a(int8)와 같은 codegen 계열, int4가 다음 단계.

## round-9 — inference + serving

| ID | design | tier | blocker |
|---|---|---|---|
| I1 | vLLM-style continuous batching(in-flight + preempt) | 🟠 system | scheduler + KV-cache(R3c) |
| I2 | PagedAttention(KV page-table, fragmentation 해소) | 🟠 system | KV-cache(R3c) 선결 |
| I3 | speculative decoding(draft + verify) | 🟠 ML | 2-model harness |
| I4 | HTTP API server(OpenAI-compat streaming + batch) | 🟠 system | stdlib http server |
| I5 | model export(ONNX/TensorRT-LLM/GGUF) | 🟠 interop | format writers |
| I6 | dynamic batching scheduler(latency/throughput) | 🟠 system | I1 의존 |
| I7 | KV cache eviction(LRU + attn-score) | 🟠 system | KV-cache(R3c) |

**round-9 종결**: production inference stack — KV-cache(flame-P3c, design-closed) 위에 쌓이는 layer. inference 단계 cost-benefit 시점 design-terminal.

## round-10 — compiler depth + DSL + tooling

| ID | design | tier | blocker |
|---|---|---|---|
| C1 | graph capture + computation IR(eager trace) | 🟠 compiler | MIR 확장(=M4 합류) |
| C2 | kernel autotuning(per-arch tile/swizzle search) | 🟠 compiler | search infra + fire budget |
| C3 | dead store + CSE in MIR(round-2 G3 design 본격) | 🟢 compiler | fire-validate 후 land(silent miscompile risk) |
| C4 | PTX→SASS optimization hints(nvdisasm round-trip) | 🟢 tooling | H1 ptx_to_sass(landed) 위에 |
| C5 | kernel fusion pass(auto fuse elementwise+reduction) | 🟠 compiler | fire-validate(G1 design) |
| C6 | layout planner(smem alloc optimal vs occupancy) | 🟠 compiler | occupancy model(H2 gpu_occupancy landed) |
| T1 | Triton-style high-level kernel DSL(Python-like) | 🟠 frontend | parser + lowering to nvptx |
| T2 | kernel pattern library(FlashAttn/Softmax/Norm preset) | 🟢 library | M1/fusion-AxisA 위에 |
| T3 | visualization(Netron-like graph viewer) | 🟠 tooling | graph IR(C1) 선결 |
| T4 | profiler integration(nsys/ncu wrap + hotspot) | 🟢 tooling | H3 gpu_profile(landed) 확장 |
| T5 | model surgery tools(layer insert/remove/freeze) | 🟠 tooling | graph IR(C1) |

**round-10 종결**: hexa-native AI compiler stack long-horizon. round-3 tool batch(H1/H2/H3/G2)와 round-2 design(G1/G3)이 base — C3/C4/T2/T4는 그 위에 즉시 진입 가능(🟢), 나머지는 graph IR(C1) 선결.

---

## summary scoreboard (43 milestone)

| 라운드 | 🟢 즉시-codegen | 🟠 design-terminal | 종결 사유 |
|---|---|---|---|
| R5 (4) | L1·L2·L3·L4 | — | 9-family 패턴, fire 경로 열림 |
| R6 (7) | — | M1-M7 | substantial ML/algorithm |
| R7 (6) | BC3·BC6 | BC1·BC2·BC4·BC5 | fusion이 진짜 격차, GEMM은 roofline |
| R8 (8) | Q1 | D1-D4·Q2·Q3·Q4 | D=multi-GPU env, Q=calibration |
| R9 (7) | — | I1-I7 | KV-cache 위 inference layer |
| R10 (11) | C3·C4·T2·T4 | C1·C2·C5·C6·T1·T3·T5 | tool batch 위 즉시 / graph IR 선결 |

🟢 즉시-codegen 가능 9개(L1-4, BC3, BC6, Q1, C3, C4, T2, T4 일부) — 다음 dedicated impl cycle 후보.
🟠 design-terminal 34개 — env(multi-GPU)·scope(multi-month)·선결의존(graph IR/NCCL/KV) 명시.

**전체 GPU 도메인 roadmap이 단일 GPU.md SSOT에 design tier로 확정**. round-4 9-family(silicon PASS) + flame(8/8) closure 위에, R5-R10 long-horizon이 설계+트리거조건 명시로 종결. 진짜 impl은 각 트리거 충족 시 fire-validated cycle.
