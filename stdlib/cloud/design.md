# stdlib/cloud — design decision ledger

Structured-argv remote dispatch for hexa-lang. A remote command is always a
structured argv list (`[str]`), never a shell command string — so the bug
class where a shell re-parses a command (glob expansion, C-style `/* */`
comment mis-parse, word-splitting) cannot be represented.

Origin: the `dispatch_s126_runpod.sh` L145 incident — a C-style
`/* PCN has no negative samples */` line, intended as a comment, was
glob-expanded by the remote shell (`/*` → `/bin /boot /etc …`, `*/` → cwd
dirs) into the trainer's argv, crashing argparse. `bash -n` passed it
because the string was syntactically valid. The fix is not to lint the
string better — it is to never build the string.

---

### Decision 1 — approach C (structured argv, eliminate the shell-string class)
**picked**: Remote commands are passed as `[str]` argv lists. Each element is
POSIX single-quoted before being handed to ssh.
**rationale**:
- A shell command string is re-parsed by whichever shell receives it; a
  structured argv has no parse step to corrupt.
- Considered (A) lint `.sh` strings and (B) move dispatch to hexa but keep
  string commands — both still leave a corruptible string. C removes it.
- Aligns with hexa-lang principle #1 (ai-native: structured over prose) —
  argv arrays are unambiguous to machines, the way `subprocess.run([...])`
  avoids `shell=True`.

### Decision 2 — scope A→B (phased)
**picked**: Cycle A = generic SSH structured-dispatch core. Cycle B = RunPod
+ vast.ai provider wrappers (pod create / teardown / billing).
**rationale**:
- RunPod and vast.ai both ultimately dispatch over SSH — one SSH core covers
  both, and B's wrappers sit on top of it.
- The incident is a "command corrupts" bug, not a "cannot start a pod" bug;
  A targets exactly the pain, B is a separate bug class.
- Minimum-surgical first (karpathy simplicity) — provider APIs are added
  when actually needed, no speculative code.

### Decision 3 — module name `stdlib/cloud`
**picked**: `stdlib/cloud/`.
**rationale**:
- Covers RunPod, vast.ai and plain SSH under one neutral name.
- Lowercase, matches the existing stdlib convention (`qrng`, `flame`).
- hexa-lang owns all stdlib (AGENTS.tape `g_stdlib_ownership`); downstream
  repos (anima, wilson) point at it, never copy it.

### Decision 4 — escape-hatch lint is library-level, not a compiler strict-lint stage
**picked**: `cloud_lint_argv()` plus a reject-in-`cloud_run` guard. The 8
compiler strict-lint stages are NOT touched in cycle A.
**rationale**:
- A new mandatory strict-lint stage means editing the compiler orchestrator
  + diag catalog (`compiler/check/`, `compiler/diag/`) — invasive, and out of
  scope for a "minimal core" cycle.
- With every argv element quoted, a `/* */` element is already harmless to
  the shell; the lint's job is to flag it as a probable authoring mistake,
  which a library function does fine.
- A compiler-integrated audit (walk the AST for `exec("…")` literals) stays
  on the table as a later cycle, decoupled from this module.

### Decision 5 — `hexa cloud` self/main.hexa wiring deferred
**picked**: Cycle A ships `cloud_cli.hexa` as a standalone CLI
(`hexa run stdlib/cloud/cloud_cli.hexa …`). The `else if sub == "cloud"`
branch in `self/main.hexa` is a later deploy-adjacent step.
**rationale**:
- `self/main.hexa` is the highest-conflict file in the repo (100+ active
  worktrees); an additive branch there belongs in a deploy step, not here.
- The `hexa cloud` branch shells out to a compiled `bin/hexa-cloud` binary,
  which requires a build — that is a promote step, not cycle A.
- The primary consumer (anima) imports the library directly via
  `use "stdlib/cloud/cloud"`; it does not need the `hexa cloud` verb.

