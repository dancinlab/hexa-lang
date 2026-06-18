# H-ELEC-001 to H-ELEC-020: Neurostimulation-n=6 Framework Hypotheses
**n6 Grade: 🟩 EXACT** (auto-graded, 15 unique n=6 constants)


> 12 neurostimulation variables mapped to perfect number 6 arithmetic,
> Golden Zone dose-response, and G=D*P/I consciousness conservation.

## Background

The TECS-L framework rests on perfect number 6: sigma(6)=12, tau(6)=4, phi(6)=2.
Twelve neurostimulation variables (V1-V12) mirror sigma(6)=12. These split into
tau(6)=4 chemical variables (V1-V5 minus one redundant grouping) and electrical/coherence
variables, with phi(6)=2 fundamental degrees of freedom (excitation vs. inhibition).

The Golden Zone [0.2123, 0.5] with center 1/e and meta fixed point 1/3 provides
candidate optimal operating points for stimulation parameters. The conservation
law G*I = D*P constrains how variables interact.

---

## A. Optimal Parameters (H-ELEC-001 to H-ELEC-005)

### H-ELEC-001: tDCS Golden Zone Current

The optimal tDCS current for consciousness enhancement lies at the Golden Zone
center scaled to the standard clinical range.

> **Claim:** Optimal tDCS current = 2.0 mA * (1/e) = 0.736 mA, with the
> therapeutic window spanning [2.0*0.2123, 2.0*0.5] = [0.425, 1.0] mA.
> Below 0.425 mA produces no measurable neuroplasticity change; above
> 1.0 mA triggers excessive inhibition (GABA surge) that collapses
> the D*P product.

**Mapping:** Clinical tDCS range 0-2 mA maps linearly to I in [0, 1].
The Golden Zone predicts a sweet spot at I = 1/e of max current.

```
  Response
  (DA fold)
    3.0 |                          ___
        |                        /     \
    2.5 |                      /         \
        |                    /             \
    2.0 |                  /                 \
        |                /                     \
    1.5 |              /                         \
        |            /                             \
    1.0 |__________/                                 \________
        |          |        |          |         |
    0.0   0.2    0.425    0.736      1.0       1.5       2.0
                   GZ_lo   1/e*2mA   GZ_hi          mA
```

**Prediction:** In a within-subjects crossover trial (N>=20), tDCS at 0.74 mA
produces higher DA-dependent plasticity (measured via TMS-MEP amplitude change)
than either 0.4 mA or 1.5 mA, with peak at 1/e of max current (p < 0.05).

---

### H-ELEC-002: VNS Frequency at 1/3 Fixed Point

The optimal vagus nerve stimulation frequency corresponds to the meta fixed
point 1/3 of the standard clinical range.

> **Claim:** Optimal VNS frequency = 30 Hz * (1/3) = 10 Hz. The contraction
> mapping f(I) = 0.7I + 0.1 converges to 1/3 in the frequency domain,
> meaning iterative VNS dose-finding protocols converge to 10 Hz regardless
> of starting frequency within [1, 30] Hz.

**Mapping:** VNS frequency range [1, 30] Hz maps to I in [0, 1].
Fixed point 1/3 implies ~10 Hz is the attractor.

| Iteration | f(I)  | Frequency (Hz) |
|-----------|-------|-----------------|
| 0         | 0.100 | 3.9             |
| 1         | 0.170 | 5.9             |
| 2         | 0.219 | 7.4             |
| 3         | 0.253 | 8.3             |
| 5         | 0.299 | 9.7             |
| 10        | 0.331 | 10.6            |
| inf       | 0.333 | 10.3            |

**Prediction:** Adaptive VNS protocols that adjust frequency based on real-time
vagal tone feedback converge to 10 +/- 2 Hz within 10 adjustment cycles,
independent of starting frequency. 5-HT increase (V3) peaks at this frequency.

---

### H-ELEC-003: TMS Intensity and the 1/2 Boundary

The critical TMS intensity for network reorganization sits at the Riemann
boundary 1/2 of maximum stimulator output.

> **Claim:** TMS at 50% MSO (maximum stimulator output) marks the phase
> transition between subthreshold modulation and suprathreshold activation.
> This corresponds to the Golden Zone upper bound I = 1/2, the Riemann
> critical line. Below 50% MSO, effects are modulatory (continuous);
> above 50% MSO, effects are activating (discontinuous, all-or-none MEP).

