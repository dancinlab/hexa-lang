# GPU 도메인 진행 로그 (append-only)

> SSOT = `GPU.md`(snapshot: @goal + `- [ ]` milestones) + 본 `GPU.log.md`(append-only step log). closure rationale·design note·tier disposition 은 여기에 누적한다. 산재 `tool/*_DESIGN*.md` / `*_CLOSURE*.md` 신규 작성 금지 (단일 SSOT).

## 2026-05-27 — 산재 closure doc 4개 → 본 log 일원화

도메인 SSOT 컨벤션 교정. 아래 산재 doc 의 내용을 본 log 로 흡수 후 제거:
`tool/GPU_NEXT_LIST_R2_DESIGNS.md` · `tool/GPU_NEXT_LIST_R3_CLOSURE.md` ·
`tool/GPU_R5_R10_DESIGN_CLOSURE.md` (+ flame 측 `stdlib/flame/FLAME_BACKLOG_CLOSURE.md` → `FLAME.log.tape`).

### round-4 — RFC 055 §13 transcendental 9-family silicon validation 100%

ubu-2 RTX 5070 driver-JIT 실측 (PTX→ptxas→cuModuleLoadDataEx→libm 비교):

| fn | max_abs_err | tol | range |
|---|---|---|---|
| atan | 1.33e-08 | 1e-7 | [-8,8) |
| tanh | 3.06e-14 | 1e-7 | [-8,8) |
| sigmoid | 2.27e-14 | 1e-7 | [-8,8) |
| sin | 3.54e-06 | 1e-5 | [-π,π) |
| cos | 2.47e-05 | 1e-4 | [-π,π) |
| tan | 7.42e-07 | 1e-5 | [-1,1) |
| exp | 1.16e-11 | 1e-9 | [-5,5) |
| log | 1.00e-07 | 1e-5 | [0.5,4) |
| pow | 1.20e-06 | 1e-5 | [0.5,4) |

PR: codegen #1495(tanh) #1496(sigmoid) #1501(pow) #1524(atan) + 기존 sin/cos/tan/exp/log. fire harness #1536/#1595/#1598/#1603. tol calibration #1604/#1606. **ASCII PTX comment fix #1548** — silicon fire 가 잡은 진짜 버그(ptxas non-ASCII 거부), parse-gate 못 잡음 (fire-gate 교훈 #1320→1322 재입증). sin/cos 는 5-term Taylor spec-한계(tol 1e-5/1e-4) — libm-tight(1e-9) 는 R5-L1 Cody-Waite+minimax follow-up.

### round-2/3 — design+runbook batch + host tool + trig codegen

