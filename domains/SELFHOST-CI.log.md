# SELFHOST-CI — step log (append-only)

## 2026-06-03 — milestone 2: native-codegen regression guards

- Landed `tool/selfhost_codegen_guard.sh` + `.github/workflows/selfhost-codegen-guard.yml` + two corpus programs (`self/test/miscompile_zero/g1_hex_corpus.hexa`, `g2_stp_ldp_corpus.hexa`). Additive only (g4) — a standing, named, always-run codegen-correctness fence DISTINCT from milestone-1's heavy byte-eq leg. No production codegen edits.
- THREE hard-assert corpora; any ENCODE-MISS / re-collapsed literal / dead spill path exits 1 (true regression), build-floor "cannot native-emit" exits 2 (CI-neutral, same #2547 discipline as the sister gates):
  - CORPUS 1 — full self-emit ENCODE-MISS=0 as a REQUIRED assert (milestone-1 only reported it). Re-emit the full `cc-flat-fix.hexa`; ghost: rc=0 objsize=3224592 ENCODE-MISS=0 PASS.
  - CORPUS 2 — 0x-literal value-check (locks #47421c89c). Emit `g1_hex_corpus`, disassemble (otool), assert each immediate present: 0x0 0x7f 0x80 0xff 0xffff 0xdeadbeef 0x8 0x1ff → 8/8 PASS, ENCODE-MISS=0.
  - CORPUS 3 — STP/LDP [sp] value-check (locks #2579). Emit `g2_stp_ldp_corpus` (small/medium/large frames), assert STP+LDP [sp,#N] pairs at multiple distinct offsets: 73 stp + 115 ldp, 35 distinct offsets, ENCODE-MISS=0 PASS.
- Real run on ghost macOS (graduated `gen2_fix`): guard exit 0 (all corpora PASS). Verdict `.verdicts/selfhost-ci/CODEGEN-GUARD.txt` (raw stdout verbatim).
- FINDING (g63 honesty) — the FIRST guard run red'd on `0xdeadbeef` ("immediate MISSING"). This was a FALSE NEGATIVE in the guard's own assertion, NOT a codegen bug: a 32-bit constant is lowered MOVZ `#0xbeef` + MOVK `#0xdead,lsl#16` (0xdead<<16|0xbeef = 3735928559), so the full `#0xdeadbeef` token never appears. The hex-literal fix is intact (both halves present; a regression to #0x0 drops both). Fixed the value-check to assert the 16-bit chunk decomposition for wide constants; re-ran → PASS. Rejected the false negative before declaring green.

## 2026-06-03 — byte-eq fixpoint CI gate (milestone 1)

- Landed `domains/SELFHOST-CI.md` (+ this log) + `DOMAINS.tape` roster row + `tool/selfhost_byteeq_gate.sh` + `.github/workflows/selfhost-byteeq-gate.yml`. Additive only (g4), no production codegen edits.
- Real run on ghost macOS (graduated `gen2_fix`):
  - LEG B native-codegen probe — `c1_hex_literal` (0xff→255 hex-literal) objsize=1600 ENCODE-MISS=0 PASS; `c2_stack_locals` (STP/[sp]) objsize=1816 ENCODE-MISS=0 PASS.
  - LEG A byte-eq fixpoint — re-emit gen3 → gen4 from `cc-flat-fix.hexa`: gen3 rc=0 objsize=3224592 ENCODE-MISS=0; gen4 rc=0 objsize=3224592 ENCODE-MISS=0; `cmp gen3 gen4` BYTE-EQ FIRSTDIFF=0. Fresh gen3 also byte-identical to the graduated `cc-gen3.o` (cmp rc=0).
- FINDING — the canonical graduation fixpoint is the SELF-REPRODUCTION `gen3 ≡ gen3b ≡ gen4` (confirmed by ghost markers `gen3b.done` CMP_gen3_vs_gen3b=IDENTICAL + `gen4.done` CMP_gen3_vs_gen4=BYTE-EQ-GRADUATION, FIRSTDIFF=0). `cc-prc2-fix.o` is gen2's OWN object, relinked via a different path (hld_fixed literal8-merge, `gen2fix.done`), so it differs from gen2's EMIT at char 1528257 — it differed at graduation time too (`gen3.done` recorded CMP=DIFFER). First gate draft wrongly red'd on this; fixed: GEN_REF default UNSET + informational-only (never fails the gate). The fixpoint gate compares gen3 vs gen4.
- Verdict: `.verdicts/selfhost-ci/BYTEEQ-GATE.txt` (raw run + finding).
