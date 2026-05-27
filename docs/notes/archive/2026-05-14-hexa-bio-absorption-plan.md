# hexa-bio → hexa-lang absorption plan (research only)

**Date:** 2026-05-14
**Source repo:** `~/core/hexa-bio/` (792 MB, Apache-2.0, registry L24)
**Target repo:** `~/core/hexa-lang/`
**Status:** RESEARCH — read-only audit. No source modification in either tree. Implementation gated on user approval.

## 0. TL;DR

- hexa-bio is the **5-axis Molecular Toolkit** (WEAVE / NANOBOT / RIBOZYME / VIROCAPSID / QUANTUM) organized around the n=6 invariant lattice (σ(6)=12, τ(6)=4, φ(6)=2, J₂=24). It is a **standalone CLI tool distributed via `hx install hexa-bio`** — it consumes hexa-lang's runtime, not the reverse.
- The repo is itself an **evolving absorption layer** (`_absorption_bridge/` for 9 protein-AI external systems, `_python_bridge/` for stdlib heavy lifting, `_qiskit_bridge/` for VQE adapters). It already contains "imported-from-canon" content. Risk of **double-port** for anything mirrored from `~/core/nexus/canon-infra/legacy-canon/`.
- hexa-lang's rodata atlas already mentions HEXA-WEAVE / hexa-bio / nanobot / ribozyme / virocapsid (158 substring hits in `embedded.gen.hexa`, mostly omega-cycle rationale rows on hexa-weave abstraction). The **doctrine, falsifiers, σ/τ/φ/J₂ identity rows are absent as structured first-class data.**
- High-value absorptions are doctrine-grade, not the bio simulators themselves:
  1. **LATTICE_POLICY.md + LIMIT_BREAKTHROUGH.md doctrine** — universal "real-limits-first verification" rule that the user already deployed dancinlab-wide (Wave K) and which hexa-lang would benefit from anchoring inline alongside its own Doctrine v2.
  2. **`selftest/n6_axis_computational_verification.py` (318 LOC)** — pure-stdlib deductive verifier of σ(6)=12 / τ(6)=4 / φ(6)=2 / J₂=24 across all 5 axes (42/42 checks). Direct match for hexa-lang's `compiler/falsifiers/` + `compiler/absolute_rules/` data-plus-checker pattern.
  3. **`quantum/module/n6_lattice_check.hexa` (152 LOC)** — pure-hexa cross-axis n=6 reference table + drift detector. Already in hexa-lang's idiom.
- Most of hexa-bio (the bio axes themselves, `_absorption_bridge/`, `_qiskit_bridge/`, the C2 disease matrix, the 162 `.roadmap.disease_*` files, the 64 `.tape` files) is **out-of-scope for hexa-lang** — it is the domain consumer of the toolkit, not toolkit infrastructure.
- License: Apache-2.0. Bring-with-attribution friendly.

## 1. Project identity

`hexa-bio` is a **standalone 5-axis Molecular Toolkit** (registry L24, GitHub `dancinlab/hexa-bio`) distributed as a `hx install`-able CLI package on top of hexa-lang. Its 4 bio axes (`weave` / `nanobot` / `ribozyme` / `virocapsid`) form the n=6 τ-quartet tetrahedron, with `quantum` as the 5th compute substrate axis bridging to `qmirror` and `xeno`. **`weave` is the only wired empirical sandbox (Caspar-Klug + Zlotnick ODE + Bayesian σ(6)=12 audit, posterior 0.97); the other three bio axes ship C0b skeleton simulators + falsifier preregisters.** Closure track is v1.x category-(a) "100% — 35/35 selftest PASS" (bookkeeping only; wet-lab / IND remain explicitly out-of-software-scope). The relationship to hexa-lang is **consumer-to-platform**: hexa-bio uses hexa-lang's runtime / `hx` package manager / RFC 034-039 quantum kernels — hexa-lang does **not** need the bio domain content. The *doctrine* hexa-bio crystallized (real-limits anchoring, n=6 axis computational verification, sister-repo CLI-direct integration rule) is what is portable upstream.

## 2. Inventory table

Top-level survey (size order, dir-flavor):

