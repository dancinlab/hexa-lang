# `hexa cloud` / runpod — anima 2026-05-24 R8/R8c fire orchestration gaps (4 items)

> **Status (open):** 4 separate operational gaps surfaced during the 2026-05-23/24 R8a' + R8c probe saga (~6 H100/A100-SXM pod-hours total, ~$0.50). Each independently workaroundable, but consolidation would materially reduce operator wall-time + cost-burn risk on multi-pod parallel fires.

**Reporter**: anima (`dancinlab/anima` downstream consumer · LORA / V3 substrate domain)
**Severity**: medium (gaps caused 1 LOST fire + 1 invalid wiring measurement + 1 hardware-OOM burnt pod + 1 wall-time 5x estimate miss in a single 24-hour cycle)
**Affected**: `stdlib/cloud/runpod.hexa`, dispatcher-to-pod code-sync semantics, pod hardware-class wall-time predictability, watchdog re-fire logic
**Sibling**: `cloud-runpod-session-findings-anima-2026-05-23.md` (R1 fixed · R2-R4 still open), `cloud-cli-operational-improvements-anima-2026-05-20.md` (P1-P11 open)

Findings from anima R8a' (init_CE wiring re-fire) + R8c (4-cell noise/kv ablation probe) cycle, dispatched between 2026-05-23 18:30 UTC and 2026-05-24 04:00 UTC.

## G1 — dispatcher scp races merge timing → stale-code silent-fail

**Symptom**: R8a' fire dispatched 2026-05-23 18:35 UTC with intent `--n-kv-head 2` (Qwen native match per PR #342 wiring fix). pod train.log shows `[from_qwen] qwen: n_kv_head=2 -> v3_n_kv_head=4` — the fix did NOT apply. R8a' result is INVALID as a wiring test (n_kv=2 measurement), only usable as cluster Z baseline re-confirmation (n_kv=4 environment).

**Root cause**: PR #342 (`train_p21h_v3.py` + `conscious_decoder_v3.py` arg forwarding fix) merged at 2026-05-24 03:15 UTC — **8h 45m AFTER** R8a' fire dispatch (18:30 UTC). dispatcher `scp`-ed the pre-fix files at dispatch time. PR #342 code itself is correct; the silent-fail is a dispatcher-to-pod **code freshness** gap. No warning surfaced to operator that pod received stale tree.

**Cost impact**: $0.20 R8a' pod-hours spent on a measurement that does NOT test the intended hypothesis. Re-fire required (R8a''). The natural-experiment framework (anima `R8A_VS_R8A2_BYTE_EQUAL_NATURAL_EXPERIMENT.md`) detected this only post-hoc via the `[from_qwen]` log line, not via dispatcher pre-flight.

**Suggested patch**:
- `stdlib/cloud/runpod.hexa` `cloud_dispatch_with_code(repo_root, fix_pr_numbers=[])` helper that:
  1. records `git rev-parse HEAD` at dispatch time
  2. for each `fix_pr_numbers` entry, asserts the PR is merged in HEAD via `gh pr view <n> --json mergeCommit` cross-check against `git log <merge_commit>..HEAD`
  3. refuses dispatch (or emits warning) if HEAD is behind expected fix
- alternatively, dispatcher dry-run mode that prints the SSH `scp` rsync source commit hash + warns "this commit predates PR #X" if operator passes `--expect-fix <pr>`

## G2 — wall-time class variance unaccounted (5x estimate miss)

**Symptom**: R8a' fire (5000-step training on A100-SXM4-80GB SECURE) estimated ~90 min wall by operator (extrapolating from Wave saga 1.5B Qwen+LoRA ~30 min wall on similar hardware). Actual wall at step 875/5000 = 5380s (1.5h) → projected full-run **~8.5 hours wall**, 5.7× operator's estimate. Operator was committed-and-blocked for 7+ hours on a single fire.

R8c 4-pod parallel showed similar variance: 3 pods completed in ~100-110s wall (PROBE_STEPS=100), but cell-3 (same hardware class A100-SXM4-80GB, same dispatcher, same step count) took 520s = 5× others. No clear corpus / config difference.

**Root cause hypotheses** (none verified):
- (a) different physical hosts within same `A100-SXM4-80GB SECURE` class have very different real throughput (memory bandwidth, PCIe topology, neighbor-process pressure)
- (b) `runpodctl` does not expose per-host benchmarks; operator cannot pre-select fast vs slow hosts in the class
- (c) PCIe topology + ConsciousDecoderV3 3B (1.5B-base + cell-pool overhead) may hit memory-bandwidth corners that 1.5B-only Wave saga avoided

