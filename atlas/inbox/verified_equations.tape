#!/usr/bin/env tape
# atlas/inbox/verified_equations.tape — `hexa verify --absorb` ledger
# g7 inbox: hexa-native self-verified 🔵 equations (g_self_verify;
# NOT sympy carry). Reviewer-merge → MAIN.tape (cycle_033/035 pattern).
@V := "tape" :: spec [active]
  version = "1.2"

@D verified_is_perfect_496__1 := "is_perfect(496)=1" :: verdict [d=2026-05-16 active]
  status = "🔵 SUPPORTED-FORMAL"
  evidence = "is_perfect hexa-native recompute = 1 == claimed 1"
  stage = "Stage 1 — hexa-native recompute (hexa verify)"
  anchor = "[compiler invariant — hexa-native NT closed-form, g_self_verify]"
  cite = "hexa verify self-verified (g_self_verify · TECS-L Tier1)"
  provenance = "tool/verify_cli.hexa --absorb · binary built-in atlas + calculators"

