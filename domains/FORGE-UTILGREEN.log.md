# FORGE-UTILGREEN — append-only step log

## 2026-06-02T22:30Z — Lane-G (substrate=GPU · H100 sm_90 pod vast 39126604 · a_lane_akida_gpu_split — NEVER merged with AKIDA) — lever-3 util fire **2nd INDEPENDENT CONFIRMATION** (longer run, n=6868): DESCENT 🟢 / util 🔴 RED (PEAK 35% MEAN 0.4879%) — corroborates #2542 lever-4 verdict

Independent re-fire of lever-3 on a FRESH single-GPU pod, corroborating the #2542
closure with a much longer, finer-grained measurement. #2542 ran the short config
(E=4 ep=3 nwin=8, 0.5s sampler, **n=349** PEAK 21% MEAN 0.5616%) on the adopted
8-GPU candidate 38996679; this run uses a clean **single-GPU** H100 sm_90
(`num_gpus=1`, `CUDA_VISIBLE_DEVICES=0`) pod 39126604, the longer config
(E=2 ep=2 nwin=32, 0.1s sampler → **n=6868**, 19× more samples).

- **rented** fresh `H100_SXM num_gpus=1` (pod 39126604, after the adopted 38996679
  died on a vast transport outage mid fire-launch). protected pods untouched.
- **build path** (proven, scripted all-in-one, nohup fire survives SSH drop): clone
  `lane-g/rfc046-lever3-batched-gemmfeed` `a5d01f37f` → spliced `self/runtime.c`
  (levers a+b+2+3, byte-eq DELEGATE fix) → `tool/stage_build_hexa` (cuda_link_decision
  baked=1) → **symlink `hexa`→`hexa_fresh` on PATH** (the emit sub-proc resolves `hexa`
  via PATH — the silent-CPU-fallback trap if missing) → pre-emit `runtime_cuda.c`
  (bt/atb/batched kernels + `_d2h_out`/`_ensure_dev_alloc_out` fwd-decls) →
  `HEXA_CUDA_LINK=1 HEXA_CUDA_ARCH=90` build → `-lcuda` relink.
- **3-GATE PASS** (g5): CUDA link ENGAGED=1 · `nvcc -x cu` EXIT 0 (660952B .90.o, 0 err)
  · `clm_prod` ldd 4 cuda libs (cublas+cudart+**libcuda.so.1**+cublasLt) + 10 lever syms.
- **byte-eq ALL PASS** (g5, max|Δ|=0.0): `F-RFC046-GEMMFEED-EQ`=1 · `F-RFC046-BATCHED-GEMMFEED-EQ`=1
  · `F-CLM-DEVFEED-*` ALL-PASS (dX 5.55e-17 ULP) · `F-CLM-CONV2-BATCHED-*` ALL-PASS.
- **util fire** (CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1, d1536/T512, c4 5-lang 402270B):
  - **DESCENT 🟢 GREEN**: `epoch-1 mean CE = 4.05535` → `epoch-2 mean CE = 3.45564`,
    `F-CLM-PROD-DESCENT = 1` (g5 verbatim).
  - **util 🔴 RED**: `n=6868 PEAK=35% MEAN=0.4879% busy_mean=5.3445% pct≥20%=0.1019%`
    (GPU0, 0.1s, g5 verbatim). forge live on GPU (115W vs 70W idle).
- **two-pod cross-check (decisive)**: #2542 (n=349) MEAN 0.5616% · this (n=6868) MEAN
  0.4879%. Across two pods + two configs, lever-3 MEAN util is **flat ~0.5%** (lever-1
  0.811% → lever-2 0.4999% → lever-3 0.49–0.56%). PEAK rose (19→21→35%) but MEAN did
  not — **confirms** the device-feed lever chain (a+b+2+3) is necessary-but-insufficient
  and the residual is the **interpreted per-step DRIVER LOOP** (F-RFC046 root: ~30
  host↔device crossings/step incl 20× separate AdamW; busy_mean 5.34% ⇒ GPU ~95% idle),
  NOT the GEMM-feed/link/kernel/emit/scale (all ruled out). → **lever-4** (fused
  on-device per-step driver) is the real unblock.
