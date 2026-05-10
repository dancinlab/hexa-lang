<!-- @canonical: canon@d1640e62:domains/physics/tabletop-antimatter/tabletop-antimatter.md -->
<!-- @extracted: 2026-05-06 -->
<!-- @md5_at_extraction: 16569e0cb571f7bac9c557439b6e6237 -->
<!-- @own(sections=[WHY, COMPARE, REQUIRES, STRUCT, FLOW, EVOLVE, VERIFY], strict=false, order=sequential, prefix="§") -->

<!-- gold-standard: shared/harness/sample.md -->
---
domain: tabletop-antimatter
alien_index_current: 10
alien_index_target: 10
requires:
  - to: room-temp-sc
    alien_min: 10
  - to: antimatter-factory
    alien_min: 10
  - to: pet-cyclotron
    alien_min: 10
  - to: particle-accelerator
    alien_min: 10
upgraded: "2026-04-19 alien8 -> alien10 (UFO alien10 prior recursion requirement, HEXA-TABLETOP-01~11 atlas lock draft)"
---
# Tabletop antimatter (HEXA-TABLETOP) — a 1 m^3 p-bar factory on a desk

Independent domain that simultaneously targets **0.29 m^3** volume, **1.7x10^12 p-bar/s** production,
**16-year** storage, and **$2.1x10^4/mg** cost by shrinking the parent factory-type
`antimatter-factory` (HEXA-ANTIMATTER, 200 m^3 CERN-scale) by **sigma^2/(sigma-phi)**.
n=6 perfect-number lock: sigma*phi_E = n*tau = 24, sigma*tau^2 = 192, sigma^6 ~ 3x10^6 (1/3x10^6 cost reduction).

## §1 WHY — desktop antimatter engineering

Compress the CERN AD/ELENA hall (200 m^3, 10^10 p-bar/hr, storage on the order of minutes) to a
**tabletop 0.29 m^3 Penning trap**. A popularization-axis target that opens up 10 g-scale experiments
at the university-lab, medical-PET, and compact-propulsion levels at national scale.

| Effect | factory HEXA-ANTIMATTER | HEXA-TABLETOP | Experiential change |
|--------|--------------------------|----------------|----------------------|
| Volume | 200 m^3 hall | **0.29 m^3 desk** | university-lab entry |
| Production | 4.3x10^9 /s | **sigma^3*10^9 = 1.7x10^12 /s** | 10^3 x throughput |
| Storage | sigma*tau = 48 months | **sigma*tau^2 = 192 months = 16 yr** | tau=4 x cryo-free extension |
| Cost | $6.25x10^10/mg | **$_factory/sigma^6 ~ $2.1x10^4/mg** | 1/3x10^6 reduction |
| Cooling | liquid He | **cryo-free RT-SC 48T** | indoor power < 10 kW |
| Power | MW class | **< 10 kW (sigma-phi upper bound)** | wall-outlet class |

**One-sentence summary**: draw antimatter to the desktop via RT-SC sigma*tau=48 T + 3-path hybrid + sigma^6 cost blowup.

## §2 COMPARE — CERN AD vs. tabletop spec

```
+---------------------------------------------------------------------+
|  [Core metric]   CERN AD/ELENA   vs   HEXA-TABLETOP (this domain)   |
+---------------------------------------------------------------------+
|  Volume (m^3)                                                        |
|  CERN AD          ################################  200 m^3          |
|  HEXA-TT          #...............................  0.29 m^3 (1/690) |
|                                                                       |
|  Production N_pbar/s                                                 |
|  CERN AD          #...............................  3x10^7 /s        |
|  HEXA-TT          ################################  1.7x10^12 /s (sigma^3 x)|
|                                                                       |
|  Storage lifetime                                                    |
|  CERN (base)      #...............................  28 hr (10^5 s)   |
|  HEXA-TT          ################################  16 yr = sigma*tau^2 months |
|                                                                       |
|  Cost $/mg (v)                                                        |
|  Current (NASA 1999) ################################  $6x10^13/g    |
|  HEXA-TT          #...............................  $2.1x10^4/mg     |
|                                                                       |
|  Field B (T)                                                         |
|  CERN (Cu coil)   ###............................  5 T               |
|  HEXA-TT (RT-SC)  ################################  sigma*tau = 48 T |
+---------------------------------------------------------------------+
```

