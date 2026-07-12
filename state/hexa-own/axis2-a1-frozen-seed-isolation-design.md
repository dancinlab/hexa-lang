# axis-② A1 frozen-seed isolation — own dead-code-elim design (LModule reachability filter)

Design SSOT for replacing the `tool/isolate_native_seed.py` text-slice with an own-emit
isolation pass, so the FROZEN-SEED A1 class (strcmp/strncmp/strchr/strdup/strstr/calloc, +free)
can be own-obj-wired like the libm/objcopy classes — zero binutils, zero `.s` seed consume.

## Verdict: Approach 1-mechanism carrying Approach 2's algorithm

**Prune at the LModule (LIR) level, BEFORE `pack_lir_*` — NOT byte-surgery on the packed
ElfX86Obj.** A new pass `isolate_lmodule_x86_64(lm, keeplist) -> LModule` filters `lm.funcs`
to the keeplist-reachable closure (with a carrier-boundary cut), then the EXISTING pipeline
(`pack_lir_x86_64` → E4 `demote_nonkeep_to_local`) produces the isolated `.o` naturally.

This is the structural mirror of the reference algorithm: `tool/isolate_native_seed.py`
slices the **.s before assembling** (`keep = {root}`, isolate_native_seed.py:84) and keeps all
data sections (:104). In own-emit the packer plays the assembler role, so the analogous slice
point is the LModule before packing.

### Why not obj-level (pure Approach 2)?
Pruning the packed `ElfX86Obj` requires text compaction: rewrite every kept `ElfSym.value`,
rebase every surviving `ElfRel.offset`, drop relocs sited in dead bodies, redo the
intra-module CALL pre-patches (elf_x86_64.hexa:5280–5287 write PC-rel deltas into `.text`
that go stale the moment bodies move), extern-ize still-referenced dropped defs, drop
now-unreferenced undef syms, THEN re-partition + remap. ~150 lines of offset surgery with
stale-pre-patch hazards. The LIR filter gets every one of those for free:

- A cut sibling's `call` site: `pack_lir_x86_64` Pass 2 (elf_x86_64.hexa:5244–5259) finds no
  def → synthesizes the SHN_UNDEF extern + PLT32 reloc automatically. The undef set of the
  output == exactly what kept bodies reference — the isolation invariant by construction.
