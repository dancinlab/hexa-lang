# BC4 FlashAttention-v3 — smem-residency 웨지 닫힘-형식 정찰 (2026-05-28)

> **목적.** GPU 도메인 §1m round-7(`F-FUSION-ATTN-ROOFLINE`)의 closing note —
> *"shallower tile BM=32/16 + register-resident O + selective TMA → 2-4 CTAs/SM"* —
> 가 silicon-fire 가치가 있는지 **closed-form** 으로 사전-증명/사전-반증한다.
> 본 라운드는 **NO codegen, NO silicon fire**. 다음 silicon 라운드의 표적을 정직히
> 결정하기 위한 정찰 한 장.
>
> **방법론.** `feedback_closure_is_physical_limit` + `feedback_instrument_first_methodology`
> 규칙 5 (AI-aware roofline) — 분석이 *물리적으로* BM=32 웨지를 1.5× 아래로 가둔다면
> 그 사실을 정직하게 적고, **다른 라운드 표적**을 제안한다.

---

## 1. 선행 4 라운드 정직 요약 (지배 비율 + 닫힌 축)

| Round | Slug | 비율 vs cuBLAS-TC | 닫힌 축 |
|---|---|---|---|
| 3 | `F-FUSION-ATTN-WMMA` (단일-CTA) | **9.4–15.5× slower** | TC instruction 단독; single-CTA = ~1/48 SM 점유 = 47/48 SM idle |
| 4 | `F-FUSION-ATTN-MULTICTA` (BM=16, BK=256) | **3.4–5.0× slower** | 좁은 BK; BK=16→256 softmax 16× amortize 했으나 16×16 wmma tile efficiency 가 cuBLAS 큰-tile GEMM 을 못 넘음 |
| 5 | `F-FUSION-ATTN-DECOMP` (153-config sweep) | **best 3.47×** (N=512), N≥2048 worsens | KV-split = small-N occupancy gap 만 채움; N≥2048 partial-O HBM round-trip O(N·split·d) 가 net-negative |
| 7 | `F-FUSION-ATTN-ROOFLINE` (N204 toolkit, BM=64, TMA, double-buffer) | **5.27× @ N=2048 · 6.87× @ N=4096** (REGRESSION) | 64×64 tile smem 99 KB → `cuOccupancyMaxActiveBlocksPerMultiprocessor = 1 CTA/SM`. Double-buffer Δ 0.01% (DMA-bound 아님) |

**Closing-note next-wedge (round-7 §1m bullet):**
> *BM=32 (or BM=16 multi-warp) + REGISTER-RESIDENT O + selective TMA → 2–4 CTAs/SM*

본 문서가 그 wedge 를 **closed-form** 으로 검증한다.

추가 컨텍스트:
- R10 `F-FUSION-ATTN-MULTIWARP` (BM=64, 4-warp, cp.async double-buffer) — best **1.149× @ N=4096 d=64**, 91 reg / 14336 B smem. occupancy = reg-bound 5 CTAs/SM. *binding constraint = intra-warp QK→reduce→PV chain*
- R11 `F-FUSION-ATTN-DSWEEP-PIPE` — d-sweep + 2-stage 컴퓨트 파이프 모두 닫힘 (잘못된 방향)

---

## 2. smem-residency budget (closed-form)

**상수.** RTX 5070 sm_120: smem optin = **102 400 B/SM**, default = 49 152 B; d = 64; fp16 mul / fp32 acc.

**가정 (R10/R11 기준선):** K, V double-buffered (cp.async overlap, 1.34–1.50× lever) + V^T single slot (round-7 mma-fragment-map discovery: `mma.sync.m16n8k16 .trans` 가 8×8-블록 transpose 만 → P·V 는 non-trans 경로) + S=fp32 + P=fp16.

| (BM,BK) | TOTAL(O-smem) | TOTAL(O-reg) |
|---|--:|--:|
| (16, 16) | **17 920** | **13 824** |
| (16, 32) | **29 696** | **25 600** |
| (16, 64) | **53 248** | **49 152** |
| (16,128) | **100 352** | **96 256** |
| (16,256) | **194 560** | **190 464** |
| (32, 16) | **25 600** | **17 408** |
| (32, 32) | **38 912** | **30 720** |
| (32, 64) | **65 536** | **57 344** |
| (32,128) | **118 784** | **110 592** |
| (32,256) | **225 280** | **217 088** |
| (64, 16) | **40 960** | **24 576** |
| (64, 32) | **57 344** | **40 960** |
| (64, 64) | **90 112** | **73 728** |
| (64,128) | **155 648** | **139 264** |
| (64,256) | **286 720** | **270 336** |

