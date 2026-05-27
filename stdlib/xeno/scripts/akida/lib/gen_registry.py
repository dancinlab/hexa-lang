"""Generation registry + auto-detection from akida device.version string.

Version format (BrainChip): `BC.A<gen>.<rev>.<build>` — e.g. `BC.A2.001.000`.
Detection extracts the integer following `BC.A`. Future generations (BC.A3,
BC.A4, ...) plug in via `register_backend(gen, BackendCls)` with no edits
to this file.
"""
from __future__ import annotations
import re
from typing import Type
from .gen_base import Backend, BackendError

REGISTRY: dict[int, Type[Backend]] = {}

_VERSION_RE = re.compile(r"^BC\.A(\d+)\.")


def register_backend(gen: int, cls: Type[Backend]) -> None:
    """Register a Backend subclass under its generation number.

    Idempotent: re-registering the same gen replaces the prior class
    (allows hot-swapping during dev).
    """
    if not isinstance(gen, int) or gen < 1:
        raise ValueError(f"generation must be int >= 1, got {gen!r}")
    REGISTRY[gen] = cls


def list_generations() -> list[int]:
    return sorted(REGISTRY.keys())


def detect_generation(version: str | None = None) -> int | None:
    """Parse `version` (e.g. 'BC.A2.001.000') -> 2. Return None if no match.

    If `version is None`, probe the connected device via akida.devices().
    Returns None if no device present (caller decides fallback).
    """
    if version is None:
        try:
            import akida  # type: ignore[import-not-found]
            devs = akida.devices()
            if not devs:
                return None
            version = devs[0].version
        except (ImportError, AttributeError, OSError):
            return None

    # akida 2.x returns akida.core.HwVersion (not str). Coerce via str().
    version_str = version if isinstance(version, str) else str(version)
    if not version_str:
        return None
    m = _VERSION_RE.match(version_str)
    if not m:
        return None
    try:
        return int(m.group(1))
    except (ValueError, IndexError):
        return None


def get_backend(gen: int | str = "auto") -> Backend:
    """Resolve and instantiate a Backend for the requested generation.

    Args:
        gen: int (explicit), or "auto" (detect from connected device).

    Raises:
        BackendError if requested gen isn't registered, or if "auto" and
        no device is present and no fallback is registered.
    """
    if gen == "auto" or gen is None:
        detected = detect_generation()
        if detected is None:
            from .backends._unknown import UnknownBackend
            return UnknownBackend()
        target = detected
    else:
        try:
            target = int(gen)
        except (TypeError, ValueError) as e:
            raise BackendError(f"invalid --akida-gen: {gen!r}") from e

    cls = REGISTRY.get(target)
    if cls is None:
        known = list_generations()
        raise BackendError(
            f"no backend registered for gen={target}; "
            f"known generations: {known}. "
            f"To add a new generation, write a Backend subclass and call "
            f"register_backend({target}, YourBackendCls)."
        )
    return cls()


# Eagerly load built-in backends so REGISTRY is populated on `import xeno.akida.lib`.
def _bootstrap() -> None:
    from .backends import gen1_akd1000, gen2_a2_fpga, gen3_stub  # noqa: F401


_bootstrap()
