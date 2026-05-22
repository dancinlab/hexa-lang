# CLOUD — hexa-lang's cloud-dispatch substrate (domain SSOT)

> Forward-looking roadmap + checklists for `stdlib/cloud` (RunPod · Vast.ai
> · plain SSH). **확정 스펙 ↔ 로그 split:** this file is the *confirmed
> spec* — roadmap, checklists, F-gate definitions; the *append-only cycle
> ledger* (the log) is `CLOUD.log.md`. Domain SSOT per `AGENTS.tape`
> `@D g_plan_consolidation`.

**hexa-lang North-Star ③ (run anywhere)** + **GOAL — "cost-bearing fire
that never silently silently burns OR silently corrupts"** is the umbrella
this file tracks.

---

## 0 · One-paragraph state (2026-05-22)

Cycle A (structured-argv core) + B-1 (`cloud_copy_*` scp) + B-2 (RunPod
GraphQL+CLI cascade) all measured-PASS landed on `origin/main`
(`stdlib/cloud/{cloud,runpod,e2e_smoke}.hexa`, ~38–46s real fire @ ~$0.10
on A100-SXM4-80GB). Anima V3 + demiurge H₃X sessions on 2026-05-22 surfaced
**5 inbox notes** + ~$13/h passive-burn pattern → **cycle C re-design**
opens here. Goal: dispatch becomes a typed gate that **structurally refuses**
to spinup when budget / secret / capability would be wrong, AND every pod
ships with an on-board self-reaper so orchestrator death ≠ idle-billing
death.

---

## 1 · Completed (measured-PASS, landed on origin/main)

### 1a — Cycle A: structured-argv core

- [x] `cloud.hexa` — `CloudResult` struct; `cloud_run` / `cloud_nohup` /
  `cloud_poll` + `*_opts` variants; `cloud_lint_argv`; `_shq`/`_join_argv`/
  marker helpers
- [x] `cloud_cli.hexa` — standalone CLI (`run` / `nohup` / `poll` / `copy-to`
  / `copy-from` / `help` / `version`; `--port` / `--insecure` flags)
- [x] **F-CYCLE-A-SHELL-CORRUPTION-IMPOSSIBLE** — argv elements POSIX-quoted
  per element; `/* */`, `*`, `/tmp/*` all stay literal through 2-shell hops
  (local `/bin/sh -c` + remote SSH shell). 5/5 live smoke PASS against
  `ubu-2` + RunPod pod.

### 1b — Cycle B-1: file transfer

- [x] `cloud_copy_to` / `cloud_copy_to_opts` (scp upload)
- [x] `cloud_copy_from` / `cloud_copy_from_opts` (scp download)
- [x] `_scp_opts` translates ssh's `-p PORT` → scp's `-P PORT`
- [x] **F-CYCLE-B1-ROUNDTRIP-SHA256-EQ** — live byte-identical round-trip
  on `ubu-2` (sha256 local → remote → local).

### 1c — Cycle B-2: RunPod provider

- [x] `runpod.hexa` — `runpod_create` / `runpod_create_cascade` /
  `runpod_get_ssh_port` / `runpod_wait_ssh` / `runpod_pod_opts` /
  `runpod_terminate`
- [x] CLI-first (runpodctl) + GraphQL fallback; `RUNPODCTL_DISABLE=1`
  forces fallback
- [x] **F-CYCLE-B2-E2E-LIVE** — `e2e_smoke.hexa`: pod create → wait_ssh →
  echo → copy-to → remote sha256 → copy-from → terminate. ~38s @ $0.10 on
  A100-SXM4-80GB SECURE cloud, ~46s on CLI path.

---

## 2 · Cycle C — strict dispatch + self-reaper (THIS CYCLE)

Recommendation locked (★★★★★ both axes): **`stdlib/cloud` extension** for
SSOT, **`F-PREFLIGHT-MEM`** for first gate. Composition driven by 5 inbox
notes (anima V3 saga + demiurge H₃X saga) accounting for **$7.39 sunk on
3/3-FAIL fire + ~$50 estimated passive-burn from orphan pods**.

### 2a · Typed `CloudJob` (dispatch-time refusal)