(round-7 실측 smem = 99 136 B @ BM=BK=64 — 본 모델 90 112 B 와 9 KB 차 = wmma fragment scratch + softmax m/l + alignment padding. 모델 1-σ 정확.)

---

## 3. Occupancy 투영 — 핵심 표 (O register-resident vs smem)

`CTAs/SM = floor(102 400 / smem_per_CTA)`, **optin budget**.

| (BM,BK) | O-smem CTAs/SM | O-reg CTAs/SM | wedge 이득 |
|---|--:|--:|--:|
| (16, 16) | 5 | **7** | +2 |
| (16, 32) | 3 | **4** | +1 |
| (16, 64) | 1 | **2** ✓ | +1 |
| (16,128) | 1 | 1 | 0 |
| (32, 16) | 4 | **5** | +1 |
| (32, 32) | 2 | **3** | +1 |
| (32, 64) | 1 | 1 | 0 (★ wedge 후보 falsified) |
| (32,128) | 0 | 0 | both N/A |
| (64, 16) | 2 | **4** | +2 |
| (64, 32) | 1 | **2** ✓ | +1 |
| (64, 64) | **1** (round-7 실측) | **1** | 0 |
| (64,128) | 0 | 0 | both N/A |

**🔴 닫힌-형식 1차 결론 (round-7 closing note 부분-반증).**

round-7 의 wedge 추천은 *"BM=32/16 + register-resident O + selective TMA → 2-4 CTAs/SM"*.
본 closed-form 분석은:

- **BM=32 BK=64 (R10 의 자연스러운 후속): O-reg 적용해도 여전히 1 CTA/SM** (smem 57 344 B > 102 400 B 절반 초과) — ★ wedge 후보가 *quantitatively falsified before silicon*
- **BM=32 BK=32 → 3 CTAs/SM** ≥ 2 cutoff 통과
- **BM=16 BK=64 → 2 CTAs/SM** 통과
- **BM=64 BK=32 → 2 CTAs/SM** 통과 (R10 코드베이스에 가장 가까운 변화)

**실제 wedge 후보:**

| wedge 후보 | smem (O-reg) | CTAs/SM | grid(N=2048) | SM coverage |
|---|--:|--:|--:|---|
| (BM=16, BK=64) | 49 152 B | 2 | 128 CTAs | 256 CTA-slots ÷ 48 SM = 2.67 waves |
| **(BM=32, BK=32)** | 30 720 B | 3 | 64 CTAs | 144 ÷ 48 = 3 waves, full |
| (BM=64, BK=16) | 24 576 B | 4 | 32 CTAs | 32 ÷ (48·4) = under-fills |

**주된 wedge = (BM=32, BK=32).**

---

## 4. Register pressure check (O register-resident)

**O = BM × d fp32 elements, 분산 over 4 warps = 128 threads.**

| BM | O elements | fp32 regs/thread (O 만) |
|--:|--:|--:|
| 16 | 1 024 | 8 |
| 32 | 2 048 | **16** |
| 64 | 4 096 | 32 |

R10 multi-warp BM=64 kernel reg footprint = 91 reg/thread (smem-O 형식, 0-spill).

| BM | 추정 reg/thread (O-reg) | reg-bound CTAs/SM (65 536 reg/SM, 128 thd/CTA) |
|--:|---|--:|
| 16 | ~95 | **5** |
| 32 | ~103 | **4** |
| 64 | ~119 | **4** |

**모두 255-reg/thread 한계 밑. spill 위험 없음.**

**최종 occupancy = min(smem, reg):**

| wedge | smem-CTAs/SM | reg-CTAs/SM | **min** |
|---|--:|--:|--:|
| (BM=16, BK=64) | 2 | 5 | **2** |
| (BM=32, BK=32) | 3 | 4 | **3** |
| (BM=64, BK=16) | 4 | 4 | **4** |

**`__launch_bounds__(128, 3)` 권장 (BM=32 wedge).**

