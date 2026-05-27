// Stage 1 forced self-compile artifact (2026-05-10)
// Reach status: DEFERRED — see doc/stage_1_closure_2026_05_10.md
//
// Invocation:
//   HEXA_MEM_UNLIMITED=1 RESOURCE_LOCAL_HEXA=1 \
//   timeout 1800 /Users/ghost/.hx/bin/hexa_real run \
//     compiler/main.hexa --emit=asm \
//     -o /tmp/stage_1_forced.s compiler/main.hexa
//
// Result: no .s produced. timeout(1) killed the run at 1800s wall.
// Process consumed 228.33s user CPU and 6.88s sys CPU in 1800s wall —
// ~13% CPU utilisation, indicating host contention starvation rather
// than progress. Peak RSS 238 MiB (well under the 3.5 GiB high-water
// mark from the post-A1 probe in stage1_punch_list_v2.md), confirming
// the run never crossed the splice → types phase boundary where memory
// growth dominates.
//
// Concurrent stage 1 attempts on the same host (pgrep snapshot at
// completion):
//   * PID 52351 — parallel agent #4 stage1_v4.s, 60+ min elapsed,
//     state R< (high-priority running). This is the contention source.
//   * PID 7166  — agent worktree test_keyword_audit run
//   * PID 63200 — wilson plugin test
//
// This .s placeholder is committed as evidence of the forced-run
// attempt and to anchor the closure doc reference. The next forced
// attempt must serialize against parallel #4 (or wait for it to land
// stage1_v4.s) before re-running with a cleared host.
//
// Known-defect note: this is a placeholder, not a real assembler
// output. `as` will reject it (only // comments). See known-defects
// list in doc/stage_1_closure_2026_05_10.md item KD-01.
