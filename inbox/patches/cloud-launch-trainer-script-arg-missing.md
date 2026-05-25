# `hexa cloud` dispatcher → `launch_trainer_p21h.sh` script-path arg missing (silent orphan)

date: 2026-05-25
severity: HIGH (cost-bearing, silent failure)
affected anima file: `HEXAD/PURE/launchers/dispatch_p21h_v3.hexa` (line 364-365)
affected pod-side script: `HEXAD/UNCLASSIFIED/state/grid_3b_s187_2026_05_21/launch_trainer_p21.sh`

## Symptom

F-CURRICULA-1 fire on pod `c25njysjdga2vb` (1× A100 SXM, $1.49/hr) ran for **158 minutes idle** with zero training activity. `out_main/` empty, no checkpoints, no GPU utilization. Estimated burnt cost: ~$3.92.

## Root cause

`dispatch_p21h_v3.hexa:365`:

```hexa
let argv = ["bash", p21hr + "/launch_trainer_p21h.sh", init_variant, seed]
// → bash launch_trainer_p21h.sh qwen 1337
```

`launch_trainer_p21h.sh` (final line):

```bash
echo "[launch] python3 -u $@"
exec python3 -u "$@"
# → python3 -u qwen 1337
# → python3: can't open file '/root/qwen': [Errno 2] No such file or directory
```

The shell script expects `"$@"` to begin with the python script path (`train_p21h_v3.py`), but the dispatcher only passes `(init_variant, seed)`. The script execs `python3 -u qwen 1337`, immediately exits.

## train.log evidence (line 23)

```
[launch] accelerate=1.13.0
[launch] python3 -u qwen 1337
python3: can't open file '/root/qwen': [Errno 2] No such file or directory
```

(no further entries, no `[P21H]` lines, no kosmos anchors.)

## Why it went undetected

1. `dispatch_p21h_v3.hexa` returns immediately after `cloud_nohup` succeeds (pid returned). The remote process death was not polled.
2. WATCHDOG_SEC=5400 polled for `result.json` existence — it never appeared, so dispatcher logged `RESULT_TIMEOUT after 90 tries` and set `SAVE_POD=1` (per design). But this is indistinguishable from "still training" vs "crashed before step 1".
3. No early-life check (e.g. `[P21H] step=` line must appear within first 5 min) — silent class-1 failure.

## Suggested fix (two options)

### Option A — fix dispatcher (anima-side)
`dispatch_p21h_v3.hexa:365`:
```hexa
let argv = ["bash", p21hr + "/launch_trainer_p21h.sh",
            p21hr + "/train_p21h_v3.py", init_variant, seed]
```

### Option B — harden script (canonical, hexa-lang cloud-side)
Make `launch_trainer_p21.sh` self-aware so callers don't have to remember the path:
```bash
TRAINER_SCRIPT="${TRAINER_SCRIPT:-train_p21h_v3.py}"
echo "[launch] python3 -u $TRAINER_SCRIPT $@"
exec python3 -u "$TRAINER_SCRIPT" "$@"
```

### Option C — add early-life poll to `hexa cloud nohup`
Within first N seconds (e.g. 60s), confirm remote pid still alive (`cloud poll`). Caller can wire `[train_launch_smoke]` step that aborts dispatcher (and tears down pod) if pid died — preventing 158-min idle burn.

## Recommendation

- **Anima**: apply Option A (fastest, anima-local).
- **hexa-lang**: adopt Option C — add an `--early-life-check <sec>` flag to `hexa cloud nohup` that polls the remote pid and fails the dispatch if the process dies within the window. This generalizes across all anima trainers.

## Lesson Index

Belongs in commons / project.tape "cost-bearing fire — silent class-1 failure" notes. Pairs with `feedback_agent_bash_pool_route_runpod_orphan` (different orphan mechanism: ssh routing vs script-path arg).
