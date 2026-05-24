# `hexa cloud rent` (Vast.ai backend): fast-fail on host-boot failure cluster (CDI / OCI / rate-limit / stuck-boot)

**Reporter**: demiurge (`dancinlab/demiurge` RTSC DFT campaign, 2026-05-23)
**Severity**: high — without fast-fail, every rent retry burns SSH-wait timeout (5-15 min) on a host that was never going to boot. Multiplies caller wall-time and pod-hour spend.
**Affected**: `stdlib/cloud/cloud_cli.hexa` (vast-backend rent / wait path) and the host-status polling loop.

## Problem statement

A sizable fraction (~60-70%) of general Vast.ai offers in our pool **fail to boot the requested image**, even when `vastai create instance` reports success and `actual_status=running` eventually shows. The failure modes cluster into 4 distinct signatures, all surfaced via `vastai show instance <iid> --raw` → `status_msg` field, but **hexa-cloud's current wait loop does not read `status_msg`** — it just polls `actual_status` and waits for SSH-22 reachability. That means each bad host costs the full SSH-wait timeout before the wrapper gives up.

### The four boot-failure signatures

| signature (substring in `status_msg`)                                                                      | what it means                                                                                                  |
|------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| `Error response from daemon: failed to create CDI ...` / `CDI runtime`                                     | Host's NVIDIA Container Toolkit / CDI runtime misconfigured; image can never start. Will never recover.        |
| `Error response from daemon: failed to start container` / `OCI runtime ... exec ... not found`             | Image start failed at the OCI layer (entrypoint missing, mount issue). Will never recover.                     |
| `pull access denied` / `toomanyrequests: You have reached your pull rate limit` (Docker Hub anonymous tier) | Anonymous Docker Hub pulls throttled on a busy host. Will never recover within retry window.                   |
| `actual_status=running` but SSH-22 unreachable for >15 min (no `status_msg` signature)                     | Stuck-boot: kernel up, sshd not started or networking misconfigured. Recovery rare; abandon after fixed cap.   |

## Repro / campaign incidents (demiurge RTSC, 2026-05-23)

From the campaign instance ledger:

- machine **36504**, **53447**, **46742** → `failed to create CDI` (3 separate retry rounds, all CDI-failed before we recognized the pattern).
- multiple machines (id varies) → `toomanyrequests` on `docker pull ubuntu:22.04` — Docker Hub anonymous rate-limit on the host's outbound IP.
- machines with `actual_status=running` + SSH refused for 15+ minutes — abandoned manually after we noticed the asymmetry between status and actual reachability.

Across 8 retry rounds in a single campaign day, **~3-5 distinct hosts per round** failed in one of the above ways. Each retry burned the full SSH-wait window (we were configured to 600s) before falling through.

## Root cause

1. **hexa-cloud's wait loop does not surface `status_msg`** — it polls `actual_status` and probes SSH-22. The status_msg field is the host's own self-report of boot failure, but the wrapper never reads it.
2. **No host-blacklist memory across retries** — a failed `machine_id` is re-eligible on the next `vastai search offers` and gets re-claimed. We hit the same CDI-broken machines twice within one campaign.
3. **No upper bound on stuck-boot waits** — only the configured SSH-wait timeout, which (for forgiving setups) can be 15+ min per attempt.

## Suggested fix

**(1) Parse `status_msg` on every poll tick; abandon on known-fatal substrings.**

