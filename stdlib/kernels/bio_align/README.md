# kernels/bio_align/ — ①a sequence-alignment kernel (demiurge D72)

Domain-agnostic sequence-alignment kernel. **NEW kernel folder added
by D80 pilot #12** — first kernel in the bio domain family
(`kernels/bio_*/`), introducing the bio substrate to the D80
hexa-native port roster. Prior pilots covered orbital / solar /
plasma / mc_transport / graph / urdf / neural / signal_proc / noc_sim
/ circuit / fem / autodiff — none touched the bio family until now.

| file | role |
|---|---|
| `needleman_wunsch_kernel.hexa` | Global pairwise alignment via Needleman-Wunsch DP — `score_only` + `align`. Integer-symbol-agnostic (caller supplies the ASCII / DNA-index / protein-index encoding) and linear-gap (a follow-on pilot will land Gotoh affine gap). |
| `needleman_wunsch_kernel_test.hexa` | substrate parity test — 36 assertions across 7 sequence pairs + 5 invariants vs an integer Python transliteration (`needleman_wunsch_oracle.py`). Bit-exact integer equality on score AND every aligned column. |
| `needleman_wunsch_oracle.py` | Clean-room Python `math`-free integer transliteration of the kernel — used to capture the `want` literals embedded in the test. No Biopython / EMBOSS / parasail import. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No FASTA parser, no
  BLOSUM62 / PAM250 substitution matrix lookup, no organism-specific
  alphabet — pure "two integer-encoded sequences + (match, mismatch,
  gap) -> optimal global alignment score + columns".
- **①b adapter** — `stdlib/bio/needleman_wunsch.hexa` (future). Will
  own the DNA / protein alphabet mapping, BLOSUM / PAM substitution-
  matrix table lookup, FASTA / UniProt input contract, and any
  honesty caveats specific to a real biological alignment task.

## API

- `gap_symbol() -> int` — sentinel value (-1) inserted into the
  aligned-rows where an indel occurred. Caller filters this out to
  recover the original sequences.
- `score_only(a, b, match_s, mismatch_s, gap_s) -> int` —
  optimal global-alignment score only. O(|a|·|b|) time.
- `align(a, b, match_s, mismatch_s, gap_s) -> [[int]]` — full
  alignment. Returns `[[score], a_aligned, b_aligned]`. Tie-break in
  traceback: diagonal > up > left.

## Algorithm provenance

Clean-room — no Biopython / EMBOSS needle / parasail / SeqAn / ssw /
scikit-bio source-code inspection. Needleman-Wunsch is a textbook
dynamic-programming recurrence pre-dating every modern alignment
library by decades:

- Needleman SB, Wunsch CD (1970), "A general method applicable to the
  search for similarities in the amino acid sequence of two
  proteins", *J. Mol. Biol.* **48**(3):443-453.
- Durbin R, Eddy SR, Krogh A, Mitchison G (1998), *Biological
  Sequence Analysis: Probabilistic Models of Proteins and Nucleic
  Acids*, Cambridge University Press, §2.3 (global alignment with
  linear gap penalty) is the spec we follow.

## Honesty (g3)

- **Linear gap only**. Affine gap (open + extend penalties — Gotoh
  1982) is a separate pilot (a 3-matrix DP). Real protein alignment
  typically uses affine + BLOSUM62; this kernel is the closed-form
  baseline.
- **Simple match/mismatch scoring**. A full (K × K) substitution
  matrix (BLOSUM50/62/80, PAM120/250, EDNAFULL) is a one-step
  extension — replace `score(x, y) = match if x==y else mismatch`
  with `score(x, y) = matrix[x][y]`. Queued.
- **Global only**. Smith-Waterman (local alignment) is a separate
  pilot — same DP recurrence with the floor at 0 + local-max
  traceback start.
- **Optimal alignment can be non-unique** — multiple alignments may
  share the maximum score. The SCORE is unique; our traceback
  tie-break (diag > up > left) selects one canonical alignment, and
  the oracle uses the same tie-break.
- **`absorbed = false`** at the record layer (D80 g_hexa_only) —
  this is a NEW domain (bio) in `demiurge:domains/DEPENDENCIES.demi`;
  the flip happens at the cell level when a bio producer actually
  consumes this kernel, not in the kernel itself.

## Parity (pilot #12, 2026-05-20)

36/36 PASS at bit-exact integer equality:

- **7 sequence pairs** (Durbin §2.3 sequences with simple scoring;
  Wikipedia GATTACA/GCATGCU; identity ACGT; empty-vs-ACGT; disjoint
  AAAA/TTTT; EDNAFULL-style DNA pair; single-insertion AT/ACT) —
  score AND aligned columns both match the Python oracle exactly.
- **5 invariants** — self-alignment yields `len*match`; symmetry
  `score(a,b) == score(b,a)`; empty/empty yields 0; gap-stripped
  alignment rows recover the original sequences (both a and b).

D80 spec ceiling: rel_err ≤ 1e-10. Actual: integer arithmetic
throughout, so rel_err = 0 exactly. See
`docs/notes/hexa-native-port-pattern-pilot.md` "Pilot #12" for the
full algorithm-choice rationale and lessons-learned.

## Why bio is the right domain

The bio domain was added to demiurge in D81 (2026-05-20) with no
hexa-native substrate yet — `hexa-bio/` is the sibling SSOT but
nothing in `stdlib/kernels/` referenced it. Needleman-Wunsch is the
canonical bio-textbook algorithm (Durbin §2.3 — the chapter that
introduces the entire field) and uses pure-integer arithmetic, so the
1e-10 spec ceiling collapses to bit-exact. That makes it the
smallest, most reviewable foothold for the bio family.

## Follow-on pilots queued

- Smith-Waterman (local alignment) — same DP recurrence with floor=0.
- Gotoh 1982 affine-gap (open + extend) — 3-matrix DP.
- Substitution-matrix-aware variant — replace (match_s, mismatch_s)
  with a `[K][K]` score lookup; first real ①b adapter consumer.
- Hirschberg (space-O(min(m,n))) — recursive midpoint split.
