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
# COMPILE-ONLY.tape for `dancinlab/hexa-lang`
#
# Sibling doctrine to HEXA-NATIVE-ONLY.md ("no LLVM / no C-transpile as
# architecture"). This file codifies the **interpreter-retirement** gate
# stack: hexa-lang is a native compiled language; `hexa_interp` exists
# only as stage-0 bootstrap and retires after stage 3 fixed point (E2).
#
# Authority chain: SPEC.md §2.1 (language kind = native compiled) ·
#                  SPEC.md §5    (4-stage bootstrap, hexa_interp = stage 0)
#                  SPEC.md §15   (E2 = retire hexa_interp after stage 3)
#
# Status anchor (snapshot d=2026-05-14): P0 stage-1 OOM CLOSED 2026-05-11;
# stage 1 binary still not produced (wall-clock + 4 unverified P0s);
# stage 2/3 harness DEFERRED; E2 minimum weeks-to-months out.

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §1 Identity ─────────────────────────────────────────────────────

@I id001 := "hexa-lang.compile-only" :: identity-claim [d=2026-05-14 active]
  kind = "native compiled language with bootstrap-only interpreter"
  positions = "hexa_interp ∈ {stage-0 anchor}; user-facing surface ∈ {hexa build, hexa run≡build+exec, hexa repl (opt-in AST eval)}"
  rejects = "interpreter_only · interpreter_with_cache · keep separate ~20K-LOC interpreter · JIT-first"
  authority = "[@x_spec_2_1] [@x_spec_5] [@x_spec_15_e2]"

# ─── §2 Decisions (mirror SPEC, restated as governance) ──────────────

@D d1 := "language-kind-native-compiled" :: governance [required]
  rule = "hexa-lang transitions from interpreter (hexa_interp) to a native compiler. Interpreter remains only as bootstrap stage 0."
  why = "interpreter_only too slow for CI/LSP at atlas size 4.2 MB; interpreter_with_cache still has per-process overhead, not zero"
  apply = "all new semantics MUST land in the native-compile path; interp gets bug-fix only (no feature growth)"
  authority = "[@x_spec_2_1]"
  <: g5
  @> SPEC.md

@D d2 := "stage-0-bootstrap-only" :: governance [required]
  rule = "hexa_interp is stage 0 of the bootstrap chain — anchor that produces stage 1, nothing more."
  table <<~EOF
    | stage | tool          | output                                |
    | 0     | hexa_interp   | stage 1 native compiler binary         |
    | 1     | stage 0       | stage 2 (self-compiled by stage 1)     |
    | 2     | stage 1       | stage 3                                |
    | 3     | stage 2       | byte-equal to stage 2 (fixed point)    |
  EOF
  retires = "hexa_interp after stage 3 settles (system as/ld permitted only during stage 0 → stage 1)"
  authority = "[@x_spec_5]"
  @> SPEC.md

@D d3 := "post-retire-mode-d-plus-b" :: governance [required]
  rule = "After stage 3 fixed point: D (default) `hexa run x.hexa` ≡ build + exec, zero extra LOC. B (opt-in) `--interp` / `hexa repl` = ~200–500 LOC AST evaluator under compiler/eval/, reusing the full frontend."
  rejected = ["A: keep separate ~20K-LOC interpreter", "C: JIT first"]
  why = "single semantic SSOT (the AOT codegen); REPL/repl ergonomics preserved via tiny AST walker, not a parallel runtime"
  authority = "[@x_spec_5]"
  @> SPEC.md

@D d4 := "e2-retire-trigger" :: governance [required]
  rule = "E2 (retire hexa_interp) fires when stage 3 binary is byte-equal to stage 2 binary (sha256 match)."
  precondition = "stage 1 binary exists AND stage 2 self-compile PASS AND stage 3 fixed-point PASS"
  harness = "tests/bootstrap/run_bootstrap.sh — exits 0 with FIXED_POINT_PASS on success"
  authority = "[@x_spec_15_e2] [@x_bootstrap_doc]"

# ─── §3 Forbidden patterns ───────────────────────────────────────────

@F f1 := "interp-feature-growth" :: governance [required deny:write]
  pattern = "adding new semantics, new builtins, or new optimizations into self/runtime.c or self/interpreter.hexa beyond what stage 0 needs"
  why = "interp is bootstrap-only; feature growth there violates [@x_spec_2_1] and creates two-SSOT divergence (interp ≠ AOT)"
  exception = "P0 bug fixes that block stage-0 from producing stage 1 — explicitly scoped"

@F f2 := "jit-as-default" :: governance [required deny:write]
  pattern = "introducing a JIT (LLVM ORC, custom IR JIT, etc.) as the default execution path or as a third runtime alongside interp/AOT"
  why = "rejected at SPEC §5 (option C) — adds a third semantics SSOT; no pull beyond cold-start narrative"
  exception = "JIT may be re-considered ONLY after AOT codegen is feature-complete AND has measured cold-start blocking real workflows"

@F f3 := "preserve-20k-loc-interpreter" :: governance [required deny:write]
  pattern = "blocking E2 by arguing the existing ~20K LOC interpreter (self/runtime.c + self/interpreter.hexa.c) should be preserved as a long-term parallel runtime"
  why = "rejected at SPEC §5 (option A); single user-facing repl path is the ~200-500 LOC AST evaluator at compiler/eval/ (option B)"

