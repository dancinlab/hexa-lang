# Fork Storm Inventory

Snapshot date: 2026-05-09. English only. No diagnostics emitted from the
inventory — this is documentation, not a lint.

Goal: bring per-build fork count down from 5–10 to ≤2, where the only
remaining unavoidable forks are the external assembler (`as`) and linker
(`ld`). Every other forked-out shell utility (date, uname, mkdir, rm, cat,
test, …) is replaced by a hexa intrinsic — see
`compiler/intrinsics/intrinsics.hexa`.

## Scope

Trees scanned:

- `compiler/`  — 13 files, 57 `exec(...)` call sites
- `tool/`      — 250 files, 1328 `exec(...)` call sites
- `tests/`     — 2 files, 18 `exec(...)` call sites

Total: **1403** `exec()` call sites across **265** files.

## Category histogram (top-10, by leading command word)

Status legend: **v0-absorbed** = a `compiler/intrinsics/intrinsics.hexa`
function exists for this category; bodies still fork once but the surface
is closed at the call site. **pending** = no intrinsic yet.

| Rank | Category    | Count | Status        | Notes                                        |
| ---- | ----------- | ----- | ------------- | -------------------------------------------- |
| 1    | `date`      | 160   | v0-absorbed   | wall-clock / timestamp formatting            |
| 2    | `rm`        | 123   | v0-absorbed   | filesystem deletion                          |
| 3    | `echo`      | 110   | v0-absorbed   | env probe (`echo $HOME`, `echo $$`)          |
| 4    | `test`      |  85   | v0-absorbed   | path / file existence probes                 |
| 5    | `uname`     |  84   | v0-absorbed   | host / arch detection                        |
| 6    | `mkdir`     |  78   | v0-absorbed   | directory creation                           |
| 7    | `pwd`       |  58   | v0-absorbed   | current working directory                    |
| 8    | `ls`        |  56   | v0-absorbed   | directory listing                            |
| 9    | `cd`        |  45   | pending       | shell-state path mutation (always paired)    |
| 10   | `git`       |  38   | pending       | repo metadata (rev-parse, log, status)       |

Cumulative v0-absorbed sites: **752** (160 + 123 + 110 + 85 + 84 + 78 +
58 + 56). Pending in top-10: **83** (45 + 38: cd + git). Long-tail
commands not counted here.

The long tail (wc, grep, cat, cp, basename, dirname, awk, printf, stat, …)
adds another ~300 calls.

## Top-10 representative call sites (file:line)

These are the highest-leverage replacement targets — each appears multiple
times in build-hot paths.

1. `compiler/main.hexa:100` — `exec("uname -sm 2>/dev/null").trim()`
   → `host_target()`
2. `compiler/main.hexa:255` — `exec("date +%s%N 2>/dev/null").trim()`
   → `now_ns()`
3. `compiler/main.hexa:264` — `exec("mkdir -p '" + dir + "' 2>/dev/null")`
   → `mkdir_p(dir)`
4. `compiler/main.hexa:558` — `exec("test -f " + obj_path + " && echo ok || echo fail")`
   → `path_exists(p)` (long-tail intrinsic)
5. `compiler/main.hexa:573` — `exec("cp -f " + obj_path + " " + out_path)`
   → `copy_file(src, dst)` (long-tail intrinsic)
6. `compiler/main.hexa:575` — `exec("rm -rf '" + tmp_dir + "' 2>/dev/null")`
   → `rm_rf(path)` (long-tail intrinsic)
7. `compiler/main.hexa:597` — `exec("xcrun --show-sdk-path 2>/dev/null")`
   → kept as exec (Darwin SDK probe — rare)
8. `compiler/link/hexa_ld.hexa:814` — `exec("uname -s 2>/dev/null").trim()`
   → `host_target()`
9. `compiler/discover/cascade.hexa:69` — `exec("date -u +%Y-%m-%d").trim()`
   → `today_utc()` (formats `now_ns()`)
10. `tool/hexa_ssot_init.hexa:59` — `exec("date -u +%Y-%m-%d").trim()`
    → `today_utc()`

## Per-call replacement plan