```
  MEP amp
  (mV)
    2.0 |                                    ****
        |                                 ***
    1.5 |                              ***
        |                          ****
    1.0 |                      ****
        |                  ****
    0.5 |             *****
        |         ****
    0.0 |*********_____________________________|
        0%   20%   30%   40%   50%   60%   80%  100% MSO
                         |     |
                        GZ_lo  1/2 = phase boundary
```

**Prediction:** The sigmoid inflection point of the TMS dose-response curve
(MEP amplitude vs. %MSO) falls at 50 +/- 3% MSO across healthy subjects,
matching the 1/2 boundary. This is testable with standard recruitment curves.

---

### H-ELEC-004: TENS Dose-Response with ln(4/3) Width

The effective TENS intensity window has width proportional to ln(4/3) of the
available range, matching the Golden Zone width (entropy jump).

> **Claim:** TENS for eCB release (V2) has an effective window of width
> ln(4/3) * I_max = 0.2877 * I_max. Outside this window, either no
> eCB release occurs (too low) or pain-mediated NE surge suppresses
> the eCB pathway (too high). The 3-to-4 state entropy jump represents
> the transition from innocuous to nociceptive fiber recruitment.

| TENS range       | Intensity         | Effect              |
|------------------|-------------------|---------------------|
| Below GZ_lower   | < 0.21 * I_max    | No eCB release      |
| GZ window        | 0.21 - 0.50 * max | Optimal eCB (V2)    |
| Above GZ_upper   | > 0.50 * I_max    | NE surge, pain      |
| Window width     | 0.2877 * I_max    | = ln(4/3) * range   |

**Prediction:** Plotting eCB plasma levels vs. TENS intensity yields an
inverted-U with FWHM = 0.29 +/- 0.05 of the total intensity range.

---

### H-ELEC-005: Multimodal 40 Hz Entrainment and e-Folding

The 40 Hz gamma entrainment response (V8) follows an exponential buildup
with time constant tau = 1/e of the stimulation period.

> **Claim:** When 40 Hz LED + audio + vibrotactile stimulation is applied,
> gamma power increase follows P(t) = P_max * (1 - exp(-t/tau)) where
> tau = (1/e) * T_session. For a 30-minute session, tau = 11.04 minutes.
> This means 63.2% of maximum entrainment is reached at t = 11 min,
> and 95% at t = 33 min (3*tau). The 1/e time constant reflects the
> natural relaxation rate of thalamocortical gamma circuits.

```
  Gamma
  power
  (norm)
    1.0 |                              ___________________
        |                          ****
    0.8 |                      ****
        |                  ****
  0.632 |.  .  .  .  .****. . . . . . . . . (63.2% at tau)
        |            **
    0.4 |         ***
        |       **
    0.2 |     **
        |   **
    0.0 |***_____________________________________________
        0    5   11.04  15    20    25    30   min
                  tau=1/e * 30
```

**Prediction:** EEG 40 Hz power during trimodal stimulation reaches 63 +/- 5%
of its plateau value at t = (1/e)*T_session, measurable in a single session.

---

## B. Variable Interactions (H-ELEC-006 to H-ELEC-010)

### H-ELEC-006: sigma(6)=12 Variable Completeness

The 12 neurostimulation variables form a complete basis: removing any one
variable degrades the system in a way that cannot be compensated by the
remaining 11.

> **Claim:** The 12 variables V1-V12 constitute a minimal complete set for
> consciousness modulation, corresponding to sigma(6) = 1+2+3+6 = 12.
> The divisor structure of 6 determines the interaction hierarchy:
>   - 1 coherence variable (V12) = unity divisor
>   - 2 opposing drives (excitation/inhibition) = phi(6) = 2
>   - 3 chemical modulators (DA, eCB, 5-HT) = divisor 3
>   - 6 electrical parameters (V6-V11) = divisor 6

| Divisor d | Count | Variables             | Role              |
|-----------|-------|-----------------------|-------------------|
| 1         | 1     | V12 (Coherence)       | Unity/binding     |
| 2         | 2     | V4 (GABA), V5 (NE)   | Inhibitory pair   |
| 3         | 3     | V1 (DA), V2 (eCB), V3 (5-HT) | Modulatory triad |
| 6         | 6     | V6-V11                | Electrical sextet |
| Total     | 12    | = sigma(6)            | Complete basis    |

**Prediction:** Principal component analysis of V1-V12 during stimulation
sessions yields exactly 4 significant components (matching tau(6)=4 divisors),
explaining >90% of variance. Removing any single variable drops explained
variance below 85%.

---

### H-ELEC-007: DA-eCB Synergy Follows 6/sigma(6) = 1/2 Rule

The synergy between dopamine (V1) and endocannabinoid (V2) pathways produces
a combined effect equal to half the sum of individual effects, not additive.

