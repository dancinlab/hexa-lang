# AUDIT — `macho_obj_wrap` emit-side reloc gap for arena `adr x9, #0`

Date: 2026-05-26
Branch: emit-arena-relocs-2026-05-26 (worktree)
Scope: chunk-B / phase-H — close #1297 residual #2 (state-relative primitives).

## current emitter state

File: `self/codegen/macho.hexa::macho_obj_wrap(code, main_offset)` — L34-136.

- L88-90 — section_64 `__text`:
    ```
    out = push_u32_le(out, 0)              // reloff
    out = push_u32_le(out, 0)              // nreloc
    ```
- L56 — header `ncmds = 3` (LC_SEGMENT_64 + LC_SYMTAB + LC_BUILD_VERSION).
- L100 — `nsyms = 1` (only `_hexa_main` exported).
- L122-127 — single nlist_64 record for `_hexa_main`.
- L130-133 — strtab = `"\0_hexa_main\0"` = 12 bytes.

**Gap**: `reloff/nreloc` are hard-coded to 0; there is NO codepath that emits `relocation_info` records for ANY symbol. The 16-byte arena `adr x9, #0` placeholder slots therefore cannot reach the linker as relocs — they would land as a stale `0x10000009` referencing PC instead of the arena_state symbol.

## arena emit-side state

File: `self/codegen/runtime_arm64.hexa::rt_arena_*` — L1045+.

Each of the 4 arena fns emits exactly one or two `adr x9, #0` placeholder words:

| fn | placeholder offset(s) (bytes from fn start) | bytes (LE) |
|----|---|---|
| rt_arena_init | 40 | 09 00 00 10 |
| rt_arena_alloc | 0 | 09 00 00 10 |
| rt_arena_reset | 0 | 09 00 00 10 |
| rt_arena_release | 8, 32 | 09 00 00 10 |

All 6 placeholder words = `0x10000009` (ADR x9, #0).

## linker side capability (already landed via #1282, see `tool/hexa_ld.hexa` L800+)

PR #1282 (commit 5c464c71) — the linker DOES apply both `ARM64_RELOC_PAGE21` (kind=3) and `ARM64_RELOC_PAGEOFF12` (kind=4) for `adrp` (PAGE21) and `add` (PAGEOFF12) instruction pairs. It computes:

- PAGE21 (kind=3, adrp):
    - `pc_page = pc_addr & ~0xfff`
    - `tgt_page = tgt_addr & ~0xfff`
    - `page_imm = (tgt_page - pc_page) >> 12`
    - encode immlo @ bits[30:29], immhi @ bits[23:5]
- PAGEOFF12 (kind=4, add unscaled):
    - `off12 = tgt_addr & 0xfff`
    - encode @ bits[21:10]

**Important divergence vs arena**: the linker side resolves an **ADRP** (`0x90000000` family), not **ADR** (`0x10000000` family). The arena uses **ADR** in its bytes (`0x10000009`). ADR's reloc encoding diverges:

- ADR's immediate is 21-bit signed BYTE offset (not page-shifted) at bits[30:29]+[23:5].
- `ARM64_RELOC_PAGE21` per Apple's `mach-o/arm64/reloc.h` is for ADRP only.
- For an immediate **address** within ±1MB (the arena state slot fits if both __text and the arena_state slot are co-located in the merged image), the codegen could keep ADR and have the linker patch the 21-bit IMM with `(tgt - pc) >> 0` (byte-units).
- The clean fix is to swap the placeholder to **ADRP + ADD** pair (8 bytes / 2 instructions instead of 1), matching ld64's conventional reloc encoding.

## conclusion — emit-side closure: 3 sub-gaps

1. **Symbol-table extension**: `macho_obj_wrap` exports only one symbol (`_hexa_main`). To carry an arena_state slot the strtab must include `_arena_state` (or similar) and nlist must record its bss/data section + offset.
2. **Reloc records emit**: write 6 (or 12 if ADRP+ADD swap) `relocation_info` records (8 bytes each) per arena fn, populate `reloff/nreloc` on the section_64 record, and shift `symtab_offset` past the reloc table.
3. **Placeholder-instruction widening**: rt_arena_*'s `adr x9, #0` (4 bytes, 1 instruction) → `adrp x9, page` + `add x9, x9, #off` (8 bytes, 2 instructions). All 6 arena placeholder sites must be widened.

Sub-gap (3) crosses into **runtime_arm64.hexa rt_arena_* mutation** + a re-byte-count audit (4-byte/site additions × 6 sites = +24 bytes total across the 4 fns). That's a non-trivial 2nd surface beyond `macho.hexa`.

## PoC scope (what this PR lands)

To respect the "≤200 line per PR" stack discipline + the honest residual policy:

- Sub-gap (1) + (2) — `macho_obj_wrap_v2(code, sym_main_offset, state_init_bytes)`: a sibling wrapper that emits an MH_OBJECT carrying TWO symbols (`_hexa_main` in `__text` + `_arena_state` in `__data` w/ zero-filled 24 bytes for base/ptr/end) AND the matching `__text` reloc records targeting the state slot. **Single arena fn (rt_arena_reset, the cleanest 16-byte fn with ONE adr-placeholder)**.
- Sub-gap (3) — defer to follow-up: the v2 wrap is parameterised so when rt_arena_* gets the ADRP+ADD widening, plumbing already exists.

## verification plan

- emit a .o via macho_obj_wrap_v2 containing rt_arena_reset bytes (post-widening to adrp+add) + arena_state slot
- `otool -rv` to dump the reloc table → expect 2 records (PAGE21 + PAGEOFF12) targeting `_arena_state`
- `clang -arch arm64` link with a tiny C caller that supplies _hexa_main → run → `otool -tv` final binary → see resolved imm in adrp+add → arena_reset zeroes ptr to base.

If sub-gap (3) blows up — partial PoC = ADR placeholder kept, ADR-specific reloc emission encoded, link will fail at ld64 (unknown ADR reloc kind) but the audit + reloc record encoding lands as a clean spec for the follow-up.
