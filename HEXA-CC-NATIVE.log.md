# HEXA-CC-NATIVE — log

Append-only history sister of `HEXA-CC-NATIVE.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-01 — N5-pre STEP0 MEASURED 🟢: 181→144 on a current-source aprime_cc (3+ session blocker broken)

- [x] made the bootstrap chain current: (1) `hexa cc` rebuilt transpiler -> ~/.hx/bin/self/native/hexa_v2 (lowers __map_raw_len), (2) `hexa run runtime_core_emit.hexa` regen runtime (float_to_bits), (3) clean worktree off main 8face82b6
- [x] build_aprime.sh OK: transpile 43502L -> clang 1435712B Mach-O arm64 -> smoke exit(42)==42 PASS
- [x] falsifier PASS: intentional undefined name -> HX2001 + exit 1 (measurement tool honest)
- [x] measured (tag-based): HX2001 104->80 (-24, stale intrinsics resolved, ~28 predicted), HX4001 13->0 (-13), HX0011/3001/3004/2003 unchanged; TOTAL 181->144 (-37)
- [x] STEP0 goal (separate stale from genuine on a current binary) ACHIEVED; triage prediction confirmed
- [x] remaining 144: as-cast cascade ~81 (`as`x61 + `)`x7 + HX0011x13) | genuine-missing ~9 (bytes_to_str_raw x7, __arr_alloc_items_zero(_int) x2) | HexaVal carrier gaps (3001/3004/2003)
- [x] repro recipe PROVEN + fast (~15s) -> each STEP1..N fix verifiable by rebuild+re-measure
- [ ] NEXT STEP1: parser as-cast (compiler/parse/parser.hexa + ast.hexa) -> expect 144 -> ~63
- N5 not flipped (fixpoint not reached); STEP0 sub-state BLOCKED -> MEASURED
- verdict: `.verdicts/hexa-cc-native/F-HEXA-CC-NATIVE-N5PRE-STEP0-MEASURED.txt`

## 2026-06-01 — CORRECTION to R2: __map_raw_len is NOT runtime-missing (retracting overclaim)

- [x] verified __map_raw_len IS a recognized builtin: bind.hexa:1044 allowlist + codegen.hexa:6161 lowers it to HX_MAP_LEN
- [x] verified HX_MAP_LEN IS defined in runtime: runtime_core.c:1045 + current emit SSOT:1208 — nothing missing
- [x] real mechanism = bootstrap transpiler self/native/hexat emits literal __map_raw_len (lowers siblings __str/__arr_raw_len but not __map) = transpiler-lowering gap = same stale-bootstrap family as the ~28 STALE-BINARY; NOT a defect on main
- [x] RETRACTED the R2 "genuine-missing runtime symbol / real defect on main's self-host path" claim (anti-fabrication)
- [x] float_to_bits round-2 finding (stale runtime_core healed by emit-SSOT regen) STANDS
- corrected frontier: regenerate the bootstrap chain (hexat/aprime_cc) from current builtins so __map_raw_len lowers

## 2026-06-01 — N5-pre STEP0b R2: recipe gap traversed; runtime drift decomposed (float_to_bits FIXED, __map_raw_len mischaracterized — see CORRECTION above)

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

