# MAIN

@title: 🎯 MAIN — current active thrust (flame + forge improvement on FREE resources)

@goal: Keep improving flame (NN-training stdlib) + forge (GPU compute substrate) using ONLY free
resources (sidecar pool aiden/summer RTX 5070 · pi5-akida · ghost + local CPU/code), ZERO vast by
default (user-approved one-shot H100 rentals are the only exception, each torn down to leak 0). The
live frontier right now: push the hexa-owned own-GEMM toward cuBLAS-TF32 parity at MORE shapes —
bit-exactly (rel_rms 0) — and keep every public claim honest (matched-dtype, no apples-to-oranges).
This is the top-level tracker; the deep work lives in [[HEXA-0POD]] (60 OP rounds, OP-1→OP-60) + [[HEXA-BENCH]]
+ [[HEXA-FUSION]]. Each round: pick a 0-pod-feasible improvement, verify on a free GPU (byte-eq /
bit-exact gates), land it, loop — run via `/deep-dive` (심층 탐구).

## milestones (current — in flight / next)

- [x] **TF32 gap-close SETTLED (OP-52/55 · H100)** — the T4 lever family was built bit-exactly and
      measured: CTA-swizzle −1.6% (OP-52 closed-neg), 128×256 t256e −7.1% via wgmma serialization ptxas
      C7515 (OP-55 closed-neg), t256/MODE7 persistent already closed-neg (OP-45-GPU). The @D=4096 ~1.5×
      sub-parity gap vs cuBLAS-TF32 is **bit-exactness-bound** — the T4 single-pass-tile lever family is
      exhausted closed-neg while holding rel_rms 0. own-GEMM = bit-exact-parity-not-beat is the honest final.
- [x] **own-GEMM boundary measured + documented** — route-(a) = 1.08× cuBLAS-TF32 PARITY @D=2048 (rel_rms 0),
      ~1.5× @D=4096 (shape-rigid); OP-45/49/50 + OP-45-GPU. Boundary is in `docs/forge-routea-shape-adaptive.md`.
- [x] **honest docs corrected** — README + `FLAME+FORGE-vs-PYTORCH+CUBLAS.md` lead with the FAIR
      matched-dtype result (FP64 flame ties/wins; TF32 torch 2-8×), NOT the retired apples-to-oranges
      ~1656× figure (#3113). `## honest-number discipline` added to prevent recurrence.
- [x] **machine-independent bit-exact training** — flame trains byte-identically across 6 environments /
      4 architecture-libc combos, no libm on the step path, golden-fold CI tripwire (the campaign flagship).
- [x] **selector operationalized (OP-60)** — the OP-49/53 cost-model-validated `select_config(D,M,N,K)`
      is now an importable launch-dict + a regression-LOCK test (`test_routea_selector.py`, asserts the
      measured-correct pick per canonical shape — fails if a future edit picks a measured-bad config) +
      a machine-readable `routea_selection.json`. Design → tested, regression-protected artifact (#3165).
- [ ] **NEXT (deferred, non-0-pod)** — SELFHOST-NEXT const-fold + atof + vsnprintf seed-promote bundle
      (OP-37b/40/44/39b) on a build host; see `docs/selfhost-next-constfold-promote.md`.

## links

- [[HEXA-0POD]] — the 0-pod improvement loop (84 milestones, the main work surface)
- [[HEXA-BENCH]] — flame vs PyTorch FAIR matched-dtype benchmark (F-BENCH-1 = the speed authority)
- [[HEXA-FUSION]] — the W-ladder own-GEMM / wgmma kernel campaign
- `/deep-dive` (심층 탐구) — the self-generating round driver for this thrust