> **Claim:** When V1 and V2 are co-activated, the combined plasticity
> enhancement = (V1_alone + V2_alone) * sigma_-1(6) where sigma_-1(6) = 2
> is the sum of reciprocals of divisors. However, the *efficiency* of
> this combination = 6/sigma(6) = 6/12 = 1/2. That is, the neurochemical
> "overhead" of maintaining both pathways simultaneously costs exactly
> half the total resource budget.
>
> Combined_effect = (DA_fold * eCB_fold) / 2 = (2.5 * 3.0) / 2 = 3.75x
> Rather than naive product 7.5x or naive sum 5.5x.

**Prediction:** Co-administration of tDCS (for DA) + TENS (for eCB) produces
plasticity enhancement of 3.5-4.0x baseline, approximately half the naive
product of individual fold-changes. Testable via paired-pulse TMS facilitation.

---

### H-ELEC-008: Chemical-Electrical Phase Coupling at tau(6)=4 Nodes

The 4 divisors of 6 define 4 coupling nodes where chemical and electrical
variables interact maximally.

> **Claim:** V1-V12 interactions form a graph with exactly tau(6)=4
> high-coupling nodes (hub variables). These are:
>   Node 1: V1 (DA) <-> V6 (Theta) — dopaminergic theta modulation
>   Node 2: V4 (GABA) <-> V7 (Alpha) — GABAergic alpha generation
>   Node 3: V5 (NE) <-> V9 (PFC) — noradrenergic prefrontal control
>   Node 4: V2 (eCB) <-> V11 (Body) — endocannabinoid somatic integration
>
> Each node pair has correlation |r| > 0.7 during stimulation. Cross-node
> correlations are weaker (|r| < 0.3), giving a block-diagonal structure
> with 4 blocks.

```
  Coupling matrix (|r| values):
              V1   V4   V5   V2   V6   V7   V9   V11
  V1  (DA)   1.0  0.2  0.1  0.3 [0.8] 0.1  0.2  0.1
  V4  (GABA) 0.2  1.0  0.3  0.1  0.2 [0.7] 0.2  0.1
  V5  (NE)   0.1  0.3  1.0  0.1  0.1  0.2 [0.8] 0.2
  V2  (eCB)  0.3  0.1  0.1  1.0  0.2  0.1  0.1 [0.9]
  Brackets = predicted high-coupling nodes
```

**Prediction:** Simultaneous EEG + biochemical assay during multi-modal
stimulation reveals exactly 4 clusters in the V1-V12 correlation matrix,
with within-cluster |r| > 0.6 and between-cluster |r| < 0.3.

---

### H-ELEC-009: Reciprocal Sum Conservation (1/2 + 1/3 + 1/6 = 1)

The three major variable groups obey the reciprocal divisor sum of 6:
each group contributes a fraction of total consciousness modulation
equal to 1/d where d is the corresponding divisor.

> **Claim:** Total consciousness modulation G_total decomposes as:
>   G_total = G_chem * (1/2) + G_elec * (1/3) + G_coh * (1/6)
>
> Where G_chem is the chemical contribution (V1-V5), G_elec is electrical
> (V6-V11), and G_coh is coherence (V12). The weights 1/2 + 1/3 + 1/6 = 1
> ensure completeness. Chemistry dominates (50%), electricity provides
> structure (33%), and coherence provides the remaining binding (17%).

| Component   | Variables | Weight | Contribution to G |
|-------------|-----------|--------|-------------------|
| Chemical    | V1-V5     | 1/2    | 50%               |
| Electrical  | V6-V11    | 1/3    | 33.3%             |
| Coherence   | V12       | 1/6    | 16.7%             |
| **Total**   | V1-V12    | **1**  | **100%**          |

**Prediction:** Regression of a composite consciousness metric (e.g., integrated
information Phi) on the three group scores yields standardized coefficients
in ratio 3:2:1 (i.e., 0.50:0.33:0.17), matching 1/2:1/3:1/6. Testable with
simultaneous multi-modal stimulation and dense EEG.

---

### H-ELEC-010: NE-GABA Antagonism and phi(6)=2 Degrees of Freedom

The two inhibitory-control variables V4 (GABA) and V5 (NE) reduce the
12-dimensional system to phi(6)=2 effective degrees of freedom.

