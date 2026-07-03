조사가 끝났습니다. 발산 결과를 정리합니다.

# 발산 돌파 판정 — zeroc #29 마지막 WALL: `dlopen`/`dlsym`/`dlerror` → floor 0 (진짜 ∅)

## 1. 판정: **irreducible WALL 아님 — 구조변경으로 제거 가능 (조건부 floor→0)**

현 verdict(`state/zeroc-29-terminal-front-reduction-2026-07-03.md`:35)의 논거는 *"runtime dynamic-linker가 필요하므로 알고리즘 이식으로 제거 불가 = genuine WALL"* 이다. 이 논거는 **두 지점에서 반증된다**:

1. **runtime dynamic linker는 알고리즘이다.** musl의 `dynlink.c`(~2.4kLOC portable C)가 존재 증명이고, repo 안에서는 `compiler/link/hexa_ld.hexa`(3,207 LOC)가 이미 ELF64 리더·symtab 워크·`read_elf_relocs`·GOT 분류기(`elf_reloc_is_got_typed`)·`ET_DYN` emit(PT_DYNAMIC + .dynsym/.dynstr/.hash, RFC 070 G7-B ✅)을 갖고 있으며, `tool/hexa_ld.hexa`(2,473 LOC)는 Mach-O arm64 reloc 처리(BRANCH26·PAGE21/PAGEOFF12·GOT_LOAD relaxation)를 이미 수행한다. STATIC 링킹과 RUNTIME 링킹의 차이는 "언제 reloc을 패치하나"뿐이다.
2. **repo 자신이 이미 이 경로를 예약해뒀다.** `docs/rfc/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` §3.A option (c): *"custom relocatable blob + own loader; libc-free ⇒ **reserved for libc-free mandate**"*, §5-1: *"If a future 'no libc' mandate lands, option (c) custom loader is the bridge."* zeroc #29 floor-∅가 바로 그 no-libc mandate다. G7-C(`hexa_dlopen` 계열)는 **아직 미구현**이라 설계 충돌 없이 own-native로 착지시킬 수 있다.

단, 정직한 한정 두 가지:

- **darwin은 floor-∅ 축 밖이다.** `hexa_ld.hexa` 자체 주석(L56)이 명시하듯 truly-static Mach-O는 커널이 거부한다(`LC_LOAD_DYLINKER`/dyld 필수). darwin에서 dl*는 libc floor가 아니라 **OS-mandated ABI 표면**(syscall과 동급)이므로, ∅ 판정 축은 Linux ELF다 — 이는 기존 nm-UND floor 캠페인이 이미 채택한 프레임과 일치한다.
- **glibc-빌드 vendor `.so`(cuBLAS 체인)를 자체 로더로 직접 로드하는 것은 UND 이동일 뿐 소멸이 아니다** (§3-A 반증 참조). 그래서 해법은 "만능 로더 1개"가 아니라 **계층 분해**다.

## 2. 사용처 census (measured)

libc `dlopen`/`dlsym`/`dlerror`의 nm-UND 원천은 **단일 표면**이다: `self/runtime.c`의 FFI 계층.

| site | 역할 | 요구사항 |
|---|---|---|
| `hexa_ffi_dlopen` (`runtime.c:3102`) | `@link` 라이브러리 탐색 (framework/dylib/so/CUDA-dir 폴백 사다리) | 전부 `RTLD_LAZY`, `RTLD_GLOBAL` 없음 |
| `hexa_ffi_dlsym` (`runtime.c:3227`) | 심볼 1개 resolve | 실패 시에만 `dlerror` (진단 문자열) |
| `hexa_host_ffi_open/sym` (`runtime.c:~3505`) | `hexa run` 인터프리터의 `@link` extern 디스패치 | `dlopen(NULL)` self-handle 포함 |
| codegen init 라인 (`self/codegen.hexa:2736`) | `__ffi_sym_X = hexa_ffi_dlsym(hexa_ffi_dlopen(lib), "sym")` in `main()` | extern 선언이 있을 때만 방출 |

