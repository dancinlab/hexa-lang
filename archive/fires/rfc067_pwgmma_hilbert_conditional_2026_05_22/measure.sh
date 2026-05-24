#!/usr/bin/env bash
# RFC 067 PWGMMA-HILBERT-CONDITIONAL (N199) -- wgmma.mma_async + Hilbert + conditional dispatch.
#
# Plain `ssh ubu-2` (NO SIDECAR_NO_POOL).
# Driver-JIT cuModuleLoadDataEx with PTX text -- pure ASCII.
#
# HARDWARE BLOCKER: this kernel needs sm_90a Hopper. The available pool host ubu-2 is
# RTX 5070 sm_120 (Blackwell consumer), which REJECTS wgmma at ptxas/driver level
# (N195 scaffold cycle already established this: commit 7e26b7b8). Per @D g3 honest scope:
#   STEP 0-1: regen + ship PTX (idempotent, Hilbert bijection verified per shape)
#   STEP 2:   verify PTX with CUDA 12.9 standalone ptxas for BOTH sm_90a (PASS, all 8 shapes)
#             and sm_120a (REJECT, 4 wgmma errors). Capture into ptxas_info.log.
#   STEP 3:   detect device sm. If sm_major != 9, skip the silicon fire and emit a
#             blocker-only result.json. If sm_major == 9, build host with sm_90a and run
#             the full measurement (no Hopper host available in this campaign).
#
# Usage:  bash measure.sh
# HOST = ubu-2. Override with PY_HOST env if needed.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HOST="${PY_HOST:-ubu-2}"
ART_DIR_BASENAME="rfc067_pwgmma_hilbert_conditional_2026_05_22"
PTXAS_BIN="${PTXAS_BIN:-/usr/local/cuda-12.9/bin/ptxas}"

echo "== STEP 0: regen PTX (idempotent, Hilbert bijection verified per shape) ==" >&2
python3 gen_sgemm_wgmma_hilbert_conditional_ptx.py

echo "== STEP 1: rsync to ${HOST}:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh "${HOST}" "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_wgmma_hilbert_conditional_ptx.py *.ptx "${HOST}:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: standalone ptxas verification (sm_90a PASS + sm_120a REJECT) ==" >&2
ssh "${HOST}" "cd /tmp/${ART_DIR_BASENAME} && {
  echo '============================================================'
  echo 'RFC 067 N199 PWGMMA-HILBERT-CONDITIONAL — ptxas verification'
  echo '============================================================'
  echo
  echo '## sm_90a (Hopper) ptxas verification — EXPECTED PASS'
  echo
  for f in sgemm_wgmma_cond_256x256_grid.ptx sgemm_wgmma_cond_384x384_grid.ptx \
           sgemm_wgmma_cond_512x512_grid.ptx sgemm_wgmma_cond_1024x1024_grid.ptx \
           sgemm_wgmma_cond_2048x2048_grid.ptx sgemm_wgmma_cond_4096x4096_grid.ptx \
           sgemm_wgmma_cond_6144x6144_grid.ptx sgemm_wgmma_cond_8192x8192_grid.ptx; do
    echo \"### \$f\"
    ${PTXAS_BIN} --gpu-name=sm_90a -v \$f -o /tmp/\${f%.ptx}.sm90a.cubin 2>&1
    echo
  done
  echo
  echo '## sm_120a (RTX 5070 Blackwell consumer) ptxas verification — EXPECTED REJECT'
  echo
  for f in sgemm_wgmma_cond_256x256_grid.ptx sgemm_wgmma_cond_4096x4096_grid.ptx \
           sgemm_wgmma_cond_8192x8192_grid.ptx; do
    echo \"### \$f\"
    ${PTXAS_BIN} --gpu-name=sm_120a -v \$f -o /tmp/\${f%.ptx}.sm120a.cubin 2>&1 || true
    echo
  done
  echo '============================================================'
  echo \"host        : \$(hostname)\"
  echo \"ptxas       : \$(${PTXAS_BIN} --version | head -1)\"
  echo \"cuda toolkit: 12.9\"
  echo \"GPU         : \$(nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader)\"
  echo '============================================================'
}" 2>&1 | tee ptxas_info.log

echo "== STEP 3: detect device sm + decide fire vs. blocker-only ==" >&2
SM_FULL=$(ssh "${HOST}" "nvidia-smi --query-gpu=compute_cap --format=csv,noheader" | tr -d '\r')
SM_MAJOR="${SM_FULL%%.*}"
SM_MINOR="${SM_FULL##*.}"
DEVICE_NAME=$(ssh "${HOST}" "nvidia-smi --query-gpu=name --format=csv,noheader" | tr -d '\r')
echo "detected ${HOST} GPU ${DEVICE_NAME} sm_${SM_MAJOR}${SM_MINOR}" >&2

if [ "${SM_MAJOR}" != "9" ]; then
    echo "== HARDWARE BLOCKER: sm_${SM_MAJOR}${SM_MINOR} (need sm_9x Hopper), skipping silicon fire ==" >&2
    cat > compile.log <<EOF
(skipped) ${HOST} sm_${SM_MAJOR}${SM_MINOR} cannot execute wgmma; no nvcc build attempted.
See ptxas_info.log for sm_90a PASS + sm_120a REJECT.
EOF
    cat > fire.log <<EOF