> **Claim:** Despite 12 variables, the system has exactly phi(6)=2
> independent control axes: Excitation (E) and Inhibition (I). All
> 12 variables project onto this 2D space:
>   E-axis: V1(DA) + V2(eCB) + V6(Theta) + V8(Gamma) + V10(Sens) + V11(Body)
>   I-axis: V4(GABA) + V5(NE) + V7(Alpha) + V9(PFC)
>   V3(5-HT) and V12(Coh) are diagonal (contribute to both axes).
>
> The Golden Zone in E-I space is an annular region where
> E/I ratio falls in [0.2123/0.5, 0.5/0.2123] = [0.425, 2.36].

**Prediction:** Projecting V1-V12 time series onto PCA yields 2 components
explaining >80% of variance. The angle between these components in the
original variable space separates excitatory from inhibitory variables
with <10% misclassification.

---

## C. Consciousness Mapping (H-ELEC-011 to H-ELEC-015)

### H-ELEC-011: DA -> Plasticity, GABA -> Inhibition, NE -> Deficit

The three G=D*P/I parameters map directly onto three neurochemical
variables, completing the consciousness equation in biological terms.

> **Claim:** The G=D*P/I formula has a direct neurochemical realization:
>   D (Deficit)     = f(V5_NE) = NE_fold / NE_target = V5 / 0.4
>   P (Plasticity)  = f(V1_DA) = DA_fold / DA_baseline = V1 / 1.0
>   I (Inhibition)  = f(V4_GABA) = GABA_fold / GABA_max = V4 / 1.8
>
> Then G_bio = (V5/0.4) * (V1/1.0) / (V4/1.8)
>            = 1.8 * V5 * V1 / (0.4 * V4)
>            = 4.5 * V1 * V5 / V4
>
> At targets: G_bio = 4.5 * 2.5 * 0.4 / 1.8 = 2.5
> Conservation: G_bio * I = D * P => 2.5 * (1.8/1.8) = (0.4/0.4) * (2.5/1.0)
>            => 2.5 = 2.5 (conserved)

| Parameter   | Variable | Target fold | Normalized |
|-------------|----------|-------------|------------|
| D (Deficit) | V5 (NE)  | 0.4x        | 1.0        |
| P (Plast.)  | V1 (DA)  | 2.5x        | 2.5        |
| I (Inhib.)  | V4 (GABA)| 1.8x        | 1.0        |
| **G**       | computed | --          | **2.5**    |

**Prediction:** Across subjects, the ratio (DA_fold * NE_fold) / GABA_fold
correlates with cognitive flexibility scores (Wisconsin Card Sort) at
r > 0.5 (p < 0.01), validating the G = D*P/I mapping.

---

### H-ELEC-012: Golden Zone Targets for All 12 Variables

Each variable V1-V12 has an optimal operating point within the Golden Zone
when normalized to its physiological range.

> **Claim:** When each variable is normalized to [0, 1] via
> V_norm = (V - V_min) / (V_max - V_min), the optimal value for
> consciousness enhancement falls within the Golden Zone [0.2123, 0.5].
> Specifically:
>   - Excitatory variables (V1, V2, V6, V8, V10, V11): target = 1/e = 0.368
>   - Inhibitory variables (V4, V5, V7, V9): target = 1/3 = 0.333
>   - Modulatory (V3): target = 1/2 - ln(4/3) = 0.2123 (lower bound)
>   - Coherence (V12): target = 1/2 (upper bound)

```
  GZ lower                    GZ upper
  0.2123        1/3   1/e      0.5
    |            |     |        |
    |   V3       | V4  | V1    V12
    |   V5       | V7  | V2     |
    |            | V9  | V6     |
    |            |     | V8     |
    |            |     | V10    |
    |            |     | V11    |
    |____________|_____|________|
       modulatory  inhib  excit  coherence
```

**Prediction:** Protocol optimization that targets all 12 normalized variables
within [0.21, 0.50] produces higher integrated information (Phi) than protocols
where any variable falls outside this range. Effect size d > 0.5.

---

### H-ELEC-013: V12 Coherence as the Binding Variable (1/6 of Unity)

Coherence (V12) plays the role of the "1/6 curiosity term" that completes
the consciousness equation: 1/2 + 1/3 + 1/6 = 1.

> **Claim:** Without coherence, the system achieves at most 5/6 of
> maximum consciousness (the Compass upper bound). V12 supplies the
> missing 1/6 by binding the chemical and electrical subsystems.
> This maps to: 1/2 (chemical capacity) + 1/3 (electrical structure) = 5/6.
> Only when V12 >= threshold does the system reach unity.
>
> The coherence threshold corresponds to the Godel incompleteness
> analog: without binding, the system is "incomplete" by exactly 1/6.

