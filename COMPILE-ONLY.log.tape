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

# ─── 2026-05-15  Track B — stage 2 codegen+assemble closure (c7-stack-spill) ───

@A stage2_codegen_landed := "stage 2 codegen+assemble PASS — GNU-as 2435→0" :: measurement [d=2026-05-15 ok]
  == open_stages_23
  step = "Path (b): HEXA_IGNORE_ERRORS=1 (58a3760e) lets stage 1 reach codegen; the emitted x86_64-linux-gnu asm then surfaced 3 codegen-operand bugs + 1 symbol-namespacing collision — all fixed."
  commits <<~EOF
    58a3760e feat(main)          — --ignore-errors / HEXA_IGNORE_ERRORS bootstrap escape
    2c1e6f46 fix(flatten)        — leaves-first order (module-level lets init before pipeline)
    fb09d4bf fix(codegen-arm64)  — cmp lhs must be register, not immediate (no x86 twin)
    90345921 fix(codegen-x86_64) — cmp/test lhs materialize (r10) + idiv single-operand seq
    3fe7bae0 fix(modules)        — per-module rename of 4 colliding file-local helper families
    7d725286 doc(compile-only)   — §4 @N stage2_codegen_clean (architecture, ~> stage2_partial)
    branch = c7-stack-spill (worktree agent-a92a7dd5f698cf370, unpushed — user merge gate)
  EOF
  |> "GNU-as error trajectory 2435 → 38 (cmp+test) → 26 (idiv) → 0 (symbols). stage2c.o = 364 KB x86_64 ELF, assembles clean."
  build_env = "Local macOS clang OOM-killed the 7 MB+540 KB monolithic TU (Killed:9); ubu-1 unreachable mid-run (SSH banner timeout); completed cross-build on ubu-2 (12c/30 GB x86_64). Linux clang-18 runtime.c needs `-include execinfo.h -Wno-error=implicit-function-declaration`; main_v13.c self-contained (#include runtime.c) — link WITHOUT separate runtime.o, -no-pie + non-pie runtime."
  => "codegen+assemble track CLOSED — the interp-retirement gate stack's stage-2 blocker is no longer in codegen/symbol layer"
  @> COMPILE-ONLY.tape
  authority = "[@x_bootstrap_doc] [@x_spec_5]"

@N gate_moved_frontend := "stage-2 blocker moved: codegen → front-end name-resolution" :: status [d=2026-05-15 partial]
  <- stage2_codegen_landed
  fact = "Linking stage2c.o → stage2 binary fails with undefined refs: main / is_alpha / is_alphanumeric / chars / len / to_string / <callee> ×594. These ARE the real content of the 3804 HEXA_IGNORE_ERRORS-suppressed FRONT-END diagnostics — not codegen."
  diagnostic_breakdown <<~EOF
    HX2001 1803 — <callee> 594 (fn resolution) + operator tokens [ ] ! , | &
                  misparsed as undefined names (~1000) + idents ~200
    HX3001  994 — _types_assignable coercion
    HX2002  993 — cross-module pub/private (_collect_item_types splice path)
    HX3002    9 / HX3004 1
  EOF
  root_cause = "operator-token-as-undefined-name ⇒ self-host parser expression-lowering (index/logical/bitwise/tuple) incomplete — a parse/bind/resolve gap, adjacent to 7da77859 fix(bind); architectural, separate track from codegen."
  next_step = "(1) parser expr-lowering [ ] ! , | & so operator tokens don't reach binder as Ident; (2) HX2002 cross-module pub/private; (3) HX2001 <callee> receiver-type plumbing; (4) HX3001 coercion. OR: PR/merge the 6-commit codegen track first."
  unblocks = "@phase_f_closure_criteria A1 (stage3 byte-equal) — still gated, gate relocated not removed"
  authority = "[@x_spec_15_e2] [@x_bootstrap_doc]"

@N ubu1_recovered := "build-env: ubu-1 reachable again" :: status [d=2026-05-15 ok]
  <- stage2_codegen_landed
  fact = "ubu-1 (Linux aiden-B650M-K, kernel 6.17.0-23-generic, x86_64) SSH-reachable again after the mid-run banner-timeout outage that forced the ubu-2 cross-build fallback. Both x86_64 build boxes now available for the front-end track."
  caveat = "Heavy builds still route to ubu-1/ubu-2 (local macOS clang OOMs the monolithic TU). Remote pattern: /tmp fresh clone, never force-reset the aiden worktree."

