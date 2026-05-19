# RFC 061 — runtime 2-layer split (runtime_core.c + runtime_hi.hexa)

## 1. Status

- **Status**: **design-draft (2026-05-19)** — DESIGN ONLY, no implementation.
  This RFC scopes ROADMAP child **69** ("runtime 2-레이어 분할"), which until
  now was a single unscoped roadmap line. No code moves with this RFC; it
  defines the boundary criterion, the bootstrap-circularity constraint, and a
  4-phase execution plan so the split can proceed as reviewable cycles.
- **Date**: 2026-05-19
- **Priority**: P2 (architectural hygiene — not on any critical chain; the
  monolithic runtime.c works correctly today, it is simply hard to audit and
  blocks the hexa-native-only end-state for the runtime layer).
- **Severity**: LOW (no correctness bug; a completeness/maintainability gap).
- **Domain**: **compiler / runtime**. Deliverable scope is
  `self/runtime.c` → `self/runtime_core.c` + `self/runtime_hi.hexa`.

## 2. Problem

`self/runtime.c` is **13,336 lines** of monolithic C — the entire hexa runtime
(HexaVal representation, allocator, ~191 `hexa_*` builtins, string/math/IO).
ROADMAP 69 (anima hxa-20260423-003, child of self-host roadmap 64) wants it
split into:

- `runtime_core.c` — the irreducible C primitives (target **≤500 lines**).
- `runtime_hi.hexa` — everything expressible in hexa, written in hexa.

This advances `HEXA-NATIVE-ONLY.md`: the CPU *codegen* is already self-hosted
(`compiler/codegen/{arm64_darwin,x86_64_linux}.hexa`), but the *runtime* the
codegen emits calls into is still 13 k lines of hand-C. A hexa-authored
runtime closes that seam for everything that does not manipulate representation
bits directly.

## 3. The hard constraint — bootstrap circularity

`runtime_hi.hexa` cannot be a runtime-*loaded* hexa module. The C that hexa
codegen emits calls `hexa_str_char_count(...)`, `hexa_array_map(...)` etc.
*directly* — those symbols must exist as compiled object code before any hexa
program (including `runtime_hi.hexa` itself) runs.

Therefore `runtime_hi.hexa` is **hexa source shipped as pre-generated C**: it
is transpiled (`hexa_v2 runtime_hi.hexa runtime_hi.c`) at toolchain-build time,
and `runtime_hi.c` is committed + linked exactly like `hexa_cc.c`. The split is
a re-layering of *authorship* (C → hexa for the hi tier), not a change to how
the runtime is loaded.

This also bounds `runtime_core.c`: it must contain everything `runtime_hi.hexa`
*itself* needs at its own codegen-emit time (HexaVal constructors, allocator,
array/map primitives) — `runtime_hi` cannot bootstrap on functions it defines.

## 4. Proposal

### 4.1 Boundary criterion

A function belongs in `runtime_core.c` **iff any of**:

1. it reads or writes `HexaVal` representation bits (NaN-box tag macros
   `HX_INT`/`HX_FLOAT`/`HX_IS_*`, the struct layout), **or**
2. it is on the allocation hot path (arena, `malloc` wrappers,
   `hexa_array_new`/`_push` primitive memory ops), **or**
3. hexa codegen emits a direct call to it in essentially every program
   (`hexa_int`/`hexa_float`/`hexa_str` constructors, `hexa_add`,
   `hexa_index_get`, `hexa_len`), **or**
4. `runtime_hi.hexa`'s own transpiled C depends on it (transitive closure of 1–3).

Everything else → `runtime_hi.hexa` (string methods, math wrappers,
`hexa_array_map`/`_filter`/`_reduce`, formatting, the `hexa_str_*` UTF-8
family, `__hexa_range_array`, file/IO helpers that are thin shells over libc).

### 4.2 Honest target

ROADMAP 69 names "≤500 lines" for `runtime_core.c`. That is **aspirational**;
the real number is whatever the §4.1 closure yields and will be **measured in
phase 061-P0**, not assumed. If the irreducible core lands at 700–900 lines the
RFC is still satisfied — the deliverable is *a clean 2-layer split*, not a
line-count.

## 5. Phasing

| Phase | Deliverable | Gate |
|-------|-------------|------|
| **061-P0** | Boundary-analysis ledger — classify all ~191 `hexa_*` functions core-vs-hi per §4.1. Audit-only, **zero code move**. | ledger reviewed; core line-count estimated |
| **061-P1** | Extract `runtime_core.c` — move the core set out; `runtime.c` `#include`s it. Byte-identical behavior (pure file split). | self-host fixpoint + atlas 118/118 + full corpus byte-eq |
| **061-P2** | Author `runtime_hi.hexa` for tranche 1 (string methods — the smallest self-contained group). Transpile → `runtime_hi.c`, link, retire the C originals. | per-fn byte-eq vs the C original; corpus regression 0 |
| **061-P3** | Migrate remaining tranches (math, array HOFs, formatting); delete migrated C from `runtime.c`; `runtime.c` becomes `runtime_core.c` + `#include "runtime_hi.c"`. | full corpus + self-host fixpoint + atlas |

Each phase is an independent reviewable cycle. P1 is risk-free (file split). P2
onward each carry a byte-eq falsifier per migrated function.

## 5b. Phase 061-P0 — boundary ledger (COMPLETE 2026-05-19)

