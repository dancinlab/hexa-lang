#!/usr/bin/env python3
# design.py - `firmware + design` producer (D72 adapter-only).
#
# Probes `arm-none-eabi-gcc --version` and emits a CMake skeleton for the
# QEMU mps2-an385 (Cortex-M3) reference target. If gcc is missing, honest
# install-gated skip.
#
# Citations (domains/firmware.md §5):
#   - arm-none-eabi-gcc — developer.arm.com Tools and Software / GNU Toolchain
#   - CMake — cmake.org
#   - west (Zephyr build orchestrator) — zephyrproject.org
#
# D61: SSOT here. D72: adapter-only. g3: honest install-gated.

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


_CMAKE_TEMPLATE = """# CMake skeleton for firmware design — QEMU mps2-an385 reference target.
# domains/firmware.md §2 (DESIGN row): arm-none-eabi-gcc / CMake / west / TinyUSB.
cmake_minimum_required(VERSION 3.20)
project(firmware_design_demo C ASM)

set(CMAKE_C_COMPILER   arm-none-eabi-gcc)
set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)
set(CMAKE_C_FLAGS "-mcpu=cortex-m3 -mthumb -nostdlib -ffreestanding -Os -g")
set(CMAKE_EXE_LINKER_FLAGS "-Wl,--gc-sections -Wl,-T,linker.ld")

add_executable(firmware.elf hello.c)
"""

_HELLO_C_TEMPLATE = """/* hello.c - minimal Cortex-M3 freestanding entry for firmware+design.
 * Pairs with the synthesize verb (cross-compile + ELF emit).
 */
void _start(void) {
    volatile unsigned i = 0;
    while (1) { i = i + 1U; }
}
"""


def _probe_gcc() -> tuple[str | None, str | None]:
    gcc = shutil.which("arm-none-eabi-gcc")
    if gcc is None:
        return None, "arm-none-eabi-gcc not on PATH"
    try:
        out = subprocess.run(
            [gcc, "--version"], capture_output=True, text=True, timeout=10
        )
        first = (out.stdout or "").splitlines()
        return (first[0].strip() if first else "unknown"), None
    except Exception as e:  # pragma: no cover
        return None, f"arm-none-eabi-gcc --version failed: {e}"


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    gcc_version, skip_reason = _probe_gcc()
    src_dir = out / "source"
    src_dir.mkdir(parents=True, exist_ok=True)
    cmake_path = src_dir / "CMakeLists.txt"
    cmake_path.write_text(_CMAKE_TEMPLATE)
    hello_path = src_dir / "hello.c"
    hello_path.write_text(_HELLO_C_TEMPLATE)

    citations = [
        "arm-none-eabi-gcc — developer.arm.com Tools and Software / GNU Toolchain.",
        "CMake — cmake.org.",
        "west (Zephyr build orchestrator) — zephyrproject.org.",
        "QEMU mps2-an385 board docs — qemu.org/docs/master/system/arm/mps2.html.",
    ]
    scope_caveats = [
        "CMake + hello.c are a TEMPLATE skeleton — a real design vendors "
        "a board-specific linker.ld + startup.s + vendor HAL.",
        "arm-none-eabi-gcc probe is a version sniff, NOT a build — actual "
        "compile happens in firmware+synthesize.",
        "measurement_gate = GATE_OPEN permanently — design scaffolding is "
        "not an absorption claim (g3).",
    ]
    if skip_reason is not None:
        scope_caveats.append(f"arm-none-eabi-gcc missing — install-gated skip: {skip_reason}")

    producer = (
        f"arm-none-eabi-gcc@{gcc_version}"
        if gcc_version is not None
        else "firmware_design@template"
    )
    record = {
        "domain": "firmware",
        "verb": "design",
        "kind": "cmake_template",
        "stamp": stamp,
        "producer": producer,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": "arm_none_eabi_gcc_missing" if skip_reason is not None else None,
        "artifacts": {
            "cmake": f"source/{cmake_path.name}",
            "hello_c": f"source/{hello_path.name}",
        },
    }
    rec_path = out / f"firmware_design_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[firmware+design] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/firmware_design"))
