# `uniprot/SOURCES.md` — UniProt (EMBL-EBI / SIB / PIR)

> hexa-bio cycle-30++++++++ absorption adapter target: `uniprot_api_smoke.py`

---

## System

- **Name**: UniProt (Universal Protein Resource — Swiss-Prot + TrEMBL + PIR-PSD)
- **Maintainer**: UniProt Consortium (EMBL-EBI + SIB Swiss Institute of Bioinformatics + Protein Information Resource)
- **Web**: https://www.uniprot.org
- **REST API**: https://rest.uniprot.org/uniprotkb
- **Scale (2024)**: ~570k reviewed (Swiss-Prot) + ~250M unreviewed (TrEMBL) protein entries

## Authoritative citation

- UniProt Consortium. "UniProt: the universal protein knowledgebase in 2023." **Nucleic Acids Research** 51(D1), D523-D531 (2023). DOI: 10.1093/nar/gkac1052

## API endpoint + auth

- Base URL: `https://rest.uniprot.org/uniprotkb/{accession}.json`
- Auth: none (free public API)
- Rate limits: anonymous / lightly-throttled per IP; documented at
  https://www.uniprot.org/help/api
- Accession scheme: 6-10 char alphanumeric (`P0DTC2`, `Q9BYF1`, ...)

## Output schema (this adapter validates)

- `primaryAccession`, `uniProtkbId`, `entryType` (reviewed / unreviewed)
- `organism` (scientificName, taxonId)
- `proteinDescription.recommendedName.fullName.value`
- `sequence` (length, molWeight, crc64, md5)
- `features[]` (Signal, Chain, Domain, ...)

## License

- **Data: CC-BY 4.0** (UniProt terms of use)
- API: free; cite the UniProt Consortium 2023 paper in downstream work
- hexa-bio cites accession + retrieval date, not raw sequence bytes,
  for provenance.

## Honest notes

- **No n=6 lattice-fit** applied to UniProt records (C3).
- **annotationScore** (0-5) carries UniProt's OWN confidence rating;
  the adapter passes it through untouched.
- **Adapter caching**: bundled fixture `cache/sample_entry.json` (P0DTC2
  SARS-CoV-2 spike shape).

## Cross-link

- `_absorption_bridge/uniprot/uniprot_api_smoke.py` — this adapter
- `_absorption_bridge/pdb/SOURCES.md` — sibling RCSB PDB adapter
