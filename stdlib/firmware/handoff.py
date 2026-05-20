#!/usr/bin/env python3
# handoff.py - `firmware + handoff` producer (D72 adapter-only).
#
# Emits the release.tar.gz bundle (image + dossier + SBOM placeholder).
# Probes `imgtool` (MCUboot signer — github.com/mcu-tools/mcuboot) and
# generates a CycloneDX SBOM skeleton (cyclonedx.org). If imgtool is
# missing, sign step is honest-skipped.
#
# Citations (domains/firmware.md §5):
#   - MCUboot — mcu-tools.github.io/mcuboot
#   - TUF / Uptane — theupdateframework.io / uptane.org
#   - SWUpdate — sbabic.github.io/swupdate
#   - CycloneDX SBOM — cyclonedx.org
#   - SPDX — spdx.dev
#
# D61: SSOT here. D72: adapter-only. g3: honest install-gated.

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tarfile
import time
from pathlib import Path


def _probe_imgtool() -> tuple[str | None, str | None]:
    imgtool = shutil.which("imgtool")
    if imgtool is None:
        return None, "imgtool not on PATH (MCUboot not installed)"
    try:
        out = subprocess.run(
            [imgtool, "version"], capture_output=True, text=True, timeout=10
        )
        text = (out.stdout or out.stderr or "").strip()
        return (text.splitlines()[0].strip() if text else "unknown"), None
    except Exception as e:  # pragma: no cover
        return None, f"imgtool version failed: {e}"


def _cyclonedx_sbom_skeleton(image_name: str | None) -> dict:
    """Minimal CycloneDX 1.5 SBOM — components left empty (a real SBOM
    is generated from the build's compile-commands plus dependency
    manifests). cyclonedx.org schema reference.
    """
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "version": 1,
        "metadata": {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "component": {
                "type": "firmware",
                "name": image_name or "firmware.bin",
                "version": "0.0.0-template",
            },
        },
        "components": [],
    }


def _find_synthesize_bin(out: Path) -> Path | None:
    candidate = out / "firmware.bin"
    if candidate.exists() and candidate.stat().st_size > 0:
        return candidate
    parent = out.parent
    if parent.exists():
        for sub in sorted(parent.glob("**/firmware.bin"), reverse=True):
            if sub.stat().st_size > 0:
                return sub
    return None


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    imgtool_version, imgtool_skip = _probe_imgtool()

    citations = [
        "MCUboot — mcu-tools.github.io/mcuboot.",
        "TUF / Uptane — theupdateframework.io / uptane.org.",
        "SWUpdate — sbabic.github.io/swupdate.",
        "CycloneDX SBOM — cyclonedx.org.",
        "SPDX — spdx.dev.",
    ]
    scope_caveats = [
        "release.tar.gz is a TEMPLATE bundle — a real handoff stuffs in "
        "image + sign + dossier + OTA manifest + audit evidence.",
        "SBOM is a CycloneDX 1.5 SKELETON (empty components) — a real "
        "SBOM is generated from the build's compile-commands.json + "
        "dependency manifest.",
        "measurement_gate = GATE_OPEN permanently — a handoff bundle is "
        "scaffolding, not an absorption claim (g3).",
    ]

    bin_path = _find_synthesize_bin(out)
    if bin_path is None:
        scope_caveats.append(
            "no firmware.bin from synthesize cell — bundle ships SBOM "
            "skeleton + this record only."
        )

    sbom = _cyclonedx_sbom_skeleton(bin_path.name if bin_path else None)
    sbom_path = out / f"sbom_{stamp}.cdx.json"
    sbom_path.write_text(json.dumps(sbom, indent=2))

    # Optional: sign probe — never actually signs (would need a private
    # key; that is a per-project artifact, not part of the SSOT skeleton).
    sign_probe = {
        "imgtool_version": imgtool_version,
        "imgtool_skipped_reason": imgtool_skip,
        "signed": False,
        "note": "imgtool present-probe only — no key material in SSOT.",
    }
    sign_path = out / f"sign_probe_{stamp}.json"
    sign_path.write_text(json.dumps(sign_probe, indent=2))

    # Bundle into release.tar.gz.
    tarball = out / f"release_{stamp}.tar.gz"
    with tarfile.open(tarball, "w:gz") as tf:
        tf.add(sbom_path, arcname=sbom_path.name)
        tf.add(sign_path, arcname=sign_path.name)
        if bin_path is not None:
            tf.add(bin_path, arcname=bin_path.name)

    if imgtool_skip is not None:
        scope_caveats.append(f"imgtool missing — sign step honest-skip: {imgtool_skip}")

    producer = (
        f"imgtool@{imgtool_version} + tarfile + cyclonedx_skeleton"
        if imgtool_version is not None
        else "firmware_handoff@template"
    )
    # G7 typed gate_type — install-gated when MCUboot imgtool missing
    # (sign step honest-skipped); otherwise bundle assembled and no
    # hexa-native firmware-handoff kernel exists yet → D80
    # hexa-native-absent + provisional.
    if imgtool_skip is not None:
        gate_type = "install-gated"
        provisional = False
    else:
        gate_type = "hexa-native-absent"
        provisional = True
    record = {
        "domain": "firmware",
        "verb": "handoff",
        "kind": "release_bundle",
        "stamp": stamp,
        "producer": producer,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": "imgtool_missing" if imgtool_skip is not None else None,
        "gate_type": gate_type,
        "provisional": provisional,
        "artifacts": {
            "sbom": sbom_path.name,
            "sign_probe": sign_path.name,
            "release_tarball": tarball.name,
        },
    }
    rec_path = out / f"firmware_handoff_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[firmware+handoff] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/firmware_handoff"))
