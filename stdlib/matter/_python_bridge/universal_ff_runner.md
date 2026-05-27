# `universal_ff_runner.py` — Phase K.1 unified NNP runner

> **Created**: 2026-05-14 (Phase K.1) · **Status**: INFRASTRUCTURE-ONLY · **Author**: 박민우 <nerve011235@gmail.com>
> **Module**: [`_python_bridge/universal_ff_runner.py`](universal_ff_runner.py)
> **Selftest gate**: [`selftest/universal_ff_runner_smoke.sh`](../selftest/universal_ff_runner_smoke.sh) (gate #38)

---

## Purpose

`universal_ff_runner.py` is the single entry point for running the five
universal force-field NNPs (MACE / CHGNet / ALIGNN / SchNet / M3GNet) locally
against the 17 SIM-NNP-PROXY candidates vendored under
`_absorption_bridge/universal_ff/predictions/*.json`.

Phase K.1 lands the **infrastructure only** — the module loads cleanly,
exposes a unified `run_universal_ff(candidate_id, model, structure=None)`
function, and SKIPs cleanly when an optional dep is missing. Phase K.2 (a
separate, explicitly-user-triggered commit) will land the 7 Tier-1 actual
runs that promote those candidates' status row from `SIM-NNP-PROXY` to
`SIM-NNP` (real local computation) when 5/5 NNPs cooperate AND the
proxy-match falls inside the ±20 % relative tolerance.

---

## SIM-NNP vs SIM-NNP-PROXY (NOVEL.md §2 distinction)

| Status tag       | Meaning                                                                                            | Promotes to EXTERNAL-VERIFIED? |
|------------------|----------------------------------------------------------------------------------------------------|-------------------------------|

Both are SIM tags. **Neither** crosses the EXTERNAL-VERIFIED boundary —
that requires an attributed external-lab measurement on the candidate's

---

## Optional-dep installation

| Model     | Package         | License        | Install                          |
|-----------|-----------------|----------------|----------------------------------|
| MACE      | `mace-torch`    | MIT            | `pip install mace-torch`         |
| CHGNet    | `chgnet`        | BSD-3-Clause   | `pip install chgnet`             |
| ALIGNN    | `alignn`        | MIT            | `pip install alignn`             |
| SchNet    | `schnetpack`    | MIT            | `pip install schnetpack`         |
| M3GNet    | `matgl`         | BSD-3-Clause   | `pip install matgl`              |

All five are torch-backed; on Apple Silicon, install torch via the
official wheel (`pip install torch`) first.

---


Every record returned by `run_universal_ff()` carries:

- `is_measurement: false` — model output is **computation**, not measurement.
- `is_external_verification: false` — running an NNP locally does **not**
  satisfy the external-lab attribution requirement for `EXTERNAL-VERIFIED`.
- `n6_lattice_fit_applied: false` — NNPs publish their **own** error bars
  (Batatia 2022 force MAE 20–60 meV/Å typical); no n=6 lattice-fit is
  applied to model outputs.

The `--selftest` path is **mock-only** — it force-SKIPs every optional dep
so CI never imports torch or downloads a checkpoint. Live runs require a
deliberate user action (Phase K.2).

---

## Citations

- **MACE** — Batatia, I. et al. *MACE: Higher Order Equivariant Message
  Passing Neural Networks for Fast and Accurate Force Fields*. NeurIPS 2022
  ([arXiv:2206.07697](https://arxiv.org/abs/2206.07697)).
- **CHGNet** — Deng, B. et al. *CHGNet as a pretrained universal neural
  network potential for charge-informed atomistic modelling*.
  Nat. Mach. Intell. **5**, 1031–1041 (2023).
- **ALIGNN** — Choudhary, K. & DeCost, B. *Atomistic line graph neural
  network for improved materials property predictions*. npj Comput. Mater.
  **7**, 185 (2021).
- **SchNet** — Schütt, K. T. et al. *SchNet — A deep learning architecture
  for molecules and materials*. J. Chem. Phys. **148**, 241722 (2018).
- **M3GNet** — Chen, C. & Ong, S. P. *A universal graph deep learning
  interatomic potential for the periodic table*. Nat. Comput. Sci. **2**,
  718–728 (2022).

---

*Phase K.1 authored 2026-05-14 by 박민우 <nerve011235@gmail.com>;
co-defined with Claude Opus 4.7 (1M context). Sister-of-pattern:
`_python_bridge/module/ase_atoms_construct.py` (optional-dep SKIP discipline)
+ `_absorption_bridge/universal_ff/mace_call.py` (per-model adapter shape).*
