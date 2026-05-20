#!/usr/bin/env python3
# specify.py - `firmware + specify` producer (D72 adapter-only).
#
# Emits a `requirements.json` template skeleton: MCU + RAM/flash budget
# + interfaces + SIL level. Reference target = QEMU mps2-an385 (Cortex-M3,
# zero hardware dependency per domains/firmware.md §1).
#
# Citations (domains/firmware.md §5):
#   - IETF / Zephyr public RFCs
#   - AUTOSAR Classic Platform public spec (autosar.org)
#   - IEC 61508 (Functional Safety, public summary)
#   - MISRA-C:2012 public summary (misra.org.uk)
#   - CERT-C secure coding (cert.org)
#
# D61: substrate SSOT here under hexa-lang/stdlib/firmware/.
# D72: firmware = adapter-only (no FEM/MC/graph math) — never kernel.
# g3:  honest. Pure template emit, no external tool required. Record
#      always GATE_OPEN / absorbed=false (requirements skeleton, not
#      a measurement).

from __future__ import annotations

import json
import sys
import time
from pathlib import Path


def _build_requirements_template() -> dict:
    """The skeleton requirements.json — fields are placeholders; a real
    project fills them. Reference defaults track QEMU mps2-an385.
    """
    return {
        "target": {
            "mcu": "ARM Cortex-M3 (QEMU mps2-an385 reference)",
            "ram_kib": 16,
            "flash_kib": 256,
            "clock_mhz": 25,
        },
        "interfaces": {
            "uart": True,
            "gpio": True,
            "i2c": False,
            "spi": False,
            "can": False,
            "usb": False,
            "ethernet": False,
        },
        "safety": {
            "sil_level": None,
            "iec_61508_class": None,
            "misra_c_profile": "MISRA-C:2012",
            "cert_c_profile": "CERT-C",
        },
        "boot": {
            "secure_boot": False,
            "ota_update": False,
            "rollback_protection": False,
        },
    }


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    requirements = _build_requirements_template()
    req_path = out / f"requirements_{stamp}.json"
    req_path.write_text(json.dumps(requirements, indent=2))

    citations = [
        "IETF / Zephyr public RFCs.",
        "AUTOSAR Classic Platform public spec — autosar.org.",
        "IEC 61508 (Functional Safety, public summary) — iec.ch/functional-safety.",
        "MISRA-C:2012 — misra.org.uk.",
        "CERT-C secure coding — wiki.sei.cmu.edu/confluence/display/c.",
    ]
    scope_caveats = [
        "requirements.json is a TEMPLATE skeleton, NOT a project spec — "
        "a real product fills MCU / RAM / flash / interfaces / SIL "
        "with measured / vendor-validated values.",
        "Reference defaults track QEMU mps2-an385 (Cortex-M3, 16 KiB RAM, "
        "256 KiB flash) per domains/firmware.md §1 — zero hardware "
        "dependency target so every cell is measurable.",
        "measurement_gate = GATE_OPEN permanently — a requirements "
        "skeleton is never an absorption claim (g3, domains/firmware.md §7).",
    ]

    record = {
        "domain": "firmware",
        "verb": "specify",
        "kind": "requirements_template",
        "stamp": stamp,
        "producer": "firmware_specify@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        # G7 typed gate_type — template emit succeeded; no hexa-native
        # firmware-specify kernel exists yet → D80 hexa-native-absent
        # + provisional.
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "artifacts": {
            "requirements": req_path.name,
        },
    }
    rec_path = out / f"firmware_specify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[firmware+specify] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/firmware_specify"))
