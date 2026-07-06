// strtod_tail_oracle_ref.c — independent re-verifier for strtod_tail_oracle.hexa.
// Reads harness lines "<cls> <tag> <got> <ora> <input-to-EOL>" from stdin and
// RECOMPUTES host strtod per input. Verifies (1) ora == strtod bits — proves the
// in-process oracle really was libc strtod; (2) class T/F: got == strtod bits —
// the flip gate, independent of the in-process compare. Full 64-bit compare incl.
// NaN sign+payload. Exit 0 = gate pass.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

int main(void) {
    char line[16384];
    long long n = 0, t_mis = 0, f_mis = 0, ora_drift = 0, shown = 0;
    while (fgets(line, sizeof line, stdin)) {
        if ((line[0] != 'T' && line[0] != 'F' && line[0] != 'J') || line[1] != ' ')
            continue;                                  // skip '#' meta lines
        char cls = line[0];
        long long got = 0, ora = 0;
        if (sscanf(line, "%*c %*s %lld %lld", &got, &ora) != 2) continue;
        char *p = line; int sp = 0;                    // input = after 4th space, verbatim
        while (*p && sp < 4) { if (*p == ' ') sp++; p++; }
        size_t L = strlen(p);
        if (L && p[L-1] == '\n') p[L-1] = 0;           // strip only the newline
        double d = strtod(p, NULL);
        long long ref; memcpy(&ref, &d, 8);
        n++;
        if (ora != ref) {
            ora_drift++;
            if (shown++ < 20) fprintf(stderr, "ORACLE-DRIFT %c ora=%lld ref=%lld [%s]\n", cls, ora, ref, p);
        }
        if ((cls == 'T' || cls == 'F') && got != ref) {
            if (cls == 'T') t_mis++; else f_mis++;
            if (shown++ < 60) fprintf(stderr, "MISMATCH %c got=%lld ref=%lld [%s]\n", cls, got, ref, p);
        }
    }
    printf("REF-VERDICT n=%lld T_mis=%lld F_mis=%lld oracle_drift=%lld\n", n, t_mis, f_mis, ora_drift);
    return (t_mis || f_mis || ora_drift) ? 1 : 0;
}
