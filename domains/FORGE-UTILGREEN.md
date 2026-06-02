# FORGE-UTILGREEN — current state

@title: 🟢⚡ FORGE-UTILGREEN — flame+forge CLM 트레이너 GPU util-GREEN 엔드게임

@goal: flame+forge CLM 트레이너(stdlib/flame · clm_prod)의 GPU 가동률을 **util-GREEN(nvidia-smi util ≥20% AND descent GREEN)** 으로 끌어올려 **PUBLIC-grade Lane-G → 3B → 7B** 를 연다. 핵심 falsifier = `F-RFC046-GPU-UTILIZATION`(util≥20% @ mid d~1536/T~512). 측정은 깨끗한 single-driver pod(H100 sm_90·충돌0·하네스X·inline) 1회로, byte-eq(F-CLM-DEVFEED-*-EQ + 신규 게이트 max|Δ|=0.0) 보존을 hard gate 로 둔다. 광범위 가속 백로그는 [[FLAME-PERF]] 공유 — 이 도메인은 그 중 **util-GREEN 엔드게임 lever 체인**에 집중.

## 전제 — 현재 위치 (2026-06-02, 정직)

오늘의 깨끗한 GPU fire 로 **GPU 빌드가 완전 작동**(GPU 실측 live: 87W · GB-scale device memory)했고 util 측정이 **신뢰 가능**해졌다 — 5개 빌드/링크/컴파일/emit 버그를 다 잡은 뒤. **lever-2(transpose-aware GEMM bt/atb) util-verify fire 완주·CLOSED** (pod 39082940, d1536/T512): util 🔴 RED(**MEAN 0.4999%·PEAK 19%·n=147863** — byte-eq PRESERVED, F-RFC046-GEMMFEED-EQ=1 + 전 오라클 max|Δ|=0.0). descent 🟢 GREEN(CE 0.818097→0.0591666). **결정적 발견**: before(lever-1-only) 0.811% → after(lever-2) 0.4999% — lever-2 는 util 을 **못 올림**. lever-2 가 device 化한 건 **un-batched conv(profile 31.2%)** 뿐, 프로덕션이 실제 도는 **DOMINANT 65% batched `conv2_*_via_forge_batched` host repack 은 미접촉** → **lever-3 (batched bt/atb)가 진짜 unblock**. 진짜 병목 = **host per-step 오케스트레이션(F-RFC046)**: 인터프리티드 드라이버가 CPU 1코어 점유 → GPU SM-starve. 링크/커널/emit/스케일 아님(전부 closed). util-GREEN milestone = **아직 미달**(lever-3 fire verdict 대기) · PUBLIC-grade/3B = still gated.

```
util-GREEN 막던 것 (오늘 한 겹씩)        진짜 원인 (확정)
──────────────────────────           ─────────────────────
 #1 CUDA-링크 main 누락        →       host per-step 오케스트레이션 (F-RFC046)
 #2 커널 전방선언 (#2506)               인터프리터 드라이버가 CPU 1코어 점유
 #3a fork-bomb (27535d93d)             104M op·1.39s/step >> sub-ms GPU GEMM
 #3b emit truncate (bb10154fb)         → util ~0.8% (RED)
 (전부 수정·머지)                       lever a+b = 필요충분 아님
```