### Decision 6 — `host` + optional `ssh_opts`; `*_opts` variants for ephemeral pods
**picked**: `cloud_run(host, argv)` for a stable host (a `~/.ssh/config` alias).
`cloud_run_opts(host, ssh_opts, argv)` takes extra ssh flags as a `[str]` — the
same structured-argv discipline applied to the ssh invocation itself. Same pair
for nohup / poll. The CLI exposes `--port` / `--insecure` for this.
**rationale**:
- Revised from a measurement: the cycle-A live smoke against a real RunPod pod
  showed a static `~/.ssh/config` alias is unworkable there — an ephemeral pod
  gets a fresh IP, a non-22 port, and a new host key every creation. A generic
  SSH core must accept a port and a host-key policy.
- `ssh_opts` is itself a `[str]` (`["-p","19241","-o","StrictHostKeyChecking=no"]`)
  — every element `_shq`-quoted, consistent with approach C.
- `cloud_run` (no opts) stays for the common stable-host case; `*_opts` is
  purely additive — no existing caller breaks.

### Decision 7 — exec via `exec_capture` + double-quoting + RC-marker
**picked**: Local dispatch uses the `exec_capture` builtin; both `host` and
the remote command are POSIX-quoted (`_shq`) for the local shell as well.
The remote exit code is recovered from a `; echo __CLOUD_RC__=$?` marker line.
**rationale**:
- Revised from a measurement: cycle A first chose `exec_argv` (a no-local-shell
  fork/execvp builtin), but `hexa build` failed — `exec_argv` is in the bind
  allowlist yet has no codegen branch (only the `hx_exec_argv` carrier exists),
  so it is not callable from compiled hexa. `exec_capture` is both
  bind-registered and codegen-wired.
- `exec_capture` routes through a local `/bin/sh -c`, so the local invocation
  is `_shq`-quoted too — the local shell sees `ssh`, `-o`, `BatchMode=yes` and
  two literal words. Approach C holds: every shell in the path (local and
  remote) sees only single-quoted literal tokens.
- The RC-marker pattern is already proven in-repo (`self/main.hexa` qrng
  dispatch uses `echo "__HEXA_SHIM_RC__=$?"`); a missing marker distinctly
  signals ssh transport failure.
- Wiring `exec_argv` through codegen stays available as a later option, but it
  is a compiler-frontend change — out of cycle-A scope.

---

## Cycle A deliverable

- `cloud.hexa` — library: `CloudResult` struct; `cloud_run` / `cloud_nohup`
  / `cloud_poll` / `cloud_tail_cmd` and their `*_opts` variants (extra
  `ssh_opts: [str]`); `cloud_lint_argv`; `_ssh_cmd` / `_shq` / `_join_argv`
  / marker helpers.
- `cloud_cli.hexa` — standalone CLI (`run` / `nohup` / `poll` / `tail` /
  `help` / `version`; `--port` / `--insecure` connection flags).
- `README.md`, `design.md` (this file).

### Decision 8 — `cloud tail` streams via `exec_replace` + remote `sed -u`

**picked**: `cloud tail` builds `ssh host 'tail -F -n +1 LOG | sed -E -un
"/until/{p;q}; /grep/p"'` and runs it through `exec_replace` (execvp /bin/sh).
**rationale**:
- The harness Monitor attaches to a command's stdout. exec_replace makes the
  hexa process *become* the ssh pipeline, inheriting stdout, so each line
  streams live with zero buffering and the process exits when the pipe closes.
- `exec_stream(cmd, on_line)` would be the obvious fit, but its callback
  fn-pointer path **SIGSEGVs in a `hexa build` standalone binary** (works only
  in the bootstrapped `hexa` driver) — logged as an upstream gap. exec_replace
  has no callback and is the same primitive `hexa lsp` uses for stream
  passthrough.
- The remote consumer is `sed -E -un`, not `awk`: the stock pod `awk` is mawk,
  which **block-buffers its stdin** behind a following `tail -F` and never
  emits until EOF (and `stdbuf` cannot fix it — mawk owns its read buffer).
  `sed -u` is line-buffered. Verified live on a Linux pod (mawk 1.3.4).
- terminal-first program (`/until/{p;q}` before the filter) means a terminal
  line always surfaces and stops the stream; the default `until` ERE covers a
  clean finish AND crash signatures so a watch is never silent on a crashloop.

## Cycle B-2 — `runpod` provider (GraphQL pod lifecycle)

