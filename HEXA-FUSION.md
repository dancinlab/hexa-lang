# HEXA-FUSION — current state

@goal: clm_prod 학습 1-스텝의 GPU util-GREEN (MEAN ≥ 20%) — whole-program 융합으로
PyTorch+CUDA 수준을 MATCH(compute-bound) 하고, launch-bound 영역(glue·작은 op)에서
경계제거(launch + op-boundary fusion + compile-time 특화)로 EXCEED. (FORGE-UTILGREEN 계보)
rich SSOT = `domains/HEXA-FUSION.md` (tracked, on main).

## 완료 (코드 = 도메인 본질)

- **② async-launch pipeline codegen — 전량 main 머지** (#2619 fwd · #2621 GEMM · #2622
  bwd/opt 스트림정합 · #2624 bwd sync제거). async-on 시 학습 1스텝 전체(fwd 커널 +
  cuBLAS GEMM + bwd 커널 + optimizer)가 단일 `g_forge_stream` 에서 host-readback 경계만
  sync — W2 가 지목한 인터프리트 per-step 드라이버 병목의 해제 코드. async-off byte-identical.
- **forge wrapper 레이어** — main 완전체 (codegen 9 등록 + inbox 패치 9 정의 + runtime.h).
- **emit >128KB exec-heredoc E2BIG 버그픽스** — #2630 머지 (write_file).
- **W1** device-resident glue 6-lane (byte-eq max|Δ|=0) · **W2** util fire = CLOSED-NEGATIVE
  (device-resident glue 만으로 util RED 0.53% → per-op device화 축 결정적 배제).

## 측정 완료 (2026-06-04 — 빌드벽 SOLVED + ② CLOSED-NEGATIVE)

- **빌드인프라 벽 = 뚫림** (이전 "유지자/CI 에만 존재" 결론 번복): 신규 임대 CUDA pod
  (vast H100_NVL, idle, glibc 2.35, nvcc 12.4)에서 frozen-seed 번들(self/ 전체 트리)로
  clm_prod_gpu 빌드+학습 성공. 핵심 = **nvcc 에도 `-DHEXA_CUDA`**(runtime_cuda.c 전체가
  `#ifdef HEXA_CUDA` → 없으면 58 중 40 launcher 만 방출 → undefined ref) · `-lcuda`(driver
  API) · summer 선빌드 .o 는 `__isoc23_strtol`(glibc2.38+) 라 2.35 pod 에 비이식 → pod 재빌드.
  레시피 = memory `project_clmprod_gpu_build_seed_drift`.
- **util A/B (clean idle H100, baseline 0.00%) — verdict `.verdicts/hexa-fusion/F-FUSION-ASYNC-UTIL-AB.txt`**:
  · ASYNC=0 (per-op sync): util MEAN **12.50%** PEAK 100% · CE 4.47→3.65 · F-DESCENT=1 PASS ✓
  · ASYNC=1 (async pipe):  util MEAN **10.28%** PEAK 100% · CE 4.89→4.86 · DESCENT 형식상 PASS
- 🔴 **② async 레버 = CLOSED-NEGATIVE (2축)**: async 가 util 을 **안 올림 — 오히려 낮춤**
  (10.28%<12.50%, 둘 다 ≥20% 미달) + ASYNC=1 이 byte-eq 깨짐(CE 궤적 발산 → ②d sync제거 race).
  사전등록 falsifier "async 가 util MEAN≥20% 달성" = **FALSIFIED** (paper_negative_ok 해당).

## 리서치-주도 돌파 (이 도메인의 진행 방식 — research-led, NOT blind pool)

리서치(web+arxiv 1차출처 교차검증)가 측정을 정확히 설명 + 다음 레버를 확정:
- 측정 MEAN~10-12%+PEAK100% bursty = **launch-bound** 교과서 신호(host launch 2-10µs/커널 +
  인터프리터 per-op dispatch 가 임계경로). 단일-스트림 async 는 host 를 임계경로에서 **못 뺌**
  → util 무변 + sync제거 race (내 결과와 정확히 일치 — async 실패는 예상된 것).
- **canonical 해법 = ④ CUDA Graph 통째 캡처** (launch+dispatch 를 1회 `cudaGraphLaunch`≈10µs
  로 상각, host 를 임계경로에서 제거). PyTorch ~1.7× step (graphable 영역 ~5×).
- **int4 MoE 주의점**: 동적 expert 라우팅 → 전체-step 정적캡처 불가(Mirage MPK 도 동적 MoE 미지원).
  **piecewise graph** (dense/attn 캡처 + MoE dispatch 는 eager split + 라우팅 토큰을 capacity
  버킷에 패딩 = vLLM/SGLang `FULL_AND_PIECEWISE`). 조각마다 RUNEQ/byte-diff (graph replay 가
  순서 복원 → ②가 깬 byte-eq 를 구조적으로 회복).