## ── util-GREEN lever 체인 (F-RFC046 host-feed) ──
- [x] **빌드/링크/컴파일/emit 5버그 수정** ✅ — CUDA-링크 main 누락 · 커널 전방선언(#2506 nvcc -x cu use-before-decl) · fork-bomb(27535d93d, nested hexa run 이 HEXA_CUDA_LINK 상속 → 무한 재귀) · emit-truncate(bb10154fb, 100KB runtime_cuda.c 를 exec heredoc 에 넣어 잘림 → write_file 빌트인) · 양 lever(#2504/#2505). → 3중 게이트 PASS · GPU 실측 live. 증거: 오늘 H100 fire, anima CLM+KOSMOS.log.md.
- [x] **util-RED 원인 확정 (F-RFC046)** ✅ — profile(104M 인터프리티드 스칼라-op × 13.4ns ≈ 1.39s host/step) → util 0.07~0.8% ⇒ fire(0.811%) 일치. 분해: expert 배치 host repack/im2col 65% · conv Wt-transpose+bias+db 31% · glue 4%. NOT link/kernel/emit/scale. inbox fe2e43a35.
- [x] **lever-1: expert im2col gather → device** ✅ (PR #2515) — 배치-expert 의 im2col/transpose-im2col 을 lever-a device helper(`_clmp_im2col`/`_t`)로 라우팅 → DEVFEED 하 device-resident → host hot-path 에서 65% 항 제거. byte-eq `F-RFC046-HOSTFEED-{FWD,BWD}-EQ=1 max|Δ|=0.0` + 기존 오라클 전부 0.0. **단 lever-1 만으론 util<20%**(잔여 ~36M op·~0.49s/step).
- [x] **lever-2: device GEMM-feed repack / transpose-aware GEMM** ✅ (소스 `403735b29` · byte-eq PRESERVED) — 잔여 지배항(host Wt-transpose 4conv ×2 way · a/b/c pack/unpack · dW unpack = 14.16M-op) 을 device 로. cuBLAS 네이티브 transA/transB(CUBLAS_OP_T)로 호스트 전치 제거 + a/b/c·dW device 스테이징. byte-eq `F-RFC046-GEMMFEED-EQ = 1` (bt/atb GPU 커널 == host-transposed forge, max|Δ|=0.0) + 기존 오라클 전부 max|Δ|=0.0 → **byte-eq hard gate PASS**. **단 lever-2 는 un-batched 경로(profile 31.2%)만 처리 → util 미상승**(아래 fire 참조).
- [x] **util-verify fire (F-RFC046-GPU-UTILIZATION) — 측정 완료, util 🔴 RED (정직한 closed result)** — pod vast 39082940 단일 드라이버 d1536/T512 E=2 epochs=6 nwin=32, corpus 402270B V=256. **DESCENT 🟢 GREEN** (CE 0.818097→0.0591666, F-CLM-PROD-DESCENT=1, g5 verbatim). **util 🔴 RED**: `n=147863 PEAK=19% MEAN=0.4999% busy_n=21575 busy_mean=3.43% pct≥20%=0` (g5 verbatim) — **util-GREEN NOT 도달**(MEAN 0.50% ≪ 20%, PEAK 19% < 20%). before(lever-1-only)=0.811% → after(lever-2)=0.4999% : lever-2 는 util 을 **올리지 못함**(un-batched 경로만 device 化, **DOMINANT 65% batched `conv2_*_via_forge_batched` host repack 미접촉**). ckpt sha256 `407f1564…b7e90865d1`, HF PRIVATE `dancinlab/clm-v1-dev-d1536-lever2-util-probe`(closure-FAIL→PRIVATE). **⇒ lever-3 (batched bt/atb)가 진짜 unblock.** util-GREEN milestone 은 **여전히 미달** — lever-3 fire 의 verdict 대기.
- [x] **lever-3: 배치-expert GEMM-feed repack → device 〔byte-eq-GREEN-ready · util fire HELD〕** ✅ — lever-2 는 **un-batched** 경로(`conv1d_via_forge` 4conv = profile 31.2% 항)만 transpose-aware GEMM(`_bt`/`_atb`)로 처리. 프로덕션 트레이너가 실제로 도는 **batched** 경로(`conv2_*_via_forge_batched` 2-expert = profile **65% DOMINANT 항**)의 host repack(`b_all` Wt-pack · `a_all` xcol 복제 · `c_all`/`dW_flat_all` unpack)을 lever-3 가 strided-batched transpose-aware GEMM(`forge_dispatch_matmul_batched_{bt,atb}` + xcol strideA=0 broadcast)로 → **host repack DROPPED**. **소스 LANDED** (PR #2528, stacked on lever-2): runtime.h decl + codegen 8-arg lowering + runtime_cuda_emit GPU 커널(`cublasDgemmStridedBatched` OP_T) + clm_prod 배치경로 라우팅 + inbox 프래그먼트 SSOT. **byte-eq GREEN (mac `hexa run`, $0, g5 verbatim → `.verdicts/forge-utilgreen-lever3/`)**: `F-RFC046-BATCHED-GEMMFEED-EQ = 1` (BT/ATB/per-problem **max|Δ|=0.0**) + 재그린 `F-RFC046-GEMMFEED-EQ=1` (lever-2 — open-coded ijk dot 의 ~1e-14 FMA-drift 노출·교정: 호스트 fallback 을 `hexa_farr_matmul` 위임으로 재작성 → bit-identical) + `F-CLM-DEVFEED-{IM2COL,FWD,BWD,ADAM}-EQ=1` + `F-CLM-CONV2-BATCHED-{FWD,BWD}-EQ=1`. **util≥20% 는 HELD pod fire — 소스 단독 주장 금지(a_scale_honest_scope)**, 별도 free pod 가 발사. 다음 lever 설계 = `inbox/patches/forge-devfeed-lever4-fused-step-driver-DESIGN.md` (fused on-device per-step driver — F-RFC046 root residual: glue ~3.8% + 인터프리트 per-step 드라이버 루프 + 20× 분리 AdamW; 投影 ~30→~2 host boundary crossings/step; 오라클 `F-RFC046-FUSED-STEP-EQ`).
- [ ] **lever-4 (DESIGN-AHEAD): fused on-device per-step driver — F-RFC046 root** — lever-3 까지가 GEMM repack 을 다 device 化했어도 잔여 = ① glue ~3.8% ② **인터프리트 per-step 드라이버 루프(F-RFC046 root)**: step body 가 ~30 개 분리 빌트인 콜(1×fwd·1×ce·1×ce-grad·1×bwd·**20×분리 `_adam`**)을 인터프리트로 디스패치 → 커널 사이 GPU idle. lever-4 = `forge_dispatch_train_step` 단일 fused 빌트인(device-resident param/grad/moment, fwd→loss→bwd→AdamW 전부 device, host 로는 scalar loss 만) + `forge_dispatch_adamw_group`(20 텐서 1 launch). 投影 ~30→~2 host boundary crossings/step. 시그니처 변경 = pod self-host 빌드 필요 → **DESIGN DOC only** (`inbox/patches/forge-devfeed-lever4-fused-step-driver-DESIGN.md`). 오라클 `F-RFC046-FUSED-STEP-EQ` + `F-RFC046-ADAMW-GROUP-EQ` max|Δ|=0.0. util≥20% 는 fire verdict.

## ── 3B throughput-justification 게이트 (a_scale_honest_scope) ──
3B 프로덕션 fire 는 **util-GREEN 이전에는 절대 발사 금지** (NOT-before-util-GREEN guard) — host-feed-bound 트레이너로 3B 를 발사하면 더 큰 d 가 device mem 만 더 점유하고 SM 은 더 idle(측정: d768→d1536 에서 util ~flat 5%→4-6%, residual=host-feed). 게이트 로직:

```
3B fire 자격 = util-GREEN(≥20% MEAN) ∧ descent-GREEN   (둘 다 필수, AND)
   util-GREEN  : nvidia-smi MEAN util ≥ 20% (PEAK 아님 — MEAN, verbatim)
   descent-GREEN: F-CLM-PROD-DESCENT=1 (CE epoch-1 > epoch-N)
            ↓ (둘 다 GREEN 일 때만)
3B = throughput-justified  →  ladder ≥3 rung 필수 (단일 point = INCOMPLETE)
   rung 1  d1536/T512  (util-GREEN 확인 스케일, the verify-fire 스케일)
   rung 2  ~d2048      (중간 — util 이 스케일에서 유지되는지 curve 점 2)
   rung 3  3B (d~2560+) (목표 — util≥20% 유지 시 throughput-justified 확정)
```

- **NOT-before guard**: util RED 인 채로 3B 발사 = a_scale_honest_scope 위반 (toy/mid-scale util-RED 을 prod 로 승격하는 것과 동형). util-GREEN 미달 시 3B 항목은 BLOCKED 로 유지.
- ladder 가 ≥3 rung 이어야 "3B 에서도 util≥20%" 가 측정-curve 로 입증됨 (한 점 = scale-transfer 미검증). scale-break 시 정직한 closed-negative (GPU fire autonomous, no cost gate — a_fire_autonomous).
- 7B 는 3B rung 이 util-GREEN 으로 throughput-justified 확정된 뒤에만.

## ── 엔드게임 (util-GREEN 이후) ──
- [ ] **PUBLIC-grade Lane-G** — util-GREEN + descent → closure-PASS → HF PUBLIC(a_hf_autonomous) + dancinlab CLM 컬렉션 + HF.jsonl(substrate=GPU). **STAGED**: repo_id `dancinlab/clm-v1-base-mirror-lane-g-forge` (mk2-spec conformant, `-util-probe` 미사용) + model-card 템플릿(forge+flame, GPU, fire 로그에서 `{FILL}` 채움) + HF.jsonl row schema + 컬렉션 plan = `inbox/patches/forge-utilgreen-hf-public-closure-readiness.md`. fire 가 util-GREEN 착지 시 PUBLIC 업로드 = 한 기계적 단계. **업로드는 fire run 소유 — 본 prep 은 업로드 안 함.**
- [ ] **3B scale-up** — util-GREEN 으로 throughput-justified 후 3B 프로덕션 fire (a_scale_honest_scope: ≥3 rung ladder).
- [ ] **7B scale-up** — 3B green 후.

## 측정 잣대 · 교훈 (다음 fire 필수 적용)
- 깨끗한 single-driver pod: **H100 sm_90**(HEXA_CUDA_ARCH=90 정확, Blackwell sm_120 arch 불일치 회피) · agent 1개·충돌0("Killed"=agent cross-pkill, OOM 아님) · bespoke laneg_*.sh 하네스 금지(삭제됨) · inline 폴링(Monitor waiter 금지) · rate-limit backoff · rent-cap #2507 가 무한 rent 차단 · recover-before-teardown · 보호 pod 무손상.
- byte-eq 는 hard gate: 드리프트 시 revert, 절대 가짜 GREEN 금지(g5 verbatim).
