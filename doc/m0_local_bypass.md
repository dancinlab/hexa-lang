# M0 Smoke Harness — Local Interpreter Bypass

**Status:** Workaround for Gap 6 from M0 smoke report (commit `b437a77c`).
**Owner:** anyone running `tests/m0/run_m0.hexa` on a fresh box.

## Problem

The shell wrapper at `$HOME/.hx/bin/hexa` (resource toolkit) routes
`hexa run` and `hexa batch` over TCP to a remote host:

```sh
#!/bin/sh
HEXA_REAL=$HOME/.hx/packages/hexa/hexa.real
case "$1" in
    run|batch) exec /Users/ghost/core/resource/bin/hexa-r ubu-1 "$@" ;;
    *) exec "$HEXA_REAL" "$@" ;;
esac
```

Two problems for M0:

1. The wrapper is **unconditional** — `RESOURCE_LOCAL_HEXA=1` is silently ignored.
2. The remote `hexa-r ubu-1` route **drops `--target`, `--emit`, and `-o` flags**, so
   `compiler/main.hexa` never receives the M0-driver arguments.

Worse, two paths the harness used to probe are themselves routing wrappers,
not local binaries:

* `$HOME/.hx/packages/hexa/build/hexa_interp.real` — POSIX shell, contains `hexa-r ubu`.
* `<repo>/build/hexa_interp.real` — POSIX shell, same routing logic.

## Solution

A POSIX-sh helper `tool/find_local_hexa.sh` probes for a real local
interpreter binary in priority order and **rejects any candidate whose
first 4KB contain the `hexa-r ubu` routing marker**. The M0 harness
(`tests/m0/run_m0.hexa`) calls this helper via `exec()` and uses its stdout
as the interpreter path.

### Probe order

| # | Path | Notes |
|---|------|-------|
| 1 | `$HEXA_INTERP` | Explicit user override; most specific. |
| 2 | `build/hexa_interp.darwin` *or* `build/hexa_interp.linux` | Host-specific vendored binary. Picked via `uname -s`. |
| 3 | `self/native/hexa_v2` | Self-hosted compiler binary (Mach-O on macOS dev boxes). |
| 4 | `/usr/local/bin/hexa_real` | System-wide bypass install. |
| 5 | `$HOME/.hx/bin/hexa_real` | Per-user bypass install. The user's existing native binary. |

If nothing matches, the helper exits 1 with a diagnostic listing every
path it tried.

### Why we keep `$HOME/.hx/bin/hexa_real` last

It is reliable but user-specific. CI / fresh boxes will not have it.
Vendored or in-tree binaries should win first, so the harness is
reproducible without a populated `$HOME/.hx`.

## Usage

### macOS (Apple Silicon dev box)

```sh
cd /path/to/hexa-lang
HEXA_BIN=$(tool/find_local_hexa.sh) || exit 1
"$HEXA_BIN" run tests/m0/run_m0.hexa
```

On the existing dev box, this resolves to `self/native/hexa_v2` (Mach-O arm64).

### Linux CI

Vendor the host binary at `build/hexa_interp.linux` (already committed,
ELF x86\_64). The helper picks it automatically:

```sh
tool/find_local_hexa.sh
# -> /workspace/hexa-lang/build/hexa_interp.linux
build/hexa_interp.linux run tests/m0/run_m0.hexa
```

### Fresh checkout (no pre-built interpreter)

Two options:

1. **Build it:** any of the existing build scripts produce
   `build/hexa_interp.<host>`. Run the build, then re-run the harness.
2. **Point at an external binary:**

   ```sh
   export HEXA_INTERP=/abs/path/to/known-good-hexa
   tests/m0/run_m0.hexa
   ```

## Constraints respected

* We do **not** modify `$HOME/.hx/bin/hexa` — that is the user's
  environment, owned by the resource toolkit.
* The helper is POSIX `sh`; no `bash` arrays, `[[ ]]`, or `read -r`.
* No new dependencies. Uses only `head`, `grep`, `uname`, `dirname`,
  `cd`, `pwd`, `printf`.

## File map

| File | Role |
|------|------|
| `tool/find_local_hexa.sh` | POSIX-sh probe, prints absolute path of usable interpreter. |
| `tests/m0/run_m0.hexa` | M0 harness; `_resolve_hexa_bin()` shells out to the helper. |
| `doc/m0_local_bypass.md` | This file. |

## Future improvements (not done here)

* `tool/build_local_interp.hexa` — recompile `hexa_cc.c` to
  `build/hexa_interp.<host>` on demand. Currently out of scope; tracked
  as a follow-up to Gap 6.
* Commit a vendored `build/hexa_interp.darwin` so option (2) of the
  probe order works without `self/native/hexa_v2` being present.

## Adding the `Acked-grace` trailer

Unrelated to the M0 bypass above, every `@grace(HXxxxx, ...)` site that
a commit or PR introduces or modifies must carry a matching consent
trailer per SPEC.yaml `opt_out.ai_native_warn_policy.user_consent_mechanism`.
The CI gate is `tool/check_grace_consent.hexa`, wired to PRs by
`.github/workflows/grace_consent.yml`.

### Trailer format

* In a **commit message body** (one trailer per acknowledged site):

  ```
  Acked-grace: HX1042 by alice
  ```

* In a **PR description** (same form; multiple sites use multiple lines):

  ```
  Acked-grace: HX1042 by alice
  Acked-grace: HX5001 by bob
  ```

The match is case-insensitive (`acked-grace:` is fine), tolerates leading
whitespace, and accepts either ` by ` or ` By ` between the HX code and
the reviewer handle. Trailing whitespace is allowed; a final newline is
optional.

### Local pre-flight

Before pushing, you can run the same check the CI runs:

```sh
# default: HEAD vs HEAD~1 against the HEAD commit message
hexa tool/check_grace_consent.hexa

# explicit base..HEAD range
hexa tool/check_grace_consent.hexa --diff origin/main

# specific commit
hexa tool/check_grace_consent.hexa --commit <sha>
```

Exit 0 = every `@grace` site has a matching trailer; exit 2 = at least
one site is unacknowledged (full per-site report on stderr).
