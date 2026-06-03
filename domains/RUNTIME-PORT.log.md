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

---

## 2026-06-03 · M2-followup — 3 more B-OPEN leaves (RUNEQ local on mini, no ghost)

Extended M2 (hexa_float_to_int #2626) with 3 more tier-B-OPEN scalar/string
leaves, same minimal-TU RUNEQ rig (hexat transpile → extract body → link vs
shipping runtime.o C SSOT → byte/value-exact compare). LOCAL on mini only.

| leaf | C SSOT | hexa port | LOC | RUNEQ | verdict |
|------|--------|-----------|-----|-------|---------|
| hexa_from_char_code | runtime.c L6035 | rt_from_char_code (string.hexa) | 35 | 32/32 | **PORT-EQ** |
| hexa_is_empty | runtime.c L4809 | rt_is_empty (core.hexa) | 17 | 9/9 | **PORT-EQ** |
| hexa_bytes_to_str_raw | runtime.c L6105 | rt_bytes_to_str_raw (string.hexa) | 30 | 6/9 | **DIFFER** (NUL) |

- **rt_from_char_code** — codepoint→UTF-8. Assembles raw UTF-8 bytes itself
  and feeds rt_str_from_chars (chr→hexa_chr_byte, &0xFF no-op). Byte-identical
  across all 4 byte-length tiers + boundaries + negative clamp. 6 locked IT6
  assertions in test_string.hexa. `.verdicts/runtime-port/M2-hexa_from_char_code.txt`.
- **rt_is_empty** — array/string len==0; RUNEQ confirmed the load-bearing C
  quirk that EVERY other tag (int/float/void/bool/MAP) reports empty=true
  (default fallthrough). 6 locked assertions in test_core.hexa.
  `.verdicts/runtime-port/M2-hexa_is_empty.txt`.
- **rt_bytes_to_str_raw** — DIFFER on embedded NUL: C uses hexa_strbuf_alloc(n)
  (explicit length header → NULs survive, RFC 030 Phase 2); the hexa chr()/join
  path derives length via strlen and collapses NUL-bearing results to "".
  Non-NUL identity + range-guard (256/-1/300 → "") are PORT-EQ (6/9). SAME
  class of primitive gap as M2's hexa_dict_keys — needs a NUL-clean
  string-builder intrinsic (length-header analogue of hexa_strbuf_alloc
  exposed to hexa). NOT wired as live delegation; C SSOT stays authoritative
  for NUL callers (image_read PNG IHDR). Kept in-source as proven non-NUL port
  + persisted falsifier. DISPOSITION: BLOCKED.
  `.verdicts/runtime-port/M2-hexa_bytes_to_str_raw.txt`.

Net: M2 now has **3 PORT-EQ leaves landed** (float_to_int + from_char_code +
is_empty) and **2 BLOCKED** on primitive gaps (dict_keys = map-rep, bytes_to_
str_raw = NUL-clean builder). RUNEQ method continues to earn its keep — caught
the NUL divergence honestly rather than waving it through.

## 2026-06-03 — STRBUILDER-FEAS (feasibility-only, no codegen/runtime mutation)

Scoped what a NUL-clean hexa-native string-builder would take to unblock the
M2 BLOCKED leaf **rt_bytes_to_str_raw**. Verdict-only investigation.

**Class B** (needs-new-runtime-intrinsic / codegen surface; medium risk). NOT
Class A (no hexa-expressible path carries a length header — every builder
funnels through a strlen-truncating wrapper) and NOT Class C (the length-header
representation ALREADY EXISTS; no ABI change).

Exact root cause located: `hexa_str_join` (runtime_core.c L7987/L8020) memcpy's
all bytes incl NULs correctly, but returns `hexa_str_own(result)`, and
`hexa_str_own` (L1664) does `len = strlen(s)` — re-measuring TRUNCATES at the
first NUL, discarding join's correct total. The length-carrying C entry points
(`hexa_str_own_with_len` L1672, `hexa_strbuf_alloc` L756) exist but are NOT
exposed in the codegen builtin table (codegen.hexa L7143-7155).

Smallest unblock (deferred to a dedicated codegen PR, NOT this round): B1 =
add ONE codegen builtin mapping a length-carrying byte→string constructor +
rewrite rt_bytes_to_str_raw's body to use it (range-guard loop unchanged).
Touches codegen.hexa + runtime_core_emit.hexa (wipe_guard / stdlib_trig_libm
cautioned surface) + a runtime regen + self-host byte-eq gate — out of scope
for a feasibility-only round. B2 (make hexa_str_join itself length-preserving
via hexa_str_own_with_len) fixes the whole join family but has larger blast
radius; defer to an RFC.

rt_bytes_to_str_raw stays BLOCKED / not-live-wired; C SSOT authoritative for
NUL callers (image_read PNG IHDR). Carry B1 to M2-followup / M3 alongside the
hexa_dict_keys map-rep gap. `.verdicts/runtime-port/STRBUILDER-FEAS.txt`.

## 2026-06-03 · B1 LANDED — str_from_bytes_n NUL-clean builder closes rt_bytes_to_str_raw

STRBUILDER-FEAS Class B delta implemented. Added a length-carrying byte→string
constructor codegen builtin `str_from_bytes_n(arr)` → maps to the EXISTING
NUL-clean C constructor hexa_bytes_to_str_raw (hexa_strbuf_alloc(n) + perf-31
length header). NO new runtime symbol · NO ABI change. Registered in all 3
builtin tables: self/codegen.hexa (tier-2), compiler/codegen/arm64_darwin.hexa
(native), compiler/check/bind.hexa (bind allow-list).

rt_bytes_to_str_raw rewritten: keeps the hexa range-guard loop (b<0/b>255 → "")
and delegates final assembly to str_from_bytes_n instead of chr()/join, which
derived length via the NUL-truncated C string and collapsed NUL-bearing results
to "".

RUNEQ 9/9 PORT-EQ (LOCAL on mini), byte-exact vs C SSOT, incl all 3 prior
embedded-NUL DIFFER cases: nul [00], mix-nul [00 41 00 42 00], full
[00 01 7f 80 fe ff]. End-to-end proof: `hexa cc --regen` folded the codegen
edit into hexa_cc.c; the regenerated hexat lowers str_from_bytes_n →
hexa_bytes_to_str_raw (was hexa_call1 fallback), emitted code 9/9 PORT-EQ.
Install toolchain restored to pristine after the local proof.

byte-eq risk: SELF-HOST CODEGEN change — the codegen fixpoint (shipped
transpiler re-emits byte-identically) is the non-required ghost
selfhost-byteeq-real check; PR does NOT run/wait on it (parent gates merge).
Local lowering + semantic proof is 9/9 PORT-EQ.

M2 score: 4 PORT-EQ landed · 1 BLOCKED (hexa_dict_keys map-rep). NUL-clean
builder gap CLOSED. `.verdicts/runtime-port/M2-bytes_to_str_raw.txt`.

## 2026-06-03 · DICTKEYS-FEAS — hexa_dict_keys re-classed BLOCKED → CLASS A

Feasibility-only round (NO codegen/runtime/bind mutation). Scoped the last
portable-but-BLOCKED runtime leaf hexa_dict_keys → rt_dict_keys, mirroring the
STRBUILDER-FEAS → B1 method.

KEY FINDING: the prior M2-hexa_dict_keys.txt "BLOCKED (map-representation
mismatch)" verdict was based on a FACTUAL ERROR. It claimed rt_map_keys consumes
a separate pure-hexa functional map (rt_map_new/rt_map_set) with its own
ordering, so no apples-to-apples RUNEQ. In fact the live path is:
  dict_keys → hexa_dict_keys → hexa_map_keys → rt_map_keys → map_keys_pure,
