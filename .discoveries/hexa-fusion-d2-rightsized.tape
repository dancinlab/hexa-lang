@D2 := "right-sized GPU saturates the clm-scale own-GEMM workload" :: discovery [active]
  seed   = "util = GEMM saturation; util-GREEN is a WORKLOAD-SIZE property, not a code defect"
  parent = "F-FUSION-OCCUPANCY-WALL (lever B: RIGHT-SIZED GPU)"

  falsifier =
    "the SAME D1536-scale own-GEMM step that gives util MEAN ~13% (10.28-13.19%)
     on an idle H100 (F-FUSION-OCCUPANCY-WALL) gives >=~70% util on a right-sized
     consumer GPU (RTX 5070 / 4090) -> util is workload-size-relative.
     If the small GPU ALSO stays low -> FALSIFIED (util would be a code defect)."

  method =
    "lightweight standalone driver self/native/hxqwen14b_llmstep_driver.cu
     (#includes shipped hxqwen14b_cuda.cu — measured kernels = exact main-branch).
     mode=util M K N R secs, sustained step loop, nvidia-smi sampling.
     env HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 = our CUTLASS-grade WMMA2 own-GEMM.
     Shapes: clm-scale M=1536 K=1536 N=1536 R=16 (D1536) AND large M=N=K=2048.
     NO clm_prod rebuild (too heavy)."

  baseline_h100 =
    "F-FUSION-OCCUPANCY-WALL: util MEAN @ D=1536 idle H100 = 10.28-13.19% across
     async/graph levers; median 2%, PEAK 71-100% only during the brief GEMMs."

  target = "GREEN — clm-scale util MEAN >=70% on right-sized consumer GPU"
  verdict-ptr = ".verdicts/hexa-fusion/F-FUSION-D2-RIGHTSIZED.txt"

  result = "🟢 CONFIRMED — RTX 5070 12GB: clm-scale 1536³ util MEAN 98.00% (all 102
            samples =98%, SM 98% compute-bound) vs idle H100 ~13% on the SAME step.
            large 2048³ = 99.00%. util is workload-size-relative, NOT a code defect.
            pods 39484047 (RTX 5070) + 39483879 (mis-prov B200) destroyed, leak 0."
