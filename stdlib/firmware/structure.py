#!/usr/bin/env python3
# structure.py - `firmware + structure` producer (D72 adapter-only).
#
# Emits an arch.json skeleton describing the RTOS task tree + memory map.
# Probes `west` (Zephyr build orchestrator) — if present, records its
# version. If missing, honest install-gated skip (Zephyr ecosystem is
# the most-used public-surface RTOS per domains/firmware.md §2).
#
# Citations (domains/firmware.md §5):
#   - Zephyr RTOS — zephyrproject.org
#   - FreeRTOS — freertos.org
#   - Apache NuttX — nuttx.apache.org
#   - AUTOSAR Classic Platform — autosar.org
#
# D61: substrate SSOT here. D72: firmware adapter-only. g3: honest.

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


def _probe_west() -> tuple[str | None, str | None]:
    west = shutil.which("west")
    if west is None:
        return None, "west not on PATH (Zephyr ecosystem not installed)"
    try:
        out = subprocess.run(
            [west, "--version"], capture_output=True, text=True, timeout=10
        )
        return (out.stdout or out.stderr or "unknown").strip(), None
    except Exception as e:  # pragma: no cover
        return None, f"west --version failed: {e}"


def _arch_template() -> dict:
    """Skeleton task tree for the QEMU mps2-an385 reference target —
    a Zephyr-style multi-thread arch with the headline split:
    main / idle / log / shell.
    """
    return {
        "rtos": "Zephyr (reference) | FreeRTOS | NuttX | bare-metal",
        "tasks": [
            {"name": "main", "priority": 7, "stack_kib": 2},
            {"name": "idle", "priority": -1, "stack_kib": 1},
            {"name": "log", "priority": 9, "stack_kib": 1},
            {"name": "shell", "priority": 10, "stack_kib": 2},
        ],
        "memory_map": {
            "flash_origin": "0x00000000",
            "flash_size": "0x00040000",
            "ram_origin": "0x20000000",
            "ram_size": "0x00004000",
        },
        "interrupts": {
            "vector_table_origin": "0x00000000",
            "highest_priority": 0,
            "tick_source": "SysTick",
        },
    }


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    west_version, skip_reason = _probe_west()
    arch = _arch_template()
    arch_path = out / f"arch_{stamp}.json"
    arch_path.write_text(json.dumps(arch, indent=2))

    citations = [
        "Zephyr RTOS — zephyrproject.org.",
        "FreeRTOS — freertos.org.",
        "Apache NuttX — nuttx.apache.org.",
        "AUTOSAR Classic Platform — autosar.org.",
    ]
    scope_caveats = [
        "arch.json is a TEMPLATE skeleton — RTOS / task tree / memory map "
        "are placeholders for a Zephyr-style mps2-an385 starter, NOT a "
        "vendor-validated production arch.",
        "west probe is a version sniff, not a build — full arch validation "
        "requires `west init` + `west build` against a real Zephyr tree.",
        "measurement_gate = GATE_OPEN permanently — arch skeleton is not "
        "an absorption claim (g3).",
    ]
    if skip_reason is not None:
        scope_caveats.append(f"west missing — install-gated skip: {skip_reason}")

    producer = (
        f"west@{west_version}" if west_version is not None else "firmware_structure@template"
    )
    record = {
        "domain": "firmware",
        "verb": "structure",
        "kind": "arch_template",
        "stamp": stamp,
        "producer": producer,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": "west_missing" if skip_reason is not None else None,
        "artifacts": {
            "arch": arch_path.name,
        },
    }
    rec_path = out / f"firmware_structure_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[firmware+structure] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/firmware_structure"))
