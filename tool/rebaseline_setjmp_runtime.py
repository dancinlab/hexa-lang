#!/usr/bin/env python3
# tool/rebaseline_setjmp_runtime.py
#
# RFC061 §M8 ∅−8 setjmp/longjmp frozen re-baseline — idempotent transformer.
#
# Converts the frozen runtime.c (151c52c8 image, restored by
# tool/restore_frozen_seeds) linux-branch setjmp/longjmp block from the
# glibc-coupled form:
#
#     #include <setjmp.h>
#     #define hxlcl_setjmp(buf) setjmp(*(jmp_buf *)(buf))
#     static void __attribute__((noinline, noreturn)) hxlcl_longjmp(void *buf, int val) {
#         longjmp(*(jmp_buf *)buf, val ? val : 1);
#     }
#
# into a hexa-native musl-layout x86_64 pair (real global symbols, no glibc
# PTR_MANGLE, 64-B jmp_buf), guarded `#if defined(__x86_64__)` so arm64-linux
# (and any other linux arch) keeps the unchanged libc-macro + glibc-longjmp
# path — byteeq-NEUTRAL on those targets.
#
# This is the SAVE/RESTORE-co-owned half of the re-baseline; the SAVE half is
# compiler/codegen/x86_64_linux.hexa try_setjmp `call hxlcl_setjmp`. Both halves
# use the SAME 64-B musl layout: [0]=rbx [8]=rbp [16]=r12 [24]=r13 [32]=r14
# [40]=r15 [48]=rsp [56]=rip. .text is byte-id to musl
# src/setjmp/x86_64/{setjmp,longjmp}.S (objdump-verified, #4218).
#
# Idempotent: a second run is a no-op. Exit 0 = transformed or already-native;
# exit 2 = neither the old block nor the native marker found (unexpected runtime).
#
# Usage:  python3 tool/rebaseline_setjmp_runtime.py [self/runtime.c]
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else "self/runtime.c"

OLD = (
    "#include <setjmp.h>\n"
    "#define hxlcl_setjmp(buf) setjmp(*(jmp_buf *)(buf))\n"
    "static void __attribute__((noinline, noreturn)) hxlcl_longjmp(void *buf, int val) {\n"
    "    longjmp(*(jmp_buf *)buf, val ? val : 1);\n"
    "}\n"
)

NEW = (
    "#include <setjmp.h>\n"
    "#if defined(__x86_64__)\n"
    "// RFC061 §M8 re-baseline (ING#29 ∅−8): native musl-layout x86_64 setjmp/\n"
    "// longjmp pair. Real GLOBAL symbols (no longer a libc-setjmp macro + a\n"
    "// static glibc longjmp) so the linux-x86_64 codegen try-block SAVE\n"
    "// (`call hxlcl_setjmp`, compiler/codegen/x86_64_linux.hexa) and the\n"
    "// hexa_throw RESTORE (`call hxlcl_longjmp`) BOTH use the SAME 64-B musl\n"
    "// jmp_buf ([0]=rbx [8]=rbp [16]=r12 [24]=r13 [32]=r14 [40]=r15 [48]=rsp\n"
    "// [56]=rip), with NO glibc PTR_MANGLE. .text is byte-id to musl\n"
    "// src/setjmp/x86_64/{setjmp,longjmp}.S (objdump-verified, #4218). Pairs\n"
    "// with the darwin-arm64 native pair above; dissolves the last glibc\n"
    "// setjmp/longjmp dependency on linux-x86_64 (the M3 mixed-ABI SEGV wall).\n"
    "__asm__(\n"
    "\".text\\n\"\n"
    "\".globl hxlcl_setjmp\\n\"\n"
    "\".type hxlcl_setjmp,@function\\n\"\n"
    "\"hxlcl_setjmp:\\n\"\n"
    "\"  movq %rbx, (%rdi)\\n\"\n"
    "\"  movq %rbp, 8(%rdi)\\n\"\n"
    "\"  movq %r12, 16(%rdi)\\n\"\n"
    "\"  movq %r13, 24(%rdi)\\n\"\n"
    "\"  movq %r14, 32(%rdi)\\n\"\n"
    "\"  movq %r15, 40(%rdi)\\n\"\n"
    "\"  leaq 8(%rsp), %rdx\\n\"\n"
    "\"  movq %rdx, 48(%rdi)\\n\"\n"
    "\"  movq (%rsp), %rdx\\n\"\n"
    "\"  movq %rdx, 56(%rdi)\\n\"\n"
    "\"  xorl %eax, %eax\\n\"\n"
    "\"  ret\\n\"\n"
    "\".globl hxlcl_longjmp\\n\"\n"
    "\".type hxlcl_longjmp,@function\\n\"\n"
    "\"hxlcl_longjmp:\\n\"\n"
    "\"  movl %esi, %eax\\n\"\n"
    "\"  testl %eax, %eax\\n\"\n"
    "\"  jnz 1f\\n\"\n"
    "\"  incl %eax\\n\"\n"
    "\"1:\\n\"\n"
    "\"  movq (%rdi), %rbx\\n\"\n"
    "\"  movq 8(%rdi), %rbp\\n\"\n"
    "\"  movq 16(%rdi), %r12\\n\"\n"
    "\"  movq 24(%rdi), %r13\\n\"\n"
    "\"  movq 32(%rdi), %r14\\n\"\n"
    "\"  movq 40(%rdi), %r15\\n\"\n"
    "\"  movq 48(%rdi), %rsp\\n\"\n"
    "\"  movq 56(%rdi), %rdx\\n\"\n"
    "\"  jmp *%rdx\\n\"\n"
    ");\n"
    "int  hxlcl_setjmp(void *buf) __attribute__((returns_twice));\n"
    "void hxlcl_longjmp(void *buf, int val) __attribute__((noreturn));\n"
    "#else\n"
    "// arm64-linux (and any other non-x86_64 linux arch): keep the libc-setjmp\n"
    "// macro + glibc longjmp wrapper unchanged — byteeq-neutral on those targets.\n"
    "#define hxlcl_setjmp(buf) setjmp(*(jmp_buf *)(buf))\n"
    "static void __attribute__((noinline, noreturn)) hxlcl_longjmp(void *buf, int val) {\n"
    "    longjmp(*(jmp_buf *)buf, val ? val : 1);\n"
    "}\n"
    "#endif\n"
)

MARKER = ".globl hxlcl_setjmp\\n"  # ASCII substring unique to NEW's asm block

def main():
    with open(PATH, "r") as f:
        src = f.read()
    if MARKER in src:
        print("[rebaseline_setjmp_runtime] already native — no-op (%s)" % PATH)
        return 0
    if OLD not in src:
        sys.stderr.write(
            "[rebaseline_setjmp_runtime] FATAL: glibc setjmp/longjmp block not found in %s\n"
            "  (unexpected runtime image — refusing to guess)\n" % PATH)
        return 2
    n = src.count(OLD)
    if n != 1:
        sys.stderr.write(
            "[rebaseline_setjmp_runtime] FATAL: expected exactly 1 glibc block, found %d in %s\n"
            % (n, PATH))
        return 2
    src = src.replace(OLD, NEW)
    with open(PATH, "w") as f:
        f.write(src)
    print("[rebaseline_setjmp_runtime] transformed %s -> native musl x86_64 setjmp/longjmp pair" % PATH)
    return 0

if __name__ == "__main__":
    sys.exit(main())
