# discovery: hexa-fusion-p1b-reduction-order
# id: F-FUSION-P1B
# seed: B6 (#2772) — FP64-exact own-GEMM in the cooperative megakernel still gives max|Δ|≠0
#       (~4 ULP, first fwd pass) vs cublasDgemm because own naive-k ≠ cuBLAS tiled-k summation order.
#       Question: can a megakernel-resident GEMM achieve max|Δ|=0 vs the training reference?
# verdict-tier-target: 🟢 numerical (own-vs-own re-measure / reproducible-by-construction GEMM)
#
# === BRAINSTORM (depleted, 5 clusters) ===
#   R1 match-cuBLAS-directly  → reverse-engineer tile/k-order  (DEAD-END, see P1B-z)
#   R2 re-baseline            → eager uses own-GEMM too → byte-eq = own-vs-own (trivially 0)  [P1B-a]
#   R3 order-independent acc  → Kulisch/ReproBLAS/Ozaki                                        [P1B-c1/c2/c3]
#   R4 own-vs-own re-measure  → B6 compared own-mega vs cuBLAS-eager; own-vs-own may be 0      [P1B-d ★cheap]
#   R5 device-side GEMM       → NVIDIA cuBLASDx in-kernel cuBLAS call                          [P1B-b, web-research pending]
#   R6 contract relax         → max|Δ|=0 → ≤N-ULP near-byte-eq tier                            [P1B-e]
#
# === ARXIV RESEARCH (agent aef7cf77, 2026-06-05) — key findings ===
#   * NO published method bit-matches an arbitrary cublasDgemm — it is the WRONG target
#     (vendor-internal tile/split-K order, heuristic, version-fragile). Confirms P1B-z dead-end.
#   * Two principled routes to max|Δ|=0, BOTH require REDEFINING THE REFERENCE (→ P1B-a is a prereq):
#     1. Ozaki-II EXACT GEMM (CRT/integer): arXiv 2504.08009 + error-bound 2602.02549 +
#        Mukunoki FP8 2508.00441 + INT-MMA 2409.13313 + 2603.10634. Exact product → order-independent
#        → any two exact impls bit-identical. Provable max|Δ|=0 vs a correctly-rounded reference.
#     2. Neal superaccumulator / ExBLAS exact long accumulator: arXiv 1505.05571 (Neal, <2x cost,
#        4096+67 fixed-point chunks, order-independent exact) + 2005.07282 (ExBLAS). Cheapest retrofit
#        for the megakernel K-reduction. = the Kulisch "complete register" in practical software.
#   * ReproBLAS binning (1802.09883 / 2005.07282) = reproducible-not-exact, cheapest fallback.
#   * Split-and-correct tensor-core (Ootomo 2203.03341, SGEMM-cube 2507.23387) — literature EXPLICITLY
#     disclaims bit-exactness; NOT for the max|Δ|=0 goal.
#   * Bottom line: chase reproducible-by-construction (adopt one scheme + regenerate the reference),
#     NOT cuBLAS bits. First prototype = Neal superaccumulator K-reduction; full = Ozaki-II.
#
# === WEB RESEARCH (agent ab8ee527, 2026-06-05) — DOUBLE-CONFIRMS arxiv ===
#   * cuBLAS IS bitwise-deterministic run-to-run (NVIDIA docs verbatim) per {version, arch, SM-count,
#     single-stream, fixed workspace} — so it CAN be a fixed reference; the problem is matching from OUTSIDE.
#   * DMMA (FP64 tensor-core) accumulation order = NVIDIA-"UNSPECIFIED" (round-nearest, normalize-each-add,
#     deterministic within arch, differs across generations) → THIS is the root of the 2-4 ULP gap.
#   * cuBLASDx NOT validated as a matcher — any device GEMM on a different kernel path ≠ cuBLAS bits → P1B-b
#     downgraded toward dead-end (joins P1B-z).
#   * Tier-1 industry answer = RE-BASELINE (P1B-a): make own deterministic GEMM the SSOT oracle, assert
#     max|Δ|=0 vs ITSELF. Refs: Thinking Machines "batch-invariant ops" + TBIK arXiv 2511.17826 (fixed-order
#     tree-MatMul, ~63% cuBLAS throughput, explicitly NOT matching cuBLAS). CUTLASS also does NOT bit-match cuBLAS.
#   * Tier-2 = snapshot a frozen cuBLAS reference (pin version/arch/SM, capture bytes) — validates an oracle,
#     doesn't help the megakernel produce matching bits.
#   * Dead-ends (both reports agree): reverse-engineer cuBLAS tiling (P1B-z), ReproBLAS/Ozaki-as-cuBLAS-matcher.
#   web refs: bebop.cs.berkeley.edu/reproblas · docs.nvidia.com/cuda/cublas §Reproducibility ·
#     arXiv 2511.17826 (TBIK) · PMC7959640 (tensor-core numerical behavior) · accu.org/.../Reverse-Engineering-cuBLAS
#
# === REGISTERED MILESTONES (HEXA-FUSION.md P1B family) ===
#   P1B-d  own-vs-own re-measure        ★cheapest decisive (is B6's delta only-vs-cuBLAS?)
#   P1B-a  re-baseline to own-GEMM      ★Occam + PREREQ for c1/c2/c3
#   P1B-b  cuBLASDx device GEMM         (web-research pending)
#   P1B-c1 Neal superaccumulator        arXiv 1505.05571  (cheapest exact retrofit)
#   P1B-c2 Ozaki-II exact GEMM          arXiv 2504.08009 + 2602.02549  (provable)
#   P1B-c3 ReproBLAS binning            arXiv 1802.09883  (reproducible-not-exact fallback)
#   P1B-e  near-byte-eq tier            governance (≤N-ULP), needs user sign-off
#   P1B-z  cuBLAS reverse-engineer      CLOSED-NEG (arxiv-confirmed dead-end)
#
# next-cycle claim: P1B-d (own-mega vs own-eager max|Δ| — GPU, ~0 new code) decides whether P1B-a
# gives byte-eq megakernel almost for free. If P1B-d ≠ 0, escalate to P1B-c1 (Neal superaccum K-reduction).

