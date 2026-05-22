# CLOUD — cycle ledger (append-only log)

> The append-only, date-keyed cycle log for `stdlib/cloud`, split out of
> `CLOUD.md` per 확정스펙 ↔ 로그. `CLOUD.md` is the forward-looking spec —
> roadmap, checklists, F-gate definitions; this file is the chronological
> record of which cycle landed what, when.
>
> **Append new cycle rows at the bottom. Never rewrite rows above** — this
> is a log, not a document.

| date | cycle | commit/PR | gate(s) closed | notes |
|---|---|---|---|---|
| 2026-05-19 | A | landed `origin/main` | F-CYCLE-A-SHELL-CORRUPTION-IMPOSSIBLE | 5/5 live smoke PASS |
| 2026-05-19 | B-1 | landed `origin/main` | F-CYCLE-B1-ROUNDTRIP-SHA256-EQ | scp byte-eq round-trip |
| 2026-05-19 | B-2 | landed `origin/main` | F-CYCLE-B2-E2E-LIVE | A100 ~$0.10 e2e_smoke |
| 2026-05-22 | C | (this cycle) | **F-PREFLIGHT-MEM ✓** | 5 files landed (cloud_budget · cloud_job · cloud_dispatch · cloud_cli(preflight) · preflight_smoke). `hexa build && /tmp/preflight_smoke` 12/12 PASS, exit 0. V3 attempt-9 reconstruction: 119,692 MB > 69,632 MB cap, ladder finds PagedAdamW8bit FITS @ 66,172 MB. $0 spent, LLM zero. |
| 2026-05-23 | C·dir-fetch | `ed39c463` (branch `cloud-dir-fetch-2026-05-23`) | **F-DIR-ROUNDTRIP-$0 ✓ · F-DIR-FETCH-E2E ✓** | `cloud_copy_dir_{from,to}` (scp -r) in cloud.hexa; `cloud_dispatch_cycle` fetches the whole `output_dir_remote`, verifies file-count + optional `verify_sha` sha256-manifest, RETAINS the pod on fetch-fail instead of terminating (`pod_retained`). `copy-dir-{to,from}` CLI verbs (v0.3.0, deployed to `~/.hx/bin/hexa-cloud`). New `cycle_smoke.hexa`. ubu-2 $0 round-trip (4 files + subdir + cross-platform sha-eq) + 2 paid RunPod A100 e2e fires (`ytwfylvtdvsg5q` count-only, `l0vjbkaz6urg3z` verify_sha=1; 64 MiB ckpt byte-exact, both terminated, ≈ $0.05). Closes the V3 5.7 GB checkpoint-loss class. |
