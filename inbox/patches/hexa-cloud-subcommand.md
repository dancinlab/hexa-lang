# hexa-cloud — register as `hexa cloud` subcommand

> **Status:** open — filed 2026-05-22 by sidecar/commons during `/cloud` wrapper ship cycle.
> **Update 2026-05-22 (cycle C):** subcommand wire ALREADY exists in `self/main.hexa:4693` (lands in source, currently absent from deployed `~/.hx/bin/hexa` — stale build). Cycle C extends the surface with a `preflight` verb (F-PREFLIGHT-MEM ✓). Sidecar plugin updated to expose preflight; awaits the next hexa deploy to be reachable end-to-end. Help text re-synced to byte-eq with `stdlib/cloud/cloud_cli.hexa::_cloud_help`.

**From:** sidecar (downstream consumer)
**Sister files:** sidecar `commons.tape` g8 · sidecar `skills/cloud/` plugin

## Problem (one concept)

`hexa cloud {run|nohup|poll|copy-to|copy-from}` is the canonical invocation referenced cross-project (sidecar `commons.tape` g8 — "for runpod dispatch use `hexa cloud` ..."). But `hexa --help` doesn't list `cloud` as a subcommand:

```
$ hexa cloud --help
error: unknown subcommand 'cloud'
```

The functionality EXISTS in hexa-lang source:

- `~/core/hexa-lang/bin/hexa-cloud` — standalone binary (NOT on PATH after install)
- `~/core/hexa-lang/stdlib/cloud/cloud.hexa` — implementation
- `~/core/hexa-lang/stdlib/cloud/cloud_cli.hexa` — CLI wiring (subcommand-shaped?)

But the wiring from `hexa <subcommand>` dispatcher to the cloud implementation is missing — `hexa cloud` is unrecognized.

## Symptom (downstream)

sidecar's `/cloud` slash command wrapper (`skills/cloud/bin/cloud.sh`) calls `exec hexa cloud "$@"` per the canonical g8 form. This fails until the subcommand is registered.

Workaround temptation: have sidecar wrap `hexa-cloud` (separate binary) instead. **Rejected** per commons g11 (no gap workarounds — file upstream inbox patch).

## Ask

In `~/core/hexa-lang/`:

1. Register `cloud` as a hexa subcommand in the top-level dispatcher (whichever module routes `hexa <verb>` to the corresponding stdlib module). Reference: `stdlib/cloud/cloud_cli.hexa` (already CLI-shaped).
2. After registration, `hexa cloud --help` should print the cloud usage (run · nohup · poll · copy-to · copy-from subverbs).
3. `hexa --help` should list `cloud` in the STDLIB CLI section.
4. Optional: deprecate / archive `bin/hexa-cloud` (separate binary) once the subcommand form is canonical, so there's a single SSOT.

## Acceptance

```
$ hexa cloud --help
hexa cloud — structured-argv remote dispatch + cycle C preflight

usage (cycle A — transport):
  cloud run / nohup / poll       ...

usage (cycle B-1 — file transfer):
  cloud copy-to / copy-from      ...

usage (cycle C — preflight $0 gates):
  cloud preflight [spec-flags]   ...

$ hexa cloud run <pod> "<cmd>"          # works without errors
$ hexa cloud preflight --n-params-m 8920 --optimizer AdamW --gpu-mem-mb 81920 ...
# exit 0 = green, exit 2 = BudgetExceededError / CapabilityError / ...
```

Once landed, sidecar `/cloud` wrapper works without code change (already on the canonical form). The cycle-C `preflight` verb is already wired in `stdlib/cloud/cloud_cli.hexa::_cmd_preflight` and reachable via `cmd_run` fallback in the existing `self/main.hexa` cloud branch — just needs a fresh `~/.hx/bin/hexa` deploy.

## Related

- sidecar `commons.tape` g8 — canonical `hexa cloud` reference
- sidecar `skills/cloud/.claude-plugin/plugin.json` — wrapper plugin
- `~/core/hexa-lang/bin/hexa-cloud` — current separate-binary impl
- `~/core/hexa-lang/stdlib/cloud/cloud_cli.hexa` — CLI wiring source
