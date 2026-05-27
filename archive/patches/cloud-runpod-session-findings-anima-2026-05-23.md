# `hexa cloud` / runpod — anima 2026-05-23 session findings (4 items)

**Status**: CLOSED-2026-05-25 — 4-item anima cycle bundle 전부 처리됨. R1 fixed in main · R2 CLOSED via PR #715 (cloud_idle_autokill_watchdog) · **R3 (`copy-from --resume` = rsync `--partial --append-verify`) + R4 (`run`/`nohup --env K=V` + `--env-file`) CLOSED via cloud CLI ergonomics 번들 (stdlib/cloud, cloud 0.2.2).** `--via-hf` 는 anima-side HF-via-pod 패턴이라 hexa-lang core 범위 밖 — anima가 자체 유지.

> **Status (2026-05-24 sync):**
> - **R1 — CLOSED** by PR #388 (`490b05ab` `feat(stdlib/cloud/runpod): runpod_list_pods — runpodctl 2.x/1.x bridge`). Downstream sees a stable interface independent of runpodctl version.
> - **R2 (auto-terminate-on result.json watchdog) — OPEN**, partially overlapped by:
>   - PR #612 `cloud(diag): pod 상태 진단 verb — cloud list + cloud status` (read-only status surface)
>   - PR #614 `cloud(diag): orphans + owner-tag verb` (orphan detection L2)
>   - PR #615 `cloud(diag): diag verb (nvidia-smi+ps+tail) + HEXA_LANG log` (L3 introspection)
>   - Diag verbs give the watchdog its inputs but the **`result.json`-triggered auto-teardown loop itself is not yet wired**. Sibling patch `hexa cloud guard UX + pod-lock` (PR #646, F5) proposes a tag-based `owner_lock + protected_until` extension to `cloud_create_pod_opts` — orthogonal mechanism (lifecycle-side, not completion-side) but converges on the same operator-time saving.
> - **R3 (`--resume` copy-from) — CLOSED.** `cloud_copy_from_resume_opts` (rsync `--partial --append-verify -e ssh`) + `copy-from --resume` flag in `cloud_cli.hexa`. Same local-side verify (file materialised non-empty) as the scp path. `--via-hf` 는 anima-side HF-via-pod 패턴 — hexa core 미포함.
> - **R4 (`--env K=V` structured env) — CLOSED.** `run`/`nohup --env K=V` (repeatable) + `--env-file <path>` in `cloud_cli.hexa`; each K=V is prepended to `argv` as `env K=V ...` so it stays ONE POSIX-quoted token end-to-end (value-with-spaces survives remote word-split — the original dispatch bug). Verified: `_join_argv(["env","FOO=bar baz",...]) == "'env' 'FOO=bar baz' ..."`.
>
> **Related merged work (not closing R2/R3/R4 directly):** PR #429 (vast.ai backend mirror) · PR #429 retain-on-fail guard · PR #629 dispatcher bootstrap + wait + ssh-endpoint surface · PR #646 cloud-guard UX + pod-lock filing.
>
> Net: **4 of 4 CLOSED** (R1 main · R2 #715 · R3+R4 cloud CLI ergonomics 번들 2026-05-25). `--via-hf` 만 anima-side 로 남김.

**Reporter**: anima (`dancinlab/anima` downstream consumer)
**Severity**: low-medium (each item independently workaroundable; consolidation reduces operator wall-time)
**Affected**: `stdlib/cloud/runpod.hexa`, downstream dispatch ergonomics, pod-lifecycle governance
**Sibling**: `cloud-cli-operational-improvements-anima-2026-05-20.md` (P1-P11 still open)

Findings from a single 2026-05-23 anima cycle (V3 corpus-axis re-fire + AXIS_MAP 7-axis benchmark, ~9 H100/A100-SXM pod-hours total).

## R1 — `runpodctl get pods` deprecated → `runpodctl pod list`

Anima dispatch + recovery scripts still use the old form; new `runpodctl` returns:

```
deprecated: use 'runpodctl <resource> list' or 'runpodctl <resource> get <id>'
```

Old form exits 0 with the deprecation banner on stdout, so scripts that pipe through
`grep RUNNING` silently miss the actual pod list. Net effect: orphan-detection scripts
report 0 alive pods even when 7 are running. Suggested:

- `stdlib/cloud/runpod.hexa` wrap both old and new `runpodctl` syntaxes (try new, fall
  back to old) so downstream sees a stable interface independent of `runpodctl` version.
- OR document the migration in the cloud README + bump anima's downstream patterns.

## R2 — `SAVE_POD=1` retain-on-fail + missed-completion ⇒ silent cost burn

Two of today's pods (Track 1 E2 + E3) were started with `SAVE_POD=1` (retain on fail
for inspection). E3 completed successfully (`result.json` + `ckpt_best.pt` pulled), but
the controlling agent missed the completion event and the pod stayed alive for ~30 min
post-completion — ~$0.75 wasted on A100-SXM at $1.49/hr. Multiply by parallel pods +
missed events = real money.

Suggested: `hexa cloud monitor <host> <pod_id> --auto-terminate-on result.json` —
poll `<remote-out-dir>/result.json` (or a configurable success-marker file); when it
appears AND the local pull + HF upload completes, auto-teardown the pod. This is
P7-adjacent from the sibling patch (orphan-billing watchdog) but the **trigger is
result.json existence**, not GPU-util-low.

## R3 — 6 GB ckpt scp drops mid-transfer (Mac ↔ runpod LAN)

Pulling a 6 GB `ckpt_best.pt` from runpod to Mac via `scp -C` repeatedly dropped at
~5-6 GB (TCP RST / broken pipe class). Recovery: pod → HF direct upload first,
local Mac mirror via independent `ssh cat | tee` later. HF became the authoritative
SSOT, Mac the eventual mirror.

Suggested:
- `hexa cloud copy-from --resume` (rsync with `--partial --append-verify`) so a dropped
  transfer can be resumed without re-sending the prefix.
- OR `hexa cloud copy-from-via-hf <host> <remote-path> <hf-repo>` — pod uploads to HF
  first (S3-backed, resilient), local pulls from HF afterward (HF CLI handles resume +
  sha verify). Pattern proven against 6 GB on this cycle.

## R4 — env-var word-splitting bug in remote-dispatch bash

Anima's fan-out scripts compose remote dispatch as

```
$SSH "cd $POD_DIR && nohup env $AXIS_ENV $CMD ..."
```

Where `$AXIS_ENV` is built locally as a space-separated `K1=v1 K2=v2 K3=v3` string and
shell-interpolated into the SSH'd command. If any value contains spaces (notably file
paths like `P21H_DISTILL_TEACHER='/some path/teacher.pt'`), remote bash word-splits the
value mid-quote → corrupted env on the pod → fire crashes mid-init or runs with wrong
config. Today's symptom: AXIS_MAP variants A/B/F all needed `.envbug_<ts>` rollback +
re-dispatch.

