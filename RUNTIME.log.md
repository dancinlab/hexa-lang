# RUNTIME — log

Append-only history sister of `RUNTIME.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-25 — cycle 75: doc-sync to 29-extern ground-truth + -Oz builtin-trap root-cause 반증

- [x] Ground-truth 재측정 — `nm aprime_cc | grep ' U _'` @ HEAD `6617e7a4` = **30 externs**, PR #988 (`_getuid` svc-trap drop) 머지 후 = **29**. 이게 live baseline (doc 상단 Tier-A 체크박스는 cycle 48 anchored = ~25 cycle stale)
- [x] RUNTIME.md 동기화 — `step 1` 진척선 (137→93 → 137→29) · Tier-A.1 acceptance line 에 ground-truth UPDATE blockquote · `## Extern reconciliation @ 6617e7a4` 신규 subsection (gone/regressed/open 3-way partition + 29-list verbatim)
- [x] doc-lag 플립 — `- [ ]` → `- [x]`: Tier-A.4 syscall 18종 · Tier-A.5 libm · Tier-A.3 stdio · Tier-A.6 std-stream/error override 패밀리 · str/mem aggregate (`_strcpy _bzero _strncpy _memcpy _memset _memmove`) 전부 nm @6617e7a4 ABSENT 확인 ("cycle 59-73, verified absent" 주석)
- [x] regression 명시 — network 11 (`_socket … _setsockopt`) + exec/spawn 9 (`_execve … _posix_spawn_file_actions_*`) 가 r16 / GO-domain 으로 extern 재등장. 일부는 correctness 위한 의도적 real-libc 복원 (M10/M16)
- [x] genuinely-open 명시 — `_gmtime_r _nanosleep _mkdir _backtrace _backtrace_symbols_fd _environ` + hard-deferred trio (`___chkstk_darwin ___darwin_check_fd_set_overflow _longjmp`)
- [x] cycle-65 "🛸 ACCEPTANCE REACHED ≤5" 라인 = SUPERSEDED 주석 (삭제 X · 30 regressed · ≤5 UNMET @ 29). wipe-guard 준수 — 작은 surgical annotation
- [x] Tier-A.1 `_bzero`/`_strncpy` root-cause 정정 — 기존 메커니즘("clang -Oz folds byte loops to memset/bzero; -fno-builtin can't stop it") EMPIRICALLY FALSIFIED. 진짜 = `-Oz` 가 byte-loop 에 loop-idiom recognition 안 돌림; libcall 은 compiler-SYNTHESIZED aggregate op (`char buf[N]={0}`→bzero, `*dst=*src`→memcpy) 에서 나옴 → textual token 없어 `#define` 으로 intercept 불가. 검증 fix = `volatile size_t i` induction var + caller-side aggregate idiom 을 explicit `hxlcl_memcpy/hxlcl_bzero` 로 치환. `optnone`/`no_builtin`/`#pragma optimize off` 모두 FAIL
- [x] discovery 로그 — `.discoveries/oz-aggregate-synthesis-not-loop-idiom.tape` 생성 (closed root-cause correction · verdict-tier-target 🔴/🔵)

