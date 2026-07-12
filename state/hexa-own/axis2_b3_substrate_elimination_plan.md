
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

## A0 round-1 COMPLETE — 9/10 tractable families landed + ON-path GREEN (2026-07-12)

All 4 multi-flag families now landed, closing the round-1 tractable set (PR #4900):
- **map_core** (4-read `rt_map_(get|fnv1a|strcmp0|contains)_native` + 1-inplace `rt_map_set_inplace_native`)
- **valop_core** (10-sym `rt_(truthy|sub|mul|add|cmp_lt|cmp_gt|cmp_le|cmp_ge|div|mod)_native`)
- **num_float_core** (dual-flag: parse `rt_parse_float_native` + format `rt_format_float_native`)
- **str_core** (5-flag; **A0 branch placed BEFORE the `.s` seed-existence guard** — str_core has no
  in-tree `.s` seed so the guard would else early-return before A0; own-emit needs no seed)

**summer ON-path verify: 9/9 own-obj families GREEN** (`HEXA_RT_OWNOBJ=1` → every family own-emits
`--emit=obj`, ZERO `$CC` assemble). Only **regex_rt** remains for A0 — **blocked on E4** (82⊇6
over-export needs own symbol-demotion). So A0 round-1 is DONE modulo the E4-gated family.

**Next**: the `:-0`→`:-auto` flip PR, gated on a full `tool/release_build HEXA_RT_OWNOBJ=1` witness
(the ON-path is invisible to default-OFF byteeq) + byteeq 3-target + install smoke. Then A1
(~35 one-sym members), which E4 (own symbol-demotion) also unblocks alongside regex_rt.

## A0 SHIP WITNESS — PASS (summer, 2026-07-12, witness3)

`tool/release_build TARGET=linux-x86_64 HEXA_RT_OWNOBJ=1 HEXA_OWNOBJ_CC=$PWD/build/aprime_cc
HEXA_PREBUILT_RUNTIME=$PWD/build/runtime.a HEXA_CUDA=0` →
**`[release_build] PASS — ./hexa built`**. All 9 own-obj members fire (`B3-A0 OWN-OBJ` ×9) at
Stage-0b and land in the shipped `build/runtime.a` (`ar t` confirms `array_core_native.o ·
map_core_native.o · str_core_native.o · valop_core_native.o …`), and the self-host `./hexa` binary
builds Stage 0/1/2 against that own-obj runtime.a. So the own-object runtime members are
**ship-compatible** — the (v) ship-witness gate is cleared for the A0 flip.

TWO ship-recipe traps found + fixed this session (convergence `stage-resolve-runtime-a-2`):
1. cached `[ -f build/<fam>_native.o ] && return 0` shortcut pre-empted A0 in a non-clean build (stale
   `.s` `.o` masked own-emit → 0 `B3-A0` lines despite the flag). FIX: 9 shortcuts gated on
   `HEXA_RT_OWNOBJ=0`.
2. witness must pin `HEXA_PREBUILT_RUNTIME=$PWD/build/runtime.a` + `HEXA_CUDA=0` (summer's shell profile
   inherits an installed CUDA-baked runtime.a → Stage-0 link dies on `__cudaRegister*` without `-lcudart`
   — a measurement-path artifact, not a target defect).

## A0 round-1 COMPLETE — 10/10 families (2026-07-12, regex_rt via E4)

E4 own-symbol-demotion (`demote_nonkeep_to_local` + `--keep-global=` flag, PR #4904, verified GREEN:
regex_rt `--keep-global=<6>` → 6 global T + 76 local t, byte-neutral off-flag 195984B identical) landed,
so the 10th/final A0 family **regex_rt** is wired: own-emit `--emit=obj --keep-global=rt_regex_findall,
rt_regex_match,rt_regex_match_full,rt_regex_replace,rt_regex_search,rt_regex_split` → the 76 internal
helpers demote to STB_LOCAL, matching the `.s` seed's exactly-6-global contract. summer verify:
**10/10 B3-A0 families fire** with the E4 aprime. Merge-safety: a non-E4 aprime emits all 82 global →
the 6/6-global assertion fails → **clean fallback to the `.s` seed** (so #4900 ships safe before #4904).

**A0 round-1 = DONE** (10/10 seed families own-emit under `HEXA_RT_OWNOBJ`) + ship witness PASS. Next =
the `:-0`→`:-auto` flip PR (ship witness3 already PASS).

## A1 mechanism PROVEN (2026-07-12) — E4 own-emits the one-sym hxlcl members

The ~27 A1 one-sym members (`HEXA_RT_NATIVE_{CALLOC,FREE,REALLOC,STRCMP,STRNCMP,STRCHR,STRDUP,STRSTR,
STRTOLL,ATOF,ATOLL,SIN,COS,EXP,LOG,FMOD,TIME,CLOCK,GETENV,SETENV,OPEN,FORK,PIPE,POPEN,PCLOSE,EXECVP,
SIGNAL}`) all derive from a **single `stdlib/runtime/hxlcl_core.hexa`** (248KB, all shims): each `.s`
seed today is `aprime --emit=asm hxlcl_core.hexa` + a `regen_hxlcl_<sym>_native_s.sh` `.globl` demotion
post-pass keeping ONE shim global. That is **exactly E4's job**. VERIFIED on summer with the E4 aprime:
`aprime --emit=obj --keep-global=hxlcl_strcmp hxlcl_core.hexa` → **1 global T (hxlcl_strcmp) + 79 local t**,
matching the frozen `.s` seed's `.globl` count of 1. So the whole A1 batch is de-risked + uniform:
per member, own-emit `hxlcl_core.hexa --keep-global=<one shim>` replaces the `--emit=asm`+regen-sed seed.

**A1 wiring (next round)**: the one-sym members live in the MULTIOBJ tri-state resolvers (e.g.
`HEXA_RT_NATIVE_CALLOC=auto` at stage_resolve_runtime_a:~2583, `-DHEXA_RT_NATIVE_CALLOC` + member add) —
more structure than the A0 seed families, so each needs an own-emit branch mirroring the regex_rt A0
pattern (own-emit + `nm` assert exactly-1-global + fallback to `.s`). Batch by family (string / mem /
libm / FILE / proc). Gated on E4 #4904 (non-E4 aprime → all-global → clean `.s` fallback = merge-safe).

## A1 wiring — libm + objcopy classes COMPLETE (2026-07-12, 17 branches / 18 symbols)

The two SAFE A1 classes are fully wired (all default-OFF byte-neutral; own-emit only under HEXA_RT_OWNOBJ):
- **libm class (5)**: fmod · sin · cos · exp · log — `--emit=asm` → `--emit=obj --keep-global`, drops `$CC`.
- **objcopy class (12)**: getenv · time · atof · atoll · signal · fork · setenv · pipe · execvp ·
  clock_gettime (`hxlcl_clock_gettime`) · open (`hxlcl_open_sys`) · popen/pclose (2-sym combined) —
  `--emit=asm + $CC + objcopy --keep-global-symbol` → `--emit=obj --keep-global`, drops **BOTH `$CC` AND
  binutils objcopy** (the direct axis-③ no-binutils win). Each own-emit verified on summer to the exact
  global count (1, or 2 for popen/pclose); popen/pclose builds the comma-list from its POPEN/PCLOSE flags.

**Only the frozen-seed class remains for A1** — strcmp/strncmp/strchr/strdup/strstr/calloc: the frozen
`.s` seeds were `isolate_native_seed.py`-isolated to **0 undefined externals**, but `--keep-global` alone
reintroduces 5 (convergence stage-resolve-runtime-a-3). Needs an isolation step → **design-gated (fable,
in-flight)**, distinct sub-problem.

### Reference algorithm characterized (isolate_native_seed.py) — the own-emit target to match
The isolation is a **transitive reachability DCE over the call graph**: `keep = {root}`; BFS following
`refs_of(block)` (symbols a function references = call-graph edges) via `resolve(sym)`; emit only the
reachable functions (`kept_order`), strip every `.globl/.type/.size/…` directive for dropped syms, and
re-assert the single contract `.globl <root>`. Dropping the dead sibling bodies removes the darwin-absent
externals they carried (errno/environ/…). So the own-emit design (Fable) must do the same reachability
sweep at `--emit=obj`: from the keeplist function roots, follow **reloc edges to STT_FUNC defined
symbols** transitively, KEEP only reachable functions (drop unreachable bodies from `obj.text` — recompute
offsets — + their symbols + their relocs + now-unreferenced undef externals). This is E4 + a reachability
filter, but with **text-range removal + offset/reloc recompute** (harder than E4's symbol-reorder) →
needs the grounded Fable design + a compiler rebuild to verify (own-emit strcmp.o `nm U == 0`). Interim
fallback: the frozen `.s` seeds still ship (default path), so this is purely the own-obj upgrade.

**Remaining for lane-2 (multi-session)**: A1 frozen-seed isolation (~6 members, design-gated) → the
`:-0`→`:-auto` flip PR (ship witness3 PASS) verified by `release_build HEXA_RT_OWNOBJ=1` archive-link →
S1/S2 fragments → the runtime.c body (Round-3+, ~29-32k LOC HexaVal machinery) → m3 TU-drop = literal ② DONE.
