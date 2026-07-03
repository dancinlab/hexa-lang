<p align="center">
  <img src="docs/logo.svg" width="140" alt="hexa-lang">
</p>

<h1 align="center">💎 hexa-lang</h1>

<p align="center"><strong>Native compiler with atlas-bound theorems</strong> — strict-lint · citation-enforced · no LLVM · self-hosting native fixpoint</p>

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

`hexa-lang` is a native compiler that carries its own theorem 사전 (dictionary) inside the binary. **No LLVM anywhere** — the self-host backend lowers source through its own IR to native objects (a byte-identical `gen3 ≡ gen4` fixpoint) and links them with its own `hexa_ld`; `hexa run`/`hexa build` ship clang-free on the promoted toolchain. (Two C pieces remain by engineering necessity, not as unfinished debt: a C-transpile fallback delegate for some flows, and a libc/syscall runtime floor generated from `.hexa` emitters — the latter is **reducible**, not permanent: a 2026-06-16 falsification showed ~50% of the runtime is already portable to `.hexa` (a `.hexa` `fnv1a` is byte-identical to the C one) and zero-`.c` is an open, attackable campaign — `runtime_hi_gen.c` is now eliminated on **both** arm64-darwin and x86_64-linux via native `.s` seeds — the x86_64 backend was reworked (#3462) to carry the full HexaVal `{tag,payload}` pair like arm64 (its old "raw-int model" had dropped the tag, silently breaking native string functions; caught by a C-differential harness, fixed at the root, confirmed by all CI faithful + whole-compiler byte-eq gates green); a 2026-06-17 audit further found the `rt_str` family is already hexa-source-complete (every function has a native `.hexa` definition), so the remaining `.c` reduction is a standalone-build redesign — dropping the `#else` C-body fallbacks that duplicate the native source — not more function ports; the runtime-core port now has a symmetric pair of HexaVal leaf-intrinsics on both targets — `__hx_tag(v)` reads a value's tag and `__hx_make_val(tag, payload)` writes a `{tag, payload}` HexaVal from two raw words without boxing-tag-loss (so a payload word loaded from an array slot keeps its real element tag — verified on real x86_64: a `__hx_make_val(TAG_STR, ptr)` round-trips back as TAG_STR, not flattened to TAG_INT), unblocking native array/map element access; with that the collection-accessor read-half lane is now COMPLETE — the array (`get`/`set`/`pop`/`shift`) and map (`get`/`contains`) alloc-free primitives are ported to raw-memory `.hexa` bodies, shipping native via a frozen `.s` seed ar'd into `runtime.a` with the standalone C `#else` bodies DROPPED (the first non-string runtime-substrate `ls` byte-decrease, #3494–#3506, 13 PRs, every one preserving the `gen3≡gen4` fixpoint); the C-transpile bootstrap can't lower the raw-memory intrinsics (only the native backend can), so they enter the runtime via a native-emitted seed exactly like the `rt_str` family. The next frontier is the **alloc/write lane** (`set`/`push`/`new`), whose naive `#else`-drop is a measured NO-GO (the arena ships as C on both targets, so dropping it is a real link regression) — the live levers are an **M5 standalone-redesign** (native-compile the `self/rt/` tree so the write `#else` can finally drop) and the make_val-unlocked map construct-half — the first M5 brick already RUNs: a de-circularized multi-pool raw-memory bump arena (the allocator floor, re-shaped to address its pool table by raw pointer instead of a hexa array + `.push()`) native-emits through the shipping x86_64 backend and executes exit-0 on real hardware, non-circular (no malloc/push referenced), and that proven body is now ported into the real `self/rt/alloc.hexa` — the next blocker, located by a RAN emit, is porting `self/rt/syscall.hexa` off its P7-7 `syscall()` builtin onto the shipping `__hx_syscall6` leaf — its `__TARGET_OS__` half is already landed as a new `__hx_target_os()` const intrinsic (x86_64→linux, arm64→darwin, RUN-verified, gen3≡gen4 preserved), and all 25 of syscall.hexa's `syscall()` call sites are now rewritten to that `__hx_syscall6` leaf — the string→pointer gap is closed (a new `__hx_str_ptr` leaf) and the module-global data-slot gap too (x86_64 now emits a `.data g<id>:` slot, matching arm64 — a real parity bug fixed), so the combined alloc+syscall gate **emits + assembles + links clean**; the last blocker — the x86_64 backend had no module-global *write* path (it read `g<id>` but never stored to it) — is now FIXED (the lower's `arena_id==-999` sentinel write now emits `mov [rip+g<id>], payload`), so the combined alloc+syscall gate **runs exit-0 on real x86_64 — a C-free alloc+syscall integration proven end-to-end** (cross-pool arena grow + mark/rewind + reset, byte-exact, over fully-native syscall+alloc with no C body); the remaining work is the standalone relink — the alloc+syscall seed is now FROZEN (`self/native/alloc_syscall_{x86_64,arm64,arm64-linux}.s`, 116 native globals each) and arm64 write-parity is confirmed already-present, but the seed's pure leaves (syscall/pointer) have no C body to drop (the shipping runtime is libc-backed) and the arena is all-or-nothing (a different data structure from the C linked-block one), and the map construct-half turns out to be C memory-management orchestration (lazy-alloc + load-factor rehash + key-intern), not a pure-algorithm port — so the honest shape of the campaign is now clear: the EASY pure-algorithm reductions are exhausted (the read-half), and what remains is the **memory substrate floor** — the real next lever is porting the C arena itself to `.hexa` (linked-block allocator + RSS-hygiene, the hardest single body) — this is now underway: its address-envelope half (the part that keeps self-compile RSS bounded) is real code in `self/rt/alloc.hexa` and native-emit-verified, with the C-ABI half now DONE (linked-block alloc.hexa rewrite + seed regen, native-emit-verified, dormant; the build-wiring and arena `#ifndef` guard now in place (byteeq-inert until measured) and the ON measurement underway (it caught + fixed a stale seed, a seed-`main` clash, and confirmed whole-runtime byteeq — not standalone — is the right gate; the seed is now main-stripped so it ar's cleanly) — the whole-runtime byteeq/RSS measurement remaining) — it was scoped as: it is a linked-block rewrite (the C arena's mark is a 16-byte `{block*, used}` struct that callers pass by value, so the seed must adopt the C block-chain data structure, not the b2 pool table) — and that rewrite is now done: `self/rt/alloc.hexa` is a full HexaArenaBlock-chain arena (the `HexaArenaMark {block,used}` mark reuses the 16-byte HexaVal layout for a C-ABI-identical struct return), native-emit-verified, with the build-wiring + heapify↔envelope `#ifdef` + an x86_64 seed rodata fix now landed (byteeq-inert, OFF builds green) and the ON measurement RAN on real x86_64: the link is clean (the 16-byte mark struct-return ABI is confirmed compatible — the ABI-mismatch worry was refuted) and self-compile RSS stays bounded (~1.4 GB, the envelope reject works), but the whole-compiler transpile deterministically miscompiles on the large input because `hexa_val_heapify`'s slow-path (the loop that copies arena strings out to the heap) still walks the C arena struct, which the native seed never populates — so the heapify block-walk was wired to the native arena's block chain — and then a clean-rebuild isolation found the genuine root cause was a **C↔seed ABI mismatch** (and that the earlier "link-pass refuted the ABI worry" reading was misleading: the `mark`/`rewind` struct entries happened to match the C ABI, but every *scalar* seed entry did not): the native arena seed uses the HexaVal two-register calling convention (return value in `rdx`, tag in `rax`; an int arg as a `{tag, payload}` register pair) but the C runtime declared the seed entries as plain scalars, so it silently read the *tag* (always 0) instead of the value — making `hexa_arena_on()` report OFF and every block pointer / allocation come back null (the `tag 3 - tag 0` miscompile, and an earlier self-recursion, both trace to this); the fix is a **C-ABI bridge** that aliases each scalar seed symbol to its true HexaVal signature and wraps it (`#ifdef`-guarded, opt-in, OFF builds byte-identical), which eliminates the miscompile and drives execution *into* the native arena for the first time — exposing a deeper, pre-existing seed-codegen defect (a module-global's *tag* half is never persisted to its `.data` slot, only its payload), which is the now-narrow next blocker; after the arena, the map construct-half and the io/fmt/proc/fs/intern/math modules become genuine reductions; the honest accounting is in [ARCHITECTURE.json → Self-host status](ARCHITECTURE.json) (사람용 뷰어 `architecture.html`, `python3 serve.py`).) Every formula in your code either cites the atlas or the build refuses to start. The stricter the gate, the cleaner the code that passes.

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

1. **Native compiled, direct codegen** — no LLVM; native-emit (own IR → object) is the self-host backend. The tree-walking interpreter is retired: the self-host stage reached a byte-equal fixed point (`gen3 ≡ gen4`), and `hexa run`/`hexa build` compile then execute clang-free (a C-transpile fallback delegate stays for uncovered flows).
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
hexa run <file>.hexa [<args>...]       # compile then execute a single file
hexa explain HX8004                    # what does this diagnostic mean
hexa atlas lookup <id> | --prefix=<p>   # read atlas node(s) — embedded.gen.hexa SSOT
hexa atlas census                       # count BLANK cells of the @F identity grid (2145 cells/64 filled/2.98%; blanks mechanically resolvable — ATLAS/state/novel-dfs/census_blank_classify.py)
hexa atlas resolve [--n N] [--fold]     # MECHANICAL no-LLM loop: deterministically classify ALL 2145 grid cells (filled 64/closed-⚪ 1654/multi-⊞ 321/degenerate 106 @ N=20000); --fold = phase-2 @N fold (stub)
hexa atlas register --from-verify <fn> <args> <v>   # verify IN-PROCESS → fold node into embedded.gen.hexa
hexa atlas export [--out PATH]          # export live atlas → portable .n6 (n6 = export-only)

hexa deck <domain> <slug> '<spec>'     # input-deck 빵틀 → exports/<domain>/decks/<slug>/ (rtsc full · others stub)
hexa dojo <domain> <slug> '<spec>'     # cloud training-job 빵틀 → exports/<domain>/dojo/<slug>/ (.hexa+.py+run.sh)

hx install <package>                   # install a hexa package by name (looks up dancinlab GitHub by default)
hx update                              # pull updates for all installed packages
hx list                                # what's installed under ~/.hx/bin/
```

`hexa run` compiles a file then executes it in one shot — convenient for single-file scripting. Release-grade builds go through `hexa build`, which produces a reusable static binary.

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

The **atlas** is a 사전 — a single shared dictionary of primitives (P), connections (C), laws (L), and errors (E). 60,760 lines, 4.2 MB, unconditionally binary built-in (compile-time embedded); new laws land via GitHub PR.

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
      hexa atlas export                ← .n6 export artifact (interop / inspection)
            │
            ▼
      GitHub PR into embedded.gen.hexa ← the atlas SSOT (binary built-in)
            │           ├─► fingerprint dedup → register as alias
            │           └─► id collision     → first-wins + warning
            ▼
      compiler build re-embeds atlas   ← live atlas grows (no runtime overlay)
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

- native compiled — direct codegen, no LLVM (self-host native fixpoint; C-transpile = fallback only)
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
├── tool/                         hexa CLI subcommand drivers (build / cc / run / atlas / explain / ...)
├── tests/                        m0 · selftest · regression
├── proposals/                    RFC-017..020 + future RFCs
├── doc/                          runbooks, audits, explainers
├── convergence/                  cross-repo propagation tracking (.PRESERVE-AS-SSOT)
├── state/                        gitignored runtime hook markers (cargo — migration candidate)
├── archive/                      frozen records — patches/ (downstream patch reports) · fires/
└── build/                        gitignored hexa build artifacts
```

Full doc index: [`AGENTS.md`](AGENTS.md) + [`doc/`](doc/) + [`SPEC.yaml`](SPEC.yaml).

* * *

## Data corpora (git-LFS)

Data-bound corpora — ENDF/B-VIII evaluated nuclear data (HEXA-PORT P4b), and future
binary/HDF5 datasets — live under `data/` or `stdlib/corpora/` and are stored via
**git-LFS**. The reserved LFS extensions are `.hdf5 .h5 .dat .bin .endf .ace .xml.gz
.tar.gz` (see [`.gitattributes`](.gitattributes)).

hexa-lang is the canonical home for these corpora (per @D d3 — implementation /
asset SSOT) so downstream domain repos can `hx`-depend on them rather than
re-fetching from upstream mirrors. Existing tracked files (atlas SSOT text,
build artifacts, fixtures) are intentionally **not** migrated — LFS is reserved
for future data ports only. Policy reference: HEXA-PORT.md §4.0.

* * *

## License

MIT License. Copyright (c) 2026 dancinlab. See [`LICENSE`](LICENSE).

* * *

## Contributing

Strict lint is the contract. Every PR runs through S0–S5 + S8. The only opt-out is `@grace(HXxxxx, until=, reason=)` on a single item, and every `@grace` emits HX9000 at every compile. CI fails the merge unless `Acked-grace: HXxxxx by <reviewer>` rides along.

Pointers: `gate/` for build gates, `proposals/` for active RFCs, `SPEC.yaml` for decisions, `doc/` for runbooks and audits. Diagnostics, error messages, `hexa explain`, stdlib docs are ENGLISH ONLY (Decision 3).

---

🕸️ **재사용 격자 SSOT** → 루트 [`DOMAINS.tape`](DOMAINS.tape) (commons @D g67 cross-domain + g68 cross-project · `@link` connection graph · hexa-lang = shared substrate hub)
