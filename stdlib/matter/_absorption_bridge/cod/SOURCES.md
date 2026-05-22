# `cod/SOURCES.md` — Crystallography Open Database (COD)

> Phase G+1 adapter target: `cod_search_smoke.py` (offline schema replay; real fetch via the public COD REST search endpoint)

---

## System

- **Name**: Crystallography Open Database (COD)
- **Maintainer**: COD Advisory Board (Vilnius University · IUCr-hosted mirrors)
- **Web**: https://www.crystallography.net/cod/
- **Search**: http://www.crystallography.net/cod/result
- **CIF fetch**: http://www.crystallography.net/cod/<COD-ID>.cif
- **Scale (as of 2024)**: > 500,000 deposited crystal structures (organic + inorganic + minerals)

## Authoritative citations

- Gražulis, S. et al. "Crystallography Open Database — an open-access collection of crystal structures." **J. Appl. Crystallogr.** 42, 726–729 (2009). DOI: 10.1107/S0021889809016690
- Gražulis, S. et al. "Crystallography Open Database (COD): an open-access collection of crystal structures and platform for world-wide collaboration." **Nucleic Acids Res.** 40, D420–D427 (2012). DOI: 10.1093/nar/gkr900
- Quirós, M. et al. "Using SMILES strings for the description of chemical connectivity in the Crystallography Open Database." **J. Cheminform.** 10, 23 (2018). DOI: 10.1186/s13321-018-0279-6

## REST endpoint shape

- Free-form web search: `http://www.crystallography.net/cod/result?formula=Si&format=json`
- Per-record CIF: `http://www.crystallography.net/cod/{cod_id}.cif`
- No API key, no auth, no signup. Polite rate cadence (≤ 1 req / 3 s) per IUCr server-load guidance.
- Public bulk SVN / rsync mirror: `rsync://www.crystallography.net/cif/`

## License

- **Raw structural data: public domain / CC0** (COD policy, in line with the
  IUCr "no reproduction restriction on cell parameters and atomic positions"
  position). See https://wiki.crystallography.net/howtoCite/ for the
  citation-courtesy expectation (cite the depositor + journal that originally
  reported the structure, plus a courtesy cite of COD itself).
- This adapter passes records through AS-IS; no re-licensing of the raw cell
  parameters is implied.

## Schema (per record, abbreviated)

| Field | Type | Note |
|---|---|---|
| `cod_id` | int | COD numeric identifier (e.g. 9008565 = Si) |
| `formula` | str | Hill or empirical |
| `spacegroup_hm` | str | Hermann-Mauguin symbol |
| `spacegroup_it` | int | International Tables number |
| `cell` (`a`, `b`, `c`, `alpha`, `beta`, `gamma`, `volume`) | dict | Å + degrees + Å³ |
| `z` | int | formula units per cell |
| `measurement_type` | str | typically `experimental_xrd` |
| `publication` | dict | journal + year + DOI/ref |

## Honest notes

- COD records are **measurements**, not predictions — distinct from Materials
  Project / GNoME / OMat24 (which are DFT outputs). Cell parameters were
  determined experimentally by the depositor. Provenance lives in the
  attached publication.
  uncertainties (typically e.s.d. on cell parameters, ~10⁻⁴ Å) are the
  authoritative bars.
- **Not a DFT-property replacement**: COD records carry experimental cell
  parameters + atomic positions; they do NOT carry computed band gap,
  formation energy, or elastic tensor. Use Materials Project / OMat24 /
  GNoME for those.
- The adapter's selftest is **offline fixture replay only**. Live REST hits
  are gated behind explicit `--cod-id` runtime use and observe the polite
  ≤ 1 req / 3 s cadence + identify themselves with a User-Agent.

## Cross-link

- `_absorption_bridge/materials_project/SOURCES.md` — DFT-computed sister db (predicted, not measured)
- `_absorption_bridge/gnome/SOURCES.md` — purely predicted (DeepMind GNoME)
- `_python_bridge/module/pymatgen_structure_io.py` — pymatgen `Structure.from_str(cif)` reader (Phase E)
- `silicon/silicon.md` — Si lattice parameter cross-cited against COD entry 9008565

