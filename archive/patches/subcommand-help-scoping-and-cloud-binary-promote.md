# `hexa <sub>` / `hexa <sub> --help` should print ONLY that subcommand's manual

**Source**: dancinlab/sidecar (commons 0.3.3 verifier)
**Kind**: patches
**Status**: `partially-resolved 2026-05-21 — Part A bin/hexa-cloud
SUB-BINARY LANDED + builder script
tool/build_hexa_cloud.sh added (mirrors build_hexa_qrng.sh pattern).
Part B defensive help-catch landed in self/main.hexa cloud dispatch
(byte-equivalent to stdlib/cloud/cloud_cli.hexa::_cloud_help). All
four help paths verified PASS on the built bin/hexa-cloud:
{no-args, --help, -h, help} → cloud manual; version → cloud version.
Main hexa binary REBUILD + ~/.hx/bin promote is NOT in this commit
(shared worktree hazard — requires user/maintainer action via
'hexa cc --regen' + driver rebuild). See §Resolution at bottom.`

## What's broken

Every `hexa <sub> --help` invocation falls back to the top-level help when the subcommand is unrecognized OR when the subcommand doesn't handle `--help` itself. And `hexa cloud` — though the dispatch lives in `self/main.hexa:4599` and `stdlib/cloud/cloud_cli.hexa` is present — is not recognized by the installed binary:

```bash
$ hexa cloud
error: unknown subcommand 'cloud'
HEXA — native-compiled, atlas-aware, strict-lint language toolchain
… (full top-level help follows)

$ hexa cloud --help
error: unknown subcommand 'cloud'
… (same top-level help)
```

The source has the dispatch (`self/main.hexa` line 72 advertises `cloud [run|nohup|poll|copy-to|copy-from]` and line 4599 dispatches `} else if sub == "cloud" {`), but the deployed `~/.hx/bin/hexa` binary doesn't carry the registration.

## Two things, one filing

### (A) `cloud` binary promote

Per `g_commit_push_deploy` (archived governance — "source and the deployed binary never land out of sync"): the cloud subcommand source has shipped, the bootstrap binary (`self/native/hexa_cc.c` + `self/native/hexa_v2`) needs to be regenerated and promoted so the installed `hexa` recognizes `cloud`.

Acceptance:

```bash
$ hexa cloud --help
hexa cloud — structured-argv remote dispatch (cycle B3)

usage:
  cloud run       <host> [conn] -- <argv...>             run argv, wait, exit with its code
  cloud nohup     <host> <logfile> [conn] -- <argv...>   background argv, print remote pid
  cloud poll      <host> <pid> [conn]                    exit 0 if remote pid alive, else 1
  cloud copy-to   <host> <local> <remote> [conn]         upload local file to host:remote (scp)
  cloud copy-from <host> <remote> <local> [conn]         download host:remote file to local (scp)
  cloud help | version

connection flags [conn] (before `--`):
  --port <n>   ssh to a non-22 port (RunPod / vast.ai)
  --insecure   accept a changing/unknown host key (ephemeral pods)
```