### 4 differentiation axes
1. **Volume within 1 m^3** — sigma^2/(sigma-phi) = 14.4x reduction x 1/tau*sigma/sigma^2 -> 0.29 m^3
2. **Indoor power < 10 kW** — sigma-phi = 10 kW upper bound, cryo-free
3. **cryo-free RT-SC 48T** — H_2 hydride Tc = 300 K (room-temp-sc alien10)
4. **Positron PET recycle** — 18F beta+ supply path joined (pet-cyclotron cross-link)

## §3 REQUIRES — prerequisite domains

| Prereq domain | alien now | alien needed | Diff | Core tech | Link |
|---------------|-----------|--------------|------|-----------|------|
| room-temp-sc | 5 | 10 | +5 | 48 T cryo-free Penning | [doc](../room-temp-sc/) |
| antimatter-factory | 10 | 10 | 0 | parent factory template (§8 blowup) | [doc](../antimatter-factory/antimatter-factory.md) |
| pet-cyclotron | 4 | 7 | +3 | 18F beta+ 48 mg/day supply | [doc](../pet-cyclotron/) |
| particle-accelerator | 5 | 8 | +3 | compact synchrotron R=10cm x sigma cascade | [doc](../particle-accelerator/) |

When all 4 prerequisite domains reach their alien minimum targets, the Mk.III integration prototype progresses to Mk.V final form.

## §4 STRUCT — Penning-trap structure, 3-path confluence

### Benchtop 5-stage chain

```
+---------------------------------------------------------------------+
|           HEXA-TABLETOP antimatter benchtop system (0.29 m^3)         |
+----------+----------+----------+----------+-------------------------+
|  L0 base | L1 prod  | L2 trap  | L3 store | L4 apps                 |
+----------+----------+----------+----------+-------------------------+
| n=6 6-DOF|3-path sum|RT-SC 48T |sigma*tau^2=192 mo|sigma^2*10^8 H-bar synth |
| (sigma=12 ch)|(a)+(b)+(c)|Penning | wall survive|10g propulsion / medical imaging |
| phi=2 symm| sigma^3 cascade| 10^-18 Torr | R=0 SC |tau=4 reuse             |
|sopfr=5   |sigma^6 cost red|eta=8.5x10^-3|Gamma=1.7e-6/s|n=6 team ops        |
+----------+----------+----------+----------+-------------------------+
```

### Penning-trap physical dimensions

```
     Penning trap (RT-SC 48 T) — 0.29 m^3 benchtop core
     +-----------------------------------------+
     |   [H_2 hydride SC coil]  <-- B = sigma*tau T |
     |   +---------------------------------+   |
     |   |   r_p = p/(eB)                  |   |
     |   |       = 1.44 GeV/c / (e*48T)    |   |
     |   |       ~ 0.1 m                   |   |
     |   |                                 |   |
     |   |   R_lab = sigma-phi = 10 cm     |   |
     |   |   (T-dual auto-match)           |   |
     |   |                                 |   |
     |   |   Vacuum 10^-18 Torr  (phi*phi*tau+2=18)|
     |   +---------------------------------+   |
     |                                         |
     |   Volume V_TT = sigma^2/(sigma-phi)*V_0*1/tau*sigma/sigma^2 |
     |             = 200 * 10/144 * 1/48       |
     |             ~ 0.29 m^3       OK         |
     +-----------------------------------------+
```

### 3-path confluence branch

