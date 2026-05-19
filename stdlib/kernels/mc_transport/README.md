# kernels/mc_transport/ — ①a Monte-Carlo transport kernel (demiurge design.md D72)

Domain-agnostic Monte-Carlo particle-transport computation kernel.
The THIRD kernel extracted under the D72 2-layer STDLIB restructure
(after `kernels/graph/` and `kernels/fem/`).

| file | role |
|---|---|
| `transport_kernel.py` | `lookup_particle` · `particle_mass_mev` · `relativistic_kinematics` · `max_energy_transfer_mev` · `bethe_bloch_dedx` · `stopping_range` · `ensure_particle` · `particle_version` — given a projectile spec + a stopping medium, compute the deterministic particle-physics facts. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No CERN shielding
  short-list, no antiparticle PET context. Pure "PDG id / projectile
  + medium + KE in -> particle data / kinematics / dE/dx / range out".
- **①b adapter** — `stdlib/cern/bethe_bloch_stopping.py` (CERN-style
  shielding materials, antiproton projectile, ELENA-scale KE grid)
  and `stdlib/antimatter/pdg_lookup.py` (antiparticle short-list, PET
  / Penning-trap context). Each owns its domain particle list /
  material tables / honesty caveats and calls this kernel for the
  physics.

## API

- `ensure_particle()` / `particle_version()` — import + version probe
  for the scikit-hep `particle` library (recovers from the macOS
  Homebrew user-site layout; raises on a genuine miss — g3).
- `lookup_particle(pdg_id)` — PDG-aggregated measured constants for
  one particle: `{ pdg_id, name, pdg_name, mass_mev, mass_lower_mev,
  mass_upper_mev, charge, lifetime_s, ctau_m, width_pdg_units,
  spin_type, is_self_conjugate, anti_flag }`. `lifetime_s` / `ctau_m`
  are `None` for stable particles.
- `particle_mass_mev(pdg_id)` — convenience: the PDG mass (MeV/c²).
- `relativistic_kinematics(ke_mev, mass_mev)` — exact special
  relativity: `{ gamma, beta, beta2, beta_gamma, momentum_mev,
  total_energy_mev }`.
- `max_energy_transfer_mev(ke_mev, mass_mev, electron_mass_mev)` —
  T_max, the single-collision relativistic energy-transfer ceiling
  (PDG eq. 34.4).
- `bethe_bloch_dedx(ke_mev, projectile_mass_mev, projectile_charge,
  target_z, target_a_gpermol, target_i_ev, electron_mass_mev)` — PDG
  Bethe-Bloch mean mass stopping power (eq. 34.5, δ = 0). Returns
  `{ beta, gamma, beta_gamma, tmax_mev, dedx_mevcm2_per_g }`.
- `stopping_range(...)` — CSDA range, the trapezoidal integral of
  1/(dE/dx) above a low-energy floor. Returns `{ range_g_per_cm2,
  ke_mev, ke_floor_mev, n_steps }`.

## Why

`cern+verify` (Bethe-Bloch stopping power) and `antimatter+analyze`
(PDG particle-data lookup) both wrap the scikit-hep `particle`
library and both touch relativistic particle physics. Extracting the
shared kernel means N domains share 1 kernel (N×M -> N+M). The day a
hexa-native transport kernel re-derives these on absorbed PDG
constants — the Stage-2 hexa port `stdlib/cern/
bethe_bloch_stopping.hexa` already exists — and passes a Geant4-MC
parity round, `absorbed=true` flips HERE — once — instead of in every
domain adapter.

## Honesty (g3)

Two layers of "real":

- **PDG lookup** (`lookup_particle`) returns real measured constants
  — but a lookup is NOT a demiurge measurement.
- **Bethe-Bloch dE/dx** (`bethe_bloch_dedx`) is a real physics
  calculation on measured constants — but it omits four pieces of a
  full Geant4 MC: shell corrections, density effect δ, straggling
  distribution, nuclear stopping channel.
- **Relativistic kinematics** is exact special relativity,
  IEEE-754-deterministic.
- **`stopping_range`** is the CSDA approximation — no straggling, no
  nuclear stops, integral cut off at a low-energy floor.

The honesty gate (`measurement_gate`, `absorbed`, `scope_caveats`)
lives in the ①b adapter, NOT here. `particle` is an external library
and the formula paths slice a subset of a full Geant4 MC, so
`absorbed = false` at the record layer always.

## Callers

- `stdlib/cern/bethe_bloch_stopping.py` — antiproton dE/dx in
  CERN-style shielding materials (demiurge `cern+verify`).
- `stdlib/antimatter/pdg_lookup.py` — antiparticle PDG-data lookup
  (demiurge `antimatter+analyze`).

Each adapter locates this kernel by path relative to its own file
(`../kernels/mc_transport/`), so the `python3 <script> <output_dir>`
spawn from demiurge works regardless of cwd.
