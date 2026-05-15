# hexa-lang Specification

> **Companion to `SPEC.yaml`** — the YAML file is the SSOT for hexa-lang
> language and toolchain decisions. This Markdown file mirrors the YAML
> shape with prose + tables for readers and downstream consumers
> (orpheus, wilson, anima, firmware boards). When the two files
> disagree, **`SPEC.yaml` wins**. Run `tool/render_spec.hexa` to check
> drift on the header fields below.

- **Schema version**: 1
- **Status**: directional (decisions locked; P0 stage-1 source-side OOM closed at current scale — A1+A2 → peak ~782 MB verified; deployed `hexa_real` current at HEAD `dae438ee`)
- **Last updated**: 2026-05-11
- **Authoritative RFCs**:
  - [RFC-017 — atlas embedding + strict lint](proposals/rfc_017_atlas_n6_embedding_and_strict_lint.md)
  - [RFC-018 — native codegen spec](proposals/rfc_018_native_codegen_spec.md)
  - [RFC-019 — error diagnostics spec](proposals/rfc_019_error_diagnostics_spec.md)
  - [RFC-020 — enum payload variants](proposals/rfc_020_enum_payload_variants.md)
  - [RFC-021 — daemon mode](proposals/rfc_021_daemon_mode.md)
  - [RFC-022 — async model](proposals/rfc_022_async_model.md)
  - [RFC-023 — firmware linker spec](proposals/rfc_023_firmware_linker_spec.md)

---

## 0. What hexa-lang is trying to be

A native-compiled, atlas-aware, strict-lint language with an in-house
prover, an in-house linker, English-only diagnostics, and zero runtime
GC. Stage 0 is the existing `hexa_interp`; stage 1 is a ground-up
compiler whose source is hexa itself; stage 3 is the byte-equal
self-hosted fixed point that retires the interpreter. Five firmware
repos (`hexa-rtsc`, `hexa-chip`, `hexa-cern`, `hexa-antimatter`,
`hexa-space`) are absorbed into the `firmware/` tree under the
Option C `stdlib/core` + `stdlib/alloc` + per-board separation.

---

## 1. Tree layout (Decision 2026-05-09)

| Tree | Role | Status |
|---|---|---|
| `self/` | Existing self-host upstream — parser, typechecker, IR in hexa; transpiled to `self/native/hexa_cc.c` (~20k LOC C) via `hexa cc --regen` | Active |
| `compiler/` | New ground-up native compiler (RFC-018) — 5-stage IR, atlas static embed, direct codegen | Phase A0 skeleton |
| `firmware/` | Per-board absorption tree (Option C, 2026-05-10) — boards, BSP, linker scripts | Skeleton landed (F0) |

Both compiler trees coexist; language-level features (e.g., enum
payloads via RFC-020) land in `self/` upstream first and `compiler/`
consumes them.

---

## 2. Foundational decisions (RFC-017 / RFC-018)

### 2.1 Language kind — **native compiled**
hexa-lang transitions from interpreter (`hexa_interp`) to a native
compiler. Interpreter remains only as bootstrap stage 0.

Rejected: `interpreter_only` (too slow for CI/LSP at atlas size 4.2 MB),
`interpreter_with_cache` (still per-process overhead, not zero).

### 2.2 atlas embedding — **static, baked into compiler**
`atlas.n6 + atlas.append.*.n6` are merged at compiler build time and
embedded as a packed const into the compiler binary (rodata). Hash
pinned via `ATLAS_HASH` constant.

| Property | Value |
|---|---|
| Runtime cost | 0 ms |
| Compiler binary overhead | 1–2 MB |
| Drift handling | CI auto-rebuilds compiler |
| Override | `hexa.toml [atlas] path = "..."` (rebuilds compiler) |

Rejected: `read_atlas_at_runtime` (200 ms per invocation),
`mtime_disk_cache` (acceptable but inferior).

### 2.3 Execution-blocking lint — **strict, compile-time fatal**
Python `SyntaxError` + TypeScript-strict model. No binary is produced
when any S0–S5 or S8 check fails. S6/S7 are fatal only when annotated.

| Stage | Fatal | Description |
|---|---|---|
| S0 parse | yes | syntax / lex |
| S1 resolve | yes | atlas P/C/L/E node existence |
| S2 bind | yes | scope / variable binding |
| S3 type | yes | nominal types, generics |
| S4 domain | yes | R / N / Z / C domain consistency |
| S5 units | yes | dimensional analysis |
| S6 equational | opt-in via `@verify` | LHS=RHS canonical, sample counter-example |
| S7 proof | opt-in via `@prove` | self-prover only (no Z3) |
| S8 citation | yes | atlas `L[*]` citation present where required |

### 2.4 Codegen strategy — **direct codegen**
No LLVM, no C-transpile. Direct source → mach pipeline keeps every IR
stage atlas-aware.

Pipeline: `lex → parse → resolve → check → lower → mono → ssa →
optimize → regalloc → emit → link`.

---

## 3. Targets — **parallel dual (Decision 1)**

| Tier | Triple | Role |
|---|---|---|
| 0 (concurrent) | `arm64-apple-darwin` | primary dev environment |
| 0 (concurrent) | `x86_64-linux-gnu` | CI / docker / runners |
| 1 (followup) | `arm64-linux-gnu` | ARM containers |
| 1 (followup) | `thumbv7em-none-eabihf` | Cortex-M4F (firmware: hexa-rtsc, hexa-chip) |
| 1 (followup) | `riscv32imac-unknown-none-elf` | RISC-V 32-bit (firmware) |
| 2 (later) | `wasm32-unknown-unknown` | playground |
| 2 (later) | `riscv64-linux-gnu` | bonus target |
| 2 (later) | `thumbv6m-none-eabi` | Cortex-M0 / M0+ |
| 2 (later) | `thumbv7m-none-eabi` | Cortex-M3 |
| 2 (later) | `xtensa-esp32-none-elf` | ESP32 (firmware: hexa-antimatter) |

---

## 4. macOS Mach-O gate (Decision 2026-05-09 — warn-only Phase B)

| Phase | Status |
|---|---|
| A in-repo | landed |
| B user wrapper | active in user session (`$HOME/.hx/bin/hexa`) |
| C strict block | deferred — awaits hook-layer migration |