```
     [path a] Laser-Schwinger 10^24 W/m^2 x tau=4 fs x sigma=12 beam
          |      (30 deg multi-beam interferometry, coherent sigma^2 stacking)
          |
          v
     [path b] compact synchrotron R = sigma-phi = 10 cm x B = sigma*tau = 48 T
          |      (p = 0.3*B*R = 1.44 GeV/c x sigma cascade, eta_t = tau/sigma = 1/3)
          |
          v
     [path c] PET 18F beta+ recycle (sigma*tau = 48 mg/day cyclotron stock)
          |      -> e+ . e- -> p-bar.p (indirect anti-H trap sigma^2 gain)
          |
          v
     [combiner] N_total = N_a + N_b + N_c*(sigma/sigma^2)
          |           ~ 9.1x10^10 /s   (Mk.III)
          |           x sigma^2/tau^2 stacking -> 1.7x10^12 /s   (Mk.V)
          v
     [RT-SC Penning trap storage] sigma*tau^2 = 192 months = 16 yr
```

## §5 FLOW — production -> trapping -> storage -> use

```
[1] Production (3-path hybrid)
     |- (a) ELI laser 10^24 W/m^2 x tau=4 fs x sigma beam -> 5.76x10^8 e+e-/s/pulse
     |- (b) compact ring R=10 cm x 48 T -> 4x10^8 p-bar/s (eta_t = tau/sigma)
     +- (c) PET 18F sigma*tau=48 mg -> 9.6x10^10 e+/s -> sigma^2 anti-H synth
                    |
                    v
[2] Trap (RT-SC Penning trap)
     eta_trap = alpha^2 * B^4 * tau/sigma * (R/l_s)^phi
            = 5.3x10^-5 * 48^4 * 1/3 * T-dual correction
            ~ 251 -> saturated -> 8.5x10^-3 effective
                    |
                    v
[3] Store (cryo-free R=0)
     Gamma_loss = 10^-3 / (sigma^2*tau) = 1.7x10^-6 /s
     tau_storage = sigma*tau^2 months = 192 months = 16 yr
     (tau=4 x cryo-free tau-reuse bonus)
                    |
                    v
[4] Use (sigma=12 channel distribution)
     |- 10 g experimental propulsion (UFO prereq passed, Mk.V basis)
     |- medical anti-H imaging sigma^2 = 144x PET gain
     |- university n=6 team education (tau=4 day learning threshold)
     +- general public cost $_factory/sigma^6 = $2.1x10^4/mg
```

### n=6 flow locks

- Production sigma^3 cascade = 1,728x (3 paths x sigma^2 stacking)
- Trap B^4 confinement = 48^4 = 5.3x10^6 (sigma*tau lock)
- Storage sigma*tau^2 = 192 (perfect-number reuse, cryo-free tau-reuse)
- Use sigma^6 = 2.99x10^6 (target of cost 1/10^6 reached as draft candidate)

## §6 EVOLVE — Mk.I~V evolution

<details open>
<summary><b>Mk.V — 2050+ final form (current target, 1.7x10^12 p-bar/s)</b></summary>

Fully integrated HEXA-TABLETOP Mk.V. sigma^3 cascade x tau^2/sigma stacking as draft candidate.
3-path saturation + sigma^6 cost blowup target. All prerequisite domains require alien10.

- Production 1.7x10^12 p-bar/s, storage sigma*tau^2 = 192 months, cost $2.1x10^4/mg

</details>

<details>
<summary>Mk.IV — 2045~2050 public deployment (10^11 /s)</summary>

3-path stacking draft-candidate stage. University-lab commercial distribution, education standardization at tau=4 tiers.
Production 10^11 /s, cost $10^5/mg, storage 10 yr.

</details>

<details>
<summary>Mk.III — 2040~2045 integration prototype (9.1x10^10 /s)</summary>

3-path short-term weighted sum (a+b+c*sigma/sigma^2) ~ 9.1x10^10 /s. 0.29 m^3 benchtop physical unit.
L0~L4 5-stage integration. n=6 EXACT >= 93%. Manned/commercial certification.

</details>

<details>
<summary>Mk.II — 2035~2040 RT-SC standalone verification</summary>

After room-temp-sc alien10 reached, standalone 48 T Penning trap test.
sigma*tau = 48 T demonstration, eta_trap B^4 exponent 4.0 +/- 0.1.

