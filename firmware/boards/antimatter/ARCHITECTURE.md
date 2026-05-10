# Architecture — hexa-antimatter

> The lay-of-the-land doc.  How the repo is structured, why each layer exists,
> what reads what, and where the abstraction boundaries are.  Read this before
> trying to add a new substrate or to navigate to a specific evidence tier.

---

## §1 The 6-layer architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Layer 6 — Phase E hardware       (NOT in repo, gated on funding)    │
│   • PCBs, flashed firmware, bitstreams, live data feeds              │
│   • state/*_LOG.hexa replaces paper-feed in verify/empirical_*       │
└──────────────────────────────────────────────────────────────────────┘
                                  ▲
                                  │  (paper-spec → hardware)
┌──────────────────────────────────────────────────────────────────────┐
│  Layer 5 — Phase D paper firmware/HDL/MCU/schematic specs            │
│   • firmware/hdl/*.{v,xdc}        Vivado-synthesizable Verilog tops  │
│   • firmware/mcu/*.rs              Rust no_std MCU skeletons          │
│   • firmware/doc/{board,schematic}_v0_*.md   board pinout + KiCad-   │
│                                              ready netlist           │
│   • verify/firmware_phase_d_lint.hexa  paper-spec drift catcher      │
└──────────────────────────────────────────────────────────────────────┘
                                  ▲
                                  │  (sim → paper firmware)
┌──────────────────────────────────────────────────────────────────────┐
│  Layer 4 — Phase C sim firmware (state machines + DAC/ADC + safety)  │
│   • firmware/sim/*.hexa            4 controllers, 46/46 PASS         │
└──────────────────────────────────────────────────────────────────────┘
                                  ▲
                                  │  (numerics → sim spec)
┌──────────────────────────────────────────────────────────────────────┐
│  Layer 3 — T2 numerical (closed-form parity + ODE + 4-effort comp.)  │
│   • verify/numerics_*.hexa         14 scripts (RK4 + Simpson +       │
│                                    parity + Stage-1 sim parity)      │
│   • verify/lint_numerics.hexa      5-invariant grep-lint             │
└──────────────────────────────────────────────────────────────────────┘
                                  ▲
                                  │  (algebra → numerics)
┌──────────────────────────────────────────────────────────────────────┐
│  Layer 2 — T1 algebraic (n=6 lattice closed-form per pillar)         │
│   • verify/calc_*.hexa              4 pillars + cross-cutters        │
│   • verify/n6_arithmetic.hexa       master σ·φ = n·τ = J₂ proof      │
│   • verify/cross_doc_audit.hexa     SSOT lattice alignment           │
└──────────────────────────────────────────────────────────────────────┘
                                  ▲
                                  │  (substrate → algebra)
┌──────────────────────────────────────────────────────────────────────┐
│  Layer 1 — Substrate SSOT (declarative)                              │
│   • factory/antimatter-factory.md, tabletop/tabletop-antimatter.md,  │
│     pet_cyclotron/pet-cyclotron.md       (verbs)                     │
│   • factory.hexa, tabletop.hexa, pet_cyclotron.hexa  (n=6 numbers)   │
│   • .roadmap.hexa_antimatter             (release + falsifier track) │
└──────────────────────────────────────────────────────────────────────┘
```

Each layer **reads only the layer below** (or layer 1, the substrate).  Nothing in layer 5 reaches into layer 1 directly without going through layer 2/3/4.  This is what makes the SSOT-drift audit (`cross_doc_audit.hexa`) and the firmware-paper-spec drift audit (`firmware_phase_d_lint.hexa`) tractable.

---

## §2 The 3-verb (4-falsifier) tetrahedron

```
                    ┌─────────────────────┐
                    │      factory        │
                    │  (CERN-scale        │
                    │   200 m³, F-AM-3)    │
                    └──────────┬──────────┘
                               │
                ┌──────────────┴──────────────┐
                │                             │
       ┌────────▼─────────┐         ┌─────────▼────────┐
       │     tabletop      │         │   pet_cyclotron  │
       │ (desktop 0.29 m³, │         │ (¹⁸F β⁺ recycle, │
       │       F-AM-2)     │         │       F-AM-1)    │
       └──────────┬─────────┘         └────────┬─────────┘
                  │                            │
                  └────────────┬───────────────┘
                               │
                               ▼
                        ┌──────────────┐
                        │  break_even  │
                        │ (cross-pillar│
                        │  thrust DAQ, │
                        │   F-AM-4)    │
                        └──────────────┘
```

`break_even` is the cross-cutter — it's not its own pillar but reuses the 3 pillars to scope a thrust-bench DAQ.  The 4th falsifier (F-AM-4) lives there.

---

## §3 Where to find what

### "I want to know what `σ·τ = 48` means"
- **Algebra**: `verify/n6_arithmetic.hexa` § master closure
- **Per-pillar projection**: `verify/calc_*.hexa` § per-pillar
- **Float parity**: `verify/numerics_*.hexa` § master_float
- **Cross-pillar consistency**: `verify/numerics_cross_pillar.hexa`
- **Lattice stability under math_pure**: `verify/numerics_lattice_arithmetic.hexa`

### "I want to know how the CERN AD beam handshake works"
- **Sim-firmware**: `firmware/sim/penning_rf.hexa` § AD handshake stage
- **HDL**: `firmware/hdl/penning_rf.v` § state machine S_AD_REQUEST → S_AD_CONFIRMED
- **MCU companion**: `firmware/mcu/tabletop.rs::AdHandshakeStage`
- **Pinout**: `firmware/doc/board_v0_tabletop_penning.md` § connector J7 (RS-485 DB-9)
- **Schematic**: `firmware/doc/schematic_v0_tabletop_penning.md` § ADM4168E RS-485 transceiver
- **XDC**: `firmware/hdl/penning_rf.xdc` § Bank 228 LVDS pairs

### "I want to know what closure tier each falsifier is at"
- **Tracker**: `verify/falsifier_check.hexa` (run it; emits 4-row table)
- **Roadmap**: `.roadmap.hexa_antimatter §A.4`

### "I want to know what Phase E looks like"
- **Top-level**: `firmware/doc/PHASE_E_HARDWARE_PATH.md`
- **Per-board**: `firmware/doc/{board,schematic}_v0_*.md` § §9 Forward path

### "I want to add a new verifier"
- **Recipe**: `~/core/bedrock/docs/runnable_surface_recipe.md` §2 (7-step cycle)
- **Pattern**: copy any existing `verify/numerics_*.hexa` and adapt
- **Wire-in**: `verify/all.hexa`, `verify/lint_numerics.hexa NUMERICS_SCRIPTS`, `verify/falsifier_check.hexa F<N>_T2_SCRIPTS`, `tests/test_calculators.hexa CASES`, `tests/test_verify_all.hexa EXPECTED_AGG`
- **Lint**: `hexa run verify/lint_numerics.hexa` to catch missing wire-in
- **Reference**: `CONTRIBUTING.md §3`

---

## §4 Why .hexa (not Python)

- **Reproducibility**: `.hexa` runs through a 3 KB interpreter; `python` runs through a 50 MB CPython + 200 MB pip ecosystem
- **n=6 lattice purity**: integer-first arithmetic, no implicit float coercion (math_pure for explicit float)
- **HEXA family contract**: every `dancinlab/hexa-*` substrate uses `.hexa`; cross-substrate verifiers (e.g. `cross_doc_audit.hexa`) work uniformly
- **No-PII discipline**: `.hexa` runtime has no `requests`, no `socket`, no `http.client`; only `exec()` to a controlled shell
- **Lower drift surface**: a 200-line `.hexa` script with explicit math anchors is easier to audit than a `numpy + scipy + sympy` mix

For Phase D HDL, the choice is Verilog (Vivado) — not `.hexa` — because that's the toolchain that produces synthesizable bitstreams.  For Phase D MCU, the choice is Rust — also not `.hexa` — because that's the toolchain for `no_std` cross-compile.  In each case the `.hexa` sim layer is the **golden behavioral spec**; HDL/Rust mirror it.

---

## §5 The cross-doc audit (why we keep MDs in sync)

`verify/cross_doc_audit.hexa` does a grep audit across:
- 4 SSOT MDs (factory, tabletop, pet_cyclotron, plus 1 cross-cutter)
- `.roadmap.hexa_antimatter`
- `hexa.toml`
- (optionally) `README.md`

Looking for: σ=12, τ=4, φ=2, J₂=24 markers + per-pillar n=6 numbers (R=10 cm, B=48 T, etc.).  If a number drifts in one place but not the others, audit fails (exit 1).  This is what keeps Layer 1 (substrate SSOT) consistent with everything above it.

---

## §6 The honest negative (raw#10 C3)

This repo carries **honest negatives** on purpose — places where the n=6 closed form disagrees with measurement.  These are NOT bugs; they're documented falsifiers.  The closure-depth-accumulation loop is allowed to *bookkeeping-close* a falsifier (T1 + T2 + T3-paper) without resolving the underlying scientific gap.  Resolving the gap requires Stage-1+ hardware.

Examples (carried forward):
- `pet_cyclotron`: medical PET cyclotrons use 1.5-2 T fields, not σ·τ=48 T; the 48 T figure is the *post-RT-SC retrofit target*
- `tabletop`: CERN AD's 1 K trap is not 100 mK; the 100 mK figure is the *sympathetic-cool target*
- `factory`: 1e12 p̄/hr is the *target rate*; CERN AD currently does ~10⁷/s

The closure-pct counter (`falsifier_check.hexa`) tracks **bookkeeping** progress, not empirical truth.  Don't conflate the two.

---

## §7 Drift surfaces (where bugs hide)

The smaller the drift surface, the more rigid the audit.  Known drift surfaces in this repo:

1. **σ·τ=48 vs 47.999...** — math_pure float arithmetic round-off (caught by `numerics_lattice_arithmetic.hexa`)
2. **CHANGELOG vs commit log** — manual sync; periodic `git log -- CHANGELOG.md` audit
3. **`firmware/sim/*.hexa` ↔ `firmware/mcu/*.rs`** — both define state machines; cross-link asserted by `firmware_phase_d_lint.hexa` §6
4. **`firmware/doc/board_v0_*.md` ↔ `firmware/hdl/*.xdc`** — pin assignments; cross-link asserted by `firmware_phase_d_lint.hexa` §7
5. **n=6 numbers across SSOTs** — caught by `cross_doc_audit.hexa`
6. **External chip part numbers vs vendor catalog** — manual periodic refresh; if a part EOLs, BOM update needed (Phase E concern)

Each drift surface has a verifier; if a verifier doesn't exist for a drift you spot, **add one** (per recipe §2).