#!/bin/sh
# tool/verify_hxlcl_setjmp_roundtrip.sh
#
# literal-∅ feature C · setjmp/longjmp RUNG1 verification (linux-x86_64).
#
# 1. emit the native hxlcl_setjmp/hxlcl_longjmp .o via the hexa emitter
# 2. reference-match: assemble the verbatim musl setjmp.S/longjmp.S and prove the
#    emitted .text bytes are byte-identical to the assembler's (.o .text dump)
# 3. round-trip: link the C harness against ONLY the emitted .o, run, expect PASS
#
# Usage:  HEXA=<hexa-binary> sh tool/verify_hxlcl_setjmp_roundtrip.sh
set -eu

HEXA="${HEXA:-hexa}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$(mktemp -d)}"
EMITTER="$ROOT/test/native_build/emit_hxlcl_setjmp_elf_o.hexa"
HARNESS="$ROOT/test/native_build/hxlcl_setjmp_roundtrip.c"
OBJ="$WORK/hxlcl_setjmp_elf.o"

echo "== [1/3] emit native hxlcl_setjmp/longjmp .o =="
HEXA_HXLCL_SETJMP_O="$OBJ" "$HEXA" run "$EMITTER"
test -f "$OBJ" || { echo "FAIL: emitter produced no .o"; exit 1; }
echo "  emitted: $OBJ ($(wc -c < "$OBJ") bytes)"

echo "== [2/3] reference-match against musl setjmp.S/longjmp.S =="
cat > "$WORK/musl_ref.s" <<'EOF'
.text
.global hxlcl_setjmp
hxlcl_setjmp:
	mov %rbx,(%rdi)
	mov %rbp,8(%rdi)
	mov %r12,16(%rdi)
	mov %r13,24(%rdi)
	mov %r14,32(%rdi)
	mov %r15,40(%rdi)
	lea 8(%rsp),%rdx
	mov %rdx,48(%rdi)
	mov (%rsp),%rdx
	mov %rdx,56(%rdi)
	xor %eax,%eax
	ret
.global hxlcl_longjmp
hxlcl_longjmp:
	mov %rsi,%rax
	test %rax,%rax
	jnz 1f
	inc %eax
1:
	mov (%rdi),%rbx
	mov 8(%rdi),%rbp
	mov 16(%rdi),%r12
	mov 24(%rdi),%r13
	mov 32(%rdi),%r14
	mov 40(%rdi),%r15
	mov 48(%rdi),%rsp
	mov 56(%rdi),%rdx
	jmp *%rdx
EOF
cc -c "$WORK/musl_ref.s" -o "$WORK/musl_ref.o"
# extract .text from both objects and compare byte-for-byte
objcopy -O binary --only-section=.text "$WORK/musl_ref.o" "$WORK/ref.text.bin"
objcopy -O binary --only-section=.text "$OBJ"            "$WORK/emit.text.bin"
echo "  musl .text : $(wc -c < "$WORK/ref.text.bin") bytes  $(sha256sum < "$WORK/ref.text.bin" | cut -c1-16)"
echo "  emit .text : $(wc -c < "$WORK/emit.text.bin") bytes  $(sha256sum < "$WORK/emit.text.bin" | cut -c1-16)"
if cmp -s "$WORK/ref.text.bin" "$WORK/emit.text.bin"; then
    echo "  REFERENCE-MATCH OK: emitted .text == musl assembler .text (byte-identical)"
else
    echo "FAIL: emitted .text differs from musl reference"; cmp "$WORK/ref.text.bin" "$WORK/emit.text.bin" || true; exit 1
fi
# symbols present
nm "$OBJ" | grep -q 'T hxlcl_setjmp'  || { echo "FAIL: hxlcl_setjmp not a defined global"; exit 1; }
nm "$OBJ" | grep -q 'T hxlcl_longjmp' || { echo "FAIL: hxlcl_longjmp not a defined global"; exit 1; }
echo "  symbols: hxlcl_setjmp + hxlcl_longjmp both GLOBAL FUNC OK"

echo "== [3/3] non-local-return round-trip =="
cc -O0 "$HARNESS" "$OBJ" -o "$WORK/rt"
"$WORK/rt"
echo "== verify_hxlcl_setjmp_roundtrip: ALL GREEN =="
