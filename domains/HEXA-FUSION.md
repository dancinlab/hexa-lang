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

## ── 사다리: match (L1) → graph (L2) → exceed (L3) ──

### L1 — device-resident (= PyTorch eager 수준, util-GREEN)

- [~] **device-resident tensor lifetime** — param/grad/moment 를 step 전체에 GPU-resident 유지(host roundtrip 0). falsifier: 기존 오라클 byte-eq max|Δ|=0 ∧ nvidia-smi devmem persist across step. **W1-① PARTIAL (PR #2555 m,v + #2559 grad-db + #2561 int4)**: m,v + bias grad db + **int4 quant(W-fwd/dW-STE, 정수-exact)** device-resident 착지(env `CLM_PROD_DEVRESIDENT`, byte-eq ALL-PASS). 잔여: dX col2im transpose(orthogonal) · self-host pod build · devmem/util fire. **③ 정밀화: 텐서 resident 만으론 부족 — op 사이 인터프리트 host glue 도 fuse 해야 util MEAN gap 닫힘**. 상세 = §W1 results.
- [ ] **async kernel-launch pipeline / per-step driver 제거 — ★ W2-CONFIRMED 진짜 unblock** 〔glue 소진(✅) 후 W2 가 MEAN 0.53% 로 측정: 인터프리트 per-step 드라이버가 floor〕 — step body 가 host 인터프리터 블로킹 없이 device 커널을 비동기 큐(host-sync 제거). glue fusion(⑤*)은 이미 done 이나 W2 가 **불충분 확정** → 핵심은 ~30 커널/step 의 host-sync 디스패치 제거(async queue / CUDA-graph ④ / 단일 fused step). falsifier: `F-RFC046-GPU-UTILIZATION` util MEAN≥20% @ d1536/T512.
- [x] **fwd-only fused device kernel 프로토타입 + util Δ probe** ✅ W1-③ — H100 fwd-only fire: MEAN 0.56→**2.83%** (5×↑) PEAK 21→**81%**, 여전히 RED. **진단**: device 는 세게 돌 수 있음 + binding = 인터프리트 per-step glue(GEMM 아님). 텐서 resident 만으론 부족 → inter-op glue fusion(⑤) 필요. 상세 = §W1 results.

### L2 — graph capture (= torch.compile / CUDA-graph 수준)

- [x] **per-step CUDA-graph capture/replay — 구현+측정 DONE (PR #2658)** — fwd→ce_grad→bwd 1회 캡처
  (첫 비-metric step) → bulk step 은 `cudaGraphLaunch` 1번 replay. AdamW eager(step-의존 t), loss readback
  캡처 밖. env `HEXA_CUDA_GRAPH`. 측정(idle H100, `.verdicts/hexa-fusion/F-FUSION-GRAPH-AB.txt`):
  GRAPH=0 util 11.85% vs GRAPH=1 13.17%(+1.32pp) · CE 4.46624→3.64669 **둘 다 비트동일 = byte-eq PASS**.
  ✅ 정확성: 캡처 건전(race 無) — ②가 깬 byte-eq 회복(②와 달리 정확성 통과한 최초 레버).
  ❌ util-GREEN 미달(+1.32pp, FALSIFIED ≥20%): 그래프가 fwd→bwd 만 — eager 28-launch AdamW + 토큰 H2D 가
  여전히 host 임계경로 고정. ④ = 필요조건이나 불충분.
- [x] **⑤ whole-step capture — 🔴 CLOSED-NEGATIVE (PR #2658, PHASE-1 PROBE 측정)** — AdamW 16-launch
  sweep 를 ④ 캡처 영역(fwd→ce_grad→bwd) 안으로 넣어 host 를 per-step 임계경로에서 완전 제거(env
  `HEXA_CUDA_GRAPH_WHOLESTEP=1`, `_adam_sweep` 를 begin…commit 안에서 issue + replay 에서 skip).
  PHASE-1: c1/c2 baked(num-wrong OK) — util CEILING 만 측정. H100 NVL @ D1536/T512/EPOCHS4:
  g0(eager)=**14.87%** · g1(④ fwd/bwd)=**13.19%** · g1ws(⑤ whole-step)=**13.54%**, 셋 다 MEDIAN 2% PINNED.
  ❌ FALSIFIED util MEAN≥20% (13.54%, ④ 대비 +0.35pp = noise). **결정 게이트: Phase 2(device-t byte-eq)
  진행 안 함** — host-removal 가설 REJECTED. binding constraint = host launch 가 아니라 **fine-grained
  serial kernel DAG**(sub-ms 커널이 의존성 체인으로 직렬, SM 이 커널 사이 idle). util-GREEN 은 어떤 캡처
  영역으로도 도달 불가 — 남은 축은 host-removal 이 아니라 **workload-shape**(larger-tile / 커널 fusion 으로
  의존성 체인 축소 = L3 ⑤ fwd+bwd autograd fusion 방향). verdict: `.verdicts/hexa-fusion/F-FUSION-GRAPH-WHOLESTEP-AB.txt`.
  ② async · ④ fwd/bwd graph · ⑤ whole-step 전부 MEDIAN 2% / MEAN ~12-15% 로 bottom-out → "host launch
  overhead = util ceiling" 축 전체 CLOSED-NEGATIVE TERMINAL. (paper_negative_ok 자격: 닫힌 음성.)

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
