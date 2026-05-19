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

### Decision 6 — `host` is an ssh destination; ssh options live in ssh config
**picked**: `cloud_run(host, argv)` takes `host` as a `user@host` or, preferred,
a `~/.ssh/config` Host alias. Key / port / user are not API parameters.
**rationale**:
- Matches the wilson-pool roster convention (`host: ssh-target`).
- Keeps the cycle-A API to two parameters; an inline-options variant can be
  added later without breaking callers.
- ssh config is the canonical, per-host place for keys and ports.

### Decision 7 — exec via `exec_argv` + RC-marker, not `exec_argv_with_status`
**picked**: Use the `exec_argv` builtin (bind-registered) and recover the
remote exit code from a `; echo __CLOUD_RC__=$?` marker line.
**rationale**:
- `exec_argv` is in the compiler's builtin allowlist (`compiler/check/bind.hexa`);
  `exec_argv_with_status` is not — using it would require editing the
  compiler frontend, out of scope for cycle A.
- The RC-marker pattern is already proven in-repo (`self/main.hexa` qrng
  dispatch uses `echo "__HEXA_SHIM_RC__=$?"`).
- A missing marker is itself a useful signal — it means ssh transport
  failure or a dead remote shell, which `cloud_run` reports distinctly.

---

## Cycle A deliverable

- `cloud.hexa` — library: `CloudResult` struct, `cloud_run`, `cloud_nohup`,
  `cloud_poll`, `cloud_lint_argv`, and `_shq`/`_join_argv`/marker helpers.
- `cloud_cli.hexa` — standalone CLI (`run` / `nohup` / `poll` / `help` /
  `version`).
- `README.md`, `design.md` (this file).

Verification: local `hexa parse` edit-gate (syntactic). Full semantic build
and a live SSH smoke test are a follow-up step.
