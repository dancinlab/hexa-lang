#!/usr/bin/env python3
# t56_make_bin.py — build a raw little-endian f32 .bin fixture for t56/t56b.
#   v[i] = (i % 1000) * 0.5 - 250.0   (exactly representable in f32, lossless)
# Usage: python3 t56_make_bin.py <out.bin> <n_floats>
# NO hexa boxing — the fixture build must not dominate the RSS under test.
import sys, struct
path, N = sys.argv[1], int(sys.argv[2])
with open(path, "wb") as f:
    buf = bytearray()
    for i in range(N):
        buf += struct.pack("<f", (i % 1000) * 0.5 - 250.0)
        if len(buf) >= (1 << 18):
            f.write(buf); buf = bytearray()
    if buf:
        f.write(buf)
print("built", path, N * 4, "bytes")
