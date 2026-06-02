# FORGE-UTILGREEN — append-only step log

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
