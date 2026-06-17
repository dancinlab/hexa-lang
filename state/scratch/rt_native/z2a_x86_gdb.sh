#!/bin/bash
# Debug the x86_64 aprime_z2a_lin segfault: gdb backtrace at crash.
cd ~/hexa-lang
which gdb >/dev/null 2>&1 || { echo "no gdb; installing skipped — using core/dmesg"; }
[ -x build/aprime_z2a_lin ] || { echo "aprime_z2a_lin MISSING — rebuild needed"; exit 1; }
echo 'fn main() -> int { return 6*7 }' > /tmp/smk.hexa
echo "=== run under gdb, backtrace at SIGSEGV ==="
if which gdb >/dev/null 2>&1; then
  gdb -q -batch \
    -ex "set pagination off" \
    -ex "run _drv.hexa --emit=asm --target=x86_64-linux-gnu -o /tmp/smk.s /tmp/smk.hexa" \
    -ex "bt 12" \
    -ex "info registers rip rsp rdi rsi" \
    -ex "x/4i \$rip" \
    ./build/aprime_z2a_lin 2>&1 | grep -vE '^\[|Reading|warning: |No such|Missing sep' | head -40
else
  echo "no gdb available"
fi
echo "=== which rt_str_* + .rodata reloc style in the seed (RIP-rel vs absolute)? ==="
grep -nE 'rt_str_split|\.LC|lea|movabs|rip|\.rodata|\.quad' /tmp/rt_hi.s 2>/dev/null | grep -iE 'lea|rip|movabs|\.LC[0-9]' | head -12
echo "GDB_DONE"
