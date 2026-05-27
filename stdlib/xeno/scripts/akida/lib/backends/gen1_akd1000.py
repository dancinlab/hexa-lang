"""Gen 1 — AKD1000 (Akida 1.x silicon, RPi5 + M.2 dev kit).

Status: dev kit ordered 2026-04-29, ETA pending. Until physical chip lands
we cannot exercise this backend; methods raise NotAvailable when invoked
without a connected gen-1 device.

Power path: external (RAPL on host CPU + USB shunt) — not in-band.
Reference: docs/anima_origin/akida_dev_kit_evaluation_2026-04-29.md.
"""
from __future__ import annotations
from typing import Any
from ..gen_base import Backend, NotAvailable
from ..gen_registry import register_backend


class Gen1AKD1000Backend(Backend):
    generation = 1
    version_pattern = r"^BC\.A1\."
    marketing_name = "AKD1000 (Akida 1.x silicon)"

    def _device(self):
        try:
            import akida  # type: ignore[import-not-found]
        except ImportError as e:
            raise NotAvailable("akida package not installed") from e
        devs = akida.devices()
        if not devs:
            raise NotAvailable("no Akida device connected")
        d = devs[0]
        v = str(d.version)
        if not v.startswith("BC.A1."):
            raise NotAvailable(
                f"connected device version {v!r} is not gen-1 "
                f"(expected BC.A1.*); use --akida-gen=auto or matching gen"
            )
        return d

    def device_present(self) -> bool:
        try:
            self._device()
            return True
        except NotAvailable:
            return False

    def device_info(self) -> dict[str, Any]:
        try:
            d = self._device()
        except NotAvailable as e:
            return {
                "version": None, "marketing_name": self.marketing_name,
                "generation": 1, "available": False, "note": str(e),
            }
        return {
            "version":        str(d.version),
            "marketing_name": self.marketing_name,
            "generation":     1,
            "available":      True,
            "soc_present":    d.soc is not None,
        }

    def mesh_summary(self) -> dict[str, Any]:
        d = self._device()
        return {"raw": str(d.mesh)[:500], "generation": 1}

    def forward(self, model_path, inputs):
        raise NotAvailable(
            "gen1 forward pass requires AKD1000 dev kit + cnn2snn 1.x; "
            "implementation lands when physical kit arrives"
        )

    def run_inference(self, model_path, n_events):
        raise NotAvailable(
            "gen1 inference path requires cnn2snn 1.x .fbz deploy + AKD1000 "
            "M.2 dev kit; not implemented for cloud (Akida 2 FPGA only)"
        )

    def measure_power(self, n_events, model_path=None):
        return {
            "available":                False,
            "method":                   "external_rapl_plus_usb_shunt",
            "vendor_estimate_required": False,
            "watts_idle":               None,
            "watts_inference":          None,
            "joules_per_event":         None,
            "note": (
                "AKD1000 power requires (a) host CPU RAPL with root, "
                "(b) USB shunt for board-level draw. Both off-chip; "
                "implementation lands when physical dev kit arrives."
            ),
        }

    def capture_spike_trace(self, model_path, n_steps, batch_size=1):
        raise NotAvailable("gen1 spike capture pending dev-kit arrival")

    def capabilities(self) -> dict[str, bool]:
        present = self.device_present()
        return {
            "device_probe":    present,
            "mesh_introspect": present,
            "forward":         False,  # SDK path not yet wired
            "run_inference":   False,
            "power_measure":   False,  # external instrumentation only
            "spike_capture":   False,
        }


register_backend(1, Gen1AKD1000Backend)