| Path | Type | Size/LOC | One-line purpose | Classification |
|---|---|---:|---|---|
| `README.md` | doc | 538 LOC | 5-axis status table + v1.x closure verdict + install/run + honest C3 caveats | C (project-specific) |
| `AGENTS.md` | doc | ~360 LOC | Sister-repo CLI-direct rules + LATTICE_POLICY anchor + raw-pattern policy | **B (rules portable)** |
| `CLAUDE.md` | doc | symlink to AGENTS.md head | identical-prefix | C |
| `LATTICE_POLICY.md` | policy | 242 LOC | Universal real-limits-first verification — dancinlab-wide policy declaration | **B (high-priority doctrine port)** |
| `LIMIT_BREAKTHROUGH.md` | policy | 208 LOC | Bio-domain real-limits audit (L1-L8: DNA fidelity / k_cat / ribosome / capsid ΔG / ATP / CRISPR off-target / drug cost / Levinthal) | C (domain instance — useful as template) |
| `hexa.toml` | manifest | ~150 LOC | `hx` package descriptor (registry L24) | C |
| `cli/hexa-bio.hexa` | code | ~300 LOC | 5-axis router + status + audit log | C |
| `install.hexa` | hook | ~60 LOC | hx pre/post install hooks | C |
| `weave/module/*.hexa` | code | 7 files / ~1.5K LOC | WEAVE axis: cage-assembly + composition + C2 candidates + lean4 emitter | C |
| `nanobot/module/*.hexa` | code | 16 files / ~3K LOC | NANOBOT axis + bayesian n=6 ablation/stratum modules | C (bayesian audit reusable as pattern only) |
| `ribozyme/module/*.hexa` | code | 15 files / ~2.5K LOC | RIBOZYME axis + sister-genus + Mg sweep + bayesian audit | C |
| `virocapsid/module/*.hexa` | code | 14 files / ~3K LOC | VIROCAPSID axis + Zlotnick ODE + multi-T + PDB corpus + kinetic-trap | C |
| `quantum/module/quantum.hexa` | code | ~400 LOC | qpu_bridge VQE / ML pilot dispatcher | C |
| `quantum/module/n6_lattice_check.hexa` | code | 152 LOC | Pure-hexa cross-axis n=6 reference table + drift detector | **B (HIGH — port as doctrine seed)** |
| `quantum/module/external_pilot_runner.hexa` | code | ~250 LOC | ProteinMPNN / Boltz-2 / RhoFold+ smokes dispatcher | C |
| `quantum/module/{closure_summary,sister_axes_status,upstream_pulse_check,registry_witness_emitter,anima_phi,simu_multiverse,hexabrain_consumer}.hexa` | code | ~600 LOC total | qmirror/xeno/hexa-brain consumer adapters + status surface | C (depends on external SSOTs) |
| `selftest/n6_axis_computational_verification.py` | code | 318 LOC | Pure-stdlib deductive σ/τ/φ/J₂ verifier — 42/42 checks across 5 axes | **B (HIGH — port as stdlib bio fixture)** |
| `selftest/run_all.sh` | script | ~700 LOC est. | 35-gate aggregator | C |
| `selftest/{cmt_*,ribozyme_a1_*,virocapsid_*}` | scripts | ~30 files | Per-axis readiness + perturbation + replay tests | C |
| `selftest/module/selftest.hexa` | code | ~150 LOC | 5-axis sentinel sweep | C |
| `_python_bridge/module/*.py` | code | 9 files / 2,276 LOC | Bio simulator stdlib re-implementations + lean4 witness emit | C (sim-side; rule-3 metadata, not algorithm) |
| `_qiskit_bridge/module/*.py` | code | 15 files / 5,898 LOC | VQE / ansatz / Pauli expectation / qmirror entropy adapters | C (would duplicate qmirror — sister repo by design) |
| `_absorption_bridge/` | code | 9 dirs / ~1,877 LOC Python | AF3/RoseTTAFold/ESMFold/OpenFold/ColabFold/Foldseek/MMseqs/UniProt/PDB smoke adapters | C (protein-AI consumer surface) |
| `tests/*.hexa` + `tests/*.py` | tests | 18 hexa + 50 py | Per-axis + per-disease + chemistry-VQE regressions | C |
| `examples/0{1..5}_quick_*.hexa` | examples | 5 files / ~150 LOC | Per-axis quick-start | C |
| `papers/n6-*.md` | docs | 8 papers / 316 KB | n6-genetics, n6-synbio, n6-dolphin, hexa-weave-formal-mechanical | C (domain content) |
| `docs/n6/{hexa-{weave,nanobot,ribozyme,virocapsid}}.md` | docs | 4 files | Per-axis canonical concept docs (canon-extracted) | C |
| `docs/closure_100_research_2026_05_12.md` | docs | ~200 LOC est. | Π¹₁-CA₀ → RCA₀ re-scope + 5-axis closure deep-dive | C |
| `docs/{cmt_v7_closure_summary,hexa_bio_*_2026_05_08,disease_inventory,external_systems_review,...}.md` | docs | ~20 files | Cycle handoff notes / domain consolidations | C |
| `.roadmap.hexa_bio + .roadmap.{quantum,weave,virocapsid,nanobot,ribozyme,...}` + 5 axis files | docs | ~12 K LOC | Per-axis gate / cycle / deadline registers | C |
| `.roadmap.disease_*` | docs | **162 files**, ~12-15K each | Per-disease working roadmaps (ALS / asthma / CRISPR / cancer / atrial fib / ...) | C (domain catalogue; SKIP) |
| `*.tape` files at top level | shell-recordings | 64 files | Per-vertical "Ultimate X" goal records (agriculture / coffee / fermentation / immunology / pharma / synbio / ...) | C |
| `proposals/hexa-weave/` | docs | ~852 KB | hexa-weave proposal archive | C |
| `breakthroughs/{bt-1387,bt-1391}.md` | docs | 2 files | Aromatic / glucose photosynthesis breakthrough records | C (atlas already has them) |
| `state/discovery_absorption/registry.jsonl` | data | 18 MB | C2 / discovery / witness audit log (raw_77_* row stream) | C (project journal — SKIP) |
| `state/markers/*.marker` | data | 4.1 MB | Per-script idempotency tokens | C (SKIP) |
| `wetlab/{cro,data,ip,mta,regulatory,sop}/` | docs | 52 K | Wet-lab handoff stubs | C |
| `biology/biology.md` + `genetics/`+`synbio/`+`bio-pharma/`+`medical-device/`+`crispr-*/`+`hexa-{nanobot,ribozyme,virocapsid,weave}/` | docs | 12 single-MD verb dirs | Canon-extracted single-doc verb stubs | C |
| `__pyphi_cache__/` + `pyphi.log` | cache | 8 K + log | PyPhi (IIT) library cache — orphan | C (skip; possibly stale) |
| `IMPORTED_FROM_CANON.md` | meta | ~30 LOC | Provenance record of canon-imported MD files | C (SSOT marker) |
| `CITATION.cff`, `RELEASE_NOTES_v1.{0,1}.md`, `CHANGELOG.tape`, `AXIS_CLOSURE_PLAN.md`, `CLOSURE_RESIDUAL_BACKLOG.md`, `COMPUTE_PORTFOLIO.md`, `DECOMPOSITION_PLAN.md`, `USER_ACTION_REQUIRED.md`, `V1_1_0_HANDOFF.md`, `LESSONS.tape`, `TAPE-AUDIT.md` | meta | various | Project meta files | C |

