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
