# `stdlib/cern/` — CERN domain producers (HEP / accelerator-physics)

> **Status: `cern + verify` at Stage 3 parity GREEN (hexa-native).**
> The Bethe-Bloch dE/dx producer has a Stage 1 Python substrate AND a
> Stage 2 hexa-native re-derivation (`bethe_bloch_stopping.hexa`); the
> in-file selftest confirms numeric parity (4/4 reference points,
> relerr ≤ 4e-10). `cern + analyze` (`lhe_stats.py`) is still Stage 1
> substrate only.
> **Stage 3 GREEN ≠ absorbed.** `measurement_gate = GATE_OPEN` +
> `absorbed = false` STILL hold — Stage 3 only proves the hexa port
> matches the Python substrate (both omit the same four Geant4-MC
> corrections). `absorbed = true` needs Stage 4: a Geant4-MC parity
> round (shell corrections, density effect, straggling, nuclear
> stopping). See demiurge `ABSORPTION.md` §"hexa 포팅 단계".

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
| `bethe_bloch_stopping.hexa` | hexa-native re-derivation of the dE/dx producer + in-file Stage 3 parity selftest | Stage 2 + Stage 3 GREEN | PDG eq. 34.5 closed-form, masses folded as compile-time constants (no run-time `particle` dep) |
| `bethe_bloch_stopping.hexa.stub` | original Stage 2 skeleton / contract (kept per booksim `*.hexa` + `*.hexa.stub` convention) | superseded by `.hexa` | — |

## Stage 1 substrate vs Stage 2 hexa-native

The hexa-first principle (`hexa-first` in wilson's identity tape +
demiurge `AGENTS.tape`) asks for `.hexa` modules whenever feasible. For
the HEP tool stack the *external libraries* (`pylhe`, `particle`,
`uproot`) carry decades of accelerator-experiment calibration / format
validation, so the demiurge ABSORPTION.md §"hexa 포팅 단계" sanctions a
Python substrate as Stage 1.

For Bethe-Bloch specifically (closed-form, no MC) the Stage 2 hexa-
native port was ⭐⭐⭐ — feasible — because the body is a small block of
arithmetic once antiproton mass + electron mass + K are folded as
compile-time constants. `bethe_bloch_stopping.hexa` is that port: it
imports only `stdlib/core/math/float` (libm `sqrt` / `log`), carries no
run-time `particle` dependency, and exposes an in-file `selftest()`.

Stage 3 parity is **numeric**, not byte-identical text: hexa's `str()`
float formatting differs from Python's `%.10g`, so the gate compares
the dE/dx *values* within 1e-6 relative. Measured this session:

| reference point | substrate dE/dx | hexa dE/dx | rel-err |
|---|---|---|---|
| Al @ 1 MeV   | 178.824652   | 178.824652  | 7.8e-11 |
| Al @ 1 GeV   | 1.766629737  | 1.766629737 | 2.7e-10 |
| Pb @ 100 MeV | 3.609992692  | 3.609992692 | 9.6e-11 |
| Pb @ 1 GeV   | 1.196980424  | 1.196980424 | 4.1e-10 |

The ~1e-10 floor (not 1e-12) is the libm-`log` spread between CPython's
`math.log` and hexa's runtime shim — ~10 significant digits of
agreement, four orders inside tolerance. `selftest()` returns
exit 0 on 4/4 PASS, exit 90 (rfc_048 gate-unmet) otherwise.

## CLEAN-ROOM provenance (demiurge design.md Decision 1)

Neither producer re-derives or copies any Geant4 source. The producers
consume PDG-aggregated public-surface measured constants + the PDG
*Review of Particle Physics* eq. 34.5 (Bethe-Bloch mean stopping
power), and round-trip data through the public APIs of `pylhe` /
`particle` / `uproot` (BSD-3 / public). The substrate values ARE real
measured physics; the demiurge record IS NOT a demiurge measurement —
provenance pins the producer to the upstream library identity, and
`measurement_gate` stays `GATE_OPEN`. Stage 3 GREEN does NOT flip it:
the hexa port reproducing the substrate proves the *formula* is
hexa-owned, not that the *physics* is absorbed — both still omit the
four Geant4-MC corrections.

## Cross-host parity (Stage 1 substrate)

The `bethe_bloch_stopping.py` substrate is deterministic: same
(particle@v, formula, inputs) → byte-identical CSV. Verified
cross-host on demiurge κ-42:

| host     | python  | particle | uproot | sha256(CSV) |
|----------|---------|----------|--------|---|
| mac local | 3.14.4 | 0.26.2   | 5.7.4  | `b7c8c46f44bea3555d28e4266389055fe2a0380be3e8a455aadd729b0a687806` |
| ubu-1    | 3.12.3  | 0.26.2   | 5.7.4  | `b7c8c46f44bea3555d28e4266389055fe2a0380be3e8a455aadd729b0a687806` |

The Stage 2 `bethe_bloch_stopping.hexa` re-derivation matches this
substrate numerically (table above) — `hexa run
stdlib/cern/bethe_bloch_stopping.hexa` reproduces the 28-row sweep and
self-validates the four pinned reference points.
