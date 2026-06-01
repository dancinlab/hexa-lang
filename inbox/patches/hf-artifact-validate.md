# hf-artifact-validate — HF-artifact VALIDATION harness (pull → on-core RUN → verbatim verdict)

**Status:** landed (PR to hexa-lang). selftest 5/5 PASS · real dataset smoke 🟢 GREEN.
**Owner:** anima HF tooling lane (g5 metrology · a_claim_verify).
**Repo:** hexa-lang. **Branch:** `feat/hf-artifact-validate`. **File:** `stdlib/hf/validate.hexa`.

## What it is

Companion to `stdlib/hf/upload.hexa`. Institutionalizes the repeated session
lesson: a model/dataset is **VALIDATED only when pulled onto the core and RUN**.
README / manifest / download-count inspection is NOT validation (g5,
a_claim_verify). The harness pulls the artifact, runs the real on-core probe,
and derives the tier **only** from the verbatim run stdout — never from metadata.

## CLI

```
hexa run stdlib/hf/validate.hexa <hf_repo_id> --type {model|dataset} [--probe <name>] [--dry-run]
hexa run stdlib/hf/validate.hexa --selftest        # no network
hexa run stdlib/hf/validate.hexa --help
```

## DATASET path (fully implemented)

`hf download --repo-type dataset --local-dir <tmp>` → locate corpus payload
(`--probe` / `*.kosmos` / `*.txt` / `*.corpus` / largest file) → construct checks
(bytes, lines, non-ASCII proxy) → on-core RUN:
`CLM_PROD_CORPUS=<corpus> hexa run stdlib/flame/clm_prod.hexa` → parse the
VERBATIM `F-CLM-PROD-DESCENT` verdict + `epoch-1 / epoch-N mean CE` lines.

- 🟢 GREEN — descent=1 AND construct checks pass.
- 🔴 RED — descent=0 (failed to descend / malformed).
- 🟠 AMBER — could not pull / no corpus / no terminal verdict line.

Always stated: toy CPU rung (d=8, $0); **production-scale transfer DEFERRED**
(a_toy_scale_recheck). CPU-LOCAL only; NO GPU/chip fire (a_cpu_local_no_waiter).

## MODEL path (honest DEFERRED stub)

A `.clm` CPU loader + held-out CE-eval driver are NOT present in this CPU-local
harness (flame `.clm` loader is GPU/fire-track). Rather than fabricate a number
(g63), the model path emits an explicit `🟠 model-load DEFERRED (reason)` and
still persists a verdict + ledger row so the deferral is audited.

**Follow-up (hexa cloud):** implement a `.clm` CPU loader + a small held-out
CE-eval probe so the model path can RUN and tier from real stdout.

## Output

- verbatim run stdout → `.verdicts/hf-validate/<repo_slug>/<ts>.txt` (checked in as proof).
- one row per run → `state/hf_validate_ledger.jsonl` (gitignored runtime ledger):
  `{repo, type, tier, key_metric, verdict_path, ts}`.

## Conventions mirrored from upload.hexa

- 3-tier token resolution: `secret get huggingface.token` → `~/.cache/huggingface/token` → `HF_TOKEN`.
- ps-invisible token: private `HF_HOME/token` file (never `--token` argv, never inline `HF_TOKEN=<value>`).
- `hf` CLI shell-out (raw#9 STRICT, zero `.py`); `_sh_q` single-quote escaping; sha-free pull (download verifies).

## Proof (verbatim, this run)

selftest (no network): 5/5 — GREEN/RED/AMBER parse cases + construct-fail gate + fixture construct-check → `__HEXA_HF_VALIDATE__ PASS`.

real smoke — `dancinlab/clm-backbone-5lang-sample` (PUBLIC dataset):
```
corpus  = <tmp>/clm_backbone_5lang.corpus.kosmos
construct: bytes=1748 lines=29 ok=1
epoch-1 mean CE = 4.63456
epoch-12 mean CE = 1.5922
F-CLM-PROD-DESCENT = 1
tier = 🟢 GREEN  (toy-only; production transfer DEFERRED)
```

## Known caveat

The non-ASCII language-coverage check is a coarse `grep -P` band heuristic and
is **informational only** — it never gates the tier. On the smoke corpus it read
`nonascii=0` despite multilingual content; tier correctly came from the on-core
CE descent, not the heuristic. A precise per-script coverage counter is a future
refinement.

## Optional `/hf validate` alias

The `/hf` skill already wraps `stdlib/hf/upload.hexa`. A thin `validate` subverb
(`/hf validate <repo> --type ...` → `hexa run stdlib/hf/validate.hexa ...`) can be
added to the skill; not over-scoped into this PR (CLI is the SSOT).
