# zero-c #29 — terminal-front reduction 종결 판정 (2026-07-03)

> 2개 audit 레인(WALL-2 `calloc/free/realloc` · own-start `environ/atexit`)을
> 통합하여, 5-flip 이후 도달 가능한 **참 terminal floor N**을 확정한다.
> 선행 판정(`state/zeroc-29-goal-terminal-verdict-2026-06-30.md`, commit `c7fe5dbef`)의
> "floor 15→7 · permanent-WALL 4" 프레이밍을 **양 레인의 tree 증거로 교정**한다.

---

## 1. Updated terminal floor — 정직한 도달 가능 바닥

선행 판정은 5-flip 후 잔여를 **7 = permanent-WALL 4 (dlopen/dlsym/dlerror + atexit) + conditional 3 (environ, `__libc_calloc`, `__libc_free`)** 로 두었다.
두 레인이 이 잔여 7 중 **4개를 reducible로 falsify**한다.

| 축소 단계 | floor | 제거되는 U | 근거 |
|---|---|---|---|
| 시작 (현 ON-floor) | **15** | — | 5 reducible이 아직 default-ON flip 안 됨 (레인 A 재평가) |
| **5-flip 랜딩** (qsort·regex·strtod·glob·fgets) | **15 → 10** | qsort · regcomp/regexec/regfree · strtod · glob/globfree · fgets (8 U 계열, 5 front) | 이미 reducible 확정 (선행 판정) |
| **WALL-2 flip** (calloc/free/realloc) | **10 → 7** | `__libc_calloc` · `__libc_free` · `__libc_realloc` | LANE 1: 네이티브 body 구현·머지·byteeq-neutral 완료(#4242·#4244) |
| **own-start flip** (environ + atexit 동반) | **7 → 4** | `environ` · `atexit` | LANE 2: own-LIFO + envp 스택캡처가 in-tree, #4409로 배선 |

### 참 terminal floor N = **4**

```
{ dlopen, dlsym, dlerror }   — FFI/loader WALL (진짜 비가역)
{ setjmp/longjmp, sigaction(SA_RESTORER), va_list, pthread_* } — ABI/kernel WALL (15-U 밖 별개 축)
```

15-U 축만 놓고 보면 **참 terminal = 3 (dlopen/dlsym/dlerror)**.
`atexit`은 선행 판정이 이 3개와 묶었으나 **오분류(LANE 2가 반증)** — own-LIFO로 감축 가능하므로 15-U permanent-WALL에서 빠진다.
`environ`도 own-start에서 절단되므로 conditional이 아니라 **flip 후 소멸**한다.

따라서:
- **15-U 축 참 terminal floor = 3** — `dlopen` / `dlsym` / `dlerror` 만.
- 이 3개는 vendor-FFI 동적 디스패치(`runtime.c:3058-3227`, cuBLAS 탑승)로 **native-canonical-default가 sanction하는 유일한 진짜 바닥**. runtime dynamic-linker가 필요하므로 알고리즘 이식으로 제거 불가 = **genuine WALL**.
- 별개 축의 ABI/kernel WALL(`setjmp`·`sigaction` SA_RESTORER·`va_list`·`pthread_*`)은 15-U에 포함되지 않으며 예외-언와인드/시그널-ABI/가변인자 primitive라 동일하게 비가역. 이는 zero-c #29 15-U 종결과는 별개의 영구 축이다.

**선행 판정 대비 교정: 잔여 7이 아니라 잔여 3.** permanent-WALL 4→3(atexit 제외), conditional 3(environ/calloc/free)은 전부 flip으로 소멸.

---

## 2. Per-front verdict — 오분류 교정

### WALL-2 (`__libc_calloc` / `__libc_free` / `__libc_realloc`) = **REDUCIBLE (구현·머지 완료)**

- **판정: 벽 아님. 이미 구현·머지·byteeq-neutral 증명 완료된 reducible.**
- 선행 판정의 "WALL-2 arena 포트(별도 blocked front)" 스탬프는 **re-openable stale 스탬프이며 tree가 반증**.
- nm-UND의 실제 출처는 HexaVal *arena*(bump·no-free)가 아니라 `hxlcl_*` libc-mirror 레이어의 **default arm libc 위임**이다:
  - `hxlcl_free` default → `free(p)` (`self/runtime_core_hxlcl_shim_emit.hexa:151`)
  - `hxlcl_realloc` default → `realloc(p,n)` (`:189`)
  - `hxlcl_calloc` default → `calloc(...)` (`:219`)
- "free=0 in floor" 프레이밍도 오류 — arena no-free(HexaVal)와 `hxlcl_*` 레이어를 혼동. nm-UND는 후자에서 발생.
- 네이티브 대체 body가 이미 존재: `stdlib/runtime/hxlcl_core.hexa` — `hxlcl_calloc`(`:1216`)·`hxlcl_realloc`(`:1249`)·`hxlcl_free`(r3 pure-noop leaf).
- drop guard·stage 배선·verify 하네스 전부 live. **PR #4242(free)·#4244(calloc+realloc) 랜딩, default-OFF/byteeq-neutral 태그.**
- **교정: `__libc_calloc/__libc_free/__libc_realloc`을 CONDITIONAL/WALL-2에서 reducible-but-unflipped 버킷으로 이동** (strtod/qsort/fgets/glob/regex와 동급). reducible 집합 8→11.

### own-start `environ` = **REDUCIBLE (own-start flip으로 절단, low risk)**

- **판정: 벽 아님. 조건부이나 own-start flip시 확정 소멸.**
- 두 독립 provider가 in-tree:
  - own-start: `_hx_start_c`가 `envp = argv+argc+1`을 스택에서 읽어 file-local `static char **hxlcl_environ`에 저장(`self/runtime_emit_full.hexa:91`), `#define environ hxlcl_environ`(`:68`)로 모든 consumer 리다이렉트 → libc `environ` global 미참조 → UND 소멸.
  - codegen `__hx_environ_ptr`(`compiler/codegen/x86_64_linux.hexa:4592`)이 `environ@GOTPCREL`로 `&environ` 해석 — 오늘 default 경로가 남기는 유일한 reloc.
- 스택 레이아웃 `envp = argv+argc+1`은 SysV/AArch64 process-start ABI(안정). 캡처는 priority-101 ctor(`:64`)와 idempotent. **risk = LOW.**

### own-start `atexit` = **REDUCIBLE — 선행 판정의 "permanent-WALL" 은 WRONG**

- **판정: 벽 아님. own-LIFO shim으로 감축 가능. 선행 판정이 dlopen과 잘못 묶었다.**
- 교정 근거:
  1. **atexit은 libc-registered-handler 요구가 없다.** 3개 runtime caller(`_hx_stats_dump`·`hexa_ic_dump_stats`·`_hxp_atexit_cleanup`, `runtime_emit_full.hexa:3329-3331`)가 전부 raw C fn-ptr을 넘김, TAG_FN box 아님. 생존해야 할 libc-internal handler 없음.
  2. **own-LIFO 대체가 이미 작동.** `HEXA_ZEROC_OWN_START`에서 64-slot `_hxlcl_atexit_fns[64]` + `hxlcl_atexit` + `_hxlcl_atexit_drain`(LIFO, `hxlcl_exit`가 `exit_group` 전 drain)이 libc `atexit`을 완전 대체(`runtime_emit_full.hexa:3335-3344`). `#else`(`:3343`)만이 libc `U atexit`의 출처.
  3. **dlopen과 범주적으로 다르다.** dlopen/dlsym/dlerror는 runtime dynamic-linker 필요 = 진짜 영구. atexit은 64-entry 배열 + drain loop = 이미 작성됨.
- **아직 안 빠진 이유 = 패키징이지 벽이 아니다:**
  - own-start default-OFF (byteeq-3-target + install-smoke flip 필요).
  - MULTIOBJ ship archive shim이 아직 glibc 위임: `self/runtime_core_hxlcl_shim_emit.hexa:835`이 **무조건** `int hxlcl_atexit(...) { return atexit(fn); }`(OWN_START 분기 없음), 그리고 `tool/stage_resolve_runtime_a:2614`가 `$_mo_shim_def`(=`""`, `:1411`)로 컴파일 — `$_zc_own_def` 아님. → `OWN_START=1`에서도 shipped shim이 `U atexit` → `libc_nonshared.a(atexit.oS)` → `__dso_handle` undefined → link FATAL. **PR #4409가 정확히 이 둘을 수정**(shim `#ifdef` 분기 추가 → `_hxlcl_atexit_register`, define을 S4 컴파일로 전파).
- **교정: permanent-WALL 4→3. atexit은 environ과 동급 CONDITIONAL, #4409로 droppable.**
- **공정성 caveat**: atexit drop은 독립 1-symbol raw-svc leaf가 아니라 own-start front(`_start`·crt-drop·`__dso_handle`·environ) 전체에 번들되며, byteeq-3-target + install-smoke gated default-ON flip을 요구 = reducible-but-campaign-coupled(자유 flip 아님). 그래도 CONDITIONAL이지 permanent-WALL 아님.

---

## 3. Design — reducible front별 네이티브 body + 게이트

패턴은 glob/fgets/qsort/regex/strtod와 동형: **default-OFF `#ifdef` → Route-C native `.o` emit → objcopy 심볼 격리 → shim member drop(`-DHEXA_RT_NATIVE_*`) → `ld -r` multidef gate → byteeq 3-target GREEN → default-ON flip.**

### WALL-2 (calloc/free/realloc) — 구현 완료, flip만 잔여

| front | 네이티브 body 메커니즘 | emitter file | resolver 변경 |
|---|---|---|---|
| `hxlcl_free` | arena no-op leaf: `(void)p; return`. bump arena는 never reclaim. zero syscall/errno/inner-callee. 최순수 leaf (RUNG-3). | `stdlib/runtime/hxlcl_core.hexa` (r3 leaf) · guard `#ifndef HEXA_RT_NATIVE_FREE` @ `shim_emit:144` | `tool/stage_resolve_runtime_a:1901-1930` |
| `hxlcl_calloc` | `total=nmemb*size; p=hxlcl_malloc(total); zero-fill p[0..total)`. 유지된 shim `hxlcl_malloc`을 inner C-ABI `bl` + zero-fill byte loop(native memset-등가)로 재사용. frozen floor calloc과 byte-faithful. malloc co-drop 불필요. | `hxlcl_core.hexa:1216` (r9 composite) · guard `#ifndef HEXA_RT_NATIVE_CALLOC` @ `shim_emit:206` | `stage_resolve_runtime_a:2055-2086` |
| `hxlcl_realloc` | `hxlcl_malloc(n)` + negative-offset header read `*(size_t*)(p-16)`로 old size + `memcpy(min(n,old_n))` byte loop(native memcpy-등가). frozen floor realloc과 byte-faithful. malloc co-drop 불필요. | `hxlcl_core.hexa:1249` (r10 composite) · guard `#ifndef HEXA_RT_NATIVE_REALLOC` @ `shim_emit:169` | `stage_resolve_runtime_a:2102-2133` |

- verify 하네스 존재: `tool/routec_alloc_native_verify.sh`·`tool/routec_free_native_verify.sh`.
- **남은 실제 제약 (측정, reducibility 벽 아님)**: 토글이 **x86_64-linux-only** gated. else-arm(`stage_resolve_runtime_a:2084,2131,1930`)이 `IGNORED — fp-ABI xmm Route C is x86_64-linux-only` 출력. default-ON flip 전제 = (a) arm64/darwin Route-C fp-ABI 커버리지, (b) byteeq 3-target GREEN + faithful DROP 캡처(`__libc_calloc/realloc/free`가 nm-UND에서 소멸). 다른 8 reducible과 동일 DEFER 조건.

### own-start (environ + atexit) — 배선 #4409, 동반 flip

| front | 네이티브 body 메커니즘 | emitter file | resolver 변경 |
|---|---|---|---|
| `environ` | own-start `_start`(x86_64+aarch64 raw-asm)이 `%rsp`/`sp`를 `_hx_start_c(long *sp)`에 전달 → `envp=argv+argc+1` 스택 재구성 → `static char **hxlcl_environ = envp` → `#define environ hxlcl_environ`로 getenv/execvp 리다이렉트. libc `environ` global·`environ@GOTPCREL` reloc 소멸. | `self/runtime_emit_full.hexa:69-118` (scaffold, envp 캡처 `:91`) · redirect `:63,68` | `#ifdef HEXA_ZEROC_OWN_START` payload guard — 모든 stage `${HEXA_ZEROC_OWN_START:-0}` |
| `atexit` | 64-slot `_hxlcl_atexit_fns[64]` + `hxlcl_atexit` register + `_hxlcl_atexit_drain` LIFO(`hxlcl_exit`가 `exit_group` 전 drain). libc `atexit`/`__dso_handle`(weak hidden `:78`)/CRT 완전 대체. | `self/runtime_emit_full.hexa:3335-3344` · drain hook `:2320` | **#4409가 배선**: `self/runtime_core_hxlcl_shim_emit.hexa:835`에 `#ifdef HEXA_ZEROC_OWN_START` 분기 추가(→ `_hxlcl_atexit_register`) + `stage_resolve_runtime_a:2614` S4 컴파일이 `$_mo_shim_def`(`""`) 대신 `$_zc_own_def` 사용 |

- **environ/atexit은 own-start front에 공동 번들** — 단일 `HEXA_ZEROC_OWN_START` default-ON flip이 둘을 동시에 절단. 독립 flip 불가.
- gate: **#4409 랜딩(shim MULTIOBJ + register 배선 수정)** → byteeq-3-target GREEN + install smoke → `HEXA_ZEROC_OWN_START` default-ON.

---

## 4. Execution roadmap — 참 terminal까지 ordered flip

선행 5-flip(qsort·regex·strtod·glob·fgets) **이후**의 순서. 각 flip은 default-OFF #ifdef → byteeq-3-target GREEN + faithful DROP 캡처 → default-ON 표준 게이트를 통과한다.

```
[선행] 5-flip 랜딩 (qsort·regex·strtod·glob·fgets)         floor 15 → 10
   └─ 게이트: 각 front byteeq-3-target GREEN + nm DROP 캡처

[FLIP-6] WALL-2 default-ON (calloc + realloc + free)        floor 10 → 7
   ├─ 의존: PR #4242(free)·#4244(calloc/realloc) 이미 머지 ✅
   ├─ 블로커: arm64/darwin Route-C fp-ABI xmm 커버리지 (else-arm IGNORED 해소)
   │          → stage_resolve_runtime_a:1930/2084/2131 non-x86 arm 구현
   └─ 게이트: byteeq 3-target GREEN + faithful DROP
              (__libc_calloc/__libc_realloc/__libc_free가 nm-UND에서 소멸 캡처)

[FLIP-7] own-start default-ON (environ + atexit 동반)        floor 7 → 4
   ├─ 의존: PR #4409 랜딩 (현 OPEN·CONFLICTING/DIRTY — main HEAD
   │        `_hxlcl_atexit_register` count = 0). 먼저 conflict 해소.
   │        → shim `:835` #ifdef 분기 + stage `:2614` $_zc_own_def 전파
   ├─ 블로커: own-start = bit-changing default-ON (5-flip·WALL-2와 달리
   │          bit-neutral 아님) → install-smoke 필수
   └─ 게이트: byteeq 3-target GREEN + install.sh consumer smoke GREEN
              (environ@GOTPCREL reloc 소멸 + atexit UND 소멸 동시 캡처)

[TERMINAL] 15-U 축 참 바닥                                    floor = 3
   └─ { dlopen, dlsym, dlerror } — vendor-FFI dynamic-linker WALL.
      native-canonical-default sanction. 알고리즘 이식 불가 = genuine WALL.
      → /goal "terminal reached" 마킹은 여기(floor=3)에서만 정당.
```

### 의존성 요약
- **FLIP-6 (WALL-2)**: 메커니즘 완료·PR 머지 완료. 유일 블로커 = **arm64/darwin fp-ABI Route-C 커버리지** + 3-target DROP 캡처. FLIP-7과 독립 병렬 가능.
- **FLIP-7 (own-start)**: **#4409 conflict 해소 + 랜딩이 선결**. bit-changing이므로 install-smoke가 추가 게이트. FLIP-6과 독립.
- 두 flip 완료 시 15-U floor = **3**(dlopen/dlsym/dlerror). 이것이 zero-c #29의 **참 terminal** — 그 아래는 vendor-FFI/loader primitive라 no-LLVM·native-canonical-default 정책 하에서 sanction된 영구 바닥.

### 정직한 종결 문장
> 5-flip + WALL-2 flip + own-start flip을 전부 랜딩하면 zero-c #29 15-U floor는 **15 → 3**으로 줄고, 잔여 3(dlopen/dlsym/dlerror)만이 **genuine FFI-loader WALL**이다.
> 선행 판정의 "permanent-WALL 4(atexit 포함)"는 **atexit 오분류로 1개 과다 집계** — atexit은 own-LIFO shim(#4409)으로 감축 가능한 CONDITIONAL이다.
> "conditional 3(environ/calloc/free)"은 별개 blocked front가 아니라 **WALL-2 flip·own-start flip으로 소멸하는 reducible**이다.
> 따라서 zero-c #29의 참 terminal은 floor=7이 아니라 **floor=3 (FFI-only WALL)**이며, 여기서만 /goal "terminal reached"가 정당하다.
