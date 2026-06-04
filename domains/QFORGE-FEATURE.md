# QFORGE-FEATURE — milestone annotations (worktree; parent cherry-picks)

@title: 🛠️ QFORGE-FEATURE — QFORGE el-ph engine feature milestones

## milestones

- [x] #27 — NVPTX el-ph hot kernel pilot (α²F BZ-sum) — GPU PARITY HELD on sm_120
      kernel  : stdlib/qforge/nvptx_a2f_kernel.hexa (@gpu_kernel qforge_a2f_bzsum,
                bin-per-thread BZ double-delta, #1215 exp, underflow-guarded)
      PTX     : stdlib/qforge/nvptx_a2f_kernel.hexa.ptx (sm_90, driver-JIT→sm_120)
      harness : stdlib/qforge/nvptx_a2f_host.cu (cuModuleLoadDataEx driver-API)
      selftest: stdlib/qforge/qforge_nvptx_a2f_parity_selftest.hexa (g5, hexa run PASS)
      verdict : .verdicts/qforge-nvptx-a2f-parity/ — max_rel_err 2.455136e-14 ≤ 1e-5
      GPU     : real on-device exec (RTX PRO 6000 Blackwell sm_120, vast 39481710)
      finding : #1215 f64 exp() returns garbage below x≈−745 (no 2^k underflow
                clamp) → kernel-side Gaussian guard; gap filed
                inbox/patches/nvptx-expf64-underflow-clamp.md (d6/d8 honest)

- [x] #35 — GPU accel lever quantification (PROCESS) — measured CPU vs GPU speedup
      bench   : stdlib/qforge/nvptx_a2f_bench.cu (1D sweep) + nvptx_a2f_bench2d.cu
      2D fix  : stdlib/qforge/nvptx_a2f_kernel2d.hexa (sample×bin, atomic-add)
      ledger  : domains/QFORGE-PERF.bench.m35.md · verdict .verdicts/qforge-m35-gpu-lever/
      finding : M27 bin-per-thread kernel = POOR lever (only ng threads, 0.3%
                occupancy on 188 SMs) → slower than CPU below ns=131072, 1.7× peak.
                2D (sample×bin) kernel fills SMs → 27–42× over single-core CPU
                (ns≥4096), plateau ~138 GFLOP/s (transcendental/exp-bound roof,
                not FMA peak). Crossover ns·ng ≳ 1e5. Distinct from #2706 DFPT
                n_iter cost model — this assembler is parallelism-limited.
      gap     : 3-arg gpu_atomic_add reg-decl missing in NVPTX codegen → filed
                inbox/patches/nvptx-atomic-add-3arg-reg-decl.md (2D measured via
                1-line PTX reg-decl patch; kernel source correct) (d6/d8 honest)