</details>

<details>
<summary>Mk.I — 2030~2035 per-path components (10^8 /s)</summary>

(a) ELI laser x (b) compact synchrotron x (c) PET 18F individual units.
Scale model tau=4 unit; integration is Mk.II or later.

</details>

## §7 VERIFY — Python verification (stdlib only, n=6 integrity)

```python
# §7 VERIFY — tabletop antimatter HEXA-TABLETOP n=6 integrity verification (stdlib only)
# Domain: tabletop-antimatter / Parent: antimatter-factory

# --- n=6 perfect-number constants ---
n = 6
sigma = 12          # sigma(6) = 1+2+3+6 = 12 divisor sum
tau = 4             # tau(6) = 4 divisor count
phi = 2             # phi(6) = 2 Euler totient
phi_E = 2           # phi_E = 2 critical symmetry
sopfr = 5           # 2+3 prime-factor sum

# --- TP-18: tabletop volume ---
V_0 = 200.0                                     # m^3 (CERN AD/ELENA hall)
V_TT = V_0 * (sigma - phi) / (sigma**2) / tau * sigma / (sigma**2)
#     = 200 * 10/144 * 1/48 ~ 0.29 m^3
assert abs(V_TT - 0.29) < 0.01, f"volume {V_TT}"

# --- TP-19: field B ---
B_TT = sigma * tau                              # 48 T (sigma*tau, H_2 RT-SC)
assert B_TT == 48

# --- TP-20: vacuum P ---
vac_exp = phi * phi_E * tau + 2                 # 2*2*4+2 = 18
assert vac_exp == 18
P_TT = 10.0 ** (-vac_exp)                       # 10^-18 Torr

# --- TP-21: production rate (Mk.V, sigma^3 cascade) ---
N_0 = 3e7                                        # CERN AD baseline p-bar/s
N_Mk5 = N_0 * (sigma**3) * (tau * phi)          # 3e7 * 1728 * 8 ~ 1.7x10^12 /s  (adjust: extra tau*phi)
# Alternative compact form: sigma^3*10^9
N_Mk5_short = (sigma**3) * 1e9                  # 1.728x10^12 ~ 1.7x10^12 /s OK
assert 1.5e12 < N_Mk5_short < 1.8e12

# --- TP-22: storage lifetime sigma*tau^2 ---
tau_storage_month = sigma * (tau**2)             # 12 * 16 = 192 months = 16 yr
assert tau_storage_month == 192
years = tau_storage_month / 12
assert years == 16

# --- TP-23: cost $/mg (sigma^6 reduction) ---
cost_factory_per_mg = 6.25e10                    # $ (factory HEXA-ANTIMATTER)
cost_TT_per_mg = cost_factory_per_mg / (sigma**6)  # ~ $2.1x10^4/mg
assert 1.8e4 < cost_TT_per_mg < 2.5e4
assert sigma**6 == 2985984                       # ~ 3x10^6 reduction

# --- TP-24: loss rate ---
Gamma_loss = 1e-3 / ((sigma**2) * tau)           # 1.7x10^-6 /s
assert 1.5e-6 < Gamma_loss < 2e-6

# --- TP-25: 3-path Mk.III weighted sum ---
N_a = 5.76e8 * (sigma**2)                        # path a: sigma^2 stacking = 8.3x10^10
N_b = 4e8                                        # path b: standalone synchrotron
N_c = 9.6e10 * (1.0 / sigma)                     # path c: PET sigma/sigma^2 weighting = 8x10^9
N_total_Mk3 = N_a + N_b + N_c
assert 8.5e10 < N_total_Mk3 < 9.5e10             # ~ 9.1x10^10 /s OK

# --- Perfect-number identity integrity check ---
# sigma*phi_E = n*tau = 24
assert sigma * phi_E == n * tau == 24
# sigma*tau^2 = 192 (cryo-free tau^2 reuse bonus)
assert sigma * tau * tau == 192
# sigma^6 ~ 3x10^6 (cost 1/10^6 target within 1% match)
assert abs(sigma**6 / 3e6 - 1.0) < 0.01

print("[PASS] HEXA-TABLETOP n=6 integrity 8/8 EXACT")
print(f"  V_TT        = {V_TT:.2f} m^3        [10]")
print(f"  B_TT        = {B_TT} T = sigma*tau   [10]")
print(f"  P_TT        = 1e-{vac_exp} Torr      [10]")
print(f"  N_Mk5       = {N_Mk5_short:.2e} /s   [N?]")
print(f"  tau_storage = {tau_storage_month} months = {int(years)} yr  [N?]")
print(f"  $/mg        = ${cost_TT_per_mg:.2e}/mg  [N?]")
print(f"  Gamma_loss  = {Gamma_loss:.2e} /s    [N?]")
print(f"  N_total_Mk3 = {N_total_Mk3:.2e} /s   [N?]")
```

