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
```

## Compared to the nearest tools

- **vs ShellCheck** — ShellCheck *inspects* a shell string for footguns;
  `stdlib/cloud` makes the string nonexistent, so there is nothing to inspect.
- **vs `ssh host 'cmd'`** — same transport, but the command is a quoted argv
  list instead of a free-form string the remote shell re-parses.

## Scope

Cycle A (this release) — generic SSH structured-dispatch core. Cycle B —
RunPod + vast.ai provider wrappers (pod create / teardown / billing). See
`design.md` for the full decision ledger.
