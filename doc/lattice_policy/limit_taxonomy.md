<!-- absorbed from ~/core/hexa-bio/LIMIT_BREAKTHROUGH.md (Apache-2.0, hexa-bio v1.1.0) -->

# Limit-class taxonomy — 4-way classification for real-limit audits

> Companion doc to `compiler/lattice_policy/limit_class.hexa` and
> [`LATTICE_POLICY.md`](../../LATTICE_POLICY.md). Domain instance and
> rationale phrases summarised from the hexa-bio v1.1.0 real-limits audit;
> the original verbatim audit lives at `~/core/hexa-bio/LIMIT_BREAKTHROUGH.md`.

Every real-limit anchor in a `LATTICE_POLICY.md §1.2` audit must carry one
of these four class tags. The tag fixes how the limit is allowed to enter
verification evidence, and what breakthrough vectors (if any) are legitimate.

---

## §1 The four classes

### HARD_WALL
**Definition.** Violation requires breaking known physics or biochemistry —
e.g. the speed of light `c`, Planck's constant `h-bar`, Carnot efficiency,
ATP hydrolysis free energy `~30.5 kJ/mol`, the Smoluchowski diffusion
encounter rate, the Bekenstein bound on information per unit area.

**Evidence rule.** A HARD_WALL anchor is non-negotiable. A spec that claims
to "break" it is a falsifier trigger, not a breakthrough. Only re-derivations
that stay strictly inside the physical regime count.

### SOFT_WALL
**Definition.** Engineering or economic ceiling that is improvable within
physics — pipeline-attrition figures, fab throughput, cost-per-X, regulatory
gate fail-rates. The wall is set by current organizational / capital /
infrastructure conditions, not by a conservation law.

**Evidence rule.** SOFT_WALL anchors permit "improvable N-fold by mechanism
M" claims, provided M is named, the N-fold figure is sourced, and the
improvement does not implicitly violate a co-anchored HARD_WALL.

### BREAKABLE_WITH_TECH
**Definition.** Physics permits more than current tech delivers; a named
technology vector is the gap-closer (not just incremental tuning). The
upper bound has a known direction even when the magnitude is uncertain.

**Evidence rule.** BREAKABLE_WITH_TECH requires the named tech vector to be
recorded alongside the breakthrough estimate; "improvable" without a named
mechanism collapses the claim to SOFT_WALL.

### UNCLEAR
**Definition.** Wall type not yet decidable from current evidence —
typically because the underlying mechanism is disputed, the relevant scale
is unmeasured, or only practical (not physical) bounds have been
demonstrated. Holds the slot until another audit pass resolves it.

**Evidence rule.** UNCLEAR anchors cannot carry weight in a PASS verdict;
they must be downgraded to one of the three decisive classes before any
spec relying on them can advance past honesty-caveat status.

---

## §2 Bio-domain instances (hexa-bio L1..L8)

Per `~/core/hexa-bio/LIMIT_BREAKTHROUGH.md` §2-§3, the 8 bio-domain anchors
classify as follows. These are *consumer-side* instances and remain in
hexa-bio; only the taxonomy itself is portable upstream.

| ID | Limit | Class | One-line rationale |
|----|-------|-------|--------------------|
| L1 | DNA replication fidelity (10^-9 .. 10^-10 per base) | HARD_WALL | thermodynamic discrimination + Hopfield kinetic proofreading; cannot beat without ATP, even then floor is polymerase active-site geometry |
| L2 | Enzyme k_cat/K_M ceiling (~10^8 .. 10^9 M^-1 s^-1) | HARD_WALL | Smoluchowski diffusion encounter rate; TIM / catalase / acetylcholinesterase already sit at the ceiling |
| L3 | Ribosomal translation rate (5..20 aa/s) | HARD_WALL | GTP hydrolysis + tRNA accommodation kinetics; cell-free systems give ~1.5x headroom at the cost of accuracy |
| L4 | Levinthal / Kolmogorov protein folding | UNCLEAR -> BREAKABLE_WITH_TECH | AlphaFold-class ML broke the *practical* wall; *physical* folding kinetics intact (misfolding diseases persist) |
| L5 | Caspar-Klug / Zlotnick capsid assembly Delta-G | HARD_WALL | geometry is fixed; -6..-10 kT per subunit drives WEAVE sigma(6)=12 audit, and that match is geometric vocabulary not therapeutic evidence |
| L6 | Drug discovery cost / FDA attrition ($2.6B, ~10% Phase-I->approval) | SOFT_WALL | pure pipeline engineering; improvable 3-5x via organoid screens, AI target ID, decentralized trials |
| L7 | ATP cost of macromolecular synthesis (~4 ATP/peptide bond, 25-30 ATP/nt) | HARD_WALL | ATP hydrolysis Delta-G ~ -30.5 kJ/mol thermodynamic floor; synthetic life cannot duck this without redesigning the code |
| L8 | CRISPR-Cas off-target specificity (10^-3 .. 10^-5 per locus) | BREAKABLE_WITH_TECH | prime-editor / base-editor / HiFi-Cas variants give 10..100x reduction; floor set by PAM degeneracy + DNA mismatch tolerance (= L1) |

**Per-class roll-up:**
- HARD_WALL: L1, L2, L3, L5, L7 (5 of 8 — biochemistry-forbidden majority).
- SOFT_WALL: L6 (drug-pipeline economics).
- BREAKABLE_WITH_TECH: L8 (CRISPR specificity), and L4 in its *practical* facet.
- UNCLEAR: L4-physical (folding kinetics open-ended until a kinetic theory replaces Levinthal).

---

## §3 Audit checklist

When tagging a new real-limit anchor with a `LimitClass`:

1. State the underlying physical / biochemical / engineering law in one
   sentence. If you cannot, the tag is UNCLEAR until you can.
2. If a named conservation law / fundamental constant is violated by the
   counterfactual, the tag is HARD_WALL.
3. If a named technology vector closes the gap (not just "more R&D"), the
   tag is BREAKABLE_WITH_TECH.
4. If the wall is set by capital / organization / regulation rather than
   physics, the tag is SOFT_WALL.
5. Record both the tag and the rationale phrase. The rationale is what
   downstream readers will see; the tag is what gate-checks consume.

---

*Source: hexa-bio v1.1.0 / 2026-05-12 real-limits audit (Wave M).*
*Apache-2.0 — see `~/core/hexa-bio/LICENSE` for the verbatim license text.*
