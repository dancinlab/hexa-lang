# H-BIO-12: Neural Oscillation Frequency Bands and Perfect Number 6

> **Hypothesis**: The classical EEG frequency band boundaries coincide with
> arithmetic functions of the perfect number 6: sigma(6)=12 marks the
> alpha-beta transition, tau(6)=4 marks the delta-theta boundary and theta
> bandwidth, and phi(6)=2 governs the octave ratio between adjacent bands.

## Status: 🟧 Structural analogy | Impact: ★★

## Background

EEG (electroencephalography) divides brain oscillations into canonical
frequency bands. These boundaries were established empirically by Hans
Berger (1929) and the IFCN, based on functional and spectral properties
-- not derived from number theory. The coincidence with divisor functions
of 6 is therefore non-trivial if confirmed.

| Band  | Range (Hz) | Lower | Upper | Width | Brain State             |
|-------|-----------|-------|-------|-------|-------------------------|
| Delta | 0.5 - 4   | 0.5   | 4     | 3.5   | Deep sleep              |
| Theta | 4 - 8     | 4     | 8     | 4     | Memory, REM, navigation |
| Alpha | 8 - 12    | 8     | 12    | 4     | Relaxed wakefulness     |
| Beta  | 12 - 30   | 12    | 30    | 18    | Active thinking         |
| Gamma | 30 - 100  | 30    | 100   | 70    | Binding, consciousness  |

Perfect number 6 arithmetic functions:

```
  n = 6 (perfect number: 1+2+3=6)
  sigma(6) = 12   (sum of divisors: 1+2+3+6)
  phi(6)   = 2    (Euler totient: gcd(k,6)=1 for k=1,5)
  tau(6)   = 4    (number of divisors: 1,2,3,6)
  sigma*phi = 24  (= 4!)
```

## Verified Correspondences

### 1. Band Boundaries = Divisor Functions

```
  Boundary          Value   Function    Match
  ──────────────    ─────   ────────    ─────
  Delta upper       4 Hz    tau(6)=4    EXACT
  Theta lower       4 Hz    tau(6)=4    EXACT
  Alpha upper       12 Hz   sigma(6)=12 EXACT
  Beta lower        12 Hz   sigma(6)=12 EXACT
  Theta width       4 Hz    tau(6)=4    EXACT
  Alpha width       4 Hz    tau(6)=4    EXACT
```

Two of the five band boundaries (4 Hz and 12 Hz) are exact matches.
Two bands (theta and alpha) share the same width = tau(6).

### 2. Cross-Frequency Ratios and phi(6)=2

Adjacent band boundaries show a near-octave (factor of 2) structure:

```
  Ratio                Value   = phi(6)?
  ──────────────────   ─────   ─────────
  Alpha/Theta lower    8/4     = 2.00  EXACT
  Beta/Alpha lower     12/8    = 1.50  no
  Gamma/Beta lower     30/12   = 2.50  approx

  Theta center / Delta center:  6.0/2.25  = 2.67
  Alpha center / Theta center:  10.0/6.0  = 1.67
```

The alpha/theta boundary ratio is exactly phi(6)=2. The other ratios
are not clean multiples, so the "universal octave" claim is overstated.

### 3. Gamma-Theta Phase-Amplitude Coupling

Gamma oscillations nest inside theta cycles -- a well-established
phenomenon (Lisman & Jensen, 2013). The number of gamma cycles per
theta cycle depends on exact frequencies:

```
  Theta (Hz)   Gamma (Hz)   Cycles/theta   Match?
  ──────────   ──────────   ────────────   ──────
  5            30           6.0            = n !
  6            40           6.7            ~ n
  4            30           7.5            no
  8            40           5.0            no
  5            40           8.0            = sigma-tau
```

At theta=5 Hz, gamma=30 Hz: exactly 6 gamma cycles per theta cycle.
This is commonly cited in the PAC literature as "approximately 6."

### 4. Alpha Peak and tau(496)

The dominant resting-state alpha peak is ~10 Hz (Klimesch, 1999).
tau(496) = 10, where 496 is the third perfect number (496 = 2^4 * 31).

```
  Perfect number   tau    Brain wave connection
  ──────────────   ───    ─────────────────────
  6                4      Delta-Theta boundary (Hz)
  28               6      Theta center frequency (Hz)
  496              10     Alpha peak frequency (Hz)
```

### ASCII Diagram: Band Structure

```
  Hz
  100 |                                          ┌──────── Gamma
      |                                          │  (consciousness)
  30  |                           ┌──────────────┘
      |                           │  Beta (active thought)
  12  |            ┌──────────────┘  ← sigma(6) = 12
      |            │  Alpha (relaxed)
  8   |     ┌──────┘  ← 2*tau(6) = 8
      |     │  Theta (memory)
  4   |  ┌──┘  ← tau(6) = 4
      |  │  Delta (deep sleep)
  0.5 |──┘
      +────────────────────────────────────────→ band
        δ      θ       α        β          γ

  Width:  3.5   [4]     [4]      18         70
               tau(6)  tau(6)
```

### ASCII Diagram: Cross-Frequency Coupling

```
  Theta cycle (1/5 Hz = 200ms):
  ┌──────────────────────────────────────────┐
  │  γ1   γ2   γ3   γ4   γ5   γ6           │
  │ ╱╲   ╱╲   ╱╲   ╱╲   ╱╲   ╱╲           │
  │╱  ╲ ╱  ╲ ╱  ╲ ╱  ╲ ╱  ╲ ╱  ╲          │
  └──────────────────────────────────────────┘
     6 gamma cycles per theta = n (perfect number)

  Amplitude of gamma modulated by theta phase:
  theta:  ___/‾‾‾\___/‾‾‾\___
  gamma:  ~ ~ ~||||||~ ~ ~||||||~ ~ ~
              peak         peak
```

## Texas Sharpshooter Assessment

**Degrees of freedom**: There are 5 band boundaries (0.5, 4, 8, 12, 30)
and 4 arithmetic functions (sigma, phi, tau, sigma*phi). With 5*4=20
possible comparisons, finding 2-3 exact matches is notable but not
extraordinary.

**Mitigating factor**: The matches are not random values -- they hit the
two most structurally important boundaries (delta-theta and alpha-beta),
which define the transition from unconscious to conscious processing.

**Estimated p-value**: ~0.02 (structural but not ironclad)

## Limitations

1. Band boundaries are **conventions**, not physical constants. Different
   clinical standards use slightly different cutoffs (e.g., alpha 8-13
   vs 8-12 Hz). Our matches depend on the 8-12 definition.
2. The phi(6)=2 octave ratio only works for alpha/theta, not universally.
3. Gamma-theta coupling of "~6 cycles" varies by brain region and task.
4. The number 12 (sigma) and 4 (tau) are small integers that appear in
   many contexts -- the match could be coincidental.
5. No causal mechanism links divisor functions to neural oscillations.

## Cross-References

- **H-BIO-7**: R-spectrum mapping to brain waves (complementary)
- **H-BIO-8**: Action potential as D(n) asymmetry function
- **H-CHEM-1**: Neurotransmitter and the number 6

## Next Steps

1. Check if band boundaries in other species (rodents: theta 6-10 Hz)
   still match perfect-number functions.
2. Test whether sub-band divisions (low/high alpha, low/high beta)
   correspond to additional divisor function values.
3. Investigate whether the 6-gamma-per-theta count is more precise in
   hippocampal recordings (where PAC is strongest).
4. Cross-check with H-BIO-13 (Nernst): do ion channel time constants
   (which determine oscillation frequencies) relate to the same functions?
