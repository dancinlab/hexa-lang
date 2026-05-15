# hexa-matter → hexa-lang absorption plan (research only)

**Date:** 2026-05-14
**Source repo:** `~/core/hexa-matter/` (n=6 materials substrate, MIT, ~205 MB)
**Target repo:** `~/core/hexa-lang/`
**Status:** RESEARCH — no code modified. No commit. Implementation gated on user approval.
**Reference template:** `incoming/notes/2026-05-13-n6-absorption-plan.md` (n6 absorption precedent)

---

## 0. Identity

`hexa-matter` is the **materials member** of the HEXA family — a 36-verb
materials-science toolkit ("Phase D'' 2026-05-13, 36/36 verbs ship-grade")
organised around the **n=6 invariant lattice as auxiliary** (not as a
constraint, per its own `LATTICE_POLICY.md`). The 7-group taxonomy is
CER / POL / FIB / MET / GEM / PRC / FAS (bond character + processing
axis), each verb shipping as a peer-citable markdown spec.

Important upstream property: hexa-matter has **already absorbed the
n=6 doctrine** that hexa-lang's `LATTICE_POLICY` enforces — every spec
is real-limits-first (NIST WebBook / CRC Handbook 105th ed. / ASM /
Ashby), and the repo carries an active `LIMIT_BREAKTHROUGH.md` (L1..L12
universal limits + Si-L1..Si-L12 silicon-specific) with HARD_WALL /
SOFT_WALL / BREAKABLE_WITH_TECH / UNCLEAR classification per limit.

License: MIT. Provenance: most v1.0.0 specs imported from
`canon/domains/materials/ @ 47c70cbf` (2026-05-09); Phase D / D' / D''
specs authored in-repo.

Relationship to hexa-lang atlas:
- hexa-matter is **NOT an atlas source** — it neither emits `.n6` shards
  nor adds nodes to `atlas.n6`. Its `papers/n6-*.md` (4 papers, 7 atlas
  refs each) merely reference existing atlas nodes (`Linked atlas node:
  chemistry 34/38 EXACT [10*]`, `polymer-engineering 19/24 EXACT [10*]`,
  etc.) — they consume, not produce.
- hexa-matter's `selftest/n6_axis_computational_verification.py` validates
  the n=6 arithmetic identities (σ·φ = n·τ = 24) but as **lattice
  tautology**, not as atlas-corpus contribution.
- Therefore the absorption surface is **horizontal** (sister-substrate
  parity: bridges, audits, real-limits doctrine) rather than **vertical**
  (atlas corpus extension).

---

## 1. Inventory

Top-level survey (`ls ~/core/hexa-matter/` = 126 entries):

| Bucket | Count | Notes |
|---|---:|---|
| Verb spec subdirs | 36 | one per dispatchable verb (ceramics/ silicon/ aramid/ … electrode-material/) |
| Root UPPERCASE infra docs | ~30 | AGENTS · AXIS · AXIS_CLOSURE_PLAN · CLOSURE_RESIDUAL_BACKLOG · DECOMPOSITION_PLAN · LATTICE_POLICY · LIMIT_BREAKTHROUGH · LESSONS · NOVEL · CROSS_LINK · INIT · RELEASE_NOTES_v1.{0,1,2}.0 · V1_2_0_HANDOFF · USER_ACTION_REQUIRED · IMPORTED_FROM_CANON · PHASE_{H,J,K}_PLAN · TAPE-AUDIT · NOVEL_ROADMAP · MATERIAL-SYNTHESIS · SILICON · CERAMIC-ENGINEERING · METALLURGY-DEEP · POLYMER-CHEMISTRY · GRAPHENE-CARBON · plus 16 Phase D root stubs |
| Bridges | 3 | `_python_bridge/` (12 modules, 1.5K LOC) · `_research_bridge/` (8 modules, arxiv+web) · `_absorption_bridge/` (16 adapters, 3.3K LOC) |
| Selftest harness | 38 gates | `selftest/run_all.sh` aggregator + 27 audit modules (.py + .sh) |
| Parity tests | 29 | `tests/<group>_b<N>_<topic>_parity.py` (CER/POL/MET/FIB/GEM/PRC/FAS) + JSON snapshots |
| Verify (n6-style structural) | 5 | `verify/{spec_presence,closure_consistency,lattice_arithmetic,real_limits_anchor,run_all}.hexa` |
| CLI dispatcher | 1 | `cli/hexa-matter.hexa` (spec-first verb router) |
| Origins (canon-imported hexa programs) | 2 | `origins/material-dse/main.hexa` (560 LOC, N6 material-DSE Cartesian sweep) · `origins/carbon-capture-calc/main.hexa` (559 LOC) |
| N6 seed papers | 4 | `papers/n6-{chemistry,polymer-engineering,textile-engineering,carbon-capture}-paper.md` — canonical v2, ~atlas-consumer |
| Breakthroughs ledger | 1 | `breakthroughs/bt-1388-ionic-octahedral-2026-04-12.md` |

