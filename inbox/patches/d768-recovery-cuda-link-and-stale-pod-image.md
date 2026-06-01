# d768 recovery — two hexa-cloud gaps surfaced (2026-06-02)

Context: d768/12L CLM fire on a vast H100 (pod 38991004), deploy-gate = #2472 (forge FP64-conv→cuBLAS) + #2478 (idempotent rent). Fire succeeded (CE descent PASS, .clm recovered + HF-uploaded PRIVATE), but util = 0% and the pod required heavy manual repair.

## Gap 1 — `hexa run` never links cuBLAS, so #2472's forge GPU dispatch can't engage  [RESOLVED 2026-06-02]

RESOLUTION: `self/main.hexa` now has `cuda_link_decision(self_dir, c_file)` (after `os_clang_ldflags()`),
wired into the native `hexa build`/`hexa run` compile+link path. 3 rules:
  1. EXPLICIT — `HEXA_NO_CUDA=1` forces off; `HEXA_CUDA_LINK=1` forces on-intent.
  2. AUTO-DETECT — links CUDA iff the transpiled C uses a forge/flame device op
     (`forge_dispatch_matmul` or a `*_matmul_gpu` symbol — present only when the
     program actually drives the GPU dispatch).
  3. TOOLKIT GATE — even when wanted, falls back to CPU **with a clear log** unless
     BOTH nvcc and libcublas are present (never silently). On engage it nvcc-compiles
     `self/cuda/runtime_cuda.c` → cached `runtime_cuda.<sm>.o` (emitting the gitignored
     seed first if absent), compiles runtime.c+user with `-DHEXA_CUDA`, links
     `-lcublas -lcudart`.
Host selftest (mac, no nvcc): auto-detect fires on a forge program and honestly
falls back CPU-only with a log; CPU-path link line carries zero CUDA flags
(byte-identical legacy link); `HEXA_NO_CUDA`/`HEXA_CUDA_LINK` overrides honored.
GPU verification (H100 util before/after) — see CLM+KOSMOS.log.md Lane G.

---
ORIGINAL DIAGNOSIS:

- `hexa run <flame_program>` builds the user binary with `os_clang_ldflags()` (self/main.hexa:1186) = `-lm -lpthread` only on Linux. No `-DHEXA_CUDA`, no `-lcublas -lcudart`, no nvcc'd `runtime_cuda.o`.
- Result: forge's `_forge_dispatch_matmul_fp64 → hexa_farr_matmul_gpu` (#2472, runtime.c:8644) always takes the CPU fallback. Measured: PEAK=0% MEAN=0.000% over 1617 nvidia-smi samples; 0 MiB GPU mem; 67W idle; trainer at 100% on one CPU core.
- #2472 is necessary but NOT sufficient: the host-side `hexa run` link is the real F-RFC046 bottleneck.
- Ask: a `hexa run --cuda` (or auto-detect HEXA_CUDA host) build path that compiles runtime with `-DHEXA_CUDA`, nvcc-compiles `self/cuda/runtime_cuda.c` for the device arch, and links `-lcublas -lcudart`. Then a d768 fire can actually validate the cuBLAS path.

## Gap 2 — pre-baked pod hexa binary is unusable on a fresh vast H100
A vast pod whose base image ships a pre-installed hexa at `~/.hx/bin` required ALL of the following manual repair before `hexa run` worked (the driver's `[ -x hexa ] && skip-install` made it silently use the broken binary):
1. `hexa.real` (and `build/hexat`, `build/hexa_module_loader`) needed GLIBC_2.38 but Ubuntu 22.04 pod has 2.35 → `patchelf --set-interpreter <staged glibc-2.39 ld> --set-rpath ...` on every ELF.
2. The cloned `~/.hx/src/self/` had ZERO `.c` files — runtime.c + its ~22 `#include`d seed `.c` (runtime_core.c, native/*.c, forge/forge_tier_v1.c, cuda/*.c) are all gitignored and NOT in the release tarball (only a stale precompiled `runtime.a`). Had to ship the 44 seed `.c` from a working mac install and `clang -c runtime.c` natively.
- Ask: either (a) the linux release tarball ships `self/runtime.c` + seed `.c` (or a regen-on-install step), and (b) install.sh / drivers force-rebuild the binary from origin/main when the pre-baked one fails a `--version` smoke under the host glibc, instead of skipping install on mere presence.

## Workaround used (this fire)
patchelf all ELFs to a staged glibc-2.39 loader + scp the 44 seed `.c` from mac + `clang -O2 -D_GNU_SOURCE -DHEXA_CUDA -c self/runtime.c -o self/runtime.o`. After that `hexa run stdlib/flame/clm_prod.hexa` built+ran (CPU-only, per Gap 1).
