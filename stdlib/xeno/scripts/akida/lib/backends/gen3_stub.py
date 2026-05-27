"""Gen 3 — forward-compat stub for unannounced future Akida silicon.

**Important**: as of 2026-05-09 deep research, BrainChip has NOT publicly
committed to an "Akida 3" generation. The known silicon roadmap is:

  AKD1000 (TSMC 28nm, 2022 양산, Akida 1)
  AKD1500 (GF 22nm FD-SOI, 2025-11-04 발표, 2026 Q3 양산, Akida 1 co-processor)
  AKD2000 (marketing 이름이 vapor — silicon 출시 안됨)
  AKD2500 (TSMC 12nm, 2026-02-13 project 시작, Q3 2026 prototype, Akida 2 silicon)

Akida 2 generation은 silicon AKD2500이 첫 작품 — gen3는 그 이후 generation을
가리키며, 공개 발표 없음. 이 파일은 plugin path가 작동함을 보여주는
forward-compat 스텁이지 구체적 silicon에 대한 commit이 아님.

When BrainChip announces a true 3rd-generation IP/silicon (BC.A3.* version
prefix), replace this stub with a real backend (`gen3_<silicon_name>.py`)
implementing forward + spike_capture + power lanes per the new SDK.

Plugin pattern (when adding any future generation):
  1. Create backends/genN_<silicon>.py with NotAvailable-raising methods
     converted to real ones.
  2. Match `version_pattern = r"^BC\\.AN\\."` so auto-detect picks it up.
  3. Call `register_backend(N, ClassName)` at module import time.
  4. No edits to gen_registry.py / gen_base.py needed.

Reference: docs/anima_origin/akida_brainchip_deep_research_2026_05_09.md §1
"""
from __future__ import annotations
from typing import Any
from ..gen_base import Backend, NotAvailable
from ..gen_registry import register_backend


class FutureSiliconStub(Backend):
    """Stub for any future Akida generation past Akida 2 (AKD2500).

    Class name avoids "Gen3" / "Akida3" labels because no such product
    has been announced. Registry slot 3 is reserved as plugin demonstration —
    when (and if) BrainChip ships BC.A3.* silicon, swap this stub with a
    real backend.
    """

    generation = 3
    version_pattern = r"^BC\.A3\."
    marketing_name = "future Akida silicon (unannounced)"

    def device_present(self) -> bool:
        return False

    def device_info(self) -> dict[str, Any]:
        return {
            "version":        None,
            "marketing_name": self.marketing_name,
            "generation":     3,
            "available":      False,
            "note": (
                "BC.A3.* not announced as of 2026-05-09. AKD2500 (Akida 2 silicon, "
                "TSMC 12nm) prototype is Q3 2026; future-gen silicon beyond that "
                "has no public roadmap. This stub exists as plugin demonstration."
            ),
        }

    def mesh_summary(self) -> dict[str, Any]:
        raise NotAvailable("future-gen silicon unannounced — stub only")

    def forward(self, model_path, inputs):
        raise NotAvailable("future-gen silicon unannounced — stub only")

    def run_inference(self, model_path, n_events):
        raise NotAvailable("future-gen silicon unannounced — stub only")

    def measure_power(self, n_events, model_path=None):
        return {
            "available":                False,
            "method":                   "unannounced",
            "vendor_estimate_required": False,
            "watts_idle":               None,
            "watts_inference":          None,
            "joules_per_event":         None,
            "note":                     "BC.A3.* product not announced; no measurement path",
        }

    def capture_spike_trace(self, model_path, n_steps, batch_size=1):
        raise NotAvailable("future-gen silicon unannounced — stub only")

    def capabilities(self) -> dict[str, bool]:
        return {k: False for k in super().capabilities()}


register_backend(3, FutureSiliconStub)
