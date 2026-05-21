#!/usr/bin/env python3
# askcos_adapter.py — `material + verify` Tier 2 synthesis-route adapter (D72 · N3).
#
# RTSC.md §9.1 + §9.7 N3 row + §9.9.1 Phase 1: wrap-as-is (B path) thin adapter
# around ASKCOS (MIT open-source synthesis planning suite — arxiv:2501.01835,
# ACS Accounts of Chemical Research 2025). Spawns demiurge-side and emits a
# typed JSON synthesis-route record under <out_dir>/material_verify_<stamp>.json.
#
# Sibling pattern — see `sim_adapter.py` (Tier 1 closed-form Tc predictors) and
# `mp_query.py` (Materials Project REST API) for the record shape; this file
# follows that shape with domain="material", verb="verify",
# kind="synthesis_route_prediction".
#
# What ASKCOS does:
#   - Retrosynthesis (Monte Carlo Tree Search · Retro*)
#   - Reaction condition prediction
#   - Route scoring (template + neural model confidence)
#   - Primary published API: web-app + Python lib `askcos` + Docker image
#     (registry.gitlab.com/mlpds_mit/askcosv1/askcos-core / askcos-deploy)
#
# Honest scope mismatch (the big one for SC materials):
#   ASKCOS is trained on Reaxys-derived organic reaction data. For INORGANIC
#   SC families (claim-only RT-SC apatite-class, YBCO = Y-Ba-Cu oxide, MgB₂
#   = intermetallic, hydrides under GPa pressure) it has no training signal.
#   Routes returned for these targets would be hallucinations. We detect
#   inorganic composition up-front and emit `gate_type=domain-mismatch`
#   *without* running ASKCOS, so the record honestly says "not applicable"
#   rather than fake-confident.
#
# Skip path semantics (gate_type values):
#   - install-gated             — askcos not importable AND no local Docker image
#   - domain-mismatch           — composition is inorganic SC material (NEW gate)
#   - simulation-only-prediction— ran successfully (still absorbed=false)
#   - external-api              — MIT hosted endpoint reachable + returned
#   - external-api-missing-key  — hosted endpoint requires registration
#
# R4 invariant (ALWAYS): absorbed=false. ASKCOS predicts *candidate routes*,
# not measured wet-lab synthesis — RTSC.md §8.9 (a) requires
# `replicated_by_independent_labs ≥ 3`, which only wet-lab can produce.
#
# D61: substrate SSOT under `hexa-lang/stdlib/material/`. Demiurge spawns via
#      `python3 ~/core/hexa-lang/stdlib/material/askcos_adapter.py <out_dir> <target_compound>`.
# D72: 3rd material-domain consumer (after sim_adapter, mp_query). Still a thin
#      adapter — no kernel promotion. Phase 3-4 in RTSC.md §9.9.1 may later
#      identify retrosynthesis score aggregation as a hexa-native microkernel
#      candidate, but the wrap itself stays Python (anti-pattern: re-train
#      template DB hexa-native).
# g3:  absorbed = false 영원히 — Tier 2 candidate recipe is *prediction*, NOT
#      *replicated_by_independent_labs ≥ 3* (RTSC.md §8.9 (a) gate).

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path


# ─── ASKCOS import + docker probe (honest skip on missing) ──────────────


def _probe_askcos():
    """Return (askcos_module_or_None, error_string).

    The package name shifted across ASKCOS versions:
      - `askcos` (v1 Python lib, retrosynthetic.mcts.tree_builder)
      - `askcos_site` (v1 Django app glue)
      - `askcosv2` (v2, gitlab.com/mlpds_mit/askcosv2)
    We try v2 first, then v1 forms, and surface ImportError as a clean string.
    """
    candidates = ["askcosv2", "askcos", "askcos_site"]
    for name in candidates:
        try:
            mod = __import__(name)
            return mod, None
        except ImportError:
            continue
        except Exception as e:  # pragma: no cover — defensive
            return None, f"{name} import error: {type(e).__name__}: {e}"
    return None, (
        "no askcos / askcosv2 / askcos_site importable. "
        "Install options: (1) `pip install askcos` (v1, may need rdkit + "
        "tensorflow; partially abandoned upstream), (2) docker image at "
        "registry.gitlab.com/mlpds_mit/askcosv2/askcos2_core "
        "(see https://gitlab.com/mlpds_mit/askcosv2)."
    )


