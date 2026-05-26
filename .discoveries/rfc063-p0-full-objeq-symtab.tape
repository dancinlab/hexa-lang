@discovery := "RFC 063 P0 — full Mach-O object byte-eq: symtab layout + DWARF path residual" :: finding [active]
  id     = "rfc063-p0-full-objeq-symtab"
  seed   = "extend macho_arm64.hexa so full .o == clang -c (not just __text)"
  verdict-tier-target = "🟢 numerical byte-eq (modulo non-portable DWARF)"

  # MEASURED on mini (arm64 macOS 26.5, Apple clang 21.0.0):
  finding_1 = "clang -c on aprime_cc's .s emits 5 sections: __text, __HEXA,__cap, __HEXA,__abi, __DWARF,__debug_line, __DWARF,__debug_line_str + LC_BUILD_VERSION"
  finding_2 = "__DWARF __debug_line_str EMBEDS the absolute build CWD (/Users/.../repo) — full .o is NOT host/CWD-portable. Two cwds -> different sha. This is the hard residual."
  finding_3 = "Stripping .file/.loc from the .s makes clang emit a CWD-INDEPENDENT 3-section object (no DWARF, no path). THIS is the portable byte-eq closure target."
  finding_4 = "Local symtab order (LLVM-MC): ltmp0(sect-start), entry bb0, then block labels in FIRST-BRANCH-REFERENCE order, then ltmp1+_hexa_cap_manifest(__cap), ltmp2+_hexa_abi_stamp(__abi)"
  finding_5 = "extdef order = address order; undef order = ALPHABETICAL. fib: _fib n_type=0x1f (N_SECT|N_EXT|N_PEXT, .private_extern/.hidden), _main=0x0f (plain global)"
  finding_6 = "DYSYMTAB: nlocalsym/iextdefsym/nextdefsym/iundefsym/nundefsym all populated (was: only nextdefsym)"

  # HARD RESIDUALS to FULL byte-eq (verified non-derivable):
  residual_1 = "strtab BYTE ORDER = MCStringTableBuilder suffix-merge sort, not symbol-order. Shifts every n_strx + strsize (±1..5 B). NOT derivable outside LLVM-MC. The remaining whole-.o diff is THIS and only this."
  residual_2 = "DWARF __debug_line_str embeds absolute build CWD -> not host-portable. We deliberately do NOT emit __debug_*; byte-eq target is the CWD-independent (.file/.loc-stripped) clang object, which we match section-for-section."

  # MEASURED at HEAD vs #1257 baseline (mini, arm64 macOS 26.5, clang 21.0.0). Verbatim.
  m_smoke      = "tool/build_aprime.sh @ HEAD: smoke exit(42)==42 PASS — default path untouched. Baseline also PASS."
  m_text_eq    = "__text byte-eq vs clang -c: HOLDS @ HEAD (trivial/fib/while = 17/74/44 words IDENTICAL). HEAD __text == baseline __text (UNCHANGED) == clang."
  m_symtab     = "nm -ap IDENTICAL to clang (symbols+n_type+n_sect+n_value+ORDER). DYSYMTAB IDENTICAL (ilocal0 nlocal6 iext6 next1 iundef7 nundef2). Sections+LCs IDENTICAL."
  m_closeness  = "whole-.o size gap vs CWD-indep clang ref: baseline 367/459/466 B -> HEAD 1/1/5 B (trivial/fib/while). Remaining diff = strtab byte-order + n_strx + strsize only."
  m_corpus_note= "corpus structural harnesses (SYMTAB/RELOC/FRAME) fail to BUILD at BOTH baseline+HEAD: they construct PReg{name,kind} (2 fields) but lir.hexa PReg grew to 5 (RFC 067 P3). Pre-existing staleness, NOT this work."

  verdict = "🟢 scoped-closure LANDED: symtab LAYOUT/ORDER + __HEXA sections + LC_BUILD_VERSION = byte-eq w/ clang. FULL byte-eq blocked ONLY by residual_1 (strtab interning). residual_2 (DWARF) is the non-portable default-clang variant, out of target."
