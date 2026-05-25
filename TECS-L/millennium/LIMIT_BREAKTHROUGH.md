<!-- @created: 2026-05-12 -->
<!-- @wave: M (limit-breakthrough audit) -->
<!-- @scope: long-time-horizon limits bounding a millennium-scale program -->
<!-- @policy: LATTICE_POLICY.md §1.2 — n=6 격자 anchors NOT used here -->
---
type: limit-breakthrough-audit
wave: M
session: 2026-05-12
domain: millennium-scale-mathematics + long-horizon-engineering
verbs: 7 (BSD/Hodge/N-S/P-vs-NP/Poincaré/Riemann/Yang-Mills) "candidate" closed-forms
policy_ref: LATTICE_POLICY.md §1.2
---

# LIMIT_BREAKTHROUGH.md — hexa-millennium real-limits audit

> **Frame**: hexa-millennium ships seven *candidate* closed-forms over an
> implied multi-century reception window. The audit below covers (a)
> formal-mathematics acceptance limits, and (b) the engineering limits of
> any artifact intended to survive 10²–10³ years. Status of candidates
> themselves is **NOT FORMAL PROOF** per the repo's own README; we audit
> the wall, not the candidate.

---

## §1 Domain

Two layered domains:

1. **Mathematical-acceptance domain** — Clay Mathematics Institute
   Millennium Problems. Each has a formal statement; acceptance criteria
   are referee-mediated (publication + 2-year community review per Clay
   rules).
2. **Long-horizon-engineering domain** — anything claiming "millennium"
   relevance must survive language drift, institutional turnover,
   information-medium decay, and civilizational discontinuity.

---

## §2 Real limits

### §2.1 Formal-proof acceptance (HARD — process-defined)

| Limit | Value | Notes |
|---|---|---|
| Clay-Prize acceptance window | publication + 2 yr community review | Procedural; no shortcut |
| Acceptable proof formats | rigorous mathematical proof, no closed-form-without-proof shortcut | Closed-form *candidate* is not the same artifact class as proof |
| Open since | BSD 1965 / Hodge 1950 / N-S unbounded / P-vs-NP 1971 / Poincaré 1904→Perelman 2003 (resolved) / Riemann 1859 / Yang-Mills mass-gap 1954 (physics)/1969 (Wightman) | Mean ≈ 100 yr of effort by professionals; this is the empirical bound |
| Proof-length record | Classification of Finite Simple Groups ~10⁴ pages, multiple authors, decades | Sets a soft ceiling on "what a community can verify" |

**HARD wall**: closed-form *expressions* (no matter how elegant) without a
proof do not pass Clay-Prize acceptance.

### §2.2 Information-medium decay (HARD — physical chemistry)

