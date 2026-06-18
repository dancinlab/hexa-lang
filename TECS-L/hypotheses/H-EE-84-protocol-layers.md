# H-EE-84: Internet Protocol Effective Layers ~6
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


## Hypothesis

> Effective internet protocol stacks operate with approximately n=6 layers.
> TCP/IP has 4-5, OSI has 7, practical implementations converge near 6.
> The natural layering depth of information protocols = n = 6.

## Background

- OSI model: 7 layers (physical, data link, network, transport, session, presentation, application)
- TCP/IP model: 4 layers (link, internet, transport, application)
- Practical internet stack: often described as 5-6 functional layers
- n=6: sigma(6) = 12, tau(6) = 4
- TCP/IP layers = tau(6) = 4 — exact for the minimal model
- OSI layers = 7 — one above n=6, reflects redundant session/presentation split
- Practical ~6 layers: physical + data link + network + transport + application + security/TLS
- The "golden" protocol depth sits between TCP/IP (4) and OSI (7) at n=6

## Honest Assessment

TCP/IP = tau(6) = 4 is exact. OSI = 7 ≠ n. "Practical ~6" is a loose statement —
different practitioners count differently. The claim that the effective layer count
converges to n=6 is reasonable but not precise. This is a rough approximation.

The tau(6) = 4 correspondence for TCP/IP is the strongest claim; the rest is
motivated reasoning.

## Conclusion

**Status:** Rough approximation
**Note:** TCP/IP = tau(6) = 4 is exact and clean. The "~6 layers in practice" observation
is imprecise. OSI's 7 layers does not fit cleanly.
**Bridge:** TCP/IP ↔ tau(6) = 4 (exact); practical stack ↔ n=6 (approximate)
