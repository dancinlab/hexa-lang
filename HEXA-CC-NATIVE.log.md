# HEXA-CC-NATIVE — log

Append-only history sister of `HEXA-CC-NATIVE.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-01 — N5-pre STEP0b (darwin) BLOCKED: build-recipe gap, same root cause as BUILDFLOOR

- [x] darwin-arm64 (mini, policy-designated darwin host) rebuild attempt in isolated worktree off main 9be1ed393, guarded (nice -n 19 + background; no kill-storm)
- [x] build_aprime.sh stages 1-3 PASS fast (~12s): flatten 39932L -> transpile 43366L C -> post-process
- [x] stage-4 clang FAIL chain: self/runtime.c absent (generated "B9 SSOT", untracked) -> runtime_core.c -> native/tensor_kernels.c (+33 .c) -> dumping generated tree into self/ corrupts transpile
- [x] root cause confirmed = build_aprime.sh not self-contained; depends on pre-generated build/self/ C-artifact tree (on-disk copy 2026-05-26 stale vs current self/runtime.h 2026-06-01)
- [x] g5/g63 STOP: refused Frankenstein build (stale-artifact + current-source splice) -> would fabricate the diagnostic count; no binary kept, worktree reset clean
- [x] darwin blocker = recipe gap; distinct from Linux blocker (-arch arm64 / glibc malloc.h / hxlcl_* shims). Both upstream of the 181-diagnostic measurement.
- [ ] NEXT: bundle B9 runtime regen as build_aprime stage-0 (hexa-native, .sh edits governance-blocked) OR run existing B9 pipeline standalone first -> fresh consistent build/self tree -> rebuild -> 181 re-measure
- verdict: `.verdicts/hexa-cc-native/F-HEXA-CC-NATIVE-N5PRE-STEP0B-DARWIN.txt`

