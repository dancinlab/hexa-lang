@title: 🛠️ MISCOMPILE-ZERO — post-self-host miscompile hardening

@goal: AFTER self-host completion (gen2 byte-eq fixpoint), continuously drive and KEEP gen2's native codegen at MISCOMPILE-ZERO — catch and fix every further native-codegen miscompile (ENCODE-MISS / spurious udf / wrong-codegen) exposed as the self-hosted compiler is exercised on broader code, refining onward after completion.

# MISCOMPILE-ZERO — current state

Pre-created hardening track. Like SELFHOST-NEXT, its START CRITERION is the
completion of the work in flight NOW — the self-host byte-eq fixpoint campaign
(tracked in memory `project_selfhost_gate_reduction` + the active self-host
domain). This domain does NOT begin until gen2 self-emits a byte-identical
object (byte-eq graduation). It is the "keep it at zero, then polish" lane that
follows graduation.

The pre-completion drilling (peel each linker + native-codegen miscompile wall
to first reach byte-eq) is NOT this domain — it is the active campaign. Landed
walls so far (context, on `cc-native/selfhost-ghost`): hexa_ld __literal8
(5f38d7eb4) · hexa_ld __DATA UNSIGNED (23207ce70) · hexa_ld __mod_init_func
(07d8556d1) · lower-aliasing _lr_ctx_clear (953c8824b) · gen2 `_ends_with`
native mis-eval (in flight). When byte-eq lands, MISCOMPILE-ZERO opens here.

## milestones

- [ ] ENTRY GATE — self-host byte-eq fixpoint achieved (gen2 emits cc-gen3.o == cc-prc2, 0 ENCODE-MISS / 0 udf)
- [x] regression guard: a CI gate that fails on ANY `gen2 --emit=obj` ENCODE-MISS / spurious udf (keep the floor at zero) — `tool/miscompile_zero_gate.sh` + corpus `self/test/miscompile_zero/` + `.github/workflows/miscompile-zero-gate.yml`; PASS 5/5 on graduated gen2_fix, FAIL on udf shim
- [x] broaden the self-emit corpus beyond the compiler flat — exercise gen2 native codegen on diverse stdlib / app programs, sweep for new miscompiles — 82-program broad sweep on GHOST gen2_fix = CLEAN (0 ENCODE-MISS / 0 udf / 82 oracle-asm-match modulo benign label hash); verdict `.verdicts/miscompile-zero-sweep/CLEAN-SWEEP-82.txt`; corpus widened 6→10 (c6 closures · c7 recursion+array · c8 string-methods · c9 branch-control · c10 try/catch)
- [x] catalogue the native-codegen miscompile CLASS (index/slice/char_code, 2-reg value ABI, aliasing, string-intern) as targeted codegen tests so regressions (cf. the cycle-41 `.truncate` regression) can't silently return — `self/test/miscompile_class/` (7 PRIMITIVE-level tests m1..m7) + standalone runner `run.sh` (emit asm-oracle 0 ENCODE-MISS/0 udf → clang link → RUN real rc); 7/7 PASS on graduated gen2_fix (ghost), RUNNER-EXIT=0; g63-discriminating (tamper → rc=1 names the class); verdict `.verdicts/miscompile-class/CLASS-TESTS.txt`; additive, gates untouched
- [ ] each newly-exposed native-codegen miscompile → its own fix + byte-verify vs clang oracle, driven to zero
- [x] linker determinism: make hexa_ld output byte-deterministic (relink gen2 == gen2b; prior diff @byte ~1924664 symtab tail) so byte-eq holds across rebuilds — VERIFIED + GATED: re-link of the 3.2MB cc-prc2-fix.o twice gives an identical SHA256 (symtab/strtab tail deterministic, wall closed); `tool/determinism_gate.sh` + `.github/workflows/determinism-gate.yml` lock re-emit + relink byte-eq; PASS 10/10 on graduated gen2_fix + hld_fixed

## deferred

- promote the miscompile-zero corpus into the standard `hexa verify` gate suite
- fuzz / differential-test gen2-native vs aprime-C codegen across random programs to surface latent miscompiles before users hit them
- track miscompile-zero as a perf-stable property (no codegen regression budget)
