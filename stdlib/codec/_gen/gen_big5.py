#!/usr/bin/env python3
"""Generate stdlib/codec/big5_table.gen.hexa from CPython's authoritative `big5`
codec (traditional Chinese). Records the two-byte glyphs (codepoint -> b0,b1) as
a flat hex blob of 8-hex-char records `CCCCBBBB`. Run: python3 gen_big5.py > ../big5_table.gen.hexa
"""
import sys

def main() -> None:
    entries = []
    for cp in range(0x80, 0x10000):
        try:
            b = chr(cp).encode("big5")
        except Exception:
            continue
        if len(b) == 2:
            entries.append((cp, b[0], b[1]))
    blob = "".join("%04x%02x%02x" % (cp, b0, b1) for cp, b0, b1 in entries)
    out = sys.stdout
    out.write("// AUTO-GENERATED — do not edit. Regenerate via stdlib/codec/_gen/gen_big5.py\n")
    out.write("// Source of truth: CPython codecs `big5` (Big5 traditional Chinese / Unicode mapping).\n")
    out.write("// Format: BIG5_BLOB = concat of 8-hex-char records `CCCCBBBB` = (codepoint u16)(byte0)(byte1).\n\n")
    out.write("pub let BIG5_COUNT: int = %d\n" % len(entries))
    out.write('pub let BIG5_BLOB: string = "%s"\n' % blob)

if __name__ == "__main__":
    main()
