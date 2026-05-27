# ☁ stdlib/cloud — "the safe remote runner"

A hexa-lang library for running commands on remote hosts (RunPod, vast.ai,
plain SSH) **without a shell string getting in the way**.

- **What it does**: hands a remote host a structured argument list and runs
  it — every argument stays its own separate word, start to finish.
- **Analogy**: like a drawer organiser with one slot per item. A loose pile
  of words (a shell string) lets things slide into the wrong slot; a slotted
  tray cannot. Each argv element rides in its own slot.

```
   shell string                  structured argv (this module)
   "python3 train.py /* x */"     ["python3","train.py","--steps","2000"]
          |                                |
   remote shell re-parses          each element POSIX-quoted, then ssh
          |                                |
   /* x */  ->  glob explosion 💥    remote shell word-splits it back to
   argparse crash                    exactly the original argv ✓
```

## Why it exists

A command sent over `ssh host '…'` is re-parsed by the **remote** shell.
Unquoted globs, C-style `/* */` comments, and word-splitting silently
corrupt the argument list. `bash -n` is only a *syntax* check — it passes
such strings, and the failure surfaces far away, at remote runtime.

`stdlib/cloud` removes the string entirely: you pass `[str]`, it POSIX-quotes
each element, and the remote shell can only ever split it back into the
exact list you gave. The corruption is not caught — it is unrepresentable.

## API

```hexa
use "stdlib/cloud/cloud"

// run, wait, get exit code + output (stable host — a ~/.ssh/config alias)
let r = cloud_run("gpu-pod-1", ["python3", "-u", "train.py", "--steps", "2000"])
if r.ok == 1 { println(r.stdout_) }

// an ephemeral RunPod / vast.ai pod — non-22 port, changing host key
let r2 = cloud_run_opts("root@154.54.102.51",
    ["-p", "19241", "-o", "StrictHostKeyChecking=no"],
    ["python3", "train.py"])

// background a long job, get the remote pid
let j = cloud_nohup("gpu-pod-1", ["python3", "train.py"], "/workspace/train.log")

// later — is it still alive?
let alive = cloud_poll("gpu-pod-1", j.pid)

// upload / download files (cycle B-1 — scp via structured argv)
cloud_copy_to_opts("root@154.54.102.51",
    ["-p", "19241", "-o", "StrictHostKeyChecking=no"],
    "/local/train.py", "/workspace/train.py")
cloud_copy_from("gpu-pod-1", "/workspace/result.json", "/local/result.json")
```

### RunPod provider (cycle B-2)

```hexa
use "stdlib/cloud/runpod"

let pod = runpod_create_cascade(api_key,
    ["NVIDIA A100-SXM4-80GB", "NVIDIA H100 80GB HBM3"],
    "runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04",
    pubkey, "my-job")
let p = runpod_wait_ssh(api_key, pod.pod_id, 90, 10)   // ~15min budget
let host = "root@" + p.ip
let opts = runpod_pod_opts(p.port)
cloud_run_opts(host, opts, ["python3", "train.py"])
// ... cloud_copy_to / cloud_copy_from / cloud_nohup as needed ...
runpod_terminate(api_key, pod.pod_id)
```

Each `runpod_*` call tries the **runpodctl CLI first** (`pod create` /
`pod get` / `pod delete`) and falls back to the GraphQL API on CLI absence
or failure. Set `RUNPODCTL_DISABLE=1` to force the API path.

Live e2e smoke (`stdlib/cloud/e2e_smoke.hexa`): pod create →
wait_ssh → echo → copy-to → sha-verify → copy-from → terminate.
~38–46 seconds on an A100, ~$0.10. Run with `hexa run` (requires
`secret get runpod.api_key` and `~/.ssh/id_ed25519.pub`).

`CloudResult` fields: `ok`, `exit_code`, `pid`, `stdout_`, `message`.

### Wiring a downstream dispatcher (anima PURE / HEXAD)

This section answers the four integration asks raised by
`archive/patches/runpod-graphql-builtin-for-pure-dispatcher.md`. The verdict
there was that no new builtin was needed — the surface is complete — only a
canonical usage contract plus one small teardown-gating helper.

**1 · import path.** Use `use` (the hexa-lang module keyword), not `import`:

```hexa
use "stdlib/cloud/cloud"     // cloud_run / cloud_nohup / cloud_copy_from ...
use "stdlib/cloud/runpod"    // runpod_create_cascade / wait_ssh / terminate ...
```

A dispatcher copies these two `use` lines verbatim. Module resolution is
relative to `HEXA_LANG` (the hexa-lang checkout root).

**2 · secret integration — pattern (a) is the SSOT.** `runpod_*` keep
`api_key: str` as a first-class argument; the caller reads it. There is
deliberately **no** `runpod_create_from_secret` wrapper — that would
duplicate the key name (`runpod.api_key`) inside stdlib and fork from
sidecar `commons.tape` g8. Read it once at the top of `main` and thread it:

```hexa
let api_key = exec("secret get runpod.api_key 2>/dev/null").trim()
if len(api_key) == 0 { println("FATAL no runpod api key"); exit(1) }
let pubkey  = read_file(env_var("HOME") + "/.ssh/id_ed25519.pub").trim()
let pod = runpod_create_cascade(api_key, ["NVIDIA H100 NVL", "NVIDIA H100 PCIe"],
                                image, pubkey, "p21h-alpha")
```

