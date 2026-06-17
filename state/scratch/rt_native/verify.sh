#!/bin/bash
# RT-NATIVE Z3 byte-eq harness: C ref vs pure-.hexa arena port.
# PASS iff clang(arena_ref.c) output == hexa(arena_port.hexa) output, byte-identical.
set -euo pipefail
cd "$(dirname "$0")"

HEXA="${HEXA:-$HOME/.hx/bin/hexa}"

clang -O2 -o arena_ref arena_ref.c
./arena_ref > c_out.txt
"$HEXA" run arena_port.hexa > hexa_out.txt

if diff -q c_out.txt hexa_out.txt >/dev/null; then
    echo "PASS — byte-identical"
    shasum -a256 c_out.txt hexa_out.txt
    exit 0
else
    echo "FAIL — outputs differ:"
    diff c_out.txt hexa_out.txt
    exit 1
fi
