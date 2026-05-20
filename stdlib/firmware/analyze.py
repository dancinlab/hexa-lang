#!/usr/bin/env python3
# analyze.py - `firmware + analyze` producer (D72 adapter-only).
#
# Probes `clang-tidy` and `cppcheck` (the two free-tier static-analysis
# tools cited in domains/firmware.md §2 ANALYZE row) and collects their
# version banners. Emits analysis.json skeleton. If neither tool is
# present, honest install-gated skip.
#
# Citations (domains/firmware.md §5):
#   - clang-tidy — clang.llvm.org / LLVM project
#   - cppcheck — cppcheck.sourceforge.io
#   - Frama-C — frama-c.com (heavier; not probed here)
#   - KLEE (Cadar et al., OSDI '08) — klee-se.org
#   - CBMC — cprover.org/cbmc
#
# D61: SSOT here. D72: adapter-only. g3: honest install-gated.

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


def _probe(tool: str, args: list[str]) -> tuple[str | None, str | None]:
    binp = shutil.which(tool)
    if binp is None:
        return None, f"{tool} not on PATH"
    try:
        out = subprocess.run(
            [binp, *args], capture_output=True, text=True, timeout=10
        )
        text = (out.stdout or out.stderr or "").strip()
        first = text.splitlines()
        return (first[0].strip() if first else "unknown"), None
    except Exception as e:  # pragma: no cover
        return None, f"{tool} probe failed: {e}"


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    clang_tidy_v, clang_skip = _probe("clang-tidy", ["--version"])
    cppcheck_v, cppcheck_skip = _probe("cppcheck", ["--version"])

    analysis = {
        "tools": {
            "clang-tidy": {
                "version": clang_tidy_v,
                "skipped_reason": clang_skip,
            },
            "cppcheck": {
                "version": cppcheck_v,
                "skipped_reason": cppcheck_skip,
            },
        },
        "findings": [],
        "rules_profile": "MISRA-C:2012 + CERT-C (target)",
    }
    analysis_path = out / f"analysis_{stamp}.json"
    analysis_path.write_text(json.dumps(analysis, indent=2))

    citations = [
        "clang-tidy — clang.llvm.org (LLVM project).",
        "cppcheck — cppcheck.sourceforge.io.",
        "Frama-C — frama-c.com (heavier; not probed here).",
        "KLEE — Cadar et al., OSDI 2008, klee-se.org.",
        "CBMC (Diffblue) — cprover.org/cbmc.",
    ]
    scope_caveats = [
        "Probe-only — no actual analysis is performed against source. "
        "Real findings require a build database (compile_commands.json) "
        "plus the project's source tree.",
        "Frama-C / KLEE / CBMC (deductive / symbolic / bounded-model) "
        "are NOT probed here — they are heavier and per-project; future "
        "expansion candidate.",
        "measurement_gate = GATE_OPEN permanently — static-analysis "
        "version sniffing is not an absorption claim (g3).",
    ]
    skipped: list[str] = []
    if clang_skip is not None:
        skipped.append("clang-tidy")
        scope_caveats.append(f"clang-tidy missing — {clang_skip}")
    if cppcheck_skip is not None:
        skipped.append("cppcheck")
        scope_caveats.append(f"cppcheck missing — {cppcheck_skip}")

    producer_parts = []
    if clang_tidy_v is not None:
        producer_parts.append(f"clang-tidy@{clang_tidy_v}")
    if cppcheck_v is not None:
        producer_parts.append(f"cppcheck@{cppcheck_v}")
    producer = " + ".join(producer_parts) if producer_parts else "firmware_analyze@absent"

    record = {
        "domain": "firmware",
        "verb": "analyze",
        "kind": "static_probe",
        "stamp": stamp,
        "producer": producer,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": ",".join(skipped) if skipped else None,
        "artifacts": {
            "analysis": analysis_path.name,
        },
    }
    rec_path = out / f"firmware_analyze_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[firmware+analyze] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/firmware_analyze"))