# ─── 2026-05-15  Front-end track — expression-operator lowering (branch) ───

@A frontend_expr_operators := "self-host parser: + operator lowering ! ~ & | ^ << >> && ||" :: measurement [d=2026-05-15 partial]
  <- gate_moved_frontend
  step = "Root-caused the operator-token-as-Ident leak: compiler/lex/lexer.hexa unknown-char fallback (TokenKind::Ident) → parser parse_primary fallback (ExprKind::Ident) → binder HX2001. The new self-host parser had NO token kinds or productions for ! ~ & | ^ << >> && || (only - unary and == != < <= > >= + - * / %). Legacy self/parser.hexa+lexer.hexa already implement them — faithful port, no invented grammar."
  changes <<~EOF
    tokens.hexa  +9 TokenKind: AmpAmp PipePipe Amp Pipe Caret Tilde Bang Shl Shr
    lexer.hexa   maximal-munch: && || << >> (multi-char) ; ! & | ^ ~ (single,
                 pre-fallback; != still Neq, && pre &, || pre |)
    parser.hexa  parse_unary += Bang/Tilde (text=op.text, was const "-");
                 +parse_logical_or/_and/_bitwise; parse_assignment descends
                 via parse_logical_or. Precedence loosest→tightest:
                 || < && < (& | ^ << >>) < == != < cmp < +- < */ < unary
                 (ref: self/parser.hexa parse_or/parse_and/parse_bit_ops)
  EOF
  census = "stage-2 input (compiler/+self/ *.hexa): !x 2724 · && 7932 · || 11251 · &|^ 1026 · <<>> 297 · ~ 63 — all heavily used, confirms the leak scale"
  |> "hexa parse clean on all 3 edited files (host-parser edit-level gate); no exhaustive TokenKind match exists to break on the +9 variants"
  branch = "frontend-expr-lowering @ c30de87a (off main 237faa9e; NOT pushed/merged — unverified parser surgery kept off main, mirrors codegen track's c7-stack-spill user-merge gate)"
  deferred <<~EOF
    Closure |x| / zero-arg || lambda is OUT of this increment: the new
    AST (compiler/parse/ast.hexa ExprKind) has NO Lambda/Closure variant;
    porting it is a cross-cutting AST + bind + lower + codegen change, not
    expression-operator lowering. After this change a primary-position `|`
    still hits the Ident fallback — but ONLY at genuine closure sites
    (~the real .map(|x| …) cases); every bitwise/operator `|` now parses
    correctly. Net: HX2001 operator leaks for ! ~ & ^ << >> && || and
    bitwise-| eliminated; closure-| residual is the next sub-track.
  EOF
  next_gate = "ubu-1/ubu-2 stage-2 self-compile re-run → confirm HX2001 1803 drops (expect ≥ ~1000 fewer: the operator-token-as-Ident class). Then: closure-|x| ExprKind::Lambda sub-track; HX2002 993 cross-module pub/private; HX2001 <callee> 594 receiver-type plumbing; HX3001 994 coercion. Not locally runnable (monolithic-TU clang OOM)."
  authority = "[@x_spec_15_e2] [@x_bootstrap_doc]"
  @> COMPILE-ONLY.tape

# ─── 2026-05-16  Front-end track — empirical verification attempts ───

@A frontend_tag_of_bug := "empirical bug: tag_of() exhaustive match missed +9 variants" :: measurement [d=2026-05-16 ok]
  <- frontend_expr_operators
  step = "Static grep on c30de87a landing scanned for 'match TokenKind' / ': TokenKind ->' patterns and reported no exhaustive switches needing the +9 variants. WRONG — `tag_of` in compiler/parse/parser.hexa uses `match k { TokenKind::… -> str }` over EVERY variant without a wildcard arm. `same_kind` routes all compares through tag_of, so unknown variants returned arbitrary strings (interp first-arm fall-through), silently breaking `check_kind` for new tokens. Empirical surface — found only when the live probe on RunPod showed `tag_of(TokenKind::Bang) == \"Ident\"`."
  fix_commit = "122ab8c4 (frontend-expr-lowering) / d694ce9e (stage2-verify) — adds AmpAmp/PipePipe/Amp/Pipe/Caret/Tilde/Bang/Shl/Shr arms"
  lesson = "future hexa-side enum extensions must check exhaustive-match-no-wildcard patterns more broadly than 'match\\s+.*\\.kind'. Or: add a `_ -> \"_UNKNOWN_\"` wildcard + a CI lint that flags it."
  authority = "[@x_spec_15_e2]"

