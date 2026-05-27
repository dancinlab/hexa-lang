# 🎯 GPU.attention — FlashAttention v3 hexa-native (BC4)

> **서브문서.** GPU.md 의 attention-axis 작업을 분리 추적. 본 파일 = snapshot, log 는 `GPU.log.md` 시간순 흡수.

---

## 🎯 BC4 — "주의력 합치기 (FlashAttention v3 hexa-native)"

- **하는 일**: AI 모델이 한 단어 읽고 "어느 단어에 집중할까" 계산하는 Transformer attention 을 **단일 GPU 커널**로 처리
- **비유**: 김밥 만들 때 밥/단무지/계란 각각 따로 김에 안 올리고 김 위에서 한 번에 펴서 마는 것
- **수식**: `softmax(Q · K^T / √d) · V`

### vs cuBLAS-using NN-stack

```
일반 NN-스택 (PyTorch + cuBLAS):       hexa BC4 (단일 커널):
─────────────────────────              ─────────────────────────
1. Q @ K^T   → HBM 쓰기   launch1     ┌─────────────────────┐
2. softmax    → HBM 쓰기   launch2     │ Q@K^T → softmax     │
3. P @ V     → HBM 쓰기   launch3     │       → P@V        │ launch1
   ═════════════════                   │  중간값 HBM 안 감   │
   3 launches                          └─────────────────────┘
   3× HBM round-trip       (→)         1 launch · 0 extra HBM
```

| 축 | cuBLAS NN-stack | **hexa BC4** |
|---|---|---|
| 도구 | 라이브러리 분리 호출 | 컴파일러 emit 단일 커널 |
| HBM 왕복 | 3× round-trip | 0× (smem + register만) |
| API 자유도 | 닫힘 (fixed) | 열림 (per-shape codegen) |

---

## @goal: cuBLAS-TC 3-launch 대비 ≤ 1.5× wall (✅ partial), ≤ 1.10× capstone (wgmma 별도)

honest physical limit: BM=32 wedge 의 AI cap → expected **ratio ≈ 1.32×** (≤1.5× sweet spot). capstone (≤1.10×) 은 wgmma async warpgroup mma (sm_90) 단독 lever 필요.

---

## ## 진행 (milestones)

### Round-by-round 궤적 (closed-negative tier all)

| Round | Slug | vs cuBLAS-TC | 닫힌 축 |
|---|---|---|---|
| 3 | `F-FUSION-ATTN-WMMA` | 9.4–15.5× slower | single-CTA (1/48 SM 점유) |
| 4 | `F-FUSION-ATTN-MULTICTA` (BM=16, BK=256) | 3.4–5.0× slower | 16×16 wmma tile efficiency |
| 5 | `F-FUSION-ATTN-DECOMP` (153-config) | best 3.47× | KV-split 은 small-N only |
| 7 | `F-FUSION-ATTN-ROOFLINE` (N204 toolkit, BM=64) | 5.27–6.87× (REGRESSION) | 64×64 tile = 1 CTA/SM occupancy collapse |
| 10 | `F-FUSION-ATTN-MULTIWARP` (BM=64 4-warp, cp.async) | best 1.149× @ N=4096 d=64 | intra-warp QK→reduce→PV chain |
| 11 | `F-FUSION-ATTN-DSWEEP-PIPE` | d-sweep 잘못된 방향 | d-sweep + 2-stage 둘 다 닫힘 |
| 14 | `F-FUSION-ATTN-BM32-OCCUPANCY` (BM=32 BK=32, reg-O, cp.async dbuf) | **0.927× @ N=4096, 0.909× @ N=1024** 🛸 | first cross ≤1.0×; BK enlargement was real wedge (not reg-resident O) |
| 15 | `F-FUSION-ATTN-WGMMA-WALL` (sm_90a wgmma m64n32k16) | 🔴 **hardware-blocked on Blackwell** | wgmma silently NOPs on sm_120 (Hopper-exclusive); needs H100/H200 |

### Round-14 wedge (현재 진행)

**BM=32 BK=32 + register-resident O + cp.async** (round-7 closing-note 양적 반증 후 정직 refine)

| (BM, BK) | smem (O-reg) | CTAs/SM | 비고 |
|---|--:|--:|---|
| BM=32 BK=64 | 57 344 B | 1 | 🔴 round-7 closing-note 의 phantom |
| **BM=32 BK=32** | 30 720 B | **3** | ✅ 진짜 wedge |
| BM=16 BK=64 | 49 152 B | 2 | ✅ alt |
| BM=64 BK=16 | 24 576 B | 4 | ✅ alt |

