# FORGE-UTILGREEN — append-only step log

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
