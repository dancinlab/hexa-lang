# BrainChip Akida — Deep Research 2026-05-09

D+0 cycle (2026-05-09) 도중 실시한 광범위 조사. seed: brainchip.com + developer.brainchip.com + web search (GitHub BrainChipInc, doc.brainchipinc.com, Hackster, CNX Software, EE Times, arxiv 2205.13037 등 30+ source).

조사 트리거: device.version=`BC.A2.001.000` 발견 후 우리 D-1 plan(AKD1000 가정)과의 mismatch 진단 필요.

## 0. TL;DR — 우리가 가진 가정 vs 실제

| 항목 | 우리 가정 (D-1) | 실제 |
|---|---|---|
| Cloud device | AKD1000 (Akida 1 silicon) | **Akida 2 IP를 FPGA에 emulate** (silicon 아님) |
| AKD2000 chip | 출시된 Akida 2 silicon | **존재하지 않음** — marketing 이름 vapor. silicon은 AKD2500 |
| AKD1500 | 미인지 | **2025-11-04 발표, 2026 Q3 양산** — Akida 1 차세대 22nm FD-SOI co-processor |
| AKD2500 | 미인지 | **2026-02-13 project 시작, Q3 2026 prototype** — TSMC 12nm Akida 2 silicon |
| Akida 3 | gen3 stub로 미래 대비 | **공식 발표 전혀 없음**. AKD2500이 Akida 2 generation의 silicon |
| Power telemetry | 완전 미제공 | `m.statistics.last_inference_power` 존재 (FPGA estimate). silicon equivalent은 별도 NDA |
| MetaTF version | 최신 가정 | 우리 cloud env (2.18, 2024-12-16)는 5개월 lag. **최신 2.19 (2025-02-20)** |
| cnn2snn 1.x → 2.x | hint만 | API 자체 교체: `quantizeml.models.quantize(model, QuantizationParams)`, default 8/8/8 |

## 1. 정확한 silicon roadmap

| 칩 | 공정 | 발표 / 양산 | Generation | 상태 |
|---|---|---|---|---|
| **AKD1000** | TSMC 28nm | 2018 발표 / 2022-01 양산 | Akida 1 | 양산 중 (PCIe + M.2) |
| **AKD1500** | GF 22nm FD-SOI | 2023 tape-out / 2025-11-04 unveil / **2026 Q3 양산** | Akida 1 | sample 단계, wearables/IoT 전용 |
| **AKD2000** | — | — | Akida 2 (IP only) | **silicon 출시 안됨** — vapor |
| **AKD2500** | TSMC 12nm | **2026-02-13 project 시작 / Q3 2026 prototype** | Akida 2 | 개발 중 (현재 silicon 미존재) |
| **Akida Pico** | — | 2024 발표 / 2026-02-03 FPGA Cloud 평가 가능 | Akida 2 sub-tier | FPGA only, sub-mW target |

핵심: **Akida 2 generation silicon은 2026-05 시점 미존재.** Akida 2 평가 path는:
1. **Akida FPGA Cloud** (우리가 쓰는 것, Colfax hosted)
2. on-prem FPGA development box
3. IP licensing 후 customer 자체 SoC 통합 (ex: Frontgrade Gaisler, EDGEAI)

## 2. 우리 cloud platform 정체

- `BC.A2.001.000` parsing:
  - `BC.A` = BrainChip Akida 공통 prefix
  - `2` = generation
  - `001` = IP configuration revision (1–6 node 구성 중 하나로 추정)
  - `000` = patch level
- `device.soc = None` → **silicon SoC 아님**. FPGA가 host PC에 PCIe로 직접 연결
- 24 NPs mesh = 6-node Akida-P configuration으로 추정 (Akida-S 상위 / Akida-P 하위 영역)
- conda env: `akida 2.18.2 + cnn2snn 2.18.2 + akida_models 1.12.0 + onnx2akida 0.6.0` = MetaTF 2.18 (2024-12-16 release)

→ 우리가 측정하는 latency는 **FPGA emulation 속도 (50–100 MHz 추정)**. silicon AKD2500 (12nm)은 훨씬 빠를 것이지만 **scaling은 비례 단순 환산 불가** (memory access pattern이 BRAM vs SRAM 다르고, mesh interconnect도 다름).

