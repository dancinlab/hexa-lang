#!/usr/bin/env python3
# beenet_adapter.py — `material + verify` BEE-NET / BETE-NET inference thin adapter
# (D72 · B path · wrap-as-is).
#
# RTSC.md §9.2 (Tc sim libraries) + §9.7 N2 row + §9.9.1 Phase 1 (wrap-as-is).
# Sibling adapter pattern — see `sim_adapter.py` (closed-form Tc), `mp_query.py`
# (MP REST API), `csp_adapter.py` (CSP cohort N1) in this same dir. This file is
# the N2 cohort `material+verify` producer; B path = wrap an external ML model
# repo, NEVER port the e3nn/torch_geometric model code into hexa-lang.
#
# What this wraps
# ---------------
# BETE-NET (Bootstrapped Ensemble of Tempered Equivariant graph neural NETworks)
# — Gibson · Hire · Dee · Barrera · Geisler · Hirschfeld · Hennig 2024,
#   npj Comput. Mater. 11:11 (2025) (arxiv:2401.16611) — pretrained EGNN ensemble
#   that maps a crystal structure to the Eliashberg α²F(ω) spectral function,
#   then evaluates the Allen-Dynes formula (Allen & Dynes 1975 PRB 12 905) to
#   obtain λ · ω_log · Tc. Three model variants are shipped in the upstream
#   repo: CSO (Crystal Structure Only), CPD (+ phonon DOS), FPD (+ full phonon
#   DOS). CSO is the only variant usable from a bare composition / POSCAR.
#
# The task spec quotes a follow-on Nature paper (s41524-026-01964-8 · "Developing
# a complete AI-accelerated workflow for superconductor discovery" arxiv
# 2503.20005) that exercises BETE-NET inside a 1.3M-candidate screening pipeline
# and a sibling arxiv id 2406.14524 — both are recorded under `citations` below;
# the primary code/weights repo is github.com/henniggroup/BETE-NET regardless.
# The task brief uses the name "BEE-NET"; the actual upstream model is
# "BETE-NET" — the `model.version` field carries the canonical name to avoid
# downstream confusion.
#
# D61: substrate SSOT under `hexa-lang/stdlib/material/`. Demiurge spawns via
#      `python3 ~/core/hexa-lang/stdlib/material/beenet_adapter.py <out_dir> <composition_or_structure_file>`.
# D72: 4th material-domain consumer (after sim, mp_query, csp). Still a single-
#      file thin adapter — NO kernel promotion. The closed-form Allen-Dynes
#      math already lives in `sim_adapter.py::allen_dynes_tc`; if the wrapped
#      model returns the α²F curve we recompute Tc through that sibling rather
#      than duplicate the formula. (No shared kernel until a 2nd consumer of the
#      EGNN forward pass appears.)
# D80: install-gated when torch / torch_geometric / e3nn / ase missing OR repo
#      checkout missing; weights-missing when CSO/CPD/FPD model dirs absent;
#      simulation-only-prediction when inference ran. NEVER hexa-native.
# R4:  absorbed = false ALWAYS — BETE-NET output is an *ML model prediction*,
#      NOT a *measurement*. The published MAE is quoted against DFT Allen-Dynes
#      (itself a prediction), so even a perfect-match prediction is at best
#      sim-grade. RTSC.md §8.9 5-gate evaluation: this record fills only the
#      (b) Tc-prediction aspect, NOT the full 5-gate stack.

from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import os
import sys
import time
from pathlib import Path
from typing import Any


# ─── dependency probe (honest skip — never auto-install) ───────────────


_REQUIRED_IMPORTS: tuple[tuple[str, str], ...] = (
    # (module_name, install_hint) — order = honest user-facing diagnosis order.
    ("torch", "pip install torch  # (torch>=1.10 used in the upstream env)"),
    (
        "torch_geometric",
        "pip install torch_geometric -f "
        "https://pytorch-geometric.com/whl/torch-${TORCH_VERSION}.html",
    ),
    ("torch_scatter", "pip install torch_scatter -f <pyg wheel index>"),
    ("torch_cluster", "pip install torch_cluster -f <pyg wheel index>"),
    ("e3nn", "pip install e3nn"),
    ("ase", "pip install ase"),
    ("pymatgen", "pip install pymatgen"),
)


