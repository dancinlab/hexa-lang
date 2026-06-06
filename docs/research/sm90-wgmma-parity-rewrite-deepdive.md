# sm_90a wgmma own-GEMM → cuBLAS-parity: rewrite deep-dive (the architecture crux)

**Type:** research / literature deep-dive — NOT a measured verdict. No perf claim below is
our own measurement; every external claim carries a URL or arXiv id. Primary sources
(NVIDIA PTX ISA, CUTLASS/CuTe source, NVIDIA docs) are preferred over blogs; where they
overlap, secondary blogs are labelled SECONDARY.

**This is the SECOND, DEEPER scan.** The first (`sm90-wgmma-parity-litscan.md`, PR #2846)
named the *levers* (warp-spec, tile size, ping-pong, swizzle form). This one answers the
**architecture crux** that the lever-scan deferred:

> **How does CUTLASS 3.x / CuTe feed `wgmma.mma_async` warpgroup operands on sm_90a
> WITHOUT a software "decode-copy" — and does the SMEM matrix descriptor express the
> SWIZZLE_128B-TMA-landed tile DIRECTLY (avoiding the 32KB decode-copy scratch band that
> our W11–W14 measured as ⊥ occupancy)?**

**Our measured wall (the thing to break).** Our own-GEMM (W1→W14, on `main` @ #2853) tops
out at TF32 70.7 TFLOP/s (6.09× off cuBLAS-TF32) / FP16 71.6 (11.5× off cuBLAS-FP16). The
root cause measured from both sides (W11/W12/W13/W14): the kernel needs a software
**decode-copy** — it reads the `SWIZZLE_128B`-TMA-landed SMEM tile and re-permutes it into
the GMMA core-matrix layout the wgmma descriptor expects, into a separate scratch buffer.
That decode-copy scratch is a 32KB gmma band; holding it at 2 CTA/SM and overlapping
decode↔MMA are mutually exclusive (32KB band ⊥ occupancy, proven both dtypes). The HW
in-place swizzle descriptor (feed wgmma directly from the swizzled tile, no decode-copy)
was tried (W10/W11 MODE5) and gave rel-RMS 1.392.

*(stub — sections filled per-commit below)*
