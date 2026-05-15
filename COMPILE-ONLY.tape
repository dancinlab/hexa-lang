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
# v1.2 architecture-vs-history split: this .tape file holds the current
# architecture state (policy clauses · forbidden patterns · closure
# criteria · citations). Per-commit landings / status-transition events
# live in COMPILE-ONLY.log.tape (append-only sibling).
#
# Authority chain: SPEC.md §2.1 (language kind = native compiled) ·
#                  SPEC.md §5    (4-stage bootstrap, hexa_interp = stage 0)
#                  SPEC.md §15   (E2 = retire hexa_interp after stage 3)

@V := "tape" :: spec [active]
  version = "1.2"

@I id001 := "hexa-lang.compile-only" :: identity-claim [d=2026-05-15 active]
  kind = "native compiled language with bootstrap-only interpreter"
  brief = "compile-only doctrine + E2 (hexa_interp retire) gate stack — architecture SSOT for the no-interp-as-architecture stance"
  parent = "dancinlab/hexa-lang"
  sibling-log = "COMPILE-ONLY.log.tape"
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
       Full closure per [@phase_f_closure_criteria] — 43-condition matrix
       (31 required + 12 recommended); cut-over subset = A1–A4 + B1–B5 + C5.
  EOF
  parallelizable = "step 1 / step 2 / step 6 are independent — steps 3–5 sequential gate"

# ─── §5a Phase F closure criteria — 43-condition matrix ──────────────

@D phase_f_closure_criteria := "e2-100pct-closure-d-2026-05-15" :: governance [required]
  rule = "E2 (hexa_interp retire) is 100% closed iff all 31 required conditions are satisfied AND verified. 12 recommended conditions cover safety net (rollback) + cross-repo + ergonomics."
  cut_over_subset = "A1-A4 + B1-B5 + C5 (=10 conditions) trigger E2 fire; remaining 33 are post-cut-over wave, except H (rollback) which MUST precede cut-over"
  total_required = 31
  total_recommended = 12
  total = 43
  criteria <<~EOF
    # A. Technical preconditions (REQUIRED, all 4) — must precede E2 fire
    A1 [req] sha256(build/stage3/hexa) == sha256(build/stage2/hexa)
    A2 [req] tests/bootstrap/run_bootstrap.sh exit 0 + status FIXED_POINT_PASS
    A3 [req] tests/m0/run_m0.hexa exit 0 on stage-3 binary
    A4 [req] self/test_*.hexa transitive PASS on stage-3 binary

    # B. Replacement surfaces (REQUIRED, all 6) — D mode + B mode functional
    B1 [req] `hexa run x.hexa` = AOT build + exec via ~/.hexa-cache/<hash>
    B2 [req] Cache invalidation on source mtime / content-hash change
    B3 [req] `hexa repl` interactive REPL via compiler/eval/ (e.g., `2+2` → `4`)
    B4 [req] `hexa run --interp x.hexa` opt-in uses compiler/eval/ AST evaluator
    B5 [req] compiler/eval/ LOC ∈ [200, 500] per SPEC §5 (option B)
    B6 [rec] D-mode cold-start ≤ 2× legacy interp; warm hit ≤ 0.1×

    # C. Consumer migration inside hexa-lang (REQUIRED 6 + 1 rec)
    C1 [req] LSP (self/lsp.hexa) runs as native binary, not via hexa_interp
    C2 [req] bin/* tools (proposal_inbox, hexa-commit, hexa-push, …) all D mode
    C3 [req] hooks/ + .hook-commands/ fire under D mode
    C4 [req] tool/*.hexa scripts all D mode (smoke per script)
    C5 [req] tests/bootstrap/run_bootstrap.sh references stage-3 binary, zero hexa_interp fallback
    C6 [req] module_loader.hexa subprocess pattern (alias-rewrite, py-import) D-mode compatible
    C7 [rec] bench/*.hexa all D mode

    # D. Cross-repo downstream safety (RECOMMENDED, all 4)
    D1 [rec] wilson (~/core/wilson) — no hexa_interp binary references
    D2 [rec] echoes + anima + hexa-* family repos — broad grep clean
    D3 [rec] ~/.wilson/identity.tape + incoming/patches/ scrubbed of hexa_interp paths
    D4 [rec] wilson POOL.md + firmware/boards/ hexa_interp paths replaced with D-mode

    # E. Artifact removal (REQUIRED 5 + 2 rec)
    E1 [req] build/hexa_interp* binaries deleted (all variants)
    E2 [req] self/interpreter.hexa + self/interpreter.hexa.c removed
    E3 [req] self/runtime.c interp-only paths excised — D-mode helpers only (target <5K LOC, was ~12K)
    E5 [req] hexa.real.bak.* backups ≤ 1 (keep last working for rollback chain)
    E7 [req] `hexa` shim → stage-3 binary (no hexa_interp ref)
    E4 [rec] self/bc_vm.hexa explicit decision (keep / archive / delete) recorded as @D entry
    E6 [rec] launchd/*.plist hexa_interp references replaced

    # F. Doctrine updates (REQUIRED 4 + 3 rec)
    F1 [req] SPEC.md §15 E2 row → CLOSED d=YYYY-MM-DD marker
    F2 [req] SPEC.md §5 stage table → historical-note for stage 0
    F3 [req] COMPILE-ONLY.tape @D d4 e2-retire-trigger → grade `fired d=YYYY-MM-DD`
    F4 [req] COMPILE-ONLY.tape @F f1..f3 audit — `deprecated` grade for entries that lose meaning post-retire
    F5 [rec] README.md — remove interpreter-as-architecture claims, history-only mentions
    F6 [rec] HEXA-NATIVE-ONLY.md — §I "interp sunset" axis added + closed mark
    F7 [rec] AGENTS.tape (no edit required; cross-cite only)

    # G. Verification regression (REQUIRED 3 + 2 rec)
    G1 [req] bench/*.hexa under D mode — perf ≥ pre-retire baseline (warm ≥ 10× faster expected)
    G2 [req] test/ + tests/ full suite green on stage-3 binary
    G3 [req] Daily-workflow manual smoke: hexa-commit / proposal_inbox / /loop / LSP
    G4 [rec] Sister repo smoke (wilson session_start, anima phi_engine, echoes audit) PASS
    G5 [rec] .github/workflows/* CI green

    # H. Rollback plan (RECOMMENDED, all 4) — H1-H4 MUST be done BEFORE cut-over
    H1 [rec] doc/interp_restore.md — 30-min restore procedure documented
    H2 [rec] archive/hexa_interp_last/ — last working interp binary + build-env metadata (90-day retention)
    H3 [rec] git tag pre-e2-fire — restore branch-point
    H4 [rec] Rollback dry-run executed once — `git checkout pre-e2-fire && ./hexa --version` works
  EOF
  verification_hint <<~EOF
    Each condition is designed to be single-command verifiable:
      grep / sha256sum / wc -l / exit-code check / file-existence test.
    A future tool/phase_f_audit.hexa can iterate the criteria and emit a
    per-condition PASS/FAIL/SKIP report — drop-in CI gate before E2 fire.
  EOF
  authority = "[@x_spec_5] [@x_spec_15_e2]"
  @> SPEC.md

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