File-type LOC totals (excluding `.git/` and `.claude/worktrees/`):

| Extension | Files | LOC |
|---|---:|---:|
| `*.md` | 166 | 119,655 |
| `*.py` | 104 | 12,022 |
| `*.json` | 60 | (mostly snapshot + cache fixtures) |
| `*.hexa` | 10 | 2,052 |

Total disk: 205 MB (dominated by canon-extracted markdown + bridge fixtures).

---

## 2. Atlas-relevance analysis

The audit-question for hexa-lang is: **which hexa-matter artifacts
extend the atlas substrate (6594 nodes + overlay, 9 SSOTs, 38+
algorithms, Doctrine v2 5 rules)?**

Three answers, in decreasing relevance:

### 2.1 Doctrine + audit parity (HIGH relevance)

hexa-matter operates the same `LATTICE_POLICY` regime hexa-lang ships:
> "The project's ceiling is set by REAL math/physics/engineering limits,
> never by the n=6 invariant lattice"

The matter-side enforces this via:
- `LATTICE_POLICY.md` (mirror of the universal policy) +
- `LIMIT_BREAKTHROUGH.md` (Wave M real-limits audit, 12 universal + 12
  silicon-specific limits with HARD/SOFT/BREAKABLE classification) +
- `selftest/lattice_fit_on_external_entities_audit.py` (honest-caveat C3 honesty
  guard — fails if any post-policy spec applies n=6 lattice formulas to
  vendor / NIST / ITER / ASTM data) +
- `selftest/nist_anchor_audit.py` (verifies citations resolve to
  NIST WebBook / CRC Handbook / ASM / Ashby anchors).

hexa-lang already has Doctrine v2 5 rules; what it does **not** yet have
is a NIST-anchor / external-entity honesty audit running over the
**atlas corpus** itself. The matter `lattice_fit_on_external_entities`
+ `nist_anchor` audits are direct templates for a parallel
`compiler/atlas/honesty_audit.hexa` that walks `embedded.gen.hexa` and
fails on lattice-tautology assertions about external entities. **This
is the highest-value horizontal absorption surface.**

### 2.2 Real-limits ledger (HIGH relevance — doc/data only)

`LIMIT_BREAKTHROUGH.md` is a peer-citable list of **24 anchored real
limits** (Frenkel σ_th = E/10 · Mohs ceiling = diamond · Os ρ =
22.59 g/cm³ · diamond k = 2200 W/m·K · Hales packing 0.7405 · Gibbs
entropy of mixing · etc.) with HARD/SOFT classification + provenance.

This is the kind of artifact `doc/atlas/` is the natural home for. It
fits the same shape as `doc/atlas/omega_closure.md` (mirrored from n6
on 2026-05-13 per the n6 absorption plan §6). A verbatim mirror
preserves the cross-link from hexa-lang's `LATTICE_POLICY` ladder to a
**materials-side real-limits ground truth**, useful when atlas nodes
about materials topics are graded.

### 2.3 Absorption-bridge sister pattern (MEDIUM relevance — architecture)

`_absorption_bridge/` ships **16 adapters** (Materials Project · GNoME ·
Matlantis · OMat24 · COD · OQMD · AFLOW · NOMAD · NIMS MatNavi ·
Catalysis-Hub · 5 universal force fields) with a single discipline:
- `--selftest` is **offline-replay only** (bundled fixtures, exit 0);
- live API calls gated behind `--live`;
- honest-caveat C3 enforced — no n=6 lattice-fit on absorbed external data;
- License honesty matrix per `SOURCES.md` per adapter;
- "PREDICTED, NOT SYNTHESIZED" preserved on GNoME/OMat24/Matlantis.