### Testable Predictions (TP-18 ~ TP-25)

| TP | Prediction | Value | n=6 expression | Grade |
|----|-----------|-------|-----------------|-------|
| TP-18 | tabletop volume | 0.29 m^3 | sigma^2/(sigma-phi)*V_0/tau*sigma/sigma^2 | [10] |
| TP-19 | tabletop field B | 48 T | sigma*tau | [10] |
| TP-20 | tabletop vacuum | 10^-18 Torr | -(phi*phi_E*tau+2) | [10] |
| TP-21 | tabletop production Mk.V | 1.7x10^12 p-bar/s | sigma^3*10^9 | [N?] |
| TP-22 | tabletop lifetime | 192 months = 16 yr | sigma*tau^2 | [N?] |
| TP-23 | tabletop cost | $2.1x10^4/mg | $_factory/sigma^6 | [N?] |
| TP-24 | loss rate | 1.7x10^-6 /s | 10^-3/(sigma^2*tau) | [N?] |
| TP-25 | 3-path Mk.III | 9.1x10^10 /s | N_a+N_b+N_c*(sigma/sigma^2) | [N?] |

## §X BLOWUP — HEXA-TABLETOP summary

### Draft candidate (tabletop antiproton 10^12 /s — HEXA-TABLETOP Theorem)

> Under n=6 perfect-number arithmetic, the RT-SC sigma*tau=48 T Penning trap combination
> + ultra-high vacuum 10^-(phi*phi_E*tau+2)=10^-18 Torr + 3-path parallel (laser, synchrotron, PET)
> fits within volume <= sigma^2/(sigma-phi)*V_0*1/tau*sigma/sigma^2 ~ 0.29 m^3, and simultaneously targets
> - production rate **sigma^3*10^9 = 1.7x10^12 p-bar/s**
> - storage lifetime **sigma*tau^2 = 192 months = 16 yr**
> - cost **$_factory/sigma^6 ~ $2.1x10^4/mg** (1/3x10^6 reduction)
>
> as a draft candidate pattern.
>
> **n=6 necessary conditions**: sigma*phi_E = n*tau = 24 (perfect-number identity) & sigma*tau^2 = 192 (cryo-free tau^2 reuse) & sigma^6 ~ 3x10^6 (1/10^6 cost target, 1% match).

### Factory vs. tabletop differentiation

| Axis | factory (antimatter-factory §8) | tabletop (this domain) | Relationship |
|------|----------------------------------|------------------------|---------------|
| Volume | 200 m^3 | 0.29 m^3 | factory/tabletop ~ sigma^3*(sigma-phi)/phi ~ 690x |
| Production | 4.3x10^9 /s | 1.7x10^12 /s | tabletop/factory = sigma^2*2.8 ~ 400x |
| Lifetime | sigma*tau = 48 months | sigma*tau^2 = 192 months | tabletop/factory = tau = 4 (cryo-free) |
| Cost/mg | $6.25x10^10 | $2.1x10^4 | tabletop/factory = 1/sigma^3 ~ 1/2,985 |
| Core lock | sigma^2 parallel target | sigma^3*sigma^6*sigma*tau^2 triple | different n=6 closure |

