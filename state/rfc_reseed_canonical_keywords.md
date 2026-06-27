# RFC — Re-seed for canonical keyword tokens (Wall B) · PLAN-ONLY de-risk ladder

Status: **PLAN-ONLY** (no seed touched · no re-seed executed · no compiler-source
edit). This RFC is a design + de-risk ladder + RISK assessment for promoting the
contextual-identifier language-surface words (`type`/`trait`/`impl`/`dyn` and the
resource words `extern`/`own`/`borrow`) to **real keyword tokens** on the native
byteeq-fixpoint front-end. It deliberately stops at the gate: the actual re-seed
is the highest-risk substrate operation in the repo and is forbidden here.

Lane: `reseed-canonical-keywords` (Go/Rust language-surface parity census,
ARCHITECTURE.json `#language-surface` → "Wall B" subsection).
SSOT cross-link: ING #4090.

---

## 0. TL;DR

- **Wall B** = the self-imposed *"no new keyword token"* discipline. Every new
  language-surface keyword is currently routed through a contextual-identifier /
  name-prefix / whitelist hook so the frozen bootstrap seed (blob `151c52c8`)
  never meets a token it cannot lex.
- **Wall C** = the byte-identical self-host fixpoint (`gen3 ≡ gen4`, 3-target)
  *already* mechanically detects any re-seed that diverges the bootstrap chain.
- Therefore **Wall B is duplicate insurance.** A re-seed that promotes the
  contextual words to canonical keyword tokens is *permissible* — it is gated
  not by a hand-rule but by **byteeq 3-target GREEN + consumer smoke BEFORE the
  pinned-seed flip**.
- The cheaper-than-expected path (OPEN, to be measured on pool): if the corpus
  is **collision-clean** (no candidate word used as an identifier anywhere), the
  frozen seed can *still build a working gen1* — keyword behavior only matters
  from gen1 onward — so the minimal change is **add-tokens + clean-corpus +
  let-byteeq-prove-convergence**, with a full blob re-freeze kept *optional*
  (hygiene / fallback).
- **Nothing in this RFC modifies compiler source or the seed.** Plan only.

---

## 1. Motivation

The .hexa native front-end (`compiler/lex` + `compiler/parse`) currently has no
keyword tokens for `type`, `trait`, `impl`, `dyn`, or `extern`. To add the
language-surface features that need those words, every landing so far has paid a
"contextual-identifier tax": the word is lexed as a plain `Ident`, and the
parser peeks for it by *text* at a decl-leader position, then carries the
construct on a pre-existing `ItemKind` so no new token and no new exhaustive
`match` arm is introduced. This is correct and byteeq-neutral, but it is
**non-canonical**: it diverges from how every mainstream compiler (rustc, go,
zig, swift) reserves these as hard keywords, it leaves `trait`/`impl`/`dyn` as a
front-end *hole* (only the bootstrap `self/` front-end parses them at all), and
it accretes special-case peek hooks that future maintainers must remember.

The goal of an eventual re-seed is to **retire the contextual-ident workarounds**
and let the native front-end lex these words to real keyword tokens
(`KwType`/`KwTrait`/`KwImpl`/`KwDyn`/`KwExtern`), matching the bootstrap
front-end which **already reserves all of them** (`self/lexer.hexa:25`
`keyword_list()` — `type`/`struct`/`enum`/`trait`/`impl`/… ; `self/lexer.hexa:61`
`is_keyword()` / `:128` `keyword_kind()`).

The reason this is *safe to contemplate at all* is the trust already supplied by
Wall C: byteeq compares **bytes** across the bootstrap chain, so a re-seed that
disagrees with the corpus surfaces as a build-time RED, never as a silent
miscompile. Wall B (the hand-rule) is then **duplicate insurance** — useful as a
default-deny reflex, but not the actual safety mechanism. This RFC formalizes
that relationship and lays the ladder for when the cleanup is worth landing.

---

## 2. Reference (정답지) — rustc bootstrap

The white-box reference is the rustc multi-stage bootstrap, mapped 1:1 onto the
hexa frozen-seed discipline:

| rustc                                            | hexa                                                       |
|--------------------------------------------------|------------------------------------------------------------|
| `src/stage0.json` pinned beta compiler           | frozen seed blob `151c52c8` (faithful-build root)          |
| stage0 (beta) → stage1 → stage2 fixpoint         | gen1 → gen2 → gen3 ≡ gen4 byteeq fixpoint (Wall C)         |
| `#[cfg(bootstrap)]` dual-arm                      | contextual-ident path kept compilable by the OLD seed      |
| beta-bump + strip `#[cfg(bootstrap)]`            | re-seed (new blob) + delete the contextual-ident hooks     |
| edition-gated keyword promotion (`dyn` in 2018)  | corpus-collision clean-up MUST precede the token flip       |

