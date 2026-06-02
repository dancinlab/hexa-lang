@discovery := "HEXA-FUSION L3 §5b — compile-time GEMM shape specialization (M,N,K baked)"
  id      = "F-FUSION-GEMM-SHAPE-SPECIALIZE"
  domain  = "HEXA-FUSION"
  milestone = "L3 §5b — compile-time specialization (GPU.md §5b · Static shape specialization)"
  lane    = "⑥ L3 codegen ($0 emit-diff probe — no pod)"
  branch  = "hexa-fusion/l3-compile-time-spec-emit"
  seed    = "GPU codegen emits GEMM shape-GENERICALLY (M/N/K as runtime .param.u64 + data-dependent K-loop). A library-call stack (cuBLAS/cuDNN) is structurally forced into this regime — shape is a runtime descriptor field, not a fact at the call site."

  finding = "added emit_ptx_gemm_module_specialized(target,M,N,K) alongside the generic emit_ptx_gemm_module(target). When (M,N,K) are compile-time constants the specialized kernel: (1) drops the M/N/K .param.u64 + their ld.param.u64 + cvt.u32.u64 (3 data buffer params only); (2) bakes M/N into the setp.lt bounds immediates and K into the row*K stride; (3) FULLY UNROLLS the K contraction — zero setp.lt runtime K-compare, zero @!p bra loop-exit, zero bra back-edge, zero kk counter — into exactly K straight-line fma.rn.f64 steps with kk*N folded to literal offsets."

  emit_delta = "GENERIC: 6 params · $L_LOOP setp.lt.s32 %p2,%r11,%r10 · @!%p2 bra $L_LOOPEND · add.s32 %r11,%r11,1 · bra $L_LOOP · 1 looped fma.rn.f64.  SPECIALIZED(M=4,N=4,K=3): 3 params · NO $L_LOOP/setp.lt %p2/back-edge/kk counter · M=4,N=4,K=3 baked immediates · 3 straight-line fma.rn.f64. Same %fd0,%fd1,%fd2,%fd0 acc-chain → numeric byte-eq."

  verdict_tier   = "🟢 numerical (text-shape emit-diff + byte-eq) — terminal for the $0 codegen probe half"
  verdict_ptr    = ".verdicts/hexa-fusion/F-FUSION-GEMM-SHAPE-SPECIALIZE.txt"
  byte_eq        = "generic GEMM PTX byte-identical origin/main baseline binary == new binary, max|Δ|=0 (purely-additive change, 0 deletions in nvptx_target.hexa)"

  honest_scope = "NOT a raw-GEMM-speed-win claim (cuBLAS = roofline, GPU.md:84 박제). The moat is the compile-time specialization itself — a structural capability the library cannot perform (it resolves shape at runtime dispatch). The win = boundary removal (runtime loop control + shape param-loads erased), not beating cuBLAS at one GEMM."

  remains = "ptxas-accept + silicon numeric-eq half (specialized vs generic produce max|Δ|=0 on a real GPU for a fixed M/N/K) reuses tool/dispatch_r055_p2_gemm.sh — pod fire DEFERRED-to-serial. Next: (a) wire a known-shape call site in MIR to auto-select the specialized emitter (currently a direct codegen entry point); (b) dead-output elimination (masked/pruned output rows) — the second §5b bullet; (c) extend the unroll-specialization to the WMMA matmul path (_nvptx_emit_matmul_body) where K/16 tile count becomes a compile-time fact."
