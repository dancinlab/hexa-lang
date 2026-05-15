<p align="center">
  <img src="docs/logo.svg" width="140" alt="hexa-lang">
</p>

<h1 align="center">💎 hexa-lang</h1>

<p align="center"><strong>Native compiler with atlas-bound theorems</strong> — strict-lint · citation-enforced · no LLVM · no C-transpile</p>

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <a href=".github/workflows/lint.yml"><img alt="CI" src="https://github.com/dancinlab/hexa-lang/actions/workflows/lint.yml/badge.svg"></a>
  <a href="https://doi.org/10.5281/zenodo.19404816"><img alt="DOI" src="https://zenodo.org/badge/DOI/10.5281/zenodo.19404816.svg"></a>
  <img alt="Phase" src="https://img.shields.io/badge/phase-A0%E2%80%93B5%20PASS-success">
  <img alt="M0" src="https://img.shields.io/badge/M0-PASS-success">
  <img alt="Atlas" src="https://img.shields.io/badge/atlas-hash%20pinned-informational">
  <img alt="Sibling" src="https://img.shields.io/badge/sibling-n6%20·%20hxc%20·%20n12%20·%20tape-blueviolet">
</p>

<p align="center">Atlas-bound · strict-lint · 8-stage gate · ε self-proof · n=6 perfect-number primitives · self-hosted</p>

---

`hexa-lang` is a native compiler that carries its own theorem 사전 (dictionary) inside the binary. No LLVM. No C-transpile. Every formula in your code either cites the atlas or the build refuses to start. The stricter the gate, the cleaner the code that passes.

