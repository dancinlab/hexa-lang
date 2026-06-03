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
- [ ] M2 — port the top-10 B-OPEN leaf helpers to hexa-native
- [ ] M3 — adjudicate the 151 BORDERLINE fns (numeric CPU kernels: keep vs port)
- [ ] M4 — extend inventory to self/runtime_core.c (the CORE tier)