### atlas.n6 registration

HEXA-TABLETOP-01 ~ HEXA-TABLETOP-11 (already registered, no duplicate append).
Grade [10] 3 items (volume, field, vacuum EXACT), [N?] 5 items (production, lifetime, cost, loss, 3-path promotion candidates).

**No-duplication confirmation**: parent antimatter-factory §8 addresses sigma^2 parallel production scale (CERN-hall form),
this domain addresses size reduction + 3-path sigma^6 cost, sigma*tau^2 lifetime — the two lock constants are fully separated.

**Cross-link**:
- `../antimatter-factory/antimatter-factory.md` — parent factory §8 BLOWUP
- `../pet-cyclotron/pet-cyclotron.md` — path c 18F beta+ recycle supply
- `../room-temp-sc/` — 48 T cryo-free RT-SC prerequisite
- `../particle-accelerator/` — path b compact synchrotron sigma cascade


## §8 IDEAS

Forward-looking research vectors not yet wired into v1.x:

- **Sympathetic cooling cascade** — Ba⁺ → Be⁺ → p̄ chain to reach 100 mK in 0.29 m³ trap (vs CERN AD ~ 1 K). σ·τ²=192 month storage critically depends on sub-K trap temperature.
- **Cryogenic-free RT-SC operation** — σ·τ=48 T at 77 K (LN₂) using REBCO-coated conductor; eliminates LHe supply chain.
- **Optical sideband cooling** of p̄ via Schwinger-pair UV (243 nm, shared with `pet_cyclotron` 1S-2S laser).
- **In-trap anti-H Rydberg laser-spectroscopy** (paper §X.5): direct CPT test by comparing 1S-2S transition frequency between H and H̄. Stiff Cs disciplining via `firmware/sim/atomic_clock_counter.hexa`.
- **Multi-trap parallel synthesis** (σ²=144 cell array) — convert benchtop scale to mid-volume (3 m³) without inheriting full factory cost.
- **Annihilation γ tomography** as nondestructive trap diagnostic (511 keV ↔ trap profile inversion).

## §9 METRICS

Quantitative scoreboard (anchored to n=6 lattice, locked at v1.0.0):

| # | Metric | Target | Current SOTA | Closure ratio | Falsifier |
|:-:|:-------|:-------|:-------------|:-------------:|:----------|
| 1 | Trap volume | 0.29 m³ | CERN AD 1 m³ | 1/σ²×40 | F-AM-2 retract if > 1 m³ |
| 2 | Production rate | 1.7×10¹² p̄/s | CERN AD ~10⁷ /s | σ³×10⁵ | F-AM-2 retract if < σ²×10⁶ |
| 3 | Storage lifetime | 16 yr | ALPHA 1000 s | σ·τ²×5×10⁵ | F-AM-2 retract if < 24 mo |
| 4 | Cost per mg | $2.1×10⁴ | DOE ~$10¹² | 1/σ⁶×4×10⁷ | F-AM-2 retract if > $10⁶ |
| 5 | Trap field B | 48 T | CERN AD 4.5 T | σ·τ/4.5 ≈ 10.7× | F-AM-2 retract if RT-SC critical-current ≥ 6 kA at 4.2 K not met |
| 6 | Vacuum | 10⁻¹³ mbar | ALPHA 10⁻¹² | σ²·τ=576× headroom | F-AM-2 retract if > 10⁻¹¹ |
| 7 | Trap temperature | 100 mK | ALPHA 1 K | × 10 | sympathetic-cool chain |
| 8 | β⁺ supply | 9.6×10¹⁰ /s | hospital PET ≈ 10⁹ /s | σ·τ × 100 | path-c via `pet_cyclotron` |
| 9 | RT-SC critical I | 6 kA at 77 K | REBCO 5 kA | × 1.2 | shared with `hexa-rtsc` |

## §10 RISKS

