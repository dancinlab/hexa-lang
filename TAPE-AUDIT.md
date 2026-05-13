# TAPE-AUDIT — hexa-lang

`.tape` (agent-execution trace grammar) adoption audit. Read-only; no code changes.

## A. Audit-class ledgers

Heaviest of the four siblings. Concrete inventory:

- **DESIGN-ledger (SSOT, not cargo):** `.raw-audit` (143-line hash-chained log; `ts | event | actor | reason | result | sha_before | sha_after | prev_line_sha`; raw#1 lock/unlock/bypass/verify history). Per-raw `.raw-audit/` pattern referenced from `incoming/patches/`. Already structurally close to `.tape` (typed events + provenance + append-only).
- **Class-T candidates:** `state/*.jsonl` (10: `aot_cache_gc`, `convergence`, `cross_repo_links`, `discovery_absorption`, `format_witness_*`, `hx_meta_telemetry`, …). Schema-repetitive append-only. `state/hxc/` already mirrors them as `.hxc`.
- **CARGO:** `state/markers/` carries **28,695** `*.marker` files (no reader, classic cargo). `.hook-statusline.jsonl` is 3.5 MB. Prune or re-encode as `.tape` `@T marker_emit` rows.
- **Queue:** `incoming/patches/` (37 files) + `INBOX.md` + `PATCHES.yaml` — Class-T candidate.

## B. Identity surface

Empty `AGENTS.md` (zero bytes) + symlinked `CLAUDE.md`. Identity carried implicitly via root domain files (`HEXA-NATIVE-ONLY.md`, `FLOW.md`, `LATTICE_POLICY.md`, `LIMIT_BREAKTHROUGH.md`, `PLAN.md`, `ROADMAP.md`, `SPEC.md`). A `hexa-lang/identity.tape` would carry compiler-self-id + atlas-pin-sha + active-RFC + raw-rule-lock state — a legitimate slot, but lower-priority than D.

## C. Domain.md files

10 root `*.md` files including 7 domain-shaped: `FLOW.md`, `HEXA-NATIVE-ONLY.md`, `LATTICE_POLICY.md`, `LIMIT_BREAKTHROUGH.md`, `PLAN.md`, `ROADMAP.md`, `SPEC.md`. Strong convention — sibling `<DOMAIN>.tape` files (`PLAN.tape`, `ROADMAP.tape`, `LATTICE_POLICY.tape`) would capture decision/transition events while leaving the `.md` head intact.

## D. Per-run / per-event history

The crown jewel. Active streams: raw-rule promotion events (the `.raw-audit/` chain), measurement pilots (`format_witness_*.jsonl`, `convergence.jsonl`, `hx_meta_telemetry.jsonl`), patch-promotion queue (`incoming/patches/`), atlas-callers (`state/atlas_n6_callers.tsv`), continuous scans (`state/hx_continuous_scan_*.json`). All Class-T. A unified `promotion.tape` + `pilots.tape` + `patches.tape` set would replace ad-hoc JSONL with typed/edged/graded events and dogfood the format the project itself co-developed.

## E. Promotion candidates

- **n6 atoms** — verified RFC outcomes (e.g. raw 92 / raw 137 / raw 157 cited in hxc spec) promote to `@F` / `@R` atoms; already happening informally.
- **hxc** — `state/hxc/*.jsonl.hxc` already proves self-application; `.tape` ledgers would be the next surface.
- **n12** — `state/hx_continuous_scan_*.json` is multi-axis (time × phase × metric) and could feed n12 cells.

## Verdict

**HEAVY** — strongest dogfood-tape opportunity of the four siblings. Concrete first wins: (1) re-encode `state/markers/` 28,695-file cargo as a single `markers.tape` event stream, (2) port `.raw-audit` hash-chain into `.tape` typed-event form with `@T` raw-rule-lock rows + `<-` chain edges, (3) sibling `<DOMAIN>.tape` for the 7 root domain files. This repo is where `.tape` earns its keep.