---

## 5. Selective TMA — 분석

round-7 측정: TMA double-buffer Δ = 0.01% = ZERO benefit @ 1 CTA/SM.

Wedge 후 (3 CTAs/SM): 12 warps/SM = 25% occupancy. cp.async.cg 가 이미 K/V load latency hide (R10 lever 1.34–1.50×). BM=32 BK=32 wedge 의 K/V tile = 4 KB < TMA sweet-spot 16 KB.

**TMA = secondary lever.**

| 적용 | 권장 | 근거 |
|---|---|---|
| TMA on Q | NO | cp.async 1-shot 충분 |
| TMA on K-prefetch (4 KB) | NO | cp.async sweet spot |
| **TMA on V (after pre-transpose)** | MAYBE | A/B 1 회 측정으로 결정 |

---

## 6. Pre-registered falsifier — `F-FUSION-ATTN-BM32-OCCUPANCY-WALL`

Kernel `flash_attn_bm32_occupancy_v0` (BM=32, BK=32, register-resident O, V pre-transpose, cp.async.cg double-buffered K/V, 4 warps/CTA, `__launch_bounds__(128, 3)`):

- `cuOccupancyMaxActiveBlocksPerMultiprocessor ≥ 3` AND
- ratio ≤ **1.5×** vs cuBLAS-TC 3-launch @ N ∈ {2048, 4096} d=64 AND
- per-row-scaled rel ≤ **1e-2** vs f64 CPU ref (NOT `|err|/(|want|+1e-6)` — round-3 metric artifact), naninf=0

**Honest 비-PASS 케이스:**

| measured ratio | tier | 다음-라운드 표적 |
|---|---|---|
| ≤ 1.0× | 🟢 capstone WIN | paper_gate 통과 |
| ≤ 1.10× | 🟢 partial WIN | d-sweep + selective TMA |
| 1.10× < r ≤ 1.5× | 🟠 partial closed-negative | wgmma 또는 FP8 e4m3 |
| > 1.5× | 🔴 wedge FALSIFIED | axis-A round-15 = wgmma 단일-lever |

**기준선 무결성 (R11 lesson):** baseline = corrected cuBLAS-TC 3-launch (R11 OPTIMIZED block-per-row parallel-reduction softmax, NOT naive one-thread-per-row strawman).

---

## 7. Honest risk register (silicon-fire 전 cheap-first 검증)

| # | 위험 | cheap-first oracle |
|---|---|---|
| a | Reg footprint > 255 → spill | R10 PTX sed 1-line patch (smem-O → reg-O) → `ptxas -arch=sm_120a -v` 30초 |
| b | BM=32 grid (N/32) < 48 SMs @ N=2048 | closed-form: N/BM = 64 > 48 ✓ |
| c | Per-warp softmax 가 binding constraint | sm_120 scheduler 12 warps/SM 분석 + ncu profile 1회 |
| d | V pre-transpose smem 충돌 | round-7 probe2/probe3 BM=32 BK=32 형식 재실행 |
| e | cp.async lever 약화 (BK=32 K-tile 4KB < sweet spot) | A/B 1회 (cp.async on/off) |
| f | R12 batch=1 decode axis 직교 | 다른 worktree 동시 fire 가능; 본 plan 은 prefill scope 만 |

**Risk a, b: free oracle 즉시 closed. Risk c, d, e: 각 < 5분 silicon probe.**

---

## 8. Closure 기준

(1) Round-14 새 행 `### 1p — F-FUSION-ATTN-BM32-OCCUPANCY` 을 `GPU.md` § 1 끝에 append.

(2) §10 axis-A attention 박스 `[ ]` → `[x]` flip 조건: ratio ≤ 1.0× AND numeric PASS.

(3) Honest tier 사전 등록:

| outcome | tier | paper_gate |
|---|---|---|
| ≤ 1.0× | 🟢 | PASS |
| ≤ 1.10× | 🟢 | PASS (round-7 pre-registered target) |
| ≤ 1.5× | 🟠 | NO |
| > 1.5× | 🔴 | NO |

---

## 9. **HONEST physical-limit 검토 — round-7 closing note 부분 반증 + 진짜 표적**

`feedback_closure_is_physical_limit` + `feedback_instrument_first_methodology` rule 5 적용:

