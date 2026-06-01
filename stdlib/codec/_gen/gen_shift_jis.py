#!/usr/bin/env python3
"""Generate stdlib/codec/shift_jis_table.gen.hexa from CPython's authoritative
`shift_jis` codec. Records two-byte glyphs AND single-byte half-width katakana
(0xA1-0xDF) as a flat hex blob of 10-hex-char records `CCCCNNBBBB` =
(cp u16)(nbytes)(byte0)(byte1). Single-byte <0x80 aliases are skipped (ASCII).
Run: python3 gen_shift_jis.py > ../shift_jis_table.gen.hexa
"""
import sys

def main() -> None:
    entries = []
    for cp in range(0x80, 0x10000):
        try:
            b = chr(cp).encode("shift_jis")
        except Exception:
            continue
        if len(b) == 2:
            entries.append((cp, 2, b[0], b[1]))
        elif len(b) == 1 and b[0] >= 0x80:
            entries.append((cp, 1, b[0], 0))
    blob = "".join("%04x%02x%02x%02x" % (cp, n, b0, b1) for cp, n, b0, b1 in entries)
    out = sys.stdout
    out.write("// AUTO-GENERATED — do not edit. Regenerate via stdlib/codec/_gen/gen_shift_jis.py\n")
    out.write("// Source of truth: CPython codecs `shift_jis` (Shift-JIS / Unicode mapping).\n")
    out.write("// Format: SJIS_BLOB = concat of 10-hex-char records `CCCCNNBBBB` = (cp u16)(nbytes)(byte0)(byte1).\n")
    out.write("//         nbytes=1 -> single-byte half-width katakana (byte0, 0xA1-0xDF); nbytes=2 -> (byte0,byte1).\n\n")
    out.write("pub let SJIS_COUNT: int = %d\n" % len(entries))
    out.write('pub let SJIS_BLOB: string = "%s"\n' % blob)

if __name__ == "__main__":
    main()
