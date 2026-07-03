// test/native_build/hxlcl_setjmp_roundtrip.c
//
// Non-local-return round-trip test for the hexa-emitted x86_64 native
// hxlcl_setjmp / hxlcl_longjmp pair (test/native_build/emit_hxlcl_setjmp_elf_o.hexa).
//
// Links ONLY against the emitted .o — no libc setjmp/longjmp involved. Proves
// the native pair saves/restores the musl jmp_buf and performs the non-local
// return with the correct value semantics:
//   (1) hxlcl_setjmp returns 0 on the direct call.
//   (2) hxlcl_longjmp(buf, 42) resumes hxlcl_setjmp returning 42.
//   (3) hxlcl_longjmp(buf, 0)  resumes hxlcl_setjmp returning 1 (POSIX coercion).
//
// Build (linux-x86_64):
//   <hexa> run test/native_build/emit_hxlcl_setjmp_elf_o.hexa   # -> hxlcl_setjmp_elf.o
//   cc -O0 hxlcl_setjmp_roundtrip.c hxlcl_setjmp_elf.o -o rt && ./rt

#include <stdio.h>

// returns_twice is required so the compiler reloads locals clobbered across the
// setjmp boundary — exactly how <setjmp.h> declares the libc primitive.
__attribute__((returns_twice)) extern int  hxlcl_setjmp(void *buf);
__attribute__((noreturn))      extern void hxlcl_longjmp(void *buf, int val);

// 128 bytes — the musl x86_64 jmp_buf is 64 bytes (8 slots); double for safety.
static long buf[16];

static int phase = 0;   // marked volatile-equivalent via static storage

int main(void) {
    int rc = hxlcl_setjmp(buf);
    if (phase == 0) {
        // direct (first) return — MUST be 0.
        if (rc != 0) { printf("FAIL: first setjmp returned %d, expected 0\n", rc); return 10; }
        phase = 1;
        hxlcl_longjmp(buf, 42);
        printf("FAIL: hxlcl_longjmp(buf,42) returned (should be noreturn)\n");
        return 11;
    } else if (phase == 1) {
        // resumed by longjmp(buf, 42) — MUST be 42.
        if (rc != 42) { printf("FAIL: longjmp(42) resumed setjmp with %d, expected 42\n", rc); return 12; }
        printf("OK  : longjmp(buf,42) -> setjmp returned 42 (non-local return)\n");
        phase = 2;
        hxlcl_longjmp(buf, 0);
        printf("FAIL: hxlcl_longjmp(buf,0) returned (should be noreturn)\n");
        return 13;
    } else {
        // resumed by longjmp(buf, 0) — POSIX coerces 0 -> 1.
        if (rc != 1) { printf("FAIL: longjmp(0) resumed setjmp with %d, expected 1\n", rc); return 14; }
        printf("OK  : longjmp(buf,0) -> setjmp returned 1 (POSIX 0->1 coercion)\n");
        printf("PASS: hxlcl_setjmp/hxlcl_longjmp x86_64 native round-trip\n");
        return 0;
    }
}
