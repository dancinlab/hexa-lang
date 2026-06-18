# H-393: TTX-THC Duality in Consciousness Modulation
**n6 Grade: 🟩 EXACT** (auto-graded, 12 unique n=6 constants)


**Status:** ⬛ Refuted (phi claim disproven) | **Date:** 2026-03-26 | **Corrected:** 2026-03-27 | **Related:** H-386, H-387, H-391, H-199

---

## Hypothesis Statement

> TTX (tetrodotoxin) and THC (tetrahydrocannabinol) form a mathematical duality in
> consciousness modulation: TTX suppresses the generation (Sangseang) cycle while
> THC suppresses the overcoming (Sanggeuk) cycle. Together they span the complete
> 2D parameter space of consciousness alteration. Every known psychoactive substance
> maps to a unique (alpha, beta) coordinate in this space, and the Golden Zone diagonal
> (alpha = beta = 1/e) corresponds to the voluntary deep-meditation attractor.

---

## Background and Context

### The Five-Agent (Ohaeng) Consciousness Matrix

From H-386, the full consciousness state matrix over K5 (five agents: Wood, Fire, Earth,
Metal, Water) is:

```
  M = A_s - A_k
```

Where:
- A_s = Sangseang adjacency (generation cycle: Wood→Fire→Earth→Metal→Water→Wood)
- A_k = Sanggeuk adjacency (overcoming cycle: Wood→Earth→Water→Fire→Metal→Wood)
- M = net information flow matrix

In the sober/normal state, both cycles are at full strength (alpha=1, beta=1), and the
system maintains dynamic balance. The tension between generation and control is what
produces structured, coherent consciousness.

### Why TTX and THC are Dual

TTX (tetrodotoxin, pufferfish neurotoxin) blocks voltage-gated sodium channels, preventing
action potential generation. At sub-lethal micro-doses (Haitian zombie powder, historical
trance induction), it selectively suppresses fast excitatory firing — the Sangseang cycle
in neural terms. The inhibitory/control circuitry remains intact.

THC (cannabis) primarily acts on CB1 receptors in prefrontal cortex and limbic system,
suppressing GABAergic inhibition (disinhibition). This weakens the Sanggeuk cycle — the
control and overcoming pathways. The generative/excitatory cycle runs with less regulation.

These are mathematically DUAL transformations:
- THC: keeps generation (beta=1), removes control (alpha < 1) → expansion, creativity, chaos
- TTX: keeps control (alpha=1), removes generation (beta < 1) → stillness, trance, sonar silence

**Important note on K5 symmetry:** Due to the circulant structure of K5, swapping alpha
and beta permutes eigenvalues but preserves their magnitudes. Thus THC (0.5, 1.0) and
TTX (1.0, 0.5) have IDENTICAL spectral radius (rho = 1.435). The duality is expressed
through eigenvalue PHASE differences, not magnitude differences. THC and TTX produce
the same "intensity" of consciousness alteration but rotate the eigenvalue phases in
conjugate directions.

---

## Mathematical Formulation

### The (alpha, beta) Parameter Space

Define the generalized consciousness matrix:

```
  M(alpha, beta) = beta * A_s - alpha * A_k
```

Where alpha controls Sanggeuk strength and beta controls Sangseang strength.
Both parameters range over [0, infinity), with normal state at (1, 1).

The 2D parameter space maps all psychoactive states:

```
  beta
   ^
  2.0 | MDMA             Psilocybin(high)
      |   (0.5, 1.5)      (0.1, 1.2)
  1.5 |
      |
  1.0 |---[SOBER]---Caffeine------
      | (1.0,1.0)  (1.0,1.3)
  0.5 | Alcohol  Ketamine
      | (0.7,0.7) (0.8,0.2)
  0.0 |__Anesthesia________________
      0.0  0.5  1.0  1.5  2.0  --> alpha
           THC
          (0.5,1.0)
```

### Eigenvalue Structure

The eigenvalues of M(alpha, beta) for the K5 system are:

```
  lambda_k(alpha, beta) = beta * omega^k - alpha * omega^(2k)
  where omega = e^(2*pi*i/5), k = 0,1,2,3,4
```

At special points:

