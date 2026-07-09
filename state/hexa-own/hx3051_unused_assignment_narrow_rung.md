# HX3051 — unused_assignments NARROW rung (write-only local `let mut`)

**Status:** shipped opt-in default-OFF · byteeq-neutral · FP=0 · P4 default-flip = follow-up
**Lint:** rustc `unused_assignments` (warn-by-default) — NARROW projection
**Flag:** `HEXA_UNUSED_ASSIGN=1` (`_unused_assign_on`) — SEPARATE from `HEXA_UNUSED_LET`
**Files:** `compiler/check/bind.hexa`, `compiler/diag/catalog.hexa`, `compiler/check/unused_assign_test.hexa`

## What it catches
A function-local `let mut x` that is WRITTEN via a pure `=` reassignment
(`x = …`) but whose value is never READ anywhere in scope.

```hexa
fn f() { let mut x = 1  x = 2 }   // HX3051: value assigned to `x` is never read
```

## rustc reference (정답지)
`rustc_passes::liveness` computes BOTH `unused_variables` and
`unused_assignments` from ONE backward liveness dataflow over an
intra-procedural CFG (RWU read/write/used triple per Variable per LiveNode,
`Liveness::compute` fixpoint).

- FULL `unused_assignments` flags a SPECIFIC dead store even when the variable
  IS read elsewhere (the store is overwritten / dies before any read) — this
  genuinely needs the per-program-point fixpoint (`live_on_exit`). **LARGE
  follow-up.**
- The NARROW rung shipped here = the degenerate projection "the variable is read
  at NO node" — a purely SYNTACTIC "no read-occurrence exists" test needing NO
  CFG/fixpoint. It is exactly HX3050's used-set MINUS the write-as-use
  conflation.

## Wire (all RE-ANCHORED on origin/main, ~279 behind HEAD at authoring)
1. **State** (`bind.hexa` ~:95) — `_unused_assign_on` (env `HEXA_UNUSED_ASSIGN`)
   + `_unused_written_ids: [i64]`, latched/reset in `_unused_let_reset()`.
   SEPARATE flag ⇒ HX3050's emitted stream is byte-identical when only
   `HEXA_UNUSED_LET` is set.
2. **Read/write split at the assign arm** (`bind.hexa` ~:1130) — gated on
   `_unused_assign_on`. When `e.text == "="` (PURE assign; the parser tags
   compound `+= -= *= /=` with a DIFFERENT `.text`, `parser.hexa`
   `parse_assignment` — VERIFIED; Eq token text is `"="`, `lexer.hexa`) AND
   `children[0]` is a BARE local Ident (non-`_`): resolve inline via
   `_bind_lookup` (HX2001-on-miss PRESERVED, mirroring the Ident arm), push
   `hit.index` to `_unused_written_ids` INSTEAD of walking through the read
   choke. RHS `children[1..]` always walked as reads. Compound ops or non-bare
   LHS (`a[i]=`, `p.f=` — place computation) keep the LHS a READ (FP-safe).
   Flag OFF → the else-branch reproduces the original walk EXACTLY.
3. **HX3050 non-overlap guard** (`bind.hexa` ~:1750) — only when
   `_unused_assign_on`, additionally require the candidate be ABSENT from
   `_unused_written_ids`. HX3050 then means exactly "never referenced at all"
   (absent from BOTH read used-set and written-set). The two lints never
   double-fire on one binding.
4. **HX3051 sweep + `_emit_hx3051`** — fires for a candidate present in
   `_unused_written_ids` AND absent from the read used-set. Accumulate + read-mark
   gated on `(_unused_let_on || _unused_assign_on)`.
5. **Catalog** (`catalog.hexa`) — HX3051 DiagSpec after HX3050: `Severity::Warning`,
   `S3`, template `value assigned to \`{name}\` is never read`, `FixItKind::None`.
   Parity 95/95 (`DiagSpec {` == `fix_it_kind:`).

## FP=0 basis
Locals have NO external linkage ⇒ a local is referenced ONLY via a source ident
descending the single name-resolution choke ⇒ the read-set is resolver-complete
(the same argument HX3050 relies on), MINUS the write-as-use conflation. Every
non-write reference stays a READ: compound-assign LHS (read-modify-write),
field/index LHS receiver (place computation), call-arg, closure-capture (resolves
up-chain through the choke), return. `_`-prefix excluded at the accumulate site.

## byteeq-neutral
env default-OFF ⇒ the assign choke does not split a write-set and the sweep is
skipped ⇒ nothing emitted ⇒ diag stream + codegen `.text` byte-identical.
PR-CI byteeq is the proof.

## Test
`compiler/check/unused_assign_test.hexa` — dual-flag matrix, `lex→parse→bind`
direct (no hexat):
- `hz_write_only` `let mut x=1  x=2` → HX3051 ×1, HX3050 0
- `fp_written_read` `let mut x=1  x=2  print(x)` → 0 / 0
- `fp_compound` `let mut x=1  x+=1` (`+=` is a read of x) → 0 / 0
- `fp_never_ref` `let x=1` (never referenced) → HX3050 ×1, HX3051 0 (non-overlap)
- `fp_underscore` `let mut _x=1  _x=2` → 0 / 0
- OFF sweep → all 0

## Follow-ups
- **P4 default-flip** — offline corpus census (0 false-warn) + faithful×3 GREEN +
  install.sh consumer smoke (never x86-only), same staged path as HX3050.
- **FULL unused_assignments dead-store** (var read elsewhere but THIS store
  overwritten before any read) — the fixpoint-requiring half. LARGE.
