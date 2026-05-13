# tool/hexa_annot — annotation analyzer scripts (wave 1, grep-MVP)

Wave 1 = 29 bash scripts ported AS-IS from `~/core/nexus/bin/hexa-*` (absorption per the 2026-05-13 nexus command inventory §5, "Layer L4b"). AST-based upgrade and dispatch wiring into `hexa <verb>` are deferred follow-ups.

## What this directory is

Each script is a standalone grep MVP that scans one or more `.hexa` files for `@<annotation>(...)` markers and emits JSON to stdout (schema `v0.1`, `source: "grep-mvp"`). Pure-read by default, no shared-state writes (the two scripts that *can* write — `hexa-rule --mode migrate --apply` and `hexa-gate-register --apply` — already enforce dry-run-or-explicit-apply at the script level).

Invocation pattern (all 29 scripts):

```
tool/hexa_annot/<name> <file.hexa> [<file2.hexa> ...]
tool/hexa_annot/<name> --dir <directory>
```

## Categories

Per the absorption inventory and grouped by purpose:

### 1. Lint / purity / hygiene (3)

| script | annotation kinds |
|---|---|
| `hexa-pure-check` | `@pure` body side-effect heuristic (`--strict` also bans `let mut`) |
| `hexa-memo-check` | `@memo(ttl=N)` cache key schema |
| `hexa-codegen-hints` | `@inline`, `@no_inline`, `@cold`, `@deprecated` |

### 2. Effects / capability / intent (3)

| script | annotation kinds |
|---|---|
| `hexa-effect-map` | `@effect`, `@capability`, `@ai`, `@prove`, `@refines` |
| `hexa-intent-map` | `@intent(description: ...)` |
| `hexa-struct-layout` | `@repr`, `@align`, `@pack` + struct fields |

### 3. Docs / catalog / surfaces (4)

| script | annotation kinds | default output |
|---|---|---|
| `hexa-doc` | `@doc(section=..., body=...)` + fn signature | markdown |
| `hexa-readme` | `@readme`, `@changelog`, `@api_doc`, `@example`, `@deprecated`, `@since`, `@author` | markdown (`--mode json` for JSON) |
| `hexa-catalog` | `@cli(sub=...)`, `@flag(...)`, `@doc(...)` | JSON |
| `hexa-schema` | `@schema(type=...)` + struct fields → JSON Schema | JSON |

### 4. ML / inference / training (5)

| script | annotation kinds |
|---|---|
| `hexa-distill` | `@distill`, `@prune`, `@lora`, `@adapter`, `@kd` |
| `hexa-infer` | `@infer`, `@quantize`, `@cache_kv`, `@speculate`, `@batch_continuous` |
| `hexa-learn` | `@learn`, `@curriculum`, `@moe`, `@chinchilla`, `@synthetic_data` |
| `hexa-eval-run` | `@eval`, `@cat_adaptive`, `@judge_calibrate`, `@contamination_check` |
| `hexa-self-aware` | `@compile_trace`, `@ast_visible`, `@codegen_mark`, `@optimizer_hint`, `@type_debug`, `@self_check` |

### 5. ML-safety / agency / cognition (4)

| script | annotation kinds |
|---|---|
| `hexa-safety` | `@interpret`, `@align`, `@adversarial_robust`, `@deploy_safe`, `@multimodal_safe`, `@model_welfare` (Anthropic Fellows 171 baseline) |
| `hexa-antivirus` | `@antivirus`, `@quarantine`, `@heal`, `@integrity`, `@sandbox`, `@cve`, `@rce_guard`, `@audit`, `@canary`, `@patch` |
| `hexa-freedom` | `@free_will`, `@autonomy`, `@agency`, `@choice`, `@spontaneity`, `@volition`, `@initiative`, `@self_determined`, `@degrees_of_freedom`, `@indeterminate` |
| `hexa-cognitive` | 25 kinds across vision / audio / memory / emotion / plan |