## 3. Akida 1 vs Akida 2 architecture

### 3.1 Akida 1 (AKD1000)
- TSMC 28nm, 80개 NPU mesh, ~1.2M neurons, ~10B synapses
- 각 NPU: 100KB SRAM + 8개 NPE
- **Quantization 고정**: 8/4/4 (input/weight/activation bit)
- **on-chip learning**: 마지막 FC layer만, binary weights + binary inputs 제약
- Layer 종류: Conv2D + BN + MaxPool + ReLU + Dropout, FullyConnected

### 3.2 Akida 2 IP (2023-03-08 발표)
| 추가 기능 | 의미 |
|---|---|
| **8-bit weights/activations** (i8/w8/a8) | 양자화 손실 줄음. 4-bit는 옵션 |
| **Vision Transformer 가속** | encoder block hardware support |
| **TENN** (Temporal Event-based NN) | spatio-temporal 시계열 (gesture/eye/audio/vital signs) — RNN/Transformer보다 가벼움 |
| **Multi-pass sequential processing** | 모델 단일 mesh 안 들어가면 시간 분할 |
| **Configurable local scratchpads** | NP별 SRAM 활용 최적화 |
| **3 product tiers** | Akida-E (1–4 nodes, ≤200 GOPS), Akida-S (2–8 nodes, ≤1 TOPS), Akida-P (8–128 nodes, ≤50 TOPS, ViT) |

### 3.3 Mesh layer types (Akida runtime API 정의)

| Type | 풀네임 | 역할 |
|---|---|---|
| **HRC** | Host (Reset) Controller | mesh entry point, host I/O |
| **CNP1** | Convolutional NP type 1 | 일반 CNN layer (가장 많이 allocate됨) |
| **CNP2** | Convolutional NP type 2 | Akida 2 ViT/multi-pass용 변형 (depthwise/pointwise unfused 처리로 추정) |
| **FNP2** | FC NP (External memory) | FC layer 첫 instance, 외부 SRAM 사용 |
| **FNP3** | FC NP (Internal memory) | FNP2 다음 추가되는 FC unit, on-chip SRAM |
| **TNP_B** | Temporal NP — Buffered | Akida 2 전용, TENN (시간축 conv + state) 처리 |

예시 mapping (AkidaNet/ImageNet, doc.brainchipinc.com): 1 HRC + 67 CNP1 + 1 FNP2. 모델별 allocation 다름.

## 4. Power measurement 공식 path

### 4.1 Cloud / FPGA가 주는 것
- `model.statistics`: floor_power, last_inference_power_range (avg/min/max), energy_per_frame
- `device.inference_power_events`: power profiling enable시 PowerEvent list
- `device.soc.power_measurement_enabled = True` — silicon SoC 시 활성화. **우리 device는 soc=None이라 AttributeError 가능**
- BUT: cloud 측정값은 **FPGA estimate**. silicon equivalent 아님

### 4.2 공식 신청 경로 (sales@brainchip.com)

| Stage | 정보 |
|---|---|
| Entry | sales@brainchip.com (ACLP 페이지 명시) |
| Akida Cloud | Free 1-day → 1-week → 3-month tier (가격 미공개). 1–6 node Akida 2 |
| RTL power estimate | **별도 engagement** (추측). Akida 2 IP는 fully synthesizable RTL + synthesis scripts 제공 → vendor가 customer's target node (12nm/22nm/28nm)에서 합성 + power simulation 돌려야 정확 |
| NDA / 비용 | 공개 자료 없음 |
| Turnaround | 공개 자료 없음 (RTL synthesis + power sim은 보통 1–4주 추측) |

### 4.3 권고 — F-L1 power lane 3-phase

- **Phase 1 (즉시)**: `m.statistics.last_inference_power` 사용 + "FPGA cloud estimate, NOT silicon" 라벨. `available: cloud_estimate` (boolean false에서 격상)
- **Phase 2**: sales@brainchip.com 통해 RTL/silicon power estimate 별도 요청
- **Phase 3 (2026 Q4+)**: AKD2500 prototype 입수 가능 시 자체 측정

## 5. cnn2snn 1.x → 2.x 마이그레이션

### 5.1 API 변경

