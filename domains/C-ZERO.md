@title: 🚫🇨 C-ZERO — drive the live C dependency to ZERO

@goal: Drive the live C dependency to ZERO across the real dancinlab projects — every `.c` on a
build/run critical path ported to hexa, compiled by the now-self-hosting gen3, and proven
behaviourally equivalent (RUNEQ / byte-diff) BEFORE the C original is retired. No C deleted without
a green parity verdict (g63).

## method

The hexa-native port discipline is already established in `self/native/`: each authored `.c` shim
has a hexa **emitter** (`<mod>_emit.hexa`, the SSOT) and a **byte-diff oracle**
(`<mod>_byte_diff.hexa`) that proves `sha256(emitter output) == sha256(authored .c)`. A green
oracle PASS is the HARD GATE that opens `git rm <mod>.c` (the build regenerates the `.c` from the
emitter before `runtime.c` compiles, so behaviour is preserved by construction). C-ZERO advances by
(1) running each oracle to a persisted verdict, (2) retiring the C once green + the full hexa_cc
self-host build passes, (3) writing emitters+oracles for the units that still lack them.

## milestones

- [x] INVENTORY — enumerate every `.c` on a live build/run path (hexa-lang + reachable siblings),
      classify (runtime / app / FFI-shim / external-fork), LOC by repo+class
      → `.verdicts/c-zero/INVENTORY.txt`
- [x] first runtime `.c` port w/ RUNEQ — `fp_init.c` (59 LOC) byte-diff oracle GREEN
      (sha256 match) → `.verdicts/c-zero/fp_init.txt`
- [ ] rt_* shim sweep — run the remaining 15 `self/native/*_byte_diff.hexa` oracles to verdicts,
      retire each `.c` whose oracle is green AND the full hexa_cc build passes
- [ ] per-port verdict gate — every retire backed by `.verdicts/c-zero/<module>.txt` (g63)
- [ ] C-LOC burn-down ledger — running total of live authored C across the ecosystem
- [ ] `hexa_cc.c` (28482 LOC) — the dominant remaining authored-C mass; needs an emitter or a
      native-hexa self-host of the cc driver (large; multi-PR)

## scope (reachable repos this run)

hexa-lang (`~/dancinlab/hexa-lang`) — primary. Siblings checked out under `~/dancinlab/*`: anima
(C is vendored / deploy-snapshot / training-shim, not live build path), void (external Ghostty
hard-fork — out of scope for porting). phanes · n6 · tape · airgenome NOT checked out (not counted).
