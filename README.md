# hexa-lang

> An atlas of laws bound to the compiler. The stricter the gate, the cleaner the code that passes.

[![phase A0–B5](https://img.shields.io/badge/phase-A0%E2%80%93B5%20PASS-brightgreen.svg)](SPEC.yaml)
[![D1](https://img.shields.io/badge/D1-PASS-brightgreen.svg)](SPEC.yaml)
[![M0](https://img.shields.io/badge/M0-PASS-brightgreen.svg)](tests/m0)
[![atlas](https://img.shields.io/badge/atlas-hash%20pinned-blue.svg)](SPEC.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A native compiler that carries its own theorem 사전 (dictionary) inside the binary. No LLVM. No C-transpile. Every formula in your code either cites the atlas or the build refuses to start.

* * *

## 🧱 Pipeline

```
   .hexa source
        │
        ▼
   lex ─► parse ─► resolve ─► bind ─► types ─► domain ─► units ─► citation
                    (S1)      (S2)    (S3)     (S4)     (S5)      (S8)
        │                                                            │
        │                  any fatal stage → no binary               │
        ▼                                                            ▼
   lower (HIR) ─► mono ─► MIR (SSA) ─► optimize ─► regalloc (LIR) ─► emit (asm)
        │                                                            │
        ▼                                                            ▼
                                  hexa_ld v1.1
                          ELF64 + Mach-O arm64 static
                                       │
                                       ▼
                                 native binary
```

A binary appears only when every fatal stage passes. The atlas (4.2 MB) is baked in at compile time — runtime cost: 0 ms.

* * *

## 🎯 What just landed (Cycle close 2026-05-09)

The last week's fixed points, with witnesses on disk:

- `f9e61595` — macOS Mach-O gate Phase A — wrapper ref + lint + SPEC + doc
- `0b14ae23` — Decision 5e completion: cascade tombstones + auto-PR helper
- `3a0ce4d2` — tombstone + retroactive sweep + HX1099 (citing tombstoned L)
- `5ee37b49` — HX8004 atlas citation strict — formula must cite L (S8 Error)
- `e1ba9369` — HX9000 @grace ai-native warn — every grace site visible at compile
- `0aa8b47a` — Acked-grace CI checker — enforces user consent per @grace site
- `0008cdd4` — promote_to_atlas — Decision 5b/5d auto-promote
- `758659eb` — hexa_ld v1.1 — Mach-O arm64 static-binary emission
- `5569ee25` — M0 gap 1–3: label emit, arm64 ldp/stp, return lowering (M0 PASS)
- `6786affd` — phase B5 — S6 equational verify (in-house prover v0)

Snapshot derived from `git log` on main; full table at `SPEC.yaml::phases_completed_2026_05_09`.

* * *

## 📐 Decisions (the spine)

Six choices that shape everything else, pinned in [`SPEC.yaml`](SPEC.yaml):

1. **Native compiled, direct codegen** — no LLVM, no C-transpile. The interpreter survives only as bootstrap stage0 and retires once stage3 hits a byte-equal fixed point.
2. **Atlas static-baked into the compiler binary** — `ATLAS_HASH` pinned, drift handled by CI auto-rebuild. Runtime atlas-load cost: 0 ms.
3. **Strict compile-time fatal lint** — Python `SyntaxError` + TypeScript `strict` model. S0–S5 + S8 always fatal. No `--unsafe`. No `HEXA_STRICT=0`.
4. **`@grace` is the only opt-out** — `@grace(HXxxxx, until="...", reason="...")` per site, every site emits HX9000 at every compile, CI requires `Acked-grace:` trailer.
5. **ε self-proof** — verified functions auto-register as atlas `L[*]` theorems; tombstones cascade on prover upgrade; `HX1099` fires on citing a tombstoned law.
6. **ENGLISH ONLY diagnostics** — catalog, `hexa explain`, stdlib docs. RFCs and meta docs may stay bilingual.

Full record: 14+ pinned decisions, all traceable to RFC-017 through RFC-020.

* * *

## 🔭 Quick start

```bash
# 1. clone
git clone https://github.com/need-singularity/hexa-lang
cd hexa-lang

# 2. install hexa + hx (one-liner, drops binaries into ~/.hx/bin)
hexa install.hexa

# 3. M0 smoke — fn main() -> i32 { return 0 } end-to-end
build/hexa_interp tests/m0/run.hexa

# 4. strict lint over a tree (S0–S5 + S8 fatal)
build/hexa_interp compiler/main.hexa --check path/to/source.hexa
```

`hx install <pkg>` resolves bare names by probing GitHub orgs in `HX_ORGS` order. No central index, no lock-in.

* * *

## ⚙️ Architecture (the cooking metaphor)

From [`doc/atlas_lint_easy_explainer.md`](doc/atlas_lint_easy_explainer.md):

The **atlas** is a 사전 — a single shared dictionary of primitives (P), connections (C), laws (L), and errors (E). 60,760 lines, 4.2 MB, regenerated daily.

The **compiler** is a 셰프 (chef) — it has the entire 사전 memorized. It does not phone the library mid-recipe. When you hand it a `.hexa` file, the chef checks every ingredient, unit, and citation against the atlas it already knows by heart.

The **strict lint** is the 품질 검사관 (QC inspector) — it stands at the kitchen door. One missing citation, one ℝ-vs-ℕ mismatch, one orphan unit, and the dish is rejected before the stove turns on. There is no "we'll fix it after." There is no binary.

* * *

## 📜 Strict-lint stages

Eight checks, six always fatal, two opt-in via annotation:

- **S0 parse** — syntax / lex. No surprises.
- **S1 resolve** — every `P[*]`, `C[*]`, `L[*]`, `E[*]` exists in the atlas.
- **S2 bind** — every name resolves to a real binding.
- **S3 type** — nominal types and generics.
- **S4 domain** — ℝ / ℕ / ℤ / ℂ consistency.
- **S5 units** — dimensional analysis. No "distance + time."
- **S6 equational** — opt-in via `@verify`; canonical-form check + sample counter-example. In-house prover v0, no Z3.
- **S7 proof** — opt-in via `@prove`; reserved for the in-house prover only.
- **S8 citation** — formula-bearing functions must cite atlas `L[*]` (HX8004). 공식 없으면 거절.

* * *

## 🛡️ Atlas SSOT cycle (ε self-proof)

```
   @verify fn f(...) { ... }                     ← author writes a theorem
            │
            ▼
      compile-time prover  (S6, equational + sample-eval, in-house only)
            │
            ▼
      atlas.proposed.{date}.n6        ← compiler/discover/staging.hexa
            │
            ▼
      promote_to_atlas                 ← compiler/discover/promote.hexa
            │           ├─► fingerprint dedup → register as alias
            │           └─► id collision     → first-wins + warning
            ▼
      atlas.append.{date}.n6           ← live atlas grows
            │
            ▼
      prover upgrade                   ← retroactive sweep (compiler/discover/cascade.hexa)
            │
            ▼
      tombstone failing L nodes + cascade dependents
            │
            ▼
      auto-PR (tool/auto_pr_tombstone_sweep.hexa) → human review
```

Citing a tombstoned `L[id]` fires `HX1099` and fails the build. Bypass is `@grace`, which is never silent.

* * *

## 💎 Highlights

- transitioned from interpreter to native compiler — no LLVM, no C-transpile
- 4.2 MB atlas baked statically into the compiler binary; runtime cost 0 ms
- 8-stage strict lint S0–S5 + S8 enforced at compile time, fatal by default
- ε self-proof: `@verify` / `@discover` → atlas auto-promote → tombstone retroactive sweep
- M0 milestone: `fn main() -> i32 { return 0 }` produces a working Mach-O arm64 binary
- `hexa_ld` v1.1: in-house static linker for ELF64 + Mach-O arm64
- 14+ pinned decisions in `SPEC.yaml`, every claim traceable to an RFC

* * *

## 🚧 Roadmap

- **stage 1 reach: 6–10 weeks** of focused work to first full stage1 binary, plus 2–3 weeks for stage2 == stage3 byte-equal stabilization.
- biggest unknowns: recursive multi-file import loader, MIR/LIR coverage on real `compiler/` source (closures, growable arrays, nested struct construction, `match` on user enums).
- full punch list: [`doc/stage1_punch_list.md`](doc/stage1_punch_list.md).

Phase status (PASS / IN-PROGRESS / DEFERRED) lives in [`SPEC.yaml::phases_completed_2026_05_09`](SPEC.yaml).

* * *

## 📚 RFCs + docs

- [RFC-017 — atlas n6 embedding + strict lint](proposals/rfc_017_atlas_n6_embedding_and_strict_lint.md)
- [RFC-018 — native codegen spec](proposals/rfc_018_native_codegen_spec.md)
- [RFC-019 — error diagnostics spec](proposals/rfc_019_error_diagnostics_spec.md)
- [RFC-020 — enum payload variants](proposals/rfc_020_enum_payload_variants.md)
- [`doc/atlas_lint_easy_explainer.md`](doc/atlas_lint_easy_explainer.md) — the 셰프 metaphor in full
- [`SPEC.yaml`](SPEC.yaml) — authoritative decision record (edit this; `SPEC.md` is auto-rendered)

* * *

## 📜 License

MIT License. Copyright (c) 2026 need-singularity. See [`LICENSE`](LICENSE).

* * *

## 🤝 Contributing

Strict lint is the contract. Every PR runs through S0–S5 + S8. The only opt-out is `@grace(HXxxxx, until=, reason=)` on a single item, and every `@grace` emits HX9000 at every compile. CI fails the merge unless `Acked-grace: HXxxxx by <reviewer>` rides along.

Pointers: `gate/` for build gates, `proposals/` for active RFCs, `SPEC.yaml` for decisions, `doc/` for runbooks and audits. Diagnostics, error messages, `hexa explain`, stdlib docs are ENGLISH ONLY (Decision 3).
