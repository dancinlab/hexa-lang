# L5 B1 census TRIAGE verdict (90 fires @ main 66e85e219, aiden)

90 fires = 45 unique sites × 2 (census double-count: per-config/pre-dedup — benign).

## HX3014 (48 fires / 24 sites) — VERDICT: 100% FP, one idiom
Every site is the **rebuild-then-reassign (swap) idiom**: `let mut tmp = []; …tmp.push(x[i])…; x = tmp`.
- parse/parser.hexa:3107-3127 — path-normalize: `stack = next` in a loop (next re-`let` fresh each iter).
- lower/hir_to_mir.hexa:4736-4768 — `_last.push(arg_ops[…]); arg_ops = _last`, straight-line.
- codegen/arm64_darwin.hexa:855-948 — regalloc: `active_idx = keep/na`, `pool = np` in the scan loop.
- check/units.hexa:239 — `den = new_den` after `new_den.push(den[k])`.
Mechanism (checker defect, not source hazard): the M4 event-reachability fixed-point
`_bck_nll_check` (hir_to_mir.hexa:1961) is **gen-only — no kill, no join ordering**:
(a) writes through the temp recorded BEFORE the aliasing assignment arm every later use of
the assignee (pre-join writes); (b) the loop back-edge makes iteration-i writes reach
iteration-i+1 uses even though the fresh `let mut tmp = []` re-init severs the alias every
iteration (no kill on severing re-defs). Zero real use-after-move/aliased-write hazards.

## HX3055 (42 fires / 21 sites) — VERDICT: TRUE POSITIVE per spec, zero runtime hazard
HX3055 = assign-to-field/element-of-immutable-owned-base (Rust E0594), emitted by
`_bck_emit_write_immut_base` (hir_to_mir.hexa:1803). Every fire is a genuine non-`mut` `let`
whose field/element is later written (`let info = GradeInfo{…}; info.value = v` atlas/parser.hexa:264;
`let buckets = {}; buckets[key] = arr` atlas/prefix_index.hexa:99; `let caps = _bt_fill(…); caps[0] = start`
regex/backtrack.hexa:827; `let obj = ElfX86Obj{…}; obj.nlocal += 1` emit/elf_x86_64.hexa:5008).
Works at runtime (reference semantics) — a mutability-declaration hygiene gap, not a bug.
Catalog's "fires on ~ZERO real source (corpus-clean)" claim is FALSIFIED (42 measured).

## B3 decision
- `_bck_warn_allowlist` today: **HX3055 is FP=0 → allowlist-eligible**; HX3014 is NOT (all-FP).
- Fast unlock (round-2a): mechanical `let → let mut` sweep at the 21 HX3055 base decls →
  count 0 → allowlist ["HX3055"]. Verify: census re-run 0 + byteeq 3-target (mut must be
  codegen-neutral).
- Main fix (round-2b): **gen/kill-refine the HX3014 Rule-1 lane** —
  (i) join-seq gate: stamp `_bck_evseq` at every group join (`let b = a` / `b = a` handle-copy
      arm) and on `_bck_note_write` rows; a write arms a use only if it postdates that use-name's
      join (seq within block; kill-blocked reachability from the join block across blocks);
  (ii) sever-kill: a fresh (non-handle-copy) `let`/reassign of a group member records a kill
      block; `_bck_nll_check` propagation of that group's events is blocked THROUGH kill blocks
      (path-through only, never a global purge).
  Loci: `_bck_track`/assign-arm join sites, `_bck_note_write` (hir_to_mir.hexa:987),
  `_bck_check_use` (:1852 Rule-1 arm), `_bck_nll_check` (:1961).
  Verify: (1) corpus census re-run → HX3014 = 0; (2) borrowck_test.hexa true-positive suite
  stays green + ADD adversarial case (join, THEN write through one name on a kill-free path,
  THEN read through the other → must still fire); (3) flag-off byteeq 3-target.

## RISK + control
A kill implemented as a global group-purge (kill anywhere ⇒ drop all group events) would mask
`let b = a; a.push(x); use(b); let a2 = …` real hazards. Control: kill only blocks propagation
through the kill block in the reach recurrence (paths around it still arm); adversarial
regression in borrowck_test.hexa; STRICT-band run on the test corpus.