Surfaces:
- `tool/wrappers/hexa_top_wrapper.sh` — reference wrapper
- `tool/lint_macho_gate.hexa` — LINT-MACHO-1 (`.hexa` exec sites)
- `tool/lint_macho_gate_invocations.hexa` — LINT-MACHO-2 (sh + CI surface)
- `spec/hexa_macho_gate.spec.yaml` — falsifier SSOT (F-HEXA-MACHO-1/2)

Silenced by: CLI flag `--Mach-O`, env var `HEXA_TARGET_MACHO=1`. Lint
bypass per session: `HEXA_LINT_MACHO_DISABLE=1`.

Rationale: 94% of macOS `hexa_interp` invocations don't need native
Mach-O codegen (hooks/handlers/probes); the flag makes intent explicit.

---

## 5. Bootstrap — **existing `hexa_interp` is stage 0 (Decision 2)**

| Stage | Tool | Output |
|---|---|---|
| 0 | `hexa_interp` | stage 1 native compiler binary |
| 1 | stage 0 | stage 2 (self-compiled by stage 1) |
| 2 | stage 1 | stage 3 |
| 3 | stage 2 | byte-equal to stage 2 (fixed point) |

`hexa_interp` retires after stage 3 settles. System `as` / `ld` permitted
only during stage 0 → stage 1 transition.

### Stage 1 OOM mitigation (2026-05-11 — CLOSED at current scale)

The stage 0 → stage 1 self-compile hit a 2 GB-cap OOM at the spliced
super-module (~25,932 lines). Source-side mitigations landed and the
deployed host was re-promoted; the re-probe confirms closure:

