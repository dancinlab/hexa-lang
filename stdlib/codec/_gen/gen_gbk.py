#!/usr/bin/env python3
"""Generate stdlib/codec/gbk_table.gen.hexa from CPython's authoritative `gbk`
codec (GB2312 superset). Records the two-byte glyphs (codepoint -> b0,b1) as a
flat hex blob of 8-hex-char records `CCCCBBBB`. Run: python3 gen_gbk.py > ../gbk_table.gen.hexa
"""
import sys

def main() -> None:
    entries = []
    for cp in range(0x80, 0x10000):
        try:
            b = chr(cp).encode("gbk")
        except Exception:
            continue
        if len(b) == 2:
            entries.append((cp, b[0], b[1]))
    blob = "".join("%04x%02x%02x" % (cp, b0, b1) for cp, b0, b1 in entries)
    out = sys.stdout
    out.write("// AUTO-GENERATED — do not edit. Regenerate via stdlib/codec/_gen/gen_gbk.py\n")
    out.write("// Source of truth: CPython codecs `gbk` (GBK / GB2312 superset / Unicode mapping).\n")
    out.write("// Format: GBK_BLOB = concat of 8-hex-char records `CCCCBBBB` = (codepoint u16)(byte0)(byte1).\n\n")
    out.write("pub let GBK_COUNT: int = %d\n" % len(entries))
    out.write('pub let GBK_BLOB: string = "%s"\n' % blob)

if __name__ == "__main__":
    main()