**Aggregate counts:**
- 91 `.hexa` files / ~17,005 LOC total (incl. tests + examples)
- 4,423 `.py` files including tests/cache (~2,276 LOC `_python_bridge` + ~5,898 LOC `_qiskit_bridge` + 318 `n6_axis_verify` + ~1,877 LOC `_absorption_bridge` + tests; remainder is `__pycache__`)
- ~200 `.md` + `.roadmap.*` + `.tape` docs / ~50 K LOC total
- 22 MB `state/` (run journals; SKIP)
- 64 `.tape` files = vhs/asciinema-style terminal recordings of per-vertical "Ultimate X" goal walks; not loadable as data.

## 3. Atlas-relevant subset

Files in hexa-bio that **mention** atlas / n6 / σ / τ / φ / J₂ explicitly (50 `.hexa` files matched). Of those, only a small set is candidate for upstream port:

| File | LOC | Atlas-relevance | Integration into hexa-lang |
|---|---:|---|---|
| `quantum/module/n6_lattice_check.hexa` | 152 | **Canonical 5-axis lattice table + cross-check driver.** Hardcoded 5 ROW arrays (RIBOZYME/VIROCAPSID/NANOBOT/WEAVE/QUANTUM), runs each axis dispatcher and verifies σ/τ/φ/J₂ literals match. Pure-hexa, pure-stdlib (`self/stdlib/proc`). | New module `compiler/n6_lattice/check.hexa` + table seed for `compiler/falsifiers/` data plane. Doctrine rule 1 (rodata data) for the 5 ROW arrays; rule 2 (algorithm) for the drift detector. |
| `selftest/n6_axis_computational_verification.py` | 318 | **Deductive σ/τ/φ/J₂ checker.** itertools+math only; verifies 12-vertex polyhedron Euler V−E+F=2, S₄≅O for J₂=24, master identity σ·φ=n·τ=24, plus regression MVP values per axis. Exits with `__N6_AXIS_VERIFY__ PASS\|FAIL` + optional `--json`. | Port to **pure-hexa** as `compiler/n6_lattice/verify.hexa` (~250 LOC after dropping bio MVP regression assertions). Doctrine rule 2 (algorithm code). The bio MVP-regression block lives in hexa-bio as the consumer; only the **lattice arithmetic / geometry / group theory** belongs upstream. |
| `quantum/module/closure_summary.hexa` | ~80 LOC est. | Reads per-axis sentinel + emits 5-axis closure JSON | SKIP (consumer-side) |
| `weave/module/lean4_proof_witness_emit.hexa` | ~100 LOC est. | Emits `raw_77_lean4_proof_witness_v0` rows referencing hexa-meta state | SKIP (overlaps `compiler/atlas/witness*` if any; consumer-side) |
| `*/module/bayesian_n6_ablation.hexa` (nanobot+ribozyme) | ~300 LOC each | Bayesian audit: σ(6)=12 vs uniform{5..50} log10_BF | SKIP as code; the **Bayesian audit pattern** is a doctrine rule 3 metadata candidate (record once, not 2× duplication) |
| `nanobot/module/bayesian_n6_stratum_bias.hexa`, `nanobot/module/bayesian_n6_per_axis_stratum.hexa` | ~150 LOC each | Stratum analysis of σ(6)=12 audit | SKIP (consumer-side) |
| `LATTICE_POLICY.md` | 242 LOC | **Universal lattice-as-tool-not-constraint declaration.** §1.2 lists the canonical real-limits table (Shannon / Kolmogorov / Bekenstein / c / ℏ / k / Stefan-Boltzmann / Carnot / Margolus-Levitin / Bremermann / ASML / ERCOT / ...). | **Mirror verbatim** into `doc/lattice_policy.md` + cross-link from hexa-lang doctrine. The §1.2 real-limits table is also a candidate to seed a `compiler/lattice_policy/real_limits.hexa` rodata array if hexa-lang ever runs limit-anchor checks. |
| `AGENTS.md` (sister-repo CLI-direct rules) | ~360 LOC | "Never duplicate a sister-repo's logic; CLI-direct integration over wrappers; gates not re-verifications; SKIP is honest." | **Quote into hexa-lang's CLAUDE.md / AGENTS.md** as a cross-link reference; the rules are dancinlab-wide and hexa-lang is the platform many sisters share. |
| `LIMIT_BREAKTHROUGH.md` | 208 LOC | Bio-domain instance of LATTICE_POLICY §1.2 with HARD_WALL / SOFT_WALL / BREAKABLE_WITH_TECH classification per limit | SKIP (domain instance); but the **classification taxonomy** (HARD/SOFT/BREAKABLE/UNCLEAR) belongs in `doc/lattice_policy.md` as the recommended audit format. |

