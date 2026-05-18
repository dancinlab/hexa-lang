# inbox/notes — INDEX

> 44 session notes (2026-05-11 .. 2026-05-14) capturing hexa-lang
> absorption work, wilson↔hexa-lang closure, atlas/n6 absorption phases,
> drill spine + variants, nexus full-purge, and inter-repo absorption
> plans. Plus one `.n6` artifact (engine harvest candidates).
>
> These are **historical session records**, not actionable patches.
> Index regenerated 2026-05-17 by inbox triage pass.
>
> The notes are append-only — they document what happened during each
> session, are NOT updated as state evolves, and exist as audit trail.
> Material that needs to persist as architecture lives elsewhere
> (CLAUDE.md, SPEC.md, AGENTS.tape, FLAME.tape, FORGE.tape, RFC drafts).

## By topic cluster

### atlas / n6 / data absorption (8 notes)

Multi-day push to fold the `n6` semantic atlas + atlas Phase 3
metadata into hexa-lang stdlib.

- `2026-05-12-atlas-absorption-phase3-and-interp-drift.md` — Phase 3 closure + interp drift blocker
- `2026-05-12-atlas-n6-absorption-session.md` — atlas.n6 absorption session log
- `2026-05-13-data-embed-wave1-session.md` — Data-embed Wave 1 absorption (D1-D9)
- `2026-05-13-metadata-archive-session.md` — Metadata archive absorption (D10-D14, Phase 1-ext)
- `2026-05-13-n6-absorption-plan.md` — n6 → hexa-lang absorption plan
- `2026-05-13-n6-absorption-execution-session.md` — execution session
- `2026-05-14-fu2-prefix-benchmark-session.md` — FU2 prefix benchmark
- `2026-05-14-wave24-prefix-index-impl-session.md` — Wave 2.4 prefix_index impl

### drill / chain / engines (6 notes)

Phase 2/3 drill spine + variants + chain integration.

- `2026-05-13-drill-accumulation-impl-session.md` — multi-round overlay accumulation
- `2026-05-13-phase2-generators-session.md` — generators (A5 / A6 / A8)
- `2026-05-13-phase2-verifiers-session.md` — verifier port (A3 / A4 / A7)
- `2026-05-13-phase3-drill-spine-session.md` — drill spine (A9 drill + A19 chain)
- `2026-05-13-phase3-foundation-session.md` — loader hardening + overlay surface
- `2026-05-13-phase3-variants-omega-session.md` — omega-axis variants (A10-A13)
- `2026-05-13-phase3-variants-special-session.md` — Port 7 variants & special engines (A14-A18, A20-A21)
- `2026-05-13-phase4-external-resources-session.md` — Phase 4 external-resource absorption

### nexus purge / hexa-annot (4 notes)

End of `nexus` as a separate project — full-purge + tool absorption.

- `2026-05-13-gate-commands-scrub.md` — gate/commands.json nexus reference scrub
- `2026-05-13-hexa-annot-absorption-session.md` — `bin/hexa-*` annotation-analyzer absorption (wave 1, AS-IS)
- `2026-05-13-hexa-annot-ast-upgrade-session.md` — `tool/hexa_annot/hexa-*` grep-MVP → AST upgrade
- `2026-05-13-nexus-command-inventory.md` — Nexus Command Surface Inventory
- `2026-05-13-nexus-full-purge-session.md` — nexus residue full-purge

### wilson ↔ hexa-lang (3 notes)

Closure of wilson's upstream-patch flow + codegen wall + final consolidation.

- `2026-05-11-wilson-build-codegen-wall.md` — `hexa build core/main.hexa` post-#12 wall
- `2026-05-11-wilson-hexa-lang-closure.md` — wilson ↔ hexa-lang closure
- `2026-05-13-wilson-codegen-fixes-session.md` — Wilson codegen fixes
- `2026-05-13-final-consolidation-session.md` — final consolidation

### inter-repo absorption plans (5 notes)

Research-only plans for absorbing sibling repos into hexa-lang
stdlib / tools.

- `2026-05-14-anima-absorption-plan.md` — anima → hexa-lang
- `2026-05-14-anima-engine-harvest-candidates.md` (+ `.n6`) — engine docstring harvest
- `2026-05-14-hexa-bio-absorption-plan.md` — hexa-bio → hexa-lang
- `2026-05-14-hexa-chip-absorption-plan.md` — hexa-chip → hexa-lang
- `2026-05-14-hexa-matter-absorption-plan.md` — hexa-matter → hexa-lang
- `2026-05-14-hexa-space-absorption-plan.md` — hexa-space → hexa-lang

### infra / tooling / policy (12 notes)

- `2026-05-11-bg-git-commit-serialization.md` — BG agents racing on git commit via ssh mac
- `2026-05-11-doc-spec-md-stale-marker.md` — doc/spec.md stale v0.1 marker
- `2026-05-11-linux-mount-git-diagnosis.md` — Linux Mount Git Diagnosis
- `2026-05-11-pretooluse-hook-policy.md` — PreToolUse hook rejection pattern (bedrock claude-bind)
- `2026-05-11-stage-2-smoke-restored.md` — tests/bootstrap/stage_2_smoke.hexa restored
- `2026-05-12-orpheus-loop-hexa-idioms.md` — orpheus loop empirical hexa-lang idioms
- `2026-05-13-bridge-cache-live-validation-session.md` — Bridge cache repopulation + live-HTTP validation (Phase 5 fu)
- `2026-05-13-bridge-cache-populate-session.md` — bridge cache populate
- `2026-05-13-fu1-memcap-fix-session.md` — FU1 interp memcap (768 → 2048 → 4096 MB) — see [[rfc_024]] + [[codegen-struct-fwddecl-vs-fn-arena]]
- `2026-05-13-fu3-cli-shims-part2-session.md` — FU3 CLI fn main() shims, part 2 (20 modules)
- `2026-05-13-mkx-transcendental-closure-port-session.md` — Mk.X transcendental_closure port
- `2026-05-13-phase5-small-wins-session.md` — Phase 5 small wins (ubu2 bootstrap + HX9000 template fix)
- `2026-05-14-static-index-lazy-load-design.md` — static_index lazy-load design (see also [[poc/static_index_lazy_v0.hexa]])

## Sunset

These notes are **historical** and not consumed by any tool. Once the
inbox itself sunsets (per `INBOX.md` §Sunset — at stage 3 fixpoint),
this notes directory can be moved to `docs/sessions/` or similar
archival location. Until then, leave in place — the date prefix makes
chronological scan trivial.
