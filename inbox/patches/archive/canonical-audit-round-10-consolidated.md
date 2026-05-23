# canonical-deviation audit round 10 — consolidated (4 axes + P0 CRITICAL)

> **ARCHIVED (2026-05-24) — ALL round-10 actionable items CLOSED.** Re-verified
> the P0 (200-char identifier truncation) **does NOT reproduce** against HEAD
> (transpile → C-emit → clang → run at 206 / 207 / 300 / 500 / 1000-char idents:
> exactly 1 distinct C symbol per ident, full length preserved at decl/fwd-decl/use,
> binary runs and prints the correct value). Root cause class (fixed-size codegen
> buffer) **does not exist** — `_hexa_mangle_ident` (`self/codegen.hexa:229`) returns
> the full name unchanged (only `u_`-prefixes reserved names), and the lexer ident
> path (`self/lexer.hexa:204-215`) uses a dynamic `word_parts` array + `join`, not a
> scratch buffer. Closed by the codegen-rename + regen cycle and documented in PR #442;
> P1 `@derive` cluster landed (#436); r10-15g `@cold`/`@noinline` placement landed (#440);
> r10-8 trailing-comma VERIFIED-CLOSED. No code fix needed — moving to `archive/` to stop
> cycle re-triage as a live P0. Remaining r10 entries (r10-15b/c/d attr-whitelist,
> r10-18d error-snippet) are intentional cycle-8+ design candidates, not P0/P1.

> **Status (2026-05-23):** PROBE r10 surfaces **1 🚨 P0 CRITICAL silent-failure** (200-char identifier — parser PASS but codegen TRUNCATES decl-vs-use, yielding a broken binary), **2 P1** (attribute hygiene — `@derive(D) @derive(D)` rejected; `@derive` on `fn` emits generic `LBrace` error instead of a semantic message), and a cluster of small DX gaps. Two FIX-SURGICAL clusters are in-flight this cycle (long-ident codegen, `@derive` attribute cluster) — separate PRs. This doc is the **consolidated round-10 inbox**: axis tables + priority queue + structural-notes mirror.

PROBE round 10 결과 (24 probes, 4 axes: lexer edges · whitespace/layout · error recovery & diagnostics · attribute hygiene). FIX-SURGICAL 항목은 별도 PR — 본 문서는 **language-surface audit** consolidated 기록.

## TL;DR

| axis | FIX-SURGICAL (cycle 7 in-flight) | design / DX gap (본 문서) | P0 / P1 |
|---|---|---|---|
| 1. lexer edges | **r10-P0** 200-char ident codegen truncation (long-ident fix PR) | r10-4 unicode ident (ASCII-only `is_ident_start`, lexer.hexa:101-105) | **P0 ×1** |
| 2. whitespace / layout | **r10-8** trailing comma in CALL accepted (✅ FIXED — mirrors array `[a, b,]`) | — | — |
| 3. error recovery / diagnostics | — | r10-18d no source snippet / no caret / no "did you mean" hints (error.hexa render) | — |
| 4. attribute hygiene | **r10-P1** `@derive(D) @derive(D)` reject + `@derive` on `fn` semantic msg (attr cluster PR) | r10-15b/c/d unknown/conflicting attrs silent-absorb · r10-15g `@cold`/`@noinline` defn-vs-decl placement (`-Wgcc-compat` warnings) | **P1 ×2** |

**1 P0 CRITICAL** (long-ident codegen truncation — broken binary). **2 P1** (attribute cluster). **0 🚨 stdout content-leak class this round** (distinct from r8 `write_file`).

## 🚨 P0 CRITICAL — 200-char identifier codegen TRUNCATION

### Symptom

A 200-char identifier (`a_…_a` × 200) **parses successfully** but the codegen emits TRUNCATED forms for the declaration vs the use-site, breaking name-resolution at the C-emit boundary → resulting binary is broken (link error or wrong-symbol call).

| stage | 60-char ident | 200-char ident |
|---|---|---|
| lexer/parser | PASS | **PASS** |
| codegen (decl emit) | PASS | **TRUNCATED** |
| codegen (use emit) | PASS | **TRUNCATED DIFFERENTLY → mismatch** |
| binary | runs | **broken** |

### Severity

- **Silent-ish at parse-time**: no error surfaces until C-compile / link.
- **Cause class**: fixed-size buffer in codegen identifier rename path (no length check, no overflow guard).
- **Reach**: any generated identifier (mangled type-params, monomorph names, internal helpers) that exceeds the buffer.
- **Equivalence**: same class as silent-failure C-buffer overruns — under the carry-flag bug family but at codegen-emit instead of syscall.

### Action (cycle 7, in-flight)

- FIX-SURGICAL PR — long-ident codegen buffer fix (separate branch). Replace fixed-size scratch with growable buffer or assert + fail-loud at codegen ident-emit when len > MAX.
- Regression test: a 200-char ident declared + used; assert decl-symbol == use-symbol.

### Status update (2026-05-23) — ✅ ALREADY FIXED (verified, no truncation)

Re-verified against the canonical committed transpiler (`self/native/hexa_v2` == HEAD `b036121d`,
identical blob hash for `self/codegen.hexa`). **The P0 does NOT reproduce** — the codegen ident
path has no fixed-size buffer: `_hexa_mangle_ident` (`self/codegen.hexa:229`) returns the full
name unchanged (only prefixes `u_` for reserved names), and every decl/use/fwd-decl site routes
through that one function. Likely closed by the earlier codegen-rename + regen cycle (PR #403 →
regens #413/#437).

Repro evidence (transpile → clang → run, full ident at every site):

| ident len | distinct C symbols emitted | runs | output |
|---|---|---|---|
| 199-char `fn` (`a_…_a`) | 1 (decl == fwd-decl == use) | ✅ | `42` |
| 199-char `let` var (`b_…_b`) | 1 | ✅ | `99` |
| 200 / 300 / 500 / 1000-char `fn` | 1 each (maxlen-in-C == ident len) | — | full-length, no cliff |
| short-ident regression (`add`) | — | ✅ | `5` |

`hexa parse self/codegen.hexa` clean. No code change needed — this entry is closed as a
docs-only status update.

## Axis 1 — Lexer edges

| probe | hexa-current | canonical | verdict |
|---|---|---|---|
| 60-char ident | ✓ parse + codegen | Rust / Go / Py (no limit) | ✅ PASS |
| **200-char ident** | ✓ parse, **🔴 codegen TRUNCATES** | Rust / Go / Py (no limit) | **P0 CRITICAL** (fix in cycle 7) |
| 30-level paren nesting | ✓ PASS | canonical | ✅ PASS |
| unicode string literal (UTF-8 bytes) | ✓ PASS | canonical | ✅ PASS |
| unicode identifier (e.g. `한글`, `αβ`) | ✅ FIXED — `is_unicode_byte` (byte ≥ 0x80) wired into `is_ident_start`/`is_ident_char`; Go-style (any UTF-8 letter byte). Verified `日本()`/`café`/`λ` build+run; clang accepts verbatim-UTF-8 C symbols; self-host `=== BUILD OK ===` | Rust `XID_Start` / Py PEP 3131 / Go letters+digits | ✅ FIXED (lexer-only, regen-gated) |

### 핵심 design 결정

Lexer 의 ident-start = ASCII alpha only — i18n identifier 가 로드맵에 들어올 경우 `XID_Start` / `XID_Continue` (Unicode UAX #31) 또는 최소 BMP letter-class 으로 확장 필요 (medium 규모, lexer + 호환성 매트릭스 영향).

**P0 200-char ident 는 별도 클래스** — i18n 과 무관, **고정 버퍼 안전성** 이슈.

## Axis 2 — Whitespace / layout

| probe | hexa-current | canonical | verdict |
|---|---|---|---|
| `let x=1` no-spaces | ✓ PASS | canonical | ✅ PASS |
| one-line `if{}else{}` | ✓ PASS | canonical | ✅ PASS |
| trailing comma in `[a, b,]` | ✓ PASS | Rust / Go canonical | ✅ PASS |
| **trailing comma in CALL `f(a, b,)`** | ❌ REJECTED → ✅ **FIXED** | Rust / Go canonical | ✅ r10-8 FIX-SURGICAL (mirrors array) |
| tabs vs spaces uniform | ✓ PASS | canonical | ✅ PASS |
| nested block comments `/* /* */ */` depth-tracked | ✓ PASS — **beats C, matches Rust** | Rust canonical | ✅ PASS (좋은 시그널) |
| indent irrelevant (free-form) | ✓ PASS | Rust / Go (not Py) | ✅ PASS |
| dense one-liner | ✓ PASS | canonical | ✅ PASS |
| newline in `[…]` suppressed (paren_depth>0) | ✓ PASS | canonical | ✅ PASS |
| blank lines | ✓ PASS | canonical | ✅ PASS |

### 핵심 design 결정

**Whitespace handling 은 거의 fully canonical** (Rust-leaning). 유일했던 inconsistency — **trailing comma in CALL** 이 array literal 과 비대칭 — 은 **r10-8 로 FIXED** (2026-05-23): `parse_args` 의 comma-loop 에서 comma 소비 후 다음 토큰이 `RParen` 이면 break (array 의 `while != RBracket` 패턴 미러). leading `f(,)` / double `f(a,,b)` 는 여전히 reject. parser 변경은 regen-gated → local regen→transpile→compile→run + `build_hexa_cli.sh` (`=== BUILD OK ===`) 로 검증.

## Axis 3 — Error recovery / diagnostics

| probe | hexa-current | canonical | verdict |
|---|---|---|---|
| 8 distinct errors in one batch | ✓ parser.hexa:214-252 `p_synchronize` | Rust `recover` / Swift parser recovery | ✅ PASS (좋은 시그널) |
| error format `Parse error at L:C: expected K, got K ('V')` | ✓ parser.hexa:210 | Rust `expected X, found Y` | ✅ PASS |
| p_max_errors cap (50) + dedup via `p_last_err_key` | ✓ | Rust / Swift / Go canonical | ✅ PASS |
| **source snippet + caret + "did you mean" hints** | ❌ NONE — bare `L:C: msg` only | Rust `^^^^^^^^^` + `help: did you mean …` | 🟠 r10-18d DX gap |

### 핵심 design 결정

Error recovery **mechanics are strong** (synchronize + cap + dedup), but **diagnostic render is bare**. Closing the DX gap (snippet + caret + hint) needs:

- **source text retention** in `error.hexa` render path — currently only `(line, col, msg)` triple is captured; full source line is dropped before render.
- caret column-arithmetic (post-tab-expand).
- "did you mean" requires keyword/ident similarity index (Levenshtein cap 2) — small lookup table over reserved-word set + symbol table at parse time.

**Medium** 규모 (source-text retention + render rewrite + similarity index). Cycle 8+ candidate.

## Axis 4 — Attribute hygiene

| probe | hexa-current | canonical | verdict |
|---|---|---|---|
| attr order known/unknown observationally equivalent | ✓ | canonical | ✅ PASS |
| r10-15b unknown attr `@foo_bar_baz` | ⚠ silent absorb (parser.hexa:1032-1053 generic fall-through) | Rust `unknown attribute` warn/err | 🟠 design |
| r10-15c conflicting attrs (e.g. `@inline @noinline`) | ⚠ silent absorb (no conflict detection) | Rust diagnoses | 🟠 design |
| r10-15d typo-friendly attr (e.g. `@inlnie`) | ⚠ silent absorb (no whitelist + no similarity hint) | Rust `unknown attribute, did you mean …` | 🟠 design |
| **r10-15e `@derive(D) @derive(D)` on struct** | ❌ REJECTED (parser.hexa:747 `parse_derive_decl` after-loop) | Rust allows duplicate derive (dedup) | **P1** |
| **r10-15f `@derive` on `fn`** | ❌ generic `LBrace` error (no semantic msg) | Rust `derive can only be applied to ADTs` | **P1** |
| r10-15g `@cold`/`@noinline` C passthrough on **defn** instead of **decl** | ⚠ emits to defn → `-Wgcc-compat` warnings | gcc/clang canonical: attrs on decl | 🟡 small fix |

### 핵심 design 결정

**Attribute parser = generic fall-through** (silent absorb of unknown / conflicting / typo'd attrs). Two related but distinct issues:

1. **Hygiene cluster (r10-15b/c/d)** = lint-level whitelist + warning + similarity hint. Small-medium surgical PR (whitelist table + warn emitter + Levenshtein lookup). 동일 패턴 PR #432 의 `@derive` deprecation hint approach.

2. **`@derive` cluster (r10-15e/f)** = **P1 surgical** — duplicate-derive dedup loop fix + fn-target semantic-msg branch.

3. **`@cold`/`@noinline` placement (r10-15g)** = codegen attribute emitter 의 decl-vs-defn 분기 — small fix (one if-branch in codegen attribute emit).

## FIX-SURGICAL this cycle (in-flight)

| 항목 | 규모 | 상태 |
|---|---|---|
| **r10-P0** long-ident codegen truncation (200-char) | small-medium (fixed-buffer → growable, or assert + fail-loud) | ✅ already-fixed (verified 2026-05-23 — no truncation; see §P0 status update) |
| **r10-P1** `@derive` cluster — duplicate-derive dedup + fn-target semantic msg | small (parser.hexa:747 + parse_derive_decl call-site dispatch) | 🟡 in-flight (separate PR) |

## 우선순위 (cycle 8+ 후보)

| 항목 | 규모 | 영향 |
|---|---|---|
| ~~**r10-8 trailing comma in CALL**~~ | ~~small~~ | **VERIFIED-CLOSED 2026-05-23** — `parse_args` close-paren-before trailing-comma branch landed in `self/parser.hexa` (mirrors array `[a, b,]`). 6-line guard; leading `f(,)` + double `f(a,,b)` stay rejected. Verified via local regen→transpile→compile→run + `build_hexa_cli.sh` (`=== BUILD OK ===`). |
| **r10-15b/c/d attr whitelist + warn unknown + "did you mean"** | small-medium (whitelist table + warn emitter + Levenshtein lookup) | typo-friendly → typo-detect 으로 보강 |
| **r10-18d error snippet + caret + "did you mean"** | medium (source text retention in `error.hexa` + caret column-math + similarity index) | DX 대폭 개선, Rust 수준 진단 |
| **r10-15g `@cold`/`@noinline` defn → decl placement** | small (codegen attribute emit if-branch) | `-Wgcc-compat` 제거 |
| **r10-4 unicode ident `XID_Start`** | medium (lexer.hexa:101-105 + UAX #31 lookup) | i18n 로드맵 진입 시 |

## Structural notes (low-priority + 좋은 시그널)

**Strong areas (이번 라운드에서 확인)**:

- **Nested block comments** depth-tracked — beats C (C 는 nested block comment 미지원), matches Rust. 좋은 시그널.
- **Error recovery** — `p_synchronize` (parser.hexa:214-252) + `p_max_errors=50` cap + `p_last_err_key` dedup. 8 distinct errors in one batch passes cleanly.
- **Whitespace** — free-form (indent irrelevant), tabs/spaces uniform, newline suppressed inside paren-depth>0. Rust-leaning, 일관성 좋음.
- **Paren nesting** — 30-level PASS.

**Design-level (low-priority intentional)**:

- **Attribute model = generic fall-through (silent absorb)** — typo-friendly 이지만 silent-failure class (r9 와 동일 클래스, 이번 라운드에서 다시 확인). 하지만 r10-15e/f 는 **silent-absorb 가 아닌 reject** 임 — 따라서 P1 (사용자가 의도한 attr 사용을 막음).

- **Lexer ASCII-only ident-start** — single-byte path 가 v1 의도. i18n 진입 시 lexer.hexa:101-105 의 `is_alpha` 를 UAX #31 으로 확장.

- **Diagnostic mechanics > render** — recovery 기계장치는 좋고, 표현 (render) 만 빈약. source-text retention 한 줄 추가하면 큰 DX upgrade.

## 참고

- PROBE r10 source (4 axes · 24 probes) — anima-side audit log.
- prior round inbox: `inbox/patches/canonical-audit-round-7-consolidated.md` (PR #395)
- prior round inbox: `inbox/patches/canonical-audit-round-8-consolidated.md` (PR #400)
- prior round inbox: `inbox/patches/canonical-audit-round-9-consolidated.md` (PR #418)
- cycle 7 FIX-SURGICAL (r10-P0 long-ident codegen): ✅ already-fixed (verified 2026-05-23 — no truncation, no fixed buffer; closed by prior codegen-rename + regen #403/#413/#437)
- cycle 7 FIX-SURGICAL (r10-P1 `@derive` cluster): separate PR, in-flight
- r9-7 follow-up landed: PR #432 (`@derive_meta` surface + `@derive` deprecation hint)
- r9-6 FIX-SURGICAL landed: PR #419 (`MacroCall` parse-time fail-loud + expander design inbox)
- r9-14 FIX-SURGICAL landed: PR #417 (`where T: …` parser wire)
- r8 CRITICAL closure: PR #407 (`write_file` content-leak fix)
