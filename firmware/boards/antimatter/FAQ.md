# FAQ — hexa-antimatter

> Quick answers to the most common questions.  Cross-reference in
> `CONTRIBUTING.md`, `ARCHITECTURE.md`, and the per-pillar SSOTs.

---

## Repository scope

### Q1. Does this repo synthesize anti-hydrogen?
**No.**  This is a substrate spec — paper specifications + closed-form algebra + numerical sim.  No working apparatus, no clinical PET cyclotron, no real p̄ capture.  Per raw#10 honest C3 (see `factory/antimatter-factory.md §0`).

### Q2. Why are there 4 `verify/empirical_*_inspire.hexa` if there's no real apparatus?
They query the INSPIRE-HEP API (with offline fixtures via `HEXA_ANTIMATTER_OFFLINE=1`) for the **published-paper existence** of milestone results.  This is the T3 *paper-feed* tier — closes T3 in bookkeeping but **not** in empirical fact.  Real T3 closure happens at Stage-1+ when `state/*_LOG.hexa` ingests live data.

### Q3. What does "100% closure" mean if no hardware exists?
It means **bookkeeping-closure**: every falsifier has T1 algebra + T2 ×4 numerics + T3 paper-feed registered on disk.  It does NOT mean "the n=6 lattice is empirically validated."  See `ARCHITECTURE.md §6` (honest negative).

### Q4. Why is `cyclotron_trigger.v` only 19 lines while other HDLs are 100+?
Because the PET cyclotron board (HEXA-PET-FW-01) is **MCU-only** — no FPGA.  The `.v` file exists as a Phase D inventory placeholder so all 4 boards have a parallel slot.  Real cyclotron logic lives in `firmware/mcu/pet_cyclotron.rs` (134 lines).

---

## n=6 lattice

### Q5. Why σ=12, τ=4, φ=2, J₂=24?
- σ(6) = 12 = sum of divisors of 6 (perfect-number anchor)
- τ(6) = 4 = number of divisors of 6
- φ(6) = 2 = Euler totient of 6
- J₂ = 24 = 24-element finite group (octahedral O ⊂ icosahedral I)
- Master identity: σ · φ = n · τ = J₂ = 24 (pinned by `verify/n6_arithmetic.hexa` from first principles)

### Q6. Is the n=6 lattice physically meaningful?
The lattice is an **organizing scaffold**, not a physical theory.  It's used to anchor candidate numerical targets (R = σ-φ = 10 cm, B = σ·τ = 48 T, etc.) onto a single algebraic substrate.  Empirical validation per axis is **not claimed** at v1.1.0.

### Q7. Why σ·τ = 48 specifically (not 47, not 49)?
Because σ = 12 and τ = 4 individually anchor distinct meanings (12 archetypes, 4-stage ladder); their product 48 is what the magnet-design column inherits.  The choice of σ = 12 (not 11 or 13) traces back to the perfect-number σ(6) = 12; it's not a free parameter.

---

## Build / verify

### Q8. How do I run all verifiers?
```bash
hexa run verify/all.hexa            # 38/38 PASS expected
```
If you don't have a running `hexa` interpreter:
```bash
~/.hx/packages/hexa/hexa.real run verify/all.hexa     # direct binary
```

### Q9. Some verifiers fail with "fork resource unavailable"
That's a system-level limit on the host (`ulimit -u` on macOS/Linux).  Each `.hexa` script forks subprocesses for `exec("cat ...")` calls.  If many launchd watchers are running concurrently (especially `dev.hexa-lang.hexa-runtime-*`), the fork limit can be hit.  Mitigation: kill stale processes (`pkill -9 -f hexa.real`), or run individual verifiers serially.

### Q10. How do I add a new T2 numerics verifier?
Follow `CONTRIBUTING.md §3` and recipe §2 (7-step cycle): chunk select → write → run standalone → wire CLI/tests/falsifier/lint → regression `verify/all` + `tests/test_all` → CHANGELOG entry → commit.

