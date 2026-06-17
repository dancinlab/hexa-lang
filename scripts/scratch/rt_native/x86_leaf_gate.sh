#!/usr/bin/env bash
# RT-NATIVE-ZEROC M1 — x86_64 `__hx_*` leaf-intrinsic parity gate.
#
# Verifies the 25 leaf intrinsics ported to compiler/codegen/x86_64_linux.hexa
# against TWO authorities:
#   (A) ENCODING ground-truth — assemble each leaf's instruction forms with GNU
#       `as` and diff the bytes against objdump (c2: never self-judged). The
#       canonical forms below were captured from `as`/`objdump` on aiden.
#   (B) SEMANTIC ground-truth — compile three .hexa test programs through the
#       native x86_64 emitter (aprime --emit=asm --target=x86_64-linux-gnu),
#       cross-assemble with GNU `as`, link with the C runtime, RUN on real
#       x86_64 hardware, and assert the exit code (the leaves computed the
#       right value end-to-end).
#
# This is the EMIT+RUN fence; CI selfhost-byteeq-real (gen3≡gen4) is the final
# authority on the self-host fixpoint.
#
# Usage:  bash scripts/scratch/rt_native/x86_leaf_gate.sh [APRIME]
#   APRIME  native x86_64 aprime binary (default build/aprime_m1)
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
AP="${1:-build/aprime_m1}"
RT_O="${RT_O:-build/runtime.o}"
RT_HI="${RT_HI:-build/rt_hi_native.o}"
[ -x "$AP" ] || { echo "FAIL: build $AP first (tool/build_aprime.sh -o $AP)"; exit 1; }

fail=0
SCRATCH="scripts/scratch/rt_native"

echo "── (A) ENCODING ground-truth (GNU as ↔ objdump byte-match) ──"
# Each line: the exact GAS Intel form the leaf emits → expected objdump byte head.
cat > /tmp/x86leaf_probe.s <<'EOF'
.intel_syntax noprefix
.text
.globl probe
probe:
    cmp r10, r11
    sete al
    setne al
    setl al
    setle al
    setg al
    setge al
    movzx r13, al
    add r10, r11
    sub r10, r11
    imul r10, r11
    movq xmm0, r10
    movq xmm1, r11
    addsd xmm0, xmm1
    subsd xmm0, xmm1
    mulsd xmm0, xmm1
    divsd xmm0, xmm1
    movq r10, xmm0
    comisd xmm1, xmm0
    seta al
    setae al
    cvtsi2sd xmm0, r10
    cmove r10, r11
    movzx r10, byte ptr [r10]
    mov r10d, dword ptr [r10 + 8]
    mov qword ptr [r10], rsi
    mov r10, qword ptr [r10]
    mov dword ptr [r10], esi
    mov r10d, dword ptr [r10]
    syscall
    ret
EOF
if as --64 -o /tmp/x86leaf_probe.o /tmp/x86leaf_probe.s 2>/tmp/x86leaf_as.err; then
    DUMP="$(objdump -d -M intel /tmp/x86leaf_probe.o)"
    n=$(echo "$DUMP" | grep -cE '^\s+[0-9a-f]+:')
    echo "  as: OK ($n instructions encoded by GNU as)"
    # Load-bearing encodings vs the captured GNU-as/objdump ground-truth bytes.
    check_enc() { # objdump-mnemonic expected-byte-head
        local hit
        hit="$(echo "$DUMP" | grep -iE "$1" | head -1)"
        if echo "$hit" | grep -qiE "\b$2\b"; then echo "  ✓ $1  [$2]"
        else echo "  ✗ ENC MISMATCH: $1 want=$2 got=[$hit]"; fail=1; fi
    }
    # Ground-truth bytes are register-specific (REX.B/REX.W reflect the operand
    # register); these match the EXACT forms the leaves emit (r10/r11/xmm).
    check_enc "comisd xmm1,xmm0"  "66 0f 2f c8"
    check_enc "seta   al"         "0f 97 c0"
    check_enc "setae  al"         "0f 93 c0"
    check_enc "cvtsi2sd xmm0,r10" "f2 49 0f 2a c2"
    check_enc "movq   xmm0,r10"   "66 49 0f 6e c2"
    check_enc "movzx  r10,BYTE"   "4d 0f b6 12"
    check_enc "syscall"           "0f 05"
else
    echo "  as: FAIL"; cat /tmp/x86leaf_as.err; fail=1
fi

echo "── (B) SEMANTIC ground-truth (emit → as → link → run, assert exit) ──"
link_run() { # hexa-file expected-exit label
    local src="$1" want="$2" name="$3"
    "$AP" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o /tmp/${name}.s "$src" 2>/tmp/${name}.emit
    local erc=$?
    if [ $erc -ne 0 ]; then echo "  ✗ $name: emit rc=$erc"; grep -iE 'error|ENCODE-MISS' /tmp/${name}.emit | head; fail=1; return; fi
    if ! as --64 -o /tmp/${name}.o /tmp/${name}.s 2>/tmp/${name}.as; then
        echo "  ✗ $name: as failed"; grep error: /tmp/${name}.as | head; fail=1; return; fi
    if ! gcc -no-pie -o /tmp/${name} /tmp/${name}.o "$RT_O" "$RT_HI" -lm 2>/tmp/${name}.ld; then
        echo "  ✗ $name: link failed"; head -3 /tmp/${name}.ld; fail=1; return; fi
    /tmp/${name}; local got=$?
    if [ "$got" = "$want" ]; then echo "  ✓ $name: exit=$got"; else echo "  ✗ $name: exit=$got (want $want)"; fail=1; fi
}
link_run "$SCRATCH/m1_x86_leaf_core.hexa"  16 core   # int/float cmp+arith+nz+tag+to_double
link_run "$SCRATCH/m1_x86_leaf_str.hexa"    3 str    # __hx_str_byte
link_run "$SCRATCH/m1_x86_leaf_arena.hexa"  5 arena  # syscall6 + ptr_store/load 64/32

echo "──"
if [ $fail -eq 0 ]; then echo "M1 x86 LEAF GATE: PASS"; else echo "M1 x86 LEAF GATE: FAIL"; fi
exit $fail
