# R4 — HEXA-OWN Lane-B B2 vehicle: BORROWCK → advisory trigger wiring

Branch `feat/ownlint-vehicle-borrowck` · file: **`self/main.hexa` ONLY** (shipping CLI).
Base = `origin/main` (`ef0599b61`). Spec: `state/hexa-own/round3_dual_lane_batch_plan.json` `.result` §3 R4.

## What / why

Roadmap Lane-B **B2**: the own/borrowck lint already runs inside the native
frontend (`compiler/check`, gated by `HEXA_BORROWCK` / `HEXA_BORROWCK_STRICT`
from R3's E-ladder), but on the **gen2 shipping path** (`hexa build` / cold
`hexa run`) it was only reachable via `HEXA_OWN_LINT`. This wires the two
borrowck flags into the two shipping seams so a user on the released binary can
see borrowck diagnostics — advisory only.

## Anchors (re-verified against current main, NOT the stale spec coords)

| spec coord | actual line (ef0599b61) | site |
|---|---|---|
| :3228 | :3228 (unchanged) | advisory trigger `if env("HEXA_OWN_LINT") == "1"` in `cmd_build` |
| :4529 | :4529 (unchanged) | cold `hexa run` native `--emit=obj` output un-swallow in `cmd_run_user_direct` |

Both coordinates matched the spec exactly — no divergence.

## Diffs

1. **Trigger (:3228)** — extended to
   `env("HEXA_OWN_LINT") == "1" || env("HEXA_BORROWCK") == "1" || env("HEXA_BORROWCK_STRICT") == "1"`.
   The env var inherits into the advisory `aprime_cc` child, so this one OR is
   the whole wiring — the child's own/borrow registry activates off the same
   flag. Relabelled `[own-lint]` → `[own/borrow-lint]` on both eprintln lines
   and refreshed the block header comment.
2. **Cold `hexa run` un-swallow (:4529)** — the native-emit output forward
   condition now ORs the same 3 flags with `HEXA_CG_PROFILE`, exposing the
   "already running but nobody can see it" diag stream from the linux-x86_64
   cold native path.

## ADVISORY contract (UNCHANGED)

- aprime rc is deliberately **ignored**; the gen2 build is **never blocked**,
  **STRICT included** — enforcement (if any) is the native path's job; here it
  is diagnostics-only.
- A missing `aprime_cc` degrades to ONE loud line, not a build kill.
- Flag unset = one extra `env()` compare per site → default path
  byte-identical (byteeq 3-target gate = proof).

## Vehicle coverage (per verb/path)

| path | wired via | note |
|---|---|---|
| `hexa build` (C backend) | :3228 trigger | advisory aprime_cc spawn, both backends |
| `hexa build` (native backend) | :3228 trigger | sits before backend select → covers both |
| cold `hexa run` (linux-x86_64 native `--emit=obj`) | :4529 un-swallow | diag already produced, now forwarded |

## Honest limits

- **Warm-cache `hexa run` is NOT re-linted**: the un-swallow only fires on the
  cold native-emit path; a cache hit skips the emit entirely.
- **Advisory / non-blocking**: no rc change under any of the 3 flags, STRICT
  included. This is diagnostics wiring, not enforcement.
- **x86_64-linux only** for the cold-run seam (arm64/darwin never reach that
  native `--emit=obj` block).
- `hexa --help` intentionally **not** touched (avoids help-lockstep scope; env
  vars stay undocumented this round).

## Gate

`self/main.hexa` is the shipping CLI → standard **byteeq 3-target GREEN +
install.sh consumer smoke** before merge (orchestrator gates). Flag-OFF default
path is byte-identical by construction (single env() compare added per site).
