# `cloud_cli.hexa run` mode EOF-recognition hang on long remote processes

**Severity**: high (blocks all anima cost-bearing fire dispatch via
`hexa cloud run`-and-wait pattern)

**Affected**: `stdlib/cloud/cloud_cli.hexa` (origin/main, merged from
PR #88 cycle B3) — `run` subcommand only. `nohup`/`poll`/`copy-to`/
`copy-from` subcommands not affected (different code paths).

**Reporter**: anima (dancinlab/anima downstream consumer)

**Repro**: 2026-05-20 §184 retry v3 + §182 4-tier — 5 simultaneous
`hexa cloud run` invocations against fresh RunPod pods. After 1.13GB
ckpt SCP + corpus build script SSH dispatch, each `cloud run`
command for the *long* (>1 min wall, ~5+ min for corpus build_
corpus_s101.py) python script **hangs after the remote process
completes**. Symptoms:

- Remote: process exits 0, stdout fully flushed, no zombie
- Local: `hexa run … cloud_cli.hexa run <host> -- <argv>` blocks
  indefinitely with no further output; pgrep shows hexa.real still
  alive consuming ~0% CPU
- Approximate threshold: ~1 minute remote wall (short `mkdir`,
  `ls`, `echo SSH_UP` calls all return immediately — only longer
  processes triggered the hang)

Outcome of this anima cycle:
- All 5 pods (1× §184 Phase 2 retry + 4× §182 t1/t2/t3/t4) hit the
  hang on the `python3 build_corpus_s101.py` step (5-10 min wall on
  the GPU pods)
- Mac-side dispatch script `trap _teardown EXIT` could not fire
  because the wait was blocked, not timed out
- Eventually a zombie `dispatch_s182_runpod.sh` from a prior 7:28 PM
  cycle was force-killed; its kill-cascade tripped the active 5 pods'
  trap, terminating them all
- ~$10-13 sunk in idle billing across the 5 pods during the silent
  hang window

## Suspected cause

`cloud_cli.hexa` `run` subcommand reads remote stdout/stderr until
EOF. SSH multiplexes both streams; the EOF detection appears to
require both streams to close, but on long processes one stream
closes first and the buffered second stream may not be drained
deterministically. The exit code is received via the ssh exit
status, but the read-loop doesn't observe it directly.

Speculation only — not having traced the source yet (anima is
downstream consumer, never edits hexa-lang).

## Workaround (anima carrying)

Replace `cloud run host -- argv` for long processes with:

```
cloud nohup    host logfile -- argv    # backgrounds + returns pid
cloud poll     host pid                # exit 0 if alive, 1 if dead
# then: tail logfile via `cloud run host -- tail -N logfile` (short)
```

This is the pattern recommended in `cloud_cli.hexa` help text already,
but `run` is currently the more ergonomic API for sequential dispatch
scripts. Anima `AGENTS.tape @D g_train_via_hexa_cloud_and_hexa_lang`
records this workaround under `hang_workaround` field 2026-05-20.

## Suggested fix (design only — anima does not edit hexa-lang)

Three orthogonal options:

1. **Per-stream EOF + timeout**: after both stdout and stderr have
   returned EOF, wait up to N seconds for ssh exit status; on timeout
   exit with a documented synthetic code (e.g. 124).
2. **Use ssh exit code as primary signal**: read both streams in
   background, observe ssh's exit (its `Channel close received` /
   exit status), report that as the canonical exit; flush remaining
   buffered bytes synchronously before returning.
3. **Add `--max-wall <sec>` flag to `cloud run`** (and propagate to
   `cloud_run` API) — explicit timeout so callers can bound; on
   expiry emit `exit_code=124 (timeout)` and `message="run wall
   exceeded"`. Lets anima dispatch scripts use `run` for long jobs
   with a known upper bound (e.g. `--max-wall 600` for corpus build).

Option 3 is the *minimum* viable fix from anima's perspective — it
makes `run` predictable for any process. Options 1/2 are the cleaner
root-cause fix.

## anima-side carry until landed

- New fires use `cloud nohup` + `cloud poll` for any remote step
  expected to exceed 60s wall (corpus build, training, eval)
- Short commands (`mkdir`, `sha256sum`, `tail -N`, `test -f`, `echo`)
  continue to use `cloud run` (no hang observed under 60s)
- `AGENTS.tape @D g_train_via_hexa_cloud_and_hexa_lang.hang_workaround`
  carries the policy

## Cross-link (anima side)

- `dancinlab/anima` `AGENTS.tape @D g_train_via_hexa_cloud_and_hexa_lang`
- `dancinlab/anima` `HEXAD/UNCLASSIFIED/state/all_taps_release_s184_2026_05_20/dispatch_s184_phase2_retry_runpod.sh`
  (one of the affected dispatch scripts)
- `dancinlab/anima` `HEXAD/NEUROMORPHIC/state/vspont_scale_ladder_s182_2026_05_20/dispatch_s182_retry_runpod.sh`
  (4-tier orchestrator, 4× simultaneous hang)
- `dancinlab/anima` archive/PHILOSOPHY.tape §verdict_all_taps_release_s184
  (when post-mortem lands)

## honest C3

- This is a downstream-consumer bug report based on operational
  observation; root cause speculation may be wrong, hexa-lang
  maintainer should reproduce + bisect before fixing
- The 5-pod cost burn was also caused in part by zombie dispatchers
  from a prior session being SIGKILL'd while the new fires were
  alive — the cloud_cli hang triggered the trap cascade, not the
  cascade itself
- Workaround (nohup+poll) is *functional today*; this patch
  request is for the cleaner long-form pattern
- anima never edits hexa-lang source — this file lives at
  `~/core/hexa-lang/inbox/patches/` per upstream-downstream invariant
  (anima `g_train_flame_not_pytorch.upstream_downstream_invariant`
  + `g_train_via_hexa_cloud_and_hexa_lang.apply` (4))