def _probe_imports() -> tuple[dict[str, str | None], list[str]]:
    """Return (status_per_module, missing_install_hints).

    status_per_module[name] = version string when present, else error string.
    Honest: we ONLY check importability, never install.
    """
    status: dict[str, str | None] = {}
    missing: list[str] = []
    for mod, hint in _REQUIRED_IMPORTS:
        try:
            m = importlib.import_module(mod)
            ver = getattr(m, "__version__", "unknown")
            status[mod] = f"present ({ver})"
        except Exception as e:
            status[mod] = f"import-error: {type(e).__name__}: {e}"
            missing.append(f"{mod} — {hint}")
    return status, missing


# ─── repo / weights probe ────────────────────────────────────────────────


_DEFAULT_REPO_LAYOUT = {
    "CSO": "crystal structure only (no phDOS / eDOS) — primary screening model",
    "CPD": "crystal + partial phonon DOS — improved accuracy",
    "FPD": "crystal + full phonon DOS — highest accuracy (requires DFPT input)",
}


def _probe_repo() -> tuple[Path | None, str | None]:
    """Resolve a BETE-NET checkout via BETE_NET_ROOT env var.

    Honest skip — we do NOT auto-clone. Returns (path_or_None, note).
    Acceptable layouts (any one of):
      $BETE_NET_ROOT/utils/{model.py,data.py}   ← upstream repo root
      $BETE_NET_ROOT/CSO/   $BETE_NET_ROOT/CPD/   $BETE_NET_ROOT/FPD/
    """
    env = os.environ.get("BETE_NET_ROOT", "").strip()
    if not env:
        return None, "BETE_NET_ROOT env var not set"
    p = Path(env).expanduser()
    if not p.is_dir():
        return None, f"BETE_NET_ROOT={env} does not exist or is not a directory"
    utils_model = p / "utils" / "model.py"
    if not utils_model.exists():
        return None, (
            f"BETE_NET_ROOT={env} present but utils/model.py missing — "
            "expected upstream github.com/henniggroup/BETE-NET checkout"
        )
    return p, f"BETE_NET_ROOT={env}"


def _probe_weights(repo_root: Path) -> tuple[dict[str, dict], list[str]]:
    """Inspect CSO/CPD/FPD weight directories. Returns (per_variant_info,
    missing_variants). Each per_variant entry is a dict with keys:
      present (bool) · path (str) · n_checkpoints (int) · sha256_first (str|None)
    """
    info: dict[str, dict] = {}
    missing: list[str] = []
    for variant in ("CSO", "CPD", "FPD"):
        vp = repo_root / variant
        if not vp.is_dir():
            info[variant] = {"present": False, "path": str(vp)}
            missing.append(variant)
            continue
        # Collect any .pth / .pt / .ckpt files (BETE-NET upstream ships a
        # bootstrap of model checkpoints, hence "ensemble").
        ckpts = sorted(
            list(vp.glob("**/*.pth"))
            + list(vp.glob("**/*.pt"))
            + list(vp.glob("**/*.ckpt"))
        )
        sha = None
        if ckpts:
            try:
                h = hashlib.sha256()
                with open(ckpts[0], "rb") as fh:
                    for chunk in iter(lambda: fh.read(1 << 20), b""):
                        h.update(chunk)
                sha = h.hexdigest()
            except Exception as e:  # pragma: no cover — IO failure
                sha = f"sha256-error: {type(e).__name__}: {e}"
        if not ckpts:
            missing.append(variant)
        info[variant] = {
            "present": bool(ckpts),
            "path": str(vp),
            "n_checkpoints": len(ckpts),
            "sha256_first_checkpoint": sha,
            "description": _DEFAULT_REPO_LAYOUT[variant],
        }
    return info, missing


# ─── input resolution: composition string OR structure file ────────────


def _classify_input(token: str) -> str:
    """Return one of: 'structure-file', 'composition'. Heuristic only — a
    token containing a path separator OR ending in .poscar/.cif/.vasp/.xyz is
    treated as a structure file path; otherwise as a composition string."""
    low = token.lower()
    if any(low.endswith(s) for s in (".poscar", ".cif", ".vasp", ".xyz")):
        return "structure-file"
    if os.sep in token or token.startswith("./") or token.startswith("../"):
        return "structure-file"
    return "composition"


