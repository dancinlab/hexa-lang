#!/usr/bin/env tape
# atlas/inbox/verified_equations.tape — `hexa verify --absorb` ledger
# g7 inbox: hexa-native self-verified 🔵 equations (g_self_verify;
# NOT sympy carry). Reviewer-merge → MAIN.tape (cycle_033/035 pattern).
# Cleared 2026-05-16 cycle_036 — 11 @D merged to MAIN.tape §1/§2/§8 SSOT.
# Transient rolling --absorb sink: header + @V only post-merge.
@V := "tape" :: spec [active]
  version = "1.2"
