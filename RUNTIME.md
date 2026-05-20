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

- [partial] `_strcmp` — removed cycle 46 (`hxlcl_strcmp` + #define)
- [partial] `_memcmp` — removed cycle 46 (`hxlcl_memcmp` + #define)
- [pending] `_strlen` — `hxlcl_strlen` landed + #define; 1 residual
      libc call remains chained from `_strcat` inline path (cycle 47
      lands `_strcat` and closes this in the same surgery)
- [ ] `_atoi` — string → i64. → `stdlib/runtime/atoi.hexa`
- [ ] `_atof` — string → f64 (scaled accumulator + decimal exponent)
- [ ] `_atoll` — string → i64 (alias of atoi or longer-range variant)
- [ ] `_strtol`, `_strtod`, `_strtoul` — strtok-like with end-ptr
- [ ] `_strcpy`, `_strncpy`, `_strcat` — byte copy
- [ ] `_strncmp` — byte compare (n-prefixed; cycle 47)
- [ ] `_strchr`, `_strstr` — substring search
- [ ] `_strdup` — strlen + malloc + memcpy
- [ ] `_bzero` — fill with zero
- [ ] `_qsort` — sort-array helper (rare; review usage)
- [ ] `_bsearch` — binary search (rare; review usage)

Acceptance: 12+ libc symbols removed → 137 → ~125 externs.
Cycle 46 partial: 137 → 135 (−2 measured).

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
