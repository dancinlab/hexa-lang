# NPU n=6 (HEXA-NPU) — Foundry-pitch Datasheet  v0.1

> Companion to `npu_n6/chip-npu-n6.md` (vision spec). Step-A
> paper-design enhancement (.roadmap §A.6.1) — foundry-/IDM-facing
> datasheet skeleton: **interface · μarch corners · PDK assumptions
> · safety/quality · ASCII block diagram · BOM/footprint**.
>
> Status: **paper design, pre-tape-out**. v2.0.0 (Stage-1+, .roadmap
> §A.6) gates fabrication.

## 0. Scope and conformance

| field          | value                                                       |
|:---------------|:------------------------------------------------------------|
| product class  | NPU (Neural Processing Unit) IP block, mobile/edge SoC       |
| target spec    | foundry-portable IP; integration via AXI4 / CHI / NVDLA-class|
| n=6 anchors    | τ(6)=4 dataflow stages · σ(6)=12 lane width · J₂=24 macroblock |
| falsifier      | F-CHIP-2 (NPU dataflow τ=4); 100% RSC closure                |
| scope at v0.1  | spec + interface; no synthesizable RTL / GDSII / PDK lib     |
| out of scope   | proprietary tensor-core floorplans; vendor-specific dataflows|

## 1. Top-level interface (foundry-agnostic IP)

```
              ┌─────────────────────────────────────────────────┐
              │                  HEXA-NPU IP                    │
              │  (parameterizable: σ-lane × τ-stage × J₂-macro) │
              └─────────────────────────────────────────────────┘
                 ▲    ▲    ▲    ▲                ▲
                 │    │    │    │                │
            AXI4 │ AXI4│IRQ │CSR (APB)           │PWR/CLK
            mem  │ inst│line│CFG                 │PMU
                 │    │    │    │                │
            (host SoC ←→ NPU IP integration)
```

| port group       | width / type           | direction | notes                       |
|:-----------------|:-----------------------|:----------|:----------------------------|
| AXI4 mem (HBM/DDR)| 128/256/512-bit data  | bidir     | weights + activations       |
| AXI4 instruction  | 64-bit                | host→NPU  | layer descriptors            |
| APB CSR           | 32-bit                | host→NPU  | mode / start / status        |
| IRQ               | 1                     | NPU→host  | layer-done / fault           |
| PMU (clk/rst/PG)  | per-IP                | host→NPU  | DVFS + power-gate domains    |

## 2. n=6 dataflow microarchitecture (τ = 4 stages)

The 4 dataflow stages are aligned to τ(6)=4:

```
      stage 0 (FETCH)        stage 1 (MAC)          stage 2 (ACCUM)        stage 3 (WB)
   ┌─────────────────┐   ┌──────────────────┐   ┌────────────────┐   ┌──────────────────┐
   │ load weights    │   │ multiply lanes   │   │ partial-sum    │   │ writeback +      │
   │  + activations  │ → │  σ-wide (×12)    │ → │  tree (J₂=24)  │ → │  activation      │
   │ from AXI4 mem   │   │  INT8/FP16 dual  │   │  reduce        │   │  (ReLU/GELU/...)  │
   └─────────────────┘   └──────────────────┘   └────────────────┘   └──────────────────┘
```

Cross-references:

- `verify/calc_npu.hexa` — τ=4 algebraic identity (4 dataflow stages enumerated)
- `verify/numerics_npu_solver.hexa` — power iteration on τ×τ stage matrix
- `verify/empirical_npu.hexa` — 8 published architectures, mode == τ = 4

## 3. Microarchitecture corners (PVT)

Closed-form-only at v0.1. Real corners come from PDK characterization
post-§A.6 step 2 (foundry MOU + funding).

### 3.1 Process corners (P)

| corner       | nominal node target | deviation     |
|:-------------|:--------------------|:--------------|
| FF (fast)    | N5 / N3 / Intel-4   | -3σ           |
| TT (typical) | N5 / N3 / Intel-4   | center        |
| SS (slow)    | N5 / N3 / Intel-4   | +3σ           |

### 3.2 Voltage corners (V)

