#!/usr/bin/env bash
# RT-NATIVE-ZEROC M4 ARRAY-R2 — `__hx_make_val(tag, payload)` round-trip gate.
#
# `__hx_make_val` is the symmetric WRITE-half of `__hx_tag`: it builds a
# {tag, payload} 16-byte HexaVal from two raw int64 words so a payload word
# loaded from an array slot can be re-stamped with its REAL element tag, WITHOUT
# the boxing-tag-loss of hexa_int/hexa_str/… (unblocks B4/B5 element returns).
#
# Two authorities (c2: never self-judged):
#   (A) ENCODING — make_val emits ONLY already-proven instruction forms (no new
#       opcode): arm64 = mov/ldp/stp (HexaVal pair I/O, proven by `__hx_tag`);
#       x86_64 = mov reg,reg + mov [rbp,off],reg (proven by `_x86_hv_store_leaf`/
#       `_x86_store_tag_reg`). So there is no fresh byte-form to ground-truth —
#       we assert the composed `mov r/r` + reg-tag-store bytes assemble identically
#       under GNU `as` ↔ objdump as a sanity check, NOT a novel encoding claim.
#   (B) SEMANTIC (DECISIVE) — emit m4_makeval_roundtrip.hexa through the native
#       x86_64 emitter, cross-assemble (GNU as), link the C runtime, RUN on real
#       x86_64 hardware, assert exit=8. The 8 = 4 tag-survives (STR/FLOAT/BOOL/INT
#       read back EXACT, NOT flattened to TAG_INT) + 4 payload-survives. A
#       make_val that ignored the tag word would drop the exit below 8.
#
# CI selfhost-byteeq-real (gen3≡gen4) is the final authority on the fixpoint.
#
# Usage:  bash scripts/scratch/rt_native/makeval_gate.sh [APRIME]
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
AP="${1:-build/aprime_m4}"
RT_O="${RT_O:-build/runtime.o}"
RT_HI="${RT_HI:-build/rt_hi_native.o}"

fail=0
SCRATCH="scripts/scratch/rt_native"

echo "── (A) ENCODING sanity (GNU as ↔ objdump byte-match — composed, no novel opcode) ──"
# The exact x86_64 forms `__hx_make_val` composes: payload→r10, tag→r11, then
# `mov dst, r10` (here a pool-reg example rbx) + `mov [rbp-OFF], r11` (tag-slot).
cat > /tmp/makeval_x86_probe.s <<'EOF'
.intel_syntax noprefix
.text
.globl probe
probe:
    mov rbx, r10
    mov QWORD PTR [rbp-8], r11
    ret
EOF
if as --64 -o /tmp/makeval_x86_probe.o /tmp/makeval_x86_probe.s 2>/tmp/makeval_x86_as.err; then
    DUMP="$(objdump -d -M intel /tmp/makeval_x86_probe.o)"
    check_enc() {
        local hit
        hit="$(echo "$DUMP" | grep -iE "$1" | head -1)"
        if echo "$hit" | grep -qiE "\b$2\b"; then echo "  ✓ x86 $1  [$2]"
        else echo "  ✗ x86 ENC MISMATCH: $1 want=$2 got=[$hit]"; fail=1; fi
    }
    # mov rbx, r10  → REX.WR(4c) 89 d3
    check_enc "mov +rbx,r10" "4c 89 d3"
    # mov [rbp-8], r11  → REX.WR(4c) 89 5d f8  (89 /r, modrm 5d, disp8 f8)
    check_enc "mov +QWORD PTR \[rbp-0x8\],r11" "4c 89 5d f8"
else
    echo "  x86 as: FAIL"; cat /tmp/makeval_x86_as.err; fail=1
fi

# arm64 composed forms: mov x0,x1 / mov x1,x3 / stp x0,x1,[...] — all proven by
# `__hx_tag`. Assemble for a byte sanity check when an arm64 assembler exists.
AARCH_AS=""
for cand in aarch64-linux-gnu-as aarch64-none-elf-as; do
    command -v "$cand" >/dev/null 2>&1 && { AARCH_AS="$cand"; break; }
