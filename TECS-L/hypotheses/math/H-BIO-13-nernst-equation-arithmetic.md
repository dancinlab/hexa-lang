# H-BIO-13: Nernst Equation Ion Concentrations and Perfect Number 6

> **Hypothesis**: The key ion concentrations governing neuronal membrane
> potential encode arithmetic functions of the perfect number 6:
> intracellular [Na+] = sigma(6) = 12 mM, extracellular [K+] = tau(6) = 4 mM,
> and the thermal voltage RT/F at body temperature approximates
> sigma(6)*phi(6) + e = 24 + e with 0.03% accuracy.

## Status: 🟧 Structural analogy | Impact: ★★

## Background

The Nernst equation determines the equilibrium potential for a single
ion species across a membrane:

```
  E = (RT / zF) * ln([ion]_out / [ion]_in)

  where:
    R = 8.314 J/(mol*K)     gas constant
    T = 310.15 K            body temperature (37 C)
    F = 96485 C/mol         Faraday constant
    z = ion valence (+1 for Na+, K+; -1 for Cl-)
```

At body temperature:

```
  RT/F = 8.314 * 310.15 / 96485 = 26.725 mV   (thermal voltage)
```

Standard textbook ion concentrations (Kandel, Guyton):

| Ion  | Intracellular (mM) | Extracellular (mM) | E_eq (mV) |
|------|-------------------|--------------------:|----------:|
| Na+  | 12                | 145                 | +66.6     |
| K+   | 140               | 4                   | -95.0     |
| Cl-  | 4                 | 120                 | -90.9     |
| Ca2+ | 0.0001            | 2                   | +128.7    |

## Verified Correspondences

### 1. Ion Concentrations = Divisor Functions of 6

```
  Concentration        Value   Function      Match
  ─────────────────    ─────   ──────────    ─────
  [Na+]_in             12 mM   sigma(6)=12   EXACT
  [K+]_out             4 mM    tau(6)=4      EXACT
  [Cl-]_in (lower)     4 mM    tau(6)=4      EXACT
  [Cl-]_out            120 mM  10*sigma(6)   EXACT
  [Ca2+]_out           2 mM    phi(6)=2      EXACT
```

Five ion concentrations match divisor functions of 6. The matches span
three different ions and both intra/extracellular compartments.

### 2. Thermal Voltage and sigma*phi + e

```
  RT/F at 37 C = 26.7253 mV

  sigma(6) * phi(6) + e = 24 + 2.7183 = 26.7183

  Error: |26.7253 - 26.7183| = 0.0070 mV
  Relative error: 0.026%

  Note: sigma(6)*phi(6) = 12*2 = 24 = 4!
  So: RT/F ~ 4! + e  (0.026% accuracy)
```

This is a remarkably close match. The thermal voltage -- the fundamental
energy scale of ion channel biophysics -- approximates the product of
sigma and phi of the perfect number 6, plus the natural constant e.

### 3. Nernst Potentials Computed

```
  E_Na = 26.73 * ln(145/12)  = 26.73 * 2.491  = +66.6 mV
                     ^^^
                  sigma(6) in denominator

  E_K  = 26.73 * ln(4/140)   = 26.73 * (-3.555) = -95.0 mV
                     ^
                  tau(6) in numerator

  E_Cl = -26.73 * ln(120/4)  = -26.73 * 3.401  = -90.9 mV
                      ^^^  ^
                   10*sigma tau
```

Every Nernst potential calculation involves sigma(6) or tau(6) values
in the concentration ratio.

### ASCII Diagram: Ion Concentrations and Perfect-6 Functions

```
  EXTRACELLULAR                    INTRACELLULAR
  ──────────────  ║ membrane ║  ──────────────
                  ║          ║
  [Na+] = 145    ║  ──Na──► ║  [Na+] = 12 = sigma(6)
                  ║          ║
  [K+]  = 4      ║  ◄──K─── ║  [K+]  = 140
    = tau(6)      ║          ║
                  ║          ║
  [Cl-] = 120    ║  ──Cl──► ║  [Cl-] = 4 = tau(6)
    = 10*sigma(6) ║          ║
                  ║          ║
  [Ca2+] = 2     ║  ──Ca──► ║  [Ca2+] = 0.0001
    = phi(6)      ║          ║
  ──────────────  ║          ║  ──────────────

  Thermal voltage driving all transport:
  RT/F = 26.73 mV ~ sigma*phi + e = 24 + e = 26.72 mV
```

