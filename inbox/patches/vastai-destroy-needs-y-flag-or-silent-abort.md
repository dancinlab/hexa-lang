# `hexa cloud destroy <iid>` (Vast.ai backend): silent abort + rc=0 when `vastai destroy instance` lacks `-y`

**Reporter**: demiurge (`dancinlab/demiurge` RTSC DFT campaign, 2026-05-23)
**Severity**: high — silent leak class. Caller scripts see exit code 0 and assume the instance is gone; instance keeps billing.
**Affected**: `stdlib/cloud/cloud_cli.hexa` (vast-backend dispatch path) — the wrapper that shells out to `vastai destroy instance <iid>`.

## Problem statement

`vastai destroy instance <iid>` opens an interactive `Are you sure? [y/N]` prompt. In a non-interactive context (CI script, hexa-cloud dispatch, EOF on stdin) the prompt receives EOF, `vastai` prints `Aborted.` to stdout, **exits with rc=0**, and the instance keeps running.

The hexa-cloud wrapper currently forwards rc verbatim — callers see `exit 0` and treat the destroy as successful. Result: orphan instances accumulate at full hourly billing, only discovered on the next `vastai show instances --raw` audit.

## Repro (minimal, 2026-05-23)

```
$ vastai destroy instance 12345 --raw </dev/null
Are you sure you want to destroy instance 12345? [y/N]: Aborted.
$ echo $?
0
$ vastai show instance 12345 --raw   # still there, still billing
{"id": 12345, "actual_status": "running", ...}
```

Same shape via the hexa wrapper:

```
$ hexa cloud destroy 12345 </dev/null
[cloud] destroy 12345 → ok
$ echo $?
0
$ vastai show instance 12345 --raw   # still alive
```

## Campaign incidents (demiurge RTSC, 2026-05-23)

The instance ledger accumulated **9 destroy-failed orphans** before we noticed the pattern (4 retry rounds with the same script before adding `-y` upstream of the wrapper). Each orphan was burning ~$0.20-0.40/hr while we believed them gone. Estimated overspend ~$3-5 before the manual audit caught them.

The orphan class only surfaced because the next `vastai show instances` listed them — the destroy log itself gave no signal.

## Root cause

Two coupled causes; either alone is sufficient:

1. **`vastai destroy instance` has no `--yes` / `-y` flag by default in our invocation pattern.** The CLI insists on interactive confirmation. EOF maps to abort + rc=0 — the worst possible combination (looks like success).
2. **hexa-cloud's destroy wrapper does not inspect stdout for the abort marker.** A simple `if stdout contains "Aborted"` post-check would have caught every incident.

## Suggested fix

**(1) Wrapper auto-injects `-y` (or `--yes`) when calling `vastai destroy instance`.**

Match what every other automation does — the CLI's confirmation is for humans typing at a terminal, not for `hexa cloud` dispatch. If the upstream `vastai` binary refuses `-y` on `destroy instance`, fall through to (2). (Current observed: recent `vastai` versions accept `-y` on most subcommands; the destroy subcommand specifically may need version-gated handling.)

```hexa
// stdlib/cloud/cloud_cli.hexa — sketch for vast backend
fn vast_destroy(iid: str) -> Result<unit, str> {
    let out = run(["vastai", "destroy", "instance", iid, "-y", "--raw"])
    if out.rc != 0 { return Err("vastai destroy rc=" + to_string(out.rc) + ": " + out.stderr) }
    // post-verify stdout — never trust rc alone on destroy paths
    if contains(out.stdout, "Aborted") || contains(out.stdout, "aborted") {
        return Err("vastai destroy returned rc=0 but stdout='Aborted' — leak suspected: " + iid)
    }
    if !(contains(out.stdout, "destroying") || contains(out.stdout, "success") || contains(out.stdout, "not found")) {
        return Err("vastai destroy returned rc=0 but stdout has no success/destroying/not-found marker: " + out.stdout)
    }
    return Ok(())
}
```

**(2) Cross-verify with `vastai show instance <iid>` after a short settle.**

Post-destroy, poll once (2-5s settle) — if `show instance` still returns a non-`stopped`/non-`destroyed` status, mark the destroy as failed and propagate to caller. This catches the rare case where `vastai` reports success but the backend ledger lags.

**(3) Surface the abort string in the wrapper's error output.**

If a future `vastai` version changes the abort token, the post-check should at minimum print the *first 200 chars of stdout* on detected failure so callers can pattern-match.

**Recommended combo**: (1) + (3). (2) is belt-and-braces for production runners; optional.

## Cross-link

- Sibling: `inbox/patches/cloud-cli-operational-improvements-anima-2026-05-20.md` P10 (cleaner stderr propagation on non-zero remote exit) — same family of "rc alone is insufficient signal" gaps.
- Sibling: `inbox/patches/hexa-cloud-argv-guard-shell-redirect-falsepos.md` (PR #376) — same campaign (demiurge RTSC 2026-05-23).
- Demiurge governance: `project.tape @D d9` (Vast.ai trouble → hexa-lang inbox upstream) — the rule that motivates filing this rather than patching the orphan-audit script silently.
- Commons `@D g11` (no gap workarounds — fix at source).

## honest C3

- The behavior is technically vendor-side (`vastai` CLI). hexa-cloud is the *integration point* that callers reach through — `hexa cloud destroy` is the right place to defend, because demiurge / anima / wilson never call raw `vastai`.
- No substrate / ladder / parity surface is touched — pure CLI wrapper hygiene. Filing here per commons `@D g11`; demiurge does not edit hexa-lang source.
- machine_id / instance_id used in repro examples are public Vast.ai identifiers (visible to anyone who searches the offer pool). No credential / SSH key / token is included in the repro.
- The 9-orphan count is from a single campaign on a single day; the leak rate per campaign-day is likely higher under heavier parallel-track patterns.