Two load-bearing lessons from rustc:

1. **Rename every genuine identifier collision BEFORE promoting the word.** rustc
   could not turn `dyn` into a keyword in edition 2015 because real code used
   `dyn` as an identifier; the promotion was deferred to a new edition after the
   ecosystem migrated. The hexa analogue: each corpus collision is renamed first
   (byteeq-neutral, lands as ordinary commits), and *only then* is the word
   promoted.
2. **Strip-after-bump ordering.** rustc deletes the `cfg(bootstrap)` arms only
   *after* the new beta is published as stage0. The hexa analogue: delete the
   contextual-ident hooks only *after* the new seed is published as the default
   pinned blob — never in the same change that introduces the new tokens.

---

## 3. Current state — what Wall B routes around

### 3a. The native front-end has NO keyword tokens for these words

- `compiler/lex/tokens.hexa:74-97` — the `TokenKind` `Kw*` variants
  (`KwFn`/`KwLet`/`KwStruct`/`KwEnum`/`KwMatch`/`KwPub`/`KwImport`/`KwAs`/`KwTry`/
  `KwCatch`/`KwThrow`/…) contain **NO** `KwType`, `KwTrait`, `KwImpl`, `KwDyn`,
  or `KwExtern`.
- `compiler/lex/lexer.hexa:69` `keyword_kind(word)` maps every word not in its
  explicit cascade to `TokenKind::Ident` (the `return TokenKind::Ident`
  fallthrough at the end of the fn). So `type`/`trait`/`impl`/`dyn`/`extern` all
  lex as `Ident` on the native path.

### 3b. The 5 native contextual-ident hooks (measured file:line)

1. **`extern fn`** — `compiler/parse/parser.hexa:2294` `_peek_is_extern_kw()`
   (`peek().text == "extern"`) + `:2299` `parse_extern_fn_item(...)` (carries the
   construct on `ItemKind::Fn` → zero `ItemKind`-variant ripple).
2. **`type Name = …`** — `compiler/parse/parser.hexa:2369` `_peek_is_type_kw()`
   (`peek().text == "type"`) + `:2374` `parse_type_alias_item(...)` (carries on
   `ItemKind::Let` + bare `__type_alias` marker + `@phase("parse_only")`; see
   `state/rfc_type_alias.md`).
3. **`parse_item` dispatch** — `compiler/parse/parser.hexa:2434` (extern arm) /
   `:2439` (type arm): each guarded by the peek hook AND a `peek_at(1)` lookahead
   (`extern` requires a following `KwFn`; `type` requires a following `Ident`
   name) to disambiguate from any other `Ident`-led form.
4. **module-scope decl-leader guard** — `compiler/parse/parser.hexa:2652-2653`:
   the top-level decl loop re-checks the same two peek-hook predicates so an
   item-leader `extern`/`type` is recognized at module scope.
5. **`trait`/`impl`/`dyn`** — **NO native hook at all** (front-end hole). They are
   recognized only by the bootstrap `self/` front-end; the native parser sees
   them as bare `Ident` and has no decl form for them.

### 3c. The bootstrap `self/` front-end ALREADY reserves all candidates

- `self/lexer.hexa:25` `keyword_list()` lists `type`/`struct`/`enum`/`trait`/
  `impl` (+ `extern`/`own`/`borrow`/`dyn`/`as` elsewhere in the cascade).
- `self/lexer.hexa:61` `is_keyword()` / `:128` `keyword_kind()` map them to hard
  keyword kinds (`type`→`Type`, `trait`→`Trait`, `impl`→`Impl`, `extern`→
  `Extern`, `dyn`→`Dyn`, `as`→`As`).
- `self/parser.hexa:1373-1374` dispatch `Impl`→`parse_impl_block()` /
  `Trait`→`parse_trait_decl()`; `:1428-1429` dispatch `Extern`→
  `parse_extern_fn()` / `Type`→`parse_type_alias()`.
- `self/parser.hexa:624` `p_is_contextual_kw_kind()` returns `false` — *all*
  historical contextual keywords have been demoted out of the contextual path on
  the bootstrap front-end; they are now strict.
- `self/parser.hexa:644` `p_is_strict_reserved_kw_kind()` (binding-name guard)
  already lists `Trait` (`:658`) and `Impl` (`:659`) as strict-reserved, so they
  cannot be used as binding names on the bootstrap front-end.

