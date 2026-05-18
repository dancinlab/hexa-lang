# forge — Paradigm C research snapshot (genuinely-new compute/execution model, 2026-05-19)

> **Why this file exists.** `PARADIGM_RESEARCH.md` (2026-05-16) opens by
> citing the user directive *"forge 는 CUDA 포팅이 아니다 — 더 뛰어난
> 아키텍쳐/패러다임"* — but its §1-§8 body only ever surveyed **software
> strategies on NVIDIA silicon** (AOT compilation, kernel fusion, CUDA
> graphs, BF16 precision). The 4 paradigms it produced (A/B/C/D in
> `PARADIGM.md`) are dispatch/fusion/precision tactics *inside* the
> SIMT kernel-per-op model — not a new execution model. That is an
> honest g3 gap between the stated directive and the delivered
> research. **This file fills it.**
>
> **Goal (user, 2026-05-19)**: *new paradigm 으로 CUDA 성능·자원·속도
> 돌파 — 100% closure (measured).* Not "use CUDA better" — **beat the
> kernel-per-op execution model CUDA imposes**, proven by measurement.
>
> **Status**: research snapshot. NOT a paradigm decision — per g3 and
> the project's "실험·검증 후 결정" rule, the paradigm is adopted only
> by measured falsifier, never by this document. Decision SSOT after
> measurement = a `PARADIGM_C.md` sibling (to be written post-fire).
> RFC scaffold = `inbox/rfc_drafts_2026_05_12/rfc_060_forge_new_compute_paradigm.md`.

---

## 1. Framing — software execution model, not hardware procurement

Forge today runs the **kernel-per-op** model: the host launches a stream
of CUDA kernels (one matmul, one norm, one activation, …), each a
separate GPU dispatch with its own HBM round-trip. forge's Phase R
"paradigm A" (AOT dispatch elimination, 2.95× over PyTorch eager —
`PARADIGM.md` §5) is a *software optimization* of that model: it removes
Python+ATen launch overhead, but the GPU still executes a kernel stream.

Direction C asks the deeper question: **should forge's compiler emit a
different execution model entirely** — something other than "a sequence
of imperative kernels on a SIMT GPU"?

Critical boundary (g3 honest): forge owns **an NVIDIA GPU and nothing
else**. New *hardware* paradigms (dataflow ASICs, CGRA, PIM silicon) are
not targetable — compiling to a dataflow/CGRA/PIM IR with no matching
silicon produces an IR that must be lowered back to SIMT anyway, paying
the abstraction cost and getting none of the hardware benefit. PIM
specifically is the separate `comb` project's territory (GOAL ③ — n=6
hexagonal spatial PIM). Direction C is therefore scoped to **execution
*models* runnable on the GPU forge already has**.

---

## 2. Dataflow architectures / dataflow execution model

**What**: data-availability drives execution instead of a program
counter; the program is a dataflow graph mapped onto a fabric. Real
commercial revival — SambaNova SN10 RDU spatially maps an ML dataflow
graph onto a reconfigurable tile fabric (IEEE Xplore 9731612);
Tenstorrent and Groq are parallel bets.

**Limit**: the wins (fusion-by-construction, no HBM round-trips) are
*inseparable from the silicon* — the RDU's reconfigurable interconnect
*is* the dataflow. On a SIMT GPU, "compile to a dataflow graph" yields
an IR, not an execution model.

**Fit: LOW-to-MEDIUM** — dataflow-graph-as-IR is useful (forge's
autograd tape RFC 034 already is one), but "data-availability drives
execution" as forge's *runtime model* needs hardware forge lacks.

## 3. CGRA — coarse-grained reconfigurable arrays

**What**: a grid of word-level PEs reconfigurable per-cycle; the
compiler does spatio-temporal mapping of a loop nest via modulo
scheduling. 2024-2026 work is on the mapping problem — SAT-based exact
modulo scheduling (arXiv:2402.12834), SAT-solver mapping
(arXiv:2512.02884).

**Limit**: CGRA is a *hardware* class; without a CGRA, "compile to a
CGRA mapping" is academic. There is a resonance — CGRA modulo-scheduling
is constraint-solving, and hexa-lang already runs SMT-style equational
verification — but forge would have to *be* a CGRA backend, which
collapses into the `comb` hardware project.

