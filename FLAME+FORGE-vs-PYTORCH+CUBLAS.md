# flame + forge vs PyTorch + cuBLAS — an honest head-to-head

> **Read the TL;DR before quoting any number.** This is a *result* document, not a
> pitch. Every speed and correctness number below traces to a named verdict under
> `.verdicts/` (g5: verbatim evidence, no rounding-mangle, no invented benchmark).
> No `/paper` was scaffolded (project.tape **g84**, PAPER OPT-IN).

---

## TL;DR — flame + forge is NOT 3 orders behind PyTorch + cuBLAS; matched-dtype the gap is single-digit, and it wins on a different axis

**flame + forge is NOT three-orders-of-magnitude behind PyTorch + cuBLAS.** Measuring the
**compiled** training step at **matched dtype** (interpreter eliminated — the fair comparison,
`F-BENCH-1`, RTX 5070), the step gap is **SINGLE-DIGIT**:

- **FP64: flame TIES/WINS.** flame ÷ best-torch = 0.90–1.10×: B=1 1.10× (torch edges via
  `torch.compile`), **B=2 0.98× (flame ties)**, **B=4 0.93× and B=8 0.90× (flame WINS)** —
  flame even posts the **highest FP64 throughput** at B=8 (826 vs 745 samp/s). torch has no
  tensor-core FP64 path; flame's hand-fused deterministic FP64 step is genuinely competitive.
- **TF32: torch leads 3.03× (B=1) → 7.88× (B=8)** — its cuBLAS/inductor-tuned GEMM beats
  flame's naive tiled CUDA-core GEMM. (FP32: 2.15× → 6.60×.) A torch win at TF32 is expected.
- The hexa-owned **own-GEMM** reaches **parity, not a beat**: ~1.08× of cuBLAS-TF32
  @ D=2048 (bit-exact), and **~1.5× slower** @ D=4096. (`F-GPU-ROUTEA-KEEPBAND-MEASURE`.)

> ⚠ The old **~1656× / ~2207×** headline was **misleading** and is **retired**: it compared
> flame **FP64** to torch **TF32** (an unfair dtype mismatch) on the **interpreted** full
> trainer at **batch=1**, via a 2-point linear extrapolation of a ~6-second/step glue
> artifact — NOT the compute gap. See the §1 callout. The fair matched-dtype number is
> single-digit (FP64 flame ties/wins, TF32 torch 2–8×).

It competes on a **different axis** entirely:

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

## 1. Speed — matched-dtype the gap is single-digit (verbatim, with sources)

### 1.1 Full training step — matched-dtype, COMPILED (the FAIR headline) — `F-BENCH-1`

This is the **authoritative** speed number: same step DAG both sides (fwd GEMM → groupnorm +
tanh-gelu → bwd GEMM → AdamW), **matched dtype**, **compiled** (interpreter eliminated), batch
swept B=1,2,4,8, on a **free** RTX 5070 (aiden pool, $0, no vast). flame is byte-exact
run-to-run (`max|Δ|=0` at every cell); torch is tolerance-based. ratio = torch ÷ flame
(`>1` = torch faster; `<1` = **flame faster**). (`F-BENCH-1`.)

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
   FP32  8 |     470.86   | 2089.92  (4.44×)    | 3106.77  (6.60×)      |  6.60×