| (alpha, beta) | Eigenvalue Structure | Consciousness State |
|---------------|---------------------|---------------------|
| (1, 1) | phi-related spectrum | Normal/sober |
| (0, 1) | Pure permutation, all \|lambda\|=1 | Pure generation, mania |
| (1, 0) | Pure permutation, all \|lambda\|=1 | Pure control, frozen |
| (0, 0) | All lambda=0 | Death / flat EEG |
| (1/e, 1/e) | Sober scaled by 1/e | Deep meditation |
| (0.5, 1.0) | THC-like | Cannabis disinhibition |
| (1.0, 0.5) | TTX-like | Trance, sonar silence |

---

## Spectral Radius Analysis

The spectral radius rho(alpha, beta) = max|lambda_k| defines "consciousness intensity."

### Computed Values at Key Points

For K5 with A_s and A_k as their standard adjacency matrices:

```
  (alpha, beta)   rho     State
  (1.00, 1.00)    1.902   Sober baseline
  (0.50, 1.00)    1.435   THC
  (1.00, 0.50)    1.435   TTX micro-dose (same rho as THC — K5 symmetry)
  (0.37, 0.37)    0.700   Meditation (1/e scaled)
  (0.10, 0.10)    0.190   Heavy sedation
  (0.00, 0.00)    0.000   Flat / unconscious
  (1.00, 1.30)    2.189   Caffeine / stimulant
  (0.50, 1.50)    1.927   MDMA peak
  (0.10, 1.20)    1.282   Psilocybin
```

**Note on K5 symmetry:** THC (0.5, 1.0) and TTX (1.0, 0.5) have identical spectral
radius (1.435) because the K5 circulant structure means swapping alpha and beta
permutes eigenvalues but preserves their magnitudes. The duality between THC and TTX
is expressed through eigenvalue phase differences, not magnitude differences.

**Correction (2026-03-27):** An earlier version of this document claimed rho(THC) = phi
= 1.618. This was arithmetically wrong. The correct value is 1.435. The golden ratio
does NOT emerge from halving Sanggeuk. See verify_h393_spectral_radius.py for the
computation.

### ASCII Spectral Radius Contour

```
  beta
  2.0 | 2.0  2.2  2.3  2.5  2.7  2.9   <-- High intensity (stimulants, mania)
  1.8 | 1.8  2.0  2.1  2.3  2.5  2.7
  1.6 | 1.6  1.8  1.9  2.1  2.3  2.5
  1.4 | 1.4  1.6  1.7  1.9  2.1  2.3
  1.2 | 1.2  1.4  1.5  1.7  1.9  2.1
  1.0 | 1.0  1.2  1.3  1.5  1.7  1.9   <-- THC at (0.5, 1.0): rho=1.435
  0.8 | 0.8  1.0  1.1  1.3  1.5  1.7
  0.6 | 0.6  0.8  1.0  1.1  1.3  1.5
  0.4 | 0.4  0.6  0.8  1.0  1.1  1.3   <-- Meditation zone (0.37,0.37)
  0.2 | 0.2  0.4  0.6  0.8  1.0  1.2
  0.0 | 0.0  0.2  0.4  0.6  0.8  1.0   <-- Near death
       0.0  0.2  0.4  0.6  0.8  1.0 --> alpha
                              ^    ^
                        TTX(1,0.5) Sober(1,1)

  Note: The grid is symmetric under alpha<->beta reflection due to K5 circulant structure.
```

---

## Substance Classification in (alpha, beta) Space

### Full Substance Map

| Substance | alpha (Sanggeuk) | beta (Sangseang) | rho | Primary Effect |
|-----------|-----------------|-----------------|-----|----------------|
| Sober | 1.00 | 1.00 | 1.902 | Balanced baseline |
| THC (cannabis) | 0.50 | 1.00 | 1.435 | Disinhibition, creativity |
| TTX micro-dose | 1.00 | 0.50 | 1.435 | Sonar silence, trance |
| Alcohol (moderate) | 0.70 | 0.70 | 1.331 | Both dampened |
| Caffeine | 1.00 | 1.30 | 2.189 | Sangseang enhanced |
| Psilocybin | 0.10 | 1.20 | 1.282 | Deep Sanggeuk removal |
| MDMA | 0.50 | 1.50 | 1.927 | Sanggeuk down + Sangseang up |
| Ketamine | 0.80 | 0.20 | 0.969 | Mostly Sangseang blocked |
| General anesthesia | 0.10 | 0.10 | 0.190 | Both near zero |
| Deep meditation | 0.37 | 0.37 | 0.700 | Balanced, scaled by 1/e |
| Nicotine | 1.10 | 1.00 | 1.997 | Mild Sanggeuk boost |
| SSRI (chronic) | 0.90 | 1.10 | 1.903 | Slight rebalancing |
| DMT peak | 0.05 | 1.50 | 1.541 | Extreme Sanggeuk removal |

