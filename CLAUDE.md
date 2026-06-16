# hexa-lang

Native compiler for the `.hexa` language with an embedded theorem **atlas** and the `hx`
package manager. No LLVM anywhere: source is lowered through the compiler's own IR to native
objects (ELF64 / Mach-O arm64) and linked with `hexa_ld` — a byte-identical self-host fixpoint
(`gen3 ≡ gen4`), default for `--emit`. Two C pieces still remain: a C-transpile fallback
delegate for some full `hexa build`/`run` flows, and the ~5.5k-LOC C runtime substrate (the
libc/syscall bootstrap floor, generated from `.hexa` emitters) — the floor RUNTIME-PORT is
still shrinking (M3 open), an irreducible-bootstrap assessment, **not** a permanence policy. See
[ARCHITECTURE.json](ARCHITECTURE.json) → Self-host status for the honest accounting (사람용 뷰어 `architecture.html`, `python3 serve.py`). Every
formula-bearing function must cite an atlas law (`@cite(L[id])`), carry an active `@verify`, or
declare a `@grace` — otherwise the build refuses to emit a binary (stage S8, fatal `HX8004`).
The full architecture SSOT is [ARCHITECTURE.json](ARCHITECTURE.json) (JSON 트리 — 사람은 `architecture.html` 뷰어로 봄, `python3 serve.py`); this file is the single governance SSOT (md 단일화 — `project.tape`·`ARCHITECTURE.md` retired).

## Structure

```
hexa-lang/
├─ compiler/        — the compiler: S0–S8 strict-lint gate + HIR/MIR/LIR lowering + native emit
│  ├─ lex/          — S0 lexer (.hexa → tokens)
│  ├─ parse/        — S0 parser (tokens → AST)
│  ├─ check/        — S1–S8 stages (resolve · bind · types · units · equational · citation)
│  ├─ atlas/        — embedded atlas (embedded.gen.hexa rodata) + static index + fold/merge
│  ├─ lower/        — AST → HIR → MIR (SSA) lowering
│  ├─ optimize/     — const-fold · DCE · inline (opt-level 0–3)
│  ├─ codegen/      — MIR → LIR per target (arm64-darwin · x86_64-linux · thumbv7em · nvptx)
│  ├─ emit/         — LIR → asm / direct Mach-O / ELF object serialization
│  ├─ diag/         — diagnostic catalog (HX0001–HX8004) + renderers
│  └─ main.hexa     — compiler driver entry point
├─ stdlib/          — runtime + domain modules (io · math · crypto · codec · bio · chem · flame · forge)
├─ self/            — self-hosting bootstrap (compiler written in .hexa that builds itself)
├─ tool/            — hx package manager (hx.hexa) · atlas CLI (atlas_cli.hexa) · linker (hexa_ld.hexa)
├─ bin/             — CLI front-end shims (hexa-run · hexa-fast · hexa-commit · hexa-push)
├─ atlas/           — atlas working area + `.n6` export/inspection artifacts
├─ spec/            — language + format specification
├─ tests/, test/    — smoke · core-invariant · regression suites
├─ bench/           — performance benchmarks
├─ docs/            — supplementary documentation + logo
├─ ARCHITECTURE.json — architecture SSOT (JSON 트리, update in place) + architecture.html 뷰어 + serve.py
├─ CHANGELOG.md     — append-only history / decisions
├─ CLAUDE.md        — governance SSOT (this file — directives below)
└─ .harness-engine/ — vendored harness (submodule); gate engine behind .claude hooks
```

## Governance

This file is the single governance SSOT (md 단일화) — edit directives here, keep them concise:

- **diff-guard** — a subagent diffs guarded files (`git diff <baseline>...HEAD`) before staging
  (`.githooks/pre-commit`).
- **wipe-guard** — do not commit >50-line deletions in `stdlib`/`runtime`/`codegen`/`rt`
  without a scoped subject or a `WIPE-OK:` trailer.
- **atlas fold** — fold atlas nodes only into `compiler/atlas/embedded.gen.hexa` via
  branch → commit → PR (never elsewhere).
- **verify is ambient** — a successful `🔵`/`🟢` `hexa verify` auto-folds the verified atom
  into the atlas; verify is the single canonical surface — no separate `atlas register` ceremony.
- **domain audits** — land as `hexa verify --<axis> <domain>` subcommands (one CLI surface,
  no new top-level verbs).
- **stdlib trig = libm** — signal/math modules use native libm trig (`cos`/`sin`/…), never
  hand-rolled Taylor series (codegen-fragile).
- **external LLM** — invoke external LLMs only via `hexa loop --dfs` (budget cap + verify gate).
- **HF namespace** — all HuggingFace uploads/Collections live under the `dancinlab` org.
- **L0 edits** — editing a lockdown file (see `harness.config.json` → `lockdown.files`)
  requires updating `CHANGELOG.md` in the same change.

## Harness

This repo is governed by the vendored [dancinlab/harness](https://github.com/dancinlab/harness)
engine, pinned as the `.harness-engine` git submodule and wired through `.claude/settings.json`
hooks (guarded: each hook is a no-op when the submodule binary is absent). Config lives in
`harness.config.json` (profile `hardcore`, stack `hexa`). The harness enforces single-document
discipline (architecture SSOT + append-only log + quickref pointers), L0 lockdown reminders,
the changelog gate for `.hexa` changes, and protected branches (`main`, `master`).

Run the engine:

```sh
git submodule update --init --recursive          # activate (hooks no-op until present)
.harness-engine/bin/harness <cmd>                 # via wrapper
```

### Quick reference

| Command | Purpose |
|---------|---------|
| `harness docs check` | single-doc discipline: architecture SSOT + log + quickref pointers |
| `harness lint` | staged-L0 + freshness + convergence gate |
| `harness verify` | run configured verification (`hexa verify`) |
| `harness audit` | 6-axis self-scorecard |
| `harness gc` | broken markdown links in guides |
| `hexa verify` | g5 gate: S6 equational + S8 citation + atlas reverify/auto-fold |
| `hx commit` / `hx push` | SSOT-attested git wrappers (re-run lint gate) |