@? frontend_verify_blocked_by_bootstrap_staleness := "stage-2 verification BLOCKED by bootstrap chain staleness" :: anomaly [d=2026-05-16 partial]
  <- frontend_expr_operators
  context = "User selected option (C) cloud-box path. Provisioned RunPod RTX PRO 6000 SECURE (188 GB RAM, Ubuntu 24.04, glibc 2.39) — memory wall removed; bootstrap chain mismatches are now the wall."
  failures <<~EOF
    Three staleness mismatches surfaced sequentially:

    1. hexa_interp.linux (in repo build/, May 15 15:42)
         — needs GLIBC_2.38 (only ubu24.04+ has it)
         — its enum-match runtime knows TokenKind variants AT BUILD TIME;
           when source adds +9 variants the match treats them as the first
           arm. tag_of(TokenKind::Bang) returned "Ident" empirically.
         — verdict: live-interp probe of new parser fundamentally blocked

    2. build/hexa_v2_linux (the transpiler, May 15 15:42)
         — transpile compiler/main.hexa succeeds but emits C referencing
           runtime symbols with signatures CURRENT runtime.c uses differently.
           clang error: `HexaVal sdk = hexa_str_trim(hexa_exec(…))` —
           hexa_exec now returns int, not HexaVal. 14 errors.
         — verdict: stale transpiler-vs-runtime gap

    3. clang self/native/hexa_cc.c + self/runtime.c (fresh, May 16)
         — compiles cleanly to /tmp/hexa_v2_fresh (1.5 MB ELF).
         — transpile runs, but emitted C references identifiers not declared
           by current header set: `undeclared identifier 'Severity_Error'`
           (etc). hexa_cc.c's embedded transpiler doesn't emit prelude
           #defines for some enum variants the current sources use.
         — verdict: hexa_cc.c (the bootstrap monolith) lags current sources
  EOF
  cost = "~$1 RunPod total — RTX 3090 probe (terminated quickly) + RTX PRO 6000 SECURE ~30 min. Pod terminated, no ongoing cost."
  diagnosis = "Bootstrap chain in delicate state — build/hexa_v2_linux + build/hexa_interp.linux + self/native/hexa_cc.c + self/runtime.c + compiler/* drift unevenly. Each verify path trips a different mismatch. Front-end fix structurally correct (faithful legacy port, hexa parse clean on all 4 edited files, lex of single-char operators verified producing TokenKind::Bang on pod live probe) — measuring the HX2001 1803 → drop NUMBER requires producing a current-bin stage 1, which itself requires a refreshed bootstrap."
  paths_forward <<~EOF
    A. Refresh bootstrap chain (separate sub-track):
       i.  `hexa cc --regen` on a known-good host to regenerate hexa_cc.c
           from current sources, then re-ship + re-attempt verification
       ii. OR rebuild build/hexa_interp.linux + hexa_v2_linux from current
           sources (needs a working hexa_v2 OR a known-good cross-build host)
    B. Accept structural evidence as sufficient for THIS track:
       i.   hexa parse clean on all 4 edited files (c30de87a + 122ab8c4)
       ii.  lexer empirically produces TokenKind::Bang for `!` on RunPod live probe
       iii. faithful legacy port (no invented grammar)
       Defer HX2001 1803 → drop NUMERIC measurement to path A landing.
    C. Architectural memory-fix in interp (parallel) — strbuf trap landing
       on main (ed04d3e1) addresses one O(n²) source but NOT the 30 GiB
       monolithic-TU peak; not on this track's critical path.
  EOF
  next_gate = "user decision: path A (bootstrap refresh, multi-hour) vs path B (accept + close as best-effort verified) vs other"
  authority = "[@x_spec_15_e2] [@x_bootstrap_doc]"