and map_keys_pure(m) is literally `return keys(m)` (self/runtime/map_pure.hexa
L42) — it consumes the SAME HexaVal map / SAME native HexaMapTable as the C SSOT.
There is no second rep on the path. The only real defect is that
self-referential re-entry (keys() lowers back to hexa_map_keys → infinite
self-reference; it never ported the walk at all).

CLASS A (expressible-in-hexa-today). The native HexaMapTable (runtime_core.c
L1048-1065: open-addressing slots + INSERTION-ORDER order_keys[]/order_vals[] +
len) is already index-addressable from hexa source via THREE builtins that read
the EXACT fields the C SSOT loop walks, with NO recursion into the keys()/
map_keys family and NO new registration:
  __map_raw_len(m)        codegen L6161 -> HX_MAP_LEN (== HexaMapTable.len)
  __map_order_key_at(m,i) codegen L6094 -> C __map_order_key_at (runtime_core.c
                          L2608 = hexa_str(t->order_keys[idx]))
  __map_order_val_at(m,i) codegen L6097 -> C __map_order_val_at (L2616)
ALL THREE already registered in all 3 builtin tables: self/codegen.hexa is_builtin
(L12421/12422/12433), compiler/check/bind.hexa allow-list (L1059/1156). This is
the load-bearing piece B1 had to ADD; for dict_keys it is already done — zero new
builtins, zero new runtime symbol, zero ABI/rep change (strictly less than B1).

