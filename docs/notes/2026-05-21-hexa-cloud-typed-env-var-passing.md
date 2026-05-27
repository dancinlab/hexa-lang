---
title: hexa cloud dispatch — grammar-level safety for remote env/arg passing
status: open
filed: 2026-05-21
filed_by: claude-code-tui (anima project session)
target_ssot: wilson/plugins/pool (cloud dispatcher SSOT)
related: feedback_hexa_resource_local_dispatch (~/.claude memory), POOL.md decisions #91-97
---

# Gap

When dispatching a remote GPU job via shell-string SSH (`$SSH "cd $DIR && ENV=val nohup python3 ..."`),
the env-var and arg-vector live as **unstructured bash string concatenation**. There is no
compile-time check that:

1. The env var literally reached the remote python process.
2. The CLI args were quoted correctly (spaces, special chars).
3. The remote process inherited the env (vs being dropped by intermediate `nohup`/`bash -c` shells).

# Concrete incident (2026-05-21, anima S187 3B grid)

Dispatch script: `HEXAD/UNCLASSIFIED/state/grid_3b_s187_2026_05_21/dispatch_s187_3b_runpod.sh`
attempt 8, line:

```bash
$SSH "cd $S187R && PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True nohup python3 -u train_s187_3b.py ..."
```

Intent: set `PYTORCH_CUDA_ALLOC_CONF` for the python process so PyTorch CUDA allocator uses
expandable segments (defragments memory, halves OOM-via-fragmentation risk).

Reality (verified post-OOM by `grep -l expandable_segments /proc/*/environ` on remote pod): the env
var was **NOT set** on the python process at any point during the run. Either nohup or the SSH
remote shell stripped it. Trainer OOMed and the fix silently never took effect.

This is a class of bug that:
- ✗ no static analyzer catches (bash strings are opaque)
- ✗ no runtime assert catches (bash treats missing env as empty, python sees default behavior)
- ✗ only manifests at OOM-time on remote GPU (expensive to discover — $20+/hr burn while debugging)

# Proposed grammar-level prevention (hexa-native dispatch)

When `wilson pool` (or successor `wilson cloud`) gains remote-job dispatch, the contract should be:

```hexa
let job = CloudJob {
    host: "runpod://h100-80gb",         // provisioner-typed URI
    cwd:  "/workspace/s187r",
    env:  #{                              // typed dict<str, str>, no shell quoting
        "PYTORCH_CUDA_ALLOC_CONF": "expandable_segments:True"
    },
    argv: ["python3", "-u", "train_s187_3b.py",  // typed list<str>, no shell quoting
           "--bsz", "4", "--block", "128", ...],
    verify_env: ["PYTORCH_CUDA_ALLOC_CONF"]      // ★ post-launch assertion
}
cloud_dispatch(job)
```

Where `verify_env` triggers a **mandatory post-launch SSH-side check**:

```
ssh pod 'grep -l <var-name> /proc/$PID/environ' → must return non-empty
```

If the assertion fails, the job is aborted before training-time burn accumulates.

# Why this matters for the lattice

`feedback_active_resource_utilization` says cost-bearing fire is encouraged. But cost-bearing fire
with silent env-passing bugs creates **false positives in saga falsifier** (the fix appears applied,
the OOM appears unfixed, leading to wrong root-cause hypotheses). The mistake compounds: in this
incident, attempts 4-8 all reasoned about activation memory when the env-var fix itself was the
unverified link.

The grammar-level prevention closes this loop at the type-system / verify-step boundary, BEFORE
expensive remote execution.

# Acceptance for `wilson pool dispatch` (or cloud successor)

P1 — type-safe `CloudJob` record (env, argv, cwd as typed fields, not shell strings).
P2 — `verify_env` assertion runs post-launch, blocks training-poll on failure.
P3 — `verify_args` assertion echoes argv into a remote .echo file, compares byte-equal.
P4 — `verify_dtype` / `verify_gpu_mem` assertions (out of scope of this note, but same pattern).

# Honest carve-out

This is a `notes` / RFC-shaped gap. No PR attached. Implementation needs `wilson pool` cloud
provisioning surface (POOL.md decision #92 = opt-in --with pool, not yet bundle-default). A more
formal `rfc_drafts/` entry can follow once the cloud-dispatch SSOT lands in the pool plugin.

# Workaround (until grammar fix lands)

Current saga-level patch: add explicit `echo $PYTORCH_CUDA_ALLOC_CONF` line in the SSH command
before launching python, AND grep the python's `/proc/$PID/environ` after launch — fail-fast if
either is empty. Both are bash-side workarounds and DO NOT replace the grammar fix.