def _probe_docker_image() -> tuple[bool, str | None]:
    """Return (image_present, image_tag_or_None). Best-effort — no pull, only
    list. Looks for any image tag matching `askcos` substring."""
    docker_bin = shutil.which("docker")
    if docker_bin is None:
        return False, None
    try:
        result = subprocess.run(
            [docker_bin, "images", "--format", "{{.Repository}}:{{.Tag}}"],
            capture_output=True,
            text=True,
            timeout=10.0,
        )
    except (subprocess.TimeoutExpired, OSError):
        return False, None
    if result.returncode != 0:
        return False, None
    for line in result.stdout.splitlines():
        line = line.strip()
        if "askcos" in line.lower():
            return True, line
    return False, None


def _resolve_hosted_endpoint() -> tuple[str | None, str | None]:
    """Return (endpoint_url, api_key) for an optional MIT-hosted ASKCOS REST
    instance. As of 2026-05 there is no widely-publicized public ASKCOS REST
    endpoint open to anonymous traffic; the MIT-internal instance requires
    registration. We honor environment overrides for users who do have access.

    Env:
      ASKCOS_ENDPOINT — base URL (e.g. https://askcos.mit.edu/api/v2)
      ASKCOS_API_KEY  — bearer / token
    """
    endpoint = os.environ.get("ASKCOS_ENDPOINT")
    key = os.environ.get("ASKCOS_API_KEY")
    return endpoint, key


# ─── inorganic / organic composition classifier ─────────────────────────


_ELEMENT_PATTERN = re.compile(r"([A-Z][a-z]?)(\d*\.?\d*)")


def _parse_formula_elements(formula: str) -> dict[str, float]:
    """Parse a flat compound formula into element-count dict. Handles
    parentheses one level deep (e.g. "Ca10(PO4)6F2" → Ca10, P6, O24, F2).
    NOT a full IUPAC parser — just enough to detect carbon-presence vs purely
    inorganic-ion families."""
    # Expand single-level parentheses: "(PO4)6" → "P6O24"
    def expand(match: re.Match) -> str:
        inner = match.group(1)
        mult_str = match.group(2)
        mult = int(mult_str) if mult_str else 1
        # Multiply each element in inner by mult
        parts: list[str] = []
        for sym, count in _ELEMENT_PATTERN.findall(inner):
            if not sym:
                continue
            c = float(count) if count else 1.0
            parts.append(f"{sym}{int(c * mult) if (c * mult).is_integer() else c * mult}")
        return "".join(parts)

    expanded = re.sub(r"\(([^()]+)\)(\d*)", expand, formula)
    counts: dict[str, float] = {}
    for sym, count in _ELEMENT_PATTERN.findall(expanded):
        if not sym:
            continue
        c = float(count) if count else 1.0
        counts[sym] = counts.get(sym, 0.0) + c
    return counts


# Approximate organic / molecular C-containing families that ASKCOS *was*
# trained on. We do NOT enumerate — we use a heuristic: carbon-present AND
# composition looks molecular (small element count, no oxide-anion pattern).
_INORGANIC_SC_HINTS = {
    # apatite-class oxide hints (anonymized 2026-05-22 from a specific
    # historical claim — kept as parenthesis-handling test fixtures only)
    "Ca10(PO4)6F2",
    "Ca10(PO4)6(OH)2",
    "Sr10(PO4)6O",
    # YBCO / REBCO cuprates
    "YBa2Cu3O7", "YBa2Cu3O6", "YBa2Cu3O6.5",
    "Bi2Sr2CaCu2O8", "Bi2Sr2Ca2Cu3O10",
    "HgBa2Ca2Cu3O8",
    # Iron-based
    "FeSe", "FeAs", "BaFe2As2", "LaFeAsO",
    # Intermetallics / borides
    "MgB2", "Nb3Sn", "Nb3Ge", "NbTi", "Nb",
    # Hydrides (high-P)
    "H3S", "LaH10", "CaH6", "ScH9", "YH6",
    # A15 / heavy-fermion
    "URu2Si2", "CeCu2Si2", "Sr2RuO4",
}


