# forge cuda emit: fork-bomb recursion + large-content write failure (Lane-G util-RED root cause #3)

**Status:** FIXED on `laneg/devfeed-cudalink-integrated` (commits `27535d93d` #3a + `bb10154fb` #3b) — propose cherry-pick to main.
**Found on:** vast RTX-PRO-6000-Blackwell pod 39062745 ("laneg-utilgreen"), 2026-06-02, branch `laneg/devfeed-cudalink-integrated` (carries #2504 lever-b + #2505 lever-a + #2506 nvcc fwd-decl + cuda_link).
**Substrate:** GPU (Lane G) — separate from AKIDA (a_lane_akida_gpu_split).

## Symptom

A `HEXA_CUDA_LINK=1 hexa build stdlib/flame/clm_prod.hexa` spawned an UNBOUNDED FORK BOMB
(observed 1800+ procs) at the `[cuda] emitting runtime_cuda.c (seed absent)` step, never
producing `runtime_cuda.c`, GPU stays 0 MiB. The recursion is self-sustaining (procs reparent
to init PID 1) and survives killing the original build — it re-spawns faster than `pkill`.

## Root cause #3a — recursion under HEXA_CUDA_LINK=1 (`self/main.hexa` `cuda_link_decision`)

`cuda_link_decision()` emits `runtime_cuda.c` on demand via a nested `hexa run
runtime_cuda_emit.hexa`. Under a forced-on build (`HEXA_CUDA_LINK=1`) that env is **inherited**
by the child `hexa run`, whose own build of `runtime_cuda_emit.hexa` re-enters
`cuda_link_decision()` → sees `runtime_cuda.c` still absent (the parent emit has not finished) →
emits AGAIN → infinite recursion.

**Fix (#3a):** prefix the nested emit exec with `HEXA_NO_CUDA=1` (hits the `force_off`
short-circuit at the top of the fn) and clear `HEXA_CUDA_LINK`. The emit is pure C-string
generation — needs no GPU link. One-line env guard; byte-eq preserved.

```
-   exec("hexa run '" + ... + "/runtime_cuda_emit.hexa' '" + cuda_c + "' 2>&1 | tail -2")
+   exec("HEXA_NO_CUDA=1 HEXA_CUDA_LINK= hexa run '" + ... + "/runtime_cuda_emit.hexa' '" + cuda_c + "' 2>&1 | tail -2")
```

## Root cause #3b — large-content write silently dropped (`self/cuda/runtime_cuda_emit.hexa`)

With #3a, the recursion stops and the failure surfaces cleanly:
`[runtime_cuda_emit] FATAL: failed to write <path>`. The emit assembled the ENTIRE ~100KB+
(3967-line) `runtime_cuda.c` into ONE `exec()` command string (`cat > out <<'EOF' <c_text>
EOF`). The exec arg buffer truncates a command that large → the shell never received the full
heredoc → the file was never written. (This is the same class as the older "exec-heredoc fails on
the 169KB payload" note in forge-gpu-link-prebuilt-and-lcuda-and-seeds.md — now root-caused.)

**Fix (#3b):** write the emitted C straight to the file with the `write_file` builtin
(→ `rt_write_file`): no shell, no ARG_MAX limit, streams content to the fd. Same `c_text` →
byte-identical output.

```
-   let cmd = "cat > \"" + out_path + "\" <<'__HEXA_EMIT_EOF__'\n" + c_text + "__HEXA_EMIT_EOF__"
-   let _ = exec(cmd)
+   write_file(out_path, c_text)
```

## Verification (pod 39062745, RTX-PRO-6000-Blackwell, CUDA 12.4)

After both fixes the on-demand emit writes a full `runtime_cuda.c` (3967 lines, fwd-decls
present), `nvcc -x cu` compiles it EXIT 0 (555824-byte `.o`), and `clm_prod` links cublas +
cudart + **libcuda** + cublasLt (4 cuda libs) with `forge_dispatch_matmul_batched` +
`forge_dispatch_adamw` present. CUDA-link-ENGAGED count = 1. The trainer reaches the GPU
(device-resident memory grows past 14 GB) — the link/compile/emit chain is fully un-blocked.

## Remaining (NOT a hexa-lang bug — a perf finding)

With all three Lane-G defects fixed, the d768 forge fire still measures **util-RED** (peak 6%,
mean 0.8%) because the host-side per-step loop pegs one CPU core at ~100% while the GPU starves
(the F-RFC046 host-backward bottleneck). That is a throughput problem with known levers (device
im2col/adam are now on, but the interpreted-compiled per-step orchestration dominates), not a
build defect. The 3B/7B gate stays throughput-blocked.
