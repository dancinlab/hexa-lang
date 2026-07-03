# RFC — Advanced type system for hexa (borrow checker · lifetimes · associated types · HKT)

- Status: **research-RFC / design-scale ceiling (정직 천장)** — NO compiler code changed by this document.
- Scope: borrow checker, lifetimes (`'a`), associated types, higher-kinded types (HKT).
- Captured: 2026-06-27.
- SSOT lockstep: `ARCHITECTURE.json#language-surface` Tier-2 ("Rust-only gaps"), CHANGELOG.
- Sibling precedent: `ARCHITECTURE.json#language-surface` static-generics/monomorphization slice
  (the only Tier-1 feature that got a byteeq-safe opt-in slice — used here as the template for
  "how a Rust-grade feature lands under hexa's frozen-substrate + byteeq constraints").

---

## 0. Why this is an RFC, not an implementation

This is **honestly a design-scale ceiling (🧱 design-scale)**, not a tractable feature. Three of
hexa's load-bearing design choices each individually defeat a naive port of these four features,
and they compound:

1. **hexa is dynamically typed.** Every value is a runtime `{tag,payload}` HexaVal
   (`compiler/ir/lir.hexa:77,84` — "Module-level mutable globals — one writable 16-byte HexaVal
   slot"; `compiler/ir/mir.hexa:80,104`). Typecheck/codegen **erase** generics:
   `compiler/parse/parser.hexa:1808-1816` parses `fn` items with `return_type`/params but no type
   identity survives to codegen, and `compiler/check/types.hexa:1-20` is an explicit S3 stub that
   synthesises types "without lowering the AST". Borrow checking, lifetimes, associated types, and
   HKT are all **static-type-system** features — they have nothing to attach to at the point hexa
   currently throws type information away.

2. **The arena IS the lifetime model.** hexa allocates through a bump arena
   (`HEXA_RT_ALLOC_NATIVE`; memory `project_hexa_alloc_not_a_wall` — "arena bump 이미 native…
   hexat …free=0=arena-bump-only"). There are no per-value destructors, no RAII, no move
   semantics that free memory: `own`/`borrow`/`move`/`drop` are **recognized keyword tokens**
   (`self/bootstrap.hexa:94-97`) but carry NO checking and NO codegen — the arena's scope owns all
   lifetimes (`ARCHITECTURE.json#language-surface` Tier-2: "arena-scope owns lifetime"). A borrow
   checker's entire job (statically prevent use-after-free / aliasing-XOR-mutation) is **vacuous**
   under an arena that never frees mid-scope. It only becomes meaningful if/when hexa grows a
   non-arena allocation mode (e.g. the `HEXA_STREAM_RECLAIM` free-tree path, memory
   `project_hexa_rfc061_m2_freetree_gated_live`).

3. **byteeq determinism + frozen seed.** Every codegen/runtime change must keep the DEFAULT emit
   byte-identical on 3 targets (x86_64-linux · arm64-linux · darwin-arm64), and the parser is a
   **frozen blob (parent `151c52c8`)** that cannot learn new keywords or new `@attr` names without
   a faithful build-break (CLAUDE.md 가드레일; memory
   `project_hexa_deepfn_r4_parser_spine_frozen_method_wall`). So every slice below must (a) reuse
   **already-recognized** tokens (`own`/`borrow`/`move`/`drop`/`<T>`) or the **generic annotation
   capture** (`self/parser.hexa:161-165` "raw-arg capture"), and (b) be `default-OFF` with the
   flag-unset asm proven byte-identical — exactly the discipline the monomorphization slice
   followed.

**Conclusion up front:** none of the four features is a from-scratch-implementable lane today. Each
is a *checker/analysis* layer that presupposes a static type lattice hexa does not have. The
release-safe, honest path is a **staged opt-in lint/analysis ladder** that adds *advisory* static
reasoning (warnings, not hard errors; never gating DEFAULT codegen) on top of the existing
recognized tokens, deferring any value-representation change to a much later, separately-RFC'd
stage. This RFC specifies that ladder per feature.

---

## 1. Reference reading (정답지 — reference-first, file/section cite)

White-box differential: read the reference's algorithm + invariants, map onto hexa's IR, align
only at the divergence point. Sources consulted:

- **Rust borrow checker (NLL / Polonius).**
  - rustc dev guide, "MIR borrow check" — borrowck runs on **MIR**, after type-check, as a
    dataflow analysis over *loans* and *regions*; it is a **separate pass** that consumes typed MIR
    and never changes codegen (rustc_borrowck crate; `rustc-dev-guide.rust-lang.org` →
    *Borrow checking* and *MIR borrowck*). Key invariant: **aliasing XOR mutability** — at most one
    `&mut` OR many `&`, enforced by region/loan liveness, *not* by runtime cost.
  - NLL RFC 2094 (`rust-lang/rfcs` `text/2094-nll.md`): lifetimes are **liveness of references**,
    computed per-MIR-point, not lexical scopes. This is the crucial mapping for hexa: a hexa
    borrow checker would be a **MIR-level dataflow pass** (`compiler/ir/mir.hexa`), structurally
    the same place rustc puts it — *after* the (currently-stub) type stage.
  - Polonius (`rust-lang/polonius`): reformulates borrowck as Datalog over `loan_issued_at` /
    `subset` / `origin_live_on_entry` relations — a declarative spec that is portable to any IR
    with a CFG. hexa's MIR has the CFG (`compiler/ir/mir.hexa` STMT_BR_COND etc.), so the *spec*
    transfers even though the *value model* does not.

- **Rust lifetimes `'a`.** rustc-dev-guide *Region inference* + RFC 2094. Lifetimes are **erased
  before codegen** (`'a` has zero runtime representation) — this is the single most important
  parity point with hexa: lifetimes are a **compile-time-only** annotation, so adding them is
  byteeq-neutral *by construction* (they cannot reach the emitted bytes). The wall is purely the
  *checker*, never the codegen.

- **Rust associated types.** RFC 0195 (`text/0195-associated-items.md`) + Reference §"Associated
  Items". An associated type is a **type-level function**: `trait Iterator { type Item; }` lets
  `<T as Iterator>::Item` resolve a type from the impl. Requires (a) trait resolution and (b) a
  type projection mechanism. hexa has `impl T For X` **parsing only** (`self/parser.hexa:2603`, per
  ARCHITECTURE.json) — no trait resolution, no projection. Associated types are therefore *gated
  behind* a trait-resolution layer that itself does not exist.

- **Haskell higher-kinded types (HKT).** GHC type system / "Typing Haskell in Haskell" (Jones) +
  the kind system: HKT means abstracting over **type constructors** (`Functor f` where `f :: * ->
  *`), requiring a **kind system** (`*`, `* -> *`, …) layered above the type system. Rust
  deliberately lacks HKT (the GAT/`type Item<'a>` work in RFC 1598 / RFC 2289 is the partial
  workaround). HKT presupposes (a) a type system, then (b) a kind system *above* it — two layers
  hexa has zero of. This is the **deepest** of the four walls.

**Parity → beyond-parity lever (hexa-unique strength, per CLAUDE.md):** hexa's `@cite(L[id])` /
`@verify` / `@grace` atlas-citation gate (stage S8, fatal `HX8004`) is a *proof-obligation*
surface no reference language has. The beyond-parity direction (Stage 4 below) is to let a borrow
*proof obligation* be discharged by an **atlas law citation** rather than only by the dataflow
solver — i.e. a function asserting an aliasing invariant could `@cite` a verified law, unifying the
borrow checker with hexa's existing verification economy. That is the one place hexa could go
*past* rustc's model rather than merely re-implementing it.

---

## 2. Conflict / coexistence matrix

| Feature | Conflict with dynamic `{tag,payload}` | Conflict with arena | byteeq risk | Frozen-parser risk |
|---|---|---|---|---|
| **Borrow checker** | High — needs static aliasing knowledge that erased types don't carry | **Vacuous** under bump-arena (nothing frees) — only meaningful with `HEXA_STREAM_RECLAIM` free-tree | **None if advisory** (warning-only, post-codegen analysis) | Low — reuse `own`/`borrow`/`move` (already tokens, `self/bootstrap.hexa:94-97`) |
| **Lifetimes `'a`** | Medium — `'a` annotations have no value-level meaning | Arena scope already = the (single) lifetime | **None — erased before codegen by construction** | **High** — `'a` is new lexer syntax the frozen blob can't read → must encode in annotation strings, NOT new tokens |
| **Associated types** | High — type-level function over erased types | Low (compile-time only) | **None if advisory** | Medium — needs trait resolution first; reuse `impl…For` (already parses) |
| **HKT** | **Severe** — requires a type system + a kind system above it; hexa has neither | Low (compile-time only) | None if advisory | High — kind syntax is new |

Reading: the **byteeq column is the good news** — all four are compile-time-only static analyses, so
an *advisory* (warning-emitting, non-gating) implementation is byteeq-neutral by construction
(they never touch emitted bytes). The **real wall is the missing static type lattice**: every
feature needs a type/trait/kind layer that hexa erases. The honest sequencing is therefore
*build the lattice first, advisory-only, default-OFF*, and only ever promote to hard errors behind
an explicit opt-in flag.

---

## 3. Opt-in introduction path (release-safe invariants)

Every stage obeys the same four invariants (mirroring the monomorphization slice that already
landed this way):

1. **default-OFF env flag.** `HEXA_BORROWCK=1`, `HEXA_LIFETIMES=1`, `HEXA_ASSOC_TYPES=1`,
   `HEXA_HKT=1`. Flag-unset ⇒ pass is a no-op ⇒ DEFAULT asm byte-identical on 3 targets (CI-proven,
   same as `tool/test_monomorphize_emit.sh` asm-grep precedent).
2. **advisory-first.** New diagnostics are **Warnings** (like `HX4001` domain hint,
   `compiler/check/types.hexa:10-18` "Warning only … doesn't gate codegen"), NOT fatal. Promotion
   to fatal (`HXnnnn`) is a *second* opt-in flag (`HEXA_BORROWCK_STRICT=1`) gated separately.
3. **no new keywords / no new `@attr`.** Reuse recognized tokens (`own`/`borrow`/`move`/`drop`/
   `<T>`) and the generic annotation capture (`self/parser.hexa:161-165`). Lifetime / kind syntax
   that the frozen parser can't lex is encoded **inside annotation argument strings** (e.g.
   `@verify("lifetime: a outlives b")`), never as new lexer tokens. Frozen blob `151c52c8` stays
   byte-faithful.
4. **emitter SSOT for any runtime piece.** No runtime-rep change in this RFC at all; if a far-future
   stage needs one, it goes through the `.hexa` emitter, never a hand-edited `.c`.

---

## 4. Per-feature ladder (step-by-step, each rung byteeq-safe)

### 4.1 Borrow checker — the most tractable (advisory MIR dataflow)

The arena makes runtime borrow *enforcement* vacuous, but **advisory aliasing lint is still
useful** (catch obvious `&mut` aliasing bugs at compile time, warning-only) and is the natural
on-ramp to a future free-tree allocator.

- **R1 (census, byte-neutral, PR-able now-ish):** add `compiler/check/borrow.hexa` as a MIR
  **read-only** pass that, under `HEXA_BORROWCK=1`, walks `compiler/ir/mir.hexa` blocks and records
  `borrow`-token-annotated bindings. Emits a single advisory `HX46xx (Warning)` when a `move`-marked
  value is used after move within one MIR block (intra-block only — cheapest, no region inference).
  No flag ⇒ pass never runs ⇒ byte-identical. Reference: rustc "MIR borrowck is a separate pass
  over typed MIR" — we copy the *placement*, scope down to intra-block.
- **R2:** lift to **inter-block liveness** (NLL-style "lifetime = liveness of reference", RFC 2094):
  compute reference liveness over the MIR CFG (the CFG already exists — STMT_BR_COND). Still
  warning-only. This is the rung where the Polonius `origin_live_on_entry` relation maps onto
  hexa's CFG.
- **R3 (opt-in strict):** behind `HEXA_BORROWCK_STRICT=1`, promote aliasing-XOR-mutation violations
  to fatal `HX46xx`. Still default-OFF ⇒ DEFAULT builds unaffected.
- **R4 (beyond-parity, far):** discharge a borrow obligation via `@cite(L[id])` atlas law — the
  hexa-unique lever (§1). A function that asserts a non-aliasing invariant can satisfy the checker
  by citing a verified law instead of by solver inference.
- **Wall on this lane:** real *enforcement* (freeing on scope-exit) is blocked until a non-arena
  allocator exists (`HEXA_STREAM_RECLAIM` free-tree, currently census-only — memory
  `project_hexa_rfc061_m2_freetree_gated_live`). Advisory lint is the honest ceiling until then.

### 4.2 Lifetimes `'a` — byteeq-trivial, parser-syntax-blocked

- **Conflict:** lifetimes are erased before codegen in rustc ⇒ **byteeq-neutral by construction**
  for hexa too. The ONLY wall is **lexer syntax**: `'a` is not a token the frozen parser
  (`151c52c8`) can read, and adding it is a forbidden new-keyword change.
- **R1:** encode lifetime relations **inside annotation strings** the generic capture already
  swallows (`self/parser.hexa:161-165`), e.g. `@verify("'a: &x outlives &y")`. Under
  `HEXA_LIFETIMES=1`, `borrow.hexa` parses these strings and feeds the R2 liveness solver above.
  No new tokens, no new `@attr`, byte-neutral.
- **R2:** region-inference advisory (rustc *Region inference*) over the same MIR liveness graph —
  report when an annotated `outlives` relation is violated. Warning-only.
- **Wall:** native `'a` *syntax* requires touching the frozen lexer ⇒ blocked until a frozen-seed
  re-pin event (out of scope for any byteeq-safe slice). Annotation-string encoding is the honest
  ceiling.

### 4.3 Associated types — gated behind trait resolution

- **Prerequisite that doesn't exist:** `impl T For X` parses (`self/parser.hexa:2603`) but there is
  **no trait resolution and no vtable** (ARCHITECTURE.json#language-surface Tier-1). Associated
  types are a *type-level projection* (`<T as Trait>::Item`, RFC 0195) that needs trait resolution
  first.
- **R1 (depends on a separate trait-resolution RFC):** once a trait table exists, add associated
  type *bindings* as named entries on the impl, resolved at compile time, advisory-only (warn on
  unresolved projection). Byte-neutral (compile-time only).
- **Wall:** this lane is **blocked on trait/vtable dispatch** (itself a Tier-1 gap with no slice).
  Associated types cannot precede it. Honest status: deferred until trait-dispatch RFC lands.

### 4.4 HKT — the deepest wall (two missing layers)

- **Conflict:** HKT abstracts over **type constructors** (`f :: * -> *`), which presupposes (a) a
  working type system and (b) a **kind system** above it (GHC kinds; "Typing Haskell in Haskell").
  hexa has neither — `compiler/check/types.hexa` is a stub. Rust itself omits HKT and only
  approximates with GATs (RFC 1598/2289).
- **Honest verdict:** **closed for the foreseeable** under the dynamic-erasure design. There is no
  byteeq-safe slice because there is no type lattice to put a kind lattice on top of. The only
  forward motion is a *documentation* node: record HKT as a measured design-scale wall and point
  at GATs as the eventual-parity proxy *if* a static type system ever lands.
- **First non-vacuous rung (far):** a kind-checker would only make sense after §4.3 (associated
  types) and a real type lattice exist — i.e. it is **two RFCs deep**. Not actionable now.

---

## 5. Dependency DAG (what unblocks what)

```
static type lattice (compiler/check/types.hexa stub → real)   ← root wall, separate RFC
        │
        ├── trait resolution + vtable (Tier-1 gap, no slice)
        │        └── associated types (§4.3)            ← blocked on trait resolution
        │                 └── HKT / kind system (§4.4)  ← blocked 2 layers deep
        │
        └── MIR liveness dataflow (CFG already exists)
                 ├── borrow checker advisory (§4.1)     ← TRACTABLE on-ramp (warning-only)
                 │        └── strict enforcement         ← blocked on non-arena allocator
                 └── lifetimes advisory (§4.2)           ← byteeq-trivial, blocked on `'a` lexer syntax
```

Only the **left branch's first rung (borrow-checker advisory R1)** and **lifetimes R1
(annotation-string encoding)** are byteeq-safe-implementable today. Everything else is gated on a
real static type lattice / trait resolution / non-arena allocator — each a separate design-scale
RFC.

---

## 6. First byteeq-safe slice this RFC authorizes (NOT shipped here)

Per the "구현 규율 — implement-to-the-wall" rule, the smallest honest forward slice is:

- A new **read-only** MIR pass `compiler/check/borrow.hexa`, gated `HEXA_BORROWCK=1` (default-OFF),
  emitting one advisory `HX46xx (Warning)` for intra-block use-after-`move` on `move`-token-marked
  bindings (tokens already recognized, `self/bootstrap.hexa:94-97`).
- Test parity with the monomorphization precedent: `tool/test_borrowck_advisory.sh` asserting (a)
  flag-unset asm is byte-identical on the 3 byteeq targets, (b) flag-set emits the expected warning
  on a crafted use-after-move fixture.

This slice is **not implemented in this document** (this PR is docs-only, per the task's RFC
mandate). It is the authorized R1 for a follow-up implementation lane — the same shape that landed
static-generics safely.

---

## 7. Honest wall statement (🧱 design-scale)

The advanced type system is a **measured design-scale ceiling**, not a build wall:

- **Root cause (measured by reading the source, file:line cited above):** hexa is dynamically
  typed with arena lifetimes and an erasing codegen; all four features are static-type-system
  analyses that have no lattice to attach to. The arena makes borrow *enforcement* vacuous; the
  frozen lexer blocks native `'a`/kind syntax; trait resolution (a prerequisite) does not exist.
- **What IS byteeq-safe-tractable now:** advisory-only borrow lint (§4.1 R1) and annotation-string
  lifetime relations (§4.2 R1) — both warning-only, default-OFF, byte-neutral.
- **What is genuinely blocked (and on what):** strict borrow enforcement (non-arena allocator),
  native lifetime syntax (frozen-seed re-pin), associated types (trait resolution RFC), HKT (a kind
  system two layers above a type system that doesn't exist).
- **Not punting:** the honest next move is the §6 advisory borrow-lint slice as a separate
  implementation PR, plus a trait-resolution RFC as the prerequisite for the right branch. This
  document is the design SSOT those lanes consume.
