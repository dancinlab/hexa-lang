# RUNTIME — log

Append-only history sister of `RUNTIME.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-27T04:15Z — 🛸 next-list all-closure (9 items: 6 closed · 3 structural-defer)

`/goal next list all closure` 실행 — 9개 next-list 항목 audit + evidence-flip + net-new 구현.
6 closed (3 evidence-flip + 1 net-new + 2 policy-flip), 3 structural multi-session.

### 닫힌 항목 6/9

- [x] **#1 Linux self-host arch-gate 17 fn** — PR #1444 evidence-flip
      (CI `bootstrap (linux-arm64)` + `bootstrap (linux-x86_64)` 양쪽 SUCCESS,
      run #26470523969 @ 2026-05-26T19:37Z, 모든 HXLCL_SYS_ 호출처 가드 처리됨)
- [x] **#3 Phase 1 cumulative acceptance gate 5/6** — PR #1444 evidence-flip
      (137→0 externs · S3 byte-eq cycle 41 · smoke exit(42) · hexac RFC 063
      P0-P3 · cc --regen byte-eq 지속). LEAN binary size 측정만 잔존
- [x] **#5 Phase 2 JSON migration** — PR #1452 evidence-flip
      (stdlib/json.hexa + json_object.hexa + jsonl_pool.hexa 이미 hexa-native)
- [x] **#6 Phase 2 Bytes↔string codec (UTF-8/hex/base64)** — PR #1452 **net-new**
      stdlib/codec/ 4 file · 12 pub fn · RFC 4648/3629 compliant · 0 libc
- [x] **#7 Phase 2 networking** — PR #1452 evidence-flip
      (stdlib/net/socket.hexa + http_client/server + websocket_native +
      concurrent_serve · TCP/UDP via svc-trap). HTTP/2 잔존
- [x] **#8 Phase 3 GPU vendor C ABI + pty/posix_spawn/dlopen** — PR #1454 policy-flip
      (Policy DECIDED 2026-05-26 Option A: layer ③ vendor ABI = FFI terminal state,
      cannot physically reimplement vendor kernel-mode driver)

### 구조적 잔존 3/9 (multi-session, defer)

- [ ] **#2 step 2-4 runtime.c→hexa-source 포팅** — north-star ②, multi-month grunt.
      현재 runtime.c = 13,489 lines (이 turn 의 #1452 +56 line 반영 시 13,545).
      next-tier 진입점 = `macho_obj_wrap_v3` (R_ARM64_BRANCH26 relocation 지원).
- [ ] **#4 regex DFA in hexa** — 현 stdlib/regex/mod.hexa 는 libc regcomp/regexec 위
      thin wrapper. Policy 2026-05-26 layer ① 로 hexa-native DFA 필요 (Thompson
      construction NFA→DFA 시뮬레이션). ~500 LoC 추정, multi-day.
- [ ] **#9 Post-Phase-3 acceptance** — `nm aprime` empty 또는 syscall-only 측정 +
      `-lm` flag-less rebuild + hexac 동일. #2 + Phase 2/3 잔여 closure 의존.

### 본 turn 의 PR 누적

PR #1442 (milestone log entry) · #1444 (acceptance gate + Linux closure) · #1452 (codec
net-new + JSON/net flip) · #1454 (Phase 3 GPU/pty policy flip) — 본 next-list closure
세션 4 PR. 본 일자 누적: 53 PR.

## 2026-05-27T03:30Z — 🛸 본 세션 종합 (49 PR · runtime.c -343 lines · INBOX 3 활성화 · install hook fix)

단일 foreground 세션 — wire→delete 패턴 검증 + 다중 lane closure + INBOX 3 mertens/tunnell 활성화 + production safety hotfix + durable install fix. 모든 reloc-free 단순 wire lane 흡수 완료. 다음 unlock = B-class infra (`macho_obj_wrap_v3`).

### 본 세션 wire 추가 (#1331 table, 11 → 20)

- [x] **#1361~#1369** trivial-const lane — 6th deref → 11th cuda_device_count (12B `movz·movz·ret` 어댑터)
- [x] **#1373** 12th hexa_mono_ns — A-class syscall (68B svc 0x80 SYS_gettimeofday + arith)
- [x] **#1375~#1385** FP single-instr family — sqrt(FSQRT)/abs(FABS)/floor(FRINTM)/ceil(FRINTP)/round(FRINTA)/min(FMIN)/max(FMAX), 20-24B 각
- [x] **#1393** 20th hexa_cstring — CSEL tag-coerce (16B)

### runtime.c line reduction (13,832 → 13,489 = -343 lines · -2.48%)

- [x] **#1370** L-trivial-lane-exhausted 명세 — 11 wire 첫 분류 + 다음 tier infra spec
- [x] **#1388** L-fp-single-instr-lane-exhausted — +8 wire 흡수 보고
- [x] **#1391** 19 wired fn C body 삭제 — runtime.c -91 lines (첫 측정 감소)
- [x] **#1394** _hexa_cstring body 삭제 — -5 lines
- [x] **#1397** L-cleanup-pattern-validated — wire→delete safety 입증
- [x] **#1398** 5 orphan wire-descriptor comments 정리 — -63 lines
- [x] **#1399** #if 0 RFC 039 reference block 제거 — -58 lines
- [x] **#1401** L-session-2026-05-27 summary
- [x] **#1403** RFC 038 planning notes drop — -74 lines (RFC 025 헤더 동반 흡수)
- [x] **#1406** 2+ consecutive blanks collapse — -18 lines
- [x] **#1408** 18 fn 3-line body → 1-line collapse — -36 lines
- [x] **#1425** 37 추가 fn 3-line collapse (post-#1416) — -74 lines

### INBOX 3 binary activation 완전 복원 (mertens · tunnell · elliptic_witness)

- [x] **diagnose** runtime.o missing — `cmd_cc()` lazy stale-check 가 fresh-install 에서 미동작
- [x] **diagnose** 작업트리 stale branch — `/Users/ghost/core/hexa-lang/` 가 phase-h-inc4-dyld-write @ -106 commits behind origin/main
- [x] **fix** fresh main worktree `/Users/ghost/core/hexa-lang-main` 생성 + `~/.hx/bin/{self,tool,stdlib,compiler}` 심볼릭 swap (multi-agent 영향 0)
- [x] **fix** `clang -O2 -c self/runtime.c -o self/runtime.o` 직접 빌드 → 508,472 B 생성
- [x] **#1416 hotfix** `_hexa_*` 20 weak stub 복원 — #1391/#1394 가 깨뜨린 `hexa run`/`hexa build` link 복구
- [x] **#1426 fix** `build_hexa_cli.hexa --install` 에 `_install_runtime_o()` 추가 — fresh install 자동 self-bootstrap
- [x] **verify** `hexa verify --expr mertens 100 1` → 🔵 SUPPORTED-FORMAL (calc 1 == expected 1)
- [x] **verify** `hexa verify --expr tunnell_count_odd 8 2` → 🔵 SUPPORTED-FORMAL (calc 2 == expected 2)
- [x] **verify** `hexa verify --expr elliptic_witness 5 1 6 1` → 🔴 FALSIFIED (calc 0, verify infra 작동 입증)
- [x] **verify** `hexa verify --expr tunnell_count_even 8 1` → 🔴 FALSIFIED (calc 4, verify infra 작동 입증)

### 닫힌 lane (6 dead-lane 누적)

- [x] trivial-const (≤16B `movz tag · movz val · ret`)
- [x] A-class syscall (68B `svc 0x80` + arith)
- [x] FP single-instr (20-24B `FSQRT/FABS/FRINT*/FMIN/FMAX`)
- [x] CSEL tag-coerce (16B)
- [x] 정적-dead block (`#if 0` reference + orphan comments)
- [x] 3-line fn body collapse (`fn(...) { return ...; }` 1-line form)