`stdlib/cloud/runpod.hexa` — reusable RunPod GraphQL wrappers. POSTs go
through `stdlib/http` (`http_post_with_headers` over HTTPS curl) and JSON
responses through `stdlib/alloc/json_object` (`json_object_get_path` with
dotted nested-field access). No hand-rolled curl strings, no JSON line
scans.

- `runpod_create(api_key, gpu_type, image, pubkey, name) -> RunPodPod` —
  on-demand pod with 22/tcp exposed, /workspace volume mount, PUBLIC_KEY
  injected for sshd authorized_keys.
- `runpod_create_cascade(api_key, gpu_types[], …) -> RunPodPod` — try
  each GPU type in order; first that succeeds wins (RunPod capacity is
  bursty).
- `runpod_get_ssh_port(api_key, pod_id) -> RunPodSshPort` — query the
  port map; returns the public IP+port mapped to private 22.
- `runpod_wait_ssh(api_key, pod_id, max_tries, sleep_each_sec)` — polls
  the port query AND a real `echo` round-trip via `cloud_run` until both
  succeed or the budget expires.
- `runpod_pod_opts(port) -> [str]` — the canonical ssh_opts for an
  ephemeral RunPod pod (`-p <port> -o StrictHostKeyChecking=no -o
  UserKnownHostsFile=/dev/null`); hand the same list to `cloud_run_opts`,
  `cloud_copy_to_opts`, `cloud_copy_from_opts`.
- `runpod_terminate(api_key, pod_id) -> int` — best-effort pod terminate.

**Verified — live e2e PASS** (`stdlib/cloud/e2e_smoke.hexa`, 2026-05-19,
~$0.10, ~38s on `NVIDIA A100-SXM4-80GB`): pod create → wait_ssh → echo →
copy-to → remote sha256 == local → copy-from → round-trip byte-identical
→ terminate. Every primitive of the cycle-A + cycle-B chain confirmed end
to end against real RunPod infrastructure.

### Cycle B-2.1 — CLI-first (runpodctl), API fallback

Each `runpod_*` function now tries the **runpodctl CLI first** and falls
back to the GraphQL API on CLI absence or failure. The CLI route is cleaner
(top-level `id` / `ssh.ip` / `ssh.port` JSON instead of GraphQL's
`data.pod.runtime.ports[].{…}` nested array) and uses RunPod's officially
maintained tool. `RUNPODCTL_DISABLE=1` in the env forces the API-fallback
path (handy for testing the fallback).

CLI subcommand mapping (new-form `pod` subgroup — the deprecated
top-level `create pod` / `remove pod` emit a warning line that breaks
`json_parse`):

| operation | CLI                                          | API fallback             |
|-----------|----------------------------------------------|--------------------------|
| create    | `runpodctl pod create --gpu-id … -o json`    | GraphQL `podFindAndDeployOnDemand` |
| ssh-port  | `runpodctl pod get <id> -o json` → `ssh.{ip,port}` | GraphQL `pod.runtime.ports[]` |
| terminate | `runpodctl pod delete <id> -o json`          | GraphQL `podTerminate`   |

Live e2e re-verified on the CLI path (2026-05-19, 46s, `created (cli)`
message in the smoke log).

## Cycle B-1 — `cloud_copy_*` (file transfer)

- `cloud_copy_to` / `cloud_copy_to_opts(host, ssh_opts, local, remote)` —
  upload a local file to `host:remote` over scp.
- `cloud_copy_from` / `cloud_copy_from_opts(host, ssh_opts, remote, local)` —
  download `host:remote` to a local path.
- `_scp_opts` translates ssh's `-p PORT` to scp's `-P PORT` (other `-o` opts
  pass through unchanged). `_scp_capture` POSIX-quotes every opt + src + dst
  for the local `/bin/sh -c`. scp's exit code rides on the local process —
  recovered from `exec_capture` element 2, no remote marker needed.
- CLI: `cloud copy-to <host> <local> <remote> [--port N] [--insecure]` and
  `cloud copy-from <host> <remote> <local> [...]`.
- Verified: live round-trip on `ubu-2` — sha256 byte-identical both
  directions (local → remote → local).