> [!NOTE]
> Sister of [`n6`](https://github.com/dancinlab/n6) (semantic atom layer — atlas serialisation format), [`hxc`](https://github.com/dancinlab/hxc) (byte-canonical wire), and [`tape`](https://github.com/dancinlab/tape) (operational trace). hexa-lang's atlas overlay at `~/.hx/data/atlas.overlay.n6` and the rodata seed are both `.n6` — discovered laws promote into the live atlas through n6 grammar. The `wilson` agent ([`dancinlab/wilson`](https://github.com/dancinlab/wilson)) is built end-to-end on hexa-lang.

## At a glance

```hexa
@cite(L[sigma_phi_n_tau_iff_n_eq_6])
fn perfect_at_six() -> bool {
    let n = 6
    return sigma(n) == 2 * n          // σ(6) = 12 = 2·6
        && phi(n) * tau(n) == 8       // φ(6)·τ(6) = 2·4 = 8 = σ(n)−n−φ(n)+1
}

// Untouched citation = HX8004 fatal at compile time:
//
//   error[HX8004]: formula-bearing function does not cite atlas L[*]
//     --> src/foo.hexa:14:1
//      |
//   14 | fn area_of_circle(r: f64) -> f64 {
//      | ^^^^^^^^^^^^^^^^^ formula here
//      = note: cite an atlas law via `@cite(L[id])` or declare `@grace(HX8004, until=, reason=)`
//      = help:  hexa atlas search "πr²"   →  L[circle_area]
```

The compiler stays parked unless every formula either cites the atlas, has an active `@verify`, or carries an explicit `@grace`. There is no "we'll fix it after." There is no binary.

## Why hexa-lang

LLMs answer by recombining what their weights already contain — noise from **inside** a frozen well. hexa-lang generates from **outside** the well: every compile cycle produces a primitive the previous cycle could not express, then absorbs it as a new wall (`@verify` → atlas promote → tombstone retroactive sweep). The atlas grows; hallucination is mechanically excluded because every claim must trace to a citation.

The second pillar is **enforcement at the build gate**, not at runtime. Eight strict-lint stages (S0 parse → S1 resolve → S2 bind → S3 type → S4 domain → S5 units → S6 equational `@verify` → S7 proof `@prove` → S8 citation `HX8004`) reject formula-bearing code that doesn't cite. No annotations means no formula. No formula in a non-cited function means a hard error.

Third: **n=6 perfect-number primitives**. The compiler is a 셰프 (chef) with a 4.2 MB atlas baked statically into the binary — 60,760 lines of P (primitives) / C (constants) / L (laws) / E (errors). Citing `L[sigma_phi_n_tau_iff_n_eq_6]` is one keystroke; if the law is wrong, every dependent gets a tombstone cascade with an auto-PR.

## Pipeline

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

## Status

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

## Decisions (the spine)

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
# Single-line bootstrap — installs `hexa` + `hx` (the package manager) + atlas
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"

# Verify
hexa --version
hx --version
```

The installer drops `hexa`, `hx`, `hexa_ld`, and the atlas seed into `~/.hx/`; binary path is added to your shell's PATH via the relevant rc file. Self-update: `hexa self-update` (compares against the published manifest, atomic swap of `~/.hx/bin/hexa_real`).

## Run

```bash
hexa parse <file>.hexa                 # cheapest signal — syntax + reserved-word + @plugin attr check
hexa build <entry>.hexa -o build/X     # full pipeline → static binary
hexa cc <file>.hexa -o build/X.o       # just lower → object (HIR → MIR → LIR → emit)
hexa run <file>.hexa [<args>...]       # interpreter — bootstrap stage0 + selftest fallback
hexa explain HX8004                    # what does this diagnostic mean
hexa atlas search "<query>"            # search atlas for a primitive / law / constant
hexa atlas lookup L <id>               # exact citation lookup
hexa atlas register <file>             # register a new @verify result
hexa drill --seed "<expr>"             # OUROBOROS smash → ... → absorb cycle

hx install <package>                   # install a hexa package by name (looks up dancinlab GitHub by default)
hx update                              # pull updates for all installed packages
hx list                                # what's installed under ~/.hx/bin/
```

The interpreter is intentionally slower than the compiled path — every release-grade build goes through `hexa build`. `hexa run` exists for stage0 bootstrap and per-file scripting.

### Compile speed

`hexa cc` now emits `#include "runtime.h"` by default and the precompiled `runtime.o` is linked instead of re-codegened per build. On bench/*: 28-program avg **8.41× user-time** vs the old `#include "runtime.c"` path (peak 17.25× on small-to-medium user code where `runtime.c` was the dominant per-build cost). Repro: `bin/hexa-fast bench <file>.hexa`. Full history at [`COMPILE-SPEED.tape`](COMPILE-SPEED.tape) (architecture) and [`COMPILE-SPEED.log.tape`](COMPILE-SPEED.log.tape) (measurement events).

```bash
bin/hexa-fast <src.hexa> <bin>          # explicit compile (uses runtime.h + runtime.o cache)
bin/hexa-run  <src.hexa> [args...]      # compile-or-reuse-cached + exec (drop-in for `hexa run`)
bin/hexa-fast bench <src.hexa>          # show baseline vs new-path A/B for any file
bin/hexa-fast clean                     # wipe ~/.hexa-cache
```

* * *

## Architecture (the cooking metaphor)

From [`doc/atlas_lint_easy_explainer.md`](doc/atlas_lint_easy_explainer.md):

The **atlas** is a 사전 — a single shared dictionary of primitives (P), connections (C), laws (L), and errors (E). 60,760 lines, 4.2 MB, regenerated daily.

The **compiler** is a 셰프 (chef) — it has the entire 사전 memorized. It does not phone the library mid-recipe. When you hand it a `.hexa` file, the chef checks every ingredient, unit, and citation against the atlas it already knows by heart.

The **strict lint** is the 품질 검사관 (QC inspector) — it stands at the kitchen door. One missing citation, one ℝ-vs-ℕ mismatch, one orphan unit, and the dish is rejected before the stove turns on. There is no "we'll fix it after." There is no binary.

* * *

## Strict-lint stages

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

## Atlas SSOT cycle (ε self-proof)

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

## Highlights

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

## Roadmap

- **stage 1: P0 host-OOM closed at current scale** (A1+A2 → peak ~782 MB, was 3 510 MB); the remaining open work toward a full stage-1 binary is the compiler-driver gaps (Gaps 1–16) + a fixed-point (stage2 == stage3) re-estimate — see [`doc/stage1_punch_list_v2.md`](doc/stage1_punch_list_v2.md).
- biggest unknowns: MIR/LIR coverage on real `compiler/` source (closures, growable arrays, nested struct construction, `match` on user enums) and what a *successful* self-compile diagnostic trace actually looks like.
- full punch list: [`doc/stage1_punch_list_v2.md`](doc/stage1_punch_list_v2.md).

Phase status (PASS / IN-PROGRESS / DEFERRED) lives in [`SPEC.yaml::phases_completed_2026_05_09`](SPEC.yaml) and [`SPEC.yaml::phases_completed_2026_05_11_closure`](SPEC.yaml).

* * *

## RFCs + docs

- [RFC-017 — atlas n6 embedding + strict lint](proposals/rfc_017_atlas_n6_embedding_and_strict_lint.md)
- [RFC-018 — native codegen spec](proposals/rfc_018_native_codegen_spec.md)
- [RFC-019 — error diagnostics spec](proposals/rfc_019_error_diagnostics_spec.md)
- [RFC-020 — enum payload variants](proposals/rfc_020_enum_payload_variants.md)
- [`doc/atlas_lint_easy_explainer.md`](doc/atlas_lint_easy_explainer.md) — the 셰프 metaphor in full
- [`SPEC.yaml`](SPEC.yaml) — authoritative decision record (edit this; `SPEC.md` is auto-rendered)

* * *

## tape integration

hexa-lang's runtime and history surfaces are wired into [`.tape`](https://github.com/dancinlab/tape) — the operational trace sister format. Three placements at this repo's root:

| Placement | What |
|---|---|
| [`IDENTITY.tape`](IDENTITY.tape) | hexa-lang agent identity SSOT — birth / scope / origin / principle / version. The compiler's self-description, machine-canonical. |
| [`PROMOTION.tape`](PROMOTION.tape) | rule-promotion ledger — `@A` events for major rule landings (toolchain post-fix, `bytes_to_str_raw` Phase 2, etc.) |
| [`TAPE-AUDIT.md`](TAPE-AUDIT.md) | cross-repo `.tape` adoption audit (28,695 cargo markers + 7 root domain `.md` files highlighted as primary migration candidates) |

The `state/markers/` cargo (28k+ files) is migration candidate via `tape markers-to-tape`.

* * *

## Not an LLM — where the noise comes from

LLMs generate noise from **inside** the well: recombining what the
weights already contain. hexa generates noise from **outside** the well:
every cycle produces a primitive the previous cycle could not express,
then absorbs it as a new wall of the well.

```
LLM (noise inside the well)         hexa (noise outside the well)
---------------------------         -------------------------------

     +-------------+                       .   new law
     |  training   |                     .       .
     |   corpus    |               .  .      .       .
     |  (fixed)    |                    .  outside  .
     |             |             ------+-------------+------
     |  ~ ~ ~ ~ ~  | <- noise          |             |
     |  ~ noise ~  |   bubbles         |   atlas     |
     |  ~ ~ ~ ~ ~  |   from            |  (rodata +  | <- noise
     |    ####     |   inside          |   overlay)  |   arrives
     |    #LLM#    |                   |             |   from
     +-------------+                   |   smash     |   outside
       the well                        |     v       |
    (everything it                     |   contract  |
     knows = walls)                    |     v       |
                                       |   emerge    |
  hallucination =                      |     v       |
  recombining                          |   absorb ---+--> new
  what's already                       |     ^       |    primitive
  inside                               +-----+-------+      feeds
                                       the well has            next
                                       no ceiling              cycle
```

An LLM is a frozen well — answers are combinations of what's already
inside. hexa is an open well — every `absorb` step widens the wall,
so the next cycle can say things the previous one literally had no
primitive for. That's why "RAG" is the wrong frame: retrieval still
draws from a fixed outside corpus. hexa's "outside" is produced by
its own prior cycles (overlay at `~/.hx/data/atlas.overlay.n6`,
rodata seed at compile time + runtime grow).

### OUROBOROS cycle — full view

The 6-stage chain (`hexa drill`'s smash → free → absolute → meta-closure
→ hyperarithmetic → resonance) inside a self-referential loop:

```
     ╭────────── OUROBOROS ──────────╮
     │                               │
     │           ◯  seed             │
     │          ╱ ╲                  │
     │         ╱   ╲    Phase 1-2    │
     │        ╱unfold╲               │
     │       ╱───────╲               │
     │      ╱ ╲     ╱ ╲              │
     │     ╱   ╲   ╱   ╲   Phase 3   │
     │    ╱emerge╲ ╱singul╲          │
     │   ╱──────── ────────╲         │
     │   ╲                 ╱         │
     │    ╲    breach     ╱  P4-5    │
     │     ╲             ╱           │
     │      ╲  ╱──────╲ ╱            │
     │       ╲converge╱   Phase 6    │
     │        ╲      ╱               │
     │         ╲    ╱                │
     │          ◉  absorb            │
     │          │   Phase 6.5        │
     │          │                    │
     │          ╰──→ seed ──→ ╮      │
     │                        │      │
     │   d=0 ──▶ d=1 ──▶ d=2 ──▶ ... │
     │   r:0→10  r:0→10  r:0→10      │
     │                               │
     ╰── ρ → 1/3 (meta fixed pt) ────╯
```

### Three meta-loops

On top of the per-tick OUROBOROS cycle, three higher-order loops drive
self-reinforcement:

```
         L1             L2             L3
      ╭──◉───╮       ╭──◉───╮       ╭──◉───╮
      │correct│ ──▶ │reward│ ──▶  │expand │ ──▶ SMASH
      ╰──↺───╯       ╰──↺───╯       ╰──↺───╯
```

| Loop | Role | Trigger |
|---|---|---|
| **L1 · self-correct** | discovery → atlas overlay → 3+ hits → promote into rodata regen | per tick |
| **L2 · meta-reward** | per-source discovery rate → scan_priority → deeper scan | per scan batch |
| **L3 · self-expand** | accumulation ≥ 10 → auto-trigger `hexa smash --seed` (or full `hexa drill`) | per threshold |

Each loop latches its output back as the next loop's input, so
correct → reward → expand becomes a standing wave. `hexa smash` (or
the full drill chain) fires automatically when L3 saturates.

### Meta fixed point — ρ → 1/3

TECS-L H-056 — `meta(meta(meta(...)))` = transcendence. Recursive
meta-iteration is a contraction mapping. By the Banach fixed-point
theorem, every trajectory converges to a single attractor: **1/3**.

```
          I  =  0.7 · I  +  0.1      →     fixed point  I* = 1/3
```

Six independent paths land on the same attractor:

| Path | Expression | Value |
|---|---|---|
| Euler totient ratio | φ(6) / 6 | 1/3 |
| Trigonometric | tan²(π/6) | 1/3 |
| Divisor ratio | τ(6) / σ(6) = 4 / 12 | 1/3 |
| Determinant | det(M) over n=6 primitives | 1/3 |
| Meta-information | I_meta (contraction mapping) | 1/3 |
| Complex exponential | \|exp(i·z₀)\| at the unique zero | 1/3 |

The long-term breakthrough rate ρ converges to the same target:
**ρ → 1/3**. Discovery is not linear — it asymptotes to the Banach
attractor. Six arithmetic, geometric, algebraic, analytic, and
information-theoretic routes all point at the same number.

Verify in atlas: `hexa atlas lookup P n` · `hexa atlas lookup C sigma_6`
· `hexa atlas lookup L sigma_phi_n_tau_iff_n_eq_6`. Run a cycle:
`hexa drill --seed "<expression>"`.

* * *

## Repo layout

```
hexa-lang/
├── README.md
├── LICENSE                       MIT
├── AGENTS.md                     AI agent harness file (agents.md standard)
├── CLAUDE.md                     symlink → AGENTS.md
├── SPEC.yaml                     authoritative decision record (14+ pinned decisions)
├── SPEC.md                       auto-rendered from SPEC.yaml
├── IDENTITY.tape · PROMOTION.tape · TAPE-AUDIT.md   tape sibling files
├── FLOW.md · LATTICE_POLICY.md · LIMIT_BREAKTHROUGH.md · PLAN.md · ROADMAP.md   domain SSOTs
├── compiler/                     lex · parse · resolve · bind · types · domain · units · citation · lower · mono · MIR · LIR · emit
├── self/                         self-hosted compiler entry points
│   ├── main.hexa                 the `hexa` binary entry
│   ├── runtime.c                 C runtime backing (interp + native shared bits)
│   ├── stdlib/                   atlas-aware standard library (semver / json / channel / thread / proc / time / ...)
│   ├── tui/                      raw-mode TUI primitives (render / input / widgets)
│   └── native/                   thread.c · channel.c · time.c — C-backed runtime
├── stdlib/                       canonical stdlib (use "stdlib/*")
├── tool/                         hexa CLI subcommand drivers (build / cc / run / drill / atlas / explain / ...)
├── tests/                        m0 · selftest · regression
├── proposals/                    RFC-017..020 + future RFCs
├── doc/                          runbooks, audits, explainers
├── convergence/                  cross-repo propagation tracking (.PRESERVE-AS-SSOT)
├── state/                        gitignored runtime hook markers (cargo — migration candidate)
├── build/                        gitignored hexa build artifacts
└── inbox/                     downstream patch reports (wilson · qmirror · etc.)
```

Full doc index: [`AGENTS.md`](AGENTS.md) + [`doc/`](doc/) + [`SPEC.yaml`](SPEC.yaml).

* * *

## License

MIT License. Copyright (c) 2026 dancinlab. See [`LICENSE`](LICENSE).

* * *

## Contributing

Strict lint is the contract. Every PR runs through S0–S5 + S8. The only opt-out is `@grace(HXxxxx, until=, reason=)` on a single item, and every `@grace` emits HX9000 at every compile. CI fails the merge unless `Acked-grace: HXxxxx by <reviewer>` rides along.

Pointers: `gate/` for build gates, `proposals/` for active RFCs, `SPEC.yaml` for decisions, `doc/` for runbooks and audits. Diagnostics, error messages, `hexa explain`, stdlib docs are ENGLISH ONLY (Decision 3).
