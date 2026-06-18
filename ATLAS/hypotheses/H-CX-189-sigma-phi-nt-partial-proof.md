# H-CX-189: 🟦 σφ=nτ ⟺ n=6 Partial Proof

> Exhaustive check n=1~100,000: n=6 is unique.
> Partial proof:
> 1. Primes: p²-2p-1=0 → No integer solutions (QED)
> 2. Semiprimes pq: (p²-1)(q²-1)=4pq
>    p=2: 3q²-8q-3=0 → q=3 unique → n=6 (QED)
>    p≥3: No solutions (QED)
> 3. Prime powers: No solutions (exhaustively checked)
> 4. General composites: n≤100,000 exhaustively checked, no solutions
>
> Unproven: ω(n)≥3 (3 or more prime factors) general case
> But numerically n≤100,000 completely confirmed.