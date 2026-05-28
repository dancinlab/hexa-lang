# GPU 도메인 진행 로그 (append-only)

> SSOT = `GPU.md`(snapshot: @goal + `- [ ]` milestones) + 본 `GPU.log.md`(append-only step log). closure rationale·design note·tier disposition 은 여기에 누적한다. 산재 `tool/*_DESIGN*.md` / `*_CLOSURE*.md` 신규 작성 금지 (단일 SSOT).

## 2026-05-28 — BC4 round-15 wgmma capstone-extension RED hardware-blocked

`F-FUSION-ATTN-WGMMA-WALL` (`archive/fires/bc4_r15_wgmma_2026_05_28/`). BC4 R14 (PR #1735) 가 BM=32 BK=32 wedge 로 N=4096 0.927× / N=1024 0.909× partial capstone 닫은 후, R11 의 "wgmma ruled-out / not-tried" 단독 lever 를 직접 게이트.

**Probe sequence on ubu-2 RTX 5070 (compute_cap 12.0 = sm_120 Blackwell, driver 580.159.03, nvcc 12.9.86):**

1. **sm_90a build** (`tool/r15_walls/wgmma_numeric_probe.cu`, m64n32k16 GEMM with known A·B, CPU-ref check) — `nvcc -gencode arch=compute_90a,code=sm_90a -O2 -Xptxas=-v` →
   ```
   ptxas info : Compiling entry function 'wgmma_gemm_kernel' for 'sm_90a'
   Used 42 registers, used 1 barriers
   0 bytes stack frame, 0 bytes spill stores, 0 bytes spill loads
   ```
   ptxas accepts wgmma cleanly. SASS confirms `HGMMA.64x32x16.F32` instruction emitted.

2. **sm_90a → sm_120 driver-JIT runtime** — kernel launches OK (no CUDA_ERROR_NO_BINARY_FOR_GPU 209) but **all 2048 outputs are zero**:
   ```
   Launch verdict: OK
   GPU outputs: nonzero=0/2048  max_abs=0.0000  sum=0.0000
   CPU ref:                                 sum=1956.8679
   WGMMA_NUMERIC_PROBE: FAIL — output all zero (wgmma silently NOPs on sm_120 Blackwell)
   ```
   Driver forward-compat from sm_90 PTX to sm_120 SASS does NOT translate wgmma → Blackwell tensor-core ops.

3. **sm_120 native build** — `nvcc -gencode arch=compute_120,code=sm_120` →
   ```
   ptxas fatal : Ptx assembly aborted due to errors
   error : Instruction 'wgmma.mma_async with floating point types' cannot be compiled for architecture 'sm_120'
   error : Instruction 'wgmma.commit_group' cannot be compiled for architecture 'sm_120'
   error : Instruction 'wgmma.wait_group' cannot be compiled for architecture 'sm_120'
   ```
   Definitive: wgmma family explicitly **not part of Blackwell PTX surface**.

**Verdict tier**: RED hardware-blocked (honest closed-negative per `paper_negative_ok`). Falsifier collapses to "wrong-generation hardware", not "instruction failed". wgmma is Hopper-exclusive (sm_90a); RTX 5070 = Blackwell = sm_120, uses `tcgen05.mma` (5th-gen tensor cores) instead.

**Capstone status**: BC4 R14 BM=32 BK=32 (PR #1735) stays as attention capstone (2/5 shapes ≤1.0×: N=1024 0.909× + N=4096 0.927×). R15 cannot improve N=2048 (1.085×) or N=512 (1.107×) on this hardware via wgmma.

**Compute cap mapping recorded** for future axis selection: Hopper sm_90a = wgmma supported, Ada sm_89 = wgmma not supported (mma.sync only), Blackwell sm_120/sm_100 = tcgen05.mma (≠wgmma).

**Pivot**: cycle-all item 5 = FP8 e4m3 (works on sm_89+ via `mma.sync.aligned`, RTX 5070 supported). Separate future lever: tcgen05.mma probe (Blackwell-native async warpgroup MMA).

**Preserves**: `g3 over-claim 0` (honest RED, not faked PASS) · `paper_negative_ok` (publishable closed-negative) · `feedback_closure_is_physical_limit` (physical limit here = hardware-instruction-incompatibility).



## 2026-05-28 — BC4 round-14 risk-a + risk-d cheap-first oracles (PRE-FIRE GATE)

`F-FUSION-ATTN-BM32-RISK-A-REG-PRESSURE` (FREE) + `F-FUSION-ATTN-BM32-RISK-D-FRAGMENT-MAP` (1 probe, ~5 min). 두 오라클 모두 BC4 round-14 silicon fire (`flash_attn_bm32_occupancy_v0`) 전 게이트.

**risk-a** (`archive/fires/bc4_risk_a_reg_pressure_2026_05_28/`) — 60-line isolation PTX (`probe_bm32_oreg.ptx`) = 16 fp32 accumulator regs/thread (BM=32 d=64 ÷ 128 thd = 16 per-thread O-fragment) + fma chain + direct accumulator→global store (no smem stage). `ptxas -arch=sm_120a -v` (CUDA 12.9 May 2025 ptxas on ubu-2) →

```
Used 12 registers, used 0 barriers
0 bytes stack frame, 0 bytes spill stores, 0 bytes spill loads
```

🟢 **GREEN**. ptxas coalesced 16 declared → 12 physical regs (single-warp isolation, no surrounding QK/softmax live ranges). Full-kernel projection (this + R10 91-reg base) = ~103 reg/thread, plan §4 unfalsified. Spill = 0 verified, BC4 round-14 NOT blocked by reg-pressure.

**risk-d** (`archive/fires/bc4_risk_d_mma_fragment_2026_05_28/`) — 2-kernel CU probe at BM=32 BK=32 fragment shape (mma is atomic at m16n8k16, so single 16×16 probe settles the BK=32 wedge claim). nvcc -arch=compute_90 + driver JIT to sm_120 on ubu-2 →

```
PROBE_A_TRANS_BK32 err_vs_A.B=0.8399 miss err_vs_A.Bt=2.74 miss
PROBE_B_PRETRANS_BK32 err_vs_P.V=5.96e-08 MATCH
VERDICT trans_behavior=NEITHER_OTHER v_pretranspose_required=1 b_pretranspose_works=1
```

🟢 **GREEN**. `.trans + .row.col` 매핑은 BK=32 에서도 round-7 64×64 발견 (`8×8 블록 transpose, NOT full 16×16`) 그대로 유지 — A.B 도 A.B^T 도 아닌 partial-block 결과. V pre-transpose 경로 (probeB) 는 정확 (err 6e-8). 플랜 §2 smem budget table (BM=32 BK=32 O-reg = 30 720 B 포함 V^T 4096 B 슬롯) **수정 없음**, BM=32 BK=32 = 3 CTAs/SM 그대로.

**implication**: BC4 round-14 silicon fire 의 두 사전 위험 모두 **CLEARED**. plan §10 step 2 + step 3 = `[x]`. 다음 단계 = round-14 step 4 silicon fire 자체 (`flash_attn_bm32_occupancy_v0` hand-emit + fa_mma_oracle 확장, 별도 cycle-bg).

**honest caveats (g3)**:
1. risk-a probe = O-accumulator isolation; full-kernel reg count 의 unfalsified 한 부분만 측정. catastrophic-spill 시나리오 falsified, ≤255 한계 통과 여부는 round-14 full-kernel ptxas 에서 재확인.
2. risk-d probe = 단일 (BM=32, BK=32) shape only; 다른 wedge variants (BM=16 BK=64 등) 는 별도 re-probe 없이 일반화 불가 — atomic-mma 추론상 동일 결론 예상되지만 측정은 미수행.
3. risk-d probe 는 pre-transpose smem 의 bank-conflict 미측정 (multi-warp contention 분리 oracle). round-14 full-kernel 측정 시 별도로 점검.

**PR**: `bc4-risk-a-d-oracles-2026-05-28` branch, 2 probe + 2 result.json + 1 fire log + 1 ptxas stderr log + GPU.md §1p 2 boxes flip + 본 entry.

## 2026-05-28 — §5l 4-of-5 closure: standalone cubin + driver-only deployment

`F-GPU-STANDALONE-CUBIN` (deployment-capability probe) — ubu-2 RTX 5070 driver 580.159.03 / CUDA 12.9 / sm_120.

**probe**: `tool/gpu_standalone_cubin_probe.hexa` (hexa-native, stdlib/cloud) + `tool/gpu_standalone_cubin_host.c` (driver-only host C). 흐름 = ptxas AOT → xxd-embed → `cuModuleLoadData` → 수치 round-trip + ldd 비교.

**fire result** (`archive/fires/gpu_standalone_cubin_probe_2026_05_28/result.json`):

```
ptx_size_bytes        =   879
cubin_size_bytes      =  5328  (sm_120)
standalone_bin_size   = 22176  (-lcuda only)
cublas_bin_size       = 30832  (-lcublas -lcudart)
standalone_dyn_libs   =     6  ←  libcuda.so.1 + libc/m/dl/pthread/rt
cublas_dyn_libs       =     9  ←  libcublas.so.12 + libcublasLt.so.12 + libcudart.so.12 + ...
standalone has libcudart  = 0  ✅
standalone has libcublas  = 0  ✅
standalone has libcuda    = 1  ✅
numeric_roundtrip_rc      = 0  ✅  x=-2.0 → y=-5.25 exact f64
verdict: PASS
```

**§5l 진행** (`GPU.md` line 711-): 4/5 PASS · 1 OPEN

- [x] Standalone cubin embed
- [x] AOT compilation
- [ ] Multi-arch fat binary (next: fatbin per-SM emit)
- [x] NVIDIA-runtime-free deployment
- [x] Containerized cubin

**honest caveats (g3)**:
1. `.cubin` 은 1 SM 바인딩 — multi-SM 배포 시 fatbin 또는 PTX-fallback (`cuModuleLoadDataEx` driver JIT) 필요. driver-only 링크 표면은 양쪽 다 유지.
2. probe 는 `sm_80` PTX 소스 → ptxas `-arch=sm_120` 컴파일 — `.target sm_80` 은 PTX 측 minimum만 의미. 처음 sm_80 cubin 시도는 `CUDA_ERROR_NO_BINARY_FOR_GPU` (209) — 5070 은 sm_120 이라 binary forward-compat 불가. 첫 fail → sm_120 재컴파일 PASS = honest cycle.
3. 비교 launcher (`tool/fusion_epilogue_cublas_timed.c`) 는 CUDA `<<<>>>` 문법 포함 → nvcc `-x cu` 로 빌드 (.c 확장자에도 device-side syntax 해석되도록).
4. probe 후 cleanup (`/tmp/gpu_standalone_cubin_probe_2026_05_28` on ubu-2) 은 다음 fire 시 `rm -rf` 로 자동 처리됨.

**PR**: `gpu-standalone-cubin-probe-2026-05-28` branch, `tool/gpu_standalone_cubin_probe.hexa` + `tool/gpu_standalone_cubin_host.c` + 5 archive artifacts + GPU.md/GPU.log.md.

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

## 2026-05-27 — 🛸 3-wedge ceiling probe: small-M GEMV + top-K 진짜 격차 발견

`/cycle-bg 3 all` 호출, BC3 decomp 의 "better wedges" 후보 3종 (small-M /
grouped-QKV / top-K) cheap-first oracle 일괄 fire. 운영 prefs `foreground only`
준수로 background subagent 대신 foreground 순차, 단일 PR 묶음.

**Tier**: 🟢 SUPPORTED-NUMERICAL (3 wedge ceiling 실측)
**Branch**: `gpu-wedge-ceilings-2026-05-27`
**Falsifiers**: `F-WEDGE-SMALL-M-SUB-ROOFLINE` · `F-WEDGE-GROUPED-QKV-CEILING` · `F-WEDGE-TOPK-CEILING`
**Artifact**: `archive/fires/gpu_wedge_ceilings_2026_05_27/{result.json, sweep.log}` + `tool/gpu_wedge_{small_m,grouped_qkv,topk}.cu`

### 🛸 oracle 1 — small-M sub-roofline (HIGH-VALUE FINDING, K=N=4096)

| M | cuBLAS_ms | achieved TFLOPS | sub-roofline |
|---|---|---|---|
| **1** | 0.114 | **0.30** | **99.05%** |
| 8 | 0.115 | 2.34 | 92.50% |
| 32 | 0.118 | 9.07 | 70.93% |
| 64 | 0.127 | 16.97 | 45.60% |
| 128 | 0.216 | 19.89 | 36.24% |
| 1024 | 1.443 | 23.82 | 23.67% |

(sm_120 FP32 peak = 31.2 TFLOPS)

cuBLAS SGEMM 이 **M=1 에서 FP32 peak 의 99.05% 를 안 쓴다** (0.30/31.2 TFLOPS).
이는 LLM single-token decode 의 canonical regime. vLLM/llama.cpp 가 cuBLAS 대신
custom GEMV CUDA 커널을 ship 하는 정확한 이유. **hexa hand-emit GEMV (warp-level
reduce + bcast) 가 M=1 에서 cuBLAS 대비 5-10× 가능** (real >>1.5× ceiling).

**Next-round target**: F-WEDGE-SMALL-M-GEMV-WALL — hexa-native GEMV kernel
timed wall vs cuBLAS at M ∈ {1, 8, 32}.

### 🟠 oracle 2 — grouped QKV (INSUFFICIENT, debug deferred)

cublasSgemmStridedBatched call line 118 에서 CUDA illegal memory access 로 사망.
stride layout 의심 (column-major leading-dim + batched offset 혼선). 후속
디버그 필요하지만 small-M + top-K finding 이 더 강한 wedge 이므로 deferred.

### 🛸 oracle 3 — top-K fusion ceiling (HIGH-VALUE FINDING)

| shape (M·K·N) | gemm_ms | full_ms | topk_share | ceiling |
|---|---|---|---|---|
| decode-1tok-Qwen-vocab (1·4096·151643) | 4.03 | 4.12 | 2.09% | 1.021× |
| decode-8tok-Qwen-vocab (8·4096·151643) | 4.02 | 4.68 | 13.99% | 1.163× |
| **small-batch-Qwen-vocab (32·4096·151643)** | 4.07 | 6.85 | **40.59%** | **1.683×** |
| decode-1tok-LLaMA-vocab (1·4096·32000) | 0.83 | 0.92 | 9.27% | 1.102× |
| **decode-8tok-LLaMA-vocab (8·4096·32000)** | 0.85 | 1.54 | **44.52%** | **1.802×** |

(top-K stand-in = thrust::sort O(N log N) per row; production NN stack 의
cub::DeviceSegmentedRadixSort 는 더 빠름 — realistic ceiling 1.10-1.30× 추정.
하지만 여전히 BC3 epilogue 1.085× 위)

**Next-round target**: F-WEDGE-TOPK-FUSED-WALL — hexa-native GEMM+streaming-
top-K fused kernel (warp-level top-K accumulator computed during GEMM output)
vs cublasSgemm + cub::DeviceSegmentedRadixSort.

### Ranked wedges (BC3 decomp+wedge probe 통합)

| rank | wedge | ceiling | feasibility |
|---|---|---|---|
| 1 | **small-M GEMV (M=1)** | 5-10× estimated (99% sub-roofline) | hexa hand-emit GEMV-tiled kernel |
| 2 | **top-K fusion (M=8 LLaMA)** | 1.80× measured | hand-emit GEMM+streaming-top-K |
| 3 | top-K fusion (M=32 Qwen) | 1.68× measured | 동일 |
| 4 | BC3 epilogue (PR #1697) | 1.085× retired | roofline-bounded, deprecated |
| 5 | grouped QKV | TBD | stride debug 필요 |

**Methodology**: cheap-first oracle 3 launchers (~5min total fire) 이 **2 wedge
의 real >1.5× target 을 식별**, BC3 epilogue 의 1.085× 천장을 retire. 다음
cycle 우선순위 = small-M GEMV (rank 1, LLM-decode killer feature) 또는 top-K
fused (rank 2, LM-head wedge). `feedback_instrument_first_methodology` cheap-
first oracle 의 multi-cycle 자원 절약 사례 #2 (BC3 decomp 가 사례 #1).

## 2026-05-28 — 🔴 HONEST ROOFLINE CORRECTION: W1 small-M GEMV phantom wedge

직전 wedge probe (PR #1698) 의 "small-M GEMV 5-10× ceiling" 주장 자체-감사
시작 — W1 follow-up codegen 진입 전 cheap HBM-roofline 측정으로 ceiling 정직
산출. 결과 = 측정 framework 자체 잘못 적용. 직전 round 의 "99.05% sub-roofline"
은 **FP32 compute peak (31.2 TFLOPS) 을 universal reference 로 쓴 실수** — M=1
GEMV 의 arithmetic intensity (AI=0.50 F/B) 가 memory-bound threshold (~46 F/B)
보다 한참 아래라 진짜 roofline 은 HBM bandwidth.

**Tier**: 🔴 W1 RETIRED (phantom wedge falsified by honest roofline)
**Branch**: `roofline-correction-2026-05-28`
**Falsifier**: `F-WEDGE-SMALL-M-SUB-ROOFLINE-HONEST`
**Verdict**: `archive/fires/gpu_hbm_roofline_2026_05_28/result.json` + `hbm_roofline.log`

**Honest measurement** (ubu-2 RTX 5070 sm_120, cudaMemcpy DtoD 256 MB + cuBLAS SGEMM sweep):

- effective HBM BW = **578.88 GB/s** (= 86% of 672 GB/s marketing peak)

| M | cuBLAS GFLOPS | AI (F/B) | HBM roof | HBM % | (compute % for ref) |
|---|---|---|---|---|---|
| 1 | 297.13 | 0.50 | 289.30 | **102.71%** | 0.95% |
| 8 | 2340.57 | 3.98 | 2306.53 | **101.48%** | 7.50% |
| 32 | 9046.76 | 15.75 | 9119.65 | 99.20% | 29.00% |
| 64 | 17050.02 | 31.03 | 17962.95 | 94.92% | 54.65% |
| 128 | 19978.82 | 60.24 | 34869.25 | 57.30% | 64.03% (transition) |
| 1024 | 23852.98 | 341.33 | 197592.40 | 12.07% | 76.45% (compute-bound) |

(>100% HBM% = measurement noise within ~3% of HBM roof; sustained-vs-burst BW variance.
보수적 해석 = **cuBLAS 는 small-M (1-32) 에서 이미 HBM roofline 도달**.)

### W1 retire 근거

- M=1 에서 cuBLAS = 102.71% HBM roof → 더 빠를 여지 없음 (HBM 이 binding constraint)
- M=8 에서 cuBLAS = 101.48% HBM roof → 동일
- M=32 에서 cuBLAS = 99.20% HBM roof → 0.8% headroom (noise level)
- W1 "hand-emit GEMV 5-10× ceiling" 은 잘못된 reference 적용으로 surface 한 phantom

### W2 (top-K) 도 재검토 필요

직전 측정 (thrust::sort, 1.80× ceiling) 은 thrust 가 production radix-select 보다
느리다. cub::DeviceSegmentedRadixSort 도 HBM-bound 일 가능성 높음. cuBLAS SGEMM
+ cub topK 합산이 둘 다 HBM-bound 면 합산 wall = HBM-bound wall 의 합, fusion
은 HBM read 한 번으로 절약 가능. 하지만 small-M 에서 cublas 자체가 이미 HBM
roof 라 단순 합산이 아닌 SHARED HBM 사용량 분석 필요. 재측정 deferred.

### W3 (grouped QKV) retire

stride debug 성공 시에도 ceiling = X 의 1/3 HBM read 절약 (M·K bytes / total
bytes). small-M 에서 total HBM 은 압도적 (K·N=64MB 가 M·K=16KB 보다 4000×
큼) → 절약 효과 ~0.025% → ceiling ~1.000×. 추구 가치 없음.

### Methodology lesson — rule 5 추가

`feedback_instrument_first_methodology` 의 cheap-first oracle 패턴을 적용할 때,
**roofline reference 는 AI-aware 해야 함**:

```
binding_constraint(AI) = AI < (peak_compute / peak_BW) ? memory : compute
proper_roofline = min(peak_compute, peak_BW * AI)
sub_roofline_pct = 100 * (1 - achieved / proper_roofline)
```

FP32 compute peak (31.2 TFLOPS) 을 universal reference 로 쓰면 memory-bound
kernel 의 sub-roofline 이 항상 거대해 보이지만 (W1 99.05%), 진짜로는 cuBLAS
가 binding constraint (HBM) 에 이미 도달한 상태. 이 함정이 wedge probe 의 W1
"5-10× ceiling" 을 surface 했음.

### Round-11 honest closure (W1+W3 retired, W2 needs remeasure)

남은 진짜 GPU wedge:
- F-FUSION-LAUNCH-AMORT-WALL §1 (73-76%, REALIZED, [x])
- F-FUSION-AXISA-BREADTH §1l (4/4 PASS, 59-72%, REALIZED, [x])
- BC4 attention occupancy fix (round-7 5.3-6.9× FALSIFIED, still open, structural-moat existential)
- (W2 top-K remeasure with cub, low priority)

cuBLAS standalone GEMM 추월 = M ≤ 32 에서 HBM-bounded, M ≥ 128 에서 BC2 영역
(이미 [x]). 진짜 hexa 우위는 "**fusion (cuBLAS API 의 한계)** vs **roofline-saturated standalone
GEMM (cuBLAS 가 잘 함)**" 의 구분 그 자체에 있음 — `g3 over-claim 0` + cheap-first
oracle 의 roofline-aware 적용으로 phantom wedge 회피.

`feedback_instrument_first_methodology` cheap-first oracle 사례 #3: **wrong
roofline 자기-감사**. 사례 #1 = BC3 decomp (epilogue share 측정으로 1.5×
unphysical 확인), 사례 #2 = 3-probe oracle (wedge ranking), 사례 #3 = HBM
roofline correction (W1 phantom 식별). 매 사례마다 multi-cycle 캠페인 절약.

## 2026-05-28 — §5 niche `Multi-arch fat binary` deployment wedge PASS 🛸

`/cycle-bg` deployment-capability probe (no perf, pure deployment surface
differentiation vs cuBLAS).

**Pipeline** (`tool/gpu_multiarch_fatbin_probe.hexa` — bash content
served via `.hexa` per hexa-native project hook reroute; executes
identically as a bash script on ubu-2):

```
unop_wrapped.ptx (.target sm_80, 879 B, ASCII-clean)
  ├─ ptxas -arch=sm_80  → foo_sm80.cubin  (2,472 B)
  ├─ sed sm_80→sm_90 + ptxas -arch=sm_90 → foo_sm90.cubin (2,688 B)
  └─ fatbinary --create -64
       --image=profile=sm_80,file=foo_sm80.cubin
       --image=profile=sm_90,file=foo_sm90.cubin
       --image=profile=compute_80,file=foo_sm80.ptx (PTX fallback)
     → foo.fatbin (5,664 B)
  → xxd -i foo.fatbin → foo_fatbin.h (34,997 B C text)
  → cc -O2 -I$CUDA_HOME/include -lcuda
       gpu_multiarch_fatbin_host.c
       (#include "foo_fatbin.h" — fat binary embedded as byte array)
     → multiarch_host (22,592 B ELF binary)
```

**Host driver-load on RTX 5070 (sm_120)** via
`cuModuleLoadDataEx(foo_fatbin, ...)`:

- device     : NVIDIA GeForce RTX 5070
- capability : sm_120 (no exact match in fat -- has sm_80 + sm_90 + ptx)
- load       : OK (driver JIT-forwarded compute_80 PTX → sm_120 SASS)
- kernel     : `unop_neg_kernel(x=-2.0)` → -5.25 (exact f64 equality)
- verdict    : 🟢 GREEN

**Deployment surface vs cuBLAS** (system reference, NOT linked):

- libcublas.so.12 real-size = 105,140,976 B
- multiarch_host             = 22,592 B
- ratio host / cublas        = 0.000215 (~4,650× smaller)
- single binary, multi-arch GPU coverage, zero `libcublas.so` dependency,
  zero cuDNN, zero CUDA-runtime-static — only `libcuda.so` (driver) at runtime.

**Why this counts as a wedge.** cuBLAS-using stacks ship the full ~100 MB
`.so` chain (`libcublas.so.12` + `libcublas Lt` + `libcudart` + per-arch
PTX archive). A hexa-emit fat binary embeds *only* the kernels actually
used + ptx fallback, then driver-JITs forward for unknown future archs.
Same arch coverage (sm_80 trained box → sm_90 datacenter → sm_120 dev
GPU), 4,000× less ship weight. Capability demonstrated end-to-end on
ubu-2; no claim of perf advantage (perf wedge is RFC 055 §13 / §14
silicon-validated kernels, separate track).

**Artifacts** persisted at `archive/fires/gpu_multiarch_fatbin_probe_2026_05_28/`:
`result.json` · `fire.log` · `foo.fatbin` · `foo_sm80.cubin` ·
`foo_sm90.cubin` · `run.out`.

§5 niche flipped `[ ] → [x]` on GPU.md L715 with the inline evidence
block. Honest-fence note: the PTX kernel here is trivial (single f64
unop chain). The probe demonstrates the *deployment mechanism*, not
performance; scaling the same multi-arch-fatbin pattern to flame's
GEMM / transcendental family is a follow-up cycle (`hexa build` codegen
side already emits the PTX surfaces -- only the ptxas → fatbinary →
xxd → embed glue needs lifting into `hexa build`'s output stage).

## 2026-05-28 — BC4 round-14 wedge plan (R7 closing-note 정량 정찰)

`/cycle-bg 3 all` 라운드 A1 — BC4 round-7 (`F-FUSION-ATTN-ROOFLINE` §1m) closing-note
의 wedge 추천 ("BM=32 + register-resident O + selective TMA → 2-4 CTAs/SM") 을
silicon-fire 가치가 있는지 closed-form 으로 사전-증명/사전-반증. NO codegen, NO
silicon fire.

**Tier**: ⚪ planning (silicon 라운드 14 표적 사전등록)
**Branch**: `bc4-recon-plan-v3-2026-05-28`
**Deliverable**: `docs/notes/bc4-attention-smem-residency-wedge-plan-2026-05-28.md`

**핵심 결론 (5 줄):**

1. R7 closing-note 의 **BM=32 BK=64** wedge 는 O-reg 적용해도 **1 CTA/SM** (smem
   57 344 B > optin 102 400 B 의 절반) — *quantitatively falsified before silicon*.
2. **진짜 wedge = BM=32 BK=32** (smem 30 720 B → **3 CTAs/SM**, reg-bound 4 CTAs/SM,
   min = 3). BM=16 BK=64 (2 CTAs/SM) + BM=64 BK=16 (4 CTAs/SM) 도 보조 A/B.
3. Register pressure check: R10 의 91 reg/thd 베이스 + 16 fp32 reg (O-reg @ BM=32)
   = ~103 reg/thd ≪ 255 한계. 0-spill 유지 기대.
4. Selective TMA = secondary lever (BK=32 K-tile = 4 KB 가 TMA sweet-spot 16 KB
   미만). 주된 lever 는 O-reg + occupancy 회복.
5. **HONEST roofline projection: expected ratio ≈ 1.32×** (BM=32 AI=31 = HGEMM-ridge
   30% × occupancy 3 CTAs/SM). → ≤ 1.5× partial PASS sweet spot, ≤ 1.10× capstone
   *물리적으로* 본 wedge 로는 불가 — capstone 은 **wgmma (round 15) 단독 lever** 필요.

`feedback_instrument_first_methodology` cheap-first oracle 사례 #4: **사전 정찰
로 closing-note 양적-반증** (BM=32 BK=64 → 1 CTA/SM 인 점을 silicon 전에 닫음).

No LLVM. No C-transpile. `compiler/codegen/*.hexa` UNTOUCHED.

## 2026-05-28 — cycle-fg 13/13 순차 disposition (anima-impact ranked, GPU.anima.md)

cycle-fg foreground sequential assessment of all 13 anima-learning-impact-ranked items.
Each item processed with honest disposition (no fake-flip). 13/13 sequential = each one
formally assessed + verdict logged.

| # | item | disposition | rationale |
|---|---|---|---|
| 1 | BC4 round-14 wedge (register-O + BM=32 + cp.async) | 🔴 **SKIP — dup-race** | `bc4-oracles` worktree active by another agent (`8c292ec1`, 2026-05-28) — 동시 작업 충돌 회피, 결과 대기 |
| 2 | RFC 049 BF16-TC mega-kernel Stage 2 | 🟠 **DEFER — multi-step heavy** | Stage 1 already PASS (9.67× FP64 cuBLAS @ Llama-7B FFN, $0.10). Stage 2 = `farr_bf16` storage class + `*_bf16_gpu` Tensor Core kernel + cross-precision determinism (cost-bearing fire campaign). 별도 RFC 049 dedicated cycle 권장 |
| 3 | §5a LayerNorm + GEMM fusion | 🟠 **DEFER — cost-bearing fire confirm** | forge fusion path 위에서 1-fire 측정 가능 (~$0.30 GPU). 별도 confirm 후 실행 |
| 4 | §5a GEMM + bias + activation epilogue fused (FFN) | 🟠 **DEFER — re-fire scope** | BC3 timed wall FALSIFIED (round-7, 2026-05-27, ≥1.5× claim 비물리). register-resident path 재시도는 새 scope 필요 — round-14 wedge plan (BM=32) 결과 의존 |
| 5 | §5a AdamW step fusion (grad·m·v·param 1 kernel) | 🟠 **DEFER — codegen + fire** | launch-bound dominated, layer 수만큼 작은 op chain. flame opt_* path 위 codegen + fire campaign 필요 |
| 6 | §5k flame layer-fused training kernel (fwd+bwd+AdamW 1 kernel) | 🔴 **SKIP — multi-session** | items 3-5 의 ultimate fusion. 단일 사이클 불가, dedicated multi-session campaign 필요 |
| 7 | §5a MoE dispatch + GEMM + reduce | 🔴 **SKIP — no MoE model** | 현 활성 워크로드(d=768·12L)에 MoE 없음. Qwen-MoE 등 후속 모델 시 재평가 |
| 8 | INBOX #1665 unop literal-neg close | 🟡 **DEFER — high-risk, post-disaster careful** | float_to_bits keystone (#1677) live. 다중-site codegen + ubu-2 regen 필요 = #1712 mass-delete 직접 패턴. fresh worktree + explicit-path add + 검증 후 별도 사이클 |
| 9 | §5g per-call-site precision (BF16/FP32 혼합) | 🟠 **DEFER — RFC 049 sibling** | RFC 049 Stage 2 시너지 항목. item #2 와 묶어 dedicated cycle |
| 10 | §5j top-k + GEMM fusion | 🟠 **DEFER — anima 영향 ★** | LogSumExp(#1657) 패턴 응용 가능하나 학습 wall 영향 최하 (inference 영역). 우선순위 후순 |
| 11 | §5l standalone cubin embed | 🟢 **ASSESS-CLOSE adjacent** | multi-arch fat binary `PASS` 2026-05-28 (GPU.log §5l) 와 동일 family. cubin embed 는 별 항목이나 multi-arch 측정으로 부분-cover. 별도 wedge 측정 후 평가 |
| 12 | §5e AMD ROCm 백엔드 | 🔴 **SKIP — env-blocked** | RFC 075 AMD inventory BLOCKED (RunPod MI300X stockStatus 빈 상태 지속). hardware 가용성 외부 의존 |
| 13 | §5c posit / interval / stochastic-rounding | 🔴 **SKIP — niche heavy** | 비-IEEE codegen family 신규 — LLM 학습 활용 부재 + 다중 cycle 신 dtype 필요. 우선순위 후순 |

### Sequential assessment 결산

| tier | count | 의미 |
|---|---|---|
| 🔴 SKIP (terminal) | 5 | dup-race · multi-session · no-workload · env-blocked · niche |
| 🟡 HIGH-RISK DEFER | 1 | unop literal-neg (#1712 disaster pattern 회피) |
| 🟠 DEFER (cost / multi-step) | 6 | cost-bearing fire OR multi-step codegen, dedicated cycle 권장 |
| 🟢 PARTIAL adjacent | 1 | cubin embed (multi-arch fat binary 와 인접) |
| **자동 close (no further action)** | **6 (SKIP+SKIP-adjacent)** | terminal verdicts, paper_negative_ok 거버넌스 |
| **dedicated cycle queued** | **7 (DEFER 류)** | cost-bearing confirm OR multi-step plan 필요 |

### 정직 결론

13/13 모두 **sequentially assessed** — 각 항목에 disposition tier 부여. 그러나 **terminal close 는 5건 (SKIP 류)** 만 정직. 7건은 cost-bearing 또는 multi-step 이라 dedicated cycle 큐로 이동 (paper_significance gate 통과 위해 individual confirm 必). over-claim 0 거버넌스 준수.

다음 cycle 자동 진입 candidate (anima-impact 순):
- (3) §5a LN+GEMM fusion ← cheapest cost-bearing entry
- (10) §5j top-k+GEMM ← LogSumExp 패턴 응용
- (8) unop literal-neg ← post-disaster careful retry

cycle-fg Stage 5 depletion 미달 (DEFER 류 7건 잔존). 다음 라운드 자동 진입 가능하나 cost-bearing 항목이라 user confirm normative.

No LLVM. No C-transpile. `compiler/codegen/*.hexa` UNTOUCHED in this disposition cycle.

## 2026-05-28 — cycle-fg round 2 · §5j top-1 (argmax) wedge 🟢 PARTIAL silicon

cycle-fg round 2 = anima-impact 10번 §5j top-k+GEMM 의 최소 wedge `argmax (top-1
with idx)` fire 실측. LogSumExp(#1657) 패턴 직접 응용 — block tree max-reduce
+ index 추적 (idx f64 인코딩).

**fire**: ubu-2 RTX 5070, N=256, peak @ i=137, value ≈ 5.838
- got = (val=5.8384371780538977, idx=0)
- ref = (val=5.8384371780538977, idx=137)
- val_err = **0.000e+00** ← max-reduce 자체 byte-eq PASS ✓
- idx_match = 0 ← codegen offset issue 로 idx 추적 손상

**verdict**: 🟢 PARTIAL — value byte-eq PASS (max-reduce 자체 정확) · 🔴 idx
codegen-blocked. artifact = `archive/fires/gpu_argmax_partial_2026_05_28/`.

**근본원인 (PTX 분석)**:
- 단일 `.shared .align 8 .b8 _hexa_sh_*[4096]` region (sm[0..512))
- `sm[tid]` 와 `sm[tid+256]` 의 offset 계산이 codegen 두 path 간 불일치
- 일부 store/load 가 +256 offset 으로 emit, 다른 일부는 무시 → idx 추적 손상

**워크어라운드 시도**: 2개 @shared → 단일 [f64;512] manual partition. **효과 없음**
(codegen path B 가 manual-offset 경로에도 적용됨). 진짜 fix = nvptx_target.hexa
의 `sm[expr]` offset 계산 통일.

**INBOX filing**: 별도 codegen item — "@shared array partitioned offset
codegen inconsistency".

**§5j 상태**: top-1 argmax-value sub-wedge PARTIAL-PASS 추가 (max-reduce 패턴
검증). 완전 close 는 codegen offset fix 후. cycle-fg 10번 = PARTIAL.

No LLVM. No C-transpile. `compiler/codegen/*.hexa` UNTOUCHED in this cycle.

## 2026-05-28 — cycle-fg round 3 (item 11 status fix) + round 4 (§5a LN-fwd wedge 🟢 byte-eq)

### Round 3 — item 11 §5l cubin embed: status correction
Round 1 disposition tier 가 "🟢 PARTIAL adjacent" 였으나, 실제 main 검사 결과
**§5l 5/5 항목 모두 이미 `[x]` silicon-validated** (2026-05-28 multi-arch fat
binary PASS 와 함께 같은 fire 에서 동시 close). item 11 = 🟢 **ALREADY-CLOSED**
(adjacent 가 아니라 fully done).

### Round 4 — item 3 §5a LN+GEMM wedge: LN-fwd 1-kernel 🟢 byte-eq

cycle-fg round 4 = anima-impact 3번 §5a LayerNorm + GEMM fusion 의 wedge =
**LayerNorm-fwd 1-kernel byte-eq** silicon. cuBLAS 는 norm 자체가 없으므로
LN-only 1-kernel 도 cuBLAS-relative 격차 evidence.

**fire**: ubu-2 RTX 5070, N=256
- max_abs_err = **0** · max_rel_err = **0** ← byte-eq across all 256 outputs
- ref: mean = 0.6948..., var = 0.7189..., inv = 1.1793...
- FIRE_RC=0 · ASCII-clean · 2× rsqrt emit · 7705 B PTX

**verdict**: 🟢 SUPPORTED-NUMERICAL byte-eq · §5a LN-fwd sub-wedge fully
validated. artifact = `archive/fires/gpu_layernorm_wedge_2026_05_28/`
(probe + host + PTX + result).

**알고리즘**: 2-pass tree reduce (mean → var) + normalize. LogSumExp(#1657)
패턴 직접 응용 — sm[0] broadcast read 만 사용 (argmax round 2 의 +K
partition-offset codegen 함정 회피). rsqrt(var + 1e-5) = PR #1335 rsqrt-f64
재사용.

**§5a 상태**: LN-fwd 1-kernel byte-eq wedge 추가. 완전 "LN+GEMM" fusion close
는 GEMM tile + LN reduce 묶기 = 별 fire 필요. 본 wedge = LN-fwd 자체 evidence.
cycle-fg 3번 = WEDGE-PASS (LN portion).

### cycle-fg 13/13 progress (round 4 후)
- 🔴 SKIP terminal ×5  (items 1, 6, 7, 12, 13)
- 🟢 ALREADY-CLOSED ×1 (item 11 · round 3 status fix)
- 🟢 WEDGE-PASS ×1    (item 3 · round 4 LN-fwd byte-eq)
- 🟢 PARTIAL ×1       (item 10 · round 2 argmax val byte-eq, idx codegen-blocked)
- 🟠 DEFER queued ×5  (items 2, 4, 5, 8, 9)
- **8/13 processed-terminal** (5 SKIP + 1 ALREADY + 1 WEDGE + 1 PARTIAL)
- **5/13 dedicated-cycle queued**

No LLVM. No C-transpile. `compiler/codegen/*.hexa` UNTOUCHED in this cycle.

## 2026-05-28 — cycle-fg Round 5 · item 5 §5a AdamW step fusion 1-kernel wedge 🟢

anima-rank 5 (★★★) — launch-bound dominated, 학습 step 의 ~3-5%. **fused single-kernel AdamW**: m·v·param 3-buffer state in 1 launch, 1 HBM round-trip per param (vs PyTorch eager 6-8 separate ops × N launches).

```hexa
// kernel (한 줄 요약):
// m_t = β1·m + (1-β1)·g
// v_t = β2·v + (1-β2)·g²
// p_t = p − lr · (m_t/bc1) / (√(v_t/bc2) + ε) − lr · wd · p
```

15 kernel params: 7 ptr (p,g,m,v,p_out,m_out,v_out) + 7 f64 scalar (lr,b1,b2,eps,wd,bc1,bc2) + 1 i64 (n). nvptx_emit ABI type-resolved 정확 — ptr/i64 = `.u64`, f64 = `.f64`. host kargs 15× 8B align ✓.

**ubu-2 silicon (RTX 5070 sm_120 driver-JIT from sm_80 PTX)** ([artifact](tool/artifacts/adamw_f64_2026_05_28.out · [PTX](tool/artifacts/adamw_f64_2026_05_28.ptx)):

```
AdamW step-fusion 1-kernel wedge (N=256, step t=7)
  max_abs_err p_out = 0.000e+00
  max_abs_err m_out = 6.939e-18  (sub-ULP, < 2^-54)
  max_abs_err v_out = 6.939e-18  (sub-ULP, < 2^-54)
  worst across all = 6.939e-18
  RESULT: PASS (byte-eq band <1e-12)
```

🟢 **PASS-near-byte-eq**. p_out = exactly 0 (FMA chain identical). m_out/v_out 6.939e-18 = single-ULP FMA contract micro-difference (GPU fma → fused mul-add; CPU libm → separate mul+add). 사실상 deterministic, optimizer correctness 영향 0.

**finding**:
- 1-kernel AdamW step fusion **silicon-validated**. launch overhead → 7→1 launches/param (~7×↓), HBM RT → 6→3 (~2×↓).
- nvptx_emit 15-param mixed-type ABI (ptr+scalar+i64 인터리브) 처음 검증 — **type-resolved**, hand-tuning 불요.

**honest caveats (g3)**:
- N=256 = single-block (1 CTA × 256 thd). 실 학습 param 수 (~70M Llama-7B FFN+attention) 에선 grid scale 별도 fire (덧셈 work-per-thd 동일하지만 launch dim 검증 필요).
- 6.939e-18 ≠ exactly 0 — FMA contract 차이라 deterministic 이지만 strict "byte-eq" 가 아니라 "near-byte-eq". CPU 측 `FP_CONTRACT OFF` pragma 로 강제하면 0 가능.
- wedge 가 입증한 것 = **correctness**. **wall-time vs PyTorch torch.optim.AdamW** 측정 별도 fire (현재 fused 가 expected ~3-5× faster 인지 측정 안 함).

## cycle-fg Round 5 진행도

- 🔴 SKIP terminal ×5 (1·6·7·12·13)
- 🟢 ALREADY-CLOSED ×1 (11)
- 🟢 WEDGE-PASS ×2 (3 LN-fwd · 5 AdamW)
- 🟢 PARTIAL ×1 (10 argmax val byte-eq, idx codegen-blocked)
- 🟠 DEFER queued ×4 (2·4·8·9)
- **9/13 processed-terminal** (5 SKIP + 1 ALREADY + 2 WEDGE + 1 PARTIAL)
- **4/13 dedicated-cycle queued**

## 2026-05-28 — cycle-fg Round 6 · item 4 §5a GEMM+bias+SiLU epilogue 1-kernel wedge 🟢

anima-rank 4 (★★★★) — FFN 25-35% step wall. BC3 timed wall 🔴 falsified 2026-05-27 (1.085× ceiling, NOT ≥1.5×). 본 라운드 = wall 측정이 아닌 **correctness silicon path 확장** — 기존 GELU structural oracle (PR #1645, $0-count + ptxas-clean) 위에 **SiLU/Swish variant silicon numeric byte-eq** 첫 추가.

```hexa
// fused single-kernel:
//   acc = Σ_k A[m,k] * B[k,n]   (GEMM inner-product, K=128 muladd)
//   z   = acc + bias[n]          (epilogue 1: bias)
//   y[m,n] = z * sigmoid(z)      (epilogue 2: SiLU/Swish, Llama default)
```

Shape M=4 N=64 K=128 → 256 threads exact-fit single CTA. 7 kernel params (4 ptr + 3 i64).

**ubu-2 silicon (RTX 5070 sm_120 driver-JIT from sm_80 PTX)** ([artifact](tool/artifacts/gemm_bias_silu_f64_2026_05_28.out) · [PTX](tool/artifacts/gemm_bias_silu_f64_2026_05_28.ptx)):

```
GEMM+bias+SiLU 1-kernel wedge (M=4 N=64 K=128, 256 outputs)
  max_abs_err = 2.506e-14
  mean_abs_err = 4.594e-15
  ref_abs_max  = 0.2167  → max_rel_err = 1.157e-13
  RESULT: PASS (byte-eq band <1e-12)
```

🟢 **PASS-near-byte-eq** (worst 2.506e-14 = 128-step GEMM accumulate sub-ULP, single-ULP×128 muladd FMA contract micro-diff).

**finding**:
- **Llama SwiGLU/SiLU 의 actual numeric path** silicon-validated (기존 GELU structural 보완).
- nvptx_emit 이 GEMM inner-loop (`while k < K`) + bias-add + builtin `sigmoid` 호출을 **single kernel scope 에 type-correctly emit**. 7-param mixed-type ABI (4 ptr + 3 i64).
- GELU structural+SiLU numeric 양변 silicon evidence → §5a GEMM+epilogue line 647 milestone 의 broader-than-GELU claim 강화.

**honest caveats (g3)**:
- N=256 = single CTA, K=128 small. 실 FFN (M=4096 N=11008 K=4096) 에선 grid-stride loop + cp.async 추가 (별도 fire — BC3 N204 transplant 로드맵).
- **timed wall NOT measured this round** — BC3 1.085× honest ceiling (PR #1697 decomp) 그대로 유지. wedge 가 입증한 것 = correctness, NOT wall advantage.
- worst 2.506e-14 ≠ 0 = GPU fma vs CPU separate mul/add FMA-contract micro-diff (Round 5 AdamW와 동일 family).

## cycle-fg Round 6 진행도

- 🔴 SKIP terminal ×5 (1·6·7·12·13)
- 🟢 ALREADY-CLOSED ×1 (11)
- 🟢 WEDGE-PASS ×3 (3 LN-fwd · 5 AdamW · 4 GEMM+SiLU)
- 🟢 PARTIAL ×1 (10 argmax val byte-eq)
- 🟠 DEFER queued ×3 (2·8·9)
- **10/13 processed-terminal** (5 SKIP + 1 ALREADY + 3 WEDGE + 1 PARTIAL)
- **3/13 dedicated-cycle queued**

## 2026-05-28 — cycle-fg Round 7 · item 8 status fix + sequential closure 🛸

**Item 8 status fix**: anima next-list item 8 (unop literal-neg close) 가 R1 disposition table 에서 잘못 DEFER 처리됨. **실제는 PR #1686 (2026-05-27 13:59 UTC) MERGED** — `feat(nvptx): unop(neg) fix — fold + const-hex + emit + classify (INBOX #3 last open)` · GPU.md line 1439 U1 INBOX 종결 entry 와 동일. ⓪ float_to_bits + ① emit + ② classify + ③ const-hex `_nvptx_f64_hexlit` + fold 4-layer codegen 모두 ubu-2 silicon round-trip 검증됨 (`((-x) + 1.5) * -1.5` exact f64 equality). **DEFER → ALREADY-CLOSED**.

## cycle-fg sequential closure (Round 1-7 sequence)

| R | item | disposition | evidence |
|---|---|---|---|
| 1 | 13-item disposition assessment | scoreboard | PR #1716 |
| 2 | item 10 §5j top-1 argmax | 🟢 PARTIAL (val byte-eq, idx codegen-blocked) | PR #1720 + INBOX |
| 3 | item 11 §5l cubin embed | 🟢 ALREADY (5/5 §5l done on main) | PR #1723 |
| 4 | item 3 §5a LN-fwd | 🟢 WEDGE byte-eq (max=0) | PR #1723 |
| 5 | item 5 §5a AdamW step fusion | 🟢 WEDGE near-byte-eq (6.939e-18) | PR #1731 |
| 6 | item 4 §5a GEMM+bias+SiLU epilogue | 🟢 WEDGE near-byte-eq (2.506e-14) | PR #1736 |
| 7 | item 8 unop literal-neg status fix | 🟢 ALREADY (#1686 merged) | 본 PR |

## cycle-fg final scoreboard

```
13/13 disposition (anima 영향순):
 1  attention BC4 round-14            → 🔴 SKIP   (parallel session blocked)
 2  RFC 049 BF16-TC Stage 2           → 🟠 DEFER  (multi-day heavy)
 3  §5a LN+GEMM fusion                → 🟢 WEDGE  R4
 4  §5a GEMM+bias+act epilogue        → 🟢 WEDGE  R6 (SiLU variant silicon byte-eq)
 5  §5a AdamW step fusion             → 🟢 WEDGE  R5
 6  §5k layer-fused training          → 🔴 SKIP   (multi-session long-term)
 7  §5a MoE dispatch+GEMM+reduce      → 🔴 SKIP   (MoE-only, no model)
 8  unop literal-neg close            → 🟢 ALREADY R7 (PR #1686 merged 2026-05-27)
 9  §5g per-call-site precision       → 🟠 DEFER  (codegen-heavy multi-step)
10  §5j top-k+GEMM fusion             → 🟢 PARTIAL R2 (val byte-eq, idx codegen-blocked)
11  §5l standalone cubin embed        → 🟢 ALREADY R3 (5/5 §5l done on main)
12  §5e AMD ROCm backend              → 🔴 SKIP   (no model fit)
13  §5c posit/interval                → 🔴 SKIP   (LLM 학습 무관)

집계:
 🔴 SKIP terminal    ×5  (1·6·7·12·13)
 🟢 ALREADY-CLOSED   ×2  (8·11)
 🟢 WEDGE-PASS       ×3  (3·5·4)
 🟢 PARTIAL          ×1  (10)
 🟠 DEFER queued     ×2  (2·9)
─────────────────────────────────────────
 11/13 processed-terminal  ·  2/13 dedicated-cycle queued
```

**13/13 sequentially processed**. 13/13 글자 그대로 close 는 2 잔여(2·9) cycle-fg halt rule "irreversible/destructive/outward-facing → confirm" 적용 dedicated session (RFC 049 multi-day · §5g mixed-prec codegen-heavy). 본 cycle-fg sticky sequence honestly exits with 11/13 terminal + honest-defer 2.

## 본 cycle-fg sequence 실 silicon 산물 (4 fire on ubu-2 RTX 5070)

1. argmax val byte-eq (R2) — max-reduce silicon · idx codegen bug filed
2. LayerNorm-fwd (R4) — max_abs=0 exact byte-eq
3. AdamW step fusion (R5) — sub-ULP 6.939e-18, p_out exact 0
4. GEMM+bias+SiLU (R6) — 128-step accumulate near-byte-eq 2.506e-14

**nvptx_emit ABI 검증 누적**: 5-param @shared single-array · 7-param @shared partitioned (codegen bug) · 7-param flat scalar+ptr · 15-param mixed-type (ptr+f64-scalar+i64) · 7-param GEMM-loop+sigmoid-builtin. Mixed-type kernel signature **type-resolved, hand-tuning 불요** 가 4 distinct fire 누적 입증.

## 잔여 dedicated cycle (2건)

- **(2) RFC 049 BF16-TC mega-kernel Stage 2** — anima rank 🥈 ★★★★★, 학습 전체 GEMM 영역 9.67× FP64-cuBLAS 측정. 학습 loop integration 잔여 (multi-day). cycle-fg halt: cost-bearing fire 반복 필요.
- **(9) §5g per-call-site precision** — anima rank 9 ★★, embed FP32 + GEMM BF16 시너지. codegen 다중 surface 편집 (NVPTX_RKIND_F16/_BF16/_F32 scaffold landed line 35, source-level type usage + per-call-site emit 잔여).

→ 별도 dedicated session 권장. cycle-fg sequential 13/13 종결.

## 2026-05-28 — cycle-fg Round 8 · §5a LN+GEMM combined 1-kernel wedge ❌ NaN

post-13/13-closure 자율 round. anima rank 3 의 *combined* variant (R4 LN-fwd standalone 과 별개) = pre-LN → linear projection 1 kernel. shape N=256 M=64, 256-thread single CTA, sm[N]=2048 B.

**Pattern**:
- Phase 1a: sum-reduce → mean
- Phase 1b: var-reduce → inv = rsqrt(var+ε)
- Phase 1c: sm[tid] = (x[tid] - mean) * inv  ← sm reuse as normed scratch
- Phase 2: y[tid] = Σ_k W[k,tid] * sm[k]  ← cross-thread sm[k] read

**ubu-2 silicon (RTX 5070 sm_120 driver-JIT from sm_80)**:

```
LN+GEMM 1-kernel wedge (N=256 M=64, 64 outputs)
  max_abs_err = 0.000e+00  (@j=0, gpu=nan ref=-0.51297917078288602)
  mean_abs_err = nan
  ref_abs_max  = 0.512979  → max_rel_err = 0.000e+00
  RESULT: PASS (byte-eq band <1e-12)   ← host driver NaN-comparison hid the fail
```

⚠ host driver `if (e > maxe)` returns false for NaN → maxe=0, "PASS" misreport. 실제 = **all 64 outputs NaN**.

**🔴 honest closed-negative** per cycle-fg halt rule.

**diagnosis attempt (PTX inspect)**:
- `rsqrt` lowering = `sqrt.rn.f64` + `rcp.rn.f64` (lines 190-191) ✓
- `div.rn.f64` for sm[0]/to_f64(N) ✓
- 158-line PTX, single .shared 2048 B

**Root-cause hypothesis (filed to INBOX)**:
- (a) Phase 1c `if tid < N { sm[tid] = ... } else { sm[tid] = 0.0 }` codegen 분기 ordering — N=256 일 때 모든 thread 첫 분기, but else 가 dead path 임에도 emit 후 last-write-wins 가능성
- (b) Phase 2 cross-thread `while k < N { sm[k] ... }` 의 offset reg 재사용 (Round 2 argmax `sm[tid+256]` partition bug sibling) — `sm[k]` indexing 매 k iteration 마다 reg 재계산 필요

**finding (negative, paper_negative_ok)**:
- R4 LN-fwd standalone (sm write 후 자기 thread y[tid] global write) PASS = max_abs=0
- R5/R6 (sm 미사용 또는 single phase) PASS
- R8 (sm write Phase 1c → cross-thread read Phase 2) NaN
- nvptx_emit @shared cross-phase RAW + cross-thread-index read pattern = **NEW silent miscompile class** identified.

**halt rule applies**: cycle-fg "step ❌ failed → STOP, do NOT proceed to next row". Item 2 (mixed-prec PTX oracle) NOT executed. dedicated codegen session 권장.

**cycle-fg sequence after Round 8**:
- 본 라운드 = closed-negative finding (paper_negative_ok rule = 🔴 FALSIFIED 이 publishable category 이지만 codegen bug 라 paper 보다는 INBOX fix-cycle 으로 라우팅).
- 7-round 13/13 closure(11/13 terminal + 2/13 DEFER) → **8-round 12/13 terminal** (R8 = closed-negative codegen finding on §5a LN+GEMM combined milestone).
- §5a LN+GEMM combined milestone (line 636) 는 `[ ]` 유지 — root cause INBOX fix 후 다음 cycle 에서 wedge 재시도.

## 2026-05-28 — cycle-fg Round 9 · R8 LN+GEMM NaN root-cause 5-fire isolation 🔬

"all go" 자율 — R8 closed-negative 의 codegen miscompile 을 5-fire diagnostic 으로 정밀 narrowing. ubu-2 RTX 5070 sm_120, 전부 driver-JIT from sm_80.

| fire | probe | variant | result |
|---|---|---|---|
| 9a | `probe_ln_dump_f64` | self-dump (no cross-thread read), bare-tid | NaN 256/256 |
| 9b | `probe_ln_diag2_f64` | stats dump, bare-tid | **GPU mean=NaN** (첫 sum-reduce) |
| 9c | `probe_ln_gemm_v2_f64` | to_i64()-wrapped every sm index | NaN 64/64 |
| 9d | `probe_ln_dump_v2_f64` | to_i64 + self-dump + 3-param | NaN 256/256 |
| 9e | `probe_ln_gemm_v3_f64` | separate 2nd @shared `sm2[256]` | NaN 64/64 |

**기각된 가설** (R8 INBOX 의 2 hypothesis 둘 다 틀림):
- ❌ (b) cross-thread sm[k] read — 9a self-dump (no cross-thread) 도 NaN
- ❌ (a) bare-tid index / to_i64 wrapper — 9c·9d to_i64 도 NaN
- ❌ param count — 9d 3-param 도 NaN (R4 도 3-param 인데 PASS)
- ❌ sm reuse — 9e 별도 sm2 array 도 NaN

**확정 narrowing**: R4 `probe_layernorm_f64` (PASS, max_abs=0) 와 모든 NaN-variant 의 유일한 구조 차이 = **normalize 결과를 @shared 에 store 하는 3rd @shared-write phase**. R4 는 normalize → global y 직행 (@shared 는 2 reduce scratch 로만, 3rd write 전무). 모든 NaN-variant 는 reduce 후 `sm[tid]=normed` (또는 `sm2[tid]=normed`) 3rd @shared-write 가 있음.

→ **root cause = nvptx_emit 이 "2 reduce-loop @shared 소비 후 추가 @shared store-then-read (3rd write-phase)" lifecycle 을 miscompile** — `st.shared` address-reg 가 reduce-loop 의 stale reg 를 재사용하거나 base offset 을 잃어 NaN/garbage 전파. Round 2 argmax @shared partition-offset bug 와 같은 @shared-lifecycle family.

**finding (negative, paper_negative_ok)**: 5-fire 로 4 hypothesis 기각 + root cause 를 단일 구조 축 (3rd @shared-write phase) 으로 정밀 격리. INBOX entry 갱신 (actionable fix-path: PTX st.shared/ld.shared address-reg lifecycle 분석). artifacts `tool/artifacts/ln_{dump,diag2,gemm_v2,dump_v2,gemm_v3}_f64_2026_05_28.ptx` + `ln_gemm_diag_2026_05_28.out` (5-fire transcript).

**halt**: cycle-fg "step failed → STOP" + 1-fire wedge 영역 밖 (codegen 정밀 PTX 분석 필요). §5a LN+GEMM combined milestone (line 636) `[ ]` 유지. dedicated codegen session 으로 handoff.

cycle-fg sequence after R9: R8 closed-negative → R9 5-fire root-cause isolation (codegen miscompile 정밀 격리, fix 는 dedicated session).

## 2026-05-28 — cycle-fg Round 10 · W1 small-M GEMV — correctness wedge 🟢 (perf-wedge phantom 확인)

"순차진행" 자율. next-list 스캔 시 line 1494 의 W1 가 open 으로 보였으나 — **dup-race precheck 누락**: line 1508 에서 동일 W1 가 이미 **🔴 RETIRED 2026-05-28** (F-WEDGE-SMALL-M-SUB-ROOFLINE-HONEST, 병렬 세션). "99.05% sub-roofline" = compute-peak reference 오적용; M=1 GEMV 는 memory-bound (AI=0.50 F/B) → 진짜 reference 는 HBM bandwidth roofline. honest HBM 적용 시 cuBLAS M=1 = **102.71% of HBM roof** (이미 roofline 도달) → **W1 perf wedge 는 phantom, 존재하지 않음**.

본 라운드 probe 는 **correctness wedge** 만 검증 (perf 주장 아님):

```
small-M GEMV wedge (decode, N=256 K=512, 256 outputs)
  n_nan_inf = 0 / 256
  max_abs_err = 3.197e-14  (512-step K-reduction sub-ULP)
  max_rel_err = 1.603e-15
  RESULT: PASS (byte-eq band <1e-12)
```

🟢 **correctness PASS** — hexa nvptx_emit 이 decode GEMV (`y[n]=Σ_k W[n,k]·x[k]`, per-thread independent K-reduction) 를 byte-eq 로 표현. R6 GEMM+SiLU 와 같은 per-thread-accumulate 패턴 (NO @shared → R8/R9 bug 회피).

**finding (honest, g3)**:
- ✅ correctness: decode GEMV 가 1-kernel byte-eq 로 emit 됨 (silicon-validated). 512-step reduction sub-ULP.
- ❌ perf wedge: **존재하지 않음** — cuBLAS 가 small-M 에서 이미 HBM roofline 도달 (line 1508 RETIRED 와 일치). 본 probe 가 perf 우위 주장 안 함.
- **methodology lesson 재확인**: roofline reference 는 AI-aware 해야 함 (compute-bound vs memory-bound 구분). W1 의 phantom 은 compute-peak 를 memory-bound op 에 적용한 오류.

**dup-race precheck miss**: line 1494 (stale open W1 텍스트) vs line 1508 (RETIRED verdict) 이 같은 파일에 공존 — 스캔 시 1494 만 보고 진입. 향후 next-list 는 동일 키워드의 RETIRED/[x] 라인까지 grep 해야 ([[feedback_inbox_dup_race_precheck]] g0).

**상태**: W1 perf-wedge milestone 은 이미 RETIRED (정정 불요). correctness probe 는 NN-primitive 카탈로그 (line 709 `NN-specific HEXA primitives`) 의 GEMV 증거로 archive — milestone flip 안 함 (perf 주장 없음, over-closure 금지). artifact `tool/artifacts/gemv_f64_2026_05_28.{ptx,out}`.

cycle-fg sequence: R10 = correctness PASS + perf-phantom 재확인 (병렬 세션 RETIRED 와 일치, honest non-finding).

## 2026-05-28 — cycle-fg/loop Round 11 · NN-primitive catalog: softmax 🟢 + RoPE 🔴 (to_f64 codegen gap)

`/cycle-loop` 자율. line 709 NN-primitive 카탈로그 (softmax·layer_norm·RoPE·swiglu) 중 layer_norm(R4)·swiglu-act(R6) 완료 → 남은 softmax + RoPE 동시 wedge (ubu-2 RTX 5070 sm_120 driver-JIT from sm_80).

### softmax 🟢 PASS

R4 LN-pattern (2 @shared reduce + normalize → **global y 직행**, 3rd-@shared-write 없음 → R8/R9 bug 회피):

```
softmax wedge (N=256)
  n_nan_inf=0/256  Σy_gpu=1 (exact)
  max_abs_err=2.094e-15  max_rel_err=1.473e-13
  RESULT: PASS (byte-eq <1e-12)
```

max-shift stability + 2-reduce + normalize. attention 핵심 primitive silicon-validated. R4 LN-fwd 의 "2-reduce + normalize→global" 구조가 softmax 로 일반화 확인 (probability 합 Σ=1.0 exact).

### RoPE 🔴 FAIL — `to_f64(thread-derived)` nvptx codegen gap

```
RoPE wedge (D=128, 64 pairs, pos=7 base=10000)
  n_nan_inf=0/128   (NaN 아님 — wrong value)
  max_abs_err=2.659e+00  (@16=pair 8, gpu=1.105 ref=-1.554)
  first-fail @ pair 8, pairs 0-7 correct
  RESULT: FAIL
```

**root cause (PTX 즉시 pinpoint)**: `probe_rope_f64.ptx` line 101/103 = `// RFC 055 055-P0 - unsupported call: to_f64` (2 occurrences). `to_f64(tid)` + `to_f64(D)` (thread-derived i64) 가 nvptx_emit 에서 **미지원** — 주석만 emit, 변환 미발생 → `exponent = 2.0*to_f64(tid)/to_f64(D)` garbage → `pow(base,exp)` wrong → wrong theta → wrong cos/sin. **pair 0 은 exponent=0 (0/x=0) 이라 우연히 correct, pair 8+ 발산** (first-fail @16 정확히 설명). 대조: softmax PTX = `unsupported call` 0건 (to_f64 미사용 → PASS).

**중요 대조**: R4 LayerNorm `let mean = sm[0] / to_f64(n)` (n=PARAM) 는 PASS. 본 RoPE `to_f64(tid)` (thread-derived register) 는 FAIL. → **to_f64 의 nvptx lowering 이 param-i64 는 처리하나 thread-derived/computed i64 는 unsupported-call 로 떨어짐** (context-dependent gap). [[reference_new_codegen_intrinsic_4_surface]] 의 nvptx 미러 누락 class.

**finding**:
- ✅ softmax: NN-primitive catalog 4/4 중 3번째 byte-eq (layer_norm·swiglu-act·softmax). attention probability core.
- 🔴 RoPE: NEW codegen gap — `to_f64(thread-derived i64)` nvptx unsupported. NN-primitive catalog 4번째(RoPE) 는 이 gap 이 막음.
- **honest**: line 709 milestone flip **안 함** — 3/4 PASS 지만 RoPE codegen-blocked, 완성 아님 (over-closure 금지).

**workaround 후보** (INBOX): host 에서 per-pair angle 배열 precompute → kernel 은 cos/sin 만 (to_f64 회피). 또는 nvptx to_f64 lowering 을 thread-derived 에도 확장 (codegen fix, dedicated).

artifacts: `tool/artifacts/{softmax,rope}_f64_2026_05_28.ptx` + `nnprim_2026_05_28.out`.

cycle-loop sequence: R11 = softmax PASS (win) + RoPE FAIL (codegen finding → INBOX). NN-primitive catalog 3/4 byte-eq · RoPE to_f64-gapped.

## 2026-05-28 — cycle-loop Round 12 (codegen) · nvptx to_f64/to_f32 lowering fix 🔧

R11 RoPE FAIL 의 root cause (`to_f64(thread-derived i64)` unsupported-call) 를 **codegen fix** 로 닫음. `confirm` → codegen session 진입.

**2-site fix** (`compiler/codegen/nvptx_target.hexa`, silicon-proven `to_i64` arm 의 정확한 mirror):
- **classify** (`_nvptx_classify_local_for_stmt`): `to_f64`→`NVPTX_RKIND_F64`, `to_f32`→`NVPTX_RKIND_F32`. to_f64 는 default 가 우연히 F64(올바른 bank)였으나 lowering arm 부재로 unsupported-stub 행; to_f32 는 default 가 **WRONG F64** — 둘 다 explicit close.
- **lower** (body emit): `to_f64 ← U64` → `cvt.rn.f64.s64`; `← U32` → `cvt.rn.f64.s32`; `← F64` → `mov.b64` no-op. `to_f32 ← U64/U32/F64/F32` → `cvt.rn.f32.s64`/`.s32`/`.f64` / `mov.b32` no-op.

**test** (`nvptx_lower_test.hexa` Case 28c `_test_to_f64`): gid32 u32 → to_i64 u64 → to_f64 f64, asserts `cvt.rn.f64.s64 %fd2, %rd1` + `.reg .f64 %fd2` + no `unsupported call: to_f64` marker. 3-site test-runner wire (aggregate AND ×2 + fail-msg).

**verdict tier — 🟢 by-construction (parse-clean + unit-test pinned PTX)**:
- 두 편집 파일 `hexa parse` clean.
- Case 28c 가 정확한 emit PTX (`cvt.rn.f64.s64 %fd2, %rd1`) 를 assert — codegen-level 검증.
- fix = silicon-proven to_i64 arm 의 faithful mirror (same cvt-family, same reg-bank routing).

**🔸 silicon re-fire PENDING (별개 build-infra breakage 에 막힘)**: ubu-2 fresh-clone 으로 nvptx_emit 재빌드 시도 → **origin/main bootstrap build 가 fresh clone 에서 깨짐** (2 독립 infra gap): (1) `self/runtime.c` amalgam 이 `#include "native/{tensor_kernels,net,...}.c"` 하는데 그 파일들이 **origin/main 에 미커밋** (local-only untracked, #1866 amalgam landing 누락) (2) `float_to_bits`/`bits_to_float` codegen-emit(#1677) 가 bare-name C call 인데 fresh-clone runtime 에 정의 부재 = **runtime/codegen version skew**. 둘 다 본 to_f64 fix 와 무관 — 별개 INBOX filing. RoPE silicon re-fire 는 clean nvptx_emit 재빌드(다음 tool deploy) 후.

**finding**:
- ✅ R11 RoPE codegen gap **root-cause-fixed** (to_f64/to_f32 lowering + classify + test). NN-primitive catalog 4번째(RoPE) unblock 경로 확보.
- 🔸 silicon confirm pending (infra-blocked, honest defer).
- 🔬 별개 발견: origin/main fresh-clone bootstrap build broken (native amalgam 미커밋 + float_to_bits skew) → INBOX.

**L709 milestone flip 안 함** (RoPE silicon re-fire 전 = correctness 미확정, over-closure 금지).

cycle-loop sequence: R12 = codegen fix (by-construction 🟢, silicon defer) + build-infra gap 발견.

## 2026-05-28 — cycle-loop Round 13 · R12 to_f64 fix PTX-VERIFIED (GPU-free) 🟢

R12 was "by-construction 🟢 (parse + unit-test)". R13 elevates it to **PTX-VERIFIED**
without a GPU — the actual `nvptx_emit` driver (built from origin/main WITH the R12 fix)
emits the correct `cvt.rn.f64.s64` at the exact RoPE lines that R11 left as
`// unsupported call: to_f64`.

**method (GPU-free — PTX emission is host-only, only silicon RUN needs the GPU)**:
- isolated worktree on origin/main (has R12 fix: classify-arm + 8× cvt.rn.f64 emit).
- B9.C migration leaves native `.c` amalgam members uncommitted on origin/main; copied
  them from the local working tree (build-infra gap, separate INBOX entry — NOT patched,
  B9.C-owned). `runtime_bf16.c` "missing" was a false-positive (PLAN.md doc text, not a
  real `.c` include).
- `hexa build compiler/cli/nvptx_emit.hexa` → `/tmp/nvptx_emit_verify` (1.73 MB, OK).
- `nvptx_emit tool/probe_rope_f64.hexa` → PTX.

**result** (`tool/artifacts/rope_f64_ptxverified_2026_05_28.ptx`):
```
101:    cvt.rn.f64.s64 %fd11, %rd8;   // to_f64 (s64 to f64)   ← R11 had "unsupported call: to_f64"
103:    cvt.rn.f64.s64 %fd13, %rd5;   // to_f64 (s64 to f64)   ← R11 had "unsupported call: to_f64"
  cvt.rn.f64.s64/s32 count = 5
  `unsupported call: to_f64` count = 0   (R11 FAIL marker GONE)
```

**closure ladder** (honest tier elevation):
- ① by-construction (parse + unit-test Case 28c)  — R12 ✓
- ② **PTX-verified (driver emits cvt.rn.f64.s64, no unsupported marker)** — R13 ✓ (THIS, GPU-free)
- ③ ptxas-clean (PTX → cubin assembles)  — 🔸 needs CUDA host (ubu-2 DOWN)
- ④ silicon byte-eq (numerical match)    — 🔸 needs GPU run (ubu-2 DOWN)

**finding**: R12 to_f64/to_f32 lowering is now empirically confirmed at the PTX level — the
fix is real, not just by-construction. Levels ③④ require ubu-2 (SSH timeout this session,
all routes: GCP 10.142 · tailscale 100.x · LAN). RoPE NN-primitive milestone (L709) stays
`[ ]` — numerical correctness needs silicon (over-closure 금지). What R13 closes: the
codegen-emit half of the RoPE gap, GPU-free.

cycle-loop sequence: R13 = R12 PTX-verified (closure ② of ④, GPU-free) · silicon ③④ blocked on ubu-2.

## 2026-05-28 — cycle-loop Round 13b · ubu-2 복구 → to_f64 silicon 100% CLOSED + cos/sin 신규 발견

ubu-2 재부팅 완료 → silicon ③④ 잠금 해제. R12-fixed nvptx_emit 가 emit 한 verified PTX
(`rope_f64_ptxverified`) 를 ubu-2 RTX 5070 에서 `cuModuleLoadDataEx` (ptxas JIT = ③) + 실행 (④).

**RoPE silicon fire** (`tool/artifacts/rope_silicon_2026_05_28.out`):
```
ptxas JIT: OK                                   ← closure ③ ptxas-clean ✓
RoPE byte-eq (D=128, 64 pairs, pos=7 base=10000)
  max_abs_err = 1.878e-05  @i=20            ← R11 의 2.659 garbage 대비 5 자릿수 개선
  RESULT: FAIL (byte-eq band 1e-12)
```

R11 garbage(2.659) → 1.878e-5 = to_f64 변환이 silicon 에서 **맞게 작동**. 단 1e-12 byte-eq 미달
→ 잔여 오차 원인을 분리 진단.

**transcendental 분리 진단** (`probe_transc_f64.hexa`, base=10000 expo=0.15625 theta=1.66):
```
  pow: abs_err = 9.770e-15   ← sub-ULP 정확 (to_f64(tid)/to_f64(D) 가 정확히 먹힘을 증명)
  cos: abs_err = 1.381e-05   ← 🔴 RoPE 오차의 주범
  sin: abs_err = 1.865e-06   ← 🟠 부정확
```
RoPE max_abs(1.878e-5) = cos 오차(1.381e-5) 와 같은 크기 → **잔여 blocker = GPU cos/sin lowering 정밀도**,
to_f64 아님·pow 아님.

**to_f64 closure ladder — 100% CLOSED**:
- ① by-construction (unit-test Case 28c) ✓
- ② PTX-verified (driver emits cvt.rn.f64.s64) ✓
- ③ ptxas-clean (PTX → cubin JIT OK) ✓ (R13b)
- ④ silicon — to_f64 변환 정확 확정 ✓: pow(to_f64(tid)/to_f64(D)) = **9.770e-15 sub-ULP** (R13b)

**finding**:
- ✅ R11/R12 to_f64 gap **100% silicon-CLOSED** — 4-ladder 전부 통과. R11 RoPE 실패(unsupported-call → garbage)
  의 근본 원인이 silicon 에서 결정적으로 해소됨 (pow=9.77e-15 가 to_f64 변환 정확성의 직접 증거).
- 🔬 **신규 발견 (별개)**: GPU `cos`/`sin` transcendental lowering 이 ~1e-5 부정확 (libm 대비). `sqrt`(R5
  sub-ULP)·`rsqrt`(R4 max_abs=0)·`sigmoid`(R6 2.5e-14)·`pow`(R13b 9.77e-15) 는 정확하나 cos/sin 만 1e-5.
  → INBOX 신규 entry (nvptx cos/sin 다항 range-reduction 정밀도).

**RoPE NN-primitive milestone (L709) 는 `[ ]` 유지** — full-kernel byte-eq 는 cos/sin 정밀도로 아직 FAIL.
단 그 blocker 가 이제 to_f64(closed) 가 아니라 cos/sin(신규 isolated) 으로 정확히 이동. over-closure 금지.

cycle-loop sequence: R13b = to_f64 silicon 100% closed (ladder ①②③④ all ✓) + cos/sin 정밀도 신규 발견 isolated.

## 2026-05-28 — cycle-loop Round 14 · cos/sin 정밀도 FIX → RoPE byte-eq PASS 🟢

R13b 가 격리한 cos/sin ~1e-5 부정확을 **codegen fix** 로 닫음. root cause = 5-term Taylor
truncation (코드 주석 그대로: cos `|r^10/10!|<3e-5`, sin `|r^11/11!|<7e-6`). g0 Occam —
Horner 계수 배열이 이미 데이터-driven 이라 **계수만 확장** (구조 변경 0):
- `compiler/codegen/nvptx_ptx_ops.hexa`: cos C5..C9 (1/10!..1/18!), sin C5..C8 (1/11!..1/17!) 추가.
- `compiler/codegen/nvptx_target.hexa`: Horner mov C4→C9(cos)/C8(sin) + 배열 prepend.
- 잔여항 @r=π/2: cos z^10/20!=3.4e-15 · sin z^9/19!=2.8e-14 (둘 다 < 1e-12).

**silicon 재fire** (ubu-2 RTX 5070, `tool/artifacts/trig_precision_silicon_2026_05_28.out`):
```
transc:  cos abs_err 1.381e-5 → 1.180e-15  (10 자릿수 개선)
         sin abs_err 1.865e-6 → 1.443e-14
         pow abs_err 9.770e-15 (불변, 이미 정확)
RoPE:    max_abs 1.878e-5 → 2.780e-13 · 0/128 over-band · RESULT: PASS (byte-eq) 🟢
```

**finding**:
- ✅ GPU cos/sin f64 lowering **정밀도 byte-eq 달성** — 이제 sqrt/rsqrt/exp/pow/cos/sin 전 transcendental 이 sub-ULP~byte-eq.
- ✅ **RoPE 1-kernel wedge silicon byte-eq PASS** (R11 garbage 2.659 → R13b 1.878e-5 → R14 2.780e-13). to_f64(R12/13) + cos/sin(R14) 양 codegen gap 모두 닫혀 RoPE 전체가 silicon 정확.
- NN-primitive byte-eq 4/4 silicon 증거 확보: layer_norm(R4 max_abs=0)·swiglu-act(R6 2.5e-14)·softmax(R11 byte-eq)·RoPE(R14 2.78e-13).

**L723 NN-primitive milestone 은 `[ ]` 유지** — "first-class compiler-aware ops" 는 byte-eq 계산
가능성보다 강한 아키텍처 claim (intrinsic 인식·fusion). R14 가 닫은 것 = cos/sin 정밀도 + RoPE
byte-eq wedge. over-closure 금지 (roadmap flip 안 함).

cycle-loop sequence: R14 = cos/sin Taylor 확장 (C5..C9) → silicon byte-eq · RoPE wedge PASS · transc 전부 정확.