```hexa
let job = CloudJob {
  model:     ModelSpec { n_params, param_dtype, grad_dtype },
  optimizer: OptimizerSpec::PagedAdamW8bit { ... },
  batch:     BatchSpec { bsz, seq_len, n_layer, d_model, n_head, n_kv },
  gpu:       GpuSpec { kind: "H100-80GB", mem_bytes: 80*GB,
                       reserved_overhead: 4*GB },
  env:       #{ "PYTORCH_CUDA_ALLOC_CONF": "expandable_segments:True" },
  argv:      ["python3","-u","train.py", ...],
  verify:    [VerifyEnv, VerifyArgv, VerifyMem],
  deadline:  Duration::hours(2),
  budget_usd: 5.0,
}
cloud_dispatch(job)  // raise BEFORE any spinup
```

`dispatch_validate()` gates (all $0, run pre-spinup, in this order):

1. **mem budget** — closed-form `params + grads + opt_state +
   activations + temps` vs `gpu.mem_bytes * 0.85` → `BudgetExceededError`
   with breakdown + `optimizer_downgrade_path()` suggestion ladder.
2. **secret presence** — `secret_get("<provider>.ssh_private")` non-empty
   bytes; loud error on silent-empty (vast `ssh_priv` typo trap).
3. **auth ping** — provider 1-call cheap query (RunPod
   `myself{clientBalance}` · Vast `vastai show user`); `{"error":{}}`
   3-in-a-row → `AuthError` (cascade short-circuit).
4. **API key shape** — `rpa_…` 51-char + provider-specific prefix lint.
5. **CLI quirk lint** — argv contains `/* */` · `tee >(…)` · bash-3.2
   process-substitution · unescaped glob → reject with hint.
6. **provider capability** — `(min_vcpu, backend)` matrix; e.g. `RunPod
   CPU min_vcpu=32` → reject ("RunPod CPU max=8").

### 2b · Self-reaper (on-pod autokill, orchestrator-independent)

3-bound autokill, executed by **hexa-compiled `cloud_self_reaper` binary**
shipped to the pod at dispatch time:

```hexa
fn cloud_self_reaper(deadline: i64, budget: f64, pid_file: str) {
  loop {
    let now    = clock_now()
    let crash  = !pgrep_alive(pid_file)
    let exceed = elapsed_h() * dph > budget
    if now > deadline || exceed || crash {
      kill_with(pid_file, SIGTERM); sleep(30)         // graceful ckpt
      write_file("/tmp/reaper_verdict.json",
                 emit_json({reason, deadline, budget, ts: now}))
      runpod_terminate(secret_get("runpod.api_key"), self_pod_id())
      return
    }
    sleep(60)
  }
}
```

Outer-layer safety net (orchestrator-side):
- `defer cloud_destroy(pod_id)` on every `cloud_dispatch()` call
- daily `hexa cloud reap` cron (age > deadline → destroy any stragglers)
- `~/core/hexa-lang/.cloud_kill_switch` file — pod also polls; reaper
  self-kills within 30 s of switch flip (`hexa cloud panic` one-liner)

### 2c · Deliverables

- [x] `stdlib/cloud/cloud_budget.hexa` (2026-05-22) — `mem_budget_check()`
  closed-form + optimizer state-size table (SGD·SGDMomentum·AdamW·
  AdamW-AMP-fp16·AdamW8bit·PagedAdamW8bit·Lion·ZeRO-2/3) + activation
  envelope (GQA-aware) + temps envelope + `optimizer_downgrade_path()` +
  `format_budget()` / `format_downgrade_ladder()` pretty-print
- [x] `stdlib/cloud/cloud_job.hexa` (2026-05-22) — `CloudJob` /
  `ModelSpec` / `OptimizerSpec` / `BatchSpec` / `GpuSpec` /
  `DispatchValidation` typed records + 6 gate functions
  (`gate_mem`/`gate_capability`/`gate_cli_quirk`/`gate_api_key_shape`/
  `gate_secret`/`gate_auth`) + `dispatch_validate()` ordered runner
- [x] `stdlib/cloud/cloud_dispatch.hexa` (2026-05-22 · dir-fetch 2026-05-23) —
  `cloud_dispatch_cycle()` full orchestrator-side cycle (validate →
  create_cascade → wait_ssh → bundle copy_to × N → nohup train
  (env-prefixed) → deadline poll loop → remote `kill -9` on deadline →
  **whole-directory** fetch (`cloud_copy_dir_from_opts`, scp -r) →
  remote/local file-count verify → terminate **iff the fetch verified**,
  else RETAIN the pod (`pod_retained=1`) so the artifact is not destroyed);
  `CloudCycle` carries `output_dir_remote`/`output_dir_local`; LLM-free,
  deterministic. See §2f.