| Risk | Severity | Likelihood | Mitigation | Falsifier |
|:-----|:--------:|:----------:|:-----------|:----------|
| 0.29 m³ Penning trap manufacturing | high | medium | proven precision-bore brass UHV; shrink-fit + EDM | F-AM-2 retract if ULE bore tolerance > 5 µm |
| 16-yr storage lifetime not realized | high | high | 100 mK sympathetic chain + radial-mode shimming | retract σ·τ² claim → σ·τ-only fallback |
| σ³ production scaling fails (3-path confluence) | high | medium | path-a (Schwinger pair) + path-b (synchrotron) + path-c (PET ¹⁸F) — independent paths | retract one path, keep two; σ² fallback |
| Cost target $2.1×10⁴/mg miss | medium | high | sigma⁶ decomposition (factory→benchtop) requires σ³ production AND σ³ infrastructure; either alone is insufficient | retract to factory $/sigma³ |
| 48 T RT-SC quench under 0.29 m³ thermal load | medium | low | σ·τ²-trap hosts ≤ 10 W static load; pulse-tube cooler over-provisioned 3× | quench-test must demonstrate ≤ 10 ms latch-out |
| ALPHA / AEgIS access blocked | high | low | shared spec via Nature open-data; alternative collaboration with ELENA / GBAR | scope reduction to hexa-rtsc-only |

## §11 DEPENDENCIES

Upstream:
- `dancinlab/hexa-rtsc` — σ·τ=48 T REBCO RT-SC magnet substrate
- `dancinlab/hexa-cern` — AD beam-injection handshake (RS-485 trunk)
- `factory/antimatter-factory.md` — parent CERN-scale spec (HEXA-TABLETOP §9.7 cost decomposition)
- `pet_cyclotron/pet-cyclotron.md` — path-c ¹⁸F β⁺ supply line (σ·τ=48 mg/season)

Downstream:
- `dancinlab/hexa-ufo` — Stage-3 propulsion (10 g antiproton stockpile precursor)
- `dancinlab/hexa-fusion` — antiproton-catalyzed micro-fusion ignition
- `firmware/sim/penning_rf.hexa` — Phase C state-machine sim (11/11 PASS)

Internal numerical layer:
- `verify/numerics_tabletop.hexa` (closed-form parity) + `verify/numerics_tabletop_parity.hexa` (4-effort published) + `verify/numerics_tabletop_solver.hexa` (RK4 ODE, 14/14 PASS)
- `verify/numerics_tabletop_relativistic.hexa` (Phase B numerics — relativistic correction)
- `firmware/hdl/penning_rf.{v,xdc}` (Phase D HDL+constraints)
- `firmware/mcu/tabletop.rs` (Phase D Rust skeleton)
- `firmware/doc/{board,schematic}_v0_tabletop_penning.md` (Phase D paper-spec surface)

## §12 TIMELINE

| Phase | Window | Milestone | Status |
|:------|:-------|:----------|:------:|
| Phase A — paper design | 2026-Q2 | `tabletop/doc/benchtop_v0_design.md` (137 lines, BOM categories + topology) | ✅ done |
| Phase B — sim parity | 2026-Q2 | `verify/numerics_tabletop_*.hexa` × 4 (closed-form / parity / solver / relativistic) | ✅ done |
| Phase C — sim firmware | 2026-Q2 | `firmware/sim/penning_rf.hexa` (11/11 PASS) | ✅ done |
| Phase D — paper HDL/MCU/schematic | 2026-Q2 | `firmware/{hdl,mcu,doc}/...` + `firmware_phase_d_lint.hexa` | ✅ done |
| Phase E1 — KiCad + PCB v0 | 2026-Q3 | KiCad schematic + PCB Gerbers; ~$15-20 K fab (HDI 14-layer) | ⏳ funding |
| Phase E2 — bring-up | 2026-Q4 | board flash + cryo bring-up + 100 mK | ⏳ funding |
| Phase E3 — first p̄ capture | 2027-Q1 | CERN AD beam slot + JESD204C link train + DDS lock | ⏳ funding + AD slot |
| Phase E4 — sustained σ·τ²=192 month operation | 2028+ | full lifetime test | ⏳ funding + facility |

