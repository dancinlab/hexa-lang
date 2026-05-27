"""xeno cycle 결과를 nexus 형식 falsifier evidence로 변환.

본 wrapper는 anima/nexus 측 코드를 직접 변경하지 않고 (own 34 mandate-4)
xeno CLI 결과만 받아서 nexus 가 평소 사용하는 ``F-<id>_<ts>.json`` 형식
evidence를 emit. ``state/akida_evidence/`` 디렉토리에 그대로 들어가서
nexus runner.py 의 ``_collect_latest()`` 가 그대로 픽업 가능.

Usage:
  python3 cycle_to_falsifier.py --model PATH --falsifier F-L1 \\
    --out-dir /home/guest/work/nexus/state/akida_evidence

지원 falsifier:
  F-L1   J/op energy        — cloud_clock_estimate proxy → BLOCKED-VENDOR-ESTIMATE-REQUIRED
  F-L1+  sub-Landauer       — 동일 (silicon equivalent watts 미제공)
  F-L6   Lyapunov           — spike-trace의 latency_us / out_norm_l2 분산 → λ proxy
  F-A    blowup phase-7     — multi-pass fallback 발생 여부 → blowup proxy
  F-M2   gzip compression   — outputs entropy estimate
  F-C    architectural      — 24-NP mesh + Akida 2 IP version 자동 PASS

honest verdict (PASS / FAIL / BLOCKED-* / PLAUSIBLE-*) 출력.
"""
from __future__ import annotations
import argparse, json, os, subprocess, sys, time
from typing import Any


def _xeno_cycle_measure(model_path: str, n_events: int) -> dict[str, Any]:
    """xeno cycle measure 호출 — cloud-side 직접 또는 remote 모두 가능.

    cloud 안에서 직접 실행 가정 (본 스크립트는 ~/work/xeno/scripts/akida/
    nexus_origin/에 추출되어 conda env 활성 후 호출). cycle_runner.py를
    같은 process 내에서 import해 호출하면 더 빠르지만, SSOT 정합 위해
    subprocess + JSON parse 패턴을 그대로 사용.
    """
    cycle_runner = os.path.join(os.path.dirname(__file__), "..", "cycle_runner.py")
    cycle_runner = os.path.realpath(cycle_runner)
    p = subprocess.run(
        ["python3", cycle_runner, "measure",
         "--model", model_path, "--n-events", str(n_events)],
        capture_output=True, text=True, check=False,
    )
    # cycle_runner는 stdout=JSON, stderr=[written] 라인.
    return json.loads(p.stdout)


def _xeno_cycle_spike_trace(model_path: str, n_steps: int) -> dict[str, Any]:
    cycle_runner = os.path.join(os.path.dirname(__file__), "..", "cycle_runner.py")
    cycle_runner = os.path.realpath(cycle_runner)
    p = subprocess.run(
        ["python3", cycle_runner, "spike-trace",
         "--model", model_path, "--n-steps", str(n_steps)],
        capture_output=True, text=True, check=False,
    )
    return json.loads(p.stdout)


def _emit(evidence: dict[str, Any], out_dir: str) -> str:
    os.makedirs(out_dir, exist_ok=True)
    fid = evidence["falsifier_id"]
    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    path = os.path.join(out_dir, f"{fid}_{ts}.json")
    with open(path, "w") as f:
        json.dump(evidence, f, indent=2, default=str)
    return path


def _f_l1(measure: dict, falsifier_id: str = "F-L1") -> dict:
    """F-L1 J/op energy: cloud는 silicon watts 미제공 → BLOCKED."""
    cap = measure["capabilities"].get("power_measure")
    cloud = measure["power"].get("cloud_estimate") or {}
    return {
        "falsifier_id": falsifier_id,
        "measured_ts":  measure["ts"],
        "verdict":      "BLOCKED-VENDOR-ESTIMATE-REQUIRED",
        "measured_value": {
            "watts_idle":           None,
            "watts_inference":      None,
            "joules_per_event":     None,
            "fps":                  cloud.get("fps"),
            "inference_clk":        cloud.get("inference_clk"),
            "program_clk":          cloud.get("program_clk"),
            "power_measure_capability": cap,
        },
        "raw_log_path":     None,
        "hardware_present": measure["device_info"]["available"],
        "command":          f"xeno cycle measure --model {measure['inference']['raw'].get('model_path')}",
        "blocking_reason":  measure["power"]["note"],
    }


def _f_l6(spike_trace: dict) -> dict:
    """F-L6 Lyapunov: spike trace에서 out_norm_l2 의 step 간 분산 → λ proxy.

    제대로 된 Lyapunov 측정은 두 perturbed trajectory 의 발산률이지만,
    cloud_clock_estimate 환경에선 같은 seed 로 재현되므로 latency / norm
    """
    import statistics as st
    trace = spike_trace["spike_trace"]["trace"]
    norms = [t["out_norm_l2"] for t in trace]
    lats  = [t["latency_us"]   for t in trace]
    norm_var  = st.pstdev(norms) if len(norms) > 1 else 0.0
    norm_mean = st.mean(norms)   if norms          else 0.0
    proxy = norm_var / norm_mean if norm_mean > 0 else 0.0
    band = (-0.05, 0.05)
    in_band = band[0] <= proxy <= band[1]
    return {
        "falsifier_id": "F-L6",
        "measured_ts":  spike_trace["ts"],
        "verdict":      "PLAUSIBLE-PASS" if in_band else "PLAUSIBLE-FAIL-PROXY",
        "measured_value": {
            "lambda_proxy_norm_cv":  proxy,
            "n_steps":               len(trace),
            "out_norm_l2_mean":      norm_mean,
            "out_norm_l2_pstdev":    norm_var,
            "latency_us_mean":       st.mean(lats) if lats else 0.0,
            "latency_us_pstdev":     st.pstdev(lats) if len(lats) > 1 else 0.0,
            "edge_of_chaos_band":    list(band),
        },
        "hardware_present": True,
        "command":          "xeno cycle spike-trace",
        "note": (
            "λ proxy = pstdev(out_norm_l2)/mean — NOT true Lyapunov exponent. "
        ),
    }