- [x] `stdlib/cloud/cloud_cli.hexa` (extended 2026-05-22) — `preflight` verb
  + `--n-params-m`/`--optimizer`/`--gpu`/etc spec flags + extended help
  (`cloud help` · `--help` · `-h` cover cycle A/B-1/B-2/C) +
  `version` bumped to `0.2.0`
- [x] `stdlib/cloud/preflight_smoke.hexa` (2026-05-22) — `F-PREFLIGHT-MEM`
  falsifier: V3 attempt-9 reconstruction (8.92B / AdamW f32 / H100-80GB)
  + PagedAdamW8bit positive control + AdamW8bit positive control +
  RunPod_CPU capability refusal
- [ ] `stdlib/cloud/cloud_reaper.hexa` — `cloud_self_reaper()` compiled-binary
  source; cross-compile target = pod arch (Linux x86_64 default). DEFERRED
  to follow-up — orchestrator-side terminate guarantee already in cycle C
  via `cloud_dispatch_cycle`'s explicit terminate-on-every-path pattern;
  in-pod self-reaper is the orchestrator-death insurance layer.
- [ ] e2e real-fire smoke battery — `F-DEADLINE` + `F-BUDGET-CAP` +
  `F-KILL-SWITCH` (~$0.30 on real RunPod A100)

Syntactic gate: `hexa parse` clean on all 5 deliverable files
(2026-05-22). Run-time gate deferred — see HANDOFF.md.

### 2d · F-gates (cycle C)

- [x] **F-PREFLIGHT-MEM** — V3 attempt 9 OOM scenario reconstructed as
  spec (`n_params=8.92B, AdamW f32, H100-80GB`) → `dispatch_validate()`
  raises `BudgetExceededError` with measured breakdown
  `params 17,840 + grads 17,840 + opt 71,360 + act 364 + temps 8,192 +
  reserved 4,096 = 119,692 MB > cap 69,632 MB (over by 50,060 MB)`.
  Downgrade ladder: AdamW8bit · PagedAdamW8bit both FIT at 66,172 MB
  (3,460 MB headroom); Lion still over 14,380 MB; ZeRO-2 unchanged @
  n_gpu=1. **Run-time PASS 2026-05-22** (`/tmp/preflight_smoke`, 12/12
  checks PASS, exit 0, $0 spent, no LLM). First closure landed.
- [ ] **F-AUTH-FAST** — revoked-key scenario (real RunPod, expired key) →
  `AuthError` within 10 s, cascade does NOT proceed. T1 + T3 from saga
  note `hexa-cloud-runpod-anima-v3-saga-2026-05-22.md` falsified.
- [ ] **F-SECRET-EMPTY** — `secret_get("vast.ssh_priv")` (typo) → loud
  `SecretMissingError`, not silent empty bytes.
- [ ] **F-CAPABILITY-REFUSE** — `(min_vcpu=32, backend=RunPod_CPU)` →
  `CapabilityError` "RunPod CPU max=8" before any rent.
- [ ] **F-DEADLINE** — real fire `deadline=60s` on A100 ($0.025/min × 2 min
  budget ≈ $0.05) → pod self-destroys at `60 ± ε` seconds with
  orchestrator process killed mid-dispatch.
- [ ] **F-BUDGET-CAP** — real fire `budget_usd=0.01` → pod self-kills at
  first cost-check after $0.01 elapsed.
- [ ] **F-KILL-SWITCH** — `hexa cloud panic` with 1 RUNNING pod →
  destroyed within 30 s; subsequent `cloud_dispatch` refused.
- [ ] **F-REAPER-INDEPENDENT** — orchestrator `kill -9`'d mid-fire → pod
  still self-destroys at deadline (provider API list shows pod absent
  within 30 s of deadline).
- [ ] **F-DOWNGRADE-SUGGESTION** — `AdamW` over-budget on H100-80GB →
  ladder emits `[AdamW8bit, PagedAdamW8bit, Lion, ZeRO-2 AdamW]` in order.