hexa-lang has nothing equivalent today: no `compiler/bridges/external/`
or `tool/atlas_bridge_*` analog. **If** atlas ever needs to absorb live
external corpora (Wikidata, DBpedia, OpenAlex, ORCID, OEIS, …), this
bridge pattern is the proven template. Recommend **mirroring the
bridge-rules contract** (4 rules from `AGENTS.md` §"Bridge rules") as
`doc/atlas/bridge_rules.md`, even if no bridges are built immediately.

### 2.4 Everything else (LOW / SKIP)

- The 36 verb specs (`silicon/silicon.md`, `aramid/aramid.md`, …) are
  **domain content**, not atlas infrastructure. They belong in
  `hexa-matter`, not hexa-lang. Skip.
- The 4 `papers/n6-*-paper.md` are atlas-**consumers** (they reference
  existing nodes); they do not contribute new atlas nodes. Skip — they
  remain canonical in `hexa-matter`.
- `origins/material-dse/main.hexa` (560 LOC) is a Cartesian-sweep DSE
  program. Interesting as a hexa-lang program example but not atlas
  infrastructure. Skip-or-archive.
- The 29 `tests/<group>_b<N>_*_parity.py` parity tests + snapshots are
  property-level matter-side gates; not atlas-side. Skip.
- `_python_bridge/` (12 modules: RDKit / ASE / pymatgen / silicon-purity /
  polymer-MW / metallurgy-alloy / carbon-form / nist-anchor-resolver /
  …) is **scientific compute**, not atlas. Skip unless hexa-lang ever
  ships a chemistry-compute surface (it doesn't today).
- `_research_bridge/` (arxiv + vendor + RSS + USPTO/EPO) is **literature
  ingestion**, again not atlas-corpus material today.

---

## 3. Candidates by Doctrine v2 rule

Doctrine v2's 5 rules (as I understand them from the atlas absorption
precedent + the user's framing):
1. **Real-limits-first** — no fit-to-convenient-number.
2. **No lattice-fit on external entities** (honest-caveat C3).
3. **Predictions ≠ measurements** — preserve provenance.
4. **Offline / deterministic verification** in CI.
5. **License + citation honesty** per absorbed artifact.

| Candidate | Source path | Rule(s) addressed | Disposition |
|---|---|---|---|
| `lattice_fit_on_external_entities_audit.py` port → `compiler/atlas/external_entity_audit.hexa` | `selftest/lattice_fit_on_external_entities_audit.py` | 2 | **adopt** (Wave 1) |
| `nist_anchor_audit.py` port → `compiler/atlas/anchor_audit.hexa` | `selftest/nist_anchor_audit.py` | 1, 5 | **adopt** (Wave 1) |
| `LIMIT_BREAKTHROUGH.md` mirror → `doc/atlas/materials_real_limits.md` | repo root | 1 | **mirror verbatim** (Wave 2) |
| `AGENTS.md §Bridge rules` mirror → `doc/atlas/bridge_rules.md` | `AGENTS.md` §"Bridge rules (agents — observe ALL)" | 3, 4, 5 | **mirror** (Wave 2) |
| `LATTICE_POLICY.md` (matter-side) cross-link in hexa-lang's own `LATTICE_POLICY` | `LATTICE_POLICY.md` | 1, 2 | **doc cross-link** (Wave 2) |
| `hardwall_provenance_audit.py` pattern → `compiler/atlas/hardwall_audit.hexa` | `selftest/hardwall_provenance_audit.py` | 1, 5 | **study** (Wave 3) |
| `falsifier_wellformed_audit.py` pattern → atlas falsifier well-formedness audit | `selftest/falsifier_wellformed_audit.py` | 4 | **study** (Wave 3) |
| `cross_link_integrity_audit.py` pattern → atlas overlay↔rodata cross-link audit | `selftest/cross_link_integrity_audit.py` | 4 | **study** (Wave 3) |
| `_absorption_bridge/` 4-rule contract reified | `AGENTS.md` §Bridge rules | 3, 4, 5 | **mirror as policy** (Wave 2) |
| `vendor_citation_completeness_audit.py` pattern | `selftest/vendor_citation_completeness_audit.py` | 5 | **defer** — no vendor citations in atlas today |
| 36 verb spec docs | `<verb>/<verb>.md` | n/a | **skip** — domain content, stays in hexa-matter |
| `papers/n6-*-paper.md` | `papers/` | n/a | **skip** — atlas-consumer, not contributor |
| `origins/material-dse/main.hexa` | `origins/material-dse/` | n/a | **skip** — DSE example, not infra |
| `_python_bridge/` 12 modules | `_python_bridge/module/` | n/a | **skip** — chemistry compute |
| `_research_bridge/` 8 modules | `_research_bridge/` | n/a | **skip** — literature ingest |
| `_absorption_bridge/` 16 adapters | `_absorption_bridge/` | n/a | **skip-as-content** (mirror only the *contract*, not the adapters) |
| `tests/<group>_b<N>_*_parity.py` | `tests/` | n/a | **skip** — matter-side property gates |

---

## 4. Top-3 high-priority candidates

### 4.1 — `lattice_fit_on_external_entities_audit` port → `compiler/atlas/external_entity_audit.hexa`

- **Source:** `~/core/hexa-matter/selftest/lattice_fit_on_external_entities_audit.py` (~200–300 LOC, exact count TBD on read-pass).
- **What it does (matter-side):** walks every spec doc, fails if it
  finds `σ(6)` / `τ(6)` / `J₂` arithmetic applied to vendor (Wacker /
  Wolfspeed / Shin-Etsu / …) or canonical reference (NIST / ITER /
  ASTM) data tables — honest-caveat C3 enforcement.
- **Target (hexa-lang):** walks `embedded.gen.hexa` + overlay nodes;
  fails if any node baseline contains lattice-arithmetic applied to a
  marker-tagged external entity (`@vendor:` · `@nist:` · `@external:`).
- **Wire to:** `selftest/atlas_doctrine_smoke.sh` (new gate) and
  `hexa atlas audit --doctrine` CLI surface.
- **Estimated LOC:** ~150 source + ~80 test.
- **Why top-priority:** Doctrine v2 rule 2 is currently a *policy*
  (`LATTICE_POLICY`) without a corpus-level *gate*. This closes that gap.

### 4.2 — `LIMIT_BREAKTHROUGH.md` mirror → `doc/atlas/materials_real_limits.md`

- **Source:** `~/core/hexa-matter/LIMIT_BREAKTHROUGH.md` (verbatim mirror;
  hexa-matter file is the canonical owner).
- **Why high-priority:** Doctrine v2 rule 1 ("real-limits-first") needs
  a **citable ground truth** for materials-domain atlas nodes. Without
  this mirror, atlas nodes about Mohs hardness, melting points,
  packing fractions, fracture toughness, etc. have no in-repo anchor.
- **Pattern:** identical to `doc/atlas/omega_closure.md` (mirrored from
  n6 2026-05-13). Add header preface noting absorption date, source,
  and "upstream canonical owner — see `hexa-matter/LIMIT_BREAKTHROUGH.md`".
- **Estimated LOC:** ~600 LOC verbatim + ~10 LOC preface. Zero code change.
- **Optional second mirror:** `LATTICE_POLICY.md` matter-side variant
  (~250 LOC), if cross-link friction warrants — hexa-lang's own
  `LATTICE_POLICY` already exists, so this would be an "as seen from
  the materials substrate" companion rather than authoritative.

### 4.3 — Bridge-rules contract → `doc/atlas/bridge_rules.md`

- **Source:** `~/core/hexa-matter/AGENTS.md` §"Bridge rules (agents —
  observe ALL)" — the 5-bullet contract:
  1. stdlib fallback or clean SKIP;
  2. OFFLINE selftest only (no live API in `--selftest`);
  3. License honesty (every adapter `SOURCES.md` cites license, paper, version);
  4. Predictions ≠ measurements (preserve UNVERIFIED markers);
  5. No n=6 lattice-fit on absorbed data.
