# External-corpus bridge rules

> Source: `~/core/hexa-matter/AGENTS.md` §"Bridge rules (agents — observe ALL)"
> (MIT, hexa-matter v1.2.0). Mirrored 2026-05-14. Upstream is canonical
> owner — do not hand-edit, regenerate via `tool/mirror_doc.hexa` (TBD).
> Absorbed under Wave 2 of `incoming/notes/2026-05-14-hexa-matter-absorption-plan.md`.

---

## Preface — tying the 5-bullet contract to Doctrine v2

hexa-lang's atlas substrate is, today, internal: rodata
(`compiler/atlas/embedded.gen.hexa`, 6594 nodes) plus a per-user overlay
(`~/.hx/data/atlas.overlay.n6`). It has no live external-corpus
bridges (Wikidata / DBpedia / OpenAlex / ORCID / OEIS / arXiv …) and no
adapters to materials databases (Materials Project / GNoME / OMat24 /
COD / OQMD / AFLOW / NOMAD / NIMS …). That gives us a one-shot
opportunity: the **first** external bridge built into hexa-lang should
already obey the discipline that has been battle-tested across
hexa-matter's 16 absorption-bridge adapters. Writing the contract now,
before any bridge ships, is the cheap-now-save-later move.

The 5 rules below land directly under Doctrine v2 rules 3, 4 and 5:

- Rule 3 (*predictions ≠ measurements*) is satisfied by bullets (3) and
  (4) — license / paper / version honesty plus an explicit `PREDICTED`
  / `MEASURED` provenance tag preserved through every adapter step.
- Rule 4 (*offline, deterministic verification in CI*) is satisfied by
  bullet (2) — `--selftest` is fixture-replay only, no live API calls,
  exit 0 even when the upstream service is unreachable.
- Rule 5 (*license + citation honesty per absorbed artifact*) is
  satisfied jointly by bullets (1) and (3) — every adapter ships a
  `SOURCES.md` and either runs on stdlib or cleanly SKIPs.

Bullets (1) and (5) close the loop with hexa-lang's `LATTICE_POLICY`:
external data stays as the upstream lab / consortium published it; no
n=6 lattice-fit (raw#10 C3) is ever applied to absorbed values.

These rules are passive today — there are no bridges to enforce them
against. They become *active* the moment the first
`compiler/bridges/external/` adapter lands; at that point the audit
gates at `compiler/atlas/external_entity_audit.hexa` and
`compiler/atlas/anchor_audit.hexa` (also absorbed Wave 1) verify them
against the corpus.

---

## Bridge rules (agents — observe ALL)

1. **stdlib fallback** — every adapter MUST work on stock Python 3.9+
   via stdlib OR cleanly SKIP with `SKIP: <dep> not installed` (exit
   0). No mocked functionality disguised as real.

2. **OFFLINE selftest only** — `--selftest` mode MUST NOT make live API
   calls. Use bundled cache fixture for replay. Fixtures tagged
   `SAMPLE FIXTURE — not real data, for selftest replay only`.

3. **License honesty** — every adapter `SOURCES.md` MUST cite license,
   cite paper, cite version. Commercial / non-commercial restrictions
   flagged loudly (Matlantis commercial; AlphaFold-3 non-commercial).

4. **Predictions ≠ measurements** — GNoME / OMat24 / Matlantis / NNP
   outputs are PREDICTIONS. Every adapter must preserve this in its
   smoke output and `SOURCES.md`. The atlas anchor audit hard-fails on
   `[10*]` ceiling claims that were sourced from a predictor without
   an UNVERIFIED marker.

5. **No n=6 lattice-fit on absorbed data** (raw#10 C3) — external
   metrics stay as the vendor / lab / consortium published them. The
   external-entity audit (`compiler/atlas/external_entity_audit.hexa`)
   walks every atlas node and fails on lattice-arithmetic tokens
   (σ(6) / τ(6) / φ(6) / J₂ / σ·φ=24 / …) co-occurring with an external
   marker (`@vendor:` / `@nist:` / `@external:` / `@iter:` / `@astm:` /
   vendor name).

---

## Provenance

These 5 bullets are absorbed verbatim from hexa-matter's
`AGENTS.md`, where they have been enforced across 16 absorption-bridge
adapters (Materials Project / GNoME / Matlantis / OMat24 / COD / OQMD /
AFLOW / NOMAD / NIMS MatNavi / Catalysis-Hub / 5× universal force
fields). They are MIT-licensed and we mirror them with attribution
preserved.

Upstream canonical owner: `~/core/hexa-matter/AGENTS.md` §"Bridge rules
(agents — observe ALL)" (hexa-matter v1.2.0).
