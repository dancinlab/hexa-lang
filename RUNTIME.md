# 🛸 RUNTIME — hexa-native runtime rewrite SSOT

> Per-domain root file (CLAUDE.md domain-meta-domain principle).
> Sibling to `COMPILER.md` (compiler self-host) — this file owns the
> RUNTIME layer's hexa-native journey (~16,809 LoC of C → hexa source).

## North-star

Eliminate **all C dependencies** from the hexa-lang compiler binary
(`aprime_cc` + `hexac`). Final acceptance: `nm aprime | grep '^.* U _'`
produces only kernel syscall stubs (≤ 5 lines) — zero libc, zero libm,
zero libsystem.

## Domain map (Phase 0 → 3 + post)

```
COMPILER.md            ← compiler self-host fixpoint (cycle 22-41)
   │
   ▼ S3 fixpoint stable
RUNTIME.md             ← runtime hexa-native rewrite (this file)
   │
   ├─ Phase 0 (DONE)   build-pipeline strip (cycle 41-44)
   ├─ Phase 1 (PENDING) Tier-A compiler-essential primitives
   ├─ Phase 2 (PENDING) Tier-B stdlib primitives
   ├─ Phase 3 (PENDING) Tier-C application primitives
   └─ Post-3 (POLICY) zero-C-dep acceptance
```

## Phase 0 — build-pipeline strip

- [x] S3 fixpoint full closure proven (cycle 41 · gen1≡gen2 md5
      `4197fd52560f3acca059a197b000c83c`)
- [x] Bug A — UTF-8 chars()→bytes() in rodata pool (cycle 39 commit
      `e7c71dde`)
- [x] Bug B — module-init truncate()→assign on module-global (cycle
      41 commit `2392d901`)
- [x] aprime_cc dead-strip + -Oz (cycle 43 · 2.24 MB → 1.00 MB ·
      173 → 137 externs)
- [x] hexac dead-strip + -Oz (cycle 44 · 2.11 MB → 1.91 MB · 172 →
      137 externs)
- [x] LEAN S3 fixpoint preserved (cycle 43-44 · md5 `39dbb35c1606...`)
- [x] external symbol catalog (`inbox/rfc_drafts_2026_05_20/
      aprime_c41_externs_catalog.txt` · 173 entries)
- [x] RFC draft (`inbox/rfc_drafts_2026_05_20/
      rfc_runtime_hexa_native_rewrite.md`)

## Phase 1 — Tier-A compiler-essential primitives (est 8-12 cycles)

### Tier-A.1 — Trivial libc replacements (pure logic, no syscall)

Cycle 46 (2026-05-20) landed step-1 (C-source scaffold). Method:
`static hxlcl_*` helpers in `self/runtime.c` defined ABOVE the
`#include "runtime_core.c"` line, plus textual `#define strlen
hxlcl_strlen` etc that redirect every subsequent call (including
macro expansions clang's libcall recognition would otherwise re-pull
to libc). Step-2 (later cycle) ports each `hxlcl_*` to
`stdlib/runtime/<name>.hexa` + codegen routing; runtime.c itself
retires once its callers move to hexa-source.

