# fork-storm source-block — HX9xxx lint + runtime concurrency cap

**Status:** 🟠 FILED / OPEN (2026-05-23)
**Reporter:** anima session — observed during round-5 parallel probe fanout
**Severity:** medium-high — recurring symptom (PRs #343 / #359 each closed
one storm vector; the user observes a new occurrence, with the
self-help comment at `self/main.hexa:208` calling the HX9xxx
fork-storm lint "planned").

## Symptom

`hexa run <probe>` chains spawn `hexa_v2` (transpile) → `clang`
(compile) → executable, per invocation.  When N agents / probes /
loops each invoke `hexa run` on distinct inputs, the cache (#359
content-hash) misses on every input — and clang spawns are
unbounded.  Observable as a flood of `clang` PIDs during heavy probe
work.  PR #343 closed the `runtime.o` recompile vector; PR #359 closed
the `hexa run` content-hash cache vector; the remaining vector is
**parallel unique-input compiles with no global concurrency cap**.

## The user directive

"fork storm 원천 차단 가능해야함" — must be source-blockable.  Two
mechanisms are needed:

1. **HX9xxx fork-storm lint** (planned per `self/main.hexa:208`) —
   author-level static prevention.  Catch `exec("clang …")` /
   `exec_with_status("clang …")` patterns that should route through an
   intrinsic; map to `compiler/intrinsics/intrinsics.hexa`.  Refuses
   commits that introduce new shell-out paths.
2. **Runtime concurrency cap on clang invocations** — system-level
   structural limit.  Counting semaphore via `flock` (or `mkdir`-token
   pool) caps concurrent clang to `N` (default = nproc, ENV override
   `HEXA_BUILD_PARALLELISM`).  Excess invocations wait on the lock,
   not block-fork-spawn.

## Design — runtime cap (smaller, ship first)

Wrap every `clang …` invocation site in `cmd_build` / `cmd_run` with a
`flock`-guarded permit acquisition:

```hexa
fn _hexa_clang_with_cap(cmd) {
    let cap_n = env_or_default("HEXA_BUILD_PARALLELISM", num_cpus())
    let lock_root = tmpdir() + "/.hexa_clang_caps"
    exec("mkdir -p " + lock_root)
    let mut tok = 0
    loop {
        // Try to acquire a token (mkdir is atomic on most fs)
        let token_dir = lock_root + "/" + to_string(tok)
        let r = exec_with_status("mkdir " + token_dir + " 2>/dev/null && echo OK")
        if r[1] == 0 { break }
        tok = (tok + 1) % cap_n
        // exponential backoff up to 200 ms
        sleep_ms(min(100, 5 * (1 + tok)))
    }
    let out = exec(cmd)
    exec("rmdir " + token_dir + " 2>/dev/null")
    return out
}
```

Three call sites in `self/main.hexa` are documented (around lines 2616
inflight build, 2706 sibling, plus the regen-time runtime.o compile at
`cmd_cc` line 975).  Each one substitutes `exec(cmd)` → `_hexa_clang_with_cap(cmd)`.

Concerns:
- Token leak on hard kill — startup must reap stale tokens older than
  N seconds.
- `mkdir`-token may not be atomic on networked fs — fall back to
  `flock` on a sentinel file (Linux/macOS reliable).
- Latency cost on lightly-loaded systems — negligible (the loop fast-
  paths through cap_n attempts before backoff).

## Design — HX9xxx lint (bigger, file as RFC)

Author-level catch: any `exec(…)` / `exec_with_status(…)` whose first
argument's string content matches a shell-out signature gets an HX9001
diagnostic with the mapped intrinsic.  Concrete signatures + intrinsic
mappings already listed at `self/main.hexa:208-215`:

```
pwd                → cwd()
ls <path>          → list_dir(path)
test -e <p>        → path_exists(p)
test -d <p>        → path_is_dir(p)
mkdir -p <p>       → mkdir_p(path)
rm <p>             → rm_file(path)
rm -rf <p>         → rm_rf(path)
uname -sm          → host_target()
date +%s%N         → now_ns()
$VAR               → getenv(k)
clang …            → (intentional codegen path — exempt; but cap via runtime semaphore above)
```

The lint runs at parse time: walk all `Call(exec, [StringLit s, …])`
and `Call(exec_with_status, [StringLit s, …])`; pattern-match `s`
against the signature table; emit HX9001 with the mapping hint.

`@grace(HX9001, until="…", reason="…")` opt-out exists per the
existing grace surface (`self/main.hexa:227`).

## Sequence

1. Ship the runtime cap (small).  Closes the immediate observable storm.
2. RFC for HX9001 lint.  Closes the structural drift.

## Cross-refs

- Prior fork-storm closures: #343 (runtime.o cache), #359 (hexa run /
  batch content-addressed cache)
- Intrinsic surface table: `self/main.hexa:208-215`
- Grace mechanism: `self/main.hexa:227-229`