- Symbol values/sizes/pre-patches/nlocal: recomputed by the packer, never edited.
- No new serializer/reader code; `demote_nonkeep_to_local` (E4, PR #4904) runs unchanged
  downstream to localize any kept non-contract helpers.

## Algorithm (isolate_lmodule_x86_64)

Inputs: `lm: LModule` (ir/lir.hexa:71 — funcs/rodata/bss/globals/floats), `keeplist: [string]`.

1. **Roots.** For each keeplist name, find the LFunc in `lm.funcs` by name. Missing root =
   FATAL (eprintln + exit 2) — mirrors isolate_native_seed.py:78. The resolver contract
   depends on the root existing.
2. **Per-fn reference harvest = trial-pack.** For fn `f`, call
   `_pack_fn_x86(scratch_text, p_off, p_names, d_off, d_names, d_add, g_off, g_names, f)`
   (elf_x86_64.hexa:4784) with throwaway arrays. Harvested names =
   `p_names ∪ d_names ∪ g_names` — the packer's three collector channels are BY CONSTRUCTION
   the complete set of symbolic references a function makes (calls / RIP-rel data / GOT
   loads; intra-fn labels resolve internally and never escape). Reusing the packer as the
   authority means no separate LInstr op-scanner that can drift. `_pack_fn_x86` is pure
   w.r.t. module state (appends only to its argument arrays) → byte-eq-neutral trial.
3. **BFS closure with carrier-boundary cut.** Worklist from roots; for each harvested name:
   - defined in `lm.funcs` AND (name has a carrier prefix `hxlcl_`/`hexa_`/`__hx_` — the
     `_rn_seed_und_gate` whitelist, stage_resolve_runtime_a:1478–1481) AND not in keeplist
     → **CUT**: do not keep, do not traverse. The call site becomes a carrier undef served
     by the still-compiled shim / runtime.o inside runtime.a — byte-for-byte the committed
     seeds' shape (self/native/hxlcl_strdup_x86_64.s carries `call hxlcl_malloc`;
     hxlcl_calloc seed likewise). This cut is WHY the syscall-leaf siblings'
     `__errno_location`/`environ`/`stderr`/`slot_900` externals never enter the output:
     the only referents of those symbols are the cut bodies.
   - defined AND non-carrier-prefixed (module-internal helper) → keep + traverse (dropping
     it would mint a NON-carrier undef and fail the gate).
   - not defined in the module → extern already; no action.
   Visited-set = parallel `[string]` + linear contains (closure is tiny); BFS as
   `while qi < len(queue)` (push-only, bounded by len(lm.funcs) — RFC-010 shape, no indexed
   [Int] assignment, same idiom as E4's `_demote_partition`).
4. **Rebuild.** `LModule { file, target, funcs: kept-in-original-order, rodata: lm.rodata,
   bss: lm.bss, globals: lm.globals, floats: lm.floats }` — data pools copied WHOLESALE,
   matching isolate_native_seed.py:104 ("+ all data/stamp sections"). All rodata/global syms
   are STB_LOCAL defs (pack Pass 0/0b, elf_x86_64.hexa:5108–5150) → never appear in `nm -u`;
   bloat is gate-irrelevant (optional later round may prune unreferenced `.LCstrN`/`g<id>`).
5. **Downstream unchanged.** `pack_lir_x86_64(filtered)` → `demote_nonkeep_to_local(obj,
   keep_globals)`. Demote is still REQUIRED: step 3 may keep non-carrier helpers that must
   go STB_LOCAL for the resolver's `nm | grep -cE ' T '` == 1 contract.

## Hook points (exact)

All on top of branch `feat/axis2-e4-symbol-demotion` (PR #4904, commit 2486094f4 — land E4
first; this pass composes with it):

- **CLI flag**: `--isolate` (boolean modifier), parsed next to `--keep-global=` at
  compiler/main.hexa:474–476 (E4 hunk). Valid only with `--emit=obj` + non-empty
  `keep_globals`; otherwise warn + ignore, mirroring E4's gating at main.hexa:536–553.
  A SEPARATE flag — NOT a semantics change to `--keep-global` — because 17 A1 members
  (libm + objcopy classes) are already wired and verified under keep-all-bodies semantics;
  changing them silently violates opt-in-first (their pre-existing external contract is
  resolved by the archive on linux; isolation there is a separate, re-verified round).
- **x86_64 emit branch**: main.hexa ~:1117 (E4 hunk):
  `let lmodule_iso = if isolate_flag { isolate_lmodule_x86_64(lmodule, keep_globals) } else { lmodule }`
  then `pack_lir_x86_64(lmodule_iso)` → existing `demote_nonkeep_to_local`.
- **New pass body**: appended in compiler/emit/elf_x86_64.hexa next to E4's
  `demote_nonkeep_to_local` (file end, after :5493 pre-E4 EOF) — it needs private
  `_pack_fn_x86` and lives with the shapes it trial-packs.
- **arm64-elf twin**: `isolate_lmodule_arm64_elf` in elf_arm64.hexa — harvest channels are
  `pending_names ∪ page_names` (`_pack_fn_arm64_elf`, elf_arm64.hexa:375–379); hook at
  main.hexa ~:1080 (E4 hunk). Mach-O/darwin = later rung; the resolver tri-state `auto`
  keeps the frozen-seed fallback per-target, so incremental target rollout is safe.

## Resolver wiring (tool/stage_resolve_runtime_a)

Add an own-obj arm ABOVE the seed-consume in each frozen-seed branch (strcmp ~:2310,
free :2416, calloc :2621, strncmp :2703, strstr :2788, strchr :2870, + strdup), following
the libm arm pattern (e.g. hxlcl_exp :2195–2204) but with the und gate as acceptance:

```sh
if [ "${HEXA_RT_OWNOBJ:-0}" != "0" ] && [ -x "${HEXA_OWNOBJ_CC:-}" ] && \
   env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
       "$HEXA_OWNOBJ_CC" "$_drv" --backend=native --emit=obj \
       --keep-global=hxlcl_strcmp --isolate --target=x86_64-linux-gnu \
       -o "$_o" stdlib/runtime/hxlcl_core.hexa >log 2>&1 \
   && [ "$(nm "$_o" | grep -cE ' T _?hxlcl_strcmp$')" -eq 1 ] \
   && [ "$(nm "$_o" | grep -cE ' T ')" -eq 1 ] \
   && [ -z "$(_rn_seed_und_gate "$_o")" ]; then
    # own-obj adopted — seed consume skipped
else
    # fall through to frozen-seed consume (tri-state auto unchanged)
fi
```

Note: unlike the libm arms, the und-gate check is MANDATORY here — it is the exact check
(`_rnsc_bad`, :2324–2326) that rejects the un-isolated `--keep-global`-only output today.

## Verification (pool = summer; mini = git/gh only)

1. **Per-member isolation oracle**: `nm -u own.o` vs `nm -u <assembled frozen seed .o>` —
   strcmp/strncmp/strchr/strstr: BOTH empty (pure leaves). strdup/calloc: both exactly
   `hxlcl_malloc` (carrier). `_rn_seed_und_gate own.o` == '' for all 6.
2. **1-global contract**: `nm own.o | grep -cE ' T '` == 1, matching the seed's
   `.globl`-count gate (:2306–2311).
3. **Byte-neutrality**: same command WITHOUT `--isolate` → byte-identical .o to pre-change
   compiler (pass-through returns `lm` unchanged; trial-pack only runs under the flag).
   Then standard byteeq 3-target CI (compiler binary changed).
4. **Negative control**: `--keep-global=hxlcl_strcmp` (no `--isolate`) still yields the
   5-undef .o and a NON-empty `_rn_seed_und_gate` → proves the resolver arm's gate would
   fall back gracefully (measured trap reproduced, convergence stage-resolve-runtime-a-3).
5. **Archive witness**: HEXA_RT_OWNOBJ=1 release_build → S5 `ld -r` multidef gate +
   shipping smoke; then the 3-target byteeq + smoke before any default consideration
   (release integrity > self-host progress; all of this stays behind opt-in HEXA_RT_OWNOBJ).

## Edge cases pinned

- **Address-taken siblings** (fn-pointer via RIP-rel lea, e.g. signal handlers): harvested
  through `d_names`; the cut is still sound — the reloc binds to the shim's global def at
  archive link.
- **Recursion / diamond call graphs**: visited-set BFS.
- **Cut-target pre-patch**: pack Pass 2 pre-patches imm32 ONLY for defined targets
  (elf_x86_64.hexa:5281 `if sym.section != 0`); cut targets keep the 0-placeholder +
  PLT32 reloc — linker-authoritative, nothing stale.
- **`.o` bloat from wholesale rodata/globals**: LOCAL-only, gate-clean, same as the seeds;
  prune later only if archive size ever matters.
- **Byte-eq risk**: none on any existing path — the filter is flag-gated and the trial-pack
  writes only scratch arrays.

## Why this matches the DONE line

Own-emit + own-isolation removes `tool/isolate_native_seed.py` + `$CC` assemble + the
frozen `.s` seeds from the A1 frozen-seed class path — the last A1 sub-class goes
binutils-free and C-compiler-free (axis-② member layer + axis-③ clang-flip win), with the
committed seeds retained only as the tri-state `auto` fallback until 3-target adoption.
