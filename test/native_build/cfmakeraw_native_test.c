// test/native_build/cfmakeraw_native_test.c — ING #29 (axis-②) parity verifier.
//
// Verifies the hexa-native symbolic-flag-clear cfmakeraw core
// (self/native/cfmakeraw_native.c, glibc/musl port) over several synthetic
// starting struct termios fills.
//
// Build (host reference):
//   cc -O2 -std=gnu11 -D_GNU_SOURCE -D_DARWIN_C_SOURCE -I self/native \
//      test/native_build/cfmakeraw_native_test.c -o /tmp/cfmakeraw_test && /tmp/cfmakeraw_test
//
// Note: the native source is included WITHOUT -DHEXA_RT_CFMAKERAW_NATIVE so the
// `cfmakeraw` override is NOT defined here — we call the pure compute
// hxlcl_cfmakeraw_compute() directly.
//
// Two independent oracles:
//   (1) ref_glibc_cfmakeraw() — a SECOND, independent transcription of the glibc/
//       musl mask set (using the same <termios.h> SYMBOLIC constants). Asserted on
//       EVERY platform: catches emitter round-trip corruption, a dropped flag, a
//       wrong field, CS7-vs-CS8, etc. This is the spec the port claims to match.
//   (2) host libc cfmakeraw — asserted ONLY on __linux__, where the host libc IS
//       glibc/musl (== the byteeq target). It proves the ported spec is BIT-EXACT
//       with the libc symbol being dropped. NOT a valid oracle on BSD/Darwin, whose
//       cfmakeraw is a genuinely DIFFERENT function (it keeps IGNBRK, sets CREAD,
//       and clears IMAXBEL/NOFLSH/TOSTOP/PENDIN — neither a subset nor a superset
//       of the glibc set), so it is not compared there.

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#ifndef _DARWIN_C_SOURCE
#define _DARWIN_C_SOURCE
#endif
#include <stdio.h>
#include <string.h>
#include <termios.h>

#include "cfmakeraw_native.c"

// Oracle (1): independent transcription of glibc termios/cfmakeraw.c == musl
// src/termios/cfmakeraw.c. Kept textually separate from the emitted body so a
// transcription error in the emitted .c is caught by the diff.
static void ref_glibc_cfmakeraw(struct termios *t) {
    t->c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
    t->c_oflag &= ~OPOST;
    t->c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    t->c_cflag &= ~(CSIZE | PARENB);
    t->c_cflag |= CS8;
    t->c_cc[VMIN] = 1;
    t->c_cc[VTIME] = 0;
}

static int cmp_tm(const struct termios *a, const struct termios *b) {
    if (a->c_iflag != b->c_iflag || a->c_oflag != b->c_oflag ||
        a->c_lflag != b->c_lflag || a->c_cflag != b->c_cflag ||
        a->c_cc[VMIN] != b->c_cc[VMIN] || a->c_cc[VTIME] != b->c_cc[VTIME]) {
        return 1;
    }
    return 0;
}

static void dump(const char *tag, const struct termios *t) {
    printf("      %-10s i=%08lx o=%08lx l=%08lx c=%08lx VMIN=%d VTIME=%d\n",
           tag, (unsigned long)t->c_iflag, (unsigned long)t->c_oflag,
           (unsigned long)t->c_lflag, (unsigned long)t->c_cflag,
           t->c_cc[VMIN], t->c_cc[VTIME]);
}

static int check_one(const char *name, int fill) {
    struct termios init, got, spec;
    memset(&init, fill, sizeof(init));
    got = init;  spec = init;
    hxlcl_cfmakeraw_compute(&got);   // the emitted native body
    ref_glibc_cfmakeraw(&spec);      // oracle (1): glibc/musl spec

    int bad = cmp_tm(&got, &spec);
    if (bad) { printf("  spec-diff:\n"); dump("native", &got); dump("glibc-spec", &spec); }

#if defined(__linux__)
    struct termios ref = init;
    cfmakeraw(&ref);                 // oracle (2): host libc (== glibc on linux)
    if (cmp_tm(&got, &ref)) { bad = 1; printf("  libc-diff:\n"); dump("native", &got); dump("libc", &ref); }
#endif

    // Postconditions (platform-independent spec facts).
    if ((got.c_cflag & CSIZE) != CS8) { printf("      spec: CS8 not set\n"); bad = 1; }
    if (got.c_cc[VMIN] != 1 || got.c_cc[VTIME] != 0) { printf("      spec: VMIN/VTIME wrong\n"); bad = 1; }
    if (got.c_lflag & ICANON) { printf("      spec: ICANON not cleared (not raw)\n"); bad = 1; }

    printf("%-5s %-16s native c=%08lx VMIN=%d VTIME=%d\n",
           bad ? "FAIL" : "PASS", name,
           (unsigned long)got.c_cflag, got.c_cc[VMIN], got.c_cc[VTIME]);
    return bad;
}

int main(void) {
    struct { const char *name; int fill; } V[] = {
        { "all-zero fill", 0x00 },
        { "all-one  fill", 0xFF },
        { "0xAA fill",     0xAA },
        { "0x55 fill",     0x55 },
        { "0x0F fill",     0x0F },
    };
    int n = (int)(sizeof(V) / sizeof(V[0]));
    int pass = 0, fail = 0;
    for (int i = 0; i < n; i++) {
        if (check_one(V[i].name, V[i].fill) == 0) pass++; else fail++;
    }
#if defined(__linux__)
    printf("\n%d/%d bit-exact vs glibc spec AND host libc cfmakeraw  (%d fail) [linux]\n", pass, n, fail);
#else
    printf("\n%d/%d bit-exact vs glibc/musl spec  (%d fail) [non-linux: host BSD cfmakeraw differs, not oracle]\n", pass, n, fail);
#endif
    return fail == 0 ? 0 : 1;
}
