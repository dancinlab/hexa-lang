# `foldseek/SOURCES.md` — Foldseek structural search

> hexa-bio cycle-30++++++++ absorption adapter target: `foldseek_smoke.py`

---

## System

- **Name**: Foldseek (fast structural search via 3Di alphabet)
- **Maintainer**: Martin Steinegger lab, Seoul National University
- **Web / Code**: https://github.com/steineggerlab/foldseek
- **Public web server**: https://search.foldseek.com (free, with rate limits)
- **Scale**: searches the AFDB / PDB100 / ESM Atlas at 10^8-structure scale in seconds

## Authoritative citation

- van Kempen, M. et al. "Fast and accurate protein structure search with Foldseek." **Nature Biotechnology** 42, 243-246 (2024). DOI: 10.1038/s41587-023-01773-0

## Output schema (this adapter validates)

- Per-hit M8-style fields: `target`, `fident`, `alnlen`, `mismatch`,
  `gapopen`, `qstart`, `qend`, `tstart`, `tend`, `evalue`, `bits`
- Foldseek extensions: `lddt` (0-1), `tm_score` (0-1)
- Top-level: `alphabet: 3Di+AA` marker, `database`, `n_hits`

## License

- **GPLv3** — using Foldseek's *output* (alignment hits) in a downstream
  pipeline is unrestricted (data is not a derivative work of the GPL'd
  source). Distributing the *binary* in a closed-source product would
  invoke GPL obligations.
- hexa-bio's adapter only parses Foldseek output → no GPL contagion.

## Honest notes

- **TM-score / lDDT** are deterministic structural-similarity metrics
  inherited from the structural-bioinformatics literature; the adapter
  validates ranges but does NOT renormalize them.
- **No n=6 lattice-fit** applied to Foldseek hits (C3).
- **E-value semantics**: Foldseek's E-value is calibrated against the
  3Di+AA alphabet's null model; comparing it to BLAST E-values is
  apples-to-oranges.
- **Adapter caching**: bundled fixture `cache/sample_alignment.json`.

## Cross-link

- `_absorption_bridge/foldseek/foldseek_smoke.py` — this adapter
- `_absorption_bridge/mmseqs/SOURCES.md` — sister sequence-search engine
  from the same lab
