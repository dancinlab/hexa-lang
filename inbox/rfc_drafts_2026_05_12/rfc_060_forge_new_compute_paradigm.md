# RFC 060 — forge new compute paradigm: verified mega-kernel execution model

## 1. Status / Date / Priority / Severity

- **Status**: **falsifiers RESOLVED — 100% closure (2026-05-19)**. All 3
  pre-registered falsifiers measured: 1 PASS, 2 measured-KILL. Headline
  verdict: at FP64, a new paradigm does NOT break past CUDA's
  kernel-per-op model — measured-falsified. Measurement SSOT =
  `state/forge_rfc060_2026_05_19/RFC060_FALSIFIER_RESULTS.md`. Closure
  detail in §13 below.
- **Date**: 2026-05-19 (drafted + closed same day)
- **Priority**: P1 (carries the 2026-05-19 user goal — *"new paradigm 으로
  CUDA 성능·자원·속도 돌파 — 100% closure"*. forge's Phase R closed the
  *CUDA-paradigm* question; this RFC opens the *new-paradigm* question the
  original 2026-05-16 directive asked for but `PARADIGM_RESEARCH.md` never
  delivered.)
- **Severity**: MEDIUM — forge ships today on the C/CUDA substrate (Phase R
  measured, flame 2.95× over PyTorch eager). Nothing breaks without RFC 060;
  it is an *exploration enabler*, not a correctness fix. But the directive
  gap is real (see §5) and g3 demands it be named.
- **Domain**: **forge** (`self/forge/`). The deliverable scope is an
  execution-model exploration + measured falsifiers, not a hardware project
  (PIM/CGRA = the separate `comb` project, GOAL ③).

## 2. Source convergence

Three threads converge:

1. **The 2026-05-16 directive gap.** `self/forge/PARADIGM_RESEARCH.md` cites
   *"forge 는 CUDA 포팅이 아니다 — 더 뛰어난 아키텍쳐/패러다임"* but its body
   surveyed only NVIDIA-silicon software strategies. The 4 paradigms A/B/C/D
   in `PARADIGM.md` are dispatch/fusion/precision tactics *inside* the SIMT
   kernel-per-op model. The "genuinely new paradigm" half was never done.
2. **The 2026-05-19 goal.** User set: *new paradigm 으로 CUDA 성능·자원·속도
   돌파 — 100% closure (measured)*. Not "use CUDA better" — **beat the
   kernel-per-op execution model**, proven by measurement.
3. **The 2025-2026 mega-kernel result.** Mirage Persistent Kernel
   (arXiv:2512.22219) and Stanford Hazy Research megakernels independently
   measure 1.5-2.5× end-to-end latency wins by compiling a whole model pass
   into one persistent GPU kernel with an in-kernel scheduler. This is the
   first genuinely-new execution model that is measured, reproduced, and runs
   on the GPU forge already owns.

Research SSOT: `self/forge/PARADIGM_C_RESEARCH.md` (2026-05-19) — full
8-paradigm survey + ranked synthesis.

## 3. Source evidence (g3 — every claim traces to a real source)

- `self/forge/PARADIGM_RESEARCH.md` §1-§8 — the CUDA-only survey (the gap).
- `self/forge/PARADIGM.md` §5 — Phase R paradigm A measured 2.24-6.07×
  PyTorch eager via dispatch elimination (the *software* optimization of
  kernel-per-op, not a model shift).
- `stdlib/flame/PLAN.md` 2026-05-19 — flame mk2 generic ag_tape 114s/step
  d768·12L, 2.95× PyTorch eager (the real baseline RFC 060 must beat).
- Mirage Persistent Kernel — arXiv:2512.22219 — up to 1.7× inference latency
  vs kernel-per-operator serving.
- Stanford Hazy Research megakernels (2025-09 blog) — Llama-1B megakernel
  2.5× vs vLLM / 1.5× vs SGLang on H100; Llama-70B throughput +22% vs SGLang.
- Exo 2 (arXiv:2411.07211, ASPLOS 2025) + Exo-GPU (PLDI 2026) — verified
  trusted-rewrite scheduling, equivalence chain to synchronized GPU code.
