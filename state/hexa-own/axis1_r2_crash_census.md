# axis-① R2 — crash-where-clang-works census

**Verified on origin/main `31194bf07`** (worktree off origin/main; the mini working
tree was stale for `hir_to_mir.hexa`, so all line refs below are the fresh tree).

**Question.** Enumerate the `.hexa` constructs where the default C-transpile (clang /
`hexa_cc.c` → hexat) path COMPILES but the native own-IR path
(`compiler/lower/hir_to_mir.hexa` + `compiler/codegen/*`) ABORTS (loud HX110x punt →
C fallback) or MISCOMPILES (silent — the fallback does *not* catch it). Rank the next
`hexa_cc.c`-drop lowering rungs by *frequency in real sources × load-bearing*, to size
the remaining COMPILE-coverage gap toward the `cmd_build` default-flip.

---

## Headline finding

**The LOUD abort class (HX1101/HX1102/HX1103/HX1104) is measured NEAR-DRAINED for the
real language surface.** Every discrete lowering arm that fires on any in-tree `.hexa`
source has been closed; the two arms named in the task just closed the last two that
had *any* theoretical trigger:

- **#4732 (neglit, R1b)** — `unop -` negative-literal match arm, `hir_to_mir.hexa:6041`
- **#4739 (const-ident, R1c)** — bare-ident pattern that resolves to a module const →
  refutable COMPARE instead of an irrefutable binder, threaded through the `ident` arm
  (`hir_to_mir.hexa:5701`).

The `hexa_cc.c` that survives on the default `cmd_build` path is therefore **no longer
kept alive by a missing lowering arm** — it is kept alive by (a) the dispatch wiring
(`cmd_build` forks hexat unconditionally, an ①-R1/host-coverage problem, not a codegen
gap) and (b) the **SILENT miscompile class** the delegate-fallback cannot see. The
"drain another HX110x arm" well is dry; the frontier has moved to the crash census.

### Evidence the abort class is drained

**Match-pattern dispatch (`_lower_arm`, `hir_to_mir.hexa` ~5650–6120).** Handled arms:
`match_guard · wildcard · ident` (+ R1c const-ident refutable sub-case) `· enum_path ·
literal_int · literal_string · literal_bool · literal_char · literal_float ·
struct_pattern · unop "-"` (neglit). Only then the `else → _emit_hx1102(pat.kind)`
(`:6098`), which covers **or-patterns (`A | B ->`, parsed as a `binop` bitor), range
patterns (`a..b ->`), tuple patterns, and any arbitrary-expression pattern.**

**Corpus scan (compiler + stdlib + self, `*.hexa`):**
- or-pattern match arms (`A | B ->`): **0**
- range-pattern match arms (`a..b ->`): **0**

The parser has no dedicated or/range/tuple pattern grammar
(`parser.hexa:1381 parse_match_pattern` → wildcard / struct-lookahead / else
`parse_expr()`), and **no in-tree source uses these shapes** — so the HX1102 `else`
never fires on real code. It is a defensive catch-all, not a live gap.

**Unknown-HExpr (`_emit_hx1103`, `:6639`).** `_lower_hexpr` on origin/main dispatches
every `ExprKind` that survives desugaring: `array_lit · assign · atlas_ref · binop ·
block · break · call · closure · continue · defer · enum_path · field · ident · if ·
index · let · literal_* · match · return · struct_lit · throw · try · tryop · unop ·
while`. `For` and `Range` are desugared to `while`+index in `ast_to_hir.hexa:1603-1642`
before MIR; `wildcard`/`field_lit` are pattern / struct-lit-child contexts. **No
surviving ExprKind is undispatched** → HX1103 is defensive-empty for well-formed input.

**`_emit_hx1104` (`:3012`) is DEAD** — zero call sites anywhere in `compiler/`. Closures
are fully lowered (`:5636`), so the "@lazy / closure-codegen-deferred" niche cited in
older design docs (`no_hexacc_round1_design_fable.md:24`) is stale; there is no live
HX1104 or `@lazy` punt in the lowering core (`grep @lazy compiler/lower compiler/check`
= 0).

**`_emit_hx1101` (`:3335`) residual = resolver bugs, NOT lowering-coverage.** The `nil`
literal (`:3276`) and fn-ref-as-value (`:3314`, TAG_FN auto-wrap) fast-paths are in;
what remains fatal is a genuinely unbound name (cross-file resolution failure). That is
a bind/resolve correctness axis, not a construct the C path "supports" — clang-hexat
would emit the same undefined-name error. Not a `hexa_cc.c`-drop rung.

---

## The real gap: the SILENT miscompile / crash-where-clang-works class

