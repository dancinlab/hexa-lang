#!/usr/bin/env python3
"""Generate stdlib/codec/unicode_normalize_table.gen.hexa from CPython's
authoritative `unicodedata` (UCD). Emits four blobs: canonical decomposition,
compatibility-only decomposition, non-zero combining classes, and canonical
composition pairs (derived via the CPython NFC oracle so composition exclusions
are baked in). Hangul syllables (U+AC00..U+D7A3) are EXCLUDED — handled by the
algorithmic L/V/T rules in unicode_normalize.hexa. Run:
  python3 gen_unicode_normalize.py > ../unicode_normalize_table.gen.hexa
"""
import sys
import unicodedata

SBASE, SCOUNT = 0xAC00, 11172

def is_hangul(cp: int) -> bool:
    return SBASE <= cp < SBASE + SCOUNT

def main() -> None:
    canon, compat, ccc = [], [], []
    for cp in range(0x80, 0x110000):
        if is_hangul(cp):
            continue
        ch = chr(cp)
        d = unicodedata.decomposition(ch)
        if d:
            parts = d.split()
            if parts[0].startswith("<"):
                compat.append((cp, [int(x, 16) for x in parts[1:]]))
            else:
                canon.append((cp, [int(x, 16) for x in parts]))
        c = unicodedata.combining(ch)
        if c:
            ccc.append((cp, c))
    compose = []
    for cp, cps in canon:
        if len(cps) == 2 and not is_hangul(cp):
            a, b = cps
            if unicodedata.normalize("NFC", chr(a) + chr(b)) == chr(cp):
                compose.append((a, b, cp))

    def vrec(lst):
        return "".join("%06x%02x" % (cp, len(cps)) + "".join("%06x" % c for c in cps) for cp, cps in lst)

    out = sys.stdout
    out.write("// AUTO-GENERATED — do not edit. Regenerate via stdlib/codec/_gen/gen_unicode_normalize.py\n")
    out.write("// Source of truth: CPython `unicodedata` (UCD %s). Hangul syllables EXCLUDED (handled algorithmically).\n" % unicodedata.unidata_version)
    out.write("// CANON/COMPAT_BLOB: var records cp(6hex) count(2) (decomp cp 6hex)*. CCC: cp(6)+class(2). COMPOSE: a(6)b(6)cp(6).\n\n")
    out.write('pub let UN_CANON_BLOB: string = "%s"\n' % vrec(canon))
    out.write('pub let UN_COMPAT_BLOB: string = "%s"\n' % vrec(compat))
    out.write('pub let UN_CCC_BLOB: string = "%s"\n' % "".join("%06x%02x" % (cp, c) for cp, c in ccc))
    out.write('pub let UN_COMPOSE_BLOB: string = "%s"\n' % "".join("%06x%06x%06x" % (a, b, cp) for a, b, cp in compose))

if __name__ == "__main__":
    main()
