# QC-001: Quantum Error Correction and n=6 Arithmetic

- **ID**: QC-001
- **Grade**: 🟩⭐⭐
- **Domain**: Quantum Computing / Quantum Information
- **Status**: FACT + STRUCTURAL
- **GZ-dependent**: No

> The foundational quantum error correcting codes have parameters
> entirely described by n=6 arithmetic: Steane [[7,1,3]] uses
> P₁+1 qubits with distance P₁/phi, and 6-state QKD is optimal.

## Steane Code [[7,1,3]]

| Parameter | Value | n=6 |
|-----------|-------|-----|
| Physical qubits | 7 | P₁+1 |
| Logical qubits | 1 | unit |
| Distance | 3 | P₁/phi |
| Classical parent (Hamming) | [7,4,3] | [P₁+1, tau, P₁/phi] |

The Steane code is the first CSS code and one of the most important
quantum error correcting codes. ALL its parameters = n=6 arithmetic.

## 6-State QKD Protocol

- BB84 uses 4 = tau(6) states
- 6-state protocol uses 6 = P₁ states on Bloch sphere
- 6-state achieves higher key rate against coherent attacks
- Optimal quantum key distribution = P₁ states

## Quantum Codes and Perfect Numbers

| Code | Parameters | n=6 connection |
|------|-----------|---------------|
| Steane | [[7,1,3]] | P₁+1 qubits, P₁/phi distance |
| Shor | [[9,1,3]] | 9 = (P₁/phi)² |
| Perfect [[5,1,3]] | [[5,1,3]] | 5 = sopfr(6) |
| Surface code | d² physical | d=3: 9=(P₁/phi)² |

## Significance

Quantum error correction — essential for practical quantum computing —
is structured by n=6 arithmetic at its foundation.