```python
# BEFORE (Akida 1, cnn2snn 1.x)
import cnn2snn
quantized = cnn2snn.quantize(model,
    input_weight_quantization=8,
    weight_quantization=4,
    activ_quantization=4)
akida_model = cnn2snn.convert(quantized)

# AFTER (Akida 2 default, MetaTF 2.x)
import quantizeml, cnn2snn
qparams = quantizeml.models.QuantizationParams(
    input_weight_bits=8, weight_bits=8, activation_bits=8)
quantized = quantizeml.models.quantize(model, qparams=qparams)
akida_model = cnn2snn.convert(quantized)  # default → Akida 2

# To still target Akida 1:
with cnn2snn.set_akida_version(cnn2snn.AkidaVersion.v1):
    akida_model_v1 = cnn2snn.convert(quantized)
```

### 5.2 Architecture 강제 변경
1. **Separable conv**: Akida 2는 fused depthwise+pointwise drop. `akida_models unfuse -m model.h5` CLI 필요
2. **GAP 위치**: ReLU 대비 GAP 위치가 1.0 vs 2.0 다름 → 수치적으로 다른 결과 → 일부 모델 retrain 필요
3. **Dense2D layer drop** (MetaTF 2.16+)

### 5.3 .fbz 호환성
- 기존 AKD1000용 `.fbz` → Akida 2 FPGA에서 직접 load 가능 여부 **명시 안됨**
- 안전 path: source Keras 모델을 quantizeml로 재양자화 → v2 fbz 생성. 또는 `set_akida_version(v1)` context로 v1 fbz 생성 후 v1 hardware에 매핑
- nexus 코드 (Akida 1 fbz를 Akida 2 FPGA로 직접 forward)는 layer type mismatch 가능성 — **재컴파일 권장**

## 6. akida.Model API + 활용

### 6.1 핵심 API
```python
import akida
dev = akida.devices()[0]
dev.version              # "BC.A2.001.000"
dev.soc                  # None (FPGA) | AKD1000 instance
dev.learn_enabled        # bool — on-chip learning gate
dev.metrics              # {inference_frames, inference_clk, program_clk}

m = akida.Model("model.fbz")
m.summary()              # NP allocation breakdown (CNP1/FNP2/TNP_B counts)
m.map(dev, hw_only=False)   # default: multi-sequence split 허용
m.map(dev, hw_only=True)    # 강제 단일 hw seq, fail → exception
out = m.forward(x)       # int tensor (Akida native)
out_f = m.predict(x)     # float CNN output (post-conversion semantics)

events = dev.inference_power_events
stats  = m.statistics    # last_inference_power, average_framerate, energy_per_frame
```

### 6.2 우리 backend가 더 활용해야 할 것
- `m.summary()` 결과 capture → falsifier evidence 첨부 (mesh allocation reproducible record)
- `hw_only=True` 우선 시도 → multi-pass fall-back 여부 명시 분리 (latency variance source)
- `dev.metrics["inference_clk"]` clock-cycle latency 병기 (jitter 적음)
- `try/except` for `dev.soc.power_measurement_enabled` (FPGA에선 attribute error 가능)
- `dev.learn_enabled` False면 online-learning lane skip

## 7. 온라인 학습 generation matrix

| Generation | Learn 가능? | 제약 |
|---|---|---|
| Akida 1 (AKD1000) | Yes (last layer만) | FullyConnected + binary weights + binary inputs |
| Akida 1 co-pro (AKD1500) | Yes ("on-device learning" 마케팅 명시) | 동일 가정 (추측) |
| **Akida 2 IP / FPGA cloud (우리)** | **현재 unclear** — Open Neuromorphic 정리: "AKD2000 device의 on-chip learning 지원 unclear" |
| Akida 2 silicon (AKD2500) | 미공개 | — |

우리 `learn_enabled = false` 관찰과 일치. **Akida 2 cloud에선 online learning 미지원**으로 표시가 정확.

## 8. Model zoo (akida_models 1.12.0)