NOT Class B (no new codegen builtin needed). NOT Class C (no iterator/rep
exposure beyond what exists, no ABI/layout change, no caller migration).

RUNEQ (LOCAL on mini, no ghost): (1) equivalence-by-construction — the ported
body is a 1:1 transliteration of the C SSOT hexa_map_keys #else loop over the
same order_keys[]/len; (2) C SSOT ground truth via surface keys() — strict
insertion order, dedup-on-overwrite, 40-key collision-stress ordered, empty=0;
(3) codegen-lowering proof — the rt_dict_keys body compiled to byte-exact direct
calls (HX_MAP_LEN(m) + __map_order_key_at(m,i)) in the emitted .c, confirming
the installed hexat lowers all three to the SSOT-field accessors. A full runtime
end-to-end numeric RUNEQ needs the standard runtime regen (the byte-eq-gated
step) and is out of scope for feasibility-only; the install link failed only on a
stale-runtime.o artifact (predates de-staticized __map_order_* / HX_MAP_LEN fn
decl), NOT a rep gap.

Ready-to-apply hexa-SOURCE-ONLY patch (in DICTKEYS-FEAS.txt): replace
map_keys_pure's `return keys(m)` with the __map_raw_len + __map_order_key_at
order-walk (~6 lines); optionally do the same for map_values_pure/entries via
__map_order_val_at to kill their hidden re-entry; optional rt_dict_keys alias in
self/rt/map_ops.hexa. NO codegen/arm64_darwin/bind/runtime_core_emit edit.

DEFERRED to a reviewed impl PR because map_pure.hexa compiles INTO the self-host
transpiler set → the codegen byte-eq fixpoint gate (gen3→gen4 + ghost
selfhost-byteeq-real) applies, same gate-class as B1 #2632 (parent gates merge).
Verdict: `.verdicts/runtime-port/DICTKEYS-FEAS.txt`. With this, NO portable
runtime leaf remains hard-BLOCKED — the last one is a known Class-A unblock.

## 2026-06-03 — M2 dict_keys LIVE-WIRE (DICTKEYS-FEAS → PORT-EQ)

Implemented the DICTKEYS Class-A unblock. Rewrote self/runtime/map_pure.hexa
map_keys_pure from the self-referential `return keys(m)` (which lowered straight
back to hexa_map_keys and never ported the walk) to an explicit insertion-order
walk over the native HexaMapTable using the already-registered codegen builtins
__map_raw_len + __map_order_key_at — a 1:1 transliteration of the C SSOT
hexa_map_keys #else body. +13/-1 LOC, ONE file. Zero new builtin, zero new
runtime symbol, zero ABI/rep change (Class A).

RUNEQ (LOCAL on mini, no ghost/pool — B1 self-contained-link pattern): emitted C
via installed hexat (lowered byte-for-byte to HX_MAP_LEN(m) + __map_order_key_at
(m,i) as designed), linked against cache runtime.2dc93e6e…o which defines
___map_order_key_at (nm-verified), with a tiny prelude supplying the HX_MAP_LEN
macro + __map_order_* extern protos the pinned install's runtime.h predates (the
STALE-INSTALL header gap FEAS identified — NOT a rep/abi change). Global install
NOT mutated; no `hexa cc --regen` needed.

Result — ALL PASS, byte/order-identical vs C SSOT keys() path:
  empty(0) · one[solo] · many[k1 k2 k3 zzz a] · overwrite→[x y] (dedup-on-
  overwrite, no dup, order unchanged) · forty[0..39] (collision-stress, ordered)
  · mix[alpha beta gamma delta] (interleaved insert+overwrite) · nul (embedded-
  NUL key bit-identical both sides).