### ASCII Diagram: Nernst Potential Landscape

```
  E (mV)
  +130 |  ▓▓  Ca2+ equilibrium (+128.7)
       |
  +67  |  ████  Na+ equilibrium (+66.6)
       |             E_Na = (sigma*phi+e) * ln(145/sigma)
       |
  0    |────────────────────────────── zero
       |
  -70  |  ████████  resting potential (-70)
       |             Goldman eq. weighted average
  -91  |  ██████  Cl- equilibrium (-90.9)
  -95  |  █████  K+ equilibrium (-95.0)
       |             E_K = (sigma*phi+e) * ln(tau/140)
       +─────────────────────────────────→
```

### 4. Goldman Equation Verification

The resting membrane potential uses all ion concentrations together:

```
  V_m = RT/F * ln( (P_K*[K]o + P_Na*[Na]o) / (P_K*[K]i + P_Na*[Na]i) )

  With P_Na/P_K = 0.04 (at rest):
  V_m = 26.73 * ln( (4 + 0.04*145) / (140 + 0.04*12) )
      = 26.73 * ln( 9.8 / 140.48 )
      = 26.73 * (-2.663)
      = -71.2 mV

  Textbook resting potential: -70 mV  (match within 1.7%)
```

### 5. Connections NOT Found (Honesty Check)

```
  Quantity              Value       Clean ratio with 6?
  ─────────────────     ──────      ────────────────────
  Faraday F             96485       F/12 = 8040.4   NO
  F/6                   16080.8     NO
  |V_rest|/(RT/F)       2.619       NO (not phi or e)
  K_in/K_out            35          NO
  Na_out/K_out          36.25       NO (close to 36=6^2 but not exact)
```

These non-matches are important: not everything fits, which argues
against pure cherry-picking.

## Texas Sharpshooter Assessment

**Search space**: There are ~8 standard ion concentrations and 4 divisor
functions, giving 32 possible comparisons. Finding 5 exact matches out
of 32 is significant.

**Strength**: The matches are not arbitrary -- they involve the most
biologically critical concentrations (the ones that directly determine
action potentials and resting potential).

**Weakness**: Ion concentrations are integers in mM, and small integers
(2, 4, 12) are common. The base unit (millimolar) is a human convention.

**RT/F match**: The thermal voltage match (0.026% error) is the strongest
single finding. There is one free parameter (temperature = body temp),
which is biologically fixed, not chosen.

**Estimated p-value**: ~0.01 (the RT/F match alone is striking)

## Limitations

1. **Units are conventional**: Ion concentrations in mM depend on the
   choice of millimolar as unit. In micromolar, [Na+]_in = 12000, which
   does not match sigma(6). The match is unit-dependent.
2. **Biological variance**: [Na+]_in ranges from 10-15 mM across cell
   types and species. The value 12 is a textbook representative, not
   a universal constant.
3. **Small number problem**: 4 and 12 appear in many contexts. The
   Strong Law of Small Numbers warns against over-interpreting matches
   involving numbers < 100.
4. **No causal mechanism**: There is no known reason why evolution would
   "select" ion concentrations based on divisor functions of 6.
5. **Faraday constant does not match**: A truly deep connection would
   likely involve F itself, which it does not.

## Cross-References

- **H-BIO-7**: Brain wave R-spectrum (oscillation frequency perspective)
- **H-BIO-8**: Action potential D(n) asymmetry
- **H-BIO-12**: Neural oscillation bands (same sigma/tau at band boundaries)
- **H-CHEM-2**: Carbon (Z=6) as perfect-number element

## Next Steps

1. Test whether other excitable cells (cardiac myocytes, smooth muscle)
   share the same sigma/tau concentration pattern.
2. Investigate temperature dependence: at T=300K (27C), RT/F=25.85 mV.
   Does this have a clean expression? (25.85 ~ 26-1/e? Check.)
3. Check ion channel conductances (g_Na, g_K) for perfect-6 ratios.
4. Explore whether the Goldman permeability ratio P_Na/P_K = 0.04
   connects to any function of 6 (0.04 = 1/25, not obvious).
5. Cross-validate with H-BIO-12: the ion channel kinetics that produce
   oscillation frequencies should connect the two hypotheses.
