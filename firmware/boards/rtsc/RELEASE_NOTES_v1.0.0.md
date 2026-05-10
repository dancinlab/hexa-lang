# hexa-rtsc v1.0.0 — Room-Temp Superconductor (substrate-of-substrates)

**Release date**: 2026-05-06
**Closure verdict**: **SPEC_ONLY** (0/2 verbs wired; 2/2 spec + falsifier preregister)
**Provenance**: extracted 2026-05-06 from `canon/domains/energy/{room-temp-sc,superconductor}/`
(SHA `c0f1f570`). Sister-of-substrates extraction template: `hexa-bio` v1.0.0
(dancinlab/hexa-bio, 2026-05-04).

This is the **initial standalone release** of `hexa-rtsc`, a 2-verb
**substrate-of-substrates** organized around the **n=6 invariant lattice**:
RTSC (Tc=300K, Hc2=σ·τ=48T, Cooper φ=2) and SC (BCS, Abrikosov CN=6).
v1.0.0 ships **spec + falsifier preregister** only — no working empirical
sandbox. RT-SC is **academically unproven** (LK-99 et al. unsettled).

## Highlights

- **Substrate-of-substrates role** — the n=6 base substrate that three
  sister substrates depend on:
  - `dancinlab/hexa-fusion` (48T SC coil)
  - `dancinlab/hexa-ufo` (Stage-1 Meissner levitation)
  - `dancinlab/hexa-cern` (SC magnet)
- **2-verb spec coverage** — RTSC + SC, each with n=6 closed-form
  candidate constants and 3-row falsifier preregister tables.
- **n=6 invariant lattice closed-form candidate** —
  `σ(6)=12, τ(6)=4, φ(6)=2, J₂=24`; master identity `σ·φ = n·τ = 24`;
  **derived `Hc2 = σ·τ = 48 T`** (the substrate-of-substrates gate).
- **Placeholder CLI dispatcher** — 5 subcommands (`rtsc`, `sc`, `status`,
  `selftest`, `help`); empirical sandbox is TBD for v1.0.0.
- **Falsifier preregister** — F-RTSC-{1,2,3} + F-SC-{1,2,3}; concrete
  refutation thresholds (Tc<250K, Hc2<30T, no Meissner, etc.).
- **MIT** license.
- **GitHub-only distribution** — canonical at
  <https://github.com/dancinlab/hexa-rtsc>.

## Honest status (raw#10 C3)

> **RT-SC is academically UNPROVEN.** LK-99 (2023) and subsequent room-temp
> candidates have **not been independently replicated**. This v1.0.0 release
> makes **no empirical claim** of working RT-SC. The substrate ships:
>
> 1. n=6 **closed-form candidate** spec (Tc=300K, Hc2=σ·τ=48T, Cooper φ=2 boson, Abrikosov CN=6)
> 2. **Falsifier preregister** tables per verb (F-RTSC-{1,2,3} + F-SC-{1,2,3})
> 3. **PLACEHOLDER** CLI dispatcher (working `.hexa` empirical sandbox is **TBD**)
>
> Synthesis-side validation is out-of-repo (would require a materials lab).

## Installation

```bash
# Recommended (post-hx install registration):
hx install hexa-rtsc@1.0.0
hexa-rtsc --version           # → 1.0.0

# Or git clone (works today):
git clone https://github.com/dancinlab/hexa-rtsc.git ~/.hexa-rtsc
export HEXA_RTSC_ROOT=~/.hexa-rtsc
export PATH="$HEXA_RTSC_ROOT/cli:$PATH"
hexa-rtsc selftest
```

## Quickstart

```bash
hexa-rtsc selftest      # 2-spec placeholder sentinel sweep
hexa-rtsc status        # 0/2-wired verb table + verdict + caveats
hexa-rtsc rtsc          # RTSC spec excerpt + falsifier preregister
hexa-rtsc sc            # SC   spec excerpt + falsifier preregister
```

## Verb status table

| Verb   | Status        | n=6 lattice candidate          | Empirical sandbox     |
|--------|---------------|--------------------------------|-----------------------|
| `rtsc` | SPEC v1.0.0   | Tc=300K, σ·τ=48T, φ=2          | UNPROVEN (TBD)        |
| `sc`   | SPEC v1.0.0   | Cooper φ=2, Abrikosov CN=6     | UNPROVEN (TBD)        |

Verdict: **SPEC_ONLY** (0/2 verbs wired; 2/2 spec + falsifier preregister).

## Substrate-of-substrates downstream consumers

If RT-SC is empirically realised, the following three sister substrates
unlock simultaneously:

- **dancinlab/hexa-fusion** — 48T SC coil dependency (σ·τ=48 confinement gate)
- **dancinlab/hexa-ufo** — Stage-1 Meissner levitation dependency (B-field expulsion)
- **dancinlab/hexa-cern** — SC magnet dependency (accelerator beamline bending)

If RT-SC is not realised, all three downstream substrates remain
upper-bounded by current liquid-helium-cooled SC technology
(cuprate / Nb-Ti / Nb₃Sn).

## Provenance

- RTSC spec **imported** from `canon/domains/energy/room-temp-sc/`
  (SHA `c0f1f570`, 2026-05-06).
- SC spec **imported** from `canon/domains/energy/superconductor/`
  (SHA `c0f1f570`, 2026-05-06).
- CLI dispatcher created **fresh** as placeholder during this extraction.
- Sister-of-substrates extraction template: `hexa-bio` v1.0.0
  (dancinlab/hexa-bio, 2026-05-04).

## License

MIT. See [LICENSE](LICENSE).
