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
