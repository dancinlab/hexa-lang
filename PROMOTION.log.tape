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
# PROMOTION.log.tape — append-only history sibling of PROMOTION.tape
# (per tape v1.2 architecture-vs-history split, AGENTS.tape @D g_arch_vs_log_split).
#
# Architecture-current declarative entries (the raw-rule promotion policy
# and current milestones) live in PROMOTION.tape (editable, latest-wins
# per id). This file is the append-only stream of new promotion landings:
# @A milestone events, @T promote.hexa invocations, @R atlas-register
# results, @K verification costs, @? promotion failures.
#
# Note: the canonical hash-chained promotion log remains at
# ~/core/hexa-lang/.raw-audit/ (DESIGN ledger · .PRESERVE-AS-SSOT).
# This tape sibling is the typed/grep-friendly milestone projection.

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §Log ────────────────────────────────────────────────────────────
# (Append @A/@T/@R/@K/@H/@?/@D::decision events below this line.)