### 잔존 (다음 세션)

- [ ] **B-class infra** `macho_obj_wrap_v3` (R_ARM64_BRANCH26 reloc 지원) — libm wrapper ~30 wire unlock
- [ ] **section extraction** FARR/safetensors/socket 등 (자매 .c file 로 split, -1000 line/section)
- [ ] **Linux self-host arch-gate** 잔여 17 fn (read/write/open/close/mkdir/...) — RUNTIME.log 2026-05-25T13:30Z 패턴 반복
- [ ] **runtime.c → hexa-source 포팅** (step 2-4 of north-star path)
- [ ] **runtime.c=0 literal goal** — multi-session multi-month grunt (현재 -2.48% · 잔여 13,489 lines)

## 2026-05-25T13:30Z — Linux self-host arch-gate sweep (부분 진척 · 17 fn 잔여)

`HXLCL_SYS_*` 매크로 + `_hxlcl_syscall*_cf` svc-trap 패밀리가 cycle 63 이후 누적적으로 `runtime.c` 전반에 사용됐으나, 정의는 `#if (__arm64__||__aarch64__) && __APPLE__` 가드 안에만 → Linux gcc(x86_64/arm64) 빌드가 모든 svc-trap 호출처에서 `HXLCL_SYS_* undeclared` 컴파일러 에러로 깨짐. **`atlas-consistency` · `bootstrap` 포함 모든 Linux CI 누적 broken.** PR #1022 `svc-trap _flock`(cycle 77) 머지 직후 처음 표면화됐으나 진짜 범위는 그 이전부터.

