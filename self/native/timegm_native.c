// self/native/timegm_native.c — ING #29 libc-free re-architecture ladder, R1.
//
// α (native-compute) pure-leaf: replaces the runtime substrate's sole RAW libc
// `timegm()` reference with a hexa-native integer calendar computation. No
// syscall, no ABI surface — pure tm{year,mon,mday,hour,min,sec} → time_t (UTC).
//
// ── Why a delegate (NOT a frozen-blob edit) ──────────────────────────────────
// The shipping runtime substrate calls timegm RAW at exactly one site:
//   self/runtime.c:12312 (frozen blob 151c52c8) —
//     `int64_t epoch = (int64_t)timegm(&g);`   (hexa_utc_iso_parse)
// The companion `gmtime_r` (the INVERSE, epoch→civil) was already ported to a
// hexa-native body INSIDE the frozen blob before it froze (runtime.c:2645
// `hxlcl_gmtime_r`, civil-from-days, "no libc"), routed via an in-blob
// `#define gmtime_r hxlcl_gmtime_r`. `timegm` never received that treatment and
// the blob is now IMMUTABLE (release-integrity hardline — faithful byte-identity
// gate vs 151c52c8). So timegm cannot be redirected from inside the blob.
//
// Instead we follow the #3798 fmod→rt_fmod / zeroc_hxlcl_delegate.c pattern:
// supply a STRONG EXTERNAL definition of `timegm` in a SEPARATE seed object that
// the DEFAULT build never compiles (byte-identical OFF). When opt-in
// (-DHEXA_RT_TIMEGM_NATIVE) the seed .o is linked ahead of libc, so the frozen
// blob's raw `timegm(&g)` reference resolves to THIS definition and the libc
// `timegm` symbol is dropped from the final link — one symbol off the -lc
// ladder, with zero edits to the immutable frozen blob.
//
// ── Reference-match (white-box port) ─────────────────────────────────────────
// Ported 1:1 from musl-libc (integer calendar arithmetic, bit-exact UTC):
//   musl src/time/__tm_to_secs.c    — tm → seconds (month overflow normalised)
//   musl src/time/__year_to_secs.c  — year → seconds since 1970 + leap accounting
//   musl src/time/__month_to_secs.c — month → cumulative seconds (+leap-day)
//   musl src/time/timegm.c          — public wrapper (returns __tm_to_secs)
// Cross-checks the repo's own native calendar (stdlib/time/civil.hexa
// days_from_civil, Howard Hinnant) and the in-blob hxlcl_gmtime_r inverse.
//
// The pure compute (hxlcl_timegm_secs) is ALWAYS defined so the standalone test
// harness (test/native_build/timegm_native_test.c) can diff it against libc
// timegm without pulling in the symbol override; the override `timegm` is gated.

#include <time.h>
#include <stdint.h>

// musl src/time/__month_to_secs.c — cumulative seconds at the start of `month`
// (0-11) within the year, +1 day past February in a leap year.
static int hxlcl_month_to_secs(int month, int is_leap) {
    static const int secs_through_month[] = {
        0, 31*86400, 59*86400, 90*86400,
        120*86400, 151*86400, 181*86400, 212*86400,
        243*86400, 273*86400, 304*86400, 334*86400
    };
    int t = secs_through_month[month];
    if (is_leap && month >= 2) t += 86400;
    return t;
}

// musl src/time/__year_to_secs.c — seconds from 1970-01-01 to `year`-01-01
// (year is the absolute proleptic-Gregorian year, e.g. 2000), and sets *is_leap.
static int64_t hxlcl_year_to_secs(int64_t year, int *is_leap) {
    if (year - 2ULL <= 136) {
        int y = (int)year;
        int leaps = (y - 68) >> 2;
        if (!((y - 68) & 3)) {
            leaps--;
            if (is_leap) *is_leap = 1;
        } else if (is_leap) {
            *is_leap = 0;
        }
        return 31536000LL * (y - 70) + 86400LL * leaps;
    }

    int cycles, centuries, leaps, rem;
    int dummy;
    if (!is_leap) is_leap = &dummy;
    cycles = (int)((year - 100) / 400);
    rem = (int)((year - 100) % 400);
    if (rem < 0) { cycles--; rem += 400; }
    if (!rem) {
        *is_leap = 1;
        centuries = 0;
        leaps = 0;
    } else {
        if (rem >= 200) {
            if (rem >= 300) { centuries = 3; rem -= 300; }
            else            { centuries = 2; rem -= 200; }
        } else {
            if (rem >= 100) { centuries = 1; rem -= 100; }
            else            { centuries = 0; }
        }
        if (!rem) {
            *is_leap = 0;
            leaps = 0;
        } else {
            leaps = rem / 4;
            rem %= 4;
            *is_leap = !rem;
        }
    }

    leaps += 97 * cycles + 24 * centuries - *is_leap;

    return (year - 100) * 31536000LL + leaps * 86400LL + 946684800LL + 86400LL;
}

// musl src/time/__tm_to_secs.c — broken-down UTC tm → Unix seconds.
// `tm_year` is years-since-1900, `tm_mon` is 0-11 (over/underflow normalised),
// `tm_mday` is 1-based. Result is bit-exact with glibc/musl timegm for UTC.
int64_t hxlcl_timegm_secs(const struct tm *tm) {
    int is_leap;
    int64_t year = tm->tm_year;
    int month = tm->tm_mon;
    if (month >= 12 || month < 0) {
        int adj = month / 12;
        month %= 12;
        if (month < 0) { adj--; month += 12; }
        year += adj;
    }
    int64_t t = hxlcl_year_to_secs(year, &is_leap);
    t += hxlcl_month_to_secs(month, is_leap);
    t += 86400LL * (tm->tm_mday - 1);
    t += 3600LL * tm->tm_hour;
    t += 60LL * tm->tm_min;
    t += tm->tm_sec;
    return t;
}

#ifdef HEXA_RT_TIMEGM_NATIVE
// musl src/time/timegm.c — public wrapper. Strong external definition: when this
// seed object is linked (opt-in), it satisfies the frozen blob's raw `timegm`
// reference ahead of libc, dropping the libc timegm symbol from the final link.
// (Field-normalisation writeback to *tm — glibc behaviour — is omitted: the sole
//  shipping caller hexa_utc_iso_parse uses only the return value and discards tm;
//  the returned epoch is bit-exact. R2 may add __secs_to_tm writeback for full
//  drop-in parity if a writeback-dependent caller appears.)
time_t timegm(struct tm *tm) {
    return (time_t)hxlcl_timegm_secs(tm);
}
#endif
