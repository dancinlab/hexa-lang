# flame + forge vs PyTorch + cuBLAS — an honest head-to-head

> **Read the TL;DR before quoting any number.** This is a *result* document, not a
> pitch. Every speed and correctness number below traces to a named verdict under
> `.verdicts/` (g5: verbatim evidence, no rounding-mangle, no invented benchmark).
> No `/paper` was scaffolded (project.tape **g84**, PAPER OPT-IN).

---

## TL;DR — matched-dtype, the gap is SINGLE-DIGIT: flame TIES/WINS at FP64, torch wins TF32 by 2–8×

flame + forge is **not** three orders of magnitude behind PyTorch + cuBLAS. When you
measure the **compiled step kernel** (interpreter eliminated) at **matched dtype**, the
honest speed gap collapses to **single digits**:

- **FP64**: flame **TIES or WINS** — torch ÷ flame = 0.83–1.10× across the batch sweep
  (flame ties at B=2, **wins at B=4 and B=8**; highest FP64 throughput at B=8 is flame's,
  826 vs 745 samples/s). The precision torch cannot tensor-core-accelerate is exactly where
  flame's bit-exact step is **on par or faster**. (`F-BENCH-1`, RTX 5070.)
- **TF32 / FP32**: torch is **2–8× faster** (3.03× @B=1 → 7.88× @B=8 for TF32; 2.15× → 6.60×
  for FP32) — its **cuBLAS / inductor tuned GEMM** beats flame's naive tiled CUDA-core GEMM.
  This is a real, honest torch win — but it is **single-digit, not 1656×**. (`F-BENCH-1`.)
- The hexa-owned **own-GEMM** reaches **parity, not a beat**: ~1.08× of cuBLAS-TF32
  @ D=2048 (bit-exact), and **~1.5× slower** @ D=4096 (a **fixable scheduling stall**, not a
  hard roofline — see §4). (`F-GPU-ROUTEA-KEEPBAND-MEASURE`, `F-OP45GPU-OCCUPANCY-SWEEP`.)

> **The old "~1656× / ~2207× slower" headline was MISLEADING — see §1.1.** It compared
> flame **FP64** against torch **TF32** (different precision, which favors torch on GEMM)
> **and** derived flame's step/s from the **interpreted-glue full trainer** at batch=1
> (a 2-point extrapolation of a ~6 s/step interpreter artifact), not the compiled step
> kernel. The matched-dtype BENCH-1 re-measurement takes it down to ~1× (FP64) … ~8× (TF32 B=8).

Where torch *does* win (TF32/FP32 throughput, 2–8×), it competes on a **different axis** anyway:

> **bit-exact reproducibility · machine-independence · device-residency · no-LLVM / no-Python compile-theorem stack.**

**Pick hexa flame + forge when** you need a training step that produces **byte-identical
results across machines and architectures** and compiles with cited theorems — an
auditable, reproducible, vendor-free stack. **Pick PyTorch + cuBLAS when** you need
maximum TFLOP/s, large-batch throughput, or the ecosystem. They are not the same product.

PyTorch does **not** guarantee cross-machine bit-exactness: its transcendentals route
through the platform `libm` (not correctly-rounded — glibc vs Darwin differ in the last
ULP), its reductions are tree/atomic-order-dependent, and cuBLAS's DMMA accumulation
order is vendor-**"unspecified"**. flame closes every one of those holes by construction.

---

## 1. Speed — matched-dtype, single-digit (FP64 flame ties/wins; TF32 torch 2–8×)

### 1.1 Full training step, MATCHED DTYPE (the fair, authoritative number)

The authoritative speed evidence is `F-BENCH-1` — a **fair, matched-dtype, batch-swept**
comparison of the **compiled step DAG** (interpreter eliminated) on a **free** RTX 5070
(sm_120, $0, no vast). Same step DAG both sides: fwd GEMM → groupnorm + tanh-gelu valley
→ bwd GEMM → AdamW, with torch's `nn.Linear` / `LayerNorm` / `gelu(tanh)` / `torch.optim.AdamW`
matched cell-for-cell. flame is **bit-exact / deterministic** (run-to-run `max|Δ(W')| = 0` at
every cell); torch is tolerance-based. **ratio = torch step/s ÷ flame step/s** (>1 = torch
faster · <1 = **flame faster**); `best torch` = max(eager, compile). (`F-BENCH-1`.)