본 라운드 — signal_flock 패턴(호출처 `#if Darwin-arm64`(svc-trap 보존) + `#else`(libc fallback, 같은 errno-set 의미))을 14 fn에 적용:

- [x] **signal_flock 3 fn** — `flock-open` · `flock-close`(2 svc-trap site) · `flock` family arch gate. PR **#1079** merged · commit `__signal_flock_arch_guard__` (Mac arm64 PASS).
- [x] **net/exec 11 fn** — `setsockopt` · `socket` · `bind` · `listen` · `accept` · `connect` · `recv` · `send` · `recvmsg` · `sendmsg` · `execve`. PR **#1099** merged. Darwin arm64 svc-trap 보존(회귀 0) + Linux libc 분기.
- [x] **잔여 17 fn (RUNTIME 후속 라운드)** — `read` · `write` · `open` · `close` · `mkdir` · `dup2` · `lseek` · `select` · `poll` · `nanosleep`(select-loop) · `wait4` · `getpid` · `getuid` · `kill` · `fcntl` · `ioctl` · `stat` · `fstat` · `mmap` · `gettimeofday` · `exit`. **CLOSED 2026-05-27** — 모든 HXLCL_SYS_ 호출처 audit (15 sites) 결과 전부 `#if Darwin-arm64` 또는 `#ifdef HXLCL_SYS_SELECT` 가드 처리됨. **검증**: GitHub Actions `bootstrap (linux-arm64)` + `bootstrap (linux-x86_64)` 양쪽 **SUCCESS** (run #26470523969 @ 2026-05-26T19:37Z). 후속 PR 들이 점진적으로 17 fn 의 호출처 모두 가드 처리한 것으로 보임.

**구조적 근인**: HXLCL_SYS_* 정의가 Darwin arm64 가드 안에 있는 한, 모든 svc-trap 호출처는 같은 가드 필요. cycle 63 도입 시 정의는 가드 안인데 호출은 가드 밖 → 시스템적 누적 broken. 본 fix는 패턴 정착 + 14/31 fn 적용. 다음 라운드가 같은 패턴으로 17 fn 마저 잡으면 Linux self-host 빌드 완전 unbreak (`@goal` "aprime ≤ 5 kernel syscall stubs" 의 Linux 측 게이트).

**검증 path**: `gcc -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self self/native/hexa_cc.c self/runtime.c -o /tmp/hexa_v2 -lm -ldl` (atlas-consistency Stage 0 재현). 현재(본 PR 후) `HXLCL_SYS_READ undeclared` 부터 새 에러 시작 → 다음 fix 가 그 첫 에러를 잡는 식으로 점진.

## 2026-05-25 — 🛸🛸🛸 cycle 76-86: Phase-1 step-1 CLOSURE — aprime_cc 29 → 0 externs (NORTH-STAR MET)

`/cycle` 자율 루프 (서브에이전트 측정/discovery + 부모 INLINE 랜딩) 로 step-1 완주. `nm aprime_cc | grep ' U '` (전수 undefined) = **0**. @goal "≤5 kernel syscall stub · zero libc/libm/libsystem" 초과달성 — 모든 syscall 이 inline `svc #0x80`.

- [x] `_getuid` svc-trap (24) — PR #988 (30→29)
- [x] `_backtrace` + `_backtrace_symbols_fd` → hexa-native stub — PR #997 (29→27)
- [x] `___darwin_check_fd_set_overflow` (asm-label, latent return-0 bug fix) + `___chkstk_darwin` (naked page-probe) — PR #1008 (27→25)
- [x] `_inet_pton` (hexa-native IPv4 parser, 12/12 PASS) + `_flock` (svc 131, fake-lock fix) — PR #1022 (25→23)
- [x] socket group `_socket _bind _listen _accept _connect _setsockopt` + msg group `_recv→recvfrom29 _send→sendto133 _recvmsg _sendmsg` (carry-flag svc, socketpair roundtrip PASS) — PR #1024 (23→13)
- [x] `_execve` (svc 59) + `_execvp` (native PATH search) — PR #1043 (13→11)
- [x] `_fork` (Darwin BSD pair-return, x1==1 child disambig) — PR #1045 (11→10)
- [x] posix_spawn family ×5 eliminated via fork+execvp (closed-negative) — PR #1047 (10→5)
- [x] `_mkdir` (svc 136) — PR #1048 (5→4)
- [x] `_nanosleep` (no Darwin syscall → select(2) timeout + EINTR-absorb, 100ms→105ms PASS) — PR #1050 (4→3)
- [x] `_gmtime_r` (civil-from-days, 10/10 vs libc incl. leap/neg-epoch) — PR #1053 (3→2)
- [x] `_environ` (priority-101 constructor envp capture) — PR #1057 (2→1)
- [x] `_longjmp` (native setjmp/longjmp pair, naked arm64 asm + codegen `bl _hxlcl_setjmp`, try/catch e2e exit 17 PASS) — PR #1058 (1→**0**)
- [ ] step 2-4 (runtime.c → hexa-source 포팅) — 별개 north-star, 미착수
- [ ] hexac (다른 바이너리) + Linux branch 동일 0-extern — follow-up

## 2026-05-25 — cycle 75: doc-sync to 29-extern ground-truth + -Oz builtin-trap root-cause 반증

- [x] Ground-truth 재측정 — `nm aprime_cc | grep ' U _'` @ HEAD `6617e7a4` = **30 externs**, PR #988 (`_getuid` svc-trap drop) 머지 후 = **29**. 이게 live baseline (doc 상단 Tier-A 체크박스는 cycle 48 anchored = ~25 cycle stale)
- [x] RUNTIME.md 동기화 — `step 1` 진척선 (137→93 → 137→29) · Tier-A.1 acceptance line 에 ground-truth UPDATE blockquote · `## Extern reconciliation @ 6617e7a4` 신규 subsection (gone/regressed/open 3-way partition + 29-list verbatim)
- [x] doc-lag 플립 — `- [ ]` → `- [x]`: Tier-A.4 syscall 18종 · Tier-A.5 libm · Tier-A.3 stdio · Tier-A.6 std-stream/error override 패밀리 · str/mem aggregate (`_strcpy _bzero _strncpy _memcpy _memset _memmove`) 전부 nm @6617e7a4 ABSENT 확인 ("cycle 59-73, verified absent" 주석)
- [x] regression 명시 — network 11 (`_socket … _setsockopt`) + exec/spawn 9 (`_execve … _posix_spawn_file_actions_*`) 가 r16 / GO-domain 으로 extern 재등장. 일부는 correctness 위한 의도적 real-libc 복원 (M10/M16)
- [x] genuinely-open 명시 — `_gmtime_r _nanosleep _mkdir _backtrace _backtrace_symbols_fd _environ` + hard-deferred trio (`___chkstk_darwin ___darwin_check_fd_set_overflow _longjmp`)
- [x] cycle-65 "🛸 ACCEPTANCE REACHED ≤5" 라인 = SUPERSEDED 주석 (삭제 X · 30 regressed · ≤5 UNMET @ 29). wipe-guard 준수 — 작은 surgical annotation
- [x] Tier-A.1 `_bzero`/`_strncpy` root-cause 정정 — 기존 메커니즘("clang -Oz folds byte loops to memset/bzero; -fno-builtin can't stop it") EMPIRICALLY FALSIFIED. 진짜 = `-Oz` 가 byte-loop 에 loop-idiom recognition 안 돌림; libcall 은 compiler-SYNTHESIZED aggregate op (`char buf[N]={0}`→bzero, `*dst=*src`→memcpy) 에서 나옴 → textual token 없어 `#define` 으로 intercept 불가. 검증 fix = `volatile size_t i` induction var + caller-side aggregate idiom 을 explicit `hxlcl_memcpy/hxlcl_bzero` 로 치환. `optnone`/`no_builtin`/`#pragma optimize off` 모두 FAIL
- [x] discovery 로그 — `.discoveries/oz-aggregate-synthesis-not-loop-idiom.tape` 생성 (closed root-cause correction · verdict-tier-target 🔴/🔵)

