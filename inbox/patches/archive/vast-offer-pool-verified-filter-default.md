# `hexa cloud rent` (Vast.ai backend): default to verified-host filter + corrects prior recipe advice

**Reporter**: demiurge (`dancinlab/demiurge` RTSC DFT campaign, 2026-05-23)
**Severity**: medium (caller-side workaround exists — pass explicit filters; but the default is misleading and prior recipe advice was outright wrong).
**Status**: SHIPPED (suggested-fix (1)+(2)) — `stdlib/cloud/vast.hexa::vast_search_offers(query, verified_only)` prepends the campaign-proven defaults `rentable=true verified=true reliability2>=0.95` when `verified_only==1` (the `hexa cloud rent` default) and always passes `-n` to raise the result cap; `verified_only==0` is the `--broaden` escape hatch that searches the general/unverified pool. Defaults come first so a caller token can override (vastai last-wins). Query-build logic unit-tested (verified-only prepends defaults + keeps the user token; broaden drops them — PASS). Doc-side correction (3) of `hexa-cloud-vast-usage-recipe-2026-05-22.md` is deferred to that recipe's owner. Live offer-pool measurement is downstream (needs creds).
**Affected**: `stdlib/cloud/cloud_cli.hexa` (vast-backend offer-search defaults), and the sibling recipe `inbox/patches/hexa-cloud-vast-usage-recipe-2026-05-22.md`.

## Problem statement

The default `vastai search offers` query (no explicit filters) returns a small, noisy slice of the catalog (often 1-3 offers) and the `verified` field's effect on the result set is ambiguous. To actually surface the **~8-12 verified-datacenter offers** that match a real GPU/CPU spec, the caller must pass:

```
vastai search offers 'num_gpus>=1 cpu_cores>=16 rentable=true verified=true' -n
```

— note both the explicit `verified=true` predicate **and** the `-n` flag (which raises the result cap; without `-n` the default cap silently truncates to a handful of entries).

The campaign empirically observed that **switching to verified-only hosts dropped the boot-failure rate from ~60-70% (see sibling patch `vast-host-boot-failure-cluster-fast-fail.md`) to effectively 0%**. Verified-datacenter hosts have correctly-configured CDI / NVIDIA Container Toolkit / outbound networking, and don't hit Docker Hub anonymous rate-limits the same way.

### Recipe correction

The previously-filed `inbox/patches/hexa-cloud-vast-usage-recipe-2026-05-22.md` recommends *not* filtering by `verified=true` (the stated reason was "narrows the pool too aggressively"). The campaign data contradicts that advice — the verified pool is large enough for our workloads and the reliability gain is decisive. **This patch supersedes that advice in `hexa-cloud-vast-usage-recipe-2026-05-22.md`.**

## Repro (minimal, 2026-05-23)

```
# Default — small noisy result, mixed quality:
$ vastai search offers 'num_gpus>=1 cpu_cores>=16 rentable=true' --raw | jq 'length'
3   # (varies; sometimes 1-2)

# Same predicate + verified + -n:
$ vastai search offers 'num_gpus>=1 cpu_cores>=16 rentable=true verified=true' -n --raw | jq 'length'
~8-12

# Boot success rate, campaign data:
#   unverified general pool : ~30-40% success per rent attempt
#   verified pool           : ~100% success per rent attempt (3 campaign rounds, 0 boot failures)
```

## Root cause

Two layered defaults bite together:

1. **`vastai search offers` without explicit predicates** returns a near-random small sample; the result is not a useful baseline.
2. **The `-n` flag's omission silently caps the result count**, hiding most of the catalog even when predicates are present.

Neither default is documented in a place callers reach via `hexa cloud --help` today — both are vendor-CLI defaults that the wrapper inherits unchanged.

## Suggested fix

**(1) `hexa cloud rent` defaults its offer-search to `verified=true rentable=true` + `reliability2>=0.95` + `-n` flag.**

```hexa
// stdlib/cloud/cloud_cli.hexa — sketch
let DEFAULT_OFFER_FILTERS = [
    "rentable=true",
    "verified=true",
    "reliability2>=0.95",
]
let DEFAULT_GPU_CAP = "num_gpus<=2"  // demiurge default; broadenable

fn vast_search_offers(user_filters: [str], opts: SearchOpts) -> [Offer] {
    let effective = if opts.broaden { user_filters }
                    else { concat(DEFAULT_OFFER_FILTERS, user_filters) }
    run(["vastai", "search", "offers", join(" ", effective), "-n", "--raw"])
        |> parse_json
}
```

**(2) `--broaden` (or `--unverified-ok`) flag to bypass the verified-default.**

The escape hatch for callers who *do* want the general pool — useful for cost-sensitive batch jobs that can tolerate higher failure rates, and for falling back when verified inventory is exhausted.

**(3) Correct the sibling recipe `hexa-cloud-vast-usage-recipe-2026-05-22.md`.**

Strike the "verified=true 필터 쓰지말것" line and replace with "default to `verified=true rentable=true reliability2>=0.95`; pass `--broaden` to fall back to the general pool only when verified inventory is exhausted". Optionally also add a "always pass `-n`" note.

**Recommended combo**: (1) + (2) + (3). (3) is doc-only and cheap.

## Impact / cost

- Verified-pool boot success ~100% vs general-pool ~30-40% (campaign 1-day sample). Translates to ~3× fewer rent retries on average, ~2-3× less pod-hour spend per successful boot, and much shorter wall-time per campaign step.
- Cost concern: verified hosts charge a modest premium (~10-25% on offer rates we sampled), but the rent-retry savings dwarf that premium.
- Inventory concern: verified pool is smaller (~8-12 matching offers on our spec vs ~30-50 in the general pool). Heavy-parallel campaigns (5+ tracks) may exhaust verified inventory; `--broaden` covers that case explicitly.

## Cross-link

- Sibling: `inbox/patches/vast-host-boot-failure-cluster-fast-fail.md` (this batch) — the detection-and-abandon side; this patch is the prevention side. Both should land together.
- Sibling: `inbox/patches/hexa-cloud-vast-usage-recipe-2026-05-22.md` — this patch **corrects** that recipe's "skip verified filter" advice.
- Sibling: `inbox/patches/vast-offer-machine-claim-lock-for-parallel-tracks.md` (this batch) — exhausted verified inventory + parallel tracks make the race-claim problem more likely; that patch is the lock-side fix.
- Demiurge governance: `project.tape @D d9` (Vast.ai trouble → hexa-lang inbox upstream).
- Commons `@D g11` (no gap workarounds — fix at source).

## honest C3

- The ~100% verified-pool boot success rate is from 3 campaign rounds on a single day; production form should re-measure over a longer horizon (verified hosts can also rot — a smaller failure rate is expected long-term, not literal zero).
- `reliability2>=0.95` is the demiurge campaign default; other downstream consumers may want a different threshold. (1) should make the threshold a manifest knob, not a hard-coded constant.
- Recipe correction (3) is the doc-side companion; without it, the next caller will read the stale advice and skip the verified filter again — same gap re-opens.
- No substrate / ladder / parity surface is touched — pure offer-search default tuning.
- No credentials / SSH keys / tokens appear in this patch; Vast.ai offer pool is a public catalog.
