# axis-② flip — darwin --isolate Mach-O demotion fix (Fable design)

# Design spec — `--isolate` demotion on Mach-O (darwin-arm64)

All line numbers below are on branch `feat/axis2-mapquery-flip-on` (tip `076a9e3e6`, the #4913/#4914 lineage — the current checkout `fix/install-bare-cuda-pip` doesn't carry the `--isolate` work at all).

## 1. Where everything lives

**Flag parsing** — `compiler/main.hexa`:
- `--keep-global=` capture: `compiler/main.hexa:481-483` (`keep_global_arg`); `--isolate` boolean: `compiler/main.hexa:484-486` (`isolate_flag`, declared at :451).
- Comma-split gated on `--emit=obj`: `compiler/main.hexa:548-566` — `keep_globals` stays `[]` for every other emit kind, which is what makes both downstream passes strict pass-throughs on the exec/own-link paths.

**The demotion is NOT done during symbol-table emission** — it is a **post-pack, pre-serialize object rewrite** on the in-memory object struct, invoked per-target in main.hexa:

| target branch | isolate (LModule prune) | demotion (symtab rewrite) |
|---|---|---|
| `x86_64-linux-gnu` `main.hexa:1128-1141` | `isolate_lmodule_x86_64` (`emit/elf_x86_64.hexa:5670`) | `demote_nonkeep_to_local` (`elf_x86_64.hexa:5625`) |
| `arm64-linux-gnu` `main.hexa:1090-1094` | `isolate_lmodule_arm64_elf` (`emit/elf_arm64.hexa:2269`) | `demote_nonkeep_to_local_arm64` (`elf_arm64.hexa:2247`) |
| `arm64-apple-darwin` `main.hexa:1060-1078` | **— nothing —** | **— nothing —** |

The ELF demotion core is `_demote_partition` (`elf_x86_64.hexa:5527-5624`), shared by both ELF targets: Pass A classifies (defined global fn not in keeplist → local), Pass B builds an `old2new` index permutation ([locals 0..nloc) then globals), Pass C rebuilds symbols with `bind: 0` (STB_LOCAL) for the local partition, Pass D remaps every `ElfRel.sym_idx` through the permutation. `nlocal` feeds the serializer's `sh_info` (ELF requires locals-before-globals, `elf_x86_64.hexa:1071`).

**Binding is written**: ELF — `st_info = (bind<<4)|type` from `ElfSym.bind` at serialize time (STB_LOCAL=0, `elf_x86_64.hexa:43`). Mach-O — `emit/macho_arm64.hexa:1614-1620`: `n_type = s.kind | N_EXT(0x01 if is_external) | N_PEXT(0x10 if is_pext)`, from `MachoSymbol { is_external, is_pext }` (`macho_arm64.hexa:177-184`).

## 2. Root cause

Two stacked facts:

**(a) The passes are simply absent from the darwin branch.** `main.hexa:1060-1078` does `pack_lir(lmodule)` → `serialize(obj_data)` directly. There is no target guard "skipping" a generic demotion — no generic demotion exists; each target branch calls its own pass, and darwin's was never written (`elf_arm64.hexa:2267` even records it: "Mach-O/darwin = a later rung"). So under `--keep-global --isolate` on darwin, the full module is packed and every defined fn keeps the binding `pack_lir` gives it.

**(b) What `pack_lir` gives it is N_PEXT — which does not prevent multidef.** `macho_arm64.hexa:2829-2847` (Pass 3) pushes every fn as `is_external: 1, is_pext: 1` unless it's `main`/`_start` (`_is_entry_symbol_name`, :196-201). That's your `.private_extern` sighting (the `.s` text path in `asm.hexa` does the same blanket non-entry private-extern). The Mach-O nlist scoping model:

- **True local**: `n_type = N_SECT (0x0e)`, N_EXT **clear**. Invisible to cross-object resolution, not indexed in the archive TOC by ranlib, cannot collide. This is the ELF-STB_LOCAL equivalent.
- **Private extern**: `n_type = N_SECT|N_EXT|N_PEXT (0x1f)`. Still **external for the duration of the link** — it resolves references, it is TOC-indexed, and two definitions of the same name in one `ld -r` invocation are a duplicate-symbol error *before* ld64's output-side localization (ld -r turns pexts into locals in the *output* unless `-keep_private_externs`, but duplicate detection runs first). ELF analogy: N_PEXT ≈ `STB_GLOBAL + STV_HIDDEN`, and hidden globals multidef in ELF too.

The measured multidef=95 with the seed's prelude fns *already* N_PEXT is itself the falsification of "just set N_PEXT": the S5 collision happens with N_PEXT set. **The fix must clear N_EXT.**

## 3. The fix — two functions + one wiring edit

### (a) `demote_nonkeep_to_local_macho` — new, in `emit/macho_arm64.hexa` (place next to `pack_lir`)

Mirror `_demote_partition` on `MachoArm64Obj`. Signature: `pub fn demote_nonkeep_to_local_macho(obj: MachoArm64Obj, keeplist: [string]) -> MachoArm64Obj`.

1. `if len(keeplist) == 0 { return obj }` — byte-neutrality by construction, same as ELF.
2. Mangle the keeplist once: `_darwin_mangle(k)` (:2174) — keeplist arrives as `hexa_map_keys`, symbols are stored `_hexa_map_keys`. (The ELF twins compare unmangled; this is the one darwin-specific delta.)
3. **Pass A — classify.** `want_local[i] = 1` iff `is_external == 0` (already local: ltmp/blabels/.LCstr/.LCflt/g-slots) OR (`is_external == 1 && section != 0` and name ∉ mangled keeplist). Undefs (`section == 0`) and keeplist syms stay in the global partition. Read the name with `_symh_name_at(obj.strtab, s.name_offset)` (`elf_x86_64.hexa:5465`, reusable cross-file per the existing `_kg_in_list`/`_iso_is_carrier` precedent — the merged strtab is still NUL-terminated C-strings at `n_strx`; suffix-merging shares tails, the full name is always readable at the offset).
4. **Pass B — `old2new` permutation**: locals take `[0, nloc)` in original relative order, globals `[nloc, ns)` in original relative order. Verbatim from `elf_x86_64.hexa:5553-5570`.
5. **Pass C — rebuild** `obj.symbols`: local partition first, with **`is_external: 0, is_pext: 0`** (n_type serializes to pure `N_SECT 0x0e`); `kind/section/value/name_offset` untouched. Then the global partition verbatim.
6. **Pass D — remap** every `Arm64Reloc.sym_idx` (:169-175) through `old2new`.
7. Return the rebuilt struct; `text/strtab/dwarf_line/cstring/cflt/gdata` carried over unchanged.

Why the reorder (not just flipping the flag in place) is mandatory: `serialize` derives `nlocal/nextdef/nundef` by scanning flags (`macho_arm64.hexa:1511-1525`) but `_emit_dysymtab_cmd` (:1584) hardcodes the run layout `ilocalsym=0 / iextdefsym=nlocal / iundefsym=nlocal+nextdef` — the nlist array must physically be `[locals | extdefs | undefs]` or the LC_DYSYMTAB indices point at the wrong records (malformed object). The permutation restores the run invariant; serialize then does everything else for free (n_type composition :1614-1620, reloc emission :1619-1637).

Why the relocs stay valid: serialize hardcodes `r_extern=1`, and **r_extern=1 against a local N_SECT symbol is already shipped behavior** — the `.LCstr*`/`.LCflt*` page relocs resolve against N_SECT locals today (Pass-4 comment :2988-2994). ld64 accepts it; only the index needs remapping.

### (b) `isolate_lmodule_macho` — new, in `emit/macho_arm64.hexa`

Near-verbatim twin of `isolate_lmodule_arm64_elf` (`elf_arm64.hexa:2269-2340`): same keeplist-root FATAL check, same BFS closure with carrier-boundary cut, same rebuild of `lm.funcs` in original order. Only the trial-pack harvest differs — call `_pack_fn` (`macho_arm64.hexa:2212`) with ten scratch arrays (its signature adds `blabel_names/blabel_offsets/blabel_reforder` vs the ELF packers; all throwaway), and the reference channels are `pending_names ∪ pending_page_names`. Names in those channels are **raw/unmangled** at pack time (mangling happens later in Pass 2, :2740-2752), i.e. the same namespace as `lm.funcs[].name` and the keeplist — so `_kg_in_list` (`elf_x86_64.hexa:5517`) and `_iso_is_carrier` (:5663) are reused cross-file with no mangling adjustments. Page-channel entries like `.LCstr0`/`g3` never match a defined fn and fall through harmlessly, same as the ELF twins.

### (c) Wiring — `compiler/main.hexa:1060-1078` (darwin branch)

Mirror the x86 branch (:1128-1141) exactly:

```
let lmodule_iso = if isolate_flag { isolate_lmodule_macho(lmodule, keep_globals) } else { lmodule }
let obj_data0 = pack_lir(lmodule_iso)
let obj_data = demote_nonkeep_to_local_macho(obj_data0, keep_globals)
let obj_bytes = serialize(obj_data)
```

The branch also serves `emit_kind == "exec"` — safe: `keep_globals` is populated only under `--emit=obj` (:548-566) and `isolate_flag` without `--keep-global` passes an empty list → both passes return the input struct untouched. Default darwin obj/exec emits are byte-identical (same construction the x86 comment at :1132-1140 documents).

Entry symbols: a non-keeplisted `main`/`_start` gets demoted like anything else — this matches measured ELF behavior (x86 seed 275→8 total globals).

## 4. Verification recipe

Unit (on the darwin seed, closes the gap that hid this — count **total** globals, not `hexa_map_*` presence; GNU nm can't read Mach-O):
1. `llvm-nm --extern-only --defined-only seed.o` → **exactly 8 lines**, all `_hexa_map_*`.
2. `llvm-nm -m seed.o | grep -c 'private extern'` → **0** (guards against a PEXT-based half-fix, which the measured multidef=95 already falsified).
3. `llvm-nm --undefined-only seed.o` → carrier-only (`_hxlcl_*` / `_hexa_*` / `___hx_*`).
4. Demoted syms still present as lowercase `t` (defined locals), and the seed's map-query smoke runs (intra-object dispatch works).

Gate: full darwin `release_build` → Case-B S5 `ld -r` **multidef == 0**. Byte-neutrality: byteeq 3-target CI GREEN (off-flag both passes are structural pass-throughs — same argument that kept the ELF landing byte-neutral).

## 5. Risk: do dispatchers still reach the absorbed `rt_map_*`? Yes.

- Intra-module **calls don't even reach the linker**: Pass 4 pre-patches BL `imm26` at pack time for any defined callee and emits **no reloc** (`macho_arm64.hexa:~2973-2983`, "Intra-module defined callee: pre-patch imm26, no reloc"). Demotion happens after packing and doesn't touch `text`.
- Any remaining reloc against a demoted symbol (page-ref/function-pointer) becomes `r_extern=1` → local N_SECT symbol — the exact shape the `.LCstr` relocs already use; a local symbol is still a defined nlist record and resolves within its own object under `ld -r`.
- ranlib TOC then indexes only the 8 keeplist globals, so archive extraction is gated solely by `hexa_map_*` — the intended carrier-boundary behavior; `-keep_private_externs` questions become moot since no pexts remain in the seed.

One residual to watch during implementation: `_symh_name_at` reads to the first NUL from an `[Int]` strtab — identical encoding on the Mach-O merged strtab, but it must run **after** Pass 3b has back-patched `name_offset` (it does: demotion is post-`pack_lir` by design).