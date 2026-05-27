"""Gen 2 — Akida 2 FPGA (BrainChip Cloud, Colfax-hosted).

Connected device version on cloud (probed 2026-05-09): `BC.A2.001.000`.
Mesh: 24 NPs, ip_version=v2, soc=None (FPGA emulation, not silicon AKD2500).

Power measurement (3-phase plan):
  Phase 1 (current): m.statistics provides `fps / inference_clk / program_clk
    / energy / powers`. On FPGA cloud `energy=None` and `powers={}` (silicon-only),
    but `fps + inference_clk` are real measurements — we surface those as
    `available: cloud_clock_estimate` (NOT silicon-equivalent watts).
  Phase 2: BrainChip Solution Architects RTL-level estimate via sales@brainchip.com
    (separate NDA engagement).
  Phase 3: AKD2500 prototype (TSMC 12nm, Q3 2026) — direct silicon measurement.

  Source: bc_cloud_examples/Eye_Tracking.ipynb §4, doc.brainchipinc.com runtime API.

Forward pass: int8 inputs required (`m.forward()` rejects uint8).
Mapping path: hw_only=True attempted first; on failure falls back to multi-pass.
"""
from __future__ import annotations
import contextlib, io, re, time
from typing import Any
from ..gen_base import Backend, NotAvailable
from ..gen_registry import register_backend


# Akida 2 mesh layer types per doc.brainchipinc.com/api_reference/akida_apis.html.
# We extract two distinct distributions:
#   model_np_counts — what the deployed model uses (from model.summary()
#     "Component (type) Count" table); falsifiers compare this against
#     expected fingerprints.
#   mesh_np_counts — what the mesh provides (from `<Type.X:>` repr in
#     device.mesh); shows hardware capability ceiling.
_NP_TYPES = ("HRC", "CNP1", "CNP2", "FNP2", "FNP3", "TNP_B",
             "SKIP_DMA_STORE", "SKIP_DMA_LOAD")
_MESH_TYPE_RE = re.compile(r"<Type\.([A-Z0-9_]+):")
_MODEL_NP_LINE_RE = re.compile(r"^([A-Z][A-Z0-9_]*)\s+(\d+)\s*$", re.MULTILINE)


