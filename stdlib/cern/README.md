# `stdlib/cern/` — CERN domain producers (HEP / accelerator-physics)

> **Status: Stage 1 substrate only.** Two Python producer scripts are
> live; `.hexa.stub` markers track the Stage 2 hexa-native re-derivation
> path per demiurge `ABSORPTION.md` §"hexa 포팅 단계".
> `measurement_gate = GATE_OPEN` + `absorbed = false` ALWAYS until Stage
> 3 parity GREEN.

The CERN domain (`demiurge/domains/cern.md` — particle accelerators,
detector physics) and the antimatter domain (`demiurge/domains/antimatter.md`
— positron/antiproton trap design, PET cyclotrons) share the high-energy-
physics tool stack. The Geant4 + ROOT pair is the canonical *verify*-
verb tool for both, so the producers in this directory serve the
`cern + verify` cell (and, by symmetry, ground-truth shielding numbers
the antimatter cell would consume in a Stage-3 hand-off).

## Module index

| file | purpose | Stage | substrate / re-derivation |
|---|---|---|---|
| `lhe_stats.py`             | pylhe LHE-event-stats producer (`cern + analyze`, demiurge κ-44 / D66) | Stage 1 substrate | scikit-hep `pylhe` round-trip on a synthetic e⁺e⁻ → Z → µ⁺µ⁻ sample |
| `bethe_bloch_stopping.py`  | particle + Bethe-Bloch antiproton stopping-power producer (`cern + verify`, demiurge κ-42 / D65) | Stage 1 substrate | PDG eq. 34.5 closed-form on PDG-aggregated masses, uproot-emitted ROOT histograms |
| `bethe_bloch_stopping.hexa.stub` | Stage 2 hexa-native re-derivation marker for the dE/dx producer | Stage 2 skeleton | TBD — body lands when Stage 3 parity (byte-identical CSV vs Python substrate) is set up |

## Why Stage 1 = Python here, not hexa-native

The hexa-first principle (`hexa-first` in wilson's identity tape +
demiurge `AGENTS.tape`) asks for `.hexa` modules whenever feasible. For
the HEP tool stack the *external libraries* (`pylhe`, `particle`,
`uproot`) carry decades of accelerator-experiment calibration / format
validation, and the demiurge ABSORPTION.md §"hexa 포팅 단계" explicitly
sanctions a Python substrate as Stage 1 because the four omissions vs
full Geant4 MC (shell corrections, density effect, straggling, nuclear
stopping) make the absorbed-claim contingent on parity testing, not on
re-implementing the formula.

For Bethe-Bloch specifically (closed-form, no MC), Stage 2 hexa-native
port is ⭐⭐⭐ — feasible — because the body is a small block of arithmetic
once antiproton mass + electron mass + K are atlas-pinned. The
`bethe_bloch_stopping.hexa.stub` lays out that Stage 2 target. Stage 3
parity gate = byte-identical CSV between the substrate and the hexa
native re-derivation (Bethe-Bloch is deterministic, so the parity
floor is float64 round-off ≤ 1e-12 relative, not a Monte-Carlo
tolerance).

## CLEAN-ROOM provenance (demiurge design.md Decision 1)

Neither producer re-derives or copies any Geant4 source. The producers
consume PDG-aggregated public-surface measured constants + the PDG
*Review of Particle Physics* eq. 34.5 (Bethe-Bloch mean stopping
power), and round-trip data through the public APIs of `pylhe` /
`particle` / `uproot` (BSD-3 / public). The substrate values ARE real
measured physics; the demiurge record IS NOT a demiurge measurement —
provenance pins the producer to the upstream library identity, and
`measurement_gate` stays `GATE_OPEN` until Stage 3.

## Cross-host parity (Stage 1)

The `bethe_bloch_stopping.py` substrate is deterministic: same
(particle@v, formula, inputs) → byte-identical CSV. Verified
cross-host on demiurge κ-42:

| host     | python  | particle | uproot | sha256(CSV) |
|----------|---------|----------|--------|---|
| mac local | 3.14.4 | 0.26.2   | 5.7.4  | `b7c8c46f44bea3555d28e4266389055fe2a0380be3e8a455aadd729b0a687806` |
| ubu-1    | 3.12.3  | 0.26.2   | 5.7.4  | `b7c8c46f44bea3555d28e4266389055fe2a0380be3e8a455aadd729b0a687806` |

This is the parity floor Stage 3 (hexa-native re-derivation) must
preserve.
