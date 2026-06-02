# C-ZERO — log (append-only)

## 2026-06-03 · INVENTORY + first port (milestone 1)

### INVENTORY (reachable repos only — host `mini`)

Full table → `.verdicts/c-zero/INVENTORY.txt`. Headline:

| repo | live authored .c | LOC | class |
|------|------------------|-----|-------|
| hexa-lang | self/native/*.c (16 emitter-backed + hexa_cc.c) | 32428 | FFI-shim + cc driver |
| hexa-lang | self/cuda/*.c + forge | 4925 | GPU substrate (emitters present) |
| hexa-lang | runtime.c / runtime_core.c / runtime_hi_gen.c | 23651 | EMITTED (no authored C) |
| anima | training/*.c live shims; rest vendored/deploy/cache | ~6 live | training FFI-shim |
| void | Ghostty hard-fork | 30 | EXTERNAL — out of scope |
| echoes/demiurge/hexa-codex/kosmos/sidecar/pool/secret | 0 | — | no C |
| phanes/n6/tape/airgenome | ABSENT (not checked out) | — | not counted |

Key finding: hexa-lang's runtime C is ALREADY hexa-emitted (SSOT = `*_emit.hexa`), and 16/17
`self/native/*.c` shims have an emitter + a `*_byte_diff.hexa` RUNEQ oracle. The C-ZERO frontier in
hexa-lang therefore reduces to (a) running each oracle to a green verdict and retiring the `.c`, and
(b) the ONE unit with no emitter: **`self/native/hexa_cc.c` — 28482 LOC**, the single biggest live
authored-C mass in the ecosystem.

### FIRST PORT — `fp_init.c` (59 LOC), RUNEQ GREEN

- module: `self/native/fp_init.c` (per-thread IEEE-754 FP control-word reset; called at main()
  entry by codegen). hexa SSOT: `self/native/fp_init_emit.hexa`. Oracle:
  `self/native/fp_init_byte_diff.hexa`.
- RUNEQ: source-text byte-identity — `sha256(emitter output) == sha256(authored fp_init.c)`.
  Result: **PASS, 3/3 checks**, both sha256 = `f32c2ccd8dc320cd96b57f9352e75891d649fe4b801ad15a356192e5bdb4ed46`.
  Token `__HEXA_LANG_FP_INIT_BYTE_DIFF__ PASS`. Verdict → `.verdicts/c-zero/fp_init.txt`.
- retire decision: **port landed ALONGSIDE the C, NOT retired this run.** The oracle proves the
  emitter reproduces the C exactly (deletion gate OPEN), but the brief's full discipline also
  requires the end-to-end hexa_cc self-host build to pass before `git rm fp_init.c`. That build is a
  heavy ghost/summer step; retire is logged as a follow-up so nothing regresses (g63). The emitter
  is already the SSOT — the build regenerates the `.c` regardless.

Toolchain note: the `*_byte_diff.hexa` harnesses shell out to `hexa-run`; added a
`~/.hx/bin/hexa-run` shim (`exec hexa run "$@"`) so the oracles run on hosts that only ship `hexa`.

### remaining (next cycles)

- Run the other 15 `self/native/*_byte_diff.hexa` oracles → verdicts → retire on green + build pass.
- `hexa_cc.c` (28482 LOC) — needs an emitter or a native-hexa cc-driver self-host (multi-PR).
- GPU shims (cuda/forge) — parity oracle needs a GPU host (pool RTX 5070).
