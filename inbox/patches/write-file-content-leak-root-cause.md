# write_file content-leak root cause (PROBE r8 CRITICAL)

**Status:** root cause confirmed · fix sketch provided · NOT shipped
**Filed:** 2026-05-23 from anima sibling investigation (PROBE round-8)
**Severity:** CRITICAL — silently writes user data to stderr (visible on `2>&1`); silently returns success on every failed write; affects ALL `write_file` / `read_file` / `file_exists` callers on Darwin arm64 when the underlying `open(2)` fails.

Round-8 probe (`canonical-audit-round-8-consolidated.md`, PR #400) reported:
> `write_file("/tmp/__nopath_for_sure__/x.txt", "miss")` returns `true` (false success) + content `"miss"` leaks to stdout.

This patch identifies the exact mechanism.

---

## 📋 Reproducer (verbatim)

```bash
cat > /tmp/probe_writefile_leak.hexa <<'EOF'
fn main() {
    let ok = write_file("/tmp/__nopath_for_sure__/x.txt", "miss")
    println("ok = " + ok)
}
EOF
HEXA_NO_CACHE=1 hexa run /tmp/probe_writefile_leak.hexa 2>&1 | od -c | head -3
```

## 🔍 Observed behavior (current main HEAD — post-#408/#410/#411)

```
0000000    m   i   s   s   o   k       =       t   r   u   e  \n
0000016
```

Decoded: `missok = true\n`.

- `miss` (the file CONTENT) leaks to the captured `2>&1` stream.
- `ok = true` even though no file was created (`ls /tmp/__nopath_for_sure__/` → ENOENT).

Second confirmer with a different errno path (EACCES variant):

```bash
cat > /tmp/probe_writefile_perm.hexa <<'EOF'
fn main() {
    let ok = write_file("/etc/__cannot_write__/x.txt", "FORBIDDEN_BYTES")
    println("ok = " + ok)
}
EOF
HEXA_NO_CACHE=1 hexa run /tmp/probe_writefile_perm.hexa 2>&1 | od -c | head -3
```

Output: `FORBIDDEN_BYTESok = true\n` — content again written to fd that happens to be stderr.

Control (success path → no leak):

```hexa
write_file("/tmp/__exists__.txt", "HELLO")
```

Output: `ok = true\n` — no leak, file actually written. Bug is specific to the failure path.

---

## 🧬 Root cause

The chain (Darwin arm64):

1. `rt_write_file` (`self/runtime_core.c:6040`) calls `fopen(path, "wb")`.
2. `fopen` is `#define`'d to `hxlcl_fopen` (`self/runtime.c:1320`).
3. `hxlcl_fopen` (`self/runtime.c:799`) calls `hxlcl_open_sys(path, O_WRONLY|O_CREAT|O_TRUNC, 0644)`.
4. `hxlcl_open_sys` (`self/runtime.c:1111`) on arm64 Darwin is implemented via:

   ```c
   static int __attribute__((noinline)) hxlcl_open_sys(const char *path, int flags, ...) {
       int mode = 0;
       __builtin_va_list ap;
       __builtin_va_start(ap, flags);
       mode = __builtin_va_arg(ap, int);
       __builtin_va_end(ap);
       return (int)_hxlcl_syscall3(HXLCL_SYS_OPEN, (long)path, (long)flags, (long)mode);
   }
   ```

5. `_hxlcl_syscall3` (`self/runtime.c:1014`) issues `svc #0x80` and returns `x0`:

   ```c
   static inline long _hxlcl_syscall3(long nr, long a0, long a1, long a2) {
       register long x0 __asm__("x0") = a0;
       register long x1 __asm__("x1") = a1;
       register long x2 __asm__("x2") = a2;
       register long x16 __asm__("x16") = nr;
       __asm__ volatile("svc #0x80" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x16) : "memory", "cc");
       return x0;
   }
   ```

   **The Darwin arm64 syscall ABI uses the carry flag to signal error.** On success, `x0` is the result and carry is clear. On error, `x0` is the **positive errno value** (e.g. `2 = ENOENT`, `13 = EACCES`) and the carry flag is set. The inline asm captures `x0` but never reads `nzcv`, so an errno gets returned as if it were a valid fd.

6. Result: `open("/tmp/__nopath_for_sure__/x.txt", ...)` fails with ENOENT → wrapper returns `2`.
7. `hxlcl_fopen` then does `if (fd < 0) return NULL` — `fd=2` is not `< 0`, so it falls through to `return (void*)(uintptr_t)(fd + 1)` → returns `(void*)3`.
8. `hxlcl_fwrite` (`self/runtime.c:848`) calls `_hxlcl_fp_fd((void*)3)` (`self/runtime.c:823`) which returns `3 - 1 = 2` (= stderr).
9. `hxlcl_write(fd=2, "miss", 4)` writes `miss` to **stderr**, which the probe captures via `2>&1`.
10. `hxlcl_fwrite` returns `put/sz = 4/1 = 4` → `rt_write_file` proceeds to `fclose` and returns `hexa_bool(1)` → `true`.
11. `hxlcl_fclose((void*)3)` decodes `fd=2`, hits the `if (fd < 3) return 0` safety net → does NOT close stderr (which is the only thing protecting the rest of the process from a closed stderr).

### Verification chain

- `clang /tmp/check_errno.c -o /tmp/check_errno` of a 3-line C program calling the same `open(2)` confirms `fd=-1 errno=2`.
- The bug ONLY manifests on the failure path (the success control case writes the actual file with no leak).
- Existing comment at `self/runtime.c:1043` already names the exact root issue:
  > `cycle 66 — libc read/write (carry-flag issue + EINTR handling).`
  Cycle 66 fixed `read` / `write` / `close` / `dup2` / `pipe` / `fork` / `waitpid` by routing them through libc wrappers (which correctly read `nzcv` and set `errno`/`-1`). **`hxlcl_open_sys` was missed.** The comment at line 1052-54 explicitly diagnoses the symptom for `close` ("returned errno on failure without distinguishing from success-fd convention (no carry flag access in inline asm)") — same root cause survived intact for `open`.

### Why this is critical (beyond the immediate probe)

Any errno value in the range `[3, INT_MAX]` from a failed `open(2)` becomes an "fd" that aliases a real open fd (likely something opened by the script — pipe, socket, dispatcher state). EACCES=13 → if the process has fd 13 open as a runtime control channel, `fwrite` will silently corrupt it. ENOENT=2 → stderr leak (visible). EBUSY=16, ENOSPC=28, EROFS=30 → wherever those fds happen to land. `read_file` / `file_exists` / any other `fopen("rb"|...)`-backed I/O has the same problem.

---

## 🩹 Proposed fix (actual code)

**Primary fix** — route `hxlcl_open_sys` through libc on Darwin arm64 (mirror the cycle-66 pattern for `read`/`write`/`close`):

```c
/* self/runtime.c — replace the Darwin arm64 branch of hxlcl_open_sys
 * (around line 1111). Match the cycle-66 libc-wrapper pattern used for
 * read/write/close/dup2/pipe/fork/waitpid above. The raw svc 0x80 path
 * does not check the carry flag, so a failed open returns the positive
 * errno value masquerading as a valid fd (root cause of PROBE r8
 * write_file content-leak).
 */
extern int open(const char *path, int flags, ...);
static int __attribute__((noinline)) hxlcl_open_sys(const char *path, int flags, ...) {
    int mode = 0;
    __builtin_va_list ap;
    __builtin_va_start(ap, flags);
    mode = __builtin_va_arg(ap, int);
    __builtin_va_end(ap);
    return open(path, flags, mode);
}
```

**Defense-in-depth (recommended companion)** — harden `hxlcl_fopen` against any future syscall-wrapper that returns a small positive errno. Today the only guard is `if (fd < 0)`; tighten to "small reserved fds (0/1/2) and unreasonable values are NOT real opens":

```c
/* self/runtime.c — hxlcl_fopen around line 799.
 * Defense layer for the carry-flag class of bug. A correct open() can
 * return fd in {0, 1, 2} only if those slots were closed first (very
 * unusual in this runtime). Anything in [0, 2] coming back from
 * O_CREAT|O_WRONLY is overwhelmingly the carry-flag confusion.
 */
static void *__attribute__((noinline)) hxlcl_fopen(const char *path, const char *mode) {
    if (!path || !mode) return (void *)0;
    int flags = 0;
    if (mode[0] == 'r') flags = O_RDONLY;
    else if (mode[0] == 'w') flags = O_WRONLY | O_CREAT | O_TRUNC;
    else if (mode[0] == 'a') flags = O_WRONLY | O_CREAT | O_APPEND;
    else return (void *)0;
    if (mode[1] == '+' || (mode[1] != 0 && mode[2] == '+')) {
        flags = (flags & ~(O_RDONLY | O_WRONLY)) | O_RDWR;
    }
    int fd = hxlcl_open_sys(path, flags, 0644);
    if (fd < 0) return (void *)0;
    /* Carry-flag defense: a freshly-opened user file cannot be 0/1/2
     * unless the runtime closed stdin/stdout/stderr first (it never
     * does). Anything in this range from open(2) is the wrapper
     * returning errno-as-fd → fail closed. */
    if (fd <= 2) return (void *)0;
    return (void *)(uintptr_t)(fd + 1);
}
```

**Audit pass for siblings** — `grep -n '_hxlcl_syscall' self/runtime.c` returns the full list of raw-svc users; the open fix is necessary, but the same audit should confirm none of the others (`fstat`, `stat`, `lseek`, `mmap`, `fcntl`, `ioctl`, `kill`, `poll`, `select`, `gettimeofday`, `exit`) returns the value to a path that branches on `< 0`. Spot-check shows several DO (`hxlcl_stat`, `hxlcl_fstat`, `hxlcl_lseek`) — those have the same latent bug class but no current `write_file`-equivalent observable. Recommend a follow-up cycle-67 sweep.

---

## ✅ Validation plan (post-fix)

Re-run the original probe + the two corroborators:

```bash
# 1. ENOENT case — expected: ok = false, NO leak
HEXA_NO_CACHE=1 hexa run /tmp/probe_writefile_leak.hexa 2>&1 | od -c | head -3
# Expected: 0000000  o  k     =     f  a  l  s  e \n

# 2. EACCES case — expected: ok = false, NO leak
HEXA_NO_CACHE=1 hexa run /tmp/probe_writefile_perm.hexa 2>&1 | od -c | head -3
# Expected: 0000000  o  k     =     f  a  l  s  e \n

# 3. Success control — expected: ok = true, file written, NO regression
HEXA_NO_CACHE=1 hexa run /tmp/probe_writefile_ok.hexa
cat /tmp/__exists__.txt
# Expected: ok = true / HELLO

# 4. Read-side cousin — confirm read_file on missing path returns "" or void (not leak)
cat > /tmp/probe_readfile_leak.hexa <<'EOF'
fn main() {
    let s = read_file("/tmp/__definitely_not_here__/y.txt")
    println("got=" + to_string(len(s)))
}
EOF
HEXA_NO_CACHE=1 hexa run /tmp/probe_readfile_leak.hexa 2>&1 | od -c | head -3
# Expected: got=0 (no fd-aliased read of garbage)
```

Plus a regression smoke (any existing `write_file`-heavy test in `self/test_*.hexa`).

---

## 🔬 Honest C3 (caveats for the maintainer)

1. **arm64 Darwin only.** The Linux x86_64 branch (`self/runtime.c:1222`) already routes `hxlcl_open_sys` through libc — that branch is correct. The bug is Mac-arm64-specific.
2. **PROBE r8 listed 4 possible mechanisms** (fopen-failure / HX_STR macro / link-time alias / path-traversal). Only #1 (fopen failure + downstream fd confusion) is the actual cause. The other three are RULED OUT by the disassembly + control test.
3. **Fix sketch not compiled yet.** Per inbox-only mandate, no binary rebuild attempted. The libc-wrapper pattern is byte-identical to what cycles 66 already shipped for read/write/close/dup2/pipe/fork/waitpid, so the risk surface is well-understood.
4. **Defense-in-depth `fd <= 2` guard is opt-in conservative.** It will refuse legitimate `open(2)` returns of 0/1/2 (which only happen if the runtime first closes stdin/stdout/stderr). If any code path in the runtime deliberately closes a std fd and re-opens it, the guard will break that pattern. Quick audit: no such pattern found, but the maintainer should confirm.
5. **The same root cause likely affects `stat`/`fstat`/`lseek`/`mmap` on Darwin arm64.** Out of scope for this probe (only `write_file` has a user-visible content leak), but worth a tracking ticket.

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