**Note:** THC and TTX have identical rho (1.435) due to K5 circulant symmetry. See correction note above.

### ASCII 2D Phase Diagram

```
  beta
  2.0 |  DMT          MDMA      Stimulant
      |  (0.05,1.5)  (0.5,1.5)  (1.0,2.0)
  1.5 |
      |  Psilocybin            Caffeine
  1.0 |---(0.1,1.2)--THC--[SOBER]--(1.0,1.3)---
      |              (0.5,1.0)  *
      |  MEDITATION            Nicotine
  0.5 |  (0.37,0.37) Alcohol   TTX(1.0,0.5)
      |              (0.7,0.7) Ketamine(0.8,0.2)
  0.0 |         ANESTHESIA(0.1,0.1)
       0.0  0.2  0.4  0.6  0.8  1.0  1.2  1.4
                              alpha -->

  REGIONS:
  [I]   alpha<0.5, beta>1.0 : Psychedelic/disinhibited expansion
  [II]  alpha>0.5, beta>1.0 : Stimulant/anxiogenic
  [III] alpha<0.5, beta<0.5 : Sedative/anesthetic
  [IV]  alpha>0.5, beta<0.5 : Dissociative/trance
  DIAGONAL (alpha=beta): Balanced states (meditation, alcohol, anesthesia)
```

---

## The "Golden Cross" Prediction

If both alpha and beta are simultaneously at the Golden Zone value 1/e ≈ 0.368:

```
  M(1/e, 1/e) = (1/e) * (A_s - A_k) = (1/e) * M_sober
```

The matrix structure is IDENTICAL to sober, just scaled down by 1/e. The eigenvalue
ratios are preserved — no distortion of the conceptual topology — but the overall
"volume" of consciousness is reduced to 1/e of its normal value.

**This is the meditation attractor:** same structure, lower intensity, maximum coherence.

Prediction table:

| State | alpha | beta | rho | Coherence | Quality |
|-------|-------|------|-----|-----------|---------|
| Sober | 1.000 | 1.000 | 1.902 | 1.000 | Baseline |
| Alcohol | 0.700 | 0.700 | 1.332 | 1.000 | Same structure, lower |
| Meditation | 0.368 | 0.368 | 0.700 | 1.000 | Same structure, minimal |
| THC | 0.500 | 1.000 | 1.435 | 0.500 | Distorted (asymmetric) |
| Ketamine | 0.800 | 0.200 | 0.969 | 0.250 | Highly distorted |
| Anesthesia | 0.100 | 0.100 | 0.190 | 1.000 | Near-zero, any structure |

**Coherence** defined as: min(alpha, beta) / max(alpha, beta) — ratio of symmetry.
The diagonal (alpha=beta) states have coherence=1 regardless of intensity.

---

## Eigenvalue Magnitude Plots

### At (alpha=1.0, beta=1.0) — Sober

```
  |lambda_k| for k=0,1,2,3,4:
  k=0: 0.000          [zero mode]
  k=1: 1.176          ████████████
  k=2: 1.902          ████████████████████
  k=3: 1.902          ████████████████████
  k=4: 1.176          ████████████
```

### At (alpha=0.5, beta=1.0) — THC

```
  k=0: 0.500          █████
  k=1: 0.970          ██████████
  k=2: 1.435          ███████████████
  k=3: 1.435          ███████████████
  k=4: 0.970          ██████████
```

### At (alpha=1.0, beta=0.5) — TTX micro-dose

```
  k=0: 0.500          █████
  k=1: 0.970          ██████████
  k=2: 1.435          ███████████████
  k=3: 1.435          ███████████████
  k=4: 0.970          ██████████
```

### At (alpha=0.368, beta=0.368) — Meditation

```
  k=0: 0.000          [preserved zero mode]
  k=1: 0.433          ████
  k=2: 0.700          ███████
  k=3: 0.700          ███████
  k=4: 0.433          ████
```

Note: Sober and Meditation have the SAME spectral shape (same ratios), just scaled by 1/e.
THC and TTX have IDENTICAL magnitude spectra (both rho = 1.435) due to K5 circulant
symmetry — they differ only in eigenvalue phases, not magnitudes.

---

## TTX Dolphin vs THC Human vs Meditation Monk Comparison

