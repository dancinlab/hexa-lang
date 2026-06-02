# F-RFC046 lever-4 — util fire HELD (BLOCKED-OUTAGE), reproduction kit

status: **SOURCE LANDED (#2543 MERGED) · host byte-eq GREEN · on-device 3-gate + util fire HELD (vast.ai SSH transport outage)**
substrate: GPU / Lane-G / FORGE-UTILGREEN. a_lane_akida_gpu_split (NEVER merged with AKIDA/Lane-A).
date: 2026-06-02

## what landed

lever-4 = the fused on-device per-step driver, the named F-RFC046 ROOT unblock after
lever-3's util-RED (PEAK 21% transient · MEAN 0.5616% · n=349). The precisely-isolated
residual is the interpreted host per-step driver loop: each step dispatched ~17 separate
`forge_dispatch_adamw` calls, each its own H2D(W,g,m,v)→launch→cudaDeviceSynchronize→
D2H(W,m,v), so the GPU idled between 17 microsecond-latency launches/step (NOT
link/compile/emit/scale/device-math — all closed by lever a/b/1/2/3).

lever-4 builtin `forge_dispatch_adamw_group(W_ids, g_ids, m_ids, v_ids, n_sizes, count, t)`
collapses the whole AdamW param group into ONE host crossing (CUDA: H2D all → `count`
back-to-back `_hx_k_adamw_step_inplace` launches with NO per-tensor host sync → ONE
`cudaDeviceSynchronize` → D2H all). Byte-eq to `count` serial
`_hx_cuda_farr_adamw_step_inplace_gpu` / `opt_adamw_step` by construction. Projection
~30→~11 host crossings/step.

LANDED (#2543, stacked on lever-3 #2528): self/runtime.h decl · self/codegen.hexa 7-arg
lowering · self/cuda/runtime_cuda_emit.hexa GPU kernel `_hx_cuda_farr_adamw_group_gpu` ·
inbox/patches/forge-devfeed-lever4-fused-step-driver-runtime-c-fragment.c.txt (host wrapper) ·
stdlib/flame/clm_prod.hexa (`_adam_group` + 17-tensor handle arrays built ONCE before the
step loop; in-loop 17× `_adam` → ONE `_adam_group`) · stdlib/flame/clm_fused_step_eq.hexa.

## host byte-eq GREEN (mac `hexa run`, $0, g5 verbatim)

```
F-RFC046-ADAMW-GROUP-EQ = 1
F-RFC046-FUSED-STEP-EQ = 1
max|Δ| (grouped vs per-tensor serial opt_adamw_step, final W+m+v) = 0.0
PASS — fused AdamW group byte-eq to per-tensor serial opt_adamw_step
```

The prebuilt mac runtime.o lacks the new builtin (same constraint as lever-2/3 batched
builtins), so the mac oracle proves the group iteration/handle-pack contract via the exact
no-CUDA fallback. The real ON-DEVICE `F-RFC046-FUSED-STEP-EQ` re-runs on the pod self-host
build where the builtin engages.

## why the fire is HELD (BLOCKED-OUTAGE — NOT a code failure)

The on-device 3-gate (CUDA link ENGAGED · nvcc -x cu sm_90 EXIT 0 · clm_prod links the
fused dispatch) + the util fire (CLM_PROD_DEVFEED=1 + CLM_PROD_BATCHED=1 + the fused
driver, d~1536/T~512) require an SSH-reachable H100 sm_90. Both candidate pods went dark:
- the pre-armed util-verify H100 (vast 39126604, sm_90) went SSH-dark mid-session
  (`ssh3.vast.ai:16604 Connection refused`) and dropped from the pod list.
- a fresh H100 sm_90 (vast 39131850, compute_cap 9.0) was rented, the full fresh-pod
  driver authored + uploaded, but its SSH (`ssh7.vast.ai:11850` / `156.19.254.8`) is ALSO
  persistently refused across a full 10/30/60/120/240s backoff — a vast.ai transport
  outage spanning both pods.

No util number was produced; NO fabricated GREEN (a_completeness_over_cheap ·
a_scale_honest_scope). util before(lever-3) PEAK 21%/MEAN 0.5616% → after(lever-4) = NOT
MEASURED. The fire is HELD pending an SSH-reachable H100 sm_90.

## reproduction kit (run the moment a pod is reachable)

1. `forge-devfeed-lever4-fresh-pod-build-driver.sh` — single detached nohup driver:
   CUDA-toolkit-12-4 install (sm_90 needs ≥11.8; distro nvidia-cuda-toolkit is 11.5 = sm_86
   max, fails -arch=sm_90) → clone `lane-g/rfc046-lever3-batched-gemmfeed` (lever-4 merged
   there) → `tool/restore_frozen_seeds` base runtime.c → splice lever a/2/3/4 fragments →
   self-host build → pre-emit runtime_cuda.c → GATE1/2/3 → byte-eq (all oracles +
   clm_fused_step_eq, STOP on drift) → util fire d=1536/T=512/E=2/epochs=3. Logs to
   `/root/lever4.log`. SUCCESS = util≥20% (PEAK+MEAN) AND descent GREEN, g5 verbatim.
2. `forge-devfeed-lever2-unbatched-bt-atb-runtime-c-fragment.c.txt` — the un-batched
   lever-2 `matmul_bt`/`matmul_atb` wrapper bodies, RECONSTRUCTED from the runtime.h decls
   + the lever-2 byte-eq-fix host fallbacks. The original #2515/403735b29 bodies lived only
   in the lost pod's `runtime_lever3.c` seed and were never captured as a standalone
   fragment; this closes that reconstruction gap permanently. The byte-eq oracle
   (clm_gemmfeed_eq.hexa, F-RFC046-GEMMFEED-EQ) is the HARD gate that catches any drift.

## if the fire lands util RED again

Then lever-4 alone is insufficient and the next bottleneck is the REMAINING ~10 host
crossings/step (1×fwd · 1×ce · 1×ce-grad · 1×bwd + the nn_* elementwise glue). The next
lever = `forge_dispatch_train_step` (the DESIGN.md's second half — a single fully-fused
device step that keeps param/grad/moment device-resident and returns only the scalar loss,
projecting ~11→~2 host crossings/step). Oracle `F-RFC046-TRAIN-STEP-EQ` max|Δ|=0.0.
