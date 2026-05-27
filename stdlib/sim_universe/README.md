<p align="center">🌌 <strong>stdlib/sim_universe</strong></p>

<p align="center"><strong>Sim-Universe</strong> — virtual-universe runtime · toy lattice-model substrate at cosmological scale · 26 modules · QRNG-anchored entropy</p>

<p align="center">
  <img alt="RFC" src="https://img.shields.io/badge/RFC-046-success">
  <img alt="Modules" src="https://img.shields.io/badge/modules-26-informational">
  <img alt="Status" src="https://img.shields.io/badge/status-scaffold-yellow">
  <a href="https://doi.org/10.5281/zenodo.20102970"><img alt="DOI" src="https://zenodo.org/badge/DOI/10.5281/zenodo.20102970.svg"></a>
</p>

<p align="center">virtual-universe · toy-lattice · τ-clock · multiverse-interferometer · QPU-bridge · ouroboros-QRNG · Bostrom-test · Gödel-Q-mutator</p>

---

`stdlib/sim_universe` is a virtual-universe runtime substrate — a toy lattice
simulation framework with QRNG-anchored entropy. 26 modules across τ-clock
evolution, multiverse interferometry, QPU bridge, Bostrom test harness,
Gödel-Q mutator, ouroboros QRNG perturbation, and 16+ exact small-N quantum
experiments (FVD · stark-fragmentation · quantum-Darwinism · ca-qm ·
supremacy-frontier · mbs-revival · fock-prethermal-dtc · z2-gauge-prethermal
· preheating-analog · multipolar-prethermal · surface-code · ssh-topology ·
hofstadter · dqpt-loschmidt · wdw-minisuperspace).

