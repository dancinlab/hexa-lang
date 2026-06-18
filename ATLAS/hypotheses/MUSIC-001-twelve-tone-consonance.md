# Hypothesis MUSIC-001: 12-TET = sigma(6) Semitones, Consonance = d(6) Ratios
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


## Hypothesis

> The 12-tone equal temperament (12-TET) system divides the octave into 12 = sigma(6) equal
> semitones. The most consonant musical intervals are defined by frequency ratios involving
> ONLY the divisors of 6: {1, 2, 3, 6}. The semitone counts of fundamental intervals map
> exactly to number-theoretic functions of n=6.

## Background and Context

Western music's foundation rests on the 12-tone chromatic scale — a division of the octave
into 12 equal semitones. The number 12 appears throughout music: 12 keys in the circle of
fifths, 12 major scales, 12 minor scales. This is sigma(6) = 1+2+3+6 = 12.

The consonance hierarchy of musical intervals has been studied since Pythagoras. The most
consonant intervals have the simplest frequency ratios, and these ratios involve small
integers — specifically, the divisors of 6.

Related hypotheses: H-CX-090 (master formula = perfect number 6), H-CX-098 (unique
reciprocal sum 1/2+1/3+1/6=1).

## Interval-to-n=6 Mapping Table

```
  Interval          Semitones  Ratio    n=6 Function      Match
  ─────────────────┬──────────┬────────┬─────────────────┬──────
  Unison            │  0       │ 1:1    │ d1:d1           │ exact
  Minor second      │  1       │ 16:15  │ (none)          │ --
  Major second      │  2       │ 9:8    │ phi(6)          │ exact
  Minor third       │  3       │ 6:5    │ max prime of 6  │ exact
  Major third       │  4       │ 5:4    │ tau(6)          │ exact
  Perfect fourth    │  5       │ 4:3    │ sopfr(6)        │ exact
  Tritone           │  6       │ sqrt2  │ P1 = n itself   │ exact
  Perfect fifth     │  7       │ 3:2    │ n+1 = P1+1      │ exact
  Minor sixth       │  8       │ 8:5    │ (none)          │ --
  Major sixth       │  9       │ 5:3    │ (none)          │ --
  Minor seventh     │ 10       │ 16:9   │ (none)          │ --
  Major seventh     │ 11       │ 15:8   │ (none)          │ --
  Octave            │ 12       │ 2:1    │ sigma(6)        │ exact
  ─────────────────┴──────────┴────────┴─────────────────┴──────

  Matched intervals: 8 out of 12 (unison, maj2, min3, maj3, P4, tritone, P5, octave)
  Unmatched: minor 2nd, minor 6th, major 6th, minor 7th, major 7th
```

## Consonance Hierarchy and Divisors of 6

```
  Consonance rank (most to least consonant):

  Rank 1: Unison    1:1  ── uses {1}       subset of d(6)  YES
  Rank 2: Octave    2:1  ── uses {1,2}     subset of d(6)  YES
  Rank 3: Fifth     3:2  ── uses {2,3}     subset of d(6)  YES
  Rank 4: Fourth    4:3  ── uses {3,4}     4 = tau(6)      EXTENDED
  Rank 5: Maj 3rd   5:4  ── uses {4,5}     5 = sopfr(6)    EXTENDED
  Rank 6: Min 3rd   6:5  ── uses {5,6}     both n=6 funcs  YES

  The three "perfect consonances" (unison, octave, fifth) use ONLY d(6)={1,2,3}.
  The fourth introduces tau(6)=4. The thirds introduce sopfr(6)=5.
```

## Circle of Fifths: sigma(6) = 12 Steps

```
         C
      F     G
    Bb        D
   Eb          A
    Ab        E
      Db    B
        Gb/F#

  12 keys = sigma(6), each separated by a perfect fifth (7 semitones).
  After 12 fifths: (3/2)^12 = 129.746...
  After 7 octaves: 2^7 = 128
  Pythagorean comma = (3/2)^12 / 2^7 = 3^12 / 2^19 = 531441/524288
                    = 1.013643... (about 23.46 cents)

  Comma as fraction of octave: 23.46/1200 = 0.01955
  Compare: 1/sopfr(6)^2 = 1/25 = 0.04 (same order, not exact)
```

## Tritone: The Devil's Interval at n = P1

