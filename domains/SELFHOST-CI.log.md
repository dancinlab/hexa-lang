# SELFHOST-CI — step log (append-only)

## 2026-06-03 — byte-eq fixpoint CI gate (milestone 1)

- Landed `domains/SELFHOST-CI.md` (+ this log) + `DOMAINS.tape` roster row + `tool/selfhost_byteeq_gate.sh` + `.github/workflows/selfhost-byteeq-gate.yml`. Additive only (g4), no production codegen edits.
- Real run on ghost macOS (graduated `gen2_fix`):
  - LEG B native-codegen probe — `c1_hex_literal` (0xff→255 hex-literal) objsize=1600 ENCODE-MISS=0 PASS; `c2_stack_locals` (STP/[sp]) objsize=1816 ENCODE-MISS=0 PASS.
  - LEG A byte-eq fixpoint — re-emit gen3 → gen4 from `cc-flat-fix.hexa`: gen3 rc=0 objsize=3224592 ENCODE-MISS=0; gen4 rc=0 objsize=3224592 ENCODE-MISS=0; `cmp gen3 gen4` BYTE-EQ FIRSTDIFF=0. Fresh gen3 also byte-identical to the graduated `cc-gen3.o` (cmp rc=0).
- FINDING — the canonical graduation fixpoint is the SELF-REPRODUCTION `gen3 ≡ gen3b ≡ gen4` (confirmed by ghost markers `gen3b.done` CMP_gen3_vs_gen3b=IDENTICAL + `gen4.done` CMP_gen3_vs_gen4=BYTE-EQ-GRADUATION, FIRSTDIFF=0). `cc-prc2-fix.o` is gen2's OWN object, relinked via a different path (hld_fixed literal8-merge, `gen2fix.done`), so it differs from gen2's EMIT at char 1528257 — it differed at graduation time too (`gen3.done` recorded CMP=DIFFER). First gate draft wrongly red'd on this; fixed: GEN_REF default UNSET + informational-only (never fails the gate). The fixpoint gate compares gen3 vs gen4.
- Verdict: `.verdicts/selfhost-ci/BYTEEQ-GATE.txt` (raw run + finding).
