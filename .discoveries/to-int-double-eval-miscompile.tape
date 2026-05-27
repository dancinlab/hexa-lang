@X to_int_double_eval := "codegen to_int/to_i64 cast text-expands its argument into a C ternary twice; a side-effecting arg runs its side effect twice -- a compile-clean silent miscompile, latent across the language" :: discovery [slug=to-int-double-eval-miscompile group=CODEGEN]
  seed         = "F-AGTAPE-WIRE-LMHEAD-BWD-DTEMB FAIL (origin/main): flame nn_lm_head_bwd dtemb gradient = 2*(dl outer zT) instead of (dl outer zT); flame_nn_test LMHEAD-BWD FAIL with dtemb max|d| = 0.57"
  date         = "2026-05-26"
  host         = "mac arm64 LOCAL no-CUDA build (hexa build + run); $0"
  verdict_tier_target = "RED FALSIFIED (deterministic miscompile) -> call-site CLOSED (#1279); codegen root deferred"

  site         = "self/codegen.hexa:5979 and :6245 -- to_int/to_i64 emit (HX_IS_STR(a)?hexa_str_parse_int(a):hexa_int((int64_t)__hx_to_double(a))); the C ternary evaluates cond then ONE branch, so the text-expanded `a` is evaluated twice. char-class predicates is_alpha/is_digit/is_alnum (L5632/5636/5640) share the HX_IS_STR ternary shape and expand `a` up to 4x"
  probe        = "to_int(farr_add_inplace_gpu(dst,src,n)) with dst=[1], src=[10] -> 21 (expected 11): the in-place add ran twice. Minimal deterministic reproduction of the double-evaluation"

  finding_1    = "LIVE on origin/main via PR #1262 flame GPU-wiring: nn_lm_head_bwd wrapped the side-effecting farr_add_inplace_gpu/farr_outer_gpu in to_int, doubling the lm-head dtemb gradient (2x). This was the exact cause of flame_nn_test LMHEAD-BWD FAIL (dtemb d=0.57), undiagnosed since #1262"
  finding_2    = "scope is NARROW in practice: a codebase sweep found 265 to_int/to_float/to_i64(<call>) sites but all except the flame one are PURE calls (string_slice/_cli_flag/ac_layer_cost/...) where double-evaluation is harmless (wasteful, not wrong). After #1279 there are ZERO remaining live side-effecting victims"
  finding_3    = "a SAFE single-eval form already exists in the same file: codegen.hexa:6709 emits hexa_to_int(a) (runtime fn, evaluates arg once, same str-parse-vs-double-cast semantics). The root fix is to route L5979/6245 to that form -- minimal, no new infra"
  finding_4    = "fixed at the call-site (#1279, MERGED) by let-binding the side-effecting kernel result before the to_int cast; flame_nn_test 13/17 -> 14/17 (LMHEAD-BWD restored, dtemb byte-eq). codegen left untouched (scope discipline + serial cc --regen conflict with active go-daemon codegen campaign)"

  next_cycle   = "codegen root fix: replace the inline HX_IS_STR ternary at codegen.hexa:5979/6245 (and audit the char-class predicates L5632/5636/5640) with the single-eval hexa_to_int(a) form, verified via DIRECT-transpile + gen2==gen3 fixpoint (reference_codegen_change_verify_recipe). Gate on a codegen cycle being open (avoid racing go-daemon). Re-run the probe: post-fix 1+10 must give 11"