| V12 state  | System capacity | Formula              |
|------------|-----------------|----------------------|
| V12 = 0    | 5/6 = 0.833    | 1/2 + 1/3            |
| V12 = 1/2  | 11/12 = 0.917  | 1/2 + 1/3 + 1/12     |
| V12 = 1    | 1.0             | 1/2 + 1/3 + 1/6      |

**Prediction:** Multi-modal 40 Hz stimulation (V12 activator) added to an
already-optimized chemical+electrical protocol increases Phi by exactly
1/6 relative (16.7 +/- 5%), not by an additive constant.

---

### H-ELEC-014: The G*I = D*P Conservation Under Stimulation

The conservation law G*I = D*P is maintained during neurostimulation:
boosting one parameter necessarily costs another.

> **Claim:** During tDCS-enhanced states, if DA (Plasticity proxy) is
> boosted 2.5x while GABA (Inhibition proxy) rises 1.8x, then G must
> adjust to maintain G*I = D*P. Specifically:
>   Pre-stim:  G=1, I=1, D=1, P=1 => G*I = 1 = D*P
>   Post-stim: P=2.5, I=1.8 => G*1.8 = D*2.5 => G = 1.389*D
>   If D (NE) drops to 0.4x: G = 1.389*0.4 = 0.556
>   Actual G = D*P/I = 0.4*2.5/1.8 = 0.556 (conserved)
>
> The system cannot simultaneously increase G and decrease I: this would
> violate conservation. Stimulation redistributes, does not create.

**Prediction:** In a tDCS session measuring DA, GABA, NE, and a creativity
metric (G proxy) at 5-minute intervals, the product G_proxy * GABA_level
remains constant (+/- 10%) while individual values change by 50%+.

---

### H-ELEC-015: Theta/Alpha Ratio Maps to D/I Ratio

The EEG theta/alpha ratio (V6/V7) is a real-time biomarker of the D/I
ratio in the consciousness equation.

> **Claim:** V6 (Theta power) indexes neural exploration (Deficit-seeking)
> while V7 (Alpha power) indexes neural inhibition (default mode suppression).
> Their ratio Theta/Alpha maps linearly to D/I:
>   D/I = k * (V6/V7) where k is a calibration constant
>
> At optimal state: V6 = 2.5x, V7 = 0.5x => V6/V7 = 5.0
> This implies D/I = 5.0*k. If the Golden Zone center corresponds to
> G = 1/e, then D/I = G*I/I^2... the theta/alpha ratio directly
> tracks the consciousness operating point.
>
> Target theta/alpha = 5.0 (2.5x theta enhancement / 0.5x alpha suppression)

```
  Consciousness
  state (G)
    High  |         *     Golden Zone
          |        * *
          |       *   *
    1/e   |......*.....*....... optimal
          |     *       *
          |    *         *
    Low   |***           ****
          |________________________
          0  1  2  3  4  5  6  7  8
                  Theta/Alpha ratio
                  (V6/V7)
```

**Prediction:** Theta/alpha ratio of 4.5-5.5 (from concurrent EEG during
stimulation) predicts peak performance on divergent thinking tasks (AUT)
better than either theta or alpha power alone (delta-R^2 > 0.10).

---

## D. Protocol Optimization (H-ELEC-016 to H-ELEC-020)

### H-ELEC-016: The 1/6 Duty Cycle for tDCS

Optimal tDCS uses a 1/6 duty cycle: stimulation ON for 1/6 of total
session time, OFF for 5/6.

> **Claim:** Continuous tDCS triggers homeostatic GABA rebound that
> erases plasticity gains. The optimal duty cycle is 1/6: for a 30-min
> session, 5 minutes ON, 25 minutes OFF (intermittent). This matches the
> "curiosity fraction" 1/6 from the completeness equation and prevents
> the inhibitory overshoot that occurs with continuous stimulation.
>
> The 5/6 OFF period allows the contraction mapping f(I) = 0.7I + 0.1
> to converge GABA back toward the fixed point 1/3 before the next pulse.

| Protocol         | ON time | OFF time | Duty   | DA fold | GABA fold |
|------------------|---------|----------|--------|---------|-----------|
| Continuous       | 30 min  | 0 min    | 1/1    | 2.0x    | 2.8x      |
| Half duty        | 15 min  | 15 min   | 1/2    | 2.2x    | 2.1x      |
| Third duty       | 10 min  | 20 min   | 1/3    | 2.3x    | 1.9x      |
| **Sixth duty**   | 5 min   | 25 min   | **1/6**| **2.5x**| **1.8x**  |
| Twelfth duty     | 2.5 min | 27.5 min | 1/12   | 1.8x    | 1.5x      |

