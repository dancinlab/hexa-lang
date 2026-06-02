# FORGE-UTILGREEN — current state

@title: 🟢⚡ FORGE-UTILGREEN — flame+forge CLM 트레이너 GPU util-GREEN 엔드게임

@goal: flame+forge CLM 트레이너(stdlib/flame · clm_prod)의 GPU 가동률을 **util-GREEN(nvidia-smi util ≥20% AND descent GREEN)** 으로 끌어올려 **PUBLIC-grade Lane-G → 3B → 7B** 를 연다. 핵심 falsifier = `F-RFC046-GPU-UTILIZATION`(util≥20% @ mid d~1536/T~512). 측정은 깨끗한 single-driver pod(H100 sm_90·충돌0·하네스X·inline) 1회로, byte-eq(F-CLM-DEVFEED-*-EQ + 신규 게이트 max|Δ|=0.0) 보존을 hard gate 로 둔다. 광범위 가속 백로그는 [[FLAME-PERF]] 공유 — 이 도메인은 그 중 **util-GREEN 엔드게임 lever 체인**에 집중.

## 전제 — 현재 위치 (2026-06-02, 정직)

오늘의 깨끗한 H100 fire 로 **GPU 빌드가 완전 작동**(GPU 실측 live: 87W · GB-scale device memory)했고 util 측정이 **신뢰 가능**해졌다 — 5개 빌드/링크/컴파일/emit 버그를 다 잡은 뒤. 측정 결과 util 🔴 RED(mean 0.811%·peak 6%·n=987 @ d1536/T512) **despite 양 device-feed lever(a #2505 · b #2504)** — lever 는 필요했으나 불충분. descent 🟢 GREEN. 진짜 병목은 **host per-step 오케스트레이션(F-RFC046)**: 인터프리티드 드라이버가 CPU 1코어를 ~1.39s/step 점유 → GPU SM-starve. 링크/커널/emit/스케일 아님(전부 closed).

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
- [ ] **lever-2: device GEMM-feed repack / transpose-aware GEMM** — 잔여 지배항(host Wt-transpose 4conv ×2 way · a/b/c pack/unpack · dW unpack = 14.16M-op) 을 device 로. cuBLAS 네이티브 transA/transB(CUBLAS_OP_T)로 호스트 전치 제거 + a/b/c·dW device 스테이징. self/runtime.c + cuda 시그니처 + flame 라우팅 = pod self-host 빌드 필요(mac byte-eq 불가). **진행중 (drafts/rfc046-gemmfeed-plan.md · agent a195b3eb)**. falsifier: F-RFC046-GEMMFEED-EQ max|Δ|=0.0 ∧ util≥20%.
- [ ] **util-verify fire (F-RFC046-GPU-UTILIZATION)** — 깨끗한 single-driver H100 sm_90 1회: 3중검증 → pod byte-eq → CLM_PROD_DEVFEED+CLM_PROD_BATCHED fire @ d1536/T512. SUCCESS = util≥20% AND descent GREEN(nvidia-smi PEAK/MEAN verbatim). before=0.811%.
- [ ] **lever-3 (DESIGN-AHEAD): 배치-expert GEMM-feed repack → device** — lever-2 는 **un-batched** 경로(`conv1d_via_forge` 4conv = profile 31.2% 항)만 transpose-aware GEMM(`_bt`/`_atb`)로 처리. 프로덕션 트레이너가 실제로 도는 **batched** 경로(`conv2_*_via_forge_batched` 2-expert = profile **65% DOMINANT 항**)의 host repack(`b_all` Wt-pack · `a_all` xcol 복제 · `c_all`/`dW_flat_all` unpack)은 그대로 host. lever-3 = 그 배치 경로를 strided-batched transpose-aware GEMM(`forge_dispatch_matmul_batched_{bt,atb}` + xcol strideA=0 broadcast)로 → host op 을 glue floor(~3.9M op)로. self/runtime.c+cuda+codegen 시그니처 변경 = pod self-host 빌드 필요(mac byte-eq 불가) → **DESIGN DOC only this pass** (`inbox/patches/forge-rfc046-lever3-batched-expert-repack.md`). falsifier: F-RFC046-BATCHED-GEMMFEED-EQ max|Δ|=0.0. util≥20% 는 fire 의 verdict(소스 단독 주장 금지, a_scale_honest_scope). **DESIGN-AHEAD — live RED 진단은 fire agent 소유; 본 항목은 forward lever 設計.**

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