The delegate-fallback (`self/main.hexa` leg-B / `HEXA_BUILD_NATIVE`) catches emit
*failures* (a loud HX110x → non-zero rc → fall to C). It does **not** catch a native
binary that emits, links, runs, and produces the WRONG answer or SIGSEGVs. This is the
legacy "**13 native-crash-where-clang-works**" number
(`selfhost_done_criterion_dag_fable.md:17,25`; `no_runtime_c_no_cc_verdict.md:73`) —
the true trust-gate for any `cmd_build` default-flip, and the only class that can burn a
user on a "green" flip.

The dominant, load-bearing member:

- **x86_64 HexaVal pair-carry miscompile** — `F-RT-NATIVE-X86-CODEGEN-ROOTCAUSE`. The
  x86_64 backend uses a raw 1-register int value-model; a returned HexaVal
  `{tag,payload}` drops `rdx`/payload at store → SIGSEGV in e.g. `hexa_array_push`
  (`compiler/codegen/x86_64_linux.hexa`, regalloc/store path; wall recorded
  `no_runtime_c_no_cc_verdict.md:59`, `done_axis23_next_rounds_plans.md:75`). arm64 is
  the existence proof it is fixable — arm64 carries the pair via `_hv_load/_hv_store`,
  byte-identical (Z2a). Recorded as a "multi-week value-model rearch, not a targeted
  patch" and owned by **axis-②-R4**, not a `lower/` arm. Fires on any fn returning a
  boxed `{tag,payload}` through a store — extremely common — so it, not any HX110x arm,
  is what actually blocks a trusted x86_64-linux `cmd_build` native default.

The other legacy "13" members are compiler-side SIGSEGVs already closed
(escape-scan runaway recursion #4693 and siblings — `escape_scan_trycatch_fix.md`,
`stack_alloc_default_on.md`: 980-module differential = 0 new SIGSEGV), i.e. the census
number is stale-high and needs a live re-measure (see Rank 2).

---

## RANKED next `hexa_cc.c`-drop rungs (frequency × load-bearing)

| # | Rung | Class | Freq in real src | Load-bearing | Owner / cost |
|---|------|-------|------------------|--------------|--------------|
| **1** | **x86_64 HexaVal pair-carry** (`{tag,payload}` return/store, `x86_64_linux.hexa`) | SILENT miscompile | **High** (every boxed-value return through a store) | **Maximal** — the one thing that blocks a *trusted* x86_64-linux `cmd_build` default-flip | ②-R4 value-model rearch (multi-week, pool-gated); arm64 = existence proof |
| **2** | **Crash-census instrumentation vehicle** — `HEXA_RUN_NATIVE_TRACE=1` differential + a *miscompile-zero* gate (native vs C, rc+stdout) over a real build corpus | Measurement | n/a | **High** — converts the stale "13" into a live count, proves abort-class = 0, and enumerates any residual silent miscompile beyond #1 | This lane's true deliverable; pool-run (aiden/summer). No trusted flip without it |
| **3** | **HX1102 or-pattern / range-pattern arm** (`A \| B ->`, `a..b ->`) | LOUD abort | **0** today | Low (byte-neutral; only bites if a future stdlib/compiler source adopts the shape) | Cheap `lower/` arm — clone the literal arm into an or-splitter / range-compare. The **only remaining discrete lowering rung** |
| **4** | HX1103 unknown-HExpr · HX1104 (dead) · HX1101 resolver residual | defensive / resolver | 0 | none | Not lowering-coverage; do **not** spend a rung |

---

## Verdict for the `cmd_build` default-flip

The COMPILE-coverage gap (loud aborts) is **effectively closed** for the real language
surface — no discrete `lower/` arm remains that fires on in-tree code. What still keeps
`hexa_cc.c` on the default path is **not** a missing lowering arm but:

1. the **silent x86_64 value-model miscompile** (Rank 1, ②-R4) — the true correctness
   blocker the fallback can't catch; and
2. the **absence of a live crash-census + miscompile-zero measurement** (Rank 2) to
   prove the flip is safe.

No new HX110x lowering arm moves the flip closer. The honest ①-R3 is therefore the
**crash-census instrumentation vehicle (Rank 2)** — stand up the
`HEXA_RUN_NATIVE_TRACE` differential + miscompile-zero gate on a real build corpus so
the legacy "13" becomes a measured live number and the x86 pair-carry (Rank 1) is the
named, tracked residual it catches. Rank 3 (or/range HX1102 arm) is the only remaining
*discrete lowering* fix, but is 0-frequency and byte-neutral — a cleanup, not a flip
enabler.
