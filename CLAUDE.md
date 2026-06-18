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
The full architecture SSOT is [ARCHITECTURE.json](ARCHITECTURE.json) (JSON 트리 — 사람은 `architecture.html` 뷰어로 봄, `python3 serve.py`); this file is the single governance SSOT (md 단일화 — `project.tape`·`ARCHITECTURE.md` retired). **Domains** are folded into ARCHITECTURE.json → `domains` section (final-form registry: `@goal` + status + remaining); the per-domain `*.md` snapshots, `*.log.md`/`*.tape` step-logs, and `DOMAINS.tape` roster are **retired** (2026-06-17) — ARCHITECTURE.json is now the sole domain record, milestone history lives in CHANGELOG.md + git.

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
├─ ATLAS/           — `README.md` 단일 원장 = 수학 지도 (발견 엔진 · 거시↔양자) · 구 TECS-L/·atlas/(소문자) retired
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
- **ATLAS math-map** — 발견 엔진(수론·물리·우주·생명)의 사람용 원장은 `ATLAS/README.md`
  **단일 SSOT** (n=6 축0 출발 · 거시↔양자 수학 지도 · 구 `TECS-L/` 에서 개명 2026-06-18).
  지도는 README.md 에 **점진적으로 그려나간다** (one-shot 아님 · 검증된 노드/다리를 계속
  채움). 검증 atom 의 기계 SSOT 는 `compiler/atlas/embedded.gen.hexa`, history 는 CHANGELOG +
  git. **수학 DFS 는 `hexa loop --dfs` 로 진행** (external-LLM 단일 surface · 예산캡 + verify
  게이트 · ad-hoc 스크립트 금지), 결과는 `ATLAS/README.md` 연대기 + `ATLAS/CLAUDE.md` 에 기록.
  **retired**: 구 `atlas/`(소문자) 폴더 · `TECS-L/` 명칭 · TECS-L 다문서(`TECS-L.md`·
  `TECS-L.log.md`·`n6.md`·`docs/`·`millennium/`·`.verdicts/`) · `.tape` 원장(CLAIMS 등).
  **n=6 은 지도 중심이 아니라 노드 1개** (lattice-as-tool · 외부 영역 anchor 금지) ·
  미판독·미검증·lattice-fit·미증명 conjecture 는 🔵 승격 금지(c2).
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
- **release → pool 동기화** — 신규 릴리스(`vX.Y.Z` 태그 발행) 직후 pool 공유 호스트
  (`aiden`·`summer`)에도 그 릴리스를 `install.sh` 로 세팅(동기화)한다 —
  `harness pool on <host> 'curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/<tag>/install.sh | sh'`.
  pool 의 빌드·byteeq·measure 가 stale 바이너리/시드를 물지 않도록(자기복제 측정 신뢰성·c2),
  릴리스마다 공유자원을 최신 prebuilt 로 맞춘다.
- **self-host ≠ release 회귀** — self-hosting 완성(byteeq `gen3≡gen4`·measure·RT-NATIVE·zero-C)
  작업은 **절대 실제 사용 릴리스를 망가뜨리지 않는 선에서** 진행한다. 출하 바이너리(`hexa`/`hexa.real`)·
  `hexa build`/`run`·stdlib·C-transpile fallback 등 **사용자 사용 경로를 깨는 변경은 금지** — 셀프호스트
  게이트(native arena·#else drop·substrate 바이트감소 등)를 위해 릴리스를 회귀시키지 않는다. **릴리스
  무결성 > self-host 진척**: 회귀 위험이 있으면 릴리스 그린을 먼저 보장한 뒤 진행하고(코드젠/런타임
  변경은 byteeq + 출하 smoke 통과 확인 후 머지), 위험하면 self-host 진척을 미룬다.
- **릴리스 채널 규율 (edge=실험 · stable=승격)** — self-host 진척(byteeq·measure·RT-NATIVE·zero-C·
  static-musl 등 실험적 변경)은 `main` push → **edge prerelease**(`HEXA_VERSION=edge` 로 설치)로 상시
  흘린다. 소비자 기본 경로(`install.sh` → 최신 stable `vX.Y.Z`)는 **3타깃(x86_64-linux·arm64-linux·
  darwin-arm64) 릴리스 잡 전부 GREEN + install.sh 소비자 스모크(`hexa --version` + hello/exit42 run)
  GREEN** 일 때만 새 stable 태그로 승격한다. **"x86 만 green" 은 승격 불가**(v0.241.0 arm64 asset 미발행
  회귀 교훈 — 한 타깃 그린이 전체 그린 아님). 즉 실험은 edge 에서 검증·soak, stable 은 전타깃 green
  승격 — 이것이 [self-host ≠ release 회귀]의 운영 방식이다(소비자=stale-but-stable, 실험=edge).

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