## 4. Absorption candidates by Doctrine v2 rule

### Rule 1 — rodata data (seed-grade, frozen)

| Item | Source | Target | Size | Priority |
|---|---|---|---:|---|
| 5-axis n=6 reference table | `quantum/module/n6_lattice_check.hexa::RIBOZYME_ROW…QUANTUM_ROW` | `compiler/n6_lattice/axis_table.hexa` (rodata `[N6Axis]`) | ~60 LOC | **HIGH** |
| Real-limits table (§1.2) | `LATTICE_POLICY.md §1.2` (Shannon / Kolmogorov / Bekenstein / c / ℏ / k / Stefan-Boltzmann / Carnot / Margolus-Levitin / Bremermann / ASML / ERCOT / TCEQ / CHIPS / BLS / USPTO / Hopfield / Berg-vHippel / Bremer-Dennis / Levinthal / Caspar-Klug / DiMasi / Tsai-2015 / Anzalone-2019 / Kunkel-2000) | `compiler/lattice_policy/real_limits.hexa` (rodata `[RealLimit]`) | ~120 LOC | MEDIUM |
| Honest-C3 taxonomy markers (HARD_WALL / SOFT_WALL / BREAKABLE_WITH_TECH / UNCLEAR) | `LIMIT_BREAKTHROUGH.md` per-limit tags | enum + per-limit annotations on the above | ~30 LOC | LOW |

### Rule 2 — algorithm code (operational, hexa-source)

