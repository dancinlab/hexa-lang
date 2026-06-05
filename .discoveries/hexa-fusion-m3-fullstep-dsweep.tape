@discovery := "hexa-fusion-m3-fullstep-dsweep" :: hexa-fusion [active]
  id     = "F-FUSION-M3-FULLSTEP-DSWEEP"
  seed   = "anima handoff 2e4438a7 #1: does the REAL clm_prod FULL training step reach util-GREEN at GEMM-bound D (2560-4096) on idle H100?"
  context = "H1A (#2734) proved ISOLATED own-GEMM saturates H100 ~95% at all D (flat-at-ceiling). The REAL full step (serial sub-ms glue DAG) was only measured at D1536 (~12-13% via ② ASYNC=0). This sweep fills D1536/2560/3072/4096 on the REAL full step → converts anima path-(a) 'plausible'→'measured'."
  falsifier = "the REAL full clm_prod step util climbs to GREEN (>=20%, ideally >=70%) at GEMM-bound D (2560-4096) on an idle H100"
  method = "build clm_prod_gpu (kit fusion_build_sources.tgz + rebuild.sh, ② ASYNC=0 eager FP64), T512, sweep D=1536/2560/3072/4096; nvidia-smi utilization.gpu @100ms sustained → MEAN/PEAK/MEDIAN/pct>=20 per D. Watch OOM at large D. Optional HEXA_FUSE_ALL=1 arm."
  verdict-tier-target = "🟢 numerical (the util-vs-D curve on the REAL step) — likely CLOSED-NEGATIVE (the serial DAG idles any D; bigger D only lowers steps/s)"
  prior  = ".verdicts/hexa-fusion/F-FUSION-ASYNC-UTIL-AB.txt (D1536 ASYNC=0 12.50%) · README sweep 12.71→2.94% (ASYNC=0, drops with D) · F-FUSION-H1A-3B7B-UTIL.txt (isolated GEMM flat-95%)"