Suggested: `hexa cloud run <host> --env K1=v1 --env K2=v2 ...` (or `--env-file`) — let
the cloud CLI handle quoting once, downstream scripts pass env as structured argv, never
shell-interpolated strings. Mirrors `docker run -e` ergonomics. Anima's `dispatch_*.sh`
scripts would each lose ~30 lines of fragile quoting boilerplate.

## Cost data (informational)

- A100-SXM4-80GB on runpod: **~$1.49 / hr** observed (today's Track 1 E2/E3 pods)
- H100-80GB-HBM3: ~$2-3 / hr (prior cycles)
- Track 1 corpus-axis fire actual: **$3-4** for 2 pods × ~1-2 hr wall (osc early-stop @ step 1125 cut wall ~50%)
- AXIS_MAP 7-axis benchmark in flight: estimated ~$25-40 (7 pods × ~1-2 hr parallel)

## honest C3

- R1 is annoying but workaroundable in a one-liner per script (sed migration)
- R2 + R4 are operator-time saves, not blockers
- R3's HF-via-pod pattern (R3 option 2) is the only one with real evidence — `--resume` is conjectural for hexa cloud
- All 4 are within the scope of the existing `cloud-cli-operational-improvements-anima-2026-05-20.md` patch's spirit; this is a fresh-evidence supplement, not a contradiction
- Anima is now governed by `@D a_runpod_inbox` (project.tape) — every future runpod
  finding gets filed here, not patched anima-side only