```hexa
// stdlib/cloud/cloud_cli.hexa — sketch
let FATAL_STATUS_MSG_SUBSTRINGS = [
    "failed to create CDI",
    "CDI runtime",
    "Error response from daemon: failed to start container",
    "OCI runtime",
    "pull access denied",
    "toomanyrequests",
    "You have reached your pull rate limit",
]

fn vast_wait_boot(iid: str, ssh_cap_s: i32) -> Result<HostInfo, str> {
    let start = now_ms()
    loop {
        let info = vast_show_instance(iid)?
        for substr in FATAL_STATUS_MSG_SUBSTRINGS {
            if contains(info.status_msg, substr) {
                blacklist_add(info.machine_id, substr)  // see (2)
                let _ = vast_destroy(iid)
                return Err("boot-fatal status_msg: " + substr + " (machine=" + info.machine_id + ")")
            }
        }
        // also abandon on persistent intended_status=stopped
        if info.intended_status == "stopped" && elapsed_ms(start) > 60_000 {
            let _ = vast_destroy(iid)
            return Err("intended_status=stopped for >60s — abandoning iid=" + iid)
        }
        // ssh probe + cap
        if info.actual_status == "running" && ssh_probe(info)? { return Ok(info) }
        if elapsed_ms(start) > ssh_cap_s * 1000 {
            let _ = vast_destroy(iid)
            return Err("ssh-22 unreachable after " + to_string(ssh_cap_s) + "s — abandoning iid=" + iid)
        }
        sleep_ms(10_000)
    }
}
```

**(2) Persistent per-session `BAD_MACHINES` set.**

When a host fails any of the fatal-substring checks, record `machine_id` in a process-local (or `$HOME/.hexa-cloud/bad-machines.json`) blacklist that the **next** `vast_search_offers` call filters out. Optional knob: `--ignore-blacklist` to override.

**(3) Hard cap on SSH-wait window — default 480s (8 min).**

The current configurable max is fine, but the *default* should be 480s, not 900s. Stuck-boot recovery beyond 8 min is empirically rare (campaign data: 0/15 stuck-boot hosts recovered after 8 min).

**(4) `actual_status=running` + SSH refused: classify as stuck-boot, abandon at cap.**

The combination is currently silent — the wrapper just keeps probing. Should be a distinct error class (`stuck-boot`) so callers can log it separately from `boot-fatal`.

**Recommended combo**: (1) + (2) + (3). (4) is implicit if (3) is enforced.

## Impact / cost

- Per campaign day with 5-8 retry rounds and ~$0.15-0.30/hr offers: ~$1-2 of wasted pod-hours on hosts we knew were broken within the first 30s of status_msg. The wall-time cost is larger — each bad-host retry ate 5-15 min of campaign progress.
- The blacklist (2) alone removes the duplicate-claim cost. (1) removes the SSH-wait-on-broken-host cost. Combined: estimated 3-4× speedup on the rent loop, and elimination of the "we just rented the same broken machine again" foot-gun.

## Cross-link

- Sibling: `inbox/patches/vast-offer-pool-verified-filter-default.md` (this batch) — the verified-host filter is the **prevention** side; this patch is the **detection + abandon** side. Both compose.
- Sibling: `inbox/patches/vastai-destroy-needs-y-flag-or-silent-abort.md` (this batch) — destroy hygiene is a precondition for clean abandon (otherwise blacklisted hosts leak).
- Sibling: `inbox/patches/cloud-cli-operational-improvements-anima-2026-05-20.md` P7 (orphan-billing detection) — closely related: that one polls GPU util to catch zombies; this one polls status_msg to catch dead-boot.
- Demiurge governance: `project.tape @D d9` (Vast.ai trouble → hexa-lang inbox upstream).
- Commons `@D g11` (no gap workarounds — fix at source).

## honest C3

- The substring list (1) is empirically derived from 1 campaign day. Production form should accumulate over the next 2-3 dispatch cycles — there are likely more failure signatures we haven't hit yet.
- Blacklist (2) is bounded by Vast's offer pool size; eventually we exhaust good machines. For multi-week campaigns the blacklist should TTL (e.g. forget entries older than 7 days — hosts can be repaired).
- No substrate / ladder / parity surface is touched — pure rent-loop hygiene.
- machine_id values used as examples are public Vast.ai identifiers; no credentials / SSH keys / tokens are exposed.
- The 60-70% bad-host fraction is for **unverified general offers**. The sibling verified-filter patch (this batch) cuts that to near-zero — but we still want fast-fail because verified-host quotas are limited and we sometimes fall back to general.