| Category | Intrinsic                         | Effort | Notes                                                  |
| -------- | --------------------------------- | ------ | ------------------------------------------------------ |
| date     | `now_ns()` + `format_utc(ns,fmt)` | S      | shipped — v0 fork; v1 clock_gettime FFI; v2 syscall 228|
| uname    | `host_target() -> string`         | S      | shipped — v0 fork; v1 compile-time constant            |
| mkdir    | `mkdir_p(path)`                   | S      | shipped — v0 fork; v1 libc walk; v2 mkdirat 258        |
| rm       | `rm_rf(path)` + `rm_file(path)`   | M      | shipped — v0 fork; v1 opendir/unlink FFI; v2 unlink 87 |
| test     | `path_exists`, `path_is_dir`      | S      | shipped — v0 fork; v1 libc stat; v2 access 21          |
| echo     | `getenv(name)`                    | S      | shipped — v0 validates name then forks; v1 libc getenv |
| pwd      | `getcwd()` / `cwd()`              | S      | shipped — v0 fork `pwd`; v1 libc getcwd; v2 syscall 79 |
| ls       | `list_dir(path) -> [string]`      | M      | shipped — v0 fork `ls -1`; v1 opendir/readdir; v2 217  |
| cd       | (call-site rewrite)               | M      | pending — most `cd && X` collapses into absolute paths |
| git      | `git_rev_parse_head()` + small    | L      | pending — keep as exec for v0; eventually parse `.git` |
| cat      | `read_file(path)`                 | S      | pending — already exists in stdlib for most call sites |
| cp       | `copy_file(src, dst)`             | S      | pending — read+write; sendfile() at v2 on Linux        |
| awk/sed  | (call-site rewrite)               | L      | pending — bring the formatting into hexa               |

## L0 → L3 ladder reference

- **L0 — fork storm (today).** Each call site forks a shell to invoke
  `date`, `uname`, `mkdir`, `rm`, `test`, … 5–10+ forks per build is
  routine; build latency dominated by `fork+exec+exit` overhead.
- **L1 — intrinsic surface (this RFC).** Call sites use named hexa
  functions like `now_ns()`, `host_target()`, `mkdir_p()`. The bodies
  still fork a single canonical command, but the call-site count stays
  flat regardless of how many places need the value (caching kicks in
  for `host_target`).
- **L2 — libc FFI.** Intrinsic bodies call libc directly through hexa's
  C-FFI: `clock_gettime`, `mkdir`, `uname`. One library load, no shell.
- **L3 — raw syscalls.** Intrinsic bodies emit the platform syscall
  trap inline (Linux x86_64 `syscall` insn, arm64 `svc 0`; Darwin uses
  the BSD syscall vector). Zero process forks for any of these
  primitives. Only `as` and `ld` remain as forks, satisfying the goal
  of ≤2 forks per build.

## Migration sequencing

1. Land `compiler/intrinsics/intrinsics.hexa` (this RFC). **Done.**
2. Add `rm_rf`, `rm_file`, `getenv`, `path_exists`, `path_is_dir` as the
   second batch of intrinsics — covers an additional ~318 sites
   (rm 123 + echo 110 + test 85). **Done 2026-05-09.**
3. Rewrite `compiler/main.hexa`, `compiler/link/hexa_ld.hexa`, and
   `compiler/discover/*.hexa` call sites — these are in the build hot
   path. Estimated 30 sites, S effort. **Pending (issue #58 + future
   batches).**
4. Add `getcwd`/`cwd`, `list_dir` as the third batch of intrinsics —
   covers the next ~114 sites (pwd 58 + ls 56). `getcwd()` forks `pwd`
   once (logical $PWD, matching every existing `exec("pwd").trim()`
   call site); `list_dir(path)` forks `ls -1` once with a single-quote-
   escaped path and splits on newlines (the newline-in-name caveat is
   documented inline and resolved at v1). **Done 2026-05-11.**
5. Land L2 (libc FFI) bodies once hexa's C-FFI lands cleanly.
6. Land L3 syscall bodies once the codegen knows the platform's
   syscall convention. At that point per-build forks = 2 (`as`, `ld`)
   and the goal is met.
