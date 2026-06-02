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

## ── 엔드게임 (util-GREEN 이후) ──
- [ ] **PUBLIC-grade Lane-G** — util-GREEN + descent → closure-PASS → HF PUBLIC(a_hf_autonomous) + dancinlab CLM 컬렉션 + HF.jsonl(substrate=GPU).
- [ ] **3B scale-up** — util-GREEN 으로 throughput-justified 후 3B 프로덕션 fire (a_scale_honest_scope: ≥3 rung ladder).
- [ ] **7B scale-up** — 3B green 후.

## 측정 잣대 · 교훈 (다음 fire 필수 적용)
- 깨끗한 single-driver pod: **H100 sm_90**(HEXA_CUDA_ARCH=90 정확, Blackwell sm_120 arch 불일치 회피) · agent 1개·충돌0("Killed"=agent cross-pkill, OOM 아님) · bespoke laneg_*.sh 하네스 금지(삭제됨) · inline 폴링(Monitor waiter 금지) · rate-limit backoff · rent-cap #2507 가 무한 rent 차단 · recover-before-teardown · 보호 pod 무손상.
- byte-eq 는 hard gate: 드리프트 시 revert, 절대 가짜 GREEN 금지(g5 verbatim).