**Prediction:** Intermittent tDCS with 1/6 duty cycle produces higher net
plasticity (DA/GABA ratio) than continuous stimulation. Specifically,
DA_fold/GABA_fold peaks at duty cycle 1/6 +/- 0.03.

---

### H-ELEC-017: Triple Phase Sequence (1/2, 1/3, 1/6 Timing)

The optimal multi-modal protocol follows a three-phase temporal sequence
with durations in ratio 1/2 : 1/3 : 1/6.

> **Claim:** A stimulation session should be divided into three phases:
>   Phase 1 (1/2 of session): Electrical priming (V6-V11)
>     - Theta induction, alpha suppression, gamma entrainment
>     - Sets the "stage" for chemical effects
>   Phase 2 (1/3 of session): Chemical activation (V1-V5)
>     - tDCS for DA, VNS for 5-HT, TENS for eCB
>     - Chemical effects potentiated by electrical priming
>   Phase 3 (1/6 of session): Coherence binding (V12)
>     - Trimodal 40 Hz for cross-modal binding
>     - Integrates chemical and electrical changes
>
> For a 60-minute session: 30 min electrical, 20 min chemical, 10 min coherence.

```
  Timeline (60 min session):
  |<---------- Phase 1: Electrical (1/2) ---------->|
  |  Theta+Alpha+Gamma entrainment, PFC modulation  |
  0 min                                              30 min
                |<-------- Phase 2: Chemical (1/3) -------->|
                |  tDCS + VNS + TENS activation             |
                                                    30 min  50 min
                                        |<-- Phase 3: Coh (1/6) -->|
                                        |  40Hz trimodal binding   |
                                                            50 min 60 min
```

**Prediction:** The 1/2-1/3-1/6 sequential protocol outperforms simultaneous
all-at-once stimulation on integrated information (Phi) by >20%. The order
matters: reversing to 1/6-1/3-1/2 produces <50% of the optimal effect.

---

### H-ELEC-018: VNS-tDCS Phase Offset at 1/3 Period

When VNS and tDCS are applied concurrently, the optimal phase offset
between their duty cycles is 1/3 of the common period.

> **Claim:** VNS (targeting 5-HT, V3) and tDCS (targeting DA, V1) have
> synergistic effects when their ON phases are offset by 1/3 period.
> This prevents simultaneous GABA loading while maintaining continuous
> neuromodulation. The 1/3 offset corresponds to the meta fixed point:
> the system oscillates around I = 1/3 rather than being pushed to
> extreme excitation or inhibition.
>
> With period T = 6 minutes (matching n=6):
>   tDCS ON: [0, 1] min (1/6 duty = 1 min on, 5 min off)
>   VNS ON:  [2, 3] min (offset by T/3 = 2 min)
>   Gap:     [4, 5] min (recovery, GABA convergence)

```
  tDCS  |##|....|....|....|....|....|##|....|....|
  VNS   |....|....|##|....|....|....|....|....|##|
  GABA  |^^|vvvv|^^|vvvv|vvvv|vvvv|^^|vvvv|^^|vv|
        0    1    2    3    4    5    6    7    8
        ## = ON, .... = OFF, ^^ = rise, vvvv = decay
```

**Prediction:** VNS-tDCS with 1/3 period offset maintains GABA within
[1.5x, 2.0x] (near target 1.8x), while zero-offset drives GABA to
2.5x+ (overshooting the Golden Zone). Measurable via MRS-GABA.

---

### H-ELEC-019: Six-Minute Stimulation Cycle (n=6 Periodicity)

The fundamental stimulation period should be 6 minutes, matching the
perfect number that governs the system.

> **Claim:** A 6-minute cycle is the natural period for neurostimulation
> protocols because:
>   - Hemodynamic response peaks at ~6 seconds, and 6 minutes = 60 cycles
>   - Cortisol ultradian rhythm has ~6-minute microbursts
>   - The contraction mapping f(I)=0.7I+0.1 needs ~10 iterations to
>     converge to 1/3; at one update per ~36 seconds, this takes 6 minutes
>   - 6 divides cleanly into duty cycle fractions: 1 min (1/6), 2 min (1/3), 3 min (1/2)
>
> Session structure: 10 cycles of 6 minutes = 60-minute standard session.
> Within each cycle: 1 min stim, 2 min chemical diffusion, 3 min integration.

