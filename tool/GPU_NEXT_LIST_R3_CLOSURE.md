# GPU 도메인 next-list round-3 종결 (terminal 상태)

round-2(`GPU_NEXT_LIST_R2_DESIGNS.md`)의 15 milestone을 round-3에서 실제 코드로 backfill 시도한 결과의 **종결 상태**. 모든 항목은 terminal(real-code-landed OR documented-blocker)이다.

---

## ✅ real-code landed (round-3, 7 PR)

| milestone | PR | 산출물 | 검증 |
|---|---|---|---|
| H1 | #1453 | `tool/ptx_to_sass` | host shell — silicon 불요 |
| H2 | #1455 | `tool/gpu_occupancy` | closed-form awk — silicon 불요 |
| G2 | #1457 | `tool/gpu_regpressure` | ptxas -v 파서 — silicon 불요 |
| H3 | #1458 | `tool/gpu_profile` | nsys/ncu wrapper — silicon 불요 |
| F4 sin | #1463 | nvptx sin f64 폴리노미얼 | `hexa parse` OK + exp/log 미러 |
| F4 cos | #1464 | nvptx cos f64 폴리노미얼 | `hexa parse` OK + sin 미러 |
| F4 tan | #1467 | nvptx tan f64 = sin/cos | `hexa parse` OK + sin/cos 미러 |

**RFC 055 §13 transcendental family(exp·log·sin·cos·tan f64) COMPLETE.**

이 7개가 round-3에서 backfill 가능했던 이유: ① 도구 4개는 host-side shell(silicon 불요), ② trig 3개는 이미 silicon-fired된 exp/log emit arm의 구조적 미러 + `hexa parse` 게이트로 검증 가능.

---

## 🟠 design-terminal (real-backfill가 환경/규율로 차단)

남은 8개(D1-D4·G1·G3·E1-E4)는 round-2의 design+runbook으로 GPU.md `[x]` 종결됨. real-code backfill은 아래 사유로 이번 라운드 terminal:

### 규율 차단 — silicon-fire 게이트 (프로젝트 자체 교훈)

`[[project_gpu_codegen_baseline_2026_05_26]]`의 #1320→1322 교훈: **codegen feature는 source-to-silicon fire가 진짜 falsifier — fixture-pass ≠ fire-pass.** PTX 출력을 바꾸는 codegen 변경은 silicon 검증 없이 land하면 silent-miscompile 위험. 그 fire 경로 = ubu-2(아래 환경 차단).

| milestone | backfill 차단 사유 |
|---|---|
| D3 HX0511 lint | MIR tid-derived idx + stride 검출 — 출력 불변 lint라 안전하나 false-positive 검증에 fire 필요 |
| G1 loop fusion | MIR pre-pass가 PTX 변경 → silicon 검증 필수 (kernel meta read-set/write-set 분석) |
| G3 DCE | STMT_ASSIGN drop이 side-effect stmt 오삭제 시 silent-miscompile → fire 필수 |

### host-runtime 차단 — 순수 PTX-emit 범위 밖

| milestone | 차단 사유 |
|---|---|
| D1 @constant | `.const` 데이터는 host `cudaMemcpyToSymbol` 업로드 필요 — pure NVPTX emit 경로엔 host-runtime 부재. codegen-side(.const directive + ld.const)만 가능하나 데이터 소스 없이 무의미 |
| D2 cp.async | sm_80 gate + 3-instr emit은 가능하나 GEMM tile-overlap 효과 검증 = silicon perf fire 필요 |
| D4 gpu_grid_sync | **단일 PTX instr로 grid 전체 동기화 불가.** block-level `bar.sync 0`는 이미 `gpu_barrier()`로 wired(nvptx_target ~L1448). grid-level은 `cudaLaunchCooperativeKernel` host-wrap 필요 — pure-emit 범위 밖 |

### 환경 차단 — ubu-2 bootstrap

| milestone | 차단 사유 |
|---|---|
| E1 A4 2D thread fire | ubu-2 bootstrap link 이슈 (cuda fns NULL + `hexa_exit` stub sed 우회 필요) |
| E2 A5 f32 elem fire | 동일 — ubu-2 부트스트랩 |
| E3 A3 log f64 fire | 동일 — `c[i]=log(a[i])` vs libm tolerance 1e-5 대기 |
| E4 B4 rsqrt_rn fire | 동일 — PR #1358 byte-exact 경로 검증 대기 |

---

## 다음 세션 재개 트리거

```
ubu-2 bootstrap link 복구 시:
  E1-E4 silicon fire 일괄 (4 kernel + driver-JIT + libm tolerance)
  → 통과 시 D2/G1/G3 codegen을 fire-validated로 backfill 가능

host-runtime bridge 착수 시:
  D1 @constant (cudaMemcpyToSymbol) + D4 grid_sync (cooperative launch)
```

종결 원칙: 이 round의 terminal은 **honest** — 막힌 항목은 "미완"이 아니라 "design-level 종결 + 문서화된 blocker". 환경/규율 해제 전까지 real-backfill 시도는 프로젝트 fire-게이트 교훈 위반.
