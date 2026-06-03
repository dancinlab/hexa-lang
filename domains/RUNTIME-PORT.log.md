# RUNTIME-PORT — append-only step log

@goal: port self/runtime.c's portable (tier-B) surface to hexa-native, exposing
the irreducible tier-A bootstrap floor. See RUNTIME-PORT.md for the snapshot.

## 2026-06-03 — M1 portability inventory

Classified all 606 function definitions in self/runtime.c (14919 LOC) into
A/B/C tiers via brace-match extraction + per-name-prefix rule + manual
adjudication of borderline bodies. Verdict: `.verdicts/runtime-port/INVENTORY.txt`.

Tier aggregates (runtime.c HI tier only; CORE primitives live in the separate
runtime_core.c, 8544 LOC, out of scope):

| tier | fns | LOC | meaning |
|------|-----|-----|---------|
| A (irreducible) | 167 | 1547 | freestanding libc/libm · raw syscall · pthread · math ABI |
| B-OPEN | 30 | 2783 | portable, NO hexa impl yet → **M2 target** |
| B-PORTED | 74 | 817 | portable, hexa impl already in rt-stdlib (C is fallback) |
| C (FFI/platform) | 184 | 2188 | dlopen/extern · fs/proc/net/clock shims · C-ABI struct |
| BORDERLINE | 151 | 3066 | numeric CPU kernels + value-tag coerce |

Key finding: 74 `#ifndef HEXA_HAS_HEXA_RT_STDLIB` guards already delegate 82
distinct helpers to hexa-native `rt_*` stdlib fns — so a large slice of tier-B
is ALREADY ported (C kept only as a fallback when the hexa stdlib is unlinked).

Projected irreducible C floor (tier-A) = **1547 LOC** vs current 14919.

### M2 port candidates — top-10 highest-tractability B-OPEN leaves
(smallest, fewest deps, no existing hexa impl; call only the core HexaVal API)

- `hexa_dict_keys` (1 LOC, L11887) — pure dispatch → hexa_map_keys
- `hexa_find_poly` (4 LOC, L4706) — array/str find polymorphic dispatch
- `hexa_contains_poly` (6 LOC, L4673) — str/array contains dispatch
- `hexa_float_to_int` (6 LOC, L5812) — scalar coerce, pure
- `_jp_skip_ws` (7 LOC, L12417) — JSON whitespace scan, pure string
- `hexa_is_error` (7 LOC, L6000) — tag predicate, pure
- `hexa_array_position` (8 LOC, L5358) — index-of-by-predicate, core API only
- `hexa_is_empty` (8 LOC, L4809) — len==0 predicate, pure
- `hexa_array_skip_while` (9 LOC, L5319) — combinator over core push/get
- `hexa_array_step_by` (9 LOC, L5397) — combinator over core push/get