| Domain | Model | Akida gen | Dataset |
|---|---|---|---|
| Image cls | AkidaNet (0.25/0.5/1.0), MobileNetV1, GXNOR, AkidaNet18 | 1+2 (AkidaNet18 = 2 only) | ImageNet, MNIST, PlantVillage, VWW |
| Object det | YOLOv2, CenterNet (AkidaNet18) | 2 only for CenterNet | PASCAL-VOC, WIDER FACE |
| Regression / seg | VGG-like (age), AkidaUNet 0.5 | 2 only for UNet | UTKFace |
| Face ID | embeddings | 1+2 | CASIA Webface |
| Audio / KWS | DS-CNN | 1+2 | Google Speech Commands |
| Point cloud | PointNet++ | 1+2 | ModelNet40 |
| **Spatiotemporal (TENN)** | gesture recog, eye tracking | **2 only** | DVS128, Jester, eye tracking comp |
| Pico KWS / anomaly | StatefulRecurrent + Projection | 2 (Pico) | (MetaTF 2.19 추가) |

호스팅:
- 가중치 H5 → cnn2snn .fbz 변환
- Public download: `doc.brainchipinc.com/model_zoo_performance.html`
- GitHub: `Brainchip-Inc/akida_examples` + `Brainchip-Inc/akida_models`

## 9. 경쟁사 비교 (요약)

| Feature | Akida 2 | Loihi 2 (Intel) | NorthPole (IBM) |
|---|---|---|---|
| Native model | SNN + CNN→SNN + ViT + TENN | SNN, async loops, learning rules | ANN inference (NOT SNN) |
| On-chip learning | Yes (limited) | Yes (programmable plasticity) | No |
| Commercial silicon | AKD1000 양산 / AKD1500 Q3 2026 / AKD2500 Q3 2026 prototype | Loihi 2 research only (Kapoho Point) | 2026 production |
| Differentiation | First commercialized at scale (자동차/우주 ref design) | Most neuro-faithful, programmable | 25× H100 image inference 효율 (claim) |

Loihi 2 = academic / research (Intel Neuromorphic Research Community 가입 필요), Akida = **purchasable commercial product**. NorthPole = ANN inference 가속기 (SNN 아님, outlier).

## 10. Customer / 파트너 요약

- **자동차**: Mercedes-Benz Vision EQXX (in-cabin Hey Mercedes KWS, 5–10× 효율), Valeo (ADAS JDA), Renesas
- **우주**: NASA Phase I (VORAGO 28nm HARDSIL rad-hard), Frontgrade Gaisler (commercial license, space-grade SoC), ESA, AFRL
- **국방**: Parsons, RTX, AFRL
- **Foundry/IP**: Intel Foundry, GlobalFoundries (22FDX for AKD1500), TSMC 12nm (AKD2500), SiFive, Arm, Andes, MegaChips
- **Sensors**: Prophesee (event camera), NVISO, Emotion3D, Edge Impulse
- **License**: EDGEAI (smart metering, 2026)

## 11. Dev kit pricing (corrected)

| SKU | 가격 | 비고 |
|---|---|---|
| Akida M.2 (B+M Key) AKD1000 | **$249** | (이전 자료 $1,495는 outdated) |
| Akida M.2 (E Key) | (별도) | E key form factor |
| Akida PCIe board AKD1000 | **$499** | 2022 commercialization |
| Akida Edge AI Box | $1,495 | host PC 통합 |
| RPi 4 + Akida dev kit | **$995** | (이전 $4,995에서 인하) |
| **Akida 2 dev kit (silicon)** | **존재하지 않음** | AKD2500 prototype Q3 2026 후 가능 |

## 12. 우리 코드베이스 반영 액션 아이템

### 12.1 P0 — `gen2_a2_fpga.py` 즉시 보강 (~30분)
1. `model.map(d, hw_only=True)` 우선 시도 + fallback `hw_only=False`, 두 path metadata 분리
2. `model.summary()` capture + `{HRC, CNP1, CNP2, FNP2, FNP3, TNP_B}` count 추출
3. `dev.metrics["inference_clk"]` clock-cycle latency 추가 (host timer + clock 병기)
4. `try/except AttributeError` for `dev.soc.power_measurement_enabled` → cloud FPGA에선 skip, silicon에선 enable
5. `m.statistics.last_inference_power` 시도 → power 'available: false' → 'available: cloud_estimate'
6. `dev.learn_enabled` 검사, False 시 online-learning lane skip 명시

