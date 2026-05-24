// RFC 071 P8 N63 — F-RFC071-E2E-VEC-ADD-SCALE-NUMERIC-EQ + bandwidth sweep
//
// Scale-up cycle for N34 vec_add (c29359ab, N=1024 single-block PASS) +
// N50 vec_mul (097451f3, N=1024 single-block PASS). Same PTX kernel
// shape (vec_add with bounds check `to_i64(gid) < n`), now driven with
// a multi-block grid across 6 N values to probe bandwidth-bound regime
// + grid sizing + bounds-check correctness at scale.
//
// Shapes:
//   N ∈ {1024, 16384, 262144, 1048576, 4194304, 16777216}
//        1K,   16K,   256K,   1M,      4M,      16M
//   blockX = 1024, gridX = (N + 1023) / 1024
//
// Per shape:
//   - LCG-deterministic FP64 inputs (seed = 0x0123456789abcdefULL, same
//     as N34/N50 to maintain comparability)
//   - allocate fresh device buffers
//   - 5 warmup launches + 20 timed launches
//   - cuEventRecord wall time (median of 20)
//   - D2H copy result + byte-eq vs CPU reference
//   - GB/s = 3 * N * 8 bytes / median_seconds (1 load_a + 1 load_b + 1
//     store_c · 8 bytes/FP64 each)
//
// Build (ubu-2, requires CUDA toolkit):
//   gcc host_vec_add_scale.c -o /tmp/host_vec_add_scale -lcuda -lm
// Run:
//   /tmp/host_vec_add_scale
//
// Output: multi-line JSON (one line per shape) + headline summary line.
//   PASS = all 6 shapes byte_mismatch=0 AND status=PASS.
//   FAIL = any shape mismatches (kernel bug or grid wiring bug) OR
//          JIT / launch / sync error.
//
// Bandwidth saturation expected at N >= 1M (smaller N is launch-overhead
// bound · larger N saturates memory subsystem). RTX 5070 theoretical
// peak ≈ 672 GB/s (LPDDR5X 6750 MHz x 128-bit x 0.667? — closer to spec
// is GDDR7 28 Gbps x 192-bit = 672 GB/s). >50% saturation = >336 GB/s.

#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <time.h>

#define PTX_PATH "/tmp/rfc071_n63_vec_add.ptx"
#define NUM_SHAPES 6
#define WARMUP_RUNS 5
#define TIMED_RUNS 20

static const int64_t SHAPES_N[NUM_SHAPES] = {
    1024,        //   1K  (single-block, matches N34/N50)
    16384,       //  16K  (16 blocks)
    262144,      // 256K  (256 blocks)
    1048576,     //   1M  (1024 blocks)
    4194304,     //   4M  (4096 blocks)
    16777216     //  16M  (16384 blocks)
};

static int check(CUresult r, const char *what) {
    if (r == CUDA_SUCCESS) return 0;
    const char *name = NULL, *str = NULL;
    cuGetErrorName(r, &name);
    cuGetErrorString(r, &str);
    fprintf(stderr, "CUDA error in %s: %s (%s)\n", what,
            name ? name : "?", str ? str : "?");
    return 1;
}

static int cmp_double(const void *a, const void *b) {
    double da = *(const double*)a, db = *(const double*)b;
    if (da < db) return -1;
    if (da > db) return  1;
    return 0;
}

