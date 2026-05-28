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
- `.c` = **93** (2026-05-28 B9.C-6 ACTIVATED · 3-file small standalone batch
  삭제 = 96→93 · `tests/runtime_h_smoke.c` · `stdlib/hal/t3/harness_main.c` ·
  `stdlib/hal/t3/harness_stm32h7_main.c` ← per-file `*_emit.hexa` +
  `*_byte_diff.hexa` · 각 6/6 PASS ·
  `.verdicts/runtime-floor-closure/B9C6-{runtime-h-smoke,harness-main-rp2040,harness-stm32h7-main}-byte-diff.txt`
  · bin/hexa-fast `check` rewired to regen runtime_h_smoke_gen.c each invocation ·
  Makefile.rp2040 + Makefile.stm32h7 rewired to regen harness_*_gen.c each build).
  이전: 2026-05-28 B9.C-5 (#1851) `self/cuda/runtime_{bf16,cuda}.c` — self-emit PROVEN
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

## 🧱 floor closure 상태 (2026-05-28 — F1-F6 종결 pass)

| 항목 | 상태 | verdict |
|------|------|---------|
| **F1** perf-floor (hxflash/hxlayer/hxvdsp) | 🔴 **TERMINAL** | 측정 285x ML 회귀 → irreducible perf-floor (`F1-perf-floor.txt`) |
| **F2** vendor/OS-ABI FFI (19 layer-③) | 🔴 **TERMINAL** | audit #1809 — 순수 로직 0, ABI 경계 (`F2-vendor-ffi.txt`) |
| **F3** runtime-core (640/548 fn · self-emit 20/640 shadow · **12 ACTIVATED** = memset+11 leaf · class-A reloc 경로 PROVEN) | 🟠 **LIVE FRONTIER** | genuinely-portable · Path-A 템플릿 스케일아웃 → reloc-free leaf 12 LIVE-주입 (HEXA_RT_SELFEMIT 가드 · default 0-extern 보존 byte-identical) · 4 SKIP (C 대상 부재) · class-A reloc 인프라 COMPLETE+PROVEN (arena adrp+add link+run rc=0 · 실 blocker=per-primitive PORT) · class-D(~350-450 fn HARD-본체) = struct-repr(NaN-box 아님 · 미션전제 정정) · 3-분할 sub-plan 특정 · 단일-increment no-go(struct-return ABI emit 부재+접근자 매크로 슬롯無+rt#38 선행) · HARD-phase ~620 fn expert serial |
| **F4** sha256 (exec_argv_sha256.c) | 🟢 **RESOLVED→F3** | runtime.c `#include` 조각 · 포팅 타깃 FIPS-검증 (`F4-sha256.txt`) |
| **F5** boot-asm (3 `.s`) | 🔴 **TERMINAL** | audit #1810 — vector-table 데이터 섹션, RFC 063/064 gated (`F5-boot-asm.txt`) |
| **F6** bootstrap seed (hexa_cc.c) | 🔴 **TERMINAL** | irreducible bootstrap FLOOR (B9.8) |

**honest 100% closure = 5/6 terminal + F3 단일 frontier 로 정밀 특정.** F1·F2·F5·F6
= irreducible/honest-floor closed-negative (각각 미래 enabler re-open flag). F4 =
runtime.c 조각이라 F3 로 fold (mis-split 해소). **F3 만이 진짜 open** — irreducible 이
아닌 portable codegen self-emit campaign (enabler `rt_arena_*` 4-fn LANDED 입증).
단일 세션 종결 불가 = 정직한 multi-session 잔여 (`feedback-closure-is-physical-limit`).
모든 verdict = `.verdicts/runtime-floor-closure/` raw 명령 출력 verbatim (g5 claim_verify).

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
    - **(B) call-bound composite (~60-100 fn)** — `hxlcl_strdup`/`strndup`/`atoll`/`strtoll` 처럼
      다른 runtime fn(`malloc`·`atof`) 을 **call** 하는 비-leaf. 호출 규약(stp/blr/ldp frame +
      ARM64 calling convention) + call-target reloc 필요. 필요 인프라 Z = calling-convention
      codegen + BL/ADRP-target reloc.
    - **(C) syscall-bound I/O (~40-60 fn)** — fork/execvp/popen/fopen/read/write 래퍼. svc 패턴은
      LANDED (`rt_exit`·`rt_arena_init` mmap) 이나 errno·struct-arg·다단 syscall 시퀀스가 fn별
      상이 — 개별 신중 작업. 필요 인프라 Z = syscall-ABI struct marshalling.
    - **(D) HexaVal-repr 생성자/접근자 (~350-450 fn · HARD FLOOR 본체)** — `hexa_int`/`hexa_float`/
      `hexa_string`/`valstruct_*`/배열 ops 등 NaN-box repr 을 **생성·태깅·역참조** 하는 코어.
      B9.6a 의 진짜 본체이자 가장 위험한 단위 — repr 레이아웃 전체를 codegen 이 알아야 함.
    - **(E) GC/arena-coupled (~30-50 fn)** — reclaim·mark·clone·arena lifecycle. (D) 의 repr +
      (A) 의 state 양쪽에 결합 — 가장 마지막. 필요 인프라 Z = GC 통합 codegen.
    **요약**: easy-leaf phase = **DONE (20/640, 모두 byte-eq + JIT-exec 검증)**. hard phase =
    **~620 fn**, 5 클래스 (A reloc · B calling-conv · C syscall-ABI · D HexaVal-repr · E GC) —
    각각 신규 codegen 인프라 필요, **cold-batchable 아님 · expert human-guided serial** (#1812
    의 50-70 PR 추정과 정합). F3 의 [ ] 유지 근거 = 이 hard phase 가 실제 open 작업이기 때문.
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

## 진짜 닫는 길 = codegen self-emit (B9.6a/b)

F1·F2(syscall)·F3 를 닫는 **단일 enabler** = hexa codegen 이 inline-svc / FFI /
SIMD machine-code 를 직접 emit → C shim 전부 대체. expert multi-session serial,
regen+fixpoint, cold 자동 fan-out 부적합. `rt_arena_*` 4-fn(#1252/#1297/#1315)이
입증한 패턴의 확장.

## handoff / cross-ref

- `RUNTIME.flip.md` — quick-win atomic 캠페인 (B1-B8 + B9.1~6h · 거의 종결)
- `RUNTIME.md` — frontier next-list (상위 18-list)
- 이 doc(`RUNTIME.floor.md`) — `.hexa`-only 물리 바닥 전담 (F1-F6)