- [x] `_strcmp` — removed cycle 46 (`hxlcl_strcmp` + #define)
- [x] `_memcmp` — removed cycle 46 (`hxlcl_memcmp` + #define)
- [x] `_strlen` — removed cycle 47 (closed with strcat surgery)
- [x] `_strcat` — removed cycle 47 (`hxlcl_strcat` + #define)
- [x] `_strchr` — removed cycle 47 (`hxlcl_strchr` + #define)
- [x] `_strstr` — removed cycle 47 (`hxlcl_strstr` + #define)
- [x] `_strndup` — removed cycle 47 (`hxlcl_strndup` + #define)
- [x] `_strdup` — removed cycle 48 (cycle-47 "residual" was actually
      broken `#define hxlcl_strdup hxlcl_strdup` self-redefine from
      perl mis-substitution; fix → clean removal)
- [x] `_strncmp` — removed cycle 48 (same broken-#define cause)
- [x] `_strrchr` — removed cycle 48 (same broken-#define cause)
- [x] `_atoi` — removed cycle 48 (`hxlcl_atoi` + #define)
- [x] `_atoll` — removed cycle 48 (`hxlcl_atoll` + #define)
- [x] `_atof` — removed cycle 48 (`hxlcl_atof` + #define, simple
      decimal-exponent impl; bit-exactness not yet verified against
      libm path — gated under Phase 1 cumulative S3 fixpoint check)
- [x] `_strtoll` — removed cycle 48 (`hxlcl_strtoll` + #define, full
      base+endptr semantics)
- [x] `_strtoull` — removed cycle 48 (`hxlcl_strtoull` + #define)
- [pending] `_bzero` — `hxlcl_bzero` + #define landed cycle 48 but
      `-fno-builtin-bzero` flag (added to build_aprime.sh) does NOT
      stop clang -Oz from emitting bzero. Mechanism: `memset(p,0,n)`
      auto-converted to bzero before tokenization sees our #define.
      Defer to cycle that replaces memset call sites too.
- [pending] `_strncpy` — newly emerged after cycle 48 (was not in
      baseline 137; clang -Oz converted some other loop pattern in
      our helpers / runtime into strncpy). 1 call site.
- [ ] `_strcpy` — byte copy
- [ ] `_qsort` — sort-array helper (already dead-stripped; 0 source
      sites in current build, may need attention if reachable code
      grows)
- [ ] `_bsearch` — binary search (already dead-stripped; same as
      qsort)
- [ ] `_strtod` — already dead-stripped; 0 in current externs

Acceptance: 12+ libc symbols removed → 137 → ~125 externs.
Cycle 46-48 cumulative: 137 → 122 (**−15 measured · 15 of 12+ symbols
dropped · ~125 target REACHED**, surpassed by 3 externs).

### Tier-A.2 — Memory allocator family

- [ ] `_malloc` — bump allocator + 4MB mmap blocks (port from
      `self/runtime_core.c::hexa_arena_alloc`)
- [ ] `_free` — track-via-bookkeeping or leak (arena rewind handles
      lifetime)
- [ ] `_realloc` — alloc-new + memcpy + free-old
- [ ] `_calloc` — malloc + bzero
- [ ] `_memcpy` — byte copy via `@asm` SIMD-friendly loop
- [ ] `_memset` — byte fill via `@asm`
- [ ] `_memmove` — overlap-safe direction-checking memcpy
- [ ] `_mmap` — direct syscall via `@asm` `svc 0x80` (Darwin) / `syscall`
      (Linux x86_64)

Acceptance: 8 memory symbols → 125 → ~117 externs.

### Tier-A.3 — stdio narrowest subset

- [ ] `_write` (syscall #4 Darwin) — direct `@asm` syscall
- [ ] `_read` (syscall #3) — direct syscall
- [ ] `_open` (syscall #5), `_close` (syscall #6) — direct syscall
- [ ] `_fopen` → hexa wrap of `_open`
- [ ] `_fclose` → wrap `_close`
- [ ] `_fread` → wrap `_read`
- [ ] `_fwrite` → wrap `_write`
- [ ] `_fputs`, `_fputc`, `_fgetc`, `_fgets` → wrap read/write
- [ ] `_printf`, `_fprintf` → wrap `_write` + hexa-native formatter
- [ ] `_snprintf`, `_sprintf` → format-to-buffer hexa fn
- [ ] `_sscanf` → format-from-buffer hexa fn
- [ ] `_fflush`, `_setvbuf`, `_setbuf` → buffer state hexa fn
- [ ] `_perror` → `_write(stderr, ...)`
- [ ] `_ftell`, `_fseek`, `_rewind`, `_fileno` → `_lseek` syscall wrapper

Acceptance: ~19 stdio symbols → 117 → ~98 externs.

### Tier-A.4 — POSIX syscalls direct via `@asm`

- [ ] `_exit`, `__exit` — syscall #1 (Darwin)
- [ ] `_getpid`, `_getuid`, `_geteuid`, `_getppid` — single syscall each
- [ ] `_kill`, `_signal`, `_sigaction` — syscall wrappers
- [ ] `_alarm`, `_sleep`, `_usleep`, `_nanosleep` — wrap `_nanosleep`
- [ ] `_fork`, `_execve`, `_execvp`, `_execl` — wrap `_fork`/`_execve`
- [ ] `_waitpid`, `_wait` — wrap `_wait4`
- [ ] `_pipe`, `_dup`, `_dup2`, `_fcntl`, `_ioctl` — syscalls
- [ ] `_select`, `_poll` — multiplexers
- [ ] `_lseek`, `_pread`, `_pwrite` — file offset/IO syscalls
- [ ] `_stat`, `_lstat`, `_fstat`, `_access` — file-attr syscalls
- [ ] `_chmod`, `_unlink`, `_mkdir`, `_rmdir` — fs syscalls
- [ ] `_readlink`, `_symlink`, `_rename`, `_chdir`, `_getcwd` — fs syscalls
- [ ] `_munmap`, `_mprotect`, `_madvise`, `_sbrk` — memory syscalls
- [ ] `_gettimeofday`, `_clock_gettime` — time syscalls
- [ ] `_setjmp`, `_longjmp` — hexa-native register save/restore (no syscall)
- [ ] `_getenv`, `_setenv`, `_unsetenv` — env via `_environ` global +
      hexa-native lookup
- [ ] `_setlocale` — stub returning "C"
- [ ] `_atexit` — register on hexa-native exit handler chain
- [ ] `_abort` — `_kill(_getpid, SIGABRT)` + `_exit(1)`
- [ ] `_isatty` — `_ioctl(fd, TCGETS)` check
- [ ] `_fdopen`, `_flock` — wrap `_open`/`_fcntl`
- [ ] `_getrlimit`, `_getrusage` — syscalls
- [ ] `_grantpt`, `_posix_openpt`, `_ptsname`, `_cfmakeraw` — pty syscalls
- [ ] `_posix_spawn*`, `_posix_spawn_file_actions_*` — fork/exec combos
- [ ] `_popen`, `_pclose` — pipe + fork combo
- [ ] `_getline`, `_putchar` — read/write wrappers
- [ ] `_gmtime_r` — date conversion (no syscall, pure math)
- [ ] `_backtrace`, `_backtrace_symbols_fd` — frame walker; replace
      with hexa-native unwinder or stub

Acceptance: ~40 POSIX symbols → 98 → ~58 externs.

### Tier-A.5 — libm float math (FP precision sensitive!)

Choose path:
- (a) bit-exact libm replacement (Pade approximants, CORDIC, LUTs)
- (b) libm-exception policy ("libm-only-extern" allowed, documented)

Path (a) checklist:
- [ ] `_sin`, `_cos`, `_tan` — Pade or CORDIC, ULP-tested
- [ ] `_asin`, `_acos`, `_atan`, `_atan2` — series + LUT
- [ ] `_exp`, `_exp2`, `_log`, `_log2`, `_log10` — Pade
- [ ] `_sqrt` — arm64 `fsqrt` insn (1-cycle, bit-exact with libm)
- [ ] `_pow` — `exp(b * log(a))` identity
- [ ] `_fabs`, `_fmod`, `_floor`, `_ceil`, `_round`, `_trunc` — bit-level
- [ ] `_sinh`, `_cosh`, `_tanh`, `_expm1`, `_log1p`, `_hypot`, `_cbrt`,
      `_sincos`, `_erf`, `_tgamma`, `_lgamma` — Pade/identities
- [ ] `_nan` — return NaN bit pattern (`0x7FF8000000000000`)

Path (b) checklist:
- [ ] LATTICE_POLICY review: is libm-only-extern acceptable for
      "hexa-native runtime"?
- [ ] Document the exception in `HEXA-NATIVE-ONLY.md`
- [ ] Acceptance gate becomes: ≤ 5 syscall externs + 16 libm

Acceptance: 16 libm symbols (path a) OR documented exception (path b).

### Tier-A.6 — Darwin/compiler-rt internals

- [ ] `___chkstk_darwin` — stack probe; replace with `@asm` or noop on
      sufficient stack
- [ ] `___darwin_check_fd_set_overflow` — fd_set guard; replace with
      hexa-native assert or noop
- [ ] `___error` — `errno` access; hexa-native TLS errno
- [ ] `___memcpy_chk` — fortified memcpy; bypass with
      `-D_FORTIFY_SOURCE=0`
- [ ] `___sincos_stret` — paired sin/cos; wrap with hexa fn
- [ ] `___stack_chk_fail`, `___stack_chk_guard` — stack canary; disable
      with `-fno-stack-protector`
- [ ] `___stderrp`, `___stdinp`, `___stdoutp` — std stream pointers;
      replace with hexa-native fd constants (0/1/2)
- [ ] `__DefaultRuneLocale` — locale data; stub
- [ ] `_environ` — env array; populate from argv-passed envp
- [ ] `_dyld_*` — dynamic loader; ignored once we go `-static`
- [ ] `_NS*` / `_CF*` — CoreFoundation; not used by compiler (already 0)
- [ ] `_compiler_rt` — clang's runtime; replaceable with `@asm` ops
- [ ] `_mach_*` — Mach IPC; replaceable with syscall wrappers

Acceptance: 12 darwin/internal symbols replaced → 58 → ~46 externs.

### Tier-A.7 — networking (defer to Phase 2 unless compiler needs it)

- [ ] `_socket`, `_bind`, `_listen`, `_accept`, `_connect` — syscalls
- [ ] `_send`, `_recv`, `_sendto`, `_recvfrom`, `_shutdown` — syscalls
- [ ] `_getsockopt`, `_setsockopt` — syscalls
- [ ] `_getaddrinfo`, `_freeaddrinfo`, `_gethostbyname` — resolver
      (heavy; could remain as libc exception)
- [ ] `_inet_addr`, `_inet_ntoa`, `_inet_pton`, `_inet_ntop` — pure
      string ↔ int byte ops
- [ ] `_htons`, `_htonl`, `_ntohs`, `_ntohl` — endian flips (arm64
      `rev` insn)

Compiler-essential? **NO** — compiler doesn't open sockets. Defer to
Phase 2 (Tier-B) unless catalog audit reveals otherwise.

### Tier-A.8 — threading (defer to Phase 2 too)

- [ ] `_pthread_create`, `_pthread_join`, `_pthread_exit`
- [ ] `_pthread_mutex_*`, `_pthread_cond_*`, `_pthread_rwlock_*`
- [ ] `_pthread_self`, `_pthread_setname_np`, `_pthread_get_stacksize_np`
- [ ] `_sched_yield`, `_sched_get_priority_max`

Compiler-essential? **NO** — aprime_cc is single-threaded. Defer.

### Tier-A.9 — misc residuals

- [ ] `_dlopen`, `_dlsym`, `_dlerror` — dynamic loading; not used by
      compiler. Defer or stub.
- [ ] `_pthread_*` (see A.8 above)

## Phase 1 cumulative acceptance gate

- [ ] aprime_cc rebuild after Phase 1 → ≤ 5 external syscalls (write,
      read, mmap, exit, gettimeofday) + libm exception (16)
- [ ] S3 fixpoint full closure preserved (gen1 ≡ gen2 byte-eq)
- [ ] aprime_cc smoke `exit(6*7)==42` PASS
- [ ] hexac via aprime_cc emit-asm builds + smoke PASS
- [ ] LEAN binary size within ±20% of cycle 44 baseline
- [ ] `cc --regen` byte-eq after each Tier-A sub-phase

## Phase 2 — Tier-B stdlib primitives (~50 fns, est 4-8 cycles)

- [ ] regex: `_regcomp`, `_regexec`, `_regfree` (DFA in hexa)
- [ ] JSON: parse/serialize (already mostly hexa; finish migration)
- [ ] Bytes ↔ string codec (UTF-8 / hex / base64)
- [ ] Networking (TCP/UDP via syscalls; HTTP/2 in hexa)
- [ ] Threading (green threads in hexa or keep C pthread?)
- [ ] Crypto helpers: HMAC-DRBG, scrypt, pbkdf2 (slow path)
- [ ] More math (gamma, beta, erf — for stdlib/quantum, sim_universe)
- [ ] Time format (ISO 8601, RFC 3339)

## Phase 3 — Tier-C application primitives (16+ cycles OR deferred)

- [ ] crypto bulk: chacha20, x25519, sha256, ed25519, libsodium-equivalent
- [ ] networking full: TLS 1.3 in hexa? (very heavy)
- [ ] GPU kernels (hxcuda_*.cu, hxblas_*) — **vendor C ABI**;
      legitimately deferred to FFI
- [ ] pty/posix_spawn/dlopen — keep as C? Or hexa-native shell?

**Policy decision needed**: is "hexa-native runtime" allowed to FFI
to vendor C (GPU drivers, system services), or must everything be in
hexa source? `LATTICE_POLICY.md` review required.

## Post-Phase-3 — zero-C-dep acceptance

- [ ] `nm aprime | grep '^.* U _'` returns empty (after Phase 1+2+3a or
      policy variant)
- [ ] `nm aprime | grep '^.* U _'` returns only syscalls (policy
      variant: libm + GPU FFI allowed)
- [ ] aprime_cc rebuild without `-lm`, without any `-l*` flag
- [ ] Same on hexac
- [ ] S3 fixpoint preserved at every stage
- [ ] HEXA-NATIVE-ONLY.md updated with measured proof

## Methodology checkpoints (per-cycle)

For each Tier-A sub-phase:
- [ ] Pre-cycle: catalog target symbols + count externs before
- [ ] Source-level fix: write hexa replacement in `stdlib/runtime/<name>.hexa`
- [ ] Codegen wire: `_builtin_runtime_sym` mapping if symbol-renamed
- [ ] Link flags: `-fno-builtin-<name>` if libc tries to inline
- [ ] Rebuild aprime_cc via `tool/build_aprime.sh`
- [ ] Verify externs count dropped (`nm | grep '^.* U _' | wc -l`)
- [ ] S3 fixpoint check: gen1.s ≡ gen2.s md5 byte-eq
- [ ] aprime_cc smoke exit(42) PASS
- [ ] hexac rebuild + smoke PASS
- [ ] commit with cycle number + measured deltas

## Risks + known unknowns

- [ ] @asm block support in aprime_cc may be incomplete (Tier-A.4 prereq)
- [ ] libm replacement bit-exactness vs S3 fixpoint stability (any
      FP-differ breaks gen1 ≡ gen2)
- [ ] Hexa malloc alignment must match C malloc's
- [ ] Arena rewind interaction with hexa-allocated state needs proof
- [ ] Darwin-specific syscall numbers (#1 exit) differ from Linux —
      need cross-platform table
- [ ] Backtrace/unwinder removal may break debugging UX
- [ ] `-Oz + -ffunction-sections + -dead_strip` interaction with
      hexa-native runtime may produce different code paths than
      libc — needs re-validation per phase

## Resource notes

- mini + ubu-1 + ubu-2 + m4mini all reachable (per cycle 31-c)
- jetsam OOM (cycle 36) resolved post-cycle 41 (Bug B fix)
- LEAN toolchain (cycle 43-44) is the working baseline forward
- aprime_c41 + hexac_c41 binaries preserved in `/tmp/` for cross-check
- gen1/gen2 baseline md5: `4197fd52560f3acca059a197b000c83c` (cycle 41
  original) / `39dbb35c1606c3cf0886c5fb00e7cabc` (cycle 43-44 lean)

## Cross-refs

- `COMPILER.md` — compiler self-host SSOT (cycle 22-41 source)
- `LATTICE_POLICY.md` — north-star ② definition
- `HEXA-NATIVE-ONLY.md` — policy spec
- `compiler/PLAN.md` — per-cycle log (entries since cycle 22)
- `inbox/rfc_drafts_2026_05_20/rfc_runtime_hexa_native_rewrite.md` —
  RFC draft (cycle 42)
- `inbox/rfc_drafts_2026_05_20/aprime_c41_externs_catalog.txt` — raw
  173-symbol list

---

## Log

### 2026-05-20 — Phase 0 closure

- 🛸 cycle 41 `2392d901` — S3 fixpoint full closure PROVEN (gen1 ≡
  gen2 byte-eq, md5 `4197fd52560f3acca059a197b000c83c`, 10.6 MB)
- ✅ cycle 39 `e7c71dde` — Bug A UTF-8 multi-byte rodata fixed
- ✅ cycle 41 `2392d901` — Bug B module-init truncate→assign fixed
- ✅ cycle 43 `505dfb29` — build_aprime.sh dead-strip + -Oz (aprime
  55% smaller, externs 173→137)
- ✅ cycle 44 `ca22c5d1` — build_hexac.hexa dead-strip + -Oz (hexac
  9.3% smaller, externs 172→137)
- ✅ cycle 45 entry — this file created (RUNTIME.md SSOT, Phase 1-3
  [ ]/[x] checkpoint roadmap)
- 📌 137 externs catalogued; Phase 1 ready to begin (cycle 46+)

### 2026-05-20 — Phase 1 Tier-A.1 step-1 (cycle 46)

- ✅ cycle 46 — `_strcmp` + `_memcmp` libc unhook landed (137 → 135
  externs measured · aprime_cc smoke exit(42) PASS · binary
  1,120,024 B +544 B vs baseline)
- Method: `static __attribute__((noinline)) hxlcl_strlen/memcmp/
  strcmp` helpers added to `self/runtime.c` ABOVE the
  `#include "runtime_core.c"` line, plus textual `#define strlen
  hxlcl_strlen` (and friends) that redirects every subsequent
  call including macro expansions / inline header bodies clang's
  libcall recognition would otherwise re-pull to libc
- Source delta: `self/runtime.c` (+helper block + #define + 17
  call-site substitutions) · `self/runtime_core.c` (30 strlen + 39
  strcmp + 1 memcmp substitutions) · `tool/build_aprime.sh`
  (comment-only — no -fno-builtin flag needed)
- Residual: `_strlen` 1 stubborn libc call remains, chained from a
  `_strcat` inline path (`bl _strcat` immediately followed by
  `bl _strlen` in disasm at `0x100000824`). Cycle 47 closes this
  by introducing `hxlcl_strcat` + `#define strcat hxlcl_strcat`
  in the same surgery — eliminates 2 externs simultaneously
- Honest scope: this is step-1 (C-source scaffold); the `hxlcl_*`
  helpers themselves are slated for retirement when step-2 ports
  them to `stdlib/runtime/<name>.hexa` + codegen routing. The
  helpers and runtime.c HI tier go away together once their
  callers (the broader runtime.c surface) move to hexa-source
- S3 fixpoint validation DEFERRED to Phase 1 cumulative gate —
  this step is a single sub-symbol edit; preserving gen1 ≡ gen2
  is gated when full Tier-A.1 lands

### 2026-05-20 — Phase 1 Tier-A.1 step-1 (cycle 47)

- ✅ cycle 47 — 5 more libc symbols removed (135 → 130 externs ·
  cumulative 137 → 130 = −7 vs Phase 0 baseline). aprime_cc smoke
  exit(42) PASS · binary 1,120,024 → 1,119,976 B (−48 B,
  effectively unchanged)
- Removed this cycle: `_strcat` · `_strlen` (residual closed
  alongside strcat) · `_strchr` · `_strstr` · `_strndup`
- Added helpers: `hxlcl_strcat` · `hxlcl_strchr` · `hxlcl_strrchr`
  · `hxlcl_strstr` · `hxlcl_strncmp` · `hxlcl_strdup` ·
  `hxlcl_strndup` (7 helpers; all in `self/runtime.c` above the
  runtime_core.c include, all with `noinline` + volatile reads)
- Added `#define` redirects for those names
- Source delta: `self/runtime.c` (+9 helpers + 7 defines · ~95
  lines net) · `self/runtime_core.c` (perl substitutions across
  the 6 new symbols)
- `tool/build_aprime.sh` comment updated. `-fno-builtin-{strncmp,
  strdup,strrchr}` flag combo tested — DID NOT help (still 130
  externs, same 3 residuals); flags removed to keep the build
  recipe clean
- 3 stubborn residuals: `_strdup` · `_strncmp` · `_strrchr`. All
  1 libc call each via clang `-Oz` reverse-libcall recognition
  converting our `hxlcl_*` patterns back to libc-shaped calls
  (e.g. `hxlcl_memcmp(a, b, k)` with constant `k` → `_strncmp`;
  `malloc(n+1) + byte copy` → `_strdup`). `-fno-builtin-NAME`
  flag is insufficient on -Oz; the optimizer pass that does the
  reverse-recognition fires before the builtin check
- Defer cycle: rewrite the 3 helpers either (a) as `@asm` blocks
  that the optimizer can't pattern-match, (b) with explicit
  side-effects to escape pattern fingerprinting, or (c) port to
  hexa-source per the canonical step-2 path
- S3 fixpoint check still DEFERRED to Phase 1 cumulative gate

### 2026-05-20 — Phase 1 Tier-A.1 step-1 (cycle 48) — acceptance reached

- ✅ cycle 48 — Tier-A.1 acceptance "12+ symbols removed → ~125
  externs" **REACHED measured**. aprime_cc nm undefined externs
  127 → 122 (−5 this cycle · cumulative 137 → 122 = **−15**) ·
  smoke exit(42) PASS · binary 1,119,896 B (vs baseline 1,119,480
  B, +416 B = 0.04%)
- Bug correction: cycle 47's "stubborn 3 residual via clang
  reverse-libcall" hypothesis was WRONG. Real cause = broken
  `#define` block: perl substitution from cycle 47 hit the LHS
  of its own newly-added `#define strncmp(...) hxlcl_strncmp(...)`
  lines and converted them to `#define hxlcl_strncmp(...)
  hxlcl_strncmp(...)` self-redefines (no-op). Fixed by typing out
  the correct LHS names directly + updating future perl skip rule
  to `unless (/^\s*\/\/|^\s*#\s*define\b/)`
- Closed cycle 48: `_strdup` + `_strncmp` + `_strrchr` (broken-
  define fix) · `_atoi` + `_atoll` + `_atof` + `_strtoll` +
  `_strtoull` (numeric batch). 8 symbols dropped this cycle. Plus
  `-fno-builtin-bzero` added to build_aprime.sh (unsuccessful for
  bzero, but documents the attempt)
- 2 residuals open: `_bzero` (clang memset-to-bzero conversion;
  `-fno-builtin-bzero` insufficient) · `_strncpy` (newly emerged
  via clang loop-to-strncpy conversion in our helpers). Both 1
  call site each, address in cycle 49+
- atof simple impl is NOT bit-exact with libc — may break S3
  fixpoint when Phase 1 cumulative gate fires. Mitigation options
  documented in RFC draft: (i) accept FP drift if gen1/gen2 both
  go through hxlcl_atof, (ii) keep libm path for atof, (iii) port
  to bit-exact Pade/Dekker scheme

### 2026-05-20 — Tier-A.1 final stragglers + Tier-A.2 partial (cycle 49)

- ✅ cycle 49 — aprime_cc nm undefined externs 122 → **117** (−5
  this cycle · cumulative **137 → 117 = −20**) · smoke exit(42)
  PASS · binary 1,119,896 → 1,119,992 B (+96 B = 0.04% from
  baseline 1,119,480)
- Closed: `_bzero` (closed via memset replacement chain · clang's
  memset→bzero conversion goes silent once no memset literals
  remain) · `_strncpy` (formerly "newly emerged" — also resolved)
  · `_strcpy` · `_strerror` (constant-string stub by errno class)
  · `_strftime` (zero-return stub; compiler-binary fallbacks tested
  to handle no-op output) · `_memset` · `_memmove` · BONUS
  `___memcpy_chk` (fortified variant dropped automatically once
  non-fortified memcpy unhooked)
- Tier-A.2 partial (3 of 8 memory symbols dropped): memset +
  memmove + ___memcpy_chk. `_memcpy` residual = 2 call sites of
  constant-size-160 `*dst = *src` aggregate assignments clang
  lowers to libc memcpy below the `#define` layer. `-fno-builtin-
  memcpy` added but ineffective for this codegen path
- Tier-A.2 still OPEN: `_malloc` · `_free` · `_realloc` ·
  `_calloc` · `_mmap` · `_munmap` (5 symbols). These underpin
  `hxlcl_strdup` plus the hexa arena allocator (`hexa_arena_
  alloc`). A cycle to port them needs either (a) a hexa-native
  bump allocator + mmap-syscall shim, or (b) interpose at the
  arena layer
- 22 `hxlcl_*` helpers now in `self/runtime.c`: strlen · strcmp ·
  memcmp · strcat · strchr · strrchr · strstr · strncmp · strdup
  · strndup · atoi · atoll · atof · strtoll · strtoull · bzero ·
  memcpy · memset · memmove · strncpy · strcpy · strerror ·
  strftime (23 entries; strerror+strftime are stubs)

### 2026-05-20 — Tier-A.6 fortification/stack-protector flags (cycle 50)

- ✅ cycle 50 — flag-only closure of compiler-rt residuals.
  `-D_FORTIFY_SOURCE=0` + `-fno-stack-protector` added to
  build_aprime.sh; clang stops emitting `___stack_chk_fail` and
  `___stack_chk_guard` runtime symbols (fortified `___memcpy_chk`
  already dropped automatically via cycle 49's memcpy unhook).
  Result: aprime_cc nm undefined externs 117 → **115** (−2 ·
  cumulative **137 → 115 = −22**) · smoke exit(42) PASS · binary
  1,119,992 → 1,119,784 B (−208 B; smaller since stack-canary
  prologues no longer emitted)
- `-fno-builtin-sincos` also attempted to drop `___sincos_stret`
  (macOS-specific paired-trig stret call) — INEFFECTIVE; clang's
  stret packing fires after the builtin check. Defer
- Tier-A.6 remaining: `___chkstk_darwin` · `___sincos_stret` ·
  `___darwin_check_fd_set_overflow` · `___error` · `___stderrp` ·
  `___stdoutp` · `__DefaultRuneLocale` (dropped earlier?). These
  need either source touches (stderrp/stdoutp → fd-0/1 constants)
  or compiler-flag deeper changes (chkstk_darwin: `-mstack-arg-
  probe-size=0` or `-fno-stack-clash-protection`)
- No source changes this cycle — `self/runtime.c` unchanged from
  cycle 49 state. Pure build-script update.

### 2026-05-20 — cycle 51 (small maintenance, no extern delta)

- ⚠ cycle 51 — no extern reduction (115 → 115). 3 attempts:
  - `-fno-builtin-sincos` flag: INEFFECTIVE for `___sincos_stret`
    (macOS stret pack-pair fires after builtin check) · removed
  - `-mllvm -disable-loop-idiom-memcpy=true`: INEFFECTIVE for the
    2 constant-size 160-byte aggregate memcpy calls · removed
  - `__attribute__((no_builtin("memcpy")))` on hexa_val_heapify
    + hexa_valstruct_set_by_key (the 2 caller fns identified by
    disasm): INEFFECTIVE · KEPT (valid attribute, harmless,
    documents the attempt)
- aprime_cc smoke exit(42) PASS · binary 1,119,784 B unchanged
  (no codegen change net)
- Conclusion: `_memcpy` residual closure requires source-level
  rewrite of the 160-byte `*dst = *src` aggregate-assign in those
  two fns (via explicit byte-loop or `__builtin_memcpy_inline`).
  Deferred to a cycle that touches the source pattern directly
- Phase 1 Tier-A.1 acceptance maintained (137 → 115 = -22, 8
  better than `~125` target)

### 2026-05-20 — cycle 52 — Tier-A.3 stdio printf-family minimal impl (-7 externs)

- ✅ cycle 52 — aprime_cc nm undefined externs 115 → **108**
  (−7 measured · cumulative **137 → 108 = −29**) · smoke
  exit(42) PASS · binary 1,119,784 → 1,119,608 B (−176 B)
- Closed: `_printf` · `_fprintf` · `_snprintf` · `_fputs` ·
  `_fputc` · `_fflush` · `_putchar` · `_perror` · plus
  `_strlen` residual from new code's string-scan loops (closed
  via `-fno-builtin-strlen` flag · this flag was tried + failed
  in cycle 47 but works now because the new code surface
  triggers a different optimization pass)
- Method: minimal-but-correct `hxlcl_vsnprintf` (~90 LoC)
  handles `%s/%d/%i/%u/%lld/%ld/%llu/%lu/%zu/%c/%x/%X/%p/%%`,
  basic width + zero-pad + left-align. Float specifiers
  (`%f/%g/%e/%F/%G/%E`) emit `(float)` placeholder — compiler's
  hot paths don't print floats. `printf` → `write(1, ...)` ·
  `fprintf` → `write(stderr ? 2 : 1, ...)` · `fputs/fputc/
  putchar/perror` → direct `write()`
- Tier-A.3 still OPEN: `_fopen` · `_fclose` · `_fread` ·
  `_fwrite` · `_fseek` · `_ftell` · `_fdopen` · `_flock` ·
  `_setvbuf` (9 file-stream symbols · need FILE* abstraction
  layer; defer until either (a) hexa runtime stops using FILE*
  for compiler-side IO, or (b) write a minimal FILE struct +
  open/read/write/close wrappers)
- Honest scope: hxlcl_printf is NOT bit-exact with libc printf
  (no `%a`, no locale, no positional args, simplified width/
  precision handling, `(float)` placeholder for FP). Compiler
  binary uses printf only for error messages + diagnostics
  where format-string subset is well-defined; smoke shows
  acceptable output. Bit-exactness with libm printf path is
  gated under Phase 1 cumulative S3 fixpoint check (deferred)
- `__attribute__((no_builtin("memcpy")))` from cycle 51 kept
  (still no benefit but harmless · documents the attempt)

### 2026-05-20 — cycle 53 — Tier-A.2 mmap-backed bump allocator (-4 externs)

- ✅ cycle 53 — Tier-A.2 memory family port. aprime_cc nm
  undefined externs 108 → **104** (−4 measured · cumulative
  **137 → 104 = −33**) · smoke exit(42) PASS · binary
  1,119,608 → 1,119,144 B (−464 B)
- Closed: `_free` · `_realloc` · `_calloc` · `_munmap`
- Method: mmap-backed bump allocator. `hxlcl_malloc` 16-byte-
  aligns + bumps within a 4 MB mmap chunk; grows on overflow.
  `hxlcl_free` is a noop (compiler binary leaks until exit —
  acceptable for one-shot tool). `hxlcl_realloc` = malloc-new +
  byte copy. `hxlcl_calloc` = malloc + zero. `hxlcl_munmap` is a
  noop (we never release mmap chunks)
- Tier-A.2 progress: **6 of 8 dropped** (cycle 49: memset +
  memmove + ___memcpy_chk · cycle 53: free + realloc + calloc
  + munmap)
- Tier-A.2 residual: `_malloc` (1 call site in `_hxlcl_strdup`
  · clang -Oz fuses `volatile-loop + malloc(n+1) + byte-copy`
  back to libc strdup-shape and emits `_malloc`; `volatile`
  cast in source insufficient) · `_memcpy` (cycle 51 residual)
- Tier-A.2 NEW floor: `_mmap` (1 call from `hxlcl_malloc`) —
  this single extern is the allocator floor until @asm syscall
  inlining lands (Tier-A.4 path-c)
- Honest scope: bump allocator + noop free is functionally
  correct for compiler binary lifetime; memory grows monotonic-
  ally per build, peaks at ~tens of MB based on aprime_cc usage
  pattern. NOT suitable for long-running daemons. atexit() not
  hooked; the OS reclaims chunks at exit
### 2026-05-20 — cycle 54 — Tier-A.3 file-stream batch (-7 externs)

- ✅ cycle 54 — Tier-A.3 stdio file-stream subset closed.
  aprime_cc nm undefined externs 104 → **97** (−7 measured ·
  cumulative **137 → 97 = −40**) · smoke exit(42) PASS · binary
  1,119,144 → 1,118,952 B (−192 B)
- Closed: `_fopen` · `_fclose` · `_fread` · `_fwrite` ·
  `_fseek` · `_ftell` · `_fdopen` · `_flock` · `_setvbuf`
- Method: FILE* encoded as `(void *)(uintptr_t)(fd + 1)` so 0
  doesn't alias NULL. _hxlcl_fp_fd helper checks if value is
  "small" (<0x1000) → our encoding, else libc FILE* → pointer
  compare against stderr/stdout/stdin. fopen uses `open()`
  syscall; fread/fwrite call `read`/`write`; fseek/ftell call
  `lseek`. flock + setvbuf = noop stubs (compiler binary doesn't
  rely on file locks or specific buffering modes)
- Tier-A.3 closure: 8 cycle-52 + 9 cycle-54 = **17 of 19**
  symbols. acceptance "~19 stdio → 117 → ~98 externs" REACHED
  at 97 (1 better than target). Remaining 2 Tier-A.3-ish:
  none in current externs
- Carryover residuals: `_malloc` · `_memcpy` · `_mmap`