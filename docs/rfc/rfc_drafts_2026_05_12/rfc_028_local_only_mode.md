# RFC 028 — `--local` / `HEXA_NO_REMOTE=1` for explicit non-dispatched execution

- **Status**: draft
- **Date**: 2026-05-12
- **Severity**: MEDIUM (cross-host transparency)
- **Priority**: P1
- **Source convergence**: HEXA_NATIVE_INFERENCE.md Phase 1.2
- **Source session**: Mac shell `hexa run` silently offloads to aiden

## Problem

The Mac-side `hexa run script.hexa` binary (`/Users/ghost/core/hexa-lang/hexa.real`, Mach-O arm64) **silently forwards execution to aiden host** via the resource-tcp dispatcher. The user cannot tell from invocation alone whether code runs locally or remotely.

Evidence:

```
# Mac shell:
$ uname -s
Darwin

# hexa probe of env from Mac shell:
$ hexa run /tmp/env_probe.hexa
HOME = /home/aiden       # ← LINUX
USER = aiden
PWD = /tmp/resource-tcp-XXXX
uname-s = Linux
hostname = aiden-B650M-K
```

This silent dispatch causes:
1. **Path confusion**: `~/core/anima/foo` means different paths on Mac vs aiden
2. **State surprise**: Files written on Mac aren't visible to hexa unless on sshfs mount
3. **Debugging difficulty**: Failures attribute to wrong host
4. **Resource overcommit**: One bad script (e.g., 9GB ML load) can OOM aiden; Mac shell user unaware until ssh dies

## Falsifier

- F-028-1: `hexa --local run script.hexa` ALWAYS runs on the host invoking the binary (no dispatch)
- F-028-2: `HEXA_NO_REMOTE=1 hexa run script.hexa` same effect (env-level)
- F-028-3: default behavior (no flag) emits ONE-LINE diagnostic if dispatching: `[hexa-runtime] dispatching to <host>:<port> (HEXA_LOCAL=1 to disable)`
- F-028-4: `hexa --local-or-fail run script.hexa` errors out if local execution unsupported (e.g., binary is dispatcher-only)

## Proposal

Three layered controls:

### Tier A — explicit flag
```
hexa --local run script.hexa     # force local
hexa --remote run script.hexa    # force remote (current default for Mac binary)
hexa run script.hexa             # current default + diagnostic
```

### Tier B — env var
```
HEXA_NO_REMOTE=1 hexa run ...    # same as --local
HEXA_DISPATCH=remote hexa run    # same as --remote
HEXA_DISPATCH=auto hexa run      # current default + diagnostic
```

### Tier C — verbose dispatch indicator
```
$ hexa run script.hexa
[hexa-runtime] dispatching to aiden:port (HEXA_LOCAL=1 to disable)
HOME = /home/aiden
...
```

## Implementation

- Diagnostic line via existing `HEXA_DISPATCH_TRACE` mechanism — promote a single line to default-on
- `HEXA_NO_REMOTE=1` short-circuits the dispatcher in `main()` of the Mac binary
- `--local` flag parsed in CLI before dispatcher engages

## Cross-RFC

- RFC 026 (env passthrough): once 026 lands, `--local` might be unnecessary because env propagates cleanly. But 028 is still valuable for debugging.
- RFC 024 (mem cap): local mode would inherit Mac's mem (much higher headroom in M-series Macs vs ubu hosts).

## Risks

- Local Mac execution might lack certain features the aiden Linux binary has (different stdlib version, missing FFI libs). Mitigation: `--local-or-fail` errors out explicitly when feature missing rather than silent fallback.

## Migration

- All three controls are additive — no breaking change
- Diagnostic line could be opt-out (`HEXA_QUIET_DISPATCH=1`) for scripts that parse stdout
