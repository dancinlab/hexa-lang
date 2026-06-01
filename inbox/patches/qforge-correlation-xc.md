# qforge-correlation-xc — the missing correlation functional in the cell→|g|² front-end

**status:** OPEN (migration gate blocker — d8 / d6 / d_qforge_engine)
**surfaced-by:** QFORGE production-migration cross-val (demiurge RTSC), 2026-06-01
**affects:** `stdlib/qforge/screening.hexa`, `stdlib/qforge/scf.hexa`, `stdlib/qforge/orchestrator.hexa`

## what

The QFORGE el-ph→Tc production chain (`qforge_elph_to_tc`, PR #2395) is
QE-cross-validated **end-to-end from the el-ph moment boundary** — i.e. it
reproduces QE λ·ω_log·Tc once handed the per-mode |g|²/ω(q,ν) DFPT dataset
(CaH6: λ rel-ε=1.2e-4, McMillan Tc rel-ε≤1.1e-4 vs the QE textbook-proof
record; YH10 α²F assembler λ rel-ε=9.8e-5; 10/10 Tc-from-moments anchors
rel-ε≤2.5e-3).

What is **NOT** wired in-repo is the **cell→|g|² plane-wave front-end** — the
stage that turns raw atomic positions + pseudopotentials into the per-mode
electron-phonon coupling. `screening.hexa` today implements the dielectric
response with **Hartree + LDA-exchange only**; the **correlation** part of the
XC kernel is deferred (a `// correlation XC deferred` boundary). So the DFPT
|g|² stage in production still runs on Quantum ESPRESSO (`hexa cloud dft-run
<deck>`), and QFORGE consumes its output to compute moments→λ→Tc.

`hexa qforge run <deck>` correctly reports this blocker (d6 — no fabricated Tc)
when a deck has no harvested `ph.out`, and the `--engine` dispatch default stays
`qe` (`dft_engine_resolve("") == "qe"`).

## why it blocks full migration

The `@engine` gate (full flip to QFORGE-only) requires g5 λ·Tc agreement vs QE
on CaH6·LaH10·Li2MgH16 from an **independent QFORGE-only path**. Today only the
moments→Tc leg is independent; the |g|² that feeds it is still QE's. A truly
self-contained QFORGE el-ph requires the correlation functional so the SCF +
DFPT response (and thus |g|²) is computed without QE.

## the missing piece (concrete)

`screening.hexa` needs a correlation XC kernel to complete the LDA (or GGA) XC
potential used in the SCF/DFPT response:

- **minimum:** LDA correlation — Perdew-Zunger (PZ81) or Perdew-Wang (PW92)
  parametrization of the Ceperley-Alder homogeneous-electron-gas correlation
  energy ε_c(r_s) and its potential v_c = ε_c + r_s·(dε_c/dr_s)/3 (spin-
  unpolarized first; ζ-interpolation for spin later).
- **then:** a GGA correlation (PBE) gradient correction H(r_s, t) to match the
  PBE PAW the campaign's QE decks use (the QE refs are PBE), so the front-end
  XC matches the reference XC and the |g|² is comparable.

Until that lands, `screening.hexa` = Hartree + LDA-exchange, and the
cell→|g|² front-end cannot be cross-validated independently against QE — so the
migration gate stays HELD and the dispatch default stays QE (the 26 running QE
RTSC pods are untouched). This is the honest gate blocker, not a forced flip.

## acceptance

- [ ] PZ81 or PW92 LDA correlation ε_c/v_c in `screening.hexa`, unit-tested vs
      tabulated ε_c(r_s) values
- [ ] PBE GGA correlation gradient term, tested vs a known ε_c^PBE point
- [ ] one small-cell (CaH6, 7 atoms) SCF+DFPT |g|² computed QFORGE-only and
      λ cross-validated vs the QE CaH6 |g|² (g5, rel-ε ≤ 0.5%)
- [ ] then re-run the `@engine` gate on CaH6·LaH10·Li2MgH16 from the QFORGE-only
      path and flip the dispatch default iff all three agree

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
