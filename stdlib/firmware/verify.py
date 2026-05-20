#!/usr/bin/env python3
# verify.py - `firmware + verify` producer (D72 adapter-only).
#
# Boots the synthesized bin on `qemu-system-arm -machine mps2-an385`
# (Cortex-M3 reference target, zero hardware dependency per
# domains/firmware.md §1). Also probes the Unity test framework
# presence (ThrowTheSwitch — the §2 VERIFY row free-tier choice).
#
# If qemu-system-arm is missing OR the prior synthesize record is not
# available, honest install-gated skip.
#
# Citations (domains/firmware.md §5):
#   - QEMU — qemu.org, mps2-an385 board docs:
#     qemu.org/docs/master/system/arm/mps2.html
#   - Renode (Antmicro) — renode.io (heavier; not probed here)
#   - Unity + Ceedling — throwtheswitch.org
#
# D61: SSOT here. D72: adapter-only. g3: honest install-gated.

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


def _probe_qemu() -> tuple[str | None, str | None]:
    qemu = shutil.which("qemu-system-arm")
    if qemu is None:
        return None, "qemu-system-arm not on PATH"
    try:
        out = subprocess.run(
            [qemu, "--version"], capture_output=True, text=True, timeout=10
        )
        first = (out.stdout or "").splitlines()
        return (first[0].strip() if first else "unknown"), None
    except Exception as e:  # pragma: no cover
        return None, f"qemu-system-arm --version failed: {e}"


def _find_synthesize_bin(out: Path) -> Path | None:
    """If a sibling firmware/synthesize record exists with firmware.bin,
    use it. Otherwise look in $out for a firmware.bin (chained call).
    """
    candidate = out / "firmware.bin"
    if candidate.exists() and candidate.stat().st_size > 0:
        return candidate
    # Walk one level up to look for synthesize/<stamp>/firmware.bin.
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

    qemu_version, qemu_skip = _probe_qemu()
    unity = shutil.which("ceedling")  # Ceedling wraps Unity; absence is fine
    unity_present = unity is not None

    citations = [
        "QEMU — qemu.org.",
        "QEMU mps2-an385 board docs — qemu.org/docs/master/system/arm/mps2.html.",
        "Renode (Antmicro) — renode.io.",
        "Unity + Ceedling — throwtheswitch.org.",
    ]
    scope_caveats = [
        "Verify boots the synthesize cell's firmware.bin on QEMU "
        "mps2-an385 (Cortex-M3) — zero hardware dependency per "
        "domains/firmware.md §1.",
        "Boot is a smoke-test only — runs ≤2 s then kills QEMU. NOT a "
        "passing Unity test suite, NOT a coverage measurement, NOT a "
        "HIL verification.",
        "measurement_gate = GATE_OPEN permanently — smoke-boot is not "
        "an absorption claim (g3).",
    ]

    verify = {
        "qemu_version": qemu_version,
        "unity_ceedling_present": unity_present,
        "boot_smoke": None,
    }
    bin_path = _find_synthesize_bin(out)
    skip_reason = qemu_skip
    if skip_reason is None and bin_path is None:
        skip_reason = "no firmware.bin from synthesize cell — run firmware+synthesize first"
        scope_caveats.append(skip_reason)
    if qemu_skip is not None:
        scope_caveats.append(f"qemu-system-arm missing — install-gated skip: {qemu_skip}")
    if not unity_present:
        scope_caveats.append("Ceedling/Unity not on PATH — skipped (smoke-only verify).")

    if skip_reason is None and bin_path is not None:
        try:
            # Boot QEMU for ≤2 s; -no-reboot stops it from looping, -nographic
            # avoids opening a UI. We measure "did it not crash before timeout".
            qemu = shutil.which("qemu-system-arm")
            proc = subprocess.run(
                [
                    qemu,
                    "-machine",
                    "mps2-an385",
                    "-cpu",
                    "cortex-m3",
                    "-nographic",
                    "-no-reboot",
                    "-kernel",
                    str(bin_path),
                ],
                capture_output=True,
                text=True,
                timeout=2,
            )
            verify["boot_smoke"] = {
                "exited_before_timeout": True,
                "exit_code": proc.returncode,
                "tail": (proc.stdout or proc.stderr or "")[-256:],
            }
        except subprocess.TimeoutExpired:
            # Expected — the hello.c loop never exits. That IS the smoke pass:
            # QEMU sustained execution without crashing.
            verify["boot_smoke"] = {
                "exited_before_timeout": False,
                "note": "QEMU sustained execution for 2s (loop did not crash).",
            }
        except Exception as e:  # pragma: no cover
            skip_reason = f"qemu boot crashed: {e}"
            scope_caveats.append(skip_reason)

    verify_path = out / f"verify_{stamp}.json"
    verify_path.write_text(json.dumps(verify, indent=2))

    producer = (
        f"qemu-system-arm@{qemu_version}"
        if qemu_version is not None
        else "firmware_verify@absent"
    )
    record = {
        "domain": "firmware",
        "verb": "verify",
        "kind": "qemu_mps2_an385_boot",
        "stamp": stamp,
        "producer": producer,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": ("qemu_or_bin_missing" if skip_reason else None),
        "artifacts": {
            "verify": verify_path.name,
        },
    }
    rec_path = out / f"firmware_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[firmware+verify] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/firmware_verify"))
