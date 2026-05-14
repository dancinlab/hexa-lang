<!-- @created: 2026-05-15 -->
<!-- @scope: rollback procedure — post-E2-fire restore of hexa_interp -->
<!-- @authority: COMPILE-ONLY.tape @D phase_f_closure_criteria §H (H1) -->
<!-- @audience: future maintainer reading this 6 months after retire -->
<!-- @target: 30-minute restore from a clean main HEAD -->

# `hexa_interp` Restore Procedure

**Status**: standby. This page is dormant until/unless E2 (hexa_interp
retire) is rolled back. If you are reading it because something broke
post-retire, follow §3 step-by-step. If you are reading it for context,
§1 is enough.

---

## §1 When to use

Use this procedure *only if* hexa_interp has been retired (E2 fire
committed; see [`COMPILE-ONLY.tape`](../COMPILE-ONLY.tape) @D
`phase_f_closure_criteria` §E "Artifact removal") **AND** a critical
user-flow is broken. Concretely:

- **LSP** (`self/lsp.hexa`) — completion / hover / goto-def fails to
  start under D mode and rebuild does not recover it.
- **`hexa-commit`** / `bin/proposal_inbox` / `bin/hexa-push` — daily
  workflow tools fail with no diagnostic that points at AOT codegen.
- **Dev-loop** — `hexa run x.hexa` cold-start exceeds the legacy
  interp time by >5×, beyond §G1 G2 baseline tolerance.
- **Sister-repo handoff** — `wilson` / `anima` / `echoes` smoke tests
  fail and bisection points at a hexa-lang change that landed with E2.

Cosmetic breakage (e.g. `hexa repl` ergonomics, a single test in
`bench/`) is **not** a restore trigger. File an `incoming/patches/`
note instead.

---

## §2 Prerequisites

Three artifacts must be available. Verify each before starting:

1. **`archive/hexa_interp_last/`** snapshot — the H2 artifact. Contains
   the last working interp binary (or, if binaries were not committed,
   a `README.md` documenting how to regenerate them from the
   `pre-e2-fire` tag).
2. **`git tag pre-e2-fire`** — the restore branch-point. Verify with
   `git tag -l pre-e2-fire`. If absent, abort: there is no clean
   restore target and you must reconstruct from `git log` manually.
3. **Working `clang` + macOS/Linux toolchain** — same minimum that the
   normal `hexa cc` path needs. `archive/hexa_interp_last/build_env.txt`
   records the toolchain that originally produced the binaries.

---

## §3 Procedure (30-min target)

### Step 1 — restore interp sources + binary from the tag

```bash
git checkout pre-e2-fire -- \
  self/runtime.c \
  self/interpreter.hexa \
  self/interpreter.hexa.c \
  build/hexa_interp \
  build/hexa_interp.darwin \
  build/hexa_interp.linux
```

If `build/hexa_interp*` are not tracked (gitignored — likely), copy
from `archive/hexa_interp_last/` instead, or rebuild via `hexa cc
--regen` in step 2.

### Step 2 — rebuild if needed

```bash
# Only if the binary copy is missing or for a wrong platform.
hexa cc --regen self/interpreter.hexa -o build/hexa_interp
chmod +x build/hexa_interp
```

### Step 3 — smoke-test three canonical workloads

```bash
# 1. hello world (compile + run)
./build/hexa_interp examples/hello.hexa
#    expected: "hello"

# 2. hexa-commit dry-run
./bin/hexa-commit --dry-run
#    expected: no crash, "[hexa-commit]" diagnostic on stdout

# 3. REPL eval
echo '2 + 2' | ./build/hexa_interp --repl
#    expected: "4"
```

If **all three pass**, the restored binary is functional.

### Step 4 — promote restored binary

```bash
cp build/hexa_interp self/native/hexa_v2
ln -sf "$(pwd)/build/hexa_interp" ~/.hx/bin/hexa_real
# or: ./hexa --promote-restored
```

Restore is complete. File a follow-up note at
`incoming/patches/rollback_<YYYY-MM-DD>_<reason>.md` describing what
broke under D mode so the next retire attempt does not repeat the
failure mode.

---

## §4 Common failure modes during restore

| Symptom | Likely cause | Resolution |
|---|---|---|
| `hexa cc --regen` errors on `interpreter.hexa` after step 1 | SSOT drift since retire — new fns added to compile path that interp does not implement | Cherry-pick the AOT-side fixes that are pure additions (new builtins, runtime helpers) onto the restored tree; skip changes that delete interp scaffolding |
| Smoke test 2 (`hexa-commit`) fails with "no such builtin" | Same as above, on a builtin used by `bin/*` tools | Add a stub or restore the builtin source from the post-retire tree |
| `~/.hx/bin/hexa_real` symlink points at a stale stage-3 binary | Promotion step skipped or failed silently | Re-run step 4; verify with `ls -lL ~/.hx/bin/hexa_real` |
| Restored binary segfaults on first run | ABI drift in `self/runtime.c` between `pre-e2-fire` and HEAD | Bring `runtime.c` along *fully* from `pre-e2-fire` (not surgical); accept that AOT-side fixes since retire will be lost |
| Sister-repo (wilson) still broken after smoke pass | Sister repo cached the broken artifact | Force-rebuild downstream: `cd ~/core/wilson && rm -rf build/ && hexa build core/main.hexa` |

---

## §5 Decision tree — abort vs. continue

If you are >**1 hour** into the restore and any of the following holds:

- More than two smoke tests still fail after step 3
- `runtime.c` cherry-pick produces merge conflicts in >3 hunks
- ABI drift is corrupting unrelated tests

**Abort the restore.** Re-fire E2 on the latest HEAD:

```bash
git restore -- self/runtime.c self/interpreter.hexa self/interpreter.hexa.c
rm -f build/hexa_interp build/hexa_interp.darwin build/hexa_interp.linux
# re-run E2 closure verification (tool/phase_f_audit.hexa when available)
```

The right move at this point is to stay native-only and **fix the
downstream consumer instead**. Re-document the failure mode in
`incoming/patches/` so the next E2-fire attempt avoids it.

---

## §6 Verification post-restore

After step 4 promotion, run these three checks. All must pass:

```bash
# 1. m0 milestone
./tests/m0/run_m0.hexa
echo $?    # expected: 0

# 2. REPL arithmetic
echo '2 + 2' | hexa repl
#    expected: 4

# 3. sister-repo smoke (wilson session_start)
cd ~/core/wilson && hexa run core/main.hexa --smoke
#    expected: "wilson 0.0.1" + no diagnostic
```

If any check fails, return to §5 and abort: the restored binary is not
shippable.

---

## §7 References

- [`COMPILE-ONLY.tape`](../COMPILE-ONLY.tape) @D `phase_f_closure_criteria` §H1–H4 (rollback plan)
- [`archive/hexa_interp_last/README.md`](../archive/hexa_interp_last/README.md) — H2 snapshot index
- `git tag pre-e2-fire` — restore branch-point
- [`HEXA-NATIVE-ONLY.md`](../HEXA-NATIVE-ONLY.md) §I (interp sunset axis)
- [`SPEC.md`](../SPEC.md) §15 E2 (CLOSED marker post-fire)

---

*Maintainer note: keep this file ≤ 200 lines. If procedure complexity
grows past that, split common-failure-modes into a separate
`doc/interp_restore_troubleshooting.md` and link from §4.*