Verification: `hexa parse` (syntactic) + `hexa build` (semantic, clean) +
live SSH smoke — 5/5 PASS against `ubu-2` and a real RunPod pod
(`root@…:19241`): basic run, exit-code propagation (remote `exit 7` → 7),
argv quoting (`*` and `/tmp/*` stay literal — no remote glob expansion), a
real `python3 -c` on the pod, and a `/* note */` argv rejected. Two bugs the
smoke caught and fixed: `exec_capture` returns `[stdout, stderr, rc]` not a
bare str (use element 0); the `/*`-substring lint false-positived on `/tmp/*`
(now matches only true comment-fragment shapes — opens `/*`, closes `*/`, or
inline `/* ` / ` */`).

## Cycle C — `cloud dft-run <deck-dir>` (guarded DFT el-ph dispatch, INBOX #1249)

`dft_dispatch.hexa` absorbs the demiurge RTSC campaign's hand-roll checklist
(`demiurge/exports/sweep/DFT_POD_DISPATCH_RECIPE.md`) into one guarded verb so
the four repeated-mistake classes cannot happen by omission:

- **① rent** — `dft_rent_query` pins `reliability>0.97` (low-cost
  interruptibles preempt in ~13 h → lost runs), 16+ physical cores, decent
  bandwidth; `vast_create` already passes `--direct`; a TCP `echo REACHABLE`
  precheck destroys + re-rents a proxy-only / dead host.
- **② transport** — `vast_direct_endpoint` reads the bare `public_ipaddr` +
  `ports["22/tcp"][0].HostPort` from the **plural** `show instances --raw`
  (the single `show instance <id>` crashes on a null `start_date`, #1239(2)),
  never the cloud-guard-blocked proxy host; connects with the vast identity
  via `-i` (#1155 workaround).
- **③ chain** — a hexa-native `dft_relax_to_scf_coords` parser (CELL_PARAMETERS
  alat → angstrom × `0.52917720859`, ATOMIC_POSITIONS passthrough — NO hand
  parser, which FATAL'd two campaigns); `-np` = `dft_physcores` (lscpu
  Core×Socket, NOT nproc → no oversubscribe thrash); `--allow-run-as-root`,
  `recover=.true.`, `timeout`, `setsid`.
- **④ monitor** — numeric instance-id only in the registry (#1229 argv-fragment
  guard); `dft_phonon_stable` fast-fails the moment any mode is below
  −5 cm⁻¹ (imaginary → no full-BZ wait); non-interactive teardown.

### Decision — preview by default, `--go` to spend; library module

A bare `hexa cloud dft-run <deck>` is PREVIEW: validate the deck, print the
guarded plan, and (if a local `relax.out` exists) run the coordinate parser so
the geometry can be eyeballed — spending **nothing**. Only `--go` rents a
billing pod and dispatches. `dft_dispatch.hexa` carries **no `main()`** (the
verb lives in `cloud_cli.hexa`), so the pure helpers are `use`-able by
`dft_dispatch_test.hexa` without auto-firing a top-level main (INBOX G2).

### Deck convention (`<deck-dir>/`)

`relax.in` · `ph.in` · `scf.in.head` + `scf.in.tail` (the generated
`CELL_PARAMETERS`+`ATOMIC_POSITIONS` block is spliced BETWEEN the two halves
by `dft_assemble_scf`, so a tail `K_POINTS` survives — no blind in-place
splice) · `pseudo/`.

Verification: pure helpers 17/17 (transpile `self/native/hexa_v2` → clang +
`self/runtime.c` → run) — parser alat→angstrom (`0.529177`) + crystal
passthrough, stability verdict (−5 cm⁻¹ cutoff, −3 noise stable,
inconclusive), `physcores` 14×2=28 (not nproc 56), rent query, scf assembly;
direct-endpoint parser syntax-checked + pattern-equivalent to the existing
`vast_ssh_endpoint`/`_vast_collect_offer_ids` JSON paths. The `--go` e2e
(rent/ssh/chain) is unverified without vastai + a live GPU — it is gated
behind `--go` and composed from already-shipped lifecycle primitives. Harvest
(λ_BZ / ω_log / Allen-Dynes Tc → `hexa atlas register`) and a generic
`cloud job-run <chain-spec>` abstraction are follow-ups.
