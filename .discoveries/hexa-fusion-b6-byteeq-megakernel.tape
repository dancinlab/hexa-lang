@discovery hexa-fusion-b6-byteeq-megakernel :: HEXA-FUSION B6 [terminal]
  id     = "F-FUSION-B6-BYTEEQ-MEGAKERNEL"
  seed   = "P1 (#2769) lifted real-step util +5.51pp with a TF32 GEMM-pulling cooperative megakernel but broke clm's max|Δ|=0 byte-eq gate. B6: swap the TF32 conv for the FP64-exact own-GEMM (#2697) inside the SAME cooperative megakernel — keep the util structure, ask if FP64 own-GEMM keeps byte-eq."
  target = "🟢 numerical / 🔴 closed-negative"
  verdict= ".verdicts/hexa-fusion/F-FUSION-B6-BYTEEQ-MEGAKERNEL.txt"
  result = "CLOSED-NEGATIVE on byte-eq, GREEN on util. FP64-mega lifts D1536 util 9.13%→12.57% (+3.44pp, [MEGAFWD-FIRED]≥1, CE descends identically) BUT max|Δ|≠0 vs eager cublasDgemm: 9e-16 (D512) / 1.8e-15 (D1536) on epoch-1 first_ce — already at one forward pass, so it is the GEMM reduction order (own-GEMM naive sequential k ≠ cublasDgemm tiled k), structural not a bug. f32 checkpoint: D512 identical (delta below f32 eps), D1536 differs in 36 bytes."
  finding= "byte-eq ⊥ util-lift survives the own-GEMM move. own-GEMM-in-megakernel only shrinks the precision delta from TF32-scale (~1e-3) to FP64-last-bit (~1e-15) — far better, still not 0, HARD gate stays broken. B6 premise corrected: #2697 passed CORRECTNESS within fp tol (5-decimal CE), NOT bit-equality; the 17-digit CE exposes the masked delta. smem risk #1 was a non-issue (P1 conv is register-accumulator, 0 __shared__ → FP64 swap is float→double in a register, 0B smem)."
  next   = "F-FUSION-P1B-TILED-GEMM frontier: a megakernel-resident GEMM whose k-reduction order BIT-reproduces cublasDgemm's tiling — the reduction-order-reproduction problem, multi-session."
  pod    = "vast 39564792 = NVIDIA B200 (rent asked H100; vast served Blackwell again). DESTROYED, leak 0."