### 12.2 P1 — `gen3_stub.py` 명칭 재고
- backend class를 `NextSiliconStub` 같이 재명명 고려 — Akida 3는 vapor, AKD2500이 Akida 2 silicon이므로 단순 "gen+1" 매핑 부정확
- 또는 stub은 그대로 두고 docstring만 정정 ("Akida 3는 미공개, BC.A3.* 자동 detect는 future-proof만")

### 12.3 P2 — nexus cnn2snn 1.x → 2.x 마이그레이션 (D+1 close 후)
1. `cnn2snn.quantize(...)` call → `quantizeml.models.quantize(model, QuantizationParams(...))` helper로 wrap
2. Default 8-bit (Akida 2 default) 통일, 필요 시 `set_akida_version(v1)` context
3. Separable conv 모델 → `akida_models unfuse` CI step
4. .fbz 캐시 gen별 분리 (`fbz/v1/`, `fbz/v2/`)
5. MetaTF 2.18 → 2.19 conda env upgrade 평가

### 12.4 F-L1 power lane 결정
- Phase 1: cloud `m.statistics.last_inference_power` + "FPGA cloud estimate" 라벨
- Phase 2: BrainChip sales@ 통해 RTL/silicon power estimate 별도 요청
- Phase 3 (2026 Q4+): AKD2500 prototype 자체 측정

## 13. Sources (주요 30+)

### BrainChip 공식
- https://brainchip.com (corporate)
- https://developer.brainchip.com/ (dev portal)
- https://doc.brainchipinc.com/ (full docs)
- https://doc.brainchipinc.com/user_guide/akida.html
- https://doc.brainchipinc.com/api_reference/akida_apis.html
- https://doc.brainchipinc.com/model_zoo_performance.html
- https://doc.brainchipinc.com/examples/quantization/plot_1_upgrading_to_2.0.html
- https://brainchip.com/aclp/
- https://brainchip.com/brainchip-introduces-second-generation-akida-platform/
- https://brainchip.com/brainchip-unveils-breakthrough-akd1500-edge-ai-co-processor-at-embedded-world-north-america/
- https://brainchip.com/wp-content/uploads/2025/10/AKD1500-Product-Brief-V2.4-Oct.25.pdf
- https://brainchip.com/wp-content/uploads/2025/04/Akida-2-IP-Product-Brief-V2.0-1.pdf
- https://brainchip.com/wp-content/uploads/2025/08/Akida-FPGA-Platform-Product-Brief-V1.3-Aug-25.pdf
- https://brainchip.com/akida-pico-announcement/
- https://brainchip.com/unlock-your-ai-potential-a-deep-dive-into-brainchips-akida-cloud/

### GitHub
- https://github.com/Brainchip-Inc/akida_examples
- https://github.com/Brainchip-Inc/akida_examples/releases
- https://github.com/Brainchip-Inc/akida_models

### 외부 분석
- Open Neuromorphic — https://open-neuromorphic.org/neuromorphic-computing/hardware/akida-brainchip/
- Hackster.io Akida 2.0 IP coverage
- CNX Software AKD1500 / AKD1000 PCIe board posts
- Sharecafe / Smallcaps — AKD2500 silicon project (2026-02-13)
- Stocks Today — BrainChip's reset and revised path
- arxiv 2205.13037 — Neuromorphic AI systems survey
- Open Neuromorphic + SemiconductorX — Loihi 2 / NorthPole / Akida / SpiNNaker comparison

### Customer / 파트너
- Mercedes EQXX (EE Times)
- Frontgrade Gaisler space SoC license (StockTitan)
- Valeo ADAS JDA (Marklines)
- VORAGO NASA Phase I rad-hard collab (BrainChip)
- EDGEAI smart metering license

## 14. Cross-link

- `docs/anima_origin/akida_cloud_setup_log_2026_05_08.md` — D-1 setup
- `docs/anima_origin/akida_cloud_d_minus_1_prep_2026_05_08.md` — D-1 prep
- `docs/anima_origin/akida_cloud_d0_cycle_log_2026_05_09.md` — D+0 cycle log
- `docs/anima_origin/akida_xeno_cli_usage_pattern.md` — xeno CLI = 유일 진입점 정책
- `xeno/scripts/akida/lib/backends/gen2_a2_fpga.py` — 본 research 결과 반영 대상
- BrainChip support: `support.akidacloud@brainchip.com` (cloud)
- BrainChip sales: `sales@brainchip.com` (RTL estimate / IP licensing)