This is exactly the pattern `e2e_smoke.hexa` uses, so it is already proven
on live silicon.

**3 · checkpoint integrity (`sha256_verify`).** The ckpt-hash check lives
**caller-side** — the dispatcher owns its `sha256_verify(path, expected)`
helper (anima already has it). Recommended placement in the orchestration
flow: verify the **uploaded artifact** right after `cloud_copy_to`
(before `cloud_nohup`/`train_launch` kicks off), and verify the **pulled
result** right after `cloud_copy_from` (before declaring success). stdlib
provides the transport (`cloud_run_opts(host, opts, ["sha256sum", path])`
for the remote digest); it does not impose a hashing policy.

**4 · conditional teardown (`save_pod`).** `runpod_terminate` is
unconditional. For the `pod_terminate(pod_id, save_pod)` shape — where
`save_pod` means *keep the pod alive* — use the gating helper so callsites
stay a single call:

```hexa
// save_pod == "yes"  ->  keep pod, return 1 (no-op success)
let keep = save_pod == "yes"
runpod_terminate_unless(api_key, pod.pod_id, keep)
```

`runpod_terminate_unless(api_key, pod_id, skip)` returns 1 immediately when
`skip` is true (pod left running), else delegates to `runpod_terminate`.

#### Dispatcher stub → stdlib surface map

| dispatcher need              | call this                                   |
|------------------------------|---------------------------------------------|
| `pod_create`                 | `runpod_create_cascade(api_key, gpus, …)`   |
| `pod_ssh_wait`               | `runpod_wait_ssh(api_key, pod_id, tries, s)`|
| `pod_terminate(_, save_pod)` | `runpod_terminate_unless(api_key, id, skip)`|
| `corpus_build_*`             | `cloud_run(host, argv)`                      |
| `train_launch`               | `cloud_nohup(host, argv, logfile)`          |
| `train_progress` (Monitor)   | `cloud tail <host> <log>` (→ exec_replace)  |
| `result_pull`                | `cloud_copy_from(host, remote, local)`      |
| ssh transport / opts         | `cloud_run_opts` + `runpod_pod_opts(port)`  |

`host` is an ssh destination — a `user@host`, or (preferred) a Host alias
from `~/.ssh/config` where the key, port and user live. ssh runs with
`BatchMode=yes`, so it fails fast instead of hanging on an auth prompt.

## CLI

```
hexa run stdlib/cloud/cloud_cli.hexa run       gpu-pod-1 -- python3 train.py
hexa run stdlib/cloud/cloud_cli.hexa run       root@1.2.3.4 --port 19241 --insecure -- python3 train.py
hexa run stdlib/cloud/cloud_cli.hexa copy-to   root@1.2.3.4 ./train.py /workspace/train.py --port 19241 --insecure
hexa run stdlib/cloud/cloud_cli.hexa copy-from root@1.2.3.4 /workspace/result.json ./result.json --port 19241 --insecure
hexa run stdlib/cloud/cloud_cli.hexa poll      gpu-pod-1 12345
hexa cloud tail gpu-pod-1 /workspace/train.log               # live-stream a remote log
hexa cloud tail gpu-pod-1 /workspace/train.log --grep 'step='  # filter to progress lines
```

### `cloud tail` — live remote-log stream (Monitor bridge)

`cloud tail <host> <logfile>` follows a remote log over ssh and forwards each
line to local stdout in real time — the canonical way to wire a remote job's
progress into a harness Monitor (commons `@D g57`, "attach Monitor to the
LOG") with **no polling**:

```
hexa cloud tail   →  ssh host 'tail -F -n +1 LOG | sed -E -un "/until/{p;q}; /grep/p"'
   (exec_replace)        │ replay+follow      │ line-buffered: print, quit on terminal
   inherits stdout  ◄────┘ each line ─────────┘
```

- `--grep <ere>` streams only matching lines (default: all).
- `--until <ere>` prints then **stops** on the first terminal line; the
  default covers a clean finish **and** crash signatures
  (`JOB DONE|Traceback|Killed|CUDA out of memory|…`) so a watch never stays
  silent through a crashloop. `--until ''` follows forever (pair with a
  persistent Monitor).
- The remote consumer is `sed -E -un`, not `awk`: a stock pod's `awk` is
  **mawk**, which block-buffers its stdin behind a following `tail -F` and
  stalls (and `stdbuf` cannot fix it — mawk owns its read buffer); `sed -u`
  is line-buffered. The verb runs via `exec_replace` (execvp) so the process
  inherits stdout and streams with zero buffering.

Pairs with `nohup --early-life-check` — early-life catches a launch that dies
in the first seconds; `tail` watches the whole run after it survives that.

## Compared to the nearest tools

- **vs ShellCheck** — ShellCheck *inspects* a shell string for footguns;
  `stdlib/cloud` makes the string nonexistent, so there is nothing to inspect.
- **vs `ssh host 'cmd'`** — same transport, but the command is a quoted argv
  list instead of a free-form string the remote shell re-parses.

## Scope

Cycle A (this release) — generic SSH structured-dispatch core. Cycle B —
RunPod + vast.ai provider wrappers (pod create / teardown / billing). See
`design.md` for the full decision ledger.
