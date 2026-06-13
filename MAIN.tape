# MAIN.tape — append-only step log (newest first)
# Top-level tracker for the current flame+forge improvement thrust.
# Deep per-round logs live in domains/HEXA-0POD.log.md; this is the master timeline.

@V := "MAIN" :: domain-log

# ── 2026-06-13 ───────────────────────────────────────────────
# - OP-54: sm_120 OWN120 own-GEMM (mma.sync.m16n8k8, OP-1/OP-1b-tuned) vs cuBLAS-TF32 shape sweep on the
#   FREE pool RTX 5070 `summer` ($0, NOT vast). Bit-exact gate PASS every shape (rel-RMS 1.3e-5..3.0e-5);
#   median off-cuBLAS 0.95x-1.47x, CLOSEST @D=768 (0.95x, own EDGES cuBLAS) + D=2048 near-parity (0.96x),
#   worst @D=1024 (under-fill). REPRODUCES the tuned kernel's ~1.0-1.12x claim on a 2nd free card; confirms
#   F-BENCH-5's raw 3.2-6.9x gap is CLOSED. Built via summer's CUDA 12.9 (12.0 ptxas lacks sm_120). HONEST:
#   summer at 98% FOREIGN contention (sibling python, untouched) → off-cuBLAS RATIO is the robust metric.
#   🟢 GREEN, leak-0, temp cleaned. F-OP54-SUMMER-OWNGEMM-TF32.txt + forge-routea doc §8.
# - SET UP MAIN.md + MAIN.tape as the top-level current-thrust tracker (registered in DOMAINS.tape).
# - worktree 전수조사 + 안전정리: 141->78 worktrees. Removed 63 (merged-PR confirmed · 0 uncommitted ·
#   content on main · branch refs preserved). Kept 27 (uncommitted) + 44 (no merged PR = unmerged-suspects,
#   ALL other-campaign: qforge/clm-h911/fusion/cuda/selfhost — NOT this session's work).
#   VERIFIED: this session's HEXA-0POD work (19 OP-36~52 verdicts + doc fixes) is 100% on main — nothing lost.
# - honest-number correction (#3113): retired the apples-to-oranges ~1656x flame-vs-PyTorch headline;
#   README + comparison doc now lead with the FAIR matched-dtype result (FP64 flame ties/wins; TF32 2-8x).
#   Root cause: FP64-vs-TF32 + a 2-point extrapolation of a ~6s/step interpreted-trainer artifact;
#   F-BENCH-1 had already corrected it to single-digit. honest-number discipline note added.
# - OP-45-GPU (#3110): real-H100 T1-T5 sweep — the @D=4096 own-GEMM cap is a FIXABLE scheduling stall
#   (DRAM ~12-40% HBM3, AI 682>>104), NOT a hard roofline; T4 = cuBLAS's +24.6% lever is a better
#   single-pass tile + CTA-swizzle (g5-bit-exact-reachable, NOT split-K). MODE7 persistent @4096 closed-neg.
#   ~$0.96, leak-0.
# - OP-52 (IN FLIGHT): TF32-gap-close GPU experiment — build the T4 lever bit-exactly, measure the close.
# - /deep-dive plugin v0.2.0 shipped to dancinlab/sidecar — self-generating round driver (no prior-turn
#   list; frontier from persisted domain SSOT). The driver for this MAIN thrust.

# ── context ──────────────────────────────────────────────────
# The HEXA-0POD campaign (this session: OP-36 -> OP-52) closed the const-fold codegen bug chain
# (OP-37/37b/40 + CI gate OP-39), drained the falsified-builtin roster (survive 26->10), documented the
# forge own-GEMM boundary, and measured the TF32 gap honestly. High-value 0-pod work is largely depleted;
# the live edge = the own-GEMM tile improvement (OP-52) + the deferred seed-promote bundle.
