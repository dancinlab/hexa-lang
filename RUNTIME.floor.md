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

## floor 분류 (F1–F6)

### F1 — perf-floor (port 금지 · 285x 회귀)

- [ ] **F1 perf-kernel** — `hxflash_linux.c` · `hxlayer_linux.c` · `hxvdsp_linux.c`
  - `@link(...)` FFI `.so` (H100 ML 학습 hot-path · `tool/deploy_h100.hexa` 배포 ·
    dlopen 해석).
  - pure-hexa 등가가 **이미 존재**하나 (`hxlayer.hexa:ref_rmsnorm_silu`) C 가
    **측정상 285x 빠름** (`bench_hxlayer_matrix.hexa` · B9.6g). 포팅 = ML 학습 285x
    회귀 → vendor 급 irreducible. harm-guard 로 삭제 차단(B9.6g honest-abort).
  - **enabler**: codegen 이 SIMD/GPU machine-code 를 직접 self-emit 해야 대체 가능
    (B9.6 의존) + hexa `fn`→standalone dlopen `.so` 산출 모델 필요.

### F2 — vendor / OS-ABI FFI (irreducible boundary)

- [ ] **F2 vendor-ffi** — 19 파일:
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

### F3 — runtime FLOOR (codegen self-emit · 핵심)

- [ ] **F3 runtime-core** — `self/runtime.c` · `self/runtime_core.c` (640/548 fn)
  - 파일 각 1개지만 **전 함수** codegen self-emit 후에야 삭제 가능.
  - 경로: B9.6a (HexaVal repr 생성자 emit · `rt_arena_*` 4-fn LANDED 패턴) →
    B9.6b (잔여 runtime primitive emit) → runtime.c dead.
  - 추정 **50-70 PR · expert serial** (#1812). regen+fixpoint · phase-h codegen
    에이전트와 경합 · **cold fan-out 부적합** (전담 신중 작업).
  - 🧱 **increment 1 LANDED — `rt_memset` self-emit** (`runtime_arm64.hexa` 확장 ·
    7-instr 28-B leaf byte-store loop · arena 패턴 답습). interp self-test PASS +
    `as` byte-identical + **JIT-exec 실제 memset 동작 검증**. shadow 모듈이라
    `hexa_cc.c` regen 무관 = fixpoint 무위험 · **`.c` 카운트 UNCHANGED** (640 fn
    전부 emit 후에야 파일 삭제 — 이 increment 는 토대 1칸). 다음 leaf 후보 =
    `rt_memcmp`/`rt_memmove` (동급 reloc-free 순수 루프) → 그 다음이 reloc 필요한
    state-bound primitive → 최후가 HexaVal repr/GC core (hard floor).

### F4 — sha256 entangled

- [ ] **F4 sha256** — `exec_argv_sha256.c`
  - `sha256`/`sha256_file` builtin 을 핵심 컴파일러 다수가 직접 호출 (falsifier ·
    hexa_ld · main · codegen) + stdlib 이름 불일치(`sha256` vs `sha256_hex`) +
    exec-shim 번들. 대규모 multi-caller rewire (blowfish 7-surface 레시피 확장).

### F5 — `.s` boot-floor (RFC 063/064 gated)

- [ ] **F5 boot-asm** — `boot_rp2040.s` · `boot_stm32h7.s` · `startup_stm32f429.s`
  - 고정-link-주소 vector-table (CPU reset fetch). `@asm` 는 inline escape hatch 라
    vector-table data section emit 불가 → RFC 063/064 `@interrupt`/`@target`
    lowering 선행 필수.

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
