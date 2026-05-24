# `hexa cloud` / runpod — dispatcher bootstrap · wait-after-launch · ssh endpoint surface (anima 2026-05-24 · Phase D 3 items)

**Status**: resolved-PR#646+#699-2026-05-25 — dispatcher bootstrap/wait/ssh-endpoint surface landed; F6 false-success extension also closed

> **Status (open):** 3 reusable orchestration primitives missing from `stdlib/cloud/runpod.hexa` — each hand-rolled per project across the 2026-05-23/24 anima Phase D fire saga (PR #372 + #373). Consolidation removes ~150 LoC duplication per future dispatcher and closes a class of silent races.

**Reporter**: anima (`dancinlab/anima` downstream consumer · HEXAD/PURE Phase D corpus-axis fire)
**Severity**: medium (each item independently workaroundable; cumulative = `sources_upload`-shaped function reinvented per dispatcher + `result_pull race exit 1` + hardcoded `185.216.23.188:38144` ssh endpoints in Monitor wrappers)
**Affected**: `stdlib/cloud/runpod.hexa`, dispatcher source-bootstrap semantics, post-launch polling, Monitor attach ergonomics
**Sibling patches**:
- `runpod-graphql-builtin-for-pure-dispatcher.md` (PR-merged 1eb47746 · 8 dispatcher TODO surface unblock)
- `hexa-cloud-pod-status-diagnose-verbs.md` (commit af558f3e · `cloud list / status / diag / orphans / owner-tag` — covers finding 3+4 below, cross-ref only)
- `cloud-runpod-session-findings-anima-2026-05-23.md` (R1 fixed · R2-R4 open)
- `runpod-r8-r8c-fire-orchestration-gaps-2026-05-24.md` (G1-G4 open · same-day sibling)

Findings from the anima 2026-05-23/24 Phase D fire dispatch saga across PRs #295 / #308 / #366 / #372 / #373 (`dancinlab/anima`). All 5 PRs merged; the gaps below remained as runtime / wiring surface deficits visible only at dispatch-time.

## Context

`dancinlab/anima` HEXAD/PURE Phase D requires GPU dispatch via `HEXAD/PURE/launchers/dispatch_p21h_v3.hexa` (hexa-native dispatcher · `.sh` newly-forbidden per anima `@D hexa_only_authoring`). The dispatcher land sequence:

| PR | what landed | gap surfaced |
|----|-------------|--------------|
| [#295](https://github.com/dancinlab/anima/pull/295) | v0 skeleton 225 LoC · 8 `TODO[runpod|corpus|train|pull]` stubs | (covered by prior `runpod-graphql-builtin-for-pure-dispatcher.md`) |
| [#308](https://github.com/dancinlab/anima/pull/308) | 8 stubs → stdlib import wiring · dry-run gate | none new |
| [#366](https://github.com/dancinlab/anima/pull/366) | 8-factor motivation wiring + R6 mitosis cap | none new |
| [#372](https://github.com/dancinlab/anima/pull/372) | `--corpus-path` arg surface | **finding 1 surfaced** (no source-bootstrap before `train_launch`) |
| [#373](https://github.com/dancinlab/anima/pull/373) | `sources_upload(host, opts, p21hr, dry_run)` workaround | **finding 1 confirmed as systemic** · **finding 2 surfaced** (`result_pull` raced `train_launch`) |

Findings 1+2+5 below were each hand-rolled inside `dispatch_p21h_v3.hexa`. Findings 3+4 are already-filed (cross-ref `hexa-cloud-pod-status-diagnose-verbs.md`).

## Findings

### F1 — dispatcher source-bootstrap missing (`sources_upload`-shaped function)

**Symptom**: `dispatch_p21h_v3.hexa` pre-PR-#373 sequence was `cloud_create_pod_opts → train_launch` — the pod had no project source. `train_launch` invoked `python -m HEXAD.PURE.launchers.train_p21h_v3` against a bare runpod image, immediate `ModuleNotFoundError`. PR #373 added `sources_upload(host, opts, p21hr, dry_run)` to scp N source files + create K target dirs before `train_launch`.

**Root cause**: `stdlib/cloud/runpod.hexa` exposes `cloud_create_pod_opts` (pod creation) and operator-supplied `train_launch` (nohup) but **no bridging primitive for the universal "ship N files / mkdir K dirs / sync env" step**. Every dispatcher reinvents this — anima v3 has its own, BG-* dispatchers have their own bash form, RTSC BEE-NET dispatcher has its own (`hexa-cloud-preflight-stub-and-provisioning-gap-2026-05-24.md` notes the parallel gap on the provisioning side).

**Cost impact**: ~80 LoC of `scp` / `mkdir` / `chmod` boilerplate per dispatcher; silent failures (scp partial, single-file 404, race against pod warm-up) surface only at `train_launch` exit-code-1.

**Suggested builtin**:

```hexa
// stdlib/cloud/runpod.hexa
// Ship a known file/dir manifest to a pod's filesystem before launch.
// Idempotent. Returns 0 on full success, non-zero on partial.
fn cloud_bootstrap_sources(
  host: string,             // ssh host (from cloud_create_pod_opts result)
  opts: map,                // ssh port / key / user (same shape as cloud_run)
  file_list: array[map],    // [{local: "...", remote: "..."}, ...]
  dir_list: array[string],  // remote dirs to mkdir -p before scp
  dry_run: bool
) -> int {
  // 1. mkdir -p each dir_list entry via single batched ssh
  // 2. scp each file_list entry (parallel where stdlib_cli scp supports it)
  // 3. assert all files present via remote stat batch
  // 4. on dry_run: print the would-run scp + mkdir + stat triplet, return 0
}
```

Alternatively, layer it on a higher-level `cloud_dispatch_with_code` per `runpod-r8-r8c-fire-orchestration-gaps-2026-05-24.md` G1 — both gaps share the "make pod's filesystem match operator's intent" theme.

### F2 — `result_pull` races `train_launch` exit (no `wait_until` primitive)

**Symptom**: Dispatcher sequence `cloud_create_pod_opts → sources_upload → train_launch(nohup) → result_pull` — `result_pull` ran immediately after the nohup train_launch returned. `scp <pod>:result.json local/` exits 1 because `result.json` does not exist (train still running). Today's workaround was operator-side Monitor with a hand-rolled `until ssh ... stat result.json; do sleep 60; done` loop outside the dispatcher.

**Root cause**: `stdlib/cloud/runpod.hexa` has `cloud_run` (synchronous) and the operator-pattern `train_launch` (nohup + return) but no async-wait primitive. Every dispatcher that uses nohup has to bolt on its own polling loop, usually shell-side via Monitor.

**Cost impact**: $0 wasted pod-hours per occurrence, but operator wall-time spent reading transient `scp exit 1` errors and discovering "ah, the train is still running" each cycle. Conflated with real `scp` failures (network blip, key mismatch) — operator can't distinguish "wait longer" from "broken endpoint".

**Suggested builtin**:

```hexa
// stdlib/cloud/runpod.hexa
// Poll a remote predicate until true or timeout. Predicate is a small shell
// snippet that exits 0 = ready, non-zero = not-yet. interval/timeout in seconds.
fn cloud_poll_until(
  host: string,
  opts: map,
  predicate: string,        // e.g. "test -s /workspace/result.json"
  interval: int,            // seconds between polls (typical 30-60)
  timeout: int              // seconds before giving up
) -> map {
  // returns #{ready: bool, elapsed: int, last_exit: int, last_stderr: string}
}

// Convenience wrapper: nohup-launch then poll for completion sentinel.
fn cloud_run_with_wait(
  host: string,
  opts: map,
  launch_cmd: string,       // nohup-suitable
  ready_predicate: string,  // e.g. "test -s /workspace/result.json"
  interval: int,
  timeout: int
) -> map {
  // launches via cloud_run --nohup style, then cloud_poll_until.
  // returns predicate result + launch result + total wall.
}
```

Dispatcher can then collapse the train_launch + result_pull pair to:

```hexa
let r = cloud_run_with_wait(host, opts, launch, "test -s /workspace/result.json", 60, 7200)
if r["ready"] { cloud_copy_from(host, opts, "/workspace/result.json", "state/...") }
```

### F5 — `cloud_create_pod_opts` should return `{pod_id, ssh_host, ssh_port}` tuple

**Symptom**: `runpodctl get pod <id>` does NOT print the ssh endpoint (`ip:port`). Today's Monitor wrappers hardcoded `185.216.23.188:38144` after scraping it from the dispatcher's earlier nohup log. Manual transcription · race against pod restart (new port issued) · zero compile-time check.

**Root cause**: `cloud_create_pod_opts` (or its successor) returns a pod id but does not surface the runtime ssh endpoint. The runpod GraphQL `pod(id)` query DOES include `runtime.ports[].publicPort` + `machine.podHostId` — already accessible per `runpod-graphql-builtin-for-pure-dispatcher.md`. The gap is the **return-value shape** at the hexa surface, not the underlying data availability.

**Cost impact**: Operator transcription latency per fire (~30s reading dispatcher log to grep `ssh:` line) · risk of stale endpoint when pod restarts mid-saga · zero static guarantee that the Monitor's ssh target matches the dispatcher's pod.

**Suggested builtin signature change**:

```hexa
// stdlib/cloud/runpod.hexa
// Return shape includes the ssh endpoint ready for Monitor/operator attach.
fn cloud_create_pod_opts(
  // ... existing args ...
) -> map {
  // returns #{
  //   pod_id: string,           // existing
  //   ssh_host: string,         // NEW — e.g. "185.216.23.188"
  //   ssh_port: int,            // NEW — e.g. 38144
  //   ssh_user: string,         // NEW — e.g. "root"
  //   gpu_type: string,         // NEW (parity with hexa-cloud-pod-status-diagnose-verbs.md)
  //   owner_tag: string,        // NEW (parity with finding 4 cross-ref)
  //   created_at: int           // NEW (epoch seconds)
  // }
}
```

Dispatcher + Monitor wrapper can then share a single source of truth for the endpoint:

```hexa
let pod = cloud_create_pod_opts(...)
print(f"ssh -p {pod[\"ssh_port\"]} {pod[\"ssh_user\"]}@{pod[\"ssh_host\"]}")
// ... later in same dispatcher run ...
cloud_run_with_wait(pod["ssh_host"], #{port: pod["ssh_port"], user: pod["ssh_user"]}, ...)
```

### F4 — pod-naming inconsistency between hexa dispatcher and legacy bash dispatcher (cross-ref only)

**Symptom**: hexa dispatcher names pods `p21h-qwen` (no version), legacy bash `dispatch_p21h_v3_runpod.sh` names `p21h-v3-qwen` / `p21h-v3-random`. The 2026-05-24 carryover audit (7 RUNNING pods) relied on this accidental difference to attribute pod ownership.

**Status**: **Cross-reference only** — already covered by `hexa-cloud-pod-status-diagnose-verbs.md` as a required `owner_tag` field on `cloud_create_pod_opts`. F5 above proposes the same field on the return tuple for symmetry. Listing here so the Phase D saga record is complete; no new patch needed.

### F3 — `runpodctl get pod` lacks `createdAt`/`uptime`/`ownerTag`/`costPerHr` (cross-ref only)

**Status**: **Cross-reference only** — fully covered by `hexa-cloud-pod-status-diagnose-verbs.md` (commit af558f3e). Today's 7-RUNNING-pod audit reinforces priority but adds no new surface area. Listing for Phase D saga completeness only.

## Suggested integration (anima-side migration plan)

Once the 3 builtins above land in `stdlib/cloud/runpod.hexa`:

1. `dancinlab/anima` PR — drop `sources_upload(host, opts, p21hr, dry_run)` from `HEXAD/PURE/launchers/dispatch_p21h_v3.hexa` (PR #373's workaround) · replace with `cloud_bootstrap_sources(host, opts, file_list, dir_list, dry_run)`. Net ~-80 LoC dispatcher-side.
2. `dancinlab/anima` PR — replace `train_launch + result_pull` pair with `cloud_run_with_wait(launch, "test -s result.json", 60, 7200)`. Net ~-30 LoC dispatcher-side + removes the race-class entirely.
3. `dancinlab/anima` PR — drop the operator-side hardcoded `185.216.23.188:38144` Monitor wrapper · use `pod = cloud_create_pod_opts(...); cloud_run_with_wait(pod["ssh_host"], #{port: pod["ssh_port"], ...}, ...)`. Net ~-15 LoC per Monitor invocation site.

Estimated downstream impact: ~125 LoC removed from `dispatch_p21h_v3.hexa` + the dispatcher class becomes ~100 LoC end-to-end (vs ~225 today). No new anima TODO surface; the three workarounds vacate cleanly.

## Cross-refs (prior patches)

- `runpod-graphql-builtin-for-pure-dispatcher.md` (commit 1eb47746) — 8 dispatcher TODO surface · GraphQL `pod(id)` shape (F5 depends on this query)
- `hexa-cloud-pod-status-diagnose-verbs.md` (commit af558f3e) — `cloud list / status / diag / orphans / owner-tag` (F3 + F4 fully covered)
- `cloud-runpod-session-findings-anima-2026-05-23.md` (R1 fixed; R2-R4 open) — yesterday's `runpodctl pod list` JSON fallback
- `runpod-r8-r8c-fire-orchestration-gaps-2026-05-24.md` (G1-G4 open) — same-day sibling, G1 (`cloud_dispatch_with_code`) is the natural superset of F1 here (F1 = bare "ship files"; G1 = "ship files + assert HEAD matches expected PR fix")
- `hexa-cloud-preflight-stub-and-provisioning-gap-2026-05-24.md` — parallel provisioning-side gap, same orchestration class

## C3 honesty

- These 3 findings are operational ergonomics, not safety bugs. All 5 anima Phase D dispatcher PRs (#295/#308/#366/#372/#373) merged and Phase D fires dispatched successfully via the per-project workarounds.
- F1 + F2 cost is **operator wall-time only** — no failed fires were attributable to either gap (each surfaced and was worked around within the same dispatcher PR).
- F5 carries a real-but-rare race: if a pod restarts mid-saga (new ssh port issued), the hardcoded Monitor wrapper continues to attach to the dead port until operator notices. Not observed today; theoretically reachable.
- The 3 suggested signatures are sketches — bikeshed welcome. Authority for naming + parameter ordering remains hexa-lang side per `@D a_runpod_inbox`.
- Anima will NOT vendor these patches downstream; this patch is upstream-only filing per inbox rules.
- All cross-referenced PR URLs verified live on `dancinlab/anima` at filing time.