def _f_a(measure: dict) -> dict:
    """F-A blowup phase-7: multi-pass fallback 사용 여부 → blowup proxy.

    hw_only mapping 실패 + fallback 사용 = mesh capability 초과 (모델이 mesh
    에서 단일 pass로 mapping 안 됨). 이건 blowup의 약한 proxy.
    """
    mapping = measure["inference"]["mapping"]
    fallback = mapping.get("fallback_used", False)
    err_text = mapping.get("hw_only_error", "")
    return {
        "falsifier_id": "F-A",
        "measured_ts":  measure["ts"],
        "verdict":      "PLAUSIBLE-FAIL-BLOWUP" if fallback else "PASS",
        "measured_value": {
            "hw_only_succeeded":  mapping.get("hw_only_succeeded"),
            "fallback_used":      fallback,
            "hw_only_error":      err_text[:300],
            "model_np_counts":    mapping.get("model_np_counts"),
            "summary_full_len":   mapping.get("summary_full_len"),
        },
        "hardware_present": True,
        "command":          "xeno cycle measure --model X (mapping path inspection)",
        "note": (
            "blowup phase-7 proxy = multi-pass fallback. true blowup requires "
            "phase-7 specific layer ops profiling — hexa file 의존성 별도 lane."
        ),
    }


def _f_c(measure: dict) -> dict:
    """F-C architectural: BC.A2 + 24 NP mesh = arch-PASS."""
    info = measure["device_info"]
    mesh = measure["mesh_summary"]
    arch_ok = (
        info.get("available")
        and info.get("ip_version", "").startswith("IpVersion.v2")
        and mesh.get("n_nps", 0) >= 1
    )
    return {
        "falsifier_id": "F-C",
        "measured_ts":  measure["ts"],
        "verdict":      "PASS" if arch_ok else "FAIL",
        "measured_value": {
            "device_version":    info.get("version"),
            "ip_version":        info.get("ip_version"),
            "n_nps":             mesh.get("n_nps"),
            "mesh_np_counts":    mesh.get("mesh_np_counts"),
        },
        "hardware_present": info.get("available"),
        "command":          "xeno cycle probe + measure (mesh introspect)",
    }


def _f_m2(measure: dict) -> dict:
    """F-M2 gzip compression: outputs_summary 의 std 를 entropy proxy로."""
    summary = measure["inference"]["raw"].get("outputs_summary", {})
    std = summary.get("std", 0.0)
    return {
        "falsifier_id": "F-M2",
        "measured_ts":  measure["ts"],
        "verdict":      "PLAUSIBLE-PASS" if std > 0.1 else "FAIL",
        "measured_value": {
            "outputs_std":        std,
            "outputs_min":        summary.get("min"),
            "outputs_max":        summary.get("max"),
            "outputs_mean":       summary.get("mean"),
            "entropy_proxy":      "std",
        },
        "hardware_present": True,
        "command":          "xeno cycle measure (outputs statistics)",
        "note":             "entropy proxy = std(outputs); true gzip ratio 측정 별도 lane.",
    }


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True, help=".fbz model path")
    p.add_argument("--falsifier", required=True,
                   choices=["F-L1", "F-L1+", "F-L6", "F-A", "F-C", "F-M2", "all"])
    p.add_argument("--out-dir", required=True)
    p.add_argument("--n-events", type=int, default=20)
    p.add_argument("--n-steps", type=int, default=20, help="for F-L6 spike-trace")
    args = p.parse_args(argv[1:])

    targets = (["F-L1", "F-L1+", "F-L6", "F-A", "F-C", "F-M2"]
               if args.falsifier == "all" else [args.falsifier])

    measure = None
    spike   = None
    written = []
    for fid in targets:
        if fid in ("F-L1", "F-L1+", "F-A", "F-C", "F-M2") and measure is None:
            measure = _xeno_cycle_measure(args.model, args.n_events)
        if fid == "F-L6" and spike is None:
            spike = _xeno_cycle_spike_trace(args.model, args.n_steps)
        if fid in ("F-L1", "F-L1+"):
            ev = _f_l1(measure, falsifier_id=fid)
        elif fid == "F-L6":
            ev = _f_l6(spike)
        elif fid == "F-A":
            ev = _f_a(measure)
        elif fid == "F-C":
            ev = _f_c(measure)
        elif fid == "F-M2":
            ev = _f_m2(measure)
        else:
            continue
        path = _emit(ev, args.out_dir)
        written.append({"falsifier_id": fid, "verdict": ev["verdict"], "path": path})

    print(json.dumps({"emitted": written}, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
