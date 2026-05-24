#!/usr/bin/env bash
# RFC 067 P-nsight-Hilbert -- profile N149 Hilbert-curve CTA-swizzle 4-warp 64x64
# hexa HGEMM at M=6144 + M=8192 on ubu-2 RTX 5070 using ncu (+ nsys sanity).
#
# Mechanism-confirmation cycle for N149's Hilbert-beats-super-block result:
#   N149 real perf: M=6144 ratio 0.834 (+26.1% over N134 super-block),
#                   M=8192 ratio 0.847 (+34.6% over N134 super-block).
#   N157 measured super-block (Pattern A) L2 hit: M=6144 86.94%, M=8192 87.07%.
#   N140 no-swizzle baseline:                     M=6144 56.72%, M=8192 50.44%.
# Prediction: Hilbert's tighter 2D blob pushes L2 hit > super-block's 87% plateau.
#
# Plain `ssh ubu-2` (NO SIDECAR_NO_POOL).
# PTX reused byte-identical from N149 artifact (pure ASCII, driver-JIT).
# host_hilbert.c == N157 host_one.c with the Hilbert p x p (next_pow2) launch grid
#   instead of side x side; kernel internally d2xy + padding early-return.
# Same ncu metric + section lists as N157 (extracted_metrics.csv lineage) for a
# clean 3-way diff: no-swizzle (N140) vs super-block (N157) vs Hilbert (this).
#
# Outputs (locally in this directory):
#   - compile.log
#   - ncu_M{6144,8192}.csv          (raw per-metric CSV, same metric list as N157)
#   - ncu_M{6144,8192}_sections.txt (human-readable section dumps)
#   - nsys_M{6144,8192}_run.log + nsys_M*.nsys-rep (sanity timing, non-replay)
#   - fire.log (full ssh stdout)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REMOTE=ubu-2
ART_BASENAME="rfc067_pnsight_hilbert_profile_2026_05_22"
REMOTE_DIR="/tmp/${ART_BASENAME}"

echo "== STEP 1: stage to ${REMOTE}:${REMOTE_DIR}/ ==" >&2
ssh ${REMOTE} "mkdir -p ${REMOTE_DIR}"
scp -q host_hilbert.c "${REMOTE}:${REMOTE_DIR}/"
scp -q sgemm_4warp_hilbert_6144x6144_grid.ptx "${REMOTE}:${REMOTE_DIR}/"
scp -q sgemm_4warp_hilbert_8192x8192_grid.ptx "${REMOTE}:${REMOTE_DIR}/"

echo "== STEP 2: build host_hilbert on ${REMOTE} ==" >&2
ssh ${REMOTE} "cd ${REMOTE_DIR} && /usr/local/cuda/bin/nvcc -O2 -arch=sm_90 -o host_hilbert host_hilbert.c -lcuda -lcublas -lm 2>&1" | tee compile.log

NCU=/usr/local/cuda/bin/ncu
NSYS=/usr/local/cuda/bin/nsys
# fall back to PATH ncu/nsys if cuda symlinks differ
ssh ${REMOTE} "test -x ${NCU}" || NCU=ncu
ssh ${REMOTE} "test -x ${NSYS}" || NSYS=nsys

# Same NCU section list as N157 -- memory / scheduler / occupancy.
NCU_SECTIONS="--section MemoryWorkloadAnalysis --section MemoryWorkloadAnalysis_Chart --section SchedulerStats --section WarpStateStats --section Occupancy --section LaunchStats --section SpeedOfLight"

