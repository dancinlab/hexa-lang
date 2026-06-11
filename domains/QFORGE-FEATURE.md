# QFORGE-FEATURE — milestone annotations (worktree; parent cherry-picks)

@title: 🛠️ QFORGE-FEATURE — QFORGE el-ph engine feature milestones

## milestones

- [x] UNIFIED dense off-diag V_scr(G_a−G_b) vertex assembler — the migration-gate
      ARCHITECTURAL residual CLOSED (the three off-diag routes unified into ONE
      normalization-consistent dense vertex). A==B==C is a THEOREM, not a fit:
        (A) dense Σ_{Ga,Gb}ψ*ΔV(ΔG)ψ · (B) apply-col = COMPOSE · (C) cube ∫ψ*ΔV(r)ψ
      DIAGNOSIS — the ~10-order route gap = NORMALIZATION+PHASE (NOT physics): the cube
      route dropped (1) the PW-norm ×Ntot/√Ω AND (2) the bra-conjugate −iG phase
      (ψ_m*(r), nonzero off-diagonal at Γ); compose works in G-space so avoids both.
      g5: stdlib/qforge/elph_offdiag_integrated_selftest.hexa — A==B==C machine-precision PASS
      real CaH6 (NPW=64 conv, Anderson-screened, 24-mode ω, N(E_F)=19.95, nactive=10):
        λ_unified = 1.1545 == λ_compose = 1.1545  (route A=B residual 3.30e-7 ≤1%)
        λ_diag-floor = 1.08916 → λ_dense = 1.1545  (off-diag RAISES; Σ|g|² lift ×1.68)
        Hermiticity residual = 1.39e-15 · rel-ε vs QE 4.376 = 0.736175  (VERBATIM, NOT tuned)
      VERDICT (d6/@L5 HONEST) — ARCHITECTURE CLOSED, MAGNITUDE RESIDUAL: the assembler
      is unified + consistent, but λ stays 1.1545 (off-diag structure is small ×1.06).
      The 3.8× QE gap is the vertex-MAGNITUDE / Γ-only FS BZ axis, NOT the assembler —
      hybrid (rel-ε 1.65e-7) remains the QE-grade production path; gate HELD.
      cost $0 (mini 0-pod; summer GPU BUSY @89% fep → mini fallback).
      verdict: .verdicts/qforge-offdiag-integrated/VERDICT.md
      fixture: stdlib/qforge/fixtures/cah6_realcell_offdiag_integrated_xval.hexa
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

- [x] NOVEL — quantum nuclear effects (path-integral) for H — RING-POLYMER ESTIMATOR
      why     : light-H zero-point motion is huge; classical-nucleus DFPT
                understates H delocalization → biases Tc. PIMD (Feynman path
                integral) restores the true quantum spread of the nucleus.
      module  : stdlib/qforge/nqe_pimd.hexa — qforge_nqe_pimd(ω,m,β,N,ħ) →
                {kinetic_q (virial), kinetic_q_prim, delocalization ⟨x²⟩,
                classical_limit kT/2}. Ring of N beads, spring k_N=m·N/(β²ħ²);
                harmonic-V solved DETERMINISTICALLY in ring normal modes (no RNG):
                λ_k = k_N·4sin²(πk/N)+mω²/N, ⟨|X_k|²⟩=1/(βλ_k).
      selftest: stdlib/qforge/nqe_pimd_selftest.hexa (g5, hexa run PASS — 24/24)
      anchor  : HO exact ⟨KE⟩=(ħω/4)coth(βħω/2), ⟨x²⟩=(ħ/2mω)coth(βħω/2). N=256
                PIMD → ⟨KE⟩=0.540988 vs analytic 0.540988 (Δ≤1e-4); error
                monotone N=4>16>64>256; high-T→kT/2 equipartition; H ⟨x²⟩=2·D ⟨x²⟩
                (∝1/m); virial≡primitive.
      hook    : ab-initio coupling NAMED (d6 honest) — qforge_nqe_pimd_abinitio_hook():
                per-bead V(x_s)=E_DFT(R_eq+x_s·ê) via stdlib/qforge/scf_etot (1 SCF/
                bead, parallel over N), V'=−F_DFT from DFPT forces; Tc shift =
                re-run λ on NQE-broadened ⟨u²⟩ vs classical. NO real hydride Tc
                shift fabricated — DFT-potential wiring is the downstream engine task.