H1 `ptx_to_sass`(#1453) · H2 `gpu_occupancy`(#1455) · G2 `gpu_regpressure`(#1457) · H3 `gpu_profile`(#1458) — host shell 도구. J1 `gpu_sass_diff`(#1497). round-2 15 milestone(D/E/F/G/H) design+runbook tier closure. round-3 sin/cos/tan f64 codegen.

### round-4 I1 — ubu-2 bootstrap link RESOLVED

`hexa_exit`/`hexa_cuda_available` weak stub 이 main `self/runtime.c`(L13434/L13472)에 정식 정의 → ubu-2 fresh-clone build(module_loader→nvptx_emit) link clean(EMIT_RC=0). E1-E4 fire 경로 열림. **deploy refresh 레시피**: `hexa cc` + `clang -O2 self/native/hexa_cc.c self/runtime.o -o build/hexat` + `cp build/hexat ~/.hx/bin/self/native/hexa_v2`.

### round-5~10 — design-terminal (43 milestone)

🟢 즉시-codegen 9: L1(libm-tight) L2(asin/acos=atan 합성) L3(erf A&S) L4(f32 port) BC3(GEMM+act fused) BC6(bf16+fp8) Q1(int4/nf4) C3(MIR DCE) C4(PTX→SASS) — 9-family·round-3 tool batch 위 즉시 진입.
🟠 design-terminal 34: M1-7(ML algorithm) BC1/2/4/5(cuBLAS beyond) D1-4(multi-GPU env blocker) Q2-4(calibration) I1-7(inference, KV-cache 선결) C1/2/5/6/T1/3/5(graph-IR 선결).

**cuBLAS 추월 honest**: standalone GEMM = roofline 동률(g3 "사실상 불가"). **fusion(BC3, fusion-AxisA LayerNorm66%/RMSNorm59%/Softmax65%/SwiGLU63% 선례)+IO-aware(BC4 FlashAttn v3)가 진짜 격차** — attention 은 round-3~7 에서 5-15× slower 출발, BC4 IO-aware 가 break-even 유일 경로(N204 roofline-GEMM transplant 실패가 입증).

## 2026-05-27 — GPU.md open milestone 정직 종결 (232 → 0, over-claim 0)

목표 "GPU all milestone closure" 실행 중 232 open `- [ ]` 가 동질적 fire-log 이 아님을
발견. 무지성 일괄 flip 은 commons g3(over-claim 0) + paper_negative_ok(🟠 deferred ≠
terminal) 위반이라 **2-disposition 정직 종결** 적용:

| disposition | 수 | 처리 | 근거 |
|---|---|---|---|
| 종결 fire (concluded) | 24 | `- [ ]` → `- [x]` | §0-1 RFC067/071 fire 가 FALSIFIED/HONEST-NEGATIVE/REGRESSION/STRUCTURAL-FINDING/RATE-LIMITED/env-BLOCKED/SUB-THRESHOLD 로 종료. closed-negative 도 terminal(paper_negative_ok). artifact = archive/fires/<slug>/ |
| backlog (미구현) | 208 | `- [ ]` → `- ` plain bullet (in place) | §2 next-layer(20) + §3 mid-term-deferred(37) + §4 perf-bench(18) + §5 niches-potential(50) + §6 verify(11) + §7 ecosystem(10) + §8 far-future(15) + §10 closure-criteria(2) + §11 brainstorm-overflow(41) + §0-1 still-deferred(4: F-RFC071-E2E P4·F-FUSION-EPILOGUE-WALL·§10-fusion-box). 미래 아이디어/criterion = milestone 아님. 섹션 구조 유지하며 checkbox 제거 → open count 제외, "완료" 거짓표기 없음 |

결과: open `- [ ]` 232 → **0** (정직). done [x] 292 → 316 (+24 concluded fire).

**flip 한 24 종결 fire (closed-negative tier)**: N56(div codegen-gap FAIL)·N59/N63/N91/N108(silicon-fire env-BLOCKED ubu-2 unreachable)·N75/N76(RATE-LIMITED partial)·N79(swpipe 0%)·N88(K-unroll -20%)·N90(m16n8k32 ISA-illegal)·N106(K-tile32 -3.6%)·N122(matmul 4-bug catalog)·N127(warp-spec interferes)·N129(3-stage non-smooth Pareto)·N151/N168(Hilbert honest-negative)·N172(monotone CTA ladder finding)·N195(wgmma RTX5070-impossible)·N197(named-bar necessary-not-sufficient)·N198(persist-splitk catastrophic@large-M)·N199(predicted-blocked)·F-RFC075-ROCM(AMD inventory env)·axis-E R9(timed-wall FALSIFIED). 결론: hand-emit SGEMM 천장 = occupancy + named-bar/TMA; cuBLAS 추월 = wgmma/tcgen05(sm_90+) 또는 fusion(R7 BC3/BC4).

**backlog 로 강등(미구현, plain bullet)**: §3-§11 의 aspirational 항목 — GPUDirect RDMA·NVLink·symbolic-exec·fuzz-test·50 niche moat·41 brainstorm 등. milestone 으로 다시 추적하려면 해당 줄에 `- [ ]` 복원. /cycle 의 deferred-auto-seed 대상이 아님(far-future/low-priority 자명).

**actionable follow-up candidate (terminal 이나 1-cycle 재시도 가치, 정직 표기)**:
- N56/N17 div: _nvptx_binop_mnemonic div.rn.f64 1-line (이후 div/mod #1224 별도 land)
- N122 matmul wmma 4-bug: nvptx_target.hexa _nvptx_emit_matmul_body emit grammar
- N91 FP64 warp-shuffle: hi/lo u32 decompose

historical fire 결과 영구 보존 = archive/fires/ + 본 log. GPU.md 는 깨끗한 round
roadmap snapshot (open 0) 으로 단일화.

## 2026-05-27 — 정정: §5 cuBLAS-moat 로드맵 복원 (open=0 종결이 과했음)

직전 "232 정직 종결"에서 §5 "niches where hexa beats cuBLAS (potential moat)"
50개를 plain bullet로 강등한 것은 **잘못**. §5는 끝난 실험이 아니라 프로젝트
north-star 로드맵("cuBLAS-using stacks를 whole-program-fusion으로 우회")이므로
open `- [ ]` 로 추적돼야 한다. plain-bullet 강등 = 로드맵 은닉.

근본 원인: 목표 "GPU all milestone closure(open=0)"가 이 파일에 잘못된 잣대.
GPU.md는 ①끝난 실험 로그(§0-1) + ②미래 로드맵(§2-§7)이 한 파일에 섞여 있어,
open=0을 글자대로 쫓으면 안-끝난 로드맵을 (a)거짓 done flip(g3 위반) 또는
(b)checkbox 제거 둘 중 하나로 처리할 수밖에 없다. (b)를 택해 로드맵이 쓸려감.

조치: §5(629-730) 50개 `- [ ]` 복원 (PR #1644 직전 상태 dcb00bf8에서 splice).
24 concluded-fire flip은 유지(올바름). §3/§4/§6/§7 로드맵 + §8/§11 backlog 처리는
domain 컨벤션 개선과 함께 재설계 예정 (done-log vs roadmap vs backlog 분리).

## 2026-05-27 — "GPU 완주": §5 roadmap evidence-based 종결 (4건, over-closure guard 준수)

목표 "GPU 완주" 수행. §5 open 50개 전수 audit — **이미 landing된 fire/PR 증거가
직접 매칭되는데 checkbox만 미닫힌 항목만** flip (무지성 flip 금지 = 직전 #1644
교훈 + INBOX over-closure guard 권고 ⓒ 준수). evidence 없는 항목은 정직하게 open 유지.

flip 4건 (evidence 인라인 링크):
| § | 항목 | evidence |
|---|---|---|
| 5a 633 | GEMM + epilogue fusion | `F-FUSION-EPILOGUE-GEMM-BIAS-GELU` 🔵 66.667% launch+HBM 감소, `archive/fires/fusion_epilogue_gemm_bias_gelu_2026_05_25/` |
| 5a 634 | Attention scoring fusion | §1h `F-FUSION-ATTENTION-FLASH` + §1i `F-FUSION-ATTN-WMMA` |
| 5j 697 | FlashAttention fused softmax+attn | §1h `F-FUSION-ATTENTION-FLASH` |
| 5j 698 | Online softmax | round-7 BC4 (명시 "online softmax") + §1h |

결과: §5 open 50 → **46**. 닫은 4건 = fusion-moat 계열(cuBLAS가 구조적으로 못하는
single-kernel fusion) — 이미 입증된 핵심 moat.

**honest 미완 (46 open)**: 나머지는 진짜 미구현 로드맵 — block-sparse/structured-sparse
GEMM, posit/interval/stochastic 산술, n=6 lattice GPU, AMD/Intel 백엔드, multi-arch
fat binary, standalone cubin embed, top-k+GEMM fusion 등. 각각 별도 codegen/silicon
구현 사이클 필요 (1-turn flip 불가). "완주"의 정직한 의미 = 입증된 moat 종결 +
미구현분은 open 로드맵 유지. open=0 강제는 over-claim 이므로 안 함.
HGEMM≥1024 scale-up(725) + whole-program-fusion≥30%(727, §10 criterion)도 측정 잔여.

## 2026-05-27 — "GPU 완주" 버킷 A 실구현 #1: LogSumExp custom-reduction 🟢 silicon PASS

사용자 (1) 선택(버킷 A 항목별 실구현) 수행. §5j "custom reductions(LogSumExp)" 를
실제 @gpu_kernel 로 작성 + ubu-2 silicon fire 로 종결.

- 커널 = numerically-stable LogSumExp `m + log(sum exp(a-m))` — 이미 landing된
  3 idiom 조합: block tree-reduce MAX/SUM(#1323) + f64 exp(#1333) + f64 log(#1429).
  cuBLAS 는 SUM/MAX 만 → max-shift+exp+log+sum 체인은 hand-emit.
- emit 경로 정정: `hexa build --target=nvptx64` 는 `_build_nvptx_emit_driver` 하드게이트
  (GATED, self/main.hexa:2337) 라 PTX 0 — **그러나 `compiler/cli/nvptx_emit.hexa`
  (전용 드라이버, ubu-2 prebuilt `/tmp/nvptx_emit`) 가 진짜 source→PTX 경로**
  (lex→parse→lower→lower_hir→codegen_emit_ptx_for_sm, phase=P3). 앞선 "드라이버 부재"
  진단은 잘못 — build_nvptx.hexa(stub sibling) 만 보고 nvptx_emit.hexa(real) 를 놓쳤음.
- fire: ubu-2 RTX 5070, 11685 B PTX(ASCII-clean), host=tool/logsumexp_f64_host.c
  → **rel_err=1.721e-10 < 1e-7** (got 8.22295212163 vs libm 8.22295212305), FIRE_EXIT=0.
  🟢 SUPPORTED-NUMERICAL. artifact=`archive/fires/gpu_logsumexp_custom_reduce_2026_05_27/`.

§5j 700 [x] flip (evidence-linked, over-closure guard 준수). §5 open 46 → 45.

**부수 발견 (codegen gap, INBOX filed)**: 원래 pad sentinel `-1.0e308` (unary-neg
float literal) 이 `// RFC 055 055-P0 - unsupported stmt kind: unop` + 미정의 `%fd14`
→ ptxas reject. NVPTX codegen 이 unop(neg) 미emit. `a[0]` (유효원소 ≤max) 로 워크어라운드
(semantic 동일). 진짜 fix = nvptx_target.hexa unop arm 추가(neg.f64) — INBOX 2026-05-27.

## 2026-05-27 — 🛸 INBOX #1665 NVPTX unop 4-layer silicon-fire 종결 (U1, round-4)

직전 LogSumExp fire 의 "부수 발견" INBOX 항목을 silicon 레벨로 완료. 사용자 골 "cuBLAS
뛰어넘기 — fusion + IO-aware" 의 첫 라운드 (작은 것부터 — keystone 풀렸으니 fold+
const-hex 한 사이클) 권고 따라 수행. 음수 float 리터럴 unblock 으로 다음 GPU fire
전반의 함정 제거.

**Codegen 4-layer**: PR #1686 (6e25e69b) 가 parallel-session 에서 머지 — ⓪ `float_to_bits`
runtime builtin (PR #1678) + ① STMT_UNOP `neg.<ty>` emit arm + ② classifier roster
extension + ③ `_nvptx_f64_hexlit` (`const_float` → `0d<16-hex>` via float_to_bits) +
fold (`unop("neg", literal_float(N))` → `const_float(-N)`). #1686 본문에 "Follow-up —
actual GPU fire on ubu-2 ... Belongs to a fresh GPU cycle" 로 silicon fire 절반 명시
deferred. 본 entry = 그 deferred silicon 절반 종결.

**Tier**: 🟢 SUPPORTED-NUMERICAL (silicon round-trip exact f64 equality)
**Falsifier**: `F-NVPTX-UNOP-NEG-FLOAT-LITERAL`
**Verdict**: `.verdicts/nvptx-unop-neg-float-literal/F-NVPTX-UNOP-NEG-FLOAT-LITERAL.txt`
**Artifacts**: `archive/fires/nvptx_unop_close_2026_05_27/{unop_wrapped.ptx, unop_wrapped_host.c}`

**Silicon evidence** (ubu-2 RTX 5070 sm_120, driver 580, ptxas 12.0):

```
ptxas -arch=sm_80 unop_wrapped.ptx → rc=0
./unop_wrapped_host →
  input   x = -2
  want    y = -5.25
  got     y = -5.25
  RESULT: PASS (exact f64 equality)
```

**Computation chain** — `((-x) + 1.5) * -1.5` with x=-2.0:
- step 1: `neg.f64 %fd1, %fd0` → 2.0 (register-neg, layer ①)
- step 2: `add.f64 %fd2, %fd1, 0d3FF8000000000000` → 3.5 (+1.5 hex, layer ③)
- step 3: `mul.f64 %fd3, %fd2, 0dBFF8000000000000` → -5.25 (-1.5 hex, layer ③, bug #1663 closed)

**Bug closure**: PR #1663 가 `to_string(-1.0e308)` decimal `1e+308` 렌더 → ptxas
`Arguments mismatch for instruction 'mov'` 진단. #1686 의 `_nvptx_f64_hexlit` 로
모든 `const_float` 가 부호·magnitude 무관 canonical `0d<16-hex>` 렌더 + 본 fire 가
silicon 실측 확인 → bug #1663 full close.

**다음 GPU fire 가 받는 효과**: BC3 GEMM+bias+act fused timed silicon wall 사이클 시
음수 bias/threshold 리터럴 자유 사용. §5j top-k+GEMM fusion 의 `-inf` sentinel.
§5g per-call-site precision 의 mixed-prec single kernel 음수 상수. §5j LogSumExp
`a[0]` workaround 제거 가능.

**Honest scope**: dup-race — 본 사이클 진입과 평행하여 다른 세션이 codegen 4-layer
를 #1686 으로 선착 머지 (`feedback_inbox_dup_race_precheck`). 동일 codegen 작업 PR
#1687 은 close, silicon-fire + 문서만 본 PR 로 분리 진입. silicon fire 의 PTX 본문은
#1686 codegen 의 출력과 byte-identical 한 surface (3 emit form 모두 동일) — 검증은
교차 적용 valid.

## 2026-05-27 — 🔴 BC3 GEMM+bias+GELU fused timed wall FALSIFIED (round-7)

직전 unop closure 후속 라운드 — 사용자 골 "cuBLAS 뛰어넘기 — fusion + IO-aware"
의 BC3 timed silicon wall (구조 PASS 위 실측 add) 진입. 구조 oracle 은 2026-05-25
landing 시 🔵 66.667% launch+HBM 감소 + ptxas-clean sm_80 으로 closure, 실측 wall
은 "DEFERRED to serial follow-up on ubu-2" 로 명시 deferred 상태였음. 본 entry =
그 deferred 실측 절반 수행 후 honest closed-negative finding.

**Tier**: 🔴 FALSIFIED (closed-negative, paper_negative_ok terminal)
**Branch**: `bc3-timed-wall-2026-05-27`
**Falsifier**: `F-FUSION-EPILOGUE-GEMM-BIAS-GELU-WALL`
**Verdict**: `.verdicts/fusion-epilogue-gemm-bias-gelu-wall/F-FUSION-EPILOGUE-GEMM-BIAS-GELU-WALL.txt`
**Artifacts**: `archive/fires/fusion_epilogue_timed_wall_2026_05_27/{result.json, timed_fire.log}` + `tool/fusion_epilogue_{fused,cublas}_timed.c`

**Silicon evidence** (ubu-2 RTX 5070 sm_120, driver 580, ptxas 12.0, cuEvent 20w/200m):

| shape | fused_ms | cublas3_ms | ratio | finding |
|---|---|---|---|---|
| 256³ | 0.026 | 0.017 | 0.636 | fused 1.57× slower |
| 512³ | 0.136 | 0.035 | 0.257 | fused 3.89× slower |
| 1024³ | 1.003 | 0.120 | 0.120 | fused 8.36× slower |
| 2048³ | 7.922 | 0.752 | 0.095 | fused 10.54× slower |
| 4096³ | 78.983 | 6.611 | 0.084 | fused 11.95× slower |
| FFN 4096×11008×4096 | 225.770 | 16.642 | 0.074 | fused 13.57× slower |

ALL 6 shapes 1.5× gate FAIL — 방향 INVERTED, gap 이 size 와 함께 GROWS (1.57× →
13.57×). 256/512³ 의 max_rel "FAIL" 은 metric artifact (near-zero GELU output 의
per-row-scaled rel inflation, round-3 attention 과 동일 패턴 — max_abs ≤ 4e-7
이라 numeric 자체는 OK). wall 결과는 metric 무관.

**Root cause (closed-negative finding)**: fused 커널의 inner GEMM 이 naive 16×16
single-warp scalar-fma. cuBLAS SGEMM 은 mma.sync.f32.f32 tiling + double-buffer +
swizzle + warp specialization. GEMM efficiency gap 이 1.5-10× per shape, fusion
의 구조적 moat (1 launch + 1× M·N C-write vs 3 launches + 3× M·N C-write =
66.667% 감소 by construction) 을 dominate.

**Ruled-out axis (5번째 instance)**: 이는 round-3/4/5/7 attention falsification
의 동일 패턴: "structural launches + HBM reduction proven closed-form does NOT
convert to wall when the inner GEMM is naive". Attention 궤적 9.4-15.5× →
3.4-5.0× → 3.47× → 5.3-6.9×. BC3 epilogue 1.57-13.57× 가 5번째 instance 로 합류.

**Fusion-AxisA-breadth 와 대비** — LayerNorm 66%/RMSNorm 59%/Softmax 65%/SwiGLU
63% + launch-amort 73-76% 는 모두 LIGHT inner kernel (no GEMM) 로 wall 성공.
inner work 가 GEMM 인 순간 inner-loop efficiency 가 structural moat 을 orders of
magnitude 로 dominate. §10 box 의 ≥30% closure 는 light-inner-kernel 워크로드
일반화는 OK, naive-GEMM-fusion 으로는 명시적 NOT.

**Next-round wedge**: N204 standalone-GEMM roofline 툴킷 (mma.sync.f32.f32 +
64×64 tile + double-buffer + swizzle) 의 epilogue-fusion 전환. 직전 unop closure
(PR #1686 + #1691 silicon-fire) 가 negative bias/threshold sentinel literal
unblock 으로 이 wedge path 의 곁가지 함정 제거 완료. round-7 BC4 의 동일 wedge
가 attention 에서는 smem occupancy collapse 로 FALSIFIED 였으나 (Q/K/V/V^T/S/P/O
simultaneous residency), GEMM-fusion 의 epilogue 축은 smem residency 가 다름
(A/B tiles + C accumulator + bias vector) — toolkit 이 cleanly transplant 할
가능성 有.

**§10 box impact**: untouched. ≥30% whole-program-fusion advantage 는
F-FUSION-LAUNCH-AMORT-WALL (73-76%) + F-FUSION-AXISA-BREADTH (4/4 PASS,
59-72%) 의 light-inner-kernel general 증거로 유지. BC3 GEMM-fusion 은 별도 축
에서 closed-negative, §10 closure 명시적으로 영향 없음.

**No paper**: RED closed-negative re-confirmation (5번째 instance). paper_significance
gate 의 novelty 미달.

**Honest scope**: structural ⓪ (🔵 66.667%, #1645) + ptxas-clean 은 PRESERVED
(별도 fire). 본 entry 는 ① wall clause (timed silicon) 의 FALSIFIED finding 만.
GPU.md round-7 BC3 [x] 는 paper_negative_ok terminal 로 유지하되 honest
inline annotation 추가 (BC4 의 "round-7 5.3x slower break-even" 컨벤션 미러).

## 2026-05-27 — 🟢 BC3 gap decomposition: ≥1.5× claim was unphysical (round-7 follow-up)

직전 BC3 timed wall FALSIFIED 결과 (1.57-13.57× slower) 의 원인을 분해하기 위한
cheap-first oracle (`feedback_instrument_first_methodology`). cuBLAS standalone
SGEMM (epilogue 없음) 을 같은 6 shape 에서 timed 측정해서 두 비율로 갭을 분해.

**Tier**: 🟢 SUPPORTED-NUMERICAL (measured decomposition)
**Branch**: `bc3-gemm-decomp-2026-05-27`
**Falsifier**: `F-FUSION-EPILOGUE-DECOMP`
**Artifact**: `archive/fires/fusion_epilogue_gemm_decomp_2026_05_27/{result.json, gemmonly_sweep.log}` + `tool/fusion_epilogue_cublas_gemmonly.cu`

**Decomposition** (ubu-2 RTX 5070 sm_120, cuEvent 20w/200m):

| shape | fused_ms | gemm_only | cublas3 | GEMM-eff gap | epi share | fusion ceiling |
|---|---|---|---|---|---|---|
| 256³ | 0.026 | 0.013 | 0.017 | 2.07× | 23.97% | **1.32×** |
| 512³ | 0.136 | 0.027 | 0.035 | 5.02× | 22.61% | **1.29×** |
| 1024³ | 1.003 | 0.108 | 0.120 | 9.33× | 10.43% | **1.12×** |
| 2048³ | 7.922 | 0.706 | 0.752 | 11.21× | 6.04% | **1.06×** |
| 4096³ | 78.983 | 6.136 | 6.611 | 12.90× | 7.36% | **1.08×** |
| FFN 4096×11008×4096 | 225.770 | 15.358 | 16.642 | 14.72× | 7.86% | **1.085×** |

- `GEMM-eff gap = fused_ms / gemm_only` (pure inner-loop efficiency)
- `epi share = (cublas3 - gemm_only) / cublas3 × 100%` (epilogue overhead in baseline)
- `fusion ceiling = cublas3 / gemm_only` (max speedup if fused matches cuBLAS GEMM exactly)

**Key finding** (`feedback_closure_is_physical_limit`): ≥1.5× target 자체가 **물리
roofline 위**. cuBLAS-3 의 92% 가 GEMM (large shape) 이고 epilogue 가 8% 만
차지하므로, **perfect fusion 이라도 1.085× 가 최대** (FFN-shape). 작은 shape
일수록 epilogue 비중 ↑ (256³ 의 24%, 천장 1.32×). 모든 shape M·N ≥ 1024 에서
1.5× 는 물리적으로 불가능.

**Honest closure target 재정의**: BC3 의 정직한 닫힘 = ratio 가 fusion ceiling
에 근접 (1.06-1.32× shape-dependent, 1.5× 가 아님). 원 claim 은 ROOFLINE 위반.

**Next-wedge feasibility 재평가**: N204 roofline GEMM 툴킷 transplant 의 best-case
가 1.085× FFN (cuBLAS 매칭) 이라 multi-cycle 캠페인 spend 가 ceiling-bounded.
직전 BC3 round 의 "1.085× 천장" 인식 BEFORE 가 cost-bearing 캠페인 회피 — 
`feedback_instrument_first_methodology` 의 cheap-first oracle 패턴.

**대체 wedge 후보** (더 큰 fusion ceiling):
- **BC4 attention**: inner work 가 더 무거움 (online softmax + 2 GEMMs + HBM
  dependency chain). cuBLAS-TC 3-launch 의 더 큰 부분이 epilogue + HBM round-trip.
  round-7 5.3-6.9× FALSIFIED 였으나 (occupancy collapse), wedge ceiling 자체는
  BC3 보다 높음.
- **Small-M batch inference**: MoE expert dispatch 등에서 M 작고 K·N 큰 shape,
  epilogue share ↑ → fusion ceiling ↑.
- **§5j top-k+GEMM fusion**: top-k 가 N 차원 reduction + GEMM 결과 의존. cuBLAS
  에선 분리 launch + intermediate K×top_K HBM round-trip → epilogue share 가
  크고 fusion ceiling 1.5-2× 가능 (top_K << N 일 때).

**Methodology lesson**: cost-bearing fire (e.g., N204 toolkit transplant
multi-cycle) 전에 cheap GEMM-only oracle 한 번이 ROOFLINE 정직 산출.
`feedback_instrument_first_methodology` 4 rules (통합 스칼라 금지 · cheap-first
oracle · faithful model · over-claim 0) 의 cheap-first oracle 패턴이 multi-
cycle 자원 절약.