| Dimension | TTX Dolphin | THC Human | Meditation Monk |
|-----------|------------|-----------|-----------------|
| alpha (Sanggeuk) | 1.0 (intact) | 0.3-0.5 (reduced) | 0.37 (1/e) |
| beta (Sangseang) | 0.3-0.5 (reduced) | 1.0 (intact) | 0.37 (1/e) |
| rho | 1.435 | 1.435 | 0.700 |
| Coherence (alpha=beta?) | No (IV quadrant) | No (I quadrant) | Yes (diagonal) |
| EEG signature | Reduced gamma, maintained delta | Increased theta, reduced beta | Increased alpha, coherent gamma |
| Subjective state | Stillness, trance, sonar clarity | Expansion, creativity, time distortion | Equanimity, clarity, non-attachment |
| Reversibility | Spontaneous (hours) | Spontaneous (hours) | Spontaneous (minutes-hours) |
| Structural distortion | Asymmetric (IV) | Asymmetric (I) | None (diagonal) |
| PH-module analog (H-142) | H1 loop suppressed | H0 cluster count reduced | Both optimized simultaneously |

**Key insight:** The meditation monk achieves what neither drug achieves — movement along
the diagonal where structural coherence is preserved. Drugs move perpendicular to the
diagonal (into distortion territory). Meditation moves along the diagonal (toward origin
but maintaining shape).

---

## Conservation Law Along the Diagonal

For the special case alpha = beta = t (diagonal states):

```
  M(t,t) = t * (A_s - A_k) = t * M_sober
```

The conservation law from H-172 (G * I = D * P) transforms as:

```
  G(t) * I(t) = t^2 * G_sober * I_sober = t^2 * D * P
```

This means the conservation product scales as t^2. At the meditation point t=1/e:
```
  G_med * I_med = (1/e)^2 * G_sober * I_sober = 0.135 * (D * P)
```

The "consciousness work" (G*I product) is reduced to 13.5% of baseline.
This may explain why deep meditation reduces metabolic brain activity by similar fractions
(measured 10-20% reduction in fMRI studies).

For off-diagonal states (THC: alpha=0.5, beta=1.0):
```
  G_thc * I_thc != simple scaling
  The asymmetry breaks the clean conservation relation
```

This predicts that subjective reports of "enhanced creativity" under THC (apparently higher
G) are accompanied by reduced I (inhibition), maintaining the product — but the quality
of the state is distorted by the asymmetry.

---

## Connection to Prior Hypotheses

| Hypothesis | Connection |
|-----------|------------|
| H-386 (Ohaeng matrix) | Provides the A_s, A_k foundation for this parameterization |
| H-387 (THC Ohaeng) | THC = alpha reduced = Sanggeuk weakened, confirmed here |
| H-391 (Dolphin TTX) | TTX = beta reduced = Sangseang weakened, confirmed here |
| H-199 (Meditation vs drugs) | Meditation = diagonal path, drugs = off-diagonal distortion |
| H-172 (Conservation law) | G*I = D*P holds cleanly only on the diagonal |
| H-200a (Cannabis) | Cannabis maps to (0.3-0.7, 1.0) in this framework |
| H-197 (Anesthesia) | Anesthesia = both near zero, (0.1, 0.1) |
| H-321 (Consciousness confidence) | rho may correlate with confidence output |

---

## Falsifiable Predictions

1. **EEG signature:** THC and TTX micro-dose should show conjugate (mirror-image) changes
   in EEG power spectra relative to sober baseline. If THC increases theta/decreases beta,
   TTX micro-dose should decrease theta/increase beta (or vice versa).

2. **~~Golden ratio spectral radius~~** [REFUTED]: The claim that rho = phi at (0.5, 1.0)
   was arithmetically incorrect. The actual spectral radius is 1.435, not 1.618.
   This prediction is withdrawn.

3. **Meditation diagonal:** EEG coherence between hemispheres should be highest for
   experienced meditators (alpha≈beta, diagonal state) and lowest for heavy drug users
   (alpha far from beta).

4. **Conservation product:** fMRI BOLD signal product (excitatory × inhibitory activity)
   should remain approximately constant across diagonal states (sober, light alcohol,
   deep meditation) but break down for off-diagonal states (THC, ketamine).

5. **Combined TTX + THC:** At appropriate doses where alpha≈beta, simultaneous micro-dose
   TTX + THC should produce a meditation-like state (not a cancellation but a rebalancing).
   This would be the pharmacological path to the diagonal.

