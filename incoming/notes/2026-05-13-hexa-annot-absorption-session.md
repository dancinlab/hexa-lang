# 2026-05-13 — `bin/hexa-*` annotation-analyzer absorption (wave 1, AS-IS)

> Session note per the established BG-handoff pattern (mirrors `2026-05-12-atlas-n6-absorption-session.md`). Wave 1 = port AS-IS (bash + grep). AST upgrade and `hexa <verb>` dispatch wiring are deferred to a later sweep.

**Date:** 2026-05-13
**Driver doc:** `incoming/notes/2026-05-13-nexus-command-inventory.md` §5 (Layer L4b — `bin/hexa-*`).
**Goal:** absorb the 29 standalone hexa-* annotation extractor scripts from `~/core/nexus/bin/` into hexa-lang as the first wave of the L4b absorption track. Pure file copy + path-leak rewrite + smoke test. No dispatch wiring, no AST work, no commit.

## Headline

- **29/29 ported and runnable directly** via `tool/hexa_annot/hexa-<name>` (note: the brief said "28" but the actual nexus dir and the inventory table both enumerate 29 — see §A).
- **Smoke result:** `29/29 PASS` via `test/hexa_annot_smoke.sh`.
- **Total LOC added:** 8501 (29 ported scripts, byte-identical apart from §B path rewrites) + 653 (README + smoke test + 2 fixtures) = **9154**.
- **Status:** ready for AST upgrade + dispatch wiring. No state mutation, no `self/main.hexa` touch.

## A. "28 vs 29" count reconciliation

The BG brief said "28 hexa-* scripts" but both `ls ~/core/nexus/bin/hexa-*` and §5 of the inventory document enumerate **29** scripts. The discrepancy is a brief-side typo, not a missing script: every name listed in the brief's enumeration is accounted for, and the inventory table row count is 29. The smoke test asserts `EXPECTED=29`; the README and this note both use 29 as the canonical count.

## B. Destination + path-leak rewrites

Destination chosen: **`tool/hexa_annot/`** (precedent: existing `tool/*.hexa` tooling family — `triad_lint.hexa`, `hexa_only_lint.hexa`, `ai_native_*.hexa` etc. all live under `tool/`).

3 scripts had nexus-specific hard-coded paths that needed rewriting:

| script | original | new |
|---|---|---|
| `hexa-law-link` | `$NEXUS/shared/rules/anima.json` | `<self_bin>/../../config/annot_rules.json` resolved relative to `tool/hexa_annot/`; legacy `$NEXUS/shared/rules/anima.json` kept as fallback only when `NEXUS` env is set |
| `hexa-rule` | `<self_bin>/../config/annot_rules.json` (i.e. `nexus/config/`) | `<self_bin>/../../config/annot_rules.json` (i.e. `hexa-lang/config/`); same `NEXUS`-env legacy fallback for `$NEXUS/shared/config/annot_rules.json` and `$NEXUS/config/annot_rules.json` |
| `hexa-intent-map` `--project <name>` | hard-coded `case` arm for `anima` (`$HOME/Dev/anima`) and `nexus` (`$HOME/Dev/nexus`) only | generic resolution: try `$HOME/core/<name>` then `$HOME/Dev/<name>`. Works for any project name. |
| `hexa-phi-map` `--project <name>` | same `anima`-only hard-code as `hexa-intent-map`, plus a literal `/Users/ghost/Dev/anima` candidate | same generic resolution as `hexa-intent-map` |

`hexa-doc` and `hexa-readme` each contain a `/Dev/` segment match inside their `infer_project()` helper, but that's pure string-manipulation on the input path argument (used to derive a project label for the markdown title) — not a filesystem lookup. Left alone per the AS-IS directive.

One non-path edit: `hexa-harness` had a Korean comment header reading "nexus harness annotation 10종 통합 수집기" — rewrote to English "harness annotation 10-kind unified collector" per the `project_hexa_lang_english_only` memory. All other Korean comments in the script bodies (`# 입력:`, `# 출력:`, `# 인식 annotation:` etc.) were left intact — touching those is a separate i18n sweep, out of wave-1 scope.

No script needed full skipping: every one of the 29 has either zero external file deps or only the `annot_rules.json` dep (which is now `--rules`-overridable and ships a test fixture).

## C. Smoke test

```
test/hexa_annot_smoke.sh
test/fixtures/annot_sample.hexa
test/fixtures/annot_rules.json
```

The smoke test exercises every script in two passes:

1. `-h` / `--help`: must emit non-empty usage text (exit code is **not** asserted; the original scripts mix `exit 0` (`hexa-gate-register`), `exit 1` (most), and `exit 2` (`hexa-pure-check`, `hexa-doc`, etc.) — accepting any of them is the AS-IS contract).
2. Fixture run: must exit 0 and produce either (a) valid grep-MVP JSON (compact or pretty-printed — `hexa-struct-layout`, `hexa-schema`, `hexa-n6-list`, `hexa-gate-register` all use python-pretty `json.dump`), or (b) markdown for `hexa-doc` which defaults to markdown output. `hexa-readme` is invoked with `--mode json`, `hexa-law-link` with `--rules <fixture>`.

Roll-up: `29/29 PASS`.

The `bash 3.2` compat note: `/usr/bin/env bash` on macOS picks the system bash 3.2, so the smoke test uses case-statement helpers instead of associative arrays. (Brew bash 5 is available at `/opt/homebrew/bin/bash` but not the PATH default.)

## D. What's intentionally NOT in this wave

| follow-up | scope |
|---|---|
| AST-aware re-implementation | each script is a grep heuristic — known limits include multi-line `fn` signatures, line-comment ambiguity inside string literals, and escaped-quote handling in annotation values. Wave 2 should consume `compiler/parse/*` instead. |
| `hexa <verb>` dispatch wiring | `self/main.hexa` not touched (explicit BG hard constraint). Run scripts directly via their absolute path until a later "verb sweep" adds `hexa annot <kind>` routing. |
| Real `config/annot_rules.json` | wave 1 ships a 4-rule test fixture under `test/fixtures/` only. `hexa-law-link` and `hexa-rule` will print "rules file not found" and exit 1 unless `--rules <path>` is passed; not a regression vs nexus (which had the same default failure mode when `$NEXUS` was unset). |
| Korean comment i18n | `# 입력:` / `# 출력:` / `# 인식 annotation:` blocks survive in 25 of 29 scripts. Wave 1 only translated `hexa-harness`'s top-line comment because it mentioned "nexus" by name. |
| Cross-script aggregator | no `hexa-annot-all` umbrella exists yet. |

## E. Source provenance

All 29 scripts were last touched in nexus at commit **`f14d5a8d`** (2026-04-21, `chore(shared-decommission P3.2-nexus): 15 non-HOT subdirs → top-level`). Single source SHA; the absorbed copies are bit-identical apart from the §B path-rewrites and the one `hexa-harness` comment edit.

## F. Working tree at session close

```
?? tool/hexa_annot/                              (29 scripts + README.md, 8626 LOC)
?? test/hexa_annot_smoke.sh                       (193 LOC)
?? test/fixtures/annot_sample.hexa                (302 LOC fixture)
?? test/fixtures/annot_rules.json                 (33 LOC fixture)
?? incoming/notes/2026-05-13-hexa-annot-absorption-session.md   (this file)
```

No `self/main.hexa` change. No `compiler/atlas/*` change. No nexus-repo change. No commit (per BG directive).

## G. One-line readiness

`tool/hexa_annot/` is ready for the AST upgrade + dispatch wiring follow-up sweeps. Wave-1 smoke is green: `29/29 PASS`.
