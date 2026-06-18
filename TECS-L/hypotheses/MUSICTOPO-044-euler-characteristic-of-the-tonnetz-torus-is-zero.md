# MUSICTOPO-044: Euler Characteristic of the Tonnetz Torus is Zero

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The Tonnetz, as a triangulation of the torus T^2, has Euler characteristic chi = 0. With the standard triangulation using 12 = sigma(6) vertices, 36 edges, and 24 = 2*sigma(6) triangular faces: chi = 12 - 36 + 24 = 0.

## Background

The Tonnetz triangulates T^2 with vertices at the 12 pitch classes.
The Euler characteristic chi = V - E + F must equal 0 for any
triangulation of the torus.

## Verification

```
  Tonnetz triangulation:
    V (vertices) = 12 = sigma(6)
    E (edges)    = 36 = P1^2
    F (faces)    = 24 = 2 * sigma(6)

  chi = V - E + F = 12 - 36 + 24 = 0  EXACT

  Check: chi(T^2) = 0 for any torus  (topological invariant)
  This is consistent: 0 = 0  VERIFIED
```

## ASCII Tonnetz Triangulation

```
       A----C#---F----A
      /|\  /|\  /|\  /
     / | \/ | \/ | \/
    F--|-Ab--|-C--|-E--F      Each parallelogram = 2 triangles
     \ | /\ | /\ | /\       V=12, E=36, F=24
      \|/  \|/  \|/  \
       Db---F----A----Db
      (identified edges -> torus)
```

## Euler Characteristic Components

| Component | Value | n=6 Link |
|-----------|-------|----------|
| Vertices V | 12 | sigma(6) |
| Edges E | 36 | P1^2 |
| Faces F | 24 | 2*sigma(6) |
| chi = V-E+F | 0 | torus invariant |
| F/V ratio | 2 | phi(6) |

## Interpretation

The Tonnetz Euler characteristic 0 = sigma(6) - P1^2 + 2*sigma(6) gives
the remarkable identity sigma(6) + 2*sigma(6) = P1^2, i.e., 12 + 24 = 36
=> 3*sigma(6) = P1^2 => 3*12 = 36 = 6^2. This is 3*sigma(6) = P1^2,
a clean n=6 identity.
