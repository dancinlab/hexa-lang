#!/usr/bin/env bash
# RFC 067 P-nsight -- profile N107 4-warp 64x64 hexa SGEMM at M=4096/6144/8192
# on ubu-1 RTX 5070 using nsys + ncu.
#
# Verifies N130's 3 candidate mechanisms (L2 thrash / shallow cp.async / no swizzle)
# with hard SASS-level counters.
#
# Plain `ssh ubu-1`. PTX is reused from N130 artifact byte-identical.
#
# Outputs (locally in this directory):
#   - compile.log
#   - nsys_M{4096,6144,8192}.nsys-rep / .sqlite / .txt (cuda-trace)
#   - ncu_M{4096,6144,8192}.txt (selected sections raw text)
#   - ncu_M{4096,6144,8192}.csv (raw metrics in CSV)
#   - extracted_metrics.csv (per-shape key counters)
#   - fire.log (full ssh stdout)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REMOTE=ubu-1
ART_BASENAME="rfc067_pnsight_hexa_sgemm_m8192_profile_2026_05_22"
REMOTE_DIR="/tmp/${ART_BASENAME}"
SRC_DIR_N130="../rfc067_pmax_hexa_sgemm_n107_maxM_2026_05_22"

echo "== STEP 1: stage to ${REMOTE}:${REMOTE_DIR}/ ==" >&2
ssh ${REMOTE} "mkdir -p ${REMOTE_DIR}"
scp -q host_one.c "${REMOTE}:${REMOTE_DIR}/"
scp -q ${SRC_DIR_N130}/sgemm_4warp_swizzle_4096x4096_grid.ptx "${REMOTE}:${REMOTE_DIR}/"
scp -q ${SRC_DIR_N130}/sgemm_4warp_swizzle_6144x6144_grid.ptx "${REMOTE}:${REMOTE_DIR}/"
scp -q ${SRC_DIR_N130}/sgemm_4warp_swizzle_8192x8192_grid.ptx "${REMOTE}:${REMOTE_DIR}/"

echo "== STEP 2: build host_one on ${REMOTE} ==" >&2
ssh ${REMOTE} "cd ${REMOTE_DIR} && /usr/local/cuda/bin/nvcc -O2 -arch=sm_90 -o host_one host_one.c -lcuda -lcublas -lm 2>&1" | tee compile.log

NCU=/usr/local/cuda/bin/ncu
NSYS=/usr/local/cuda/bin/nsys

# NCU section list -- focused on memory / scheduler / occupancy (L2 hit, DRAM, stall)
NCU_SECTIONS="--section MemoryWorkloadAnalysis --section MemoryWorkloadAnalysis_Chart --section SchedulerStats --section WarpStateStats --section Occupancy --section LaunchStats --section SpeedOfLight"

echo "== STEP 3: nsys + ncu profile per shape ==" >&2
for SHAPE in 4096 6144 8192; do
  ENTRY="sgemm_4warp_swizzle_${SHAPE}x${SHAPE}_grid"
  PTX="${ENTRY}.ptx"
  NREPS_NSYS=20
  NREPS_NCU=1   # ncu kernel-replay; 1 launch sufficient

  echo "--- shape M=${SHAPE} ---" >&2

  echo "  [nsys trace] M=${SHAPE} nreps=${NREPS_NSYS}" >&2
  ssh ${REMOTE} "cd ${REMOTE_DIR} && ${NSYS} profile -t cuda --force-overwrite=true -o nsys_M${SHAPE} ./host_one ${PTX} ${SHAPE} ${ENTRY} ${NREPS_NSYS} 2>&1" \
    | tee -a nsys_M${SHAPE}_run.log

  echo "  [nsys export sqlite + stats]" >&2
  ssh ${REMOTE} "cd ${REMOTE_DIR} && ${NSYS} stats --report cuda_gpu_kern_sum,cuda_gpu_mem_size_sum --format csv nsys_M${SHAPE}.nsys-rep 2>&1" \
    > nsys_M${SHAPE}_stats.csv 2>&1 || echo "  (nsys stats failed -- ok if older nsys)" >&2

  echo "  [ncu metrics] M=${SHAPE} nreps=${NREPS_NCU} (sudo for perfcounter perm)" >&2
  # CSV form (compact per-metric rows) + text form (human-readable section dumps)
  ssh ${REMOTE} "cd ${REMOTE_DIR} && sudo ${NCU} --target-processes all --csv --log-file ncu_M${SHAPE}.csv \
     --metrics l1tex__t_sector_hit_rate.pct,lts__t_sector_hit_rate.pct,dram__bytes.sum,dram__bytes_read.sum,dram__bytes_write.sum,dram__throughput.avg.pct_of_peak_sustained_elapsed,smsp__cycles_active.avg.pct_of_peak_sustained_elapsed,sm__warps_active.avg.per_cycle_active,sm__warps_active.avg.pct_of_peak_sustained_active,smsp__average_warp_latency_per_inst_issued.ratio,smsp__inst_executed.sum,smsp__pcsamp_warps_issue_stalled_long_scoreboard,smsp__pcsamp_warps_issue_stalled_short_scoreboard,smsp__pcsamp_warps_issue_stalled_mio_throttle,smsp__pcsamp_warps_issue_stalled_lg_throttle,smsp__pcsamp_warps_issue_stalled_drain,smsp__pcsamp_warps_issue_stalled_membar,smsp__pcsamp_warps_issue_stalled_branch_resolving,smsp__pcsamp_warps_issue_stalled_imc_miss,smsp__pcsamp_warps_issue_stalled_no_instruction,smsp__pcsamp_warps_issue_stalled_wait,smsp__pcsamp_warps_issue_stalled_dispatch_stall,smsp__pcsamp_warps_issue_stalled_not_selected,smsp__pcsamp_warps_issue_stalled_sleeping,smsp__pcsamp_warps_issue_stalled_tex_throttle,smsp__pcsamp_warps_issue_stalled_misc,gpc__cycles_elapsed.max \
     ./host_one ${PTX} ${SHAPE} ${ENTRY} ${NREPS_NCU} 2>&1" \
    | tee ncu_M${SHAPE}_csv_run.log

  echo "  [ncu sections]" >&2
  ssh ${REMOTE} "cd ${REMOTE_DIR} && sudo ${NCU} --target-processes all --log-file ncu_M${SHAPE}.txt ${NCU_SECTIONS} \
     ./host_one ${PTX} ${SHAPE} ${ENTRY} ${NREPS_NCU} 2>&1" \
    | tee ncu_M${SHAPE}_sec_run.log
done

echo "== STEP 4: pull artifacts back ==" >&2
for SHAPE in 4096 6144 8192; do
  scp -q "${REMOTE}:${REMOTE_DIR}/nsys_M${SHAPE}.nsys-rep" . 2>&1 || echo "  no nsys-rep M=${SHAPE}" >&2
  scp -q "${REMOTE}:${REMOTE_DIR}/ncu_M${SHAPE}.csv"        . 2>&1 || echo "  no ncu csv M=${SHAPE}" >&2
  scp -q "${REMOTE}:${REMOTE_DIR}/ncu_M${SHAPE}.txt"        . 2>&1 || echo "  no ncu txt M=${SHAPE}" >&2
done

echo "== DONE ==" >&2