```
  Tritone = 6 semitones = P1 = n
  Frequency ratio = 2^(6/12) = 2^(1/2) = sqrt(2) = irrational!

  The tritone divides the octave exactly in half:
    6/12 = 1/2 = Golden Zone upper boundary

  It is the ONLY interval that is its own complement:
    12 - 6 = 6 (tritone + tritone = octave)

  Historically called "diabolus in musica" — the most dissonant interval.
  In the n=6 framework: the number itself creates maximum tension.

  Tritone ratio in cents:
  ┌──────────────────────────────────────────────────────┐
  │ 0        300       600       900       1200 cents    │
  │ |─────────|─────────|─────────|─────────|            │
  │ Unison    min3     TRITONE   maj6    Octave          │
  │                      ^                               │
  │              exactly 1/2 of octave                   │
  └──────────────────────────────────────────────────────┘
```

## Just Intonation vs 12-TET Deviation

```
  Interval     Just Ratio  Just Cents  12-TET Cents  Error (cents)
  ────────────┬───────────┬───────────┬─────────────┬─────────────
  Unison       │ 1/1       │    0.000  │    0.000    │   0.000
  Minor 3rd    │ 6/5       │  315.641  │  300.000    │ -15.641
  Major 3rd    │ 5/4       │  386.314  │  400.000    │ +13.686
  Perfect 4th  │ 4/3       │  498.045  │  500.000    │  +1.955
  Tritone      │ sqrt(2)   │  600.000  │  600.000    │   0.000
  Perfect 5th  │ 3/2       │  701.955  │  700.000    │  -1.955
  Octave       │ 2/1       │ 1200.000  │ 1200.000    │   0.000
  ────────────┴───────────┴───────────┴─────────────┴─────────────

  Perfect intervals (octave, fifth, fourth) have smallest errors.
  These use d(6) ratios: 2/1, 3/2, 4/3.
  The fourth error = 1.955 cents = 1200 * log2(4/3) - 500.
```

## Temperament Unit

```
  The fundamental pitch unit = 2^(1/12) = 2^(1/sigma(6))
  = 1.059463...

  ln(2^(1/12)) = ln(2)/12 = ln(2)/sigma(6) = 0.05776...
  Compare: ln(4/3) / sopfr(6) = 0.2877/5 = 0.05754 (0.4% close!)
```

## Verification Results

See verify/verify_music_001_twelve_tone.py for numerical confirmation.

Verified exact matches:
- 12 semitones = sigma(6) = 12 (exact)
- Tritone = 6 = n semitones (exact)
- Perfect fifth = 7 = n+1 semitones (exact)
- Perfect fourth = 5 = sopfr(6) semitones (exact)
- Major third = 4 = tau(6) semitones (exact)
- Minor third = 3 = largest prime factor of 6 (exact)
- Major second = 2 = phi(6) semitones (exact)
- Circle of fifths returns after 12 = sigma(6) steps (exact)

## Interpretation

The 12-TET system is not arbitrary. The number 12 = sigma(6) is the divisor sum of the
first perfect number. The most consonant intervals correspond to the simplest frequency
ratios, which involve the divisors of 6 and its number-theoretic functions.

The tritone at exactly 6 semitones (dividing the octave at 1/2) being the most dissonant
interval is striking: the perfect number itself creates maximum musical tension.

8 of 12 interval semitone counts map to n=6 functions. The unmapped intervals (minor 2nd,
minor/major 6th, minor/major 7th) are the less consonant ones.

## Limitations

- The number 12 appears in many contexts (months, hours, zodiac) — could be selection bias.
- 12-TET is a Western convention; other cultures use different divisions (e.g., 24-TET in
  Arabic music, 22 shrutis in Indian music).
- The consonance ranking is partly cultural, not purely physical.
- Some mappings (n+1=7 for the fifth) involve a +1 correction — ad hoc risk.
- The Pythagorean comma does not map cleanly to any n=6 constant.

## Next Steps

- Texas Sharpshooter test: what fraction of random number-theoretic functions would produce
  similar matches to the 12 intervals?
- Investigate whether 22 shrutis or 24-TET also have number-theoretic structure.
- Check if harmonic series overtone structure (f, 2f, 3f, ...) connects to d(6) ordering.
- Explore whether musical key signatures (sharps/flats counts) relate to d(6).
