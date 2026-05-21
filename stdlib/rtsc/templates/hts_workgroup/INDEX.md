# HTS Modelling Workgroup — external reference benchmarks

> SSOT: each benchmark's *upstream* source URL (see per-dir `README.md`).
> Our repo carries **provenance manifests only** — no third-party `.pro`/`.geo`
> content is redistributed here.
>
> g3 stance: `absorbed=false`. These are external reference models for HTS-grade
> verification (RTSC.md §8.4, §4.2 Axis E). We don't claim to own them; we
> point at them and document the parameters from public benchmark pages.
>
> Access date: 2026-05-21.

---

## Entries

| dir | upstream | formulation | dim | status |
|---|---|---|---|---|
| [`benchmark1_tape/`](./benchmark1_tape/README.md) | https://htsmodelling.com/benchmark-1/ | H / A / T-A (open) | 2-D Cartesian | **[skipped: license unclear]** — benchmark *spec* is public, but no permissive license is stated on htsmodelling.com. Only the parameter manifest is recorded in our README; no third-party file content is committed. |
| [`life_hts_pancakes_ref/`](./life_hts_pancakes_ref/README.md) | https://gitlab.onelab.info/life-hts/life-hts (branch `pancakes`, dir `pancakesHPhi/pancakes_ref/`) | h-φ (reference, conventional) | 2-D | **[skipped: license unclear]** — upstream `life-hts` GitLab repo has **no `LICENSE` file** at the time of access. Author copyright reserved by default. We document fetch instructions but do NOT copy `.pro`/`.geo` source into this tree. |

---

## Why "skipped: license unclear" instead of vendoring

Per `~/core/demiurge/CLAUDE.md` g3 directive on external reference models:

- Provenance over re-derivation: the canonical SSOT is the upstream URL.
- Without a permissive license (CC-BY / MIT / Apache / public-domain), redistribution is unsafe even for research use.
- A user who needs to **run** the upstream model should clone the upstream repo directly. See each subdir's `fetch.sh` for the exact recipe.
- If the upstream later publishes a permissive license, flip the status here and vendor a copy under that license, citing the commit SHA observed at vendor time.

## GetDP version note

Upstream life-hts pancakes/tape/cylinder models require **GetDP 4.0.0** (uses `RhoPowerLaw` built-in). Our local `~/local/getdp/getdp-3.5.0-MacOSX/bin/getdp` is **3.5.0** — parses includes cleanly, then errors at `lib/lawsAndFunctions.pro:67`. Upgrade GetDP locally (or use ONELAB bundle) to run upstream reference solves. Smoke check on 2026-05-21 confirmed: *no .pro syntax errors* on the upstream files; the failure mode is host-version mismatch.

## Canonical Workgroup citations

- HTS Modelling Workgroup landing — https://htsmodelling.com/?page_id=748
- Benchmark index — https://htsmodelling.com/model-files/
- Pecher, R. & Sirois, F. (2008). *Numerical simulation of the magnetization of high-temperature superconductors: 3D finite element method using a single time-step iteration.* — https://arxiv.org/abs/0811.2883
- Shen, B., Grilli, F. & Coombs, T. (2020). *Review of the AC Loss Computation for HTS using the H-formulation.* SuST 33 033002. — https://arxiv.org/abs/1908.02176
- Dular, J., Geuzaine, C. & Vanderheyden, B. (2019). *Finite Element Formulations for Systems with High-Temperature Superconductors.* IEEE TASC. — DOI 10.1109/TASC.2019.2935429
- Denis, L., Vanderheyden, B. & Geuzaine, C. (2025). *Simultaneous Multi-Scale Homogeneous H-Phi Thin-Shell Model for Efficient Simulations of Stacked HTS Coils.* (submitted; EUCAS 2025)