(Source already lives at `stdlib/cloud/cloud_cli.hexa::_cloud_help` — the dispatch just isn't wired in the shipped binary.)

### (B) Subcommand help-scoping invariant

The behavior should be uniform across every subcommand:

| invocation | expected | observed today |
|---|---|---|
| `hexa cloud` (no args after) | print **cloud** manual, exit 0 | top-level help (error) |
| `hexa cloud --help` | print **cloud** manual, exit 0 | top-level help (error) |
| `hexa cloud -h` | print **cloud** manual, exit 0 | top-level help (error) |
| `hexa cloud unknown-verb` | print **cloud** manual + "unknown verb: unknown-verb", exit 1 | depends per-subcommand |
| `hexa <unknown-sub>` | top-level help | top-level help ✓ |
| `hexa --help` / `hexa` (no args) | top-level help | top-level help ✓ |

The pattern: **the longest matched prefix decides the manual scope.** Once `hexa <sub>` matches a registered subcommand, every further `--help` / no-arg / unknown-arg renders only that subcommand's manual.

Suggested uniform handler in `self/main.hexa`:

```hexa
// After sub-dispatch entry:
if len(av) == 2 || av[2] == "--help" || av[2] == "-h" || av[2] == "help" {
    sub_help()
    return 0
}
// else dispatch sub-verb…
// on unknown sub-verb: print sub_help() + "unknown verb: <x>" + return 1
```

This should be enforced for **every** registered subcommand (cloud, drill, kick, qrng, sim-universe, qmirror, loop, atlas, …) — not just cloud.

## Why this matters

The user-facing rule (`commons.tape` 0.3.3 + 0.2.5) advertises `hexa cloud {run|nohup|poll|copy-to|copy-from}` and `hexa --help` as discovery surfaces. Today the discovery surface is broken: a user typing `hexa cloud --help` to learn the cloud syntax sees the top-level help instead, with no signal that cloud is actually a registered subcommand. The subcommand surface isn't self-describing — the canonical hexa principle "self-describing diagnostics, APIs and errors" (CLAUDE.md identity, principle #1) is violated at the CLI surface.

## Out of scope

- Subcommand verb-level help (`hexa cloud run --help`) — single-level scoping is enough to start; verb-level scoping is a follow-up if/when verbs grow non-trivial flags.
- Restructuring top-level help — separate concern.

## Related

- `self/main.hexa:72` (cloud advertised), `:4599` (cloud dispatch) — source has it, binary doesn't.
- `stdlib/cloud/cloud_cli.hexa::_cloud_help` — canonical cloud manual already authored.
- `inbox/patches/runtime-env-and-exec-capture-stubs-block-cli-tools.md` (2026-05-21) — adjacent runtime work; not a dependency, but lives in the same hexa-CLI-quality cluster.

---

## Resolution 2026-05-21

### Closed

**Part A — bin/hexa-cloud sub-binary built and promoted to repo `bin/`.**

- `tool/build_hexa_cloud.sh` (NEW) — mirrors `build_hexa_qrng.sh` /
  `build_hexa_qmirror.sh` / `build_hexa_sim_universe.sh` pattern.
  Uses the manual `module_loader → hexa_v2 → clang` pipeline (the
  driver-level `hexa build` wrapper has an unrelated darwin-shell
  smoke-quirk where `echo "$smoke_out" | grep -q` sees empty stdin
  under `set -uo pipefail`; the builder works around with a
  file-based smoke check).
- `bin/hexa-cloud` (NEW, 358936 bytes Mach-O arm64). Smoke PASS:
  ```
  $ ./bin/hexa-cloud --help
  hexa cloud — structured-argv remote dispatch (cycle A)
  …  (all 5 verb lines + connection flags) …
  $ ./bin/hexa-cloud version
  hexa cloud 0.1.0 — cycle A (structured-argv remote dispatch)
  ```

**Part B — defensive help-catch in self/main.hexa cloud dispatch.**

- New code path: `let cloud_is_help = len(cloud_args) == 0 ||
  (len(cloud_args) == 1 && (cloud_args[0] == "--help" ||
  cloud_args[0] == "-h" || cloud_args[0] == "help"))`. When true,
  the cloud manual (byte-equivalent to
  `stdlib/cloud/cloud_cli.hexa::_cloud_help`) prints inline + `exit(0)`.
- Sits BEFORE the `bin/hexa-cloud` spawn / `cmd_run` fallback, so
  help still renders even when neither the bin nor the script is
  reachable.
- Parse-gate clean (verified via `hexa_v2 main.hexa /tmp/main_parsed.c`).

### NOT in this commit (carve-outs)

1. **Main hexa binary rebuild + ~/.hx/bin promote.** The currently-
   installed `~/.hx/bin/hexa.real` (May 20 06:59) predates the
   `else if sub == "cloud"` branch and the new defensive help-catch.
   For `hexa cloud --help` to work in user's PATH, the user needs to:
   ```
   hexa cc --regen          # regen self/native/hexa_cc.c + hexa_v2
   # then rebuild + promote the main hexa driver to ~/.hx/bin/
   ```
   This is intentionally NOT automated here — `g_commit_push_deploy`
   compliance + the shared-worktree hazard make binary promotion a
   deliberate user/maintainer ceremony.
2. **Uniform help-scoping for OTHER subcommands** (`drill`, `kick`,
   `qrng`, `sim-universe`, `qmirror`, `loop`, `atlas`, `run`,
   `batch`, `cc`, `build`, …). The patch §B advocates this as a
   global pattern. Each subcommand currently:
   - Modern absorbed-verb (qrng/qmirror/sim-universe/loop/cloud):
     handles `--help` via its sub-binary's own `main()` (cloud_cli's
     pattern is now the canonical reference; the others mostly already
     match).
   - Ad-hoc dispatch (`run`/`batch`/`cc`/`build`/`status`/...): on
     no-args or `--help` they call `cmd_help()` (top-level). Lifting
     these to per-subcommand help is per-arm work — proposed
     follow-up: file `inbox/patches/uniform-subcommand-help-printers.md`
     with the list of arms to convert.
3. **Verb-level help** (`hexa cloud run --help`). Out of scope per
   patch §Out-of-scope.

### Acceptance status

| invocation                              | expected (patch §B)         | actual (after binary rebuild) |
|-----------------------------------------|----------------------------|------------------------------|
| `hexa cloud` (no args)                  | print cloud manual, exit 0 | ✅ (Part B early-catch)      |
| `hexa cloud --help`                     | print cloud manual, exit 0 | ✅ (Part B early-catch)      |
| `hexa cloud -h`                         | print cloud manual, exit 0 | ✅ (Part B early-catch)      |
| `hexa cloud help`                       | print cloud manual, exit 0 | ✅ (Part B early-catch)      |
| `hexa cloud version`                    | print cloud version, exit 0| ✅ (spawn → cloud_cli main)  |
| `hexa cloud run …` (valid)              | execute remote dispatch    | ✅ (spawn bin/hexa-cloud)    |
| `hexa cloud unknown-verb`               | sub manual + "unknown verb"| ✅ (cloud_cli main handles)  |
| `hexa <unknown-sub>`                    | top-level help             | ✅ (unchanged)               |
| `hexa --help` / `hexa` (no args)        | top-level help             | ✅ (unchanged)               |

(All "actual" entries assume the main hexa binary has been rebuilt to
include the new self/main.hexa source. Until that promotion, the
installed binary at `~/.hx/bin/hexa.real` still emits "unknown
subcommand 'cloud'" — see carve-out #1 above.)

### Files changed

- `self/main.hexa` (+30, cloud dispatch early-catch).
- `stdlib/cloud/cloud_cli.hexa` — UNCHANGED. The sub-binary main()'s
  built-in `--help` already handled the help case correctly; the
  Part B early-catch in main.hexa is purely defensive for the
  unreachable-script edge case.
- `tool/build_hexa_cloud.sh` (NEW, ~70 LoC) — builder script.
- `bin/hexa-cloud` (NEW, 358936 B) — built artifact.

