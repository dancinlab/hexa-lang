#!/usr/bin/env python3
# n8_fusion_evap_adapter.py — `nuclear + verify` fusion-evaporation
# cross-section σ adapter for SHE synthesis (NUCLEAR.md §4.3 · N8 cohort
# · B path · wrap-as-is · Phase 5 land).
#
# NUCLEAR.md §2 (d) gate + §4.3 N8 spec + §6.3 Phase 5 land target.
# Sibling adapter shape — see `hexa-lang/stdlib/nuclear/hfbtho_adapter.py`
# (N6 wrap-as-is presence-only shape, the Phase 1 reference). N8 is the
# ★ WET-LAB-DEPENDENT gate (d): fusion-evaporation σ prediction is
# famously off by ~10× across statistical / dinuclear-system models —
# sim gives an *accelerator beam-time priority hint*, NEVER a confirmed
# cross-section. This adapter NEVER claims a measured σ.
#
# Backends (fallback chain — first present wins; all-missing → install-
# gated honest skip, which IS the PASS verdict per NUCLEAR.md §3.3):
#   1. KEWPIE2  — Vance / Hagino. Statistical-model evaporation +
#                 dynamical capture for SHE synthesis σ.
#                 Citation: arxiv:2208.11471 (SHE σ review / KEWPIE2-
#                 class analysis). Source: github.com/kewpie2 .
#   2. DNS      — Dinuclear-system model (Adamian / Antonenko, Dubna).
#                 Production σ via the dinuclear evolution picture.
#                 Citation: Adamian/Antonenko DNS publications.
#   3. HIVAP    — Statistical evaporation model (Reisdorf). Legacy
#                 Fortran; request from authors. Heavy-ion fusion-
#                 evaporation survival probabilities.
#   4. NRV      — JINR low-energy nuclear-reactions web resource
#                 (atomic-data.jinr.ru / nrv.jinr.ru). Online σ
#                 calculators — `network-fail` honest skip if offline.
#
# D72 analog: nuclear-domain consumer — single-file thin adapter.
#             NO hexa-native kernel promotion (these are statistical /
#             dynamical-evolution models, not closed-form formulas;
#             wrap-as-is forever per NUCLEAR.md §6.2 · Path A microkernel
#             port is a LATER phase if any closed-form survival-prob
#             kernel is ever identified — not this phase).
# D80 analog: install-gated when no backend found; nuclear-novel-
#             discovery-simulation when a backend ran (presence-only this
#             land — σ run-out is the Phase 5+ follow-on).
# R4 invariant: absorbed = false ALWAYS — σ output is a *model
#               prediction* with ~10× scatter, NOT a *measurement*.
#               Promotion to absorbed=true requires GSI/JINR/RIKEN
#               heavy-ion accelerator beam-time + SHIP/DGFRS/GARIS
#               recoil-separator detection of the evaporation residue +
#               IUPAC priority assignment. OUT OF SCOPE (NUCLEAR.md §7).
# Gate value: `nuclear-novel-discovery-simulation` (mirror of N6) or
#             `install-gated` (no backend / NRV network-fail).

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


# --- backend detection (PATH probe + env var + NRV network reach) -------


def _which(name: str) -> str | None:
    """shutil.which wrapper — returns absolute path or None."""
    p = shutil.which(name)
    return p if p else None


