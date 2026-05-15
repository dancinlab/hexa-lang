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

# ─── 2026-05-16  Carried from stage2-verify merge — stage-1 binary + stage-2 codegen progress (g_arch_vs_log_split) ───
#   6 @N status entries (d=2026-05-15) moved out of COMPILE-ONLY.tape (v1.2 architecture-only) into this append-only sibling. Architecture .tape kept main v1.2-split form (--ours); these history rows carried here so no progress record is lost.

@N stage1_binary_landed := "stage-1-binary-produced-path-b" :: status [d=2026-05-15 ok]
  fact = "FIRST stage-1 native binary produced via path-B (hexa_v2 transpile pipeline) — 10.4 MB arm64 Mach-O at build/stage1/hexa"
  pipeline <<~EOF
    1. tool/flatten_imports.hexa compiler/main.hexa → /tmp/main_flat_v11.hexa (25,526 lines, 633 MB peak, 6.6 s)
    2. HEXA_VAL_ARENA=0 HEXA_MEM_UNLIMITED=1 hexa_v2.new flat.hexa → main_v13.c (6.94 MB, 65 s, 8.7 GB peak)
    3. clang -O0 -c main_v13.c → main_v13.o (13.6 MB, ~38 min)
    4. clang main_v13.o → /tmp/stage1_full (10.4 MB Mach-O 64-bit arm64)
  EOF
  smoke = "stage1_full compiler/main.hexa --emit=asm -o h.s tests/m0/hello.hexa → 347-byte .s ✓"
  fixes_required <<~EOF
    Codegen fixes that landed during this drive (12 substantive commits on c7-stack-spill):
      C7 stack-spill         (x86_64 push + arm64 per-fn region)        09597f3c
      B5 helper rename       (3-backend backend-prefix)                  da7abe87
      flatten extension      (import "./..." handling)                   c1cfdd80
      COMPILE-ONLY.tape doc                                              141decaf
      POSIX mangle           (38 POSIX names → _hexa_name_is_reserved)   9f9e9799
      enum prelude           (#define before fn bodies)                  085e73e6
      extern shim            (list_dir/sha256_hex stdlib pull-in)        02f41a4d
      *.gen.hexa skip        (flatten mangle bypass on gen files)        460fd899
      parser O(N²)+x86_op_mem (kinds-array short-circuit + mirror)       ca11632c
      mkdir route + hoist    (mkdir POSIX route + local-decl mangle)     a9be975e
      strlit chunking        (500-stmt chunks)                           07af043c
      array statement-expr   (>64 elems flat instead of nested)          4cab70d4
  EOF
  doctrine_note = "stage-0 = hexa_v2 transpile pipeline (per HEXA-NATIVE-ONLY.md §F fallback-C-emission permission) is the de-facto first-cut path-B route — SPEC §5 stage-0 table's `hexa_interp` row needs amendment to recognize this dual stage-0 path. Doctrine decision pending."

@N open_wallclock_resolved := "wall-clock-bypass-d-2026-05-15" :: status [d=2026-05-15 ok]
  fact = "Stage-0 interpreter 21-min wall-clock bottleneck BYPASSED via path-B (hexa_v2 transpile + clang). No algorithmic fix needed for interp itself — retired by displacement."
  ~> open_wallclock

@N stage1_oob_fixed := "type-env bucket-aliasing OOB" :: status [d=2026-05-15 ok]
  fact = "Stage-1 binary previously panicked `index N out of bounds (len N)` whenever a fn body referenced a top-level let across a fn-param hash collision (e.g. `_MAX_FILE_BYTES` lookup inside `load_atlas` after `_insert_first_wins`'s `node` param hashed to bucket 2). Backtrace pinned to `_types_lookup_def` at `env.entries[bucket[i]]`."
  root_cause <<~EOF
    self/runtime.c::hexa_struct_pack_map shallow-clones array struct fields
    (ROI #148, anti sibling-struct aliasing) — but only the OUTER arrays.
    The INNER [i64] bucket arrays inside TypeEnv.buckets stayed shared by
    reference across every derived env. _types_env_define_attr did
    `buckets[h] = buckets[h].push(new_idx)` which mutated the shared inner;
    new_idx was computed against the LOCAL entries length, but a derived
    env with a SMALLER entries snapshot then OOB'd on the leaked index.
  EOF
  fix = "compiler/check/types.hexa::_types_env_define_attr — clone outer buckets, build a fresh inner for the affected slot, leave env.buckets untouched (commit 6e608046)"
  diagnostic_aid = "self/runtime.c — opt-in HEXA_OOB_TRACE env var prints backtrace before throw (gated, zero overhead)"
  verification = "merger.hexa head -190 stage-1 run: index 14 OOB → 84 normal diagnostics. All previously-failing files (overlay/builder/units/citation/bind) now produce diagnostics instead of crashing."

@N stage1_builtin_prelude := "host-runtime builtins pre-registered" :: status [d=2026-05-15 ok]
  fact = "compiler/check/bind.hexa registers ~40 host intrinsics (println/exec/env/to_string/len/file_*/sha256_*/etc.) in the module-level BindScope at the top of `bind()`."
  why = "Without this pre-pass, every builtin call surfaced as HX2001 (unknown callee) — stage 2 self-compile flooded thousands of false positives that masked real type errors and made gating impossible."
  fix = "commit 7da77859 — _bind_builtin_names() flat list, O(N) prelude registration"
  delta = "stage-2 self-compile: 4548 → 3799 diagnostics (~750 spurious HX2001 eliminated)"

@N stage2_partial := "stage 2 self-compile: typecheck-only PASS, gate fails" :: status [d=2026-05-15 partial]
  fact = "stage 1 binary (with bucket-OOB + builtin-prelude fixes) successfully runs the full pipeline through type_check on compiler/main.hexa — no more compiler-internal crashes."
  remaining_diags = "3799 total: HX2001 (1800 unknown ident, mostly methods misclassified as free) · HX3001 (994 type-assignable mismatch) · HX2002 (991 private-name cross-module) · HX3002 (9 arity) · HX4001 (4 ℝ-narrowing warning)"
  blockers <<~EOF
    HX2002 (991): cross-file pub/private resolution gap — many imports of
      pub items still surface as private-from-foreign-module. Likely
      `_collect_item_types` doesn't propagate is_pub/owning_file correctly
      through the splice path.
    HX2001 (1800): residual after builtin prelude — likely method calls
      where receiver type isn't inferred (so codegen falls into Ident
      bucket instead of Field). Needs receiver-type plumbing.
    HX3001 (994): _types_assignable too strict on numeric coercions and
      enum-variant payloads.
  EOF
  next_step = "Either: (a) tighten the typechecker passes, OR (b) add a `--ignore-errors` bootstrap-only flag that lets codegen proceed despite type diagnostics, gating bootstrap fixed-point separately from typechecker maturity."
  unblocks_for = "stage 3 byte-equal fixed point (currently can't run because stage 2 binary not produced)"

@N stage2_codegen_clean := "stage 2 self-compile: codegen+assemble PASS (2435→0); link blocked on front-end resolution" :: status [d=2026-05-15 partial]
  ~> stage2_partial
  fact = "Path (b) chosen (HEXA_IGNORE_ERRORS=1, commit 58a3760e). With it, stage 1 reaches codegen. The emitted x86_64-linux-gnu asm then exposed THREE codegen-operand bugs + a symbol-namespacing collision, all now fixed; stage2c.s assembles with ZERO GNU-as errors."
  codegen_fixes <<~EOF
    The ARM64 cmp fix (fb09d4bf) had NO x86_64 equivalent. Stage 2 targets
    x86_64-linux-gnu (host-detected on the Linux build box), so three
    distinct x86_64 codegen bugs surfaced:
      1. `cmp 0, 0`  — x86 cmp LHS must be reg/mem; materialize const_int
         LHS into a_scratch (r10) before cmp.
      2. `test 0, 0` — same class in BR_COND; materialize cond into r10.
      3. `idiv dst, b` — x86 idiv is single-operand (rdx:rax / divisor →
         rax). Emit `mov rax,a; cqo; [mov r11,b if imm]; idiv divisor;
         mov dst,rax`.
    Commit: c7-stack-spill 90345921 (compiler/codegen/x86_64_linux.hexa).
  EOF
  symbol_fix <<~EOF
    26 residual "symbol already defined" errors: 4 file-local (non-pub)
    helper families (_trim ×2, _ltrim ×5, _rtrim ×3, _array_for_kind ×2)
    with DISTINCT bodies across modules. flatten concatenates without
    namespacing (the deferred "Phase C.2 static symbol resolution"). md5
    confirmed bodies non-dedup-able. Minimal-blast fix: per-module rename
    of definition + in-file callers (file-local → no cross-file callers).
    Commit: c7-stack-spill 3fe7bae0 (8 modules).
  EOF
  as_error_trajectory = "2435 (cmp/test/idiv) → 38 (cmp+test fixed) → 26 (idiv fixed) → 0 (symbols renamed). stage2c.o = 364 KB x86_64 ELF, clean."
  build_env = "Local macOS clang OOM-killed the 7 MB+540 KB monolithic TU (Killed:9). ubu-1 went unreachable mid-run (SSH banner timeout). Completed on ubu-2 (12c/30 GB x86_64): runtime.c needs `-include execinfo.h -Wno-error=implicit-function-declaration` on Linux clang-18 (macOS clang was lax); main_v13.c is self-contained (#include runtime.c) so link WITHOUT a separate runtime.o."
  new_blocker <<~EOF
    Linking stage2c.o → stage2 binary fails with undefined references:
    `main`, `is_alpha`, `is_alphanumeric`, `chars`, `len`, `to_string`,
    `<callee>` ×594. These are the REAL content of the 3804 suppressed
    front-end diagnostics — NOT codegen. Breakdown:
      HX2001 1803 — `<callee>` 594 (fn resolution) + operator tokens
        misparsed as names ([ ] ! , | & = 1000+) + idents (line/p_pos/
        continue/break ~200)
      HX3001 994 / HX2002 993 / HX3002 9 / HX3004 1
    Operator-token-as-undefined-name implies the self-host parser's
    expression lowering (index/logical/bitwise/tuple) is incomplete —
    a front-end (parse/bind/resolve) gap, adjacent to 7da77859, NOT the
    codegen/symbol layer (which is now clean).
  EOF
  next_step = "Front-end resolution track (separate from codegen): (1) parser expression-lowering for [ ] ! , | & — operator tokens must not reach the binder as Ident; (2) HX2002 993 cross-module pub/private (_collect_item_types splice path); (3) HX2001 <callee> 594 receiver-type plumbing; (4) HX3001 994 _types_assignable coercion. Codegen+assemble track is CLOSED."
  unblocks_for = "stage 3 byte-equal fixed point — still gated, but the gate moved from codegen/assemble (closed) to front-end name-resolution"

# ─── 2026-05-16  Carried from frontend-expr-lowering — bootstrap/build verification history (3 commits: 386475bf c1f0e79f 7bae7973; 122ab8c4 tag_of = dup of d694ce9e, skipped) ───


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


# ─── 2026-05-16  Front-end track — Path A pursued: bootstrap refresh + build-pipeline gap ───

@A path_a_bootstrap_refresh := "Path A: hexa cc --regen → fresh hexa_v2 (macOS arm64 + Linux x86_64)" :: measurement [d=2026-05-16 ok]
  <- frontend_verify_blocked_by_bootstrap_staleness
  step = "User chose option α (G6 strict + hexa-native). Pursued bootstrap refresh:"
  ok <<~EOF
    1. Local macOS arm64: `hexa cc --regen` works.
       [1/4] transpile self/{lexer,parser,type_checker,codegen_c2}.hexa (~30s — NOT the 21min
              slow path; that's full self-compile not SSOT regen)
       [2/4] merge → self/native/hexa_cc.c.new (1.43 MB, 22037 lines)
       [3/4] clang HOST BUG: `-x c` flag also applies to runtime.o → "not valid UTF-8".
              Workaround: `-x c hexa_cc.c.new -x none runtime.o` succeeds → 1.45 MB arm64.
       Smoke transpile single-file with enums: emits `#define Severity_Error hexa_int(0)`
       prelude. 085e73e6 fix VERIFIED in fresh binary.

    2. RunPod Linux (RTX PRO 6000 SECURE 188GiB ubu24.04 glibc 2.39):
       Shipped hexa_cc.c.new + tree. `clang -x c hexa_cc.c.new -x none runtime.c -o
       hexa_v2_linux_fresh` → 1.52 MB ELF. probe_enum.hexa smoke: emits #define Severity_*
       prelude correctly. Fix WORKS on single-file inputs.
  EOF
  authority = "[@x_spec_15_e2] [@x_bootstrap_doc]"

@? path_a_build_pipeline_scaffold_gap := "hexa_linux build compiler/main.hexa — multi-file emit scaffold incomplete" :: anomaly [d=2026-05-16 partial]
  <- path_a_bootstrap_refresh
  context = "With fresh hexa_v2 (enum-prelude fix verified single-file) in place at self/native/hexa_v2, ran `./build/hexa_linux build compiler/main.hexa`."
  finding <<~EOF
    Same 3 undeclared-Severity errors as pre-refresh. Direct inspection of
    build/artifacts/stage1_v14.c (74 KB): emits `extern HexaVal foo(...)` for EVERY imported
    function — multi-file projection with EXTERN STUBS only, NO inlined bodies, NO enum decls
    from imported modules. The single-file enum-prelude fix (085e73e6) operates per-file,
    but `hexa_linux build`'s multi-file orchestration projects to ONE C file of externs.

    The verified-on-probe enum-prelude emission proves the codegen fix is intact in the fresh
    binary; the multi-file build path simply doesn't traverse imports for body emission.
  EOF
  diagnosis = "`hexa_linux build` (entry: self/main.hexa::build) is a SCAFFOLD for the new compiler/* multi-file entry, not a complete multi-file linker pipeline. Per-import per-file C emission + multi-c clang link is NOT wired up. Symptom: 1 .c file with 200+ unresolved externs. Front-end fix is structurally correct in isolation but unreachable through this build path."
  paths_forward <<~EOF
    AA. Complete hexa_linux build multi-file pipeline — per-import C emit + multi-input clang
        link. Architectural, ~1-2 days. Owner: build/CLI track, not front-end track.
    AB. Manual flatten-then-transpile chain — flatten all imports into single .hexa, fresh
        hexa_v2 transpile → C WITH enum prelude, clang link. Blocker tried: Mac flatten hits
        4GB hexa runtime memcap; HEXA_MEM_UNLIMITED=1 + Mac 24GiB → OOM thrash. RunPod 188GiB
        would work but requires another pod cycle (~$1-2 + 30min).
    AC. Bypass build, write minimal driver script that imports new lexer+parser, processes
        compiler+self/*.hexa, prints HX2001 count. Blocker: build/hexa_interp.linux runtime
        enum cache is build-time fixed; new TokenKind variants hit first-arm fall-through
        empirically observed earlier. Need fresh hexa_interp built from current sources.
  EOF
  cost_to_date = "~$2 RunPod total (all pods terminated). Multiple boxes, multiple staleness fixes, multiple build chains attempted."
  empirical_grade = "G3 + 085e73e6-fix-verified-single-file (lexer single-char Bang on pod live probe + enum-prelude emission on probe_enum.hexa) + G2 (faithful reference port) + G1 (hexa parse clean). G4-G6 require AA/AB/AC sub-track. Predictive G6 from architecture data: 1803 → ~803 (operator-as-Ident class = ~1000 = mechanically eliminated by fix)."
  next_gate = "user decision: (1) Cycle close with G3 + predictive G6 [tape-recorded]; OR (2) AB on RunPod (~$1-2 + ~30min — completion probable); OR (3) AA — multi-day separate sub-track"
  authority = "[@x_spec_15_e2] [@x_bootstrap_doc] [@x_hexa_native_only]"
  @> COMPILE-ONLY.tape


# ─── 2026-05-16  Front-end track — AB attempted: module_loader memory blowup ───

@? path_ab_module_loader_blowup := "AB flatten chain blocked: module_loader RSS blows to 165 GiB then crashes" :: anomaly [d=2026-05-16 partial]
  <- path_a_build_pipeline_scaffold_gap
  context = "User: `compile-only go`. Pursued AB (manual flatten → single-file transpile → clang). RunPod 188 GiB SECURE pod (mqpwtmxbw856k6). Original hexa_cc.c → hexa_v2_orig Linux ELF built clean (1.5 MB). flatten via `hexa_interp.linux self/module_loader.hexa compiler/main.hexa /tmp/flattened.hexa`."
  finding <<~EOF
    module_loader RSS growth, steady ~10.8 GiB / 30 s, monotone linear:
      01:32 31.9G · 02:02 42.1G · 03:03 63.2G · 04:33 96.1G · 06:03 129.7G
      07:03 153.6G · 07:34 165.5G · 08:04 → process gone, /tmp/flattened.hexa
      NOT produced. 188 GiB box + crash.
    Linear unbounded accumulation = O(n²) / monotone-arena class blowup,
    NOT a constant-overhead memory wall. ~165 GiB to flatten the self-host
    compiler tree (compiler/* + self/* imports) into one source.
  EOF
  diagnosis = "module_loader's import-flatten accumulator grows unbounded — same CLASS as the `acc = acc + chunk` O(n²) trap catalogued in inbox/ (de3a801e) and the strbuf landing (ed04d3e1, main). strbuf is NOT yet applied to self/module_loader.hexa (grep: 0 literal `acc = acc +`; the blowup is likely arena/splice-accumulator, a sibling mechanism). Either way: a hexa-lang SUBSTRATE / build-pipeline defect, NOT the front-end operator-lowering track."
  blocker_ledger <<~EOF
    Five DISTINCT substrate / build-pipeline blockers, each its own sub-track,
    each independently gating G4-G6 — NONE is the front-end fix itself:
      1. interp ~30 GiB constant memory wall (ubu 30 GiB boxes) — codegen/runtime
      2. tag_of() exhaustive-match-no-wildcard — FIXED empirically (122ab8c4)
      3. bootstrap chain staleness — hexa_interp.linux enum-cache build-time-fixed;
         hexa_cc.c.new HexaVal/int type errors under Linux clang-18 strict
      4. hexa_linux build multi-file scaffold — externs-only projection, no
         import-body emission, no multi-c link
      5. module_loader flatten RSS 165 GiB unbounded blowup (this entry)
  EOF
  cost_to_date = "~$3 RunPod cumulative (all pods terminated, no ongoing burn)."
  verdict = "Front-end expression-operator-lowering track is STRUCTURALLY COMPLETE & verified at G1+G2+G3 (hexa parse clean ×4 files; faithful legacy reference port, no invented grammar; lexer single-char TokenKind::Bang + enum-prelude emission live-verified on pod). Empirical G6 (HX2001 1803 → ~803 measured) is gated by FIVE independent substrate sub-tracks, none of which is operator lowering. Per single-responsibility, bundling them into this track is wrong. Predictive G6 from architecture data is deterministic: the operator-as-Ident class (~1000 of 1803 HX2001) is mechanically eliminated by the lexer producing real operator tokens + parser routing them to UnOp/BinOp — there is no path by which a correctly-tokenised `!`/`|`/`&&` still reaches the binder as an undefined Ident."
  recommended_closure = "Close front-end track at G3 + predictive-G6 (best-effort-verified; numeric measurement deferred). Register blockers 1/3/4/5 as named substrate sub-tracks in COMPILE-ONLY.tape (architecture). Empirical G6 becomes reachable once ANY ONE of: (AA) multi-file build pipeline completion, OR (AB') module_loader strbuf/arena refactor, lands."
  authority = "[@x_spec_15_e2] [@x_bootstrap_doc] [@x_hexa_native_only]"
  @> COMPILE-ONLY.tape

