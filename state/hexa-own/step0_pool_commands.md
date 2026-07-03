# Step-0 pool commands — run both executors on aiden or summer

mini = git/gh only; builds/measurements run on the pool (feedback_run_heavy_on_aiden_summer).
Pool hosts are direct ssh targets: `ssh aiden` / `ssh summer` (~/.sidecar/pool.json — name==target).
All env values below are the CANONICAL linux-x86_64 contract from `.github/workflows/release.yml:319-324`
(`TARGET: linux-x86_64 · CC: gcc · LIBS: "-lm -ldl" · GH_TOKEN`), same contract documented in
`tool/release_build:27-33,43-48`; arm64 precedent `tool/selfhost_arm64_remote_run.sh:43`.

```bash
HOST=aiden   # or: summer

# ── 0) isolated scratch checkout on the host (never the shared main checkout —
#       feedback_parallel_agents_isolated_worktree; clone pattern = tool/selfhost_arm64_remote_run.sh:35-38)
ssh $HOST 'rm -rf ~/hx-step0 && git clone --depth 1 https://github.com/dancinlab/hexa-lang.git ~/hx-step0'
# ship the KIT files (or push them on a branch and clone that branch instead):
scp state/hexa-own/step0_characterize.hexa state/hexa-own/step0_expected_gen2.txt $HOST:~/hx-step0/state/hexa-own/

# ── 1) EXECUTOR A — shipping `hexa run` (compile-then-exec, self/main.hexa:25)
#       STALE-HEXAT TRAP GUARD FIRST — never measure through a stale pool binary
#       (CLAUDE.md QA dont; project_local_hexa_stale_oracle). Guard idiom =
#       `hexa --version` fail-loud, exactly as tool/laneg_refire_remote.sh:36.
ssh $HOST 'bash -lc "
  set -euo pipefail
  hexa --version || { echo FATAL: no/stale hexa; exit 10; }   # capture the version+hash in the log
  rm -rf ~/.hexa-cache    # run-cache purge — cache-key/runtime-swap gotcha (self/main.hexa:3939-3996)
  cd ~/hx-step0
  hexa run state/hexa-own/step0_characterize.hexa | tee /tmp/step0_run.out
"'

# ── 2) EXECUTOR B — fresh release_build gen2 C driver (the oracle build)
#       Exact per-target env: release.yml:319-324. GH_TOKEN enables the edge-pull
#       fast path (tool/release_build:31); without gh auth it falls back to the
#       frozen-seed build (slower, still valid — selfhost_arm64_remote_run.sh ran tokenless).
ssh $HOST 'bash -lc "
  set -euo pipefail
  cd ~/hx-step0
  TARGET=linux-x86_64 CC=gcc LIBS=\"-lm -ldl\" GH_TOKEN=\$(gh auth token 2>/dev/null || true) bash tool/release_build
  ./hexa --version    # proves the driver we are about to trust is the one just built
  ./hexa build state/hexa-own/step0_characterize.hexa -o /tmp/step0_gen2    # -o flag: self/main.hexa:7147-7155
  /tmp/step0_gen2 | tee /tmp/step0_gen2.out
  # cross-check: the SAME fresh driver through the run verb (splits shipping-stale from semantics)
  rm -rf ~/.hexa-cache
  ./hexa run state/hexa-own/step0_characterize.hexa | tee /tmp/step0_freshrun.out
"'

# ── 3) verdicts (all three must be byte-identical to the frozen oracle)
ssh $HOST 'cd ~/hx-step0 && \
  diff /tmp/step0_gen2.out    state/hexa-own/step0_expected_gen2.txt && echo GEN2==ORACLE; \
  diff /tmp/step0_freshrun.out /tmp/step0_gen2.out                   && echo FRESHRUN==GEN2; \
  diff /tmp/step0_run.out      /tmp/step0_gen2.out                   && echo SHIPRUN==GEN2'

# ── 4) optional: inspect the emitted C scaffold (__ret_val / __defer_N_active /
#       goto __fn_exit / flag-guarded LIFO drain — self/codegen.hexa:2088-2303)
ssh $HOST 'cd ~/hx-step0 && ./hexa build state/hexa-own/step0_characterize.hexa -o /tmp/step0_c --c-only && \
  grep -n "__fn_exit\|__defer_\|__ret_val" /tmp/step0_c.c | head -40'   # --c-only: self/main.hexa:7156-7158
```

Interpretation table

| diff result | meaning |
|---|---|
| GEN2==ORACLE fails | my traced expectation is wrong somewhere → fix step0_expected_gen2.txt from the CAPTURED gen2 output (gen2 is the oracle, the txt is the prediction) |
| SHIPRUN==GEN2 fails, FRESHRUN==GEN2 passes | shipping pool hexa is stale (record `hexa --version` from step 1) — not a semantics finding |
| FRESHRUN==GEN2 fails | run-verb vs build-verb divergence in the SAME driver → real finding, file before M1 lowering |
| all pass | oracle frozen — commit the captured output as the Step-0 artifact and proceed to M1 Step 1 (PARSER-1 contextual defer) |
