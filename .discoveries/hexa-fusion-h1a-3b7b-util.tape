@H1A := "bigger 3B/7B model self-saturates an idle H100 (util is workload-size)" :: discovery [active]
  seed   = "D2 proved util = GPU-relative workload-size property; a WIDER-D 3B/7B model has LARGER GEMMs → should fill the H100 MORE"
  parent = "F-FUSION-D2-RIGHTSIZED (util is workload-size, not a defect) + handoff 80d47ccc (anima Lane G forge 3B/7B util-unblock)"

  falsifier =
    "as D grows from D1536 (small) to 3B-class (D≈2560-3072) to 7B-class (D≈4096),
     idle-H100 util climbs toward GREEN (≥20%, ideally ≥70%) — confirming the anima
     3B/7B forge is NOT fundamentally util-blocked, it was just tested too small.
     If util does NOT climb with D (stays low even at D=4096) -> FALSIFIED:
     the megakernel (H1b) is genuinely required (valid negative)."

  method =
    "EXISTING util driver self/native/hxqwen14b_llmstep_driver.cu mode=util
     (#includes shipped hxqwen14b_cuda.cu — measured kernels = exact main-branch).
     reuse D2/cutlass recipe: nvcc -O3 -arch=sm_90a -DHEXA_CUDA ... -lcublas -lcuda.
     Sweep D ∈ {1536, 2560, 3072, 4096} at clm/LLM GEMM shapes M=K=N=D, R=16, secs=15.
     Two arms per D: cuBLAS-TF32 (default) AND own-GEMM WMMA2
       (HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1).
     nvidia-smi utilization.gpu sampled @100ms over the full sustained 15s loop;
     report util MEAN/PEAK verbatim. ONE idle H100. NO clm_prod rebuild."

  baseline_h100 =
    "D2 / F-FUSION-OCCUPANCY-WALL: util MEAN @ D=1536 idle H100 = 10.28-13.19%
     across async/graph levers; median 2%, PEAK 71-100% only during brief GEMMs."

  target = "the util-vs-D curve + the D where util crosses 20% and 70% on the idle H100"
  verdict-ptr = ".verdicts/hexa-fusion/F-FUSION-H1A-3B7B-UTIL.txt"

  result = "🟢 CONFIRMED (stronger than predicted) — genuine idle H100 80GB: util is
            ALREADY GREEN at the SMALLEST D=1536 (MEAN 95.65% cuBLAS / 96.69% own,
            MEDIAN 100%) and STAYS saturated flat-at-ceiling through D=4096 (MEAN
            ~94-97%, MEDIAN 100%, both arms). util-vs-D is FLAT, not climbing —
            crosses 20% AND 70% already at D=1536. The size axis is NOT the lever.
            FINDING: the ~13% baseline is clm_prod's per-kernel SYNCHRONIZED serial
            DAG, NOT the GEMM workload size — the byte-identical own-GEMM step run
            back-to-back (sync every 16 iters) saturates the H100 at D=1536. anima
            3B/7B will NOT lift util by scaling; the lever is DAG-sync / CUDA-graph
            (L3-c/d, option-B), not a megakernel for the GEMM math and not bigger D.
            pods 39490223 (H100) + 39489067 (mis-prov RTX PRO 6000) destroyed, leak 0."