| Item | Source | Target | LOC after port | Priority |
|---|---|---|---:|---|
| Deductive σ/τ/φ/J₂ verifier (lattice math only) | `selftest/n6_axis_computational_verification.py` minus MVP regression block | `compiler/n6_lattice/verify.hexa` | ~250 LOC | **HIGH** |
| Cross-axis drift detector (run each axis, compare literal) | `quantum/module/n6_lattice_check.hexa::_run_axis_n6` + `_compare_rows` | `compiler/n6_lattice/cross_check.hexa` | ~80 LOC | MEDIUM |
| Bayesian σ(6)=12 vs uniform audit primitive (literature corpus form) | `*/module/bayesian_n6_ablation.hexa` (DEDUPE — same skeleton across axes) | `compiler/n6_lattice/bayes.hexa` (single canonical) | ~150 LOC | LOW-MEDIUM |

### Rule 3 — metadata archive (frozen records)

| Item | Source | Target | Priority |
|---|---|---|---|
| Hexa-bio "v1.x category-(a) 100% closure" verdict snapshot (registry L24, 2026-05-12 / 2026-05-13) | `README.md` 5-axis status table + `RELEASE_NOTES_v1.1.0.md` | `compiler/audit_archive/hexa_bio_v1_1_0.snapshot.hexa` | LOW |
| LATTICE_POLICY deployment trail (Wave K → all dancinlab repos 2026-05-12) | `LATTICE_POLICY.md` header + `AGENTS.md` "Origin: dancinlab Wave K, 2026-05-12" | metadata note in `inbox/notes/2026-05-14-hexa-bio-absorption-plan.md` (this file) | DONE-via-this-plan |
| 35-gate selftest scoreboard | `selftest/run_all.sh` headers + exit status | not portable (host-specific gates); reference only | SKIP |

### Rule 4 — external/HW (δ pattern candidates)

| Item | Source | Pattern | Status in hexa-lang |
|---|---|---|---|
| `qmirror` CLI-direct integration | `AGENTS.md` "Sister repos — live dependencies" + `selftest/qmirror_chemistry_vqe_gate.sh` pattern | Shell-out gate, SKIP on absence | hexa-lang has `compiler/hw_probes/` — same idiom. No port needed; **cross-link the pattern rule in `compiler/bridges/`** |
| `xeno` substrate orchestrator | `selftest/xeno_substrate_gate.sh` | Same SKIP/PASS/FAIL gate idiom | Same as above |
| `_absorption_bridge/` 9 protein-AI adapters | `alphafold3/af3_smoke.py`, etc. | Offline-replay fixture + `--selftest` SKIP-on-missing-dep | **Note pattern** in `inbox/patches/` if hexa-lang ever wants a similar adapter shape for ML model bridges; **do not port the adapters themselves** (bio-domain consumer surface) |
| `pyphi` (IIT) | `__pyphi_cache__/` + `stdlib/iit_ei.hexa` in hexa-lang | hexa-lang already has `iit_ei.hexa` — possible cross-link | Verify no double-port between `pyphi_cache` and `iit_ei.hexa`; **suspected no overlap** (cache is orphan in hexa-bio) |

### Rule 5 — overlay write

**N/A — this is a read-only audit. No overlay write proposed.**

## 5. Wave plan

### Wave 1 — doctrine port (foundation, blocking)

**1.1 — `LATTICE_POLICY.md` verbatim mirror**
- Copy `~/core/hexa-bio/LATTICE_POLICY.md` → `~/core/hexa-lang/doc/lattice_policy.md`.
- Add header preface "absorbed from hexa-bio on 2026-05-14, deployment trail: Wave K 2026-05-12 dancinlab-wide".
- Cross-link from hexa-lang `CLAUDE.md` / `AGENTS.md` / README.
- 0 code change. Doctrine rule 3.

**1.2 — Real-limits table (§1.2) as rodata seed**
- Extract `Mathematical / Physical / Engineering` limit rows from `LATTICE_POLICY.md §1.2` (~25 rows: Shannon · Kolmogorov · Halting · Bekenstein · Statistical power · PAC-learning · c · ℏ · k · Stefan-Boltzmann · Carnot · Bremermann · Margolus-Levitin · Bekenstein-Hawking · ASML EUV · ERCOT · Starship · TCEQ · CHIPS · BLS · USPTO).
- Emit as `compiler/lattice_policy/real_limits.hexa` rodata `[RealLimit { name, formula, citation, category }]`.
- ~120 LOC + a 30 LOC `RealLimit` struct + 50 LOC test fixture.
- Doctrine rule 1.

**1.3 — Sister-repo CLI-direct rule note**
- Quote `AGENTS.md` "Sister repositories — live dependencies (do NOT reimplement)" section block into `doc/sister_repos.md` (new file).
- Cross-link rules 1-4 (never duplicate / CLI over wrappers / gates not re-verifications / SKIP honest).
- 0 new code; ~80 LOC doc.

### Wave 2 — n=6 lattice verifier port (depends on Wave 1.1)