**Consequence:** the bootstrap front-end is already collision-clean for these
words. The re-seed work is therefore concentrated entirely on bringing the
*native* front-end (`compiler/lex` + `compiler/parse`) up to the bootstrap
front-end's keyword reservation, then deleting the contextual hooks of §3b.

---

## 4. The de-risk ladder

Each rung is **pool-build / PR only** (mini = git/gh; build/byteeq = aiden /
summer). **No seed touch until the rung below is GREEN-on-pool.**

### Step 1 — Enumerate workarounds + corpus-collision census

- **Enumeration: DONE** (§3b above — 5 native hooks + the sibling carriers).
- **Corpus-collision census** (read-only mini scan; raw identifier-position hits
  needing pool triage, NOT yet a clean count):

  | word    | raw hits | note                                            |
  |---------|----------|-------------------------------------------------|
  | `type`  | 61       | many are already decl-leaders, not collisions   |
  | `impl`  | 16       |                                                 |
  | `own`   | 96       | resource word; large surface                    |
  | `dyn`   | 2        |                                                 |
  | `trait` | 0        | no collision                                    |
  | `borrow`| 0        | no collision                                    |

  `self/` is **already collision-clean** (§3c). The raw hits above are a *triage
  ceiling*, not a confirmed collision set — most `type`/`impl` hits are
  decl-leader uses that BECOME keywords (not collisions). Pool triage classifies
  each hit as (a) decl-leader → promoted, or (b) genuine identifier → renamed.
- **rustc edition lesson applied:** rename every genuine identifier collision
  FIRST (byteeq-neutral, ordinary commits), BEFORE promoting the word. This rung
  lands entirely without touching the seed or any token table.

### Step 2 — New-seed build recipe on aiden / summer

- Add `KwType`/`KwTrait`/`KwImpl`/`KwDyn`/`KwExtern` to
  `compiler/lex/tokens.hexa` + the matching `keyword_kind` arms in
  `compiler/lex/lexer.hexa`, and real keyword-dispatch arms in
  `compiler/parse/parser.hexa`.
- Keep the contextual-ident path **compilable by the OLD seed** (rustc
  `cfg(bootstrap)` dual-window): the new dispatch arms must coexist with the
  peek-hook arms for one transition generation, so the frozen seed (which still
  lexes the words as `Ident`) parses the changed compiler source unchanged.
- Build the candidate seed on pool.
- **GATE = byteeq 3-target GREEN (x86_64-linux · arm64-linux · darwin-arm64) +
  consumer smoke (`hexa --version` + hello / exit42 run) BEFORE any pin flip.**

### Step 3 — Faithful-build break analysis

- The faithful-build break, *if any*, is a **tokenization disagreement on the
  corpus**: the old frozen seed lexes a candidate word as `Ident`; the rebuilt
  gen1 lexes it as a keyword.
- If the corpus is **collision-free** (Step 1 complete), the frozen seed and gen1
  agree on **every** token (a non-collision word in identifier position never
  appears, so the only occurrences are decl-leaders, which the old seed already
  routes through the contextual hook and the new seed routes through the keyword
  arm — same AST shape, same bytes). The chain converges and `gen3 ≡ gen4` holds.
- A **missed collision** surfaces as a **byteeq RED on pool** — never a silent
  miscompile — because byteeq compares bytes. A new `TokenKind` variant also
  ripples through exhaustive `match TokenKind` sites, which surfaces as a
  **build-fail on pool** (the pool compiler refuses a non-exhaustive match),
  again never a silent miscompile.
- **Therefore byteeq is the complete and sufficient detector.** This is the
  precise sense in which Wall B is duplicate insurance: Wall C would catch
  exactly the failure Wall B forbids.

### Step 4 — Release-integrity > self-host guardrails

- The **pin flip is LAST**, gated on byteeq 3/3 + consumer smoke. **One target
  green ≠ all green** (v0.241.0 arm64-asset regression lesson).
- If the chain is **not green-able**, **DEFER the cleanup.** The contextual-ident
  workarounds are *correct*, merely non-canonical; Wall B stays up and the
  release ships unbroken. Self-host progress NEVER overrides release integrity.
- **Strip-after-bump:** delete the contextual-ident hooks (§3b) only *after* the
  new seed is published as the default pinned blob — never in the same change
  that introduces the new tokens.

---

## 5. The cheaper path (OPEN de-risk insight — measure on pool)

A full **pinned re-freeze may not even be required.** Keyword behavior only
matters from gen1 onward; the frozen seed's job is merely to *build a working
gen1*. If the corpus is collision-clean, the frozen seed — which treats the
candidate words as valid `Ident`s — can still build a correct gen1 that, from
then on, treats them as keywords.