**Origin:** RFC 046 absorbs [`dancinlab/sim-universe`](https://github.com/dancinlab/sim-universe)
v1.1.0 into hexa-lang's stdlib. The original SSOT is frozen as the
`dancinlab/sim-universe` GitHub **private** repo (헌법 v2 룰 3). The local
`~/core/archive_sim-universe/` was retired 2026-05-17 — GitHub private repo is
the preservation SSOT; working-tree state is absorbed here in `stdlib/sim_universe/`.

> [!IMPORTANT]
> **Status: scaffold (Phase A)** — RFC 046 lands the README + CLI dispatcher
> + governance + archive 묘비. Actual `.hexa` code migration (~32k LoC across
> 26 module directories) is staged as **RFC 046-A** (substrate: anu_time,
> multiverse, qpu_bridge, sim_agent, ouroboros_qrng, godel_q, sr_harness) +
> **RFC 046-B** (16 experiments). Phase A unblocks the hexa CLI surface +
> archive freeze; Phase A/B unblock actual execution.

> [!NOTE]
> Sister packages — RFC 044 ([`qrng`](../qrng/) absorbed) · RFC 045 (qmirror,
> pending — upgrade in flight). Member of the dancinlab HEXA family.

---

## What is sim-universe?

`sim_universe` is a virtual-universe runtime that lets you experiment with
**simulation-hypothesis-flavored physics on a laptop** without renting QPU time.
It combines:

1. **anu_time τ-clock** — Lorentz-metric scalar-field lattice with topology
   evolution and empirical anchor (300-tick mini_world canonical run evidence).
2. **multiverse interferometer** — KS-test + mutual-information higher-order
   correlator across M parallel mini-worlds (Phase 1 scale-up: M=15, T=500).
3. **QPU bridge** — VQE-H2 demo + ANU noise-model adapter (delegates to
   real-QPU vendors when API keys present; classical-simulator fallback).
4. **ouroboros QRNG** — quantum-RNG perturbation pipeline (baseline / shadow /
   comparison) with 4-tier ANU fallback (paid → keyed → legacy → urandom).
   Today consumes `stdlib/qrng/` after RFC 044 absorption.
5. **Bostrom test harness** — anu_collector for simulation-hypothesis
   pre-registered statistical tests (Phase 1 scaffold).
6. **Gödel-Q mutator** — self-rewriting hexa AST harness with verify-gate.

The name reflects the **Bostrom-flavored simulation framing** — toy lattice
universes evolved against a QRNG-anchored entropy budget. **This is NOT**
lattice QCD, NOT Einstein-equation evolution, NOT N-body cosmology, NOT
Standard-Model physics. Full honesty disclosure preserved at
`dancinlab/sim-universe` (GitHub private) `README.md` §Caveats.

---

## Run via hexa CLI

```sh
hexa sim-universe                       # default = status (module inventory + tier table)
hexa sim-universe status                # module inventory + tier table + caveats
hexa sim-universe selftest              # Tier-A smoke pass (when migrated)
hexa sim-universe --help                # full subcommand reference
hexa sim-universe --version             # 1.1.0
```

Substrate subcommands (planned Phase A — `RFC 046-A` migration):

```sh
hexa sim-universe anu                   # anu_time τ-clock mini_world demo  [Tier-A]
hexa sim-universe multiverse            # multiverse interferometer + KS    [Tier-A]
hexa sim-universe qrng                  # ouroboros QRNG perturbation       [Tier-A2]
hexa sim-universe bostrom               # Bostrom test (anu_collector)      [Tier-B]
hexa sim-universe godel                 # Gödel-Q mutator bootstrap         [Tier-A2]
hexa sim-universe qpu                   # qpu_bridge VQE-H2 + ANU noise     [Tier-A]
```

Experiment subcommands (planned Phase B — `RFC 046-B` migration):

```sh
hexa sim-universe fvd                   # exact quantum false-vacuum decay  [Chao 2026 / N≤24]
hexa sim-universe stark                 # Hilbert-space fragmentation       [Wang 2024 / N≤24]
hexa sim-universe qdarwin               # quantum-Darwinism gate-circuit    [Zhu 2025]
hexa sim-universe ca-qm                 # two-engine deterministic CA of QM [Elze 2024 / van Berkel 2025]
hexa sim-universe supremacy             # 2ⁿ RCS XEB instrument             [Morvan 2024]
hexa sim-universe mbs                   # PXP-Rydberg scar revival          [Xiang 2024]
hexa sim-universe dtc                   # Fock-space prethermal DTC         [Bao 2025]
hexa sim-universe z2gauge               # (1+1)D Z₂ LGT Floquet prethermal  [Hayata-Hidaka 2024]
hexa sim-universe preheating            # cold-atom BdG preheating analog   [Gondret 2025]
hexa sim-universe multipolar            # RMD prethermalization (α=2n+1)    [Liu 2025]
hexa sim-universe surface-code          # Gottesman-Knill stabilizer QEC    [Acharya 2024]
hexa sim-universe ssh                   # SSH topological-edge primer       [SSH 1979]
hexa sim-universe hofstadter            # Harper-Hofstadter butterfly       [Hofstadter 1976]
hexa sim-universe dqpt                  # TFIM Loschmidt DQPT               [Heyl 2013]
hexa sim-universe wdw                   # Wheeler-DeWitt minisuperspace     [Basilakos 2025]
```

Each experiment subcommand supports module-specific flags (e.g.
`hexa sim-universe fvd --lindblad --selftest`, `hexa sim-universe stark --imbalance --state ndw2`).
See archived original README for full flag inventory.

Programmatic use (after Phase A/B migration):

```hexa
use "stdlib/sim_universe/anu_time/mini_world"
use "stdlib/sim_universe/multiverse/interferometer"
use "stdlib/sim_universe/qpu_bridge/vqe_h2"
use "stdlib/sim_universe/experiments/fvd"
// ...
```

---

## Module inventory

### Tier-A: runnable simulators

| Module | LoC | Description |
|---|---:|---|
| `anu_time` | 5,881 | τ-clock + mini_world + Lorentz metric + topology + empirical anchor (11 files) |
| `multiverse` | 4,181 | interferometer + KS-test + higher-order MI (triple/quad) (11 files) |
| `qpu_bridge` | 441 | VQE-H2 demo + ANU noise-model adapter (2 files) |

### Tier-A2: supporting (analytical + RNG infrastructure)

| Module | LoC | Description |
|---|---:|---|
| `atlas_anu_corr` | — | ATLAS xcorr engine + null baseline + analyze (5 files) |
| `anu_stream` | — | stream_daemon + chacha20 + client_example (3 files) |
| `ouroboros_qrng` | 862 | baseline + shadow + qrng_perturbation + comparison (4 files); consumes `stdlib/qrng/` |
| `godel_q` | 758 | Gödel-Q mutator + bootstrap (verify-gated AST mutations) |
| `fvd` | 1,338 | exact 2ᴺ quantum false-vacuum decay (Chao 2026) |
| `stark-fragmentation` | 1,212 | exact 2ᴺ Hilbert-space fragmentation (Wang 2024) |
| `quantum-darwinism` | 1,282 | quantum-Darwinism gate circuit (Zhu 2025) |
| `ca-qm` | 1,142 | two-engine deterministic CA of QM (Elze / van Berkel) |
| `supremacy-frontier` | 1,272 | 2ⁿ RCS XEB instrument (Morvan 2024) |
| `mbs-revival` | 869 | PXP-Rydberg scar revival (Xiang 2024) |
| `fock-prethermal-dtc` | 771 | Fock-space prethermal DTC (Bao 2025) |
| `z2-gauge-prethermal` | 804 | (1+1)D Z₂ LGT Floquet prethermal (Hayata-Hidaka 2024) |
| `preheating-analog` | 615 | cold-atom BdG preheating (Gondret 2025) |
| `multipolar-prethermal` | 1,176 | RMD prethermalization α=2n+1 (Liu 2025) |
| `surface-code` | 835 | Gottesman-Knill stabilizer QEC (Acharya 2024) |
| `ssh-topology` | 693 | SSH topological-edge primer (SSH 1979) |
| `hofstadter` | 823 | Harper-Hofstadter butterfly (Hofstadter 1976) |
| `dqpt-loschmidt` | 684 | TFIM Loschmidt DQPT (Heyl 2013) |
| `wdw-minisuperspace` | 889 | Wheeler-DeWitt minisuperspace (Basilakos 2025) |
| `bostrom_test` | 235 | Bostrom test (anu_collector) |
| `sim_agent` | 492 | registry + router (importable lib entry) |
| `sr_harness` | 800 | sim-adjacent harness |
| `weave` | — | (PY-only, archive only) |

**Total: ~32k LoC `.hexa` (Tier-A + Tier-A2 combined)**

---

## Governance

| ID | Rule |
|---|---|
| `@D g_sim_universe_honest_scope` | Each experiment module declares its "honest scope" (e.g. "EXACT 2ᴺ unitary; NOT decoherent; NOT lab device; NOT L→∞ thermodynamic limit"). Per-module caveat preserved in archive `MODULE/<name>.md`. |
| `@D g_sim_universe_qrng_consumer` | `stdlib/sim_universe/ouroboros_qrng/` consumes `stdlib/qrng/` (RFC 044) — no own provider implementation. |
| `@F f_sim_universe_lattice_qcd_claim` | Forbidden — claiming this is lattice QCD / Einstein-equation evolution / N-body cosmology / Standard-Model physics. The package is explicitly "toy lattice-model substrate, Bostrom-flavored framing". |
| `@X x_archive_sim_universe` | `dancinlab/sim-universe` GitHub private 묘비 (Zenodo DOI 10.5281/zenodo.20102970) |

Full entries in `AGENTS.tape` §0 (`@N sim_universe_stack`) + §3-5.

---

## Architecture

```
                        ┌─────────────────────────────────────┐
                        │       hexa sim-universe CLI         │
                        │   stdlib/sim_universe/sim_universe  │
                        │  status anu multiverse qrng bostrom │
                        │           godel selftest            │
                        └─────────────────┬───────────────────┘
                                          │
            ┌─────────────────────────────┼──────────────────────────────┐
            │                             │                              │
            ▼                             ▼                              ▼
   ┌────────────────┐          ┌────────────────────┐         ┌──────────────────┐
   │   Tier-A       │          │      Tier-A2       │         │     Tier-B       │
   │   simulators   │          │  RNG / analytics   │         │  sim-adjacent    │
   ├────────────────┤          ├────────────────────┤         ├──────────────────┤
   │ anu_time       │          │ ouroboros_qrng    ─┼──→ stdlib/qrng/ (RFC 044)
   │  └ mini_world  │          │  └ baseline        │         │ sr_harness       │
   │  └ τ-clock     │          │  └ shadow          │         │ bostrom_test     │
   │  └ Lorentz     │          │  └ perturbation    │         └────────┬─────────┘
   │ multiverse     │          │ atlas_anu_corr     │                  │
   │  └ interfer.   │          │ anu_stream         │                  │
   │  └ KS / MI     │          │ godel_q (mutator)  │                  │
   │ qpu_bridge     │          └─────────┬──────────┘                  │
   │  └ VQE-H2      │                    │                             │
   │  └ ANU noise   │                    ▼                             │
   └────────┬───────┘          ┌────────────────────┐                  │
            │                  │  stdlib/qrng/      │                  │
            │                  │  9-backend chain   │                  │
            │                  │ curby/anu/nist     │                  │
            │                  │ /T2/hw/mock        │                  │
            │                  └─────────┬──────────┘                  │
            │                            │                             │
            └────────────────────────────┼─────────────────────────────┘
                                         │
                                         ▼
                           ┌────────────────────────────┐
                           │  stdlib/sim_universe/sim_agent  │ ← importable lib entry
                           │ (registry + router)            │
                           └────────────────────────────────┘
```

---

## Caveats (preserved from upstream)

Per-module "honest scope" boxes — see `dancinlab/sim-universe` (GitHub private) `README.md` for full text:

1. **`fvd` honest scope** — EXACT 2ᴺ unitary (N≤24) or 4ᴺ GKSL Lindblad mode (--lindblad). NOT decoherent (default mode), NOT lab device.
2. **`stark-fragmentation` honest scope** — EXACT 2ᴺ unitary at experimental N=24; only Q and E are exact symmetries; P is paper's emergent constraint. NOT L→∞.
3. **`supremacy-frontier`** — calibrates the XEB ruler at exactly-reachable n≲24 where classical simulation is easy; does NOT measure whether reality is simulable.
4. **`mbs-revival`** — strict-PXP + full-Rydberg engines, no Trotter; N≈26-28 + L→∞ ceiling.
5. **`fock-prethermal-dtc`** — no Trotter; period-doubling at ω=π/T; lab `T₁≈118 μs` not modeled.
6. **`z2-gauge-prethermal`** — gauge-invariant by construction (⟨G⟩≡+1); N≤7 / Q≤20 ceiling.
7. **`preheating-analog`** — exact 2-mode BdG, **no 2ᴺ wall** (each k-mode independent); ceiling is physical linear-Bogoliubov validity.
8. **`multipolar-prethermal`** — recovers universal α(n)=2n+1; area→volume entanglement crossover.
9. **`surface-code`** — stabilizer-formalism (Gottesman-Knill polynomial tableau), NOT 2ᴺ state vector; reproduces Λ=εᵈ/εᵈ⁺² suppression.
10. **`ssh-topology` / `hofstadter`** — single-particle ED, **no 2ᴺ wall** (2N×2N or q×q matrix); bulk-boundary correspondence / TKNN Chern numbers.
11. **`dqpt-loschmidt`** — exact 2ᴺ (Route A) + free-fermion closed-form (Route B, N→∞) cross-check.
12. **`wdw-minisuperspace`** — closed-form parabolic-cylinder D_ν + RK4 Bohmian, **no memory wall**.

---

## Layout (target — Phase A/B migration)

```
stdlib/sim_universe/
├── README.md                              # this file
├── sim_universe.hexa                      # CLI dispatcher (hexa sim-universe target)
├── sim_agent/                             # registry + router (importable lib entry)
├── anu_time/                              # τ-clock substrate
│   ├── mini_world.hexa
│   ├── anu_clock.hexa
│   ├── lorentz_metric.hexa
│   ├── field_action.hexa
│   ├── topology_universe.hexa
│   ├── quantum_universe.hexa
│   ├── universe.hexa
│   ├── universe_propagation.hexa
│   ├── universe_ensemble.hexa
│   ├── universe_pipeline.hexa
│   ├── scale_universe.hexa
│   ├── empirical_anchor.hexa
│   ├── empirical_anchor_v2.hexa
│   └── analyze.hexa
├── multiverse/                            # interferometer + KS + higher-order MI
├── qpu_bridge/                            # VQE-H2 + ANU noise adapter
├── ouroboros_qrng/                        # consumes stdlib/qrng/ (RFC 044)
├── godel_q/                               # Gödel-Q mutator + bootstrap + verify_gate
├── bostrom_test/                          # anu_collector pre-registered tests
├── atlas_anu_corr/                        # ATLAS xcorr + null baseline
├── anu_stream/                            # stream_daemon + chacha20
├── sr_harness/                            # sim-adjacent harness
└── experiments/                           # 16 standalone experiment modules
    ├── fvd/  fvd.hexa
    ├── stark_fragmentation/  stark_fragmentation.hexa
    ├── quantum_darwinism/  quantum_darwinism.hexa
    ├── ca_qm/  ca_qm.hexa
    ├── supremacy_frontier/  supremacy_frontier.hexa
    ├── mbs_revival/  mbs_revival.hexa
    ├── fock_prethermal_dtc/  fock_prethermal_dtc.hexa
    ├── z2_gauge_prethermal/  z2_gauge_prethermal.hexa
    ├── preheating_analog/  preheating_analog.hexa
    ├── multipolar_prethermal/  multipolar_prethermal.hexa
    ├── surface_code/  surface_code.hexa
    ├── ssh_topology/  ssh_topology.hexa
    ├── hofstadter/  hofstadter.hexa
    ├── dqpt_loschmidt/  dqpt_loschmidt.hexa
    └── wdw_minisuperspace/  wdw_minisuperspace.hexa

github.com/dancinlab/sim-universe (private) # frozen 묘비 (RFC 046)
└── (full v1.1.0 repo verbatim — local ~/core/archive_sim-universe/ retired 2026-05-17)
```

---

## RFC chain

- **RFC 044** — qrng absorption ✅ LANDED 2026-05-16
- **RFC 045** — qmirror absorption ⏸ pending (qmirror upgrade in flight; re-fetch when ready)
- **RFC 046** (this — scaffold) — sim-universe README + CLI integration + governance + 묘비 ✅ 2026-05-16
- **RFC 046-A** — substrate code migration (anu_time, multiverse, qpu_bridge, sim_agent, ouroboros_qrng, godel_q, sr_harness, atlas_anu_corr, anu_stream, bostrom_test ≈ ~14k LoC)
- **RFC 046-B** — 16 experiments migration (~18k LoC) + tests + per-experiment selftest sentinels
