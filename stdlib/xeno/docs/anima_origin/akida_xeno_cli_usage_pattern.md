# Akida xeno CLI usage pattern (anima / nexus / 외부 호출자)

**SSOT**: `xeno bin/xeno cycle ...` + `xeno scripts/akida/cycle_runner.py`
**Rule**: anima · nexus · 다른 어떤 호출자도 직접 `import akida` 금지. xeno CLI subprocess + JSON output parse만 허용.
**Why**: D+0 2026-05-09 cycle에서 발견 — Akida Cloud는 AKD1000 아닌 Akida 2 FPGA. 하드웨어 가정을 한 곳에 격리하지 않으면 substrate drift가 모든 호출자에 confidential breaking change로 전파됨. xeno SSOT는 generation registry로 BC.A2 → BC.A3 등 미래 세대 자동 흡수.

## 1. CLI 진입점

| Command | Action | Output |
|---|---|---|
| `xeno cycle status` | 전체 상태 (primary/fallback) | text |
| `xeno cycle probe [--akida-gen N]` | 로컬 device probe | JSON |
| `xeno cycle capabilities` | 모든 등록 세대 capability 매트릭스 | JSON |
| `xeno cycle measure [--akida-gen N] [--model PATH] [--n-events N] [--out-dir DIR]` | inference + power record (honest) | JSON |
| `xeno cycle remote probe` | cloud-side probe (ssh akida-cloud + cycle_runner) | JSON |
| `xeno cycle remote measure ...` | cloud-side measure | JSON |
| `xeno cycle remote spike-trace --model PATH --n-steps N` | step-by-step latency + output norms | JSON |
| `xeno cycle remote forward --model PATH --input-npy F` | caller-supplied inputs forward pass | JSON + .npy |

**`--akida-gen` 정책**:
- `auto` (default): `device.version` regex `^BC\.A(\d+)\.` 매칭
- `1` / `2` / `3` / ...: 명시적 generation. mismatch 시 `NotAvailable` raise → `BLOCKED-CAPABILITY-GAP` verdict path
- 미래 세대 추가: `xeno/scripts/akida/lib/backends/genN_*.py` 한 파일 land + `register_backend(N, ...)` 한 줄

## 2. Capability gating

모든 호출자는 사용 전 `capabilities()` 확인 후 분기:

```python
import json, subprocess, sys

def xeno_probe(akida_gen="auto"):
    p = subprocess.run(
        ["xeno", "cycle", "remote", "probe", "--akida-gen", akida_gen],
        capture_output=True, text=True, check=False,
    )
    if p.returncode not in (0, 2):
        raise RuntimeError(f"xeno probe failed: rc={p.returncode} {p.stderr}")
    return json.loads(p.stdout)


probe = xeno_probe()
caps = probe["capabilities"]
if not caps["forward"]:
    return {
        "verdict": "BLOCKED-CAPABILITY-GAP",
        "missing": "forward",
        "generation": probe["backend_gen"],
        "device_info": probe["device_info"],
        "note": "Akida substrate cannot run forward pass for this generation",
    }
```

**금지 패턴** (직접 import):

```python
# ❌ DO NOT
import akida
devs = akida.devices()
m = akida.Model(filename="...")
```

이렇게 작성한 코드는 architectural review에서 reject 대상.

## 3. anima 측 사용 — F-M3b (Phi substrate invariance) 변환 sketch

Before (직접 akida import — 금지 대상):

```python
# anima/scripts/akida/phi_substrate_invariance.py (현재, AKD1000 가정)
def main():
    panel = generate_panel(args.panel_size)
    phi_cpu = compute_phi_cpu(panel)
    # akida 직접 import path stubbed
    return {"verdict": "BLOCKED-AKIDA-PIPELINE-MISSING", ...}
```

After (xeno CLI subprocess):

```python
# anima/scripts/akida/phi_substrate_invariance.py (D+1 후 머지 안 — own 34 mandate-4)
import json, subprocess, tempfile, numpy as np

MODEL = "/home/guest/bc_cloud_examples/examples/models/tenn_spatiotemporal_eye_buffer_i8_w8_a8.fbz"

def compute_phi_akida(panel):
    """Run panel through Akida via xeno CLI; receive raw outputs; compute Phi locally."""
    with tempfile.NamedTemporaryFile(suffix=".npy", delete=False) as f_in, \
         tempfile.NamedTemporaryFile(suffix=".npy", delete=False) as f_out:
        np.save(f_in.name, panel.astype(np.int8))
        p = subprocess.run([
            "xeno", "cycle", "remote", "forward",
            "--model", MODEL,
            "--input-npy", f_in.name,
            "--output-npy", f_out.name,
        ], capture_output=True, text=True, check=False)
        if p.returncode != 0:
            raise RuntimeError(f"xeno forward failed: {p.stderr}")
        outputs = np.load(f_out.name)
    return phi_calculator(outputs)  # anima local — Φ 계산은 caller 책임

def main():
    panel = generate_panel(args.panel_size)
    phi_cpu   = compute_phi_cpu(panel)
    phi_akida = compute_phi_akida(panel)
    rel_err = abs(phi_cpu - phi_akida) / max(phi_cpu, 1e-9)
    verdict = "PASS" if rel_err < args.threshold else "FAIL"
    emit({"verdict": verdict, "phi_cpu": phi_cpu, "phi_akida": phi_akida, "rel_err": rel_err})
```