So the **minimal validated change** is:

```
add Kw* tokens  +  clean the corpus  +  let byteeq prove convergence
                                          (re-freeze = OPTIONAL hygiene/fallback)
```

**Prefer the minimal change validated by byteeq BEFORE any actual blob
re-freeze** — that is the single biggest risk-reducer, because it avoids touching
the frozen blob `151c52c8` at all in the common case. A full re-freeze stays in
the back pocket as hygiene (so future readers see a self-consistent seed) or as a
fallback if the collision-clean assumption is falsified on pool.

This insight is **OPEN** — it must be confirmed by captured pool byteeq output,
never by LLM self-judgement.

---

## 6. RISK (highest-risk substrate)

1. **Whole-faithful-build blast radius.** The frozen seed roots the *entire*
   bootstrap chain; a bad seed poisons every generation. There is **NO opt-in
   isolation** — a seed flip is global by construction (you cannot gate it behind
   an env flag the way `HEXA_MONOMORPHIZE` / `HEXA_EXHAUSTIVE` gate feature
   slices). The only containment is the **dual-window + byteeq gate**.
2. **mini cannot build.** All build / byteeq / smoke validation is pool-only
   (aiden / summer; akida forbidden). This RFC is **plan-only by hard
   constraint.** Any validated claim requires *captured pool byteeq output*; no
   claim of GREEN may rest on LLM self-judgement.
3. **Must be pool-validated byteeq 3-target GREEN + smoke before ANY pin flip.**
   One target green ≠ all green (v0.241.0 lesson). The `finalize` discipline
   (3/3 needed) applies.
4. **OPEN de-risk (defer to pool, see §5):** a pinned re-freeze may not be
   strictly required; prefer the minimal add-tokens + clean-corpus +
   let-byteeq-prove path, with re-freeze optional.
5. **Reversible.** Both the pin bump and the workaround deletion are revertible.
   Delete workaround code ONLY after the new seed is published default
   (strip-after-bump order, §2 lesson 2).
6. **Scope = token-only.** This RFC covers promoting the *words* to keyword
   *tokens* only. It does **NOT** introduce any new `ItemKind` variant or new
   `@<attr>` keyword — those are separate, larger re-seeds with their own
   exhaustive-`match` ripple. The frozen blob `151c52c8` is untouched until the
   gated flip.

---

## 7. Non-goals

