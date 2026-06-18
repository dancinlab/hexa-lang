# H-EE-113: Category Theory — n=6 as Terminal Object in Balanced Arithmetic
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


## Hypothesis

> n=6 is the terminal object in the category of "arithmetically balanced integers."
> Every balanced number has a unique morphism to 6. This universal property
> formalizes why n=6 is the universal reference point of the framework.

## Background: Terminal Objects

In a category C, an object T is terminal if for every object X in C,
there exists exactly one morphism X -> T.

Examples:
  - In Set: the one-element set {*} is terminal (every set has a unique
    function to {*})
  - In Top: the one-point space is terminal
  - In Grp: the trivial group {e} is terminal

Terminal objects are universal: they "absorb" all other objects via
a unique arrow. If n=6 is terminal in some arithmetic category,
this explains its universality without further argument.

## Proposed Category: BalArith

Objects: Positive integers n with R(n) <= 1 (under-balanced or balanced)
  {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ...}  — all n where sigma(n)*phi(n) <= n*tau(n)

Note: R(n) <= 1 includes all primes (R(p) = (p+1)*(p-1)/(p*2) = (p^2-1)/(2p) < p/2 < 1 for small p),
and n=6 with R=1 exactly.

Morphisms: f: m -> n is a morphism if f(m) | n and R(f(m)) <= R(n)
(divisibility with non-decreasing balance)

## Why 6 Would Be Terminal

R(6) = 1 is the maximum value in the under-balanced set (since R > 1 objects
are excluded). Any balance-preserving map from m to some n must eventually
compose to n=6 if we require the morphism to be "balance-maximizing."

Claim: For any m in BalArith, the map m -> 6 given by the "balance completion"
  f(m) = smallest n >= m with R(n) = 1
is the unique balance-maximizing morphism.

For m <= 6: f(m) = 6 (the unique balanced integer >= m)
For m > 6: The next perfect number is 28. R(28) = sigma(28)*phi(28)/(28*tau(28))
  = 56*12/(28*6) = 672/168 = 4. So 28 is NOT balanced in the R=1 sense.
  The morphism must wrap around or fail — requires careful definition.

## The Simpler Categorical Statement

Restrict to {n : R(n) = 1} = {1, 6, ...} (only perfectly balanced integers).
In this subcategory, n=1 and n=6 are the only known objects.

If R(n)=1 only for n in {1, 6} among small integers (as numerical evidence suggests),
then the category has just two objects. The terminal object is 6 (since 1 -> 6
exists trivially via the inclusion map, but 6 -> 1 does not preserve R=1).

## Current Status

  Category construction: PARTIAL — morphisms not fully defined
  Terminality proof: NOT DONE
  Uniqueness of morphisms: CONJECTURED

## Conclusion

**Status: Theoretical framework — morphisms need rigorous definition**
**Core claim:** n=6 is the terminal object in some natural arithmetic category
**Significance:** Universal property would replace all case-by-case n=6 arguments
with a single categorical statement: "6 is the terminal balanced integer"

*Written: 2026-03-28*
