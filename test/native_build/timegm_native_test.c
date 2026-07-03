// test/native_build/timegm_native_test.c — ING #29 R1 bit-exact verifier.
//
// Compares the hexa-native integer calendar timegm (self/native/timegm_native.c,
// musl __tm_to_secs port) against the host libc timegm over representative
// broken-down UTC times. PASS iff every vector matches libc bit-for-bit.
//
// Build (host libc reference):
//   cc -O2 -std=gnu11 -D_GNU_SOURCE -I self/native \
//      test/native_build/timegm_native_test.c -o /tmp/timegm_test && /tmp/timegm_test
//
// Note: the native source is included WITHOUT -DHEXA_RT_TIMEGM_NATIVE so the
// `timegm` override is NOT defined here — we call the pure compute
// hxlcl_timegm_secs() and diff it against the libc `timegm` symbol.

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdint.h>

#include "timegm_native.c"

static struct tm mk(int y, int mo, int d, int h, int mi, int s) {
    struct tm t;
    memset(&t, 0, sizeof(t));
    t.tm_year = y - 1900;
    t.tm_mon  = mo - 1;
    t.tm_mday = d;
    t.tm_hour = h;
    t.tm_min  = mi;
    t.tm_sec  = s;
    return t;
}

int main(void) {
    struct { const char *name; struct tm tm; } V[] = {
        { "epoch 1970-01-01T00:00:00",       mk(1970, 1, 1, 0, 0, 0) },
        { "1970-01-01T00:00:01",             mk(1970, 1, 1, 0, 0, 1) },
        { "1999-12-31T23:59:59",             mk(1999,12,31,23,59,59) },
        { "Y2K 2000-01-01T00:00:00",         mk(2000, 1, 1, 0, 0, 0) },
        { "leap 2000-02-29T12:00:00",        mk(2000, 2,29,12, 0, 0) }, // 2000 is leap (div 400)
        { "leap 2024-02-29T23:59:59",        mk(2024, 2,29,23,59,59) },
        { "non-leap 1900-02-28 (div100)",    mk(1900, 2,28, 0, 0, 0) }, // 1900 NOT leap
        { "2001-03-01T00:00:00",             mk(2001, 3, 1, 0, 0, 0) },
        { "32-bit edge 2038-01-19T03:14:07", mk(2038, 1,19, 3,14, 7) },
        { "far future 2100-12-31T23:59:59",  mk(2100,12,31,23,59,59) }, // 2100 NOT leap
        { "far future 2400-02-29 (div400)",  mk(2400, 2,29, 0, 0, 0) }, // 2400 IS leap
        { "month overflow tm_mon=13",        mk(2023,14, 1, 0, 0, 0) }, // normalises to 2024-02
        { "pre-epoch 1969-12-31T23:59:59",   mk(1969,12,31,23,59,59) }, // negative epoch
        { "deep past 1900-01-01T00:00:00",   mk(1900, 1, 1, 0, 0, 0) },
    };
    int n = (int)(sizeof(V) / sizeof(V[0]));
    int pass = 0, fail = 0;
    for (int i = 0; i < n; i++) {
        struct tm a = V[i].tm; // libc timegm may mutate; give each its own copy
        struct tm b = V[i].tm;
        int64_t got = hxlcl_timegm_secs(&b);
        int64_t ref = (int64_t)timegm(&a);
        if (got == ref) {
            pass++;
            printf("PASS  %-34s native=%lld libc=%lld\n",
                   V[i].name, (long long)got, (long long)ref);
        } else {
            fail++;
            printf("FAIL  %-34s native=%lld libc=%lld  (DELTA=%lld)\n",
                   V[i].name, (long long)got, (long long)ref,
                   (long long)(got - ref));
        }
    }
    printf("\n%d/%d bit-exact vs libc timegm  (%d fail)\n", pass, n, fail);
    return fail == 0 ? 0 : 1;
}