| Step | Commit | Effect |
|---|---|---|
| A1 host arena reset (`--phase-arena-reset` between parse / lower / codegen) | a0f5cd5d (restored) | once spliced AST + lower IR is freed, RSS drops to ~160 MB; was previously dwarfed by `array_store` growth — A2 removes that growth |
| A2 in-place `_splice_imported_items` accumulator (module-scoped `p_splice_acc`, replaces per-call `[Item]` allocation) | ab2dfcee + ddb21f21 (host rebuild) | source land + host rebuild |
| `~/.hx/bin/hexa_real` re-promote (carrying A2 + clusters + #14) | 774c5d32, then 41ecfb97, then dae438ee (sha cd817981…) | deployed host now current at HEAD `dae438ee` |
| #13 RSS re-probe (uncapped, `HEXA_MEM_UNLIMITED=1`) | 4f5f8f07 | **peak ~782 MB** (vs 5/10 baseline 3 510 MB), dropping to ~160 MB once the A1 phase-arena reset fires — well under the ~1.5 GB threshold |

Verdict (per `doc/stage1_punch_list_v2.md` "Update 2026-05-11 (PM)"):
**P0 stage-1 source-side OOM is closed at current scale** — A1 + A2
alone suffice. Re-enabling the M4 freelist (`self/hexa_full.hexa`
~L17993) remains an *optional* further reduction, not needed for closure.

### Interpret-mode after stage 3 (Decision 2026-05-09 — D + B)

- **D (default)**: `hexa run x.hexa` ≡ build + exec. Zero extra LOC.
- **B (opt-in)**: `--interp` / `hexa repl` — AST evaluator under
  `compiler/eval/`, ~200–500 LOC walker over typed AST. Reuses the
  full frontend.
- Rejected: keep separate ~20k-LOC interpreter (A); JIT first (C).

---

## 6. Language features — enum / sum types (Decision 2026-05-09)

### 6.1 ENUM 100% first
Wherever payload-free enums (Rust unit-style) suffice, prefer them
over string discriminators. Already applied to:

- `compiler/lex/tokens.hexa::TokenKind`
- `compiler/parse/ast.hexa::ItemKind`, `ExprKind`
- `compiler/diag/catalog.hexa::Severity`, `FixItKind`

Exempted: variants needing data payloads — until RFC-020 is verified
end-to-end (parser → typechecker → codegen).

### 6.2 hexa-lang upstream first
When a language gap is hit (e.g., enum payload codegen), fix it in
`self/` upstream rather than work around in downstream tools. Example:
RFC-020.

### 6.3 Enum payload status

| Aspect | Status |
|---|---|
| `enum Shape { Circle(Int), Rect(Int), Unit }` parser declaration | working |
| `match s { Shape::Circle(r) -> ... }` pattern binding (interpreter mode) | working |
| 7 match patterns (wildcard / literal / binding / variant / struct / tuple / guard) | working |
| `E::Variant(x)` construction syntax (parse_primary line 3016) | missing |
| Typechecker variant payload type registry | missing |
| Typechecker pattern binding — variable scope | missing |
| `hexa_cc.c` struct/union codegen + payload extraction | A4 landed (4ed9966e); stage 0 binary holdout |
| Multi-field variants entirely | deferred to later RFC |

Target design: single-field payload + struct embed (RFC-020).
A5 regression suite `self/test_enum_payload_full.hexa` 15/15 PASS at
`4ed9966e`.

PATCHES.yaml id `rfc020-enum-payload-variants` (incoming inbox) tracks
A1+A2+A3 bundled (3c8be96c + 005d5427); A4 partial (a85b8a1c, match-
side extraction landed via 4ed9966e). Sibling id `wilson-pi-port-6-gap-
prereq` (G1+G2+G3 wilson core gate) is applied — G1=A5, G2 async parity
(integrated codegen + runtime + interp), G3 cancel token (stdlib).

---

## 7. Diagnostics language — **English only (Decision 3)**

User explicitly fixed ENGLISH ONLY. Korean i18n closed permanently.

Applies to: compiler diagnostics, `hexa explain`, error catalog
templates, stdlib documentation.
Excludes: design RFCs and meta documents.

---

## 8. Opt-out grace label — **`@grace` annotation only (Decision 4)**

```hexa
@grace(HX1042, until="2026-06-01", reason="legacy atlas refactor in progress")
fn old_function() { ... }
```

| Field | Required |
|---|---|
| error code | yes |
| `until` | yes |
| `reason` | yes |

Forbidden: CLI flags to disable strict, environment-variable overrides.
Scope: applies to immediately-following item only.
On expiry: compiler emits `HX9001` and refuses to build until the
`@grace` is removed (item fixed) or `until` extended.

### 8.1 AI-native warn + explicit user consent (2026-05-09)

`@grace` is allowed but **never silent**. Every `@grace` site emits an
AI-native `HX9000` Warning at compile time, and the build is gated on
explicit user consent — a CI / PR-level acknowledgement signal.

`HX9000` inlines the **full rendered message** of the diagnostic it
suppresses (title, severity, message, did-you-mean, fix-it). The
`render_short` form is used so `HX9000` layout stays clean.

User consent mechanisms:
- PR trailer: `Acked-grace: HXxxxx by <reviewer-handle>`
- Commit trailer: `acked-grace: <code> by <author-handle>`
- CI fails when a commit / PR introduces or modifies a `@grace` site
  and no `Acked-grace` trailer matches the affected HX code.

---

## 9. Atlas citation strict (Decision 2026-05-09)

Formula-bearing functions must be bound to an atlas `L[*]` node;
otherwise compile fails (`HX8004`).

Required when:
- item has `@verify` annotation
- item has `@law(...)` annotation
- item body references any `L[*]` node

Legal bindings:
- `@implements(L[<existing-id>])` — cite an already-registered atlas L
- `@discover(kind="L")` — register THIS function as a new atlas L
  (RFC-017 §5 ε self-proof; routes through `compiler/discover/`)

Bypass path: standard `@grace(HX8004, until="...", reason="...")`.
Every `@grace` site triggers `HX9000` (never silent).

`HX8003` (Warning) is superseded by `HX8004` (Error) and demoted /
retired in the next citation pass refresh.

---

## 10. Atlas self-discovery — **ε self-proof (Decision 5)**

Verified hexa code automatically registers as atlas `L[*]` (theorem)
nodes. The atlas becomes a living theorem library that grows with the
codebase.

### 10.1 Prover engine — **in-house only (Sub 5a)**
Zero external dependency. No Z3 / CVC5.

Initial: equational rewrite, constant folding, sample-eval
counter-example, unit propagation, atlas graph consistency.
Deferred: linear arithmetic, non-linear arithmetic, quantifiers,
real-number induction.

### 10.2 Registration authority — **fully automatic (Sub 5b)**
Auto-register on prover pass; safety net is invalidation (Sub 5e).

Staging pipeline at `compiler/discover/`:
- `discover.hexa` + `staging.hexa` — write `atlas.proposed.{date}.n6`
- `promote.hexa` — **active** — folds proposed → live atlas, emits
  `atlas.append.{today}.n6` shard plus
  `/tmp/_promote_manifest.{date}.txt` summarising counts.
- Conflict rules: fingerprint dedup merges as alias; id-first wins
  rejects collisions with warning; new emits full proof-hash record.

### 10.3 Verification timing — **every compile, every function (Sub 5c)**
Maximum coverage. Performance: hash-keyed skip for unchanged functions,
early reject for non-theorem shapes (side-effect, IO, mutation).

### 10.4 Conflict resolution — **fingerprint dedup + id-first wins (Sub 5d)**

| Case | Resolution |
|---|---|
| Same canonical form | Register under existing L with alias |
| Same explicit id, different meaning | First wins, warning |
| Anonymous auto-id | Derived from fingerprint — collision implies dedup |

### 10.5 Invalidation — **tombstone + retroactive sweep (Sub 5e)**

| Mechanism | Trigger |
|---|---|
| Manual tombstone | `hexa atlas tombstone L[id] --reason="..."` |
| Automatic sweep | Prover version upgrade → CI nightly re-verifies all L; failures auto-tombstone (PR for review). `compiler/discover/retroactive_sweep.hexa`. |
| Cascade tombstones | Proof-hash records lemmas; tombstoning a lemma cascade-tombstones dependents. `compiler/discover/cascade.hexa`. |
| Auto-PR helper | `tool/auto_pr_tombstone_sweep.hexa` renders a PR body and invokes `gh pr create`; falls back to `/tmp/_tombstone_sweep_pr_body.{date}.txt`. |

Citing a tombstoned `L` emits `HX1099` (compile fail). History kept in
`atlas.tombstones.n6`.

---

## 11. Memory model — **arena 1.x → borrow check 2.x (Decision 6)**

### v1 (current) — arena only

| Region | Use |
|---|---|
| Function-local arena | function calls (most cases) |
| Request-scoped arena | LSP, daemon |
| rodata static const | atlas, immutable constants |
| User heap | arena only — manual `free` forbidden in 1.x |

### v2 (future) — adds borrow check
- Borrow checker with explicit arena lifetime handles
- Limited manual escape hatch for systems code
- **Tracing GC will never be added.** Permanent reject; ref-counting
  also rejected (cycle handling burden, atomic costs).

---

## 12. Linker — **`hexa_ld` primary + system fallback (Decision 7)**

Default linker: `hexa_ld` (in-house). Fallback to system `ld` / `lld`
when the primary binary is missing, fails at runtime, or
`--linker=system` is explicit.

`hexa_ld` capability matrix:

| Feature | v1 | v1.1 | v1.2 | Deferred |
|---|---|---|---|---|
| Static linking | ELF | ELF + Mach-O arm64 | same | dynamic linking → v1.3+ |
| Symbol resolution | ELF `_start`/`main` | + Mach-O `_main` / `start` | same | LTO, dead-code elim |
| Relocations | basic | NONE only | same | full relocation → v1.3 |
| DWARF debug | basic | dropped | dropped | re-add v1.3 |
| Mach-O execute | — | MH_EXECUTE + LC_MAIN + LC_LOAD_DYLINKER | same | — |
| Codesign | — | — | **ad-hoc LC_CODE_SIGNATURE** (CSMAGIC_EMBEDDED_SIGNATURE wrapping CSMAGIC_CODEDIRECTORY, SHA-256 per-4 KiB-page hashes) | notarized → v1.4+ |

`compiler/link/hexa_ld.hexa::link()` autodetects ELF (`0x7F ELF`) vs
Mach-O 64 (`CF FA ED FE`) magic and dispatches accordingly.

Bootstrap carve-out: system `ld` permitted during stage 0 → stage 1,
expires after stage 1 settles.

---

## 13. Migration — **big bang (Decision 8)**

1. Stage 1 native compiler settles first.
2. Full-tree lint dump on existing `.hexa` files.
3. Coordinated PR series fixes all violations.
4. Flip strict globally in one commit.

Fallback for unfixable: explicit `@grace` per site (no auto-generated
grace).

---

## 14. Diagnostics

| Field | Value |
|---|---|
| Code format | `HX[CCCC]` |
| Catalog | `stdlib/diagnostics/catalog.hexa` |
| Message templates | `stdlib/diagnostics/messages.hexa` (English) |
| Output modes | pretty, short, json, github |

| Group | Range | Stage |
|---|---|---|
| HX0xxx | parse / lex | S0 |
| HX1xxx | atlas resolve | S1 |
| HX2xxx | bind / scope | S2 |
| HX3xxx | type | S3 |
| HX4xxx | domain | S4 |
| HX5xxx | units | S5 |
| HX6xxx | equational | S6 |
| HX7xxx | proof | S7 |
| HX8xxx | citation | S8 |
| HX9xxx | codegen / link / runtime | RFC-018 |

Features: error code, precise span, did-you-mean (Levenshtein over
atlas trie + scope identifiers), fix-it, `hexa explain` subcommand,
multi-error collector with cascade compression, snapshot regression
tests.

### 14.1 New diagnostics (2026-05-11)

Surfacing the stage 1 punch list v2 (C4 / C5 / C10 / C16 / C20)
through real diagnostics rather than silent fallbacks:

| Code | Severity | Stage | Emitted at | Title |
|---|---|---|---|---|
| HX1101 | Error | S2 | `compiler/lower/hir_to_mir.hexa` (`_lower_hexpr` ident miss, was silent `_const_int_op(0)`) | unbound ident in lower |
| HX1102 | Error | S2 | `compiler/lower/hir_to_mir.hexa` (match-arm pattern fallback) | unsupported pattern shape in lower |
| HX1103 | Error | S2 | `compiler/lower/hir_to_mir.hexa` (HExpr default fall-through) | unhandled HExpr kind in lower |
| HX2001 | Error | S2 | `compiler/check/types.hexa::_types_check_call` (non-Ident callee — auxiliary to bind/resolve) | undefined name |
| HX2003 | Error | S3 | `compiler/check/types.hexa::_types_check_call` (callee_t.kind != "fn") | callee is not callable |

CLI drain wiring (`compiler/main.hexa` post-lower hir_to_mir_diags
drain, commit 18c6a536) is required for HX1101/1102/1103 to surface
alongside parser / check / units diagnostics; without the drain the
lower-pass codes were emitted into a sink not visible to the caller.

---

## 15. Roadmap

`T` = stage 1 native compiler settled.

| Phase | Effort | Goal |
|---|---|---|
| A0 | L | Backend skeleton + IR types |
| A1 | L | Parser + AST atlas tagging |
| A2 | M | atlas.n6 + append merger inside compiler |
| A3 | M | atlas packed const codegen + static embed |
| A4 | S | `ATLAS_HASH` pin + drift CI |
| B1 | M | S0–S2 fatal at compile time |
| B2 | M | S3–S4 type/domain |
| B3 | M | `@units` + S5 |
| B4 | M | `@law` / `@implements` + S8 citation |
| C1 | L | In-house prover v0 (equational + sample-eval) |
| C2 | L | Prover atlas auto-register + tombstone sweep (Decision 5) |
| D1 | M | `hexa_ld` v1 (static link, ELF + Mach-O) |
| D2 | M | LSP using compiler in-process index |
| E1 | L | Full big-bang migration of existing `.hexa` tree |
| E2 | M | Retire `hexa_interp` after stage 3 fixed point |

### Firmware absorption (Decision 2026-05-10 — Option C)

| Phase | Effort | Goal | Status |
|---|---|---|---|
| F0 | S | SPEC firmware Option C + `firmware/` skeleton | DONE — fc6d48b2 |
| F1 | M | `stdlib/core` + `stdlib/alloc` extraction (16 modules) | DONE (2026-05-10) |
| F2 | M | `firmware/boards/rtsc` reference port | DONE (2026-05-10) |
| F3 | L | `thumbv7em-none-eabihf` codegen + HX1110 target_gate_check | DONE (2026-05-10) |
| F4 | L | `firmware/boards/{chip,cern,antimatter,space}` absorptions | DONE (2026-05-10) |
| F5 | M | RFC-023 firmware linker spec (linker scripts + `.bss` / `.data` init) | SPEC LAND (2f9789e3, 2026-05-10); implementation follow-up |

### Revised stage 1 timeline

| Estimate | Date | Reason |
|---|---|---|
| 6–10 weeks | pre 2026-05-10 | Original Gap-1..15 punch list assumption |
| **14–22 weeks** | 2026-05-10 | Stage 0 host OOM dominates; punch list v2 (`doc/stage1_punch_list_v2.md`, commit 86afadb0) adds A1–A4 (interpreter arena reset / partial self-compile / stage 0.5 host) as the new critical path. |
| **P0 OOM closed at current scale** | 2026-05-11 (closure round) | A1 + A2 source-side mitigations landed (a0f5cd5d restored, ab2dfcee), `~/.hx/bin/hexa_real` re-promoted (774c5d32 → 41ecfb97 → dae438ee), #13 re-probe (uncapped) shows peak ~782 MB (was 3 510 MB) → P0 stage-1 OOM closed (4f5f8f07). Track B / C cluster work (B1+C19, Types A4+C4+B2, C11 atlas embed, Lower C5/C9/C10/C16, P2 C12–C20) all landed — the recurring v1 surface is closed. A full stage 1 fixed-point re-estimate is the remaining open work (no longer host-OOM-bound). |

Bottleneck (historical): stage 0 hexa_interp 2 GB cap during spliced
self-compile (~25,932-line super-module) — resolved by A1 + A2 (peak
~782 MB; see "Stage 1 OOM mitigation" above).

### Punch list v2 cluster status (2026-05-11)

| Cluster | Items | Commits | Status |
|---|---|---|---|
| Track A (bootstrap host) | A1 arena reset, A2 in-place splice accumulator, A4 type_check side-index | A1 a0f5cd5d (restored); A2 ab2dfcee + ddb21f21 host rebuild + re-promote 774c5d32→41ecfb97→dae438ee; A4 (bc50db32 side-index) | A1+A2 landed + deployed; #13 re-probe peak ~782 MB (4f5f8f07) → P0 OOM closed |
| Track B (recurring from v1) | B1 empty-name guard in `_hir_lower_type_ref`, B2 pin `fn_name`/`fn_return` before recursive return walk | B1 e34b9eb6 / 4cd39b2a, B2 cdc66054 / bc50db32 | landed |
| Track C — Types cluster | C4 HX2001 non-Ident callee | bc50db32 | landed |
| Track C — Atlas embed | C11 parse_only skip on atlas literals (`item_is_parse_only`) | 2b67ccb6 | landed |
| Track C — Lower cluster | C5 HX1101 unbound ident, C9 else-end recompute, C10 HX1102 pattern, C16 HX1103 unhandled HExpr | f3f63b72 (+ 9b9cc8a0, b8392fa6, dc15c327, d0ca3659) | landed |
| Track C — for-desugar | C19 `for x in iter` → index-based while in ast_to_hir | 4cd39b2a (f534fea9) | landed |
| Track C — P2 batch | C12 citation walk gated `--strict-citations`, C13 units early-out, C14 typed diags, C15 lmodule if-expr, C20 HX2003 non-fn callee | 840c8f7d (b5923aad, f6468143, 5342d50a, fbe11334, bed14aac) | landed |
| #14 drain | `compiler/main` hir_to_mir_diags drain (HX1101/1102/1103 surface in CLI) | 18c6a536 | landed |
| #10 wilson hexa-real promotion | PATCHES.yaml flip → applied | 13143f18 | A1+G2 binary promoted 5/10; A2 + clusters re-promoted 5/11 (774c5d32 → … → dae438ee, sha cd817981…) |
| #11 stdlib http_sse v1.1 POST+body | wilson provider-anthropic streaming POST | faca4134 | landed |
| #12 hexa build out-of-tree | cmd_build flatten via module_loader + `$HEXA_LANG/self` -I priority | 21e7b518 | landed |
| #13 stage 1 punch list v2 5/11 update | A2 verify deferred to host rebuild | ee62470a | landed |

---

## 16. Fork-storm prevention (Decision 2026-05-09)

Per-build "fork storm" inventory (2026-05-09): 1,403 `exec()` sites
across 265 files. Goal: 5–10 forks/build → ≤2 (only `as` and `ld`).

Ladder:

| Level | Name | Meaning | Status |
|---|---|---|---|
| L0 | fork storm | scattered `exec()` at every call site | current baseline |
| L1 | intrinsic surface | centralised inside named intrinsic functions | shipping 2026-05-09 (`compiler/intrinsics/intrinsics.hexa`) |
| L2 | libc FFI | intrinsic bodies call libc via C-FFI; no shell | deferred pending FFI landing |
| L3 | raw syscall | intrinsic bodies emit platform syscall trap inline | deferred post native v1 |

L1 first three: `now_ns`, `host_target`, `mkdir_p`. Second batch:
`rm_rf`, `rm_file`, `getenv`, `path_exists`, `path_is_dir`.
Absorbed-site count v0: 638; pending site count: 197.

---

## 17. Stdlib evolution (Decision 2026-05-09)

stdlib modules version independently of the compiler. Each module
owns its own backward-compat contract.

- additive helpers — small focused commit, +N selftest, `.ai.md` append
- breaking shape change — requires RFC
- new module — requires RFC + module `.ai.md` skeleton
- dependency direction — stdlib MAY depend on stdlib; compiler/ MAY
  depend on stdlib; stdlib MUST NOT depend on compiler/

### Modules in flight

| Module | File | Version | Additions |
|---|---|---|---|
| c_ffi | `stdlib/c_ffi.hexa` | v1.1 (applied 2026-05-09) | `c_alloc_ptr_slot()`, `c_load_ptr(slot)` — out-pointer slot for duckdb-style C APIs (orpheus 136 ms → 1–3 ms) |
| http | `stdlib/http.hexa` | v1.1 (pending external) | `http_post_with_headers(url, headers, body, timeout_s)` — JSON-RPC enabler (orpheus bitcoind 15–30 ms → 3–7 ms) |
| http_sse | `stdlib/http_sse.hexa` | v1.1 (applied 2026-05-11, commit faca4134) | `http_sse_post`, `http_sse_open_post`, `http_sse_open_method`, `http_sse_build_curl_method_cmd` — streaming POST + body (Anthropic Messages, OpenAI Chat Completions). Internal `_sse_build_curl` factored into `_method` variant. GET surface byte-identical. Body routed via `printf %s '...' \| curl --data-binary @-`. Interp-mode POST fallback deferred — AOT users get streaming POST today |
| semver | `stdlib/semver.hexa` | v1.0.0 (new module, applied 2026-05-11, commit 4725c619) | `semver_parse`, `semver_compare`, `semver_satisfies` — SemVer 2.0.0 parse / precedence compare / range-satisfies (`^`, `~`, `>=`, `<=`, `>`, `<`, `=`, x-ranges, hyphen ranges). wilson `loader_validate` plugin version-constraint checks. test_semver 110/110 |

### Inbox protocol

Until the new native compiler reaches stage 3 byte-equal fixed point,
two trees coexist and stdlib patches need verification across both.

| Surface | Path |
|---|---|
| Manifest | `inbox/PATCHES.yaml` |
| Audit log | `inbox/manifest_log.jsonl` |
| Sync tool | `tool/inbox_sync.hexa` |
| Promote tool | `tool/inbox_promote.hexa` |
| Bedrock advisory | `doc/inbox_for_bedrock.md` |
| Sunset trigger | stage 3 fixed point |

---

## 18. Firmware evolution (Decision 2026-05-10 — Option C)

Per audit `doc/firmware_audit_2026_05_10.md`, hexa-lang absorbs five
firmware repos. Rather than mixing host and embedded code in a single
stdlib (Option A) or fully separating (Option B), Option C splits:

```
stdlib/core/      target-agnostic primitives (no alloc, no syscall)
stdlib/alloc/     heap + arena allocators
stdlib/hal/       hardware abstraction (target-gated)
stdlib/embedded/  bare-metal: panic, WFI, intr vectors
stdlib/mcu/       MCU-specific (cortex_m, riscv, avr, esp32)
stdlib/(host)     net, http, fs, process, json, ... (host-only)

firmware/boards/{rtsc,chip,cern,antimatter,space}/
firmware/bsp/
firmware/linker_scripts/*.ld
```

### 18.1 Absorption targets

| Repo | Phase | Tests | Role | Destination |
|---|---|---|---|---|
| hexa-rtsc | D+ verified | 70/70 PASS | reference impl | `firmware/boards/rtsc/` |
| hexa-chip | D iter 5 | partial | `stdlib/hal` consumer | `firmware/boards/chip/` |
| hexa-cern | D2 → E | partial | Rust → hexa migrate during Phase E | `firmware/boards/cern/` |
| hexa-antimatter | D workspace | partial | multi-vendor | `firmware/boards/antimatter/` |
| hexa-space | E hardware | KiCad-first | deferred | `firmware/boards/space/` |

### 18.2 Dependency direction

| Edge | Allowed |
|---|---|
| `firmware/* → stdlib/core` | yes |
| `firmware/* → stdlib/alloc` (with embedded allocator) | yes |
| `firmware/* → stdlib/hal` | yes |
| `firmware/* → stdlib/mcu` | yes |
| `firmware/* → stdlib/embedded` | yes |
| `compiler/* → stdlib/core` (cross-compile path) | yes |
| `compiler/* → stdlib/alloc` | yes |
| `firmware/* → stdlib/{net,http,fs,process,...}` (host) | no |
| `stdlib/* → compiler/*` | no |

Target gate check: compiler rejects host-stdlib imports at compile time
when `--target=*-none-*` is set.

Embedded allocator: arena v1 by default; bump allocator optional for
tight-RAM MCUs; tracing GC permanently rejected (Decision 6).

Linker scripts: `firmware/linker_scripts/*.ld` consumed by `hexa_ld`.
RFC-023 spec draft (proposed 2026-05-10, commit 2f9789e3) — extension
of RFC-018 §10; implementation deferred to F5+1.

### 18.3 Roadmap status (2026-05-11)

| Phase | Goal | Status |
|---|---|---|
| F0 | SPEC firmware Option C + `firmware/` skeleton | DONE (fc6d48b2) |
| F1 | `stdlib/core` + `stdlib/alloc` extraction (16 modules moved) | DONE (2026-05-10) |
| F2 | `firmware/boards/rtsc` reference port | DONE (2026-05-10, option_A_full_copy) |
| F3 | `thumbv7em-none-eabihf` codegen + `target_gate_check` (HX1110) | DONE (2026-05-10) |
| F4 | `firmware/boards/{chip,cern,antimatter,space}` absorptions | DONE (2026-05-10, 4-board batch) |
| F5 | RFC-023 firmware linker spec | SPEC LAND (2026-05-10, 2f9789e3 — implementation follow-up) |

### 18.4 Biggest unknown (firmware audit)

hexa-lang ARM Cortex-M native codegen has F3 spec landed (asm-shape
only; no qemu/hardware run). Phase E hardware commission still gated
on `stdlib/hal v1.0.0`. Rust-side `cortex-m-rt` parity remains the
fallback for hexa-cern / hexa-antimatter until F5 implementation +
RFC-022 (async) downstream consumers settle.

---

## 19. Open questions (NOT decisions)

Pre-existing:

- Inline asm syntax
- Generic monomorphization vs dyn dispatch default
- Async runtime model
- Effect system link to atlas `L`
- Linker self-assembler vs external `as`
- wasm32 priority
- Python FFI native path (RFC-016 `import py` + native)
- Prover v2 capability targets
- Migration window duration estimate

Surfaced 2026-05-10:

- Stage 0 arena reset semantics for 2 GB OOM mitigation (punch list v2 A1)
- `riscv32imac` codegen timeline (currently zero — no RISC-V target yet;
  `thumbv7em` resolved separately, see below)

Resolved 2026-05-10 / 2026-05-11:

- core / alloc split criteria — F1 landed with 16-module split rule
  (target-agnostic primitives in `stdlib/core`; alloc-dependent helpers
  in `stdlib/alloc`); criterion documented in `doc/stdlib_core_extraction_2026_05_10.md`.
- `thumbv7em` codegen timeline — F3 landed (asm-shape only; no
  qemu / hardware run yet).
- ARM Cortex-M codegen blocks firmware — partially resolved: F3 is `DONE`
  (asm-shape only; HX1110 gate) + `target_gate_check` landed, leaving
  qemu / hardware commission as the remaining gate.
- `hexa_str_concat` runtime stub linkage (Gap 15) — moot for the `self/`
  build path: `hexa_str_concat` is defined in `self/runtime.c` and every
  transpiled program `#include`s `runtime.c`, so `codegen_c2.hexa`'s
  `str_concat → hexa_str_concat` mapping always resolves; no stub ever
  shipped in `self/native/*.c` (the only literal there is the symbol-name
  string inside the transpiled `hexa_cc.c`). The `compiler/` (ground-up
  native) tree's `bl _hexa_str_concat` / `call hexa_str_concat` emitted by
  `compiler/codegen/{arm64_darwin,x86_64_linux,thumbv7em_eabihf}.hexa` is
  verified at the .s-text level by `tests/m0/concat_test.hexa`; wiring a
  hexa runtime into `compiler/main.hexa`'s link step is a downstream
  codegen follow-up of commit 194d9011, gated behind the still-open
  compiler-driver gaps (the driver aborts before codegen on real source),
  not a standalone open question.
- A2 source-land vs deployed-binary gap — RESOLVED: `~/.hx/bin/hexa_real`
  re-promoted (774c5d32 → 41ecfb97 → dae438ee), then re-probed uncapped
  (`HEXA_MEM_UNLIMITED=1`): peak RSS ~782 MB (vs 5/10 baseline 3 510 MB),
  dropping to ~160 MB once the A1 phase-arena reset fires (4f5f8f07,
  `doc/stage1_punch_list_v2.md` "Update 2026-05-11 (PM)").
- M4 freelist re-enable strategy — RESOLVED as a strategy question: the
  A2-verification gate cleared (~782 MB ≪ 1.5 GB), so the verdict is
  "A1+A2 alone suffice for P0 closure at current scale; re-enabling the
  M4 freelist (`self/hexa_full.hexa` ~L17993) is an optional further
  reduction, not needed for closure."

Surfaced 2026-05-11: (none currently — A2 deploy gap + M4 freelist
strategy resolved above; the still-open work is the deferred-by-design
items under "Surfaced 2026-05-10" / "Pre-existing".)

---

## 20. Phases completed snapshot

### 20.1 Through 2026-05-09

| Phase | Status | Evidence |
|---|---|---|
| A0 | PASS | 5f506d06 backend skeleton + IR types |
| A1 | PASS | 0f15a5bf lexer + parser |
| A2 | PASS | 80037e78 atlas merger + B1 S1 resolve |
| A3 | PASS | 38f8661f packed const codegen + static embed |
| A4 | PASS | 6c4e7d4b `static_atlas()` to real fixture |
| B1 | PASS | 80037e78 + 6e255165 |
| B2 | PASS | 6e255165 S2 bind + diagnostic catalog growth |
| B3 | PASS | 9e82795e S3 + S4 (refined by 93fb38a9 B3+ S5 units) |
| B4 | PASS | 6eab6c55 annotation handlers + 5ee37b49 HX8004 citation strict |
| C1 | PASS | 6786affd / 15809e3d in-house prover v0 |
| C2 | PASS (cross_prover parked) | 3a0ce4d2 Decision 5e tombstone + retroactive sweep + cascade + HX1099 (atlas-side, smoke witnesses on disk); `tool/cross_prover.hexa` diagonal exists (675ce4b0) but its auto-registration into the prover atlas is a separable nice-to-have — not yet started, parked |
| D1 | PASS | 566dd835 hexa_ld v1 ELF64 + 758659eb v1.1 Mach-O arm64 |
| D2 | SCAFFOLD (Step 3+ deferred) | 81d2176a LSP capability matrix + LSP 3.17 pin — `.roadmap.lsp` LP1–LP5 all CLOSED, status `PEER_SCAFFOLD_RC_MET` (RC met 2026-05-06); feature suite (completion/hover/definition/references/rename/formatting/workspace.diagnostic, incremental sync, pull diagnostics) explicitly deferred to Step 3+ |
| E1 | DEFERRED | scheduled post stage 1 fixed point |
| E2 | DEFERRED | depends on E1 + stage 3 fixed point |

### 20.2 Delta 2026-05-10

| Item | Status | Evidence |
|---|---|---|
| F0 firmware Option C SPEC + skeleton | PASS | fc6d48b2 |
| hexa_ld v1.2 codesign (ad-hoc Mach-O) | PASS | 96aa37e8 |
| RFC-020 A4 / A5 (15/15) | PASS | 4ed9966e |
| RFC-022 + cancel token | PASS | 925846d0 |
| stdlib `write_text` | PASS | 4d414f73 |
| Stage 1 punch list v2 (revised 6–10w → 14–22w) | PASS | 86afadb0 |
| RFC-020 B1 audit | PASS | 77254d91 |
| g7-hexa-ld-dlopen RFC draft | SPEC | a01fb505 |
| Inbox: rfc020 + wilson-prereq entries | PASS | c48bbbeb |
| Gap 14 lower coverage match payload (HX1100) | PASS | 47d99c1c |
| Upstream-patch inbox until stage 3 | PASS | 03d5070b |
| RFC-020 enum-payload handoff + wilson 6-gap inbox | PASS | 36daab7d |
| RFC-021 daemon mode v0 prototype | PASS | 4ab3930c |
| `json.hexa` numeric coercion | PASS | 2e144e58 |
| Gap 15 codegen breadth | PASS | 194d9011 |
| Gap 2 cross-file dedup | PASS | 150b004f |
| Gap 1 multi-file parser loader | PASS | 0ea8bc95 |
| Mach-O gate Phase A | PASS | 26e06d70 |
| stdlib c_ffi v1.1 (out-pointer) | PASS | ecc49e1e |
| stdlib `http_post_with_headers` | PASS | 1d76e4fe |
| Stage 0 Blocker 1 audit | PASS | 3565f672 |
| i32 lower + literal coercion | PASS | 48f65cf3 |
| Parser Gap 6 recovery | PASS | 1c7b5861 |

### 20.3 Delta 2026-05-11

A2 land + 5 cluster merges + #14 drain + #11/#12 wilson fixes (stage 1
verification deferred to host re-promote).