```

**Matched-dtype, the apparent ~1656× collapses to single digits — ~1× (FP64) to ~8× (TF32 B=8):**

- **FP64 — flame ties/wins.** flame ÷ best-torch = 0.90–1.10×: ties at B=2, **wins at B=4 and
  B=8**, and posts the **highest FP64 throughput** at B=8 (826 vs 745 samp/s). torch has no
  tensor-core FP64 path; flame's hand-fused deterministic FP64 step is on par or faster.
- **TF32 — torch leads 3.03× (B=1) → 7.88× (B=8); FP32 — 2.15× → 6.60×.** This residual is
  cuBLAS/inductor's tuned GEMM vs flame's **naive tiled CUDA-core GEMM** (NOT interpreter glue —
  that is eliminated here by measuring the kernel directly). A large torch win at TF32 is
  EXPECTED and fine; its absolute TF32 throughput (up to 29.7k samp/s @ B=8) dwarfs flame's.

The regime where flame is least-far-behind (in fact ahead) is **FP64, B≥2** — exactly the
precision torch cannot tensor-core-accelerate, and exactly where flame's bit-exact step matters.

> ### ⚠ Why the OLD ~1656× / ~2207× headline was MISLEADING (retired)
>
> A prior figure (`F-FUSION-VS-PYTORCH`, #2912) reported flame **0.167 step/s** vs torch eager
> **276.7** / `torch.compile` **368.5** on an H100 (D=1536, batch=1) — i.e. "**~1656× / ~2207×
> FASTER**". That number is misleading for **three** compounding reasons and must NOT be quoted
> as the current compute gap:
>
> 1. **Unfair dtype** — it compared flame **FP64** to torch **TF32** (torch on a tensor-core
>    GEMM path flame's FP64 cannot use). Matched-dtype (`F-BENCH-1`) the FP64 gap is **~1×**.
> 2. **Interpreted, not compiled** — the 5.98 s/step was the **interpreted** full-trainer's
>    per-step host glue (per-window `t_get`/`t_set` token copy, ~28-call eager AdamW tail,
>    CE/softmax-grad host glue) with the GPU at 0% between GEMMs — NOT the step kernels. The
>    `F-FUSION-INTERP-ELIM` probe later showed AOT-compiling that glue is ~1.0× (the bytecode
>    interpreter was never the wall), and `F-BENCH-1` measures the compiled step directly.
> 3. **2-point extrapolation** — the 0.167 step/s was a 2-point linear extrapolation of that
>    ~6-second/step artifact, not a measured throughput curve.
>
> The fair, matched-dtype, compiled number (`F-BENCH-1`) is **single-digit**: FP64 flame
> ties/wins, TF32 torch 2–8×. Use that.

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
| Maximum TFLOP/s, production throughput, large-batch training | **PyTorch + cuBLAS** — matched-dtype it is **2–8× faster at TF32** (cuBLAS GEMM is the roofline); at **FP64 flame ties/wins**, but torch's TF32 throughput dwarfs FP64 |
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

> **SETTLED (g5) — the @D=4096 gap is BIT-EXACTNESS-BOUND; the T4 lever family is exhausted
> closed-negative.** The OP-45-GPU sweep first scoped the cap: the own kernel runs at **~12–40%
> of HBM3 peak** with arithmetic intensity **682 FLOP/byte ≫ the 104 FLOP/byte compute-bound
> threshold**, so it is **COMPUTE/SCHEDULING-bound, NOT DRAM-bandwidth-bound** (ncu was infra-
> blocked on the profiling-admin-locked pod; resolved via a g5-legal analytical roofline). cuBLAS's
> +24.6% large-D lever is a **better single-pass tile + CTA-swizzle, `split_k=1` (NOT split-K)** —
> bit-exact-reachable in principle. **Two GPU builds then exhausted that lever:** (1) **CTA-swizzle
> in isolation** (MODE 9, non-persistent) **REGRESSES** — best bit-exact swizzled 280.5 vs the
> SWZ=0 baseline 285.1 TFLOP/s, −1.6%, ratio 1.50× → 1.53× (`F-OP52-TF32-GAP-CLOSE`); this also
> isolates T3's MODE 7 @4096 regress to the *swizzle*, not the persistent loop. (2) The **NEW
> 2-CTA/SM-preserving 128×256 tile** (MODE 10 t256e, register-feasible at 90 regs / 2 CTA/SM ==
> MODE 8) **REGRESSES −7.1%** (263.3 vs 283.5 TFLOP/s, ratio 1.51× → 1.64×): the sequential-halves
> schedule serializes the wgmma pipeline (ptxas C7515) + doubles the K-drain (`F-OP55-NEWTILE-D4096`).
> MODE 5 t256 (the only in-tree larger single-pass tile) and MODE 7 persistent were already
> closed-neg @4096. **No bit-exact 256-N schedule on sm_90a is BOTH 2 CTA/SM AND non-serialized —
> the @D=4096 own-GEMM TF32 gap is bit-exactness-bound. own-GEMM = bit-exact-PARITY-not-BEAT
> @D=4096 is the honest, settled final answer**, not a recoverable scheduling problem.
> (`F-OP45GPU-OCCUPANCY-SWEEP`, `F-OP52-TF32-GAP-CLOSE`, `F-OP55-NEWTILE-D4096`.)

**Consumer-card sibling — own-GEMM EDGES cuBLAS @D=768 (a DIFFERENT kernel, different roofline).**
The RTX 5070 (sm_120) ISA does **not** carry wgmma; the consumer card runs the **OWN120**
`mma.sync.m16n8k8.tf32` warp-MMA own-GEMM (64×64 tile). On summer's FREE RTX 5070 the **tuned**
OWN120 lands at **median 0.95×–1.47× off cuBLAS-TF32 across D=512..2048 — own EDGES cuBLAS at the
mid shape D=768 (0.95×, bit-exact-tolerant rel-RMS ~1.3e-5)** with D=2048 also near-parity (0.96×),
**closing the original F-BENCH-5 3.2–6.9× raw gap**. The 64×64 is the consumer optimum — shrinking
to 32×32 is strictly worse at every small-D (`F-OP54-SUMMER-OWNGEMM-TF32`, `F-OP57-SUMMER-SMALLTILE`).

**The path forward — IF a beat is ever pursued** (not a standing goal): the shape-adaptive
selector design in `docs/forge-routea-shape-adaptive.md` (§2–§6) + its CPU cost model (which
reproduces the measured win-ordering at both D) is the harness. But the @D=4096 large-D lever is
now MEASURED-exhausted bit-exact (above); the only remaining cost-model-tractable gap is the
small-D 64×64 under-fill tile (Hopper-only — wgmma; the sm_120 32×32 proxy showed the more-CTA
lever does *not* help an already-small-tile consumer kernel). (`F-OP49-SHAPE-ADAPTIVE-DESIGN`,
`docs/forge-routea-shape-adaptive.md` — see its **own-GEMM parity map** for the one-screen picture.)

**The VALUE proposition** is the same as the flame side: own-GEMM's worth is
**bit-exactness + device-residency + no-LLVM compile-theorem** — a device GEMM callable
in-line where a persistent megakernel can *never* call cuBLAS (a host API), end-to-end, with
no vendor call and a bit-exact gate. It is **NOT raw TFLOP/s-vs-cuBLAS**. The boundary is
SETTLED: **parity @Hopper-D2048 (1.08×, bit-exact) · own-edges-cuBLAS @consumer-D768 (0.95×) ·
parity-not-beat @Hopper-large-D (~1.50× @D=4096, bit-exactness-bound).**

### 4.1 The parity result is DTYPE-SCOPED to TF32 — FP16/BF16 own-GEMM is NOT parity (honest)

Everything above is the **TF32** own-GEMM. The own-GEMM parity claim (1.08× @D=2048, bit-exact)
is **dtype-scoped to TF32** — it does **NOT** hold for FP16/BF16, where cuBLAS's tensor-core
FP16 path is far ahead. The campaign also ported the same composed-decode own-GEMM to 16-bit
operands (W14, the re-derived 8×8 / 128 B f16 GMMA core), and the honest result is **PARITY=NO**:

| dtype | own-GEMM | cuBLAS roofline | ratio | gate | parity | verdict |
|-------|----------|-----------------|-------|------|--------|---------|
| **TF32** (W10, pre-route-(a) summit) | 70.7 TFLOP/s @4096 | cuBLAS-TF32 430.8 | **6.09× off** | `rel_rms 0` bit-exact-vs-FP64 | NO at W10; route-(a) reaches **1.08× @D=2048** (the headline) | `F-FUSION-SM90-WGMMA-W10` |
| **FP16** (W14) | **71.6 TFLOP/s @4096** | cuBLAS-FP16 **827.2** | **11.55× off** | `rel_rms ≤ 1e-2` vs **same-dtype** cuBLAS-FP16 (measured 0.000e+00); **NOT** bit-exact-vs-FP64 | **NO** | `F-FUSION-SM90-WGMMA-W14-FP16` |
| **BF16** (W14) | 71.1 TFLOP/s @4096 | cuBLAS-BF16 816.1 | 11.48× off | `rel_rms ≤ 1e-2` vs same-dtype cuBLAS-BF16 (measured 0) | NO | `F-FUSION-SM90-WGMMA-W14-FP16` |

The FP16/BF16 own kernel runs at the **same absolute throughput** as the TF32 kernel (~71–76
TFLOP/s — the same decode/occupancy-bound design) — but the **cuBLAS-FP16 roofline DOUBLED**
(827 vs cuBLAS-TF32 431 @4096), so the precision change moved the roofline 2× *away* without
lifting the own kernel and the same-dtype ratio **WIDENED** (6.09× → 11.5×); it did not close.
Two further honesty notes traced to the W14 verdict: (1) the gate is **NOT bit-exact-vs-FP64** —
a 16-bit-operand + f32-accumulate wgmma is a genuinely different numeric, so the W14 gate is a
precision-appropriate `rel_rms ≤ 1e-2` vs a *same-dtype* cuBLAS-FP16/BF16 oracle (it happened to
measure 0.000e+00, better than the gate required, but the **gate stays the 1e-2 same-dtype
tolerance**); (2) the W13 "a 16-bit gmma band is 16 KB → 2 bands fit → reopen the overlap" thesis
is **deterministically REFUTED** for `.k16` (the band stays 32 KB, same as TF32 — a closed-negative).

> **The honest one-liner (g5):** own-GEMM reaches **bit-exact PARITY with cuBLAS in TF32**
> (1.08× @D=2048); in **FP16/BF16 it is correct (`rel_rms ≤ 1e-2`, same-dtype) but NOT parity
> (11.5× off cuBLAS-FP16)** — the **parity result is dtype-scoped to TF32.** Presenting
> "own-GEMM ≈ cuBLAS parity" without the dtype qualifier would overstate the claim (the same
> honest-number failure class as the retired ~1656× figure). cuBLAS = roofline throughout, no
> superiority claim. (`F-FUSION-SM90-WGMMA-W14-FP16`, `F-FUSION-SM90-WGMMA-W10`.)

---

## honest-number discipline — ALWAYS compare matched-dtype

The misleading ~1656× headline was born from a **dtype mismatch**: flame **FP64** vs torch
**TF32**. The discipline that prevents this recurring:

1. **Match the dtype on both sides.** FP64-vs-TF32 is not a speed comparison — torch's TF32
   runs on a tensor-core GEMM path flame's FP64 cannot use. Compare FP64-vs-FP64, TF32-vs-TF32.
   At matched dtype the gap is single-digit (FP64 flame ties/wins, TF32 torch 2–8×).
2. **Measure the compiled step, not the interpreted trainer.** The old number was the
   interpreted full-trainer's host glue with the GPU at 0% between GEMMs — not the step kernels.
   Eliminate the interpreter (or measure the kernel directly) before quoting a gap.
3. **Use a measured curve, not a 2-point extrapolation.** The 0.167 step/s was extrapolated
   from a ~6-second/step artifact; `F-BENCH-1` sweeps B=1,2,4,8 with verbatim per-cell numbers.

When in doubt, quote `F-BENCH-1` (matched-dtype, compiled, batch-swept). The FP64-vs-TF32 trap
is exactly what produced the misleading 1656×; do not reintroduce it.

---

## 5. Provenance (every number traces to a verdict — g5)

- `.verdicts/hexa-bench/F-BENCH-1.txt` — **THE speed authority**: matched-dtype, compiled,
  batch-swept step (RTX 5070). FP64 flame ties/wins (B=2 0.98×, B=4/8 flame faster); TF32 torch
  3.03× (B=1) → 7.88× (B=8); FP32 2.15× → 6.60×. Re-contextualizes the old ~1656× to single-digit.
- `.verdicts/hexa-fusion/F-FUSION-VS-PYTORCH.txt` — the OLD (retired-as-headline) full-step
  measurement: flame **FP64** 0.167 vs torch **TF32** 276.7 / 368.5 step/s (the ~1656× / ~2207×
  figure). MISLEADING as a current gap — unfair dtype + interpreted glue + 2-point extrapolation;
  superseded by `F-BENCH-1`. Kept only as the provenance of the figure being corrected.
- `.verdicts/hexa-0pod/F-OP45GPU-OCCUPANCY-SWEEP.txt` — resolves the @D=4096 own-GEMM sub-parity
  as a FIXABLE compute/scheduling stall (DRAM ~12–40% HBM3 peak, AI 682 ≫ 104), NOT a hard roofline.
- `.verdicts/hexa-fusion/F-FUSION-BATCHFILL.txt` — flame batch self-speedup (1.504× @B=2 →
  2.954× @B=32, ~3× cap) + `F-FUSION-M5-BATCHFILL-UTIL.txt` (util duty-cycle floor).
- `.verdicts/hexa-0pod/F-GPU-ROUTEA-KEEPBAND-MEASURE.txt` — own-GEMM 1.08× parity @D=2048 /
  ~1.50× @D=4096, rel_rms 0.
- `.verdicts/hexa-0pod/F-OP45-ROUTEA-D4096-CAP.txt` — the @D=4096 (a)–(d) cause decomposition
  + the in-flight T1–T5 ncu handoff.
- `.verdicts/hexa-0pod/F-OP49-SHAPE-ADAPTIVE-DESIGN.txt` + `docs/forge-routea-shape-adaptive.md`
  — the shape-adaptive selector + §0 perf boundary.
- `.verdicts/hexa-0pod/F-OP20-TF32-FASTMODE.txt` — deterministic TF32 fast-mode (4.2× @B=1,
  D=1536) + `F-OP25-BF16-FASTMODE.txt` (BF16 Pareto-dominated).
- `docs/flame-machine-independent-training.md` + `docs/flame-determinism-contract.md` —
  the cross-machine bit-exact result (6 env / 4 arch-libc, no libm on the step path) and the
  contributor-facing per-phase determinism index + golden-fold CI tripwire.

**Governance:** logged-discovery consolidation only. Per project.tape **g84** (PAPER OPT-IN),
no `/paper` was scaffolded, no `PAPER.tape`/`PAPER.md` created, no paper skill invoked.