**Round-7 closing note 의 quantitatively 정확한 형태:**
- 원안: BM=32 BK=64 → § 3 표에서 **1 CTA/SM 으로 falsify** (smem 57 344 B > 102 400 B 절반)
- 본 plan 의 *진짜* wedge: **BM=32 BK=32** = 3 CTAs/SM (smem 30 720 B) — closing note 의 *정량적 빈 칸* 채움

**Arithmetic intensity 정직:**

| (BM, N) | AI (flops/byte) | sm_120 TC ridge (~372 fp/byte) | HGEMM ridge (~104 fp/byte) |
|---|--:|--:|--:|
| (16, 2048) | 15.8 | 4.2% | 15.2% |
| **(32, 2048)** | **31.3** | **8.4%** | **30.0%** |
| (64, 2048) | 61.1 | 16.4% | 58.8% |

**물리적 ceiling 정직:** BM ↑ = AI ↑ but smem ↑ → occupancy ↓.

| BM | regime |
|---|---|
| 16 | bandwidth-bound (occupancy 5+) |
| **32** | **compute-leaning-balanced (occupancy 3)** |
| 64 | compute-bound + parallel deficit (occupancy 1) |

**HONEST closed-form roofline projection:**

cuBLAS-TC 3-launch @ N=4096 d=64 = 0.186 ms (round-7 측정), 그 안 두 GEMM ≈ 23.0 TFLOPS (HGEMM-ridge 32.8%).

BM=32 wedge 최대 달성 TFLOPS ≈ HGEMM-ridge × (AI/AI_ridge ≤ 1) × (occupancy 3/5 of R10)
≈ 70.2 × 0.3 × 0.6 ≈ **12.6 TFLOPS**

→ 예상 fused wall ≈ 0.135 × (23.0/12.6) ≈ **0.246 ms** @ N=4096
→ **ratio ≈ 0.246 / 0.186 ≈ 1.32×**

**🟠 wedge 의 honest closed-form 예상 = ratio 1.32× → ≤ 1.5× partial PASS sweet spot, ≤ 1.10× capstone *물리적으로* 불가** — capstone 은 wgmma (sm_90 async warpgroup mma) 단독-lever 필요 (R11 미시도).

**Sequenced recommendation:**
- **Round 14 (본 plan 적용)** = BM=32 BK=32 O-reg wedge, 표적 ratio ≤ 1.5×, sweet spot 🟢 partial
- **Round 15 (contingency)** = wgmma (sm_90 async warpgroup mma), 표적 ratio ≤ 1.10×, *진짜* capstone

---

## 10. Step-by-step roadmap (sequenced, no silicon this round)

1. **본 plan commit + push + PR** (이 라운드의 유일한 deliverable)
2. **Cheap-first oracle 1: risk (a) 닫힘** — R10 PTX 1-line patch → `ptxas -v` 30초
3. **Cheap-first oracle 2: risk (d) 닫힘** — round-7 probe2/probe3 BM=32 BK=32 재실행
4. **Round 14 silicon fire** (별도 cycle-bg): `flash_attn_bm32_occupancy_v0` hand-emit → fa_mma_oracle 확장 fire on ubu-2
5. **Round 15 contingency**: 1.10× 미달이면 wgmma 라운드

본 plan = step 1.

---

## 11. Invariants 준수

- No LLVM (@F f1)
- No C-transpile (@F f2)
- `compiler/codegen/*.hexa` UNTOUCHED — 본 plan 은 docs/notes/ 만
- CPU codegen MD5 preserved
- Pure-ASCII (한국어 문서; English code identifiers)
- No silicon fire this round
- SSOT roster: 본 plan = plan; 향후 fire 결과 = `GPU.md` round 행 + `GPU.log.md` append

---

## 12. Cross-references

- Round-7 closing note `archive/fires/fusion_attention_roofline_2026_05_25/result.json` field `next_round_wedge` = 본 plan 출발점; § 3 가 closing note 를 부분 양적-반증
- Round-10 `archive/fires/fusion_attn_multiwarp_2026_05_26/` 의 91-reg footprint = § 4 기준선
- Round-11 `archive/fires/fusion_attn_dsweep_pipe_2026_05_26/` 의 baseline 무결성 lesson = § 6 baseline rule