---

## Phase A → E

### Q11. What's the difference between Phase A, B, C, C.5, D, E?
| Phase | Artefact | Status (v1.1.0) |
|:------|:---------|:---------------:|
| A — paper benchtop design | `*/doc/benchtop_v0_design.md` | ✅ done |
| B — sim parity numerics | `verify/numerics_*_relativistic.hexa` etc. | ✅ done |
| C — sim firmware | `firmware/sim/*.hexa` (4 controllers, 46/46 PASS) | ✅ done |
| C.5 — board-level paper-spec | `firmware/doc/{board,schematic}_v0_*.md` | ✅ done |
| D — paper HDL/MCU | `firmware/{hdl,mcu}/*` + Phase D lint | ✅ done |
| E — real hardware | KiCad / fab / flash / live data | ⏳ funding |

### Q12. When will Phase E start?
When external funding lands.  See `firmware/doc/PHASE_E_HARDWARE_PATH.md` § funding ladder.  Roughly:
- $0 — KiCad files (volunteer hours)
- $5 K — Board 1 (PET cyclotron) fab + assembly
- $25 K — Board 2 (tabletop Penning) fab + cryo
- $50 K — Board 3 (atomic clock) fab + 1S-2S laser bench
- $115 K — all 4 boards fabbed
- $1 M — full Stage-1 prototype operational
- $50 M — factory-scale (Phase E5, post-this-repo)

---

## Cross-substrate

### Q13. What's the relationship to `dancinlab/hexa-fusion`?
Sister substrate — same recipe (`runnable_surface_recipe.md`), same n=6 lattice, different domain (fusion vs antimatter).  Both reached RSC closure at v1.1.0 on 2026-05-08 (parallel saturation).  Cross-link in `tabletop/tabletop-antimatter.md §13` (Bosch-Hale fits).

### Q14. What about `dancinlab/hexa-cern`?
Accelerator cousin — covers compact-accelerator substrate.  CERN AD beam-injection handshake (`firmware/sim/penning_rf.hexa`) is shared.  RSC pattern was first applied to `hexa-cern` (15-iter case study) and then to other hexa-* repos.

### Q15. What about `dancinlab/hexa-rtsc`?
RT-SC magnet substrate — provides σ·τ=48 T magnet for both `factory` and `tabletop` pillars.  Phase E hardware integration depends on `hexa-rtsc` reaching its own Phase E milestones first.

### Q16. Why is `dancinlab/hexa-ufo` mentioned as downstream?
`hexa-ufo` is a Stage-3 propulsion substrate that consumes p̄ fuel from this repo.  Currently an aspirational dependency (no live coupling); becomes real at Phase E5 (factory operational).

---

## License + attribution

### Q17. Can I cite this repo in academic work?
Yes — under MIT, with attribution.  Cite as:
```
hexa-antimatter v1.1.0 (2026-05-08), https://github.com/dancinlab/hexa-antimatter
provenance: canon@c0f1f570
```

### Q18. Can I fork and apply the recipe to another domain?
Yes — that's the recipe's purpose (`recipe §6`: "다른 hexa-* 프로젝트로 옮길 때 주의점").  Worked examples: `hexa-cern`, `hexa-fusion`, `hexa-antimatter` (this repo).

---

## Misc

### Q19. The repo has Korean comments in some `.hexa` files. Why?
Maintainer's primary working language for non-spec narrative.  All canonical SSOT and external-facing docs (README, ARCHITECTURE, CONTRIBUTING, CHANGELOG, RELEASE_NOTES, FAQ) are in English; only iter-internal commentary or one-line notes inside `.hexa` are bilingual.  PRs welcome to translate any holdouts.

### Q20. Is there a Discord / mailing list?
Not yet.  Issues + PRs + GitHub discussions are the only channels.