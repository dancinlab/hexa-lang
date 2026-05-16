# PLAN — stage-3 Path A (codegen HexaVal-ABI correctness, arm64-first)

> Authority: `COMPILE-ONLY.log.tape` `@D d_stage3_abi_path` (A chosen; B
> bootstrap-fatal). This file is the file/function-level implementation
> blueprint for the dedicated Path-A effort. Tracked as tasks #1–#5.

## Problem (proven)

`sizeof(HexaVal)=16` (`{HexaTag tag(4); union{i64/f64/ptr…}(8)}`, 8-aligned,
non-HFA). AAPCS64 ⇒ HexaVal is passed/returned in a **register pair**
(arg0→x0:x1, arg1→x2:x3, …, arg3→x6:x7, then 16B stack) and returned in
**x0:x1**. The new `compiler/codegen/arm64_darwin.hexa` models every value
as ONE 8-byte register/slot ⇒ every call drops the payload half and
mis-marshals multi-arg calls; raw `add`/`cmp` on tagged structs is also
semantically wrong. This pervades every call/op/param/return/local.

## Chosen tactic: A′ — memory-resident HexaVal (codegen_c2-proven model)

Every SSA value is a **16B frame slot**; the codegen threads slot
addresses, not register-resident values. This avoids a pair-aware
register allocator (the highest-risk part of plain A) and mirrors the
proven `self/codegen_c2.hexa` value model (which already self-hosts via
the C path). Slower (memory-resident) but correct; optimise post-bootstrap.

HexaVal in two GP regs / a 16B slot:
- low 8B  (slot+0 , xLo): `tag` (4B) + 4B pad
- high 8B (slot+8 , xHi): the union payload (i64 / f64 bits / pointer)

TAG values (runtime.h): INT=0 FLOAT=1 BOOL=2 STR=3 VOID=4 ARRAY=5 MAP=6
FN=7 CHAR=8 CLOSURE=9 VALSTRUCT=10.

## Sub-units (verification column states the ONLY honest signal)

- **S1 (task #1) value/slot model.** DONE-atom: spill stride 8→16
  (`b01b79ae`, regression-verified). REMAINING: force every SSA value to
  a 16B slot (no register residency — make `_arm_is_spilled` effectively
  always true / regalloc assign a slot to every id); `_arm64_op_resolve`
  for `local` yields the slot (addr `sp+off`, 16B), not a single reg.
  Verify: assembles (structural only).
- **S2 (task #2) call ABI + literals.** STMT_CALL: for arg i<4 `ldp
  x{2i},x{2i+1},[sp,#slot]`; args 4..7 likewise to x6:x7 then 16B stack
  slots; `bl`; `stp x0,x1,[sp,#dstslot]`. Param prologue: `stp` incoming
  pair regs into each param's slot. Literals → construct the 16B value
  inline into the dst slot: const_int n → xLo=0(TAG_INT),xHi=n; const_str
  → xLo=3(TAG_STR),xHi=adrp/add .LCstr; bool → xLo=2,xHi=0/1. Verify:
  assembles + links (after S4) — structural.
- **S3 (task #3) value-op routing.** STMT_BINOP/compare: `ldp` both
  operand pairs into AAPCS64 arg pairs, `bl _hexa_add|_hexa_sub|_hexa_mul|
  _hexa_div|_hexa_eq|_hexa_lt|…` (mirror codegen_c2's op→runtime map),
  `stp` result. STMT_BR_COND: load cond, `bl _hexa_truthy` (or tag/val
  test), `cbz`. Verify: assembles — structural.
- **S4 (task #4) residual builtins + _main; THE verification gate.**
  Finish int/box/inline builtins (len/contains/starts_with/has_key/
  is_alpha/is_alphanumeric) per codegen_c2; synthesise C-ABI `_main`
  (argc/argv → hexa args, call hexa entry). Then link .o+runtime →
  stage-2; run stage-2 self-compile; **byte-diff vs stage-1 .s**.
  **This is the FIRST and ONLY honest correctness signal for S1–S4** —
  byte-equal ⇒ stage-3 fixed point ⇒ E2 unblocked. S1–S3 commits are
  structural checkpoints, NOT verified milestones (a broken pair/ptr
  model still assembles); this is stated honestly in each commit.
- **S5 (task #5) mirror to x86_64_linux + thumbv7em** once arm64 is
  byte-equal proven.

## Integrity note

S1–S3 have no honest per-commit verification (assemble ≠ correct for a
value-model change). They are committed as explicitly-labelled structural
checkpoints of one entangled unit whose sole correctness gate is S4's
byte-diff. No commit in S1–S3 will be described as a verified milestone.
Tree-safety invariant: every commit must still `clang -c` cleanly (the
assemble milestone is never regressed) so S4 is always reachable.

## S4 status (empirical, real pipeline)

A′ value-model PROVEN: clang -c -arch arm64 the A′-emitted .s →
rc=0, 0 errors, .o ~1.59MB (21457 asm errors driven to 0 across
ldp/stp-offset, frame-imm, hexa_add_slow fixes). builtin box-
lowering complete (sha256/println renames; len→int-box; contains/
starts_with→bool-box; has_key→cstring+bool; is_alpha/is_alphanumeric
runtime shims). **ld Undefined: 10 → 1 — the SOLE remaining link
blocker is `_main`.**

### Final S4 unit — `_main` entry synthesis (front-end + lowering + codegen)

Root cause (precise): compiler/main.hexa is script-style (15 fns +
large top-level driver stmts L640-777, no `fn main`). The new
front-end drops it: `hir_to_mir.lower_hir` (hir_to_mir.hexa:1623)
processes ONLY ITEM_FN (→MFunc) and ITEM_LET (→ a global Local
slot — **the initializer RHS is dropped**); it never captures
module top-level statements and never synthesises an entry. hexa_v2
(C path) is the only thing that ever produced an entry (its
generated `int main(){ hexa_set_args; __hexa_strlit_init;
<global inits>; <top-level stmts> }`).

Required (mirror hexa_v2 main):
  1. parser/AST: ensure module top-level executable statements +
     each ITEM_LET initializer expr are retained in the Module
     (today lower_hir can't see them — confirm parser representation
     first; may be an AST/Module gap, not just lowering).
  2. lowering: synthesise a `main` HIR→MIR MFunc = [ global-init
     assignments in source order ; top-level driver stmts ].
  3. codegen (arm64_darwin): emit that MFunc with the C-ABI `_main`
     label + an `hexa_set_args(argc,argv)` prologue (argc=w0/x0,
     argv=x1 per AAPCS64 `int main(int,char**)`), NOT the mangled
     hexa symbol.
Then: link .o + runtime.c → stage-2 → run stage-2 self-compile →
byte-diff vs stage-1 .s = the S4 verdict (stage-3 fixed point ⇒ E2).
