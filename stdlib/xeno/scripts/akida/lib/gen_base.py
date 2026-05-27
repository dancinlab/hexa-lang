"""Backend abstract interface — every Akida generation impl satisfies this.

Scope: this layer is a SUBSTRATE ADAPTER. It owns device probe, model
deploy, forward pass, and substrate-level telemetry (latency, event count,
power-if-available). It does NOT own phi calculation, trace bisimulation,
or other application-level analytics — those live in the caller (anima
phi calculator, nexus falsifier scripts) which receive the raw outputs
from `forward()` and apply their own logic.

This split keeps gen-handling SSOT minimal and avoids leaking falsifier
semantics into substrate code (own 18 simple stack).
"""
from __future__ import annotations
from typing import Any


class BackendError(Exception):
    """Backend method genuinely failed (hardware/runtime error)."""


class NotAvailable(BackendError):
    """Capability not provided by this generation (honest fail-loud).

    Distinct from BackendError: caller should treat as 'capability gap',
    not 'measurement error'. Falsifier verdict path: BLOCKED-CAPABILITY-GAP.
    """


class Backend:
    """Per-generation Akida substrate adapter.

    Subclass contract:
      * generation        : int    (1, 2, 3, ...)
      * version_pattern   : str    (regex on device.version, group(1) = gen num)
      * marketing_name    : str    ("AKD1000", "Akida 2 FPGA", ...)

    Methods raise NotAvailable when the underlying hardware/SDK does not
    expose the capability. Callers catch NotAvailable and emit honest
    """

    generation: int = 0
    version_pattern: str = r"^BC\.A0\."
    marketing_name: str = "unknown"

    # ---- device-level ----

    def device_present(self) -> bool:
        raise NotImplementedError

    def device_info(self) -> dict[str, Any]:
        """Return {version, marketing_name, generation, available, ...}."""
        raise NotImplementedError

    def mesh_summary(self) -> dict[str, Any]:
        """NP count, layer types, dma config — capability snapshot."""
        raise NotImplementedError

    # ---- model-level ----

    def forward(self, model_path: str, inputs) -> dict[str, Any]:
        """Deploy model + run forward pass over `inputs` (numpy array).

        Caller supplies inputs of the right dtype/shape (per model spec).
        Backend returns raw outputs + substrate telemetry, no semantics.

        Returns:
            {
              "outputs":            numpy.ndarray,   # raw model outputs
              "wall_seconds":       float,
              "n_events":           int,
              "latency_per_event_us": float,
              "input_shape":        tuple,
              "output_shape":       tuple,
              "raw":                {...gen-specific telemetry...},
            }

        Raises NotAvailable when this generation cannot deploy/forward
        (e.g. gen1 without dev kit, gen3 unreleased).
        """
        raise NotImplementedError

    def run_inference(self, model_path: str | None, n_events: int) -> dict[str, Any]:
        """Convenience wrapper: forward over synthetic random inputs.

        Used for capability probing / latency baselining without requiring
        a real dataset. Without `model_path` returns telemetry-only stub.
        """
        raise NotImplementedError

    def measure_power(self, n_events: int, model_path: str | None = None) -> dict[str, Any]:

        Schema:
            {
              "available":               bool,
              "method":                  str,
              "vendor_estimate_required": bool,
              "watts_idle":               float | None,
              "watts_inference":          float | None,
              "joules_per_event":         float | None,
              "note":                     str,
            }
        """
        raise NotImplementedError

    def capture_spike_trace(
        self, model_path: str, n_steps: int, batch_size: int = 1,
    ) -> dict[str, Any]:
        """Step-by-step forward pass; record per-step latency + output norms.

        Used by F-L6 (Lyapunov sweep) and substrate-dynamics analyses to
        produce a trajectory `[(t, latency_us, ||y||_2), ...]`.

        Without model_path, raises NotAvailable (no synthetic dynamics).
        """
        raise NotImplementedError

    # ---- capability matrix ----

    def capabilities(self) -> dict[str, bool]:
        """Boolean snapshot for capability gating in callers."""
        return {
            "device_probe":      False,
            "mesh_introspect":   False,
            "forward":           False,
            "run_inference":     False,
            "power_measure":     False,
            "spike_capture":     False,
        }
