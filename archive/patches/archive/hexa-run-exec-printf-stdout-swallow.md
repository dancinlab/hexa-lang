# `exec()` builtin silently swallows child stdout under `hexa run`

> **Status:** resolved — working-as-designed (2026-05-23). `exec(cmd)` is a **capturing** call: `hexa_exec` (runtime_core.c:5061) runs the child via `popen(cmd, "r")` / posix_spawn and returns the child's **stdout as a string**. It is the canonical capture primitive (≈ Python `subprocess.check_output` / shell backticks), NOT `system()`. The "swallow" is simply the captured stdout being discarded when the return value is unused. stderr is not piped → inherits the parent fd → that's why `printf … >&2` still shows (explains the asymmetry in the TL;DR). Canonical usage: `print(exec("printf hello"))` to surface captured output, or `exec_stream(cmd, on_line)` for live line-by-line passthrough (e.g. long-running / daemon output). No code change — forcing `exec()` to passthrough would break every caller that relies on capture (the dominant use). Cross-link: streaming path is `hexa_exec_stream` (runtime_core.c, just below `hexa_exec`).

**Reporter**: anima (`dancinlab/anima` downstream consumer · cycle 2/I `telemetry_status.hexa` dev)
**Severity**: medium (workaround = `println` exists, but the pattern is a footgun for any
module mixing shell-out output with native `println`)
**Affected**: `self/main.hexa::cmd_run_user_direct` (exec-capture path) AND/OR the `exec()`
runtime builtin that does not forward captured child stdout to the outer process

## TL;DR

Inside a `.hexa` program invoked via `hexa run x.hexa`:

```
exec("printf '%s\n' hello")     → output silently swallowed (no surface to stdout)
println("hello")                → output appears on stdout correctly
exec("printf '%s\n' hello >&2") → output appears on stderr correctly
```

The shell child's STDOUT is captured by hexa's exec-capture model and then **dropped**
instead of being forwarded to the outer `hexa run` process's stdout. Stderr passes
through fine. Cycle 2/I hit this while building a CLI that used `exec("printf ...")`
for output formatting and saw zero bytes on stdout despite a clean exit.

## Symptom — minimal repro

```hexa
fn main() {
    exec("printf '%s\\n' SHOULD_APPEAR_STDOUT")
    println("DID_APPEAR")
    eprintln("STDERR_OK")
}
```

Run as:

```
nohup hexa run x.hexa > out 2> err < /dev/null
```

Observed:

| stream | contents |
|--------|----------|
| `out`  | `DID_APPEAR` |
| `err`  | `STDERR_OK` |
| nowhere | `SHOULD_APPEAR_STDOUT` |

The `printf` child exits 0, `exec()` returns to the caller, and the next two lines
fire as expected — only the child's STDOUT bytes are lost. Switching the child to
write to stderr (`>&2`) is a workaround; switching to `println` is the recommended
one.

## Root cause hypothesis

`cmd_run_user_direct` (per the sibling `proc-spawn-supervised-daemon-silent-exit`
patch) runs each compiled body via

```hexa
let out = exec(cmd + " 2>&1; echo \"__HEXA_SHIM_RC__=$?\"")
```

After the child exits, hexa.real `print(body)` to its own stdout — so the *outer*
binary's stdout reaches the user. But when an `exec()` call is made **from inside**
the running hexa script itself, the shell child's STDOUT appears to go to neither:

- it is not returned as the value of `exec()` (return value is empty)
- it is not forwarded to the calling script's stdout (no bytes appear)
- only redirecting `>&2` inside the shell argument makes the bytes appear

The asymmetry — `println` ok, `eprintln` ok, child-stderr ok, child-stdout dropped —
points at the inner `exec()` builtin discarding (or failing to plumb) the shell
child's stdout pipe. Possibly only the shell's exit code is captured, with stdout
sunk into `/dev/null` or an unread pipe end.

## Suggested fix

Three options, pick one:

- **(a)** `exec(cmd)` returns the captured stdout (mimics Python's
  `subprocess.check_output`) — semantically clean but **backward-incompatible** if any
  caller expects empty.
- **(b)** `exec(cmd)` forwards child stdout to the caller's stdout via pipe
  inheritance AND returns `""` — like `os.system`. Backward-compatible on the return
  value, surprising if any caller expected stdout to be hidden.
- **(c)** add `exec_capture(cmd) -> str` for (a) semantics AND keep `exec(cmd)` as
  fire-and-forget with current empty-return semantics, **but** fix the silent
  swallow by inheriting child stdout (pipe `fileno(stdout)` → child) instead of
  capturing-then-dropping. Document the existing footgun in `exec()` docstring
  meanwhile.

**Recommendation**: (c) — backward-compatible + adds a new explicit verb for the
"I want the output" case, while turning today's silent drop into proper inheritance
for the "fire and forget" case.

## Cross-link

- `[[proc-spawn-supervised-daemon-silent-exit]]` — related but distinct. That patch
  covers daemons (long-running) where `cmd_run_user_direct`'s exec-capture never
  returns. This patch covers short-running CLIs where `exec()` *does* return but the
  child's stdout is lost. Both touch the same root area
  (`cmd_run_user_direct` + the `exec` builtin's stdout plumbing); fixing one may
  unblock the other.

## honest C3

1. Workaround exists (`println` for native output, `>&2` for shell-out output), so
   severity is medium not high. No production daemon is blocked by this.
2. Only bites mixed-pattern code. Most native hexa-lang server modules
   (`telemetry_harness.hexa`, `akida_consumer.hexa`) stick to `eprintln` and never
   notice the gap.
3. Discovered in `.hexa` script context (`hexa run x.hexa`). Behavior of `exec()`
   from inside `hexa build`-compiled standalone binaries (invoked directly, not via
   `hexa run`) may differ and is **untested** by this patch.
4. `proc-spawn-supervised-daemon-silent-exit` and this share the same root area
   (`cmd_run_user_direct`'s exec-capture). Fixing one might fix the other or might
   not — they are correlated but not identical bugs.