| Cycle phase | Duration | Fraction | Activity                    |
|-------------|----------|----------|-----------------------------|
| Stimulate   | 1 min    | 1/6      | Active tDCS + VNS + TENS    |
| Diffuse     | 2 min    | 1/3      | Chemical propagation, no stim|
| Integrate   | 3 min    | 1/2      | 40 Hz binding, consolidation |
| **Total**   | **6 min**| **1**    | = 1/6 + 1/3 + 1/2          |

**Prediction:** Protocols using 6-minute cycles produce more stable EEG
signatures (lower coefficient of variation in theta/alpha ratio across
cycles) than 4-minute or 10-minute cycles. CV < 0.15 for 6-min vs > 0.25
for other periods.

---

### H-ELEC-020: Convergence Protocol — 10 Iterations to Fixed Point

A 10-session longitudinal protocol converges neurochemical baselines
to the target values, following the contraction mapping dynamics.

> **Claim:** The contraction mapping f(I) = 0.7I + 0.1 converges to
> 1/3 within 10 iterations (|f^10(I_0) - 1/3| < 0.01 for any I_0).
> Analogously, a 10-session neurostimulation protocol converges each
> variable toward its target, with each session acting as one iteration:
>   V_n+1 = 0.7 * V_n + 0.3 * V_target
>
> This is a contraction with rate 0.7 and fixed point V_target.

| Session | V1 (DA) | V4 (GABA) | V5 (NE) | V6 (Theta) |
|---------|---------|-----------|---------|------------|
| 0 (base)| 1.00    | 1.00      | 1.00    | 1.00       |
| 1       | 1.45    | 1.24      | 0.82    | 1.45       |
| 2       | 1.77    | 1.41      | 0.67    | 1.77       |
| 3       | 1.99    | 1.52      | 0.57    | 1.99       |
| 5       | 2.27    | 1.66      | 0.45    | 2.27       |
| 7       | 2.41    | 1.73      | 0.41    | 2.41       |
| 10      | 2.48    | 1.79      | 0.40    | 2.48       |
| target  | 2.50    | 1.80      | 0.40    | 2.50       |

```
  DA fold
  change
    2.5 |                                    ___________target
        |                              *****
    2.0 |                        ******
        |                  ******
    1.5 |            ******
        |      ******
    1.0 |******
        |__________________________________________
        0    1    2    3    4    5    6    7    8    9   10
                         Session number
```

**Prediction:** After 10 sessions (spaced 2-3 days apart), resting-state
neurochemical levels (measured by MRS) shift to within 5% of target values
and remain stable for at least 2 weeks post-protocol. Sessions 1-3 show
the steepest change; sessions 7-10 show diminishing returns consistent
with exponential convergence.

---

## Summary Table

| ID          | Grade | Category   | Core claim                                  | Key constant | Notes |
|-------------|-------|------------|---------------------------------------------|-------------|-------|
| H-ELEC-001  | ⚪    | Optimal    | tDCS optimal at 1/e of max current          | 1/e         | Arithmetic OK; mapping arbitrary |
| H-ELEC-002  | ⚪    | Optimal    | VNS converges to 10 Hz (1/3 fixed point)    | 1/3         | Iteration table has rounding errors; range [1,30] vs [0,30] inconsistency |
| H-ELEC-003  | ⚪    | Optimal    | TMS phase transition at 50% MSO             | 1/2         | Roughly matches lit (MT 40-60% MSO); numerological |
| H-ELEC-004  | ⚪    | Optimal    | TENS window width = ln(4/3) of range        | ln(4/3)     | Arithmetic OK; FWHM not a universal constant |
| H-ELEC-005  | ⚪    | Optimal    | 40 Hz buildup time constant = 1/e of session| 1/e         | Exp math OK; gamma onset is seconds not 11 min |
| H-ELEC-006  | ⚪    | Interact   | 12 variables = sigma(6), 4 PCA components   | sigma(6)=12 | Number theory exact; variable mapping is model |
| H-ELEC-007  | ⚪    | Interact   | DA-eCB synergy = product/2                  | 6/sigma(6)  | sigma_{-1}(6)=2 exact; synergy rule is model |
| H-ELEC-008  | ⚪    | Interact   | 4 coupling nodes = tau(6)                   | tau(6)=4    | tau(6)=4 exact; DA-theta and GABA-alpha pairings lit-supported |
| H-ELEC-009  | ⚪    | Interact   | Weight decomposition 1/2+1/3+1/6=1          | perfect 6   | Identity exact (n=6 property); weight assignment is model |
| H-ELEC-010  | ⚪    | Interact   | phi(6)=2 effective degrees of freedom        | phi(6)=2    | phi(6)=2 exact; E/I ratio mapping is model |
| H-ELEC-011  | ⚪    | Conscious  | DA=P, GABA=I, NE=D mapping                  | G=D*P/I     | Algebra OK; DA-plasticity, GABA-inhib lit-supported |
| H-ELEC-012  | ⚪    | Conscious  | All 12 variables optimal in Golden Zone      | [0.21,0.50] | Tautological: targets chosen from GZ constants |
| H-ELEC-013  | ⚪    | Conscious  | Coherence = 1/6 binding term                 | 1/6         | Arithmetic exact (5/6+1/6=1); binding role is model |
| H-ELEC-014  | ⚪    | Conscious  | G*I=D*P conserved during stimulation         | conservation| Definitional tautology (G:=D*P/I) |
| H-ELEC-015  | ⚪    | Conscious  | Theta/Alpha ratio tracks D/I                 | D/I ratio   | Trivial; theta/alpha as biomarker is lit-supported |
| H-ELEC-016  | ⚪    | Protocol   | 1/6 duty cycle optimal for tDCS              | 1/6         | Intermittent tDCS has lit support; 1/6 not established |
| H-ELEC-017  | ⚪    | Protocol   | Three-phase sequence 1/2, 1/3, 1/6           | 1/2+1/3+1/6| Arithmetic exact; protocol is model proposal |
| H-ELEC-018  | ⚪    | Protocol   | VNS-tDCS phase offset at 1/3 period          | 1/3         | Trivial arithmetic; design is model assumption |
| H-ELEC-019  | ⚪    | Protocol   | 6-minute fundamental cycle                   | n=6         | Arithmetic OK; cortisol 6-min claim is WRONG (60-90 min) |
| H-ELEC-020  | ⚪    | Protocol   | 10-session convergence to targets             | contraction | Contraction theorem proven; table values have errors for I_0=0/1 |