- forge Phase R cost discipline — `PARADIGM.md` §1 — 14 fires, $2.91 total,
  ~$0.40/fire unit cost (the cost anchor for RFC 060's kill-tests).

## 4. Scope

**DESIGN draft only.** RFC 060 specifies:

- The **paradigm under test**: the mega-kernel execution model — compile a
  forge transformer train step into one persistent GPU kernel with a
  compiler-generated in-kernel task scheduler, replacing the host-launched
  kernel stream.
- The **method under test**: verified rewrite-chain codegen — forge codegen
  expressed as a chain of equivalence-preserving rewrites, each citing an
  atlas law (Exo-style, mapped onto strict-lint stages 7+8).
- **3 pre-registered falsifiers** (§7) with cheap first measurements.
- The **decision rule**: the paradigm is adopted ONLY by a measured falsifier
  pass. Per g3 + the project's "실험·검증 후 결정" rule, RFC 060 declares no
  paradigm — it pre-registers the experiment.

RFC 060 does NOT specify:

- Any `.cu` / `.hexa` kernel source (Stage 2 per-falsifier work).
- Hardware (dataflow ASIC / CGRA / PIM = `comb`, GOAL ③ — explicitly
  out of scope per `PARADIGM_C_RESEARCH.md` §10).
- A replacement for `PARADIGM.md` — forge ships on the C/CUDA substrate;
  RFC 060 is the exploration layer above it.
- The flame↔forge ABI (RFC 050 `forge_tier_v1` is the stable surface; a
  mega-kernel tier would register through the same `_v1` dispatch).

## 5. Problem — the directive's "new paradigm" half was never delivered

forge's Phase R answered *"how do we use NVIDIA GPUs well?"* — measured,
honest, closed (`PARADIGM.md`). It did NOT answer *"is there a better
execution model than the kernel-per-op stream CUDA imposes?"* — the other
half of the 2026-05-16 directive. The kernel-per-op model has two structural
costs RFC 060 targets:

- **per-op launch overhead** — every matmul/norm/activation is a separate GPU
  dispatch; Phase R measured ~600 μs/step of fixed launch+dispatch cost.
- **per-op HBM round-trip** — each kernel writes its output to HBM and the
  next kernel re-reads it; intermediate tensors never stay on-chip across the
  op boundary.

Paradigm A (AOT dispatch elimination) attacks the first cost from the *host*
side. It cannot touch the second — the kernels still round-trip HBM between
ops. A mega-kernel attacks **both**: one persistent kernel means zero
inter-op launches and on-chip producer→consumer handoff. That is the literal
content of "CUDA 성능·자원·속도 돌파."

## 6. Proposal — verified mega-kernel execution model

### 6.1 The execution model (target)

Compile a forge transformer train step into **one persistent GPU kernel**:

```
  kernel-per-op (today)              mega-kernel (RFC 060)
  ┌────┐  HBM  ┌────┐  HBM           ┌──────────────────────────┐
  │MM 1│ ────▶ │Norm│ ────▶ ...      │  one persistent kernel   │
  └────┘       └────┘                │  ┌────┐→┌────┐→┌────┐    │
   ▲ launch     ▲ launch             │  │MM 1│ │Norm│ │ ...│    │
   │            │                    │  └────┘ └────┘ └────┘    │
  host stream, N dispatches          │  in-kernel scheduler,    │
  N HBM round-trips                  │  on-chip handoff, 1 launch│
                                     └──────────────────────────┘
```

- A compiler-generated **in-kernel task scheduler** tracks producer/consumer
  dependencies between fused ops (the Mirage/MPK design).
- Intermediates stay in registers / shared memory across op boundaries where
  pressure allows; HBM is touched only at the train-step boundary.
- Dispatch through RFC 050 `forge_tier_dispatch_v1` as a new tier
  (`FORGE_REGIME_*` unchanged; the mega-kernel is a kernel-family +
  specialized registration, not an ABI change).

### 6.2 The method (verified rewrite chain)

forge codegen for the mega-kernel is expressed as a chain of
**equivalence-preserving rewrites** from a sequential hexa autograd reference
to the fused GPU schedule. Each rewrite (tile, reorder, fuse, vectorize,
persist) cites an atlas law; strict-lint stage 7 (equational-verify) +
stage 8 (citation) gate the chain. A rewrite that cannot cite a legal-
transform law (e.g. a fast-math reassociation that is not bit-equal) is
flagged, not silently applied — the chain is honest about where verification
stops and tuning begins.

### 6.3 Why this is hexa-native, not a CUDA port

The mega-kernel is an *execution model*, not NVIDIA API surface. Its in-kernel
scheduler is plain compute the hexa→NVPTX backend (RFC 055) can emit. RFC 060
and RFC 055 compose: **RFC 055 = forge in hexa; RFC 060 = forge breaks
kernel-per-op; the union = a hexa-native mega-kernel.** Until RFC 055 lands,
the RFC 060 prototype may be C/CUDA (measurement first, per g3 — the paradigm
is validated by wall-clock before the hexa-native rewrite is invested).

## 7. Falsifier battery (3 pre-registered)

Each falsifier is **compiled-native** path, measured on a fresh GPU fire
(vast.ai/runpod), reference = forge Phase R measured anchors. No fabricated
targets.

### F-RFC060-MEGAKERNEL-WALL
A persistent single-kernel forge transformer **training** step
(fwd+bwd+optimizer) beats forge's current kernel-stream AOT step by **≥1.3×**
at Llama-7B-block scale on one H100.
- **Cheap first measurement (~$0.40, one H100 fire)**: fuse the **forward
  pass only** into one persistent kernel on the existing Phase-R transformer-
  block harness; measure vs the kernel-stream forward.
- **Kill condition**: forward-only fusion < **1.1×** → the backward pass
  (doubled register pressure) will not recover it. Kill, or honestly downgrade
  scope to inference-only.

### F-RFC060-VERIFIED-CHAIN
forge's existing C/CUDA FFN kernel can be re-derived as **≤8 equivalence-
preserving rewrites** from a sequential hexa reference, each citing an atlas
law, final kernel bit-equal to the current one at TOL_OP.
- **Cheap first measurement (~$0, no GPU)**: hand-transcribe one forge kernel
  as a rewrite chain on IR; check each step is a known-legal transform.
- **Kill condition**: the simplest FFN needs an un-verifiable step → "fully
  verified chain" is killed; downgrade honestly to "verified skeleton +
  unverified tuning."

### F-RFC060-POLY-FEASIBLE (long-arc gate)
The full transformer training step, as one symbolic dependence graph, yields
a feasible polyhedral ILP whose certified schedule is **≥0.9×** the
throughput of forge's hand-tiered AOT step.
- **Cheap first measurement (~$0)**: feed one transformer block's loop nest
  to an existing polyhedral tool (isl / Pluto / Tempo released code); check
  the ILP is feasible and solves in seconds.
- **Kill condition**: a single block is non-affine enough to time out or be
  rejected → whole-step polyhedral is a research program, not a deliverable;
  defer indefinitely.

## 8. Honest caveats (g3 / f1 / f2)

- **8.1 No paradigm declared.** RFC 060 pre-registers an experiment. The
  mega-kernel paradigm is adopted ONLY if F-RFC060-MEGAKERNEL-WALL passes.
  A draft RFC is not a measured result.
- **8.2 Published mega-kernel wins are inference.** MPK + Stanford numbers
  are static-shape inference. The backward pass roughly doubles register
  pressure; the forward-only cheap test exists precisely to gate this before
  a full training-step fire is funded.
- **8.3 Verified-chain ≠ verified accuracy.** The rewrite chain verifies
  functional equivalence + schedule legality, NOT floating-point accuracy or
  wall-clock optimality. A verified mega-kernel can still be slow or
  numerically divergent — that is what F-RFC060-MEGAKERNEL-WALL measures
  separately.
- **8.4 Not a `comb` overlap.** RFC 060 is a software execution model on the
  GPU forge owns. PIM/CGRA/dataflow-ASIC (new silicon) are `comb` (GOAL ③).
  `PARADIGM_C_RESEARCH.md` §10 rules them out for forge explicitly.
- **8.5 No n=6 lattice numerology.** The mega-kernel design, the rewrite
  laws, and the falsifier thresholds trace to measured Phase R anchors +
  published MPK/Stanford numbers only. No lattice/perfect-number constant in
  the paradigm (f1/f2 deny).
- **8.6 "100% closure" is measured closure.** The 2026-05-19 goal's "100%
  closure" means *all 3 falsifiers resolved* (pass → adopt, fail → honestly
  downgrade/defer) — not "all 3 pass." A measured kill IS closure.

