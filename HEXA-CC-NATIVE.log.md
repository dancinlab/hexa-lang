# HEXA-CC-NATIVE — log

Append-only history sister of `HEXA-CC-NATIVE.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-01 — N5-pre STEP0b R2: recipe gap traversed; runtime drift decomposed (float_to_bits FIXED, __map_raw_len genuine-missing)

- [x] compiler-source parity confirmed: git diff origin/main HEAD -- compiler/ self/ = EMPTY (current-main source)
- [x] self/ tree populated .c-ONLY (round-1 broke transpile via cp -R of non-.c entries); runtime.c full #include set enumerated (forge/ + 18 native/ + core + hi_gen) -> all includes resolve, clang reaches real C compile of 40k-line ap_post.c
- [x] drift symbol (1) float_to_bits/bits_to_float = STALE: current runtime_core_emit.hexa L1505-07 emits it, 2026-05-26 core has 0 -> `hexa run self/runtime_core_emit.hexa self/runtime_core.c` regen (LOCAL, routing-immune, 382923B, float_to_bits x4) RESOLVED it
- [x] drift symbol (2) __map_raw_len = GENUINE-MISSING: emitted only by self/codegen.hexa, defined in NO runtime source (regen core/hi_gen + 2026-05-26 runtime.c all 0) + fn->HexaVal type mismatch at ap_post.c:40446 = a real defect on main's native self-host path
- [x] regen mechanism PROVEN; refused to guess __map_raw_len's impl (honesty) -> deferred to scoped runtime fix; no binary kept, no flip, live untouched
- [ ] NEXT N5-pre-rt: add __map_raw_len (+ resolve :40446) to runtime SSOT matching codegen's emit contract -> regen -> rebuild -> smoke exit42 -> 181 --emit=obj re-measure (original STEP0 goal)
- verdict: `.verdicts/hexa-cc-native/F-HEXA-CC-NATIVE-N5PRE-STEP0B-R2.txt`

## 2026-06-01 — N5-pre STEP0b (darwin) BLOCKED: build-recipe gap, same root cause as BUILDFLOOR

- [x] darwin-arm64 (mini, policy-designated darwin host) rebuild attempt in isolated worktree off main 9be1ed393, guarded (nice -n 19 + background; no kill-storm)
- [x] build_aprime.sh stages 1-3 PASS fast (~12s): flatten 39932L -> transpile 43366L C -> post-process
- [x] stage-4 clang FAIL chain: self/runtime.c absent (generated "B9 SSOT", untracked) -> runtime_core.c -> native/tensor_kernels.c (+33 .c) -> dumping generated tree into self/ corrupts transpile
- [x] root cause confirmed = build_aprime.sh not self-contained; depends on pre-generated build/self/ C-artifact tree (on-disk copy 2026-05-26 stale vs current self/runtime.h 2026-06-01)
- [x] g5/g63 STOP: refused Frankenstein build (stale-artifact + current-source splice) -> would fabricate the diagnostic count; no binary kept, worktree reset clean
- [x] darwin blocker = recipe gap; distinct from Linux blocker (-arch arm64 / glibc malloc.h / hxlcl_* shims). Both upstream of the 181-diagnostic measurement.
- [ ] NEXT: bundle B9 runtime regen as build_aprime stage-0 (hexa-native, .sh edits governance-blocked) OR run existing B9 pipeline standalone first -> fresh consistent build/self tree -> rebuild -> 181 re-measure
- verdict: `.verdicts/hexa-cc-native/F-HEXA-CC-NATIVE-N5PRE-STEP0B-DARWIN.txt`

