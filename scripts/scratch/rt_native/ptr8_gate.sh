#!/usr/bin/env bash
# RT-NATIVE-ZEROC M4 PTR8 — `__hx_ptr_store8` / `__hx_ptr_load8` parity gate.
#
# Completes M2's raw-mem set (M1 landed ptr_load/store 64/32; the 8-bit byte
# ops were the one gap, needed for `hexa_strbuf_dup_n`'s byte-write in B3).
# Two authorities (c2: never self-judged):
#   (A) ENCODING ground-truth — assemble the byte forms the leaves emit with
#       GNU `as` and byte-match objdump. arm64: `strb w5,[x1]` / `ldrb w1,[x1]`.
#       x86_64: `mov byte ptr [r10], sil` / `movzx r10, byte ptr [r10]`.
#   (B) SEMANTIC ground-truth — emit m4_x86_leaf_ptr8.hexa through the native
#       x86_64 emitter, cross-assemble (GNU as), link the C runtime, RUN on real
#       x86_64 hardware, assert exit=7. Specifically gates ZERO-EXTEND: a stored
#       0xFF loads back as 255 (not -1) and 0x80 as 128 (not -128).
#
# CI selfhost-byteeq-real (gen3≡gen4) is the final authority on the fixpoint.
#
# Usage:  bash scripts/scratch/rt_native/ptr8_gate.sh [APRIME]
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
AP="${1:-build/aprime_m4}"
RT_O="${RT_O:-build/runtime.o}"
RT_HI="${RT_HI:-build/rt_hi_native.o}"

fail=0
SCRATCH="scripts/scratch/rt_native"

echo "── (A) ENCODING ground-truth (GNU as ↔ objdump byte-match) ──"

# ---- x86_64 byte store/load encodings ----
cat > /tmp/ptr8_x86_probe.s <<'EOF'
.intel_syntax noprefix
.text
.globl probe
probe:
    mov byte ptr [r10], sil
    movzx r10, byte ptr [r10]
    ret
EOF
if as --64 -o /tmp/ptr8_x86_probe.o /tmp/ptr8_x86_probe.s 2>/tmp/ptr8_x86_as.err; then
    DUMP="$(objdump -d -M intel /tmp/ptr8_x86_probe.o)"
    check_enc() { # objdump-grep expected-byte-head
        local hit
        hit="$(echo "$DUMP" | grep -iE "$1" | head -1)"
        if echo "$hit" | grep -qiE "\b$2\b"; then echo "  ✓ x86 $1  [$2]"
        else echo "  ✗ x86 ENC MISMATCH: $1 want=$2 got=[$hit]"; fail=1; fi
    }
    # store byte: mov byte ptr [r10], sil  → REX.B(41) 88 /r, modrm 32
    check_enc "mov +BYTE PTR \[r10\],sil" "41 88 32"
    # load byte zero-ext: movzx r10, byte ptr [r10] → REX.WRB(4d) 0f b6 12
    check_enc "movzx +r10,BYTE PTR \[r10\]" "4d 0f b6 12"
else
    echo "  x86 as: FAIL"; cat /tmp/ptr8_x86_as.err; fail=1
fi

# ---- arm64 byte store/load encodings (if an arm64 assembler is present) ----
AARCH_AS=""
for cand in aarch64-linux-gnu-as aarch64-none-elf-as; do
    command -v "$cand" >/dev/null 2>&1 && { AARCH_AS="$cand"; break; }
done
# clang can target arm64 too (macOS / cross).
if [ -z "$AARCH_AS" ] && command -v clang >/dev/null 2>&1; then AARCH_AS="clang-arm64"; fi
if [ -n "$AARCH_AS" ]; then
    cat > /tmp/ptr8_arm_probe.s <<'EOF'
.text
.globl probe
probe:
    strb w5, [x1]
    ldrb w1, [x1]
    ret
EOF
    OK=0
    if [ "$AARCH_AS" = "clang-arm64" ]; then
        clang -c -target arm64-apple-darwin -o /tmp/ptr8_arm_probe.o /tmp/ptr8_arm_probe.s 2>/tmp/ptr8_arm.err && OK=1
    else
        "$AARCH_AS" -o /tmp/ptr8_arm_probe.o /tmp/ptr8_arm_probe.s 2>/tmp/ptr8_arm.err && OK=1
    fi
    if [ "$OK" = 1 ]; then
        ADUMP="$(objdump -d /tmp/ptr8_arm_probe.o 2>/dev/null || llvm-objdump -d /tmp/ptr8_arm_probe.o 2>/dev/null)"
        # strb w5,[x1] = 0x39000025 ; ldrb w1,[x1] = 0x39400021 (little-endian bytes 25 00 00 39 / 21 00 40 39)
        achk() { if echo "$ADUMP" | grep -qiE "$1"; then echo "  ✓ arm64 $2"; else echo "  ✗ arm64 MISSING $2 [$1]"; fail=1; fi; }
        achk "39000025|25 00 00 39" "strb w5,[x1]"
        achk "39400021|21 00 40 39" "ldrb w1,[x1]"
    else
        echo "  arm64 as: FAIL"; cat /tmp/ptr8_arm.err; fail=1
    fi
else
    echo "  (arm64 assembler absent — strb/ldrb encoding skipped; mirrors __hx_str_byte ldrb, proven in M1)"
fi

echo "── (B) SEMANTIC ground-truth (emit → as → link → run, assert exit=7) ──"
if [ ! -x "$AP" ]; then
    echo "  (no native x86_64 aprime at $AP — semantic run skipped; build via tool/build_aprime.sh)"
else
    name=ptr8
    "$AP" "$SCRATCH/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o /tmp/${name}.s "$SCRATCH/m4_x86_leaf_ptr8.hexa" 2>/tmp/${name}.emit
    erc=$?
    if [ $erc -ne 0 ]; then echo "  ✗ ptr8: emit rc=$erc"; grep -iE 'error|ENCODE-MISS' /tmp/${name}.emit | head; fail=1
    elif ! as --64 -o /tmp/${name}.o /tmp/${name}.s 2>/tmp/${name}.as; then
        echo "  ✗ ptr8: as failed"; grep error: /tmp/${name}.as | head; fail=1
    elif ! gcc -no-pie -o /tmp/${name} /tmp/${name}.o "$RT_O" "$RT_HI" -lm 2>/tmp/${name}.ld; then
        echo "  ✗ ptr8: link failed"; head -3 /tmp/${name}.ld; fail=1
    else
        /tmp/${name}; got=$?
        if [ "$got" = 7 ]; then echo "  ✓ ptr8: exit=7 (byte round-trip + zero-extend EXACT)"; else echo "  ✗ ptr8: exit=$got (want 7 — zero-extend/round-trip FAIL)"; fail=1; fi
    fi
fi

echo "──"
if [ $fail -eq 0 ]; then echo "M4 PTR8 GATE: PASS"; else echo "M4 PTR8 GATE: FAIL"; fi
exit $fail
