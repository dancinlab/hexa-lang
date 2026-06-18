# Hypothesis Review 158: Brainwave Frequency Bands and Boltzmann Temperature Mapping
**n6 Grade: 🟩 EXACT** (auto-graded, 11 unique n=6 constants)


## Status: ⚠️ Partially verified

## Hypothesis

> Brainwave frequency bands (δ, θ, α, β, γ) correspond to Boltzmann temperature (T = 1/I). δ (sleep, high I) → θ → α (relaxation = Golden Zone?) → β → γ (low I). The alpha wave state may correspond to the Golden Zone.

## Background

In Boltzmann distribution, temperature T determines the energy distribution of a system. In Hypothesis 004, we mapped T = 1/I, which means that the lower the inhibition (I↓), the "hotter" (more activated) the state.

Brainwaves (EEG) classify the brain's electrical activity into frequency bands. Low frequency (δ) corresponds to deep sleep (high inhibition), and high frequency (γ) corresponds to focused/hyperarousal (low inhibition). A natural mapping may exist between these two systems.

Related hypotheses: Hypothesis 004 (Boltzmann-inhibition temperature), Hypothesis 155 (GABA-inhibition), Hypothesis 159 (meditation)

## Frequency-Inhibition Mapping Table

```
  Brainwave band  Frequency(Hz)  State           T(=1/I)    I(Inhibition)
  ────────────    ─────────────  ────────        ───────    ─────────────
  δ (delta)       0.5-4          Deep sleep      1.1-1.4    0.7-0.9
  θ (theta)       4-8            Light sleep/med 1.5-2.0    0.5-0.7
  α (alpha)       8-13           Relaxation/calm 2.1-3.3    0.3-0.48
  β (beta)        13-30          Focus/arousal   3.3-5.0    0.2-0.3
  γ (gamma)       30-100+        High focus/seiz 5.0+       <0.2
```

## Frequency-I Mapping Diagram

```
  I (Inhibition)
  1.0│
     │  ████ δ band (deep sleep)
  0.9│  ████
     │  ████
  0.8│  ████
     │  ████
  0.7│──████──────────────────────── I=0.7
     │       ████ θ band (light sleep)
  0.6│       ████
     │       ████
  0.5│─ ─ ─ ████─ ─ ─ ─ ─ ─ ─ ─ ─ Critical line (Riemann)
     │  ┌─────────────────────┐
  0.48│  │    ████ α band      │
     │  │    ████ (relaxation) │── Golden Zone
  0.4│  │    ████              │
  0.37│  │─ ─ ████ ─1/e ─ ─ ─ │
     │  │    ████              │
  0.3│  │    ████              │
     │  └─────────────────────┘
  0.24│       ████ β band (focus)
  0.2│──────████──────────────────── I=0.2 (danger line)
     │           ████ γ band (hyperarousal)
  0.1│           ████
     │
  0.0└──┬──┬──┬──┬──┬──┬──┬──→ Frequency (Hz)
       1  4  8  13 20 30 50 100

  ▓▓ Golden Zone (I=0.24~0.48) ≈ overlaps with α wave band!
```

## Key Finding: α Waves = Golden Zone?

The inhibition range of alpha waves (8-13Hz) (I≈0.3-0.48) substantially overlaps with the Golden Zone (I=0.21-0.50). Is this a coincidence, or a fundamental connection?

### Evidence 1: Alpha Waves and Creativity

```
  Study                         Key findings
  ──────────────                ───────────
  Martindale (1999)             α waves↑ during creative thinking
  Fink et al. (2009)            Divergent thinking → upper α increase
  Jung-Beeman (2004)            α suppression → γ burst just before insight
  Jauk et al. (2012)            High creativity = high α power
```

### Evidence 2: Meditation and α-θ Boundary

Long-term meditators (Hypothesis 159) operate near the α-θ boundary (I≈0.5), which corresponds to the Golden Zone upper bound (critical line).

## Boltzmann Temperature Interpretation

```
  T = 1/I

  T value  I value   Brainwave   Boltzmann interpretation
  ────     ────      ─────       ────────────────
  1.2      0.83      δ           "Cold" — ground energy state dominant
  1.7      0.59      θ           "Lukewarm" — low energy state prevails
  2.7      0.37      α (Golden)  "Optimal temperature" — optimal energy distribution
  4.0      0.25      β           "Hot" — high energy state activated
  10+      <0.1      γ (excess)  "Overheated" — energy disorder (seizure risk)
```

### Alpha Waves = "Optimal Temperature"

In Boltzmann distribution, when T ≈ 2.7 (I ≈ 0.37 ≈ 1/e), the energy distribution is "optimally distributed." Neither too cold (all neurons inactive) nor too hot (all neurons overactive). This matches the "relaxed but awake" state of alpha waves.

## Brainwave Transitions at Insight Moments

Jung-Beeman's (2004) "Aha!" moment research:

```
  Time →   Preparation  Incubation  Insight!  Elaboration
            α↑           α-θ         γ burst    β
            I≈0.4        I≈0.5       I≈0.1      I≈0.25

  I value
  0.6│
     │        ┌──┐
  0.5│─ ─ ─ ─│──│─ ─ ─ ─ ─ ─ ─ ─ ─ Critical line
     │  ┌──┐ │  │
  0.4│  │  │ │  │                     Golden Zone
     │  │α │ │θ │
  0.3│  │  │ │  │              ┌──┐
     │  │  │ │  │              │β │   Golden Zone
  0.2│──└──┘─└──┘──────────────└──┘── lower bound
     │              ┌──┐
  0.1│              │γ!│ ← Insight moment (cusp transition?)
     │              └──┘
  0.0└──────────────────────────────→ Time
```

At the moment of insight, I drops sharply below the Golden Zone and then returns. This may be a manifestation of cusp transition (Hypothesis 003) at the brainwave level.

## Limitations

- The overlap of α wave range (8-13Hz) with the Golden Zone (I=0.21-0.50) depends on the choice of mapping function
- The exact nonlinear function for brainwave frequency → I conversion is undetermined
- Brainwaves reflect only cortical surface activity; inhibition of deep structures (thalamus, basal ganglia) not reflected
- I may differ by brain region even within the same frequency band
- γ waves are associated with both insight and seizures → duality problem of low I

## Verification Directions

- [ ] Precisely calibrate EEG power spectrum → I value conversion function
- [ ] Correlation analysis of α wave power during creative tasks and simulated Compass Score
- [ ] Measure time spent in Golden Zone from brainwave data of meditators (Hypothesis 159)
- [ ] Verify whether γ burst at insight moment fits cusp transition model
- [ ] Build triangular mapping of GABA (Hypothesis 155) ↔ brainwave frequency ↔ I

---

*Written: 2026-03-22*
*Status: ⚠️ α wave-Golden Zone overlap is interesting, but arbitrariness of mapping function needs to be resolved*
