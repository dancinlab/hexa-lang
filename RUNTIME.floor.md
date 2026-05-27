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
| **F3** runtime-core (640/548 fn) | 🟠 **LIVE FRONTIER** | genuinely-portable · 50-70 PR multi-session (`F3-frontier.txt`) |
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
    quick-win/doc 트랙 — F3 와 직교). **다음 단위 = B9.6a HexaVal repr 생성자 emit**
    (`hexa_int/float/bool/str` tagged-union 생성자 → runtime_arm64.hexa hexa-emit-bytes).
    각 단위 = emit-path 라 `gen1≡gen2` byte-eq fixpoint 검증 필수 (regen heavy →
    ubu route). F4 sha256 ① port (FIPS-검증된 stdlib 타깃) 도 이 campaign 의 한 단위.
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