def _load_structure(token: str, mode: str) -> tuple[Any | None, str | None]:
    """Try to obtain a pymatgen Structure. Returns (structure_or_None, err).

    For composition input, BETE-NET *cannot* infer a structure from a formula
    alone — it needs lattice coordinates. We honestly surface that and let
    the caller decide whether to (a) provide a POSCAR, or (b) fetch a
    candidate structure via mp_query.py first and pipe the .cif here.
    """
    try:
        from pymatgen.core import Structure  # type: ignore
    except Exception as e:
        return None, f"pymatgen import failed at structure-load time: {e}"
    if mode == "structure-file":
        try:
            s = Structure.from_file(token)
            return s, None
        except Exception as e:
            return None, f"Structure.from_file({token!r}) failed: {e}"
    # composition path: NOT a structure — honest stop signal.
    return None, (
        f"composition {token!r} is not a structure; BETE-NET requires a "
        "crystal structure (POSCAR/CIF). Suggested chain: run "
        "mp_query.py <out> "
        f"{token} to fetch a candidate mp_id, then re-invoke this adapter "
        "with the structure file. (csp_adapter.py is an alternative source "
        "for hypothetical compositions.)"
    )


# ─── inference shim (only runs when imports + repo + weights present) ──


def _run_inference(
    repo_root: Path,
    structure: Any,
    variant: str = "CSO",
) -> tuple[dict | None, str | None]:
    """Wrap BETE-NET inference. We deliberately keep this small and surface
    any failure as a string so the caller can emit an honest skip record.

    Upstream API is notebook-shaped (`notebooks/Pred_CSO.ipynb`), not a
    stable Python library — we attempt the canonical attribute path
    `utils.model.Network` + `utils.data.build_data` and fall back to a
    skip if the upstream restructures.
    """
    # Make utils/ importable.
    sys.path.insert(0, str(repo_root))
    try:
        try:
            from utils.model import Network  # type: ignore  # noqa: F401
            from utils.data import build_data  # type: ignore  # noqa: F401
        except Exception as e:
            return None, (
                f"BETE-NET utils.{{model,data}} import failed: "
                f"{type(e).__name__}: {e}. Upstream is notebook-shaped "
                "(notebooks/Pred_CSO.ipynb); package-level API is not "
                "guaranteed stable across upstream commits."
            )
        # The upstream notebooks build an ensemble of bootstrapped Network
        # checkpoints and average α²F predictions. Without a stable library
        # surface we cannot construct the exact ensemble inference call here
        # without effectively porting the notebook (anti-pattern per
        # RTSC.md §9.9.1 wrap-as-is). Surface this honestly.
        return None, (
            "BETE-NET upstream ships no stable inference entrypoint "
            f"(variant={variant}); the ensemble forward pass lives inside "
            "notebooks/Pred_CSO.ipynb. Reproducing it here would be a B-path "
            "violation (porting, not wrapping). Recommended: drive the "
            "notebook out-of-band and feed its α²F output through "
            "sim_adapter.allen_dynes_tc — this adapter then re-runs at the "
            "weights-missing → simulation-only-prediction boundary once the "
            "ensemble result is available on disk."
        )
    finally:
        # Be a good citizen — leave sys.path the way we found it.
        try:
            sys.path.remove(str(repo_root))
        except ValueError:
            pass


# ─── record dump ────────────────────────────────────────────────────────