| Item | Status | Evidence |
|---|---|---|
| A2 in-place `_splice_imported_items` accumulator (stage1 OOM source-side fix) | PASS | ab2dfcee |
| Stage 0 host rebuild incorporating A2 | PASS (source) / PENDING (deploy) | ddb21f21 |
| Types cluster — A4 side-index / C4 HX2001 / B2 fn_name pin | PASS | bc50db32 |
| C11 parse_only skip on atlas literals | PASS | 2b67ccb6 |
| Lower cluster — C5 HX1101, C9 else-end, C10 HX1102, C16 HX1103 | PASS | f3f63b72 |
| B1 `_hir_lower_type_ref` empty-name guard + C19 for-desugar | PASS | 4cd39b2a |
| P2 batch — C12 (citation gate), C13 (units early-out), C14 (typed diags), C15 (lmodule if-expr), C20 HX2003 | PASS | 840c8f7d |
| #14 `hir_to_mir_diags` drain in compiler/main (HX1101/2/3 surface) | PASS | 18c6a536 |
| #10 wilson hexa-real-promotion → applied (incoming PATCHES.yaml) | PASS | 13143f18 |
| #11 stdlib http_sse v1.1 (POST + body via curl stdin) | PASS | faca4134 |
| #12 hexa build out-of-tree (flatten + `$HEXA_LANG/self` -I) | PASS | 21e7b518 |
| #13 stage 1 punch list v2 — 2026-05-11 update (A2 verify deferred) | PASS | ee62470a |
| superpowers/void D1–D6 defense layer design (incident 2026-05-11) | PASS | 5d97e9db |
| Stage 2 / 3 witness harness + RFC-023 firmware linker spec | PASS | 2f9789e3 |

