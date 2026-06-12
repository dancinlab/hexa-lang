# flame + forge vs PyTorch + cuBLAS — an honest head-to-head

> **Read the TL;DR before quoting any number.** This is a *result* document, not a
> pitch. Every speed and correctness number below traces to a named verdict under
> `.verdicts/` (g5: verbatim evidence, no rounding-mangle, no invented benchmark).
> No `/paper` was scaffolded (project.tape **g84**, PAPER OPT-IN).

---

## TL;DR — flame + forge is SLOWER than PyTorch + cuBLAS, and wins on a different axis

flame + forge is **not** a speed competitor to PyTorch + cuBLAS. On **raw throughput
it is slower**:

- The **full training step** at production-proxy shape (CLMConvMoE, D=1536, batch=1, H100)
  runs at **0.167 step/s** vs PyTorch eager **276.7 step/s** and `torch.compile`
  **368.5 step/s** — i.e. **PyTorch is ~1656× (eager) / ~2207× (compile) FASTER**.
  (`F-FUSION-VS-PYTORCH`.)
- The hexa-owned **own-GEMM** reaches **parity, not a beat**: ~1.08× of cuBLAS-TF32
  @ D=2048 (bit-exact), and **~1.5× slower** @ D=4096. (`F-GPU-ROUTEA-KEEPBAND-MEASURE`.)

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

## 1. Speed — PyTorch + cuBLAS wins (verbatim, with sources)

### 1.1 Full training step (the headline gap)

CLMConvMoE, identical shape D=1536 / T=512 / E=2 / K=3 / batch=1, on one idle **H100 80GB
SXM**. flame runs FP64 cuBLAS; torch runs TF32 (the dtype gap favors torch on GEMM but
accounts for **< 2×** of the gap below — the dominant term is flame's interpreted per-step
host glue, not GEMM precision). (`F-FUSION-VS-PYTORCH`.)

```
  runner            dtype   ms/step    step/s      vs flame
  --------------    -----   --------   --------     ------------------
  flame (hexa)      FP64    5980.      0.167        1.00× (baseline)
  torch eager       TF32       3.61   276.673       ~1656× FASTER
  torch.compile     TF32       2.71   368.538       ~2207× FASTER
```

- `flame / torch_eager   = 0.167 / 276.673 = 0.00060×`  → torch eager   **1656× faster**
- `flame / torch_compile = 0.167 / 368.538 = 0.00045×`  → torch.compile **2207× faster**

The wall is **not** raw GEMM and **not** kernel fusion. During flame's GEMM bursts the
GPU peaks 100% — flame's own GEMM is GPU-resident and ≈cuBLAS-class **when it runs**. The
5.98 s/step is dominated by the GPU sitting at **0% between GEMMs**: host-side serial
interpreted glue (per-window `t_get`/`t_set` token copy, ~28-call eager AdamW tail,
CE/softmax-grad host glue). Sibling probes confirm fusion is exhausted: CUDA-graph
capture/replay ~1.0× and fwd+bwd fusion ~1.0×, both closed-negative. (`F-FUSION-VS-PYTORCH`.)

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
| Maximum TFLOP/s, production throughput, large-batch training | **PyTorch + cuBLAS** — it is ~1656–2207× faster per step at batch=1, and cuBLAS is the GEMM roofline |
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

> **In flight, NOT resolved (g5):** whether the @D=4096 sub-parity is a **hard HBM-bandwidth
> roofline** (no scheduling can beat it) or a **fixable scheduling / drain stall** is *pending
> the OP-45-GPU T2 ncu profile* (achieved DRAM % of HBM3 peak + Tensor-pipe active %). The
> static analysis classifies the cause as (d)-class shape-rigidity but cannot split that
> sub-cause without a real GPU profile. Do not claim the split is settled.

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

- `.verdicts/hexa-fusion/F-FUSION-VS-PYTORCH.txt` — full-step flame vs torch eager / compile
  (0.167 vs 276.7 vs 368.5 step/s; ~1656× / ~2207× faster).
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
