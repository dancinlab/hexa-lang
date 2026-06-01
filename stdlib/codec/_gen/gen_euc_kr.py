#!/usr/bin/env python3
"""Generate stdlib/codec/euc_kr_table.gen.hexa from CPython's authoritative
`euc-kr` codec. Records only the two-byte KS X 1001 glyphs (codepoint -> b0,b1)
as a flat hex blob of 8-hex-char records `CCCCBBBB`. Hangul outside the 2350
precomposed set (CPython's 8-byte 0xA4 composition) is intentionally excluded —
see euc_kr.hexa SCOPE note. Run: python3 gen_euc_kr.py > ../euc_kr_table.gen.hexa
"""
import sys

def main() -> None:
    entries = []
    for cp in range(0x80, 0x10000):
        try:
            b = chr(cp).encode("euc-kr")
        except Exception:
            continue
        if len(b) == 2:
            entries.append((cp, b[0], b[1]))
    blob = "".join("%04x%02x%02x" % (cp, b0, b1) for cp, b0, b1 in entries)
    out = sys.stdout
    out.write("// AUTO-GENERATED — do not edit. Regenerate via stdlib/codec/_gen/gen_euc_kr.py\n")
    out.write("// Source of truth: CPython codecs `euc-kr` (KS X 1001 / Unicode mapping).\n")
    out.write("// Format: EUCKR_BLOB = concat of 8-hex-char records `CCCCBBBB` = (codepoint u16)(byte0)(byte1).\n\n")
    out.write("pub let EUCKR_COUNT: int = %d\n" % len(entries))
    out.write('pub let EUCKR_BLOB: string = "%s"\n' % blob)

if __name__ == "__main__":
    main()