## 9. Non-goals

- No `.cu` / `.hexa` kernel source (Stage 2 per-falsifier).
- No hardware paradigm (dataflow ASIC / CGRA / PIM = `comb`).
- No replacement of `PARADIGM.md` (forge ships on C/CUDA substrate).
- No flame public API change (`g_flame_api_fixed` preserved).
- No RFC 050 ABI change (mega-kernel = a tier behind `forge_tier_v1`).
- No multi-GPU mega-kernel (single-GPU first; cross-GPU = future RFC).

## 10. Cross-RFC dependency

- **RFC 040/041** — device-farr + cuBLAS + `.cu` kernels: the kernel-per-op
  substrate RFC 060 measures against.
- **RFC 044** — forge regime-tiered substrate: the mega-kernel is a new tier
  within the regime model, not a replacement.
- **RFC 049** — BF16 substrate: composes — a BF16 mega-kernel is the union;
  out of RFC 060 Stage A scope.
- **RFC 050** — flame↔forge `forge_tier_v1` ABI: the mega-kernel registers as
  a specialized kernel through the existing `_v1` dispatch; no ABI change.
- **RFC 055** — hexa→NVPTX codegen: composes — RFC 055 makes forge hexa-
  native, RFC 060 makes forge break kernel-per-op; union = hexa-native
  mega-kernel. RFC 060 prototype may be C/CUDA (measure first).

## 11. Cross-link

- `self/forge/PARADIGM_C_RESEARCH.md` — research SSOT (8-paradigm survey +
  ranked synthesis + the 3 falsifiers this RFC formalizes).
