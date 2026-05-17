# patch: retire `qrng` / `qmirror` from the nexus-absorbed verb registry — superseded by stdlib

- **filed**: 2026-05-17
- **area**: `self/main.hexa` — `_absorbed_script()` / `is_absorbed_verb()` dispatch
- **kind**: stale-registry cleanup (latent shadowing bug)
- **severity**: low (no breakage on `main`; misleading on branches lacking the RFC 044/045 dispatch)

## Observation

On a branch that has merged RFC 044 (`stdlib/qrng/`) + RFC 046 (`stdlib/sim_universe/`)
but **not** RFC 045 (`stdlib/quantum/`) — e.g. `rfc043-hexa-torch` as of
2026-05-17 — `hexa qmirror` does not error and does not reach the new
stdlib/quantum dispatcher. Instead it silently routes to the **legacy
nexus-absorbed HW-probe stub** and prints a misleading deterministic verdict:

```json
{"ok":true,"stdout":"{ \"tool\": \"qmirror\", \"mode\": \"fallback-deterministic\",
  \"closure\": { ... 8/8 ... }, \"verdict\": \"8/8 PASS (deterministic stub)\" }",
  "exit_code":0}
```

The operator sees `8/8 PASS` and reasonably assumes the real qmirror substrate
ran — it did not.

## Root cause

`self/main.hexa::_absorbed_script()` still carries the Phase-4 HW-probe entries:

```hexa
// Phase 4 external (19) — HW probes + kick + 16 bridges.
if verb == "qmirror"  { return "compiler/hw_probes/qmirror.hexa" }
if verb == "akida"    { return "compiler/hw_probes/akida.hexa" }
if verb == "qrng"     { return "compiler/hw_probes/qrng.hexa" }
```

These predate the absorption series. After RFC 044 / RFC 045 the real packages
live in stdlib:

| verb | nexus-absorbed (stale) | RFC absorption (current SSOT) |
|---|---|---|
| `qrng` | `compiler/hw_probes/qrng.hexa` | `stdlib/qrng/` (RFC 044) — `else if sub == "qrng"` dispatch |
| `qmirror` | `compiler/hw_probes/qmirror.hexa` | `stdlib/quantum/` (RFC 045) — `else if sub == "qmirror"` dispatch |

The dispatch chain in `main()` is ordered:

```
... atlas ... qrng ... sim-universe ... qmirror ... is_absorbed_verb(sub) ...
```

On `main`, the explicit `else if sub == "qrng"/"qmirror"` branches catch the verb
**before** `is_absorbed_verb` — so `main` is correct today. But:

1. **Latent shadowing** — correctness depends entirely on the explicit dispatch
   staying ordered ahead of `is_absorbed_verb`. Reorder or drop a branch and the
   verb silently falls through to the legacy stub with no diagnostic.
2. **Branch skew** — any branch with a partial absorption merge (RFC 044 but not
   045, etc.) gets the misleading legacy stub instead of an honest
   `unknown subcommand` or the real dispatcher.

## Proposed fix

Remove `qrng` and `qmirror` from `_absorbed_script()`'s Phase-4 HW-probe block.
Keep `akida` (not absorbed into stdlib). After removal:

- **`main`** — unchanged: the explicit `else if sub == "qrng"/"qmirror"` dispatch
  still handles them.
- **a branch without the dispatch branch** — `hexa qmirror` now falls to the
  final `else` → honest `error: unknown subcommand 'qmirror'` + `hexa help`
  hint, instead of a misleading `8/8 PASS` stub.
- removes the latent-shadowing fragility — the absorbed-verb registry no longer
  competes with the stdlib dispatch for the same verb name.

Optionally also retire the now-orphaned stub scripts
`compiler/hw_probes/qrng.hexa` and `compiler/hw_probes/qmirror.hexa`
(superseded by `stdlib/qrng/` and `stdlib/quantum/`) — but that is a separate
cleanup; the registry-entry removal alone fixes the dispatch behavior.

## Verification

- `hexa qrng status` / `hexa qmirror status` on `main` — unchanged (stdlib dispatch).
- On a branch with the qrng dispatch but not qmirror: `hexa qmirror` → honest
  `unknown subcommand` (was: misleading legacy stub).
- `grep -n 'hw_probes/qrng\|hw_probes/qmirror' self/main.hexa` — empty after fix.

## Context

RFC 044 (qrng → `stdlib/qrng/`), RFC 045 (qmirror → `stdlib/quantum/`),
RFC 046 (sim-universe → `stdlib/sim_universe/`) — dancinlab quantum-stack
absorption series, all landed on `main` 2026-05-16. Original repos flipped
private; frozen as `dancinlab/{qrng,qmirror,sim-universe}` GitHub private repos.
This patch closes the loose end where the pre-absorption verb registry still
shadow-claims two of the absorbed verb names.