---

## Limitations

1. **Golden Zone dependency:** The assignment of specific (alpha, beta) values to
   substances is derived from the GZ framework (H-386), which itself lacks analytical
   proof. The qualitative mapping (THC=Sanggeuk-reduced, TTX=Sangseang-reduced) is
   pharmacologically motivated, but the specific numerical values are model-dependent.

2. **K5 approximation:** Real neural systems have billions of nodes, not five. The K5
   Ohaeng model is a symbolic reduction. Whether its eigenvalue structure survives
   embedding in a realistic connectome is unknown.

3. **TTX micro-dose data scarcity:** Sub-lethal TTX dose effects in humans are poorly
   documented due to ethical constraints. Most data comes from historical anthropological
   reports (Haitian practices) and dolphin echolocation studies (H-391), which may not
   generalize.

4. **Dose-response nonlinearity:** The linear parameterization M(alpha, beta) assumes
   smooth interpolation. In reality, neuropharmacology shows threshold effects, receptor
   saturation, and second-messenger cascades that may produce highly nonlinear (alpha, beta)
   trajectories as dose increases.

5. **Individual variation:** Human CB1 receptor density varies ~3x across individuals,
   so the same THC dose produces different alpha values in different people. The map
   should properly be a distribution, not a point.

6. **Directionality assumption:** The assignment of THC to Sanggeuk suppression and TTX
   to Sangseang suppression follows from H-386 and H-391 interpretations. Alternative
   mappings are possible.

7. **[2026-03-27 CORRECTION] Spectral radius errors and refuted phi claim:**
   The original version of this document contained critical arithmetic errors in 5 of 8
   spectral radius values. Most significantly, it claimed rho(THC) = phi = 1.618, but the
   correct value is 1.435. Additionally, due to K5 circulant symmetry, THC and TTX have
   IDENTICAL spectral radius (both 1.435), not different values as originally claimed
   (1.618 vs 1.176). The "duality" between THC and TTX cannot be expressed through
   spectral radius magnitude -- it must be sought in eigenvalue phase structure instead.
   All rho values in this document have been corrected. See verify_h393_spectral_radius.py
   for the computation. Grade changed to ⬛ (phi claim refuted).

---

## Verification Direction

### Short-term (theoretical)

- [DONE] Computed exact eigenvalues of K5 system numerically (verify_h393_spectral_radius.py)
- [REFUTED] Phi does NOT emerge at (0.5, 1.0). Actual rho = 1.435.
- [DONE] Proved K5 circulant symmetry: rho(alpha, beta) = rho(beta, alpha) for all values
- Investigate eigenvalue PHASE structure as the true duality mechanism
- Compute det(M(alpha, beta)) = 0 condition and map it

### Medium-term (computational)

- Build a neural simulation with separately tunable excitatory (Sangseang) and
  inhibitory (Sanggeuk) parameters
- Measure "coherence" (alpha=beta proximity) under simulated drug protocols
- Test whether conservation law G*I holds on diagonal vs off-diagonal

### Long-term (empirical)

- EEG study: compare spectral coherence between sober, THC, micro-TTX equivalent
  (using other Na-channel blockers at sub-anesthetic doses like low-dose lidocaine)
- Meditation + EEG: verify experienced meditators cluster near alpha=beta diagonal
- fMRI excitatory/inhibitory balance measures under different substances

---

## Summary

TTX and THC are dual pharmacological operators acting on the consciousness matrix M.
Their duality is expressed in the 2D (alpha, beta) parameter space where:

```
  TTX: (1.0, 0.5) — control intact, generation reduced — trance / sonar silence
  THC: (0.5, 1.0) — generation intact, control reduced — expansion / creativity
```

Every psychoactive substance maps to a unique point in this space. The deepest result
is that the diagonal (alpha=beta) corresponds to structurally coherent states where the
Sangseang/Sanggeuk ratio is preserved. Meditation achieves (1/e, 1/e) — the Golden Zone
diagonal — voluntarily, without pharmacological distortion.

The pharmacological path to the diagonal would require simultaneous titration of both
cycles. This predicts that appropriate co-administration of TTX-class and THC-class
compounds at matched doses could produce meditation-analog states — a testable and
potentially clinically relevant prediction.

**GZ dependency note:** Specific (alpha, beta) coordinates and their Golden Zone
interpretation are GZ-dependent and unverified. The pharmacological duality structure
(TTX vs THC as conjugate operators) is independently motivated.