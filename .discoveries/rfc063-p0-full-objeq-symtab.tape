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
  residual_1 = "strtab BYTE ORDER = LLVM-MC MCContext symbol-interning order (parse-order + internal temp-symbol shuffle: bb3,ltmp2,bb2,ltmp1,bb1,ltmp0,bb0). NOT derivable outside LLVM. -> name_offset values diverge."
  residual_2 = "DWARF __debug_line_str embeds absolute build CWD -> not host-portable."
  verdict = "🟠->scoped: FULL byte-eq NOT reachable (2 LLVM-MC-internal fields). REACHABLE closure = symtab LAYOUT/ORDER parity (r_symbolnum aligns) + __HEXA sections + LC_BUILD_VERSION. Implement that; document the 2 residuals."