- **closure**: util RED → closure-FAIL → **.clm PRIVATE** `dancinlab/clm-v1-dev-d1536-lever3-util-probe`
  (a_hf_autonomous). recover-before-teardown DONE (.clm 14379581B sha256 `06e2dcf4…`
  pull+verify + HF.jsonl substrate=GPU + CLM collection + marker verified → pod 39126604
  destroyed, confirmed). PUBLIC HF / 3B / 7B still gated. inbox handoff:
  `inbox/patches/forge-rfc046-lever3-util-residual-lever4-driver-loop.md`. g5 verbatim · 날조 0.

## 2026-06-02T19:05Z — Lane-G (substrate=GPU · mac CPU-local `hexa run` $0 · a_lane_akida_gpu_split — NEVER merged with AKIDA) — lever-3 batched GEMM-feed **byte-eq GREEN** (max|Δ|=0.0), util fire HELD; lever-2 RED → lever-3 unblock 65% batched repack 확정

lever-3 (batched transpose-aware GEMM-feed) **소스 byte-eq-GREEN-ready**. 체크포인트 `62139159a`
가 batched `bt/atb` 빌트인(runtime.h decl + codegen 8-arg lowering + runtime_cuda_emit GPU 커널
`cublasDgemmStridedBatched` OP_T + clm_prod 배치경로 라우팅 + 오라클)을 올렸으나 no-CUDA 호스트
fallback drift 로 HARD gate FAIL 이었다 — 본 세션이 진단·교정·재그린·랜딩.

- **fire-confirmed rationale (lever-2 RED → lever-3 unblock)**: pod vast 39082940 lever-2 fire =
  DESCENT 🟢 (CE 0.818097→0.0591666) / util 🔴 RED (**PEAK 19% MEAN 0.4999% n=147863**, byte-eq
  PRESERVED). lever-2 는 un-batched conv(profile 31.2%)만 device 化 → DOMINANT **65% batched
  `conv2_*_via_forge_batched` host repack** 미접촉. lever-3 가 그 repack(b_all Wt-pack · a_all xcol
  복제 · dW_flat unpack)을 strided-batched op-flag GEMM + strideA=0 broadcast 로 DROP.

- **ROOT CAUSE (drift)**: `hexa run` 은 `~/.hexa-cache` 에 SOURCE-hash 로 컴파일 바이너리를 캐시 →
  stale 캐시가 진짜 byte-eq 상태를 가렸다. 캐시 bust 후 drift 노출: BATCHED-BT 2.84e-14,
  lever-2 GEMMFEED-BT 1.42e-14 (둘 다 open-coded ijk dot vs `hexa_farr_matmul` ikj UNROLL/FMA).

- **FIX**: lever-2 `_bt/_atb` + lever-3 batched `_bt/_atb` no-CUDA fallback 4종을 오라클 레퍼런스와
  동일한 호스트 transpose 후 `hexa_farr_matmul` 위임으로 재작성 → 구성상 bit-identical. CUDA
  `#ifdef`(cuBLAS OP_T) 불변. self/runtime.c gitignore → SSOT = inbox 프래그먼트(lever3 갱신 +
  lever2 byteeq-fix 신설).

- **byte-eq GREEN (mac `hexa run`, $0, g5 verbatim → `.verdicts/forge-utilgreen-lever3/`)**:
  ```
  F-RFC046-BATCHED-GEMMFEED-EQ = 1   BT 0.0 · ATB 0.0 · BT(per-problem) 0.0
  F-RFC046-GEMMFEED-EQ         = 1   BT 0.0 · ATB 0.0           (lever-2 재그린)
  F-CLM-DEVFEED-{IM2COL,FWD,BWD,ADAM}-EQ = 1 (ALL-PASS)
  F-CLM-CONV2-BATCHED-{FWD,BWD}-EQ        = 1 (ALL-PASS)
  ```

- **랜딩**: PR **#2528** (squash, `--base lane-g/rfc046-lever2-gemmfeed` stacked) MERGED.

