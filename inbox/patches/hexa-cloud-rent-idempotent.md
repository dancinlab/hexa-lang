# hexa cloud rent — idempotent per (project, purpose) [rent-leak fix]

**Severity:** cost-bearing (orphan H100 pods at 0% util)
**Status:** fixed (this PR)
**Date:** 2026-06-02

## Symptom (observed 2026-05-31)

Dispatched GPU agents repeatedly called `hexa cloud rent` for the SAME
purpose, each call provisioning a NEW billing pod:

- a forge-util-fix agent rented `38977997` → `38978180` → `38979746`
  (3 separate rents, one purpose) — each re-invocation after a Monitor-wait
  death rented another pod;
- a d768-recovery rent stalled and lost its model.

The orphans burned H100 at 0% util. The live M5 registry
(`~/.hx/cloud/active-pods.json`) tracked only a subset, so
`hexa cloud watchdog` could not reap all of them.

## Root cause (file:line)

`stdlib/cloud/cloud_cli.hexa`

- `_cloud_rent_vast` (was line ~956) and `_cloud_rent_runpod` (was
  line ~1078) both go straight from argv-parse → `vast_create` /
  `runpod_create` with **no check** for an existing live pod owning the
  same `(project, purpose=owner)` key. Each call therefore provisions a
  fresh billing instance.

NOTE — registration was already correct: both paths call
`pod_registry_add(... "RENTING")` IMMEDIATELY after `create` succeeds,
*before* the ssh-ready wait (lines ~996 / ~1107), so every successful rent
DOES write an atomic M5 row at the earliest possible point. The leak was
NOT a missing-registration gap — it was that repeated same-purpose rents
each created (and registered) a NEW orphan. So the fix is idempotency, not
registration.

## Fix

### 1. Idempotent dedup helper (`stdlib/cloud/pod_registry.hexa`)

```
fn pod_registry_find_by_purpose(project: str, purpose: str) -> str
```

Returns the id of an existing pod with the SAME `(project, purpose)` whose
status is `RENTING` or `READY`, else `""`. Blank project/purpose disables
dedup (an unattributed rent has no stable key → legacy first-rent path).
`STOPPING`/`GONE` pods are NOT reused (they are on their way out).

### 2. Guard at the top of both rent paths (`stdlib/cloud/cloud_cli.hexa`)

Before any `*_create` call:

```
if _has_flag(av, start, "--force-new") == 0 {
    let existing = pod_registry_find_by_purpose(project, owner)
    if len(existing) > 0 {
        println("[cloud] rent <prov>: reusing existing pod " + existing
            + " for " + project + "/" + owner + " (M5 registry; pass --force-new to override)")
        println("pod_id=" + existing)   // instance_id= for vast
        return 0
    }
}
```

`--force-new` is the escape hatch for a genuinely fresh pod.

### Before / after behavior

| call sequence                                   | before                | after                          |
|-------------------------------------------------|-----------------------|--------------------------------|
| `rent runpod --owner d768-recover` (1st)        | rents pod A           | rents pod A (unchanged)        |
| `rent runpod --owner d768-recover` (2nd, A live)| **rents pod B (leak)**| **reuses pod A** (prints id)   |
| `rent runpod --owner d768-recover --force-new`  | rents pod B           | rents pod B (explicit opt-out) |
| `rent runpod --owner OTHER`                      | rents pod C           | rents pod C (different key)    |
| same key, A is STOPPING                          | rents pod B           | rents pod B (A not reusable)   |

### 3. Watchdog reaper

NOT modified — `stdlib/cloud/watchdog.hexa` already has a COMPOSITE idle
classifier (`_should_autokill_composite`: uptime ≥ threshold AND util ≤ cap
AND no-compute-proc AND no-workdir). That is already stronger than the
"no live process AND util ≤ cap AND age ≥ ttl" sketch in the task; the
root cause was the missing idempotency, now fixed. Kept scope tight.

## Selftest (no provider call, no billing)

`hexa cloud rent --selftest` — exercises the dedup logic against an
in-process M5 registry (snapshots the operator's live file aside, drives
`pod_registry_add` + `pod_registry_find_by_purpose`, restores). Verbatim:

```
PASS 1 empty-registry → first rent provisions (find="")
PASS 2 same-key rent reuses pod 38977997 (no new rent)
PASS 3 different purpose → no false reuse (find="")
PASS 4 READY pod reused (live status)
PASS 5 STOPPING pod NOT reused (find="")
PASS 6 blank project/purpose → dedup disabled (find="")
PASS 7 repeated same-key rent → SAME pod 3/3 (38977997)
rent_selftest PASS — idempotent-rent dedup verified (no provider call)
```
(exit 0; the operator's live `active-pods.json` is snapshot/restored — no
test ids leak into it.)

## hexa parse (verbatim)

```
OK: stdlib/cloud/pod_registry.hexa parses cleanly
OK: stdlib/cloud/cloud_cli.hexa parses cleanly
```

## Covered vs not

- COVERED: both provider chokepoints (vast + runpod), which is the highest
  common point — the dispatcher splits on provider, so there is no single
  pre-split entry to guard. Each provider fn guards identically.
- COVERED: dedup is keyed on `(project, purpose)` where `purpose = owner`
  (the `--owner` flag), matching the existing M5 `purpose` field semantics.
- NOT covered: cross-MACHINE dedup (the M5 registry is per-host
  `~/.hx/cloud/`); a same-purpose rent from a different machine still
  provisions independently. Acceptable — pods are owned per operator host.
- NOT covered: provider-side list cross-check (a pod alive on the provider
  but absent from M5). The M5 registry is the dedup source of truth;
  `cloud reconcile`/`adopt` remain the path to fold an untracked pod in.
