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
- [x] rt_* shim sweep — run the remaining 15 `self/native/*_byte_diff.hexa` oracles to verdicts,
      retire each `.c` whose oracle is green AND the full hexa_cc build passes
      → DONE (15/15): M2 4 (`proc_fork`·`crypto_openssl`·`mount`·`wait`) + M5 11
        (`exec_argv_sha256`·`exec_pipe`·`namespace`·`net`·`persistent_pipe`·`pty`·`signal_flock`·
        `tensor_kernels`·`term_ffi`·`thread`·`crypto_sodium`) — ALL BYTE-EQ, 3/3, verdicts persisted.
        (These `.c` were already graduated in #2065; oracle replays the proof, .c NOT re-committed.)
- [x] per-port verdict gate — every retire backed by `.verdicts/c-zero/<module>.txt` (g63)
      → all 16 A2 emitter-backed shims have a BYTE-EQ verdict with raw stdout verbatim
        (fp_init + the 15 swept). Gate holds for the entire A2 mass.
- [x] C-LOC burn-down ledger — running total of live authored C across the ecosystem
      → `.verdicts/c-zero/LEDGER.txt`: live-C 37353 LOC / proven-retirable **3946 LOC**
        (16/16 A2 shims, COMPLETE) / remaining-named 33407 (`hexa_cc.c` 28482 + GPU 4925).
- [x] A3 GPU shims (cuda/forge, 4925 LOC) — DONE on pool summer RTX 5070 (FREE, no rental):
      runtime_bf16/forge_tier_v1/lora_cuda_host/gpu_codegen_stub BYTE-EQ (#2611) + runtime_cuda
      emitter nvcc-CLEAN after 2 fixes (#2612). See `.verdicts/c-zero/LEDGER.txt` §5-7.
- [x] `hexa_cc.c` (28482 LOC) — RECLASSIFIED (#2613): it is the GENERATED boot image of the
      self-host toolchain (SSOT self/{lexer,parser,type_checker,codegen}.hexa), `.hexanoport` —
      NOT hand-authored port debt. Already git-rm'd (#2065) + cold-seed bootstrap (HEXA-CC-ZERO
      P6). See `.verdicts/c-zero/F-HEXA-CC-RECLASSIFY.txt`. C-ZERO portable-surface burn-down COMPLETE.

## scope (reachable repos this run)

hexa-lang (`~/dancinlab/hexa-lang`) — primary. Siblings checked out under `~/dancinlab/*`: anima
(C is vendored / deploy-snapshot / training-shim, not live build path), void (external Ghostty
hard-fork — out of scope for porting). phanes · n6 · tape · airgenome NOT checked out (not counted).
