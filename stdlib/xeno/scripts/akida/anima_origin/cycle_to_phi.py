"""xeno cycle 결과를 anima 형식 phi/trace evidence로 변환.

own 34 mandate-4 정합: anima/scripts/akida/ 본 코드 미터치. xeno SSOT
에서 cycle 결과를 받아 anima 가 평소 emit 하는 ``F-M3b_*.json`` /
``F-M4_*.json`` 형식 evidence 만 생성. anima/state/akida_evidence/
디렉토리에 그대로 저장.

  - 진짜 IIT-style Φ 측정은 pyphi + 정확한 input-output stationarity 필요.
    여기선 outputs distribution 의 통계적 invariance 를 Φ proxy 로 사용.
  - 진짜 trace bisimulation 은 두 substrate (CPU mirror + Akida) 출력
    sequence 가 step-by-step 일치하는지. CPU mirror 는 anima 측 책임 lane.
    여기선 Akida 단독 두 시드의 outputs 분포 일관성을 trace proxy 로 측정.

이 두 lane 모두 PROXY 임을 verdict 와 note 에 명시 — caller (anima 본
falsifier 코드, D+1 후 머지) 가 진짜 측정으로 super-supersede 가능.

Usage:
  python3 cycle_to_phi.py --model PATH --falsifier F-M3b \\
    --out-dir /home/guest/work/anima/state/akida_evidence
"""
from __future__ import annotations
import argparse, json, os, statistics, subprocess, sys, time
from typing import Any


def _xeno_cycle_measure(model_path: str, n_events: int, seed: int | None = None) -> dict[str, Any]:
    """xeno cycle measure 호출. seed 인자는 cycle_runner 가 받지 않으므로
    측정 스타일을 다양화하려면 n_events 를 살짝 다르게 하거나 별도 호출."""
    cycle_runner = os.path.realpath(
        os.path.join(os.path.dirname(__file__), "..", "cycle_runner.py")
    )
    p = subprocess.run(
        ["python3", cycle_runner, "measure",
         "--model", model_path, "--n-events", str(n_events)],
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


def _f_m3b(measure_a: dict, measure_b: dict) -> dict:
    """F-M3b Phi substrate invariance: 두 measure 의 outputs_summary 가
    통계적으로 거의 같으면 proxy-PASS. relative-error 5% 임계."""
    a = measure_a["inference"]["raw"]["outputs_summary"]
    b = measure_b["inference"]["raw"]["outputs_summary"]
    rel_errs = {}
    for k in ("min", "max", "mean", "std"):
        va, vb = a.get(k), b.get(k)
        if va is None or vb is None:
            rel_errs[k] = None
            continue
        denom = max(abs(va), abs(vb), 1e-9)
        rel_errs[k] = abs(va - vb) / denom
    max_rel = max((v for v in rel_errs.values() if v is not None), default=0.0)
    threshold = 0.05
    return {
        "falsifier_id": "F-M3b",
        "measured_ts":  measure_b["ts"],
        "verdict":      "PROXY-PASS-AKIDA-SELF-INVARIANCE" if max_rel < threshold
                        else "PROXY-FAIL-AKIDA-SELF-INVARIANCE",
        "measured_value": {
            "outputs_summary_a":   a,
            "outputs_summary_b":   b,
            "rel_errs_per_field":  rel_errs,
            "max_rel_err":         max_rel,
            "threshold":           threshold,
        },
        "hardware_present": True,
        "command":          "xeno cycle measure × 2 (different n_events; akida self-invariance proxy)",
        "note": (
            "PROXY only — true F-M3b requires CPU phi calc + Akida phi calc + "
            "5% rel-err. 여기선 두 Akida self-run 의 outputs distribution "
        ),
    }


def _f_m4(measure_a: dict, measure_b: dict) -> dict:
    """F-M4 trace equivalence: 두 measure outputs_summary 비교.

    F-M3b 와 거의 동일한 측정이지만 verdict 라벨링이 다름 — F-M4 는
    closed-loop trace bisimulation, F-M3b 는 Φ invariance. proxy 수준에선
    동일한 stat 사용.
    """
    a = measure_a["inference"]["raw"]["outputs_summary"]
    b = measure_b["inference"]["raw"]["outputs_summary"]
    deltas = {}
    for k in ("min", "max", "mean", "std"):
        va, vb = a.get(k), b.get(k)
        deltas[k] = abs(va - vb) if (va is not None and vb is not None) else None
    max_delta = max((v for v in deltas.values() if v is not None), default=0.0)
    threshold = 0.5  # absolute float diff
    return {
        "falsifier_id": "F-M4",
        "measured_ts":  measure_b["ts"],
        "verdict":      "PROXY-PASS-TRACE-STATIONARY" if max_delta < threshold
                        else "PROXY-FAIL-TRACE-DIVERGENT",
        "measured_value": {
            "outputs_summary_a":   a,
            "outputs_summary_b":   b,
            "deltas_per_field":    deltas,
            "max_abs_delta":       max_delta,
            "threshold":           threshold,
            "n_events_a":          measure_a["inference"]["n_events"],
            "n_events_b":          measure_b["inference"]["n_events"],
        },
        "hardware_present": True,
        "command":          "xeno cycle measure × 2 (different n_events; trace stationarity proxy)",
        "note": (
            "PROXY only — true F-M4 requires CPU mirror + N>=1000 step-by-step "
            "trace bisimulation. 여기선 두 Akida run 의 outputs distribution 이 "
            "input-batch-size 변화에 stationary 한지를 trace stability proxy 로 측정."
        ),
    }


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True)
    p.add_argument("--falsifier", required=True, choices=["F-M3b", "F-M4", "all"])
    p.add_argument("--out-dir", required=True)
    p.add_argument("--n-events-a", type=int, default=10)
    p.add_argument("--n-events-b", type=int, default=20)
    args = p.parse_args(argv[1:])

    targets = (["F-M3b", "F-M4"] if args.falsifier == "all" else [args.falsifier])
    measure_a = _xeno_cycle_measure(args.model, args.n_events_a)
    measure_b = _xeno_cycle_measure(args.model, args.n_events_b)

    written = []
    for fid in targets:
        if fid == "F-M3b":
            ev = _f_m3b(measure_a, measure_b)
        elif fid == "F-M4":
            ev = _f_m4(measure_a, measure_b)
        else:
            continue
        path = _emit(ev, args.out_dir)
        written.append({"falsifier_id": fid, "verdict": ev["verdict"], "path": path})
    print(json.dumps({"emitted": written}, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
