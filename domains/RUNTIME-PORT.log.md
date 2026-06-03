# RUNTIME-PORT — append-only step log

@goal: port self/runtime.c's portable (tier-B) surface to hexa-native, exposing
the irreducible tier-A bootstrap floor. See RUNTIME-PORT.md for the snapshot.

## 2026-06-03 — M2 leaf ports

Conservative M2 pass — prove the RUNEQ method on the smallest/safest B-OPEN
leaves. Local-only (mini); no ghost/pool consumed.

Per-fn results:

| C SSOT | hexa port | LOC ported | verdict |
|--------|-----------|-----------|---------|
| hexa_float_to_int (runtime.c L5812) | rt_float_to_int (self/rt/convert.hexa) | 14 | **PORT-EQ 32/32** |
| hexa_dict_keys (runtime.c L11887) | — | 0 | **BLOCKED** |

- **hexa_float_to_int → rt_float_to_int** — saturating float→int64 coerce.
  RUNEQ = real: transpiled the hexa port via `hexat`, linked it against the
  SHIPPING runtime.o (which carries the C SSOT hexa_float_to_int), and a C
  harness fed 32 representative doubles (zero/±0 · frac trunc · large finite ·
  exact 2^63 boundary · >boundary · NaN · ±Inf · largest-finite-<2^63) to BOTH
  fns, comparing int64 results. 32/32 identical. The RUNEQ caught TWO real
  bugs in-flight: (a) ±Inf must return 0 (C's isinf() guard fires before the
  boundary test — first draft saturated Inf → DIFFER); (b) a constant-folder
  precision trap that truncated the negated 2^63 bound to 6 sig figs. Both
  fixed, then re-RUNEQ → PORT-EQ. Wired into the live rt path: rt_to_int()'s
  float branch now dispatches to rt_float_to_int (was the broken `int_of`
  stub which returns 0). +5 locked assertions in test_convert.hexa. Verdict:
  `.verdicts/runtime-port/M2-hexa_float_to_int.txt`.
- **hexa_dict_keys** — BLOCKED. The "1 LOC dispatch" hides a whole-map-
  representation gap: hexa_map_keys iterates the NATIVE C hashmap; rt_map_keys
  iterates a SEPARATE pure-hexa functional map. No same-object RUNEQ possible
  at the leaf level. Deferred to a map-representation port milestone. Verdict:
  `.verdicts/runtime-port/M2-hexa_dict_keys.txt`.

M2-followup (carry-over B-OPEN leaves not attempted this pass): hexa_find_poly,
hexa_contains_poly, hexa_array_position, hexa_array_concat, and the rest of the
30-fn B-OPEN set. The float_to_int recipe (hexat transpile → link vs shipping
runtime.o → C-harness value-diff) is the reusable RUNEQ template for them.

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
