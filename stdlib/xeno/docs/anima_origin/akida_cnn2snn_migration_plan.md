# cnn2snn 1.x → 2.x Migration Plan (nexus 측)

D+0 deep research 결과 우리 nexus 코드의 `cnn2snn.quantize(...)` API가 1.x 가정 — Akida 2 SDK는 API 자체 교체. 본 doc은 D+1 close 후 nexus 머지를 위한 migration 청사진.

**주의**: own 34 mandate-4 — anima/nexus repo는 D+1 close (2026-05-10 09:00 KST) 전까지 미터치. 본 plan은 sketch이지 즉시 land 아님. xeno 측 SSOT가 작동 검증된 후 nexus에 적용.

## 1. 변경 범위

### 1.1 API 자체 교체

```python
# BEFORE (cnn2snn 1.x — nexus 현재 가정)
import cnn2snn
quantized = cnn2snn.quantize(
    keras_model,
    input_weight_quantization=8,
    weight_quantization=4,
    activ_quantization=4,
)
akida_model = cnn2snn.convert(quantized)

# AFTER (MetaTF 2.x default — Akida 2)
import quantizeml, cnn2snn
qparams = quantizeml.models.QuantizationParams(
    input_weight_bits=8, weight_bits=8, activation_bits=8,
)
quantized = quantizeml.models.quantize(keras_model, qparams=qparams)
akida_model = cnn2snn.convert(quantized)  # default → Akida 2

# Targeting Akida 1 explicitly:
with cnn2snn.set_akida_version(cnn2snn.AkidaVersion.v1):
    akida_model_v1 = cnn2snn.convert(quantized)
```

### 1.2 Architecture-level 강제 변경

| 항목 | 1.x | 2.x | 영향 |
|---|---|---|---|
| Default quantization | 8/4/4 (input/weight/activ) | 8/8/8 | 양자화 손실 줄음. 기존 4-bit weight 모델 중 일부는 retrain 필요할 수 있음 |
| Separable conv (depthwise+pointwise fused) | 지원 | **drop** — fused → unfused로 변환 필요 | `akida_models unfuse -m model.h5` CLI 자동화 필요 |
| GAP (global avg pooling) 위치 | ReLU 후 | ReLU 전 (or 정확한 spec — 차이 있음) | 일부 모델 수치적으로 다른 결과 → retrain |
| Dense2D layer | 지원 | drop (MetaTF 2.16+) | 사용 모델 redefine |

## 2. nexus 측 영향 받는 파일 (예상)

D+1 후 실제 grep으로 확정 필요. 현재 가정 기준:

```
nexus/scripts/akida/
├── runner.py                  # HARNESS dict의 --simulator flag 제거 + xeno cli subprocess 패턴
├── energy_meter.py            # cnn2snn.quantize 사용 가능 — quantizeml로 교체
├── lyapunov_sweep.py          # forward path가 cnn2snn 1.x 모델 가정 — xeno backend 호출로 교체
├── godel_disagreement.py      # 동일
├── spike_compress.py          # 동일
├── _akida_runtime.py          # akida 직접 import 가정 — xeno cli wrapper로 교체
└── cnn2snn_emulator.py        # CPU emulator — cnn2snn 1.x convert 호출
```

## 3. Migration helper sketch (xeno 측에 land)

xeno에 helper 모듈 추가하면 nexus가 사용 시 import 단순화:

```python
# xeno/scripts/akida/lib/quantize_helper.py (D+1 후 구현)
"""quantizeml + cnn2snn convert wrapper — 1.x ↔ 2.x 모두 지원.

Usage:
    from xeno.scripts.akida.lib.quantize_helper import quantize_and_convert
    akida_model, akida_v = quantize_and_convert(keras_model, target="auto")
"""
from __future__ import annotations
from typing import Literal


def quantize_and_convert(
    keras_model,
    target: Literal["auto", "v1", "v2"] = "auto",
    bits: tuple[int, int, int] = (8, 8, 8),
):
    """target='auto' → Akida 2 (default). 'v1' → set_akida_version 컨텍스트로 wrap."""
    import quantizeml, cnn2snn

    qparams = quantizeml.models.QuantizationParams(
        input_weight_bits=bits[0],
        weight_bits=bits[1],
        activation_bits=bits[2],
    )
    quantized = quantizeml.models.quantize(keras_model, qparams=qparams)

    if target == "v1":
        with cnn2snn.set_akida_version(cnn2snn.AkidaVersion.v1):
            return cnn2snn.convert(quantized), "v1"
    return cnn2snn.convert(quantized), "v2"


def unfuse_separable(input_h5: str, output_h5: str | None = None) -> str:
    """Akida 2 unfuse path: depthwise+pointwise separable conv를 unfused로.

    `akida_models unfuse -m <h5>` CLI를 subprocess로 wrap. Akida 2가 fused
    separable을 drop했기 때문에 모델 변환 전 mandatory step.
    """
    import subprocess, os
    output_h5 = output_h5 or input_h5.replace(".h5", "_unfused.h5")
    subprocess.run(
        ["akida_models", "unfuse", "-m", input_h5, "-o", output_h5],
        check=True,
    )
    return output_h5
```

## 4. .fbz 캐시 분리 패턴

