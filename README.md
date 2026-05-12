# hexa-lang

> An atlas of laws bound to the compiler. The stricter the gate, the cleaner the code that passes.

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19404816.svg)](https://doi.org/10.5281/zenodo.19404816)
[![phase A0–B5](https://img.shields.io/badge/phase-A0%E2%80%93B5%20PASS-brightgreen.svg)](SPEC.yaml)
[![D1](https://img.shields.io/badge/D1-PASS-brightgreen.svg)](SPEC.yaml)
[![D2](https://img.shields.io/badge/D2-SCAFFOLD-yellow.svg)](SPEC.yaml)
[![M0](https://img.shields.io/badge/M0-PASS-brightgreen.svg)](tests/m0)
[![wilson-build](https://img.shields.io/badge/wilson--build-PASS-brightgreen.svg)](SPEC.yaml)
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

## 🎯 What just landed (Cycle close 2026-05-11)

The closure round's fixed points, with witnesses on disk:

- `41ecfb97` — RFC-020 A4 enum-payload codegen restored in SSOT `codegen_c2.hexa` (regen-safe; test_enum_payload_full 15/15 codegen + interp)
- `46016739` — builtin/method taken-by-value → `__hxthunk_<name>` codegen (fixes `hexa_callN(<builtin>)` undeclared) + un-doubled `hexa_cc.c`
- `6c0fbac7` — `exec_stream_kill(h)` runtime builtin (fork+setpgid stream child, SIGTERM→grace→SIGKILL)
- `4725c619` — `stdlib/semver.hexa` — SemVer 2.0.0 parse/compare/range-satisfies (test_semver 110/110)
- `df9e7f6b` — install-relative `stdlib/` discovery + `HEXA_INSTALL_DIR` passdown (`use "stdlib/*"` works without `HEXA_LANG`/`HEXA_STDLIB_ROOT`)
- `0ba5fd7d` — shell-builtin absorption: `pwd → cwd()/getcwd()`, `ls → list_dir()` intrinsics (absorbed 638→752, pending 197→83)
- `731f41d6` — `hexa cc` resolves `hexa_cc.c`/SSOT/`-I` via `$HEXA_LANG > install_dir > ./self` (works out-of-tree)
- `a5de44e2` — `self/stdlib/law_io.hexa` selftest `main()` → `tool/law_io_selftest.hexa` (u_main collision on flatten)
- `dae438ee` — `~/.hx/bin/hexa_real` re-promoted from HEAD `46016739` (sha cd817981…)
- `774c5d32` / `4f5f8f07` — stage-1 punch-list v2: A1+A2 host re-promote → #13 RSS re-probe **peak ~782 MB** (vs 3 510 MB) — P0 stage-1 OOM closed at current scale
- `571df583` / `a8ff675b` — SPEC §19/§20 reconcile + Gap-15 close-out
- `340c3788` / `5ddcf2a9` — wilson↔hexa-lang closure (VERIFIED — `hexa build core/main.hexa` → `wilson 0.0.1`) + SPEC closure-round fold-in

Snapshot derived from `git log` on main; full tables at `SPEC.yaml::phases_completed_2026_05_09` and `SPEC.yaml::phases_completed_2026_05_11_closure`.

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

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"
```

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
- `hexa build` / `hexa cc` work **out-of-tree** — flattens `use`/`import`, resolves `hexa_cc.c`/SSOT/`-I` via `$HEXA_LANG > install_dir > ./self`; install-relative `stdlib/` discovery means `use "stdlib/*"` works with no env vars (downstream: `wilson` builds end-to-end → `wilson 0.0.1`)
- stage-1 P0 host-OOM closed at current scale: A1 phase-arena reset + A2 in-place splice accumulator → peak ~782 MB (was 3 510 MB)
- 14+ pinned decisions in `SPEC.yaml`, every claim traceable to an RFC

* * *

## 🚧 Roadmap

- **stage 1: P0 host-OOM closed at current scale** (A1+A2 → peak ~782 MB, was 3 510 MB); the remaining open work toward a full stage-1 binary is the compiler-driver gaps (Gaps 1–16) + a fixed-point (stage2 == stage3) re-estimate — see [`doc/stage1_punch_list_v2.md`](doc/stage1_punch_list_v2.md).
- biggest unknowns: MIR/LIR coverage on real `compiler/` source (closures, growable arrays, nested struct construction, `match` on user enums) and what a *successful* self-compile diagnostic trace actually looks like.
- full punch list: [`doc/stage1_punch_list_v2.md`](doc/stage1_punch_list_v2.md).

Phase status (PASS / IN-PROGRESS / DEFERRED) lives in [`SPEC.yaml::phases_completed_2026_05_09`](SPEC.yaml) and [`SPEC.yaml::phases_completed_2026_05_11_closure`](SPEC.yaml).

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

MIT License. Copyright (c) 2026 dancinlab. See [`LICENSE`](LICENSE).

* * *

## 🤝 Contributing

Strict lint is the contract. Every PR runs through S0–S5 + S8. The only opt-out is `@grace(HXxxxx, until=, reason=)` on a single item, and every `@grace` emits HX9000 at every compile. CI fails the merge unless `Acked-grace: HXxxxx by <reviewer>` rides along.

Pointers: `gate/` for build gates, `proposals/` for active RFCs, `SPEC.yaml` for decisions, `doc/` for runbooks and audits. Diagnostics, error messages, `hexa explain`, stdlib docs are ENGLISH ONLY (Decision 3).
