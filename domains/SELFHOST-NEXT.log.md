# SELFHOST-NEXT — log

Append-only history sister of `SELFHOST-NEXT.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-02 — promote-toolchain: reproducible recipe + parity gate + gated promotion

Scoped + implemented the "promote self-hosted gen to default `hx`/hexa_v2, PARITY-GATED"
milestone. Branch `selfhost-next/promote-toolchain`. Three committed `tool/` deliverables
turn the ad-hoc ghost byte-eq build into a one-command reproducible + safely-promotable path.

- [x] `tool/build_selfhost.sh` — full bootstrap ladder from current main:
      restore_frozen_seeds → hexat → build_aprime.sh (stage0) → hexa_ld (from
      tool/hexa_ld.hexa, __literal8 fix on main) → rt.o → aprime emit→gen2 →
      gen2 emit→gen3 → gen3 emit→gen4 → GATE cmp cc-gen3.o==cc-gen4.o. `-j` fast
      path (stage0 only), `--detached MARK` for the 3×~68min self-emits. NO /tmp.
- [x] `tool/selfhost_parity_gate.sh` — parity precondition: per-program BEHAVIOUR
      parity (compile+link+run gen3, exit==`// expect:`) + 42-smoke + optional asm
      byte-match vs shipped ref (`--strict`). PASS authorizes promotion.
- [x] `tool/promote_selfhost.sh` — gated, reversible promotion. tier1 `install` =
      side-by-side slot + `hx-selfhost` launcher (default UNTOUCHED); tier2
      `--default --i-have-reviewed-parity` = backup hexa.real + symlink flip,
      `--revert`. Parity gate is a HARD precondition for both tiers. NO blind replace.
- [x] `tool/SELFHOST_PROMOTE_RUNBOOK.md` — one-command recipe + the precise
      final-flip checklist + why the default-flip is host-local manual (not a PR-carryable change).
- [ ] HONEST g63: default-flip NOT auto-landed — it mutates an on-disk launcher in
      $HX_HOME outside the repo + needs a host-local green parity + human ack. tier-1
      opt-in delivers the capability now at zero risk; flip is one gated command when ready.
- [ ] heavy ghost build re-verification from a clean main checkout = follow-up (detached).