**Suggested patch**:
- `stdlib/cloud/runpod.hexa` `cloud_preflight_throughput(pod_id, model_size_b, est_token_per_s)` that runs a 30s synthetic-forward benchmark on the pod and refuses to start the real training if measured throughput is < 50% of est (operator-tunable). Returns (predicted_wall, measured_throughput) tuple.
- OR a `runpodctl pod-bench <gpu_class>` aggregated history → expected (p50, p95) wall for `<model_size_b, steps>` workload so operator can size expectations.

## G3 — hardware-side OOM crash on otherwise valid config

**Symptom**: R8c baseline cell (PROBE_STEPS=100, same config as cell-2/3/4) crashed with OOM on pod `r32bfrvphe2i` (A100-SXM4-80GB, same class as the other 3 cells). dispatcher exit code surfaced as a pull-failure, not an OOM signal. Operator re-fired manually after diagnosis (~10 min lost).

The 3 sibling pods on **different physical hosts** (vbytct8r7w9sky / zyu73cpgio3slr / 9delzt6p6du7df) ran the same config successfully. Indicates colocated-process VRAM pressure on `r32bfrvphe2i` rather than config error — pod hardware-pressure is a per-host runtime variable not visible to the dispatcher.

**Root cause**: `cloud_dispatch_*` returns success if the dispatch command exits 0; the train script's CUDA OOM happens later inside the pod, surfaced only via missing `result.json` after the timeout. No structured OOM classification on the dispatcher side. dispatcher waits the full pull-retry budget before declaring fail.

**Suggested patch**:
- `stdlib/cloud/runpod.hexa` `cloud_classify_pod_failure(pod_id)` ssh-greps for `CUDA out of memory` / `torch.cuda.OutOfMemoryError` / `RuntimeError: CUDA error` in `train.log` and returns structured `PodFailure {category, evidence_line, retry_advisable, recommend_different_host}`. Auto-retry on `category=OOM_HARDWARE_PRESSURE` with a different pod-id from the same gpu-class.
- exit-code differentiation: dispatcher returns specific codes for "pod completed but pull failed" vs "pod OOM-crashed mid-train" vs "pod terminated by provider".

## G4 — multi-pod parallel fan-out has no aggregated SSOT progress view

**Symptom**: anima R8c 4-pod parallel fire required operator to construct ad-hoc shell loop to poll 4 separate `result.json` paths + 4 separate `train.log` tails to track per-cell progress. No `hexa cloud` verb exists to print a tabular per-pod status for a fan-out.

When baseline OOM-crashed silently while 3 siblings completed, operator was unaware until a manual `for d in vP21H_r8c_*; do ls ...; done` sweep. The 4 pods are conceptually one experiment (R8c 4-cell ablation) but no single command shows their joint state.

**Root cause**: `cloud_run / cloud_nohup` is per-pod; there's no "fan-out group" concept. The probe driver `probe_r8c_diagnostic.hexa` renders 4 dispatch commands but doesn't tag them with a shared group-id that downstream `cloud_status` could aggregate.

**Suggested patch**:
- `stdlib/cloud/runpod.hexa` `cloud_dispatch_group(group_id, [{name, env, cmd}, ...])` that:
  1. tags each pod's name with `<group_id>/<cell_name>` (visible in `runpodctl pod list`)
  2. writes a group manifest `~/.cache/hexa/cloud/groups/<group_id>.json` with pod_id ⇆ cell_name + dispatch_ts
  3. provides `cloud_group_status <group_id>` printing tabular `| cell | pod_id | status | wall | result_present | init_CE |` — parses each cell's `result.json` if present, falls back to ssh-grep train.log step / CE if not.
- this turns `R8c probe` from "operator polls 4 things in shell" to `hexa cloud group-status r8c-2026-05-24` one-shot.

---

## Per-item priority

| G | severity | wall-time saved per use | cost-burn risk |
|---|---|---|---|
| G1 stale-code race | high | 4-8 hr/fire (1 LOST fire per gap) | $0.20-2.00 per stale fire |
| G2 throughput class variance | medium | 30-60 min/fire estimate calibration | low (operator wall, not pod cost) |
| G3 OOM hardware pressure | medium | 10-30 min/OOM (faster auto-retry) | $0.05-0.10 per OOM pod-hour |
| G4 fan-out group status | medium-high | 5-10 min/fan-out poll cycle | low (operator wall) |

G1 is the highest-priority — silent-fail wiring tests cause invalid science measurements that are very expensive to detect post-hoc.

## Cross-references

- anima `LORA.log.md` (2026-05-24 cycle 13/14 sections) — full saga timeline + per-cell init_CE measurements
- anima `state/grid_3b_s187_2026_05_21/vP21H_r8c_*/result.json` — R8c 4-cell measurement SSOT
- PR #342 (anima) — the wiring fix that G1 silently raced
- PR #366 (anima) — `dispatch_p21h_v3.hexa` hexa-native rewrite (G4 group-id surface could naturally land here)
