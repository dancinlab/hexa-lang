# IPCP baseline build fix — `_db_grad_accum_farr` undeclared identifiers (2026-05-17)

> Phase 4-D-5-4 fire campaign was blocked on a pre-existing transpiler-binary
> selection bug in the flame Phase 4-B build wrappers. This note records the
> root cause and the fix. Verdict: `tool/flame_phase4b3_verify_all.sh` 26/26
> PASS, IPCP + A2 builds byte-identical to `/tmp/baseline.out`.

## Symptom

`hexa build` / IPCP pipeline produced a `_b3.c` / `_ipcp.c` with ~20 clang
errors — undeclared `dW_dst` / `d_out` / `d_in` identifiers inside the
generated `_db_grad_accum_farr` function. Sections 4-7 of
`tool/flame_phase4b3_verify_all.sh` (IPCP + A2 wrapper builds) failed; d768·12L
A2 trainer regeneration was blocked.

## Root cause — TWO coupled defects, both in the build wrappers (not codegen)

`stdlib/flame/decoder_block_lib.hexa:126-128` declares `_db_grad_accum_farr`
with a **3-line function signature** (9 params spanning 3 source lines):

```hexa
fn _db_grad_accum_farr(dY: int, dY_off: int, X: int, X_off: int,
                       dW_dst: int, dW_off: int,
                       T: int, d_out: int, d_in: int) {
```

The three flame build wrappers selected the transpiler binary with:

```sh
V2=$(find self/native -name "hexa_v2*" 2>/dev/null | head -1)
```

The glob `hexa_v2*` matches **six** binaries in `self/native/`
(`hexa_v2`, `hexa_v2_baseline`, `hexa_v2_test`, `hexa_v2_pre71`,
`hexa_v2_nobt71`, `hexa_v2_rfc011`). `find` returns directory order, and
`hexa_v2_baseline` (an Apr-15 stale binary) sorted first — so `head -1`
silently picked the **wrong transpiler**.

### Defect 1 — `hexa_v2_baseline` strips multi-line fn signatures

The Apr-15 `hexa_v2_baseline` only reads the **first source line** of a
function signature. It emitted:

```c
HexaVal _db_grad_accum_farr(HexaVal dY, HexaVal dY_off, HexaVal X, HexaVal X_off, HexaVal );
```

— params `dW_dst, dW_off, T, d_out, d_in` dropped, leaving a dangling
anonymous `HexaVal `. The function body then references `dW_dst`, `d_out`,
`d_in` → undeclared-identifier clang errors. It even printed
`Parse error at 2738:48: unexpected token RParen` yet still wrote "OK".

The canonical `self/native/hexa_v2` (May-17, commit `170d64d7`
"regenerate hexa_v2 + hexa_cc.c from merged source tree") emits the full
9-param signature correctly.

### Defect 2 — runtime-include convention drift

Selecting the canonical `hexa_v2` surfaced a second mismatch. The canonical
binary emits `#include "runtime.h"` (separate-TU convention — `runtime.c`
expected to be linked as its own object). `hexa_v2_baseline` emitted
`#include "runtime.c"` (single-TU — runtime inlined).

The flame Phase 4-B build pipeline is **architected around the single-TU
form**: `flame_phase4b3_build.sh` step 3.7 and `flame_phase4b3_a2_build.sh`
step 3.10 `sed`-insert decls / primitives **after the `#include "runtime.c"`
anchor line**, and clang compiles only the one `.c` with `-I self -lm` — it
never links `runtime.c` separately. With `#include "runtime.h"`, runtime
symbols (`__hexa_fn_arena_enter`, `__hexa_fn_arena_return`, `__hx_to_double`,
…) went undefined at link time.

## The fix — `tool/flame_phase4b_build.sh`, `flame_phase4b3_build.sh`, `flame_phase4b3_extern_build.sh`

1. **Exact binary selection.** Replace the `hexa_v2*` glob with an explicit
   `self/native/hexa_v2` selection (exact name, no glob), so a stale
   `hexa_v2_baseline` can never be picked:

   ```sh
   if [ -x self/native/hexa_v2 ]; then
       V2="self/native/hexa_v2"
   else
       V2=$(find self/native -name "hexa_v2" 2>/dev/null | head -1)
   fi
   ```

2. **Restore single-TU convention.** Right after the transpile step, rewrite
   the emitted `.c` `#include "runtime.h"` → `#include "runtime.c"` so the
   pipeline's `sed`-anchor and single-TU clang compile still resolve runtime
   symbols:

   ```sh
   if grep -q '^#include "runtime.h"' "$CFILE"; then
       sed -i '' 's|^#include "runtime.h"|#include "runtime.c"|' "$CFILE"
   fi
   ```

No transpiler-source change (`self/codegen_c2.hexa`, `compiler/lower/`) and no
runtime change were needed — both defects lived entirely in the three flame
build wrappers. This is a low-risk build-script fix.

## Verification (2026-05-17, $0 Mac builds, HEXA_MAC_BUILD_OK=1)

- `tool/flame_phase4b3_verify_all.sh` → **26/26 PASS** (5 fwd + 5 bwd + 4
  matmul + 4 grad_accum byte-eq + 3 mechanism probes + IPCP + A2 fwd+bwd
  byte-id + F-RFC048-PAIR-DETECT + F-RFC048-FUSED-COMPILE-EQ +
  F-RFC048-FUSED-FWD-BWD-EQ).
- `tool/flame_phase4b_build.sh stdlib/flame/flame_d32_corpus_test.hexa …` →
  IPCP binary builds, output **byte-identical** to `/tmp/baseline.out`.
- `tool/flame_phase4b3_a2_build.sh …` → A2 fwd+bwd primitive build
  **byte-identical** to baseline.

## Follow-up note (not blocking)

The hard-coded d=32·3L dim sed-rewrite in `flame_phase4b3_build.sh` step 3.6
remains config-specific. Regenerating the d768·12L A2 trainer needs the
analogous `T…d768…` sed program — that is Phase 4-D dimension-generalization
work, orthogonal to this transpiler-binary fix.