| Medium | Half-life (typical) | Notes |
|---|---|---|
| Acid-free paper, climate-controlled archive | ~500 yr | Best mainstream practice |
| Parchment / vellum | ~1000 yr | Surviving manuscripts (Domesday 1086 → present ~940 yr) |
| Carved stone / cuneiform tablet | >3000 yr | Egyptian pyramids ~4500 yr, Sumerian tablets ~5000 yr |
| Magnetic tape (LTO) | ~30 yr (ECC + migration mandatory) | Worst archival medium of those listed |
| Optical disc (M-DISC, archival) | claimed 1000 yr, accelerated-aging based | Field data limited |
| DNA storage (cold, dry) | claimed 10⁵–10⁶ yr | Lab evidence (Allentoft 2012 woolly-mammoth ~10⁵ yr); pre-commercial |
| Git+IPFS+replicated cloud (this repo's actual medium) | ~30–100 yr w/o active migration | Soft — requires institutional continuity |

### §2.3 Linguistic decay (SOFT — observable)

| Limit | Value | Notes |
|---|---|---|
| Lexical replacement rate (Swadesh-100) | ~14% / 1000 yr (Swadesh 1952 / later contested) | Sets useful bound on direct readability of millennium-old technical text |
| Notation drift in mathematics | even faster — Newton vs Leibniz calculus notation diverged within 50 yr | Modern LaTeX is ~50 yr old; no millennium-test data |
| Reading of un-aided 1000-yr-old technical text | rare; requires specialist (paleographer, philologist) | Implies *millennium-scale* communication needs ongoing translation, not write-once |

### §2.4 Institutional half-life (SOFT — historical)

| Entity class | Median lifetime | Notes |
|---|---|---|
| Modern corporations (S&P 500) | ~15–20 yr (and falling) | Sloan / Foster studies |
| Universities (founded pre-1500, still operating) | small cohort: ~80 worldwide (Bologna 1088, Oxford ~1096) | Most institutions die before millennium |
| Religious institutions (continuous) | rare: Catholic Church ~2000 yr, Buddhism ~2500 yr, Judaism ~3000 yr | Outliers; selection bias |
| Modern nation-states | ~100–200 yr median (Tainter, *Collapse*) | Below millennium horizon |

### §2.5 Mathematical-truth invariance (HARD — formal)

Theorems, once proven inside a fixed formal system, are eternal *within
that system*. ZFC-provable statements remain ZFC-provable regardless of
language drift, medium decay, or institutional collapse, **provided the
proof artifact survives**. The wall here is artifact survival, not truth.

### §2.6 Gödel incompleteness — HARD_WALL (per hexa-meta §3.6)

| Limit | Value | Notes |
|---|---|---|
| Gödel's 1st incompleteness theorem (1931) | Any consistent recursively-enumerable theory containing arithmetic has true statements unprovable within itself | HARD — no foundational program escapes this |
| Gödel's 2nd incompleteness theorem (1931) | Such a theory cannot prove its own consistency | **ZFC consistency is unprovable in ZFC** |
| P vs NP | Open since Cook 1971 (Stephen Cook, *The complexity of theorem-proving procedures*) — 55+ yr of professional effort | Empirical HARD wall on closed-form attacks |
| Riemann Hypothesis | Open since 1859 (Riemann's memoir) — 165+ yr | Empirical HARD wall |
| BSD | Open since 1965 (Birch, Swinnerton-Dyer) — 60+ yr | Empirical HARD wall |
| Hodge | Open since 1950 (Hodge's ICM address) — 75+ yr | Empirical HARD wall |
| Navier–Stokes (3-D existence/smoothness) | Open since Leray 1934 (unbounded), Clay-form 2000 | Empirical HARD wall |
| Yang–Mills mass gap | Open since 1954 (physics) / 1969 (Wightman axiomatic) | Empirical HARD wall |

**HARD_WALL acknowledgement (per hexa-meta §3.6)**: any candidate that
asserts the existence of a closed-form "proof" of a Clay Millennium
Problem must be checked against Gödel's incompleteness theorems. A
finite closed-form expression over the n=6 lattice arithmetic CANNOT
substitute for a formal proof in the host theory (ZFC + Peano +
relevant axioms). The candidates in this repo are organizing-principle
artefacts; bridging to acceptance requires a formal Lean4 / Coq proof
artifact + Clay-mandated 2-yr community review, neither of which is
supplied here.

### §2.7 Civilization-collapse risk (SOFT — actuarial)

Population-weighted long-horizon collapse rate: empirical major
discontinuities (Bronze-Age collapse, fall of Western Rome, Black Death,
World Wars) recur on ~300–500-yr scale by various counts. Implication:
P(at-least-one major information-disrupting event per millennium) ≈ 1.
Mitigation = redundancy + geographic + medium diversity.

---

## §3 Assessment

| Wall | Can break? | How / why not |
|---|---|---|
| Clay-Prize acceptance for non-proof artifacts | NO (HARD) | Procedural; candidate ≠ proof. Repo is honest about this in README. |
| Gödel 1st incompleteness | NO (HARD) | No consistent ω-recursive theory containing arithmetic is complete |
| ZFC consistency (provable in ZFC) | NO (HARD) | Gödel 2nd — ZFC cannot prove Con(ZFC) without escalating to a stronger theory whose consistency is itself unprovable in it |
| P vs NP open-since-1971 | NO via closed-form | 55+ yr of expert attacks; barriers (relativization Baker-Gill-Solovay 1975, natural proofs Razborov-Rudich 1994, algebrization Aaronson-Wigderson 2008) rule out broad families of techniques |
| Information-medium decay | PARTIAL | Active migration + multi-medium replication; no single artifact reaches millennium without intervention (except stone, DNA pending) |
| Linguistic drift | PARTIAL | Continual re-encoding into the current lingua franca; mathematics has TeX as a partial pivot, but TeX itself is 50 yr old |
| Institutional discontinuity | PARTIAL | Distributed open-source + DOI + Zenodo + IPFS reduces single-point failure but does not eliminate civilizational risk |
| Mathematical truth | N/A | Not a wall — eternal within fixed formal system |

---

## §4 Top-3 highest-impact unmovable walls

1. **Clay-acceptance = proof, not closed-form candidate** (HARD,
   procedural). The repo correctly labels its outputs CANDIDATE. Bridging
   to acceptance requires formal proof artifacts, not additional closed
   forms.
2. **Information-medium half-life vs millennium horizon** (HARD without
   active migration). No commercially-mature medium reaches 10³ yr
   passively except stone and (pre-commercial) DNA. Git + IPFS + Zenodo
   buys ~10²-yr-class only with continuous human stewardship.
3. **Linguistic + notation drift** (SOFT but persistent). A
   millennium-old technical document is unreadable without a specialist
   chain of custody. Mathematics partly transcends this via formal
   symbols, but informal exposition (this README, prose proofs) does
   not.

---

## §5 Caveats

- **Candidate ≠ proof.** This repo's claims of "closed-form candidates"
  are not Clay-Prize submissions. The audit does *not* evaluate
  candidate validity.
- **No n=6 lattice anchors used** (per LATTICE_POLICY §1.2). σ(6) /
  τ(6) / φ(6) algebraic identities are eternal-within-arithmetic; they
  are not the wall.
- **Long-horizon numbers are uncertain.** Institutional half-life,
  collapse rate, and language-drift rates all have wide confidence
  bands. Treat order-of-magnitude only.
- **Survivor bias is severe.** The institutions we know about for >1000
  yr (Oxford, Catholic Church) are the survivors of a population we
  cannot enumerate.

---

## §6 References

- Clay Mathematics Institute, *Millennium Prize Problems* (official rules).
- Perelman, G., *The entropy formula for the Ricci flow*, arXiv:math/0211159 (Poincaré, 2002).
- Gödel, K. (1931). *Über formal unentscheidbare Sätze der Principia Mathematica und verwandter Systeme I.* Monatshefte für Mathematik.
- Cook, S. (1971). *The complexity of theorem-proving procedures.* STOC '71. (P vs NP origin)
- Riemann, B. (1859). *Ueber die Anzahl der Primzahlen unter einer gegebenen Grösse.* Monatsberichte der Berliner Akademie. (RH origin)
- Birch, B. & Swinnerton-Dyer, P. (1965). *Notes on elliptic curves II.* J. reine angew. Math. (BSD origin)
- Baker, T., Gill, J. & Solovay, R. (1975). *Relativizations of the P =? NP question.* SIAM J. Comput.
- Razborov, A. & Rudich, S. (1994). *Natural Proofs.* J. Comput. Syst. Sci.
- Swadesh, M. (1952). *Lexico-statistic dating of prehistoric ethnic contacts.* Proceedings of the American Philosophical Society.
- Allentoft, M.E. et al. (2012). *The half-life of DNA in bone.* Proc. R. Soc. B.
- Foster, R. (2001). *Creative Destruction*, S&P-500 turnover data.
- Tainter, J. (1988). *The Collapse of Complex Societies.*
- LTO Consortium, *LTO archive lifetime specifications.*
- ARL/Library of Congress, *Acid-free paper archival lifetime estimates.*

---

*End of LIMIT_BREAKTHROUGH.md (hexa-millennium, Wave M).*