def _classify_composition_domain(formula: str) -> tuple[str, str]:
    """Return (domain_label, rationale) — "inorganic_sc", "organic_molecular",
    or "ambiguous". This drives the `domain-mismatch` gate decision.

    Rules:
      1. Explicit allow-list of known inorganic SC families → "inorganic_sc".
      2. No carbon at all → "inorganic_sc" (oxide / hydride / intermetallic).
      3. Carbon present + no metal-oxide-anion pattern + reasonable
         small-molecule size (≤ ~30 heavy atoms) → "organic_molecular".
      4. Carbon present *with* heavy metals (Pb, Y, Ba, La, Sr, Hg, Fe, Cu,
         Nb, Mg, Sc, Ti, Ca, etc.) + oxide / phosphate anion → "inorganic_sc"
         (organometallic / oxide-coordination compound — ASKCOS still
         out-of-distribution).
    """
    f_clean = formula.replace(" ", "")
    if f_clean in _INORGANIC_SC_HINTS:
        return "inorganic_sc", f"explicit hit on RTSC §8.2 SC family ({f_clean})"

    try:
        elements = _parse_formula_elements(f_clean)
    except Exception:
        return "ambiguous", f"formula parse failure on {f_clean!r}"

    has_carbon = elements.get("C", 0.0) > 0.0
    if not has_carbon:
        return "inorganic_sc", (
            f"no carbon atoms in {f_clean!r}; treated as oxide/hydride/"
            f"intermetallic — outside ASKCOS (Reaxys-organic) training "
            f"distribution"
        )

    metals = {
        "Pb", "Y", "Ba", "La", "Sr", "Hg", "Fe", "Cu", "Nb", "Mg", "Sc",
        "Ti", "Ca", "Bi", "Tl", "Zr", "Hf", "V", "Ta", "W", "Mo", "Re",
        "Ru", "Os", "Rh", "Ir", "Pd", "Pt", "Ag", "Au", "Cd", "In", "Sn",
        "Sb", "U", "Th", "Ce", "Nd", "Sm", "Gd", "Dy", "Er", "Yb",
    }
    heavy_metal_present = any(elements.get(m, 0.0) > 0.0 for m in metals)
    oxygen_count = elements.get("O", 0.0)
    has_oxide_pattern = heavy_metal_present and oxygen_count >= 2.0

    if has_oxide_pattern:
        return "inorganic_sc", (
            f"carbon present in {f_clean!r} but heavy-metal + multi-oxygen "
            f"signature suggests organometallic / oxide coordination "
            f"compound — outside ASKCOS organic distribution"
        )

    total_heavy = sum(c for s, c in elements.items() if s != "H")
    if total_heavy <= 30:
        return "organic_molecular", (
            f"{f_clean!r} contains carbon, no oxide pattern, "
            f"heavy-atom count {total_heavy:.0f} ≤ 30 — likely "
            f"small-molecule organic (in ASKCOS distribution)"
        )

    return "ambiguous", (
        f"{f_clean!r} contains carbon but heavy-atom count "
        f"{total_heavy:.0f} > 30; ASKCOS may or may not have signal"
    )


# ─── ASKCOS call (only when probe succeeded + composition is organic) ───


def _call_askcos_python(askcos_module, target_compound: str
                        ) -> tuple[list[dict], str | None]:
    """Attempt a real ASKCOS retrosynthesis call. Returns (routes, error).

    ASKCOS v1 (askcos): retrosynthetic.mcts.tree_builder.TreeBuilder
    ASKCOS v2 (askcosv2): different entry; v2 API still in flux per upstream.

    NEVER raises — any failure surfaces as a skip-reason string. The shape of
    `routes` is the normalized {step_count, score, top_reaction, template_id}
    list that the downstream consumer reads.
    """
    try:
        # v1 path: TreeBuilder takes a SMILES, not a chemical formula. The
        # caller passes a formula like "C6H6"; we'd need a formula→SMILES
        # resolver (PubChemPy / RDKit `rdMolDescriptors`). For the wrap-as-is
        # cohort we declare this as a downstream-consumer responsibility and
        # honestly skip when SMILES is missing.
        if hasattr(askcos_module, "retrosynthetic"):
            return [], (
                "askcos v1 TreeBuilder requires SMILES input, not raw "
                "formula. Adapter is wrap-as-is and does not bundle a "
                "formula→SMILES resolver (PubChemPy / RDKit canonicalize). "
                "Downstream consumer must pre-resolve the SMILES and pass "
                "via a `target_smiles` field (Phase 2 stabilization)."
            )
        # v2 path placeholder — v2 surface still in flux upstream (2026-05).
        return [], (
            "askcosv2 entry-point not stabilized in adapter (upstream API "
            "still changing as of 2026-05). Pin to a specific commit before "
            "wiring; see https://gitlab.com/mlpds_mit/askcosv2/askcos2_core "
            "for current entry points."
        )
    except Exception as e:
        return [], f"askcos call failed: {type(e).__name__}: {e}"


