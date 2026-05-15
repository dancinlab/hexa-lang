#!/usr/bin/env tape
# ══════════════════════════════════════════════════════════════════════
# .tape v1.2 — grammar primer (cold-read by any LLM / agent / human)
# ══════════════════════════════════════════════════════════════════════
# Form: each entry is `@<type> <id> := "<subject>" :: <kind> [<grades>]`
#       optionally followed by body lines (2-space indent) — key=value,
#       edges (<- -> => …), or quoted prose.
#
# ENTRY TYPES (17): @S session @U user @A assistant @T tool-call @R result
#   @H hook @D decision @K cost @P provider @? anomaly @I identity-claim
#   @X external-citation @F forbidden-pattern @N note @C config @L layout
#   @V spec-version
#
# EDGES (12, on body lines, 2-space indent):
#   <- caused-by  -> triggers  == continues  ~> supersedes  !! aborts
#   |> verified-by  => produces  <: specializes  :> generalizes
#   ?> soft-depends  !> conflicts-with  @> projects-to
#
# Full spec: ~/core/tape/spec/tape.md (or github.com/dancinlab/tape)
# ══════════════════════════════════════════════════════════════════════
#
# PROMOTION.tape — raw-rule promotion criteria (architecture SSOT)
#
# The full hash-chained log lives in ~/core/hexa-lang/.raw-audit/
# (DESIGN ledger — .PRESERVE-AS-SSOT inside `convergence/` dir).
# This .tape captures the current promotion-gate policy (what counts as
# "promoted"). Major promotion landings (raw-N batches, toolchain post-fixes,
# stdlib module promotions) are appended to PROMOTION.log.tape.

@V := "tape" :: spec [active]
  version = "1.2"

@I id001 := "hexa-lang.promotion" :: identity-claim [d=2026-05-15 active]
  kind = "raw-rule → atlas promotion gate stack"
  brief = "stdlib / atlas promotion criteria — what must hold for a verified contribution to auto-register as an atlas L[*] node"
  parent = "dancinlab/hexa-lang"
  sibling-log = "PROMOTION.log.tape"

# ─── §Criteria ───────────────────────────────────────────────────────

@D c1 := "promotion.atlas_bound_or_warn" :: promotion [d=2026-05-14 ok]
  text = "Every formula/constant not atlas-bound emits HX8003 warning / HX8004 error"
  proof = "compiler/intrinsics/intrinsics.hexa + atlas registration path"

@D c2 := "promotion.update_or_pr" :: promotion [d=2026-05-14 ok]
  text = "Verified contributions auto-register as new atlas L[*] nodes via promote.hexa"
  proof = ".raw-audit/ hash-chained entries"
