# `mmseqs/SOURCES.md` — MMseqs2 sequence search

> hexa-bio cycle-30++++++++ absorption adapter target: `mmseqs_smoke.py`

---

## System

- **Name**: MMseqs2 (Many-against-Many sequence searching, version 2)
- **Maintainer**: Martin Steinegger + Johannes Söding (Max Planck Göttingen / Seoul National University)
- **Web / Code**: https://github.com/soedinglab/MMseqs2
- **Scale**: searches billions of sequences with PSI-BLAST-class sensitivity; powers ColabFold's MSA pipeline + Foldseek's structural-alphabet stage

## Authoritative citation

- Steinegger, M. & Söding, J. "MMseqs2 enables sensitive protein sequence searching for the analysis of massive data sets." **Nature Biotechnology** 35, 1026-1028 (2017). DOI: 10.1038/nbt.3988

## Output schema (this adapter validates)

- Per-hit M8 fields: `target`, `fident` (0-1), `alnlen`, `mismatch`,
  `gapopen`, `qstart`, `qend`, `tstart`, `tend`, `evalue`, `bits`
- Top-level: `tool_name: MMseqs2`, `mode`, `database`, `n_hits`

## License

- **GPLv3** — same as Foldseek. Consuming MMseqs2 output in a downstream
  pipeline is unrestricted; shipping the binary in a closed product
  invokes GPL obligations.

## Honest notes

- **No n=6 lattice-fit** applied to MMseqs2 hits (C3).
- **E-value semantics**: MMseqs2 uses the same Gumbel-extreme-value
  null-model framework as BLAST; E-values are interchangeable in
  interpretation but differ in absolute calibration.
- **Adapter caching**: bundled fixture `cache/sample_alignment.json`.

## Cross-link

- `_absorption_bridge/mmseqs/mmseqs_smoke.py` — this adapter
- `_absorption_bridge/foldseek/SOURCES.md` — sister structural-search engine
- `_absorption_bridge/colabfold/SOURCES.md` — consumer (MSA generation)