- **util≥20% = HELD pod fire** — 소스에서 주장 안 함 (a_scale_honest_scope). 별도 free pod 가
  lever-3 적용 트레이너로 single-driver H100 fire 를 돌려 verdict 확정. **lever-4 forward-design**
  = `inbox/patches/forge-devfeed-lever4-fused-step-driver-DESIGN.md` (fused on-device per-step
  driver — F-RFC046 root residual: glue ~3.8% + 인터프리트 per-step 드라이버 루프 + 20×분리 AdamW;
  投影 ~30→~2 host boundary crossings/step; 오라클 `F-RFC046-FUSED-STEP-EQ`).

## 2026-06-02T18:30Z — Lane-G (substrate=GPU · pod vast 39082940 · a_lane_akida_gpu_split — NEVER merged with AKIDA) — lever-2 util-verify fire CLOSED: DESCENT 🟢 GREEN / util 🔴 RED (PEAK 19% MEAN 0.4999% n=147863), lever-2 byte-eq PRESERVED, lever-3 (batched bt/atb) confirmed as the real unblock

lever-2 transpose-aware GEMM(bt/atb) util-verify fire **완주·CLOSED** (직전 드라이버는 closure
직전 서버 rate-limit 으로 종료 → 본 세션이 backoff·inline·sole-driver 로 마감). branch
`lane-g/rfc046-lever2-gemmfeed` `403735b29`, config d=1536 E=2 epochs=6 nwin=32, corpus 402270B V=256.

- **DESCENT 🟢 PASS** (g5 verbatim):
  ```
  epoch-1 mean CE = 0.818097
  epoch-6 mean CE = 0.0591666
  config d=1536 E=2 epochs=6 nwin=32
  F-CLM-PROD-DESCENT = 1
  PASS — real-corpus mean CE descends under int4 envelope
  ```
- **util 🔴 RED** (g5 verbatim) — util-GREEN(≥20% MEAN ∧ descent GREEN) **NOT 도달**:
  ```
  util samples n=147863  PEAK=19%  MEAN=0.4999%  busy_n=21575  busy_mean=3.43%
  pct≥20% = 0
  ```
  MEAN 0.4999% ≪ 20%, PEAK 19% < 20%.
- **lever-2 byte-eq PRESERVED** (hard gate): `F-RFC046-GEMMFEED-EQ = 1` (bt/atb GPU 커널 == host-
  transposed forge, max|Δ|=0.0) + 기존 오라클 전부 max|Δ|=0.0 (DEVFEED-{IM2COL,FWD,BWD,ADAM}-EQ ·
  HOSTFEED-{FWD,BWD}-EQ). 드리프트 0, 가짜 GREEN 0.
- **KEY 발견** — **before(lever-1-only) MEAN 0.811% → after(lever-2) MEAN 0.4999%**: lever-2 는
  util 을 올리지 **못함**. lever-2 가 device 화한 것은 **un-batched conv 경로(profile 31.2%)** 뿐 —
  프로덕션 트레이너가 실제 도는 **DOMINANT 65% batched `conv2_*_via_forge_batched` host repack 은
  미접촉**. ⇒ **lever-3 (batched bt/atb)가 진짜 unblock** (DESIGN-AHEAD 박제됨, byte-eq pending).
  정직한 closed result: util<20% → closure-FAIL → PRIVATE.
- **ckpt** `lever2_d1536_t512.clm` 14379581 B (6 int4 blocks CLM\x01), sha256
  `407f1564d5b21bc3e896e503560a580934d276462d2ffc65b439b6e7b90865d1` (local==pod MATCH).
  recover-before-teardown 충족.
- **HF PRIVATE** (a_hf_autonomous: closure-FAIL/util-RED = PRIVATE · a_hf_complete: model card + sha256
  + manifest): `dancinlab/clm-v1-dev-d1536-lever2-util-probe` private=True (ckpt + README + SHA256SUMS +
  util_fire.csv + HARVEST.txt + fire_train.log + verify.out = 7 files, HF API 확인). FORGE 엔드게임의
  reserved PUBLIC `clm-v1-base-mirror-lane-g-forge`(미래 util-GREEN 용)와 별개의 dev-probe id. NOT
  PUBLIC-grade(util 게이트 미달). HF.jsonl row(substrate=GPU) `anima_clm_mid_d1536_t512_lever2_lane_g_2026_06_02`.
