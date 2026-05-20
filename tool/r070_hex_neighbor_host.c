/* RFC 070 P1 -- n=6 hex-fabric GPU emit smoke (bridge to north-star #3).
 *
 * Loads hex_neighbor.ptx via the CUDA Driver API (JIT-compiled from PTX
 * text -- the forward-compatible path; same pattern as RFC 055 / 067 / 069
 * hosts). Fires the 8x8 = 64-cell hex-stencil kernel and compares against
 * a CPU FP32 reference applying the exact same accumulation order.
 *
 * Falsifier:
 *   F-RFC070-HEX-NEIGHBOR-NUMERIC -- byte-eq vs CPU FP32 reference,
 *   max abs delta = 0 (no FMA contract on either side; same gather order).
 *
 * Build (on the fire host):
 *   nvcc -O2 -arch=sm_90 r070_hex_neighbor_host.c -lcuda -o host_bin
 *
 * Run:
 *   ./host_bin hex_neighbor.ptx
 *
 * Writes:
 *   result.json (hostname, driver, sm, max_delta, verdict)
 *   stdout      (raw fire log -- captured by caller into fire.log)
 *
 * g3-honesty: this is a smoke kernel -- 64 cells, 1 block, 1 fire. The
 * goal is the bridge data-point (RFC 055 GPU codegen path can carry the
 * n=6 hex-lattice motif), not a perf number. Larger grids + perf
 * benchmark are deferred to RFC 070 P2+.
 */
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <unistd.h>

#define N_Q 8
#define N_R 8
#define N_CELLS (N_Q * N_R)

#define CHECK(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA error %d at %s:%d: %s\n", (int)e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

static char *slurp(const char *path) {
    FILE *fp = fopen(path, "rb");
    if (!fp) { perror(path); return NULL; }
    fseek(fp, 0, SEEK_END);
    long n = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *buf = (char *)malloc(n + 1);
    if (!buf) { fclose(fp); return NULL; }
    if (fread(buf, 1, n, fp) != (size_t)n) { fclose(fp); free(buf); return NULL; }
    buf[n] = 0;
    fclose(fp);
    return buf;
}

/* Compute CPU FP32 reference -- MUST mirror the PTX accumulation order
 * exactly: self, east, west, ne, sw, se, nw. Each add is a separate
 * IEEE 754 binary32 op; no FMA contract since each accumulate is just
 * an add (no multiply). */
