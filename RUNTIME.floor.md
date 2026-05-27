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
- `.s` = **3** (전부 boot-floor · 아래 F5)
- `.c` = **226** → B9.6h dead-scaffolding sweep 후 **~70 예상** (대부분이 archive/
  fires + tool 의 죽은 실험 harness 였음 — runtime floor 아님). sweep 후 남는 ~70 이
  이 doc 의 대상.

세션 quick-win (flip): 4 파일 삭제 — blowfish(wire+🟢RUNEQ #1816) · v565(dead #1818)
· hxtok(dead #1820) · hxvocoder(dead #1821).

## 🧱 floor closure 상태 (2026-05-28 — F1-F6 종결 pass)

| 항목 | 상태 | verdict |
|------|------|---------|
| **F1** perf-floor (hxflash/hxlayer/hxvdsp) | 🔴 **TERMINAL** | 측정 285x ML 회귀 → irreducible perf-floor (`F1-perf-floor.txt`) |
| **F2** vendor/OS-ABI FFI (19 layer-③) | 🔴 **TERMINAL** | audit #1809 — 순수 로직 0, ABI 경계 (`F2-vendor-ffi.txt`) |
| **F3** runtime-core (640/548 fn · self-emit 20/640 · EASY-phase DONE) | 🟠 **LIVE FRONTIER** | genuinely-portable · easy-leaf 고갈 → HARD-phase ~620 fn (reloc·call·syscall·HexaVal·GC) expert serial · inc 4 LANDED |
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
      `adrp+add` PAGE21/PAGEOFF12 reloc 으로 참조하는 leaf. 인프라 LANDED (`rt_arena_*` 4-fn ·
      `tool/hexa_ld.hexa` reloc 방출) 이나 **각 신규 global 마다 reloc 레코드 짝 수동 배선** 필요 —
      cold fan-out 부적합. 필요 인프라 Z = linker reloc-emit 확장 + per-symbol 배선 검수.
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
    F1(perf)·F2(vendor-ABI) 와 동일 closure 형태 (현 capability irreducible + 미래
    enabler re-open).

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
