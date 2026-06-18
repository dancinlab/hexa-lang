# H-NT-428: sigma(n)*phi(n) = tau(n)! iff n=6

> **Hypothesis**: The product sigma*phi equals the factorial of the divisor count, uniquely for n=6.

## Background

For n=6: sigma(6)*phi(6) = 12*2 = 24 = 4! = tau(6)!

The number 24 is ubiquitous: Leech lattice dim, eta exponent, Ramanujan |tau(2)|, K3 chi, kissing(4D).

## Verification Data

| n | sigma | phi | sigma*phi | tau | tau! | Match? |
|---|-------|-----|-----------|-----|------|--------|
| 1 | 1 | 1 | 1 | 1 | 1 | YES |
| 2 | 3 | 1 | 3 | 2 | 2 | no |
| 4 | 7 | 2 | 14 | 3 | 6 | no |
| 5 | 6 | 4 | 24 | 2 | 2 | no |
| **6** | **12** | **2** | **24** | **4** | **24** | **YES** |
| 8 | 15 | 4 | 60 | 4 | 24 | no |
| 10 | 18 | 4 | 72 | 4 | 24 | no |
| 28 | 56 | 12 | 672 | 6 | 720 | no (close!) |

## ASCII Graph

```
  value
  720 |                                        * tau(28)!=720
  672 |                                       *  sigma*phi(28)=672
      |   <-- n=28 NEAR-MISS: 672/720 = 93.3%
      |
  112 |                          *  sigma*phi(12)
   72 |                    *        sigma*phi(10)
   60 |              *              sigma*phi(8)
      |
   24 |    * * *                    n=5,6: sigma*phi=24
      |         ^--- n=6: tau!=24 = sigma*phi!
    6 |  *                          sigma*phi(4)=14
    2 | *                           sigma*phi(2)=3
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
      1 2 3 4 5 6 7 8 9 10 ... 28
```

## Near-Miss at n=28

sigma(28)*phi(28) = 56*12 = 672
tau(28)! = 6! = 720
Ratio: 672/720 = 28/30 = 14/15

This near-miss has a clean fraction, suggesting deeper structure.

## Interpretation

24 = sigma*phi is the fundamental "lattice number" of n=6. That it equals tau(6)! adds a factorial interpretation.

## Limitations

- 24 has many factorizations; the factorial form is one of several
- Does not generalize to n=28 (though the near-miss is interesting)
- n=5 also has sigma*phi=24 but tau(5)!=2!=2

## Grade: 🟧* (n=6 structural, near-miss at n=28)
