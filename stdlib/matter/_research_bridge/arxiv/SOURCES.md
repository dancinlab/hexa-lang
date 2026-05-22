# arxiv SOURCES — hexa-matter research bridge

> **Created**: 2026-05-13 (Phase F)
> **Status**: arxiv API ingestion configuration + keyword strategy
> **Honesty**: arxiv abstracts are **CURRENT-RESEARCH SIGNALS**, not verified specs. Treat accordingly.

---

## §1 arxiv categories (cond-mat subtree primary)

| Category | Coverage | hexa-matter relevance |
|---|---|---|
| `cond-mat.mtrl-sci` | Materials science | PRIMARY — all 29 verbs |
| `cond-mat.supr-con` | Superconductivity | LK-99 watch (UNPROVEN preservation) |
| `cond-mat.dis-nn` | Disorder + non-equilibrium | dopant disorder, amorphous Si, glass |
| `cond-mat.str-el` | Strongly-correlated electrons | perovskite oxide, magnetic materials |
| `cond-mat.soft` | Soft matter / polymers | POL group (epoxy, nylon, biodegradable) |
| `cond-mat.mes-hall` | Mesoscale + nanoscale | 2D materials, compound-semi HEMT |

Optional secondary subtrees (queryable but not default):
- `cs.LG` filtered by "materials discovery" or "GNoME" — Phase G overlap
- `physics.atom-ph` filtered by "isotope separation" — Si-28 relevance

---

## §2 Keyword strategy

Per-verb keyword indexes are encoded in `arxiv_digest.py` `VERB_KEYWORDS`.
Conventions:

- Lowercase + space-normalized matching (case-insensitive).
- Multi-word phrases preferred (e.g., `"polylactic"`, not just `"PLA"`).
- A paper that matches multiple verbs is filed in EACH verb's bucket (no
  forced disambiguation — readers will see the same arxiv_id under several
  verbs, which is honest).
- Speculative-claim flags (`UNPROVEN_FLAGS` in `arxiv_digest.py`) trip
  regardless of verb assignment. Speculative claims surface WITH their flag.

### Speculative claims that always trip UNPROVEN

- `lk-99` / `room-temperature superconductor` — never reproduced (2023 null)
- `ambient metallic hydrogen` — never confirmed at room conditions
- `magic-MOF DAC $100/t CO2` — UNPROVEN; Climeworks amine $600–1000/t baseline
- `25-year operational lifetime` for perovskite — UNVERIFIED at commercial scale
- `infinite recycle` / `100% recyclable` — Gibbs ΔS_mix HARD wall

---

## §3 Update cadence

- **Daily pull**: not recommended for hexa-matter (low signal-to-noise).
- **Weekly pull**: RECOMMENDED. Run `arxiv_pull.py --live --max 100` once
  per week against the default 6-category union, then `arxiv_digest.py
  --md` to produce a per-verb digest.
- **Monthly review**: digest output reviewed by the maintainer; arxiv IDs
  that inform a spec update are stamped with `@arxiv-informed: <id> <date>`
  in the relevant verb's spec markdown.

---

## §4 Rate-limit + ToS notes

- arxiv API explicit policy: **minimum 3-second delay** between requests.
  `arxiv_pull.py` honors this via `ARXIV_BACKOFF_SEC = 3.0` (sleep before
  each request, not after — gives one free read on session-start).
- arxiv allows non-commercial automated access; hexa-matter usage qualifies.
- User-Agent header set to identify the bridge:
  `User-Agent: hexa-matter-research-bridge/0.1 (Phase F)`
- Max results per query: arxiv hard-caps at 30000; we cap at 100 by default.

---

## §5 Cross-link convention

When an arxiv paper informs a hexa-matter spec update, the relevant verb's
spec markdown (e.g. `silicon/silicon.md`) gets a comment line:

```
@arxiv-informed: 2405.00001 (2024-05-01) — "Boron solubility in silicon at high temperature"
```

This is parsed by `selftest/sources_audit.py` to ensure cross-links don't
drift away from the local cache.

---

## §6 Honest C3

- arxiv preprints are **NOT peer-reviewed by default**. Many become published
  papers; some don't. Treat the digest as a research-signal feed, not as a
  knowledge claim.
- A spec update grounded ONLY in arxiv (no NIST/CRC/ASM anchor) is suspect.
  The honest pattern: arxiv flags a candidate → spec update happens only
  when a NIST/CRC/ASM/SEMI/ASTM/vendor anchor matches.
  counts are not τ. Categories are not axis labels.

---

## §7 Cache discipline

Every live pull writes md5-stamped JSON to `arxiv_cache/<YYYY-MM-DD>.jsonl`
before parsing. The md5 stamp is over `arxiv_id + title` — stable across
re-pulls of the same paper. Duplicates between pulls are deduplicated by
md5 at digest time.

`arxiv_cache/sample_response.xml` is the offline-replay fixture for
`--selftest`. It is 3 synthetic papers; not real data.

---

*Document authored 2026-05-13 by 박민우 <nerve011235@gmail.com> as Phase F elevation.*