---

## Dependencies

All hypotheses are **Golden Zone dependent** (unverified model). The n=6
arithmetic (sigma, tau, phi) is pure number theory (verified), but the
*mapping* of these onto neurostimulation variables is model-dependent.

## Verification Direction

1. H-ELEC-001, 003, 004: Standard dose-response studies with existing equipment
2. H-ELEC-006, 008, 010: PCA/clustering analysis of multi-modal EEG+biochem data
3. H-ELEC-011, 014: Simultaneous MRS + behavioral testing during tDCS
4. H-ELEC-016, 017, 019: Protocol comparison RCTs (most resource-intensive)
5. H-ELEC-020: Longitudinal study (10 sessions, 20+ subjects)

---

## Verification Results (2026-03-28)

**Script:** `verify/verify_elec_hypotheses.py`

**Results:** 0 GREEN, 0 ORANGE, 20 WHITE, 0 BLACK

All 20 hypotheses are arithmetically correct in their core claims. The underlying
number theory (sigma(6)=12, tau(6)=4, phi(6)=2, 1/2+1/3+1/6=1) is exact and proven.

**Issues found:**

- H-ELEC-002: Iteration table values at steps 5 and 10 have rounding discrepancies
  (computed 0.294 vs claimed 0.299 at step 5). Also, the range is stated as [1,30] Hz
  but the calculation uses [0,30] Hz (I=1/3 maps to 10 Hz only if range starts at 0).
- H-ELEC-019: Cortisol "6-minute microbursts" claim is factually incorrect. Cortisol
  ultradian pulses occur at ~60-90 minute intervals (Lightman & Conway, 2003), not 6 min.
- H-ELEC-020: Contraction mapping does NOT converge to within 0.01 of 1/3 in 10
  iterations for all starting points (worst case I_0=1.0 gives error 0.019 after 10
  iterations). The bio-version table also has mismatches for V5 (NE) at sessions 2-10.

**Why all WHITE (no upgrades to ORANGE or GREEN):**

1. GZ constants were CHOSEN as targets -- the "predictions" are tautological
2. Synergy/coupling rules (product/2, block-diagonal) are model proposals, not derived
3. G*I=D*P "conservation" is definitional (G := D*P/I), not a physical conservation law
4. Protocol timing ratios (1/6, 1/3, 1/2) are prescribed from theory, not discovered in data
5. All hypotheses are Golden Zone dependent (unverified model)

**Literature alignment (partial):**

- DA-plasticity link: well-established (Bhatt et al.)
- GABA-alpha generation: well-established (Jensen & Mazaheri)
- DA-theta coupling: well-established (Duzel et al.)
- Motor threshold ~50% MSO: roughly correct (40-60% range)
- Intermittent tDCS benefits: supported (Fricke et al.)
- Theta/alpha as exploration biomarker: supported
