# cloud: unbounded `rent --force-new` auto-re-rent → rotation cap + re-arm gate

- **date:** 2026-06-02
- **surface:** `hexa cloud rent` (dancinlab/hexa-lang · `stdlib/cloud/`)
- **severity:** high (runaway GPU billing leak)
- **PR:** dancinlab/hexa-lang#<TBD> (branch `feat/cloud-rerent-cap`)
- **filed-from:** anima (a_runpod_inbox — upstream fix, not an anima-side workaround)

## incident

A dispatched Lane-G fire driver (host-side detached loop) re-rented a FRESH
vast pod via `hexa cloud rent ... --force-new` **every time its pod died or was
torn down** — with NO retry cap and NO explicit re-arm gate. Each teardown
(user-initiated OR guard-initiated) triggered the next `--force-new` rent,
producing a runaway billing chain:

```
fire2(39046120) → fire3(39052854) → fire4(39059036) → fire5(39059081)
```

Every pod in that chain billed. The live detached loop was killed manually this
session (driver scripts `.DISABLED`, rent shells pkilled, renter confirmed gone),
but the `hexa cloud` surface itself had no guard preventing recurrence.

## root cause

The existing **idempotent-rent** guard (0.5.1) reuses a live `(project,owner)`
pod from the M5 registry on a repeated same-key rent — but `--force-new` is the
explicit opt-out of that dedup. The runaway loop passed `--force-new` on every
re-rent, so the idempotent guard never fired. There was **no second bound** on
`--force-new` itself: a driver could re-rent unboundedly, each time provisioning
a fresh billing pod.

## fix (upstream — cloud CLI core)

A second backstop that bounds `--force-new` per `(project,owner)`:

- **`stdlib/cloud/pod_registry.hexa`** — re-rent rotation-cap module:
  - append-only ledger `~/.hx/cloud/rerent-log.jsonl`, one JSONL line per
    force-new event `{"project","owner","ts"}`.
  - `pod_registry_rerent_guard(project, owner)` — the single gate: returns 1
    (ALLOWED, records the event) while the in-window count `< cap`; returns 0
    (REFUSED, does NOT record — window never slides forever) once `>= cap`.
  - `pod_registry_rerent_rearm(project, owner)` — explicit re-arm: purges the
    window so a human who genuinely wants to continue can.
  - cap default **3** (`HEXA_CLOUD_RERENT_CAP`), window default **3600s**
    (`HEXA_CLOUD_RERENT_WINDOW_SEC`). Blank key → guard inert (legacy path).
- **`stdlib/cloud/cloud_cli.hexa`** — wired the guard into BOTH the vast and
  runpod `--force-new` branches. On the `(cap+1)`-th rent the verb prints
  `auto-re-rent cap reached (N) — re-arm explicitly to continue` and returns
  `rc=3` **without renting**. `--rearm` purges the window first.
  version `0.5.1 → 0.5.2`.
- **`stdlib/cloud/cloud_commands.hexa`** — `rent` usage + summary note the cap
  and `--rearm`.

### detection backstop (@L3)

The cap is per-`(project,owner)`: if the SAME key re-rents with `--force-new`
more than N times inside the window, the dispatcher REFUSES further force-new
rents and warns. A DIFFERENT `(project,owner)` has its own fresh budget.

## boundary note (honest)

The runaway loop lived in a **host-side driver script** (now `.DISABLED`), not in
`hexa cloud` itself — `cloud rent` only ever did one rent per invocation. The
fix is placed at the **most upstream point that prevents recurrence**: the
`cloud rent --force-new` verb now refuses rapid repeated force-new rents for the
same owner, so ANY driver (this one or a future one) that re-rents on pod-death
is bounded at the CLI core. No driver-side lock-in.

## selftest (g5 — `stdlib/cloud/rerent_cap_test.hexa`)

```
--- (i) re-rent loop: fire re-rents on every pod-death ---
    rent #1 → ALLOWED (force-new ok, under cap 3)
    rent #2 → ALLOWED (force-new ok, under cap 3)
    rent #3 → ALLOWED (force-new ok, under cap 3)
    rent #4 → REFUSED (auto-re-rent cap reached 3 — re-arm explicitly to continue)
    rent #5 → REFUSED again (loop stays stopped — no runaway)
--- (ii) explicit re-arm allows continuation ---
    re-arm → purged 3 events; next force-new → ALLOWED
--- (iii) backstop: same-key rapid force-new refused, other key unaffected ---
    same (anima,laneg-devfeed) (cap+1)-th rapid force-new → REFUSED
    different (demiurge,qforge) force-new → ALLOWED (per-key budget)
rerent_cap_test PASS
```

Regression: `rent_idempotent_test PASS`, `cloud rent --selftest` PASS (dedup
happy-path intact), `cloud_help_drift_test PASS` (35 verbs in sync).