### 6. Consciousness / meta / phi (2)

| script | annotation kinds |
|---|---|
| `hexa-meta-map` | `@meta`, `@reflect`, `@introspect`, `@self_model`, `@theory_of_mind`, `@qualia` |
| `hexa-phi-map` | `@phi`, `@consciousness`, `@channel`, `@iit` |

### 7. Serving / multi-tenant (2)

| script | annotation kinds |
|---|---|
| `hexa-serve` | `@ctx_compress`, `@tool_cache`, `@session_migrate`, `@route_agent` |
| `hexa-tenant` | `@adapter`, `@hotswap`, `@tenant_isolate`, `@self_serve_portal` |

### 8. Classification / tags (2)

| script | annotation kinds |
|---|---|
| `hexa-n6-list` | `@n6(identity=..., domain=..., target=..., name=...)` |
| `hexa-test-list` | `@test`, `@bench` |

### 9. Governance-coupled (4)

These require a JSON rules file (default: `config/annot_rules.json` resolved relative to the script).

| script | annotation kinds | write behavior |
|---|---|---|
| `hexa-law-link` | `@law(ref="<rule_id>")` cross-ref against `--rules <path>` | read-only |
| `hexa-harness` | `@harness(phase=...)`, `@gate(rule_id=H-*,action=...)`, `@dod`, `@verify`, ... (10 kinds) | read-only |
| `hexa-rule` | `@rule(kind=name|alias|deprecate|scope|stack|schema|conflict|migrate|lint|audit|enforce)` | `--mode migrate [--apply]` rewrites alias markers (DRY-RUN by default) |
| `hexa-gate-register` | `@gate(rule="...")` | `--apply` warns + exits 1 (unsupported in MVP) |

## Defaults moved from nexus

The original nexus scripts hard-coded a few absolute paths. Wave 1 rewrote them as follows:

| script | original default | new default |
|---|---|---|
| `hexa-law-link` | `$NEXUS/shared/rules/anima.json` | `tool/hexa_annot/../../config/annot_rules.json`; legacy `$NEXUS/shared/rules/anima.json` kept as fallback only when `NEXUS` env is set |
| `hexa-rule` | `<self_bin>/../config/annot_rules.json` (relative to nexus `bin/`) | `<self_bin>/../../config/annot_rules.json` (relative to `tool/hexa_annot/`); same `NEXUS` env fallback |
| `hexa-intent-map` `--project <name>` | `$HOME/Dev/<name>` (anima / nexus only) | tries `$HOME/core/<name>` then `$HOME/Dev/<name>`; works for any project name |
| `hexa-phi-map` `--project <name>` | `$HOME/Dev/anima` only | same generic resolution as `hexa-intent-map` |

`hexa-doc` and `hexa-readme` both contain a `/Dev/` path-segment heuristic in their `infer_project()` helper — that's pure string-manipulation on the file path argument, not a filesystem lookup, so it was left alone.

## Smoke test

```
test/hexa_annot_smoke.sh
```

For each of the 29 scripts the smoke test:
1. Confirms `-h` / `--help` emits non-empty usage text (exit code is not asserted — original scripts use 0, 1, and 2 inconsistently).
2. Runs the script against `test/fixtures/annot_sample.hexa` (and `test/fixtures/annot_rules.json` for `hexa-law-link`), expects exit 0, and verifies stdout is either valid grep-mvp JSON (compact or pretty-printed) or markdown (for the two doc-emitter scripts).

Roll-up: `29/29 PASS`.

## Not in this wave

- AST-aware re-implementation. Current scripts are grep heuristics with known limits (line comments, multi-line `fn` signatures, escaped strings in annotation values).
- Wiring into `hexa <verb>` via `self/main.hexa`. Run scripts directly with their absolute path until dispatch is added.
- A `hexa-only` / `triad` style cross-script aggregator.