`self/runtime.c` = **13,336 lines**, **522** `hexa_*`-prefixed function
definitions (the §2 "~191" estimate was low — measured count is 522). Category
classification per the §4.1 criterion:

| Category | n | Layer | Rationale |
|----------|---|-------|-----------|
| `val` / `valstruct` / `struct` / constructors (`hexa_int/float/str/bool/void`) | ~26 | **CORE** | manipulate HexaVal representation bits (§4.1-1) |
| `cmp` / `is` / `truthy` / tag inspection | ~18 | **CORE** | read NaN-box tag (§4.1-1) |
| `ptr` / `null` | ~9 | **CORE** | raw pointer / representation (§4.1-1) |
| `array` primitives (new/push/get/set/len) | ~15 of 59 | **CORE** | allocation hot path + universal codegen calls (§4.1-2,3) |
| `map` primitives (new/set/get) | ~8 of 21 | **CORE** | universal codegen calls (§4.1-3) |
| arithmetic (`add`/`sub`/…) | ~12 | **CORE** | codegen emits everywhere (§4.1-3) |
| arena / alloc | ~10 | **CORE** | allocation hot path (§4.1-2) |
| `array` HOFs (map/filter/reduce/sort/slice) | ~44 of 59 | HI | expressible in hexa over the primitives |
| `str` (string methods) | 39 | HI | the natural P2 tranche-1 |
| `math` | 34 | HI | thin libm wrappers |
| `farr` (flat/unboxed array) | 67 | HI | specialized array tier — built over primitives |
| `term` (ANSI) · `exec` · `format` · `json` · `regex` · `utc`/`time` · `host` · `pad` | ~70 | HI | libc/OS shells + pure logic |
| `safetensors` · `tensor` · `ad` · `ansatz` · `adamw` · `phi` · `ham` · `swiglu` · `softmax` · `rms` (ML tier) | ~70 | HI | pure hexa-expressible numerics |
| remaining misc | ~30 | mixed | resolved per-function in P1 |

**Estimated CORE set ≈ 98–120 functions.** At a measured runtime.c mean of
~18 lines/function plus the struct/macro/`#include` preamble (~600 lines of
non-function CORE: the HexaVal union, NaN-box macros, tag constants), the
honest **`runtime_core.c` projection is ≈ 2,400–3,000 lines** — **NOT ≤500**.

**This is the P0 finding the RFC §4.2 explicitly anticipated.** The ROADMAP-69
"≤500" figure is unachievable: the irreducible C core (representation + allocator
+ universal-codegen primitives) is ~2.4–3 k lines. The RFC deliverable stands —
*a clean 2-layer split* — but the ROADMAP target line is corrected here from
"≤500" to "**≈2.5 k core / ≈10.8 k hi**". P1 should be re-gated on "core
contains only §4.1-qualifying functions", not on a line count.

**Gate for P1 start:** ledger reviewed + core size measured. ✅ P0 COMPLETE.

## 6. Falsifier battery (pre-registered)

1. **F1 self-host fixpoint** — after every phase, `hexa cc --regen` produces a
   byte-identical `hexa_cc.c` (the toolchain still reproduces itself).
2. **F2 atlas** — `atlas_verify_smoke` holds 118/118.
3. **F3 per-function byte-eq** — for each function moved to `runtime_hi.hexa`,
   a fixture exercising it produces byte-identical output before/after.
4. **F4 corpus regression** — the 100-test `test/*.hexa` corpus: 0 new FAIL.
5. **F5 no perf cliff** — `runtime_hi` functions are `-O2` like the C originals;
   a bench spot-check (array map/reduce, string ops) shows no >5 % wall regression.

## 7. Honest caveats (g3 / g5)

- The ≤500-line core target may not be literally reachable — §4.2. Reported as
  measured, not assumed.
- `runtime_hi.hexa` is **not** a runtime-loaded module (§3) — it is hexa source
  compiled ahead. Anyone expecting "the runtime is now hot-swappable hexa" is
  wrong; the win is *authorship* in hexa + a small auditable C core.
- This is a **re-layering, not a rewrite**. No runtime *behavior* changes. A
  phase that cannot prove byte-eq does not land.
- g5 (hexa-native-only): this RFC *advances* g5 for the runtime layer but does
  not complete it — `runtime_core.c` stays C by necessity (it is what hexa
  compiles *through*). That irreducible C core is policy-compliant: g5 permits
  the runtime substrate, it forbids LLVM/C-transpile *codegen backends*.

## 8. Non-goals

- Not changing any runtime function's behavior or signature.
- Not making the runtime loadable/pluggable.
- Not touching `self/native/` GPU/OS-shim C (separate layer, see AGENTS.tape
  `@N native_dir`).
- Not a perf project — §6 F5 is a guard-rail, not an objective.

## 9. Cross-link

- ROADMAP child **69** (this RFC scopes it).
- `HEXA-NATIVE-ONLY.md` — the runtime-layer self-hosting end-state.
- AGENTS.tape `@D g5` (hexa-native-only) — §7 caveat.
- Sibling self-host children: 65 (RFC 062), 66/67/68 (closed 2026-05-19).

## 10. PLAN integration

Tracked in `compiler/PLAN.md`. On greenlight, 061-P0 (boundary ledger) is the
first cycle — cheap, audit-only, and it produces the measured core line-count
that confirms or revises the ≤500 target before any code moves.