**Fit: LOW**.

## 4. Spatial / systolic computing beyond the TPU

**What**: program = a spatial *layout* of compute, not a temporal
instruction stream. Live software research: SpaDA spatial-dataflow
language (arXiv:2511.09447), Ripple async spatial programming
(PLDI 2025), DFModel mapping optimization (arXiv:2412.16432), and —
critically — **Kitsune (ACM TACO 3777466), which runs spatial dataflow
pipelines *on GPUs*** via persistent kernels.

**Limit**: spatial pipelines on a GPU still bottom out as persistent
kernels with producer/consumer queues — you get pipeline parallelism,
not free spatial locality.

**Fit: MEDIUM** — the spatial *model* is targetable on forge's existing
GPU via the persistent-kernel mechanism; this is the bridge to §8.

## 5. Polyhedral compilation taken to its limit

**What**: loop nests as integer-point sets, affine schedules found by
ILP. Strongest 2025 result — **Tempo (arXiv:2501.05408)** uses the
polyhedral model for *program-wide* scheduling: symbolic dependence
graphs lowered to an ILP assigning a physical execution time to every
timestep — close to "the whole train step as one certified schedule."
Tensor-algebra compilers (TACO, Mosaic PLDI 2023) embody "the compiler
IS the kernel."

**Limit**: polyhedral scheduling is restricted to *affine* loop
bounds/access — data-dependent control flow, dynamic shapes, sparsity
break the model.

**Fit: HIGH** — strongest pure-software fit. A dense transformer train
step is overwhelmingly affine; "one polyhedral schedule, ILP-certified
legal" is realistic, and the ILP legality proof is exactly the artifact
hexa-lang's atlas/strict-lint culture wants. But it is a multi-quarter
compiler-research investment (new IR + ILP scheduler).

## 6. Verified / certified compute scheduling

**What**: the schedule itself is proven correct. Standout — the **Exo /
Exo 2 (ASPLOS 2025, arXiv:2411.07211) and Exo-GPU (PLDI 2026)**
lineage: a schedulable language where optimization is a chain of
*trusted rewrite primitives*, each provably equivalence-preserving.
Exo-GPU completes a verified equivalence chain from sequential reference
semantics to the synchronized GPU implementation. Adjacent: verified
functional tensor compiler (PLDI 2024), ML-GPU-kernel equivalence
checking (arXiv:2511.12638).

**Limit**: verification covers *functional equivalence and schedule
legality*, NOT floating-point accuracy or wall-clock optimality — a
verified schedule can still be slow or numerically divergent.

**Fit: HIGH** — best *paradigm-philosophy* match. hexa-lang already
gates every formula on a cited atlas theorem; "every scheduling rewrite
cites a proven equivalence law" is the same discipline applied to
codegen. Exo's trusted-primitive model maps almost directly onto
strict-lint stage 7 (equational-verify) + stage 8 (citation).

## 7. Event-driven / asynchronous many-task (AMT) execution

**What**: Legion, HPX — work decomposed into tasks executed when
dependencies resolve, hiding latency, no global barriers.

**Limit**: AMT runtimes *are runtimes* — dynamic schedulers with
task-stealing. That directly contradicts hexa-lang's compiler-only /
no-managed-runtime invariant (a hard architectural constraint, not a
preference). A *static* task graph compiled to a fixed schedule is fine
— but that is §4/§8 again.

**Fit: LOW** for dynamic AMT (runtime conflict); MEDIUM for
static-async-graph (which is not distinct from §8).

## 8. ★ Mega-kernel / persistent-kernel execution model (the 2025-26 result)

**What**: compile an *entire model pass* — every matmul, norm,
activation, even cross-GPU communication — into **one single persistent
GPU kernel**, with a compiler-generated *on-chip task scheduler* and
producer/consumer dependency tracking. This is a genuine execution-model
shift: from "host launches a stream of kernels" to **"one kernel IS the
program, with an in-kernel dataflow scheduler."**

**Measured (independently reproduced across three groups, 2025-2026)**:
- **Mirage Persistent Kernel (MPK, arXiv:2512.22219)** — up to **1.7×**
  end-to-end inference latency reduction vs kernel-per-operator serving.
- **Stanford Hazy Research megakernels** — Llama-1B megakernel **2.5×**
  vs vLLM / **1.5×** vs SGLang on H100; Llama-70B throughput megakernel
  **+22%** vs SGLang.