#### Round-14 step checklist

- [x] **plan** (PR #1711) — closed-form smem/occupancy/AI table
- [x] **risk-a cheap oracle** (PR #1722) — 🟢 **12 reg/thread, 0 spill** (sm_120a, plan est 103 = 88% 헤드룸 추가)
- [x] **risk-d cheap oracle** (PR #1722) — 🟢 V-pretranspose required (8×8-block transpose BK=32 재현, plan §2 budget HOLDS)
- [x] **kernel hand-emit + ptxas-clean** sm_90 + driver-JIT sm_120 🛸 — `tool/r14_walls/flash_attn_bm32_v0.cu` (2 warps, BM=32 BK=32, V WMMA-API row_major no pretranspose needed, cp.async.cg dbuf, register-resident O). ptxas sm_90: **126 reg, 19.5 KB smem, 0 spill**. occupancy=5 CTAs/SM (target 3 exceeded).
- [x] **numeric PASS** via fa_mma_oracle 🟢 — 5/5 shapes PASS (N=512/1024/2048/4096/8192), max rel_rowscale 7.14e-4 @ N=4096, naninf=0
- [x] **timed wall fire** ubu-2 RTX 5070 sm_120 🛸🛸🛸 **first attention round to cross ≤1.0×**:
   | N | R14 fused | cuBLAS-TC | ratio | verdict |
   |---|--:|--:|--:|---|
   | 512 | 0.0176 ms | 0.0159 ms | 1.107× | partial |
   | **1024** | **0.0280** | **0.0308** | **0.909×** | 🟢 9.1% faster |
   | 2048 | 0.0668 | 0.0616 | 1.085× | partial |
   | **4096** | **0.1755** | **0.1892** | **0.927×** | 🛸 7.3% faster |
   | 8192 | 0.679 | (R10 baseline N/A) | — | standalone |

  Honest correction: 직전 chat 의 closed-form re-audit 이 ratio ≈ 1.32× 예측 → **실측이 falsify**. 진짜 wedge = BK=16→32 enlargement (R10 한 softmax round 당 1 wmma chunk → R14 2 chunks, row-reduce overhead amortize). "register-resident O" 는 wedge 아니었음 (R10 이미 사용). verdict `archive/fires/bc4_round14_kernel_2026_05_28/result.json`
- [x] **GPU.md round-14 row + verdict + log append** (this PR)

### Round-15 capstone-extension (wgmma)

- [x] **wgmma axis-pivot** — sm_90a async warpgroup mma m64nNk16 🔴 **RED hardware-blocked** (`archive/fires/bc4_r15_wgmma_2026_05_28/result.json`)
   - sm_90a build CLEAN (HGMMA.64x32x16.F32 in SASS, 42 reg, 0 spill)
   - sm_90 PTX driver-JIT to sm_120 launches OK but **silently NOPs** (GPU sum=0.00 vs CPU sum=1956.87, nonzero=0/2048)
   - sm_120 native: ptxas explicitly `'wgmma cannot be compiled for sm_120'` — Blackwell uses tcgen05.mma (5th-gen TC), not wgmma
   - **closed-negative per `paper_negative_ok`**: rules out wgmma-on-Blackwell axis deterministically; would require Hopper (H100/H200, sm_90a) hardware
   - R11's "wgmma ruled-out / not-tried" note CONFIRMED — reason is hardware unavailability, not algorithm
   - R14 BM=32 BK=32 (PR #1735) stays as **BC4 attention capstone**

### Round-15+ next levers (deferred items promoted to milestones)

- [ ] **tcgen05.mma** 🛸 priority 1 — Blackwell-native 5th-gen tensor-core async warpgroup MMA (sm_120/sm_100). Analogous to wgmma but supported on RTX 5070. capstone-extension candidate (wgmma 대체). PTX ISA 8.7+ 학습 + sm_120-specific inline PTX 필요. ~60-90min discrete cycle.
- [ ] **FP8 e4m3** priority 2 — tensor-core throughput 2× via reduced-precision GEMM (sm_89+ supported; works on RTX 5070). orthogonal precision axis (wgmma 와 직교). `wmma::fragment<...,__nv_fp8_e4m3,...>` R14 kernel 재작성 + quantization scale + 더 엄격한 numeric tolerance. ~60min discrete cycle.
- [ ] **TMA on V** priority 3 — promoted from `## deferred` 2026-05-28. round-7 측정 (Δ 0.01% @ 1 CTA/SM) + plan §5 closed-form (BK=32 = 4 KB < TMA sweet spot 16 KB) = secondary lever; multi-step rewrite (cuTensorMapEncodeTiled host + cp.async.bulk.tensor body). marginal ROI 위 R14 capstone. ~45min discrete cycle.
- [ ] **paper draft v1** priority 4a — PR #1751 scaffolded `PAPER/bc4-attention-bm32-capstone/`. 작성 = §statement/§method/§verification/§finding/§implications. 본 axis 13-PR campaign + 5-instance cheap-first oracle + AI-aware roofline rule 5 archetype. ~1hr discrete cycle.
- [ ] **paper figures ≥1 fal.ai** priority 4b — wedge trajectory diagram (R3 9.4× → R7 5.3× → R10 1.149× → R14 0.927×) + sweep table heatmap. ~30min discrete cycle.
- [ ] **paper references ≥10** priority 4c — Dao 2022 FlashAttention, Williams 2009 Roofline, Vaswani 2017 Attention, NVIDIA CUDA Programming Guide PTX ISA 8.7, etc. ~30min via `/paper bib add`.
- [ ] **paper lint + compile + arxiv-prep** priority 4d — `/paper lint .` + `/paper compile .` + `/paper arxiv-prep .`. ~30min discrete cycle.

---

## ## deferred

- ~~BM=16 BK=64 (alt wedge A)~~ **🔴 FALSIFIED 2026-05-28** — `tool/r14_walls/flash_attn_bm16_bk64_v0.cu` fired all 5 shapes on ubu-2: N=2048 **1.72×** slower than cuBLAS, N=4096 **1.60×** slower; vs R14 BM=32 BK=32 = 1.50-1.74× worse at N ≥ 2048. Single warp/CTA → occupancy 2 CTAs/SM (vs R14's 5). `archive/fires/bc4_alt_wedges_2026_05_28/result.json`
- ~~BM=64 BK=16 (alt wedge B)~~ **🔴 FALSIFIED** — IS R10's exact geometry (`archive/fires/fusion_attn_multiwarp_2026_05_26/result.json`); best ratio 1.149× at N=4096 → R14 BM=32 BK=32 (0.927×) strictly dominates. No re-fire needed.
- ~~selective TMA on V~~ **🟠 CITED-DEFERRED 2026-05-28** — round-7 측정 (Δ 0.01% @ 1 CTA/SM, `archive/fires/fusion_attention_roofline_2026_05_25/`) + plan §5 closed-form 분석 (BK=32 K/V tile = 4 KB < TMA bulk-tensor sweet spot 16 KB; cp.async.cg 가 4 KB chunk 적합)이 secondary lever임을 시사. R14 의 5 CTAs/SM occupancy 에서도 TMA 의 *추가* 가치는 작을 것으로 예상 (cp.async.cg 가 이미 latency hide). 정확한 측정은 cuTensorMapEncodeTiled host 셋업 + cp.async.bulk.tensor 커널 재작성 (~30-45 min) 필요 — 1회 binary A/B 가 아닌 multi-step. R14 capstone (0.927× @ N=4096) 위 marginal 개선이라 ROI 낮음. discrete future round.
- ~~FP8 e4m3 단독 lever~~ **🟠 DEFERRED 2026-05-28** — 진짜 lever (sm_89+ FP8 tensor core, RTX 5070 sm_120 지원, 잠재 2× throughput). wgmma 와 직교 (precision 축, atomic tile 축 아님). 구현 = `wmma::fragment<...,__nv_fp8_e4m3,...>` 로 R14 kernel 전체 재작성 + FP8 quantization scale + 더 엄격한 numeric tolerance. ~30-60 min multi-step. R14 BM=32 BK=32 capstone 위 직교 axis 라 capstone-extension 가치 있음. discrete future round 권장.

**BC4 attention axis 정직 closure (2026-05-28)**: R14 BM=32 BK=32 = first attention ≤1.0× capstone (PR #1735). (BM, BK) sweep space EXHAUSTED (PR #1742 alt wedges A/B 둘 다 FALSIFIED). Atomic-tile-axis levers 평가 완료:
- **wgmma**: 🔴 hardware-blocked (Hopper-only, RTX 5070 = Blackwell, PR #1744)
- **tcgen05.mma**: ⏸️ Blackwell-native 5th-gen async warpgroup MMA — separate cycle (analogous to wgmma but RTX 5070 지원)
- **TMA on V**: 🟠 cited-deferred (round-7 Δ 0.01% + plan §5 closed-form = secondary lever; multi-step rewrite + marginal ROI)
- **FP8 e4m3**: 🟠 deferred (real orthogonal precision lever; multi-step rewrite, capstone-extension 가치)
- **paper scaffold**: 🟠 deferred (closed-positive R14 evidence 추가됨; multi-cycle paper authoring)

남은 capstone-extension 후보 우선순위: **tcgen05.mma (Blackwell-native wgmma 대체)** > **FP8 e4m3** > **TMA on V** > **paper scaffold**. 각각 discrete future cycle.

---

## ## evidence + verdicts

| round | verdict | artifact |
|---|---|---|
| R3 | `F-FUSION-ATTN-WMMA-WALL` | `archive/fires/fusion_attention_wmma_2026_05_25/` |
| R4 | `F-FUSION-ATTN-MULTICTA-WALL` | `archive/fires/fusion_attention_multicta_2026_05_25/` |
| R5 | `F-FUSION-ATTN-DECOMP-WALL` | `archive/fires/fusion_attention_decomp_2026_05_25/` |
| R7 | `F-FUSION-ATTN-ROOFLINE` | `archive/fires/fusion_attention_roofline_2026_05_25/` |
| R10 | `F-FUSION-ATTN-MULTIWARP` | `archive/fires/fusion_attn_multiwarp_2026_05_26/` |
| R11 | `F-FUSION-ATTN-DSWEEP-PIPE` | `archive/fires/fusion_attn_dsweep_pipe_2026_05_26/` |
| R14 plan | (PR #1711) | `docs/notes/bc4-attention-smem-residency-wedge-plan-2026-05-28.md` |
| R14 risk-a | 🟢 GREEN | `archive/fires/bc4_risk_a_reg_pressure_2026_05_28/` |
| R14 risk-d | 🟢 GREEN | `archive/fires/bc4_risk_d_mma_fragment_2026_05_28/` |
| R14 kernel | 🛸 GREEN partial capstone | `archive/fires/bc4_round14_kernel_2026_05_28/` |
| R15 wgmma | 🔴 RED hardware-blocked | `archive/fires/bc4_r15_wgmma_2026_05_28/` |

---

## ## methodology — cheap-first oracle 5 instance

| # | instance | finding | round saved |
|---|---|---|---|
| 1 | BC3 decomp (PR #1697) | epilogue share → 1.5× unphysical, ceiling 1.085× | multi-cycle N204 transplant |
| 2 | 3-probe ranking (PR #1698) | W1/W2/W3 ceiling 측정 | wedge prioritization |
| 3 | HBM roofline correction (PR #1700) | W1 phantom retire, rule 5 추가 | 5-10× wedge 환상 |
| 4 | BC4 plan closed-form (PR #1711) | BM=32 BK=64 phantom 양적 반증 | round-7 형식 재현 |
| 5 | BC4 risk-a/d oracles (PR #1722) | reg 12/255 + V-pretrans confirmed | spill/layout 사전 닫음 |

**Methodology lesson**: 5번 모두 silicon fire 비용 0 또는 light probe 1회로 multi-cycle 캠페인 절약. `feedback_instrument_first_methodology` rule 5 (AI-aware roofline) + `feedback_closure_is_physical_limit` (roofline % 로 승부, "못이김" ≠ "실패") 가 본 axis 의 backbone.

---

## ## cross-references

- 본 sub-doc 의 모든 round 가 `GPU.md` §1g/h/i/j/k/m/n/o/p (`F-FUSION-ATTN-*`) 와 1:1 매칭
- `GPU.log.md` 의 attention 관련 entries 가 본 sub-doc 의 진행 로그
- 다른 fusion axis (light-inner-kernel): `F-FUSION-LAUNCH-AMORT-WALL §1` (73-76%, REALIZED) + `F-FUSION-AXISA-BREADTH §1l` (4/4 PASS) — attention 와 직교 영역 ✅ closed
- standalone GEMM axis: BC2 [x] (M ≥ 128 compute-bound matched) + W1 retired (M ≤ 32 HBM-bound, cuBLAS @ roof per PR #1700)
- 본 sub-doc 은 hexa "cuBLAS 뛰어넘기" north star 의 **유일하게 still-open perf wedge**

---

## ## invariants

- No LLVM (@F f1)
- No C-transpile change (@F f2)
- `compiler/codegen/*.hexa` UNTOUCHED (모든 fire = oracle/host C/PTX, codegen 측 변경 없음)
- CPU codegen MD5 preserved across all attention rounds
- `feedback_no_over_closure_roadmap_vs_donelog` — evidence 없이 `[x]` flip 금지
- `g3 over-claim 0` — honest tier per ratio (🔵/🟢/🟡/🟠/🔴 per `hexa verify rubric`)