**2.1 — Port `n6_axis_computational_verification.py` to pure hexa**
- Source: `~/core/hexa-bio/selftest/n6_axis_computational_verification.py` (318 LOC) minus MVP-regression block (lines ~67-90, RIBOZYME_KCAT_PER_MIN etc. — those are bio domain, not lattice math).
- Target: `compiler/n6_lattice/verify.hexa` (~250 LOC after port).
- Surfaces: `verify_sigma()` (V−E+F=2 Euler on icosahedron; 12-pentamer Caspar-Klug; 12-nt nucleic core), `verify_tau()` (4-state ladder length), `verify_phi()` (binary dichotomy), `verify_J2()` (|S₄|=24 via itertools-equivalent permutations; S₄≅O via Cayley table fingerprint), `verify_master_identity()` (σ·φ = n·τ = 24).
- Wires into `tool/<exec>` as `hexa lattice verify [--json]`.
- ~250 LOC + ~80 LOC tests.

**2.2 — Port n=6 axis reference table as rodata**
- Source: `~/core/hexa-bio/quantum/module/n6_lattice_check.hexa::{RIBOZYME,VIROCAPSID,NANOBOT,WEAVE,QUANTUM}_ROW` (~65 LOC of literal table data).
- Target: `compiler/n6_lattice/axis_table.hexa` rodata `[N6Axis { name, sigma_meaning, sigma, tau_meaning, tau, phi_meaning, phi, J2_meaning, J2 }]`.
- ~65 LOC + ~30 LOC reader. Doctrine rule 1.
- Optional augmentation: also seed `[N6Axis]` rows for any **non-bio** axes hexa-lang already cares about (hexa-chip's `isa_n6`, etc. — separate audit).

**2.3 — Cross-axis drift detector (optional)**
- Port `quantum/module/n6_lattice_check.hexa::_run_axis_n6 + compare` (~80 LOC) into `compiler/n6_lattice/cross_check.hexa`.
- Only useful if hexa-lang adopts a multi-package n6-axis dispatcher convention. **Gate this on user direction** (do not auto-land).

### Wave 3 — doctrine taxonomy + audit pattern (priority medium, optional)

**3.1 — HARD_WALL / SOFT_WALL / BREAKABLE_WITH_TECH / UNCLEAR taxonomy**
- Source: `~/core/hexa-bio/LIMIT_BREAKTHROUGH.md` (208 LOC; structure: per-limit L1..L8 with class tag).
- Target: extend `compiler/lattice_policy/real_limits.hexa::RealLimit` with `class: LimitClass` (enum) field + ~30 LOC enum decl.
- The bio per-limit instance (L1=DNA fidelity HARD, L2=k_cat HARD, L3=ribosome HARD, L4=Levinthal UNCLEAR→BREAKABLE, L5=Caspar-Klug HARD, L6=drug-cost SOFT, L7=ATP HARD, L8=CRISPR-offtarget BREAKABLE) stays in hexa-bio as the **consumer** instance; only the taxonomy enum belongs upstream.

**3.2 — Bayesian audit primitive** (only if hexa-lang gains a similar use case)
- Source: dedupe of `nanobot/module/bayesian_n6_ablation.hexa` + `ribozyme/module/bayesian_n6_ablation.hexa` (same skeleton, ~300 LOC each, factor → ~150 LOC).
- Target: `compiler/n6_lattice/bayes.hexa` — `log10_BF(observation, hypothesis_a, hypothesis_b) -> f64`.
- **Defer** unless a hexa-lang module actually needs Bayesian model comparison. The bio instance fits hexa-bio better.

### Wave 4 — cross-doc + provenance

**4.1 — Mirror `hexa.toml` "in_repo_closure_components" list as example**
- Reference hexa-bio's `hexa.toml [closure]` section as a model for how a `hx`-installed package documents its own closure components (12 named in-repo components + 1 out-of-repo residual).
- Add to hexa-lang's `doc/hx_package_authoring.md` or equivalent (if exists; create stub if not).
- 0 code; ~30 LOC doc.

**4.2 — n6 omega-cycle rationale rows already in atlas**
- The `embedded.gen.hexa` rodata already contains 158 hits for hexa-weave / nanobot / ribozyme / virocapsid (mostly `omega_cycle_*_rationale_*` rows from the 2026-05-12 n6 absorption session). No re-port needed; these are **already covered** by Wave 1 of the n6 absorption plan.
- **Verification step**: after Wave 1+2 of *this* hexa-bio plan, re-run `tool/atlas_embed_gen.hexa` to confirm no double-emit of bio omega-cycle rationale.

## 6. Skip list

| Item | Reason |
|---|---|
| `weave/module/*` (7 files / ~1.5K LOC) | Bio empirical sandbox — domain consumer, not platform |
| `nanobot/module/*` (16 files / ~3K LOC) | Same |
| `ribozyme/module/*` (15 files / ~2.5K LOC) | Same |
| `virocapsid/module/*` (14 files / ~3K LOC) | Same |
| `quantum/module/{quantum,external_pilot_runner,closure_summary,sister_axes_status,upstream_pulse_check,registry_witness_emitter,anima_phi,simu_multiverse,hexabrain_consumer}.hexa` | qmirror/xeno/hexa-brain consumer adapters; sister-repo dispatchers belong on the consumer side per hexa-bio's own AGENTS.md rule |
| `_python_bridge/module/*.py` (9 / 2,276 LOC) | Per-axis stdlib sim re-implementations (Nussinov MFE, off-target Hamming, kinetics RK4, PDB corpus); bio-specific algorithms |
| `_qiskit_bridge/module/*.py` (15 / 5,898 LOC) | Would duplicate `qmirror` per hexa-bio's own "never duplicate sister logic" rule |
| `_absorption_bridge/*` (9 dirs / ~1,877 LOC) | Protein-AI consumer adapters (AF3/RoseTTAFold/ESMFold/OpenFold/ColabFold/Foldseek/MMseqs/UniProt/PDB); domain consumer |
| `tests/*.py` (50+ test scripts) | Bio test suite |
| `tests/*.hexa` (18 files) | Per-axis test wrappers |
| `examples/0{1..5}_quick_*.hexa` | Per-axis quick-start; relevant to `hx install hexa-bio` users, not hexa-lang |
| `papers/n6-*.md` (8 papers) | Domain papers; canon-imported, already cross-referenced from atlas |
| `docs/n6/hexa-{weave,nanobot,ribozyme,virocapsid}.md` | Canonical concept docs — already covered by atlas omega-cycle rationale rows (158 hits) |
| `.roadmap.disease_*` (**162 files**, ~12-15K LOC each ≈ ~2 MB total) | Per-disease working roadmaps — pure domain content |
| `*.tape` (64 files at top level) | vhs/asciinema terminal recordings of "Ultimate X" goal walks — not data |
| `state/` (22 MB) | Run journals + idempotency markers; project-specific |
| `wetlab/{cro,data,ip,mta,regulatory,sop}/` | Wet-lab handoff stubs; out-of-software-scope per hexa-bio category (c) |
| `proposals/hexa-weave/` (~852 KB) | hexa-weave proposal archive |
| `sessions/` (3 files) | Per-cycle session logs |
| `breakthroughs/{bt-1387,bt-1391}.md` | Already covered in atlas (BT- bloomed entries) |
| `__pyphi_cache__/` + `pyphi.log` | Orphan PyPhi cache; hexa-lang has its own `stdlib/iit_ei.hexa` |
| `IMPORTED_FROM_CANON.md` | Provenance record; nothing to port |
| ML weights / checkpoints | None present in repo (792 MB is mostly `state/` 22 MB + roadmap docs + git history). `.roadmap.ai_ml_integration` is text only. No `models/` `weights/` `checkpoints/` directories found. |

## 7. Estimated scope

**Wave 1+2 (recommended scope):**

| Wave | Deliverable | New LOC source | New LOC test | New doc LOC |
|---|---|---:|---:|---:|
| 1.1 | `doc/lattice_policy.md` mirror | 0 | 0 | 242 (verbatim) |
| 1.2 | `compiler/lattice_policy/real_limits.hexa` + `RealLimit` struct | 150 | 50 | 0 |
| 1.3 | `doc/sister_repos.md` | 0 | 0 | 80 |
| 2.1 | `compiler/n6_lattice/verify.hexa` | 250 | 80 | 0 |
| 2.2 | `compiler/n6_lattice/axis_table.hexa` | 65 | 30 | 0 |
| 2.3 | `compiler/n6_lattice/cross_check.hexa` (optional) | 80 | 20 | 0 |
| **Total (Wave 1+2 core, excl. optional 2.3)** | | **~465 LOC source** | **~160 LOC tests** | **~322 LOC docs** |

**Wave 3 (defer-recommended):**
| 3.1 | `LimitClass` enum extension | 30 | 0 | 0 |
| 3.2 | `compiler/n6_lattice/bayes.hexa` | 150 | 60 | 0 |

**Wave 4 (cross-doc):**
| 4.1 | `doc/hx_package_authoring.md` (stub or extend) | 0 | 0 | 30 |
| 4.2 | atlas re-embed verification | 0 | 20 | 0 |

**Grand total (recommended Waves 1+2 only):** ~465 LOC source + ~160 LOC tests + ~322 LOC docs.

**Critical path:**
1. Wave 1.1 (verbatim doc mirror) — no dependencies; ~5 minutes if approved.
2. Wave 1.2 (real-limits rodata) — depends on consensus on `RealLimit` struct shape.
3. Wave 2.1 (verifier port) — depends on hexa-lang `stdlib/proc` parity with the Python script's `itertools`/`math` usage; `itertools.permutations` is the main port target — hexa-lang stdlib has equivalents per recent absorption sessions, **verify before scheduling**.
4. Wave 2.2 (axis table rodata) — trivial; can land in parallel with 2.1.
5. Wave 1.3, 4.1, 4.2 — cross-cutting docs; land anytime after 1.1.

**Risks / coordination notes:**
- **Double-port risk:** hexa-bio's `IMPORTED_FROM_CANON.md` shows 8 papers + 4 per-axis hexa-*.md concept docs were *moved out* of canon@a86ca143. The canon retirement (2026-05-11) means future plans should not re-port content from `~/core/nexus/canon-infra/legacy-canon/` that has already been re-homed in hexa-bio. This plan **does not propose any port from canon-legacy**, so no double-port risk on this axis.
- **Sister-repo discipline:** per hexa-bio's own AGENTS.md "never duplicate a sister-repo's logic", the bio-domain modules and qmirror/xeno adapters explicitly belong in their respective repos — hexa-lang must not mirror them. Wave 2.3 (cross-axis drift detector) crosses this boundary the most softly: it would run external dispatchers, not re-implement them. Defer 2.3 until a concrete multi-package case appears.
- **5-axis count lock:** `.roadmap.axis_expansion_decision_2026_05_08` and `hexa.toml [closure].axis_count_lock` declare the 5-axis count is locked. Any hexa-lang `[N6Axis]` rodata should respect that and **not invent new axes upstream** — only consume what hexa-bio has declared.
- **LATTICE_POLICY universality:** the policy was deployed dancinlab-wide on 2026-05-12 (Wave K). hexa-lang likely already received it via that deployment — **verify** before re-mirroring. If hexa-lang already has `LATTICE_POLICY.md` at root or under `doc/`, Wave 1.1 reduces to a no-op cross-link.
- **`itertools` parity:** the Python verifier uses `itertools.permutations` for the S₄ group enumeration. Confirm hexa-lang stdlib has an `itertools_permutations(seq) -> [[T]]` (or equivalent recursive generator) before scheduling Wave 2.1.
- **License & attribution:** Apache-2.0. Add header `// absorbed from ~/core/hexa-bio/<path> (Apache-2.0)` on absorbed files.

## 8. Bottom line

The 792 MB of hexa-bio is dominated by **domain content** (162 per-disease roadmaps + 64 per-vertical `.tape` files + 18 MB run-state journal + 4 bio-axis simulator implementations + 9 protein-AI consumer adapters + 15 VQE bridge scripts). **None of that belongs in hexa-lang** — hexa-bio is the *consumer* of hexa-lang, not the reverse.

The portable surface is small, doctrine-grade, and high-value:

1. **`LATTICE_POLICY.md`** (242 LOC) — universal real-limits-first verification rule; possibly already deployed dancinlab-wide.
2. **`selftest/n6_axis_computational_verification.py`** (318 LOC, ~250 after MVP-regression stripping) — pure-stdlib deductive σ/τ/φ/J₂ verifier with strong math/geometry/group-theory anchors.
3. **`quantum/module/n6_lattice_check.hexa`** (152 LOC) — pure-hexa 5-axis reference-table + drift detector, already in hexa-lang's idiom.

These three would land hexa-lang as ~465 LOC source + ~160 LOC tests + ~322 LOC docs, providing the platform with (a) a doctrine anchor for the "n=6 lattice is a tool not a constraint" rule, (b) an executable σ/τ/φ/J₂ verifier the bio axes already consume but hexa-lang itself does not yet ship, and (c) a frozen rodata table of 5-axis lattice claims that downstream packages (hexa-bio, hexa-chip's `isa_n6`, etc.) can read from instead of duplicating literals.

Everything else is **skip**. The bio axes themselves are explicitly the consumer of `hx install hexa-bio`; the protein-AI adapters explicitly belong in `_absorption_bridge/`; the qiskit / qmirror bridge explicitly belongs in qmirror per hexa-bio's own sister-repo rule.