class Gen2A2FPGABackend(Backend):
    generation = 2
    version_pattern = r"^BC\.A2\."
    marketing_name = "Akida 2 FPGA (BrainChip Cloud)"

    # ---- device-level ----

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
        if not v.startswith("BC.A2."):
            raise NotAvailable(
                f"connected device version {v!r} is not gen-2 (expected BC.A2.*)"
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
                "generation": 2, "available": False, "note": str(e),
            }
        return {
            "version":        str(d.version),
            "marketing_name": self.marketing_name,
            "generation":     2,
            "available":      True,
            "soc_present":    d.soc is not None,
            "ip_version":     str(getattr(d, "ip_version", None)),
            "learn_enabled":  bool(getattr(d, "learn_enabled", False)),
        }

    def mesh_summary(self) -> dict[str, Any]:
        d = self._device()
        m = d.mesh
        nps = list(getattr(m, "nps", []))
        skip = list(getattr(m, "skip_dmas", []))
        repr_text = str(m)
        mesh_np_counts = {t: 0 for t in _NP_TYPES}
        for hit in _MESH_TYPE_RE.finditer(repr_text):
            t = hit.group(1)
            if t in mesh_np_counts:
                mesh_np_counts[t] += 1
        return {
            "generation":     2,
            "n_nps":          len(nps),
            "n_skip_dmas":    len(skip),
            "dma_event":      str(getattr(m, "dma_event", None)),
            "dma_conf":       str(getattr(m, "dma_conf", None)),
            "mesh_np_counts": mesh_np_counts,
            "raw_repr_head":  repr_text[:400],
        }

    # ---- model-level ----

    def _load_and_map(self, model_path: str) -> tuple:
        """Load model + map. Try hw_only=True first (single-sequence guarantee);
        fall back to default multi-pass mapping. Returns (device, model, mapping_meta)."""
        try:
            import akida  # type: ignore[import-not-found]
        except ImportError as e:
            raise NotAvailable("akida package not installed") from e
        d = self._device()
        try:
            model = akida.Model(filename=model_path)
        except (FileNotFoundError, RuntimeError, ValueError, OSError) as e:
            raise NotAvailable(f"model load failed: {e}") from e

        mapping_meta = {"hw_only_attempted": True, "hw_only_succeeded": False, "fallback_used": False}
        try:
            model.map(d, hw_only=True)
            mapping_meta["hw_only_succeeded"] = True
        except (RuntimeError, ValueError) as e:
            mapping_meta["hw_only_error"] = str(e)
            try:
                model.map(d)
                mapping_meta["fallback_used"] = True
            except (RuntimeError, ValueError) as e2:
                raise NotAvailable(f"model.map failed both hw_only and default: {e2}") from e2

        mapping_meta.update(self._summary_capture(model))
        return d, model, mapping_meta

    def _input_dtype_for(self, model):
        """Detect required input dtype from model first layer parameters.

        InputData layers (e.g. TENN spatiotemporal eye tracking) expose
        `parameters.input_signed = True` → int8. InputConvolutional layers
        (e.g. centernet, jester) do not expose input_signed → uint8 (image
        pixel domain). Falls back to int8 only if explicitly signed,
        else uint8 (pixel-style models are the more common Akida case).
        """
        import numpy as np  # type: ignore[import-not-found]
        signed = None
        try:
            params = model.layers[0].parameters
            # akida.core.LayerParams raises ValueError("Key X not found") on
            # missing attrs instead of AttributeError — we catch both.
            signed = params.input_signed
        except (AttributeError, IndexError, ValueError):
            signed = None
        # `signed` may be Python bool, int (1/0), or None — treat any truthy as int8.
        return np.int8 if bool(signed) else np.uint8

    def _summary_capture(self, model) -> dict[str, Any]:
        """Capture model.summary() output + parse mesh allocation evidence.

        Extracts NP type counts (HRC / CNP1 / CNP2 / FNP2 / FNP3 / TNP_B) plus
        the summary header line (Sequences / Layers / NPs / Skip DMAs / External
        Memory). Used by falsifier scripts to verify mesh allocation matches
        a model's expected fingerprint.
        """
        buf = io.StringIO()
        try:
            with contextlib.redirect_stdout(buf):
                model.summary()
        except (RuntimeError, AttributeError) as e:
            return {"summary_error": str(e), "np_counts": {}}
        text = buf.getvalue()
        model_np_counts: dict[str, int] = {}
        for hit in _MODEL_NP_LINE_RE.finditer(text):
            name, count = hit.group(1), int(hit.group(2))
            # Filter out header / shape lines that match the regex by accident
            # (e.g. "Layers 20"). Keep only known NP-type tokens.
            if name in _NP_TYPES:
                model_np_counts[name] = model_np_counts.get(name, 0) + count
        return {
            "summary":          text[:1500],
            "summary_full_len": len(text),
            "model_np_counts":  model_np_counts,
        }

    def _stats_snapshot(self, model, device) -> dict[str, Any]:
        """Snapshot of model.statistics + device.metrics after a forward pass.

        Cloud FPGA: energy=None, powers={}, but fps + inference_clk are real.
        Silicon (AKD1000 / future AKD2500): all fields populated.
        """
        out: dict[str, Any] = {}
        try:
            s = model.statistics
            out["fps"]            = float(s.fps) if s.fps is not None else None
            out["inference_clk"]  = int(s.inference_clk) if s.inference_clk is not None else None
            out["program_clk"]    = int(s.program_clk) if s.program_clk is not None else None
            out["energy"]         = (float(s.energy) if s.energy is not None else None)
            out["powers"]         = dict(s.powers) if s.powers else {}
        except (AttributeError, RuntimeError, ValueError) as e:
            out["statistics_error"] = str(e)
        try:
            names = list(getattr(device.metrics, "names", []) or [])
            out["device_metrics"] = {n: device.metrics[n] for n in names}
        except (AttributeError, KeyError, RuntimeError) as e:
            out["device_metrics_error"] = str(e)
        return out

    def forward(self, model_path: str, inputs) -> dict[str, Any]:
        try:
            import numpy as np  # type: ignore[import-not-found]
        except ImportError as e:
            raise NotAvailable("numpy not installed") from e
        if not isinstance(model_path, str) or not model_path:
            raise ValueError("forward() requires model_path")

        d, model, mapping_meta = self._load_and_map(model_path)

        expected_dtype = self._input_dtype_for(model)
        if inputs.dtype != expected_dtype:
            raise ValueError(
                f"Akida 2 forward() expects {expected_dtype.__name__} for this "
                f"model (first-layer input_signed inferred); got {inputs.dtype}"
            )

        ipe_before = len(d.inference_power_events)
        t0 = time.perf_counter()
        outputs = model.forward(inputs)
        wall = time.perf_counter() - t0
        ipe_after = len(d.inference_power_events)

        n_events = int(inputs.shape[0]) if inputs.ndim >= 1 else 1
        stats = self._stats_snapshot(model, d)
        return {
            "outputs":             outputs,
            "wall_seconds":        wall,
            "n_events":            n_events,
            "latency_per_event_us": (wall / n_events) * 1e6 if n_events else 0.0,
            "input_shape":         tuple(inputs.shape),
            "output_shape":        tuple(outputs.shape),
            "input_dtype":         str(inputs.dtype),
            "output_dtype":        str(outputs.dtype),
            "mapping":             mapping_meta,
            "stats":               stats,
            "raw": {
                "model_path":         model_path,
                "ipe_buffer_growth":  ipe_after - ipe_before,
                "ipe_buffer_total":   ipe_after,
                "model_input_shape":  tuple(model.input_shape),
                "model_output_shape": tuple(model.output_shape),
            },
        }

    def run_inference(self, model_path, n_events):
        try:
            import numpy as np  # type: ignore[import-not-found]
        except ImportError as e:
            raise NotAvailable("numpy not installed") from e
        if n_events <= 0:
            raise ValueError(f"n_events must be > 0, got {n_events}")

        if model_path is None:
            d = self._device()
            return {
                "outputs":             None,
                "n_events":            0,
                "wall_seconds":        0.0,
                "latency_per_event_us": None,
                "raw": {
                    "model_path": None,
                    "note":       "no model — telemetry-only probe",
                    "ipe_total":  len(d.inference_power_events),
                },
            }

        d, model, mapping_meta = self._load_and_map(model_path)
        in_shape = tuple(model.input_shape)
        dtype = self._input_dtype_for(model)
        rng = np.random.default_rng(seed=42)
        if dtype == np.int8:
            X = rng.integers(-128, 127, size=(n_events, *in_shape), dtype=np.int8)
        else:
            X = rng.integers(0, 256, size=(n_events, *in_shape), dtype=np.uint8)

        ipe_before = len(d.inference_power_events)
        t0 = time.perf_counter()
        outputs = model.forward(X)
        wall = time.perf_counter() - t0
        ipe_after = len(d.inference_power_events)
        stats = self._stats_snapshot(model, d)

        return {
            "outputs":             None,
            "n_events":            n_events,
            "wall_seconds":        wall,
            "latency_per_event_us": (wall / n_events) * 1e6,
            "input_shape":         tuple(X.shape),
            "input_dtype":         str(X.dtype),
            "output_shape":        tuple(outputs.shape),
            "mapping":             mapping_meta,
            "stats":               stats,
            "raw": {
                "model_path":        model_path,
                "ipe_buffer_growth": ipe_after - ipe_before,
                "ipe_buffer_total":  ipe_after,
                "outputs_summary": {
                    "min":  float(outputs.min()),
                    "max":  float(outputs.max()),
                    "mean": float(outputs.mean()),
                    "std":  float(outputs.std()),
                },
                "input_seed": 42,
            },
        }

    def measure_power(self, n_events, model_path=None):
        """3-phase power record (Phase 1 active on cloud FPGA).

        Phase 1 — `m.statistics.fps + inference_clk + program_clk` collected
            as `cloud_clock_estimate`. energy/powers stay None on FPGA.
        Phase 2 — sales@brainchip.com RTL estimate (separate engagement).
        Phase 3 — AKD2500 silicon (Q3 2026 prototype) direct measurement.

        Caller MUST treat cloud_clock_estimate as a proxy, not silicon watts.
        """
        try:
            d = self._device()
        except NotAvailable as e:
            return {
                "available":                False,
                "method":                   "no_device",
                "vendor_estimate_required": False,
                "watts_idle":               None,
                "watts_inference":          None,
                "joules_per_event":         None,
                "note":                     str(e),
            }

        # Try silicon SoC power-measurement gate (only AKD1000 / future AKD2500).
        soc_pme = None
        try:
            if d.soc is not None:
                d.soc.power_measurement_enabled = True
                soc_pme = True
        except (AttributeError, RuntimeError) as e:
            soc_pme = f"unavailable: {e}"

        # Phase 1 — clock-cycle estimate via m.statistics, requires a forward run.
        cloud_estimate = None
        if model_path:
            try:
                import numpy as np  # type: ignore[import-not-found]
                _, model, _ = self._load_and_map(model_path)
                in_shape = tuple(model.input_shape)
                dtype = self._input_dtype_for(model)
                rng = np.random.default_rng(seed=11)
                if dtype == np.int8:
                    X = rng.integers(-128, 127, size=(max(1, n_events), *in_shape), dtype=np.int8)
                else:
                    X = rng.integers(0, 256, size=(max(1, n_events), *in_shape), dtype=np.uint8)
                model.forward(X)
                cloud_estimate = self._stats_snapshot(model, d)
            except (NotAvailable, ImportError, RuntimeError, ValueError) as e:
                cloud_estimate = {"error": str(e)}

        ipe_len = len(d.inference_power_events)
        return {
            "available":                False if cloud_estimate is None else "cloud_clock_estimate",
            "method":                   ("rtl_estimate_required" if cloud_estimate is None
                                         else "fps_clock_proxy_via_m_statistics"),
            "vendor_estimate_required": True,  # for true silicon-equivalent watts
            "watts_idle":               None,
            "watts_inference":          None,
            "joules_per_event":         None,
            "cloud_estimate":           cloud_estimate,
            "soc_power_measurement_enabled": soc_pme,
            "raw": {
                "inference_power_events_len": ipe_len,
                "inference_power_events_sample": (
                    [repr(x) for x in d.inference_power_events[:5]] if ipe_len else []
                ),
            },
            "note": (
                "Akida 2 FPGA cloud: silicon-equivalent watts NOT available. "
                "Phase 1 surfaces fps + inference_clk + program_clk via "
                "m.statistics (cloud_clock_estimate, real measurement but FPGA-clock). "
                "Phase 2: BrainChip Solution Architects RTL estimate via "
                "sales@brainchip.com (separate NDA engagement). "
                "Phase 3: AKD2500 silicon prototype Q3 2026. "
                "Source: bc_cloud_examples/Eye_Tracking.ipynb §4 + "
                "doc.brainchipinc.com/api_reference/akida_apis.html (Statistics)."
            ),
        }

    def capture_spike_trace(self, model_path, n_steps, batch_size=1):
        try:
            import numpy as np  # type: ignore[import-not-found]
        except ImportError as e:
            raise NotAvailable("numpy not installed") from e
        if not isinstance(model_path, str) or not model_path:
            raise NotAvailable("spike_trace requires model_path (no synthetic dynamics)")
        if n_steps <= 0:
            raise ValueError(f"n_steps must be > 0, got {n_steps}")

        d, model, mapping_meta = self._load_and_map(model_path)
        in_shape = tuple(model.input_shape)
        dtype = self._input_dtype_for(model)
        rng = np.random.default_rng(seed=7)

        trace = []
        ipe_before = len(d.inference_power_events)
        for step in range(n_steps):
            if dtype == np.int8:
                x = rng.integers(-128, 127, size=(batch_size, *in_shape), dtype=np.int8)
            else:
                x = rng.integers(0, 256, size=(batch_size, *in_shape), dtype=np.uint8)
            t0 = time.perf_counter()
            y = model.forward(x)
            dt = time.perf_counter() - t0
            trace.append({
                "step":          step,
                "latency_us":    dt * 1e6,
                "out_norm_l2":   float(np.linalg.norm(y.astype(np.float32))),
                "out_mean_abs":  float(np.abs(y).mean()),
                "out_min":       float(y.min()),
                "out_max":       float(y.max()),
            })
        ipe_after = len(d.inference_power_events)
        stats_after = self._stats_snapshot(model, d)

        return {
            "n_steps":     n_steps,
            "batch_size":  batch_size,
            "model_path":  model_path,
            "trace":       trace,
            "mapping":     mapping_meta,
            "stats_after": stats_after,
            "raw": {
                "ipe_buffer_growth": ipe_after - ipe_before,
                "ipe_buffer_total":  ipe_after,
                "input_seed":        7,
            },
        }

    # ---- capability matrix ----

    def capabilities(self) -> dict[str, Any]:
        """Capability snapshot. `power_measure` reports the active phase
        (cloud_clock_estimate on FPGA, vendor_rtl_required for silicon equivalent)
        rather than a plain boolean — callers branch on string for richer gating.
        """
        present = self.device_present()
        try:
            d = self._device()
            learn = bool(d.learn_enabled)
            soc_present = d.soc is not None
        except NotAvailable:
            learn = False
            soc_present = False
        return {
            "device_probe":     present,
            "mesh_introspect":  present,
            "forward":          present,
            "run_inference":    present,
            "power_measure":    "cloud_clock_estimate" if present else False,
            "spike_capture":    present,
            "online_learning":  present and learn,
            "silicon_equivalent_power": False,  # Phase 2/3 dependent
            "soc_present":      soc_present,
        }


register_backend(2, Gen2A2FPGABackend)
