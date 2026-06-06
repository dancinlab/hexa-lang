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

## 측정 닫힘 (2026-06-04 — 빌드벽 SOLVED · ② CLOSED-NEGATIVE · research → ④)

- **빌드벽 SOLVED** (이전 "유지자/CI 에만 존재" 결론 번복): 신규 임대 idle H100_NVL pod 에서
  frozen-seed 번들(self/ 전체)로 clm_prod_gpu 빌드+학습 성공. KEY = nvcc 에도 `-DHEXA_CUDA`
  (없으면 58→40 launcher), `-lcuda`, glibc2.35 pod 재빌드(summer .o 는 `__isoc23_strtol` 비이식).
- **util A/B (clean idle, baseline 0.00%)**: ASYNC=0 12.50% (CE 4.47→3.65 PASS) vs ASYNC=1 10.28%.
  ② async = 🔴 CLOSED-NEGATIVE (util 안 오름 + byte-eq 깸). sizing 도 역효과(12.71→2.94%).
- **research(web+arxiv)**: launch-bound 진단 확정 → 유일 해법 = ④ CUDA Graph(host 임계경로 제거).
- **빌드/측정 킷** (repo-외 durable): `~/hexa-fusion-cuda-kit/` — `rebuild.sh`(신규 pod 원샷),
  `work/clm_prod_gpu`·`runtime_cuda.o`(-DHEXA_CUDA), `fusion_build_sources.tgz`, 측정로그.
  메모리 = `project_hexa_fusion_util_green` + `project_clmprod_gpu_build_seed_drift`(SOLVED).
- **현 활성 프론티어 = L2 ④ CUDA-graph piecewise** (아래 L2). ① device-resident + ② async 닫힘.

## ── 사다리: match (L1) → graph (L2) → exceed (L3) ──

### L1 — device-resident (= PyTorch eager 수준, util-GREEN)