done
if [ -z "$AARCH_AS" ] && command -v clang >/dev/null 2>&1; then AARCH_AS="clang-arm64"; fi
if [ -n "$AARCH_AS" ]; then
    cat > /tmp/makeval_arm_probe.s <<'EOF'
.text
.globl probe
probe:
    mov x0, x1
    mov x1, x3
    ret
EOF
    OK=0; AOBJDUMP="objdump"
    if [ "$AARCH_AS" = "clang-arm64" ]; then
        clang -c -target arm64-apple-darwin -o /tmp/makeval_arm_probe.o /tmp/makeval_arm_probe.s 2>/tmp/makeval_arm.err && OK=1
        command -v llvm-objdump >/dev/null 2>&1 && AOBJDUMP="llvm-objdump"
    else
        "$AARCH_AS" -o /tmp/makeval_arm_probe.o /tmp/makeval_arm_probe.s 2>/tmp/makeval_arm.err && OK=1
        command -v aarch64-linux-gnu-objdump >/dev/null 2>&1 && AOBJDUMP="aarch64-linux-gnu-objdump"
    fi
    if [ "$OK" = 1 ]; then
        ADUMP="$($AOBJDUMP -d /tmp/makeval_arm_probe.o 2>/dev/null)"
        # mov x0,x1 = aa0103e0 ; mov x1,x3 = aa0303e1 (alias of orr xD, xzr, xS)
        achk() { if echo "$ADUMP" | grep -qiE "$1"; then echo "  ✓ arm64 $2"; else echo "  ✗ arm64 MISSING $2 [$1]"; fail=1; fi; }
        achk "aa0103e0|e0 03 01 aa|mov +x0, *x1" "mov x0,x1"
        achk "aa0303e1|e1 03 03 aa|mov +x1, *x3" "mov x1,x3"
    else
        echo "  arm64 as: FAIL"; cat /tmp/makeval_arm.err; fail=1
    fi
else
    echo "  (arm64 assembler absent — mov x0,x1 / mov x1,x3 are mov aliases proven by __hx_tag; skipped)"
fi

echo "── (B) SEMANTIC ground-truth — DECISIVE (emit → as → link → run, assert exit=8) ──"
if [ ! -x "$AP" ]; then
    echo "  (no native x86_64 aprime at $AP — semantic run skipped; build via tool/build_aprime.sh)"
else
    name=makeval
    "$AP" "$SCRATCH/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o /tmp/${name}.s "$SCRATCH/m4_makeval_roundtrip.hexa" 2>/tmp/${name}.emit
    erc=$?
    if [ $erc -ne 0 ]; then echo "  ✗ makeval: emit rc=$erc"; grep -iE 'error|ENCODE-MISS' /tmp/${name}.emit | head; fail=1
    elif ! as --64 -o /tmp/${name}.o /tmp/${name}.s 2>/tmp/${name}.as; then
        echo "  ✗ makeval: as failed"; grep error: /tmp/${name}.as | head; fail=1
    elif ! gcc -no-pie -o /tmp/${name} /tmp/${name}.o "$RT_O" "$RT_HI" -lm 2>/tmp/${name}.ld; then
        echo "  ✗ makeval: link failed"; head -3 /tmp/${name}.ld; fail=1
    else
        /tmp/${name}; got=$?
        if [ "$got" = 8 ]; then echo "  ✓ makeval: exit=8 (TAG SURVIVES round-trip — STR/FLOAT/BOOL/INT not flattened + payload exact)"
        else echo "  ✗ makeval: exit=$got (want 8 — a flattened tag drops it below 8)"; fail=1; fi
    fi
fi

echo "──"
if [ $fail -eq 0 ]; then echo "M4 MAKEVAL GATE: PASS"; else echo "M4 MAKEVAL GATE: FAIL"; fi
exit $fail