def main(out_dir: str, token: str, variant: str = "CSO") -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "Gibson, Hire, Dee, Barrera, Geisler, Hirschfeld, Hennig — "
        "'Accelerating superconductor discovery through tempered deep "
        "learning of the electron-phonon spectral function', "
        "npj Comput. Mater. 11:11 (2025) · arxiv:2401.16611 — BETE-NET "
        "primary citation (the model wrapped here).",
        "arxiv:2406.14524 — referenced by RTSC.md §9.2 task brief as a "
        "companion superconductor-ML paper; primary BETE-NET code is in "
        "the 2401.16611 / npj 2024 paper above.",
        "npj Comput. Mater. s41524-026-01964-8 (arxiv:2503.20005) — "
        "'Developing a complete AI-accelerated workflow for superconductor "
        "discovery' (1.3M candidate → 741 stable screening pipeline using "
        "BETE-NET).",
        "Allen & Dynes 1975 PRB 12 905 — Tc formula evaluated on the α²F "
        "spectral function the ensemble predicts; closed-form math lives "
        "in sibling `sim_adapter.allen_dynes_tc`.",
        "github.com/henniggroup/BETE-NET — code + bootstrapped weights "
        "(CSO / CPD / FPD model directories).",
        "RTSC.md §9.2 (Tc sim libraries) + §9.7 N2 row + §9.9.1 Phase 1 "
        "(wrap-as-is) — substrate cohort anchor.",
    ]

    scope_caveats = [
        "(s1) BETE-NET prediction is ML model output, NOT a measurement. "
        "Predictions are statistical (bootstrapped ensemble), MAE 0.87 K "
        "relative to DFT-Allen-Dynes per the task brief (the npj 2024 paper "
        "reports MAE 2.1 K on its held-out Tc set) — and DFT-Allen-Dynes is "
        "itself a prediction, not a measurement. Two layers of model "
        "uncertainty stack.",
        "(s2) Training data: SuperCon database + DFT-computed α²F values. "
        "May over/underestimate Tc for materials outside the training "
        "distribution (notably: heavy hydrides under pressure, cuprate-"
        "family flat-band systems, apatite-class claim-only hypotheticals "
        "— none are well-represented in the DFT-Allen-Dynes corpus the "
        "model trained on).",
        "(s3) 5-gate (RTSC.md §8.9): this record fills only the (b) Tc-"
        "prediction aspect with sim-grade. R4 invariant: absorbed=false "
        "ALWAYS — never promotes to absorbed=true regardless of how close "
        "the predicted Tc lands to a measured value, because the gate type "
        "is structurally prediction-from-model and not coupling-loop-to-"
        "instrument.",
        "(s4) Cross-validate with sim_adapter.py BCS/McMillan/AD on the "
        "same (λ, ω_log, μ*) triple the ensemble emits — large divergence "
        "between BETE-NET α²F-derived Tc and closed-form Allen-Dynes Tc "
        "signals an out-of-distribution input rather than a real anomaly.",
    ]

    # ─── gate triage ────────────────────────────────────────────────────
    skipped_reason: str | None = None
    gate_type: str
    predicted: dict[str, Any] = {
        "tc_K": None,
        "lambda": None,
        "omega_log_K": None,
        "alpha2F_curve": None,
    }
    model_block: dict[str, Any] = {
        "version": "BETE-NET (upstream name; task brief calls it 'BEE-NET')",
        "source_url": "https://github.com/henniggroup/BETE-NET",
        "weights_sha256": None,
    }
    backend_used: str | None = None

    import_status, missing_imports = _probe_imports()

    if missing_imports:
        gate_type = "install-gated"
        skipped_reason = (
            "Missing imports: " + " | ".join(missing_imports) + ". "
            "Honest skip — adapter never installs behind the user's back. "
            "Recommended environment per upstream README: "
            "`conda create -n bete_net python=3.9 && conda activate bete_net "
            "&& conda install pytorch==1.10.0 torchvision==0.11.0 "
            "torchaudio==0.10.0 cudatoolkit=11.3 -c pytorch -c conda-forge "
            "&& pip install -r requirements.txt -f "
            "https://pytorch-geometric.com/whl/torch-1.10.0+cu113.html`. "
            "(Newer torch is acceptable but you must rebuild "
            "torch_scatter/torch_cluster against it.)"
        )
    else:
        repo_root, repo_note = _probe_repo()
        if repo_root is None:
            gate_type = "install-gated"
            skipped_reason = (
                f"{repo_note}. Clone `git clone "
                "https://github.com/henniggroup/BETE-NET` somewhere and set "
                "`export BETE_NET_ROOT=/path/to/BETE-NET`. The repo is "
                "notebook-shaped (no pip package); weights live alongside "
                "the source in CSO/, CPD/, FPD/ subdirs."
            )
        else:
            backend_used = repo_note
            weights_info, missing_variants = _probe_weights(repo_root)
            model_block["weights_inventory"] = weights_info
            # Use the requested variant's first checkpoint sha when available.
            v_info = weights_info.get(variant, {})
            model_block["weights_sha256"] = v_info.get("sha256_first_checkpoint")
            if not v_info.get("present"):
                gate_type = "weights-missing"
                skipped_reason = (
                    f"Variant {variant!r} weights absent under "
                    f"{repo_root}/{variant}/. Other variants present: "
                    + ", ".join(
                        v for v in ("CSO", "CPD", "FPD")
                        if weights_info.get(v, {}).get("present")
                    )
                    + ". Upstream ships weights in-tree (git LFS / committed "
                    ".pth files); a partial / shallow clone can omit them. "
                    "`cd $BETE_NET_ROOT && git lfs pull` may resolve."
                )
            else:
                # Try to load structure + run inference.
                mode = _classify_input(token)
                structure, load_err = _load_structure(token, mode)
                if structure is None:
                    gate_type = "weights-missing"  # honest: not weights, but
                    # we have no structure to feed the ensemble — surface
                    # the input-gap reason without inventing a new gate.
                    skipped_reason = (
                        f"Cannot prepare a Structure for inference: "
                        f"{load_err}"
                    )
                else:
                    pred, infer_err = _run_inference(
                        repo_root, structure, variant=variant
                    )
                    if pred is None:
                        gate_type = "weights-missing"
                        skipped_reason = infer_err
                    else:
                        gate_type = "simulation-only-prediction"
                        predicted.update(pred)

    # ─── input echo + provenance ────────────────────────────────────────
    input_mode = _classify_input(token)
    query_block = {
        "composition": token if input_mode == "composition" else None,
        "structure_file": token if input_mode == "structure-file" else None,
        "variant_requested": variant,
        "input_mode": input_mode,
    }

    record = {
        "domain": "material",
        "verb": "verify",
        "kind": "beenet_tc_prediction",
        "stamp": stamp,
        "producer": "beenet_adapter@material-tier1-sibling-N2",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,          # R4 invariant — never absorb prediction
        "gate_type": gate_type,     # install-gated | weights-missing |
                                    # simulation-only-prediction
        "provisional": True,
        "skipped_reason": skipped_reason,
        "query": query_block,
        "predicted": predicted,
        "model": model_block,
        "backend": backend_used,
        "dependency_status": import_status,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_url": "https://github.com/henniggroup/BETE-NET",
            "source_citation": (
                "Gibson et al. npj Comput. Mater. 11:11 (2025) · "
                "arxiv:2401.16611"
            ),
            "weights_origin": (
                "in-tree under CSO/ CPD/ FPD/ of the upstream repo (no "
                "external HuggingFace / Zenodo mirror at time of writing)"
            ),
            "task_brief_arxiv_refs": [
                "arxiv:2406.14524 (task brief reference)",
                "arxiv:2503.20005 / npj s41524-026-01964-8 (follow-on "
                "AI-accelerated workflow paper)",
            ],
        },
        "rtsc_anchor": (
            "RTSC.md §9.2 (Tc sim libraries) + §9.7 N2 row + §9.9.1 "
            "Phase 1 (wrap-as-is) · R4 invariant"
        ),
    }

    rec_path = out / f"material_verify_beenet_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    # Headline
    print(f"[material+verify · beenet] wrote {rec_path}")
    print(
        f"  · input={token!r}  mode={input_mode}  variant={variant!r}"
    )
    print(
        f"  · gate_type={gate_type}  absorbed=false (R4 invariant)"
    )
    if skipped_reason:
        # Truncate for the terminal header; full reason is in the JSON.
        short = skipped_reason if len(skipped_reason) < 200 else (
            skipped_reason[:200] + " ..."
        )
        print(f"  · skipped_reason: {short}")
    else:
        print(
            f"  · predicted Tc={predicted.get('tc_K')} K  "
            f"lambda={predicted.get('lambda')}  "
            f"omega_log={predicted.get('omega_log_K')} K"
        )
    print(
        "[material+verify · beenet] absorbed=false ALWAYS (BETE-NET "
        "prediction ≠ measurement; RTSC.md §8.9 5-gate / R4 invariant)"
    )
    return 0