static void cpu_ref(const float *in, float *out) {
    for (int q = 0; q < N_Q; ++q) {
        for (int r = 0; r < N_R; ++r) {
            /* Same clamping rule as PTX: out-of-bounds neighbor -> self. */
            int q_e = (q + 1 < N_Q) ? (q + 1) : q;
            int q_w = (q - 1 >= 0)  ? (q - 1) : q;
            int r_ne = (r + 1 < N_R) ? (r + 1) : r;
            int r_sw = (r - 1 >= 0)  ? (r - 1) : r;
            int self_i = q   * N_R + r;
            int e_i    = q_e * N_R + r;
            int w_i    = q_w * N_R + r;
            int ne_i   = q   * N_R + r_ne;
            int sw_i   = q   * N_R + r_sw;
            int se_i   = q_e * N_R + r_sw;
            int nw_i   = q_w * N_R + r_ne;
            float acc = in[self_i];
            acc = acc + in[e_i];
            acc = acc + in[w_i];
            acc = acc + in[ne_i];
            acc = acc + in[sw_i];
            acc = acc + in[se_i];
            acc = acc + in[nw_i];
            out[self_i] = acc;
        }
    }
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s hex_neighbor.ptx\n", argv[0]);
        return 2;
    }
    const char *ptx_path = argv[1];

    char *ptx = slurp(ptx_path);
    if (!ptx) {
        fprintf(stderr, "PTX read failed: %s\n", ptx_path);
        return 1;
    }

    CHECK(cuInit(0));
    CUdevice dev;
    CHECK(cuDeviceGet(&dev, 0));
    int sm_major = 0, sm_minor = 0;
    CHECK(cuDeviceGetAttribute(&sm_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CHECK(cuDeviceGetAttribute(&sm_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    char dev_name[256] = {0};
    CHECK(cuDeviceGetName(dev_name, sizeof(dev_name) - 1, dev));
    int drv_ver = 0;
    CHECK(cuDriverGetVersion(&drv_ver));

    CUcontext ctx;
    CHECK(cuCtxCreate(&ctx, 0, dev));

    /* JIT-load PTX with error log captured. */
    static char err_log[8192], info_log[8192];
    err_log[0] = 0; info_log[0] = 0;
    CUjit_option opts[4] = {
        CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_INFO_LOG_BUFFER,  CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES };
    void *vals[4] = {
        err_log, (void *)(size_t)sizeof(err_log),
        info_log, (void *)(size_t)sizeof(info_log) };

    CUmodule mod;
    CUresult cr = cuModuleLoadDataEx(&mod, ptx, 4, opts, vals);
    if (cr != CUDA_SUCCESS) {
        fprintf(stderr, "PTX JIT failed: %s\n", err_log[0] ? err_log : "(empty)");
        return 4;
    }

    CUfunction kfn;
    CHECK(cuModuleGetFunction(&kfn, mod, "hex_neighbor"));

    /* Inputs: deterministic, integer-valued in FP32. */
    float h_in[N_CELLS];
    float h_out_gpu[N_CELLS];
    float h_out_ref[N_CELLS];
    for (int i = 0; i < N_CELLS; ++i) {
        h_in[i] = (float)i;
        h_out_gpu[i] = 0.0f;
        h_out_ref[i] = 0.0f;
    }

    cpu_ref(h_in, h_out_ref);

    CUdeviceptr d_in, d_out;
    CHECK(cuMemAlloc(&d_in, N_CELLS * sizeof(float)));
    CHECK(cuMemAlloc(&d_out, N_CELLS * sizeof(float)));
    CHECK(cuMemcpyHtoD(d_in, h_in, N_CELLS * sizeof(float)));
    CHECK(cuMemsetD8(d_out, 0, N_CELLS * sizeof(float)));

    void *kargs[2] = { &d_in, &d_out };
    CHECK(cuLaunchKernel(kfn,
        /*grid*/ 1, 1, 1,
        /*block*/ N_CELLS, 1, 1,
        /*shared*/ 0, NULL, kargs, NULL));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(h_out_gpu, d_out, N_CELLS * sizeof(float)));

    /* Numeric gate -- byte-eq, max abs delta = 0. */
    float max_delta = 0.0f;
    int mismatches = 0;
    for (int i = 0; i < N_CELLS; ++i) {
        float d = h_out_gpu[i] - h_out_ref[i];
        if (d < 0.0f) d = -d;
        if (d != 0.0f) {
            ++mismatches;
            if (d > max_delta) max_delta = d;
        }
    }
    int pass = (max_delta == 0.0f && mismatches == 0) ? 1 : 0;

    printf("RFC 070 P1 hex-neighbor smoke\n");
    printf("  device: %s (sm_%d%d)\n", dev_name, sm_major, sm_minor);
    printf("  driver: %d\n", drv_ver);
    printf("  grid: %dx%d = %d cells, 1 block, %d threads\n",
        N_Q, N_R, N_CELLS, N_CELLS);
    printf("F-RFC070-HEX-NEIGHBOR-NUMERIC %s -- max|d|=%g mismatches=%d/%d\n",
        pass ? "PASS" : "FAIL", max_delta, mismatches, N_CELLS);

    /* Dump first 16 outputs for sanity. */
    printf("  out[0..15]: ");
    for (int i = 0; i < 16 && i < N_CELLS; ++i) printf("%g ", h_out_gpu[i]);
    printf("\n");
    printf("  ref[0..15]: ");
    for (int i = 0; i < 16 && i < N_CELLS; ++i) printf("%g ", h_out_ref[i]);
    printf("\n");

    char hostname[256] = {0};
    gethostname(hostname, sizeof(hostname) - 1);

    FILE *rj = fopen("result.json", "w");
    if (rj) {
        fprintf(rj, "{\n");
        fprintf(rj, "  \"rfc\": \"070-P1-hex-neighbor-smoke\",\n");
        fprintf(rj, "  \"kernel\": \"hex_neighbor\",\n");
        fprintf(rj, "  \"falsifier\": \"F-RFC070-HEX-NEIGHBOR-NUMERIC\",\n");
        fprintf(rj, "  \"grid\": {\"q\":%d,\"r\":%d,\"cells\":%d},\n",
            N_Q, N_R, N_CELLS);
        fprintf(rj, "  \"host\": {\n");
        fprintf(rj, "    \"hostname\": \"%s\",\n", hostname);
        fprintf(rj, "    \"device\": \"%s\",\n", dev_name);
        fprintf(rj, "    \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
        fprintf(rj, "    \"driver\": %d\n", drv_ver);
        fprintf(rj, "  },\n");
        fprintf(rj, "  \"numeric\": {\n");
        fprintf(rj, "    \"verdict\": \"%s\",\n", pass ? "PASS" : "FAIL");
        fprintf(rj, "    \"max_delta\": %g,\n", max_delta);
        fprintf(rj, "    \"mismatches\": %d,\n", mismatches);
        fprintf(rj, "    \"n_cells\": %d\n", N_CELLS);
        fprintf(rj, "  }\n");
        fprintf(rj, "}\n");
        fclose(rj);
    }

    cuMemFree(d_in);
    cuMemFree(d_out);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    free(ptx);

    return pass ? 0 : 7;
}