**무엇을 로드하나** (stdlib `@link` census): `hxpyembed`×13 · `c`×9 · `hxffi_slot`×6 · `m`×5 · `hxblas`×2 · `sqlite3`×1, 그리고 `self/ffi/hxcuda_matmul.hexa`가 첫 호출 시 `libnvrtc`/`libcublas`를 lazy-load. 핵심 관찰 셋:

- **runtime.a 본체의 cuBLAS는 dlopen이 아니라 link-time**(`#ifdef HEXA_CUDA` + `-lcublas`, `hexa -cuda` 릴리스 변종 #3682). dlopen-CUDA는 사용자측 FFI뿐.
- **`@link("m")`은 이미 절반 소멸했다**: FFI-NATIVE-ROUTE(`codegen.hexa:2588`)가 libm double 계열을 `hexa_math_*` 네이티브로 라우팅해 dlopen init 라인 자체를 방출하지 않는다 — "dlopen 사용은 라우팅으로 줄어든다"의 기존 선례.
- **로더 기질은 이미 libc-free다**: `hxlcl_mmap`은 raw-svc(darwin `svc 0x80` SYS_MMAP=197 carry-flag-correct, `runtime.c:1900`; SELFEMIT 시 hexa-emitted `.o`)로 이미 존재. arena alloc·raw-svc leaf(#4358/#4364) 선례와 함께, 자체 로더가 필요로 하는 커널 표면(mmap/mprotect/open/read/close)은 전부 자체 조달 가능.

## 3. 메커니즘 패밀리 (발산 · 5안 + 각 반증)

### (A-general) 범용 native dynamic loader — glibc vendor `.so`까지 직접 로드
mmap PT_LOAD → DT_NEEDED 재귀 closure → `.dynsym`/GNU-hash resolve → `R_X86_64_{GLOB_DAT,JUMP_SLOT,RELATIVE,64,TPOFF64,DTPMOD64,IRELATIVE}` 패치 → TLS 블록 → init_array.
**반증**: 메커니즘은 가능하나(musl 증명) **심볼 생태계 closure가 진짜 벽**이다. `libcublas.so.12`의 NEEDED 체인은 `libstdc++`/`libgcc_s`/`libpthread`/`librt`/`libm`/`libc`/`ld-linux`까지 끌고 오고, glibc-빌드 `.so`는 ld.so-사적 심볼(`__tls_get_addr`, `_dl_find_object`, IFUNC resolve 시맨틱, symbol versioning)을 요구한다. glibc의 `libc.so.6`은 자기 짝 `ld-linux`와 매칭 쌍이라 제3자 로더로 로드 불가에 가깝다. 결과 = **UND가 사라지지 않고 자체 로더의 재구현 표면으로 이동**. 판정: REFUTED (vendor `.so` 축에서). LOC ~4–8k + glibc-호환 무저갱.

### (B) 정적 링크 — dlopen 자체 불요화
NVIDIA는 `libcublas_static.a`를 배포하므로 `-cuda` 변종에 static link 가능. python/sqlite3/wilson-plugin 같은 런타임 확장성 축은 커버 불가, 바이너리 수백 MB.
**판정**: 부분해. 폴라리티는 안 깨진다(변종=opt-in). 그러나 이미 `-cuda` 변종은 DT_NEEDED 동적 링크로 dlopen 없이 동작하므로 **B는 사실상 불필요** — 변종 분리(E)가 같은 효과를 더 싸게 준다.

### (C) 자체 로더 — **hexa-emitted fat `.so` 한정** (RFC 070 option (c) 실체화)
RFC 070이 채택한 fat-`.so` 규약(§3.A-b)이 로더 문제를 극적으로 축소한다: *deps 전부 static-linked, export 정확히 1심볼, PLT 없음, GOT data-only* ⇒ 필요한 reloc은 사실상 `R_*_RELATIVE`(+자기 export 1개)뿐, TLS 없음, NEEDED closure 없음. 로더 = `hxlcl_mmap`(PT_LOAD) + relative-fixup 루프 + 1-심볼 lookup + `mprotect(PROT_EXEC)` + init 호출. `hexa_ld`의 ELF 리더·`read_elf_relocs`를 그대로 재사용.
**판정**: FEASIBLE, ~600–1,200 LOC. `hxblas`/`hxffi_slot`/wilson-plugin 등 **hexa가 만든 `.so`** 전부 커버. vendor `.so`는 커버 불가(의도적).

### (D) link-time self-symtab — `dlopen(NULL)`/`@link("c")`/`@link("m")` 소멸
`hexa_ld`는 링크 시점에 전 심볼을 안다. `.hexa.symtab` 섹션(FNV-hash 정렬 name→addr 테이블, #4462의 strtab FNV 인덱스 선례 재사용)을 바이너리에 굽고, `hexa_dlsym(SELF, name)` = bsearch. floor-0 static 바이너리에서 `@link("c")`의 `strlen`류는 `hxlcl_strlen`으로 resolve되거나 fail-loud — codegen의 musl-static FFI-NULL-GUARD가 이미 이 시맨틱을 규정해뒀다.
**판정**: FEASIBLE, ~150–300 LOC. `hexa run` 인터프리터 FFI의 지배적 사용처(self-handle resolve)를 죽인다.

### (E) floor-partition + 변종 분리 — **구조적 즉효**
`hexa_ffi_dlopen/dlsym` + `hexa_host_ffi_*`를 runtime.a에서 **별도 TU(`runtime_ffi_dyn.o`)로 축출**하고, codegen이 "native-route 후에도 살아남은 vendor extern이 있을 때만" 그 TU를 링크한다(codegen은 이를 정적으로 안다 — init 라인 방출 여부와 동일 조건). 결과: **canonical runtime.a의 nm-UND에서 dl* 3심볼이 물리적으로 소멸** — 현재 `nobaseline-gate.yml:321`의 sanctioned-제외 grep 필터가 필요 없어지고, 무필터 `nm -u runtime.a | grep dl` = ∅. vendor-FFI를 실제로 쓰는 프로그램만 libc dlopen TU를 물고 간다(= "external deps opt-in-flag-only"의 링크-단위 구현).
**판정**: FEASIBLE, ~1–2일, byteeq-neutral로 설계 가능(비-FFI 프로그램의 emit은 불변).

## 4. native-canonical-default 정합 — 자체 로더는 폴라리티에 *더* 부합한다

현 상태는 오히려 폴라리티 위반의 냄새가 있다: vendor `.so`를 하나도 안 쓰는 바이너리조차 **vendor libc의 동적 링커(ld.so) 의존을 무조건 지참**한다. E+D+C 이후:

- default path = own-static + own-symtab + (필요 시) own-loader — **전부 hexa-native**. `hexa_ld`가 static 링킹을 소유하듯 런타임 링킹도 소유한다.
- vendor 생태계(cuBLAS·python·sqlite3)는 opt-in TU/변종에서만 libc dlopen을 쓴다 — 이것이 정확히 "opt-in-flag-only external dep"이며, sanction의 위치가 "runtime.a 전역"에서 "opt-in 표면"으로 좁혀진다.

## 5. 추천 설계 (staged composite: E → D → C)

| stage | 내용 | 파일 | gate |
|---|---|---|---|
| **S1 (E)** | `hexa_ffi_dlopen/dlsym`·`hexa_host_ffi_*`·`hexa_extern_load`를 `runtime_ffi_dyn` TU로 분리, `runtime_emit_full.hexa`의 해당 방출 블록(L3958–4136, L4417–4445)도 동일 분리. codegen이 surviving-extern 존재 시에만 링크 편입(`stage_resolve_runtime_a` 경로에 TU 조건 추가) | `self/runtime.c`·`self/runtime_emit_full.hexa`·`tool/stage_resolve_runtime_a` | byteeq 3-target(비-FFI emit 불변 증명) + `hexa run` c_ffi smoke |
| **S2 (D)** | `hexa_ld`에 `.hexa.symtab` emit(+FNV 인덱스), `runtime_ffi_dyn` 밖에 own `hexa_dlsym_self()` 추가, `dlopen(NULL)`/`@link("c")`/`@link("m")` 경로를 self-symtab으로 라우팅. FFI-NATIVE-ROUTE를 strlen-family로 확장(codegen.hexa:2586이 이미 "named next wall"로 지목) | `compiler/link/hexa_ld.hexa`·`self/runtime.c`·`self/codegen.hexa` | default-OFF `HEXA_SELF_SYMTAB` → byteeq → flip |
| **S3 (C)** | RFC 070 **G7-C를 own-native로 착지**: `hexa_dlopen_own(path)` = `hxlcl_mmap` PT_LOAD + `R_*_RELATIVE` 패치 + 1-export lookup + `mprotect` + init — **Linux ELF x86_64/arm64만**, fat-`.so`(G7-B ✅ 산출물) 한정. `hexa_dlerror_own` = static 버퍼. darwin은 libc dlopen 유지(OS-mandated, floor 축 밖) | 신규 `self/runtime_dynload.c`(또는 hexa-emitted) + `stdlib/dynlink.hexa` | default-OFF `HEXA_OWN_DLOPEN=1` → F-C1/F-C2 falsifier(RFC 070 §4.1) → byteeq 3-target → flip |

**크로스타깃 위험** (과거 seed 함정 대조):

- **arm64 icache**: text 페이지에 fixup을 쓴 뒤 `PROT_EXEC` 전환 시 cache flush(`IC IVAU`/`__builtin___clear_cache`) 필수 — br_cond inline-truthy seed(#SIGSEGV)류의 "실행됐는데 stale" 함정과 동형. 로더 self-test에 필수 포함.
- **W^X**: mmap RW → 패치 → mprotect RX 2-phase. darwin MAP_JIT 문제는 scope 밖(로더 Linux-only).
- **pair-model ABI wall**(hxlcl cross-target 메모리)은 비적용 — 로더는 seed asm이 아니라 런타임 C/hexa 코드이고, resolve된 주소로의 호출은 기존 `__ffi_ftyp_*` fn-ptr 캐스트 경로를 그대로 쓴다.
- **SA_RESTORER류 kernel-ABI 함정** 비적용 — 로더는 시그널 ABI를 건드리지 않는다.

## 6. 비용/위험 요약

| 항목 | 추정 |
|---|---|
| S1 partition | ~200 LOC 이동 + 빌드 배선, byteeq-neutral, **floor→0 즉시 달성**(canonical 축) |
| S2 self-symtab | ~150–300 LOC, `hexa_ld` 심볼 뷰 재사용, 리스크 낮음 |
| S3 own loader | ~600–1,200 LOC(ELF 리더 재사용 시 하한 쪽), 리스크 = arm64 icache·ASLR·mprotect 시퀀스 — 전부 falsifier로 고정 가능 |
| A-general (기각) | ~4–8 kLOC + glibc-compat 표면 무한 — **UND 이동일 뿐 소멸 아님**, 착수 금지 권고 |
| cuBLAS 정합 | 불변 — `-cuda` 변종은 link-time DT_NEEDED(이미 dlopen 불사용), 사용자측 lazy-CUDA는 opt-in `runtime_ffi_dyn` 지참 |
| darwin | floor-∅ 축 밖(커널이 dyld 강제) — dl* sanction이 "libc floor"에서 "OS ABI"로 재분류될 뿐 |

## 7. 결론 한 줄

**floor→0 가능** — dl* 3심볼은 genuine WALL이 아니라 "runtime.a 전역 sanction"이라는 구조 선택의 산물이며, S1(FFI TU 축출)만으로 Linux canonical runtime.a nm-UND는 무필터 ∅에 도달하고, S2+S3(RFC 070 G7-C의 own-native 착지)로 hexa-산 `.so`의 런타임 링킹까지 자체 소유가 된다; 유일하게 남는 진짜 벽은 "glibc-빌드 vendor `.so`를 glibc 없이 로드"(A-general)뿐인데, 그것은 floor 축이 요구한 적 없는 목표다.