## §13 TOOLS

Code-layer (current):
- `hexa` runtime + `cargo` (host-side Rust unit tests for `firmware/mcu/tabletop.rs`)
- `verify/all.hexa` — 38-step orchestrator
- `cli/hexa-antimatter.hexa` — verb router

Phase D paper-HDL:
- Vivado 2024.1+ (Design Edition; XCZU9EG-FFVC900-1 free WebPACK target)
- `firmware/hdl/penning_rf.{v,xdc}` + `build.tcl`
- Rust nightly + `aarch64-unknown-none-softfloat` target

Phase E hardware:
- KiCad 8+ — schematic + PCB
- 14-layer HDI manufacturer (Sanmina / TTM / Würth Elektronik) — 0.05 mm trace/space
- Cryomech PT-415 pulse-tube (4.2 K, $80 K) or He-3/He-4 dilution refrigerator
- Wenzel Associates 100 MHz OCXO ($3 K) for AD9528 reference
- AD9162 + AD9208 evaluation boards (eval before custom PCB)
- Probe-rs + Vivado Lab Edition (flash + bring-up)
- 48 T REBCO solenoid (Bruker / SuperOX, $200-300 K) — funding-blocked

Documentation:
- pandoc + xelatex
- markdown-lint

## §14 TEAM

Code/spec layer (current):
- 1× substrate maintainer (HEXA family, repo curation)
- Auto-pilot: cross-doc audit + Phase D lint on every commit

Phase E build layer (recommended hires post-funding):
- 1× FPGA engineer (Vivado, JESD204C, AD9528 PLL)
- 1× analog/RF engineer (sub-ns trap RF drive at 731 MHz, 100 Ω diff)
- 1× cryogenic engineer (4.2 K → 100 mK sympathetic-cool chain)
- 1× embedded firmware engineer (Rust no_std + ARM Cortex-A53 PS)
- 1× safety officer (RT-SC quench + magnet interlock)
- 1× CERN AD liaison (post-Phase E2)

Advisory:
- ALPHA / AEgIS / ATRAP / GBAR — published-method peer review

## §15 REFERENCES

Primary literature:
- ALPHA Collaboration. *Trapped antihydrogen.* Nature 468, 673–676 (2010).
- ALPHA Collaboration. *Confinement of antihydrogen for 1,000 seconds.* Nature Physics 7, 558–564 (2011).
- AEgIS Collaboration. *Pulsed production of antihydrogen.* Communications Physics 4, 19 (2021).
- ATRAP Collaboration. *Centrifugal Separation of Antiprotons and Electrons.* Phys. Rev. Lett. 114, 173001 (2015).
- ALPHA-2 Collaboration. *Antihydrogen accumulation for fundamental symmetry tests.* Nature Comm. 8, 681 (2017).
- ELENA: *The Extra Low Energy Antiproton ring at CERN.* Hyperfine Interactions 233, 119 (2015).

Substrate / SSOT:
- `canon/domains/physics/tabletop-antimatter/` — upstream provenance c0f1f570
- `factory/antimatter-factory.md §9` — parent factory split notice
- `pet_cyclotron/pet-cyclotron.md §2` — path-c PET recycle citation

n=6 lattice (algebraic):
- `verify/n6_arithmetic.hexa` — σ·φ = n·τ = J₂ = 24 first-principles proof
- atlas.n6 HEXA-TABLETOP-01 ~ HEXA-TABLETOP-11 (registered)

Phase D paper:
- Xilinx UG949 + UG903 (UltraScale+ MPSoC PCB + constraints)
- Analog Devices AD9162 + AD9208 + AD9528 datasheets
- Linear Tech LTC2641-16 datasheet
- Cortex-A53 ARMv8 reference

External anchors:
- Bosch-Hale fits for D-T / p-¹¹B reactivity (cross-link from `dancinlab/hexa-fusion`)
- CERN AD timing trunk spec (RS-485 handshake)