- No compiler-source edit, no seed edit, no re-seed execution in this RFC.
- No `default-ON` flag, no new keyword landed, no new `ItemKind`/`@attr`.
- No build or byteeq run from mini (CI / pool only).
- Not a roadmap commitment — actionable items live on the ING board (#4090);
  history in CHANGELOG + git.

---

## 8. Deliverables (this change)

- `state/rfc_reseed_canonical_keywords.md` — this document (plan-only).
- `ARCHITECTURE.json` `#language-surface` → "Wall B" subsection — one line noting
  the RFC has landed (the design body already lives in that cell).
- `CHANGELOG.jsonl` — one append-only entry (doc-only).
- **NO** compiler-source / seed edit. **NO** re-seed executed. **NO** build run.

---

## 9. r2 — corpus collision census (MEASURED · doc-only)

**Goal.** §4 Step 1 left the collision count as a *triage ceiling* (raw hits, not
a clean count). §5 hinged the whole "re-freeze may be unnecessary" insight on the
corpus being **collision-clean**. r2 measures that assumption directly — does the
EXISTING native contextual detection (`_peek_is_extern_kw` / `_peek_is_type_kw`)
ever misclassify a corpus identifier as a keyword? **Measure, not LLM-judge.** All
greps below are read-only on mini (no build, no seed touch).

### 9a. Why most "raw hits" cannot collide — the detection is item-position-gated

The two native hooks fire ONLY at module-item-dispatch position AND only behind a
`peek_at(1)` lookahead (measured §3b, `compiler/parse/parser.hexa`):

- `:2434` `_peek_is_extern_kw() && same_kind(peek_at(1).kind, KwFn)` → `extern`
  is a keyword **only when immediately followed by the `fn` keyword token**.
- `:2439` `_peek_is_type_kw() && same_kind(peek_at(1).kind, Ident)` → `type` is a
  keyword **only when at item position followed by an Ident name**.
- `:2652-2653` the synthesized-main top-level loop re-checks the *same two
  lookahead-guarded predicates*.

Identifier uses — field access (`x.type`), struct/named-arg fields (`type:`),
param/var names (`type,` / `type)`) — live inside expression / param / field
positions parsed by `parse_stmt` / `parse_param` / `parse_expr`, **never** routed
through the item dispatch. So they are structurally invisible to the hooks.
`trait`/`impl`/`dyn` have **no native hook at all** (§3b.5), so the native parser
cannot misclassify them either way.

### 9b. Census commands + counts (`FILES=$(git ls-files '*.hexa')` — 6321 files)

Identifier-position uses (field access `.kw` · field/named-arg `kw:` · param/arg
`kw[:,)]`):

```sh
for kw in type trait impl dyn extern; do
  echo "$FILES" | xargs grep -hoE "\.${kw}\b"        | wc -l   # field access
  echo "$FILES" | xargs grep -hoE "\b${kw}\s*[:,)]"  | wc -l   # param/field/arg
done
```

| word     | `.kw` field access | `kw[:,)]` param/field/arg | identifier-position total |
|----------|--------------------|---------------------------|---------------------------|
| `type`   | 17                 | 197                       | ~214                      |
| `trait`  | 17                 | 8                         | ~25                       |
| `impl`   | 20                 | 86                        | ~106                      |
| `dyn`    | 29                 | 6                         | ~35                       |
| `extern` | 8                  | 69                        | ~77                       |
| **sum**  | 91                 | 366                       | **~457**                  |

Collision-trigger probe — the ONLY positions a hook can fire (col-0 item leader +
the lookahead):

```sh
echo "$FILES" | xargs grep -hnE "^extern[[:space:]]+fn\b" | wc -l        # 329
echo "$FILES" | xargs grep -hnE "^type[[:space:]]+[A-Za-z_]" | wc -l     # 1
# col-0 leaders overall:
#   ^extern = 329  (== ^extern fn 329 → every one is the INTENDED extern-fn)
#   ^type   = 1    (`self/test_keyword_audit.hexa:67  type MyInt = int`  → INTENDED alias)
#   ^trait  = 2    (`trait Drawable {…}` decls — no native hook; tier-2 self/ parser)
#   ^impl   = 46   (`impl Point {…}` blocks — no native hook; tier-2 self/ parser)
#   ^dyn    = 0
```

### 9c. Verdict — **COLLISION COUNT = 0** (contextual approach measured-sound)

- Of the **~457** identifier-position uses of the five words, **0** sit at the
  item-dispatch position the hooks read → **0** are misclassifiable.
- Every col-0 `extern` (329/329) is the INTENDED `extern fn`; the single col-0
  `type` is the INTENDED `type … = …` alias — neither is an identifier collision.
- `trait`/`impl`/`dyn` carry **no native contextual hook**, so their decl-leader
  uses (the `trait`/`impl` blocks, all in `example/`·`self/`·`stdlib/` parsed by
  the tier-2 `self/` front-end) cannot be misclassified by the native parser.

**→ Wall B = NON-WALL for the contextual approach: the lookahead-gated
contextual-identifier detection is PERMANENTLY SOUND on the current corpus, and a
re-freeze to canonical keyword tokens is NOT required to keep the front-end
correct.** This *confirms* the §5 "cheaper path" insight from the soundness side.

### 9d. The inverse — why re-freeze is the *costlier* path (asymmetry recorded)

The 0-collision result holds **because** the words stay contextual. Promoting them
to **real keyword tokens** (the §2 re-seed) would do the OPPOSITE: a hard keyword
cannot be an identifier *anywhere*, so all **~457** identifier-position uses would
INSTANTLY become collisions requiring byteeq-neutral renames first (the rustc
edition-2015-`dyn` lesson, §2.1), plus a whole-faithful-build re-seed (§6 RISK 1).
The contextual approach pays **0** renames and **0** seed risk for the same
surface. The measured asymmetry — 0 vs ~457 collisions + global seed flip —
makes **DEFER** the dominant verdict, not merely the safe one.

### 9e. Status update

Per §5 / §9c, the actionable conclusion is updated:

> **DEFER reseed — contextual approach measured-sound (collision census = 0).**
> Wall B is duplicate insurance whose retirement buys nothing the lookahead-gated
> contextual hooks don't already provide; the re-seed stays plan-only / back-pocket
> hygiene. Re-open ONLY if a future surface needs a token the contextual idiom
> genuinely cannot carry (new `@<attr>` or a new `ItemKind` with exhaustive-match
> ripple, §6 RISK 6) — *not* for `type`/`trait`/`impl`/`dyn`/`extern`, which are
> measured-sound as-is.

Constraints unchanged: **doc-only**, no compiler-source / seed / tokens.hexa edit,
no build run (mini = git/gh; any future build/byteeq = aiden/summer pool).
