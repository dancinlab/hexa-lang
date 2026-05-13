# hexa-lang/roadmaps/

Cross-repo aggregator roadmap JSONs. Consumed by `tool/roadmap_engine.hexa`
and Phase 1-3 scanners.

Status (2026-04-22): directory created as part of SSOT migration to
hexa-lang (see `docs/migration_nexus_to_hexalang_20260422.md`). The source
directory is now decommissioned; canonical aggregators live here. Actual
JSON artifacts are still being populated — deferred to a follow-up session
where per-repo references can be validated first.

Expected contents (post-migration):
- `anima.json`        — ANIMA main linker (ALM+CLM unified)
- `airgenome.json`    — airgenome aggregator
- `hexa-lang.json`    — hexa-lang self aggregator
- `SCHEMA.json`       — 3-track phase/gate schema
- `engine_schema.json`— DAG engine schema (TOC+A*, Bellman dynamics)
- `breakthroughs/`    — sub-roadmap STUBs

Per-repo `.roadmap` text files remain canonical SSOT in each repo
(uchg-locked). The JSONs in this directory are derived aggregators.