**Limit**: register / shared-memory pressure caps how much fuses into
one kernel; published wins are **inference (static shapes)**, NOT the
backward pass (which roughly doubles register pressure).

**Fit: HIGH** — this is "spatial/dataflow as a software model on a GPU"
made concrete and measured. It (a) is a true model-shift away from
kernel-per-op — i.e. literally *breaks the CUDA execution model the goal
targets*, (b) runs on the exact NVIDIA silicon forge already owns, (c)
is killable/confirmable by a single ~$0.40 H100 fire matching Phase R
cost discipline.

---

## 9. Synthesis — ranked candidates (for the 2026-05-19 goal)

The goal is *break past CUDA's kernel-per-op model — measured, 100%
closure*. Two candidates survive as the answer; one is a long-arc bet.

### #1 — Mega-kernel execution model (§8) = the TARGET

The only genuinely-new execution model that is (a) measured + reproduced
2025-2026, (b) runs on forge's current GPU, (c) is a true shift off
kernel-per-op. It directly *is* "CUDA 성능·자원·속도 돌파": one
persistent kernel removes per-op launch + per-op HBM round-trips, the
two costs the CUDA kernel-stream model structurally imposes.

**Pre-registered falsifier — F-RFC060-MEGAKERNEL-WALL**: a persistent
single-kernel forge transformer **training** step (fwd+bwd+optimizer,
not just inference) beats forge's current kernel-stream AOT step by
**≥1.3×** at Llama-7B-block scale on one H100.
**Cheap first measurement (~$0.40, one H100 fire)**: take the existing
Phase-R AOT transformer-block harness, fuse the **forward pass only**
into one persistent kernel, measure. If forward-only fusion gives
**<1.1×**, the backward pass (doubled register pressure) will not save
it — kill, or honestly downgrade to inference-only scope.

### #2 — Verified rewrite-chain codegen (§6, Exo-style) = the METHOD

Not a competing execution model — a *methodology* that composes over
#1. forge codegen becomes "a sequence of cited, equivalence-proven
rewrites from a sequential hexa autograd reference to the GPU schedule."
Unique hexa-lang fit: the atlas/strict-lint gate *is* a trusted-rewrite
verifier.

**Pre-registered falsifier — F-RFC060-VERIFIED-CHAIN**: forge's existing
C/CUDA FFN kernel can be re-derived as **≤8 equivalence-preserving
rewrites** from a sequential hexa reference, each citing an atlas law,
final kernel bit-equal to the current one at TOL_OP.
**Cheap first measurement (~$0, no GPU)**: hand-transcribe one forge
kernel as a rewrite chain on IR, check each step is a known-legal
transform (tile, reorder, vectorize). If even the simplest FFN needs an
un-verifiable step (e.g. a fast-math reassociation that is not
bit-equal), the "fully verified chain" claim is killed → degrade
honestly to "verified skeleton + unverified tuning."

### #3 — Whole-step polyhedral schedule (§5, Tempo-style) = long-arc bet

Promising but a real multi-quarter research program (new polyhedral IR +
ILP scheduler forge does not have).

**Pre-registered falsifier — F-RFC060-POLY-FEASIBLE**: the full
transformer training step, as one symbolic dependence graph, yields a
feasible ILP whose certified schedule is **≥0.9×** the throughput of
forge's hand-tiered AOT step.
**Cheap first measurement (~$0)**: feed one transformer block's loop
nest to an existing polyhedral tool (isl / Pluto / Tempo's released
code); check the ILP is *feasible and solves in seconds*. If a single
block is non-affine enough to time out or be rejected, the "whole-step
one schedule" endgame is a research program, not a deliverable.

---

## 10. Honest negatives — what is NOT a fit (g3, no diplomacy)

- **Dataflow ASICs (§2), CGRA (§3), PIM hardware (§7): not a fit, full
  stop.** Hardware paradigms. Their measured wins come from silicon
  forge does not own and is not procuring (PIM is explicitly the
  separate `comb` project). "Compile to a dataflow / CGRA / PIM IR" with
  no matching hardware produces an IR that is lowered back to SIMT
  anyway — all of the abstraction cost, none of the silicon benefit. Do
  not let "dataflow" / "spatial" as buzzwords lure forge into building a
  backend for hardware that does not exist in the project.
