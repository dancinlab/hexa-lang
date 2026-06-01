# dft-run: direct-endpoint scp-255 on proxy-only vast offers (re-picks the same broken offer)

**Source:** demiurge RTSC QFORGE-migration-gate campaign, 2026-06-01 (host mini).
**Component:** `stdlib/cloud/dft_dispatch.hexa` — `_dft_go` / `_dft_go_detach` rent→provision→upload path.
**Severity:** campaign-blocking for affected offers; wastes a rent+teardown cycle per attempt; loops on re-fire.

## Symptom

`hexa cloud dft-run <deck> --detach` for Li2MgH16 (38 atoms) repeatedly:

```
① RENT tier-1 (CPU-first): reliability>0.97 cpu_cores_effective>=16 inet_down>=200 dph_total<0.6 cpu_ram>=64
  CPU-first offer cleared — renting it (GPU premium avoided).
picked offer 28919799
created + registered instance 38917013        (then 38917304 on re-fire)
② direct endpoint 116.101.122.173:59162 (identity id_vast_anima)
① reachability OK
upload: scp exit 255
④ teardown: destroying instance 38917013
```

Two consecutive `--detach` invocations picked the **same** offer 28919799, both passed the
reachability probe, both failed `scp` with exit 255, both were torn down. No orphan left
(teardown is clean), but no progress and the loop is deterministic.

## Root cause (hypothesis)

`_dft_go*` always rents with `create --direct` and resolves `vast_direct_endpoint` (bare IP:port).
For this offer the bare-IP endpoint answers the lightweight **reachability probe** but **refuses
`scp`/ssh** (exit 255) — i.e. the offer is effectively **proxy-only** (the direct port is not a real
sshd, or is firewalled for data transfer). The dispatch has no fallback: it neither retries over the
vast **proxy** endpoint (`sshN.vast.ai:PORT`, which `hexa cloud resolve <id>` *does* return for the
same instance) nor records the offer as bad, so a re-fire re-selects it.

## Proposed fix (any one closes it; (a)+(c) preferred)

- **(a) scp proxy-fallback:** if `scp` to the direct endpoint exits non-zero, resolve the proxy
  endpoint (`vast` `ssh-port <id>` → `sshN.vast.ai:PORT`) and retry the upload there before
  declaring failure. The proxy endpoint is already what `cloud resolve` returns post-boot.
- **(b) offer direct-capability filter:** add a rent-guard predicate (e.g. `direct_port_count>=1`
  / verified-direct) so `--direct` only picks offers whose bare-IP port is a real sshd.
- **(c) in-campaign offer blacklist:** after an scp-255 teardown, exclude that `offer_id` from the
  next offer search within the same dispatch/campaign so a re-fire cannot re-pick it.

## Workaround used in-campaign (d_defer)

Li2MgH16 marked DEFERRED (exports/rtsc/DEFERRED.md) with retry recipe = steer `--query` to a
direct-capable / GPU-tier offer that excludes 28919799, pending this patch. Sibling anchor LaH10
is unaffected (its pre-existing pod 38704336 is alive + running phonon DFPT).

## 2026-06-01 update — `--query "direct_port_count>=2"` steer did NOT bypass the offer (CRITICAL)

A third `--detach` attempt with a CHANGED recipe — `hexa cloud dft-run exports/rtsc/decks/Li2MgH16
--detach --query "direct_port_count>=2"` — was fired to force a direct-capable offer and avoid the
broken 28919799. Result (instance 38917745):

```
① RENT tier-1 (CPU-first): reliability>0.97 cpu_cores_effective>=16 inet_down>=200 dph_total<0.6 direct_port_count>=2 cpu_ram>=64
  CPU-first offer cleared — renting it (GPU premium avoided).
picked offer 28919799          ← SAME broken offer, despite direct_port_count>=2
② direct endpoint 116.101.122.173:59431 (identity id_vast_anima)
① reachability OK
upload: scp exit 255           ← SAME scp-255 on a "direct-capable" offer
④ teardown: destroying instance 38917745   (clean, no orphan)
```

