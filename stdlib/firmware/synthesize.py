#!/usr/bin/env python3
# synthesize.py - `firmware + synthesize` producer (D72 adapter-only).
#
# Cross-compiles a minimal hello.c with `arm-none-eabi-gcc -mcpu=cortex-m3`
# → ELF + raw .bin for the QEMU mps2-an385 reference target.
# domains/firmware.md §1: "the signed firmware image" — the signing step
# itself sits in handoff (MCUboot imgtool). Here we produce the unsigned
# image, the canonical SYNTHESIZE deliverable.
#
# If gcc / objcopy are missing, honest install-gated skip.
#
# Citations (domains/firmware.md §5):
#   - arm-none-eabi-gcc — developer.arm.com Tools and Software / GNU Toolchain
#   - QEMU mps2-an385 board docs — qemu.org/docs/master/system/arm/mps2.html
#
# D61: SSOT here. D72: adapter-only. g3: honest install-gated.

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


_HELLO_C = """/* hello.c - freestanding Cortex-M3 entry for firmware+synthesize.
 * Single _start with an infinite increment loop — minimal text that
 * the QEMU mps2-an385 board can fetch and run (verify cell boots it).
 */
void _start(void) {
    volatile unsigned i = 0;
    while (1) { i = i + 1U; }
}
"""


def _probe_gcc() -> tuple[str | None, str | None, str | None]:
    gcc = shutil.which("arm-none-eabi-gcc")
    objcopy = shutil.which("arm-none-eabi-objcopy")
    if gcc is None or objcopy is None:
        miss = []
        if gcc is None:
            miss.append("arm-none-eabi-gcc")
        if objcopy is None:
            miss.append("arm-none-eabi-objcopy")
        return None, None, f"missing on PATH: {', '.join(miss)}"
    try:
        out = subprocess.run(
            [gcc, "--version"], capture_output=True, text=True, timeout=10
        )
        first = (out.stdout or "").splitlines()
        ver = first[0].strip() if first else "unknown"
        return gcc, objcopy, None
    except Exception as e:  # pragma: no cover
        return None, None, f"arm-none-eabi-gcc --version failed: {e}"


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    gcc, objcopy, skip_reason = _probe_gcc()

    citations = [
        "arm-none-eabi-gcc — developer.arm.com Tools and Software / GNU Toolchain.",
        "QEMU mps2-an385 board docs — qemu.org/docs/master/system/arm/mps2.html.",
    ]
    scope_caveats = [
        "Cross-compile target = Cortex-M3 (QEMU mps2-an385 reference); "
        "no signing in this verb — MCUboot imgtool sign happens in "
        "firmware+handoff (domains/firmware.md §1).",
        "hello.c is the smallest possible freestanding text — NOT a real "
        "product binary. measurement_gate = GATE_OPEN permanently (g3).",
    ]
    artifacts: dict[str, str] = {}

    if skip_reason is None:
        # Write hello.c then compile.
        src = out / "hello.c"
        src.write_text(_HELLO_C)
        elf = out / "firmware.elf"
        binp = out / "firmware.bin"
        try:
            subprocess.run(
                [
                    gcc,
                    "-mcpu=cortex-m3",
                    "-mthumb",
                    "-nostdlib",
                    "-ffreestanding",
                    "-Os",
                    "-g",
                    "-Wl,-Ttext=0x00000000",
                    "-Wl,--entry=_start",
                    "-o",
                    str(elf),
                    str(src),
                ],
                check=True,
                capture_output=True,
                text=True,
                timeout=60,
            )
            subprocess.run(
                [objcopy, "-O", "binary", str(elf), str(binp)],
                check=True,
                capture_output=True,
                text=True,
                timeout=30,
            )
            artifacts["source"] = src.name
            artifacts["elf"] = elf.name
            artifacts["bin"] = binp.name
        except subprocess.CalledProcessError as e:
            skip_reason = (
                f"cross-compile failed (exit {e.returncode}): "
                f"{(e.stderr or '').strip()[:200]}"
            )
            scope_caveats.append(skip_reason)
        except Exception as e:  # pragma: no cover
            skip_reason = f"cross-compile crash: {e}"
            scope_caveats.append(skip_reason)
    else:
        scope_caveats.append(f"arm-none-eabi toolchain missing — install-gated skip: {skip_reason}")

    producer = (
        "arm-none-eabi-gcc (cortex-m3 cross-compile)"
        if skip_reason is None
        else "firmware_synthesize@absent"
    )
    record = {
        "domain": "firmware",
        "verb": "synthesize",
        "kind": "cortex_m3_elf_bin",
        "stamp": stamp,
        "producer": producer,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": "toolchain_missing_or_build_failed" if skip_reason else None,
        "artifacts": artifacts,
    }
    rec_path = out / f"firmware_synthesize_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[firmware+synthesize] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/firmware_synthesize"))