- **Why high-priority:** these rules **anticipate** the design of any
  future hexa-lang external-corpus bridges (Wikidata, OEIS, ORCID,
  OpenAlex, …). Writing the contract *before* the first bridge is the
  cheap-now-save-later move; the matter version is battle-tested
  across 16 adapters.
- **Estimated LOC:** ~80 LOC `doc/atlas/bridge_rules.md` (rules verbatim
  + 3-paragraph preface tying to Doctrine v2 rules 3+4+5).
- **No code change.** Activates when the first atlas bridge ships.

**Top-3 total estimated LOC:** ~150 + ~80 + 0 + 0 = ~230 source LOC + ~80
test LOC + ~700 LOC mirrored markdown (no code change).

---

## 5. Waves

### Wave 1 — Doctrine audit gates (compiler/atlas/)

Adopt Top-3 §4.1 (`external_entity_audit.hexa`) + companion
`anchor_audit.hexa` (NIST/CRC/ASM anchor presence in atlas nodes that
cite external limits).

- Files: `compiler/atlas/external_entity_audit.hexa` (~150 LOC),
  `compiler/atlas/anchor_audit.hexa` (~120 LOC), tests (~150 LOC).
- Wire: `selftest/atlas_doctrine_smoke.sh` (new gate, parallel to
  `embed_smoke`); CLI `hexa atlas audit --doctrine`.
