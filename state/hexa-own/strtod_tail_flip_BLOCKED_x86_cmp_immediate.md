
---

## ✅ CLOSED 2026-07-07: strtod-tail native flip DONE (#4651, main 39342ca56)

The strtod-tail native path is now **default-ON** and matches glibc strtod bit-exact. Full arc:
- **Accuracy: T_mis 176 → 5 → 0** across 3 measured rounds (aiden, n=140,678 vs glibc strtod):
  - #4639 — x86_64 `cmp` wide-immediate codegen fix (so the seed assembles at all).
  - #4645 — 4-family reference-match (A underflow i64-overflow RNE, B optional-p hex + stop-at-junk,
    C nan-payload base-0/saturation/paren-rollback, D `\v`/`\f` whitespace) → 176 → 5.
  - #4646 — nan(0x..) hex-prefix off-by-one (`i+2` skipped the first hexdigit) → 5 → 0.
- **Flip #4651** (bit-changing): `stage_resolve_runtime_a:707` HEXA_RT_STRTOD_TAIL_NATIVE `:-0` → `:-1`
  + 3 freshly re-baked seeds. Gates GREEN: byteeq gen3=gen4 3-target (re-converged), **faithful-
  nobaseline nm DROP of the strtod symbol on all 3 targets** (the zeroc #29 win — one fewer libc
  UND), summary; the only PR RED was 12 flaky `stdlib/cloud/*_test` timeouts (network-dependent
  infra, cleared on re-run — infra-wall-noneval).
- **Build-determinism note** (convergence float-parse-hexinfnan-x86-64-s-1): the seed bake is
  build-state sensitive (a stale-aprime bake re-emitted imm=3; clean rebuild → imm=0) — always
  verify imm=0 + assemble after regen.

Discipline: every round was a **measured root-cause** (no tune-to-green, no corpus-prune); the flip
gate caught real accuracy gaps before shipping. Follow-ups (non-blocking): darwin exotic-nan ghost
C probe (Apple libc nan-payload divergence risk, Fable Family C); merge the re-runnable corpus
harness branch (feat/strtod-oracle-corpus).