| rail       | nominal | min     | max     | notes                  |
|:-----------|:--------|:--------|:--------|:-----------------------|
| VDD_LOGIC  | 0.75 V  | 0.65 V  | 0.85 V  | core MAC array         |
| VDD_MEM    | 0.85 V  | 0.80 V  | 0.90 V  | on-chip SRAM scratchpad|
| VDD_IO     | 0.80 V  | 0.75 V  | 0.85 V  | AXI4 high-speed I/O    |

### 3.3 Temperature corners (T)

| corner     | T_J range      | use case        |
|:-----------|:---------------|:----------------|
| C (cold)   | -40 …  0 °C    | qual / military |
| N (nominal)|   0 … 85 °C    | mobile / edge   |
| H (hot)    |  85 … 110 °C   | datacenter / HPC|
| TRIP       |       120 °C   | thermal trip    |

### 3.4 Performance envelope (TT/N nominal)

| metric                          | n=6 prediction           | published parity            |
|:--------------------------------|:-------------------------|:----------------------------|
| MAC lanes per macroblock        | σ = 12                   | TPUv1 systolic 16 (≈)        |
| dataflow stages                 | τ = 4                    | Eyeriss / TPU / ANE all = 4  |
| INT8 / FP16 ratio per stage     | φ = 2                    | TC / Volta = 2× INT8         |
| macroblock total ops            | J₂ = 24 ops / cycle      | NPU vector path ≈ 24/2/3 lane|
| 2^(σ-φ) bandwidth ceiling       | 2^10 = 1024 bits/cycle   | NPU vector unit width        |

## 4. PDK assumptions (foundry-agnostic)

| assumption                    | value                                  |
|:------------------------------|:---------------------------------------|
| logic process                 | N5 / N3 / Intel-4 (~ 100–290 MTr/mm²)   |
| MAC array                     | mixed INT8 / FP16; signed Booth-radix-4 |
| on-chip SRAM                  | 2-port 8T/6T per generation             |
| memory hierarchy              | L0 register file → L1 SRAM → AXI4 DRAM  |
| compiler ABI                  | NVDLA-compatible / TVM-export pluggable |
| ECC                           | SECDED on SRAM ≥ 64 KB; parity on smaller|

**Foundry-portability**: spec is foundry-agnostic IP; mapping to a
specific PDK happens after foundry MOU (§A.6 step 1). Current
estimate spans 100–290 MTr/mm² (TSMC N5 → N3) per
`verify/empirical_process.hexa`.

## 5. Safety / quality / reliability

| domain            | requirement                                       |
|:------------------|:--------------------------------------------------|
| BIST coverage     | ≥ 98% MAC array + 100% SRAM ECC + 95% glue logic  |
| burn-in           | 12h @ 110 °C, full inference replay post-burn     |
| MTTF              | ≥ 10⁶ device-hours @ T_N (commercial mobile/edge) |
| thermal trip      | thermal-trip @ T_J ≥ 120 °C; latency ≤ 100 µs    |
| FuSa              | ASIL-B path optional (auto-edge inference)        |
| secure boot       | layer-descriptor signature optional (host SoC TF-A)|
| ESD               | HBM model 2 kV all I/O; CDM 500 V                 |
| qual              | AEC-Q100 grade-3 path optional                    |

## 6. Top-level block diagram (textual)