- **Dynamic AMT runtimes — Legion, HPX (§7): the cleanest no.** Managed
  runtimes with dynamic schedulers. hexa-lang's compiler-only /
  no-runtime invariant is a hard architectural constraint. Adopting
  Legion-style execution means shipping a runtime — contradicts the
  language's identity.
- **"Dataflow-graph-as-IR" is real but NOT new for forge.** forge's
  autograd tape (RFC 034) + AOT codegen already build and traverse a
  dataflow graph internally. Re-branding that as "forge adopts the
  dataflow paradigm" would be exactly the over-claim g3 forbids.
- **Polyhedral (§5), candidly**: a worthy long-arc direction, but if
  pitched as a near-term endgame it is over-scoped — gate any commitment
  behind the $0 feasibility test in §9 #3 first.

---

## 11. Verdict (for RFC 060)

The defensible Direction-C conclusion: forge's genuinely-new paradigm =
**the mega-kernel execution model (#1) as the target, layered with
verified rewrite-chain codegen (#2) as the method.** The mega-kernel is
the only measured, reproduced, hardware-available execution model that
is a true break from CUDA's kernel-per-op model — i.e. the literal
content of the 2026-05-19 goal. The verified rewrite chain is the unique
hexa-lang fit and is gated by a zero-cost paper test, so it carries
no fire risk to pre-register alongside.

Both #1 and #2 carry a cheap kill-test (§9). Per g3, RFC 060 pre-
registers the falsifiers; the paradigm is *adopted only if the fires
pass*. No paradigm is declared here.

---

## 12. Sources

- Dataflow / spatial: SambaNova SN10 RDU (IEEE Xplore 9731612) ·
  Emerging AI/ML accelerators IPU/RDU/GPU (arXiv:2311.04417) · SpaDA
  (arXiv:2511.09447) · Ripple async spatial (PLDI 2025) · DFModel
  (arXiv:2412.16432) · Kitsune dataflow-on-GPU (ACM TACO 3777466)
- CGRA: SAT-based modulo scheduling (arXiv:2402.12834) · SAT-solver
  mapping (arXiv:2512.02884)
- Polyhedral / tensor-algebra: Tempo (arXiv:2501.05408) · TIRAMISU
  (arXiv:2005.04091) · TACO Workspaces · Mosaic (PLDI 2023)
- Verified scheduling: Exo 2 (arXiv:2411.07211, ASPLOS 2025) · Exo-GPU
  (PLDI 2026) · verified functional tensor compiler (PLDI 2024) ·
  ML-GPU-kernel equivalence checking (arXiv:2511.12638) · numerical
  methods in Isabelle/HOL (arXiv:2511.20550)
- AMT: HPX adaptive execution (arXiv:2504.07206) · Legion (Stanford)
- PIM: PIMCOMP (arXiv:2411.09159) · DCC tensor compiler for PIM
  (arXiv:2511.15503) · PIM-CARE (ICS 2025)
- ★ Mega-kernel: Mirage Persistent Kernel MPK (arXiv:2512.22219) ·
  Stanford Hazy Research megakernel blog (2025-09) · "Compiling LLMs
  into a MegaKernel" (Zhihao Jia)

---

## 13. cross-link

- `PARADIGM_RESEARCH.md` §9 — the scope-note that points here (CUDA-
  paradigm research vs new-paradigm research separation).
- `PARADIGM.md` — measured CUDA-paradigm SSOT (A/B/C/D dispatch/fusion).
  Direction C does NOT supersede it — forge ships on the C/CUDA
  substrate today; the mega-kernel paradigm is the *exploration* layer.
- `inbox/rfc_drafts_2026_05_12/rfc_060_forge_new_compute_paradigm.md` —
  RFC scaffold with the 3 pre-registered falsifiers from §9.
- `PLAN.md` §Phase 6 — endgame (RFC 055 hexa-native NVPTX). Direction C
  (RFC 060) is orthogonal: RFC 055 = "forge in hexa, still NVIDIA"; RFC
  060 = "forge breaks the kernel-per-op model." They compose — a
  hexa-native mega-kernel is the union.
- `GOAL.md` ① — north-star (flame+forge NN stack faster than PyTorch).
