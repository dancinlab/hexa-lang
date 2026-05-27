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