- [~] **device-resident tensor lifetime** — param/grad/moment 를 step 전체에 GPU-resident 유지(host roundtrip 0). falsifier: 기존 오라클 byte-eq max|Δ|=0 ∧ nvidia-smi devmem persist across step. **W1-① PARTIAL (PR #2555 m,v + #2559 grad-db + #2561 int4)**: m,v + bias grad db + **int4 quant(W-fwd/dW-STE, 정수-exact)** device-resident 착지(env `CLM_PROD_DEVRESIDENT`, byte-eq ALL-PASS). 잔여: dX col2im transpose(orthogonal) · self-host pod build · devmem/util fire. **③ 정밀화: 텐서 resident 만으론 부족 — op 사이 인터프리트 host glue 도 fuse 해야 util MEAN gap 닫힘**. 상세 = §W1 results.
- [x] **async kernel-launch pipeline / per-step driver 제거 — 🔴 CLOSED-NEGATIVE (2026-06-04 측정)** — ② async 머지(#2619-2624)를 idle H100_NVL 에서 A/B 측정: ASYNC=0 util MEAN **12.50%** vs ASYNC=1 **10.28%** → async 가 util 을 **안 올림(오히려 ↓)** + ASYNC=1 byte-eq 깸(CE 4.89→4.86 vs 4.47→3.65, ②d sync제거 race). 워크로드 sizing 도 역효과(util 단조감소 12.71→2.94% @ D 1536→4608). falsifier `util MEAN≥20%` = FALSIFIED. 진단(research): 단일-스트림 async 는 host 를 임계경로에서 못 뺌 → 구조적으로 불가. verdict `.verdicts/hexa-fusion/F-FUSION-ASYNC-UTIL-AB.txt`.
- [x] **fwd-only fused device kernel 프로토타입 + util Δ probe** ✅ W1-③ — H100 fwd-only fire: MEAN 0.56→**2.83%** (5×↑) PEAK 21→**81%**, 여전히 RED. **진단**: device 는 세게 돌 수 있음 + binding = 인터프리트 per-step glue(GEMM 아님). 텐서 resident 만으론 부족 → inter-op glue fusion(⑤) 필요. 상세 = §W1 results.

### L2 — graph capture (= torch.compile / CUDA-graph 수준)

- [ ] **per-step CUDA-graph capture/replay 〔★ ACTIVE FRONTIER — research-confirmed canonical 해법〕** — step 커널 시퀀스를 1회 캡처 → 매 step `cudaGraphLaunch`(~10µs) replay 로 launch+인터프리터 dispatch 를 상각, host 를 임계경로에서 제거(② async 가 못 한 것). **int4 MoE 주의**: 동적 expert 라우팅 → 전체-step 정적캡처 불가 → **piecewise**(dense/attn/optimizer 캡처 + MoE eager split + 라우팅 토큰 capacity 버킷 패딩 = vLLM/SGLang `FULL_AND_PIECEWISE`). graph replay 가 순서복원 → ②가 깬 byte-eq 회복. env `HEXA_CUDA_GRAPH` graph-off byte-eq 선랜딩. 빌드/측정 = CUDA 킷 `~/hexa-fusion-cuda-kit/rebuild.sh`. 기대 ~1.7× step(graphable ~5×). falsifier: replay byte-eq ∧ util MEAN≥20%. 출처: PyTorch CUDA Graphs · Mirage MPK arxiv:2512.22219 · vLLM/SGLang piecewise.

### L3 — fusion moat (= PyTorch 초과 · 구조적)

- [ ] **fwd+bwd autograd-aware fusion** (GPU.md §5d) — forward + backward 커널을 한 device 그래프로 fuse. falsifier: `F-FUSION-TRAINSTEP-EQ` max|Δ|=0 (fused == op-by-op reference).
- [x] **compile-time specialization** (GPU.md §5b) ✅ W1-⑥ (PR #2558) — known-(M,N,K) GEMM 특화: M/N/K `.param` 제거 · bounds-setp 에 M/N immediate baking · K stride literal-fold · K 수축 완전 unroll(loop·back-edge·counter 제거). emit Δ: generic fma 1(looped) → specialized K straight-line. default re-emit byte-eq max|Δ|=0. 잔여: dead-output elim · MIR call-site auto-select · WMMA matmul 경로 확장 · silicon. 상세 = §W1 results.
- [x] **operator-specific surgical override** (GPU.md §5g) ✅ W1-⑦ (PR #2556) — per-call-site WMMA precision override(`_nvptx_wmma_mnemonic_override` reads dst Local.precision). emit Δ: load `.shared.f16`→`.shared.bf16` · mma `.f32.f32`→`.f32.bf16.bf16.f32`, **store-c default .f32 유지(per-site granularity 증명)**. default re-emit byte-eq max|Δ|=0. 잔여: HIR `@bf16` grammar → Local.precision · silicon fire. 상세 = §W1 results.
- [x] **launch-overhead amortization 우위 측정** (GPU.md §5f · R12) ✅ W1-⑧ — ≥30% wall win UNCONDITIONAL (n*<0, no crossover; launch-bound 80% → BW-bound 72.7%), $0 oracle exit 0 + 실측 교차확인 max|Δ|=1.1e-5. raw-GEMM 우위 아님(경계 제거뿐). 상세 = §W1 results.

### closure — vs PyTorch+CUDA 벤치

- [ ] **vs-PyTorch+CUDA wall 벤치** — 동일 모델 device-resident, step/s + util 을 torch eager + torch.compile 와 나란히. **정직**: cuBLAS GEMM = roofline(못 이김 ≠ 실패) — 우위는 fusion/launch-amort regime 에서만 주장. closure = util-GREEN ∧ descent-GREEN ∧ vs-PyTorch wall Δ 기록.

## ── completion roadmap (goal: 병렬 발사 전략으로 HEXA-FUSION 완성) ──

각 웨이브의 독립 레인을 병렬 백그라운드 에이전트로 발사 → 착지 시 verdict 를 본 문서에 g5 verbatim 기록 → 다음 웨이브 발사. pod 레인 = idle 재사용·1-fire·즉시 down. byte-eq max|Δ|=0 = 전 레인 hard gate. raw-GEMM 우위 주장 금지.

```
W1 (fired 06-03)  ──────────────────────────────────  4/6 landed
  ⑧ launch-amort ✅  ⑨ baseline ✅  ⑦ override ✅  ① m/v [~]
  ③ fwd-only probe 🔄   ⑥ compile-time spec 🔄
        │ gate: ① FULL (grad+param) + pod self-host build
        ▼
W2 (① full → util-GREEN MATCH)  ─────────────────────
  ①b grad-residency 🔄   ①c param W (host int4 re-quant 차단 해소)
  ② async launch pipeline → F-RFC046 util MEAN≥20% fire  ← util-GREEN MATCH 닫힘
  ④ CUDA-graph capture/replay   ⑤ fwd+bwd autograd-aware fusion
        │ gate: util-GREEN ∧ ⑤ fused
        ▼
W3 closure  ─────────────────────────────────────────
  ⑨-full hexa-vs-PyTorch wall bench (compute-bound MATCH · launch-bound EXCEED)
  → 9/9 terminal → HEXA-FUSION 완성
```

병렬 가능 노드(현재): ①b·①c·⑥·③ 동시. ②④⑤ 는 ① full 착지가 gate(공유 device-resident 기반). ⑨-full 은 ② util fire 이후.

## ── first parallel wave (W1) — 6 independent lanes fired 2026-06-03 ──

Dependency DAG 추출: 선행 0 인 노드를 전부 뽑아 동시 발사(maximal parallelism). 4 lanes $0(agent/mac/codegen·oracle) + 2 lanes pod(GPU 실측). 나머지 ②④⑤ + ⑨-full 은 ① 착지 후 unblock.

```
t0 (선행 없음 — 병렬 발사)              blocks ▶  대기
─────────────────────────────                   ──────
① device-resident tensor lifetime ──┬─▶ ② async launch · ④ CUDA-graph · ⑤ fwd+bwd fusion
③ fwd-only fused probe (util Δ)  ────┘   (⑤ 설계 입력)
⑥ compile-time specialization        (독립 codegen)
⑦ operator surgical override         (독립 codegen)
⑧ launch-amort 측정 (R12 재사용)      (독립 $0 oracle)
⑨ vs-PyTorch baseline                (독립 — full bench 만 ① 대기)
```

| lane | milestone | 기질 | 비용 | falsifier |
|---|---|---|---|---|
| ① | device-resident tensor lifetime | forge/codegen | agent $0 | byte-eq max\|Δ\|=0 ∧ devmem persist |
| ③ | fwd-only fused device probe | pod H100 | 💰 1-fire | util MEAN Δ vs 0.6% floor |
| ⑥ | compile-time specialization | codegen emit | mac $0 | 특화 emit Δ + byte-eq |
| ⑦ | operator surgical override | codegen emit | mac $0 | override emit Δ + byte-eq |
| ⑧ | launch-amort 측정 | static oracle | mac $0 | vs-call wall Δ < 1.0× |
| ⑨ | vs-PyTorch+CUDA baseline | pod | 💰 1-fire | PyTorch util/step-rate 기준선 |

pod 비용 가드: idle READY pod 재사용 우선 · 신규 rent 시 smallest-sufficient 1대 · single fire · 측정 후 즉시 down.

## ── W1 results — landed 2026-06-03 (2/6 first, g5 verbatim) ──

### ⑧ launch-amort 우위 — ✅ RE-CONFIRMED ($0 mac-local, byte-identical, exit 0)

```
[1] LAUNCH      fused 1 vs baseline 5  → 5.0× fewer
[2] HBM/elem    fused 3 vs baseline 11 → 3.67× less
[3] 30%-crossover n* = -26595.7 (NEGATIVE ⇒ no crossover)
    ⇒ ≥30% wall win UNCONDITIONAL across all n>0 (launch-bound 80% → BW-bound 72.7%)
[4] pct_faster: n=64→79.98% · n=1024→79.69% · n=16M→72.88%
VERDICT: structural advantage PROVEN — ORACLE_EXIT=0
```

elementwise/glue sub-graph 에서 fusion 이 op-by-op(cuBLAS-style) 스택보다 **항상 72.7~80% 빠름**. 실측 교차확인(ubu-2 RTX 5070, n∈{1024…16.7M}, max|Δ|=1.1e-5, `.verdicts/fusion-launch-amort-wall/`). 정직: launch + HBM-traffic 경계 제거뿐, raw-GEMM 우위 아님.

### ⑨ PyTorch+CUDA baseline — ✅ MEASURED (H100 sm_90, d1536/T512, 1.09B ConvMoE)

| 스택 | step/s | util MEAN |
|---|---|---|
| PyTorch eager | 1.872 | **100.00%** (n=266) |
| torch.compile | 1.871 | 99.99% (n=265) |

pod 39139563(anima idle) 재사용·발견상태 복귀(0% util), 신규 rent 0. **target line**: 이 shape 에서 성숙 라이브러리 스택은 H100 을 **이미 util 100% 포화**(eager==compile) = **compute-bound**.

### ① device-resident tensor lifetime — ✅ PARTIAL slice (PR #2555, base main, byte-eq ALL-PASS)

AdamW moments **m,v GPU-resident across the whole CLMConvMoE train loop** (host roundtrip = 0 for m/v). Root cause: `forge_dispatch_adamw` D2H'd W,m,v every step; m/v escape only into `_adam` (host fwd/bwd never read them) → per-step m/v D2H+H2D = pure removable roundtrip. New `_keepmv` builtin elides it (marks m/v `loc=FARR_DEVICE, dirty_host=0` → next step H2D-skip). env `CLM_PROD_DEVRESIDENT` (default off → byte-identical).

```
F-CLM-DEVFEED-IM2COL-EQ = 1   (max|Δ|=0.0)
F-CLM-DEVFEED-FWD-EQ    = 1   (max|Δ|=0.0)
F-CLM-DEVFEED-BWD-EQ    = 1   (dW=0.0 dX≤5.55e-17 db=0.0)
F-CLM-DEVFEED-ADAM-EQ   = 1   (adam 5-step W max|Δ|=0.0)
ALL-PASS — device im2col/col2im + device AdamW byte-eq to host feed
```
verdict: `.verdicts/hexa-fusion/F-CLM-DEVFEED-DEVRESIDENT-MV.txt`. raw-GEMM 우위 주장 0 — roundtrip 제거뿐.

### ①b device-resident GRAD half — ✅ (PR #2559, base fusion/l1-devresident-mv, byte-eq ALL-PASS)

bias grad **db device-resident across bwd→AdamW**. Root: `conv*_bwd_via_forge*` 가 device GEMM 출력 dy 를 host 로 읽어 `db[co]=Σ_t dy` 를 host reduce → `_adam` 재업로드. db 는 `_adam` 외 host 미참조 → 제거가능. 새 `_hx_cuda_farr_db_colsum_gpu`(1 thread/channel, **sequential t-sum, tree 재결합 없음 → bit-exact**, db `loc=FARR_DEVICE dirty_host=0`).

```
F-CLM-DEVFEED-DB-EQ = 1   (db dil∈{1,2} colsum-vs-host max|Δ|=0.0)
+ IM2COL/FWD/BWD/ADAM-EQ 전부 max|Δ|=0.0 유지  → ALL-PASS
```
verdict: `.verdicts/hexa-fusion/F-CLM-DEVFEED-DEVRESIDENT-GRAD.txt`. raw-GEMM 우위 주장 0.

### ①c device int4 quant (the crux) — ✅ (PR #2561, base fusion/l1-devresident-grad, integer-exact byte-eq)

int4 quant wall 격파 → W resident 가능. device fwd-quant `forge_dispatch_int4_quant`(per-out-channel `s=max|W|/7`, `q=clamp(round(W/s),±7)`, W `loc=FARR_DEVICE dirty_host=0`) + STE-masked bwd `forge_dispatch_int4_quant_bwd`(`dW=dy·mask`, dW resident).

```
int4 fwd max|Δ| wq=0.0 scale=0.0 qlevel=0.0 mask=0.0
int4 bwd (STE) max|Δ| dW=0.0
F-CLM-DEVFEED-INT4QUANT-EQ = 1   (정수-exact: max|Δ|>0 이면 FAIL — FMA-drift 핑계 없음)
ALL-PASS (im2col/fwd/db/int4/adam = max|Δ|0.0, bwd dX≤5.55e-17)
```
verdict: `.verdicts/hexa-fusion/F-CLM-DEVFEED-DEVRESIDENT-PARAM.txt`. 잔여: dX col2im transpose(quant 과 orthogonal) · self-host pod build(HEXA_CUDA emit) → W/dW/db/m/v ALL resident → util fire. raw-GEMM 우위 주장 0.

### ③ fwd-only fused util Δ probe — ✅ MEASURED (H100 sm_90, d1536/T512, pod 39139563 reused, $0)

fwd-only 경로(ce-grad+bwd+20×AdamW elide, fwd byte-identical)로 device-residency 가 util 을 움직이는지 측정.

```
n=1048 PEAK=81% MEAN=2.8349% busy_mean=13.26% pct≥20=5.06% mem_max=67699MiB (66GB·116-120W)
F-CLM-DEVFEED-FWD-EQ = 1 (fwd dil=1,2 max|Δ|=0.0)
```
| path | PEAK | MEAN |
|---|---|---|
| lever-2 full-step | 19% | 0.50% |
| lever-3 full-step | 21% | 0.56% |
| **fwd-only (③)** | **81%** | **2.83%** |

**HONEST: 부분적으로 움직임 — MEAN 0.56→2.83% (5×↑), PEAK 21→81%, 단 여전히 RED**(78.6% 샘플 0%). **결정적 정밀화**: PEAK 81% = device 를 세게 driven 가능 증명 + bwd/AdamW host tail 제거가 util 회복 ⇒ binding = **인터프리트 per-step driver loop(F-RFC046 root), NOT GEMM kernels** 재확정. 그러나 fwd-only 내부 0% 잔여 floor = **텐서 device-resident 만으론 부족, op 사이 인터프리트 host glue(add·gelu·groupnorm·moe-router 스칼라 루프)도 fuse 해야 MEAN→20% 닫힘** ⇒ ②(async-launch)·⑤(fwd+bwd fusion)의 진짜 과제 = inter-op glue 제거. verdict: `.verdicts/hexa-fusion-l1-fwdonly/F-RFC046-FWDONLY-UTIL.txt`. raw-GEMM 우위 주장 0.

### ⑤ inter-op glue fusion (slice 1: residual-add) — ✅ (PR #2564, base #2561)

③ 가 찾은 잔여 floor 의 최고빈도 glue: 잔차 `xt = xec + hg0`(매 step T·d host scalar 루프, t-conv↔router-conv GEMM 사이)을 device 로. `forge_dispatch_residual_add` → `_hx_cuda_farr_residual_add_gpu` grid-stride, 출력 `FARR_DEVICE dirty_host=0`.

```
residual-add max|Δ| out=0.0
F-CLM-DEVFEED-RESIDUAL-EQ = 1
ALL-PASS (im2col/fwd/bwd/db/int4quant/adam 전부 max|Δ|0.0 유지)
```
verdict: `.verdicts/hexa-fusion-l3-glue/F-CLM-DEVFEED-RESIDUAL-EQ.txt`. raw-GEMM 우위 주장 0.

### ⑤b inter-op glue fusion (slice 2: gelu ×3 + groupnorm ×2) — ✅ (PR #2566, base #2564, bit-exact)

`forge_dispatch_gelu`(EXACT erf-based, device `erf()`=IEEE libm) + `forge_dispatch_groupnorm`(10-arg; sequential reduction + host-identical NR-40 sqrt → no tree re-assoc). 출력 `FARR_DEVICE dirty_host=0`.

```
gelu max|Δ| out=0.0                              → F-CLM-DEVFEED-GELU-EQ = 1
groupnorm max|Δ| y=0.0 xhat=0.0 mean=0.0 inv=0.0 → F-CLM-DEVFEED-GROUPNORM-EQ = 1
ALL-PASS (전 F-CLM-DEVFEED-* max|Δ|0.0 유지, no regression)
```
verdict: `.verdicts/hexa-fusion-l3-glue/F-CLM-DEVFEED-GELU-GN-EQ.txt`. raw-GEMM 우위 주장 0.

### ⑤c inter-op glue fusion (slice 3 FINAL: expert-pack + moe-router + embedding) — ✅ (consolidated #2571, bit-exact)

`forge_dispatch_expert_pack2` · `forge_dispatch_moe_router`(softmax: moe_lib `_moe_exp` Taylor 재현 + seq accumulation → strict 0) · `forge_dispatch_embedding`(token gather). 출력 `FARR_DEVICE dirty_host=0`.

```
expert-pack max|Δ| ex_out=0.0 → F-CLM-DEVFEED-EXPACK-EQ = 1
moe-router max|Δ| y=0.0 probs=0.0 → F-CLM-DEVFEED-MOEROUTER-EQ = 1
embedding max|Δ| xe=0.0 → F-CLM-DEVFEED-EMBED-EQ = 1
ALL-PASS (전 F-CLM-DEVFEED-* max|Δ|0.0 유지)
```
verdict: `.verdicts/hexa-fusion-l3-glue-final/F-CLM-DEVFEED-FINAL-GLUE-EQ.txt`. **🎯 fwd 인터프리트-glue EXHAUSTED 확정** — clm_prod_fwd 의 모든 host scalar 루프(embedding→conv→groupnorm→gelu→residual→expert-pack→moe-router)가 device-gated. W2 self-host pod util refire UNBLOCKED. raw-GEMM 우위 주장 0.

### ⑤-bwd BWD-tail glue fusion (slice 1) — ✅ (PR #2584, base main, strict byte-eq)

fwd glue 소진 후 다음 floor = bwd/AdamW-tail 인터프리트 glue. `forge_dispatch_gelu_bwd`(GELU'=Φ+x·φ, host literal/order 동일) · `forge_dispatch_groupnorm_bwd`(dgamma/dbeta/dX, seq reduction no atomics, saved fwd inv) · `forge_dispatch_expert_unpack2`(pack 의 bwd mirror). 출력 `FARR_DEVICE dirty_host=0`.

```
gelu_bwd max|Δ| dg=0.0 → F-CLM-DEVFEED-GELU-BWD-EQ = 1
groupnorm_bwd max|Δ| dgamma=0.0 dbeta=0.0 dX=0.0 → F-CLM-DEVFEED-GROUPNORM-BWD-EQ = 1
expert-unpack max|Δ| dex0=0.0 dex1=0.0 → F-CLM-DEVFEED-EXUNPACK-EQ = 1
ALL-PASS (전 F-CLM-DEVFEED-* max|Δ|=0 유지)
```
verdict: `.verdicts/hexa-fusion-l3-bwd-glue/F-CLM-DEVFEED-BWD-GLUE-EQ.txt`. raw-GEMM 우위 주장 0.

### ⑤-bwd2 BWD glue EXHAUST (slice 2 FINAL) — ✅ (consolidated #2591 = ⑤-bwd+⑤-bwd2, strict byte-eq)

`forge_dispatch_ce_grad`(CE softmax-grad, seq per-row) · `forge_dispatch_moe_router_bwd`(cached probs, seq, no atomics) · `forge_dispatch_grad_sum3/2`(dxt/dxec) · `forge_dispatch_embedding_bwd_scatter`(deterministic, NO atomics, host-order accumulate). 출력 `FARR_DEVICE dirty_host=0`.

```
ce_grad max|Δ| dlogits=0.0 → F-CLM-DEVFEED-CE-GRAD-EQ = 1
moe_router_bwd max|Δ| dlogits=0.0 dex_out=0.0 → F-CLM-DEVFEED-MOEROUTER-BWD-EQ = 1
grad-sum max|Δ| sum3=0.0 sum2=0.0 → F-CLM-DEVFEED-GRADSUM-EQ = 1
embedding-scatter max|Δ| dtable=0.0 → F-CLM-DEVFEED-EMBSCATTER-EQ = 1
ALL-PASS — 19 oracles 전부 max|Δ|=0
```
verdict: `.verdicts/hexa-fusion-l3-bwd-glue2/F-CLM-DEVFEED-BWD-GLUE2-EQ.txt`. **🎯 bwd 인터프리트-glue EXHAUSTED 확정** — fwd+bwd 둘 다 소진 → 인터프리터가 full-step hot path 거의 이탈. 잔여 orthogonal: dX col2im · per-tensor AdamW tail. main merge: consolidated #2591(rebase clean ← #2584/#2590). raw-GEMM 우위 주장 0.

### 📦 main merge (2026-06-02) — device-resident + glue 전부 landed

squash×스택 충돌(베이스 재작성)을 rebase + consolidation 으로 해소하고 6 logical PR 전부 main 착지:
`#2552`(reorg) · `#2556`(⑦) · `#2558`(⑥) · `#2555`(①m/v) · `#2570`(domain doc, rebased ← #2553) · `#2571`(device-resident port + 전 fwd glue, consolidated ← #2559/#2561/#2564/#2566 + ⑤c). 전부 env-gated `CLM_PROD_DEVRESIDENT` default off → byte-identical, 동작 변화 0. 남은 것: W2 pod util fire · bwd/AdamW-tail fusion(②⑤) · ④ CUDA-graph · ⑨-full bench.

### ⑦ operator surgical override — ✅ (PR #2556, base main, emit Δ ∧ byte-eq)

`compiler/codegen/nvptx_target.hexa` `_nvptx_wmma_mnemonic` was handle-uniform (cuBLAS model: one handle pins compute-type for all GEMMs). New `_nvptx_wmma_mnemonic_override(op,prec)` reads dst Local.precision → ONE call-site carries `.bf16` while siblings keep default (empty in every real run today → default byte-identical).

```
[byte-eq] default-path re-emit IDENTICAL — max|Δ|=0   PASS
[emit Δ]  override call-site emits .bf16 family         PASS
[per-site] store-c keeps default .shared.f32            PASS
F-FUSION-WMMA-OVERRIDE: PASS (emit Δ ∧ default byte-eq max|Δ|=0)
```
verdict: `.verdicts/fusion-wmma-override/F-FUSION-WMMA-OVERRIDE.txt`. 잔여: HIR `@bf16` → Local.precision grammar · silicon fire. raw-GEMM 우위 주장 0 — cuBLAS 가 못 하는 override 능력 probe.

### ⑥ compile-time specialization — ✅ (PR #2558, base main, emit Δ ∧ byte-eq)

`compiler/codegen/nvptx_target.hexa` GEMM 은 shape-generic emit(M/N/K = runtime `.param.u64`, K data-dependent loop). 새 `emit_ptx_gemm_module_specialized(M,N,K)` (additive, 0 deletion): compile-time 상수 shape 면 M/N/K param·`ld.param`·`cvt` 제거, M/N bounds-setp immediate, K stride literal-fold, K 수축 완전 unroll(`$L_LOOP`·back-edge·`kk` counter 제거).

```
emit-Δ: generic fma.rn.f64 count=1 (looped) vs specialized=3 (K straight-line, M4/N4/K3) — CONFIRMED
✅ BYTE-EQ: generic GEMM PTX IDENTICAL (origin/main == new binary), max|Δ|=0 — no regression
F-FUSION-GEMM-SHAPE-SPECIALIZE: rc=0
```
verdict: `.verdicts/hexa-fusion/F-FUSION-GEMM-SHAPE-SPECIALIZE.txt`. 잔여: dead-output elim(§5b 2nd) · MIR call-site auto-select · WMMA matmul 경로(`_nvptx_emit_matmul_body` K/16 tile) · silicon. raw-GEMM 우위 주장 0 — 런타임 loop-control + shape param-load 경계 제거(라이브러리는 런타임 dispatch).

## ── ② async-launch pipeline — slice 1 ✅ (W2-confirmed lever, 2026-06-03) ──

W2 가 확정한 진짜 unblock(인터프리트 per-step 드라이버 제거)의 첫 codegen 슬라이스. PR #2619 (base main). fwd device-kernel 10개(im2col·im2col_t·db_colsum·int4_quant·residual_add·gelu·groupnorm·expert_pack2·moe_router·embedding)를 **단일 non-blocking CUDA 스트림 `g_forge_stream`** 로 launch + per-call host-sync 제거 → 커널 back-to-back 큐. sync 는 step 경계(D2H readback 전 `cudaStreamSynchronize`)에서만.

`self/cuda/runtime_cuda_emit.hexa`: `g_forge_stream`(lazy) · `_forge_async_on()`(env `HEXA_CUDA_ASYNC` 우선, unset→`CLM_PROD_DEVRESIDENT` 따름, default off→legacy per-call sync) · `_forge_launch_check()`(async=`cudaGetLastError`, legacy=`cudaDeviceSynchronize`) · `_forge_sync()`(`_d2h`/`_d2h_out` 에 주입).

```
$ hexa run stdlib/flame/clm_conv_devfeed.hexa
ALL-PASS — 19/19 oracles max|Δ|=0, 0 FAIL
```
async-OFF = emitted-C byte-identical(substrate + 10 launch rewrite + 2 D2H sync 주입만, #2571/#2591 byte-eq 유지). async-ON = same kernels·one stream·sync-before-readback 라 **by construction byte-eq**. verdict: `.verdicts/hexa-fusion-l1-async/`. **잔여(②b 진행중)**: bwd-tail+AdamW wrapper 를 스트림에 · `cublasSetStream` 으로 GEMM 큐 합류 → 전체 step 단일 async 스트림 → ④ CUDA-graph 가능. **util MEAN≥20% 검증 = pod fire 필요 (env-congested → DEFERRED, 코드는 byte-eq 검증·landed)**. raw-GEMM 우위 주장 0.

## ── W2 util fire verdict — 🔴 CLOSED-NEGATIVE (2026-06-03, g5 verbatim) ──

full fwd+bwd device-resident step (glue 전량 device, byte-eq strict 0) 의 첫 직접 util 측정. pod H100 sm_90, d1536/T512 E2 nsamp32 epochs3, corpus 2MB, CLM_PROD_DEVRESIDENT=1 DEVFEED=1 BATCHED=1.

```
util MEAN=0.5296%  PEAK=32%  busy_mean=3.51%  pct_ge20=0.13%  n=776
devmem=28427MiB (28GB device-resident)  peak_power=116.6W
CE 3.82753 → 2.83301   F-CLM-PROD-DESCENT=1 (descent 🟢)
```
verdict: `.verdicts/hexa-fusion-w2-util/` (W2-VERDICT block). **util-GREEN gate = MEAN≥20% → 미달 🔴** (스크립트의 "GREEN(peak≥20%)" 표기는 오류 — gate 는 PEAK 아님 MEAN).

**결정적 CLOSED-NEGATIVE**: util MEAN 비교 — lever-2 0.50% · lever-3 0.56% · fwd-only(③) 2.83% · **W2 full fwd+bwd 0.53%**. glue 를 전량 device 化(byte-eq 검증)했는데도 MEAN floor 가 안 닫힘 ⇒ **병목은 glue op 들이 아니라 인터프리트 per-step 드라이버 루프 자체**(~30 device 커널을 1개씩 host-sync 디스패치). full step(fwd+bwd+adam)이 fwd-only 보다 *더 낮은* 것도 일치(host 오케스트레이션 2배). **"per-op device化" 축을 결정적으로 배제** — HEXA-FUSION device-resident+glue 는 필요 인프라(main landed·byte-eq 검증)이나 util-GREEN 엔 불충분.

**⇒ 다음 진짜 레버 확정**: ② async-launch pipeline(host-sync 없이 커널 큐) · ④ CUDA-graph(step 캡처/replay) · 또는 단일 fused train-step mega-kernel — 인터프리트 per-step 드라이버 제거. ⑤ fwd+bwd autograd fusion 의 "한 device 그래프" 도 이 방향. 정직 caveat: 빌드가 fe2e43a(laneg)+splice(prebuilt 가 forge_dispatch 로워링 미포함)였으나 결과 0.53% 가 전 이전 측정과 일치 → 결론 robust. paper_negative_ok 자격(닫힌 음성: per-op device화 축 배제).

## ── 전략 정정 (⑧+⑨ 합성) — 2-regime: compute-bound=MATCH · launch-bound=EXCEED ──

⑨ 가 확정: 프로덕션 shape(d1536 dense MoE)는 **compute-bound** — PyTorch 가 같은 H100·shape 에서 util 100% 를 이미 찍는다. ⇒ hexa 의 util-RED(0.6%)는 GPU 일이 작아서가 **아니라 인터프리터 host-loop 가 굶긴 것**(PyTorch 100% 가 그 반증). 따라서:

```
regime                compute-bound (dense GEMM)        launch-bound (elementwise glue · 30 builtin · 20× AdamW)
────────              ──────────────────────────        ────────────────────────────────────────────────────
PyTorch               util 100% · roofline (포화)        op-by-op launch 손해
HEXA 목표             = MATCH (못 이김 ≠ 실패)           = EXCEED (⑧: ≥30% wall win UNCONDITIONAL)
도달 수단             lane ① device-resident 면 충분      lane ⑤⑥⑦ fusion + compile-time 특화
```

- **util-GREEN(=match)** 는 lane ① (device-resident, host-loop 제거)만으로 도달 — 워크로드가 이미 충분히 무거움(⑨ 증명). 추가 fusion 불필요.
- **exceed-PyTorch** 는 오직 launch-bound regime(작은 op·glue)에서 — ⑧ 이 ≥30% 무조건 우위를 $0 로 박제. dense GEMM 은 둘 다 roofline → 비김.
- 측정 전제(g5): full hexa-vs-PyTorch wall 벤치는 lane ① 착지 후 unblock(⑨-full).

## ── 상속: 이미 측정된 fusion 승리 (재유도 금지, cite) ──

이 도메인은 GPU 도메인의 fusion 캠페인이 측정한 교두보를 상속한다 (재측정 아님 · g5 verbatim 인용):
- **attention fusion R14 ≤1.0× vs cuBLAS-TC 3-launch** (GPU.md §1p, F-FUSION-ATTN-BM32-OCCUPANCY) — launch-bound 영역에서 라이브러리 스택을 실제로 앞지른 측정 beachhead.
- **F-FUSION-LAUNCH-AMORT $0 oracle** (GPU.md §1h, R12) — launch-overhead amortization 정적 증명.
- **whole-program-fusion epilogue GEMM+bias+GeLU** structural finding (GPU.md §1h, 2026-05-25).

## ── 정직 가드 (a_scale_honest_scope · g5) ──

- raw GEMM/커널 한 장으로 cuBLAS 우위 주장 = 즉시 falsified(GPU.md:84 박제). 이 도메인의 win 은 **오직** 경계 제거(launch + op-boundary fusion + compile-time 특화).
- util≥20% 는 항상 single-driver pod fire verdict 소유 — 소스 단독 주장 금지.
- byte-eq(max|Δ|=0) 는 모든 fusion milestone 의 hard gate — 정확성 없는 가속은 무효.

## ── ② async-launch pipeline — codegen LANDED · util 측정 BLOCKED (seed-drift) ──

W2 가 지목한 binding constraint(인터프리트 per-step 드라이버: ~30 device 커널을 host-sync 로 1개씩 디스패치 → GPU starve)의 **codegen 해제가 main 에 전량 착지**. 4 슬라이스, 전부 async-off byte-identical(CUDA stream-0 = default 의미) + host-ref oracle 19/19 max|Δ|=0:

```
② async pipeline (self/cuda/runtime_cuda_emit.hexa) — single g_forge_stream
├─ #2619 fwd 커널 async (g_forge_stream + _forge_launch_check)      merged
├─ #2621 GEMM stream  (cublasSetStream + _forge_sync @readback)     merged
├─ #2622 bwd/opt 14 launch → g_forge_stream (단일스트림 정합)        merged
└─ #2624 device-resident bwd 9 sync 제거 (cudaDeviceSync→launch_chk) CI
```
async-on 시 학습 1스텝 전체(fwd 커널 + cuBLAS GEMM + bwd 커널 + optimizer)가 **단일 forge-stream** 에서 host readback 경계에서만 sync — per-op host barrier 제거. async **off**(기본) 는 byte-identical 이라 회귀 0. 제외: col2im/adamw(host readback `_d2h_out` 후 sync 필수) · softmax/ce_seed/rmsnorm(default stream).

**util A/B 측정(ASYNC=0 vs =1) = 🔴 BLOCKED** — pool RTX 5070(summer/aiden, $0 렌트) 에서 빌드를 끝까지 추적, **4 블로커 해결**(emit write_file·flatten argv placeholder·nvcc `-x cu`·cuda include) 후 **seed-drift 벽**:
- clm_prod → `nn_gelu_bwd`(hexa) → `forge_dispatch_gelu_bwd`(host C wrapper)
- 그 host wrapper(gelu_bwd·expert_pack2·expert_unpack2·moe_router_bwd 등 W2 device-resident glue)가 로컬 `self/runtime.c` 시드·emit·브랜치소스 어디에도 없음 — W2 pod runtime.c 에 손스플라이스됐다가 로컬 미저장(gitignored seed). `hexa_call4` 타입에러 = hexa_cc.c↔runtime.c 시드 ABI 불일치까지.
- ⇒ GPU 경로는 byte-eq oracle 부재 → 손으로 맞춘 wrapper 로 측정 시 **g5 위반(조용한 오염)**. fabricate 거부, 측정은 시드재구성을 갖춘 별도 검증사이클로 분리. 레시피 전문: memory `project_clmprod_gpu_build_seed_drift`.

**부수 발견 (실버그)**: emit 의 device runtime 쓰기가 `exec("cat > path <<EOF" + c_text + "EOF")` 였는데 c_text>128KB(현재 244KB) 이면 단일 `sh -c` argv 가 `MAX_ARG_STRLEN`(128KB) → E2BIG 로 **조용히 실패**. pool 에서 재현(prebuilt interp + 컴파일 바이너리 양쪽). `write_file`(rt_write_file fopen)로 교체 → byte-identical · #2630. fresh 빌드 호스트의 잠재 wall 제거.

verdict: `.verdicts/hexa-fusion-l1-async/` (async byte-eq) · 측정-block 은 음성-결과로 정직 기록(util 수치 미주장 — single-driver pod fire verdict 부재).

## ── own-GEMM WMMA2 sm_90 (Hopper H100) launch fix — ✅ LAUNCHES · 🔴 PARITY CLOSED-NEG (2026-06-06, g5 verbatim) ──

verdict F-FUSION-WMMA2-SM90-VERIFY(#2796) 진단: own-GEMM `_hx_k_sgemm_cm_wmma2` 가 native **sm_90** 에서 launch 안 됨 — `cudaErrorInvalidValue`. 근인 = STATIC `__shared__` 합 **57344 B**(As 32768 + Bs 16384 + tmp 8192) > sm_90 per-block static cap **49152 B**. Blackwell sm_120 은 더 큰 static admit 으로 통과(README 1.13× = 거기서 측정). Tensor-Core codegen 은 정상(sm_90 SASS HMMA 84) — 실패는 순수 launch-config/shared-mem.

**FIX (dynamic-shared opt-in, 128×64 타일 유지, math byte-identical)**: As/Bs/tmp → `extern __shared__ float hxg_smem[]`(옛 static 과 동일 offset) + launcher/driver 에 `cudaFuncSetAttribute(_hx_k_sgemm_cm_wmma2, cudaFuncAttributeMaxDynamicSharedMemorySize, 57344)` 1회 + `<<<grid,block,57344>>>` 3rd arg. OFF-safe(HEXA_OWN_GEMM_WMMA2 경로만, default cuBLAS 무변).

**native sm_90 측정** (vast 39622686, nvidia-smi `NVIDIA H100 80GB HBM3, compute_cap 9.0`, nvcc 12.4, `-gencode arch=compute_90,code=sm_90`, pod DESTROYED leak 0):
```
wmma2 cudaFuncSetAttribute(maxDynSmem=57344) -> no error
wmma2 launch status: launch=no error  sync=no error   ← LAUNCHES YES (cudaErrorInvalidValue 제거)
3-way ms/iter @ M=N=K=2048, 50 iters:
  cuBLAS (TF32)       : 0.05072 ms/iter   (1.00x)            [~339 TFLOP/s]
  tiled-WMMA2(CUTLASS): 1.49432 ms/iter   (29.46x vs cuBLAS) [~11.5 TFLOP/s]
  tiled-WMMA2 rel-RMS = 4.766e-06  PASS  (TF32 tol 3e-3)
stability re-run 100it: cuBLAS 0.05042 / WMMA2 1.48678 (29.49x) — stable
```
**PARITY-RESTORED: NO**. launch fix 는 성공(sm_90 launch + correctness PASS)이나 native-H100 parity 미회복 — WMMA2 가 cuBLAS 대비 **29.46× 느림**, Blackwell 1.13× 와 무관. 근인(cuobjdump -res-usage): **REG:236/thread**(60416 regs/256-thread block) + 57344 B dyn-smem → H100 65536 regs/SM 에서 **~1 block/SM** = register/occupancy-bound. Blackwell 1.13× 는 sm_120 의 더 큰 레지스터 파일/occupancy 헤드룸에 의존했고 sm_90 으로 **transfer 안 됨**. 정직(g5): cuBLAS = roofline, raw-GEMM 우위 주장 0. **CLOSED-NEGATIVE on sm_90 parity axis** — dynamic-shared opt-in 은 launch 에 필요(충분)하나 parity 엔 불충분; 잔여는 별개 occupancy(레지스터-압) 축. verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-DYNSHARED-FIX.txt`.

## ── own-GEMM cuBLAS-class mainloop sm_90 — ✅ 3/4 levers landed · 🔴 PARITY CLOSED-NEG (mma.sync ceiling) (2026-06-06, g5 verbatim) ──

`F-FUSION-SM90-WARPTILE-RETUNE`(#2800) 가 occupancy 축을 닫고 진단을 inner-loop **math pipeline** 으로 좁힌 뒤, cuBLAS/CUTLASS-class mainloop 기법을 직접 적용. 새 커널 `_hx_k_sgemm_cm_wmma2_cb`(env `HEXA_OWN_GEMM_WMMA2_CB`, default OFF = parent byte-identical).

**LEVERS (3/4 landed, 1 named residual):**
- **L1 ✓ 하드웨어 TF32 mma.sync** — raw PTX `mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32`, round 는 operand 레지스터에서 `cvt.rna.tf32.f32` 로 fuse (parent 의 per-element software `__float_to_tf32` 프래그먼트 스윕 제거). m16n8k8 = 1 native HMMA vs wmma 16x16x8 의 2.
- **L2 ✓ 깊은 cp.async 파이프라인** — HXG_CB_STAGES-deep 링(default 3), wait_group N. on-pod 스윕: 2→11.65, 3→11.55, 4→11.50, 5→10.99 TFLOP/s ⇒ **2-stage 에서 포화**(global→shared latency 가 binding 아님을 2차 확인).
- **L4 ✓ register-blocked epilogue** — thread 당 m16n8 accumulator 4×.f32 레지스터를 col-major C 로 직접 store (shared round-trip/`__syncwarp` 제거).
- **L3 ✗ ldmatrix** — `ldmatrix.x4` 는 `.b16`(16-bit) op, TF32 operand 는 32-bit ⇒ indexed shared load 사용. 32-bit `ldmatrix.trans` swizzle 이 named residual.

**correctness 핵심 수정**: 초기 빌드 rel-RMS 1.0(garbage). m16n8k8 `.tf32` A/B operand k-index 는 `{tig, tig+4}`(fp16-style `{tig*2, tig*2+1}` 아님). standalone mma probe(sm_90)로 canonical layout 확정 → **rel-RMS EXACTLY 0.000e+00**(이 seed 에서 cuBLAS-TF32 oracle 과 bit-exact; parent 는 4.766e-06).

**native sm_90 측정** (vast 39628863, `NVIDIA H100 80GB HBM3, compute_cap 9.0`, nvcc 12.6, `-arch=sm_90`, pod DESTROYED leak 0):
```
cuBLAS-TF32   : 0.051 ms   ~339.7 TFLOP/s   (roofline baseline)
parent WMMA2  : 1.538 ms     11.17 TFLOP/s   30.4× off cuBLAS   rel-RMS 4.77e-06
CB variant    : 1.488 ms     11.55 TFLOP/s   29.4× off cuBLAS   rel-RMS 0.000e+00 (run2 11.54, stable)
REG: parent 240/thr · CB 128/thr (STACK 56)
```
**own GFLOP/s before→after: 11,167 → 11,546 (+3.4%) · gap 30.4× → 29.4× ⇒ ~3.4% of cuBLAS gap closed · PARITY: N.**

**FINDING (CLOSED-NEGATIVE — mma.sync warp-level = ceiling)**: 3개 표현가능 lever 전부 landed + correct 이나 합산 +3.4% 에 그침. stage-depth 가 2 에서 포화(축2 재확인)하는 것과 합쳐, binding constraint 는 **mma.sync 명령어 클래스 자체**. Hopper 에서 cuBLAS 는 **wgmma.mma_async**(warpgroup-level async MMA) + **TMA**(`cp.async.bulk.tensor`)로 TC peak 도달 — mma.sync 가 pipelining/epilogue 튜닝과 무관하게 닿을 수 없는 별개 클래스. 잔여 ~29× 는 wgmma+TMA rewrite(sm_90a-specific, CUTLASS-3.x-class kernel)이지 mainloop retune 아님. 정직(g5): parity-seeking, cuBLAS=roofline, 우위 주장 0. CB 는 env-gated default-OFF 로 ship(parent byte-identical) — 검증된 작은-양성 datapoint + 날카로워진 negative(다음 lever = wgmma/TMA, 명시). verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-CUBLAS-MAINLOOP.txt`.

## ── wgmma.mma_async + TMA own-GEMM sm_90 — ✅ FEASIBILITY PASS · 🟠 layout residual (2026-06-06, g5 verbatim) ──

The residual lever named by `F-FUSION-SM90-CUBLAS-MAINLOOP` (mma.sync ceiling 11.55 TFLOP/s = 29.4× off cuBLAS): the warpgroup-async class. Standalone kit `self/native/wgmma/` — f16 + tf32 wgmma probes, a `cuTensorMapEncodeTiled` + `cp.async.bulk.tensor.2d` + mbarrier TMA pipeline feeding a `wgmma.m64n128k8` warpgroup mainloop, + `build_and_measure.sh`. Native sm_90 H100 (vast 39628805, `NVIDIA H100 80GB HBM3, compute_cap 9.0`, nvcc 12.6, `-arch=sm_90a`, pod DESTROYED leak 0).

**PROBE FEASIBLE: YES.** sm_90a builds clean and **wgmma.mma_async EXECUTES CORRECTLY on native H100** (f16 m64n32k16 probe: nonzero 2048/2048, sum 1962.49 vs ref 1956.87). This converts the prior `F-FUSION-ATTN-WGMMA-WALL` (bc4-r15, 2026-05-28) **hardware-blocked closed-negative** — same wgmma kernel silently NOP'd on Blackwell sm_120 (output all-zero) — into **testable + builds + runs** on real Hopper. The whole Hopper async PTX surface (`cuTensorMapEncodeTiled` driver API + `cp.async.bulk.tensor.2d.shared::cluster.global.mbarrier::complete_tx::bytes` + `mbarrier.init`/`arrive.expect_tx`/`try_wait.parity`) is **ptxas-accepted on sm_90a** (TMA GEMM TMA-BUILD=0). **The own-source emit path is NOT the blocker.**

**RESIDUAL (🟠): the no-swizzle core-matrix shared-memory LAYOUT.** TF32 single-warpgroup mainloop builds + launches but rel-RMS **1.309e+00** (FAIL vs 3e-3). An isolated process-safe (LBO,SBO) descriptor sweep over {16,32,64,128,256,512} found **no combo below 1.309** — descriptor byte-offsets are NOT the binding error. A structured-input diagnostic (C[m][n]=n) confirmed the **accumulator-register → C(row,col) epilogue mapping is CORRECT** (thread 0 receives column-octets 8,16,…,56). The binding residual is the wgmma no-swizzle **8×16B core-matrix tiling** of A/B in shared (a permutation/transpose leaves the contraction ~uncorrelated, rel-RMS ≈ √2); the integrated TMA pipeline additionally faults at runtime (coordinate/mbarrier-phase addressing). Pinning this is the precise CUTLASS-3.x swizzle wedge.

**own GFLOP/s: NOT-REPORTED** (kernel not bit-correct — g5 forbids perf on a wrong-result kernel). **PARITY: NO (not measured). % gap closed: 0% measured.** Honest: parity-seeking, cuBLAS=roofline, no superiority claim. **FINDING** = a POSITIVE feasibility Δ (wgmma+TMA build+run-feasible on native sm_90, vs the prior cannot-test closed-negative) + a sharpened named residual (the ruled-IN axis is operand shared-layout correctness, NOT the instruction/descriptor/epilogue/emit-path). verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-TMA.txt`.

## ── wgmma no-swizzle layout — 🔴 residual PINNED to B K-core stride (closed-neg) · `F-FUSION-SM90-WGMMA-SWIZZLE` (2026-06-06, g5 verbatim) ──

Resume from `F-FUSION-SM90-WGMMA-TMA`'s rel-RMS 1.309 residual. Native **H200** (Hopper compute_cap 9.0 = sm_90a-identical to H100 for wgmma/TMA), nvcc 12.6 `-arch=sm_90a`, **3 vast H200 contracts (2 RECLAIMED mid-run, re-rented) — all DESTROYED, leak 0**.

**SWIZZLE-FIXED: NO (this pass)** — but the binding residual is now **PINNED to ONE operand + ONE stride** (a strict advance over the prior "operand layout" framing). An **on-hardware reverse-engineering** (distinct-ramp A/B + one-hot selector on the other operand; epilogue independently confirmed correct prior) decoded *exactly what wgmma reads*:

```
B read-map, plain row-major B, desc(lA16 sA32 lB16 sB32):
  KSEL=0: n0->B[0][0]✓  n1->B[0][4]   ok=8/64
  KSEL=1: n0->B[0][1]   n1->B[0][5]   ok=0/64   <- k'=0, NOT k'=1
  KSEL>0: every selector reads k'=0                kslices_active=8/8
```

Two superimposed defects, both in the **wgmma B no-swizzle core-matrix layout**: (1) **K-STRIDE COLLAPSE** — for contraction k=1..7 wgmma re-reads B's K=0 core-matrix (k′ pinned to 0 ∀ KSEL); dominant ≈√2 rms error. (2) **N-OCTET INTERLEAVE** — output col n ← logical col ≈4n within an 8-wide octet.

**RULED OUT deterministically**: a **>2300-config** sweep — A/B shared layout ∈ {plain row-major, two 8-row-strip core tilings, col-major-B} × descriptor (LBO,SBO) ∈ {16,32,64,128,256,512} both operands × 3 epilogue register-maps (fault-isolated per-process) — found **no config below rel-RMS 1.36** (best 1.362, AL0/BL2/EPI0). The residual is **NOT** a plain-layout/offset/epilogue permutation.

**RULED IN (next-cycle, scoped)**: build the B (and A) shared tile via the **CUTLASS `GMMA::Layout` core-matrix builder** — B's 8 K-values as a contiguous 8-row core-matrix, descriptor LBO = one-core-matrix stride, swizzle field matched to the TMA `cuTensorMapEncodeTiled` swizzle (none/32B/64B/128B). Verify FIRST on the single-tile decode probe to **k′==KSEL identity (rel-RMS 0)** before any 2048³ perf run.

**own GFLOP/s: NOT-REPORTED** (g5 — no perf on a wrong-result kernel). single-tile rel-RMS 1.309 · full-GEMM N/A · PARITY: NO · % gap closed: 0% measured · **pod destroyed: YES (leak 0)**. Honest: parity-seeking, cuBLAS=roofline, no superiority claim. Kit: `self/native/wgmma/{wgmma_tf32_decode,wgmma_tf32_bdecode,wgmma_tf32_full}.cu` + `sweep_fast.sh`. verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-SWIZZLE.txt`.

## ── forge sm_90 own-GEMM parity — CONSOLIDATED FINAL STATE (honest ladder · de-risked OPEN residual) ──

This consolidates the sm_90 own-GEMM parity campaign (four honest-negative
attempts, all verbatim verdicts above). The own-GEMM seeks **parity** with
cuBLAS, never superiority — cuBLAS is the roofline; there is NO own-vs-cuBLAS
superiority claim on any architecture. The measured ladder, each rung a real
on-silicon run with its own verdict:

| rung | kernel | result | gap vs cuBLAS-TF32 | verdict |
|---|---|---|---|---|
| 0 | parent WMMA2 (sm_90 launch-fixed) | rel-RMS 4.77e-06 | **30.4×** off | `F-FUSION-SM90-DYNSHARED-FIX` |
| — | WMMA2-RR (occupancy retune) | 1→2 blocks/SM, −4% | ruled out | `F-FUSION-SM90-WARPTILE-RETUNE` |
| 1 | mma.sync cuBLAS-class mainloop (CB) | bit-exact (rel-RMS 0.000e+00) | **29.4×** off (+3.4%) | `F-FUSION-SM90-CUBLAS-MAINLOOP` |
| 2 | wgmma.mma_async + TMA | FEASIBLE (builds+runs sm_90a) | not measured | `F-FUSION-SM90-WGMMA-TMA` |
| 3 | wgmma no-swizzle bit-correctness | BLOCKED (rel-RMS 1.309) | not measured | `F-FUSION-SM90-WGMMA-SWIZZLE` |

**Ladder narrative (honest, g5):**
1. **30.4× → 29.4×** is the only measured improvement: the mma.sync cuBLAS-class
   mainloop (3/4 levers landed — hardware-TF32 `mma.sync.m16n8k8`, deep
   `cp.async` pipeline, register-blocked epilogue; `ldmatrix` did not land) is
   **bit-exact** but closes only ~3.4% of the cuBLAS gap. The binding ceiling
   is the **`mma.sync` warp-level instruction class itself** — on Hopper,
   cuBLAS reaches TC peak via `wgmma.mma_async` (warpgroup-async) + TMA, a class
   `mma.sync` cannot reach by any mainloop tuning.
2. **wgmma + TMA is FEASIBLE on sm_90a** (build + run): `wgmma.mma_async`
   executes correctly and the full Hopper async PTX surface
   (`cuTensorMapEncodeTiled` + `cp.async.bulk.tensor.2d` + `mbarrier.*`)
   compiles and launches. **The own-source emit path is NOT the blocker** —
   this converts the prior hardware-blocked `F-FUSION-ATTN-WGMMA-WALL`
   closed-negative into a testable-on-Hopper problem.
3. **wgmma bit-correctness is BLOCKED** on the no-swizzle B-operand core-matrix
   shared-memory layout: a **K-stride collapse** (k=1..7 re-read B's K=0
   core-matrix) + an **N-octet interleave**, the rel-RMS 1.309 residual. A
   >2300-config exhaustive sweep (layout × descriptor (LBO,SBO) × epilogue
   register-map) found no config below rel-RMS 1.36, **deterministically ruling
   out** the residual being a plain-layout / offset / epilogue permutation.

**NAMED RESIDUAL (concrete next-cycle claim, multi-session):** implement the
real CUTLASS-3.x `GMMA::Layout` core-matrix builder for the B (and A) shared
tile — B's 8 K-values laid out as a contiguous 8-row core-matrix, descriptor
LBO = one-core-matrix stride, swizzle field matched to the TMA
`cuTensorMapEncodeTiled` swizzle mode. Verify FIRST on the single-tile decode
probe to `k′==KSEL` identity (rel-RMS 0) before any 2048³ perf run.

**PARITY framing (g5):** own-GEMM **parity** is achieved only on Blackwell
(the 1.13× iso figure is sm_120-specific). On native sm_90 (Hopper, H100/H200)
parity is **NOT achieved** — it is an **OPEN, de-risked named residual**: the
instruction class (wgmma+TMA) and the emit path are proven feasible; the single
remaining wall is the CUTLASS core-matrix layout above. No perf number is
reported on any non-bit-correct kernel (g5). cuBLAS = roofline; no superiority
claim. Kit: `self/native/wgmma/`. Pods all destroyed across every run (leak 0).

## ── own-GEMM sm_90a W-ladder: BIT-CORRECT achieved · perf W6 → W7 (2026-06-06, g5) ──

The breakthrough route is the **own-GEMM** itself (forge's `self/native/wgmma/*` .cu) —
NOT a separate flame/forge mechanism. flame rides forge rides this kernel, so closing
the own-GEMM gap lifts the whole stack automatically.

- [x] **W1 GMMA::Layout B-core-matrix builder** ✅ (#2819) — INTER 8×4 TF32 core layout (LBO 128B/SBO 256B).
- [x] **W2 single-tile identity verify** ✅ (#2819) — rel-RMS **0.000e+00** — the swizzle is SOLVED ★ (the
      no-swizzle 8×16B core-matrix wall above is now CLOSED — the residual was one constant: 8×4 elems, not 8×8).
- [x] **W3 full wgmma+TMA GEMM bit-correct** ✅ (#2819) — rel-RMS **0 @ 2048³** (own == cuBLAS == CPU-f64);
      2nd bug fixed: wgmma reads shared via the async proxy → needs `fence.proxy.async.shared::cta`.
- [x] **W4 sm_90 parity measure** ✅ honest — naive single-wgmma/block own **20.2 TFLOP/s**, 17.67× off.
- [x] **W5 pipeline tune** ✅ — wide-N TN=128 → **38.0 TFLOP/s** (9.35× off), bit-exact.
- [x] **W6 cp.async multi-stage ring (async-pipe)** ✅ (#2833) — own **38.0 → 50.7 TFLOP/s** @4096³, rel-RMS **0**
      (+33%) → **8.39× off** cuBLAS-TF32 (~422). ~11.5% of gap closed. warp-spec first pass: race fixed
      (`wg_bar`) → rel-RMS 0 but 35.0 only (a SINGLE consumer warpgroup STARVES the tensor cores at TM=64).
- [x] **W7 dual-consumer-warpgroup warp-spec (TM=128)** — 🔴 CLOSED-NEGATIVE (bit-exact, occupancy-bound).
      BUILT (MODE 3 `gemm_ws2`, 384 thr = 3 WG: 1 cp.async producer WG + 2 consumer WGs each `wgmma` over its
      64-row band × the SHARED B tile) + run on native sm_90a H100 (vast 39651872, DESTROYED leak 0, nvcc 12.5.82).
      **BIT-EXACT** (rel_rms **0** @ S=2048/4096, NST=2..5) but **32.0 TFLOP/s (13.2×) — SLOWER** than W6 async-pipe
      50.7 (8.39×). W7 hypothesis FALSIFIED. Root cause (on-pod `cudaOccupancyMaxActiveBlocksPerMultiprocessor`):
      a 128-thread cp.async producer WG at TM=128 is **register-bound to 1 block/SM** (90 regs × 384 thr;
      2 CTAs = 69120 > 65536 regs/SM) → 256 compute-thr/SM vs async-pipe's 4×128 = 512. More consumer WGs cannot win
      while the producer eats a full WG AND evicts the 2nd resident CTA. verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W7.txt`.
- [x] **W8 TMA-driven production (single elected thread + dual-consumer-WG)** ✅ BIG-PROGRESS — `MODE 4 gemm_ws_tma`:
      thread 0 issues `cp.async.bulk.tensor.2d` for the A-band+B into an NST ring (mbarrier expect_tx); the other 255
      threads are BOTH consumer warpgroups. H100 sm_90a (vast 39701877 DESTROYED leak 0, nvcc 12.6). **BIT-EXACT**
      (rel_rms **0** @ S=2048..8192, NST=2..4). **own 50.7 → 66.5 TFLOP/s @4096³ (+31%); 69.6 @8192³**; ratio
      **8.39× → 6.44×** off cuBLAS-TF32 (~428–456). **OCCUPANCY ROSE 1 → 2 CTA/SM** (512 vs 384 compute-thr/SM) —
      the W8 success proxy ACHIEVED: TMA producer freed the WG + shrank the CTA 384→256 thr (120 regs·256 = 30,720/CTA,
      2 CTAs = 61,440 < 65,536 regs/SM). The dual-consumer-WG geometry W7 wanted FINALLY pays once the producer stops
      eating a full WG. **~26% of the 8.39×→1.0× parity gap closed.** PARITY=NO (6.44×). verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W8.txt`.
- [ ] **W9 swizzled-TMA (eliminate the cooperative permute)** ★ NEXT — frontier is now COMPUTE/MAINLOOP-bound, not
      occupancy-bound. `CU_TENSOR_MAP_SWIZZLE_128B` so the TMA tile lands wgmma-readable → KILL the per-K-step
      Araw/Braw→gmma permute (+ its 2 `__syncthreads`) that cuBLAS never pays. Plus deeper-TK accumulator double-buffer
      + n=256 (m64n256k8). Target: **6.44× → toward ≤1.3×**. Frontier kernel = W8 `gemm_ws_tma` (66.5, 6.44×, 2 CTA/SM).

**STATE**: correctness CLOSED (W2/W3 bit-exact). **W8 CONFIRMED the W7 diagnosis**: the wall WAS the production
engine — a single-elected-thread HARDWARE TMA producer fixes the occupancy (1 → 2 CTA/SM) and LIFTS the frontier
50.7 → 66.5 (+31%), gap 8.39× → 6.44×. The frontier is now compute/mainloop-bound (the cooperative gmma permute), NOT
occupancy / NOT layout / NOT emit-path / NOT 불가. Frontier kernel = W8 `gemm_ws_tma`. Parity OPEN, further de-risked,
own-GEMM-owned. cuBLAS = roofline, no superiority claim.