- **Dependencies:** none (operates over existing `embedded.gen.hexa` +
  overlay).
- **Risk:** false positives on legitimate native-lattice nodes (the n=6
  papers themselves). Mitigation: only fail on nodes marked
  `@external:` / `@vendor:` / `@nist:`; pure-internal lattice arithmetic
  is permitted (`LATTICE_POLICY §1.3` aux-only rule).

### Wave 2 — Doctrine reference mirrors (doc/atlas/)

Adopt Top-3 §4.2 (`materials_real_limits.md` mirror) + §4.3
(`bridge_rules.md`).

- Files: `doc/atlas/materials_real_limits.md` (~610 LOC mirrored),
  `doc/atlas/bridge_rules.md` (~80 LOC mirrored).
- Optional: `doc/atlas/lattice_policy_matter_companion.md` (~260 LOC
  mirrored) — only if Wave 1 audit messages reference it.
- **Dependencies:** none.
- **Risk:** drift between hexa-matter canonical and hexa-lang mirror.
  Mitigation: header preface explicitly names upstream owner; consider
  a `tool/check_doc_mirror_drift.hexa` (~50 LOC, hash-compare).

### Wave 3 — Audit-pattern studies (deferred / opt-in)

Study (not necessarily adopt) the patterns from §3's "study" disposition:
- `hardwall_provenance_audit.py` — does every HARD_WALL claim carry a
  provenance citation? hexa-lang analog: does every `[10*]` ceiling
  claim in atlas carry a `!!` breakthrough or `|>` script reference?
- `falsifier_wellformed_audit.py` — falsifier syntax / deadline / type
  well-formedness. hexa-lang analog: `@?` open-hypothesis nodes carry a
  falsifier field (post Wave-1 of the 2026-05-13 n6 plan).
- `cross_link_integrity_audit.py` — boundary discipline + NOVEL
  invariants. hexa-lang analog: overlay↔rodata cross-link integrity at
  startup.

LOC + landing path TBD pending Wave 1 read-pass.

### Wave 4 — Bridge contract activation (gated)

Only if/when hexa-lang ships its first external-corpus atlas bridge.
The Wave 2 `bridge_rules.md` mirror is the gate-keeper at that point.

---

## 6. Skip list (with reason)

