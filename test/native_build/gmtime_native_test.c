// test/native_build/gmtime_native_test.c — ING #29 R1 (axis-②) bit-exact verifier.
//
// Compares the hexa-native civil-from-days gmtime_r core (self/native/gmtime_native.c,
// Howard Hinnant algorithm) against the host libc gmtime_r over representative Unix
// epochs (incl. epoch 0, leap years, and NEGATIVE / pre-epoch times, which exercise
// the floor-toward-−inf branch). PASS iff every broken-down tm field matches libc.
//
// Build (host libc reference):
//   cc -O2 -std=gnu11 -D_GNU_SOURCE -I self/native \
//      test/native_build/gmtime_native_test.c -o /tmp/gmtime_test && /tmp/gmtime_test
//
// Note: the native source is included WITHOUT -DHEXA_RT_GMTIME_NATIVE so the
// `gmtime_r` override is NOT defined here — we call the pure compute
// hxlcl_gmtime_r_compute() and diff its fields against the libc `gmtime_r` symbol.

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdint.h>

#include "gmtime_native.c"

static int diff_tm(const char *name, const struct tm *g, const struct tm *r) {
    if (g->tm_year == r->tm_year && g->tm_mon == r->tm_mon &&
        g->tm_mday == r->tm_mday && g->tm_hour == r->tm_hour &&
        g->tm_min  == r->tm_min  && g->tm_sec  == r->tm_sec  &&
        g->tm_wday == r->tm_wday && g->tm_yday == r->tm_yday) {
        printf("PASS  %-34s %04d-%02d-%02dT%02d:%02d:%02d wday=%d yday=%d\n",
               name, g->tm_year + 1900, g->tm_mon + 1, g->tm_mday,
               g->tm_hour, g->tm_min, g->tm_sec, g->tm_wday, g->tm_yday);
        return 0;
    }
    printf("FAIL  %-34s native=%04d-%02d-%02dT%02d:%02d:%02d wday=%d yday=%d  "
           "libc=%04d-%02d-%02dT%02d:%02d:%02d wday=%d yday=%d\n",
           name, g->tm_year + 1900, g->tm_mon + 1, g->tm_mday,
           g->tm_hour, g->tm_min, g->tm_sec, g->tm_wday, g->tm_yday,
           r->tm_year + 1900, r->tm_mon + 1, r->tm_mday,
           r->tm_hour, r->tm_min, r->tm_sec, r->tm_wday, r->tm_yday);
    return 1;
}

int main(void) {
    struct { const char *name; time_t t; } V[] = {
        { "epoch 1970-01-01T00:00:00",       (time_t)0 },
        { "1970-01-01T00:00:01",             (time_t)1 },
        { "1999-12-31T23:59:59",             (time_t)946684799LL },
        { "Y2K 2000-01-01T00:00:00",         (time_t)946684800LL },
        { "leap 2000-02-29T12:00:00",        (time_t)951825600LL }, // 2000 is leap (div 400)
        { "leap 2024-02-29T23:59:59",        (time_t)1709251199LL },
        { "2001-03-01T00:00:00",             (time_t)983404800LL },
        { "32-bit edge 2038-01-19T03:14:07", (time_t)2147483647LL },
        { "far future 2100-12-31T23:59:59",  (time_t)4133980799LL }, // 2100 NOT leap
        { "far future 2400-02-29 (div400)",  (time_t)13574563200LL }, // 2400 IS leap
        { "pre-epoch 1969-12-31T23:59:59",   (time_t)-1 },             // negative epoch
        { "pre-epoch 1969-12-31T00:00:00",   (time_t)-86400LL },
        { "deep past 1900-01-01T00:00:00",   (time_t)-2208988800LL },
        { "deep past 1901-12-13T20:45:52",   (time_t)-2147483648LL }, // 32-bit min
    };
    int n = (int)(sizeof(V) / sizeof(V[0]));
    int pass = 0, fail = 0;
    for (int i = 0; i < n; i++) {
        struct tm got, ref;
        memset(&got, 0, sizeof(got));
        memset(&ref, 0, sizeof(ref));
        time_t t = V[i].t;
        hxlcl_gmtime_r_compute(&t, &got);
        gmtime_r(&t, &ref); // libc reference (override NOT defined in this TU)
        if (diff_tm(V[i].name, &got, &ref) == 0) pass++; else fail++;
    }
    printf("\n%d/%d bit-exact vs libc gmtime_r  (%d fail)\n", pass, n, fail);
    return fail == 0 ? 0 : 1;
}
