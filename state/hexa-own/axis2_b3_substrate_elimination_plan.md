
## A0 round-1 — array_core PROVEN (summer ON-path, 2026-07-12)

First family landed + verified. `resolve_native_array_core_seed` HEXA_RT_OWNOBJ branch (feat/axis2-b3-a0-ownobj,
default-OFF): with `HEXA_RT_OWNOBJ=1 HEXA_OWNOBJ_CC=<aprime>`, `stage_resolve_runtime_a` produced
`build/array_core_native.o` by own-emitting `stdlib/runtime/array_core.hexa` (`--backend=native --emit=obj
--target=x86_64-linux-gnu`) — **6/6 rt_array_*_native contract syms**, 4736B, ar'd into runtime.a, **no $CC
assemble**. Log: `B3-A0 OWN-OBJ: array_core via …aprime_cc --emit=obj (6/6 rt_array_*_native, TARGET=linux-
x86_64) → native element path`. So the A0 build-path swap works: the runtime member is now own-emit, not
`.s`+`$CC`. Default (flag-unset) path byte-identical (branch skipped). **Continuation**: replicate the
branch for the other 9 own-emit-GREEN families (map/intern/str/num/num_float/float_parse_exact/hexinfnan/
regex/valop — ideally refactored to one `_b3a0_ownobj_seed <fam> <src> <contract> <n>` helper), build
`tool/ownobj_member_parity_gate` (nm defined-global equality + RUN parity vs the `.s` seed), then the
`:-0`→`:-auto` flip PR after byteeq 3-target + install smoke.

## A0 member parity — 9/9 GREEN (tool/ownobj_member_parity_gate, summer 2026-07-12)

`ownobj_member_parity_gate` (nm defined-global set: own-emit member ⊇ `.s` seed contract) across the 10
round-0-GREEN families: **9/9 verifiable PASS** (str_core SKIP = its `.s` seed lives under a different
name, gate-path fix pending — not a failure). Contract counts (own = seed unless noted): array_core 8=8 ·
map_core 5=5 · intern_core 2=2 · num_core 1=1 · num_float_core 3=3 · float_parse_exact 17=17 ·
float_parse_hexinfnan 6=6 · **regex_rt own=82 ⊇ seed=6** (own-emit exports the internal Thompson/backtrack
helpers the `.s` seed had DEMOTED via `objcopy`; superset ⇒ still drop-in, but flags Fable's **E4** own
symbol-demotion when we want the ar'd member to also export exactly 6) · valop_core 10=10.

**A0 round-1 SAFETY is now triple-verified**: (round-0) own-emit compiles the seed `.hexa`; (ON-path)
array_core member own-emits + ar's with 6/6 syms + no `$CC`; (parity) every family's own-emit member is a
defined-global superset of its `.s` seed → drop-in under HEXA_RT_OWNOBJ. Remaining A0 work is **mechanical**:
add the same HEXA_RT_OWNOBJ branch (or the `_b3a0_ownobj_seed` helper) to the other 9 family blocks in
stage_resolve_runtime_a, then the `:-0`→`:-auto` flip after byteeq 3-target + install smoke. (regex_rt's
82⊇6 means its A0 flip should ride E4 or keep objcopy to hold the 6-symbol contract — noted.)

## A0 round-1 boundary — clean-simple EXHAUSTED at 5/10 (2026-07-12)

Landed + ON-path GREEN (5, all single-flag single-contract, parity-proven): **array_core · intern_core ·
num_core · float_parse_exact · float_parse_hexinfnan** — each own-emits under HEXA_RT_OWNOBJ with its 1-N
`rt_*_native` contract syms, no `$CC` assemble (PR #4900).

The remaining 5 are **all MULTI-FLAG / complex** — NOT uniform mechanical extensions; each needs
per-family flag→contract analysis (the own-emit member must set the RIGHT subset of native flags based on
which contract syms it exports), so they are separate careful units, not a sweep:
- **str_core** — 5 flags (HEXA_RT_STR_EQ/STARTS_WITH/ENDS_WITH/INDEX_OF/CONTAINS_NATIVE) × 5 contract syms;
  its `.s` seed is build-generated (absent in-tree → parity gate SKIP). The A0 branch must set each flag
  per the own-emit member's exported `rt_str_*_native`.
- **map_core** — HEXA_RT_MAP_NATIVE + the `rt_map_set_inplace_native` sub-contract under `-DHEXA_RT_MAP_NATIVE`.
- **num_float_core** — dual flag (HEXA_RT_NUM_PARSE_FLOAT_NATIVE + HEXA_RT_FORMAT_FLOAT_NATIVE_AVAIL).
- **regex_rt** — own-emit exports 82 globals but the seed contract is 6 (the `.s` was `objcopy`-demoted);
  the A0 flip must hold the 6-symbol contract → **blocked on E4** (own symbol-demotion replacing binutils
  `objcopy --keep-global-symbol`), else the ar'd member over-exports (collision risk).
- **valop_core** — per-symbol `.globl` loop over 10 rt_*_native.

So A0 round-1 remainder = these 5 careful per-family units (regex_rt gated on E4). Then the `:-0`→`:-auto`
flip PR, verified by **a full `tool/release_build` with HEXA_RT_OWNOBJ=1** (default-OFF byteeq can't
exercise the ON-path — convergence stage-resolve-flag-space-1 / runtime-emit-full-hexa-2). Beyond A0:
A1 (~35 one-sym members) · S1/S2 fragments · then the runtime.c body (Round-3+, ~29-32k LOC, multi-session).
