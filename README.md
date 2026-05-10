# hexa-lang

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19404816.svg)](https://doi.org/10.5281/zenodo.19404816)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A strict-lint, atlas-aware native compiler for a knowledge-bearing programming language: every formula in your code is bound to a shared theorem dictionary at compile time, or it does not build.

[ phase A0–B5 PASS · D1 PASS · M0 milestone PASS · stage 1 reach ~6–10 weeks · atlas SSOT live · ENGLISH ONLY diagnostics ]

> Status: directional spec locked, native compiler in active build (see `SPEC.yaml`, last updated 2026-05-09).

---

## What it is

hexa-lang is a native compiler (no LLVM, no C-transpile) that bakes a 4.2 MB knowledge atlas into the compiler binary and refuses to emit a binary when any strict-lint check fails (S0–S5 + S8). A small in-house prover lets verified functions auto-register as new atlas theorems via `@verify` / `@discover`.

The cooking-book metaphor (see `doc/atlas_lint_easy_explainer.md`):

- **atlas** — a shared dictionary of primitives, connections, laws, and errors
- **compiler** — a chef that has the dictionary memorized (runtime cost: 0 ms)
- **strict lint** — quality control that aborts the build before any binary is produced

The interpreter (`hexa_interp`) survives only as bootstrap stage0 and retires once stage3 reaches a fixed point.

---

## Key decisions (excerpt — see `SPEC.md` for the full record)

| # | Decision | Pin |
|---|---|---|
| 1 | Language kind | native compiled, direct codegen (no LLVM, no C-transpile) |
| 2 | Atlas embedding | static, baked into compiler binary; runtime cost 0 ms |
| 3 | Lint model | strict compile-time fatal — S0–S5 + S8 always, S6/S7 opt-in |
| 4 | Tier-0 targets | `arm64-apple-darwin` + `x86_64-linux-gnu` (concurrent) |
| 5 | Bootstrap | `hexa_interp` → stage1 → stage2 → stage3 byte-equal fixed point |
| 6 | Diagnostics language | ENGLISH ONLY (no i18n) |
| 7 | Opt-out | `@grace(HXxxxx, until=, reason=)` annotation only — no CLI flag, no env var; every site emits HX9000 ai-native warning + requires `Acked-grace:` trailer |
| 8 | ε self-proof | verified functions auto-register as atlas `L[*]`; tombstone + retroactive sweep on prover upgrade |
| 9 | Memory model | arena in v1 (no manual free, no GC ever); borrow check in v2 |
| 10 | Linker | in-house `hexa_ld` primary (ELF + Mach-O arm64 static), system `ld` fallback |
| 11 | Migration | big-bang — fix all violations, flip strict in one commit |
| 12 | Language stance | ENUM 100% first; fix gaps at hexa-lang upstream rather than work around |

---

## Pipeline

```
.hexa source
   │
   ├─ lex            ✓   tokens
   ├─ parse          ✓   AST, atlas-tagged
   ├─ resolve  S1    ✓   atlas P/C/L/E node existence
   ├─ bind     S2    ✓   scope / variable binding
   ├─ types    S3    ✓   nominal types, generics
   ├─ domain   S4    ✓   ℝ/ℕ/ℤ/ℂ consistency
   ├─ units    S5    ✓   dimensional analysis
   ├─ citation S8    ✓   atlas L[*] citation strict (HX8004)
   ├─ annotations    ✓   @law / @grace / @discover / @verify
   ├─ equational S6  ✓   in-house prover v0 (opt-in via @verify)
   ├─ proof    S7    deferred  no Z3, no CVC5; in-house only
   │
   ├─ lower (HIR)    ✓   typed IR
   ├─ mono           WIP generic monomorphization
   ├─ MIR (SSA)      ✓   CFG / SSA
   ├─ optimize       ✓   const-fold / DCE / conservative inline
   ├─ regalloc (LIR) ✓   target-specific
   ├─ emit (asm)     ✓   arm64-darwin + x86_64-linux
   ├─ assemble       system `as` (bootstrap carve-out)
   └─ link           ✓   hexa_ld v1.1 (ELF64 + Mach-O arm64 static)
```

A binary is produced only if every fatal stage passes. M0 (`fn main() -> i32 { return 0 }`) end-to-end smoke is PASS; broader codegen coverage tracks the stage 1 punch list.

---

## Repo layout

| Tree | Role |
|---|---|
| `compiler/` | New ground-up native compiler (RFC-018) — `lex/`, `parse/`, `check/`, `lower/`, `optimize/`, `codegen/`, `emit/`, `link/`, `atlas/`, `discover/`, `diag/` |
| `self/` | Existing self-host upstream (parser, typechecker, IR in hexa) — transpiled to `self/native/hexa_cc.c` via `hexa cc --regen` |
| `tool/` | Drivers, validators, CI helpers (`tool/auto_pr_tombstone_sweep.hexa`, etc.) |
| `doc/` | Explainers, runbooks, audits — start with `doc/atlas_lint_easy_explainer.md` |
| `proposals/` | Authoritative RFCs (017–020) |
| `tests/` | `m0/` smoke + `integration/` |
| `gate/` | Build gate / lint scripts |
| `SPEC.yaml` | SSOT (decision record); `SPEC.md` is auto-rendered |

Both `compiler/` and `self/` coexist by design: language features (e.g. enum payloads via RFC-020) land in `self/` upstream first; `compiler/` consumes them.

---

## Quick start

```bash
# 1. clone
git clone https://github.com/dancinlab/hexa-lang
cd hexa-lang

# 2. M0 smoke (fn main() -> i32 { return 0 })
build/hexa_interp tests/m0/run.hexa

# 3. strict lint over a source tree (S0–S5 + S8 fatal)
build/hexa_interp compiler/main.hexa --check path/to/source.hexa
```

The interpreter binary lives in `build/hexa_interp.linux` (and platform variants) and is the bootstrap stage0.

---

## Roadmap (`phases_completed_2026_05_09` from `SPEC.yaml`)

| Phase | Goal | Status |
|---|---|---|
| A0 | backend skeleton + IR types | PASS |
| A1 | parser + AST atlas tagging | PASS |
| A2 | atlas n6 + append merger | PASS |
| A3 | atlas packed const codegen + static embed | PASS |
| A4 | `ATLAS_HASH` pin + drift CI | PASS |
| B1 | S0–S2 fatal at compile time | PASS |
| B2 | S2 bind + diagnostic catalog growth | PASS |
| B3 | S3 type + S4 domain (+ S5 units refinement) | PASS |
| B4 | `@law` / `@implements` / S8 citation (HX8004) | PASS |
| C1 | in-house prover v0 (equational + sample-eval, S6) | PASS |
| C2 | prover atlas auto-register + tombstone sweep | IN-PROGRESS |
| D1 | `hexa_ld` v1 (static ELF + Mach-O arm64) | PASS |
| D2 | LSP using compiler in-process index | IN-PROGRESS |
| E1 | full big-bang migration of existing `.hexa` tree | DEFERRED |
| E2 | retire `hexa_interp` after stage3 fixed point | DEFERRED |

---

## RFCs

- [RFC-017 — atlas n6 embedding + strict lint](proposals/rfc_017_atlas_n6_embedding_and_strict_lint.md)
- [RFC-018 — native codegen spec](proposals/rfc_018_native_codegen_spec.md)
- [RFC-019 — error diagnostics spec](proposals/rfc_019_error_diagnostics_spec.md)
- [RFC-020 — enum payload variants](proposals/rfc_020_enum_payload_variants.md)

---

## Stage 1 reach

**Realistic estimate: 6–10 weeks of focused work** to first full stage1 binary, plus ~2–3 weeks for stage2 == stage3 fixed-point stabilization.

The compiler currently runs end-to-end through lex → parse → resolve → bind → types and aborts at the diagnostics gate with structured `HX3001`/`HX3004` (false-positive) errors. Major gaps tracked: recursive multi-file import loader (parser only records import names), cross-file dedup + `pub` semantics, and broader MIR/LIR coverage for closures, growable arrays, nested struct construction, and `match` on user enums.

Full punch list and weekly attack order: [`doc/stage1_punch_list.md`](doc/stage1_punch_list.md).

---

## License

MIT License. Copyright (c) 2026 need-singularity. See [`LICENSE`](LICENSE).

---

## Contributing

- **Strict lint is the contract.** Every PR runs through S0–S5 + S8. There is no `--unsafe`, no `HEXA_STRICT=0`. The only opt-out is `@grace(HXxxxx, until=, reason=)` on a single item.
- **Every `@grace` site emits HX9000** at every compile, and CI fails the build unless a matching `Acked-grace: HXxxxx by <reviewer>` trailer accompanies the change. Bypasses are never silent.
- **Diagnostics, error messages, `hexa explain`, stdlib docs are ENGLISH ONLY** (Decision 3). Design RFCs and meta documents may remain in the author's preferred language.
- **Pointers**: `gate/` for CI gates, `doc/` for runbooks and audits, `SPEC.yaml` for authoritative decisions, `proposals/` for active RFCs. Edit `SPEC.yaml`; never edit `SPEC.md` directly — it is auto-rendered.

For the full SSOT, see [`SPEC.md`](SPEC.md) (rendered) or [`SPEC.yaml`](SPEC.yaml) (source).
