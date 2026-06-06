# HEXA-DOJO — step log (append-only)

## 2026-06-07 — domain init
- Tracks the dojo as the forge-CUDA build-trap absorption + kernel-authoring practice surface. 5 LAYER-A milestones from open handoffs: 677b84cd fork-bomb, 4a7841fe glibc, d751e2c4 stack-SIGKILL, d631a08f nvptx-exp-underflow, 0a848320 shfl-FP64.
- Honest scope (g5): dojo cures LAYER-A (build/toolchain); LAYER-B (serial kernel-DAG util ceiling) is HEXA-FUSION's fusion problem (graph-capture FALSIFIED, only lift = TF32 megakernel +5.5pp). dojo = recipe book, not oven.
- A1/A4/A5 = codegen/tooling fixes; A2/A3 = dojo-doc + preflight workarounds.

## 2026-06-07 — DOJO-A1 closed (🟢 emit-step verified · partial closed-negative)
- Recovered the 2 proven laneg fixes via `git fetch` + `git show 27535d93d bb10154fb`:
  #3a `27535d93d` = HEXA_NO_CUDA=1 guard on the nested runtime_cuda.c emit (kills the
  fork-bomb recursion under HEXA_CUDA_LINK=1); #3b `bb10154fb` = write_file builtin
  instead of a cat-heredoc-via-exec (the ~100KB write was silently dropped at E2BIG).
- FINDING vs current main (9b4f2c143): #3b is **already on main** — landed independently
  as #2630 (`8409117e2`); `runtime_cuda_emit.hexa::main()` already does
  `write_file(out_path, c_text)`. #3a targets `cuda_link_decision()` + the
  `HEXA_CUDA_LINK=1` OPT-IN link path, which was **never merged** to main
  (`grep HEXA_CUDA_LINK self/main.hexa` → rc=1; `cmd_build` reads neither env, has no
  nested emit). The opt-in path lived only on the lane-g/forge-gpu lineage
  (4f64ed119/8312a8cae), on-device fire BLOCKED-OUTAGE (0904b972d), never landed.
  → fork-bomb is STRUCTURALLY IMPOSSIBLE on main; nothing to port for #3a here.
- GATE (local, emit-step = the exact step that fork-bombed on laneg):
  `hexa run self/cuda/runtime_cuda_emit.hexa /tmp/out.c` → rc=0, **308919 B** written
  (≫100KB, not dropped), single short-lived process (no 1800+ proc storm).
  fork-bomb gone = YES · runtime_cuda.c full = YES. Verdict verbatim at
  `.verdicts/dojo-a1-cudalink-forkbomb/DOJO-A1.txt`.
- TODO (named): full `HEXA_CUDA_LINK=1 hexa build clm_prod.hexa` end-to-end nvcc/pod
  link not run — the opt-in link path is absent from main so there is nothing to link
  via that env. If the lane-g opt-in feature ever merges, re-port BOTH guards together
  and fire full-link confirm on a CUDA pod.