# === RESULT (2026-06-05, GPU B200, F-FUSION-P1B-REBASELINE) — RE-BASELINE RESOLVED ===
#   P1B-d  own-mega vs OWN-EAGER (both same naive-k own-GEMM, D1536 T512, 17-digit CE):
#            first_ce max|Δ| = 8.882e-16 (~2 ULP) ≠ 0 ; last_ce 1.115e-13. FALSIFIED.
#            → re-baseline to own-eager does NOT give max|Δ|=0. Delta at first fwd pass AND
#              both arms run identical naive-k own-GEMM → NOT the GEMM k-order.
#   ROOT (audited every megakernel op vs eager fwd): conv k-order IDENTICAL, MoE/softmax order
#            IDENTICAL. The ULP gap = host↔device TRANSCENDENTALS: megakernel used CUDA sqrt
#            (groupnorm) + CUDA exp (softmax) + CUDA erf (gelu); eager reference uses host
#            NR-40 _gn_sqrt + Taylor _moe_exp + libm erf.
#   P1B-c1 FIX (self/cuda/runtime_cuda_emit.hexa): _hx_dev_groupnorm sqrt → _hx_gn_sqrt_dev,
#            megafwd softmax exp → _hx_moe_exp_dev (the host-faithful software twins). Re-fire:
#            first_ce max|Δ| = 8.882e-16 UNCHANGED ; last_ce shrank to 8.527e-14. STILL ≠ 0.
#            → sqrt+exp were NOT the first_ce binding term. gelu's erf IS: CUDA device erf vs
#              host libm erf, and there is NO host-faithful software erf (CLAUDE.md
#              stdlib_trig_libm) → IRREDUCIBLE for a megakernel-resident gelu.
#   UTIL (P1B-c1, byte-eq-best): own-eager 10.15% → own-mega 14.19% MEAN (+4.04pp), pct>=20
#            13.6%→20.5%, MEGAFWD-FIRED=2, DESCENT=1 both. Util lift real, byte-eq still ⊥.
#   VERDICT: 🔴 byte-eq CLOSED-NEG vs own-eager / 🟢 util. The re-baseline closes the
#            GEMM-reduction-order axis (conv k-order proven equal) but relocates the wall to the
#            host/device erf in gelu. Pods 39569562 + 39571743 DESTROYED, leak 0.
#   NEXT (open): P1B-a' = re-baseline the reference ITSELF to a FULLY device-resident own-GEMM
#            fwd (eager DEVRESIDENT glue on device → CUDA erf both sides) so the device gelu is
#            the oracle → then own-mega vs own-eager-device may reach max|Δ|=0 (both share CUDA
#            erf). Untested this cycle (eager arm here ran glue on host). The other route =
#            a host-faithful software erf device kernel (against stdlib_trig_libm).