int main(void) {
    if (check(cuInit(0), "cuInit")) return 10;
    CUdevice dev;
    if (check(cuDeviceGet(&dev, 0), "cuDeviceGet")) return 11;
    char devname[256] = {0};
    cuDeviceGetName(devname, sizeof(devname), dev);
    CUcontext ctx;
    if (check(cuCtxCreate(&ctx, 0, dev), "cuCtxCreate")) return 12;

    // Read PTX file
    FILE *fp = fopen(PTX_PATH, "rb");
    if (!fp) { fprintf(stderr, "cannot open %s\n", PTX_PATH); return 20; }
    fseek(fp, 0, SEEK_END);
    long ptx_sz = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *ptx = (char*)malloc(ptx_sz + 1);
    fread(ptx, 1, ptx_sz, fp);
    ptx[ptx_sz] = 0;
    fclose(fp);
    fprintf(stderr, "device: %s\n", devname);
    fprintf(stderr, "loaded PTX %ld bytes\n", ptx_sz);

    // JIT-load PTX with verbose log
    char jit_info[8192] = {0};
    char jit_err[8192]  = {0};
    CUjit_option opts[] = {
        CU_JIT_INFO_LOG_BUFFER,
        CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_ERROR_LOG_BUFFER,
        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_LOG_VERBOSE
    };
    void *vals[] = {
        jit_info,
        (void*)(uintptr_t)sizeof(jit_info),
        jit_err,
        (void*)(uintptr_t)sizeof(jit_err),
        (void*)(uintptr_t)1
    };
    CUmodule mod;
    CUresult r = cuModuleLoadDataEx(&mod, ptx, 5, opts, vals);
    if (r != CUDA_SUCCESS) {
        fprintf(stderr, "cuModuleLoadDataEx FAILED\n");
        fprintf(stderr, "JIT err  log: %s\n", jit_err);
        printf("{\"status\":\"FAIL\",\"phase\":\"jit_load\"}\n");
        return 30;
    }
    fprintf(stderr, "JIT info: %s\n", jit_info);

    CUfunction fn;
    if (check(cuModuleGetFunction(&fn, mod, "vec_add"), "cuModuleGetFunction")) {
        printf("{\"status\":\"FAIL\",\"phase\":\"get_function\"}\n");
        return 31;
    }

    // CUDA events for timing
    CUevent ev_start, ev_stop;
    cuEventCreate(&ev_start, CU_EVENT_DEFAULT);
    cuEventCreate(&ev_stop,  CU_EVENT_DEFAULT);

    // Per-shape sweep
    int all_pass = 1;
    double best_gbps = 0.0;
    int64_t best_N = 0;

    printf("{\"shapes\":[\n");
    for (int si = 0; si < NUM_SHAPES; si++) {
        int64_t N = SHAPES_N[si];
        fprintf(stderr, "\n--- shape %d/%d: N=%lld ---\n",
                si+1, NUM_SHAPES, (long long)N);

        // Host buffers + LCG fill (seed identical across shapes for
        // reproducibility — each shape replays LCG from start)
        double *ha = (double*)malloc(N * sizeof(double));
        double *hb = (double*)malloc(N * sizeof(double));
        double *hc = (double*)malloc(N * sizeof(double));
        double *href = (double*)malloc(N * sizeof(double));
        if (!ha || !hb || !hc || !href) {
            fprintf(stderr, "host malloc FAILED at N=%lld\n", (long long)N);
            printf("{\"shape\":%lld,\"status\":\"FAIL\",\"phase\":\"host_alloc\"}],\n", (long long)N);
            all_pass = 0;
            break;
        }
        uint64_t s = 0x0123456789abcdefULL;
        for (int64_t i = 0; i < N; i++) {
            s = s * 6364136223846793005ULL + 1442695040888963407ULL;
            union { uint64_t u; double d; } ua;
            ua.u = (s >> 12) | 0x3ff0000000000000ULL;  // [1, 2)
            ha[i] = ua.d;
            s = s * 6364136223846793005ULL + 1442695040888963407ULL;
            union { uint64_t u; double d; } ub;
            ub.u = (s >> 12) | 0x3ff0000000000000ULL;  // [1, 2)
            hb[i] = ub.d;
            href[i] = ha[i] + hb[i];  // FP64 add — bit-exact for [1,2)+[1,2)
            hc[i] = -1.0;  // sentinel
        }

        // Device buffers
        CUdeviceptr da, db, dc;
        if (check(cuMemAlloc(&da, N * sizeof(double)), "alloc a")) {
            free(ha); free(hb); free(hc); free(href);
            all_pass = 0; break;
        }
        if (check(cuMemAlloc(&db, N * sizeof(double)), "alloc b")) {
            cuMemFree(da); free(ha); free(hb); free(hc); free(href);
            all_pass = 0; break;
        }
        if (check(cuMemAlloc(&dc, N * sizeof(double)), "alloc c")) {
            cuMemFree(da); cuMemFree(db);
            free(ha); free(hb); free(hc); free(href);
            all_pass = 0; break;
        }
        if (check(cuMemcpyHtoD(da, ha, N * sizeof(double)), "H2D a")) {
            all_pass = 0; break;
        }
        if (check(cuMemcpyHtoD(db, hb, N * sizeof(double)), "H2D b")) {
            all_pass = 0; break;
        }
        if (check(cuMemsetD8(dc, 0xee, N * sizeof(double)), "memset c")) {
            all_pass = 0; break;
        }

        // Launch params
        int blockX = 1024;
        int gridX  = (int)((N + blockX - 1) / blockX);
        int64_t n_arg = N;
        void *args[] = { &da, &db, &dc, &n_arg };

        // Warmup
        for (int w = 0; w < WARMUP_RUNS; w++) {
            r = cuLaunchKernel(fn, gridX,1,1, blockX,1,1, 0, NULL, args, NULL);
            if (r != CUDA_SUCCESS) {
                const char *nm = NULL; cuGetErrorName(r, &nm);
                fprintf(stderr, "warmup launch FAILED (shape N=%lld): %s\n",
                        (long long)N, nm ? nm : "?");
                all_pass = 0;
                goto shape_cleanup;
            }
        }
        cuCtxSynchronize();

        // Timed runs
        double times_ms[TIMED_RUNS];
        for (int t = 0; t < TIMED_RUNS; t++) {
            cuEventRecord(ev_start, 0);
            r = cuLaunchKernel(fn, gridX,1,1, blockX,1,1, 0, NULL, args, NULL);
            cuEventRecord(ev_stop, 0);
            cuEventSynchronize(ev_stop);
            if (r != CUDA_SUCCESS) {
                const char *nm = NULL; cuGetErrorName(r, &nm);
                fprintf(stderr, "timed launch %d FAILED (N=%lld): %s\n",
                        t, (long long)N, nm ? nm : "?");
                all_pass = 0;
                goto shape_cleanup;
            }
            float ms = 0.0f;
            cuEventElapsedTime(&ms, ev_start, ev_stop);
            times_ms[t] = (double)ms;
        }
        // median
        qsort(times_ms, TIMED_RUNS, sizeof(double), cmp_double);
        double median_ms = times_ms[TIMED_RUNS/2];
        double min_ms    = times_ms[0];
        double max_ms    = times_ms[TIMED_RUNS-1];

        // D2H result + byte-eq check
        if (check(cuMemcpyDtoH(hc, dc, N * sizeof(double)), "D2H c")) {
            all_pass = 0; goto shape_cleanup;
        }
        int64_t byte_mismatch = 0;
        int64_t first_mis = -1;
        double max_abs = 0.0;
        for (int64_t i = 0; i < N; i++) {
            union { double d; uint64_t u; } a, b;
            a.d = hc[i]; b.d = href[i];
            if (a.u != b.u) {
                byte_mismatch++;
                if (first_mis < 0) first_mis = i;
                double d = fabs(hc[i] - href[i]);
                if (d > max_abs) max_abs = d;
            }
        }

        // Bandwidth: 3*N*8 bytes (2 loads + 1 store of FP64)
        double bytes = 3.0 * (double)N * 8.0;
        double seconds = median_ms / 1000.0;
        double gbps = (bytes / seconds) / 1.0e9;

        const char *st = (byte_mismatch == 0) ? "PASS" : "FAIL";
        if (byte_mismatch != 0) all_pass = 0;
        if (gbps > best_gbps && byte_mismatch == 0) {
            best_gbps = gbps;
            best_N = N;
        }
        printf("  {\"N\":%lld,\"grid\":%d,\"block\":%d,\"median_ms\":%.6f,\"min_ms\":%.6f,\"max_ms\":%.6f,\"gbps\":%.3f,\"byte_mismatch\":%lld,\"first_mis\":%lld,\"max_abs_diff\":%.17g,\"c[0]\":%.17g,\"ref[0]\":%.17g,\"status\":\"%s\"}%s\n",
            (long long)N, gridX, blockX,
            median_ms, min_ms, max_ms, gbps,
            (long long)byte_mismatch, (long long)first_mis, max_abs,
            hc[0], href[0],
            st,
            (si == NUM_SHAPES - 1) ? "" : ",");
        fprintf(stderr, "  N=%lld median=%.6f ms  %.2f GB/s  bm=%lld  %s\n",
                (long long)N, median_ms, gbps, (long long)byte_mismatch, st);

      shape_cleanup:
        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb); free(hc); free(href);
        if (!all_pass) break;
    }
    printf("],\n");
    printf("\"overall\":\"%s\",\"peak_gbps\":%.3f,\"peak_N\":%lld,\"device\":\"%s\"}\n",
        all_pass ? "PASS" : "FAIL", best_gbps, (long long)best_N, devname);

    cuEventDestroy(ev_start);
    cuEventDestroy(ev_stop);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    return all_pass ? 0 : 1;
}