```
  dtype  B | flame step/s | torch-eager (ratio) | torch-compile (ratio) | best torch÷flame
  -------+--------------+---------------------+-----------------------+-----------------
  FP64  1 |     604.84   |  514.31  (0.85×)    |  662.81  (1.10×)      |  1.10×
  FP64  2 |     357.88   |  299.73  (0.84×)    |  350.01  (0.98×)      |  0.98×  flame TIES
  FP64  4 |     196.70   |  163.32  (0.83×)    |  182.65  (0.93×)      |  0.93×  FLAME WINS
  FP64  8 |     103.33   |   85.28  (0.83×)    |   93.12  (0.90×)      |  0.90×  FLAME WINS
  TF32  1 |    1600.97   | 4856.04  (3.03×)    | 4589.95  (2.87×)      |  3.03×
  TF32  2 |    1193.69   | 4866.82  (4.08×)    | 3771.85  (3.16×)      |  4.08×
  TF32  4 |     789.24   | 4375.64  (5.54×)    | 3471.35  (4.40×)      |  5.54×
  TF32  8 |     470.91   | 2705.13  (5.74×)    | 3708.76  (7.88×)      |  7.88×
  FP32  1 |    1604.72   | 3457.55  (2.15×)    | 3730.64  (2.32×)      |  2.32×
  FP32  2 |    1195.39   | 4367.17  (3.65×)    | 4131.31  (3.46×)      |  3.65×
  FP32  4 |     789.59   | 3499.44  (4.43×)    | 3860.89  (4.89×)      |  4.89×
  FP32  8 |     470.86   | 2089.92  (4.44×)    | 3106.77  (6.60×)      |  6.60×
```

**Read this table as the truth.** Matched-dtype + batch, the gap is **~1× (FP64) … ~8× (TF32
B=8)**, single-digit everywhere:

- **FP64**: flame **ties at B=2 and WINS at B=4, B=8** (torch ÷ flame = 0.83–1.10×). torch FP64
  has **no tensor-core path**, so flame's hand-fused deterministic FP64 step is genuinely
  competitive — and at B=8 flame has the **highest FP64 throughput** (826 vs 745 samples/s).
- **TF32**: torch **3.03× (B=1) → 7.88× (B=8)** ahead. **FP32**: torch **2.15× (B=1) → 6.60×
  (B=8)** ahead. This residual is cuBLAS/inductor's tuned GEMM vs flame's naive tiled CUDA-core
  GEMM — an **expected and fine** torch win, and a fully **honest** one. torch's absolute TF32
  throughput (up to 29.7k samples/s @B=8) dwarfs flame's 3.8k; if you need max TF32 throughput,
  use torch. The point is only that the gap is **single-digit, not 1656×**.

### 1.1a Why the old "~1656× / ~2207×" headline was MISLEADING (history, re-contextualized)

