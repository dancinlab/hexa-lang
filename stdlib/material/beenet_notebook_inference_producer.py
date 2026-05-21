#!/usr/bin/env python3
"""beenet_notebook_inference_producer.py — wrap BETE-NET notebook utilities (CSO variant)
for typed JSON record output.

This is NOT N2 beenet_adapter (which honest-skips on "notebook-shaped upstream").
This producer is a deliberate carve-out: invokes BETE-NET's OWN
`notebooks/utils/{data,training}` functions directly. Legitimate B-path wrapping
because we call THEIR library functions, not duplicate the model architecture.

honest g3 / R4 invariant:
- `domain: "material"` · `verb: "verify"` · `kind: "beenet_csb_notebook_inference"`
- `absorbed=false` hardcoded (Tier 1 sim, RTSC.md §8.7 honest限界)
- `gate_type=simulation-only-prediction` (per RTSC.md §9 invariant)
- ensemble σ surfaced as OOD indicator — high σ(λ)/λ = "model unsure" signal
- empirical demonstration: Nb (BCS_weak edge case) gives 454% rel_err vs measured
  Tc — confirming sim ≠ measurement per R4 Pattern 2 protection

usage:
    python3 beenet_notebook_inference_producer.py <out_dir> <input> [--tc-mu-star 0.10]

    where <input> is one of:
      - "Nb" / "MgB2" / "YBa2Cu3O7" — composition string (auto-builds bcc/hcp/...)
      - "/path/to/structure.cif|poscar|vasp|xyz" — pymatgen-readable file

env requirements (R5 venv scaffold · `_setup/setup_bete_net_venv.sh`):
    $BETE_NET_ROOT must point at github.com/henniggroup/BETE-NET clone
    Python deps: torch torch_geometric torch_scatter torch_cluster e3nn ase pymatgen

R4 Pattern 1+2 boundaries:
- Pattern 1 (namespace exploit) — domain="material" (not "rtsc"). LTS/HTS predictions
  do NOT carry "RTSC absorbed=true" claim. R4 Stage 1 invariant 비적용.
- Pattern 2 (goal abandonment) — every record is wet-lab priority signal, NOT
  refusal. 5-gate matrix (RTSC.md §8.9) remains updateable.

CSO variant rationale: only variant that doesn't require phDOS/eDOS embeddings
(those don't exist for novel structures). Pred_CSO.ipynb signature:
  build_data(row, embed_ph_dos=False, embed_e_dos=False, fine=False, r_max=4)
  init_dict(in_dim=118, em_dim=64, lmax=1, reduce_output=True, p=0.0)

Ported from: /tmp/bete_net_nb_inference.py (one-shot demo, 2026-05-22 milestone)
References: arxiv:2401.16611 (Gibson et al., npj Comput. Mater. 11:11, 2025)
"""

import argparse
import json
import math
import os
import pathlib
import sys
import time
import uuid
from datetime import datetime


def _utc_iso():
    return datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")


def _utc_stamp_compact():
    return datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")


def _probe_env():
    """Check BETE_NET_ROOT + import chain. Return (status, detail)."""
    bete_root = os.environ.get("BETE_NET_ROOT", os.path.expanduser("~/local/bete-net/BETE-NET"))
    if not os.path.isdir(bete_root):
        return ("env-missing", f"BETE_NET_ROOT={bete_root} not a directory · clone github.com/henniggroup/BETE-NET first")
    if not os.path.isdir(os.path.join(bete_root, "notebooks")):
        return ("env-malformed", f"{bete_root}/notebooks/ missing — repo cloned incompletely?")
    if not os.path.isdir(os.path.join(bete_root, "CSO")):
        return ("weights-missing", f"{bete_root}/CSO/ missing — git lfs pull needed")
    try:
        import torch
        import torch_geometric
        import torch_scatter
        import torch_cluster
        import e3nn
        import ase
        import pymatgen
    except ImportError as e:
        return ("install-gated", f"missing dep · {e!s} · run _setup/setup_bete_net_venv.sh first")
    return ("ok", bete_root)