### 20.4 Delta 2026-05-11 (closure round)

P0 stage-1 OOM verified closed (A1+A2 → peak ~782 MB); `hexa_real`
re-promoted twice more; RFC-020 A4 restored in SSOT; wilson hexa-lang
side closed (`hexa build core/main.hexa` → `wilson 0.0.1`).

| Item | Status | Evidence |
|---|---|---|
| #13 stage-1 self-compile RSS re-probe post host re-promote — peak ~782 MB (was 3 510 MB) → P0 OOM closed | PASS | 4f5f8f07 |
| `~/.hx/bin/hexa_real` re-promote (#12 cmd_build flatten + A2 splice + clusters + #14) | PASS | 774c5d32 |
| RFC-020 A4 enum-payload match codegen restored in SSOT `codegen_c2.hexa` (regen had wiped the `a85b8a1c` hand-fix in `hexa_cc.c`) | PASS | 41ecfb97 (test_enum_payload_full 15/15 codegen + 15/15 interp) |
| `stdlib/semver.hexa` — SemVer 2.0.0 parse / compare / range-satisfies (wilson `loader_validate`) | PASS | 4725c619 (test_semver 110/110) |
| Install-relative `stdlib/` discovery + `HEXA_INSTALL_DIR` passdown — `use "stdlib/*"` works w/o `HEXA_LANG`/`HEXA_STDLIB_ROOT` (orpheus O-002) | PASS | df9e7f6b |
| Gap 15 (`hexa_str_concat` runtime stub linkage) closed out as moot | PASS | a8ff675b |
| SPEC §19/§20 status reconcile (D2 SCAFFOLD/Step3+-deferred, C2 PASS/cross_prover-parked, F3 DONE, §19 dedupe) | PASS | 571df583 |
| Shell-builtin absorption — `pwd → cwd()/getcwd()`, `ls → list_dir()` intrinsics (absorbed_site_count 638→752, pending 197→83) | PASS | 0ba5fd7d |
| `exec_stream_kill(h)` runtime builtin (fork+setpgid stream child; SIGTERM→grace→SIGKILL; wilson tool-core ESC-cancel) | PASS | 6c0fbac7 |
| builtin/method taken-by-value → static `__hxthunk_<name>` codegen (fixes `hexa_callN(<builtin>)` undeclared = wilson gap b2) + un-doubled `hexa_cc.c` (32 447→21 010 lines) | PASS | 46016739 |
| `hexa cc` / `hexa cc --regen` resolve `hexa_cc.c` / SSOT modules / `-I` via `$HEXA_LANG > install_dir > ./self` (not cwd) — works out-of-tree | PASS | 731f41d6 |
| `self/stdlib/law_io.hexa` selftest `main()` → `tool/law_io_selftest.hexa` (u_main collision on flatten) | PASS | a5de44e2 |
| `~/.hx/bin/hexa_real` + `~/.hx/packages/hexa/hexa.real` re-promoted from HEAD `46016739` (sha cd817981…; manifest_log row) | PASS | dae438ee |
| wilson `hexa build core/main.hexa` → `OK: built build/wilson` → `wilson 0.0.1` (hello, harness-cli/print/rpc, tool-core, provider-claude-cli/anthropic, agents-md) — hexa-lang side of wilson CLOSED | PASS | 340c3788 (closure note `inbox/notes/2026-05-11-wilson-hexa-lang-closure.md`) |

---

## 21. Downstream consumers

How downstream tools interact with hexa-lang today:

| Consumer | Surface | Status |
|---|---|---|
| **orpheus** | `stdlib/c_ffi v1.1` (out-pointer) → duckdb_native; `stdlib/http v1.1` (POST + headers) → bitcoind RPC; `stdlib/write_text` → bulk file I/O | working post c_ffi v1.1 + write_text; http v1.1 inbox pending external |
| **wilson** | RFC-020 enum payloads (G1), RFC-022 async (G2), `stdlib/cancel` (G3); `stdlib/http_sse v1.1` POST + body (provider-anthropic streaming); `stdlib/semver` (loader_validate); `hexa build` / `hexa cc` out-of-tree (flatten + `$HEXA_LANG > install_dir > ./self` -I); `exec_stream_kill` (tool-core ESC-cancel); builtin-by-value thunk codegen (gap b2); G7 dynamic-linking RFC draft (nice-to-have, not blocking) | **hexa-lang side CLOSED 2026-05-11** — `hexa build core/main.hexa` → `wilson 0.0.1` (340c3788); G1+G2+G3 applied 2026-05-10; http_sse + build-out-of-tree + semver + exec_stream_kill + b2-thunks landed 2026-05-11; `~/.hx/bin/hexa_real` re-promoted (dae438ee, sha cd817981…) |
| **anima** | shares language upstream via `self/`; consumes `compiler/discover/` outputs | following RFC-020 + atlas-side staging |
| **firmware boards** (hexa-rtsc / hexa-chip / hexa-cern / hexa-antimatter / hexa-space) | `stdlib/core` + `stdlib/alloc` + `stdlib/hal` + `stdlib/embedded` + `stdlib/mcu`; per-board absorption under `firmware/boards/*` | F0–F4 landed 2026-05-10; F5 (RFC-023) spec landed 2026-05-10 (implementation follow-up); qemu / hardware commission remaining gate |

---

## 22. Sanity check

Does this document comprehensively answer:

| Question | Answer location |
|---|---|
| What is hexa-lang trying to be? | §0 |
| Locked decisions vs open questions? | §2–§18 (locked) vs §19 (open) |
| Downstream consumer integration? | §17 (stdlib evolution), §18 (firmware), §21 (consumers) |
| Revised timeline? | §15 (roadmap) + revised stage 1 estimate |

Cross-reference verification:
- All RFC links (RFC-017..023) resolve in `proposals/`.
- All commit SHAs cited resolve via `git log --oneline`.
- All file paths cited (`compiler/intrinsics/intrinsics.hexa`,
  `compiler/discover/*.hexa`, `compiler/link/hexa_ld.hexa`,
  `spec/hexa_macho_gate.spec.yaml`, `tool/wrappers/hexa_top_wrapper.sh`,
  `tool/lint_macho_gate*.hexa`, `tool/auto_pr_tombstone_sweep.hexa`)
  exist on disk.

Status: **ready for share** — SPEC.yaml + SPEC.md aligned for stage 1
reach, downstream consumers, and audit verifiers. Both header fields
(`last_updated`, `status`) are at 2026-05-11 and char-for-char identical
across the two files; `tool/render_spec.hexa` reports
`ok: SPEC.yaml and SPEC.md aligned`.
