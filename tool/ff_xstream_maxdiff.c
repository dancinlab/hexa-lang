/* ff_xstream_maxdiff — max|Δ| between two raw fp32 dumps (FP64 accumulation).
 * Usage: ff_xstream_maxdiff a.bin b.bin
 * Prints: MAXDIFF=<double>  N=<count>  (exit 0 if max|Δ|==0, 1 otherwise). */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int main(int argc, char** argv) {
    if (argc != 3) { fprintf(stderr, "usage: %s a.bin b.bin\n", argv[0]); return 2; }
    FILE* fa = fopen(argv[1], "rb");
    FILE* fb = fopen(argv[2], "rb");
    if (!fa || !fb) { fprintf(stderr, "cannot open inputs\n"); return 2; }
    double maxd = 0.0; long n = 0;
    float a, b;
    while (fread(&a, sizeof(float), 1, fa) == 1 && fread(&b, sizeof(float), 1, fb) == 1) {
        double dd = fabs((double)a - (double)b);
        if (dd > maxd) maxd = dd;
        ++n;
    }
    /* length mismatch check */
    int extra_a = (fread(&a, sizeof(float), 1, fa) == 1);
    int extra_b = (fread(&b, sizeof(float), 1, fb) == 1);
    if (extra_a || extra_b) { fprintf(stderr, "LENGTH MISMATCH\n"); printf("MAXDIFF=nan N=%ld\n", n); return 2; }
    printf("MAXDIFF=%.17g  N=%ld\n", maxd, n);
    fclose(fa); fclose(fb);
    return (maxd == 0.0) ? 0 : 1;
}
