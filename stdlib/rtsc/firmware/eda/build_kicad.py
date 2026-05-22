#!/usr/bin/env python3
"""
build_kicad.py — KiCad CLI wrapper for hexa-rtsc Phase E1 verified-parse.

§A.6.1 Phase E1 deliverable per .roadmap.hexa_rtsc.

Runs `kicad-cli` to verify schematic + PCB files parse correctly without
running KiCad GUI. Generates ERC report, BOM CSV, and Gerber output if
schematic/PCB are valid.

Honesty: KiCad CLI verifies syntax + ERC. It does NOT validate against
real-board functionality. Phase E2 (procurement + first PCB fab + cold-
test) requires actual PCB and is out of code-layer scope (~$25k).

Usage:
    python3 build_kicad.py erc           # ERC report on schematic
    python3 build_kicad.py netlist       # generate netlist from schematic
    python3 build_kicad.py gerber        # PCB → Gerber files (requires .kicad_pcb)
    python3 build_kicad.py bom           # generate BOM CSV
    python3 build_kicad.py all           # all of the above

Requires:
    KiCad 7.0+ installed (kicad-cli must be in PATH).
    macOS:  brew install --cask kicad
    Linux:  apt install kicad
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

THIS_DIR = Path(__file__).parent.resolve()
OUT_DIR = THIS_DIR / "build"

# All schematic targets (Phase E1+ multi-board)
SCH_TARGETS = [
    "quench_detect",
    "synthesis_chamber",
    "calorimetry_rig",
    "squid_host_adapter",
    "power_tree",
]

# Boards with PCB layout files (Phase E2 progresses incrementally)
PCB_TARGETS = [
    "quench_detect",   # skeleton ships in Phase E1+ (4-layer stackup, board outline only)
]

BOM_CSV = THIS_DIR / "bom_kicad.csv"


def find_kicad_cli():
    """Locate kicad-cli; return path or None."""
    cli = shutil.which("kicad-cli")
    if cli:
        return cli
    # macOS app bundle fallback
    candidates = [
        "/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli",
        "/Applications/KiCad/kicad-cli",
    ]
    for c in candidates:
        if Path(c).exists():
            return c
    return None


def run_cmd(cmd, label):
    """Run shell command, print output, return returncode."""
    print(f"  → {label}")
    print(f"    cmd: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        print(f"    [TIMEOUT] command exceeded 120 s")
        return 124
    print(result.stdout.strip())
    if result.stderr.strip():
        print(f"    stderr: {result.stderr.strip()}")
    return result.returncode


def cmd_erc(cli):
    """Run ERC on every schematic in SCH_TARGETS."""
    OUT_DIR.mkdir(exist_ok=True)
    rc = 0
    for target in SCH_TARGETS:
        sch = THIS_DIR / f"{target}.kicad_sch"
        if not sch.exists():
            print(f"    [SKIP] {sch.name} not present")
            continue
        cmd = [
            cli, "sch", "erc",
            "--output", str(OUT_DIR / f"erc_{target}.txt"),
            "--format", "report",
            str(sch)
        ]
        rc |= run_cmd(cmd, f"ERC: {target}")
    return rc


def cmd_netlist(cli):
    """Generate netlist for every schematic."""
    OUT_DIR.mkdir(exist_ok=True)
    rc = 0
    for target in SCH_TARGETS:
        sch = THIS_DIR / f"{target}.kicad_sch"
        if not sch.exists():
            continue
        cmd = [
            cli, "sch", "export", "netlist",
            "--output", str(OUT_DIR / f"netlist_{target}.net"),
            "--format", "kicadsexpr",
            str(sch)
        ]
        rc |= run_cmd(cmd, f"Netlist: {target}")
    return rc


def cmd_bom(cli):
    """Generate BOM CSV for every schematic."""
    OUT_DIR.mkdir(exist_ok=True)
    rc = 0
    for target in SCH_TARGETS:
        sch = THIS_DIR / f"{target}.kicad_sch"
        if not sch.exists():
            continue
        cmd = [
            cli, "sch", "export", "bom",
            "--output", str(OUT_DIR / f"bom_{target}.csv"),
            "--fields", "Reference,Value,Footprint,Manufacturer,MPN,Datasheet",
            str(sch)
        ]
        rc |= run_cmd(cmd, f"BOM: {target}")
    return rc


def cmd_gerber(cli):
    """Generate Gerber files for every PCB target (Phase E2)."""
    OUT_DIR.mkdir(exist_ok=True)
    rc = 0
    for target in PCB_TARGETS:
        pcb = THIS_DIR / f"{target}.kicad_pcb"
        if not pcb.exists():
            print(f"    [SKIP] {target}.kicad_pcb not yet authored — Phase E2 deliverable.")
            continue
        gerber_dir = OUT_DIR / f"gerbers_{target}"
        gerber_dir.mkdir(exist_ok=True)
        cmd = [
            cli, "pcb", "export", "gerbers",
            "--output", str(gerber_dir),
            "--layers", "F.Cu,B.Cu,F.Mask,B.Mask,F.SilkS,B.SilkS,Edge.Cuts",
            str(pcb)
        ]
        rc |= run_cmd(cmd, f"Gerber: {target}")
    return rc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("step", choices=["erc", "netlist", "bom", "gerber", "all"])
    args = parser.parse_args()

    cli = find_kicad_cli()
    if not cli:
        print("=========================================================================")
        print("  [SKIP] kicad-cli not found in PATH or /Applications/KiCad/")
        print("         Install via:  brew install --cask kicad   (macOS)")
        print("                       apt install kicad           (Linux/Ubuntu)")
        print("         This script verifies schematic parse + ERC + BOM gen.")
        print("         Without KiCad, Phase E1 status: skeleton-only (verified-not-tested).")
        print("=========================================================================")
        # Phase E1 honesty: skeleton is checked into repo, parse not verified locally.
        # CI on a Linux runner with KiCad available WILL run this.
        sys.exit(0)

    print(f"=========================================================================")
    print(f"  hexa-rtsc Phase E1+ — KiCad CLI build (multi-target)")
    print(f"  cli: {cli}")
    print(f"  sch targets: {len(SCH_TARGETS)} ({', '.join(SCH_TARGETS)})")
    print(f"  pcb targets: {len(PCB_TARGETS)} ({', '.join(PCB_TARGETS)})")
    print(f"=========================================================================")

    rc = 0
    if args.step in ("erc", "all"):
        rc |= cmd_erc(cli)
    if args.step in ("netlist", "all"):
        rc |= cmd_netlist(cli)
    if args.step in ("bom", "all"):
        rc |= cmd_bom(cli)
    if args.step in ("gerber", "all"):
        rc |= cmd_gerber(cli)

    print()
    if rc == 0:
        print("  __HEXA_RTSC_EDA_BUILD__ PASS")
    else:
        print(f"  __HEXA_RTSC_EDA_BUILD__ FAIL (rc={rc})")
    sys.exit(rc)


if __name__ == "__main__":
    main()