- 출처: PyTorch CUDA Graphs blog · NVIDIA CUDA Graph best-practices · Mirage MPK
  arxiv:2512.22219 · SGLang piecewise · vLLM cuda_graphs design · XLA fusion arxiv:2301.13062.

## 마일스톤 사다리

- [x] W1 6-lane device-resident glue (byte-eq)
- [x] W2 util fire — CLOSED-NEGATIVE (per-op device화 배제)
- [x] ② async pipeline codegen 4슬라이스 (merged)
- [x] emit 버그픽스 (#2630) · 도메인 정직기록 (#2631)
- [x] **빌드벽 SOLVED — clm_prod_gpu 빌드+학습 on idle H100 (frozen-seed + -DHEXA_CUDA)**
- [x] **util A/B 측정 — ② async = CLOSED-NEGATIVE (12.50%→10.28%, byte-eq 깨짐)**
- [x] **리서치: launch-bound 진단 + ④ CUDA Graph(piecewise) = canonical 다음 레버 확정**
- [ ] ④ CUDA-graph piecewise 캡처/replay codegen (dense/attn 캡처 + MoE eager split + 토큰버킷)
- [ ] util-GREEN MEAN≥20% (④ 후 재측정)

## 새 세션 핸드오프 (next-session start — 그대로 이어가면 됨)

**현 위치**: 측정 인프라·정직측정·리서치 = 완료. 다음 = ④ CUDA Graph codegen (유일한 util-GREEN 경로).

**파일 위치 (file map)**:
- CUDA 빌드 킷 (로컬, repo 밖, durable): `~/hexa-fusion-cuda-kit/`
  · `README.md` = 레시피 3 gotcha + 결과표 · `rebuild.sh` = 신규 pod 원샷 재빌드
  · `work/clm_prod_gpu` (작동 바이너리) · `work/runtime_cuda.o` (`-DHEXA_CUDA` 빌드)
  · `fusion_build_sources.tgz` = 이식 소스번들(self/ 전체) · `work/{train_,util_,q_}*` 측정로그
- 검증값 (repo): `.verdicts/hexa-fusion/F-FUSION-ASYNC-UTIL-AB.txt` (A/B + sweep verbatim)
- 빌드 레시피 메모리: `project_clmprod_gpu_build_seed_drift` (SOLVED 헤더 = nvcc `-DHEXA_CUDA`·`-lcuda`·glibc)
- rich SSOT (tracked, main): `domains/HEXA-FUSION.md` — 이 working-copy(`HEXA-FUSION.md`)는 UNTRACKED.

**측정 재현 (필요시)**: 신규 H100 임대 (PR #2644 로 `--gpu H100` 수정됨) →
`scp ~/hexa-fusion-cuda-kit/{fusion_build_sources.tgz,rebuild.sh} pod:` → pod 에서 `bash rebuild.sh` →
`clm_prod_gpu` 재생. ⚠ summer 선빌드 .o 재사용 금지(glibc), nvcc 에 반드시 `-DHEXA_CUDA`.

**④ CUDA Graph 전략 (research-confirmed, 곧장 착수 가능)**:
1. `self/cuda/runtime_cuda_emit.hexa` 또는 codegen 에 stream-capture 경로 추가:
   `cudaStreamBeginCapture(g_forge_stream)` → train-step 커널 DAG → `cudaStreamEndCapture` →
   `cudaGraphInstantiate` (1회 warmup) → 이후 step 마다 `cudaGraphLaunch` (~10µs replay).
2. **int4 MoE 가 전체-step 정적캡처를 막음** (동적 expert 라우팅 → 가변 토큰수). →
   **piecewise**: dense/attn/optimizer 만 그래프 캡처, MoE dispatch 는 eager split,
   라우팅 토큰을 고정 capacity 버킷에 패딩(vLLM/SGLang `FULL_AND_PIECEWISE` 패턴).
3. env 게이트 `HEXA_CUDA_GRAPH` (async 처럼) → graph-off byte-identical 로 선랜딩.
4. 검증: 조각마다 device-vs-CPU byte-eq + CE-descent (② 가 깬 byte-eq 를 graph replay 가 순서복원).
5. 재측정: `rebuild.sh` 로 신규 pod 빌드 → A/B (GRAPH=0 vs 1) → util MEAN≥20% 게이트.
   기대: PyTorch CUDA Graph 사례 ~1.7× step (graphable 영역 ~5×) → 12.5% 에서 GREEN 권으로 상승.

**왜 ② 가 실패했나 (반복 금지)**: 단일-스트림 async 는 host 를 임계경로에서 못 뺌 → util 무변/악화
+ per-op sync 제거가 race → byte-eq 깸. sizing 도 역효과(util 단조감소 12.71→2.94%). host 제거 = 그래프뿐.
