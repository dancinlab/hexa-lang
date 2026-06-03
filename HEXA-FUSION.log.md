# HEXA-FUSION — log

Append-only history sister of `HEXA-FUSION.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-04 — 빌드벽 SOLVED + ② async util A/B = CLOSED-NEGATIVE + research-led ④ 확정

- [x] 빌드인프라 벽 뚫림: 임대 idle H100_NVL pod 에서 frozen-seed 번들(self/ 전체) 빌드 성공.
      KEY = nvcc 에도 `-DHEXA_CUDA`(없으면 58→40 launcher 만), `-lcuda`, glibc2.35 pod 재빌드
      (summer .o 는 `__isoc23_strtol` 비이식). clm_prod_gpu 755184B, 학습 정상.
- [x] util A/B (clean idle H100, baseline 0.00%) — `.verdicts/hexa-fusion/F-FUSION-ASYNC-UTIL-AB.txt`:
      ASYNC=0 util MEAN 12.50% (CE 4.47→3.65 DESCENT PASS) · ASYNC=1 util MEAN 10.28% (CE 4.89→4.86).
- [x] ② async 레버 CLOSED-NEGATIVE: util 안 오름(오히려 ↓) + ASYNC=1 byte-eq 깨짐(②d sync제거 race).
      falsifier "async→util MEAN≥20%" FALSIFIED. 둘 다 ≥20% 미달.
- [x] research(web+arxiv): MEAN~10-12%+PEAK100% = launch-bound 진단. 단일-스트림 async 가 host 를
      임계경로에서 못 빼서 실패한 것(예상됨). canonical 해법 = ④ CUDA Graph 통째 캡처(launch+dispatch
      를 1회 ~10µs replay 로 상각). int4 MoE 동적라우팅 → piecewise graph + 토큰 capacity 버킷
      (vLLM/SGLang FULL_AND_PIECEWISE). graph replay 가 순서복원 → ②가 깬 byte-eq 회복.
- [x] upstream fix PR #2644: `hexa cloud rent --gpu H100` family→variant 별칭표(`gpu_name in [...]`).
- [ ] ④ CUDA-graph piecewise codegen 설계/구현 (다음 레버).
- [ ] ④ 후 util-GREEN MEAN≥20% 재측정.

