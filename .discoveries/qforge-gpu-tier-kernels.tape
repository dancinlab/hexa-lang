# QFORGE GPU-tier kernels (RFC 055 §12 P4+ family) — on-device verdicts
# summer RTX 5070, sm_120, CUDA 12.9, FREE pool (d7, NO paid rent)
id     = qforge-gpu-tier-kernels
seed   = "extend merged #2737 NVPTX Sternheimer stack with 4 GPU-tier kernels"
engine = nvcc -arch=sm_120 ; cuBLAS TF32 tensor-op ; CUDA driver-JIT

[k1 mixed-precision tensor-core matvec]  verdict = PASS
  accuracy |Δψ⟩ FP64-vs-mixed max_rel_err = 0.000000e+00 (bit-exact residual-refine)
  speedup  block-matvec (NRHS=256) TF32-tc Sgemm vs FP64 Dgemm = 63.96x  (gate >=5x) @N4096
  finding  single-GEMV bandwidth-bound: ratio_lo 1.25x@N2k 1.94x@N4k 2.08x@N8k -> ~2x byte ratio
           (d6) >=5x tensor-core lever = compute-bound block regime only

[k2 fused Sternheimer CG 7->5 launches]  verdict = PARITY-PASS / THROUGHPUT-NOT-MET
  parity     max_rel_err 1.32e-14@N1024 1.78e-13@N256 4.54e-15@N128  (gate <=1e-9) PASS
  throughput 1.01x@N1024 1.03x@N256 1.05x@N128  (gate >=1.5x) NOT MET
  finding    (d6) per-iter time = host-resident scalar control (2 DtoH+sync/iter), not
             the BLAS-1 launches fused. NAMED-REMAINING: device-side dot + coop-grid CG.

[k3 multi-GPU q/k sharding]  verdict = PASS
  shard-λ (2-shard & 4-shard partition+reduce) ≡ single-λ  Δ = 0.000e+00 bit-for-bit
  NAMED-REMAINING (d6) true multi-GPU HW fan-out (cudaSetDevice >=2 dev, NVLink reduce)

[k4 out-of-core ψ streaming]  verdict = PASS
  streamed resident = 25% of full-H footprint (double-buffered output-row tiles)
  streamed out == in-core out  max_rel_err = 0.000000e+00  (disjoint rows, no FP reorder)
  completion + footprint + parity all PASS
