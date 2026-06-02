# MISCOMPILE-ZERO — log

Append-only history sister of `MISCOMPILE-ZERO.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-02 — regression guard: lightweight miscompile-zero gate landed

Milestone: "regression guard — a CI gate that fails on ANY `gen2 --emit=obj`
ENCODE-MISS / spurious udf". Built a fast gate (seconds, not the 68-min full
self-emit) covering every miscompile class fixed to reach byte-eq graduation.

- [x] Corpus `self/test/miscompile_zero/*.hexa` — one tiny program per class:
      - c1_hex_literal     — hex-literal lowering (0xNN->0, 47421c89c)
      - c2_stack_locals    — STP/LDP `[sp,#N]` stack-slot codegen (the literal
                             "ENCODE-MISS: STP/LDP mem-parse-fail" signature)
      - c3_struct_ctor     — aggregate construct + field load (aliasing-adjacent)
      - c4_f64_literal     — f64 __literal8 const pool + __DATA reloc (#2509)
      - c5_multi_fn_alias  — multi-fn bodies + shared module global + .ends_with
                             string-compare cascade (953c8824b / hex downstream)
- [x] Gate `tool/miscompile_zero_gate.sh` — native --emit=obj each program,
      assert rc=0 + 0 ENCODE-MISS (stderr grep) + 0 spurious udf (otool/objdump
      disasm) + non-empty obj; EXIT NONZERO on any. Portable via env
      (HEXA_NATIVE_CC / HEXA_CC_PREARGS / HEXA_TARGET / MCZERO_OUT). NO /tmp
      default (writes under repo `.mczero-gate-out` or MCZERO_OUT). Honest rc
      (no pipe-masking).
- [x] VERIFIED on GHOST against the graduated gen2_fix native compiler:
      5/5 PASS, real rc=0 (0 ENCODE-MISS, 0 udf across all classes).
- [x] NEGATIVE-TESTED: a shim emitting a `udf #0` object trips the gate ->
      FAIL, real rc=1. Detection proven in both directions.
- [x] CI wired: `.github/workflows/miscompile-zero-gate.yml` builds `./hexa`
      via the shared `tool/release_build` on macos-latest (arm64 — same
      arm64-apple-darwin emit + otool path) then runs the gate. Path-filtered
      on compiler/self/corpus/gate changes.
- [x] One-line ghost reference run (proven host):
      `HEXA_NATIVE_CC=~/dancinlab/selfhost-work/gen2_fix bash tool/miscompile_zero_gate.sh`
- [ ] follow-up: broaden corpus + promote into the standard `hexa verify` suite
      (domain `## deferred`).