- **3B/7B 게이트 STILL throughput-blocked**: util-RED 지속 → 3B forge fire 는 throughput-justified
  아님(NOT-before-util-GREEN guard 유지). util-GREEN 은 lever-3 fire 의 verdict 에 달림.
- pod 39082940 teardown 완료(marker+HF 검증 후) · 보호 pod 무손상 · 재-rent 0. substrate=GPU,
  a_lane_akida_gpu_split (AKIDA 무병합) · 날조 0 · g5 verbatim.

## 2026-06-02 — 도메인 생성 (util-GREEN 엔드게임 시드)

flame+forge CLM 트레이너의 GPU util-GREEN 을 향한 엔드게임 lever 체인을 박제. 광범위 가속
백로그 [[FLAME-PERF]] 에서 갈라져 나온 **focused 슬라이스** — F-RFC046 host-feed 병목을
끝장내 util≥20% → PUBLIC-grade Lane-G → 3B → 7B 를 여는 것이 단일 목표.

오늘(2026-06-02)까지의 정직한 상태 (anima 세션에서 수행, 증거는 anima CLM+KOSMOS.log.md
+ hexa-lang PR/inbox):
- **5 빌드/링크/컴파일/emit 버그 수정·머지** → GPU 빌드 완전 작동, GPU 실측 live(87W·GB device mem).
  #1 CUDA-링크 main 누락 · #2 커널 전방선언(#2506) · #3a fork-bomb(27535d93d) · #3b emit-truncate
  (bb10154fb, write_file 빌트인) · 양 lever #2504/#2505.
- **신뢰가능 util 측정**: 🔴 RED mean 0.811%·peak 6%·n=987 @ d1536/T512 (양 lever active despite).
  descent 🟢 GREEN(F-CLM-PROD-DESCENT=1, CE 4.88733→4.87688).
- **원인 확정 = F-RFC046 host per-step 오케스트레이션**(profile: 104M op·1.39s/step CPU 1코어
  >> sub-ms GPU GEMM). lever a+b = 필요했으나 불충분. inbox fe2e43a35.
