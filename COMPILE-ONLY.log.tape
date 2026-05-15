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
# COMPILE-ONLY.log.tape — append-only history sibling of COMPILE-ONLY.tape
# (per tape v1.2 architecture-vs-history split, AGENTS.tape @D g_arch_vs_log_split).
#
# Architecture-current declarative entries (policy clauses · forbidden
# patterns · closure criteria · citations) live in COMPILE-ONLY.tape
# (editable, latest-wins per id). This file captures status-transition /
# verification / commit events in strict append-only order.

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §Log ────────────────────────────────────────────────────────────

@N closed_p0_oom := "p0-stage1-oom-closed" :: status [d=2026-05-11 ok]
  fact = "P0 stage-1 source-side OOM closed at current scale: peak RSS 3 510 MB → 782 MB (uncapped probe)"
  evidence = "A1 phase-arena reset (a0f5cd5d restored) + A2 in-place _splice_imported_items accumulator (ab2dfcee) + A3 hash-keyed env (4ed9966e); host re-promote 774c5d32 → 41ecfb97 → dae438ee; #13 RSS re-probe (4f5f8f07)"
  authority = "[@x_punch_v2] §155–204"

@N closed_cluster := "track-bc-cluster-closed" :: status [d=2026-05-11 partial]
  fact = "Track B / C cluster work landed: B1+C19 / Types A4+C4+B2 / C11 atlas embed (parse_only skip) / Lower C5+C9+C10+C16 / P2 C12–C20"
  authority = "[@x_spec_15_e2] §15:484"
  caveat = "B5 (helper collisions) · C6 (regalloc spill) · C7 (>6/>8 args spill) · C8 (label hash-qualify) NOT explicitly named in 'all landed' list — verification pending"

@N open_wallclock := "stage1-binary-wallclock-gate" :: status [d=2026-05-11 partial]
  fact = "Post-OOM probe: hexa_interp `--emit=asm` self-compile still grinding CPU at ~21 min wall (~20.5 min UTIME), `.s` not produced, exit code incidental"
  why = "memory wall gone, wall-clock wall remains — interpreted whole-compiler codegen too slow at current loop dispatch rate"
  fix_options = ["isolate slow inner loop (likely _arm64_reg_for_local modulo + spill cascade or codegen single-module grinding)", "partial self-compile mode (per-leaf .s emit + link, punch-list option (b))"]
  authority = "[@x_punch_v2] §192–195"

@N verified_p0 := "p0-correctness-verified-d-2026-05-14" :: status [d=2026-05-14 partial]
  fact = "4 P0 items not in SPEC §15:484 'all landed' list — verified directly against compiler/codegen sources"
  results <<~EOF
    B5 (helper collisions)         — OPEN.    _op_reg/_op_imm/_op_label/_instr2
                                     defined in BOTH arm64_darwin.hexa
                                     (lines 61/72/83/115) AND x86_64_linux.hexa
                                     (lines 59/70/81/102). Splice → first-wins
                                     collision. Fix: rename _arm64_op_reg /
                                     _x86_op_reg etc. — mechanical sed.
    C6 (regalloc spill)            — PARTIAL. RegMap / ArmAllocResult /
                                     _arm_reg_lookup / _arm_is_spilled /
                                     _arm_spill_offset all exist (arm64_darwin.hexa
                                     :440~). Normal path safe. But _arm_reg_lookup
                                     falls back to _arm64_reg_for_local (naive
                                     id mod 31) when idx<0 or regs[idx]==[],
                                     leaving wrong-code risk on uncovered locals.
                                     stage-1 first attempt likely survives;
                                     hardening needed before byte-equal target.
    C7 (>6/>8 args spill)          — OPEN.    Both backends emit literal
                                     _instr0("nop", "TODO: spill arg N to stack")
                                     (x86_64_linux.hexa:670, arm64_darwin.hexa:709).
                                     7+ args fns silently miscompile.
    C8 (block label hash-qualify)  — CLOSED.  _arm64_modhash + modhash threaded
                                     through _arm64_block_label end-to-end
                                     (arm64_darwin.hexa:523~ 'Stage1 C8'
                                     comment confirms intent; all call sites
                                     738/746/750/839 use modhash).
  EOF
  next = "C7 has the smallest blast radius surface (any 7+ args call site) — fix first. B5 mechanical rename second. C6 hardening after stage 1 first attempt surfaces real cases."
  authority = "[@x_punch_v2] §284–311"

@N open_stages_23 := "stage-2-3-deferred" :: status [d=2026-05-14 partial]
  fact = "tests/bootstrap/run_bootstrap.sh live run reports DEFERRED — stage 2 smoke OK, stage 3 fixed-point cannot run (no stage 1 binary on disk)."
  evidence = "build/stage1/hexa = 58952 B, mtime Apr 13 (stale Q1 stub); build/stage{2,3}/hexa same mtime; build/fixpoint_report.json mode=scaffold, converged=0"
  unblocks = "@open_wallclock"
