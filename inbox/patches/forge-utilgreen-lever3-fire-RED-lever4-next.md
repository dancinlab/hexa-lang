# Lane-G util-GREEN: lever-3 util fire CLOSED 🔴 RED → lever-4 (fused step driver) is the real unblock

substrate = GPU (Lane-G, forge/flame). Separate from AKIDA (a_lane_akida_gpu_split).

## what was measured (g5 verbatim)

Clean single-driver H100 sm_90 (pod 38996679, 8×H100 80GB compute_cap 9.0, conflict-0),
lever-3 branch `lane-g/rfc046-lever3-batched-gemmfeed` @ a5d01f37f, self-host build.

- **3-gate PASS** (no CPU fire): CUDA-link ENGAGED (clm_prod binary links
  `_hx_cuda_farr_matmul_bt_gpu`/`_atb_gpu` + `cublasDgemmStridedBatched`); `nvcc -x cu -arch=sm_90`
  EXIT 0; `ldd clm_prod` → libcublas/libcudart/libcuda/libcublasLt.
- **pod byte-eq**: all oracles max|Δ|=0.0 (F-RFC046-GEMMFEED-EQ=1, F-RFC046-BATCHED-GEMMFEED-EQ=1,
  F-CLM-DEVFEED-{IM2COL,FWD,BWD,ADAM}-EQ=1, F-CLM-CONV2-BATCHED-{FWD,BWD}-EQ=1).
- **util fire** (CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1, d=1536 T=512 E=4 epochs=3 nwin=8, GPU0):
  - DESCENT 🟢 GREEN: CE 4.2974 → 3.79897, F-CLM-PROD-DESCENT=1.
  - util 🔴 RED: `n=349 PEAK=21.0% MEAN=0.5616% busy_mean=0.5782% pct>=20=2 mem_max=6331MiB`.

## finding

before(lever-2)=0.4999% → after(lever-3)=0.5616%. lever-3 dropped the DOMINANT 65% batched-expert
host repack (byte-eq GREEN proves the device path is bit-correct), yet MEAN util stayed flat.
GPU is device-resident (6.3 GB allocated, 119 W) but SM-starved between kernel launches.

⇒ The residual dominant bottleneck is NOT GEMM repack. It is the **interpreted per-step driver loop**
(F-RFC046 root): the step body dispatches ~30 separate builtin calls (1×fwd · 1×ce · 1×ce-grad ·
1×bwd · 20× separate `_adam`) through the interpreter, leaving the GPU idle between kernel launches.

## next unblock = lever-4 (fused on-device per-step driver)

- `forge_dispatch_train_step` — single fused builtin: device-resident param/grad/moment;
  fwd → loss → bwd → AdamW all on device; only scalar loss crosses to host.
- `forge_dispatch_adamw_group` — 20 tensors → 1 launch (collapse the 20× separate `_adam`).
- projected host boundary crossings/step: ~30 → ~2.
- oracles (byte-eq hard gate, max|Δ|=0.0): `F-RFC046-FUSED-STEP-EQ` + `F-RFC046-ADAMW-GROUP-EQ`.
- signature change → pod self-host build required (not a mac-only verify). util≥20% = fire verdict only.

## artifacts (recovered, anima state/laneg-lever3-utilfire/)

- laneg_l3_d1536_t512.clm  (14381125 B · sha256 34982a31022264f8104d9d877a4c115f3ce9e69d7ab85830a79fe9a3b20a6f7a · PRIVATE, closure-FAIL)
- utilfire_run.out · util_samples.csv (349 samples) · byteeq.log

closure: util RED → .clm PRIVATE; PUBLIC HF / 3B / 7B remain gated (util-GREEN NOT-before guard).