@F f4 := "interp-as-architecture-claim" :: governance [required deny:write]
  pattern = "describing hexa-lang as 'interpreted' or 'tree-walking' in any user-facing doc, README, marketing, or RFC abstract"
  why = "the architecture is native-compiled; interp's bootstrap role is implementation detail"
  exception = "internal bootstrap chain documentation that explicitly scopes the interp role to stage 0"

# ─── §4 Stage gate status (snapshot d=2026-05-14) ────────────────────

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

# ─── §5 Critical path to E2 ──────────────────────────────────────────

@D critical_path := "e2-critical-path-d-2026-05-14" :: plan [active]
  ordered_steps <<~EOF
    1. [DONE 2026-05-14] Verify B5/C6/C7/C8 closure — see @verified_p0.
       Result: C8 closed; C6 partial (regalloc real, fallback unsafe);
       B5 + C7 open. Order of fix: C7 stack-spill → B5 rename → C6 hardening.
    1a. [NEXT] Implement C7 stack-spill on both x86_64 (System V) and arm64
       (AAPCS64). x86_64: args 7+ at [rsp+0], [rsp+8], ...; arm64: args 9+
       at [sp, #0], [sp, #8], ... Both require 16-byte sp alignment at call
       site. Replaces _instr0("nop", "TODO: spill arg N") emit.
    1b. B5: mechanical rename _op_reg → _arm64_op_reg / _x86_op_reg
       (and _op_imm / _op_label / _instr2) — sed.
    1c. C6 hardening: tighten _arm_reg_lookup fallback after stage 1 first
       attempt surfaces real overflow cases.
    2. Diagnose wall-clock gate (open_wallclock): identify whether root cause
       is interpreted dispatch overhead per-iter, single-module codegen
       grinding, or a specific slow algorithm (modulo regalloc loop, etc.).
    3. Force stage 1 binary production: long-budget hexa_real run with
       /usr/bin/time -l capture, .s artifact, then clang link → promote to
       build/stage1/hexa.
    4. Re-run tests/bootstrap/run_bootstrap.sh → stage 2 smoke + stage 3 hash.
       First attempt classifies hash-drift cause among 6 fail modes
       (timestamp / map iter / readdir / env / addr / concurrency).
    5. Iterate on hash-drift causes until stage 2 == stage 3 byte-equal.
    6. (Parallel-track) Build compiler/eval/ AST evaluator skeleton
       (~200–500 LOC) so option B is in place at retire time.
    7. Fire E2 — retire hexa_interp; flip `hexa run` to D mode (build+exec).
  EOF
  parallelizable = "step 1 / step 2 / step 6 are independent — steps 3–5 sequential gate"

# ─── §6 External citations ───────────────────────────────────────────

@X x_spec_2_1 := "SPEC.md §2.1" :: spec [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/SPEC.md#21-language-kind--native-compiled"
  scope = "language kind = native compiled; interpreter_only and interpreter_with_cache rejected"

@X x_spec_5 := "SPEC.md §5 (Bootstrap)" :: spec [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/SPEC.md#5-bootstrap--existing-hexa_interp-is-stage-0-decision-2"
  scope = "4-stage bootstrap table; D+B post-retire mode; rejected A (keep 20K interp) / C (JIT first)"

@X x_spec_15_e2 := "SPEC.md §15 E2" :: spec [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/SPEC.md#15-roadmap"
  scope = "E2 = retire hexa_interp after stage 3 fixed point (M effort)"

@X x_punch_v2 := "doc/stage1_punch_list_v2.md" :: status-ledger [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/doc/stage1_punch_list_v2.md"
  scope = "stage 1 punch list, P0 OOM closure (5/11 PM), wall-clock and P0 correctness items still open"

@X x_bootstrap_doc := "doc/bootstrap_stage_2_3.md" :: spec [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/doc/bootstrap_stage_2_3.md"
  scope = "stage 2 self-compile + stage 3 byte-equal harness; common hash-drift fail modes"

@X x_agents_tape := "AGENTS.tape" :: governance [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/AGENTS.tape"
  scope = "this repo's sole agent-harness + governance file; @D g5 (hexa-native-only) is parent of @D d1"

@X x_hexa_native_only := "HEXA-NATIVE-ONLY.md" :: policy [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/HEXA-NATIVE-ONLY.md"
  scope = "sibling doctrine — no LLVM / no C-transpile as architecture; this file complements with no-interpreter-as-architecture"

# ─── §7 Sibling doctrine matrix ──────────────────────────────────────

@N doctrine_matrix := "doctrine-coverage" :: note [active]
  text <<~EOF
    Three doctrine docs cover the architectural commitments:
      HEXA-NATIVE-ONLY.md  — backend: no LLVM, no C-transpile (architecture)
      COMPILE-ONLY.tape    — frontend/runtime: native compile only, no interp/JIT (architecture)
      LATTICE_POLICY.md    — verification: real-limits-first, n=6 lattice = tool not constraint
    All three appeal to SPEC.md as formal authority. AGENTS.tape registers
    them as @X external-citations and applies @D governance rules from them.
  EOF
