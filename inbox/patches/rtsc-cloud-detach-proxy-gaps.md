# patch: hexa cloud — proxy-port resolution + detach relax-death (RTSC wave3b)

> Source: RTSC campaign re-fire audit, 2026-05-31, driven entirely from `mini`
> (vastai py3.13 venv · api-key file · vast.ssh_private restored from hex-encoded secret).
> Per d8: a Vast-discovered `hexa cloud` gap absorbed upstream instead of papered over in the campaign.

## Symptom

The whole RTSC wave3b `--detach` batch (10 candidates: ScBeH8 · YBeH8 · LaH10 · YH6 · YH9 ·
CeH9 · LaY_H10 · Y2InH18 · Y2CdH18 · Ca2SnH18) showed `relax FAILED / no 'Begin final
coordinates'` under `--resume`, and each pod was torn down. Local `relax.out` for every
candidate is truncated at SCF **iteration #2** (~71 s of compute), then nothing.

## CONFIRMED (directly observed)

### C1 — `hexa cloud run` proxy endpoint is unreachable from `mini`; direct works
`hexa cloud run <id>` resolves to the vast PROXY (`root@sshN.vast.ai :<ssh_port>`) via
`vast_ssh_config_autoinject` (vast.hexa:1204), which DELIBERATELY prefers the proxy
(line 1210; comment 1200-1203: a stale direct IP "silently times out", so proxy is default).
The `ssh_port` is the REAL vast-assigned port from `vast_ssh_endpoint` (`show instance --raw`,
vast.hexa:854) — NOT a derivation. (The id↔port resemblance I first flagged is coincidence.)

Observation from `mini`: every proxy connect = `Connection refused` (TCP, pre-auth — NOT a
key problem) across ssh2/3/7/8.vast.ai, while `--resume` over the **direct** `host:port` from
`.dft_detach.state` (e.g. `154.59.156.28:58047`) connects fine. So on this network the
proxy-first assumption is INVERTED: proxy refused, direct works.

**Fix (cloud), proposed — NOT a one-line change, must be verified before landing:** add a
proxy→direct FALLBACK in the run/exec path: when the proxy connect returns transport-outage
(ssh exit 255 / connection refused), retry once via `vast_direct_endpoint(iid)` before
declaring the pod unreachable. Do NOT invert the default (proxy-first is intentional for
ghost's network where direct is blocked). Needs a live-pod test on both networks.

### C2 — `--resume` verdict is honest (not a stale-local artifact)
`_dft_resume` (dft_dispatch.hexa:1450-1466) re-`cloud_copy_from`s `/root/deck/relax.out`
(line 1459) AND probes `pw.x` liveness (line 1452) before judging. ScBeH8's probe returned
NOT `__DFT_RUNNING__` (pw.x dead) and the re-pulled relax.out had no final coords → the relax
**genuinely died on the pod**. The teardowns were correct (failed jobs were billing for
nothing). The pod-side `tail -40 relax.out` came back EMPTY at resume time.

## HYPOTHESES (dead pods prevent confirmation)

The relax died ~71 s in, clean cutoff at SCF iter#2, uniform across the batch = **SIGKILL**,
not a graceful QE error and not SIGHUP (the relax cmd is already `setsid`-wrapped,
dft_dispatch.hexa:773 — death-immune to hangup; detach is NOT the cause).

- **H1 — OOM**: superhydride relax at the chosen `ecutwfc`/cell OOM-killed on an under-RAM
  pod. Uniform early death fits a uniformly under-sized pod class.
- **H2 — vast interruption**: cheap interruptible offers paused/reset the container
  (ephemeral fs lost `/root/deck/relax.out` → empty tail), pw.x gone.

## Proposed upstream fixes

### Fix-cloud-1 (C1) — proxy→direct fallback in run/exec  [PROPOSED, needs live test]
When the proxy connect returns transport-outage (ssh 255 / connection refused), retry once via
`vast_direct_endpoint(iid)` before declaring the pod unreachable. Keep proxy-first as default
(intentional, vast.hexa:1200-1203). Verify on both ghost (direct-blocked) and mini
(proxy-blocked) networks before landing — do NOT invert the default.

### Fix-cloud-2 (defensive) — detach stdin  [APPLIED 2026-05-31]
`cloud_nohup_opts` (cloud.hexa:448) emitted `nohup <argv> > log 2>&1 &`; now
`nohup <argv> < /dev/null > log 2>&1 &` so the backgrounded job never blocks/dies on the
closing ssh channel's stdin. Low-risk (`setsid` already covers SIGHUP; `< /dev/null` is the
standard companion). No test pinned the remote string. NOTE: this is NOT the relax-death root
cause (relax cmd is already `setsid`-wrapped); it is hardening only.

### Fix-deck-1 (H1) — preflight OOM gate before paid `--detach`
Enforce `hexa cloud preflight` (mem-budget vs atoms·basis·np) as a HARD gate in the
`--detach` path (d11). Refuse / down-size `np` when the relax won't fit the offer's RAM.

### Fix-deck-2 (H2) — raise the rent reliability floor
The `--detach` rent guard advertises `reliability>0.97` (dft_dispatch.hexa:1052) — verify it
is actually applied to the vast offer query so interruptible offers are excluded.

## Verification plan (before re-firing the 10 + LaBeH8 + novel-batch ×3 + CaAuH3_SOC)
1. Land Fix-cloud-1 → `hexa cloud run <live-id>` connects (no derived port).
2. Re-fire ONE canary (ScBeH8, deck `.validated`) with preflight gate; `--resume` after the
   relax should show `relax DONE` (final coords), not SIGKILL at iter#2.
3. Only then mass re-fire the batch.

## Deck-regen note (not upstream)
8 candidates' decks/state (BaAuH3 · SrPtH3 · YAuH3 · KBeH8 · MgBeH8 · ScH9 + H3S_anchor ·
Li2MgH16 detach-state) are absent on `mini`. `ghost` is retired (2026-05-31) — do NOT sync
from it. If these candidates are to be re-fired, REGENERATE their decks on `mini` via
`/deck` (then `--validate` → `--detach`), rather than recovering ghost's copies.
