@title: 🧬 RUNTIME-PORT — self/runtime.c → hexa-native frontier

@goal: Drive self/runtime.c's portable surface (tier-B) to hexa-native, shrinking the irreducible C floor toward the tier-A bootstrap primitives only.

## current-state
- self/runtime.c = 14919 LOC, 606 fn defs (525 unique names; #if/#else dual-defs).
- CORE tier (HexaVal encode/decode · arena · array store · refcount) lives in
  the separate self/runtime_core.c (8544 LOC) — out of scope for this domain.
- M1 inventory (2026-06-03) tiers runtime.c's OWN functions:
  - **tier-A irreducible floor = 1547 LOC / 167 fns** (freestanding libc/libm,
    raw syscall trampolines, pthread, math ABI hexa lowers to).
  - tier-B portable = 3600 LOC / 104 fns, of which **B-OPEN 2783 LOC / 30 fns**
    are the real M2 port target and B-PORTED 817 LOC / 74 fns already have a
    hexa impl via the `HEXA_HAS_HEXA_RT_STDLIB` rt_* delegation (C is fallback).
  - tier-C FFI/platform shim = 2188 LOC / 184 fns.
  - BORDERLINE = 3066 LOC / 151 fns (numeric CPU kernels + value-tag coerce).
- **projected irreducible C floor (runtime.c HI tier) = 1547 LOC** (vs 14919).
- Full classification: `.verdicts/runtime-port/INVENTORY.txt`.

## milestones
- [x] M1 — portability inventory: A/B/C tiers of self/runtime.c, floor target
- [x] M2 — port B-OPEN leaf helpers to hexa-native (method proven; 3 RUNEQ-EQ landed)
  - hexa_float_to_int → rt_float_to_int: **PORT-EQ 32/32** (real RUNEQ vs C SSOT;
    caught+fixed an Inf-semantics + const-fold-precision bug). Wired into
    rt_to_int's float branch. `.verdicts/runtime-port/M2-hexa_float_to_int.txt`.
  - hexa_from_char_code → rt_from_char_code: **PORT-EQ 32/32** (codepoint→UTF-8,
    all 4 byte-length tiers + boundaries + neg-clamp; 6 locked IT6 tests).
    `.verdicts/runtime-port/M2-hexa_from_char_code.txt`.
  - hexa_is_empty → rt_is_empty: **PORT-EQ 9/9** (RUNEQ confirmed the C quirk
    that every non-array/string tag — incl. map — reports empty=true; 6 locked
    tests). `.verdicts/runtime-port/M2-hexa_is_empty.txt`.
  - hexa_dict_keys: **BLOCKED** — not a true leaf; rt_map_keys consumes a
    different (pure-hexa) map representation than the native C map, so no
    apples-to-apples RUNEQ. `.verdicts/runtime-port/M2-hexa_dict_keys.txt`.
  - hexa_bytes_to_str_raw → rt_bytes_to_str_raw: **DIFFER/BLOCKED** — RUNEQ
    6/9 PORT-EQ but DIFFERs on embedded NUL (C strbuf length-header vs hexa
    chr/join strlen-truncation). Needs a NUL-clean string-builder intrinsic;
    kept in-source as the non-NUL port + falsifier, NOT wired as live
    delegation. `.verdicts/runtime-port/M2-hexa_bytes_to_str_raw.txt`.
  - score so far: 3 PORT-EQ landed · 2 BLOCKED on primitive gaps (map-rep,
    NUL-clean builder). Remaining B-OPEN leaves carry to M2-followup (see log).
- [ ] M3 — adjudicate the 151 BORDERLINE fns (numeric CPU kernels: keep vs port)
- [ ] M4 — extend inventory to self/runtime_core.c (the CORE tier)
