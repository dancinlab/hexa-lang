# zero-c #29 floor — authoritative census (2026-07-03, origin/main e4d20d87)

측정: summer, CC=clang-18, native/*.c regen from emitters + stage_resolve_runtime_a rebuild + nm -u.
runtime.a 1082484B · **총 U=75** (hexa-own __blk_*/__init_array 제외 후 libc-floor).

## regen 후 DROP 확인 (build-freshness였음, native impl 유효)
flock · mount · umount2 · unshare · setns · sigaddset (6) — #4385/#4377 raw-svc, native/*.c regen시 drop.

## 내 default-OFF flip 대기 (flip시 drop)
sysconf(#4412) · mallopt(#4414) · mkstemp · mkdtemp(#4415) (4)

## 여전히 U — workflow "native" 주장 측정 반증 = 진짜 reducible (다음 라운드)
- getppid: hxlcl_getppid raw-svc 존재(runtime_emit_full:1856/2955)나 term_ffi_emit:207-211 #ifndef HXLCL_PROC_SC0가 libc-fallback getppid 재정의 → emission ordering상 libc 승 → U
- setsid: 동일 #ifndef HXLCL_PROC_SC0 블록(term_ffi_emit:210 libc setsid) + proc_fork_emit:45 직접 setsid()
- rand: hxlcl_rand LCG 존재(4780)나 runtime_emit_full:4532 hexa_random + 6432 sample + tensor_kernels_emit:310-311이 libc rand() 직접(hxlcl_rand 미배선)
- sigemptyset: hxlcl_sigemptyset native(2898)나 #define hxlcl_sigemptyset(s) sigemptyset((s))(2912)가 재-libc + runtime_emit.hexa:3475/3488 직접
→ 근본=native impl 존재하나 직접 libc callsite/ #ifndef ordering이 우회. byteeq-safe wiring 필요(난제=다중-def ordering).

## WALL (~15, sanctioned)
__libc_calloc · __libc_free (transitive) · atexit(CRT) · dlerror/dlopen/dlsym(FFI) · environ(CRT) · fgets(FILE* layer) · glob/globfree(fnmatch fidelity·MEDIUM) · qsort(tie-order unspecified) · regcomp/regexec/regfree(ERE oracle) · strtod(IEEE oracle)

## /goal 상태
clean 단일 감축 착륙 완료(4 default-OFF). 잔여 reducible=getppid/setsid/rand/sigemptyset(callsite-wiring·#ifndef ordering 근본·Fable 하드분석 위임중). WALL만 남으면 종료조건 충족.

## ★ROOT-CAUSE (Fable bzjcv3u3e, origin/main ee4b0401e): frozen-seed fragment wire-gap
4심볼(getppid/setsid/rand/sigemptyset)은 #ifndef ordering 버그 아님. 근본=`tool/restore_frozen_seeds`가
term_ffi.c/proc_fork.c/signal_flock.c/tensor_kernels.c를 frozen 151c52c82서 복원하고 **emitter서 regen 안 함**
(runtime.c는 awk-synth하나 이 4 fragment는 FROZEN_SEEDS list만) → #4371/#4373/#4387 emitter native-wiring이
ship 안 됨(구현됨·미배선). frozen 복사본이 getppid()/setsid()/sigemptyset()/rand() raw 호출.
내 census도 term_ffi/proc_fork/tensor_kernels 미regen이라 여전히 U(signal_flock만 regen→sigaddset drop,
sigemptyset은 term_ffi callsite라 잔존=비대칭 설명).

## FIX = coherent 캠페인(전부 default-OFF·faithful-nobaseline 게이트·fresh 세션 실행)
- Diff A (rand·HEXA_ZEROC_RAND_NATIVE): tensor_kernels_emit:310-311 gate 소급 + restore_frozen_seeds ZEROC-RAND awk patch(ZEROC-LIBM 선례). flip시 randn PRNG=hxlcl_rand(divisor 동일 2147483648.0).
- Diff B (getppid/setsid fallback-harden·HEXA_ZEROC_PROC_SC0_RAW): term_ffi_emit:207-211 + proc_fork_emit:41-45 #ifndef 내 raw-svc(NR 110/112·173/157) default-OFF.
- ★Diff C (load-bearing·HEXA_ZEROC_FRAG_REGEN): restore_frozen_seeds에 FRAG-REGEN 블록 추가(term_ffi/signal_flock/proc_fork를 emitter서 synth). 이게 #4371/#4373 callsite rewire를 실제 ship시킴.
상세 diff=state/zeroc-floor-fragregen-fable-2026-07-03.md. Diff C awk body는 Fable 출력 truncated(재실행 or 직접작성).
게이트: 전부 default-OFF byte-neutral, flip은 byteeq 3타깃+faithful-nobaseline+smoke GREEN 후. restore_frozen_seeds=벽 vehicle이라 faithful canary 필수.

## ★FLIP 측정 (2026-07-03, summer clang-18, restore_frozen_seeds+8매크로 -D ON) = state/zeroc-flip-measure-2026-07-03.txt
측정경로 교정(verdict-integrity): stage_resolve_runtime_a는 restore_frozen_seeds 미호출(line 118)→1차측정 INVALID. 2차=restore 先실행(frag #ifdef term_ffi 3·proc_fork 1·tensor 1·runtime.c mkstemp/sysconf 2)+CFLAGS_COMMON에 8매크로 -D.
- ✅ 내 8게이트 ON에서 전부 DROP: getppid·setsid·rand·sysconf·mallopt·mkstemp·mkdtemp (nm서 사라짐=배선 검증 PASS)
- ⚠️ BUT restore_frozen_seeds가 stale frozen mount.c/namespace.c/signal_flock.c 복원→flock·mount·unshare·setns·umount2·sigaddset 재등장(libc U). #4385/#4377 syscall-family도 emitter만·restore 미regen=동일 frozen-seed wire-gap 미배선.
- 총 75 U(내 8 빠지고 syscall-family 7 재등장)

## ▶TERMINAL PATH: FRAG-REGEN (Fable Diff C·load-bearing)
targeted patch(내 8게이트)는 valid 증분이나 INCOMPLETE — restore_frozen_seeds가 frozen frag를 stale로 복원하는 게 systemic 근본. **완전 fix=restore_frozen_seeds에 FRAG-REGEN 블록(term_ffi/proc_fork/signal_flock/mount/namespace/tensor_kernels를 emitter서 synth)** → 전 frozen-frag 심볼(내 8 + #4385/#4377 family)이 한번에 native ship. Fable Diff C=state/zeroc-floor-fragregen-fable-2026-07-03.md(awk body truncated→Fable 재실행 or 직접). byteeq-critical vehicle이라 faithful-nobaseline canary 필수(own-start 교훈). flip(내 8게이트 default-ON)은 FRAG-REGEN 후 or 병행.

## ★WALL 재평가 (workflow w6jf68tjq · break-walls multi-lens · 2026-07-03) = state/zeroc-wall-reassess-2026-07-03.md
census가 "WALL"로 부른 ~15 중 5개가 lazy ceiling(reducible)로 falsified:
- strtod: REDUCIBLE(finite-decimal 이미 native seed #4200·rt_parse_float_native+rt_str_parse_float_exact·3타깃 bit-exact·default-OFF). 잔여=hex/inf/nan tail만(musl __floatscan ~40 LOC exact-by-construction). Rank1=measure-and-flip(신규코드 0)
- qsort: REDUCIBLE(byteeq-risk 역전=stable native가 더 결정적). Rank3=HEXA_RT_ARRAY_SORT_NATIVE seed(NaN-last cmp+stable HexaVal merge sort·array_core 패턴)
- fgets: REDUCIBLE(FILE* 아니라 line-splitter·native fd read-loop 존재 poll_impl). Rank5=HEXA_RT_STREAM_NATIVE_READ
- glob/globfree: REDUCIBLE(fs_glob+glob_matches native 존재·single-level */?만). Rank4=HEXA_RT_GLOB_NATIVE(smoke-gate·fixed-order cmp NOT via hexa_array_sort)
- regcomp/regexec/regfree: REDUCIBLE + byteeq-NEUTRAL(main.hexa 0 regex=self-host fixpoint 미실행). Rank2=HEXA_REGEX_NATIVE(thompson+backtrack 엔진 존재·(?i)/[[:...:]] 추가만). faithful/@ci_gate 검증(3타깃 byteeq 아님)

## ★진짜 floor-∅ 경계 (/goal 종료지점 = terminal set)
- 영구 WALL(2): dlopen/dlsym/dlerror(sanctioned FFI·native-canonical-default·CUDA 탑승) · atexit(musl-matched #4275·ship서 never fire)
- 조건부(별도 캠페인·2): environ(own-start default-ON시 해소·현 #4408 revert) · __libc_calloc/__libc_free(WALL-2 arena-calloc/free port)
- 이미 해소 mislabel: syscall(hexa own inline-asm raw-svc·libc dep 아님)
결론: 진짜 종료지점=~2 영구+2 조건부. 나머지(FRAG-REGEN 10심볼 + strtod/qsort/fgets/glob/regex)는 전부 reducible. cross-dep: hexa_array_sort→qsort(runtime.c:5551)라 Rank3(sort) before Rank4(glob).

## ★QA VERDICT (2026-07-03 #2, HEAD 654cbb5e + FRAG-REGEN sentinel-fix, summer clang-18)
#4427 FRAG-REGEN 재착륙분의 flag-ON 실측에서 signal_flock.c synth가 **sentinel-miss**로 FROZEN 유지
(spec `hexa_signal_install` ≠ emitter 실제 export `hexa_os_sig_install`, signal_flock_emit.hexa:134)
→ flock·sigaddset·sigemptyset 3심볼 잔존이 단일 root-cause. sentinel 1줄 수정 후:
- 6/6 fragment SYNTHESIZED · build rc=0
- **ON floor = 15 U = 위 WALL 목록과 정확 일치** (reducible 잔여 0 · WALL-only 수렴 MEASURED)
- TARGET-15(내 8게이트 + syscall-family 7) 전부 drop ✅ · OFF는 FRAG-REGEN 활동 0줄(byte-neutral)
측정로그=state/zeroc-flip-measure-2026-07-03.txt 측정#2. flip(default-ON)은 byteeq 3타깃+faithful-nobaseline+smoke GREEN 후 별도 PR.