- **lever-1 SHIPPED** (PR #2515): expert im2col gather → device(`_clmp_im2col`), 65% host 항 제거,
  byte-eq max|Δ|=0.0. 단 lever-1 만으론 util<20%(잔여 ~36M op·0.49s/step).
- **lever-2 진행중** (agent a195b3eb · drafts/rfc046-gemmfeed-plan.md): device GEMM-feed repack /
  transpose-aware GEMM(cuBLAS CUBLAS_OP_T + a/b/c·dW device 스테이징) — 잔여 14.16M-op repack 제거.
  깨끗한 single-driver H100 sm_90 1회에서 빌드+byte-eq+util-verify fire 합쳐 결판.

다음 세션 시작점: agent a195b3eb 의 lever-2 결과 확인 → util≥20% 면 PUBLIC HF + 3B; 여전 RED 면
정밀 진단된 다음 잔여 병목을 이 로그에 추가하고 차기 lever 로. 측정 교훈(H100 sm_90·충돌0·하네스X
·inline·backoff·rent-cap)은 FORGE-UTILGREEN.md 하단 참조. 날조 0 · g5 verbatim · a_scale_honest_scope.

## 2026-06-02 (cont.) — lever-2 SOURCE landed; verify fire HELD (throttle)

lever-2 transpose-aware GEMM(bt/atb) 소스 **커밋·푸시 완료** — `403735b29`
(branch `lane-g/rfc046-lever2-gemmfeed`): 호스트 Wt/dW repack 을 device 로 (cuBLAS
CUBLAS_OP_T + `_hx_cuda_farr_matmul_bt_gpu`/`_atb_gpu` 커널). 작업 worktree
`/private/tmp/laneg/lever2`. agent(a195b3eb)는 그 직후 **서버 throttle(rate-limit)로 종료**
— pod byte-eq + util-verify fire 는 **미실행**.

남은 단 한 단계 = **깨끗한 single-driver pod verify**(throttle 풀린 뒤 go): branch
`lane-g/rfc046-lever2-gemmfeed` self-host 빌드 → 3중게이트 → pod byte-eq(F-RFC046-GEMMFEED-EQ
+ 기존 max|Δ|=0.0) → CLM_PROD_DEVFEED+CLM_PROD_BATCHED util fire @ d1536/T512. SUCCESS = util≥20%
AND descent GREEN. 교훈: H100 sm_90 · 단일드라이버 · 하네스X · inline · rent-cap. before=0.811%.

좀비 a9b8016a 는 same throttle 로 마침내 종료(재-rent 시도 중 죽음). 중복 pod 39075752
(laneg-utilgreen2) teardown 필요.

## 2026-06-02 (cont.) — pod-INDEPENDENT endgame prep STAGED (live fire untouched)

lever-2 verify fire 가 pod 39082940 에서 in-flight 인 동안, pod-독립 엔드게임 4축을
모두 전진(라이브 fire / pod 무접촉):
- **HF PUBLIC closure readiness** (`inbox/patches/forge-utilgreen-hf-public-closure-readiness.md`):
  repo_id `dancinlab/clm-v1-base-mirror-lane-g-forge` (mk2 §2.1 EBNF: clm·v1·base-mirror·
  lane-g-forge variant — Lane A⊥G 분리를 NAME 에 박제) + model-card 5섹션 템플릿(GPU·forge+flame,
  fire 로그 `{FILL}`) + HF.jsonl row schema(substrate=GPU/lane=Lane-G) + dancinlab CLM 컬렉션 plan.
  업로드 NO (fire run 소유, a_hf_autonomous).
- **lever-3 DESIGN-AHEAD** (`inbox/patches/forge-rfc046-lever3-batched-expert-repack.md`):
  committed profile 정독 → lever-2 가 처리한 건 un-batched 4conv(31.2% 항)뿐, 프로덕션이 실제
  도는 batched 2-expert 경로(`conv2_*_via_forge_batched` = **65% DOMINANT** 항)의 host repack
  (b_all Wt-pack·a_all 복제·c_all/dW unpack)은 잔존. lever-3 = strided-batched transpose-aware
  GEMM(`forge_dispatch_matmul_batched_{bt,atb}` + xcol strideA=0 broadcast)로 device 화 →
  host op 을 glue floor 로. byte-eq oracle = F-RFC046-BATCHED-GEMMFEED-EQ. self/runtime.c+cuda
  시그니처 = pod 빌드 필요 → DESIGN DOC only(라이브 fire 와 무경쟁). util≥20% 는 fire verdict.
- **3B throughput-justification 게이트**: FORGE-UTILGREEN.md 에 NOT-before-util-GREEN guard +
  util-GREEN(≥20% MEAN)∧descent-GREEN AND-게이트 + ≥3 rung ladder(d1536→~d2048→3B) 명문화.
- **도메인 hygiene**: lever-2/util-verify 는 fire agent 소유라 미변경(✅ 안 찍음). lever-3 는
  DESIGN-AHEAD 로 별 milestone 추가.

라이브 fire / pod 39082940 / 보호 pod(38704336/38996679/39070097) 전부 무접촉. 재-rent 0.
substrate=GPU, a_lane_akida_gpu_split (AKIDA 무병합).

## 2026-06-02 (cont.) — lever-3 util-verify fire CLOSED: DESCENT 🟢 / util 🔴 RED (lever-4 = real unblock)

lever-3 batched GEMM-feed 의 **util≥20% pod fire** 를 깨끗한 single-driver H100 sm_90 에서 완주
(HELD 해제). substrate=GPU (Lane-G), AKIDA 무병합 (a_lane_akida_gpu_split).

- **pod**: adopted 38996679 (@anima-cudafix · vast ssh7 · 8×H100 80GB HBM3 compute_cap 9.0 · 충돌0 ·
  rent 0 — 기존 보호 아닌 idle candidate 입양). 보호 pod(38704336/39106252/39115197) 무접촉.
- **3-gate PASS** (no CPU fire): ① CUDA-link ENGAGED — cached clm_prod 바이너리(`hexa_run.92a5798d…`)에
  `_hx_cuda_farr_matmul_bt_gpu`/`_atb_gpu` + `cublasDgemmStridedBatched` 심볼 링크. ② `nvcc -x cu -arch=sm_90`
  EXIT 0 + runtime_cuda.90.o(564K)에 cublas* undef + bt/atb 정의. ③ `ldd clm_prod` → libcublas.so.12 ·
  libcudart.so.12 · libcuda.so.1 · libcublasLt.so.12.
- **pod byte-eq (g5 verbatim, /root/byteeq.log)**: `F-RFC046-GEMMFEED-EQ=1` (BT/ATB max|Δ|=0.0) ·
  `F-RFC046-BATCHED-GEMMFEED-EQ=1` (BT/ATB/per-problem max|Δ|=0.0) · `F-CLM-DEVFEED-{IM2COL,FWD,BWD,ADAM}-EQ=1` ·
  `F-CLM-CONV2-BATCHED-{FWD,BWD}-EQ=1`. 전 오라클 max|Δ|=0.0 → byte-eq hard gate PASS, 드리프트 0.
- **util fire** (CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 d=1536 T=512 E=4 epochs=3 nwin=8, GPU0 핀,
  nvidia-smi 0.5s 샘플러): RUN_RC=0, .clm 14381125B 6blocks CLM\x01.
  - **DESCENT 🟢 GREEN**: `epoch-1 mean CE = 4.2974` → `epoch-3 mean CE = 3.79897`, `F-CLM-PROD-DESCENT = 1`,
    `PASS — real-corpus mean CE descends under int4 envelope` (g5 verbatim).
  - **util 🔴 RED**: `n=349 PEAK=21.0% MEAN=0.5616% busy_n=339 busy_mean=0.5782% pct≥20=2 mem_max=6331MiB`
    (GPU0, g5 verbatim). GPU 는 device-resident (6.3GB · 119W power)이나 SM-starve.
- **결정적 발견**: before(lever-2)=0.4999% → after(lever-3)=0.5616% — **lever-3 도 MEAN util 을 못 올렸다**.
  lever-3 가 batched 65% host repack 을 device 化한 것은 byte-eq GREEN 으로 증명되었지만, MEAN util 은 flat.
  ⇒ 잔여 지배 병목은 GEMM repack 이 아니라 **인터프리트 per-step 드라이버 루프(F-RFC046 root)**: step body 가
  ~30 분리 빌트인 콜(fwd·ce·ce-grad·bwd·20×분리 _adam)을 인터프리트로 디스패치 → 커널 사이 GPU idle.
  device 메모리는 차고 power 도 흐르나(allocated+launched) SM occupancy 가 launch 간극에 죽는다.
- **closure**: util RED → closure-FAIL → **.clm PRIVATE** (a_hf_autonomous). PUBLIC HF / 3B / 7B 는 still gated
  (util-GREEN NOT-before guard 유지). 아티팩트 회수 완료(recover-before — anima `state/laneg-lever3-utilfire/`:
  .clm sha256 `34982a31…20a6f7a` byte-verified + utilfire_run.out + util_samples.csv(349) + byteeq.log).
  pod 38996679 = adopted candidate, rent 0 — teardown 의무 없음(입양, 보호 pod 아님), idle 로 유지.
- **next bottleneck = lever-4 (fused on-device per-step driver)** — `forge_dispatch_train_step` 단일 fused
  빌트인(device-resident param/grad/moment, fwd→loss→bwd→AdamW 전부 device, host 로 scalar loss 만) +
  `forge_dispatch_adamw_group`(20 텐서 1 launch). 投影 ~30→~2 host boundary crossings/step. 시그니처 변경 =
  pod self-host 빌드 필요 → DESIGN DOC + 차기 fire. 오라클 `F-RFC046-FUSED-STEP-EQ` + `F-RFC046-ADAMW-GROUP-EQ`
  max|Δ|=0.0. inbox/patches 에 root-residual 분해 + lever-4 설계 기록.

다음 세션 시작점: lever-4 (fused step driver) 소스 구현 → 깨끗한 H100 sm_90 self-host 빌드 → 3-gate →
pod byte-eq(F-RFC046-FUSED-STEP-EQ 추가) → util fire. before=0.5616%. 날조 0 · g5 verbatim · a_scale_honest_scope.

## 2026-06-02 — lever-4 fused AdamW group fire CLOSED + lever-5 workload-bound SWEEP (TERMINAL)
substrate = GPU (Lane G) · pod vast 39139563 (H100 80GB HBM3, sm_90 / compute_cap 9.0, ssh4.vast.ai) · REUSED (no re-rent).

### lever-4 (fused AdamW group) — 3-GATE + BYTEEQ + util fire
- 3-GATE PASS: GATE1 CUDA link ENGAGED=1 · GATE2 nvcc -x cu sm_90 EXIT 0 obj=664048B err=0 · GATE3 clm_prod ldd 4 cuda libs (libcublas/libcudart/libcuda.so.1/libcublasLt) + adamw_group symbol.
- BYTEEQ-PASS (g5 verbatim, host oracles + ON-DEVICE HEXA_CUDA): clm_gemmfeed_eq · clm_batched_gemmfeed_eq · clm_conv_devfeed · clm_conv_batched · clm_fused_step_eq — incl on-device `F-RFC046-FUSED-STEP-EQ=1` + `F-RFC046-ADAMW-GROUP-EQ=1`, all max|Δ|=0.0.
- DESCENT 🟢 GREEN: CE 4.05535 → 2.99508, F-CLM-PROD-DESCENT=1.
- util 🔴 RED (g5 verbatim): `UTIL n=9153 PEAK=41% MEAN=0.6630% busy_ge20=80 pct_ge20=0.87%`.
- ckpt `.verdicts/lane-g-lever4/clm_lever4_d1536_t512.clm`. HF PRIVATE (closure-FAIL).
- 17 host crossings 제거(adamw_group)했어도 MEAN flat(0.4879→0.6630%), PEAK 상승(35→41%) ⇒ crossing-count ≠ MEAN binding constraint.

### lever-5 (workload-bound disambiguation SWEEP) — A vs B
방법: lever-4 byte-identical clm_prod 으로 apples(d1536/T512=lever-4 정확 config) + 3 LARGER config. nvidia-smi util@0.1s · devmem@0.5s · descent per config. CLM_PROD_DEVFEED=1 BATCHED=1 HEXA_CUDA_LINK=1. 전 config FIRE_RC=0.

util (g5 verbatim, /root/lever5_sweep.log → .verdicts/lane-g-lever5/):
```
UTIL[apples] n=9149  PEAK=38% MEAN=0.6619% busy_ge20=81  pct_ge20=0.89% pct_ge50=0.00%  DEVMEM 20447MiB
UTIL[d3072]  n=11441 PEAK=78% MEAN=0.7152% busy_ge20=125 pct_ge20=1.09% pct_ge50=0.39%  DEVMEM 26405MiB
UTIL[t1024]  n=5892  PEAK=38% MEAN=0.5883% busy_ge20=35  pct_ge20=0.59% pct_ge50=0.00%  DEVMEM 15097MiB
UTIL[big]    n=8931  PEAK=75% MEAN=0.6838% busy_ge20=87  pct_ge20=0.97% pct_ge50=0.32%  DEVMEM 23215MiB
```
descent (전 config 🟢 GREEN, F-CLM-PROD-DESCENT=1): apples 4.05535→2.99508 · d3072 4.48673→3.96246 · t1024 4.20807→3.36669 · big 4.60325→4.22859.

apples-to-apples: lever-4 PEAK41%/MEAN0.6630% vs lever-5 apples PEAK38%/MEAN0.6619% — 샘플링 노이즈 내 재현 (byte-identical build). harness sound.

### A-vs-B RULING = (B) WORKLOAD-BOUND · host-feed axis CLOSED-NEGATIVE
- 8× per-step work sweep 에서 PEAK 38→78% 배증, MEAN 0.59-0.72% PINNED. bigger work 가 MEAN 못 올림.
- (A) crossing-bound 배제: d3072 는 crossing 개수 = apples 와 동일, crossing 당 device compute ~4×. fixed-count launch latency 가 binding 이었으면 MEAN 상승했어야. 안 올랐음(+0.05pp). PEAK 78% = 커널이 SM 더 점유하나 GPU wall-time ~99.3% idle.
- root residual = 인터프리트 host per-step 드라이버 루프 wall-time (hexa scalar fwd/CE/bwd ~13ns/op · ~104M op/step @ d1536 ≈ ~1.4s/step · model 크기 비례 → d3072 host gap 도 ~4× → busy fraction flat). 잔여 ~11 crossing = constraint 아님, 인터프리터 = constraint.
- lever curve (MEAN flat · PEAK monotone = workload-bound 시그니처): l1 0.811%/6% → l2 0.4999%/19% → l3 0.4879%/35% → l4 0.6630%/41% → l5 0.59-0.72%/up to 78%.

### VERDICT = HONEST TERMINAL of host-feed util lever chain
util-GREEN(MEAN≥20%∧PEAK≥20%) 어떤 config 에서도 미도달, MEAN 천장 ~0.72%. host-feed/crossing-count axis CLOSED-NEGATIVE — 추가 host-feed lever 로 MEAN 불가. 治: (i) 전체 device-resident model port (fwd+CE+bwd 그래프 CUDA C 재작성 — feed lever 아닌 production model rewrite) 또는 (ii) d3072/T1024 훨씬 너머의 production scale. a_scale_honest_scope: d1536 MEAN-util = workload-size + interpreter-wall artifact 이지 forge 결함 아님 (forge provably device-resident 20-26GB · PEAK 78% · byte-eq PRESERVED · descent GREEN 전 config).

Lane G PUBLIC milestone NOT 도달 (util-GREEN 미달) — workload-bound terminal note 유지. 3B/7B chain = util-GREEN gate 미통과로 BLOCKED 유지 (production-scale device-port 가 진짜 unblock).
pod 39139563 RUNNING 유지 (sweep, no teardown). 날조 0 · g5 verbatim.

## 2026-06-03 — option-B device-port track recorded + anima campaign pivot (decision A)

lever-5 가 host-feed lever 체인을 HONEST TERMINAL 로 닫은 뒤, 이 도메인에 **진짜 util-GREEN 의 유일 트랙 = option-B (device-resident model port)** 를 명시 milestone 으로 기록. cure = full CLMConvMoE train step(fwd→CE→bwd→AdamW)을 ONE device-resident CUDA-C graph 로 재작성해 hexa 인터프리터를 per-step hot path 에서 완전 제거 (production model rewrite, feed lever 아님; lever 체인을 extend 가 아니라 supersede). oracle target = whole train-step byte-eq (max|Δ|=0.0, `F-RFC046-FUSED-STEP-EQ` 위에 빌드) → util≥20% MEAN fire verdict. alt(ii) = production scale ≫ d3072/T1024 (8× sweep 도 미도달 → option-(i) 가 PRIMARY).

**anima campaign pivot (decision A · 2026-06-03)**: anima ENGINE+CLM+KOSMOS 캠페인은 7B 목표를 forge util-GREEN 에서 DECOUPLE — descent 축으로 3B→7B 진행 (forge 가 low-util 에서 descent-GREEN .clm 생산, util-RED/NOT throughput-justified 정직표기). NOT-before guard 불변: descent-axis .clm 은 util-RED·not-throughput-justified 로 honest scope. 이 도메인의 **util-GREEN throughput-justified** production 경로(PUBLIC-grade / 3B / 7B milestone)는 option-B device-port 에만 gated — 그것만이 해당 milestone 들을 flip.

lever-5 apples ckpt → HF PRIVATE `dancinlab/clm-v1-dev-d1536-lever5-util-probe` 업로드 완료 (모델카드+MANIFEST, private=true·4파일·sha 11ef9300… 검증, anima HF.jsonl status=uploaded · PR #1715). 날조 0 · g5 verbatim.
