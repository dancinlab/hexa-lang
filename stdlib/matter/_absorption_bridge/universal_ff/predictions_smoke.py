#!/usr/bin/env python3
"""predictions_smoke.py — Phase J.2 (2026-05-13) + Tier-2 wave (2026-05-14) + Tier-3 wave (2026-05-14)

Walks every `_absorption_bridge/universal_ff/predictions/*.json` snapshot and

  - `__fixture_tag__` present and starts with "VENDORED UNIVERSAL-FF PREDICTION"
  - `candidate_id` matches `hxm-<class>-<target>-<NNN>` pattern
  - `predicted_value` present (numeric or string for qualitative falsifiers)
  - `proxy_source` present (peer-reviewed paper / vendor datasheet anchor)
  - `is_external_verification: false` mandatory (does NOT promote to EXTERNAL-VERIFIED)

Hard list — the 7 Tier-1 + 10 Tier-2 + 2 Tier-3 promoted candidates must all be present:

Tier-1 (Phase J.2, 2026-05-13):
  - hxm-pv-tandem-002 (§4.A.11 of NOVEL)
  - hxm-bat-cath-drx-001 (§4.A.1)
  - hxm-bat-anode-li-metal-001 (§4.A.5)
  - hxm-co2-cap-mof-mfm-002 (§4.F.1)
  - hxm-te-half-zrnisn-001 (§4.B.2)
  - hxm-cement-mgo-co2neg-001 (§4.D.6)
  - hxm-h2-elec-iro2-doped-001 (§4.B.1)

Tier-2 (Tier-2 wave, 2026-05-14):
  - hxm-quantum-si-donor-001 (§4.C.1)
  - hxm-quantum-hbn-vb-001 (§4.C.1)
  - hxm-ni-4gen-re-free-001 (§4.D.2)
  - hxm-mycel-composite-001 (§4.F.13)
  - hxm-algae-plastic-001 (§4.F.13)
  - hxm-weyl-tas-001 (§4.C.4)
  - hxm-flatband-tbg-001 (§4.C.4)
  - hxm-aero-polyimide-001 (§4.D.12)
  - hxm-mof-h2o-stable-uio66-001 (§4.D.13)
  - hxm-bat-cath-naion-001 (§4.A.1)

Tier-3 (Tier-3 wave, 2026-05-14 — NOVEL_ROADMAP §5 Tier-3 list):
  - hxm-time-crystal-trivial-001 (§4.F.12) — falsifier_relation AT-RISK
  - hxm-tdmeta-photonic-001 (§4.C.4) — falsifier_relation MARGINAL

Sentinel: `__HEXA_MATTER_UFF_PREDICTIONS__ PASS (19/19 predictions, 0 invalid)`.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PREDICTIONS_DIR = HERE / "predictions"

REQUIRED_FIELDS = (
    "__fixture_tag__",
    "candidate_id",
    "predicted_value",
    "proxy_source",
    "n6_lattice_fit_applied",
    "is_measurement",
    "is_external_verification",
)

TIER1_REQUIRED = {
    "hxm-pv-tandem-002",
    "hxm-bat-cath-drx-001",
    "hxm-bat-anode-li-metal-001",
    "hxm-co2-cap-mof-mfm-002",
    "hxm-te-half-zrnisn-001",
    "hxm-cement-mgo-co2neg-001",
    "hxm-h2-elec-iro2-doped-001",
}

TIER2_REQUIRED = {
    "hxm-quantum-si-donor-001",
    "hxm-quantum-hbn-vb-001",
    "hxm-ni-4gen-re-free-001",
    "hxm-mycel-composite-001",
    "hxm-algae-plastic-001",
    "hxm-weyl-tas-001",
    "hxm-flatband-tbg-001",
    "hxm-aero-polyimide-001",
    "hxm-mof-h2o-stable-uio66-001",
    "hxm-bat-cath-naion-001",
}

TIER3_REQUIRED = {
    "hxm-time-crystal-trivial-001",
    "hxm-tdmeta-photonic-001",
}

ALL_REQUIRED = TIER1_REQUIRED | TIER2_REQUIRED | TIER3_REQUIRED

ID_RE = re.compile(r"^hxm-[a-z0-9][a-z0-9-]*-\d{3}$")


def validate_snapshot(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        snap = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [f"{path.name}: not valid JSON ({exc})"]

    for field in REQUIRED_FIELDS:
        if field not in snap:
            errors.append(f"{path.name}: missing required field '{field}'")

    if "__fixture_tag__" in snap and not str(snap["__fixture_tag__"]).startswith(
        "VENDORED UNIVERSAL-FF PREDICTION"
    ):
        errors.append(
            f"{path.name}: __fixture_tag__ must start with 'VENDORED UNIVERSAL-FF PREDICTION'"
        )

    if "candidate_id" in snap and not ID_RE.match(str(snap["candidate_id"])):
        errors.append(
            f"{path.name}: candidate_id '{snap['candidate_id']}' fails hxm-<class>-<target>-<NNN> shape"
        )

    if snap.get("n6_lattice_fit_applied") is not False:
        errors.append(
        )
    if snap.get("is_measurement") is not False:
        errors.append(
        )
    if snap.get("is_external_verification") is not False:
        errors.append(
            f"{path.name}: is_external_verification must be literal false (does NOT promote to EXTERNAL-VERIFIED)"
        )
    if "proxy_source" in snap and not str(snap["proxy_source"]).strip():
        errors.append(f"{path.name}: proxy_source must be non-empty")

    # Tier-2 candidates must declare `tier` field == "Tier-2"
    cid = snap.get("candidate_id")
    if cid in TIER2_REQUIRED:
        if snap.get("tier") != "Tier-2":
            errors.append(
                f"{path.name}: Tier-2 candidate '{cid}' must declare 'tier': 'Tier-2'"
            )

    # Tier-3 candidates must declare `tier` field == "Tier-3"
    if cid in TIER3_REQUIRED:
        if snap.get("tier") != "Tier-3":
            errors.append(
                f"{path.name}: Tier-3 candidate '{cid}' must declare 'tier': 'Tier-3'"
            )

    return errors


def main() -> int:
    args = sys.argv[1:]
    selftest = "--selftest" in args

    if not PREDICTIONS_DIR.is_dir():
        print(f"FAIL: predictions directory not found: {PREDICTIONS_DIR}")
        print("__HEXA_MATTER_UFF_PREDICTIONS__ FAIL (predictions/ missing)")
        return 1

    files = sorted(PREDICTIONS_DIR.glob("*.json"))
    invalid: list[str] = []
    seen_ids: set[str] = set()
    for path in files:
        errs = validate_snapshot(path)
        if errs:
            invalid.extend(errs)
            continue
        snap = json.loads(path.read_text(encoding="utf-8"))
        seen_ids.add(snap["candidate_id"])

    missing_tier1 = TIER1_REQUIRED - seen_ids
    if missing_tier1:
        invalid.append(
            f"Tier-1 candidate(s) missing from predictions/: {sorted(missing_tier1)}"
        )
    missing_tier2 = TIER2_REQUIRED - seen_ids
    if missing_tier2:
        invalid.append(
            f"Tier-2 candidate(s) missing from predictions/: {sorted(missing_tier2)}"
        )
    missing_tier3 = TIER3_REQUIRED - seen_ids
    if missing_tier3:
        invalid.append(
            f"Tier-3 candidate(s) missing from predictions/: {sorted(missing_tier3)}"
        )

    total = len(ALL_REQUIRED)
    found = len(ALL_REQUIRED & seen_ids)

    if invalid:
        if not selftest:
            for line in invalid:
                print(f"  ! {line}")
        print(
            f"__HEXA_MATTER_UFF_PREDICTIONS__ FAIL ({found}/{total} predictions, {len(invalid)} invalid)"
        )
        if selftest:
            for line in invalid:
                print(f"  ! {line}")
        return 1

    print(
        f"__HEXA_MATTER_UFF_PREDICTIONS__ PASS ({found}/{total} predictions, 0 invalid)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
