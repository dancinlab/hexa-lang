"""Fallback backend used when device.version doesn't match any registered gen.

Every method raises NotAvailable — caller must treat as 'no substrate available'
"""
from __future__ import annotations
from typing import Any
from ..gen_base import Backend, NotAvailable


class UnknownBackend(Backend):
    generation = 0
    version_pattern = r"^$"
    marketing_name = "unknown / no device"

    def device_present(self) -> bool:
        return False

    def device_info(self) -> dict[str, Any]:
        return {
            "version":         None,
            "marketing_name":  self.marketing_name,
            "generation":      0,
            "available":       False,
            "note":            "no Akida device detected; --akida-gen=auto fell through",
        }

    def mesh_summary(self) -> dict[str, Any]:
        raise NotAvailable("no device — mesh introspection N/A")

    def forward(self, model_path, inputs):
        raise NotAvailable("no device — forward pass N/A")

    def run_inference(self, model_path, n_events):
        raise NotAvailable("no device — inference N/A")

    def measure_power(self, n_events, model_path=None):
        return {
            "available":                False,
            "method":                   "no_device",
            "vendor_estimate_required": False,
            "watts_idle":               None,
            "watts_inference":          None,
            "joules_per_event":         None,
            "note":                     "no Akida device detected",
        }

    def capture_spike_trace(self, model_path, n_steps, batch_size=1):
        raise NotAvailable("no device — spike capture N/A")

    def capabilities(self) -> dict[str, bool]:
        return {k: False for k in super().capabilities()}