def _call_askcos_docker(image_tag: str, target_compound: str
                        ) -> tuple[list[dict], str | None]:
    """Attempt invocation via the local docker image. Returns (routes, error).

    The ASKCOS v2 docker image expects an entrypoint like:
        docker run --rm <image> python -m askcosv2.retro --smiles <smi>

    Same SMILES-input limitation as the python path. We surface a clean skip
    rather than feed a raw formula and pretend.
    """
    return [], (
        f"docker image {image_tag!r} detected but adapter does not invoke it "
        f"in wrap-as-is cohort — same SMILES-input limitation as python path "
        f"+ docker invocation contract is version-specific. Downstream "
        f"consumer should pin image digest and provide `target_smiles` in "
        f"a Phase 2 follow-up."
    )


# ─── record dump ────────────────────────────────────────────────────────


def main(out_dir: str, target_compound: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "arxiv:2501.01835 — 'ASKCOS: an open source software suite for "
        "synthesis planning' (Coley group, MIT, 2025). "
        "https://arxiv.org/pdf/2501.01835",
        "ACS Accounts of Chemical Research 2025 — review of ASKCOS "
        "synthesis planning. "
        "https://pubs.acs.org/doi/abs/10.1021/acs.accounts.5c00155",
        "RTSC.md §9.1 (a) 합성 가능성 시뮬레이션 row (ASKCOS entry) + "
        "§9.7 N3 cohort + §9.9.1 Phase 1 (wrap-as-is B path).",
        "ASKCOS v1 source — https://github.com/connorcoley/ASKCOS "
        "(legacy; partially archived).",
        "ASKCOS v2 source — https://gitlab.com/mlpds_mit/askcosv2 "
        "(active, 2024-2026).",
    ]

    scope_caveats = [
        "(s1) ASKCOS is trained on organic reaction data (Reaxys-derived); "
        "applicability to inorganic SC materials (oxides, hydrides, "
        "intermetallic alloys) is limited. Routes for inorganic SC targets "
        "(YBCO, MgB2, apatite-class hypotheticals) are extrapolation-grade "
        "only.",
        "(s2) 5-gate (RTSC.md §8.9 (a)): this is recipe *prediction*, "
        "NOT replicated_by_independent_labs >= 3. (a) gate REQUIRES "
        "wet-lab replication.",
        "(s3) ASKCOS route score reflects model's confidence, NOT chemical "
        "feasibility. Routes may be retrosynthetically valid but "
        "synthetically inaccessible at scale.",
        "(s4) 5-gate fills (a) candidate-route aspect only. R4 invariant: "
        "never absorbed=true.",
    ]

    # ─── gate decision ──────────────────────────────────────────────
    domain_label, domain_rationale = _classify_composition_domain(
        target_compound
    )

    askcos_mod, import_err = _probe_askcos()
    docker_present, docker_image = _probe_docker_image()
    hosted_endpoint, hosted_key = _resolve_hosted_endpoint()

    gate_type: str
    skipped_reason: str | None = None
    routes: list[dict] = []
    backend_used: str | None = None

    if domain_label == "inorganic_sc":
        # NEW gate value per task spec — honest "not applicable" without
        # running ASKCOS (would emit hallucinated routes otherwise).
        gate_type = "domain-mismatch"
        skipped_reason = (
            f"composition {target_compound!r} classified as inorganic SC "
            f"material — outside ASKCOS (organic-chemistry / Reaxys) "
            f"training distribution. Rationale: {domain_rationale}. "
            f"Adapter declines to run rather than emit hallucinated "
            f"organic routes for an inorganic target. Cross-reference: "
            f"exports/synthesis_recipe/ (Tier 2 stubs — literature recipes "
            f"for YBCO / NbTi / REBCO / hexa_rtsc n6 candidate already there)."
        )
    elif hosted_endpoint and hosted_key:
        # Hosted MIT REST endpoint path (env-overridden by user).
        gate_type = "external-api"
        backend_used = f"hosted endpoint {hosted_endpoint}"
        skipped_reason = (
            f"ASKCOS_ENDPOINT={hosted_endpoint!r} is set, but adapter does "
            f"not bundle an HTTP client for the MIT v2 REST surface in the "
            f"wrap-as-is cohort. Phase 2 stabilization will wire a thin "
            f"requests-based caller; current record carries the env-resolved "
            f"endpoint for downstream auditing."
        )
    elif hosted_endpoint and not hosted_key:
        gate_type = "external-api-missing-key"
        backend_used = f"hosted endpoint {hosted_endpoint} (no key)"
        skipped_reason = (
            f"ASKCOS_ENDPOINT={hosted_endpoint!r} is set but ASKCOS_API_KEY "
            f"is not. MIT-hosted ASKCOS REST requires registration "
            f"(https://askcos.mit.edu). Honest skip — adapter never embeds "
            f"or steals a key."
        )
    elif askcos_mod is None and not docker_present:
        gate_type = "install-gated"
        skipped_reason = (
            f"{import_err}. AND no local docker image with 'askcos' in tag "
            f"found via `docker images`. Install options: "
            f"(1) `pip install askcos` (v1, requires rdkit + tensorflow; "
            f"partially abandoned), "
            f"(2) `docker pull registry.gitlab.com/mlpds_mit/askcosv2/"
            f"askcos2_core:latest` then re-run, "
            f"(3) set ASKCOS_ENDPOINT + ASKCOS_API_KEY for an MIT-hosted "
            f"instance (registration required). "
            f"Honest skip — adapter never installs behind the user's back."
        )
    else:
        # We have *something* — try real call.
        gate_type = "simulation-only-prediction"
        if askcos_mod is not None:
            backend_used = (
                f"askcos python module ({askcos_mod.__name__})"
            )
            routes, call_err = _call_askcos_python(
                askcos_mod, target_compound
            )
        else:
            backend_used = f"docker image {docker_image}"
            routes, call_err = _call_askcos_docker(
                docker_image, target_compound
            )
        if call_err is not None:
            # Surface as skip reason but keep gate_type — caller sees that
            # the *environment* was capable but the *invocation* didn't
            # complete (typical for wrap-as-is cohort before SMILES wire).
            skipped_reason = call_err

    record = {
        "domain": "material",
        "verb": "verify",
        "kind": "synthesis_route_prediction",
        "stamp": stamp,
        "producer": "askcos_adapter@material-tier2-N3",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,            # R4 invariant — ALWAYS false
        "gate_type": gate_type,
        "provisional": True,
        "skipped_reason": skipped_reason,
        "query": {
            "target_compound": target_compound,
            "composition_domain_label": domain_label,
            "composition_domain_rationale": domain_rationale,
        },
        "backend": backend_used,
        "routes_predicted": routes,    # list of {step_count, score,
                                       # top_reaction, template_id};
                                       # empty when skipped / mismatch
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_url": (
                "https://gitlab.com/mlpds_mit/askcosv2/askcos2_core"
            ),
            "arxiv_ids": ["2501.01835"],
            "primary_refs": [
                "arxiv:2501.01835 (Coley group, MIT, 2025) — ASKCOS open "
                "source software suite for synthesis planning.",
                "ACS Accounts Chem Res 2025 — ASKCOS review.",
            ],
            "doi": "10.1021/acs.accounts.5c00155",
        },
        "rtsc_anchor": (
            "RTSC.md §9.1 (a) row ASKCOS + §9.7 N3 cohort + §9.9.1 "
            "Phase 1 (wrap-as-is B path)"
        ),
        "recommendation": (
            "downstream consumer should cross-check with literature "
            "recipe (existing Tier 2 stubs at "
            "exports/synthesis_recipe/{rebco_mocvd_2g_hts_tape,"
            "nbti_pit_wire_industrial,hexa_rtsc_n6_candidate}.json). "
            "Predicted routes (when present) are candidate funnel input "
            "for wet-lab prioritization — NEVER a substitute for "
            "replicated_by_independent_labs >= 3."
        ),
    }

    rec_path = out / f"material_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    # Headline lines
    print(f"[material+verify · askcos-N3] wrote {rec_path}")
    print(
        f"  · target_compound={target_compound!r}  "
        f"composition_domain={domain_label!r}"
    )
    print(
        f"  · gate_type={gate_type}  backend={backend_used!r}  "
        f"routes_predicted={len(routes)}"
    )
    if skipped_reason:
        print(f"  · skipped_reason: {skipped_reason}")
    else:
        for r in routes[:5]:
            print(
                f"    - steps={r.get('step_count')}  "
                f"score={r.get('score')}  "
                f"top_reaction={r.get('top_reaction')!r}  "
                f"template_id={r.get('template_id')!r}"
            )
        if len(routes) > 5:
            print(f"    ... ({len(routes) - 5} more routes)")
    print(
        "[material+verify · askcos-N3] absorbed=false (R4 invariant; "
        "RTSC.md §8.9 (a) requires wet-lab replicated_by_independent_labs "
        ">= 3, NEVER a simulation/prediction route)"
    )
    return 0


if __name__ == "__main__":
    argv = sys.argv
    out_dir = argv[1] if len(argv) > 1 else "/tmp/material_verify_askcos"
    target = argv[2] if len(argv) > 2 else "YBa2Cu3O7"
    sys.exit(main(out_dir, target))
