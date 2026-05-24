# RFC 072 — flame d=4096 GPT-3 class benchmark (Shape-B scaffold)

**Status**: P0 ✅ + P1 ✅ (PyTorch eager PROXY baseline measured on RTX 5070);
P1-full + P2 + P3 + P4 multi-session pending.
**Branch**: `rfc072-flame-d4096-scaffold` (P0 scaffold, PR #227 `0b29e340`) ·
`rfc072-p1-torch-d2048-proxy` (P1 PROXY measurement, this cycle).
**Date**: 2026-05-20.
**Authority**: @D g3 (honest scope), @D g5 (hexa-native-only), @D g6
(citation-enforced), @D g_plan_consolidation (stdlib/flame exception clause),
@D g_inbox_processing_loop Shape-B (RFC + scaffold; zero behavior change).
**Companion**: GPU.md §10 closure-criterion row "flame d=4096 GPT-3 class beats
PyTorch eager" (still `[ ]` — this RFC pre-registers the gate).

---

## §1 Background

`memory project_flame_phase4d9_closure` recorded the d=768·12L closure on
2026-05-18 (commit `28e9d648`, branch `rfc043-flame-camp`):

- d=768·12L 1-step wall: hexa-emit **191–268 s** vs PyTorch-eager **336.85 s**
  = **20–43 % faster** (F-RFC046-WALL PASS).
- Total spend: **$1.7** (vs prior $2.5 blind 15-fire stranded).
- Acceptance: g3-honest, no over-claim — single shape, hexa CPU-equiv
  anchored, GPU substrate via Phase 4-D dispatch.

`memory project_flame_general_pytorch_replacement_goal` (2026-05-18) records
the user north-star: **flame as general PyTorch replacement**. d=768 closure
is the *seed*; the north-star path is "d=768 single-shape closure → arbitrary
model shape sweep". RFC 072 is the first **GPT-3 class** shape on that path.

GPU.md §10 closure scoreboard (6/8 ✅ as of 2026-05-20) lists three remaining
multi-session campaigns. **flame d=4096 GPT-3 class beats PyTorch eager** is
one of them; this RFC formalizes its spec + harness so the measurement campaign
has explicit pre-registered gates rather than ad-hoc fires.

---

## §2 Spec — model shape

**Decision (justified below)**: target d_model = **4096**, n_layer = **24**,
seq_len = **2048**, batch = **8** (gradient accumulation to effective
batch = 512 if memory-bound).

**Justification** (g4 cross-language honesty — Brown et al. 2020 "Language
Models are Few-Shot Learners", Table 2.1):

| GPT-3 family member | d_model | n_layer | n_head | d_head | params |
|---------------------|--------:|--------:|-------:|-------:|-------:|
| GPT-3 Small         |     768 |      12 |     12 |     64 |   125 M |
| GPT-3 Medium        |    1024 |      24 |     16 |     64 |   350 M |
| GPT-3 Large         |    1536 |      24 |     16 |     96 |   760 M |
| GPT-3 XL            |    2048 |      24 |     24 |    128 |  1.3 B |
| GPT-3 2.7B          |    2560 |      32 |     32 |     80 |  2.7 B |
| GPT-3 6.7B          |    4096 |      32 |     32 |    128 |  6.7 B |
| GPT-3 13B           |    5120 |      40 |     40 |    128 | 13.0 B |
| GPT-3 175B          |   12288 |      96 |     96 |    128 |  175 B |

RFC 072 picks **d=4096, n_layer=24** — d=4096 matches GPT-3 6.7B's `d_model`
(the published target "GPT-3 class" floor), but with n_layer = 24 (not 32)
to keep the single-GPU memory footprint within the consumer envelope
(RTX 5070, gradient checkpoint) for a $1–5 single-fire. Honest framing
(g3): this is **GPT-3-class** by `d_model` axis, **not** an exact GPT-3
6.7B parameter-count reproduction. The d_model axis is the load-bearing
scale parameter for matmul intensity — which is what flame-vs-PyTorch
wall measurement actually tests.

**Precision modes**:

- **FP32 baseline** (correctness anchor; byte-eq against analytic ref where
  feasible).
- **FP16 mixed** (master FP32 weights + FP16 forward + loss-scaled bwd) —
  the realistic LLM training precision and where Tensor-Core throughput
  matters; comparison target for the wall measurement.

**Batch sizing**:

- Logical batch = 8 (fits single GPU); effective batch = 512 via grad-accum
  if needed to match published GPT-3 training-step semantics. F-RFC072-RATIO
  measures per-step wall at fixed micro-batch; effective-batch is
  presentation-only (g3 — does not affect the comparison).

---

## §3 Harness

**Scaffold file** (P0): `stdlib/flame/bench/d4096.hexa` — stub
function `pub fn bench_d4096_step1_wall(precision: string) -> f64` returning
0.0 with TODO P1+ markers. Shape constants as `let`-bindings at module
scope.

**Imports** (P1+, not P0): the harness will `use stdlib/flame/{tensor_lib,
decoder_lib, decoder_block_lib, nn_lib, train_lib}` mirroring the d=768·12L
fire scaffold pattern (`flame_d768_12L_agtape_fire.hexa`). P0 leaves these
as commented TODO markers — actual wiring lands in P1.

**Driver path** (P2+): the existing `flame_d128_2L_smoke_test.hexa` +
`flame_d768_12L_agtape_fire.hexa` patterns are the reference — entrypoint
.hexa file that imports the libs, builds the model, runs 1 (or N) train
step(s), prints wall.

**Measurement protocol** (P3):

1. Warmup: 1 forward + bwd, discard.
2. ≥ 3 timed steps (full fwd + bwd + AdamW).
3. Report per-step wall (median of 3+); std must be < 5 % (F-RFC072-VARIANCE).
4. Same protocol for PyTorch eager baseline on the same hardware.

### §3.P1 — PyTorch eager PROXY baseline MEASURED (2026-05-20)

**Fire**: `archive/fires/rfc072_p1_torch_d2048_proxy_2026_05_20/`
(`result.json` + `fire.log`). **Tool**:
`tool/r072_p1_torch_eager_d2048_proxy.py` (~250 lines pure PyTorch eager
with a 5-rung ladder fallback for OOM-on-12GB).

**Hardware constraint discovered**: RTX 5070 12GB (the $0 ubu-2 pool host)
**cannot fit** any d=2048 12L FP32 transformer-block + Adam config — even
**d=2048 n_layer=12 batch=1 seq=512** OOMs on PyTorch eager. Root cause:
50,257-token embed + LM head with d=2048 alone weighs ~0.82 GiB FP32 per
matrix · ×2 (embed + head) = ~1.64 GiB · ×3 (param + Adam m + Adam v) =
~5 GiB of fixed overhead before any attention/FFN activation appears.
At d=2048 12L the attention/FFN/grad/Adam state for even batch=1 seq=512
exhausts the remaining ~6 GiB.

**Ladder chosen rung**: **L4 — d=1024 n_layer=12 batch=2 seq=512 FP32**.

**Measured 1-step wall** (5 timed steps after 3 warmup, `torch.cuda.Event`
+ `synchronize()`):

| Step | Wall (ms) |
|------|----------:|
| 1    | 116.366   |
| 2    | 116.286   |
| 3    | 116.329   |
| 4    | 116.215   |
| 5    | 116.105   |

- **Median**: **116.286 ms**
- **Mean**: 116.260 ms
- **Std**: 0.104 ms (**0.089 %** of median — well within F-RFC072-VARIANCE
  std < 5 % gate)
- **Min/Max**: 116.105 / 116.366 ms
- **Peak VRAM**: **5,059.8 MiB**
- **Host**: `summer-B650M-K` · RTX 5070 sm_120 · torch 2.11.0+cu130 · CUDA 13.0
- **Verdict**: `PASS_PROXY` (variance gate PASS)

**Falsifier mapping** (g3 honest — these are proxy-scoped gates, NOT the
full-spec gates from §4):

| ID                          | Status      | Notes |
|-----------------------------|-------------|-------|
| **F-RFC072-WALL-PT-PROXY**  | **MEASURED** | d=1024 12L batch=2 seq=512 median wall = 116.286 ms (std 0.089 %) |
| **F-RFC072-VARIANCE-PROXY** | **PASS**     | std 0.104 ms = 0.089 % of median (< 5 % gate) |
| **F-RFC072-WALL-PT-FULL**   | **DEFERRED** | d=4096 24L batch=8 seq=2048 needs H100 80GB; ~$5+ multi-session |
| **F-RFC072-WALL-FLAME**     | **DEFERRED** | flame side P2; needs RFC 067 multi-tile cp.async integration question first |
| **F-RFC072-RATIO**          | **DEFERRED** | both arms required at the same shape; PROXY datum cannot close the d=4096 gate |

**Honest scope (g3)**:

- This is a **PROXY** measurement at d=1024 12L (one quarter the d-axis
  of the §2 spec; one quarter the seq; one quarter the batch). The
  PyTorch eager wall trajectory at this rung is **not interpolatable to
  d=4096** — matmul compute scales as O(d²) for FFN and O(d² · seq) for
  attention, so the d=4096/d=1024 wall ratio depends on memory-bandwidth
  vs compute regime crossover that is itself hardware-dependent.
- The d=4096 full-spec closure (GPU.md §10 row) stays `[ ]` — this P1
  result does **not** flip it. What this measurement provides:
  - An honest baseline data point for the d=1024 trajectory (cross-link
    to memory `project_flame_phase4d9_closure` which has the d=768 hexa
    arm).
  - Hardware-fit evidence: **RTX 5070 12GB is too small for the §2
    spec on either arm**; the full campaign must escalate to H100 80GB.
- F-RFC072-RATIO-PROXY can be computed *if* P2 measures the flame arm
  at the **same L4 config** (d=1024 12L batch=2 seq=512); that would
  be a useful smaller-scale honest comparison even though it doesn't
  close the d=4096 row.

---

## §4 Falsifier battery

Pre-registered gates (g3 — must measure, not assume):

| ID                       | Gate                                              | Method |
|--------------------------|---------------------------------------------------|--------|
| **F-RFC072-WALL-PT**     | PyTorch eager 1-step wall MEASURED (not estimated)| run torch baseline on same GPU; record median of ≥ 3 steps |
| **F-RFC072-WALL-FLAME**  | flame d=4096 1-step wall MEASURED                 | run `bench_d4096_step1_wall("fp32")` + `("fp16")`; record median of ≥ 3 steps |
| **F-RFC072-RATIO**       | flame / PyTorch wall **ratio < 1.0**              | both medians collected; ratio computed; closure if `< 1.0` (flame faster) |
| **F-RFC072-VARIANCE**    | std across ≥ 3 runs **< 5 %** of median           | per-side variance — gates the ratio's statistical validity |

**Honest negative outcomes are valid** (g3): if F-RFC072-RATIO yields
ratio ≥ 1.0, the measurement is published as a falsified gate and the
campaign records what optimization (shape-sweep cp.async, RFC 067 wmma
multi-tile integration, fusion gap, …) blocks closure. No "ratio = 0.9X"
rounding to claim PASS.

**Excluded**:

- Convergence (loss curve) — pre-existing F-RFC043-* gates already cover
  correctness; RFC 072 measures wall, not loss. Re-running convergence at
  d=4096 is a separate cycle (memory `project_flame_general_pytorch_replacement_goal`
  gap (a)).
- Memory peak — useful diagnostic but not a closure gate. Recorded as
  metadata.

---

## §5 Honest scope (g3)

**This is a multi-session campaign because**:

1. **PyTorch eager baseline needs careful setup** — d=4096 single-GPU may
   need gradient checkpointing; the baseline must use the same checkpointing
   so the comparison is apples-to-apples. PyTorch defaults vary by version;
   pinning torch version + recording exact eager configuration is a P1
   sub-task before the first measurement.
2. **flame d=4096 may need RFC 067 multi-tile cp.async integration not
   yet integrated** (GPU.md §5m note: "Multi-tile cp.async (PR #207) not
   yet integrated into this perf kernel — natural next-cycle"). At d=768
   the existing single-tile path won the wall comparison; at d=4096 the
   matmul shape moves into the regime where cuBLAS's k-loop unroll + ILP +
   shared-memory pipelining are at peak — flame may need the cp.async
   integration to compete. If RFC 067 P4-silicon-side integration is not
   yet shipped, that itself is a sub-cycle blocker for RFC 072.
3. **Variance gate needs ≥ 3 fires per arm** — minimum 6 measured runs
   (3 flame + 3 PyTorch); cost-bearing on consumer GPU (RTX 5070, ~$0
   on ubu-2 pool per `reference_gpu_fire_infra` memory; vast.ai backstop
   ~$1–5 per multi-hour large-model run).
4. **Cost envelope** — single full-run estimate $1–5 single-fire on
   consumer GPU; multi-session campaign aggregate likely $5–20 across
   debugging + measurement + variance.

**What this RFC explicitly does NOT claim**:

- It does NOT claim flame beats PyTorch at d=4096 — that's what the
  campaign measures. P0 is scaffold + gate registration only.
- It does NOT claim d=4096 = GPT-3 6.7B (params differ from n_layer = 24 vs
  32; vocab + sequence-length conventions also vary). It claims d=4096
  = GPT-3 6.7B's `d_model` axis (the load-bearing scale parameter for
  matmul intensity).
- It does NOT close the GPU.md §10 row "flame d=4096 GPT-3 class beats
  PyTorch eager" — that row stays `[ ]` until F-RFC072-RATIO measures
  ratio < 1.0 with F-RFC072-VARIANCE std < 5 %.
- It does NOT block on RFC 067 P4-silicon-side integration — if the
  campaign discovers that integration is required, it becomes a P2
  sub-task and a separate (already drafted) RFC.

---

## §6 Cross-links

- **GPU.md §5m** — measured wins ledger (d=768 entry); RFC 072 will append
  d=4096 result row when F-RFC072-RATIO is measured.
- **GPU.md §10** — closure criterion row "flame d=4096 GPT-3 class beats
  PyTorch eager" (still `[ ]`); P0 scaffold cross-link annotation added in
  this RFC's deliverable (4).
- **GPU.md §13 Next-layer-recommended** — RFC 072 is one of the 3 listed
  multi-session campaigns; this RFC formalizes it.
- **north-star ①** (NN stack) — RFC 072 directly serves; ② (self-host)
  and ③ (n=6 lattice) are orthogonal.
- **memory `project_flame_phase4d9_closure`** — d=768 seed measurement
  this RFC scales from.
- **memory `project_flame_general_pytorch_replacement_goal`** — user
  north-star this RFC's d=4096 milestone serves.
- **memory `reference_gpu_fire_infra`** — RTX 5070 ubu-2 substrate is the
  $0 fire path (vast.ai backstop only if ubu-2 unavailable or memory
  exceeds 5070 envelope).
- **memory `feedback_instrument_first_methodology`** — 4-rule methodology
  applies (unified scalar ban · cheap-first oracle · faithful pre-prediction
  · g3 over-claim 0).
- **memory `feedback_flame_transcendental_byteeq_hazard`** — FP32 byte-eq
  oracle hazards apply (FP_CONTRACT OFF on CPU; `--fmad=false` on GPU);
  P0 acknowledges, P1 sub-cycle re-validates.

---

## §7 Phasing

| Phase | Scope                                                              | Cost     | Closure gate                            |
|-------|--------------------------------------------------------------------|----------|------------------------------------------|
| **P0**| RFC + scaffold — parse-clean stub, no behavior change              | $0 ✅    | RFC filed, scaffold parses, GPU.md xref (LANDED PR #227 `0b29e340`) |
| **P1**| PyTorch eager PROXY baseline on $0 consumer GPU                    | $0 ✅    | F-RFC072-WALL-PT-PROXY MEASURED on RTX 5070 (this cycle) — see §3.P1 |
| **P1-full** | PyTorch eager baseline at d=4096 24L full spec                | $1–3     | F-RFC072-WALL-PT-FULL MEASURED on H100 80GB (deferred — multi-session) |
| **P2**| flame d=4096 1-step fire (FP32 first, FP16 second)                 | $1–3     | F-RFC072-WALL-FLAME measured             |
| **P3**| flame d=4096 PROXY (d=1024 12L if doing same-shape PT compare)     | $0       | F-RFC072-RATIO-PROXY at L4 rung (optional smaller-scale parity)     |
| **P4**| Variance + ratio + closure verdict at full d=4096 spec             | $1–5     | F-RFC072-RATIO + F-RFC072-VARIANCE       |

**Termination conditions**:

- **Honest PASS**: F-RFC072-RATIO < 1.0 with F-RFC072-VARIANCE < 5 % →
  GPU.md §10 row flips `[ ]` → `[x]`; §5m gets d=4096 entry; memory
  `project_flame_general_pytorch_replacement_goal` `gap` axis updated.
- **Honest FAIL**: ratio ≥ 1.0 → published as falsified gate; root-cause
  cycle (RFC 067 integration · fusion gap · cuBLAS-stack-floor) becomes
  next campaign target.
- **Indeterminate** (variance > 5 %): more fires required; not a closure.

---

## §8 Out-of-scope (g3 carve-outs)

- Convergence at d=4096 (gap (a) of `project_flame_general_pytorch_replacement_goal`).
- Multi-GPU (single-GPU only).
- ROCm / Metal parity (GPU.md §10 separate row).
- nn.Module DSL (gap (e) of `project_flame_general_pytorch_replacement_goal`).
- Shape-sweep beyond d=4096 single-shape (n_layer=24).

These are explicitly future cycles; RFC 072 closure means **one shape**
flips, not "general PyTorch replacement".

---

## Appendix A — Field test sketch (P1 reference)

```hexa
// Stub structure for P1 — NOT yet wired:
use "stdlib/flame/tensor_lib"
use "stdlib/flame/decoder_lib"
use "stdlib/flame/decoder_block_lib"
use "stdlib/flame/nn_lib"
use "stdlib/flame/train_lib"

let D_MODEL: int = 4096
let N_LAYER: int = 24
let SEQ_LEN: int = 2048
let BATCH:   int = 8
let WARMUP_STEPS: int = 1
let TIMED_STEPS:  int = 3

pub fn bench_d4096_step1_wall(precision: string) -> f64 {
    // P1: build decoder · run warmup · measure timed_steps · return median
    // P2: silicon-fire on RTX 5070 ubu-2 (reference_gpu_fire_infra)
    return 0.0
}
```
