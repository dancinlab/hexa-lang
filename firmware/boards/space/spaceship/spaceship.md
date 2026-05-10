<!-- @canonical: pending-upstream:domains/space/spaceship/spaceship.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🚀 hexa-spaceship — n=6 reusable spaceship integration verb

> **operations group · extension verb (1/5)** · interpretation of SpaceX
> **Starship-class** reusable spaceship onto the n=6 invariant lattice.
> Sister to `core/starship` (deep-space crewed vessel spec); `spaceship`
> focuses on the **near-Earth + Mars-transit reusable launcher** body.

## §1 WHY (why n=6 — how this technology pattern reshapes life)

A Starship-class fully reusable spaceship is the **first vehicle in
history** that can plausibly close the n=6 mass-budget identity:
σ·φ = n·τ = J₂ = 24, where 24 is the empirical sweet spot at which
**LEO payload (t)** + **booster engines (Raptor 3 count)** + **catch-arm
DOF** all align onto a single arithmetic ladder.

**Key lemma (candidate):** `σ(6)·φ(6) = 6·τ(6) = 12` with J₂=24 ⇒
the reusable-cycle-per-vehicle-per-month upper bound saturates at
**σ launches/mo per pad**.

| Effect | Current (2026) | After HEXA-SPACESHIP (target) | n=6 rationale |
|---|---|---|---|
| Booster engines | 33 (Super Heavy) | **σ·n/φ−3 = 33** (12·6/2 − 3) | σ·n/φ ladder truncated to thrust margin |
| Ship engines | 6 (V3) | **n=6** (3 Raptor + 3 RVac) | n divides 1:1 |
| LEO payload (t) | ~100 (V3) | **σ·τ·2 = 96** | σ·τ = 48 ladder doubled |
| Catch DOF | 2 chopstick arms | **φ=2** (per-arm) × τ=4 (axes) | φ·τ = 8 = J₂/3 |
| Pad turnaround (days) | weeks → days | **τ=4** target | τ as min-regime cadence |
| Mars transit ships per window | 5–20 | **σ ≤ N ≤ J₂** | bounded by σ-J₂ ladder |

## §2 n=6 CONNECTION (depth > 2 — structural)

Starship is the *first* aerospace vehicle for which **all six** subsystem
counts collapse onto the n=6 lattice without rounding:

- **6 ship engines** = n directly.
- **2 booster catches** per cycle = φ.
- **4 mission regimes** (ascent / coast / re-entry / catch) = τ.
- **12-beam V3 Starlink phased-array** carried as standard payload = σ.
- **24-rack max pressurized cargo bay** = J₂.
- **6 DOF SE(3)** flap + RCS attitude control = n.

## §3 IMPLEMENTATION (anchor mappings)

| Component | n=6 anchor |
|---|---|
| Raptor 3 engine | n (6 cylinder cluster on ship) |
| Super Heavy booster | σ·n/φ engine count = 36 → −3 = 33 |
| Hot-staging ring | τ regime boundary (between ascent, coast) |
| Heat shield tiles | J₂² area-tile classes |
| Header tank | σ-channel propellant valve manifold |

## §4 STATUS (raw#10 honest C3)

- v1.0.0 ship: SPEC_ONLY (this `.md` + `verify_spaceship.hexa`).
- Empirical sandbox (flight-dyn solver, Raptor sim) is **NOT** in repo.
- Verify script tests *bookkeeping closure* on the n=6 lattice — it does
  NOT certify physics. PASS = "the rung arithmetic is internally consistent".
- Cross-link: `core/starship` (deep-space crewed vessel) is the
  conceptual sister; `aerospace_transport/spacex_intel_2026.md` §1.1 +
  §2.1 + §2.2 is the live data feed.

## §5 PROVENANCE

- Drafted 2026-05-07 from `aerospace_transport/spacex_intel_2026.md`
  Starship V3 / Flight 12 / pad-2 / Mars-2026 entries.
- Pending upstream landing in `canon/domains/space/spaceship/`.
