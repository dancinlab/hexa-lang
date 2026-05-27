"""xeno generation-aware Akida cycle runner.

Subcommands:
  probe          device version + auto-detected gen + capabilities table
  capabilities   per-gen capability matrix (works without device)
  measure        run minimal inference + emit honest measurement record

Flag:
  --akida-gen {auto, 1, 2, 3, ...}    default: auto

Exit codes:
  0   success
  1   usage / arg error
  2   no device / unknown gen (fallback path taken)
"""
from __future__ import annotations
import argparse, json, os, sys, time

# cycle_runner.py lives at xeno/scripts/akida/, lib package is sibling.
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from lib import (  # noqa: E402
    Backend, BackendError, NotAvailable,
    detect_generation, get_backend, list_generations, REGISTRY,
)


def _emit(obj) -> None:
    print(json.dumps(obj, indent=2, default=str))


def cmd_probe(args) -> int:
    detected = detect_generation()
    backend = get_backend(args.akida_gen)
    out = {
        "ts":                time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "requested_gen":     args.akida_gen,
        "detected_gen":      detected,
        "backend_class":     type(backend).__name__,
        "backend_gen":       backend.generation,
        "marketing_name":    backend.marketing_name,
        "device_info":       backend.device_info(),
        "capabilities":      backend.capabilities(),
        "registered_gens":   list_generations(),
    }
    _emit(out)
    return 0 if backend.device_present() else 2


def cmd_capabilities(args) -> int:
    table = {}
    for gen in list_generations():
        b = REGISTRY[gen]()  # instantiate without device probe
        table[gen] = {
            "marketing_name":  b.marketing_name,
            "version_pattern": b.version_pattern,
            "capabilities":    b.capabilities(),
        }
    _emit({"registered_generations": table})
    return 0


def _write_record(args, record, prefix) -> None:
    if not args.out_dir:
        return
    os.makedirs(args.out_dir, exist_ok=True)
    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    gen = record.get("generation", 0)
    path = os.path.join(args.out_dir, f"gen{gen}_{prefix}_{ts}.json")
    with open(path, "w") as f:
        json.dump(record, f, indent=2, default=str)
    print(f"[written] {path}", file=sys.stderr)


def _no_device_record(info) -> dict:
    return {
        "verdict":     "BLOCKED-NO-DEVICE",
        "device_info": info,
    }


def cmd_measure(args) -> int:
    backend = get_backend(args.akida_gen)
    info = backend.device_info()
    if not info.get("available"):
        _emit(_no_device_record(info))
        return 91

    record = {
        "ts":           time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "backend":      type(backend).__name__,
        "generation":   backend.generation,
        "device_info":  info,
        "mesh_summary": _safe_call(backend.mesh_summary),
        "inference":    _safe_call(lambda: backend.run_inference(args.model, args.n_events)),
        "power":        _safe_call(lambda: backend.measure_power(args.n_events, model_path=args.model)),
        "capabilities": backend.capabilities(),
    }
    _emit(record)
    _write_record(args, record, "measure")
    return 0


def cmd_spike_trace(args) -> int:
    backend = get_backend(args.akida_gen)
    info = backend.device_info()
    if not info.get("available"):
        _emit(_no_device_record(info))
        return 91
    if not args.model:
        _emit({
            "verdict":     "BLOCKED-NO-MODEL",
            "device_info": info,
            "note":        "spike-trace requires --model PATH (no synthetic dynamics)",
        })
        return 1

    trace = _safe_call(
        lambda: backend.capture_spike_trace(args.model, args.n_steps, args.batch_size)
    )
    record = {
        "ts":           time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "backend":      type(backend).__name__,
        "generation":   backend.generation,
        "device_info":  info,
        "spike_trace":  trace,
        "capabilities": backend.capabilities(),
    }
    _emit(record)
    _write_record(args, record, "spike_trace")
    return 0


def cmd_forward(args) -> int:
    """Caller-supplied inputs forward pass — outputs printed/saved as numpy.

    Inputs from stdin (numpy .npy bytes) or --input-npy PATH. Outputs as
    numpy .npy via --output-npy PATH (binary), with telemetry on stdout (json).
    Used by anima/nexus runners to pipe raw outputs into their own analytics.
    """
    backend = get_backend(args.akida_gen)
    info = backend.device_info()
    if not info.get("available"):
        _emit(_no_device_record(info))
        return 91
    if not args.model:
        _emit({"verdict": "BLOCKED-NO-MODEL", "note": "forward requires --model"})
        return 1

    try:
        import numpy as np  # type: ignore[import-not-found]
    except ImportError:
        _emit({"verdict": "BLOCKED-NUMPY", "note": "numpy not installed"})
        return 91

    if args.input_npy:
        inputs = np.load(args.input_npy)
    else:
        _emit({"verdict": "BLOCKED-NO-INPUT", "note": "forward requires --input-npy PATH"})
        return 1

    result = _safe_call(lambda: backend.forward(args.model, inputs))
    if isinstance(result, dict) and "outputs" in result and result["outputs"] is not None:
        if args.output_npy:
            np.save(args.output_npy, result["outputs"])
            result["outputs"] = f"<saved to {args.output_npy}>"
        else:
            result["outputs"] = "<numpy array; pass --output-npy to save>"
    record = {
        "ts":           time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "backend":      type(backend).__name__,
        "generation":   backend.generation,
        "device_info":  info,
        "forward":      result,
        "capabilities": backend.capabilities(),
    }
    _emit(record)
    _write_record(args, record, "forward")
    return 0


def _safe_call(thunk):
    try:
        return thunk()
    except NotAvailable as e:
        return {"available": False, "reason": "NotAvailable", "detail": str(e)}
    except BackendError as e:
        return {"available": False, "reason": "BackendError", "detail": str(e)}


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(prog="xeno-akida-cycle")
    p.add_argument(
        "--akida-gen", default="auto",
        help="generation: 'auto' (detect from device.version) or int (1, 2, 3, ...). "
             f"registered: {list_generations()}",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("probe", help="detect device + show capabilities")
    sp.set_defaults(func=cmd_probe)

    sp = sub.add_parser("capabilities", help="capability matrix across all registered gens")
    sp.set_defaults(func=cmd_capabilities)

    sp = sub.add_parser("measure", help="run minimal inference + emit honest record")
    sp.add_argument("--model", default=None, help=".fbz model path (optional)")
    sp.add_argument("--n-events", type=int, default=1000)
    sp.add_argument("--out-dir", default=None)
    sp.set_defaults(func=cmd_measure)

    sp = sub.add_parser("spike-trace", help="step-by-step forward pass; per-step latency + output norms")
    sp.add_argument("--model", required=True, help=".fbz model path")
    sp.add_argument("--n-steps", type=int, default=100)
    sp.add_argument("--batch-size", type=int, default=1)
    sp.add_argument("--out-dir", default=None)
    sp.set_defaults(func=cmd_spike_trace)

    sp = sub.add_parser("forward", help="forward pass with caller-supplied inputs (.npy)")
    sp.add_argument("--model", required=True, help=".fbz model path")
    sp.add_argument("--input-npy", required=True, help=".npy file with int8 inputs")
    sp.add_argument("--output-npy", default=None, help=".npy file to save outputs")
    sp.add_argument("--out-dir", default=None)
    sp.set_defaults(func=cmd_forward)

    args = p.parse_args(argv[1:])
    try:
        return args.func(args)
    except BackendError as e:
        _emit({"error": "BackendError", "detail": str(e)})
        return 91


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