핵심:
- `forward()` 결과 = raw numpy outputs. Φ 계산은 anima 책임 (substrate adapter는 semantic 안 들어감).
- `panel`의 dtype/shape은 anima 책임 — int8, model.input_shape에 맞춤.
- error path는 모두 `BLOCKED-CAPABILITY-GAP` 또는 `BLOCKED-NO-DEVICE` 명시.

## 4. nexus 측 사용 — runner.py HARNESS 변환 sketch

Before:

```python
HARNESS = {
    "F-L1":  ["python3", "scripts/akida/energy_meter.py", "--falsifier", "F-L1", "--simulator"],
    "F-L6":  ["python3", "scripts/akida/lyapunov_sweep.py", "--simulate"],
    ...
}
```

After (D+1 후 머지 안):

```python
# nexus/scripts/akida/runner.py
def fire_F_L1(out_dir):
    """F-L1 J/op energy — Akida 2 FPGA cloud는 vendor estimate path."""
    p = subprocess.run([
        "xeno", "cycle", "remote", "measure",
        "--n-events", "1000",
        "--out-dir", out_dir,
    ], capture_output=True, text=True, check=False)
    record = json.loads(p.stdout)
    power = record["power"]
    if not power["available"] and power.get("vendor_estimate_required"):
        return {
            "falsifier_id": "F-L1",
            "verdict":      "BLOCKED-VENDOR-ESTIMATE-REQUIRED",
            "note":         power["note"],
            "evidence":     record,
        }
    return {"falsifier_id": "F-L1", "verdict": _energy_verdict(power), "evidence": record}


def fire_F_L6(out_dir, rates_hz):
    """F-L6 Lyapunov sweep — spike_trace를 rate 별로 fire."""
    if not _capability_check("spike_capture"):
        return {"falsifier_id": "F-L6", "verdict": "BLOCKED-CAPABILITY-GAP"}
    traces = []
    for rate in rates_hz:
        n_steps = int(rate * 0.5)  # 0.5s window
        p = subprocess.run([
            "xeno", "cycle", "remote", "spike-trace",
            "--model", MODEL,
            "--n-steps", str(n_steps),
            "--out-dir", out_dir,
        ], capture_output=True, text=True, check=False)
        traces.append({"rate_hz": rate, "trace": json.loads(p.stdout)})
    lambda_max = _compute_lyapunov(traces)
    return {"falsifier_id": "F-L6", "verdict": _band_verdict(lambda_max), "evidence": traces}
```

핵심:
- HARNESS dict 자리에 **함수 dispatch** — 각 falsifier가 xeno CLI subprocess + JSON parse + verdict logic
- `--simulator` flag 흔적 제거 — capability gating으로 sub OR honest BLOCKED-VENDOR
- `host_register_cloud.sh` (P0a generated) apply는 cycle 끝 시점

## 5. 미래 세대 (gen 3, 4, ...) 호환

Akida 3 출시 시:

1. xeno만 수정: `xeno/scripts/akida/lib/backends/gen3_a3.py` 한 파일 추가 (현재 `gen3_stub.py` 자리)
   - `generation = 3`, `version_pattern = r"^BC\.A3\."`
   - SDK 차이를 backend 내부에 격리
2. `register_backend(3, Gen3Backend)` (이미 stub에 있음 — 클래스만 교체)
3. anima/nexus 코드 무변경 — `--akida-gen auto`는 새 device 자동 detect

## 6. own 정합

- **own 34 mandate-4** (source repo untouched until D+1 close): 본 doc은 xeno에만 land. anima/nexus 실제 코드 변경은 D+1 close 이후.
- **own 35** (AKD1000 PRIMARY + Cloud FALLBACK semantic): xeno cycle status가 path 자동 분기. cycle_runner는 `--akida-gen auto`로 어느 path든 generation match.
- **own 16** (cost watchdog): forward batch 크기 제한 (예: n_events ≤ 10000) — cloud session 24h budget 내 fit.
- **own 18** (simple stack SSOT): substrate adapter는 device probe + forward + power record만 cover. phi/trace bisim 등 application logic은 caller (anima/nexus).

## 7. Verification (D+0 2026-05-09)

- `xeno cycle remote probe` → `detected_gen: 2`, `BC.A2.001.000` ✓
- `xeno cycle remote measure --model eye_buffer.fbz --n-events 50` → 65.5 ms/event, output_shape [50,3,4,3] ✓
- `xeno cycle remote spike-trace --model eye_buffer.fbz --n-steps 20` → 20-step trace, l2 norm ~9.5 stable ✓
- power record: `vendor_estimate_required: true` honest ✓

evidence: `state/akida_cloud_d0_2026_05_09/gen2_measure_*.json`, `gen2_spike_trace_*.json`

## 8. Cross-link

- `xeno/bin/xeno` cmd_cycle — CLI dispatcher
- `xeno/scripts/akida/cycle_runner.py` — subcommand entry (probe / capabilities / measure / spike-trace / forward)
- `xeno/scripts/akida/lib/` — backend SSOT
- `docs/anima_origin/akida_cloud_d0_cycle_log_2026_05_09.md` — D+0 cycle log
- BrainChip support: `support.akidacloud@brainchip.com` (RTL estimate 요청)
