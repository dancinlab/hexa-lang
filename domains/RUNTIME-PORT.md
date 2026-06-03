@title: 🧬 RUNTIME-PORT — self/runtime.c → hexa-native frontier

@goal: Drive self/runtime.c's portable surface (tier-B) to hexa-native, shrinking the irreducible C floor toward the tier-A bootstrap primitives only.

## current-state
- self/runtime.c = 14919 LOC, 606 fn defs (525 unique names; #if/#else dual-defs).
- CORE tier (HexaVal encode/decode · arena · array store · refcount) lives in
  the separate self/runtime_core.c (8544 LOC) — inventoried in M4 (2026-06-03):
  198 A / 57 B-PORTED / 9 B-OPEN / 22 C (286 unique fns). ~90% irreducible or
  already-ported; only 9 new portable leaves / 110 LOC remain (M5 optional).
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
  - hexa_dict_keys → map_keys_pure: **PORT-EQ (live-wired)** — prior BLOCKED
    verdict was a FACTUAL ERROR, now corrected. map_keys_pure was literally
    `return keys(m)` (self-referential re-entry into the C SSOT — never ported
    the walk), NOT a separate map-rep. Rewrote the body as an explicit
    insertion-order walk over the SAME native HexaMapTable via the already-
    registered __map_raw_len + __map_order_key_at builtins (+13/-1 LOC, one
    file; zero new builtin, zero ABI/rep change — Class A). RUNEQ byte/order-
    identical vs the C SSOT across empty · 1 · many · dedup-on-overwrite ·
    40-key collision-stress · interleaved · NUL-bearing keys (all PASS, LOCAL
    on mini, B1 self-contained-link pattern; no global regen). map_pure.hexa
    recompiles into the self-host set → codegen byte-eq gate (same gate-class
    as B1; ghost selfhost-byteeq-real is the parent's merge gate, NOT run here).
    `.verdicts/runtime-port/M2-dict_keys.txt` (DICTKEYS-FEAS #2633 superseded
    by this live-wire; M2-hexa_dict_keys.txt BLOCKED SUPERSEDED).
  - hexa_bytes_to_str_raw → rt_bytes_to_str_raw: **PORT-EQ (B1 closed)** —
    RUNEQ 9/9 byte-exact (incl all 3 embedded-NUL cases) after the B1
    str_from_bytes_n length-carrying builder builtin landed. The hexa body
    keeps its range-guard loop and delegates final assembly to the NUL-clean
    builder (→ hexa_bytes_to_str_raw / hexa_strbuf_alloc length header). Proven
    end-to-end: regenerated hexat lowers str_from_bytes_n → hexa_bytes_to_str_raw,
    emitted code 9/9 PORT-EQ. `.verdicts/runtime-port/M2-bytes_to_str_raw.txt`
    (codegen fixpoint byte-eq validated on ghost selfhost-byteeq-real).
  - score so far: 5 PORT-EQ landed (incl. hexa_dict_keys live-wired — the last
    portable leaf, prior BLOCKED corrected). The NUL-clean builder gap is CLOSED
    (STRBUILDER-FEAS B1). NO remaining hard-BLOCKED portable leaf. Remaining
    B-OPEN leaves carry to M2-followup (see log).
- [ ] M3 — adjudicate the 151 BORDERLINE fns (numeric CPU kernels: keep vs port)
- [x] M4 — extend inventory to self/runtime_core.c (the CORE tier) — DONE 2026-06-03.
  Tiered all 286 unique fns (363 defs) / 5531 body-LOC of the 8544-line file:
  - **tier-A irreducible CORE floor = 4011 LOC / 198 fns** (codegen-escape
    __raw_*, arena/GC/intern/heapify, map-rep hash table, value-tag ctors,
    array backing store, libm, call/try ABI — the bootstrap bedrock M1 deferred).
  - **B-PORTED = 900 LOC / 57 fns** — hexa impl ALREADY in rt-stdlib (88
    HEXA_HAS_HEXA_RT_STDLIB guards -> 83 distinct rt_*; C body is fallback only).
    The rt_* drainage is already deep in core too; the surface is NOT virgin.
  - **B-OPEN (NEW portable frontier) = only 110 LOC / 9 fns**, top 7 either
    Class-A-today (cmd_has_shell_meta · utf8_cpcount · null_coal · byte_at ·
    char_code_at) or dict_keys-class (str_concat · str_substring · char_code_at
    already have an rt_ hexa impl — only the delegation guard is missing).
    NO B1-class new-builtin gap (STRBUILDER-FEAS B1 already closed the builder),
    NO hard-BLOCKED Class-C leaf.
  - tier-C FFI/process/stdio/throw shim = 510 LOC / 22 fns.
  - **VERDICT: runtime_core.c is ~90% irreducible-or-already-ported. It is the
    bootstrap/codegen-support floor it was declared to be — NOT a second
    runtime.c-scale portable well.** Full tiering:
    `.verdicts/runtime-port/M4-INVENTORY.txt`.
- [ ] M5 (optional) — wire the 9 core B-OPEN leaves (delegation-guard / Class-A
  byte loops; dict_keys/B1 pattern, RUNEQ-gated). Low-risk mechanical follow-up.
