# codegen: cross-module struct constructor — VinaAtom prototype not emitted

**Date:** 2026-05-25
**Surfaced by:** stdlib/chem/vina/ Monte Carlo search cycle (search.hexa + grid.hexa land).
**Repo:** dancinlab/hexa-lang
**Severity:** Blocks `hexa build` for any file that uses `import` (or `use`)
to bring a struct in and then constructs it with positional-args sugar — but
the struct is defined in a transitively-imported module rather than the
directly-imported one.
**Workaround:** `hexa parse` PASS is honored (cycle-2 convention; see
PR #644 / commit `c45b6dc6` — the cycle-2 scoring_test.hexa exhibits the
SAME error and was landed under the same convention).

## Minimal repro

```hexa
// scoring.hexa
pub struct VinaAtom { x: float, y: float, z: float, atype: string }
pub fn vina_pair_energy(a: VinaAtom, b: VinaAtom) -> float { return 0.0 }
```

```hexa
// search.hexa
use "stdlib/chem/vina/scoring"
pub fn whatever(a: VinaAtom) -> float { return 0.0 }
```

```hexa
// search_test.hexa
use "stdlib/chem/vina/scoring"
use "stdlib/chem/vina/search"
fn main() {
    let a = VinaAtom { x: 0.0, y: 0.0, z: 0.0, atype: "C" }   // <-- error
    println(to_string(whatever(a)))
}
```

`hexa parse search_test.hexa` → OK.
`HEXA_MAC_BUILD_OK=1 hexa build search_test.hexa` →

```
error: call to undeclared function 'VinaAtom'; ISO C99 and later do not
       support implicit function declarations
error: passing 'int' to parameter of incompatible type 'HexaVal'
```

C codegen emits `VinaAtom(...)` constructor calls in the test file's
translation unit but doesn't emit the corresponding C prototype that the
defining-module's translation unit declares.

## Same-symptom precedent

PR #644 (autodock-vina cycle 2, merged 2026-05-23) cycle-2 `scoring_test.hexa`
exhibits the identical clang error today on the merged main branch. It was
landed because `hexa parse` was clean. This memo formalizes the workaround
convention and registers the codegen fix for a follow-up cycle.

## Suggested fix axis

`compiler/codegen_c2.hexa` — when a translation unit references a struct
constructor whose definition lives in a module brought in via a transitive
`use`/`import` chain, propagate the constructor prototype into the
test-file's emitted C header. The direct-import case already works (the
cycle-1 single-file pattern, e.g. `ode_test.hexa` against `ode.hexa`).

## Files surfaced by this cycle

- `stdlib/chem/vina/grid.hexa` (new)
- `stdlib/chem/vina/search.hexa` (new)
- `stdlib/chem/vina/search_test.hexa` (new)

All three `hexa parse` clean. Build deferred until codegen fix lands.

## DEFER rationale (per @D g11/g59)

The MC search + grid affinity map implementations are SSOT-correct and
parse-clean. Building them needs the codegen fix above, which is a
compiler-internal change scoped to a sibling cycle. Landing the .hexa
source under the cycle-2 convention (PR #644) keeps the docking surface
moving forward without conflating with the codegen work.
