"""xeno akida lib — generation-aware substrate backend.

Public surface:
    detect_generation()  -> int | None       # from device.version
    get_backend(gen=auto) -> Backend         # registry lookup
    list_generations()   -> list[int]        # supported gens

own 34 mandate-4: source repo (anima/nexus) untouched. Generation-handling
SSOT lives here in xeno; nexus/anima runner.py invoked unchanged via wrapper.
"""
from .gen_registry import (
    detect_generation,
    get_backend,
    list_generations,
    register_backend,
    REGISTRY,
)
from .gen_base import Backend, BackendError, NotAvailable

__all__ = [
    "Backend",
    "BackendError",
    "NotAvailable",
    "REGISTRY",
    "detect_generation",
    "get_backend",
    "list_generations",
    "register_backend",
]