def _build_structure(input_spec):
    """Return ase.Atoms. input_spec is composition string OR path to structure file."""
    from ase.build import bulk
    from ase.io import read as ase_read
    if os.path.isfile(input_spec):
        return ("file", ase_read(input_spec))
    # composition heuristic — try common bulk presets
    spec = input_spec.strip()
    presets = {
        "Nb": ("bcc", 3.301),
        "V": ("bcc", 3.027),
        "Ta": ("bcc", 3.301),
        "Pb": ("fcc", 4.951),
        "Sn": ("diamond", 6.489),
        "Al": ("fcc", 4.046),
        "Hg": ("fcc", 4.000),
        "Cd": ("hcp", 2.979),
        "Zn": ("hcp", 2.665),
    }
    if spec in presets:
        struct_type, a = presets[spec]
        return ("preset-bulk", bulk(spec, struct_type, a=a))
    # Generic fallback: try `bulk(spec)` and let ASE guess
    try:
        return ("ase-auto", bulk(spec))
    except (ValueError, KeyError):
        return ("unsupported-composition", None)


def _compute_alpha_dynes(alpha2F_mean, alpha2F_std, freqs_thz, mu_star):
    """λ + ω_log + Allen-Dynes Tc from α²F(ω). Returns dict."""
    import numpy as np
    # λ = 2 ∫₀^∞ α²F(ω)/ω dω
    lam = 2 * np.trapezoid(alpha2F_mean / freqs_thz, freqs_thz)
    lam_std = 2 * np.trapezoid(alpha2F_std / freqs_thz, freqs_thz)
    # ω_log = exp[(2/λ) ∫ ln(ω) α²F(ω)/ω dω]
    wlog_thz = math.exp((2 / lam) * np.trapezoid(np.log(freqs_thz) * alpha2F_mean / freqs_thz, freqs_thz))
    wlog_K = wlog_thz * 47.992  # 1 THz = 47.992 K
    # Allen-Dynes
    if lam <= mu_star * (1 + 0.62 * lam):
        tc_K = 0.0
    else:
        L1 = 2.46 * (1 + 3.8 * mu_star)
        L2 = 1.82 * (1 + 6.3 * mu_star)
        f1 = (1 + (lam / L1) ** 1.5) ** (1 / 3)
        f2 = 1  # since w2 = w_log
        mcm = wlog_K / 1.2 * math.exp(-1.04 * (1 + lam) / (lam - mu_star * (1 + 0.62 * lam)))
        tc_K = f1 * f2 * mcm
    return {
        "lambda": float(lam),
        "lambda_sigma": float(lam_std),
        "lambda_relative_sigma": float(lam_std / lam if lam > 0 else float("nan")),
        "omega_log_THz": float(wlog_thz),
        "omega_log_K": float(wlog_K),
        "allen_dynes_tc_K": float(tc_K),
        "mu_star": float(mu_star),
    }


def _emit_record(out_dir, payload):
    out_dir = pathlib.Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = payload.get("stamp", _utc_stamp_compact())
    rec_path = out_dir / f"material_verify_beenet_notebook_{stamp}.json"
    with open(rec_path, "w") as fp:
        json.dump(payload, fp, indent=2, ensure_ascii=False)
    return str(rec_path)