Two NEW facts that escalate this beyond proposal (b) alone:

1. **The `--query` user-steer was folded into tier-1 but did NOT exclude 28919799** — the dispatch
   still re-selected the same offer. So (i) `direct_port_count>=2` does not actually gate out this
   offer (its advertised direct ports do not imply a working data-transfer sshd), and/or (ii) the
   `--query` predicate is ANDed into the existing search rather than forcing a different offer when
   the prior pick is known-bad.
2. **scp-255 reproduced on an offer that passed `direct_port_count>=2`** — confirms the direct port
   is advertised but not a usable scp/ssh endpoint. Proposal **(b) (direct-capability filter) is
   insufficient on its own**: `direct_port_count` is not a reliable proxy for "scp works."

**Therefore (a) proxy-fallback + (c) in-campaign offer blacklist are now REQUIRED, not optional.**
Without (c), every re-fire (steered or not) deterministically re-picks 28919799. Without (a), even a
genuinely-direct offer that intermittently refuses scp has no recovery path. This is now a CONFIRMED
class (3 instances: 38917013, 38917304, 38917745 — all scp-255, all torn down clean). Per the
demiurge campaign's "stop auto-retrying a confirmed class on the SAME deck" rule, Li2MgH16 is held
DEFERRED until (a)+(c) land; no further blind re-fires.

## Relation

Adjacent to `cloud-rent-vastai-binary-dependency.md` (same vast rent surface). This one is about
the **direct vs proxy endpoint for data transfer**, not a missing binary.

## ✅ RESOLVED 2026-06-01 — fix (a) + fix (c) LANDED

Both required fixes shipped as two stacked PRs in `stdlib/cloud/dft_dispatch.hexa`:

- **(a) scp proxy-fallback — PR #2451** (`335126fe2`): `_dft_upload` tries the direct endpoint
  first; on a non-zero scp it resolves the vast PROXY endpoint (`vast_ssh_endpoint`) and retries
  the upload ONCE before declaring failure. The winning transport (`host`/`ssh_opts`) is pinned for
  the rest of the remote chain AND recorded in the `--detach` state stamp (`up.ep_host`/`up.ep_port`)
  so `--resume` reconnects via the same endpoint, not the scp-refusing direct IP. Wired into both
  `_dft_go` and `_dft_detach`. Pure classifier `_dft_pick_transport` g5-tested (6 cases).
- **(c) durable offer-blacklist — PR #2453** (`996a8bbdd`): a TTL'd cross-invocation file
  `~/.hx/cloud/offer-blacklist.json`. On a both-endpoints-refused upload teardown the `offer_id` is
  recorded (`_dft_blacklist_add`, 24h TTL); the rent search EXCLUDES blacklisted offers
  (`_dft_search_not_blacklisted`). A re-fire — steered or not — cannot re-pick a known-broken offer.
  Pure helpers (`_dft_blacklist_active`/`_excluded`/`_render`) g5-tested (12 cases).

g5: `hexa run stdlib/cloud/dft_dispatch_test.hexa` → `dft_dispatch_test PASS` (181 cases).

**Campaign verification (2026-06-01):** after install, a fresh
`hexa cloud dft-run exports/rtsc/decks/Li2MgH16 --detach` did NOT re-pick offer 28919799 — it picked
29302413 (host 79.112.108.70, a direct-capable host), uploaded OK, provisioned QE, fetched pseudos,
and LAUNCHED relax detached on pod 38922322 (DETACH OK, no teardown). `--resume` reaches the pod and
reports relax STILL RUNNING. The deterministic loop is broken; Li2MgH16 is now RUNNING toward its
terminal QE λ·Tc. Proposal (b) (direct-port filter) was correctly NOT pursued — (a)+(c) suffice.

Kept (not deleted) per the demiurge campaign reference (d8).