# Same metric list as N157 (extracted_metrics.csv lineage).
NCU_METRICS="l1tex__t_sector_hit_rate.pct,lts__t_sector_hit_rate.pct,dram__bytes.sum,dram__bytes_read.sum,dram__bytes_write.sum,dram__throughput.avg.pct_of_peak_sustained_elapsed,smsp__cycles_active.avg.pct_of_peak_sustained_elapsed,sm__warps_active.avg.per_cycle_active,sm__warps_active.avg.pct_of_peak_sustained_active,smsp__average_warp_latency_per_inst_issued.ratio,smsp__inst_executed.sum,smsp__pcsamp_warps_issue_stalled_long_scoreboard,smsp__pcsamp_warps_issue_stalled_short_scoreboard,smsp__pcsamp_warps_issue_stalled_mio_throttle,smsp__pcsamp_warps_issue_stalled_lg_throttle,smsp__pcsamp_warps_issue_stalled_drain,smsp__pcsamp_warps_issue_stalled_membar,smsp__pcsamp_warps_issue_stalled_branch_resolving,smsp__pcsamp_warps_issue_stalled_imc_miss,smsp__pcsamp_warps_issue_stalled_no_instruction,smsp__pcsamp_warps_issue_stalled_wait,smsp__pcsamp_warps_issue_stalled_dispatch_stall,smsp__pcsamp_warps_issue_stalled_not_selected,smsp__pcsamp_warps_issue_stalled_sleeping,smsp__pcsamp_warps_issue_stalled_tex_throttle,smsp__pcsamp_warps_issue_stalled_misc,gpc__cycles_elapsed.max"

echo "== STEP 3: ncu + nsys profile per shape (M=6144, M=8192) ==" >&2
for SHAPE in 6144 8192; do
  ENTRY="sgemm_4warp_hilbert_${SHAPE}x${SHAPE}_grid"
  PTX="${ENTRY}.ptx"
  NREPS_NSYS=20
  NREPS_NCU=1

  echo "--- shape M=${SHAPE} ---" >&2

  echo "  [nsys trace] M=${SHAPE} nreps=${NREPS_NSYS}" >&2
  ssh ${REMOTE} "cd ${REMOTE_DIR} && ${NSYS} profile -t cuda --force-overwrite=true -o nsys_M${SHAPE} ./host_hilbert ${PTX} ${SHAPE} ${ENTRY} ${NREPS_NSYS} 2>&1" \
    | tee nsys_M${SHAPE}_run.log || echo "  (nsys M=${SHAPE} failed -- continuing)" >&2

  echo "  [ncu metrics CSV] M=${SHAPE} (sudo for perfcounter perm; RmProfilingAdminOnly=1)" >&2
  ssh ${REMOTE} "cd ${REMOTE_DIR} && sudo ${NCU} --target-processes all --csv --log-file ncu_M${SHAPE}.csv \
     --metrics ${NCU_METRICS} \
     ./host_hilbert ${PTX} ${SHAPE} ${ENTRY} ${NREPS_NCU} 2>&1" \
    | tee ncu_M${SHAPE}_csv_run.log

  echo "  [ncu sections] M=${SHAPE}" >&2
  ssh ${REMOTE} "cd ${REMOTE_DIR} && sudo ${NCU} --target-processes all --log-file ncu_M${SHAPE}_sections.txt ${NCU_SECTIONS} \
     ./host_hilbert ${PTX} ${SHAPE} ${ENTRY} ${NREPS_NCU} 2>&1" \
    | tee ncu_M${SHAPE}_sec_run.log
done

echo "== STEP 4: pull artifacts back ==" >&2
for SHAPE in 6144 8192; do
  scp -q "${REMOTE}:${REMOTE_DIR}/ncu_M${SHAPE}.csv"          . 2>&1 || echo "  no ncu csv M=${SHAPE}" >&2
  scp -q "${REMOTE}:${REMOTE_DIR}/ncu_M${SHAPE}_sections.txt" . 2>&1 || echo "  no ncu sections M=${SHAPE}" >&2
  scp -q "${REMOTE}:${REMOTE_DIR}/nsys_M${SHAPE}.nsys-rep"    . 2>&1 || echo "  no nsys-rep M=${SHAPE}" >&2
done

echo "== DONE ==" >&2
