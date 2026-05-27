@V := "tape" :: spec [active]
  version = "1.2"

#
# Discovery log — GPU whole-program-fusion epilogue (GEMM + bias + GeLU).
#   id     = fusion-epilogue-gemm-bias-gelu
#   seed   = "the classic fused-epilogue case cuBLAS cannot do: GEMM +
#             bias-add + GeLU activation in one kernel — does a single fused
#             hexa-emit kernel structurally undercut a cuBLAS-using stack on
#             launch-count AND HBM write-traffic at transformer-FFN shape?"
#   group  = GPU · whole-program-fusion · GPU.md section 10 (>=30% box)
#   cycle  = 2026-05-25 · branch gpu-fusion-epilogue (from origin/main 49fcf884)
#   verdict-tier-target = 🔵 SUPPORTED-FORMAL (structural launch+HBM advantage,
#                         proven closed-form AND ptxas-clean)
#
# Pre-registered falsifier (F-FUSION-EPILOGUE-GEMM-BIAS-GELU):
#   A single fused hexa-emitted kernel computing GeLU(A@B + bias) (epilogue
#   fused into the GEMM, output written once) uses 1 kernel launch + writes
#   the M x N result to HBM exactly ONCE, vs a cuBLAS-using baseline
#   (cublasGemmEx -> write C to HBM -> separate bias-add kernel reads+writes
#   C -> separate GeLU kernel reads+writes C) = 3 launches + 3x the M x N HBM
#   write traffic. FALSIFIED if the fused kernel does NOT reduce launch-count
#   AND HBM-traffic on a transformer-FFN-shaped GEMM (M=4096 K=4096 N=11008
#   or a smaller fit).
#
# Real measurement (structural oracle = deterministic byte/launch count):
#   tool/fusion_epilogue_structural_oracle.hexa — compiled hexa, run on ubu-1.
#   FFN (M=4096 N=11008 K=4096): C tensor = 180,355,072 bytes.
#     FUSED    launches=1  C-write-bytes=180,355,072  (1x)
#     BASELINE launches=3  C-write-bytes=541,065,216  (3x)
#     launch reduction = 66.667%   HBM-write reduction = 66.667%
#   smaller-fit (256x256x256): same 66.667% (shape-independent — depends on M*N).
#
# ptxas-clean: archive/fires/fusion_epilogue_gemm_bias_gelu_2026_05_25/
#   fused_gemm_bias_gelu.ptx (md5 1d7380556da101b7e37017b79eed6f01)
#   ptxas -arch=sm_80 on ubu-2: RC=0, 23 registers, 0 spill, cubin 4264 B.
#
# Finding (positive structural delta vs cuBLAS-using baseline):
#   The fused epilogue removes 2 of 3 kernel launches and 2 of 3 full-C-tensor
#   HBM write passes — a 66.667% reduction in BOTH axes, by construction,
#   for any FFN shape. >= 30% whole-program-fusion gate cleared structurally.
#   This is the epilogue-fusion advantage cuBLAS cannot express (plain
#   cublasSgemm/GemmEx has no bias/activation epilogue).
#
# DEFERRED (per round policy — serial follow-up):
#   the timed wall-clock fire (fused 1-launch kernel vs the 3-launch cuBLAS
#   baseline on ubu-2 RTX 5070) is DEFERRED to a serial follow-up; ubu-2 is
#   shared and parallel timed fires contend and poison wall numbers. The
#   GPU.md section 10 >=30% box stays [ ] until that timed wall lands.
#
# next-cycle claim link: timed wall fire -> if fused wall < 0.7x baseline
#   wall on the FFN shape, flip the GPU.md section 10 >=30% box to [x].
#
# verdict: 🔵 structural-formal — 66.667% launch AND HBM-write reduction
#   (FFN M=4096 N=11008 K=4096) · ptxas-clean sm_80 RC=0 · timed wall DEFERRED.
