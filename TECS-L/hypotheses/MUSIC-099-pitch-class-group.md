# Hypothesis MUSIC-099: Pitch Class Group Z_12 = Z_{sigma(6)}

**Grade: 🟩 EXACT**

## Hypothesis

> The pitch class group is Z_12 = Z_{sigma(6)}, the cyclic group of order
> sigma(6) = 12, with addition modulo 12.

## Background

Pitch classes form the cyclic group Z_12 under transposition. This
algebraic structure underlies all of twelve-tone theory and set theory.

## Numerical Verification

| Property          | Value | n=6 Function | Match |
|-------------------|-------|-------------- |-------|
| Group order       |  12   | sigma(6)=12  | EXACT |
| Generators        |  4    | tau(6)=4?    | CHECK |
| Subgroups         |  6    | P1=6         | EXACT |
| Elements          |  12   | sigma(6)=12  | EXACT |

Generators of Z_12: {1,5,7,11} = elements coprime to 12
phi(12) = 4 = tau(6) (Euler totient of sigma(6) = tau(6)!)

## ASCII Diagram

```
  Z_12 subgroup lattice:
       Z_12
      / | \
    Z_6  Z_4  Z_3
      \  |  /
       Z_2
        |
       Z_1
  = 6 subgroups = P1!
```

## Interpretation

Z_{sigma(6)} has P1=6 subgroups and phi(sigma(6))=tau(6)=4 generators.
The group theory of the pitch class group encodes n=6 constants!

## Limitations

- Z_12 properties follow from 12's factorization, not directly from 6.


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