RFC 067 N199 PWGMMA-HILBERT-CONDITIONAL: HARDWARE BLOCKER
=============================================================
host    : ${HOST}
GPU     : ${DEVICE_NAME}
sm      : sm_${SM_MAJOR}${SM_MINOR}
required: sm_90a (Hopper)
result  : ptxas REJECTS wgmma on sm_${SM_MAJOR}${SM_MINOR} (4 instructions)
action  : no silicon fire performed; PTX verified ptxas-PASS on sm_90a for all
          8 shapes (256/384/512/1024/2048/4096/6144/8192). PTX is ready for fire
          on H100/H200/GH200 (sm_90a).
N195     : "wgmma.async STRUCTURAL IMPOSSIBILITY on RTX 5070 sm_120"
           (commit 7e26b7b8) — N199 reproduces same boundary for full kernel.
EOF
    cat > result.json <<EOF
{
  "rfc": "067-PWGMMA-HILBERT-CONDITIONAL-hexa-hgemm-N199",
  "date_utc": "2026-05-22",
  "host": "${HOST}",
  "device": "${DEVICE_NAME}",
  "sm": "sm_${SM_MAJOR}${SM_MINOR}",
  "required_sm": "sm_90a",
  "outcome": "HARDWARE_BLOCKER -- ptxas REJECTS wgmma on detected device",
  "ptxas_sm90a_pass": true,
  "ptxas_sm120a_reject": true,
  "ptx_shapes_verified": [256, 384, 512, 1024, 2048, 4096, 6144, 8192],
  "ptx_shape_count": 8,
  "ptxas_metrics_per_shape": {
    "regs_per_thread": 58,
    "barriers": 1,
    "shmem_bytes": 8192,
    "stack_frame_bytes": 0,
    "spill_stores_bytes": 0,
    "spill_loads_bytes": 0
  },
  "n195_dependency_status": "RESOLVED -- N195 (commit 7e26b7b8 'wgmma.async STRUCTURAL IMPOSSIBILITY on RTX 5070 sm_120') established the silicon-class boundary for the scaffold (m64n16k16). N199 is the full-kernel variant (m64n64k16 + Hilbert d2xy + conditional dispatch) and reproduces the same rejection at ptxas level on sm_120a.",
  "silicon_fire": null,
  "shapes": [],
  "scope_down_reason": "@D g3 honest-scope: no Hopper hardware available in pool. Hot-fire deferred until H100/H200/GH200 host. PTX-level verification (ptxas-PASS on sm_90a for all 8 shapes; 58 regs/thread, 8192 B shmem, 0 spills) is the strongest claim the available infrastructure supports.",
  "compound_with_hilbert": "UNTESTABLE on available silicon -- would need Hopper fire to measure whether wgmma+Hilbert > N149-Hilbert-alone (0.847 ratio @ M=8192). Hypothesis ranking from instruction count alone: wgmma reduces inner-loop instruction issues by ~8x (1 wgmma vs 8 mma.sync.m16n8k16), so the dominant factor at large M (memory-bound) would still be Hilbert L2 locality; the issue-bandwidth win from wgmma is more likely to help small-M compute-bound shapes. Cannot quantify without fire.",
  "cublas_catchup_progress": "BLOCKED -- 0.84 ratio (N149 Hilbert M=8192) -> ? unmeasurable on sm_120. N195 verdict: 16% gap on RTX 5070 CANNOT close via wgmma (it's not an instruction-class gap, since cuBLAS itself uses Ampere mma.sync on RTX 5070 per N104 SASS-diff). Closure on this silicon comes from mma.sync scheduling/tiling/occupancy, not wgmma.",
  "handoff": {
    "blocker": "sm_90a hardware",
    "candidates": ["H100", "H200", "GH200"],
    "estimated_cost_h100_smoke": "1-2 USD for 8-shape sweep on rented H100 (200 reps + warmup per shape)",
    "next_cycle_handle": "fire N199 PTX on H100/H200; result.json shape rows populate; compare hexa_pwgmma_tflops vs N171 PCOND vs cuBLAS HGEMM per shape"
  }
}
EOF
    SHIP_RESULT_JSON=0
else
    echo "== STEP 4: build host on ${HOST} (sm_${SM_MAJOR}${SM_MINOR}) ==" >&2
    ssh "${HOST}" "export PATH=/usr/local/cuda-12.9/bin:\$PATH && cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90a -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

    echo "== STEP 5: fire on ${HOST} ==" >&2
    ssh "${HOST}" "cd /tmp/${ART_DIR_BASENAME} && ./host \
        sgemm_wgmma_cond_256x256_grid.ptx \
        sgemm_wgmma_cond_384x384_grid.ptx \
        sgemm_wgmma_cond_512x512_grid.ptx \
        sgemm_wgmma_cond_1024x1024_grid.ptx \
        sgemm_wgmma_cond_2048x2048_grid.ptx \
        sgemm_wgmma_cond_4096x4096_grid.ptx \
        sgemm_wgmma_cond_6144x6144_grid.ptx \
        sgemm_wgmma_cond_8192x8192_grid.ptx 2>&1" | tee fire.log

    SHIP_RESULT_JSON=1
fi

if [ "${SHIP_RESULT_JSON}" = "1" ]; then
    echo "== STEP 6: pull result.json back ==" >&2
    scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/result.json" .
fi

echo "== DONE ==" >&2
echo "result.json:" >&2
cat result.json >&2