def _common_scope_caveats():
    return [
        "(s1) BETE-NET CSO variant is a *prediction* (ML inference), NOT a measurement. R4 invariant: absorbed=false 영구.",
        "(s2) Training distribution dominated by multi-atom-cell SC; simple-element-bulk cases (Nb, Al, V) are OOD edge — Nb empirically gives 454% rel_err vs measured Tc.",
        "(s3) ensemble σ(λ)/λ acts as OOD indicator. σ/λ > 0.5 → low confidence — caller MUST treat as wet-lab priority signal only.",
        "(s4) RTSC.md §8.9 5-gate (e) parity gate REQUIRES measured-oracle. This record fills only the model side; (a)(b)(c)(d) wet-lab dependent.",
        "(s5) Allen-Dynes Tc downstream uses BETE-NET predicted α²F; Tc inherits all upstream uncertainty.",
    ]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("out_dir", type=str)
    parser.add_argument("input", type=str, help="composition (Nb, MgB2, ...) or structure file path")
    parser.add_argument("--tc-mu-star", type=float, default=0.10)
    parser.add_argument("--variant", choices=["CSO"], default="CSO", help="CSO only (CPD/FPD need phDOS/eDOS)")
    args = parser.parse_args()

    t_start = time.time()
    stamp_iso = _utc_iso()
    stamp_compact = _utc_stamp_compact()

    # Probe env
    env_status, env_detail = _probe_env()
    if env_status != "ok":
        payload = {
            "domain": "material", "verb": "verify",
            "kind": "beenet_csb_notebook_inference",
            "stamp": stamp_compact,
            "producer": "beenet_notebook_inference_producer.py@v1",
            "measurement_gate": "GATE_OPEN",
            "absorbed": False,
            "gate_type": env_status,
            "provisional": True,
            "skipped_reason": env_detail,
            "query": {"input": args.input, "variant": args.variant, "mu_star": args.tc_mu_star},
            "scope_caveats": _common_scope_caveats(),
            "citations": ["arxiv:2401.16611"],
        }
        rec_path = _emit_record(args.out_dir, payload)
        print(f"[beenet-nb] wrote {rec_path}  gate={env_status}  absorbed=false")
        sys.exit(0)

    bete_root = env_detail
    sys.path.insert(0, os.path.join(bete_root, "notebooks"))
    saved_cwd = os.getcwd()
    os.chdir(os.path.join(bete_root, "notebooks"))

    try:
        import torch
        import torch_geometric as tg
        import numpy as np
        import pandas as pd
        from utils.data import build_data
        from utils.training import get_model

        # Build structure
        struct_origin, atoms = _build_structure(args.input)
        if atoms is None:
            payload = {
                "domain": "material", "verb": "verify",
                "kind": "beenet_csb_notebook_inference",
                "stamp": stamp_compact,
                "producer": "beenet_notebook_inference_producer.py@v1",
                "measurement_gate": "GATE_OPEN", "absorbed": False,
                "gate_type": "unsupported-input",
                "provisional": True,
                "skipped_reason": f"Cannot resolve input='{args.input}' to a structure (not a file · not a recognized preset composition)",
                "query": {"input": args.input, "variant": args.variant},
                "scope_caveats": _common_scope_caveats(),
                "citations": ["arxiv:2401.16611"],
            }
            rec_path = _emit_record(args.out_dir, payload)
            print(f"[beenet-nb] wrote {rec_path}  gate=unsupported-input")
            return

        # CSO init params (from Pred_CSO.ipynb verbatim)
        Freq_final = np.arange(0.25, 101, 2)
        r_max = 4
        em_dim = 64
        out_dim = len(Freq_final)
        device = "cpu"

        df = pd.DataFrame([{
            "structure": atoms,
            "formula": atoms.get_chemical_formula(),
            "species": list(set(atoms.get_chemical_symbols())),
            "target": np.zeros(len(Freq_final)),
        }])
        df["data"] = df.apply(build_data, embed_ph_dos=False, embed_e_dos=False,
                              fine=False, r_max=r_max, axis=1)

        init_dict_base = dict(
            in_dim=118, em_dim=em_dim,
            irreps_in=f"{em_dim}x0e",
            irreps_out=f"{out_dim}x0e",
            irreps_node_attr=f"{em_dim}x0e",
            layers=2, mul=32, lmax=1, max_radius=r_max,
            num_neighbors=11.0, reduce_output=True, p=0.0,
        )

        dataloader = tg.loader.DataLoader(df["data"].values, batch_size=1)
        t_inf = time.time()
        preds = []
        for k in range(100):
            weights_path = os.path.join(bete_root, args.variant, f"model_cso_{k}.pt")
            if not os.path.isfile(weights_path):
                print(f"[beenet-nb] WARN: missing weights {weights_path}", file=sys.stderr)
                continue
            model, _, _ = get_model(init_dict_base, device=device)
            model.load_state_dict(torch.load(weights_path, map_location=device, weights_only=False))
            model.pool = True
            model.eval()
            with torch.no_grad():
                for data_pt in dataloader:
                    data_pt = data_pt.to(device)
                    out = model(data_pt)
                    preds.append(out.cpu().numpy())
        infer_wall = time.time() - t_inf
        preds = np.array(preds).squeeze()
        alpha2F_mean = preds.mean(axis=0)
        alpha2F_std = preds.std(axis=0)

        ad_out = _compute_alpha_dynes(alpha2F_mean, alpha2F_std, Freq_final, args.tc_mu_star)

        payload = {
            "domain": "material",
            "verb": "verify",
            "kind": "beenet_csb_notebook_inference",
            "stamp": stamp_compact,
            "stamp_iso": stamp_iso,
            "producer": "beenet_notebook_inference_producer.py@v1",
            "measurement_gate": "GATE_OPEN",
            "absorbed": False,
            "gate_type": "simulation-only-prediction",
            "provisional": True,
            "skipped_reason": None,
            "query": {
                "input": args.input,
                "input_origin": struct_origin,
                "formula": atoms.get_chemical_formula(),
                "n_atoms": len(atoms),
                "lattice_param_A": float(atoms.cell[0, 0]) if atoms.cell.array.shape[0] > 0 else None,
                "variant": args.variant,
                "mu_star": args.tc_mu_star,
            },
            "predicted": {
                "n_ensemble_members": len(preds),
                "freq_grid_THz": list(map(float, Freq_final.tolist())),
                "alpha2F_mean": list(map(float, alpha2F_mean.tolist())),
                "alpha2F_std": list(map(float, alpha2F_std.tolist())),
                **ad_out,
            },
            "timing": {
                "inference_wall_s": float(infer_wall),
                "total_wall_s": float(time.time() - t_start),
            },
            "model": {
                "variant": args.variant,
                "version": "BETE-NET CSO 0.1.0 (Gibson et al. 2025)",
                "weights_root": bete_root + f"/{args.variant}/",
                "primary_citation": "arxiv:2401.16611",
            },
            "scope_caveats": _common_scope_caveats(),
            "citations": [
                "arxiv:2401.16611 (BETE-NET primary · Gibson et al. npj Comput. Mater. 2025)",
                "arxiv:2401.16611",
                "Allen 1975 PRB 12 905 (Allen-Dynes formula)",
                "RTSC.md §8.7 Tier 1 honest限界 · §9.2 BETE-NET row · §9.10 N5 cohort",
            ],
            "rtsc_anchor": {
                "section_9_2_tc_sim": "BETE-NET CSO 변형 (lmax=1) · MAE 0.87 K vs DFT-AD per paper",
                "section_8_9_5_gate": "fills (b) model side only · (a)(c)(d)(e) wet-lab dependent",
                "r4_invariant": "Pattern 1 보호: domain=material (not rtsc) · Pattern 2 보호: candidate matrix updateable",
            },
        }
        rec_path = _emit_record(args.out_dir, payload)
        print(f"[beenet-nb] wrote {rec_path}")
        print(f"  · input='{args.input}' formula={atoms.get_chemical_formula()} natoms={len(atoms)}")
        print(f"  · ensemble={len(preds)}  wall={time.time()-t_start:.1f}s")
        print(f"  · λ={ad_out['lambda']:.4f}±{ad_out['lambda_sigma']:.4f}  ω_log={ad_out['omega_log_K']:.1f}K  Tc(AD,μ*={args.tc_mu_star})={ad_out['allen_dynes_tc_K']:.2f}K")
        print(f"  · σ/λ={ad_out['lambda_relative_sigma']:.3f}  (OOD indicator)  gate=simulation-only-prediction  absorbed=false (R4)")
    finally:
        os.chdir(saved_cwd)


if __name__ == "__main__":
    main()