| Item | Reason |
|---|---|
| 36 verb spec docs (`<verb>/<verb>.md`) | Domain content. Canonical in hexa-matter. |
| 4 `papers/n6-*-paper.md` | Atlas-consumers (reference existing nodes), not contributors. |
| `origins/material-dse/main.hexa` (560 LOC) | DSE Cartesian-sweep example; not atlas infra. |
| `origins/carbon-capture-calc/main.hexa` (559 LOC) | Same; calculator example. |
| `_python_bridge/` 12 modules (~1.5K LOC) | Chemistry / metallurgy compute (RDKit/ASE/pymatgen wrappers); not atlas. |
| `_research_bridge/` 8 modules | arxiv + vendor + RSS literature ingest. |
| `_absorption_bridge/` 16 adapter implementations | External-DB adapters (MP/GNoME/OMat24/COD/OQMD/AFLOW/NOMAD/NIMS/CatHub/Matlantis/5×UFF). Mirror the **contract** (Wave 2), skip the adapters. |
| `tests/<group>_b<N>_*_parity.py` × 29 | Matter-side property-parity gates with NIST/CRC. |
| `verify/lattice_arithmetic.hexa` | σ·φ=24 tautology — `LATTICE_POLICY §1.3` aux-only; hexa-lang already has equivalents. |
| `verify/spec_presence.hexa` | Spec-doc presence check; matter-specific scoreboard. |
| 16 root UPPERCASE Phase D stubs (ELASTOMER.md / COMPOUND-SEMI.md / …) | Roadmap stubs that delegate to per-verb specs. Domain content. |
| Deep-expansion chapters (SILICON.md / CERAMIC-ENGINEERING.md / …) | Domain chapters; canonical in hexa-matter. |
| `breakthroughs/bt-1388-ionic-octahedral-2026-04-12.md` | Matter-side breakthrough ledger entry; not atlas. |
| `state/markers/` | Working-state ledger; ephemeral. |
| `NOVEL.md` + `NOVEL_ROADMAP.md` | hxm-* novel-material candidate ledger; matter-side. |
| `.claude/worktrees/` | Agent scratch space; never absorbed. |

---

## 7. Scope & coordination notes

**License:** MIT — attribution preserved via header preface on mirrored
files. Recommended one-line header on absorbed `.hexa` files:
`// absorbed from ~/core/hexa-matter/<path> (MIT, hexa-matter v1.2.0)`.

**Sister-repo discipline:** hexa-matter is itself a HEXA-family member
with its own AGENTS.md, INIT.md, CLOSURE_STATUS.md. The absorption
strategy here is **horizontal sister-parity** (lift the doctrine
gates + reference docs), not **vertical content extraction** (don't
pull the verb specs into hexa-lang — they belong in hexa-matter).

**No atlas corpus extension:** unlike the 2026-05-13 n6 absorption
(which extended `embedded.gen.hexa` rodata), this hexa-matter absorption
adds **zero atlas nodes**. The deliverables are audit code + reference
docs. The atlas count (6594 nodes + overlay) is unchanged by this plan.

**No overlap with prior absorptions:**
- nexus → `compiler/falsifiers/` · `compiler/hexad/` · `compiler/honesty/`
  · `compiler/lens_taxonomy/` — these are doctrine modules, not
  external-entity audits. Wave 1 lands a *new* audit class.
- n6 → `compiler/atlas/embedded.gen.hexa` rodata + parser. Different
  surface (rodata content vs doctrine gates).
- hexa-matter mirror to `doc/atlas/` is the same shape as the n6
  `omega_closure.md` mirror — already-established pattern.

**Estimated total cost (Waves 1+2 only):**
- ~270 source LOC (Wave 1 audits)
- ~230 test LOC (Wave 1 tests)
- ~690 LOC mirrored markdown (Wave 2 doc mirrors)
- Zero atlas regen (no rodata change)
- Zero existing-file modification on hexa-matter side (read-only audit
  honored)

**Out-of-scope by design:**
- hexa-matter `_absorption_bridge/` adapter implementations (only the
  contract mirrors)
- hexa-matter `_python_bridge/` chemistry compute (RDKit / ASE / pymatgen)
- hexa-matter 36-verb specs (stay in hexa-matter as canonical owner)
- Any modification to hexa-matter repo (read-only audit constraint)
- Any commit (research-only constraint)

---

## 8. Bottom line

`hexa-matter` is a sister-substrate, not an atlas-corpus source. Its
high-value contributions to hexa-lang are **doctrine-level**:

1. The `lattice_fit_on_external_entities_audit` pattern — closes the
   gap between hexa-lang's `LATTICE_POLICY` (policy) and atlas-corpus
   enforcement (gate).
2. The `LIMIT_BREAKTHROUGH.md` real-limits reference — gives
   materials-domain atlas nodes a citable in-repo anchor (Doctrine v2
   rule 1).
3. The 5-rule bridge contract — front-runs the design discipline for
   any future hexa-lang external-corpus bridges (Doctrine v2 rules
   3+4+5).

Skip: all 36 verb specs, all bridge adapter implementations, all
matter-side property tests, all chemistry/research compute modules.

**Total absorption surface (Waves 1+2, recommended scope): ~270 source
LOC + ~230 test LOC + ~690 LOC mirrored docs. No commit. No
hexa-matter modification. No atlas regen.**