```
+-------------------------------------------------------------------+
|                   HEXA-NPU IP (n=6 dataflow)                      |
|                                                                   |
|  ┌──────────────────────────────────────────────────────────────┐ |
|  │  Front-end                                                    │ |
|  │  ├── AXI4 instruction decoder (host CSR-driven)              │ |
|  │  ├── Layer descriptor cache                                  │ |
|  │  └── Dispatch FSM (4-stage τ=4 mapping)                      │ |
|  └──────────────────────────────────────────────────────────────┘ |
|                                                                   |
|  ┌──────────────────────────────────────────────────────────────┐ |
|  │  MAC array  (σ × σ = 12 × 12 = 144 lanes; J₂=24 macroblocks) │ |
|  │  ├── INT8 path (φ-multiplier = 2× FP16 throughput)           │ |
|  │  ├── FP16 path                                               │ |
|  │  └── Activation pipe (ReLU / GELU / sigmoid / softmax)       │ |
|  └──────────────────────────────────────────────────────────────┘ |
|                                                                   |
|  ┌──────────────────────────────────────────────────────────────┐ |
|  │  Back-end                                                    │ |
|  │  ├── Reduction tree (1024-wide = 2^(σ-φ)=2^10)               │ |
|  │  ├── On-chip SRAM scratchpad (ECC SECDED)                    │ |
|  │  ├── DMA engine (AXI4 master)                                │ |
|  │  └── Power-management (DVFS + clock gating per macroblock)   │ |
|  └──────────────────────────────────────────────────────────────┘ |
+-------------------------------------------------------------------+
       │  AXI4 (mem + inst), APB (CSR), IRQ
       v
+-------------------------------------------------------------------+
|                       host SoC integration                        |
+-------------------------------------------------------------------+
```

## 7. BOM / footprint estimate (paper)

| line item                      | v1.x estimate                          |
|:-------------------------------|:---------------------------------------|
| MAC array area (N5)            | ~3–5 mm² (σ²=144 lanes, INT8/FP16)      |
| SRAM scratchpad                | ~2–4 mm² (≥ 4 MB; 8T cells)             |
| Front-end + back-end           | ~1–2 mm²                                |
| total IP area (N5, paper)      | ~6–11 mm²                               |
| peak compute (INT8 @ TT/N)     | ~1–4 TOPS / mm²                         |
| peak power (TT/N, full duty)   | ~1–3 W                                  |
| INT8 / FP16 ratio (φ=2)        | 2:1 throughput (matches TC / Volta)     |

Cost ladder (.roadmap §A.6 step 2 funding):

- IP-only paper qualification: in scope of this repo
- MPW shuttle (NPU IP only, single die): ~$0.5–2 M (N5 class)
- Full NPU+host SoC tape-out: ~$5–20 M (foundry MOU required)

## 8. Conformance to RSC closure

| tier         | source                                          | status         |
|:-------------|:------------------------------------------------|:---------------|
| T1 algebraic | `verify/calc_npu.hexa`                          | ✓ τ=4 + σ²=144 |
| T2 numerical | `verify/numerics_npu{,_parity,_solver}.hexa`    | ✓ ×3 stack     |
| T3 archival  | `verify/empirical_npu.hexa`                     | ✓ 8 archs, mode=τ |
| T3 bench     | (this document is its prereq)                   | ✗ Stage-1+ §A.6|

## 9. Provenance

- Vision spec: `npu_n6/chip-npu-n6.md` (HEXA-NPU alien-index 10 frame)
- Verification floor: `verify/calc_npu.hexa` + `numerics_npu_*.hexa`
  + `empirical_npu.hexa`
- Roadmap: `.roadmap.hexa_chip` §A.4 F-CHIP-2 + §A.6 / §A.6.1
- Public references for τ=4: Eyeriss-v1 (ISSCC 2016), Eyeriss-v2
  (IEEE Micro 2019), TPUv1 (ISCA 2017), Volta Tensor Core (NVIDIA WP
  2017), Apple ANE (AnandTech 2020), Exynos NPU (ISSCC 2020),
  Cerebras WSE-2 (Hot Chips 2021), Graphcore IPU (Hot Chips 2019)
- n=6 lattice: σ(6)=12, τ(6)=4, φ(6)=2, J₂=24

## 10. Open issues / next-step gates

| gate | needs                                           | resolves    |
|:-----|:------------------------------------------------|:------------|
| G1   | foundry/IDM partner MOU (§A.6 step 1)           | PDK access  |
| G2   | funding for IP-only MPW shuttle (§A.6 step 2)   | tape-out $$ |
| G3   | RTL-level σ²/τ/φ identity verification          | Step C iter |
| G4   | Verilator/SystemC NPU model (§A.6.1 step C)     | sim-firmware|
| G5   | INT8/FP16 dual-path FuSa ASIL-B path            | qual        |

v0.1 freeze: 2026-05-08. Next revision tag: v0.2 after Step B (NPU
sim-parity numerics scripts) lands.