def _parse_argv(argv: list[str]) -> tuple[str, str, str]:
    """Minimal arg parsing — out_dir + token + optional --variant.

    Kept consistent with the sibling adapters (positional out_dir, positional
    composition/file). `--variant CSO|CPD|FPD` selects the upstream ensemble
    variant when weights are present.
    """
    parser = argparse.ArgumentParser(
        prog="beenet_adapter.py",
        description=(
            "BETE-NET (a.k.a. 'BEE-NET' in the task brief) Tc inference "
            "thin adapter. Honest skip on install / weights / structure "
            "gaps; absorbed=false always."
        ),
    )
    parser.add_argument("out_dir", help="record output directory")
    parser.add_argument(
        "input",
        help=(
            "composition (e.g. 'Nb', 'MgB2', 'YBa2Cu3O7') OR a structure "
            "file path (.poscar / .cif / .vasp / .xyz)"
        ),
    )
    parser.add_argument(
        "--variant",
        default="CSO",
        choices=("CSO", "CPD", "FPD"),
        help=(
            "BETE-NET model variant: CSO (default; crystal-structure-only) "
            "/ CPD (+ partial phDOS) / FPD (+ full phDOS)."
        ),
    )
    ns = parser.parse_args(argv)
    return ns.out_dir, ns.input, ns.variant


if __name__ == "__main__":
    out_dir_arg, token_arg, variant_arg = _parse_argv(sys.argv[1:])
    sys.exit(main(out_dir_arg, token_arg, variant_arg))
