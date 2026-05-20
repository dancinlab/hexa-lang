# stdlib/kernels/bio_align/needleman_wunsch_oracle.py — D80 g_hexa_only
# pilot #12 — Python `math`-free integer transliteration of
# `needleman_wunsch_kernel.hexa`. Used to capture the `want` integers
# embedded in `needleman_wunsch_kernel_test.hexa`.
#
# Clean-room (no Biopython / EMBOSS / parasail / SeqAn import).
# Identical recurrence + identical traceback tie-break (diag > up >
# left) as the .hexa kernel, so the parity test asserts bit-exact
# integer equality across both sides.
#
# Spec source — Needleman SB, Wunsch CD (1970), J. Mol. Biol. 48(3):
# 443-453; Durbin et al. (1998) §2.3.

from typing import List, Sequence, Tuple

GAP = -1  # gap sentinel — must match `gap_symbol()` in the .hexa kernel.


def fill_dp(
    a: Sequence[int],
    b: Sequence[int],
    match_s: int,
    mismatch_s: int,
    gap_s: int,
) -> List[List[int]]:
    m = len(a)
    n = len(b)
    s = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(1, m + 1):
        s[i][0] = i * gap_s
    for j in range(1, n + 1):
        s[0][j] = j * gap_s
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            sym = match_s if a[i - 1] == b[j - 1] else mismatch_s
            diag = s[i - 1][j - 1] + sym
            up = s[i - 1][j] + gap_s
            left = s[i][j - 1] + gap_s
            s[i][j] = max(diag, up, left)
    return s


def score_only(a, b, match_s, mismatch_s, gap_s):
    s = fill_dp(a, b, match_s, mismatch_s, gap_s)
    return s[len(a)][len(b)]


def align(a, b, match_s, mismatch_s, gap_s):
    """Return (score, a_aligned, b_aligned) with GAP=-1 sentinels.

    Tie-break in traceback: diagonal > up > left.
    """
    s = fill_dp(a, b, match_s, mismatch_s, gap_s)
    m = len(a)
    n = len(b)
    score = s[m][n]
    a_rev: List[int] = []
    b_rev: List[int] = []
    i, j = m, n
    while i > 0 or j > 0:
        cur = s[i][j]
        took = False
        if i > 0 and j > 0 and not took:
            sym = match_s if a[i - 1] == b[j - 1] else mismatch_s
            if cur == s[i - 1][j - 1] + sym:
                a_rev.append(a[i - 1])
                b_rev.append(b[j - 1])
                i -= 1
                j -= 1
                took = True
        if i > 0 and not took:
            if cur == s[i - 1][j] + gap_s:
                a_rev.append(a[i - 1])
                b_rev.append(GAP)
                i -= 1
                took = True
        if j > 0 and not took:
            if cur == s[i][j - 1] + gap_s:
                a_rev.append(GAP)
                b_rev.append(b[j - 1])
                j -= 1
                took = True
        if not took:
            # Should be unreachable by construction.
            break
    return score, list(reversed(a_rev)), list(reversed(b_rev))


def encode(seq: str) -> List[int]:
    """ASCII-based encoding — kernel is alphabet-agnostic, so we can
    pass ASCII codes directly. Equality is preserved."""
    return [ord(c) for c in seq]


def _print_case(name, a_str, b_str, match_s, mismatch_s, gap_s):
    a = encode(a_str)
    b = encode(b_str)
    score, a_aln, b_aln = align(a, b, match_s, mismatch_s, gap_s)
    print(f"--- {name}")
    print(f"  a = {a_str!r} -> {a}")
    print(f"  b = {b_str!r} -> {b}")
    print(f"  scoring (m, mm, g) = ({match_s}, {mismatch_s}, {gap_s})")
    print(f"  score = {score}")
    print(f"  a_aln = {a_aln}")
    print(f"  b_aln = {b_aln}")


if __name__ == "__main__":
    # Case 1: Durbin §2.3 worked-example sequences (HEAGAWGHEE / PAWHEAE)
    #   with the textbook's simpler (+1, -1, -2) scoring instead of
    #   BLOSUM50 + gap=-8. The Fig 2.5 score (+1) needs the full
    #   substitution matrix — a follow-on pilot. Here we just lock in
    #   that the kernel matches an integer-arithmetic transliteration
    #   under the same simpler scoring.
    _print_case("Durbin 2.5 (simple +1/-1/-2)",
                "HEAGAWGHEE", "PAWHEAE", 1, -1, -2)

    # Case 2: textbook DNA — GATTACA vs GCATGCU.
    #   match=+1, mismatch=-1, gap=-1 (Wikipedia NW worked example).
    _print_case("DNA classic", "GATTACA", "GCATGCU", 1, -1, -1)

    # Case 3: identical short sequences — score = len * match.
    _print_case("identity", "ACGT", "ACGT", 2, -1, -2)

    # Case 4: one empty — pure gap penalty.
    _print_case("empty vs ACGT", "", "ACGT", 1, -1, -2)

    # Case 5: completely different short — drives mismatch path.
    _print_case("disjoint short", "AAAA", "TTTT", 1, -1, -1)

    # Case 6: small biology textbook DNA pair, +5 match / -3 mm / -4 gap.
    _print_case("DNA 5/-3/-4", "ACACACTA", "AGCACACA", 5, -3, -4)

    # Case 7: 2-char vs 2-char with a single insertion.
    _print_case("AT vs ACT", "AT", "ACT", 1, -1, -2)
