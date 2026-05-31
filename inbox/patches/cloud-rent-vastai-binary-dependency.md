# patch: hexa cloud — rent step hard-depends on `vastai` CLI binary on PATH

> Source: RTSC campaign re-fire, 2026-05-31, driven entirely from `mini` (the sole
> management host; ghost retired). Per d8: a Vast-discovered `hexa cloud` gap absorbed
> upstream instead of papered over in the campaign.

## Symptom

`hexa cloud dft-run <deck> --detach` (and the underlying `hexa cloud rent vast ...`) dies at
the RENT step on a host where the `vastai` console script is not on `PATH`:

```
[dft-run] ① RENT — searching verified offers...
[dft-run] rent: vastai not found (set VASTAI_DISABLE=1 to silence)
```

This happens **even though** the vast.ai API key is available (`secret get vast.api_key`
returns it) and the `vastai` python package IS pip-installed — the failure is purely that the
build (hexa 0.1.0-dispatch) shells out to a `vastai` **binary on PATH** for the rent/provision
step and does not fall back to anything when the entrypoint isn't resolvable.

Everything else worked from mini with no binary: `hexa cloud list`, `--resume` of alive pods,
`copy-from`, liveness probes. Only NEW-pod provisioning is gated on the binary.

## Root cause

The rent/provision path resolves `vastai` via `PATH` lookup. A pip `--user` install puts the
console script under `~/Library/Python/<ver>/bin` (macOS) / `~/.local/bin` (linux), which is
frequently NOT on PATH, so `which vastai` fails and the rent aborts — despite the package being
importable as a module and the API key being present.

## Requested fix (either, (b) preferred)

(a) **Resolve the entrypoint robustly**: before declaring "vastai not found", fall back to the
    pip console-script location (`python3 -c "import vastai, os, sys; ..."` to locate the
    installed entrypoint) or invoke it as a module (`python3 -m vastai ...`) instead of relying
    solely on a PATH binary.

(b) **Internal vast.ai API rent client** (preferred — removes the binary dependency entirely):
    perform the rent via the vast.ai REST API directly, consuming `secret get vast.api_key`
    (already the documented key source). This is what `list` effectively needs too; unifying on
    an internal client makes `hexa cloud` self-contained on any host that holds the key — exactly
    the "single management host" model the RTSC campaign now runs.

## Workaround applied in-campaign (to be retired when the fix lands)

On mini: symlinked the pip entrypoint onto PATH (`~/.hx/bin/vastai ->
~/Library/Python/3.9/bin/vastai`) + wrote `~/.vast_api_key` (0600) from the keychain. After that
`hexa cloud dft-run --detach` provisions normally. This is a host-local patch, not a durable fix
— hence this note.

## Impact

Blocks re-firing any POD-DOWN candidate from a host without the binary on PATH (hit on YSbH6,
50.35.188.60:39044 GONE). With (a)/(b) landed, `hexa cloud` rents from any key-holding host with
zero per-host setup.

## Resolution (absorbed)

Option **(a) landed** — `stdlib/cloud/vast.hexa` `_vastai_path()` resolver extended to an ordered,
robust chain (the single funnel every vastai invocation passes through, d4):

1. `$VASTAI_BIN` env override (CI / operator-pinned), wins outright;
2. known-good venvs `$HOME/vastenv/bin/vastai` then `$HOME/.vastai-venv/bin/vastai` — py3.13 /
   working OpenSSL, resolved **before** any bare-PATH binary so a system py3.9/LibreSSL `vastai`
   can never win and silently return empty offers (the symptom (2) above — looked like rent
   "worked" yet provisioned nothing);
3. the legacy `$HOME/bin/vastai` (existing behaviour, preserved);
4. `command -v vastai` (bare PATH);
5. `python3 -m vastai` last resort (pip-installed-but-not-on-PATH case, symptom (1)).

The precedence is factored into a pure `_vastai_resolve` and unit-tested by injection in
`stdlib/cloud/vast_vastai_path_test.hexa` (override-wins · venv-before-PATH · python-m fallback ·
not-found → ""). The in-campaign symlink workaround (`~/.hx/bin/vastai → ~/vastenv/bin/vastai`) is
now **unnecessary** — `hexa cloud rent vast` / `dft-run --detach` resolves the venv automatically.

Option **(b)** (internal vast.ai REST rent client consuming `secret get vast.api_key`, removing the
binary dependency entirely) is a **follow-up** — not implemented in this PR. It would unify rent +
list on one internal client; tracked for a later cycle.
