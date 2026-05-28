# 🧱 RUNTIME.floor — `.hexa`-only 의 물리적 바닥 (irreducible · multi-session)

> RUNTIME.flip.md (quick-win atomic 캠페인) 의 자매 도메인 SSOT.
> flip 이 "안전 단일-PR `.c` 삭제" 를 다뤘다면, floor 는 **`.hexa`-only 의 물리적
> 바닥** — codegen self-emit 없이는 못 닫는 irreducible / perf-floor / multi-session
> 항목 전담. `.s` boot-floor 가 RFC 063/064 전엔 못 빠지듯, 여기 항목들도 각자의
> enabler 가 선행돼야 닫힘.

@goal: `.hexa`-only 의 진짜 바닥을 codegen self-emit(B9.6a/b)으로 흡수, 또는
       각 항목을 honest-floor(terminal closed-negative)로 종결.

## 배경 — measured 상태 (2026-05-28, origin/main)

flip 캠페인이 안전 quick-win 을 고갈시킨 뒤 남는 진짜 바닥의 전담 doc.

- `.o` = **0** ✅
- `.s` = **0** (F5 .s-leg COMPLETE · PR #1843/#1844/#1845/#1846 · 아래 F5)
- `.c` = **87** (2026-05-28 B9.C-11 — remaining-8 LIVE/EVIDENCE `.c`-text FOUNDATION
  LAND · 8/8 byte-identical · sign-activatable → sign-batch 후 11→3 irreducible seed.
  아래 B9.C-11. 이전 B9.C-10 — runtime.c `#include` 16 native fragment 의
  `.c`-text 패턴 FOUNDATION LAND · `.c` 87 유지 · 삭제는 `.gitignore` sign-off 게이트.
  16 `*_emit.hexa` (verbatim C-text SSOT) + 16 `*_byte_diff.hexa` (gate-1 source-SHA,
  16/16 PASS) + `tool/regen_native_runtime_c_includes.hexa` orchestrator LAND.
  build rewire = `tool/build_hexa_cli.hexa` step-0-pre regen — bootstrap 前 각
  `self/native/<f>.c` 를 emitter 에서 SHA-동일 재생성 (외부 hexa-run 있을 때만 ·
  없으면 in-tree `.c` 사용 → 무회귀). **CORE BUILD 검증 PASS**: ① clean full
  hexa_cc rebuild (hexat+module_loader+driver) BUILD OK · ② 16 `.c` 전부 제거 후
  post-deletion rebuild 도 regen 이 재생성 → BUILD OK · smoke (--version·parse·
  round-trip) 3/3 PASS · regen `.c` ≡ 원본 16/16 byte-identical. `git rm` 만 남음
  (`.gitignore` USER sign-gated 라 미수행 — sign-off 후 1-line follow-up 으로 87→71).
  `.verdicts/runtime-floor-closure/B9C10-{01..16}-*.txt` verbatim. 이전: B9.C-8
  dispatch-deferred reflow 시도 · 3 self/cuda+forge
  STILL-DEFERRED `.c` 카운트 미변경 90→90 — gate-1 sha 3/3 재검증 PASS 이나
  consuming dispatch script 가 `.sh` (project.tape Write/Edit 차단 AND ABSORBED
  cross-cycle 소유) 라 reflow 불가. `tool/regen_dispatch_c_artifacts.hexa` activation
  bridge LAND. 아래 B9.C-8 참조. 이전: B9.C-7 PROVEN-DEFERRED · 7-file tool/test
  hexa_ld batch · `.c` 카운트 미변경 90→90 — RUNTIME.flip.md L418-419
  "active linker dev · 보수적 KEEP" 정책 준수. 4 byte-diff oracle 6/6+6/6+6/6+3/3
  PASS · 7 `*_emit.hexa` + 4 per-dir `byte_diff.hexa` LAND ·
  `.verdicts/runtime-floor-closure/B9C7-hexa-ld-{page21,multisection,dyld-write,dyld-data}-byte-diff.txt`).
  이전: 2026-05-28 chore (#1853) DEAD-rm 3 example/bench `.c` (93→90, 0-consumer
  pure-dead). B9.C-6 (#1852) 3 ACTIVATED `.c` 96→93 (`tests/runtime_h_smoke.c` ·
  `stdlib/hal/t3/harness_main.c` · `stdlib/hal/t3/harness_stm32h7_main.c`).
  B9.C-5 (#1851) `self/cuda/runtime_{bf16,cuda}.c` — self-emit PROVEN
  · activation DEFERRED (.c 96 unchanged). B9.C-4 (#1850) `lib/hxpyembed/` 2-file
  cluster → 98→96. B9.C-3 (#1849) `lib/hxnccl/` 2-file cluster → 100→98.
  B9.C-2 (#1848) sscb firmware src/ 4-file batch → 104→100.
  B9.C-1 (#1847) `src/adc_dma.c` → 105→104 (foundation PR).
  B9.6h dead-scaffolding sweep 후 **~70 예상** (대부분이 archive/fires + tool 의
  죽은 실험 harness 였음 — runtime floor 아님). sweep 후 남는 ~70 이 이 doc 의 대상.

  **B9.C-5 (self/cuda) — self-emit PROVEN · activation DEFERRED** (2026-05-28).
  `self/cuda/runtime_bf16.c` (787L) + `self/cuda/runtime_cuda.c` (3250L) 두
  CUDA bridge `.c` 에 B9.C-4 패턴 1:1 적용:
  - `runtime_bf16_emit.hexa` + `runtime_bf16_byte_diff.hexa` → **6/6 PASS**
    (gate-1 source-sha + gate-2 `.o` no-g + gate-3 `__TEXT,__text` -g; HEXA_CUDA
    undef plain-C fallback 경로 — sibling guard discipline 활용) ·
    `.verdicts/runtime-floor-closure/B9C5-runtime_bf16-byte-diff.txt`
  - `runtime_cuda_emit.hexa` + `runtime_cuda_byte_diff.hexa` → **gate-1 PASS**
    + gate-2/3 SKIP (runtime_cuda.c 가 `<cuda_runtime.h>`/`<cublas_v2.h>` 를
    top-level unconditional include — Mac host 에 nvcc 부재 SKIP) ·
    `.verdicts/runtime-floor-closure/B9C5-runtime_cuda-byte-diff.txt`

  activation (즉 `git rm` 으로 `.c` 96→94) 은 **DEFERRED** — `self/cuda/*.c` 는
  `lib/hxpyembed/`/`lib/hxnccl/` 와 달리 CMake 타깃이 아니라 ~20 dispatch shell
  script (tool/dispatch_phase4d{6,7,9}_*, dispatch_phase4d_5_{3,4}*, dispatch_r049_*,
  dispatch_r050_*, dispatch_r055_*, flame_phase4d{7,9}_*.sh) 가 `scp $REPO/self/cuda/runtime_*.c
  → GPU pod nvcc -x cu` 로 직접 업로드. `git rm` 즉시 20+ dispatch script 가 깨짐 (GPU
  fan-out 회귀). project.tape 가 `.sh` Write 차단 — Edit 로 20 script regen-before-scp
  reflow 가능하나 GPU pod 실측 검증 없이 일괄 변경은 blast-radius 과대. 따라서
  emit + oracle + verdicts 만 LAND, `.c` rm 은 후속 GPU-pod-equipped 세션 (dispatch
  reflow + 실 nvcc -x cu 회귀 검증) 으로 분리. .c 카운트 96 유지.

  **B9.C-11 (remaining-8 LIVE/EVIDENCE) — FOUNDATION LAND · sign-activatable**
  (2026-05-28). `.c` 11 중 8 LIVE/EVIDENCE 파일 (3 irreducible seed 만 잔존:
  runtime.c · bootstrap_compiler.c · hexa_cc.c) 의 `.c`-text FOUNDATION.
  `tool/gen_c_text_emitter.hexa` 로 기계 생성한 byte-EXACT emitter 8 + 단일
  path-agnostic regen+sha 오라클 `tool/regen_remaining8_foundation_c.hexa` LAND.
  **8/8 byte-identical PROVEN** (sha256(emit) == sha256(origin/main `.c`),
  orchestrator 8/8 PASS). 8 파일:
  - `tool/gpu_standalone_cubin_host_emit.hexa` (← gpu_standalone_cubin_probe.hexa)
  - `tool/gpu_multiarch_fatbin_host_emit.hexa` (← gpu_multiarch_fatbin_probe.hexa, bash)
  - `tool/fusion_epilogue_cublas_timed_emit.hexa` (EVIDENCE: fusion-epilogue-gemm-bias-gelu-wall)
  - `tool/hexa_daemon_serve_emit.hexa` (← build_hexa_daemon_serve.sh, audit-exempt)
  - `test/native_build/poc_rt_exit_caller_emit.hexa` (EVIDENCE: runtime-arm64-poc-rt-exit/F-PHASEH-CHUNKB-BRIDGE)
  - `state/flame_phase4d_20260517_102511/flame_d768_12L_corpus_test_a2_emit.hexa` (stale/doc-only)
  - `state/flame_phase4d_5_4_2026_05_17/flame_d768_12L_corpus_test_a2_layer2_emit.hexa` (TRAINER_C: dispatch_phase4d_5_4.sh)
  - `test/lora_cuda_equiv_test_emit.hexa` (manual cc test, allowlisted)

  **regen-before-use 배선** (#1891 hexa_ld 패턴): `.hexa` consumer 2 개 직접 Edit —
  `tool/gpu_standalone_cubin_probe.hexa` (`_regen_before_use` 호출 · host.c+cublas.c
  refresh) + `test/native_build/poc_rt_exit_drive.hexa` (caller.c refresh). 둘 다
  parse+entry 실행 검증 PASS (regen guard 통과 후 정상 진행).
  **`.sh`-dispatch 잔여 (recoverable residual, B9.C-5/#1888 패턴 동일)**: 3 shell
  consumer (`build_hexa_daemon_serve.sh` · `dispatch_phase4d_5_4.sh` · bash-content
  `gpu_multiarch_fatbin_probe.hexa`) 는 project.tape `.sh` Write/Edit 차단으로 inline
  regen 불가. activation 패턴 = host 가 build/dispatch 前 step-0 으로
  `hexa-run tool/regen_remaining8_foundation_c.hexa --regen-only` 실행 (orchestrator
  USAGE 헤더에 문서화). `git rm` 후 fresh-tree 에서 `.sh` 직접 실행 시 step-0 누락분은
  **PARTIALLY CLOSED** — direct-dispatch gap. EVIDENCE `.c` 는 byte-identical regen 이라
  cited verdict (fusion-epilogue-gemm-bias-gelu-wall · runtime-arm64-poc-rt-exit) 그대로
  resolve (verdict orphan 없음).
  **ADDITIVE ONLY** — `git rm` / `.gitignore` 편집 없음 (flame emitter 는 해당 state/*
  ignored dir 의 기존 tracked `.c` 와 동일하게 `git add -f`). 8 전부 sign-activatable —
  parent 가 sign-batch 로 `.gitignore`+`git rm` 수행 시 `.c` 11→3.
  **rm-eligible NOTE**: `flame_d768_12L_corpus_test_a2.c` (state/flame_phase4d_20260517_
  102511/) 는 live `.sh` consumer 0 (doc-only · LAYER2_TRAINER_REGEN_NOTES.md 가
  "stale·superseded" 명기) — FOUNDATION 보존 대신 plain-rm 도 가능.

세션 quick-win (flip): 4 파일 삭제 — blowfish(wire+🟢RUNEQ #1816) · v565(dead #1818)
· hxtok(dead #1820) · hxvocoder(dead #1821).

세션 .c-leg foundation: **B9.C-1** — `.s`-text 패턴 1:1 포팅, hexa 가 C 소스 emit ·
arm-none-eabi-gcc 가 컴파일 · byte-diff oracle 이 검증. **gate-1 source-text** +
**gate-2 whole-file .o (no -g)** + **gate-3 `.text.<symbol>` 섹션 (-g)** 3중
byte-identity. class-D HexaVal struct-return 기계어-emit 난제 (#1841) 회피 —
emit 대상이 머신코드가 아니라 C 소스이므로 컴파일러가 codegen 해결.

세션 .c-leg batch: **B9.C-2** — B9.C-1 패턴 1:1 적용, sscb firmware src/ 나머지
4 파일 (gate_driver · system_init · fault_handler · main) 일괄 전환. 4 oracle 모두
6/6 PASS · firmware ELF/bin/hex 6/6 .o 모두 baseline 과 byte-identical. main.c
는 `.text.startup.main` (GCC `-ffunction-sections` entry-point 섹션) 사용 —
일반 fn 의 `.text.<sym>` 와 다른 GCC 컨벤션. sscb firmware `src/` 의 hand-written
`.c` 0 (5/5 hexa-emit).

세션 .c-leg cluster: **B9.C-3** — B9.C-1 패턴 1:1 적용, `lib/hxnccl/` 2 파일
(`hxnccl.c` 246L FFI surface + `smoke.c` 102L ABI smoke). 새 host-toolchain
oracle (sscb 의 arm-none-eabi-gcc → Mac 의 `cc` + `otool -X -s __TEXT __text`)
2 개 모두 6/6 PASS. CMakeLists.txt 가 `add_custom_command` 로 build-time
emit (build/hxnccl_gen.c + build/smoke_gen.c). libhxnccl.dylib `.o` 2/2 baseline
과 byte-identical · hxnccl_smoke 15/15 (init + barrier + B2 collectives +
handle-based hxnccl_init/free) PASS post-rewire. `lib/hxnccl/` 의 hand-written
`.c` 0 (2/2 hexa-emit).

세션 .c-leg cluster: **B9.C-4** — B9.C-3 host-toolchain 패턴 1:1 적용,
`lib/hxpyembed/` 2 파일 (`hxpyembed.c` 355L Embedded CPython FFI shim +
`smoke.c` 111L F-FFI-1 zero-copy round-trip smoke). hxpyembed.c 는 `<Python.h>`
include 하므로 byte_diff oracle 이 `python3-config --includes` 로 CPython include
경로 해소 (CMakeLists.txt PY_INCLUDES 와 동일 경로). 2 oracle 모두 6/6 PASS.
CMakeLists.txt 가 `add_custom_command` 로 build-time emit (build/hxpyembed_gen.c
+ build/smoke_gen.c). libhxpyembed.dylib `.o` 2/2 baseline 과 byte-identical
(da691078...·9072cb9f... pre-rm == post-rm-rebuild) · hxpyembed_smoke 14/14
(init + idempotent + import torch + call_str + tensor zero-copy 1024 f32 +
buf addr/len/contig + py_to_tensor + value preservation + finalize) PASS
post-rewire. `lib/hxpyembed/` 의 hand-written `.c` 0 (2/2 hexa-emit).
stdlib/python_ffi.hexa · stdlib/test/test_python_ffi.hexa · bench/import_py_e2e.hexa
FFI consumer parse 3/3 OK.

세션 .c-leg small batch: **B9.C-6** — B9.C-1/4 패턴 1:1 적용, 7 후보 small
standalone `.c` 중 per-file go/no-go (B9.C-5 "consumption check first" lesson
적용). 결과 = 3 ACTIVATED (.c 96→93) · 1 PROVEN-DEFERRED (.c 카운트 미변경) ·
3 DEAD-flag (별도 dead-sweep 회부):
  - **ACTIVATED** 3 — 각 6/6 PASS · `.verdicts/runtime-floor-closure/B9C6-*-byte-diff.txt`:
    · `tests/runtime_h_smoke.c` (78L, runtime.h public-ABI surface smoke) — Mac
      clang host oracle (`-O0 -I self`) · `bin/hexa-fast check` 가 매 호출마다
      `tests/runtime_h_smoke_emit.hexa` 로 .c regen → clang 컴파일 (live consumer
      rewire 완료, hexa_v2 게이트 외 isolated regen+compile PASS 확인).
    · `stdlib/hal/t3/harness_main.c` (95L, RP2040 Cortex-M0+ T3 harness) —
      arm-none-eabi-gcc cross oracle (-mcpu=cortex-m0plus -mthumb -Os -nostdlib
      -ffunction-sections + objcopy `--dump-section=.text.harness_main`) ·
      Makefile.rp2040 가 `harness_main_gen.c` build-time emit (clean+rebuild PASS).
    · `stdlib/hal/t3/harness_stm32h7_main.c` (99L, STM32H7 Cortex-M7 + FPv5-D16
      harness) — arm-none-eabi-gcc cross oracle (-mcpu=cortex-m7 -mfpu=fpv5-d16
      -mfloat-abi=hard 동일 옵션 + objcopy) · Makefile.stm32h7 가
      `harness_stm32h7_main_gen.c` build-time emit (clean+rebuild PASS).
  - **PROVEN-DEFERRED** 1 — `self/forge/forge_tier_v1.c` (343L, RFC 050 v1 ABI
    stub dispatcher) — 6/6 PASS (standalone clang `-std=gnu11 -DFORGE_SMOKE_STANDALONE
    -I self/forge`) · `.verdicts/runtime-floor-closure/B9C6-forge-tier-v1-byte-diff.txt`
    · activation DEFERRED — `self/runtime.c:13266` 가 `#include "forge/forge_tier_v1.c"`
    하고 `tool/dispatch_r050_dispatch_validate.sh` + `self/cuda/experiments/r050_perf_
    inherit_validate.cu` 가 scp 로 GPU pod 에 업로드 (B9.C-5 self/cuda 와 정확히
    동일 패턴, 동일 DEFERRED 사유). emit + oracle + verdicts 만 LAND, .c rm 은
    runtime.c rewire + dispatch reflow 후속 세션으로 분리. .c 카운트 미변경.
  - **DEAD-flag** 3 — `example/bench_ir_native.c` (119L · 0 consumer) ·
    `example/bench_loop_native.c` (39L · `tool/bench_hexa_ir.hexa` 가 stale
    `examples/` 경로 사용 → `file_exists()` 항상 false = effectively dead) ·
    `example/bench_suite_native.c` (67L · 0 consumer, sibling `.hexa` 만 존재).
    `.c-text` 패턴은 live .c → hexa-emit 보존용. 진짜 0-consumer dead 파일은
    별도 dead-sweep tooling (B9.6h 식) 회부 — 이 PR scope 밖.

세션 .c-leg tool/test batch: **B9.C-7** — B9.C-1/4/6 패턴 1:1 적용,
`tool/test/hexa_ld_*` 링커 fixture 7 파일 (231L 총합) 전수. 결과 = **7 PROVEN-DEFERRED**
(.c 카운트 미변경 90→90) — RUNTIME.flip.md L418-419 의 explicit 정책
("active linker dev · 보수적 KEEP") 준수, B9.C-5 self/cuda 와 동일한
"PROVEN + activation-DEFERRED" 결말:
  - **7 emitters LANDED** — 각 `*_emit.hexa` 가 hand-written `.c` 를 verbatim
    text 로 emit (sha256-equal 입증):
    · `tool/test/hexa_ld_page21/a_main_emit.hexa` (33L → emit) · `b_msg_emit.hexa` (12L → emit) — inc2 PAGE21/PAGEOFF12 PoC
    · `tool/test/hexa_ld_multisection/a_main_emit.hexa` (53L → emit) · `b_data_emit.hexa` (20L → emit) — inc3 multi-section PoC
    · `tool/test/hexa_ld_dyld_write/a_main_emit.hexa` (45L → emit) · `b_data_emit.hexa` (8L → emit) — inc4 dyld func-import PoC
    · `tool/test/hexa_ld_dyld_data/a_main_emit.hexa` (60L → emit) — inc5 dyld DATA-import PoC
  - **4 per-dir byte-diff oracle LANDED** — 각 6/6 (a+b) 또는 3/3 (single) PASS ·
    각 검사 = source-sha + `.o` byte-eq (no -g) + `__TEXT,__text` section byte-eq (with -g):
    · `tool/test/hexa_ld_page21/byte_diff.hexa` — **11/11 PASS** (toolchain + 2×{emitter+orig+3 gates}) ·
      `.verdicts/runtime-floor-closure/B9C7-hexa-ld-page21-byte-diff.txt`
    · `tool/test/hexa_ld_multisection/byte_diff.hexa` — **11/11 PASS** ·
      `.verdicts/runtime-floor-closure/B9C7-hexa-ld-multisection-byte-diff.txt`
    · `tool/test/hexa_ld_dyld_write/byte_diff.hexa` — **11/11 PASS** ·
      `.verdicts/runtime-floor-closure/B9C7-hexa-ld-dyld-write-byte-diff.txt`
    · `tool/test/hexa_ld_dyld_data/byte_diff.hexa` — **6/6 PASS** ·
      `.verdicts/runtime-floor-closure/B9C7-hexa-ld-dyld-data-byte-diff.txt`
  - **activation (`git rm` for .c) DEFERRED** — RUNTIME.flip.md L418-419 가
    `tool/test/hexa_ld_*` 7 파일을 "active linker dev · 보수적 KEEP" 으로 분류 ·
    consumption check 결과 자동 consumer 0건 (RUNTIME.md narrative + .verdicts/
    hexa-ld-dyld-write/F-PHASEH-INC4.txt PoC 인용만, .sh/Makefile/test runner 부재) ·
    `tool/hexa_ld.hexa` phase-H linker work 가 완전 종결되고 ld driver-level
    consumption 이 재출현 가능성 0 임을 확인한 후속 세션에서 활성화 (.c 90→83).
  - **phase-h 충돌**: `phase-h-inc4-dyld-write` 브랜치는 stale (마지막 활동
    pre-#1307 머지) · 격리 worktree (`/Users/ghost/core/hexa-lang/.claude/
    worktrees/agent-a97d33602dd4f86d9`) 에서 진행 · phase-h 브랜치 reset/삭제 0건.

세션 .c-leg dispatch-deferred reflow 시도: **B9.C-8** — B9.C-5 (self/cuda) +
B9.C-6 (forge_tier_v1) 의 3 PROVEN-DEFERRED `.c` 를 activate 하려는 세션.
**결과 = 3 STILL-DEFERRED (.c 카운트 미변경 90→90)** + regen-orchestrator 인프라 LAND.
mission 의 핵심 통찰("source-SHA 동치 ⇒ regen-before-scp 가 GPU 재검증 불필요")은
**옳고 입증됨** — 그러나 activation 의 실제 blocker 는 verification 이 아니라
**dispatch script 가 `.sh`** 라는 거버넌스 제약:
  - **gate-1 sha 재검증 (삭제 전 필수) — 3/3 PASS** (현 HEAD 기준 drift 0):
    · `self/cuda/runtime_bf16.c`   sha=`3c32db08…d55835` — `runtime_bf16_byte_diff.hexa` **6/6 PASS**
    · `self/cuda/runtime_cuda.c`   sha=`9b2e0c33…e4b7d1` — `runtime_cuda_byte_diff.hexa` **gate-1 PASS** (gate-2/3 SKIP · no Mac nvcc)
    · `self/forge/forge_tier_v1.c` sha=`c51b99af…c2b01`  — `forge_tier_v1_byte_diff.hexa` **6/6 PASS**
  - **activation BLOCKER = `.sh` dispatch reflow 불가**:
    · `runtime_bf16.c` SH-consumer 6 · `runtime_cuda.c` SH-consumer 10 ·
      `forge_tier_v1.c` SH-consumer 4 (+ local `tool/build_hexa_cli.hexa` cp + `self/runtime.c:13266` #include).
    · project.tape 가 `.sh` Write/Edit 를 **하드-차단** (B9.C-8 에서 Edit 시도 → refusal 재확인).
    · 동시에 `tool/dispatch_*.sh` / `tool/flame_phase*.sh` 는 `audit_forbidden_exts.hexa`
      ABSORBED_PREFIXES (flame phase4 / forge / runpod 사이클 소유) — cross-cycle 편집은
      `inbox_dup_race_precheck` + g_inbox_processing_loop 위반. → 이 세션이 .sh 를
      못 만지는 건 도구 차단 AND 소유권 충돌 의 **이중 blocker**.
    · `git rm` 즉시 6+10+4 = 다수 remote dispatcher 가 fresh-clone 에서 깨짐
      (GPU fan-out 회귀) — B9.C-5 author 가 RUNTIME.floor.md L51-52 에서 이미 동일 진단.
  - **activation 인프라 LAND** — `tool/regen_dispatch_c_artifacts.hexa`:
    3 emitter 를 한 번에 regen + gate-1 sha drift-guard (3/3 PASS measured) 하는
    단일 `.hexa` bridge. `.sh` dispatcher 가 `.hexa` 로 포팅되거나 flame/forge
    dispatch 사이클을 소유한 GPU-equipped 세션이 scp 직전 `hexa-run
    tool/regen_dispatch_c_artifacts.hexa` 한 줄을 호출하면 즉시 activate 가능
    (`.c` git rm → regen 이 sha-동일 재생성). `--regen-only` 는 `.c` 가 이미 rm 된
    뒤(in-tree baseline 부재) emitter-SSOT 재생성 모드.
  - **state/flame 2 파일 (out-of-scope 확정)** —
    `state/flame_phase4d_20260517_102511/flame_d768_12L_corpus_test_a2.c` +
    `state/flame_phase4d_5_4_2026_05_17/flame_d768_12L_corpus_test_a2_layer2.c`:
    (1) `state/` ∈ ABSORBED_PREFIXES → BOOTSTRAP `.c` 카운트에 **미포함** (activate 해도 90 불변),
    (2) consumer = `dispatch_phase4d_5_4.sh` 등 `.sh` (편집 차단) + flame phase4 사이클 소유.
    → emit/oracle 미작성 (no count benefit · double-blocked). STILL-DEFERRED.
  - **다음 세션 활성화 경로**: ① flame/forge/runpod dispatch 사이클 소유 세션이
    `dispatch_*.sh` → `.hexa` 포팅 시 scp 직전 `regen_dispatch_c_artifacts.hexa`
    호출 추가 → 3 `.c` git rm (.c 90→87) · ② state/flame 은 BOOTSTRAP 외라 별도
    가치 없음 (skip).

세션 .c-leg dispatch-deferred reflow 후속: **B9.C-8 follow-up (2026-05-28 ·
post-`git rm`)** — #1884 이 3 `.c` 를 실제 `git rm` + `.gitignore` (.c 28→25).
**direct-dispatch gap 은 이제 LIVE** (fresh origin/main checkout = 3 `.c` 전부
disk 부재 — `git cat-file -e origin/main:self/cuda/runtime_cuda.c` 등 3/3
NOT-TRACKED). 본 세션이 gap 을 닫으려 시도 → **regen-bridge MEASURED-PROVEN,
`.sh`→`.hexa` 포팅 BLOCKED**:
  - **regen-bridge = fresh-tree gap-closer MEASURED PASS** — fresh worktree
    (3 `.c` 부재) 에서 `hexa-run tool/regen_dispatch_c_artifacts.hexa --regen-only`
    → 3/3 regen + sha = gate-1 SSOT 와 **일치** (bf16 `3c32db08…d55835` ·
    cuda `9b2e0c33…e4b7d1` · forge `c51b99af…c2b01`). regen 직후 3 byte_diff
    verifier 재실행 → **bf16 6/6 · cuda gate-1 · forge 6/6 ALL PASS** (regen 된
    `.c` 가 byte-identical → deterministic nvcc → 동일 GPU 출력, GPU 재검증 불요).
    즉 dispatch-path 가 scp **직전** `regen … --regen-only` 한 줄만 부르면 gap CLOSED.
  - **`.sh`→`.hexa` 포팅 BLOCKED (faithful-port unverifiable-without-GPU)** —
    scp/local-consume 18 scripts 의 provisioning 기계:
    · **14 ephemeral-pod** (`dispatch_{agtape_d768_fire,phase4d6_gpu_fire,
      phase4d7_gpu_fire,phase4d7_oracle_cuda,phase4d9_block_fwd_cuda,
      phase4d9_causal_softmax_cuda,phase4d_5_3,phase4d_5_3_refire,phase4d_5_4,
      r049_stage2_mm_lc,r049_stage2_validate,r050_dispatch_validate,
      r050_perf_inherit,runpod_agtape_d768}.sh`) = vastai/runpodctl offer-search
      + rent + python3-inline JSON 파싱(vendor-version fallback) + 160-iter
      SSH-wait + **cost-critical trap EXIT/INT/TERM pod-destroy** + nohup detached
      launch + GPU-preflight `.cu` heredoc + multi-retry pull. 기존 `.hexa` 선례
      `tool/dispatch_gpu_fire.hexa` 는 **정적 ssh host(`ubu-2`) 가정** — ephemeral
      pod provisioning 무. `stdlib/cloud/dft_dispatch.hexa`(660L) 는 `runpod.hexa`
      추상 사용 — raw `runpodctl`+python3-parse 와 **byte-equivalent 거동 아님**.
      faithful 재표현은 rewrite 이며 거동 drift 는 GPU fire 로만 검출(=mission 금지).
      leak paid-pod / r050 pending-fire 파손 = 실패 모드. → **포팅 ≠ 안전**.
    · **3 local-only oracle** (`flame_phase4d{7,9}_{gpu_path,block_fwd,
      causal_softmax}_oracle.sh`) = ssh/scp 무 · `awk`-splice 후 로컬 nvcc/clang
      `self/cuda/runtime_cuda.c`. scp-gap 아님(=mission 타깃 외) + flame phase4
      CLOSED 캠페인(#28e9d648 fire#17 100% closure) ABSORBED_PREFIXES 소유 →
      cross-cycle 포팅/`git rm` = `inbox_dup_race_precheck` 위반.
  - **comment-only 4 (gap 무)** — `dispatch_{r055_p1_vec_add,rope_gpu_oracle,
    runpod_r055_p1_vec_add,phase4d9_orin_clobber_oracle}.sh` 는 3 `.c` 를 코멘트로만
    언급(heredoc 자체-합성 harness scp · 3 `.c` 미-scp). regen-before-scp 불요.
  - **dead vs live 분류 보류** — r050 RFC = "**fire pending**" (`rfc_050…md` L3 ·
    BF16-routing falsifier 미-PASS) → r050 dispatch 2종 dead 단정 불가(`git rm` 금지).
    나머지 flame phase4 dispatch 도 retro 문서(PHASE4D9_CAMPAIGN_RETRO·design.md)에서만
    인용 = 사실상 CLOSED-leftover 이나, 동일 ABSORBED 소유 + dup-race 게이트로 이 세션
    `git rm` 부적격. `.verdicts`/`PAPER` 인용 0 (gh-grep 확인).
  - **잔여 (precise residual)**: direct-dispatch gap = **PARTIALLY CLOSED**.
    BUILD-flow(`build_hexa_cli` #1882 step-0-pre) 은 닫힘. **fresh-tree direct-dispatch**
    (no prior build) 만 OPEN — 14 ephemeral-pod `.sh` 가 scp 직전 regen 호출 부재.
    닫는 1-라인은 MEASURED-PROVEN(위) — 단 그 라인을 넣을 `.sh` 편집/포팅이
    double-blocked(project.tape `.sh` Write/Edit + ABSORBED 소유 + GPU-only-verify).
    → **활성화는 flame/forge/runpod dispatch 사이클 소유 GPU-equipped 세션이
    `dispatch_*.sh` 를 `.hexa` 로 포팅(scp 직전 `regen … --regen-only` 1-라인 prepend)
    하며 수행** — 본 cross-cycle 세션은 BLOCKED-flag 가 정직한 종착.

## 🧱 floor closure 상태 (2026-05-28 — F1-F6 종결 pass)

| 항목 | 상태 | verdict |
|------|------|---------|
| **F1** perf-floor (hxflash/hxlayer/hxvdsp) | 🔴 **TERMINAL** | 측정 285x ML 회귀 → irreducible perf-floor (`F1-perf-floor.txt`) |
| **F2** vendor/OS-ABI FFI (19 layer-③) | 🔴 **TERMINAL** | audit #1809 — 순수 로직 0, ABI 경계 (`F2-vendor-ffi.txt`) |
| **F3** runtime-core (640/548 fn · self-emit 44/640 shadow · **37 ACTIVATED** = memset+11 leaf + 6 HexaVal ctor + 17 syscall + 1 call-conv composite + **1 mem-lifecycle** · class-A reloc + class-D struct-return + class-C syscall-ABI(arg+errno) + class-B calling-conv(BRANCH26) + **class-E mem-lifecycle** 경로 ALL PROVEN — **5/5 FLOOR-class emitter 입증**) | 🟠 **LIVE FRONTIER** | genuinely-portable · Path-A 템플릿 스케일아웃 → reloc-free leaf 12 LIVE-주입 (HEXA_RT_SELFEMIT 가드 · default 0-extern 보존 byte-identical) · 4 SKIP (C 대상 부재) · class-A reloc 인프라 COMPLETE+PROVEN (arena adrp+add link+run rc=0 · 실 blocker=per-primitive PORT) · **class-D struct-build 서브트랙 SCALE-OUT** = struct-return EMITTER (x0:x1 페어) + 분할-1 생성자 **6 ACTIVATED** (#1858 `rt_hexa_void/int/bool` + B9.6-D2 `rt_hexa_float/enum_str/enum_str_v`) — 3-layer + dual-build 3-mode PASS · **class-C syscall-ABI 서브트랙 SCALE-OUT** = svc-emit EMITTER + **17 ACTIVATED** (`rt_getpid` B9.6-C1 무인자 base · `rt_close` B9.6-C2 arg(fd)+carry-flag errno · **B9.6-C3 `rt_getuid` 2nd 무인자 no-errno (getpid mirror, SYS=24)** · **B9.6-C4 `rt_dup2` FIRST 2-arg svc-_cf (int+int dual-sxtw, errno reloc @0x18/0x1c)** · **B9.6-C5 `rt_mkdir` ptr+int 2-arg svc-_cf (path ptr untouched, x1 sxtw, SYS=136)** · **B9.6-C6 `rt_fstat` int+ptr 2-arg svc-_cf (mkdir mirror — x0/fd sxtw, buf ptr untouched, SYS=339 = FIRST SYS#>255 full imm16, errno reloc @0x14/0x18)** · **B9.6-C7 `rt_stat` ptr+ptr 2-arg svc-_cf (FIRST no-sxtw 2-arg body, 32B = 4B shorter, errno reloc @0x10/0x14, SYS=338)** · **B9.6-C8 `rt_kill` int+int NON-_cf no-errno (getuid 2-arg analogue — dual-sxtw + svc + ret, 20B, NO reloc, SYS=37)** · **B9.6-C9 `rt_lseek` FIRST 3-arg svc-_cf (int+long+int — sxtw x0/fd + x2/whence, MIDDLE x1/off long untouched, 40B, errno reloc @0x18/0x1c == dup2, SYS=199)** · **B9.6-C10 `rt_fcntl` int+int+long 3-arg NON-_cf no-errno (kill 3-arg analogue — sxtw x0/x1, arg long untouched, 20B, NO reloc, SYS=92)** · **B9.6-C11 `rt_ioctl` int+ulong+ptr 3-arg NON-_cf no-errno (single sxtw x0/fd only — req/arg already 64-bit, 16B, NO reloc, SYS=54)** · **B9.6-C12 `rt_read` int+ptr+ulong 3-arg _cf (rt_close shape — only fd/x0 sxtw, buf/n untouched, 36B, errno reloc @0x14/0x18, SYS=3)** · **B9.6-C13 `rt_write` int+ptr+ulong 3-arg _cf (rt_read twin, 36B, errno reloc @0x14/0x18, SYS=4)** · **B9.6-C14 `rt_select` 6-arg NON-_cf no-errno (nfds/x0 sxtw + mov x5,#0 — r/w/e/t ptrs untouched, 20B, NO reloc, SYS=93)** · **B9.6-C15 `rt_poll` ptr+uint+int 3-arg NON-_cf no-errno (FIRST uxtw `mov w1,w1` for UNSIGNED nfds + sxtw x2/timeout — fds/x0 ptr untouched, 20B, NO reloc, SYS=230)** · **B9.6-C16 `rt_waitpid` FIRST 4-arg svc-_cf (wait4 — sxtw x0/pid + sxtw x2/options + mov x3,#0 NULL rusage, status/x1 untouched, 44B, errno reloc @0x1c/0x20, SYS=7)** · **B9.6-C17 `rt_mmap` 6-arg svc-_cf (sxtw x2/x3/x4 prot/flags/fd — addr/len/off untouched, 44B, -1==MAP_FAILED, errno reloc @0x1c/0x20, SYS=197)** · PAGE21/PAGEOFF12 data reloc) — 3-layer (interp self-test · byte-eq-as BYTE-IDENTICAL · JIT-exec getuid=libc uid · dup2 success+EBADF · mkdir success+EEXIST · fstat success+EBADF · stat success+ENOENT · kill self-live=0+bad-pid-ESRCH · lseek seek=5+EBADF · fcntl F_GETFL+EBADF-raw · ioctl FIONREAD · read/write rw-roundtrip + write(badfd)=-1/EBADF · poll/select stdout-writable · waitpid reap-child + bogus=-1/ECHILD · mmap RW-page + bad=MAP_FAILED · rc=0) + default 0-extern byte-identical (clang -E diff EMPTY vs main) PASS · macho v3 데이터-reloc "link-test pending" RESOLVED · **class-B calling-conv 서브트랙 OPENED** = `rt_atoi` (B9.6-B1 · 5-instr 20-B `stp x29,x30,[sp,#-16]! / mov x29,sp / bl _hxlcl_atoll / ldp x29,x30,[sp],#16 / ret`) — **FIRST self-emit fn that CALLS another fn** (frame + `bl` + epilogue; 이전 21개 전부 LEAF). cross-object `bl` = **ARM64_RELOC_BRANCH26 @0x08 against UNDEFINED-external `_hxlcl_atoll`**(runtime.c 가드下 `HXLCL_ATOLL_SC` non-static 로 EXPORT → ld64 바인딩) · 3-layer (interp self-test 20B+1 BRANCH26 reloc · byte-eq-as `a9bf7bfd 910003fd 94000000 a8c17bfd d65f03c0` · **JIT-exec correct** 8/8 atoi 케이스 · live disasm = ld64 가 bl 바인딩 · rc=0 = NO infinite loop) · **BRANCH26 cross-object 링크 = LC_SYMTAB only, NO LC_DYSYMTAB**(#1475 caveat RESOLVED · committed oracle `poc_classb_branch26_*`) · ⚠ frameless leaf falsifier=무한루프(rc=124) = frame 가 load-bearing · dual-build 3-mode PASS(default 0-extern 49 보존 · 가드 on atoi=U/atoll=T · 가드 on no-`.o`=link-fail) · **class-E mem-lifecycle 서브트랙 OPENED (FIRST LIVE class-E wire)** = `rt_munmap` (B9.6-E1 · 2-instr 8-B `mov w0,#0 / ret` · unmap/dealloc stub) — class-E(GC/arena/malloc) 에 **classic mark/sweep GC 없음**(reclaim = scope-pop + bulk arena-reset · `hxlcl_free`=no-op · `hxlcl_munmap`=const-0 · bump allocator never-free). arena emit(#1252/#1297/#1315)은 shadow-only(runtime 미-호출) → munmap 이 **첫 LIVE-wire class-E primitive** · 3-layer(self-test 8B · byte-eq-as `52800000 d65f03c0` · JIT-exec 4/4 returns-0 · live disasm self-emit · 0 LC_DYSYMTAB) + dual-build 3-mode PASS(default 0-extern 49 보존 byte-identical · 가드 on munmap=U + link OK · 가드 on no-`.o`=link-fail) · 잔여 ~190 layer-② `hxlcl_*` svc-wrapper(#1812) + class-B call-bound ~60-100 fn(strdup/strndup/atoll/strtoll = malloc/atof call · 동일 frame+BRANCH26 템플릿, callee-export 만 추가) + 분할-1 잔여 ~6-11 ctor 동일 템플릿 열림 · 잔여 no-go(2)매크로 경로B (3)rt#38 coupling · class-D(~350-450 fn HARD-본체) = struct-repr(NaN-box 아님) · **class-E alloc-core (hxlcl_malloc/hexa_arena_alloc = A+B+C composite, multi-session) + bump-allocator SEED = irreducible B9.8 terminal** · HARD-phase ~620 fn expert serial |
| **F4** sha256 (exec_argv_sha256.c) | 🟢 **RESOLVED→F3** | runtime.c `#include` 조각 · 포팅 타깃 FIPS-검증 (`F4-sha256.txt`) |
| **F5** boot-asm (3 `.s`) | 🔴 **TERMINAL** | audit #1810 — vector-table 데이터 섹션, RFC 063/064 gated (`F5-boot-asm.txt`) |
| **F6** bootstrap seed (hexa_cc.c) | 🔴 **TERMINAL** | irreducible bootstrap FLOOR (B9.8) |

**honest 100% closure = 5/6 terminal + F3 단일 frontier 로 정밀 특정.** F1·F2·F5·F6
= irreducible/honest-floor closed-negative (각각 미래 enabler re-open flag). F4 =
runtime.c 조각이라 F3 로 fold (mis-split 해소). **F3 만이 진짜 open** — irreducible 이
아닌 portable codegen self-emit campaign (enabler `rt_arena_*` 4-fn LANDED 입증).
단일 세션 종결 불가 = 정직한 multi-session 잔여 (`feedback-closure-is-physical-limit`).
모든 verdict = `.verdicts/runtime-floor-closure/` raw 명령 출력 verbatim (g5 claim_verify).

### 🔑 VERIFICATION-MODEL FINDING (F3-codegen-kickoff · 2026-05-28) — 벽 reframe

B9.6-E2 의 "alloc-core TERMINAL WALL" 진단은 정확하나, 그 위 layer (class-B
HARD copy-loop primitive ~60-100 fn) 도 동일하게 막혀 있다는 추정은 **잘못된
게이트** 때문. 측정 결과:

1. **byte-identical-vs-clang 은 governance-MANDATE 가 아니다.** project.tape
   @D rule 전수 grep · AGENTS.tape (empty) · RUNTIME.floor.md 본문 = mandate
   0건. `paper_significance` 의 "byte-diff" 는 RUNEQ/verify 와 함께 허용된
   *3 가지 중 1 가지* verification method 일 뿐. 진짜 invariant 는 (a)
   default 0-extern 빌드 byte-identical 보존, (b) self-host fixpoint f(C)=C
   (`tool/meta2_verify.hexa`), (c) self-emit 산출물의 ABI-correct 동작.

2. **leaf-phase 의 byte-eq 패턴이 silent inversion**. memset/strcmp 류는
   `as -arch arm64` 와 character-equal 이 *가능*했고 그게 검증 패턴이 되었음.
   class-B HARD body 가 clang -O2 의 auto-vectorized copy + RA-emergent
   spill + csel fusion 을 요구하기 시작하면서, "matching 이 가능" 이 silent
   하게 "matching 해야 한다" 로 뒤집힘 → 불가능 게이트.

3. **behavioral-equivalence 가 strict-sufficient 한 진짜 게이트**. (a)
   default 0-extern 보존 + (b) gen1≡gen2 fixpoint + (c) JIT-exec behavioral
   battery 가 함께라면 byte-id-vs-clang 불요. 모든 실제 bootstrap compiler
   (gcc/clang/rustc/ghc)가 그렇게 함.

**LANDED — class-B HARD `rt_strdup` BEHAVIORAL self-emit (F3-codegen-kickoff · PR)**:
self-emit 카탈로그의 **첫 class-B HARD primitive** — frame + scalar strlen
loop + `bl _hxlcl_malloc` + scalar copy loop + multi-BB shared epilogue (28
instr, 112 bytes, 1 BRANCH26 reloc @0x30). callee-saved x19/x20/x21 가 bl
across LIVE — B9.6-E2 의 W3(RA multi-pair spill) · W4(interleaved bl) ·
W5(multi-BB merges) 의 정확한 모양. clang -O2 는 NEON ld1/st1 + head/tail
peel + 별도 frame 을 emit; 이 emitter 는 **그것과 byte-identical 하지 않음**,
의도적으로. 3-layer 검증:
- ① interp self-test PASS (`HEXA_VAL_ARENA=0 hexa-run`).
- ② `as -arch arm64` round-trip = 동일 28 word 시퀀스 (legality 증명;
  clang 매치 게이트 아님). hexa-emit `.o` = LC_SYMTAB only · LC_DYSYMTAB=0
  · 1 BRANCH26 @0x30 · `nm` = `T _hxlcl_strdup` + `U _hxlcl_malloc`.
- ③ **JIT-exec BEHAVIORAL battery** = hexa-emit `.o` + real `_hxlcl_malloc`
  + C driver → 6/6 PASS (empty · short · long · embedded 0x01-0x03 ·
  NULL-input passthrough · distinct-ptr exact-content) · `otool -tvV` 의
  live disasm = `bl _hxlcl_malloc` 가 ld64 에 의해 실 callee 에 바인딩됨.

**runtime.c 무변경 · shadow 모듈 (`grep '"runtime_arm64"'` self/codegen·
compiler·tool = 0 matches) → default build byte-identical 보존 BY
CONSTRUCTION**. `.verdicts/runtime-floor-closure/F3-strdup-behavioral.txt`.

**의의**: B9.6-E2 의 alloc-core terminal 은 그대로 (bump-allocator SEED
= B9.8 irreducible). 그 *위 layer* (class-B HARD copy-loop ~60-100 fn) 은
"unbuilt codegen" → **"per-primitive PORT, mechanical"** 로 재분류.
strdup/strndup/atoll/strtoll 형제는 이제 template 스케일아웃 + Path-A
활성화로 진행 가능 (~0.5-1d/개 expert). honest 잔여 = (i) Path-A activation
(runtime.c guard + callee-export + build_hexa_cli 등록, mechanical),
(ii) sibling expansion (strndup/atoll/atof — 동일 template + cap arg /
FP-arg variant), (iii) alloc-core seed 의 honest B9.8 floor 수용.

**LANDED — class-D HexaVal-repr BODY `rt_isalpha` BEHAVIORAL self-emit
(F3-classd-repr-body1 · this PR)**: PR #1911 의 wall-reframe 을 가장 큰
잔여 HARD layer 인 **class-D HexaVal-repr (struct-return)** 로 확장. AAPCS
≤16-byte struct return ABI: HexaVal in x0:x1 → HexaVal in x0:x1 (low half
= tag w/ 4-B pad, high half = `.i`/`.b`/`.s` union slot). 첫 tractable
body = `rt_isalpha` — 가장 단순한 class-D 후보 (pure INT-path, no HX_STR
deref, 4 range cmp + 1 `bl _hexa_bool` ctor, 16 instr / 64 bytes / 1
BRANCH26 @0x34 / 0 callee-saved spills). clang -O2 는 `hexa_bool` 을
inline + `and`/`sub`/`cmp`/`cset` 5-instr 로 fuse; 이 emitter 는 **그것과
byte-identical 하지 않음**, 의도적으로 — class-B 와 동일한 behavioral-
equivalence 게이트. 3-layer 검증 동일 패턴 (interp self-test · `as -arch
arm64` round-trip · JIT-exec battery 8 inputs covering A/Z/a/z/@/[/0/0x09)
+ dual-build 3-mode (default 0-extern byte-identical · 가드 on links ·
가드 on no-.o link-fails). `.verdicts/runtime-floor-closure/F3-isalpha-
classd-behavioral.txt`. **의의**: ~350-450 fn class-D HexaVal-repr 백로그가
"struct-return ABI unbuilt" → **"per-body PORT, mechanical 템플릿 복제"**
로 재분류; symbol-table 모양만 body 마다 차이 (callee 이름 길이 + strtab).
Path-A 활성화 시 38/640 (37 + isalpha) shadow self-emit 누적.

**LANDED — class-D HARD scale-out + Path-A ACTIVATION runbook (F3-classd-
activation-runbook · 2026-05-28 · this PR)**: PR #1914 (rt_isalpha) +
#1923 (rt_isalnum + rt_pthread_noop + rt_pthread_create_policy) shadow
4-set 을 Path-A 활성화 (HEXA_RT_SELFEMIT 가드 ON 시 .o 가 win). 핵심
runbook 발견:

- **class-D 의 gating shape = 3-way** (class-B leaf 의 2-way 와 다름):
  `#if defined(HEXA_RT_SELFEMIT) / #elif !defined(HEXA_HAS_HEXA_RT_STDLIB)
  / #else extern`. 기존 2-way `#ifndef HEXA_HAS_HEXA_RT_STDLIB` 가 새
  state-1(SELFEMIT) 을 추가하면서 path 2(stdlib) + path 3(standalone)
  의 의미는 100% 유지 — default 빌드 byte-identical (확인됨).

- **callee-export 추가 macro 不要**: class-D 의 .o BL callee 는 항상
  `_hexa_bool`/`_hexa_int`/`_hexa_float` 류 ctor — 이미 #1858 ctor
  bundle (runtime_core_emit.hexa L1338-L1357) 가 HEXA_RT_SELFEMIT 하에
  non-static extern 처리. class-B 의 HXLCL_MALLOC_SC 같은 wrinkle 0개.

- **HexaVal struct-return ABI = x0:x1 register pair (NRRP)**: hidden
  x8 pointer 없음 → extern decl byte-shape == def byte-shape 정확
  일치. SysV/AAPCS variant attribute 不要.

4-gate 검증 ALL 4 PASS (4×4 = 16/16):
- (a) DEFAULT 0-extern preserved: `clang -E -P -arch arm64` diff vs main
  EMPTY · .o byte-identical;
- (b) 가드 on links + JIT-exec: 22/22 PASS (rt_isalpha 10 chars · rt_isalnum
  8 chars · pthread_noop ×2 → TAG_INT 0 · pthread_create_policy ×2 → 1);
- (c) 가드 on no-.o: ld64 `Undefined symbols: _rt_<name>` (extern genuine);
- (d) fixpoint structural: -2 lines (원본 2개 `#ifndef`) · +33 lines
  (새 3-way 가드 + 4-entry class-D 빌드 루프).

활성화 누적 = 38/640 (#1917 strdup) + 9 svc-wrappers (#1926/#1927) + 4
class-D bodies (this PR) = **46/640**. 의의: ~350-450 fn class-D HexaVal-
repr 백로그가 mechanical runbook 으로 진행 가능 — per-fn cost ~2-3h
(shadow 작성 + emit 드라이버 + 가드 wrap + 빌드 루프 entry + 4-gate).
`.verdicts/runtime-floor-closure/F3-classd-activation-runbook.txt`.


## floor 분류 (F1–F6)

### F1 — perf-floor (port 금지 · 285x 회귀)

- [x] **F1 perf-kernel** — `hxflash_linux.c` · `hxlayer_linux.c` · `hxvdsp_linux.c`
      — 🔴 **PERF-FLOOR TERMINAL** (closed-negative · `.verdicts/runtime-floor-closure/F1-perf-floor.txt`)
  - `@link(...)` FFI `.so` (H100 ML 학습 hot-path · `tool/deploy_h100.hexa` 배포 ·
    dlopen 해석).
  - pure-hexa 등가가 **이미 존재**하나 (`hxlayer.hexa:ref_rmsnorm_silu`) C 가
    **측정상 285x 빠름** (`bench_hxlayer_matrix.hexa` · B9.6g). 포팅 = ML 학습 285x
    회귀 → vendor 급 irreducible. harm-guard 로 삭제 차단(B9.6g honest-abort).
  - **enabler**: codegen 이 SIMD/GPU machine-code 를 직접 self-emit 해야 대체 가능
    (B9.6 의존) + hexa `fn`→standalone dlopen `.so` 산출 모델 필요.
  - **종결 (2026-05-28)**: 구조 사실 재확인 — `@link("hxlayer")` FFI 경계(hxlayer.hexa:30,33)
    · 순수-hexa ref 존재(test_hxlayer.hexa:50) · bench `ratio=ref_ms/ffi_ms`(>1=hexa 느림).
    포팅은 등가 부재가 아니라 **285x ML 회귀**로 금지 = `feedback-closure-is-physical-limit`
    물리 바닥. codegen SIMD/GPU self-emit(B9.6) 도달 시에만 re-open.

### F2 — vendor / OS-ABI FFI (irreducible boundary)

- [x] **F2 vendor-ffi** — 🔴 **IRREDUCIBLE FFI/OS-ABI FLOOR TERMINAL**
      (closed-negative · audit #1809 · `.verdicts/runtime-floor-closure/F2-vendor-ffi.txt`)
  - crypto: `crypto_openssl.c` · `crypto_sodium.c`
  - CUDA/GPU: `hxblas_linux` · `hxccl_linux` · `hxlmhead_linux` · `hxqwen14b` ·
    `hxqwen32b` · `lora_cuda_host` · `gpu_codegen_stub`
  - syscall: `mount` · `namespace` · `net` · `pty` · `term_ffi` · `thread` ·
    `signal_flock` · `proc_fork` · `wait` · `exec_pipe` · `persistent_pipe`
  - 기타: `hxffi_slot` · `fp_init`
  - pure hexa 로 TLS/GPU/syscall 불가 — ABI 경계 필수.
  - **enabler**: hexa inline-svc/FFI emit (B9.3 svc surface) 이 syscall-shim 일부를
    닫을 수 있음. vendor blob(CUDA/openssl)은 영구 FFI 바닥(또는 hexa 가 직접 ABI
    emit 학습 시 흡수).
  - **종결 (2026-05-28)**: audit #1809 권위 분류 — 19 canonical layer-③ 파일 =
    "순수 로직이 없어 hexa 로 재작성할 대상 자체가 없음" → FFI 경계로 정당, C 유지.
    벤더 바이너리 ABI(CUDA/cuBLAS/NCCL/OpenBLAS/OpenSSL/libsodium) + 커널 syscall
    래퍼 + `fp_init`(② MXCSR/FPCR 제어레지스터 = hexa 표현 불가). svc/dlopen 경계 =
    north-star "zero .c, NOT zero asm" 의 @asm-floor 짝. #1674 multi-dylib·
    B2.ca-system closed-neg 와 동일 tier. **B9.3 svc-emit 는 runtime.c 내부 헬퍼
    (hexa_exec/term/host) 대상 — 이 standalone FFI 모듈과 직교**.
  - ⚠ **port-track 잔여 (floor 아님 → F3/layer-① 로 이관)**: `lora_cuda_host` 의
    CPU-reference 산술부 + `gpu_codegen_stub` 의 빈 contract 는 audit layer-① —
    FFI 경계가 아니라 codegen-self-emit/stdlib-flame 포팅 대상. F2 의 ③ 경계는
    terminal 이나 이 ① 비트들은 F3 campaign 으로 추적 (이중계상 방지).

### F3 — runtime FLOOR (codegen self-emit · 핵심)

- [ ] **F3 runtime-core** — `self/runtime.c` · `self/runtime_core.c` (640/548 fn)
      — 🟠 **THE SINGLE LIVE FLOOR FRONTIER** (genuinely-portable · multi-session ·
      NOT irreducible — F1/F2/F5/F6 terminal + F4 folded here, so F3 IS the only
      remaining `.hexa`-only blocker)
  - 파일 각 1개지만 **전 함수** codegen self-emit 후에야 삭제 가능.
  - 경로: B9.6a (HexaVal repr 생성자 emit · `rt_arena_*` 4-fn LANDED 패턴) →
    B9.6b (잔여 runtime primitive emit) → runtime.c dead.
  - 추정 **50-70 PR · expert serial** (#1812). regen+fixpoint · phase-h codegen
    에이전트와 경합 · **cold fan-out 부적합** (전담 신중 작업).
  - **enabler 입증 (2026-05-28 precheck · `.verdicts/runtime-floor-closure/F3-frontier.txt`)**:
    self-emit 패턴 LANDED — `self/codegen/runtime_arm64.hexa` 에 `rt_arena_init/
    alloc/reset/release` (L1157/1268/1339/1375) 포함 16 self-emit fn. dup-race
    precheck: codegen self-emit 작업 중인 open PR 0 (활성 브랜치는 전부 B9 flip
    quick-win/doc 트랙 — F3 와 직교). 각 단위 = emit-path 라 `gen1≡gen2` byte-eq
    fixpoint 검증 필수 (regen heavy → ubu route). F4 sha256 ① port (FIPS-검증된
    stdlib 타깃) 도 이 campaign 의 한 단위.
  - 🧱 **increment 1 LANDED — `rt_memset` self-emit (#1830)** (`runtime_arm64.hexa`
    확장 · 7-instr 28-B leaf byte-store loop · arena 패턴 답습). interp self-test
    PASS + `as -arch arm64` byte-identical + **JIT-exec 실제 memset 동작 검증**
    (fill range 정확 · no overrun · len=0 no-op · low-byte-only). shadow 모듈이라
    `hexa_cc.c` regen 무관 = fixpoint 무위험 · **`.c` 카운트 UNCHANGED** (640 fn
    전부 emit 후에야 파일 삭제 — 토대 1칸). **leaf-first 순서**: 다음 후보 =
    `rt_memcmp`/`rt_memmove` (동급 reloc-free 순수 루프) → reloc 필요한 state-bound
    primitive → **최후가 HexaVal repr/GC core (hard floor · B9.6a 본체 = 가장 위험)**.
    즉 B9.6a "HexaVal repr 생성자 emit" 은 leaf 들을 먼저 소진한 뒤 도달할 hard 단위.
  - 🧱 **increment 2 LANDED — 4 reloc-free leaf primitive self-emit (1 배치 가속)**
    (`runtime_arm64.hexa` 확장 · increment-1 의 단건 대신 동급 leaf 4종 한 번에):
    `rt_memcmp` (13-instr 52 B · byte 비교 루프) · `rt_memcpy` (8-instr 32 B · scalar
    forward copy · NEON 변형의 작은 fallback) · `rt_memmove` (16-instr 64 B · overlap-
    safe fwd/bwd) · `rt_strcmp` (12-instr 48 B · NUL-종단 비교). 전부 순수 register/
    memory 루프 — reloc 無 · `_arena_state` 無 · HexaVal/GC 無 (rt_memset 와 동급 leaf).
    3-layer 검증: interp self-test ALL CHECKS PASS + `as -arch arm64` 4종 byte-identical
    (파일 c.push 직접 대조) + JIT-exec 실제 동작 PASS (overlap memmove fwd/bwd, memcmp
    부호차, strcmp prefix 등). shadow 모듈이라 `hexa_cc.c` regen 무관 = fixpoint 무위험 ·
    **`.c` 카운트 UNCHANGED** (토대 누적). 이로써 self-emit 된 leaf = 6 (memset·str_len·
    memcmp·memcpy·memmove·strcmp) + arena 4-fn. **다음 후보**: reloc 필요한 state-bound
    primitive → **최후가 HexaVal repr/GC core (hard floor)**.
  - 🧱 **increment 3 LANDED — 5 reloc-free leaf string primitive self-emit**
    (`runtime_arm64.hexa` 확장 · increment-2 의 4종에 이어 동급 string leaf 5종 한 배치):
    `rt_strncmp` (14-instr 56 B · len OR NUL 종단 비교) · `rt_strchr` (11-instr 44 B ·
    첫 발생 위치 · 부재 시 NULL) · `rt_strrchr` (11-instr 44 B · 마지막 발생 위치) ·
    `rt_strcpy` (7-instr 28 B · NUL-종단 복사 · dst 반환) · `rt_strncpy` (14-instr 56 B ·
    bounded 복사 + NUL 패드 · 정확한 C semantics). 전부 순수 register/memory 루프 —
    reloc 無 · `_arena_state` 無 · HexaVal/GC 無 (rt_memset 와 동급 leaf). 3-layer 검증:
    interp self-test ALL CHECKS PASS (HEXA_VAL_ARENA=0) + `as -arch arm64` 5종 byte-identical
    (파일 c.push 자동 대조 스크립트) + JIT-exec 실제 동작 PASS (MAP_JIT + icache invalidate ·
    libc 레퍼런스 대조 · len0 no-op · NUL stop · strncpy 패드/절단 · 부재→NULL 엣지 포함).
    shadow 모듈이라 `compiler/main.hexa` 가 `use` 안 함 = `hexa_cc.c` regen 무관 = fixpoint
    무위험 · **`.c` 카운트 UNCHANGED** (토대 누적). 이로써 self-emit 된 leaf = 11 (memset·
    str_len·memcmp·memcpy·memmove·strcmp·strncmp·strchr·strrchr·strcpy·strncpy) + arena 4-fn
    = **15/640**. **다음 후보 (⚠ simple-leaf 공급 감소 신호)**: 남은 순수-루프 leaf 는
    `rt_strcat`(strlen+strcpy 합성) · bit-op(`clz`/`popcount`/byteswap) 정도로 줄어듦 →
    그 다음은 reloc 필요한 state-bound primitive → **최후가 HexaVal repr/GC core (hard floor)**.
  - 🧱 **increment 4 LANDED — final 5 simple-leaf primitive self-emit (EASY-PHASE 종료)**
    (`runtime_arm64.hexa` 확장 · increment-3 의 string leaf 에 이어 마지막 simple leaf 5종):
    `rt_strcat` (12-instr 48 B · strlen-scan + strcpy 합성 · dst 반환) · `rt_clz` (2-instr
    8 B · native CLZ · clz(0)=64) · `rt_ctz` (3-instr 12 B · RBIT+CLZ · ctz(0)=64) ·
    `rt_popcount` (5-instr 20 B · NEON CNT+ADDV 8-lane) · `rt_bswap` (2-instr 8 B · native
    REV · 64-bit 바이트 역순). 전부 순수 register/memory — reloc 無 · `_arena_state` 無 ·
    HexaVal/GC 無 (rt_memset 와 동급 leaf). 3-layer 검증: interp self-test ALL CHECKS PASS
    (HEXA_VAL_ARENA=0) + `as -arch arm64` 5종 byte-identical (파일 c.push 자동 대조 스크립트) +
    JIT-exec 실제 동작 PASS (MAP_JIT + icache invalidate · clz/ctz/popcount/bswap 다중 입력 +
    경계값 0 · strcat empty-src/dst 엣지 · libc 대조). shadow 모듈이라 `compiler/main.hexa` 가
    `use` 안 함 = `hexa_cc.c` regen 무관 = fixpoint 무위험 · **`.c` 카운트 UNCHANGED** (토대
    누적). 이로써 self-emit 된 leaf = 16 (memset·str_len·memcmp·memcpy·memmove·strcmp·strncmp·
    strchr·strrchr·strcpy·strncpy·strcat·clz·ctz·popcount·bswap) + arena 4-fn = **20/640**.
    이 배치로 **cold-batchable simple-leaf 공급 = 고갈** — 남은 후보 전수조사 결과 순수
    register/memory leaf 는 더 없음 (`hxlcl_strstr` 도 가능하나 nested-loop 한계효용 낮음 ·
    `hxlcl_strdup/strndup` 은 malloc 호출 = reloc-bound = HARD). **이 지점이 EASY/HARD
    phase boundary** — 아래 PHASE-BOUNDARY MAP 참조.
  - 🗺️ **PHASE-BOUNDARY MAP (F3 = EASY-phase DONE at 20/640 · HARD-phase = ~620 fn)**
    — easy-leaf phase 가 여기서 종료됨을 정밀 특정. 남은 ~620 primitive 는 **cold-batchable
    아님** (전담 expert + 신규 codegen 인프라 필요). 클래스별 분해 (대략치):
    - **(A) reloc-bound state primitive (~30-50 fn)** — `_arena_state` 류 module-global 을
      `adrp+add` PAGE21/PAGEOFF12 reloc 으로 참조하는 leaf. **reloc 방출/링크/실행 인프라 =
      COMPLETE + PROVEN** (2026-05-28 조사 — `macho_obj_wrap_v3`/`_v2` reloc 테이블 + `rt_arena_*`
      adrp+add placeholder + `poc_arena_reloc_caller.c` ld64 link+run rc=0). **실제 blocker =
      인프라 아님 · per-primitive PORT** (runtime.c reloc-bound composite → self-emittable leaf +
      그 global emit-side 정의). 상세 = 아래 **CLASS-A INFRA RUNBOOK**. cold fan-out 부적합.
    - **(B) call-bound composite (~60-100 fn) — 🟢 OPENED (B9.6-B1 `rt_atoi`)** — `hxlcl_strdup`/
      `strndup`/`atoll`/`strtoll` 처럼 다른 runtime fn(`malloc`·`atof`) 을 **call** 하는 비-leaf.
      호출 규약(stp/ldp frame + ARM64 AAPCS) + call-target BRANCH26 reloc 필요 — **둘 다 PROVEN**:
      `rt_atoi`(`(int)atoll(s)`) = FIRST 자기-emit composite (frame + `bl _hxlcl_atoll` + epilogue),
      ARM64_RELOC_BRANCH26 @0x08 against UNDEFINED-external callee, runtime.c 가 `HXLCL_ATOLL_SC`
      가드로 callee 를 EXPORT(non-static). 3-layer (byte-eq-as + JIT-exec 8/8 + live disasm bl 바인딩)
      + dual-build 3-mode PASS. **BRANCH26 cross-object 링크 = LC_SYMTAB only(NO LC_DYSYMTAB)** —
      #1475 macho.hexa "link-test pending" caveat RESOLVED. ⚠ frame 없으면 무한루프(ret↻bl) =
      frame 가 leaf↔composite 의 load-bearing 차이. 잔여 ~60-100 fn = 동일 frame+BRANCH26 템플릿
      스케일 (각 callee-export 1줄 추가 + multi-arg 는 인자 적재 명령만 prepend). cold fan-out 부적합.
    - **(C) syscall-bound I/O (~40-60 fn)** — fork/execvp/popen/fopen/read/write 래퍼. svc 패턴은
      LANDED + **arg+errno 템플릿 PROVEN** (`rt_exit`·`rt_arena_init` mmap · B9.6-C1 `rt_getpid`
      무인자 · **B9.6-C2 `rt_close` = 1-arg(fd)+carry-flag errno** — cset/cbz + adrp,errno/str
      reloc tail · JIT-exec success+error BOTH). read/write(3-arg) = 동일 `_cf` tail 재사용 ·
      잔여 어려운 형상 = struct-arg(stat/fstat) marshalling. 필요 인프라 Z = syscall-ABI struct marshalling.
    - **(D) HexaVal-repr 생성자/접근자 (~350-450 fn · HARD FLOOR 본체)** — `hexa_int`/`hexa_float`/
      `hexa_string`/`valstruct_*`/배열 ops 등 NaN-box repr 을 **생성·태깅·역참조** 하는 코어.
      B9.6a 의 진짜 본체이자 가장 위험한 단위 — repr 레이아웃 전체를 codegen 이 알아야 함.
    - **(E) GC/arena-coupled (~30-50 fn) — 🟢 OPENED (B9.6-E1 `rt_munmap`, dealloc subgroup)** —
      reclaim·arena lifecycle. ⚠ **classic mark/sweep GC 는 존재하지 않음** — 이 runtime 의
      memory mgmt = mmap-backed BUMP allocator(`hxlcl_malloc` never-free) + scope-pop/arena-reset
      reclaim. 서브그룹: **(b) dealloc** (`hxlcl_free`=no-op · `hxlcl_munmap`=const-0) = TRACTABLE
      leaf, munmap 이 JIT-verifiable(returns 0) → **첫 LIVE class-E wire** (arena emit set
      #1252/#1297/#1315 은 shadow-only · runtime 미-호출). **(c) alloc-core** (`hxlcl_malloc` =
      state-reloc + `bl hxlcl_mmap` + header store · `hexa_arena_alloc` = block-chain walk) =
      class-A+B+C COMPOSITE w/ branch logic → 단일 increment 불가 · multi-session expert
      (**B9.6-E2 MEASURED WALL** — clang -O2 시드 disasm 이 csel/ccmp/cmn · 2-distinct-global
      reloc · RA multi-pair spill · interleaved bl+multi-BB 요구 입증 · 44 proven emitter 中 0개
      제공 · `B9C-E2-alloc-core-wall.txt`). **(d)**
      malloc-coupled value ctor(`hexa_str`/`hexa_array_*`) = class-D 분할-3 와 중복(거기 deferred).
      **IRREDUCIBLE SEED (B9.8 terminal)**: bump allocator 자체 — self-host runtime 은 OS 메모리를
      carve 하는 SOME machine-code seed(mmap svc + bump ptr) 필요. emit 할 mark/sweep GC 가 없음.
    **요약**: easy-leaf phase = **DONE (20/640, 모두 byte-eq + JIT-exec 검증)**. hard phase =
    **~620 fn**, 5 클래스 (A reloc · B calling-conv · C syscall-ABI · D HexaVal-repr · E GC) —
    **5/5 클래스 모두 proven emitter 보유** (A arena-reloc · B rt_atoi · C rt_getpid/close ·
    D 6 ctor · E rt_munmap). 각 클래스의 첫 증분은 열렸으나 **나머지 본체는** 신규 per-fn 작업 +
    **cold-batchable 아님 · expert human-guided serial** (#1812 의 50-70 PR 추정과 정합).
    F3 의 [ ] 유지 근거 = 이 hard phase 가 실제 open 작업이기 때문.
  - **WHY [ ] 유지 (not over-closure)**: F3 는 irreducible 아님 — 실제 포팅 가능한
    open 작업. terminal verdict (🔵/🟢/🔴) 부여 불가 (= `feedback-no-over-closure`).
    단일 foreground 세션이 50-70 PR campaign 을 닫을 수 없음 = 정직한 multi-session
    잔여. floor doc 의 honest 종착 = F3 가 유일 open frontier 로 정밀 특정된 상태.

  - 🔑 **ACTIVATION RUNBOOK — self-emit primitive 를 LIVE runtime 에 실제 주입하는 법
    (2026-05-28 go/no-go 조사 · `rt_memset` 대상 · 결론 = BLOCKED → expert 인프라 필요)**

    **핵심 발견 — 왜 increment 1-4 가 전부 "`.c` UNCHANGED" 인가 (= shadow 의 정체)**:
    `self/codegen/runtime_arm64.hexa` 는 **어디서도 `use` 되지 않음** (전수 grep 확인 —
    참조처는 전부 `test/native_build/*` POC 의 코멘트 + byte 복사본뿐). `compiler/main.hexa`·
    빌드 레시피(`tool/build_hexa_cli.hexa`)·codegen(`self/codegen.hexa`) 어느 곳도 이 파일의
    `[int]` 바이트를 빌드 산출물에 **주입하는 경로가 0개**. 즉 increment 1-4 는 검증된
    machine-code 카탈로그를 쌓은 것이지, runtime 의 어떤 바이트도 교체하지 않았다 — 정직하게
    "토대" 일 뿐 활성화(activation)는 아직 시작도 안 됨. `rt_arena_*`(#1252/#1297/#1315)도
    동일 — `.o` emit+link+RUN POC(`poc_arena_bundle_emit.hexa` → rc=42)였을 뿐 `runtime.c`
    에서 `rt_arena_*` 호출처는 0개(grep 확인). **arena 도 활성화된 적 없음 · 동일 shadow 신분.**

    **LIVE runtime 이 memset 을 얻는 실제 경로 (3단계 C 메커니즘)**:
    1. compiled hexa 코드의 `memset()` 호출 → C 백엔드(`self/codegen.hexa` C-transpile,
       L947 `#include "runtime.c"`/`runtime.h`)가 `memset` 심볼로 emit.
    2. `runtime.c` L1505 `#define memset(p,c,n) hxlcl_memset(...)` → 모든 호출이
       `hxlcl_memset` 로 치환.
    3. `runtime.c` L301 `static void * __attribute__((noinline)) hxlcl_memset(...)` —
       **파일-로컬 static** 함수. clang 이 TU 내부 직접 호출로 컴파일. `runtime.c` +
       `runtime_core.c` 두 TU 가 각자 헤더 통해 자체 static 사본을 가짐(L3693 등).
    빌드: `clang -O2 main_native.c runtime.c -o driver` (build_hexa_cli.hexa L342) +
    `clang ... module_loader.c runtime.c` (L328) — `runtime.c` 가 일반 C TU 로 링크됨.

    **왜 link-level override 가 불가능한가 (= 진짜 BLOCKER)**:
    - `hxlcl_memset` 이 **`static`** 이라 외부 심볼이 아님 → hexa-emit `.o` 를 아무리 잘
      만들어 ahead-link 해도 linker 가 static 호출을 가로챌 수 없음.
    - `#define memset hxlcl_memset` 때문에 호출이 직접-호출로 박힘 → weak-symbol/PLT
      간접화 여지 없음.
    - "0 externs" freestanding 목표(B9.3/RFC 063)가 바로 이 static+`#define` 설계를
      강제 — libc `memset` extern 을 끌어오지 않으려는 의도이므로, 역으로 외부 `.o`
      주입 슬롯도 닫혀 있음.

    **활성화에 이미 LANDED 된 인프라 (재사용 가능 — 새로 만들 필요 없음)**:
    - `[int]` → linkable `.o`: `self/codegen/macho.hexa::macho_obj_wrap_v3`(N-text-symbol +
      `__const` + reloc) · `macho_obj_wrap_v3_rw`(R+W data). 검증됨(otool-clean · nm · link).
    - C 와의 link 패턴: `test/native_build/poc_rt_exit_caller.c` —
      `extern void hexa_main(long); ... clang caller.c /tmp/x.o -o run` → rc=42 PASS.
    - native linker: `tool/hexa_ld.hexa`(P1 scaffold · PAGE21/PAGEOFF12 reloc).
    - rt_memset ABI 적합성 확인: `strb w1,[x0,x3]` 루프가 x0 를 절대 수정 안 함 → `ret`
      시 x0=dst 그대로 → C `void* memset(void*,int,size_t)` 의 반환값 규약과 **호환 ✓**.

    **활성화 메커니즘 — 두 갈래 (둘 다 신규 작업 필요)**:

    *경로 A — 외부 심볼 + ahead-link (작은 인프라 · rt_memset 에 최적)*:
    1. `runtime.c`: `hxlcl_memset` 의 `static` 제거 + `#define memset hxlcl_memset` 를
       **약 심볼/조건부**로 — `#ifndef HEXA_RT_SELFEMIT` 가드. 동시에 `runtime_core.c`
       의 사본도 동일 처리(두 TU 모두 영향 · ⚠ runtime.c 는 WIPE-PRONE, regen 후 re-grep 필수).
    2. 신규 emit 드라이버 `test/native_build/emit_hxlcl_memset_o.hexa`: `rt_memset()` 바이트를
       `macho_obj_wrap` 로 감싸 심볼명 `_hxlcl_memset` (Mach-O underscore)로 export →
       `/tmp/hxlcl_memset.o`.
    3. 빌드 레시피에 step 추가: `HEXA_RT_SELFEMIT=1` 일 때 emit 드라이버 실행 →
       `.o` 산출 → `clang ... runtime.c hxlcl_memset.o -o driver` 로 ahead-link(또는
       `tool/hexa_ld.hexa` 로 순수-hexa link). external `_hxlcl_memset` 가 C 사본을 대체.
    4. ⚠ 함정: 두 TU(runtime.c + runtime_core.c)가 같은 external 심볼을 공유해야 함 →
       한 TU 만 non-static 로, 나머지는 extern 선언. 또는 양쪽 다 extern + 단일 `.o` 정의.
    5. **regen + fixpoint**: emit 드라이버는 `compiler/main.hexa` 가 `use` 하지 않으므로
       `hexa cc --regen`(hexa_cc.c 재생성)에 직접 영향 0 — 단 `runtime.c` 본문을 건드리면
       그 TU 를 링크하는 모든 바이너리가 재빌드되어야 함. fixpoint = `gen2.s ≡ gen3.s`
       byte-identical 재확인(`tool/fixpoint_compare.hexa`). ⚠ regen heavy → Mac OOM 시
       `pool on mini`(arm64) 로 offload · **ubu 는 arm64 byte-diff 산출 불가 → regen 금지**.

    *경로 B — call-site inline emit (큰 인프라 · 범용 D 클래스 대비)*:
    codegen 이 `memset` 호출을 만날 때 C `memset(...)` 대신 self-emit 바이트를 call-site 에
    직접 inline(또는 native 백엔드에서 `bl _rt_memset` + 번들된 text section). 이는
    `self/codegen.hexa` C-transpile 경로 + native 백엔드(`self/native_gen.c`) 양쪽에 신규
    emit 분기 필요 — HexaVal-repr(D 클래스) 활성화의 본체이기도 하므로, leaf 1개에 쓰기엔
    과대. rt_memset 활성화에는 경로 A 가 정답.

    **honest effort 추정 (경로 A · rt_memset 단건)**:
    - 인프라 신규: emit-`.o` 드라이버 1개(기존 POC 복제 · ~0.5d) + 빌드 레시피 step +
      `HEXA_RT_SELFEMIT` 가드 + 2-TU extern 정합 + regen/fixpoint 1 라운드. **~2-3d expert**,
      그 중 위험 구간 = (1) 2-TU static→extern 정합(runtime.c WIPE-prone), (2) freestanding
      "0 externs" 회귀(외부 심볼 추가가 0-extern 불변식을 깨는지 — `nm` 로 재확인), (3)
      ahead-link 순서가 모든 다운스트림 빌드(driver·module_loader·hexat)에 일관 적용.
    - 단, **첫 활성화는 템플릿이 됨** → 이후 leaf 활성화는 드라이버 복제 + 심볼명만 변경
      (~0.5d/개). 즉 경로 A 가 한 번 green 이면 16 easy-leaf 전부 빠르게 활성화 가능.

    **어떤 클래스를 unblock 하나**: 경로 A 활성화 템플릿은 **A(reloc-bound) 中 reloc-FREE
    leaf 전량 + 현 16 easy-leaf** 를 즉시 활성화 경로에 올림(self-emit→`.o`→ahead-link).
    reloc 필요한 state-bound(A 나머지)·call-bound(B)·syscall(C)·HexaVal(D)·GC(E)는
    경로 A 만으로 부족 — 각 클래스 인프라(reloc-emit 배선·calling-conv·syscall-ABI·repr
    layout·GC 통합)가 별도 선행. 즉 경로 A = **"link 슬롯을 여는" 토대 인프라**이고, 그
    위에 클래스별 emit 가 쌓임.

    **go/no-go 결론**: rt_memset 활성화는 **BOUNDED 하지만 새 인프라(경로 A) 필요 · 단일
    increment 로 force 하지 않음**. 이번 조사는 "shadow → live" 의 정확한 메커니즘·파일·
    위험·effort 를 특정해 expert 작업을 actionable build-plan 으로 전환함. 다음 expert
    increment = 경로 A 의 emit-`.o` 드라이버 + 2-TU extern 가드 + regen/fixpoint(1 PR).

    **✅ ACTIVATED (2026-05-28 · B9.6a-6 · 경로 A LANDED · #PR)** — rt_memset 가
    runtime 의 첫 LIVE-주입 primitive 가 됨. 정정: runtime_core.c 는 별도 TU 가 아니라
    runtime.c 에 `#include` 되는 단일 TU (runbook 의 "2-TU extern 정합" 위험은 미발생 —
    `#define memset` L1505 < `#include "runtime_core.c"` L1570 이므로 core 호출처도 동일
    `hxlcl_memset` 심볼로 resolve). 구현:
    - `self/runtime.c`: `hxlcl_memset` 를 `#ifdef HEXA_RT_SELFEMIT` 가드. **default
      (가드 off) = 기존 `static` 정의 그대로** (0-libc-extern 불변식 보존 · OPT-IN);
      가드 on = `extern` 선언 (body 無) → `.o` 가 심볼 제공.
    - `test/native_build/emit_hxlcl_memset_o.hexa`: rt_memset 의 28 self-emit 바이트를
      `macho_obj_wrap` 로 감싸 strong external `_hxlcl_memset` (13 B · strtab 1+13) export.
      (검증된 `poc_rt_exit_obj_emit.hexa`/`emit_hexa_exit_native_o.hexa` 템플릿 복제 —
      심볼명·바이트만 변경).
    - `tool/build_hexa_cli.hexa`: `HEXA_RT_SELFEMIT=1` 시 emit 드라이버(default-runtime
      로 빌드) → `.o` 산출 → driver + module_loader 양쪽 ahead-link.
    - **dual-build 증거 (mini · arm64 macOS · 실제 빌드 레시피 산출 `hexa_module_loader`)**:
      (a) default — `_hxlcl_memset` = local `t` · undefined(libc-extern) set = 55 ·
          origin/main baseline 과 **byte-identical (diff IDENTICAL)** → 0-extern 보존.
      (b) HEXA_RT_SELFEMIT=1 — `_hxlcl_memset` = strong `T` (self-emit `.o` 에서 resolve) ·
          live 바이너리 disasm = rt_memset 28-B 루프 정확 일치 · undefined set = **55 동일**
          (diff IDENTICAL) · flatten 출력 default 와 **byte-identical**.
      (driver 바이너리는 fresh-clone stale-hexat `float_to_bits`/`os_getuid` 미선언으로
      compile 실패 — origin/main 에서도 **동일 재현** = 본 변경과 무관한 선재 이슈.
      module_loader 가 runtime.c 를 동일하게 링크 → 동등 증명 surface.)
    - **fixpoint 무위험**: emit 드라이버는 `compiler/main.hexa` `use` 0 (grep 확인) →
      `hexa_cc.c` regen 무관. runtime.c diff = 순수 가드 추가 (deletion 0) → default
      regen surface 불변.
    - `.c` 카운트는 아직 안 줄어듦 (runtime.c 에 639 primitive 잔존) — 단 **활성화
      템플릿이 입증됨**: 이후 leaf 활성화 = emit 드라이버 복제 + 심볼명 변경 (~0.5d/개).

    **✅✅ BATCH-ACTIVATED (2026-05-28 · B9.6a-7 · Path-A 템플릿 스케일아웃 · #PR)** —
    rt_memset 단건(#1836)에서 입증된 Path-A 템플릿을 reloc-free leaf 전량에 일괄 적용.
    **11 추가 활성화** → 총 **12/640 LIVE-주입** (memset + memcmp · memcpy · memmove ·
    strcmp · strncmp · strchr · strrchr · strcpy · strncpy · strcat · strlen).
    - **활성화 11 (각 `hxlcl_<name>` C 사본을 self-emit 바이트로 link-override)**:
      memcmp(52B) · memcpy(32B) · memmove(64B) · strcmp(48B) · strncmp(56B) ·
      strchr(44B) · strrchr(44B) · strcpy(28B) · strncpy(56B) · strcat(48B) ·
      strlen(44B · `rt_str_len` → C `hxlcl_strlen`, 심볼명만 상이).
    - **SKIP 4 (C 카운터파트 부재 → 활성화 대상 자체가 없음, force 안 함)**:
      `rt_clz`·`rt_ctz`·`rt_bswap` = runtime.c 에 `hxlcl_*` 명명 함수 0개 (override 슬롯
      없음); `rt_popcount` = `__builtin_popcountll` 인라인(L6486)만 존재 · 명명된
      `hxlcl_popcount` 심볼 없음 → ld override 불가. (이들은 활성화할 C 대상이 없어
      SKIP — shadow 카탈로그로 잔류.)
    - **ABI 검증 (각 leaf 별 레지스터 규약 = C 시그니처 일치 · mismatch 0)**: 전 leaf
      x0..x2 인자 순서 일치 · 반환 x0/w0 일치 (memcpy/memmove/strcpy/strncpy/strcat 는
      x0=dst 절대 미변경 → C `void*/char*` 반환규약 ✓ · memcmp/strcmp/strncmp 는 w0
      signed-diff ✓ · strchr/strrchr 는 x0=ptr/NULL ✓ · strlen 은 x0=len ✓). caveat
      (정직): (i) strchr/strrchr 는 NULL-입력 가드 없음 (C strchr(NULL) = UB → 비-NULL
      호출 byte-identical); (ii) memmove 는 `dst<=src` 분기(C 본문 `dst<src`) — dst==src
      에서 forward no-op copy = 출력 동일. 둘 다 활성화 진행(실 호출 동작 동일).
    - **dual-build 증거 (mini · arm64 macOS · 실제 빌드 레시피 산출 driver + module_loader)**:
      (a) default (가드 off) — 12 `hxlcl_*` 전부 local `t` · undefined(libc-extern) set =
          driver 58 / module_loader 56 · **origin/main baseline 과 byte-identical
          (diff IDENTICAL · 양 바이너리)** → 0-extern 불변식 보존.
      (b) HEXA_RT_SELFEMIT=1 — 12 `_hxlcl_*` 전부 strong `T` (self-emit `.o` 12개에서
          resolve) · BUILD OK + smoke 3/3 PASS (--version · parse · build round-trip) ·
          guarded driver 가 실 소스 250-line 파일 parse rc=0 · LIVE disasm spot-check
          (memset 7-instr · strrchr 11-instr · memcmp subs+2-ret) = self-emit 소스 바이트
          정확 일치.
      추가 standalone 오라클 (`test/native_build/poc_hxlcl_leaves_caller.c`) = 11 self-emit
      `.o` ahead-link 후 libc ground-truth 대비 전 케이스 PASS (rc=0).
    - **빌드 레시피 정정**: selfemit emit 블록을 step 0(hexat bootstrap) **이후**로 이동
      (emit 에 hexat 필요 · `-DHEXA_RT_SELFEMIT` 는 hexat 빌드엔 미적용 → 부트스트랩
      트랜스파일러는 default static 런타임으로 빌드). #1836 의 단건 블록 = 12-leaf 루프로
      일반화 + 이동 (refactor · 무삭제).
    - **fixpoint 무위험**: 11 emit 드라이버 전부 `compiler/main.hexa` `use` 0 (grep 확인) →
      `hexa_cc.c` regen 무관. runtime.c diff = 순수 가드 추가 (deletion 0).
    - `.c` 카운트는 여전히 안 줄어듦 (runtime.c 가 나머지 primitive 보유) — 활성화는
      default-off OPT-IN 가드라 freestanding 산출물 불변. 다음 = state-bound(reloc 필요)
      leaf 활성화 (Path-A 만으로 부족 · reloc-emit 배선 선행).

  - 🔑 **CLASS-A INFRA RUNBOOK — reloc-bound state primitive frontier
    (2026-05-28 go/no-go 조사 · 결론 = **reloc 인프라 PROVEN · 실제 blocker 는 per-primitive PORT**)**

    **조사 결과 — reloc 방출 인프라는 이미 COMPLETE 이고 end-to-end PROVEN 이다 (NOT blocker)**:
    PHASE-BOUNDARY MAP 의 (A) class 가 "각 신규 global 마다 reloc 레코드 짝 수동 배선 필요 ·
    cold fan-out 부적합" 으로 적혔으나, 실측 결과 **reloc 방출/링크/실행 경로 전체가 LANDED 이고
    이번 조사에서 실제로 link+run 으로 입증됨**. 정정 사항:
    - `self/codegen/macho.hexa::macho_obj_wrap_v3` (L470) 는 이미 **완전한 reloc 테이블**을 방출:
      N text symbol + undefined external(`s_section==0` = N_UNDF) + `__const` data + 3 reloc kind
      (PAGE21=3 · PAGEOFF12=4 · BRANCH26=2). 자매 `macho_obj_wrap_v3_rw` (L703) 는 R+W `__DATA`.
      `macho_obj_wrap_v2` (L206) 가 PAGE21/PAGEOFF12 2-reloc 의 첫 형태. `reloff/nreloc` 가
      section_64 에 채워지고 `relocation_info` 8-B 레코드가 정확히 emit 됨 (L614-642).
    - `self/codegen/runtime_arm64.hexa::rt_arena_*` (L2237/2348/2419/2455) 4-fn 은 이미 각자
      `adrp x9, _arena_state@PAGE` + `add x9, x9, _arena_state@PAGEOFF` (PAGE21/PAGEOFF12)
      placeholder 를 방출 — class-A 의 정의 그 자체 (module-global 을 adrp+add reloc 으로 참조).
    - `tool/hexa_ld.hexa` (L800+ · PR #1282) 는 PAGE21/PAGEOFF12 immediate patch 를 적용.
    - **end-to-end 입증 (2026-05-28 · mini arm64 macOS)**: `poc_arena_bundle_emit.hexa` →
      `/tmp/poc_arena_bundle.o` (863 B · `otool -rv` = 10 PAGE21/PAGEOFF12 records → `_arena_state` ·
      `nm -u` = **undefined 0개** = 0-extran 보존) → 신규 오라클
      `test/native_build/poc_arena_reloc_caller.c` 가 ld64 link (exit 0) + **RUN rc=0**.
      4 reloc-bound arena primitive 가 `_arena_state` 를 정확히 resolve (bump delta=16 ·
      reset 후 realloc==first · overflow→NULL · release 후 re-init OK). reloc 가 틀렸다면
      adrp+add 가 stale 주소를 계산해 invariant 가 깨지거나 SIGSEGV — rc=0 = reloc 정확.
      이는 byte-emit POC 가 입증 못 하던 부분(ld64 가 reloc 를 PATCH 함)을 committed 오라클로 고정.

    **그럼 실제 class-A blocker 는 무엇인가 — PORT, not 인프라**:
    reloc-FREE leaf 활성화(#1836/#1837)가 쉬웠던 이유 = runtime.c 에 명명된 `hxlcl_<name>`
    static 함수가 있어 `#ifdef HEXA_RT_SELFEMIT` → extern 가드만 추가하면 self-emit `.o` 가
    심볼을 대체. class-A 는 이 활성화 슬롯 조건을 **둘 다** 만족하는 runtime.c primitive 가 희소:
    - (a) reloc-bound (global 을 adrp+add 로 참조) **AND** (b) 명명된 `hxlcl_*` override 슬롯 ·
      clean leaf (struct ABI/malloc/HexaVal 無).
    - 실측: runtime.c 의 깨끗한 class-A 후보 `_arena_state`(arena) 는 **runtime.c 에 호출처 0개**
      (grep — shadow POC 일 뿐 live 미배선). 반대로 runtime.c 에서 global 을 참조하는 명명 함수
      (`gmtime_r`+`mdays[12]` table L2073 · base64 `_b64_enc` L12067) 는 전부 **class-B/D
      composite** — `struct tm` 필드 stores · `malloc` · HexaVal 접근 = clean leaf 아님.
      `hxlcl_errno` (L75) 는 `#define errno hxlcl_errno` 인라인 치환이라 wrapper 함수 슬롯 없음.
    - 즉 class-A 의 남은 일 = **runtime.c 의 reloc-bound composite 를 self-emittable leaf 로
      재작성하는 PORT** (그 함수가 참조하는 global 을 self-emit `.o` 가 `__const`/`__DATA` 로
      정의 + reloc 으로 묶기 + runtime.c 가 그 global 을 double-define 하지 않도록 가드).
      이건 cold fan-out 부적합 = 함수별 신중 PORT (expert serial).

    **bounded 첫 increment (이번 LANDED)**: arena 는 호출처가 없어 활성화해도 dead-symbol →
    인위적이므로 force 안 함 (honest). 대신 **class-A reloc 경로를 committed 오라클로 고정** —
    arena reloc 감사(`test/native_build/arena_reloc_audit.md`)의 "verification PLAN" 을
    재현 가능한 PASS 로 전환. `poc_arena_reloc_caller.c` 1 파일 + 이 runbook (runtime.c 무변경 ·
    0-extern 중립 · regen/fixpoint 무위험). 이로써 class-A 가 "needs infra" → **"infra DONE,
    needs PORT"** 으로 정밀 재분류됨.

    **class-A PORT 단위 레시피 (per-primitive · expert serial)** — 첫 실제 활성화 대상이
    생기면 (= reloc-bound clean-leaf 슬롯을 가진 runtime.c 함수를 식별/생성하면):
    1. **runtime.c 가드**: 대상 `hxlcl_<name>` static → `#ifdef HEXA_RT_SELFEMIT extern …`
       (#1836 memset 템플릿 그대로). ⚠ 그 함수가 참조하는 global(`<sym>`)도 동일 가드 —
       guard ON 일 때 runtime.c 는 `<sym>` 을 정의하지 않고 `.o` 가 `__DATA`/`__const` 로 정의
       (double-define = ld64 duplicate symbol). ⚠ runtime.c WIPE-PRONE · regen 후 re-grep.
    2. **emit 드라이버** `test/native_build/emit_hxlcl_<name>_o.hexa`: rt_<name>() self-emit
       바이트 (adrp+add placeholder 포함) 를 `macho_obj_wrap_v3` (또는 R+W global 이면
       `_v3_rw`) 로 감싸 — text symbol `_hxlcl_<name>` + data symbol `_<sym>` + PAGE21/PAGEOFF12
       reloc 레코드 (reloc_offs/kinds/symnums 배선). `poc_arena_bundle_emit.hexa` 가 정확한
       템플릿 (5 ADRP+ADD pair · symnum→data idx). reloc-FREE 드라이버(`emit_hxlcl_memset_o.hexa`)는
       v1 single-symbol 이라 reloc 미지원 → v3 로 전환 필요.
    3. **빌드 레시피** `tool/build_hexa_cli.hexa` L333 selfemit 블록: 새 leaf 를 `leaves`/`upper`
       배열에 추가 (이미 12개 reloc-free 가 등록된 동일 루프). reloc `.o` 도 같은 ahead-link 슬롯
       (`selfemit_objs`) 으로 driver+module_loader 양쪽 링크 — clang 이 reloc `.o` 를 동일 수용
       (위 입증). global 이 R+W 면 `.o` 가 `__DATA` 정의 = runtime 시작 시 zero-init 필요 여부 확인.
    4. **dual-build 검증** (#1837 패턴): (a) default(가드 off) — `nm` undefined set =
       origin/main baseline byte-identical (0-extern 보존) · (b) HEXA_RT_SELFEMIT=1 —
       `_hxlcl_<name>` = strong `T` · `_<sym>` 정의 1곳뿐 (duplicate 無) · live disasm =
       adrp+add 가 reloc 으로 patch 된 immediate · LIVE 호출 동작 = libc 오라클 동일.
    5. **fixpoint 무위험** (emit 드라이버 `use` 0 = `hexa_cc.c` regen 무관 · #1836).
       ⚠ regen heavy → `pool on mini` (arm64) · ubu 는 arm64 byte-diff 불가.

    **인프라 컴포넌트 — 보유(✓) vs 부족(✗)**:
    - ✓ ADRP+ADD (PAGE21/PAGEOFF12) 명령 인코딩 — `rt_arena_*` 에 LANDED + placeholder 패턴.
    - ✓ Mach-O reloc 레코드 (PAGE21/PAGEOFF12/BRANCH26) — `macho_obj_wrap_v3`/`_v2` L614-642.
    - ✓ symtab + undefined-extern (N_UNDF) + `__const`/`__DATA` data section — v3/v3_rw.
    - ✓ ld64 link + run-time patch 입증 — `poc_arena_reloc_caller.c` rc=0.
    - ✓ hexa-native linker reloc patch — `tool/hexa_ld.hexa` PR #1282 (PAGE21/PAGEOFF12).
    - ✗ (남은 일) per-primitive PORT — runtime.c reloc-bound composite → self-emittable leaf +
      그 global 의 emit-side 정의 + double-define 가드. **인프라 부족이 아님 = 함수별 재작성 노동.**
    - ⚠ (class-B 한정 caveat · class-A 무관) BRANCH26 cross-object `bl` 은 ld64 가 LC_DYSYMTAB
      을 요구할 수 있음 (macho.hexa L452 주석) — 현재 LC_SYMTAB only. class-A 의 PAGE21/PAGEOFF12
      defined-symbol reloc 은 DYSYMTAB 불필요 (위 link exit 0 = 무문제). DYSYMTAB 은 (B) call-bound
      선행조건.

    **effort 추정 (class-A 전체 ~30-50 fn)**: 인프라 = **0d (DONE+PROVEN)**. 첫 실제 PORT 단위
    (reloc-bound clean-leaf 슬롯 식별/생성 + 1-PR 활성화) ≈ **1-2d expert** (대부분 = 대상 함수의
    self-emit 바이트 작성 + global double-define 가드 검수). 이후 동급 PORT ≈ 0.5-1d/개. 단,
    runtime.c 의 reloc-bound 함수 대부분이 class-B/D composite 라 **순수 class-A clean-leaf 모수는
    작음** — 실제로는 (A) 의 다수가 (D) HexaVal-repr 활성화와 함께 풀리는 경향 (repr global +
    state global 이 얽힘). honest: class-A 의 reloc 인프라는 끝났고, 남은 건 PORT 인데 그 PORT 가
    대개 (D) 와 결합 → class-A 단독 bounded PR 의 모수는 arena(dead) 외엔 희소.

    **go/no-go 결론**: reloc 인프라는 **PROVEN** (force 불필요). 이번 bounded LANDED =
    class-A reloc 경로의 committed link+run 오라클 (`poc_arena_reloc_caller.c`). class-A 를
    "needs reloc infra" → **"infra DONE + PROVEN · 남은 건 per-primitive PORT (대개 D 와 결합)"**
    으로 정밀 재분류. 다음 expert increment = runtime.c 의 reloc-bound clean-leaf 슬롯을 식별/생성
    (또는 arena 를 live 배선) 후 위 5-step PORT 레시피로 1-PR 활성화.

  - 🔑 **CLASS-D RECIPE — HexaVal-repr 생성자/접근자 frontier (~350-450 fn · HARD FLOOR 본체)
    (2026-05-28 go/no-go 조사 · 결론 = **단일-increment self-emit 불가 · 경로 B(call-site
    inline emit) 본체 인프라 선행 · "~350-450 vague" → 아래 구조적 sub-plan 으로 특정**)**

    **핵심 발견 ① — LIVE runtime 의 HexaVal 은 NaN-box 가 아니라 16-byte tagged-union struct**:
    조사 전제(미션)는 "NaN-boxed 64-bit value · `hexa_int`/`hexa_tag` 가 shift/mask pure bit-op"
    였으나, **실제 live repr 은 그렇지 않다.** `self/runtime.h` L79-92 의 `HexaVal` =
    `struct { HexaTag tag; union { int64_t i; double f; int b; char* s; HexaArr* …; }; }` —
    `sizeof(HexaVal) == 16` (4-B enum tag + 4-B pad + 8-B union; clang `/tmp/sz` 실측). 접근은
    전부 **struct 필드 access** (`HX_TAG(v)=(v).tag` · `HX_INT(v)=(v).i` · `HX_STR(v)=(v).s`,
    runtime.h L151-163 매크로) — shift/mask 가 아님.
    - **NaN-box 는 design-only · 미배선**: `self/hexa_nanbox.h` (229 L · `typedef uint64_t HexaV`)
      에 진짜 NaN-box (`hexa_nb_int32`/`hexa_nb_tag`/`hexa_nb_kind`/`hexa_nb_as_*` · 28 `static
      inline`) 가 있으나, 파일 헤더 L4-6 가 명시: **"NOT yet wired into runtime.c — encoding
      specification ... to be adopted in rt#38-B"**. L51-54: "rt#38-B will redefine
      `typedef uint64_t HexaVal;` ... ~2100 sites across 6 C files". 즉 NaN-box 전환(rt#38)은
      **별도 미착수 multi-session 리팩터**이고, F3 의 현 class-D 는 **struct repr** 을 대상으로 함.
    - **함의**: 미션이 가정한 "pure-bitop class-D leaf" (`hexa_tag` shift/mask 등) 는 **현
      코드베이스에 존재하지 않는다**. NaN-box 의 `hexa_nb_tag`(`(v&MASK)>>47`) 가 그 형태지만
      header-only `static inline` (named external symbol 0개 · §아래 ③) + 미배선이라 활성화 슬롯이
      애초에 없음. struct repr 의 `HX_TAG` 도 매크로(함수 아님) → 동일하게 슬롯 없음.

    **핵심 발견 ② — class-D 의 "가장 단순한" primitive 도 struct-return 라 leaf-ABI 와 단절**:
    가장 단순한 class-D 후보 = `hexa_int`/`hexa_float`/`hexa_bool`/`hexa_void` (runtime_core.c
    L1281-1284 · 각 1-line `return (HexaVal){.tag=…, .i=…};`). 이들은 **외부 심볼**(`static`
    아님 → 활성화 슬롯 ✓) 이지만 **16-byte struct 를 값으로 반환** → ARM64 AAPCS 에서 `x0:x1`
    **레지스터 페어** 반환 (clang `-S` 실측: `hexa_int` = `mov x1, x0` / `mov x0, #0` / `ret`
    — x0=tag, x1=payload). 이는 현 self-emit leaf 16종의 ABI (단일 x0 반환)와 **근본적으로 다른
    호출 규약**. self-emit 카탈로그(`self/codegen/runtime_arm64.hexa` · 30 `fn rt_*`) 의 **모든**
    함수가 코멘트에 "**no HexaVal touch**" 로 명시 — struct-return 또는 HexaVal-aware emit 은
    **카탈로그에 1개도 없음**. 즉 가장 단순한 class-D 조차 신규 emit capability 필요.

    **핵심 발견 ③ — class-D 활성화 슬롯 분류 (named-external vs inline-only)**:
    Path-A (link-override) 는 ① 명명된 external 심볼 + ② self-emittable 바이트 둘 다 필요. class-D 는
    슬롯 유형이 갈림:
    - **(D-ctor) 생성자 = 명명 external 함수 ✓ 슬롯 있음** — `hexa_int`/`hexa_float`/`hexa_bool`/
      `hexa_void`/`hexa_str`/`hexa_enum_str`/`hexa_array_new`/… (runtime_core.c 에 `HexaVal
      hexa_*(…)` 정의). Path-A link-override 슬롯은 **열려 있으나** struct-return ABI emit
      (x0:x1 페어 + tag 상수 + payload 배치) 인프라가 self-emit 카탈로그에 부재 (발견 ②).
    - **(D-accessor) 접근자/술어 = 매크로 inline-only ✗ 슬롯 없음** — `HX_TAG`/`HX_INT`/`HX_STR`/
      `HX_IS_INT`/`HX_IS_STR`/… (runtime.h L151-163 `#define`) 는 **명명 함수 0개** → ld
      override 불가 (rt_popcount/`__builtin_*` inline 과 동일 신분, B9.6a-7 SKIP 4 와 동류).
      이들은 **경로 B (call-site inline emit) 로만** 활성화 가능 — codegen 이 `(v).tag` field
      load 를 self-emit 바이트로 직접 방출. NaN-box `hexa_nb_*` 도 전부 `static inline` →
      동일하게 inline-only.
    - **(D-deref) 역참조/복합 = struct-ABI + heap 결합** — `hexa_str`(intern + strdup) ·
      `hexa_array_push`(realloc) · `valstruct_*`(malloc + field stores) · `hexa_struct_pack_map`
      등은 struct-return **AND** malloc/arena/deref → class-B(call-bound)·E(GC) 와 결합 = 가장
      깊음.

    **pure-bitop vs alloc-coupled 분할 (struct repr 기준 · 미션 축 재정의)**:
    미션의 "pure-bitop vs alloc-coupled" 축은 NaN-box 전제였으나, struct repr 에서는 아래로 재맵:
    - **(분할 1) struct-build, no-alloc** (~10-20 fn) — `hexa_int`/`hexa_float`/`hexa_bool`/
      `hexa_void`/`hexa_char`/`hexa_enum_str` 등. malloc/deref 無 · 순수 16-B struct compose.
      **이론상 가장 단순하나** struct-return ABI emit 필요 (발견 ②) → leaf-ABI 와 단절.
    - **(분할 2) field-load 접근자** (~30-50 fn 상당의 매크로) — `HX_TAG`/`HX_INT`/`HX_IS_*`.
      `(v).tag` 단일 필드 load + (술어면) compare. **연산 자체는 사소**하나 inline-only(슬롯 ✗)
      라 경로 B 만 가능.
    - **(분할 3) alloc-coupled** (~300-400 fn · 본체) — `hexa_str`/`hexa_array_*`/`valstruct_*`/
      map ops. struct-return + malloc/arena/realloc/deref → class-B/E 와 얽힘 = 최후.

    **inline-vs-link 판정 (per-class-D)**:
    - 생성자(D-ctor): **link-override 가능 (슬롯 ✓)** 단 struct-return emit 인프라 선행. 경로 A
      변형 (struct-ABI 지원 추가) 또는 경로 B 둘 다 후보.
    - 접근자/술어(D-accessor): **link-override 불가 (매크로 · 슬롯 ✗) → 경로 B 전용**.
    - 복합/역참조(D-deref): **경로 B + class-B/E 인프라** (calling-conv + GC) 동시 선행.

    **왜 단일 foreground increment 로 self-emit/activate 불가 (honest no-go)**:
    1. **struct-return ABI emit 부재** — self-emit 카탈로그에 16-B struct 를 x0:x1 로 구성/반환하는
       emit 가 0개. 가장 단순한 `hexa_int` 조차 이 신규 capability 없이 바이트를 못 만든다.
    2. **접근자는 매크로 → 활성화 슬롯 자체가 없음** — Path-A(link-override)가 원천 불가, 경로 B
       (call-site inline emit · codegen C-transpile + native 백엔드 양쪽 신규 분기 · RUNTIME.floor.md
       경로 B 항목 L251-256) 의 본체 인프라가 선행. 이는 "큰 인프라" 로 이미 분류됨.
    3. **repr 레이아웃 전체를 codegen 이 알아야** (PHASE-BOUNDARY MAP L177) — tag enum 값 · union
       오프셋 · struct 크기를 emit 측이 hard-code → repr 변경(rt#38 NaN-box 전환)과 충돌 위험.
       NaN-box 전환이 선행되면 class-D 가 pure-bitop leaf 로 붕괴(미션 가정이 그제서야 성립)하므로,
       **class-D 의 올바른 순서 = rt#38 NaN-box 전환을 먼저 평가** (struct repr 에 self-emit 를
       박으면 rt#38 때 전량 폐기). 이것이 class-D 를 "가장 마지막 · 가장 위험" 으로 두는 진짜 이유.

    **per-primitive effort 추정 (class-D)**:
    - **인프라 선행 (공통)**: struct-return ABI emit (경로 A 변형) 또는 call-site inline emit
      (경로 B 본체) — codegen C-transpile + native 백엔드 양쪽 신규 emit 분기. **~1-2주 expert**
      (B9.6a 본체 · 가장 위험). 또는 **rt#38 NaN-box 전환 선평가** (~2100 site · multi-session)
      후 class-D 가 pure-bitop leaf 로 단순화되면 재평가.
    - **인프라 후 (분할 1 생성자)**: ~10-20 fn · 인프라 green 후 각 ~0.5-1d (tag 상수 + payload
      배치만 상이).
    - **(분할 2 접근자)**: ~30-50 매크로 · 경로 B inline emit green 후 각 ~0.3d (단일 field load).
    - **(분할 3 alloc-coupled)**: ~300-400 fn · class-B(calling-conv) + class-E(GC) 인프라
      **동시** 선행 → class-D 단독 추정 무의미 (얽힘) · #1812 의 50-70 PR 추정의 본체.

    **go/no-go 결론**: class-D self-emit/activate 는 **단일 increment 로 force 불가** (honest
    no-go). 이유 = (1) 가장 단순한 생성자도 struct-return ABI emit 부재, (2) 접근자는 매크로라
    link-override 슬롯 없음(경로 B 본체 선행), (3) repr-layout coupling 이 rt#38 NaN-box 전환과
    충돌 — class-D 의 올바른 첫 수순은 **rt#38 (struct→NaN-box uint64) 전환을 먼저 평가**해
    pure-bitop leaf 로 단순화할지 결정하는 것. 이번 조사는 "~350-450 vague" 를 **3-분할
    (struct-build / field-load / alloc-coupled) + inline-vs-link 판정 + rt#38 선행 의존성** 의
    구조적 sub-plan 으로 특정함. runtime.c 무변경 · 0-extern 중립 · regen/fixpoint 무위험 (doc-only).

    **✅✅✅ class-D FIRST INCREMENT ACTIVATED (2026-05-28 · B9.6 · struct-return EMITTER landed · #PR)**:
    위 no-go 의 **이유 (1)** (struct-return ABI emit 부재) 가 이 PR 로 **해소됨**. self-emit 카탈로그에
    16-byte HexaVal 을 `x0:x1` 레지스터-페어로 구성/반환하는 **첫 struct-return emitter** 가 생겼고,
    분할-1(struct-build, no-alloc)의 가장 단순한 3 생성자가 LIVE-주입됨:
    - **신규 emitter 3** (`self/codegen/runtime_arm64.hexa`, 각 3-instr 12-B leaf):
      `rt_hexa_void` (`mov w0,#4 · mov x1,#0 · ret`) · `rt_hexa_int` (`mov x1,x0 · mov x0,#0 · ret`) ·
      `rt_hexa_bool` (`mov w1,w0 · mov w0,#2 · ret`). x0 = tag(low 8B) · x1 = union value(high 8B) =
      AAPCS NRRP (≤16B → x8 hidden-ptr 無). 이전 16 leaf 전부 단일-x0 반환 → **x1 을 세팅하는 첫 leaf**.
    - **ABI 검증 3-layer (JIT-exec 게이트가 load-bearing)**:
      ① interp self-test — size/align/RET/시그니처-바이트 ALL CHECKS PASS.
      ② **byte-identical to `as -arch arm64`** — 3 ctor 모두 어셈블러 출력과 바이트 동일 (`/tmp/verify_byteeq.hexa`).
      ③ **JIT-exec correctness** — 멀티심볼 `.o`(`emit_hexa_val_ctors_o.hexa` → `_hexa_void/_hexa_int/
      _hexa_bool`) 를 실 C 드라이버에 링크 → 반환된 `{tag,value}` 가 전 입력(INT64_MIN/MAX·bool 0/1 포함)
      에서 정확히 read-back. **x0:x1 struct-return ABI 가 런타임에서 정확함을 증명** (단순 byte-eq 가 아닌
      실제 호출-반환 검증). 이것이 "wrong struct-return 가 모든 HexaVal ctor 를 miscompile" 위험의 게이트.
    - **Path-A 활성화 (dual-build · #1837 패턴)**: `self/runtime_core.c` L1281-1284 의 `hexa_int`/
      `hexa_bool`/`hexa_void` 를 `#ifdef HEXA_RT_SELFEMIT extern / #else 본체 #endif` 가드로 감쌈
      (`hexa_float` 는 FP-arg `fmov x1,d0` 경로라 별도 increment 로 잔류). `tool/build_hexa_cli.hexa`
      가 HEXA_RT_SELFEMIT=1 일 때 멀티심볼 `.o` 를 emit+ahead-link. **3-mode 실측 PASS**: (a) default
      (가드 off) = C 본체·`.o` 불요·0-extern 보존, (b) 가드 on + `.o` = extern 이 self-emit `.o` 로 resolve·
      struct 정확, (c) 가드 on **without** `.o` = undefined-symbol link-fail (extern 이 진짜임을 증명).
    - **남은 no-go 이유**: (2) 접근자 매크로(경로 B 본체) · (3) repr-layout/rt#38 coupling 은 그대로 open.
      분할-1 의 잔여 생성자(`hexa_char`/`hexa_enum_str`/… ~10-17 fn)는 이제 동일 struct-return 템플릿으로
      스케일아웃 가능 (인프라 green). 즉 **class-D 의 struct-build 서브트랙은 단일-increment no-go → 템플릿
      열림** 으로 전환. .c count 불변(87) — 가드 off default 가 SSOT, runtime.c 의 eventual git-rm 을 향한
      FLOOR 인프라 (per-file drop 아님).

    **✅✅✅✅ B9.6-D2 — class-D struct-build SCALE-OUT (2026-05-28 · #1858 템플릿 스케일아웃 · #PR)**:
    #1858 의 struct-return EMITTER 인프라 위로 **분할-1 의 3 생성자 추가 ACTIVATED** (struct-build,
    no-alloc 총 **6/6** = `hexa_void/int/bool` + `hexa_float/enum_str/enum_str_v`). class-D struct-build
    카탈로그 진척 = **6/~17** (분할-1 의 named-external no-alloc ctor 모두 소진).
    - **신규 emitter 3** (`self/codegen/runtime_arm64.hexa`, 각 3-instr 12-B leaf):
      `rt_hexa_float` (`fmov x1,d0 · mov w0,#1 · ret`) — **첫 FP-arg leaf**: `fmov x1,d0`(0x9E660001)
      가 d0 의 raw double 비트를 변환 없이 x1 로 복사 (`.f` union half). 이전 5 ctor 전부 GP-only,
      이것이 self-emit 카탈로그의 **첫 FP→GP 레지스터 브리지**. ·
      `rt_hexa_enum_str` (`mov x1,x0 · mov w0,#11 · ret`) — TAG_ENUM(11) 포인터-스토어, malloc 無
      (caller-owned read-only literal 포인터 verbatim 저장 = no-free 계약). ·
      `rt_hexa_enum_str_v` (동일 바이트 · `HexaEnumDesc*` 타입만 상이) — descriptor 포인터 스토어.
    - **ABI 검증 3-layer (JIT-exec 게이트 load-bearing)**: ① interp self-test — 6 ctor 모두 size/align/
      RET ALL CHECKS PASS. ② **byte-identical to `as -arch arm64`** — 6-symbol `.o` 의 72-B `__text` 가
      어셈블러 출력과 바이트 동일 (`9e660001 52800020 d65f03c0` float · `aa0003e1 52800160 d65f03c0`
      enum). ③ **JIT-exec correctness** — 6-symbol `.o` 를 실 C 드라이버에 링크 → float = 12 edge
      값(0.0·-0.0·π·±Inf·NaN·DBL_MAX·DBL_MIN)에서 raw-bit 정확 · enum_str/enum_str_v = tag=11 +
      포인터(NULL/literal) verbatim. **fmov-브리지 + x0:x1 struct-return ABI 가 런타임에서 정확함 증명**.
    - **Path-A 활성화 (dual-build 3-mode PASS · #1858 패턴)**: `runtime_core.c` 의 3 ctor 를
      `#ifdef HEXA_RT_SELFEMIT extern / #else 본체 #endif` 가드로 감쌈. emit 드라이버
      (`emit_hexa_val_ctors_o.hexa`)를 6-symbol 로 확장(단일 `.o` 유지). **3-mode 실측**: (a) default
      = 6 ctor 모두 DEFINED(T) · **0-extern 불변 (HEAD 와 nm -u 동일 + 오브젝트 byte-size 508200 동일)**,
      (b) 가드 on + `.o` = JIT-EXEC PASS(6 ctor), (c) 가드 on **without** `.o` = 6 심볼 모두
      undefined-symbol link-fail (extern 진짜임 증명).
    - **잔여**: 분할-1 의 잔여 = `hexa_str`/`hexa_array_*`/`valstruct_*` 류는 모두 malloc/deref 결합
      (분할-3 alloc-coupled · class-B/E) → struct-build no-alloc named-external ctor 은 사실상 소진.
      class-D 의 다음 frontier = (분할-2) 접근자 매크로 경로 B 또는 (분할-3) alloc-coupled · 또는
      rt#38 NaN-box 선평가. .c count 불변(87).

    **✅ B9.6-C1 — class-C syscall-ABI 서브트랙 OPENED · FIRST svc-emit (2026-05-28 · #PR)**:
    PHASE-BOUNDARY MAP 의 **(C) syscall-bound I/O (~40-60 fn)** 클래스를 연 첫 증분.
    이전 활성화(class-A leaf · class-D struct-return)는 전부 레지스터 계산 / 메모리 루프였고,
    이것은 self-emit 카탈로그의 **첫 raw `svc #0x80` BSD syscall 방출** — class-C 의 정의 그 자체.
    - **타깃 = 런타임에서 가장 단순한 `hxlcl_*` syscall 래퍼**: `self/runtime.c` L1247
      `hxlcl_getpid(void)` = `_hxlcl_syscall1(HXLCL_SYS_GETPID(20), 0)`. 무인자 · 무errno
      (getpid 는 Darwin 에서 실패 불가 → carry-flag/`_cf` 경로 없음 · getuid 와 동형) →
      ≤1-arg scalar-return 의 base case.
    - **신규 emitter** (`self/codegen/runtime_arm64.hexa::rt_getpid`, 4-instr 16-B):
      `mov w16,#20` (0x52800290 · SYS_GETPID→x16) · `mov x0,#0` (0xD2800000 · no arg) ·
      `svc #0x80` (0xD4001001 · BSD trap) · `ret` (0xD65F03C0 · x0=pid 반환). clang -O2 가
      작은 immediate 에 32-bit `mov w16` MOVZ 를 택함 → rt_getpid 가 그것을 정확히 인코딩.
      rt_exit(무반환·epilogue 없음)와 달리 getpid 는 **값을 반환** → JIT-exec 로 결과 검증 가능
      = 첫 class-C 후보로 적합한 이유.
    - **ABI 검증 3-layer (JIT-exec 게이트 load-bearing)**: ① self-test — `rt_getpid : 16 bytes`
      + ALL CHECKS PASS (len==16 · svc@off8 · `mov w16,#20`@off0 · ret@off12 단언). ②
      **byte-identical to `as -arch arm64`** — emit `.o` 의 `__text` = `52800290 d2800000
      d4001001 d65f03c0`, 어셈블러 출력과 바이트 동일 · nm = strong `T _hxlcl_getpid`. ③
      **JIT-exec correctness** — `.o` 를 C 드라이버에 링크 → `hxlcl_getpid()` = 실 pid ==
      libc `getpid()` (43329 동일) · 런타임 래퍼 경유(`hexa_os_getpid→hxlcl_getpid`) e2e PASS
      (4970 동일) · **live 바이너리 disasm = self-emit svc 시퀀스** (ld64 가 callsite 를
      C svc-trap 이 아니라 hexa-emit 바이트에 바인딩함 확인). **svc-trap syscall ABI 가
      런타임에서 정확함 증명** (byte-eq 만이 아님).
    - **Path-A 활성화 (dual-build 3-mode PASS · #1836 패턴)**: `runtime.c` 의 L84 forward
      decl + L1247 body **둘 다** `#ifdef HEXA_RT_SELFEMIT extern / #else static #endif` 가드.
      ⚠ **forward decl 도 반드시 flip** — `static` 으로 두면 내부-링키지가 이겨 self-emit
      심볼을 마스킹(`-Wundefined-internal`) · 실측 확인. emit 드라이버
      (`emit_hxlcl_getpid_o.hexa`) = 단일-심볼 leaf 템플릿 복제(`_hxlcl_getpid` 13-B,
      `_hxlcl_memset` 와 동일 strtab 길이). `build_hexa_cli.hexa` 의 leaf emit 루프에
      `getpid` 추가(동일 single-symbol 템플릿 · 별도 env `HEXA_HXLCL_GETPID_O`). **3-mode 실측**:
      (a) default = `_hxlcl_getpid` local `t` (svc-trap 본체) · **runtime TU 심볼테이블 +
      undefined-extern set(49) 둘 다 origin/main 과 IDENTICAL** = 0-extern 불변 보존,
      (b) 가드 on + full bundle(.o) = link OK + e2e PASS + live disasm=self-emit,
      (c) 가드 on **without** `.o` = `Undefined: _hxlcl_getpid` link-fail (extern 진짜임).
      `.verdicts/runtime-floor-closure/B9C6-C1-getpid-syscall-byte-diff.txt`.
    - **fixpoint 무위험**: rt_getpid 는 shadow(`runtime_arm64.hexa`=main.hexa 미-use) · emit
      드라이버도 미-use → `hexa_cc.c` regen 무관. runtime.c diff = 순수 가드 추가(deletion 0).
    - **잔여 (class-C svc-emit 패턴 · ~190 layer-② `hxlcl_*`)**: getpid 는 무인자·무errno base.
      나머지는 (i) **multi-arg** (read/write/close = x0..x2 인자 적재 후 svc) + (ii)
      **carry-flag errno** (`_cf` 변종 = `svc · cset cs · cf 시 errno=x0;return -1`) +
      (iii) pair-return(pipe = x0:x1) · struct-arg marshalling(stat/wait4)이 fn별 상이.
      svc-emit + Path-A 템플릿은 입증됨 · multi-arg + errno-store 시퀀스 방출이 다음 증분.
      .c count 불변(87 · FLOOR 인프라).

    **✅✅ B9.6-B1 — class-B calling-convention 서브트랙 OPENED · FIRST BL composite (2026-05-28 · #PR)**:
    PHASE-BOUNDARY MAP 의 **(B) call-bound composite (~60-100 fn)** 클래스를 연 첫 증분.
    이전 21 활성화(class-A leaf · class-D struct-return · class-C svc)는 **전부 LEAF** — 단일 프레임,
    `bl` 없음(getpid/close 는 svc 를 쏘지만 다른 fn 을 부르지 않음). 이것은 self-emit 카탈로그의
    **첫 함수-호출-함수** — 스택 프레임을 세우고 `bl` 로 다른 runtime fn 을 부르는 composite,
    class-B 의 정의 그 자체.
    - **타깃 = 런타임에서 가장 단순한 class-B composite**: `self/runtime.c` L298
      `static int hxlcl_atoi(const char *s) { return (int)hxlcl_atoll(s); }` — 단일 tail-call,
      `(int)` 절단은 x0 의 w0 절반으로 free. strdup/strndup/atoll/strtoll 등 malloc/atof 호출
      composite 의 base case.
    - **신규 emitter** (`self/codegen/runtime_arm64.hexa::rt_atoi`, 5-instr 20-B + reloc 테이블):
      `stp x29,x30,[sp,#-16]!` (0xA9BF7BFD · 프롤로그 = x30(LR) 스필) · `mov x29,sp` (0x910003FD) ·
      `bl _hxlcl_atoll` (0x94000000 · imm zeroed · **BRANCH26 reloc @0x08**) · `ldp x29,x30,[sp],#16`
      (0xA8C17BFD · 에필로그) · `ret` (0xD65F03C0). `rt_atoi_reloc_offs/kinds` = [8],[2] (BRANCH26).
      clang -O2 가 `(int)` 캐스트를 bl 의 w0 결과에 folding → 추가 명령 없음.
    - **⚠ class-B load-bearing FINDING (frame = leaf↔composite 의 본질)**: `bl` 은 x30 을
      복귀주소로 덮어쓴다. 프레임 없이 `bl; ret` 만 하면 callee 가 composite 로 복귀 후 composite 의
      `ret` 가 (clobber 된) x30 으로 점프 → **무한루프**. frameless POC(`poc_macho_v3_branch26.hexa`)
      를 실제로 링크/실행 → rc=124(timeout spin) 으로 입증. `stp/ldp` 프레임이 그 차이.
    - **ABI 검증 3-layer (JIT-exec 게이트 load-bearing)**: ① self-test — `rt_atoi : 20 bytes
      (1 reloc · BRANCH26)` + stp/mov/bl/ldp/ret 단언 + reloc offs[8]/kind[2] ALL CHECKS PASS.
      ② **byte-identical to `as -arch arm64`** — emit `.o` 의 `__text` = `a9bf7bfd 910003fd
      94000000 a8c17bfd d65f03c0`, 어셈블러 출력과 바이트 동일 · nm = `T _hxlcl_atoi`(defined) +
      `U _hxlcl_atoll`(undefined extern) · BR26 reloc @0x08. ③ **JIT-exec correctness** — 멀티심볼
      `.o` 를 실 C 드라이버 + 실 `hxlcl_atoll` 에 링크 → 8/8 케이스 정확(99·-42·whitespace·+7·0·
      INT_MAX·non-numeric·-0) · rc=0 = **NO infinite loop**(frame 정확) · live disasm = ld64 가
      `bl _hxlcl_atoll` 를 바인딩. **frame + BRANCH26 cross-object call ABI 가 런타임에서 정확함 증명**.
    - **🔑 BRANCH26 cross-object 링크 = LC_SYMTAB only · NO LC_DYSYMTAB (#1475 caveat RESOLVED)**:
      `macho.hexa` L452 의 "ld64 MAY require LC_DYSYMTAB when undefined symbols present · link-test
      pending" caveat 가 이 PR 로 **종결**. hexa-emit `.o`(undefined-external `_the_callee`/`_hxlcl_atoll`
      + BRANCH26)가 별도 C `.o` 의 callee 와 `clang composite.o callee.o main.c` 로 링크 exit 0,
      실행 rc=0. emitted `.o` 에 LC_DYSYMTAB = **0개** (`otool -l | grep -c LC_DYSYMTAB`). committed
      재현 오라클 = `test/native_build/poc_classb_branch26_{emit.hexa,caller.c,callee.c}` (class-A
      arena `poc_arena_reloc_caller.c` 의 class-B 짝).
    - **Path-A 활성화 (dual-build 3-mode PASS · #1836 패턴 + callee-export 추가)**:
      `runtime.c` 의 (i) `hxlcl_atoi` forward-decl+def 를 `#ifdef HEXA_RT_SELFEMIT extern / #else static`
      가드 (#1860 lesson — decl 도 flip) · (ii) **`hxlcl_atoll` 를 가드下 EXPORT**(`HXLCL_ATOLL_SC`
      매크로 = default `static` · 가드시 빈값) — ld64 가 `.o` 의 BRANCH26 을 runtime.c 의 atoll 에
      바인딩하려면 callee 가 external 이어야 함 = **class-B 고유 wrinkle** (leaf/data-reloc 트랙은
      single-symbol override 라 안 겪던 것). `build_hexa_cli.hexa` 의 leaf emit 루프에 `atoi` 추가
      (동일 single-driver/one-`.o`/one-env 패턴 · `.o` 내부만 BRANCH26 reloc). **3-mode 실측**:
      (a) default = `hxlcl_atoi`/`atoll` 둘 다 local `t` · **undefined-extern set(49) origin/main 과
          IDENTICAL** = 0-extern 불변 보존, (b) 가드 on = `_hxlcl_atoi`=U(`.o` 가 공급)/`_hxlcl_atoll`=T
          (export·BL 바인딩) · JIT-exec PASS, (c) 가드 on **without** `.o` = `Undefined: _hxlcl_atoi`
          link-fail (extern 진짜임). `.verdicts/runtime-floor-closure/B9C6-B1-atoi-classb-byte-diff.txt`.
    - **fixpoint 무위험**: rt_atoi 는 shadow(`runtime_arm64.hexa`=main.hexa 미-use) · emit 드라이버도
      미-use → `hexa_cc.c` regen 무관. runtime.c diff = 순수 가드 추가(deletion 0).
    - **잔여 (class-B call-bound · ~60-100 fn)**: atoi 는 0/1-arg tail-call base. 나머지(`strdup`/
      `strndup`/`strtoll` = malloc/atof 호출)는 동일 frame + BRANCH26 + callee-export 템플릿 스케일 ·
      multi-arg 는 인자 적재 명령만 prepend · 다중-callee 면 BRANCH26 reloc 레코드 추가 (macho v3 가
      이미 N-reloc 지원). class-B 인프라(frame emit + BRANCH26 cross-object link)는 입증됨 ·
      callee-export wrinkle 가 fn 별 신규 작업. .c count 불변(87 · FLOOR 인프라).

    **✅✅✅✅✅ B9.6-E1 — class-E 메모리-수명(GC/arena/malloc) 서브트랙 OPENED · FIRST LIVE class-E wire (2026-05-28 · #PR)**:
    PHASE-BOUNDARY MAP 의 **(E) GC/arena-coupled (~30-50 fn)** 클래스를 연 첫 증분 — 이로써
    **5 FLOOR 클래스(A reloc · B calling-conv · C syscall-ABI · D struct-return · E mem-lifecycle)
    모두 proven emitter 보유** (단, alloc-core composite + bump-allocator seed 는 irreducible).
    - **핵심 발견 — class-E 에 classic mark/sweep GC 는 없다**: 이 runtime 의 메모리 관리는
      (1) mmap-backed **BUMP allocator**(`hxlcl_malloc` self/runtime.c L858 — 4 MB chunk bump,
      16-B size header, never-free) + (2) **no-op/const-return dealloc**(`hxlcl_free` L875 = `(void)p;`
      pure ret · `hxlcl_munmap` L902 = `return 0;`) + (3) reclaim = **scope-pop + bulk arena-reset**
      (rt 32-L discipline, GC walk 아님). 즉 emit 할 mark/sweep GC 자체가 존재하지 않음.
    - **타깃 = class-E 에서 가장 단순·JIT-verifiable primitive**: `self/runtime.c` L902
      `hxlcl_munmap(void*, size_t) { (void)addr;(void)length; return 0; }` — bump allocator 가
      never-free 라 unmap = constant-success stub. live 호출처 = mmap-file cleanup(L7438/L7609).
      `hxlcl_free` 는 void 반환(검증 불가)이라 munmap(int 0 반환)이 적합. **arena emit set
      (#1252/#1297/#1315)은 shadow-only**(runtime 가 그 심볼을 호출하지 않음) → munmap 이 runtime 에
      **실제 wire 된 첫 class-E primitive**.
    - **신규 emitter** (`self/codegen/runtime_arm64.hexa::rt_munmap`, 2-instr 8-B):
      `mov w0, #0` (0x52800000 · return 0 success · int 반환이라 32-bit MOVZ) · `ret` (0xD65F03C0).
      ⚠ **EMITTER capability 는 novel 아님** — `mov w0,#imm` + `ret` 는 class-D ctor 가 이미 입증.
      **NEW 한 것은 class-E LIVE-wiring** (end-to-end), 새 명령어가 아님. honest framing.
    - **ABI 검증 3-layer (JIT-exec 게이트 load-bearing)**: ① self-test — `rt_munmap : 8 bytes
      (class-E lifecycle)` + ALL CHECKS PASS (len==8 · mov w0,#0@off0 · ret@off4). ②
      **byte-identical to `as -arch arm64`** — emit `.o` 의 `__text` = `52800000 d65f03c0`,
      어셈블러 출력과 바이트 동일 · nm = `T _hxlcl_munmap` strong external · LC_DYSYMTAB 0개(leaf).
      ③ **JIT-exec correctness** — `.o` 를 C 드라이버에 링크 → `hxlcl_munmap()` = 0 (4/4 케이스:
      NULL/0 · 0x1000/4096 · 0xdeadbeef/SIZE_MAX · 0x1000/1) · rc=0 · live disasm = ld64 가
      self-emit `mov w0,#0 / ret` 바인딩. **메모리-수명 stub ABI 가 런타임에서 정확함 증명**.
    - **Path-A 활성화 (dual-build 3-mode PASS · #1860 패턴)**: `runtime.c` L902 body 를
      `#ifdef HEXA_RT_SELFEMIT extern / #else static stub #endif` 가드(forward decl 부재 — body 가
      모든 use 보다 앞서므로 body 만 flip). emit 드라이버(`emit_hxlcl_munmap_o.hexa`) = 단일-심볼 leaf
      템플릿 복제(`_hxlcl_munmap` 13-B, `_hxlcl_getpid` 와 동일 strtab 길이). `build_hexa_cli.hexa`
      의 leaf emit 루프에 `munmap` 추가(동일 single-symbol 템플릿 · env `HEXA_HXLCL_MUNMAP_O`).
      **3-mode 실측**: (a) default = `hxlcl_munmap` file-local static · **undefined-extern set(49)
      origin/main 과 IDENTICAL**(`nm -u` diff empty) = 0-extern 불변 보존, (b) 가드 on + `.o` =
      `_hxlcl_munmap`=U + link OK + JIT-exec returns-0 + live disasm self-emit, (c) 가드 on
      **without** `.o` = `Undefined: _hxlcl_munmap` link-fail (extern 진짜임).
      `.verdicts/runtime-floor-closure/B9C6-E1-munmap-classe-byte-diff.txt`.
    - **fixpoint 무위험**: rt_munmap 은 shadow(`runtime_arm64.hexa`=main.hexa 미-use) · emit 드라이버도
      미-use → `hexa_cc.c` regen 무관. runtime.c diff = 순수 가드 추가(deletion 0).
    - **잔여 (class-E)**: munmap 은 dealloc-stub base. (b) dealloc 서브그룹 잔여 = `hxlcl_free`(void
      반환 · 동일 leaf 템플릿). (c) **alloc-core** (`hxlcl_malloc` = state-reloc + `bl hxlcl_mmap`
      svc + header store · `hexa_arena_alloc`/`hexa_val_arena_calloc` = block-chain walk) =
      **class-A+B+C composite w/ branch logic** → 단일 increment 불가 · A/B/C sub-capability 스택으로
      원칙적 emit 가능하나 multi-session expert. (d) malloc-coupled value ctor = class-D 분할-3 중복.
      **bump-allocator SEED = irreducible B9.8 terminal** — self-host runtime 은 OS 메모리 carve 용
      machine-code seed(mmap svc + bump ptr) 필요 · emit 할 GC 부재. .c count 불변(87 · FLOOR 인프라).

    **🧱 B9.6-E2 — class-E ALLOC-CORE wall MEASURED · TERMINAL (closed-negative · 2026-05-28)**:
    B9.6-E1 이 class-E dealloc-stub(munmap) 을 열었고, (c) **alloc-core** (`hxlcl_malloc` ·
    `hexa_arena_alloc`) 가 그 다음 후보. 본 세션 = "PROVEN svc(mmap) + leaf(bump-ptr) 블록으로
    byte-identical self-emit 가능한가, 아니면 미구축 codegen 필요인가" 를 **측정**으로 판정.
    방법 = 가장 단순한 single-block bump 시드(=`hxlcl_malloc` L726 본체 형상: n==0 guard ·
    +16 header · 16-B align · 소진 시 chunk-or-bigger mmap · bump · header store) 를 `clang -O2`
    컴파일 후 `otool -tvV`/`-r` 디스어셈블. 실제 `hxlcl_malloc`/`hexa_arena_alloc` 는 이보다
    **strictly harder** 이므로 이건 하한선. `.verdicts/runtime-floor-closure/B9C-E2-alloc-core-wall.txt`
    (raw disasm + reloc verbatim).
    - **결과 = TERMINAL WALL** — 가장 단순한 시드(41 instr)조차 **byte-identical 로 emit 하려면**
      44개 proven F3 emitter 중 어느 것도 제공 못 하는 codegen 능력 5종 필요:
      · **(W1) conditional-select/compare family** — `csinc x20,x0,xzr,hi`(n==0?1:n) ·
        `ccmp x8,x9,#2,ne`(short-circuit `!g_ptr || g_ptr+total>g_end`) ·
        `csel x19,x21,x8,hi`(chunk=total>CHUNK?…) · `cmn x0,#1`(MAP_FAILED 테스트). shadow
        `rt_arena_alloc` 은 `cmp`+`b.hi` 만 — clang 은 branchless csel 로 fuse. byte-identity 는
        동일 csel/ccmp 스케줄링 요구. **csinc/ccmp/csel/cmn = 미-emit**.
      · **(W2) 2개 distinct module-global** `adrp+ldr/str` (`_g_ptr`@x22 · `_g_end`@x23) → 서로
        다른 심볼에 4개 PAGE21/PAGEOFF12 reloc(otool -r symbolnum 1·2). proven `rt_arena_*` 는
        **단일** `_arena_state` 구조체를 고정 오프셋(#8/#16)으로 참조 — multi-distinct-global
        할당 + per-global reloc 스케줄링 = **미구축**(per-primitive PORT, 템플릿 아님).
      · **(W3) register-allocator-driven multi-pair frame** — `stp x24/x23 · x22/x21 · x20/x19 ·
        x29/x30` (callee-saved 4 pair spill) + 대칭 ldp epilogue. proven class-B `rt_atoi` 는
        **1 pair**(x29/x30)만. 4-pair spill 은 RA-emergent(live-range 구동) — 고정 템플릿 아님,
        byte-identity 는 clang RA + spill 선택 복제 요구.
      · **(W4) `bl hxlcl_mmap`(BRANCH26)** 가 W1+W2+W3 와 **한 본체에 interleave** — class-B 는
        **격리된 tail-call**(atoi→atoll)만 입증. 여기선 bl 이 conditional-select 셋업과
        post-call MAP_FAILED 테스트 + state store 사이 중간에 위치.
      · **(W5) multi-basic-block 제어흐름** forward+backward merge — `b.ls`(mmap skip) ·
        `b.eq`(MAP_FAILED→NULL tail) · `b`(NULL tail→공유 epilogue back-edge). shadow
        `rt_arena_alloc` 은 **단일** `b.hi`→2-instr OOM tail 만 입증.
    - **`hexa_arena_alloc`(runtime_core.c L3538) 은 시드보다 STRICTLY HARDER** — single-block 이
      아니라 **linked-chain block-walk** allocator: W1-W5 위에 lazy env probe(`hxlcl_getenv`) ·
      **nested while**(`while (nb && nb->cap<n)`) · **second while**(`while (tail->next)`) ·
      conditional `hexa_arena_new_block`(→`hxlcl_malloc` 재귀) · stats hook(`_hx_mem_tick`/
      histogram store) · 3+ distinct static(`__hexa_arena{head,cur}`·`__hx_arena_lo/hi`·
      `__hexa_arena_enabled`) 추가. **A+B+C composite w/ loop control flow** = "단일 increment
      불가 · multi-session expert" 가 **측정 확인됨**.
    - **emit 미시도(REVERT 회피)**: 손-롤 byte-array 는 clang -O2 와 byte-identical 불가(다른 RA ·
      csel fusion 부재) → default-0-extern byte-identity 게이트 FAIL → mission 지시(non-byte-
      identical → REVERT)대로 **emit 안 함**. additive doc-only.
    - **class-E 가 .c=0 의 진짜 F3 terminal blocker 인가? — alloc-core 시드에 대해 YES**, 단 F3
      유일 잔여는 아님(A/B/C/D HARD-phase ~620 fn 의 본체 PORT 가 별도로 open). alloc-core 는
      **irreducible 정점**: 다른 모든 F3 fn 을 self-emit 해도 이 bump-allocator 시드는
      codegen self-emit 으로 bootstrap away 불가 — allocator 자체가 곧 OS-메모리-carve 시드(mmap
      svc + bump ptr)이고 emit 할 mark/sweep GC 가 없음. byte-identical .c=0 은 **full hexa
      codegen 백엔드**(RA + conditional-select 선택 + multi-global reloc) 도달 시에만, 또는 시드를
      irreducible B9.8 floor 로 honest 수용(= 측정상 옳은 종착: 시드가 곧 allocator)으로 닫힘.
      .c count 불변(87 · FLOOR 인프라).

### F4 — sha256 entangled

- [x] **F4 sha256** — `exec_argv_sha256.c` — 🟢 **RESOLVED → F3** (decompose + de-risk ·
      `.verdicts/runtime-floor-closure/F4-sha256.txt`)
  - `sha256`/`sha256_file` builtin 을 핵심 컴파일러 다수가 직접 호출 (falsifier ·
    hexa_ld · main · codegen) + stdlib 이름 불일치(`sha256` vs `sha256_hex`) +
    exec-shim 번들. 대규모 multi-caller rewire (blowfish 7-surface 레시피 확장).
  - **종결 (2026-05-28)**: `exec_argv_sha256.c` 는 **standalone 파일이 아니라
    runtime.c 의 `#include` 조각** (runtime.c:12483) → blowfish/v565 처럼 git-rm
    불가, **F4 ⊂ F3 (runtime FLOOR)** 로 재분류. 3-concern 번들 분해:
    - `hexa_exec_argv`(fork/execvp · shell-injection-safe) = ③ syscall 바닥 → F3 잔류 (terminal).
    - `hexa_sha256/_file/_bytes`·`hexa_sha1` = ① portable. **포팅 타깃 FIPS-180-4
      검증 🟢** — `sha256_hex("abc")` 빌드+실행 = `ba7816bf…015ad` (shasum 동일).
      30+ 코어 호출처 codegen rewire 는 F3 B9.6 self-emit 으로 fold (이중계상 방지).
  - F4 는 mis-split 이었음 (runtime.c 조각). 독립 floor 항목으로서는 resolved;
    실제 open 작업(sha port + caller rewire)은 정당한 홈 **F3** 로 이관.

### F5 — `.s` boot-floor (RFC 063/064 gated)

- [x] **F5 boot-asm** — `boot_rp2040.s` · `boot_stm32h7.s` · `startup_stm32f429.s`
      — 🔴 **IRREDUCIBLE BOOT-FLOOR TERMINAL** (honest-floor · audit #1810 ·
      `.verdicts/runtime-floor-closure/F5-boot-asm.txt`)
  - 고정-link-주소 vector-table (CPU reset fetch). `@asm` 는 inline escape hatch 라
    vector-table data section emit 불가 → RFC 063/064 `@interrupt`/`@target`
    lowering 선행 필수.
  - **종결 (2026-05-28)**: audit #1810 권위 분류 — 3 파일 전부 `.vector_table`/
    `.isr_vector` **데이터 섹션** (함수 본문 아님), reset 시 CPU 가 고정 link 주소
    (FLASH 0x10000100 / 0x08000000)에서 직접 fetch. `@asm`(wfi/dsb 인라인 escape)로는
    구조적으로 표현 불가. codegen.hexa:1851 이 `@interrupt/@target` 을 인식하나 lowering
    은 RFC 063/064 deferred(no-op). north-star "minimal per-arch .s asm STAYS ·
    zero .c NOT zero asm" 의 irreducible asm 바닥 그 자체. **re-open flag**: RFC
    063/064 가 vector-table data-section lowering 을 1급 처리하면 zero-.s 도달 가능.

  - 📘 **RFC 063/064 RUNBOOK (B9.S-1 정밀 정찰 · 2026-05-28)** — re-open 시 actionable:
    - **현 상태 (verbatim grep)**: `self/codegen.hexa` = hexa→C 트랜스파일러, 임베디드
      코드젠 0 (`.word`/`.section`/`vector_table`/`thumb`/ELF 매치 0건); :1851 이
      `@interrupt`/`@target` 인식하나 comment-only, HexaVal fn C codegen 으로 fallthrough.
      `compiler/codegen/thumbv7em_eabihf.hexa` 존재하나 thumbv7em (M7/M4) 타깃, M0+ 미지원,
      symbol-relocated word-array emitter 0, `@interrupt` 처리 0. firmware 빌드
      (`Makefile.rp2040`) 는 `arm-none-eabi-as/gcc/ld` 직접 호출 — hexa 미경유.
    - **5 components 필요**:
      1. `@interrupt`/`@vector_table` slot-id parse + symbol resolution (~2-3d)
      2. symbol-address word-array data-section emitter w/ relocs (~3-4d · **핵심 갭**)
      3. ARMv6-M reset-prologue lowering (~2-4d)
      4. ELF/raw-bin target + linker-script slot (~2-3d) — class-A Mach-O reloc 인프라
         (#1839)는 format-mismatch 라 직접 재사용 불가
      5. 빌드 rewire + **BYTE-IDENTICAL `arm-none-eabi-as` byte-diff 검증** + `git rm` (~1d)
    - **최소-노력 경로** (`.s`-text route · `as` 가 reloc/literal-pool 처리): **~5-7d expert**
    - **full ELF-native 경로**: ~12-16d expert
    - **first re-open 증분 scope**: Component 1 + `.s`-text vector generator + byte-diff
      oracle = 단일 PR
    - ⚠ **byte-correctness 절대 mandate**: 잘못된 reset vector = MCU silent 부팅 실패
    - rp2040 padding 주석 정정: `.rept 28` after 4 words = **128 B = 0x80** (not 0x100)
    F1(perf)·F2(vendor-ABI) 와 동일 closure 형태 (현 capability irreducible + 미래
    enabler re-open).

  - 📗 **FOUNDATION 증분 (PR1 · 2026-05-28)** — Component 2-lite + byte-diff oracle:
    - `stdlib/hal/vector_table_emit.hexa` — pure-hexa `.s`-text vector-table 생성기
      (string-builder · `as` 가 reloc/literal-pool 담당 · 핵심 API
      `vt_emit_section` + canned `rp2040_emit_vector_table_s`).
    - `stdlib/hal/t3/vt_byte_diff_rp2040.hexa` — `arm-none-eabi-as` byte-diff 오라클
      (SHA256(.vector_table) + R_ARM_ABS32 reloc-set 동일성).
    - 측정: 6/6 PASS · `.verdicts/runtime-floor-closure/F5-vt-byte-diff-rp2040.txt`
      (`gen sha == orig sha == 212baeea7479dbac…73d82c2`, 4× R_ARM_ABS32).
    - **증명**: rp2040 `.vector_table` 섹션은 hexa-emittable byte-identical.

  - 📙 **CLOSURE (PR #1844 · #1845 · #1846 · 2026-05-28)** — `.s`-leg COMPLETE:
    - PR #1844 (rp2040): `reset_prologue_emit.hexa` + `boot_emit.hexa` composer +
      `boot_byte_diff_rp2040.hexa` 오라클 → `git rm boot_rp2040.s` · `.s` 3→2.
    - PR #1845 (stm32h7): emitter extensions (`_ext` variants: `.fpu` directive +
      ARMv7-M FPU enable block — CPACR CP10/CP11 grant + dsb + isb) +
      `boot_stm32h7_gen.hexa` + `boot_byte_diff_stm32h7.hexa` 8/8 PASS → `git rm
      boot_stm32h7.s` · `.s` 2→1.
    - PR #1846 (stm32f429 CMSIS): emitter extensions (`_cmsis` variants: 
      `.isr_vector` section + `g_pfnVectors` `.type %object`+`.size` + `.extern` 
      decls + named-IRQ/`.rept`-pad chunk model + `.weak`/`.type %function` 
      annotations + indexed-load `.data` copy form) + `startup_stm32f429_gen.hexa` +
      `boot_byte_diff_stm32f429.hexa` 10/10 PASS (3 sections + 3 reloc lists) → 
      `git rm startup_stm32f429.s` · `.s` 1→**0**. firmware.bin SHA byte-identical 
      pre/post rewire (production-shipped MCU 바이너리 동일).
    - **F5 `.s`-leg COMPLETE** — 모든 boot `.s` 파일은 이제 hexa-emit at build time.
      `as` 가 reloc/literal-pool 담당 (Component 2/3 LITE 경로 · full ELF-native
      Component 2/3 proper 는 deferred). 잔여 `.s` count = 0.

### F6 — bootstrap seed (terminal)

- [x] **F6 bootstrap** — `hexa_cc.c` (생성된 self-host 컴파일러) + HexaVal repr/GC/
      arena seed = irreducible bootstrap FLOOR (CLOSED-NEG-TERMINAL). self-hosting
      컴파일러는 SOME machine-code seed 필요. B9.6 self-emit 가 100% 닫으면 re-open.
  - **2026-05-28 정밀 특정 (B9.6-E1 class-E 조사)**: 이 "GC/arena seed" 의 정체 =
    **mmap-backed BUMP allocator** (`hxlcl_malloc` self/runtime.c L858 · never-free).
    classic mark/sweep GC 는 존재하지 않음 (reclaim = scope-pop + bulk arena-reset).
    dealloc(`hxlcl_munmap`)은 self-emit 됨(B9.6-E1, FIRST LIVE class-E wire)이나
    **alloc seed 자체(OS 메모리 carve = mmap svc + bump ptr)는 irreducible** — emit 으로
    bootstrap away 불가. 즉 F6 의 irreducible 핵심 = 이 bump-allocator seed.

## 진짜 닫는 길 = codegen self-emit (B9.6a/b)

F1·F2(syscall)·F3 를 닫는 **단일 enabler** = hexa codegen 이 inline-svc / FFI /
SIMD machine-code 를 직접 emit → C shim 전부 대체. expert multi-session serial,
regen+fixpoint, cold 자동 fan-out 부적합. `rt_arena_*` 4-fn(#1252/#1297/#1315)이
입증한 패턴의 확장.

## handoff / cross-ref

- `RUNTIME.flip.md` — quick-win atomic 캠페인 (B1-B8 + B9.1~6h · 거의 종결)
- `RUNTIME.md` — frontier next-list (상위 18-list)
- 이 doc(`RUNTIME.floor.md`) — `.hexa`-only 물리 바닥 전담 (F1-F6)