- `self/forge/PARADIGM_RESEARCH.md` §9 — scope-note documenting the CUDA-
  paradigm vs new-paradigm split.
- `self/forge/PARADIGM.md` — measured CUDA-paradigm SSOT (A/B/C/D).
- `self/forge/PLAN.md` — forge roadmap; RFC 060 = a Phase 6-sibling
  exploration track.
- `self/forge/FORGE.tape` — `@X x_rfc060` citation + governance.
- `GOAL.md` ① — north-star (flame+forge NN stack faster than PyTorch).

## 12. PLAN integration

forge `self/forge/PLAN.md` gains an RFC 060 exploration track (sibling to
Phase 6 endgame):

| Step | Scope | Gate | Cost |
|---|---|---|---|
| RFC 060-A | F-RFC060-VERIFIED-CHAIN paper test (1 FFN kernel as rewrite chain) | $0, no GPU | ~$0 |
| RFC 060-B | F-RFC060-POLY-FEASIBLE feasibility (1 block → isl/Pluto/Tempo) | $0, no GPU | ~$0 |
| RFC 060-C | F-RFC060-MEGAKERNEL-WALL cheap test (forward-only persistent kernel) | 1 H100 fire | ~$0.40 |
| RFC 060-D | full training-step mega-kernel (fwd+bwd+opt) — ONLY if 060-C ≥ 1.1× | user gate | multi-fire |

Steps A and B are $0 and can run immediately. Step C is one Phase-R-unit
fire. Step D is gated on C. "100% closure" = all of A/B/C resolved
(pass-and-proceed or measured-kill).

## 13. Closure — measured 2026-05-19

All 3 falsifiers resolved the day RFC 060 was drafted. Measurement SSOT:
`state/forge_rfc060_2026_05_19/RFC060_FALSIFIER_RESULTS.md` +
`result.json` (gitignored local trail, Phase-R convention). Harnesses:
`tool/forge_rfc060b_poly_feasible.c`,
`self/cuda/experiments/rfc060_megakernel_fwd.cu`,
`tool/dispatch_rfc060_megakernel_fire.sh`.

| Falsifier | Cost | Verdict |
|---|---|---|
| F-RFC060-VERIFIED-CHAIN | $0 paper | **KILL → downgrade** — rmsnorm kernel = 6-rewrite chain; 4/6 exact bit-equal, 2/6 (reduction strip-mine + block-tree) reassociate the FP sum → not bit-equal. "fully verified bit-equal codegen" falsified; method survives as "verified skeleton + TOL-bounded reassociation." |
| F-RFC060-POLY-FEASIBLE | $0 isl | **PASS** — isl computed a valid affine schedule for the transformer-block FFN+RMSNorm nest in 0.0114 s (88× under the 1 s gate), and even fused normalize into matmul-1. Whole-step polyhedral scheduling is feasible. |
| F-RFC060-MEGAKERNEL-WALL | 2 A100 fires | **KILL (FP64)** — fixed-prototype clean fire (A100 80GB, max\|Δ\| 1.6e-14): mega-kernel forward **1.8× (small) / 4.4× (medium) SLOWER** than the kernel-per-op stream. |

**Headline verdict — measured.** At the **FP64** substrate forge runs
today, the genuinely-new paradigm (mega-kernel execution model) does
**not** break past CUDA's kernel-per-op model — it is decisively
*slower*. Root cause, corroborated by the clean `mm_cublas_ms`
diagnostic + forge's own Phase R C-V3 measurement: a whole-forward
mega-kernel must replace every cuBLAS Dgemm with an in-kernel GEMM, and
no in-kernel FP64 GEMM (naive tiled here; even hand-WMMA at 41-43% in
Phase R) matches cuBLAS — so the matmul-throughput regression dominates
the launch + HBM-roundtrip savings.

This is the §8.2 pre-registered outcome: every measured mega-kernel win
in the literature (Mirage MPK, Stanford megakernels — 1.5-2.5×) is
**BF16 Tensor Core inference**, where in-kernel GEMM *is* competitive.

**Where the paradigm IS viable (the closure points here)**: RFC 060 ∩
RFC 049 — a **BF16-Tensor-Core mega-kernel**. forge's Phase R already
validated BF16 as "the wall path" (9.67× FP64 cuBLAS at Llama-7B FFN,
`PARADIGM.md` §1); the mega-kernel literature is BF16; the union is the
measured-gated next RFC. RFC 060's FP64 kill is not a dead end — it is
the measurement narrowing the search to the BF16 substrate.

**g3**: no paradigm adopted on design. The mega-kernel paradigm is
measured-killed at FP64 and measured-deferred to the BF16 substrate.
The verified-rewrite method is retained in honest downgraded form. The
polyhedral direction is measured-feasible. 100% closure = all resolved.