Closure ordering: **F-PREFLIGHT-MEM** first ($0, V3 saga direct recovery)
→ **F-AUTH-FAST + F-SECRET-EMPTY + F-CAPABILITY-REFUSE** (cheap, no fire) →
**F-DEADLINE + F-BUDGET-CAP + F-REAPER-INDEPENDENT** (real fire ≈ $0.30
total budget) → **F-KILL-SWITCH + F-DOWNGRADE-SUGGESTION** (cheap).

### 2e · Honest carve-outs

- `mem_budget_check()` activation envelope is ±2× approximate; spec
  requires 15-20% headroom under `gpu.mem_bytes - reserved_overhead`.
  Steady-state OOM only; transient `optimizer.step` peaks (esp. paged-8bit
  CPU paging) are dynamic-allocator concern, orthogonal.
- `n_params` must be **measured** (`sum(p.numel() for p in
  model.parameters())`), not declared. Hexa-native equivalent =
  `model.n_params()` accessor; user-side measurement until then.
- Self-reaper provider API call (`runpod_terminate` from pod) requires
  api-key on the pod — minted as a **scoped credential** with terminate-self
  permission only (NOT main account key). Cycle C implementation milestone:
  scoped-key generation in `runpod.hexa`.

---

## 2f · Directory-fetch closure (2026-05-23)

Motivating incident: an anima V3 Korean run wrote a 5.7 GB `ckpt_best.pt`
next to a small `result.json`; the operator scp'd only the small files and
then terminated the pod — the checkpoint was lost. Two structural causes,
both now closed:

1. **Fetch enumerated files, not the directory.** `cloud_copy_from` is a
   single-file scp with no `-r`, no glob — a checkpoint sitting next to the
   files you *did* list never rides along. Fix: `cloud_copy_dir_from` /
   `cloud_copy_dir_to` (+ `_opts`) in `cloud.hexa` — `scp -r` of the whole
   tree. `_scp_capture` gained a `recursive` flag; scp -r exits non-zero if
   *any* file in the tree fails, so `CloudResult.ok` stays all-or-nothing.
   `cloud_dispatch_cycle` now fetches `output_dir_remote` whole — you name
   the directory, never its contents, so nothing produced can be forgotten.
2. **Terminate was unconditional.** A failed fetch still destroyed the pod.
   Fix: the cycle counts files on the pod (`find -type f`) vs files that
   landed locally; `fetch_ok` requires scp rc 0 **and** count match. On
   `fetch_ok == 0` the cycle sets `pod_retained = 1`, **skips terminate**,
   and surfaces the pod_id + a `copy-dir-from` recovery one-liner. The pod
   keeps billing — deliberately: a retained pod is cheap, a lost 5.7 GB
   checkpoint is not.

CLI: `cloud copy-dir-to` / `cloud copy-dir-from` verbs (version `0.3.0`).

Verification has two levels. **file-count** (default, fast) closes the
*missing-file* class — the one that lost the checkpoint. **sha256-manifest**
(`CloudCycle.verify_sha = 1`) additionally takes a per-file sha256 manifest
of the pod tree and compares it byte-for-byte against the manifest of what
landed locally, so a silently truncated file is caught too. `sha256sum`
(Linux) and `shasum -a 256` (macOS) emit the same `<hash>  <relpath>` line
format, so the pod-side and orchestrator-side manifests compare directly
across platforms — verified $0 on ubu-2 (see F-DIR-ROUNDTRIP-$0).

### F-gates (directory-fetch)

- [x] **F-DIR-ROUNDTRIP-$0** — `cloud copy-dir-from` of a 4-file tree
  (incl. a `sub/` subdir + a 30 MB binary) from pool host `ubu-2`:
  remote 4 files == local 4 files, ckpt sha256 byte-identical, recursion
  into the subdir confirmed. Negative: `copy-dir-from` of a missing remote
  dir → scp rc 1 (drives the retain guard). Cross-platform sha-manifest:
  the Linux-`sha256sum` pod manifest and the macOS-`shasum -a 256` local
  manifest of the same tree were byte-identical. $0, 2026-05-23.
