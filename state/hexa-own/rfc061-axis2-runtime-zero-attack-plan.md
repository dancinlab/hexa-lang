# RFC061 대공사 — axis-② runtime.c → 0 : round-by-round attack plan
**작성 2026-07-10 · 기준 origin/main `74a999708`** · 검증: 3-agent source sweep (Route-C wiring · CI run 29028266145 log · substrate census) + state/scratchpad/memory 정합.
⚠️ 이 체크아웃(`fix/install-bare-cuda-pip`)은 origin/main보다 ~305 커밋 뒤 — 라인 cite는 별도 표기 없으면 origin/main 기준, (wt)=working-tree.

---

## 0. 세 가지 baseline 정정 (재인용 금지 목록)

1. **"~210 fn irreducible" / "15-WALL" census는 stale 세대.** 진짜 floor = **46 nm-UND** (ship-witnessed, aiden `tool/release_build` runtime.a, #4759 `008709e46`) ≈ **43 real libc** (main/stderr/stdout 제외). CI advisory dump(run 29028266145, 07-09, aiden, `build/runtime.a` 1,123,702B) = 49 tokens(필터 leak 8 포함). `TOTAL undefined: 224`(unfiltered, hexa-own 포함).
2. **양대 wall은 이미 dissolved.** pair-ABI → Route C `_is_cabi` 81심볼 wired(`compiler/codegen/x86_64_linux.hexa:2245-2620`, 게이트 `HEXA_CABI_HXLCL` default-OFF=빈 whitelist=byte-identical). SA_RESTORER → `__hx_fn_addr`(#4264) + `@naked`(#4265) + wired `hxlcl_signal`(`stdlib/runtime/hxlcl_core.hexa` ~4553-4609 main / 4525-4589 wt). **signal·strtoll은 오늘 flip-ready** (verify script 존재).
3. **② DONE ≠ UND-∅.** DONE선 = "generated `.c`를 아무것도 컴파일하지 않는다". 2-트랙: **TRACK-U**(UND 46 → sanctioned-∅) + **TRACK-S**(substrate 32.75kLOC · 3(+1) TU + 16 fragment → 0 TU). nm-UND 서브트랙은 07-09 sanctioned-terminal 도달(#4753) — 캠페인은 substrate-led, UND drop은 라운드별 측정 신호.

---

## 1. TRUE current floor

### 1a. UND 축 — 46 ship-witnessed (aiden release_build, #4759)

| family | 심볼 | n | 분류 |
|---|---|---|---|
| stdio/FILE* | fopen fdopen fclose fflush fread fwrite fseek ftell fprintf fputs printf snprintf putchar getc fileno setvbuf perror popen pclose | 19 | **PORTABLE** — FILE*=(fd+1) 모델 기증명(#4109/#4113/#4116) · printf족=va-lane |
| syscall leaves | mmap munmap read lseek close dup2 getpid | 7 | **PORTABLE·body 기존재** — hxlcl_core에 native body merged(#4042-#4145 · mmap/munmap=FLIP-6 heap 동반), stage 게이트 블록만 부재 |
| signal | signal | 1 | **FLIP-READY** (`HEXA_RT_NATIVE_SIGNAL`, stage:2972-2997 main) |
| strto* | __isoc23_strtol __isoc23_strtoll | 2 | **FLIP-READY** (`HEXA_RT_NATIVE_STRTOLL`, stage:1850-1883 wt · body hxlcl_core.hexa:725/867) |
| float | strtod | 1 | **ANOMALY** — root 확정(§3 R1b): 3 잔존 ref |
| exec/process | fork execvp waitpid exit _exit abort | 6 | **PORTABLE** — fork/execvp/waitpid body+objcopy 블록 기존재 · exit/_exit/abort=raw-svc trivial |
| time | gmtime_r strftime | 2 | **PORTABLE** — 순수 알고리즘(musl ref) |
| CRT | __errno_location main stderr stdout | 4 | mixed — main=필터 artifact(프로그램 entry) · stderr/stdout=named-data(R3c에서 자연 drop) · __errno_location=전 caller native 후 own TLS cell(종반) |
| debug/tty | backtrace backtrace_symbols_fd cfmakeraw ptsname_r | 4 | cfmakeraw/ptsname_r PORTABLE(termios/pty kernel-ABI) · backtrace×2=**S2 self-symtab 첫 실수요**(조건부) |
| net-FFI / dl* / pthread / CUDA | ∅ | 0 | net=raw-svc 기이탈(#4379·getaddrinfo floor에 없음, ING `fc5b89b81`) · dl*=S1 파티션+HARD gate GREEN(`nobaseline-gate.yml:347-361`) · pthread=`HEXA_THREADS` 게이트로 default 0 · CUDA=opt-in archive |

합계 19+7+1+2+1+6+2+4+4=46. **대공사가 실제 줄이는 것**: stdio 19 + syscall 7 + signal 1 + strto* 2 + strtod 1 + exec 6 + time 2 + tty 2 + (조건부 backtrace 2 + CRT 3) = 40-45. **RFC061 후 정직한 UND 잔여**: linux canonical **∅ 도달 가능**(getaddrinfo는 이미 floor 밖 · __errno_location/backtrace만 순서 최후) — vendor .so는 비-canonical ffi_dyn TU(opt-in) 거주, darwin=영구 off-axis(`hexa_ld.hexa:56-57`).

### 1b. substrate 축 — 32,754 emitted-C LOC / ~1,090 distinct fn (측정)

| TU/fragment | emitter SSOT (LOC) | emitted C | Route-C portable? |
|---|---|---|---|
| runtime.c (외곽 TU) | `self/runtime_emit_full.hexa` (16,718) | 16,350 | YES |
| runtime_core.c | `self/runtime_core_emit.hexa` (11,164) | 10,691 | YES — `HEXA_ZEROC_RT_CORE_*` 17 클러스터 시드 기존재 |
| fragment ×16 (`self/runtime.c:15322-15531` #include) | `self/native/*_emit.hexa` 각 86-701 | 4,044 | YES 전원 |
| hxlcl shim | `runtime_core_hxlcl_shim_emit.hexa` (1,294) | 1,229 | YES — 소비자 소멸시 자연 ∅ |
| runtime_hi_gen.c | `runtime_hi_gen_emit.hexa` (491) | 440 | **이미 ∅** (Z2a 3-타깃 .s 시드, stage:1119-1128) = 패턴 증명 |
| runtime_ffi_dyn.c (비-canonical) | runtime_emit_full.hexa:16532 | ~200 | YES — `__hx_cabi_call` 필요 |
| runtime_cuda.c (opt-in) | runtime_cuda_emit.hexa | — | device 부분 NO(nvcc) — ② scope 밖 |

컴파일 사이트: `self/main.hexa:1738/1740`(clang -c runtime.c)·`:2274-2286`(cmd_build)·아카이브 `tool/stage_resolve_runtime_a:2664`(single-TU)/`:2639`(multiobj). **fn class 실측**(1,090 distinct): (a) HexaVal machinery **733=67%** portable · (b) raw-syscall wrapper **229=21%** · (c) vendor glue **72=6.6%**(`__hx_cabi_call` 대기) · (d) C-primitive **56=5.1%**(전부 escape 보유: setjmp native #4272 · va intrinsics · own-start). pthread=default-build UND 0(13 fn은 `-DHEXA_THREADS`시만). hot ≈6-8%(runtime.a 10 native member 205 export 근사).

**RFC061 성공 후 irreducible 잔여(정직)**: ① CUDA `.cu`(nvcc·opt-in archive) ② sanctioned UND 심볼축(직교) ③ hexa_cc.c(axis-① lane) ④ $CC-as-assembler(.s 시드 어셈블 — ②-합법, axis-③ own-emit이 독립 제거중).

---

## 2. RFC061 메커니즘 (현 wired 상태 + 갭 4개)

**wired (검증)**: `_is_cabi` 81심볼(hxlcl 79 + 의도적-extern hxlcl_malloc + `__errno_location`) `x86_64_linux.hexa:2235-2612`(wt) · 3경계×2백엔드(call x86:5084/arm64:3790 · return x86:5280/arm64:3953 · ingress x86:5558/arm64:4370) · fp SSE 분류기 `_cabi_sse_arg:2625`/`_cabi_is_fp:2687-2697`(x86 전용·8 fp심볼) · va-lane `HEXA_VA_INTRINSICS` 3타깃(x86 게이트 :2712·builtin :4690-4840 / arm64 :2213·:3325-3511 / bind.hexa:1385) · `__hx_fn_addr`(bind:1371·hir_to_mir:1609-1630·x86:3422·arm64:2418) · `@naked`(hir_to_mir:4394-4401) · in-body raw-payload 규율(`__hx_payload_lt/_ne/_sub`) · errno 에필로그(`__errno_location`+`__hx_ptr_store32`).

**tri-state stage 게이트 패턴**(전 라운드 공용, signal 블록=exemplar stage:2470-2500 wt): ⓐ env flip `${HEXA_RT_NATIVE_X:-0}` ⓑ host guard linux-x86_64 else IGNORED ⓒ `HEXA_CABI_HXLCL=1 --emit=asm` 시드 emit ⓓ `objcopy --keep-global-symbol=<sym>` demote ⓔ shim `-D` drop + ar member append ⓕ S5 `ld -r` multidef 0 게이트. 기존 블록 21개(strcmp/strstr/strtoll/free/atof/atoll/calloc/realloc/getenv/setenv/clock_gettime/time/signal/fork/execvp/pipe/popen/pclose/open_sys + libm).

**8-step 포트 파이프라인(proven)**: hexa body(raw-payload 규율) → `_is_cabi` whitelist → 3경계(기존) → pool freeze(.s 시드 커밋·resolve-time live-emit 금지 #4489) → stage tri-state 블록 → shim -D drop + sysheaders macro → verify script → CI dump+byteeq 3-target+install smoke → 별도 flip PR.

**잔여 codegen 갭 — 정확히 4개**:
1. **arm64 AAPCS64 fp-ABI rung** — 3사이트 전부 `!_cabi_is_fp` AND-out(x86:2681-2686 주석이 "NEXT rung" 명기). libm/atof 멤버의 3-타깃 승격 선결.
2. **`__hx_cabi_call`(indirect C-ABI call)** — repo-wide grep **0 hits, 실재 부재 확인**. 유일 신규 primitive. class-(c) 72 fn + `hexa_ffi_dlopen/dlsym` glue(`runtime_emit_full.hexa:3958-4134`) 포트의 선결. frozen-safe: `__hx_fn_addr`와 동일 additive name-prefix hook 클래스(새 keyword/파서 변경 0).
3. **`__init_array_*` hexa_ld 합성** — axis-③ 공용 rung.
4. **CI dump hygiene** — per-target dump + `_?hxlcl_` 필터 fix(§3 R1a).

---

## 3. Round-1 (즉시 실행)

### R1a — dump hygiene + substrate-dump (mini-safe·빌드 0·advisory-only)
`nobaseline-gate.yml:334`의 prefix 필터가 `_hxlcl_*` 미커버(`^hxlcl_`에 `_?` 부재) → 07-09 run leak 8: `_hxlcl_atexit_register _hxlcl_environ array_store fs_write_all_native join __init_array_end __init_array_start main`. FIX: `^(_hx_|__hexa|__hx_|__blk_|rt_|hexa_|_hexa|_?hxlcl_|_GLOBAL)` + hexa-own emit-helper 클래스(`^(array_store|fs_write_all_native|join)$`)+`^__init_array_`+`^main$` 제외 라인 추가. **동시에 substrate-dump advisory step 신설**(nm-dump 형제·never-gates): ① 컴파일되는 generated-.c TU 수(현 3(+1)) ② runtime.c live `#include "native/*.c"` 수(현 16) ③ $CC에 넘어가는 generated-C LOC(현 ~32.7k). 이 3 메트릭이 TRACK-S의 라운드별 캡처 신호.

### R1b — strtod anomaly 종결 (root 확정·이 문서가 첫 박제)
#4651 native-tail default-ON에도 ship UND 잔존의 root = **reference-retention 3사이트**:
- `self/runtime_core_emit.hexa:2128` — 3-tier(fast/EXACT/hexinfnan) 전부 ON이어도 terminal junk-fallback `return hxlcl_atof(cs)` emit 유지(#3583 규율).
- `self/runtime_emit_full.hexa:5388` — `hexa_float(strtod(HX_STR(s), NULL))` 직접 호출(step-3 cycle 73 포트 잔재).
- `self/runtime_emit_full.hexa:14592` — float-print round-trip check `if (strtod(buf, NULL) == f) return;`.
FIX: :5388→`__hexa_num_parse_float` 경유로 교체 · :14592→native parse 재사용(runtime_core_emit.hexa:7979 선례 "round-trip CHECK reuses the native parse") · :2128→`HEXA_RT_STRTOD_TAIL_NATIVE` ON시 junk=0.0 native 종결(OFF시 C fallback 유지=#3583 존중). 게이트: float parity corpus(#4651 n=140,678 재실행) + ship nm-witness strtod 소멸.

### R1c — flip 2발 (신규 코드 0 · UND −3)
- `HEXA_RT_NATIVE_SIGNAL` `:-0`→`:-1` — signal drop(−1). verify=`tool/routec_signal_native_verify.sh`(set→raise→fire→clean-return RC=0·구 SIGSEGV 재발 감지).
- `HEXA_RT_NATIVE_STRTOLL` `:-0`→`:-1` — __isoc23_strtol+strtoll drop(−2). verify=`tool/routec_strtoll_native_verify.sh`(value-exact+errno/ERANGE).
게이트(각 flip 공통·별도 PR): byteeq 3-target GREEN(linux x86_64 멤버셋 bit-changing) + faithful-nobaseline UND-drop 캡처 + install.sh consumer smoke + **ship-witness는 `tool/release_build`로만**(#4759 warm-build 함정: bare stage_resolve는 FLIP-6 미발화). RED→default-OFF revert(#4489 선례).

### R1d — substrate census work-list + #4595 선결
synthesized runtime.c/runtime_core.c fn-def awk 인벤토리 × native 커버리지(nm -g: SELFEMIT 21멤버·flip 시드·RT_CORE 17클러스터) diff → `state/rfc061-substrate-census.md` = R9/R10 work-list SSOT. **#4595(co-drop 레지스트리, open)를 캠페인 선결로 착지** — #4591 S5-multidef 클래스 방지, 전 라운드가 이 레지스트리 경유.

**R1 기대 델타**: UND 46→43 + strtod 소멸(→42) + 측정 하네스 신뢰화. 리스크: 최저(코드 0·flip+hygiene만).

---

## 4. Round map (2-트랙 · 각 라운드 = feat(default-OFF) PR + 별도 flip PR)

### TRACK-U — UND-led (Route C 포트·리스크 오름차순)
| R | 타깃 | 메커니즘 | Δ UND |
|---|---|---|---|
| 1 | hygiene+signal+strtoll+strtod | §3 | 46→42 |
| 2 | syscall leaves: mmap/munmap/read/lseek/close/dup2/getpid | body 기존재(hxlcl_core) — stage tri-state 블록 7개 신설만(codegen 0) | −7 → 35 |
| 3 | stdio: 3a byte-stream own-FILE(fd+1 기증명) · 3b printf/fprintf/snprintf/perror va-lane+T_mis 포맷 오라클 · 3c stderr/stdout `__hx_static_slot` named-data + popen/pclose(블록 기존재) | va-lane 실전 첫 대량 소비·최대 라운드 | −19 → 16 |
| 4 | time/tty: gmtime_r·strftime(musl 1:1)+cfmakeraw·ptsname_r | 순수 알고리즘+kernel-ABI struct | −4 → 12 |
| 5 | exec/process: fork·execvp(블록 기존재)+waitpid+exit/_exit/abort(raw-svc) | 대부분 flip급 | −6 → 6 |
| 6 | CRT/debug: backtrace×2(S2 self-symtab 첫 실수요·hexa_ld+#4462 재사용)+main 필터분류+__errno_location own-TLS-cell(최후) | S2 구조 진입 | −4 → ~2 |
| 7 | **arm64 AAPCS64 fp-ABI rung** + x86-only 멤버(libm/atof/strtoll 등) 3-타깃 승격(stage else-arm IGNORED 해소) + getaddrinfo GO/NO-GO(현 floor 밖) | 갭(1) 해소·3-target 대칭 | 대칭화 |

### TRACK-S — substrate-led (병렬 인터리브 · scratchpad/rfc061_delegate.md.result §4 레일 승계)
| S | 타깃 | Δ |
|---|---|---|
| a | **FRAG-KILL 사다리**: mount(71 LOC·zero-reloc 실증) → namespace/wait/proc_fork → fp_init(@naked MXCSR)/signal_flock → exec_pipe/exec_argv_sha256/persistent_pipe → term_ffi/pty → thread(extern-call body·pthread whitelist) → net/crypto(extern-call vendor glue) → tensor_kernels(perf 게이트) | live fragment 16→0 |
| b | **`__hx_cabi_call` primitive**(갭 2) + runtime_ffi_dyn.c→.hexa(비-canonical=byteeq-neutral 무게이트) | TU 1 소멸 |
| c | runtime_core.c 클러스터 드레인(17 `HEXA_ZEROC_RT_CORE_*` 재개 + R1d census 잔여) → 전 클러스터 ON-green에서 m3 all-or-nothing TU drop | TU 3→2 |
| d | runtime.c 잔여(FFI dispatch·float format·io rt_*·own-start asm→.s 시드) → m3 TU drop | TU 2→1 |
| e | hxlcl shim TU 은퇴(소비자 전멸 후) + `runtime_core_sysheaders.h` 삭제 | TU 1→0 = **② DONE** |
| f | m4: emitter 은퇴 + restore_frozen_seeds awk 제거 — gen3≡gen4 + 3-target shipping smoke·WIPE-OK 디시플린 | 기판 소멸 박제 |

**터미널(정직)**: S-e 후 canonical CPU runtime.a = 100% hexa-emit native 멤버·default 경로 generated-.c 컴파일 = **0** = ② literal DONE. TRACK-U 종점 = linux canonical UND-∅ 도달 가능(backtrace/__errno_location이 최후·getaddrinfo/NSS는 이미 floor 밖). 잔여 4종(§1b) — 오늘의 sanctioned-floor보다 심볼축은 안 작아지나 **기판축이 ∅**. darwin=영구 off-axis.

---

## 5. Kill-criteria (family별 · 전부 captured-output 판정)

| family | 벽 신호(측정) | escape / 판정 |
|---|---|---|
| R1c flips | verify script RED(signal SIGSEGV 재발·strtoll errno mismatch) | root-cause 후 재시도 — restorer/errno 메커니즘 기증명이라 회귀=버그, 벽 아님 |
| syscall leaves (R2) | 유일 후보=vDSO 상실 perf(clock_gettime류) hot-bench 회귀 캡처 | 그 fn만 extern-call body 유지 — 벽 아님 |
| stdio (R3) | printf T_mis 포맷 오라클 mismatch>0 잔존 · FILE* 내부 struct 실수요 발견(현재 0: fd+1로 전부 해소) | mismatch fn만 C 잔류·박제 후 다음 라운드 명명 · struct 실수요=그 fn extern-call |
| time/tty (R4) | strftime locale 실수요(현 코드베이스 C-locale뿐) | locale 미지원 명시(reference-match musl C-locale) |
| exec (R5) | 없음 예상(kernel-ABI) — execvp PATH-walk는 getenv native(#4611) 기해소 | — |
| backtrace (R6) | S2 self-symtab 예산 초과(DWARF/unwind 복잡도 측정) | backtrace×2만 sanctioned 박제 — UND 2 잔존 수용, ② 기판축 무영향 |
| arm64 fp (R7) | AAPCS64 v0-v7 lowering byteeq 3-target 발산 | x86-only 유지+IGNORED else-arm 지속=현상 유지(벽이면 3-target 승격만 포기) |
| pthread (S-a thread) | extern-call body가 TLS/ctor 순서로 S5/smoke FAIL | ② 충족엔 extern으로 충분 — own-clone은 별도 캠페인, kill 아님 |
| vendor glue (S-b) | `__hx_cabi_call` frozen-unsafe 판명(파서/blob 변경 강제) | 측정 후 정직 박제 — ffi_dyn TU 1개만 C 잔류(② 99% 달성) |
| HexaVal 클러스터 (S-c) | ① F5 bench ≥5% 회귀가 최적화 1라운드 후에도 잔존(숫자 캡처) ② gen3≢gen4 발산 | ① 그 클러스터 C 잔류·defer(다음 라운드 명명) ② 하드스톱=miscompile root-cause(m12/c14 선례) |
| m3 TU-drop (S-c/d) | 1심볼 미해소=link FAIL | 전 클러스터 ON-green 빌드에서만 시도 — 실패=미성숙, 벽 아님 |
| CUDA | 정의상 terminal(nvcc device·own-PTX는 별도 캠페인) | ② scope=canonical CPU archive 명시 |

**공통 거버넌스**: 모든 flip=bit-changing→byteeq 3-target GREEN+faithful-nobaseline+install smoke, RED→default-OFF revert(#4489) · ship-witness=`tool/release_build`만(#4759 warm-build 함정) · 시드 regen=pool 전용(mini=git/gh) · restore_frozen_seeds 편집=faithful canary 필수(#4431/#4429) · frozen 151c52c8 불변(신규 primitive는 additive name-prefix hook만) · NO self-merge · release integrity > self-host progress.

## 근거 문서
- 검증 CI log: nobaseline-gate run 29028266145(gh run view·repo에 미저장) · #4759 ARCHITECTURE.json `zeroc-frontier-wall-residual` 노드(46-list verbatim)
- `state/hexa-own/axis2_post_flip6_floor_census.md`(#4753·origin/main) · `state/zeroc-29-floor-to-zero-endgame-ssot-2026-07-03.md`(PHASE A/B 완료) · `scratchpad/rfc061_delegate.md.result`(TRACK-S 상세)
- memory: `project_hexa_rfc061_runtime_zero_plan`(★SSOT) · `project_hexa_rfc061_hxlcl_crosstarget_abi_wall` · `project_hexa_rfc061_hxlcl_signal_restorer_wall`