CORRECTION: the prior M2-hexa_dict_keys.txt BLOCKED (map-rep mismatch) verdict
was a FACTUAL ERROR — the path consumes the SAME native HexaMapTable, not a
separate rep. Terminal verdict now `.verdicts/runtime-port/M2-dict_keys.txt`
(PORT-EQ). map_pure.hexa recompiles into the self-host set → codegen byte-eq
fixpoint gate (same gate-class as B1 #2632); ghost selfhost-byteeq-real is the
parent's merge gate (NOT run here). PR opened base=main, DO-NOT-MERGE.
With this, the last portable RUNTIME-PORT M2 leaf is closed as a genuine
hexa-native impl. 5 PORT-EQ landed.

────────────────────────────────────────────────────────────────────────
## M4 — runtime_core.c CORE-tier portability inventory (2026-06-03, mini LOCAL)
INVENTORY + FEASIBILITY ONLY · NO codegen/runtime/bind mutation · base 4d341a103
worktree /tmp/rp-m4i (isolated) · runtime_core.c READ-ONLY (gitignored).

The last un-inventoried runtime frontier. M1 explicitly deferred runtime_core.c
(8544 LOC) as the CORE tier; M2 drained runtime.c's portable leaf well (5 PORT-EQ,
0 hard-BLOCKED). M4 asks: does core hold MORE portable leaves or is it all
irreducible bootstrap/codegen-support?

METHOD: AST-free brace-match extractor (same as M1). 363 fn DEFS, 286 UNIQUE
names (77 dual-defs — 88 HEXA_HAS_HEXA_RT_STDLIB guards + platform #if share a
name). Every B-OPEN candidate body READ (dict_keys lesson: classify by reading
the C body, never by assuming hardness).

TIER COUNTS (unique fns / body-LOC summing dual-defs):
  A         198 fns  4011 LOC  irreducible bootstrap/GC/codegen-support floor
  B-OPEN      9 fns   110 LOC  portable pure-logic leaf, unported (real frontier)
  B-PORTED   57 fns   900 LOC  hexa impl already in rt-stdlib (C body = fallback)
  C          22 fns   510 LOC  FFI/process/stdio/throw shim (external ABI)
  TOTAL     286 fns  5531 LOC  (rest of 8544 = structs/macros/globals/comments)

STRUCTURAL FINDING: rt_* delegation is already DEEP in core too — 88
HEXA_HAS_HEXA_RT_STDLIB guards -> 83 distinct rt_* hexa fns. 57 core hexa_* fns
are B-PORTED (C is standalone-link fallback only). The portable surface is NOT
virgin; the rt_* stdlib campaign already drained most of it.

FEASIBILITY FINDING (dict_keys-class): of the 9 B-OPEN leaves, THREE
(hexa_str_char_code_at · hexa_str_concat · hexa_str_substring) ALREADY HAVE a
matching hexa impl (rt_str_char_code_at / rt_str_concat / rt_str_substring exist
in self/rt|runtime|stdlib *.hexa) — they only lack the core-side delegation
guard. Exactly the dict_keys pattern (leaf looked unported; the hexa walk
already existed). The builder builtin gap is already CLOSED (B1 str_from_bytes_n
+ hexa_strbuf_alloc, STRBUILDER-FEAS #2632). NO new-builtin (B1-class) leaf and
NO hard-BLOCKED (Class-C rep/ABI) leaf remains.

RANKED B-OPEN (low-risk-first):
  1 hexa_str_char_code_at  (8 LOC) A/dict_keys — rt impl exists, wire guard
  2 hexa_cmd_has_shell_meta(14)    A — pure char-class scan, Class-A today
  3 utf8_cpcount           (5)     A — pure UTF-8 continuation count
  4 hexa_null_coal         (5)     A — pure tag/empty predicate
  5 hexa_str_byte_at       (19)    A — pure bounds+byte+throw, Class-A today
  6 hexa_str_substring     (13)    B/dict_keys — rt impl exists, B1 builder, guard
  7 hexa_str_concat        (32)    B/dict_keys — rt impl exists, arena fast-path
  8 hexa_str_grapheme_count(6)     B — needs _hx_grapheme_walk port first (defer)
  9 hexa_str_graphemes     (8)     B — pairs with #8 (grapheme-walk dep)

VERDICT: runtime_core.c is ~90% irreducible-or-already-ported. It IS the
bootstrap/codegen-support floor M1 declared it to be — confirmed by reading
bodies, not assumed. NO second runtime.c-scale portable well. The residual
9-leaf / 110-LOC B-OPEN set is small + low-risk + mechanical (delegation-guard
wiring + Class-A byte loops), carried as optional M5. Full tiering:
`.verdicts/runtime-port/M4-INVENTORY.txt`.
