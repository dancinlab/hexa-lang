# Hypothesis MUSIC-036: Common Time Signature Numerators from div(6)

**Grade: 🟧 WEAK**

## Hypothesis

> The most common time signature numerators {2, 3, 4, 6} are exactly the
> divisors of 6: div(6) = {1, 2, 3, 6}.

## Background

The most frequently used time signatures are 2/4, 3/4, 4/4, and 6/8.
Their numerators {2, 3, 4, 6} overlap significantly with div(6) = {1,2,3,6}.

## Numerical Verification

| Time Sig | Numerator | In div(6)? | In functions? |
|----------|-----------|-----------|---------------|
| 2/4      |     2     |  YES (d)  | phi(6)=2      |
| 3/4      |     3     |  YES (d)  | P1/2=3        |
| 4/4      |     4     |  NO       | tau(6)=4      |
| 6/8      |     6     |  YES (d)  | P1=6          |

## ASCII Diagram

```
  div(6)     = {1, 2, 3,    6}
  Numerators = {   2, 3, 4, 6}
  Overlap    = {   2, 3,    6}  = 3/4 overlap

  4 is NOT a divisor of 6 but IS tau(6).
```

## Interpretation

3 of 4 common numerators are divisors of 6; the 4th is tau(6).
Not a perfect match to div(6) due to 4 vs 1.

## Limitations

- 4 is in {tau(6)} not div(6). 1 is in div(6) but 1/4 time is not used.


## Grade: 🟧 WEAK

Golden Zone dependency: None (pure music theory observation).
