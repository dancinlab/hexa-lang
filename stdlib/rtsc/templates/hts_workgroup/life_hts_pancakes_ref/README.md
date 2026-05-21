# life-hts / pancakesHPhi / pancakes_ref — stacked HTS pancake coil (h-φ reference)

> External reference model — provenance manifest only.
> `absorbed=false` · status: **[skipped: license unclear]**

## Provenance

| field | value |
|---|---|
| upstream repo | https://gitlab.onelab.info/life-hts/life-hts |
| upstream path | `pancakesHPhi/pancakes_ref/` (on branch `master`; benchmark introduced for EUCAS 2025 paper) |
| upstream files (3 .pro + 1 .msh) | `pancakes_ref.pro`, `../common/pancakes_data.pro`, `../common/pancakes_functions.pro`, `pancakes_ref_5.100.msh` |
| project page | https://www.life-hts.uliege.be/ |
| workgroup mirror | https://htsmodelling.com/model-files/getdp-scripts-for-simulating |
| license | **unclear** — `git ls-files` on master shows **no `LICENSE` / `COPYING` / `COPYRIGHT` file**; only research-paper citations in `README.md`. Default copyright reserved by L. Denis, B. Vanderheyden, C. Geuzaine (U. Liège). GetDP itself is GPLv2+, but that does not propagate to user model files. |
| access date | 2026-05-21 |
| observed master HEAD | `d935381b79598be11caa91961e023ebeb67727b1` ("paper reference") |

## Geometry summary

Stack of two pancakes (top + bottom, with a symmetry plane), each pancake = 100 REBCO tapes stacked radially. Operating per Berrospe et al. SUST 2021 benchmark geometry:

- 2 × 100 tapes per coil cross-section
- tape geometry resolved individually in the `pancakes_ref` (conventional / reference) model
- 2-D Cartesian cross-section (poloidal cut through the racetrack midplane)

The `pancakes_hom`, `pancakes_fw`, `pancakes_smsts`, `pancakes_smsts_ta` sibling dirs implement progressively more aggressive homogenization on the same geometry.

## Formulation

**h-φ conventional** (h-field in conducting regions, magnetic scalar potential φ in air), full discretization of each tape. This is the *reference* against which the homogenized siblings are validated.

Reference paper: Dular, J. *et al.* IEEE TASC, 2020 (full citation in upstream README).

## Dimension

**2-D Cartesian** (not axisymmetric). Each tape modeled with finite cross-section + thin-shell edges per the h-φ thin-shell convention.

## Required parameters (from upstream `pancakes_data.pro` + paper)

The geometry/material constants are defined in `pancakesHPhi/common/pancakes_data.pro` (we do not vendor it). Per the upstream `README.md` + Berrospe SUST 2021:

- REBCO power-law E-J: `E = E_c (|J|/Jc)^n`, E_c = 1e-4 V/m
- field-dependent Jc(B) per Kim-Anderson or anisotropic table (specifics in `common/pancakes_functions.pro`)
- transport current waveform: sinusoidal at 50 Hz, I/Ic = 0.5
- GetDP runtime: 4.0.0 (commit `a2503553f1e2713ffda7f22fc6d4d0e0c68ee0eb`), PETSc 3.23.4 + MUMPS 5.7.3 + MPI

## Canonical citations

- L. Denis, B. Vanderheyden, C. Geuzaine. *Simultaneous Multi-Scale Homogeneous H-Phi Thin-Shell Model for Efficient Simulations of Stacked HTS Coils.* Submitted Oct. 2025, EUCAS 2025.
- E. Berrospe-Juarez et al. *Real-time simulation of large-scale HTS systems …* SuST 2021 (benchmark origin).
- J. Dular, C. Geuzaine, B. Vanderheyden. *Finite Element Formulations for Systems with High-Temperature Superconductors.* IEEE TASC, 2020. DOI 10.1109/TASC.2019.2935429
- B. de Sousa Alves et al. *h-φ thin-shell formulation.* SuST 2021.

## Fetch instructions

`./fetch.sh` clones the upstream repo into a local `_external/` cache (gitignored — see this dir's `.gitignore`). It does NOT copy any file into our tracked tree. After fetch, the actual `.pro` files live at `_external/life-hts/pancakesHPhi/pancakes_ref/pancakes_ref.pro` and can be inspected / simulated locally.

## Smoke-test verdict

Locally-cloned upstream parses through the include chain but **requires GetDP 4.0.0** — fails on our `getdp-3.5.0-MacOSX` at `lib/lawsAndFunctions.pro:67` (`Unknown Function: RhoPowerLaw`). `RhoPowerLaw` is a GetDP-4 built-in absent in 3.5.0. This is consistent with the upstream `README.md` claim ("All simulations were run with GetDP 4.0.0"). Affected models: `pancakes_ref`, `tape`, `cylinder` — all share `lib/lawsAndFunctions.pro`.

To exercise the upstream reference, upgrade GetDP to 4.0.0 (commit `a2503553f1e2713ffda7f22fc6d4d0e0c68ee0eb` per upstream README) and run:

```bash
./fetch.sh   # clones life-hts master into _external/
<getdp-4.0.0> _external/life-hts/pancakesHPhi/pancakes_ref/pancakes_ref.pro \
    -msh _external/life-hts/pancakesHPhi/pancakes_ref/pancakes_ref_5.100.msh \
    -solve MagDyn -v 3 2>&1 | head -5
```

Smoke check on 2026-05-21 (GetDP 3.5.0): `Error : '../lib/lawsAndFunctions.pro', line 67 : Unknown Function: RhoPowerLaw` — *expected* for a 3.5.0 host, **not** a syntax error in upstream files. .pro parser path is clean.