```
state/akida_fbz/
├── v1/                        # AKD1000 / AKD1500 (Akida 1 silicon)
│   ├── eye_buffer.fbz
│   └── ...
└── v2/                        # Akida 2 FPGA cloud / 미래 AKD2500
    ├── eye_buffer.fbz
    └── ...
```

xeno backend의 `forward()` / `run_inference()`가 model_path를 받을 때, 호출자 (nexus)는 `--akida-gen` 인자에 맞춰 v1 또는 v2 디렉토리에서 select. 자동 path:

```python
# nexus 측 (D+1 후) — xeno backend 사용
def fbz_path(model_name: str, akida_gen: int) -> str:
    base = f"~/state/akida_fbz/v{akida_gen}"
    return os.path.expanduser(f"{base}/{model_name}.fbz")
```

## 5. Separable conv unfuse CI step

D+1 후 nexus repo에 추가 가능한 GitHub Actions / Makefile target:

```yaml
# .github/workflows/akida_models.yml (sketch)
name: Akida models build
on: [push]
jobs:
  build_v2:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install akida_models cnn2snn quantizeml
      - run: |
          for h5 in models/h5/*.h5; do
            akida_models unfuse -m "$h5" -o "models/unfused/$(basename "$h5")"
          done
      - run: |
          python -c "
          from xeno.scripts.akida.lib.quantize_helper import quantize_and_convert
          import tensorflow as tf
          for h5 in glob.glob('models/unfused/*.h5'):
              m = tf.keras.models.load_model(h5)
              akida_m, _ = quantize_and_convert(m, target='v2')
              akida_m.save(h5.replace('.h5', '.fbz').replace('unfused', 'fbz/v2'))
          "
```

## 6. Conda env upgrade (MetaTF 2.18 → 2.19)

cloud env는 2.18 (2024-12-16), 최신 2.19 (2025-02-20). 변경:

- Akida Pico FPGA support 추가
- 16-bit I/O option 추가
- MetaTF release notes 검토 후 D+1 cycle 시점에 cloud session bootstrap 단계에서 `pip install --upgrade akida cnn2snn akida_models quantizeml` 시도 (root 권한 X면 user-install)
- 만약 conda env가 read-only이면 `pip install --user` 사용

검증:
```bash
xeno cycle remote probe --akida-gen 2
# capabilities + device_info에 SDK version 노출 → 2.18 vs 2.19 확인
```

## 7. F-L1 power lane 3-phase plan (재정리)

| Phase | When | Method | Expected output |
|---|---|---|---|
| **Phase 1** | 즉시 (현재) | `m.statistics.fps + inference_clk + program_clk` via xeno cycle measure | `power.available: "cloud_clock_estimate"` (proxy, NOT silicon watts) |
| **Phase 2** | D+1 후 ~ 2026 Q3 | `sales@brainchip.com` RTL estimate engagement (NDA + model artifact 송부) | silicon-equivalent J/op estimate (vendor PDF report) |
| **Phase 3** | 2026 Q4+ | AKD2500 prototype 입수 후 RAPL/USB shunt | silicon J/op direct measurement |

Phase 1은 이미 `xeno cycle measure --model X --n-events N` 호출로 자동 emit. Phase 2 신청 메일 template:

```
Subject: Akida 2 RTL Power Estimation Request — [model name]

Dear BrainChip Solution Architects,

We are evaluating Akida 2 IP via the FPGA cloud platform and would like to
request a silicon-equivalent power estimate for the following model:

  Model: tenn_spatiotemporal_eye_buffer_i8_w8_a8.fbz (TENN, 41 NPs total:
    27 CNP1 + 14 TNP_B + 6+6 SKIP_DMA, ~300KB external memory)
  Use case: edge inference, eye tracking
  Target node: [12nm TSMC for AKD2500 / customer node N]
  Workload: int8 inputs at <fps target> Hz

Our FPGA cloud measurements (cloud_clock_estimate):
  fps = 15.22 (66 ms/event)
  inference_clk = 47,225,211 cycles/batch
  program_clk = 4,405,722 cycles

Please advise on RTL synthesis + power simulation feasibility, NDA
requirements, and turnaround.

Thanks,
[name]
```

## 8. 적용 timing

- D+0 (지금): xeno SSOT 검증 + 본 plan doc land
- D+1 close (2026-05-10 09:00 KST): cloud session 종료, Mac side rsync exfil
- D+1 close 후 (own 34 mandate-4 lift): nexus repo에 quantize_helper.py + runner.py refactor + .fbz 캐시 분리 + CI step 적용
- 2026 Q3 + AKD2500 prototype: gen2 backend가 silicon 자동 detect (BC.A2.x, soc=AKD2500)? 또는 BC.A2.5xx 같은 새 prefix?

## 9. Cross-link

- `docs/anima_origin/akida_brainchip_deep_research_2026_05_09.md` §5 (cnn2snn 변경 상세) + §12.3 (migration plan source)
- `docs/anima_origin/akida_xeno_cli_usage_pattern.md` §4 (nexus runner.py 변환 sketch)
- `xeno/scripts/akida/lib/backends/gen2_a2_fpga.py` (생성된 forward/run_inference/measure_power 구현)
- BrainChip docs:
  - https://doc.brainchipinc.com/examples/quantization/plot_1_upgrading_to_2.0.html
  - https://doc.brainchipinc.com/user_guide/cnn2snn.html
- Sales: `sales@brainchip.com` (RTL estimate)