- [x] GPU-TIER KERNELS — 4 NVPTX kernels extending the merged #2737 Sternheimer stack.
      Real on-device parity+timing on summer RTX 5070 (sm_120, CUDA 12.9, FREE pool, d7).
      [1] mixed-precision tensor-core matvec — PASS. kernel nvptx_mixprec_matvec_kernel.hexa
          host nvptx_mixprec_matvec_host.cu. ACCURACY |Δψ⟩ FP64-vs-mixed max_rel_err=0.0
          (linear residual-refine, bit-exact); SPEEDUP block-matvec (NRHS=256 block-
          Sternheimer) TF32-tc Sgemm vs FP64 Dgemm = 63.96× ≥5× @N4096. HONEST (d6):
          single GEMV is bandwidth-bound (ratio→~2× byte ratio: 1.25/1.94/2.08× @N2k/4k/8k);
          ≥5× lever is compute-bound regime only (= the real block use case).
      [2] fused Sternheimer CG (7→5 launches) — PARITY PASS (max_rel_err 1.3e-14),
          THROUGHPUT NOT MET on-device (1.01×; gate 1.5×). kernel nvptx_stern_fused_kernel.hexa
          host nvptx_stern_fused_host.cu. HONEST (d6): per-iter time dominated by host-
          resident scalar control (2 DtoH + sync/iter), not the BLAS-1 launches fused.
          NAMED-REMAINING: on-device scalar reduction + cooperative-grid persistent CG.
      [3] multi-GPU q/k sharding — PASS. kernel nvptx_shard_qk_kernel.hexa host
          nvptx_shard_qk_host.cu. 2-shard (and 4-shard) partition+reduce ≡ single-pass λ,
          Δ=0.000e+00 bit-for-bit (contiguous block-partition fixes FP order). NAMED-
          REMAINING (d6): true multi-GPU HW fan-out (cudaSetDevice ≥2 devices, NVLink
          reduce) — needs a 2nd physical GPU; logic is device-count-agnostic.
      [4] out-of-core ψ streaming (cells > VRAM) — PASS. kernel nvptx_ooc_stream_kernel.hexa
          host nvptx_ooc_stream_host.cu. Double-buffered output-row tiling; streamed
          resident 25% of full-H footprint, streamed out == in-core out max_rel_err=0.0
          (disjoint output rows → no FP-order change). Completion+footprint+parity PASS.
      provider: NO PAID RENT — all four built+run on summer free pool (d7).

- [x] DISSOLUTION-MAP — "QE scaling walls are architecture, not physics" made a
      CHECKABLE ARTIFACT. The 3 QE el-ph scaling walls are MPI/data-layout
      architecture limits (not physics); each maps to a MERGED-and-MEASURED
      QFORGE lever. g5 selftest encodes a structured table (wall·lever·pr·metric·
      status) and asserts every DISSOLVED row is merged AND measured.
      selftest: stdlib/qforge/dissolution_map_selftest.hexa (hexa run → PASS)
      verdict : .verdicts/qforge-dissolution-map/F-QFORGE-DISSOLUTION-MAP.txt (🟢)
      map     :
        [1] DFPT core-ceiling (Sternheimer CPU-rank-bound) → GPU-offload block
            matvec + GPU-resident DFPT · #2764 · block-matvec 63.96× ≥5×, |dψ⟩
            max_rel_err=0.0 · DISSOLVED
        [2] memory-per-rank clamp (cell ≤ one rank RAM) → GPU-VRAM-resident +
            out-of-core ψ stream (cells>VRAM) · #2764 · streamed==in-core
            max_rel_err=0.0 · DISSOLVED
        [3] monolithic per-q serialization (no native q fan-out) → parallel-q
            split/collect/union + multi-pod q-split orchestrator · #2765 ·
            2/4-shard==single-pass λ, Δ=0.000e+00 bit-for-bit · DISSOLVED
      caveat  : (d6 HONEST · no double-count) closes the DISSOLUTION-LEVER half
                only. The gate's "λ within 1% of QE" sub-clause is NOT met —
                converged-CaH6 rel-ε=5.47% (>1%), screening-XC blocker (bare |g|²
                vs QE ε⁻¹-screened). That sub-gate ROUTES to the pow2-FFT-Poisson
                + converged-CaH6 milestones (domains/QFORGE-PERF.md), NOT here.
                d_qforge_migration_routing: gate anchors finish on QE; this map
                speeds POST-gate candidates. Supporting merged PRs: #2764 #2737
                #2730 #2765 #2742 #2766 #2767.
