# `hexa <sub>` / `hexa <sub> --help` should print ONLY that subcommand's manual

**Source**: dancinlab/sidecar (commons 0.3.3 verifier)
**Kind**: patches
**Status**: filed

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
