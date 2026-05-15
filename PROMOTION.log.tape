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
# Architecture-current declarative entries (the promotion policy and
# current milestones) live in PROMOTION.tape (editable, latest-wins per
# id). This file is the append-only stream of new promotion landings:
# @A milestone events, @T promote.hexa invocations, @R atlas-register
# results, @K verification costs, @? promotion failures.

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §Log ────────────────────────────────────────────────────────────

@A cross_repo_propagation_apr_2026 :: promotion [d=2026-04-30 ok]
  <- c1, c2
  => "cross-repo propagation arm (anima/airgenome/hive convergence)"

@A toolchain_post_fix :: promotion [d=2026-05-13 ok]
  <- cross_repo_propagation_apr_2026
  => "Toolchain post-fix: #12 use-graph flatten + RFC-020 A4 payload-enum codegen + fn-arena heapify-on-push + time_now_ms TAG_FN + bidi-stdio exec_stream_open/write/close_stdin + thread_channel_* rename"

@A bytes_to_str_phase_2 :: promotion [d=2026-05-13 ok]
  <- toolchain_post_fix
  => "Phase 2 NUL-byte support in bytes_to_str — unblocks wilson tool-image base64 collapse"
