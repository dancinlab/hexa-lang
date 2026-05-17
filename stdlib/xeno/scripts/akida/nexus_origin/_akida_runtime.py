"""Akida runtime resolver with three substrate tiers:

    tier 1: real akida package + AKD1000 device     (substrate=akida_hw)
    tier 2: real akida package, no device           (substrate=akida_pkg_only)
    tier 3: cnn2snn_emulator fallback (CPU)         (substrate=cpu_emulator_cnn2snn_stub)

Honesty contract: only tier-1 evidence is promotion-eligible. tier-2/3 evidence
must carry substrate marker so F-C barrier can refuse PASS impersonation.

Env override:
    AKIDA_FORCE_EMULATOR=1   skip package/device detection, force tier 3.
"""
from __future__ import annotations
import importlib, os, sys


def try_akida():
    if os.environ.get("AKIDA_FORCE_EMULATOR") == "1":
        return (None, False)
    try:
        ak = importlib.import_module("akida")
    except ImportError:
        return (None, False)
    try:
        devs = ak.devices()
        return (ak, len(devs) > 0)
    except Exception:
        return (ak, False)


def resolve_substrate():
    ak, dev = try_akida()
    if ak is not None and dev:
        return ("akida_hw", ak)
    if ak is not None:
        return ("akida_pkg_only", ak)
    try:
        em = importlib.import_module("cnn2snn_emulator")
    except ImportError:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        em = importlib.import_module("cnn2snn_emulator")
    return ("cpu_emulator_cnn2snn_stub", em)


def require_akida(need_device: bool = True):
    ak, dev = try_akida()
    if ak is None:
        print(
            "ERROR: 'akida' package missing. Install BrainChip Meta TF SDK:\n"
            "  pip install akida quantizeml cnn2snn\n"
            "  (or set AKIDA_FORCE_EMULATOR=1 to use cpu_emulator stub — non-promotion)",
            file=sys.stderr,
        )
        raise SystemExit(2)
    if need_device and not dev:
        print(
            "ERROR: no AKD1000 device detected via akida.devices(). "
            "Either dev kit not powered/connected, or driver missing.\n"
            "  (or set AKIDA_FORCE_EMULATOR=1 to use cpu_emulator stub — non-promotion)",
            file=sys.stderr,
        )
        raise SystemExit(3)
    return ak