An earlier figure (`F-FUSION-VS-PYTORCH`, #2912) reported **flame 0.167 step/s vs torch eager
276.7 / compile 368.5 = ~1656× / ~2207× slower** on an H100 at D=1536/T=512/batch=1. **That
number is not the step-kernel gap**, and presenting it as the current flame-vs-PyTorch speed
headline is misleading. Three reasons:

1. **FP64-vs-TF32 mismatch.** It compared flame **FP64** against torch **TF32** — a precision
   gap that *favors torch* on GEMM (the verdict itself admits this). Not apples-to-apples.
2. **Interpreted-glue full trainer, not the compiled step.** The 5980 ms/step (≈6 **seconds**
   per step for a tiny D=1536 model) was the **interpreted per-step host glue** of the full
   hexa-native trainer (per-window `t_get`/`t_set` token copy, ~28-call eager AdamW tail,
   CE/softmax-grad host glue) — **not** the compiled step kernels. Interpreter-elimination
   (#2915) later confirmed the heavy ops are native-C builtins in *both* arms.
3. **2-point linear extrapolation** of that suspect ~6 s/step artifact.

`F-BENCH-1` re-measured the **compiled** step at **matched dtype** and the apparent ~1656×
collapses to single-digit (§1.1). The history is preserved (the #2912 verdict is unchanged on
disk); it is just **no longer the headline**.

For completeness, the #2912 H100 step-rate breakdown still holds *as a description of the full
interpreted trainer*: during GEMM bursts the GPU peaks 100% (flame's own GEMM is ≈cuBLAS-class
**when it runs**), and the 5.98 s/step was dominated by the GPU sitting at **0% between GEMMs**.
Sibling fusion probes (CUDA-graph capture/replay ~1.0×, fwd+bwd fusion ~1.0×) are closed-negative
— fusion is exhausted; the full-trainer wall was the interpreted glue, which the compiled BENCH-1
step does not pay.

### 1.2 flame batch-scaling — a real SELF-speedup, capped ~3× by the interpreter glue

Filling the SMs with larger batch gives a genuine flame-vs-flame throughput lever (still
not a torch beat — this is flame÷flame). Real H100 SXM, byte-eq B=1 `max|Δ|=0`, CE descent
holds. (`F-FUSION-BATCHFILL`.)

```
  B    T_eff    samples/s   ×B=1      note
  ---  -----    ---------   -------   --------------------------------
  1    512      0.1747      1.000×    under-fills SMs (util mean ~10%, median 0%)
  2    1024     0.2628      1.504×    ≥1.3× reached already at B=2
  4    2048     0.3503      2.005×
  8    4096     0.4168      2.386×
  16   8192     0.4785      2.739×
  32   16384    0.5161      2.954×    ← curve flattens; asymptote ≈ 3×
  64   32768    — UNMEASURABLE (a single step runs many minutes; glue ∝ B·Tw runs away)
```

The cap is **structural**: the interpreted per-position glue cost grows **∝ B·Tw**, so
batch-fill is the cheap first ~3× and then the glue eats the gains. Uncapping needs a
precision change or a right-sized GPU or an interpreter-elimination rewrite — **not** more
batch. (`F-FUSION-BATCHFILL`, `F-FUSION-M5-BATCHFILL-UTIL`.)

### 1.3 own-GEMM vs cuBLAS-TF32 — bit-exact PARITY @D=2048, NOT a beat

Route-(a) pre-permute own-GEMM (bit-exact path), b14 MODE 8 frontier, fresh H100 sm_90a,
median of 3 reps, `rel_rms 0.000e+00` at every config. (`F-GPU-ROUTEA-KEEPBAND-MEASURE`.)

```
  shape    own TFLOP/s   cuBLAS-TF32   ratio    rel_rms      parity
  -----    -----------   -----------   ------   ----------   ------
  D=2048   ~315          ~342          1.08×    0.000e+00    YES   (~93% of cuBLAS roofline)
  D=4096   ~284          ~427          ~1.50×   0.000e+00    NO    (shape-rigidity, see §4)
```

`1.08×` is **parity-seeking, not superiority**: cuBLAS-TF32 is the roofline; own-GEMM
reaches ~93% of it @D=2048, **bit-exact**, with no vendor call. It does not beat cuBLAS at
any shape. (`F-GPU-ROUTEA-KEEPBAND-MEASURE`, `F-OP45-ROUTEA-D4096-CAP`.)

### 1.4 TF32 deterministic fast-mode — a flame SELF-speedup over its own FP64

flame ships a deterministic TF32 fast-mode that breaks its own ~3× FP64 step cap:
**4.2× faster than flame FP64 @B=1, D=1536** (B=1, D=768: 4.6×), self-byte-eq run-to-run
(`max|Δ|=0`), rel-RMS ~1.13e-6 vs FP64 (4 orders inside the 1e-2 contract). Measured on a
**free** RTX 5070, $0, no vast. (`F-OP20-TF32-FASTMODE`.) This is **flame ÷ flame**, not a
PyTorch beat — it lowers flame's own latency floor while keeping the reproducibility
identity at a different (TF32) precision contract. BF16 is Pareto-**dominated** by TF32
(same accuracy with fp32 masters, no faster). (`F-OP25-BF16-FASTMODE`.)

> Honest framing on §1.4: the headline B=8/B=32 ratios (19–21×) are **consumer-card-specific**
> — the RTX 5070's FP64 is ~1/64 of FP32, which inflates them; the card-robust signal is the
> **B=1 4.2×**. (`F-OP20-TF32-FASTMODE` §HONEST.)

---

## 2. Reproducibility / correctness — flame WINS (the genuine differentiator)

This is the axis flame + forge is built for. PyTorch does **not** provide these.

| property | flame + forge | PyTorch + cuBLAS | proof |
|---|---|---|---|
| **Cross-machine bit-exact training** | the same fixed-seed CLMConvMoE step produces **byte-identical** weights / grads / loss across machines, ISAs, and OSes — measured over **6 environments / 4 architecture-libc combos**: arm64-macos (Darwin libm), x86_64-linux (glibc, 2 hosts), arm64-linux (glibc, Pi 5), x86_64-musl (Alpine) | **No.** `libm` transcendentals are not correctly-rounded (glibc ≠ Darwin in the last ULP), tree/warp reductions are order-nondeterministic, atomic-scatter races, and FMA-fusion differs per ISA (clang fuses `a*b+c` → 1-rounding FMA on arm64 but 2 roundings on x86) | `flame-machine-independent-training.md`; `F-OP19`/`F-OP19B` (libm exp/erf), `F-OP29` (cross-ISA FMA-matmul), `F-OP15-STEP-DETERMINISM` (whole-step `max|Δ|=0`) |
| **No `libm` on the step path** | every `exp`/`erf`/`ln`/`sqrt` is a fixed-iteration `+ − × ÷` routine (`dt_exp`, `dt_erf` A&S 7.1.26 branchless, `dt_ln`, Newton sqrt) — bit-identical on any IEEE-754 hardware | routes transcendentals through the platform `libm` | `F-OP19`, `F-OP19B`, `F-OP8`, `F-OP11`, `F-OP12` |
| **own-GEMM dev-vs-dev bit-exact** | `rel_rms 0.000e+00` at every config of the full PDEP/NST sweep (vs cuBLAS-TF32 f32-accum order) | cuBLAS DMMA accumulation order is vendor-**"unspecified"**, drifts across GPU generations, un-matchable from outside | `F-GPU-ROUTEA-KEEPBAND-MEASURE` |
| **Whole-step run-to-run determinism** | `max|Δ| = 0` over 17 weights + m + v + loss; negative control (distinct seeds) = 0.344, so the 0.0 is a genuine pass | not guaranteed without `deterministic` flags, and even then cuBLAS algo-selection can vary | `F-OP15-STEP-DETERMINISM` |
| **Golden-fold CI tripwire** | comptime-folded float constants are serialized as bit-exact C99 hex-float literals and locked by a regression gate (`tool/op39_constfold_gate.sh`, 18 folds) so a formatter drift can never silently change the trained bits | n/a (no comptime-fold theorem stack) | `F-OP39` / `F-OP40` / `F-OP42`; `flame-determinism-contract.md` |
| **No LLVM / no Python in the trained binary** | the step compiles through the same 8-stage strict-lint native gate that compiles the compiler itself — no LLVM, no C-transpile at emit, no Python at runtime | PyTorch needs Python + ATen + the CUDA/cuBLAS vendor stack | README "hexa GPU stack"; `flame-machine-independent-training.md` §6 |

**The boundary, stated honestly** (g5): the bit-exact identity is **FP64 self-determinism**.
TF32 fast-mode is byte-eq *run-to-run at TF32* and loss-tracks FP64 to ~1e-7, but TF32
weights are **not** bit-equal to FP64 weights (NN training is chaotic). `dt_erf` is
1.38e-7 from any one platform's `libm` erf **by design** — flame trades "matches one
platform's libm" for "matches *across all* platforms." Cross-platform byte measurements ran
the deterministic transcendentals on CPU across arm64-macos and x86-linux; a
cross-*GPU-architecture* byte measurement is not part of this result. (`flame-machine-independent-training.md` §5.)

---

## 3. When to use which (honest decision guide)

| your need | use |
|---|---|
| Maximum TF32/FP32 TFLOP/s, production throughput, large-batch training | **PyTorch + cuBLAS** — matched-dtype it is **2–8× faster** at TF32/FP32 (its cuBLAS GEMM is the roofline; absolute TF32 throughput up to ~29.7k samp/s @B=8). (At **FP64** flame ties/wins — see §1.1.) |
| Ecosystem (models, datasets, tooling, community) | **PyTorch + cuBLAS** |
| Byte-identical replay across machines / architectures / OSes | **hexa flame + forge** — reproducible-everywhere by construction; PyTorch drifts via libm / FMA / cuBLAS-algo selection |
| Regulated / auditable training (must reproduce a result bit-for-bit, later, elsewhere) | **hexa flame + forge** |
| Deploy with **no LLVM and no Python** in the binary; cited-theorem compile stack | **hexa flame + forge** |
| Research needing zero GEMM noise in an A/B (clean ablations, multi-GPU bit-consistency) | **hexa flame + forge** |
| A fast standalone matmul, nothing else | **cuBLAS** — simpler and faster |

The two stacks are complementary, not competitive on the same metric. flame + forge buys a
**capability column cuBLAS leaves empty** (determinism + ownership + no-vendor + FP64-exact)
at a measured speed cost. If you do not need that column, PyTorch + cuBLAS is the right tool.

---

## 4. The forge own-GEMM boundary (settled — do not re-litigate)

This mirrors `docs/forge-routea-shape-adaptive.md` §0 verbatim where it matters; it is the
hard-won, measured boundary of the route-(a) own-GEMM.

**What it IS** — `route-(a)` pre-permute own-GEMM (gmma-INTER global pre-lay + no-swizzle
TMA + descriptor-direct, no in-kernel decode band) is a **bit-exact, device-resident,
no-LLVM / no-cuBLAS-call** TF32 GEMM:

- **Bit-exact**: `rel_rms 0.000e+00` (dev-vs-dev, f32-accum order) at **every** config — an
  equality, not a tolerance. This is the gate the in-place-descriptor route-(b)/w16 *failed*
  (floored at `rel_rms 1.107`, FALSIFIED). (`F-GPU-ROUTEA-KEEPBAND-MEASURE`.)
- **At cuBLAS-TF32 PARITY @D=2048**: own ≈ **315 TFLOP/s, ratio 1.08×, PARITY=YES** —
  **~93% of the cuBLAS-TF32 roofline**, bit-exact, no vendor call.

**What it ISN'T — NOT a cuBLAS beat.** cuBLAS-TF32 is the **roofline**; 1.08× is
parity-seeking, not superiority. Parity does **not** hold at all shapes:

- **@D=4096 it falls to ~1.50× slower** (own ≈ 284 vs cuBLAS ≈ 427, PARITY=NO). The cause is
  **shape-rigidity**: route-(a) is **one fixed 128×128 plain-launch tile** at every D, while
  cuBLAS is **shape-adaptive** — @D=4096 cuBLAS scales UP +24.6% (larger tiles / split-K /
  persistent rasterization tuned to 132 SMs) while the fixed MODE 8 scales DOWN −9.9% (2×
  K-loop drain). Register-spill, occupancy-drop, and a D-independent ptxas ceiling are all
  **statically EXCLUDED** as the cause; the surviving classification is (d) large-D
  scheduling roofline = *shape-rigid vs shape-adaptive*. (`F-OP45-ROUTEA-D4096-CAP`.)

> **RESOLVED (g5) — it is a FIXABLE stall, NOT a hard roofline.** The OP-45-GPU T1–T5 real
> H100 sm_90a sweep (`F-OP45GPU-OCCUPANCY-SWEEP`) settles the @D=4096 sub-parity: the own
> kernel sits at ~284 TFLOP/s while **DRAM is far below its HBM3 roofline (~12–40% of peak)**
> and the TF32 SM-math peak (~990 TFLOP/s) is ~3.5× above it. Register-spill and occupancy-drop
> are **measured-excluded** (96 KB/CTA, 2 CTA/SM, held at both D). The cap is **per-CTA
> Tensor-pipe issue / K-loop drain serialization — a fixable scheduling stall**, not a bandwidth
> wall. So @D=4096 sub-parity is closeable headroom (the shape-adaptive levers below), not a
> hard ceiling. (`F-OP45GPU-OCCUPANCY-SWEEP`.)

**The path forward — IF a beat is ever pursued** (not a standing goal): the shape-adaptive
selector design in `docs/forge-routea-shape-adaptive.md` (§2–§6) + its CPU cost model (which
reproduces the measured win-ordering at both D, mean |rel.err| 2.2%) + the **4 concrete
config gaps** (64×64 small-tile · MODE 7 persistent measured @4096 · bit-exact split-K ·
NST-adaptive launcher) are the levers. None exist in-tree today; each maps to a gated
GPU-session build (OP-45 T1–T5). (`F-OP49-SHAPE-ADAPTIVE-DESIGN`,
`docs/forge-routea-shape-adaptive.md`.)

**The VALUE proposition** is the same as the flame side: own-GEMM's worth is
**bit-exactness + device-residency + no-LLVM compile-theorem** — a device GEMM callable
in-line where a persistent megakernel can *never* call cuBLAS (a host API), end-to-end, with
no vendor call and a bit-exact gate. It is **NOT raw TFLOP/s-vs-cuBLAS**. Until a beat is
pursued, the boundary stands: **bit-exact parity @D=2048, not a beat, shape-rigid @D=4096.**

---

## 5. Provenance (every number traces to a verdict — g5)

- **`.verdicts/hexa-bench/F-BENCH-1.txt` — the SPEED AUTHORITY.** Fair, matched-dtype, batch-swept
  compiled-step comparison on a free RTX 5070: FP64 torch ÷ flame 0.83–1.10× (flame ties/wins),
  TF32 3.03–7.88×, FP32 2.15–6.60×. flame determinism `max|Δ|=0` at every cell. This is the table
  in §1.1 and supersedes the #2912 single-point as the current flame-vs-PyTorch speed number.
- `.verdicts/hexa-fusion/F-FUSION-VS-PYTORCH.txt` — **history (#2912), re-contextualized.** The
  full **interpreted** trainer at H100/FP64-vs-TF32/batch=1 (0.167 vs 276.7 vs 368.5 step/s;
  ~1656× / ~2207×). NOT the compiled-step gap — see §1.1a; BENCH-1 takes it to single-digit.
- `.verdicts/hexa-fusion/F-FUSION-BATCHFILL.txt` — flame batch self-speedup (1.504× @B=2 →
  2.954× @B=32, ~3× cap) + `F-FUSION-M5-BATCHFILL-UTIL.txt` (util duty-cycle floor).
- `.verdicts/hexa-0pod/F-GPU-ROUTEA-KEEPBAND-MEASURE.txt` — own-GEMM 1.08× parity @D=2048 /
  ~1.50× @D=4096, rel_rms 0.
- `.verdicts/hexa-0pod/F-OP45-ROUTEA-D4096-CAP.txt` — the @D=4096 (a)–(d) static cause
  decomposition; **resolved** by `.verdicts/hexa-0pod/F-OP45GPU-OCCUPANCY-SWEEP.txt` (real H100
  T1–T5: the @D=4096 sub-parity is a **fixable scheduling stall**, DRAM ~12–40% of HBM3 peak,
  NOT a hard roofline).
- `.verdicts/hexa-0pod/F-OP49-SHAPE-ADAPTIVE-DESIGN.txt` + `docs/forge-routea-shape-adaptive.md`
  — the shape-adaptive selector + §0 perf boundary.
- `.verdicts/hexa-0pod/F-OP20-TF32-FASTMODE.txt` — deterministic TF32 fast-mode (4.2× @B=1,
  D=1536) + `F-OP25-BF16-FASTMODE.txt` (BF16 Pareto-dominated).
- `docs/flame-machine-independent-training.md` + `docs/flame-determinism-contract.md` —
  the cross-machine bit-exact result (6 env / 4 arch-libc, no libm on the step path) and the
  contributor-facing per-phase determinism index + golden-fold CI tripwire.

## 6. Honest-number discipline — do not re-make the FP64-vs-TF32 trap (g5)

The ~1656× headline this document used to lead with was a textbook example of an
apples-to-oranges speed claim. To keep it from recurring, the rules for any flame-vs-PyTorch
speed number here:

1. **Match the dtype.** flame's bit-exact path runs **FP64**; torch's fast path runs **TF32**
   (tensor-core). FP64 has **no tensor-core path on NVIDIA**, so an FP64-flame-vs-TF32-torch
   ratio is **not a speed comparison** — it is a precision comparison wearing a speedometer.
   Compare FP64↔FP64, TF32↔TF32, FP32↔FP32 (that is exactly what BENCH-1 does).
2. **Measure the compiled step, not the interpreted full trainer.** The #2912 0.167 step/s was
   the **interpreted host glue** of the full trainer (per-step `t_get`/`t_set`, eager AdamW,
   CE glue), *not* the step kernels. Interpreter-elimination (#2915) confirmed the heavy ops are
   native-C builtins in both arms. Quote the **kernel-DAG** step rate (BENCH-1), not the glue.
3. **No 2-point extrapolation of a multi-second artifact.** A ~6 s/step figure for a tiny
   D=1536 model is a smell, not a number. Sweep real iters (BENCH-1 = 50 iters × 4 batches).
4. **Report the win honestly, with the right magnitude.** torch genuinely wins TF32/FP32 by
   **2–8×** (cuBLAS GEMM > naive tiled GEMM) — say so. Just never as 1656×.

Net: matched-dtype the gap is **single-digit** — FP64 flame ties/wins, TF32 torch 2–8×. The
1656× figure appears in this repo **only** as honestly-labeled history (#2912), never as the
headline.

---

**Governance:** logged-discovery consolidation only. Per project.tape **g84** (PAPER OPT-IN),
no `/paper` was scaffolded, no `PAPER.tape`/`PAPER.md` created, no paper skill invoked.
