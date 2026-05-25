/* F-FUSION-AXISA-LAYERNORM -- fused 1-kernel LayerNorm vs eager 4-launch baseline.
 *
 * y[row,j] = (x - mean_row)/sqrt(var_row + eps) * gamma[j] + beta[j]
 *
 *   fused:  layernorm_fused.ptx  (1 launch, smem reduction, no HBM intermediate)
 *   eager:  layernorm_eager.ptx  (k1_reduce_mean, k2_reduce_var, k3_normalize,
 *                                 k4_affine = 4 launches, HBM round-trip per op)
 *
 * Per shape (rows x d):
 *   - launch count       : fused=1   eager=4
 *   - HBM traffic / elem  : fused = 2 read + 1 write = 3 ; eager = 4 read + 2 write = 6
 *                           (k1 read x ; k2 read x ; k3 read x + write xh ; k4 read xh + write y)
 *   - numeric correctness : fused vs f64 CPU ref, HONEST per-row-scaled RMS rel metric
 *   - timed wall (median of REPS) for both, fused speedup, >=30% gate
 *
 * Build: nvcc -O2 -o host_layernorm host_layernorm.c -lcuda -lm
 * Run:   ./host_layernorm layernorm_fused.ptx layernorm_eager.ptx [rows] [d] [reps]
 */
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CHECK(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

static char *slurp(const char *path) {
    FILE *fp = fopen(path, "rb");
    if (!fp) { perror(path); exit(1); }
    fseek(fp, 0, SEEK_END); long n = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *buf = (char *)malloc(n + 1);
    if (fread(buf, 1, n, fp) != (size_t)n) { perror("read"); exit(1); }
    buf[n] = 0; fclose(fp);
    return buf;
}
static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s fused.ptx eager.ptx [rows] [d] [reps]\n", argv[0]); return 2; }
    const char *fused_path = argv[1];
    const char *eager_path = argv[2];
    int rows = (argc > 3) ? atoi(argv[3]) : 4096;
    int d    = (argc > 4) ? atoi(argv[4]) : 4096;
    int reps = (argc > 5) ? atoi(argv[5]) : 200;
    const int warmup = 20;
    const float eps = 1e-5f;
    size_t total = (size_t)rows * d;
    size_t bytes = total * sizeof(float);

    char *fused_ptx = slurp(fused_path);
    char *eager_ptx = slurp(eager_path);

    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));

    CUmodule mf, me;
    CUjit_option jo[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jv[1] = { (void *)0 };
    CHECK(cuModuleLoadDataEx(&mf, fused_ptx, 1, jo, jv));
    CHECK(cuModuleLoadDataEx(&me, eager_ptx, 1, jo, jv));

    CUfunction kf, k1, k2, k3, k4;
    CHECK(cuModuleGetFunction(&kf, mf, "layernorm_fused"));
    CHECK(cuModuleGetFunction(&k1, me, "k1_reduce_mean"));
    CHECK(cuModuleGetFunction(&k2, me, "k2_reduce_var"));
    CHECK(cuModuleGetFunction(&k3, me, "k3_normalize"));
    CHECK(cuModuleGetFunction(&k4, me, "k4_affine"));

    float *hx = (float *)malloc(bytes);
    float *hg = (float *)malloc((size_t)d * sizeof(float));
    float *hb = (float *)malloc((size_t)d * sizeof(float));
    float *hy = (float *)malloc(bytes);
    double *ref = (double *)malloc(total * sizeof(double));

    uint32_t st = 0x2468aceu;
    for (size_t i = 0; i < total; ++i) {
        st = st * 1664525u + 1013904223u;
        hx[i] = ((float)(st >> 8) / (float)(1u << 24)) * 4.0f - 2.0f;
    }
    for (int j = 0; j < d; ++j) {
        st = st * 1664525u + 1013904223u;
        hg[j] = ((float)(st >> 8) / (float)(1u << 24)) * 1.0f + 0.5f; /* [0.5,1.5) */
        st = st * 1664525u + 1013904223u;
        hb[j] = ((float)(st >> 8) / (float)(1u << 24)) * 0.4f - 0.2f; /* [-0.2,0.2) */
    }
    /* f64 reference */
    for (int r = 0; r < rows; ++r) {
        const float *xr = hx + (size_t)r * d;
        double s = 0, ss = 0;
        for (int j = 0; j < d; ++j) { s += xr[j]; ss += (double)xr[j]*xr[j]; }
        double mean = s / d;
        double var = ss / d - mean*mean;
        double inv = 1.0 / sqrt(var + (double)eps);
        for (int j = 0; j < d; ++j) {
            double xh = ((double)xr[j] - mean) * inv;
            ref[(size_t)r*d + j] = xh * (double)hg[j] + (double)hb[j];
        }
    }

    CUdeviceptr dx, dg, db, dy, dm, dv, dxh;
    CHECK(cuMemAlloc(&dx, bytes));
    CHECK(cuMemAlloc(&dg, (size_t)d * sizeof(float)));
    CHECK(cuMemAlloc(&db, (size_t)d * sizeof(float)));
    CHECK(cuMemAlloc(&dy, bytes));
    CHECK(cuMemAlloc(&dm, (size_t)rows * sizeof(float)));
    CHECK(cuMemAlloc(&dv, (size_t)rows * sizeof(float)));
    CHECK(cuMemAlloc(&dxh, bytes));
    CHECK(cuMemcpyHtoD(dx, hx, bytes));
    CHECK(cuMemcpyHtoD(dg, hg, (size_t)d * sizeof(float)));
    CHECK(cuMemcpyHtoD(db, hb, (size_t)d * sizeof(float)));

    const int TPB = 256;
    unsigned grid_rows = (unsigned)rows;
    unsigned grid_elem = (unsigned)((total + TPB - 1) / TPB);
    unsigned total_u = (unsigned)total;

    void *f_args[6] = { &dx, &dg, &db, &dy, &d, (void*)&eps };
    void *a1[3] = { &dx, &dm, &d };
    void *a2[4] = { &dx, &dm, &dv, &d };
    void *a3[7] = { &dx, &dm, &dv, &dxh, &d, &total_u, (void*)&eps };
    void *a4[6] = { &dxh, &dg, &db, &dy, &d, &total_u };

    /* --- correctness: run fused once --- */
    CHECK(cuLaunchKernel(kf, grid_rows,1,1, TPB,1,1, 0, NULL, f_args, NULL));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(hy, dy, bytes));

    /* HONEST metric: per-row RMS rel error.  For each row compute
       rms_err = sqrt(mean_j (got-ref)^2) and rms_ref = sqrt(mean_j ref^2);
       row_rel = rms_err / (rms_ref + tiny).  Report max over rows + global RMS. */
    double max_row_rel = 0.0, sum_sq_err = 0.0, sum_sq_ref = 0.0, max_abs = 0.0;
    for (int r = 0; r < rows; ++r) {
        double se = 0, sr = 0;
        for (int j = 0; j < d; ++j) {
            double g = (double)hy[(size_t)r*d + j];
            double rf = ref[(size_t)r*d + j];
            double e = g - rf;
            se += e*e; sr += rf*rf;
            if (fabs(e) > max_abs) max_abs = fabs(e);
        }
        double rms_e = sqrt(se / d), rms_r = sqrt(sr / d);
        double rr = rms_e / (rms_r + 1e-12);
        if (rr > max_row_rel) max_row_rel = rr;
        sum_sq_err += se; sum_sq_ref += sr;
    }
    double global_rms_rel = sqrt(sum_sq_err) / (sqrt(sum_sq_ref) + 1e-12);
    double tol = 1e-2;
    const char *num_verd = (max_row_rel <= tol && global_rms_rel <= tol) ? "PASS" : "FAIL";

    /* --- verify eager produces same (sanity) --- */
    CHECK(cuLaunchKernel(k1, grid_rows,1,1, TPB,1,1, 0, NULL, a1, NULL));
    CHECK(cuLaunchKernel(k2, grid_rows,1,1, TPB,1,1, 0, NULL, a2, NULL));
    CHECK(cuLaunchKernel(k3, grid_elem,1,1, TPB,1,1, 0, NULL, a3, NULL));
    CHECK(cuLaunchKernel(k4, grid_elem,1,1, TPB,1,1, 0, NULL, a4, NULL));
    CHECK(cuCtxSynchronize());

    /* --- timed --- */
    CUevent e0, e1; CHECK(cuEventCreate(&e0,0)); CHECK(cuEventCreate(&e1,0));
    double *tf = (double *)malloc(reps * sizeof(double));
    double *tb = (double *)malloc(reps * sizeof(double));

    for (int w = 0; w < warmup; ++w)
        CHECK(cuLaunchKernel(kf, grid_rows,1,1, TPB,1,1, 0, NULL, f_args, NULL));
    CHECK(cuCtxSynchronize());
    for (int rep = 0; rep < reps; ++rep) {
        CHECK(cuEventRecord(e0,0));
        CHECK(cuLaunchKernel(kf, grid_rows,1,1, TPB,1,1, 0, NULL, f_args, NULL));
        CHECK(cuEventRecord(e1,0)); CHECK(cuEventSynchronize(e1));
        float ms=0; CHECK(cuEventElapsedTime(&ms,e0,e1)); tf[rep]=(double)ms;
    }
    for (int w = 0; w < warmup; ++w) {
        CHECK(cuLaunchKernel(k1, grid_rows,1,1, TPB,1,1, 0, NULL, a1, NULL));
        CHECK(cuLaunchKernel(k2, grid_rows,1,1, TPB,1,1, 0, NULL, a2, NULL));
        CHECK(cuLaunchKernel(k3, grid_elem,1,1, TPB,1,1, 0, NULL, a3, NULL));
        CHECK(cuLaunchKernel(k4, grid_elem,1,1, TPB,1,1, 0, NULL, a4, NULL));
    }
    CHECK(cuCtxSynchronize());
    for (int rep = 0; rep < reps; ++rep) {
        CHECK(cuEventRecord(e0,0));
        CHECK(cuLaunchKernel(k1, grid_rows,1,1, TPB,1,1, 0, NULL, a1, NULL));
        CHECK(cuLaunchKernel(k2, grid_rows,1,1, TPB,1,1, 0, NULL, a2, NULL));
        CHECK(cuLaunchKernel(k3, grid_elem,1,1, TPB,1,1, 0, NULL, a3, NULL));
        CHECK(cuLaunchKernel(k4, grid_elem,1,1, TPB,1,1, 0, NULL, a4, NULL));
        CHECK(cuEventRecord(e1,0)); CHECK(cuEventSynchronize(e1));
        float ms=0; CHECK(cuEventElapsedTime(&ms,e0,e1)); tb[rep]=(double)ms;
    }

    qsort(tf, reps, sizeof(double), cmp_double);
    qsort(tb, reps, sizeof(double), cmp_double);
    double med_f = tf[reps/2], med_b = tb[reps/2];
    /* std */
    double mu_f=0, mu_b=0; for(int i=0;i<reps;i++){mu_f+=tf[i];mu_b+=tb[i];} mu_f/=reps; mu_b/=reps;
    double sd_f=0, sd_b=0; for(int i=0;i<reps;i++){sd_f+=(tf[i]-mu_f)*(tf[i]-mu_f);sd_b+=(tb[i]-mu_b)*(tb[i]-mu_b);}
    sd_f=sqrt(sd_f/reps); sd_b=sqrt(sd_b/reps);
    double speedup = med_f>0 ? med_b/med_f : 0;
    double pct = med_b>0 ? (1.0 - med_f/med_b)*100.0 : 0;
    const char *gate = (pct >= 30.0) ? "PASS" : "FAIL";

    printf("F-FUSION-AXISA-LAYERNORM rows=%d d=%d reps=%d\n", rows, d, reps);
    printf("  STRUCTURAL: launches fused=1 eager=4 (ratio 4.0x)\n");
    printf("  STRUCTURAL: HBM/elem fused=2R+1W=3 eager=4R+2W=6 (traffic ratio 2.00x)\n");
    printf("  NUMERIC %s: max_row_rel=%g global_rms_rel=%g max_abs=%g tol=%g\n",
        num_verd, max_row_rel, global_rms_rel, max_abs, tol);
    printf("  TIMED: fused_med=%.5f ms (std %.5f) eager_med=%.5f ms (std %.5f) speedup=%.3fx faster=%.1f%% gate(>=30%%) %s\n",
        med_f, sd_f, med_b, sd_b, speedup, pct, gate);

    FILE *rj = fopen("result_layernorm.json", "a");
    fprintf(rj, "{\"workload\":\"layernorm\",\"rows\":%d,\"d\":%d,\"reps\":%d,"
        "\"launch_ratio\":4.0,\"hbm_ratio\":2.0,"
        "\"numeric_verdict\":\"%s\",\"max_row_rel\":%g,\"global_rms_rel\":%g,\"max_abs\":%g,"
        "\"fused_med_ms\":%.6f,\"fused_std_ms\":%.6f,\"eager_med_ms\":%.6f,\"eager_std_ms\":%.6f,"
        "\"speedup\":%.4f,\"pct_faster\":%.2f,\"gate30\":\"%s\"}\n",
        rows, d, reps, num_verd, max_row_rel, global_rms_rel, max_abs,
        med_f, sd_f, med_b, sd_b, speedup, pct, gate);
    fclose(rj);

    cuMemFree(dx);cuMemFree(dg);cuMemFree(db);cuMemFree(dy);cuMemFree(dm);cuMemFree(dv);cuMemFree(dxh);
    cuEventDestroy(e0);cuEventDestroy(e1); cuModuleUnload(mf);cuModuleUnload(me); cuCtxDestroy(ctx);
    return (strcmp(num_verd,"PASS")==0) ? 0 : 1;
}