def _probe_kewpie2() -> tuple[bool, str | None, str | None]:
    """KEWPIE2 (Vance/Hagino) — statistical-model SHE sigma code.

    $KEWPIE2_BIN env var (explicit path) takes precedence; PATH
    fallback follows. Presence detection only — we do NOT launch the
    statistical-model run here (needs an entrance-channel deck + capture
    + survival sub-runs; that is the Phase 5+ follow-on, mirror of the
    N6 HFBTHO SCF-not-invoked first-land discipline).
    """
    env = os.environ.get("KEWPIE2_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"KEWPIE2_BIN={env}"
    for name in ("kewpie2", "kewpie"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_dns() -> tuple[bool, str | None, str | None]:
    """DNS dinuclear-system model (Adamian/Antonenko, Dubna). $DNS_BIN
    env or PATH probe (`dns_xsec` / `dns` typical executable names)."""
    env = os.environ.get("DNS_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"DNS_BIN={env}"
    for name in ("dns_xsec", "dns"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_hivap() -> tuple[bool, str | None, str | None]:
    """HIVAP statistical evaporation model (Reisdorf, legacy Fortran).
    $HIVAP_BIN env or PATH probe."""
    env = os.environ.get("HIVAP_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"HIVAP_BIN={env}"
    for name in ("hivap",):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


# NRV JINR online sigma calculator. Opt-in network probe — disabled by
# default (offline-first / honest). Set $NRV_PROBE=1 to allow the HEAD
# reachability check; otherwise NRV is reported absent without touching
# the network (mirror of the N6 `network-fail` honest-skip discipline).
_NRV_URL = "http://nrv.jinr.ru/nrv/"


def _probe_nrv() -> tuple[bool, str | None, str | None]:
    """JINR NRV online nuclear-reactions resource. Network probe only
    when $NRV_PROBE=1 (offline-first default). A reachable endpoint is
    reported present (the sigma run is still NOT launched — presence-only
    first land); an unreachable endpoint is `network-fail`-style absent.
    """
    if os.environ.get("NRV_PROBE", "").strip() not in ("1", "true", "yes"):
        return False, None, None
    try:
        req = urllib.request.Request(_NRV_URL, method="HEAD")
        with urllib.request.urlopen(req, timeout=4) as resp:
            code = getattr(resp, "status", None) or resp.getcode()
            if 200 <= int(code) < 400:
                return True, _NRV_URL, f"NRV reachable (HTTP {code})"
            return False, None, f"NRV HTTP {code} (treated absent)"
    except (urllib.error.URLError, OSError, ValueError) as e:
        # network-fail honest skip — endpoint down / offline.
        return False, None, f"NRV network-fail: {e}"


# Fallback chain order — KEWPIE2 first (modern statistical-model SHE
# sigma), DNS second (dinuclear-system dynamical picture), HIVAP third
# (legacy statistical evaporation), NRV fourth (online · network-gated).
_BACKENDS = (
    ("kewpie2", _probe_kewpie2),
    ("dns", _probe_dns),
    ("hivap", _probe_hivap),
    ("nrv", _probe_nrv),
)


def _detect_backend() -> tuple[str | None, str | None, str | None, dict]:
    """Walk the fallback chain. Return (name, bin_path, detection_note,
    full_probe_map). full_probe_map captures the per-backend present/
    absent state for the record's `backend_probe` field — honest
    visibility into *why* each fallback didn't fire."""
    probe_map: dict = {}
    chosen: tuple[str, str | None, str | None] | None = None
    for name, probe in _BACKENDS:
        present, bin_path, note = probe()
        probe_map[name] = {
            "present": present,
            "bin_path": bin_path,
            "detection_note": note,
        }
        if present and chosen is None:
            chosen = (name, bin_path, note)
    if chosen is None:
        return None, None, None, probe_map
    return chosen[0], chosen[1], chosen[2], probe_map


# Install hints surfaced in the skip record when no backend is found.
_INSTALL_HINTS = {
    "kewpie2": (
        "KEWPIE2 — Vance / Hagino statistical-model code for SHE "
        "fusion-evaporation sigma (capture x survival). Source: "
        "github.com/kewpie2 — build + set $KEWPIE2_BIN to the "
        "executable. Citation: arxiv:2208.11471 (SHE production "
        "cross-section review / KEWPIE2-class analysis)."
    ),
    "dns": (
        "DNS — dinuclear-system model (Adamian / Antonenko, Dubna). "
        "Production sigma via dinuclear evolution. Codes distributed "
        "via JINR publications; build + set $DNS_BIN. See JINR FLNR / "
        "Dubna code releases."
    ),
    "hivap": (
        "HIVAP — Reisdorf statistical evaporation model (legacy "
        "Fortran). Request the source from the authors / GSI; build "
        "+ set $HIVAP_BIN. Heavy-ion fusion-evaporation survival "
        "probabilities."
    ),
    "nrv": (
        "NRV — JINR low-energy nuclear reactions online resource "
        "(http://nrv.jinr.ru/nrv/ · atomic-data.jinr.ru). Online "
        "sigma calculators (no local install). Set $NRV_PROBE=1 to "
        "enable the network reachability probe (offline-first "
        "default skips it). Network-gated — `network-fail` honest "
        "skip when offline."
    ),
}


# --- per-backend run stub (B path · wrap-as-is presence-only) -----------
#
# Mirror of N6 `_run_backend_stub`: when a backend is present we
# acknowledge the binary/endpoint and emit an empty sigma-channel
# prediction with a `backend_present_but_not_run` note. ACTUAL sigma
# run-out (entrance-channel capture + compound-nucleus survival across
# the 1n..5n / axn evaporation chain, plus the fragile per-code output
# parser) is the NUCLEAR.md §6.2 Phase 5+ follow-on. R4 holds either way.


def _run_backend_stub(
    backend: str,
    bin_path: str | None,
    Z_proj: int,
    A_proj: int,
    Z_target: int,
    A_target: int,
    E_lab_MeV: float,
) -> tuple[dict, str]:
    """Acknowledge the backend without launching a capture+survival
    sigma run. Returns (prediction_dict, run_note).

    Evaporation channels enumerated as None placeholders so the record
    schema is stable from first land: 1n/2n/3n/4n/5n + axn. Follow-on
    cohort: spawn the backend (or query NRV) + parse output to populate
    sigma_pb per channel + the optimal-channel pick.
    """
    Z_cn = Z_proj + Z_target
    A_cn = A_proj + A_target
    note = (
        f"backend={backend} detected at {bin_path!r}; first-land "
        f"adapter is wrap-as-is presence-only — capture+survival "
        f"sigma run NOT invoked. entrance channel: (Z={Z_proj},"
        f"A={A_proj}) + (Z={Z_target},A={A_target}) @ E_lab="
        f"{E_lab_MeV} MeV -> compound nucleus (Z={Z_cn}, A={A_cn}). "
        f"Follow-on cohort: actually spawn {backend} + parse sigma "
        f"per evaporation channel."
    )
    prediction = {
        "compound_nucleus": {"Z": Z_cn, "A": A_cn},
        "sigma_pb_by_channel": {
            "1n": None,
            "2n": None,
            "3n": None,
            "4n": None,
            "5n": None,
            "axn": None,
        },
        "optimal_channel": None,
        "optimal_sigma_pb": None,
        "backend_present_but_not_run": True,
    }
    return prediction, note


# --- record emit --------------------------------------------------------


def main(
    out_dir: str,
    Z_proj: int,
    A_proj: int,
    Z_target: int,
    A_target: int,
    E_lab_MeV: float,
) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    Z_cn = Z_proj + Z_target
    A_cn = A_proj + A_target

    citations = [
        "arxiv:2208.11471 — SHE production cross-section review / "
        "KEWPIE2-class statistical-model analysis (fusion-evaporation "
        "sigma for superheavy synthesis; primary N8 citation).",
        "Adamian / Antonenko et al. — dinuclear-system (DNS) model "
        "for SHE production cross-sections (Dubna / JINR FLNR). "
        "Production sigma via dinuclear evolution picture.",
        "Reisdorf — HIVAP statistical evaporation model (heavy-ion "
        "fusion-evaporation survival probabilities; legacy Fortran).",
        "JINR NRV — low-energy nuclear reactions online resource — "
        "http://nrv.jinr.ru/nrv/ (sigma calculators · "
        "cross-validation).",
        "arxiv:2105.01035 — Wang / Huang / Kondev / Audi / Naimi, "
        "'The AME 2020 atomic mass evaluation' (Q-value / reaction-"
        "energetics oracle for entrance-channel selection).",
        "IAEA NSDC live evaluated nuclear data — https://nds.iaea.org/"
        "relnsd/ (cross-validation corpus for known SHE channels).",
        "NUCLEAR.md §2 (d) gate (wet-lab dependent) + §4.3 (N8 "
        "cohort spec) + §5.3 (external lib survey) + §6.3 (Phase 5 "
        "N8 land target) + §7 (R4 invariant block — wet-lab "
        "dependency permanent).",
    ]

    scope_caveats = [
        "(s1) sigma prediction is a MODEL output, NOT a measurement. "
        "Fusion-evaporation cross-section for SHE synthesis is "
        "famously hard: HIVAP / DNS / KEWPIE2 predictions routinely "
        "scatter by ~10x (one order of magnitude) against experiment "
        "and against each other (NUCLEAR.md §3.2). A sim-PASS "
        "sigma >= 1 pb is an ACCELERATOR BEAM-TIME PRIORITY HINT, "
        "NEVER a confirmation that the residue will be produced at "
        "that rate.",
        "(s2) Gate (d) is WET-LAB DEPENDENT PERMANENTLY (NUCLEAR.md "
        "§2 + §3.2). Even a fully-converged sigma run only RANKS the "
        "(projectile, target, E_lab) entrance channel for beam-time "
        "priority. Actual production + detection requires GSI / JINR "
        "/ RIKEN heavy-ion accelerator beam-time + a SHIP / DGFRS / "
        "GARIS recoil separator + an alpha-decay-chain "
        "identification — no sigma model substitutes. R4 invariant "
        "blocks any absorbed=true promotion (NUCLEAR.md §7).",
        "(s3) 5-gate evaluation (NUCLEAR.md §2): this record fills "
        "ONLY the (d) gate (production cross-section). The other 4 "
        "gates ((a) mass / structure, (b) spectroscopy, (c) decay "
        "half-life, (e) detection signature) are NOT addressed by "
        "this adapter. Gate (e) has no meaningful sim PASS at all — "
        "the recoil-separator beam-line IS the measurement.",
        "(s4) Backend-specific limits: HIVAP (statistical evaporation "
        "only — fixed capture cross-section input), DNS (dinuclear "
        "evolution — model-dependent quasi-fission competition), "
        "KEWPIE2 (capture x survival factorization — sensitive to "
        "the fission-barrier / shell-correction input), NRV (online "
        "calculator — entrance-channel parameterization). Cross-model "
        "ensemble is needed for an honest sigma band; the ~10x "
        "scatter is the floor, not the ceiling, in the unmeasured "
        "SHE region.",
        "(s5) First-land wrap-as-is: when a backend is detected on "
        "this host, this adapter records the presence but does NOT "
        "launch a capture+survival sigma run (entrance-channel deck "
        "+ per-channel evaporation sub-runs + fragile output parser). "
        "Follow-on cohort: real backend invocation + parse -> "
        "populated sigma_pb per 1n/2n/3n/4n/5n/axn channel + optimal-"
        "channel pick. Mirror of NUCLEAR.md §6.2 Phase 5+ schedule. "
        "Wet-lab dependency unchanged regardless of run-out (§3.2).",
    ]

    chosen, bin_path, detection_note, probe_map = _detect_backend()

    record: dict = {
        "domain": "nuclear",
        "verb": "verify",
        "kind": "fusion_evaporation_xsec_prediction",
        "stamp": stamp,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,  # R4 invariant — ALWAYS false (NUCLEAR §7)
        "provisional": True,
        "gate_d_wet_lab_dependent": True,  # NUCLEAR.md §2 (d) star gate
        "query": {
            "Z_proj": Z_proj,
            "A_proj": A_proj,
            "Z_target": Z_target,
            "A_target": A_target,
            "E_lab_MeV": E_lab_MeV,
            "compound_nucleus": {"Z": Z_cn, "A": A_cn},
        },
        "backend_probe": probe_map,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_citation": (
                "NUCLEAR.md §2 (d) + §4.3 + §5.3 + §6.3 + §7 (this "
                "paper)"
            ),
            "primary_refs": [
                "arxiv:2208.11471 — SHE sigma review / KEWPIE2-class.",
                "Adamian/Antonenko — DNS dinuclear-system model.",
                "Reisdorf — HIVAP statistical evaporation.",
                "arxiv:2105.01035 — AME2020 reaction-energetics "
                "oracle.",
            ],
            "fallback_chain": ["kewpie2", "dns", "hivap", "nrv"],
        },
        "nuclear_anchor": (
            "NUCLEAR.md §2 (d) gate (wet-lab dependent) + §4.3 (N8 "
            "cohort spec) + §6.3 (Phase 5 land target) + §7 (R4 "
            "invariant block)"
        ),
    }

    if chosen is None:
        # Honest skip — no sigma backend installed at all. install-gated
        # IS the PASS verdict (NUCLEAR.md §3.3 — honest skip acceptable).
        install_hint_lines = [
            f"  · {name}: {_INSTALL_HINTS[name]}"
            for name, _ in _BACKENDS
        ]
        skipped_reason = (
            "No fusion-evaporation sigma backend found on host. "
            "Probed (in fallback order) kewpie2 -> dns -> hivap -> "
            "nrv; all absent (NRV network-gated · $NRV_PROBE unset by "
            "default). Install one of:\n"
            + "\n".join(install_hint_lines)
        )
        record["producer"] = "n8_fusion_evap_adapter.py@all-skipped"
        record["backend"] = "all-skipped"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = skipped_reason
        record["prediction"] = None
        headline = (
            "skip: no fusion-evaporation sigma backend present "
            "(install-gated · honest-skip = PASS per §3.3)"
        )
    else:
        # Backend present — first-land wrap-as-is acknowledges presence
        # without launching a capture+survival sigma run. R4 still holds.
        prediction, run_note = _run_backend_stub(
            chosen, bin_path, Z_proj, A_proj, Z_target, A_target,
            E_lab_MeV,
        )
        record["producer"] = f"n8_fusion_evap_adapter.py@{chosen}"
        record["backend"] = chosen
        record["backend_bin"] = bin_path
        record["backend_detection_note"] = detection_note
        record["gate_type"] = "nuclear-novel-discovery-simulation"
        record["skipped_reason"] = None
        record["prediction"] = prediction
        record["run_note"] = run_note
        headline = (
            f"ok: {chosen} present at {bin_path} — presence-only "
            f"(wrap-as-is first land; sigma=stub · ~10x scatter "
            f"caveat · accelerator priority hint NEVER confirmation)"
        )

    rec_path = (
        out
        / f"nuclear_verify_n8_fusevap_{Z_cn}_{A_cn}_{stamp}.json"
    )
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[nuclear+verify · n8_fusevap] wrote {rec_path}")
    print(f"  headline: {headline}")
    print(
        f"  backend={record.get('backend')!r} "
        f"gate_type={record.get('gate_type')!r} "
        f"absorbed={record.get('absorbed')}"
    )
    if record.get("skipped_reason"):
        first_line = str(record["skipped_reason"]).splitlines()[0]
        print(f"  skipped_reason: {first_line}")
    print(
        f"  entrance: ({Z_proj},{A_proj}) + ({Z_target},{A_target}) "
        f"@ {E_lab_MeV} MeV -> CN (Z={Z_cn}, A={A_cn})"
    )
    print(
        "[nuclear+verify · n8_fusevap] absorbed=false (R4 invariant; "
        "sigma is a ~10x model prediction = accelerator priority "
        "hint, NEVER confirmation — gate (d) wet-lab dependent "
        "permanently · NUCLEAR.md §3.2 / §7)"
    )
    return 0


def _parse_argv(
    argv: list[str],
) -> tuple[str, int, int, int, int, float]:
    p = argparse.ArgumentParser(
        prog="n8_fusion_evap_adapter.py",
        description=(
            "Thin adapter for nuclear fusion-evaporation cross-"
            "section sigma prediction for SHE synthesis (NUCLEAR.md "
            "§4.3 N8 cohort · B path · wrap-as-is). Fallback chain: "
            "KEWPIE2 -> DNS -> HIVAP -> NRV. Gate (d) wet-lab "
            "dependent — sigma has ~10x scatter; sim = accelerator "
            "priority hint, NEVER confirmation. R4 invariant: "
            "absorbed=false always."
        ),
    )
    p.add_argument("Z_proj", type=int, help="Projectile proton number.")
    p.add_argument("A_proj", type=int, help="Projectile mass number.")
    p.add_argument("Z_target", type=int, help="Target proton number.")
    p.add_argument("A_target", type=int, help="Target mass number.")
    p.add_argument(
        "E_lab_MeV",
        type=float,
        help="Lab-frame projectile energy in MeV (beam energy).",
    )
    p.add_argument("out_dir", help="Output directory for JSON record.")
    ns = p.parse_args(argv)
    if ns.Z_proj < 1:
        p.error(f"Z_proj must be >= 1, got {ns.Z_proj}")
    if ns.A_proj < ns.Z_proj:
        p.error(
            f"A_proj must be >= Z_proj, got A={ns.A_proj} "
            f"Z={ns.Z_proj}"
        )
    if ns.Z_target < 1:
        p.error(f"Z_target must be >= 1, got {ns.Z_target}")
    if ns.A_target < ns.Z_target:
        p.error(
            f"A_target must be >= Z_target, got A={ns.A_target} "
            f"Z={ns.Z_target}"
        )
    if ns.E_lab_MeV <= 0:
        p.error(f"E_lab_MeV must be > 0, got {ns.E_lab_MeV}")
    return (
        ns.out_dir,
        ns.Z_proj,
        ns.A_proj,
        ns.Z_target,
        ns.A_target,
        ns.E_lab_MeV,
    )


if __name__ == "__main__":
    (
        out_dir,
        Z_proj,
        A_proj,
        Z_target,
        A_target,
        E_lab_MeV,
    ) = _parse_argv(sys.argv[1:])
    sys.exit(
        main(out_dir, Z_proj, A_proj, Z_target, A_target, E_lab_MeV)
    )
