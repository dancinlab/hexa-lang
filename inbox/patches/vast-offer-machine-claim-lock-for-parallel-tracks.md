# `hexa cloud rent` (Vast.ai backend): per-process claim lock to prevent same-offer / same-machine race-claims across parallel tracks

**Reporter**: demiurge (`dancinlab/demiurge` RTSC DFT campaign, 2026-05-23)
**Severity**: medium — caller-side orchestrator currently self-recovers via retry, but each race burns a rent cycle (~30-60s) and 2 dead instances that need destroy.
**Affected**: `stdlib/cloud/cloud_cli.hexa` (vast-backend rent path), specifically the offer-pick → create-instance window.

## Problem statement

When multiple parallel `hexa cloud rent` calls (sibling tracks of a campaign script) execute concurrently, they share the same offer-search result and can independently pick the same `offer_id` (or two slot-children of the same `machine_id`). Both `create instance` calls succeed at the API level, but the resulting two instances land with `intended_status=stopped` — Vast cannot run two lessees on the conflicting offer/machine slot, so it silently parks one (sometimes both) of them.

The campaign orchestrator currently self-recovers — it detects `intended_status=stopped` after a short settle, destroys the dead instance, re-searches, picks a different offer, retries. But each race costs:

- 1 successful-looking `create instance` API call per loser (sometimes 2, when both lose)
- 30-60s wall-clock on settle + detect + destroy
- 2 destroy calls (and per the sibling patch `vastai-destroy-needs-y-flag-or-silent-abort.md`, those destroys may themselves silently fail without `-y`)

Under heavy parallel-track patterns (campaign with 3-6 sibling rents in flight) the race rate empirically hits **~10-20% per round**.

## Repro (campaign incident, 2026-05-23)

Early in the campaign, two sibling tracks (codenames `h3po` and `cah6`) launched within ~2s of each other. Both picked **offer 30602063** / **machine 54076** as their top candidate from the same `vastai search offers` result. Both `vastai create instance` calls reported success with different instance ids; both instances came up with `intended_status=stopped`. Orchestrator detected, destroyed both (one destroy also silently failed per the destroy-y-flag patch in this batch), and re-searched. Net cost: ~90s + 2 dead instances + 1 orphan leak.

The race is structural — there's no contention-detection signal at the `create instance` boundary, so two parallel callers cannot detect the collision until the post-create status check.

## Root cause

1. **No process-shared claim ledger across sibling `hexa cloud rent` calls.** Two callers running on the same host (same `$USER`) cannot see each other's in-flight offer/machine claims.
2. **Vast.ai's `create instance` API is not race-safe at the per-offer / per-machine-slot level.** Two simultaneous claims for the same offer return success for both; one gets the slot, the other gets parked at `intended_status=stopped`. There's no API-level conflict signal.
3. **No randomization in offer-pick order across siblings.** Each track sees the same sorted list and picks index 0 — guaranteed collision on top-1 if filter results are deterministic.

## Suggested fix

**(1) Process-local + file-backed claim lock — `$HOME/.hexa-cloud/claims.json`.**

```hexa
// stdlib/cloud/cloud_cli.hexa — sketch
struct Claim { offer_id: i64, machine_id: i64, claimed_by: i32 /* pid */, claimed_at: i64 /* unix ms */ }

fn claim_acquire(offers: [Offer]) -> Result<Offer, str> {
    let active = claims_load_active()  // filter out claims older than 5 min
    for o in offers {
        if !contains_claim(active, o.offer_id, o.machine_id) {
            claims_append(o.offer_id, o.machine_id, pid(), now_ms())
            return Ok(o)
        }
    }
    return Err("all offers in current search result are already claimed by sibling rents")
}

fn claim_release(offer_id: i64, machine_id: i64) {
    claims_remove(offer_id, machine_id)
}
```

The claim file is read-modify-write under an advisory file-lock (`flock` on POSIX) so concurrent siblings serialize through it. Stale claims (older than 5 min and pid no longer exists) are GC'd on each load.

**(2) Randomize offer-pick order across processes.**

Even with (1), two siblings that load the same offers list and the claim file simultaneously would race on the `flock`. Adding a small random shuffle (or pid-seeded permutation) over the top-N candidates makes the collision rate near-zero even without (1).

**(3) Post-create detection earlier (within 5-10s) of `intended_status=stopped`.**

The current orchestrator detect+destroy loop has tens-of-seconds-to-minutes latency. Tightening the detection window to ~5s post-create (poll `vastai show instance` immediately, not after the SSH wait) shaves wall-time on every race.

**(4) Upstream ask: Vast.ai API feature request — `create instance` should fail-fast (rc != 0) on machine-slot contention.**

This is the proper fix. The other suggestions are local mitigations. We've filed this in our notes for the next time we contact Vast support; documenting here so the wrapper team sees the dependency.

**Recommended combo**: (1) + (2) + (3). (4) is an external dependency; track but don't block on.

## Impact / cost

- Campaign data: ~10-20% race rate per round under 3-6 parallel rents. With (1) + (2), expected race rate drops to near-zero (sibling processes see each other's claims). With (3), even residual races cost ~5-10s instead of 30-60s.
- Wall-time per campaign step: reduced ~5-10% on average (the race tail dominates the slowest siblings).
- Pod-hour spend: small but non-zero — each dead-on-arrival instance is destroyed within ~60s, but they still count for a minimum billing unit on some Vast plans.

## Cross-link

- Sibling: `inbox/patches/vastai-destroy-needs-y-flag-or-silent-abort.md` (this batch) — destroy-side hygiene; race cleanup is unreliable without it.
- Sibling: `inbox/patches/vast-host-boot-failure-cluster-fast-fail.md` (this batch) — the `intended_status=stopped` detection logic should be shared with the boot-failure detector (same poll path).
- Sibling: `inbox/patches/vast-offer-pool-verified-filter-default.md` (this batch) — when the verified pool is small (~8-12 offers), parallel tracks are *more* likely to race-claim the top-N; this lock is most valuable when (3) of that patch lands.
- Demiurge governance: `project.tape @D d9` (Vast.ai trouble → hexa-lang inbox upstream).
- Commons `@D g11` (no gap workarounds — fix at source).

## honest C3

- The 10-20% race rate is from a single campaign-day with 3-6 parallel tracks. Higher parallelism (anima-class 5+ pods, demiurge-class 4-6 DFT runners) likely shows higher rates; smaller fanout shows lower.
- The file-backed lock (1) works for sibling processes on the same host; cross-host parallel rents (rare for current callers — demiurge dispatches from a single host) would need a Vast-side fix per (4).
- Randomization (2) is the cheapest single mitigation — ~5 LOC change, no shared state, no lock contention. If only one thing lands from this patch, that's the right one.
- No substrate / ladder / parity surface is touched — pure rent-loop concurrency hygiene.
- `offer_id=30602063` / `machine_id=54076` in the repro are public Vast.ai identifiers from the campaign ledger; no credentials / SSH keys / tokens exposed.
