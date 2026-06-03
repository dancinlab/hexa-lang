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
  - hexa_dict_keys: **CLASS A (feas)** — prior BLOCKED verdict CORRECTED. The
    "separate map-rep" claim was a factual error: map_keys_pure(m) is literally
    `return keys(m)` and walks the SAME native HexaMapTable as the C SSOT (the
    real defect is that self-referential re-entry, not a rep mismatch). Portable
    hexa-native TODAY via the already-registered __map_raw_len +
    __map_order_key_at order-walk primitives — zero new builtins, zero ABI/rep
    change (strictly less work than B1). Ready-to-apply hexa-source patch + RUNEQ
    evidence in `.verdicts/runtime-port/DICTKEYS-FEAS.txt`. Live-wire deferred to
    a reviewed impl PR (map_pure.hexa recompiles into the self-host set → codegen
    byte-eq gate, same gate-class as B1). `.verdicts/runtime-port/M2-hexa_dict_keys.txt`
    (SUPERSEDED).
  - hexa_bytes_to_str_raw → rt_bytes_to_str_raw: **PORT-EQ (B1 closed)** —
    RUNEQ 9/9 byte-exact (incl all 3 embedded-NUL cases) after the B1
    str_from_bytes_n length-carrying builder builtin landed. The hexa body
    keeps its range-guard loop and delegates final assembly to the NUL-clean
    builder (→ hexa_bytes_to_str_raw / hexa_strbuf_alloc length header). Proven
    end-to-end: regenerated hexat lowers str_from_bytes_n → hexa_bytes_to_str_raw,
    emitted code 9/9 PORT-EQ. `.verdicts/runtime-port/M2-bytes_to_str_raw.txt`
    (codegen fixpoint byte-eq validated on ghost selfhost-byteeq-real).
  - score so far: 4 PORT-EQ landed · hexa_dict_keys re-classed BLOCKED→CLASS A
    (DICTKEYS-FEAS; ready patch, byte-eq-gated impl PR pending). The NUL-clean
    builder gap is CLOSED (STRBUILDER-FEAS B1). No remaining hard-BLOCKED
    portable leaf — the last one (dict_keys) is now a known Class-A unblock.
    Remaining B-OPEN leaves carry to M2-followup (see log).
- [ ] M3 — adjudicate the 151 BORDERLINE fns (numeric CPU kernels: keep vs port)
- [ ] M4 — extend inventory to self/runtime_core.c (the CORE tier)
