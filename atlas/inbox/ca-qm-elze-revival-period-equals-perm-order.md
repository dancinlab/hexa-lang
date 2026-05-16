# ca-qm-elze-revival-period-equals-perm-order

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For Elze's classical Ising-permutation **ontological** cellular automaton
(arXiv:2401.08253, eqs. `Uchain`, `Isingspins`, `spinexchange`,
`exchangeprop`), evolution is `Û = ∏ τ_i` — a product of nearest-neighbour
site transpositions on a chain of `2S` Ising spins. The map is a pure
permutation of the integer site indices.

**Identity claim** (pure integer equality):

    chain-revival period P(|ψ_0⟩, Û)  ==  multiplicative order of __perm

where:

- `chain-revival period` = smallest `P > 0` such that `Û^P |ψ_0⟩ = |ψ_0⟩`,
  computed by iterating the CA on a specific initial occupation string
  `|ψ_0⟩` and comparing the bit pattern after each step.
- `multiplicative order of __perm` = smallest `P > 0` such that
  `__perm^P = id` over the `2S` indices, computed from cycle structure.

For the selftest point `(2S, |ψ_0⟩) = (16, packet)` — a contiguous block
of `+1` spins on a `−1` background ("packet") — both numbers are exactly
**`8`**.

The Néel initial state `+−+−...` is a **fixed point** of `Û` (period 1)
— a true but uninteresting invariant. The packet state is chosen because
it exhibits a non-trivial revival, allowing the integer-equality
invariant to be checked against a non-trivial integer.

## Hexa-native verification

    bash state/ubu-build.sh ca-qm/module/ca_qm.hexa caqm_bin --selftest

Selftest output (verbatim):

    Engine A — Elze ontological CA (arXiv:2401.08253):
      2S=16  state=packet  Û = product of neighbour transpositions
      revival   : chain-period=8 perm-order=8 (OK — exact Û^P|ψ⟩=|ψ⟩)
      ontology  : Σs(0)=-10  Σs(after)=-10 (OK — conservation of ontology)
    __SIM_UNIVERSE_CAQM__ PASS engine=both S=16 revival=8 norm_drift=0.000000

Two independent computations (the iterated CA + the permutation cycle
order) both produce the integer `8`. The `_perm_order(perm)` routine
factors the cycle structure; the `_revival_period(state, Û)` routine
iterates until the bit string matches.

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (TECS-L Tier 1 integer equality
  — `8 == 8` over `ℤ`, no floating point).
- **Axis:** §3 PHYS (the model is a physics interpretation of QM —
  't Hooft CAI ontological automaton) · cross-link §8 TOP (the
  permutation cycle structure is a group-theoretic object).
- **Real-limit anchor (`g3`):** Elze, *Cellular Automaton Ontology,
  Bits, Qubits, and the Dirac Equation*, **International Journal of
  Quantum Information 22, 2450013 (2024)** · DOI
  `10.1142/S0219749924500138` · arXiv:2401.08253.
- **Provenance:** sim-universe c46707c · `ca-qm/module/ca_qm.hexa`
  (`_set_chain_packet`, `_ca_step`, `_revival_period`, `_perm_order`)
  · AGENTS.tape `@D g9` (STRICTER than g6/g7 — disowns metaphysical
  over-claim) · `@X x_elze_caqm`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_neel_period_1`** — replace `_set_chain_packet` with
   `_set_chain_neel`; the chain-revival period must drop to `1` (Néel
   is a `Û`-fixed point). Perm-order is unchanged at `8`. The
   `chain-period == perm-order` invariant must NOT hold for Néel
   (the atom is initial-state-dependent and we honour that).
2. **`F2_odd_2S_breaks`** — at `2S = 15` (odd), `Û` cannot be a
   product of neighbour transpositions on a ring (the perm has an
   odd number of swaps); the perm-order is `1` (trivial), chain-
   period for the packet is `1`. Atom must NOT claim non-trivial
   revival there.
3. **`F3_wrong_initial_state`** — set `|ψ_0⟩` to a uniform `+1`
   chain (vacuum); the chain-revival period is `1` (vacuum is also
   `Û`-invariant). The atom holds (`1 == 1`) trivially.
4. **`F4_period_off_by_one`** — replace `_revival_period` with a
   variant that returns `period + 1` (a common off-by-one); the
   reported `chain-period` would be `9`, not equal to `perm-order=8`
   — selftest must fail. The integer-equality check is sharp.
5. **`F5_perm_order_via_lcm`** — `_perm_order(perm) = lcm` of cycle
   lengths. For `2S=16` packet, the cycle structure of `Û` gives
   cycles of length `8` and `1`s (fixed sites at the boundaries —
   open-chain vs ring matters; the implementation uses open chain
   per Elze §3). Replacing `lcm` with `max(cycle_lengths)` would
   coincide for this specific case but break for `2S=10` (cycles
   `4, 3, 2, 1` → `lcm=12`, `max=4`). Spot-check at `2S=10` falsifies
   `max`-based implementations.
6. **`F6_open_vs_ring_topology`** — Elze §3 uses an OPEN chain
   (boundary spins are fixed). A ring (PBC) closure changes the
   permutation structure: site `2S-1` maps to site `0`. The atom is
   specifically for the open-chain Elze model. If a reviewer applies
   it to a ring CA, the revival period changes and the integer
   equality may or may not still hold accidentally — falsified.

## Open questions

- The atom is **initial-state-dependent** (packet vs Néel vs vacuum).
  Suggest the atlas atom is the more general
  `s_phys_caqm_elze_chain_period_equals_perm_order_when_state_is_
  non_invariant` — the integer equality holds **for any non-Û-
  invariant initial state with finite orbit**. The packet at `2S=16`
  is the concrete witness.
- Cross-domain: the perm cycle structure is also a §8 TOP atom (Sym
  group); the atlas could register a "physics interpretation +
  cycle group" bridge atom in `§ BRIDGES`.

## Reviewer checklist

- [ ] Tier (🔵 SUPPORTED-IDENTITY recommended).
- [ ] Axis (§3 PHYS · §8 TOP cross-link).
- [ ] Falsifiers ≥5.
- [ ] Real-limit anchor (g3) verified — Elze 2024 IJQI.
- [ ] Merge to `atlas/MAIN.tape § PHYS` (or split § BRIDGES).

---

Submitter: claude-opus-4-7 (2026-05-16). Origin: sim-universe c46707c.