- [x] **F-DIR-FETCH-E2E** — `cycle_smoke.hexa` ran the full
  `cloud_dispatch_cycle` on real RunPod A100 pods: a fake trainer wrote
  `/workspace/out/{result.json, ckpt_best.pt (64 MiB), notes.txt}`; the
  cycle fetched the whole directory, the 64 MiB ckpt landed byte-exact
  (67,108,864 bytes), and the pod was terminated (confirmed absent from
  `runpodctl pod list`). Two fires: count-only (`ytwfylvtdvsg5q`, 52 s)
  and `verify_sha=1` (`l0vjbkaz6urg3z`, 72 s — message `fetch: verified —
  3 files, sha256 manifest byte-identical`). phase=`complete`, ≈ $0.05
  total. 2026-05-23.

---

## 3 · Future cycles (deferred, ★ ranking from brainstorm)

### Cycle D — bundle + emit/log channels (★★★★☆)

Bundle = `{train, monitor, reaper, watchdog, inputs, manifest}` one tarball,
one scp, one sha verify. Structured `emit cloud_event(...)` →
`telemetry/events.ndjson` → 4-channel egress (tail / scp / webhook / S3).
Resolves V3β 4-hour PULL_FAILED blackout. Cycle C reaper depends on bundle
upload primitive — bundle scaffold may land inside cycle C if needed.

### Cycle E — provider abstraction + direct calls (★★☆☆☆ but high leverage)

`trait CloudProvider` (rent/ssh_info/terminate/list/cost). Implementations:
RunPod · Vast · Hetzner · LocalSsh (ubu pool same interface). Direct HTTPS
via `stdlib/http`, runpodctl/vastai CLI dependency removed (vast 3.9
SyntaxError + runpodctl `create pod` vs `pod create` drift gone).

### Cycle F — cloud-lsp · cloud-lint stage (★★★☆☆)

`CloudJob` literal gets red underlines in editor for over-budget / missing
secret / capability-mismatch / argv quirks. Hover = "est. 78.2/80 GB
CRITICAL" + cost forecast. 8-stage strict-lint stage `cloud-event-schema`
new. Quickfix = optimizer downgrade auto-rewrite.

### Cycle G — recovery + multi-pod orchestration (★★★☆☆)

`hexa cloud recover <pod_id>` first-class verb (V3β PULL_FAILED 4h pattern).
`cloud_fleet` typed orchestration (Serial / Parallel{max:N} / Wave{n,gap}).
Shared budget cap + `taken_listings.json` race coordination + cost
dashboard (`hexa cloud cost`).

### Cycle H — provenance / R4 invariant (★★★☆☆)

`CloudResult.gate_type: SimulationOnly | Measurement | Mixed`; cloud
outputs default `SimulationOnly`; type-system blocks downstream
`absorbed=true` promotion from `simulation-only-prediction` upstream tier.
Demiurge / Anima consumers strict-typed.

---

## 4 · Inbox notes index (cycle C source material)

5 markdown notes, all 2026-05-22, all under `inbox/notes/`:

| file | layer | sage |
|---|---|---|
| `2026-05-21-hexa-cloud-typed-env-var-passing.md` | dispatch type-safety | anima S187 env-var silent-drop, 4-cycle wrong-root-cause chase |
| `2026-05-21-hexa-cloud-optimizer-mem-budget-preflight.md` | preflight | anima S187 attempt9→10, optimizer state mis-budget, 8/8 identical OOM |
| `hexa-cloud-runpod-anima-v3-saga-2026-05-22.md` | provider + telemetry | V3 3/3 FAIL ($7.39), T1 auth-empty-error, T2 PULL_FAILED retain saved $5.91 verdict, T5 multi-pod cost burn $13/h |
| `hexa-cloud-vast-runpod-orchestration-troubleshooting-2026-05-22.md` | provider quirks | 9 concrete CLI/auth/SSH timing gotchas, vast CPU-only deny trap, runpod CPU 8-vCPU ceiling |
| `hexa-cloud-vast-usage-recipe-2026-05-22.md` | happy-path recipe | Vast single-GPU-host sequential chain that actually worked, $0.65/13-candidate H₃X screen |

Cycle C ingests the **dispatch + preflight + autokill** subset; cycles
D/E/F/G/H consume the rest.

---

## 5 · Cycle ledger → `CLOUD.log.md`

The append-only, date-keyed cycle ledger lives in **`CLOUD.log.md`** —
split per 확정스펙 ↔ 로그. This file (`CLOUD.md`) is the forward-looking
spec; `CLOUD.log.md` is the log of which cycle landed what, when. Append
new cycle rows to `CLOUD.log.md`, never here.
