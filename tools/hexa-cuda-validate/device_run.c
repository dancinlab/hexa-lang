// device_run.c — load hexa-emitted PTX via the CUDA Driver API, launch on a
// real H100, verify output == CPU reference.  HEXA-CUDA D2 silicon validation.
//
//   usage: ./device_run <kernel.ptx> <entry> {vecadd|saxpy}
//
// Build: gcc device_run.c -o device_run -I/usr/local/cuda/include \
//            -L/usr/local/cuda/lib64/stubs -lcuda
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define CK(x) do { CUresult _r = (x); if (_r != CUDA_SUCCESS) { \
    const char *_s; cuGetErrorString(_r, &_s); \
    fprintf(stderr, "CUDA ERROR %d (%s) at %s:%d\n", _r, _s, __FILE__, __LINE__); \
    exit(2);} } while(0)

static char *slurp(const char *p) {
    FILE *f = fopen(p, "rb"); if (!f) { perror("fopen"); exit(2); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *b = malloc(n + 1); fread(b, 1, n, f); b[n] = 0; fclose(f); return b;
}

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s <ptx> <entry> <vecadd|saxpy>\n", argv[0]); return 2; }
    const char *ptx_path = argv[1];
    const char *entry    = argv[2];
    const char *which    = argv[3];

    const long N = 1<<20;          // 1,048,576 elements
    const double ALPHA = 2.5;

    double *a = malloc(N*sizeof(double));
    double *b = malloc(N*sizeof(double));
    double *out = malloc(N*sizeof(double));
    double *ref = malloc(N*sizeof(double));
    for (long i = 0; i < N; i++) {
        a[i] = (double)(i % 1000) * 0.5 + 1.0;     // y / a
        b[i] = (double)((i*7) % 997) * 0.25 - 3.0; // x / b
    }
    int is_saxpy = (strcmp(which, "saxpy") == 0);
    if (is_saxpy) {
        // y = alpha*x + y ; here a=y, b=x
        for (long i = 0; i < N; i++) ref[i] = ALPHA * b[i] + a[i];
    } else {
        for (long i = 0; i < N; i++) ref[i] = a[i] + b[i];
    }

    CK(cuInit(0));
    CUdevice dev; CK(cuDeviceGet(&dev, 0));
    char name[256]; CK(cuDeviceGetName(name, sizeof(name), dev));
    int cc_major=0, cc_minor=0;
    CK(cuDeviceGetAttribute(&cc_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CK(cuDeviceGetAttribute(&cc_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    printf("DEVICE: %s  sm_%d%d\n", name, cc_major, cc_minor);
    CUcontext ctx; CK(cuCtxCreate(&ctx, 0, dev));

    char *ptx = slurp(ptx_path);
    CUmodule mod; CK(cuModuleLoad(&mod, ptx_path));
    CUfunction fn; CK(cuModuleGetFunction(&fn, mod, entry));
    printf("LOADED: entry=%s from %s\n", entry, ptx_path);

    CUdeviceptr dA, dB, dOut, dPar;
    CK(cuMemAlloc(&dA, N*sizeof(double)));
    CK(cuMemAlloc(&dB, N*sizeof(double)));
    CK(cuMemAlloc(&dOut, N*sizeof(double)));
    CK(cuMemAlloc(&dPar, 1*sizeof(double)));
    CK(cuMemcpyHtoD(dA, a, N*sizeof(double)));
    CK(cuMemcpyHtoD(dB, b, N*sizeof(double)));
    double par0 = ALPHA; CK(cuMemcpyHtoD(dPar, &par0, sizeof(double)));
    // for saxpy y is in/out -> seed dOut path: kernel writes into first arg.
    // vec_add(a,b,out,n): out is 3rd arg. saxpy(y,x,par,n): y is 1st arg (in/out).
    if (is_saxpy) CK(cuMemcpyHtoD(dA, a, N*sizeof(double))); // y = a

    int block = 256;
    int grid = (N + block - 1) / block;
    long n = N;

    void *args_vecadd[] = { &dA, &dB, &dOut, &n };
    void *args_saxpy[]  = { &dA, &dB, &dPar, &n };  // y=dA, x=dB, par=dPar
    void **args = is_saxpy ? args_saxpy : args_vecadd;

    CK(cuLaunchKernel(fn, grid,1,1, block,1,1, 0, 0, args, 0));
    CK(cuCtxSynchronize());

    if (is_saxpy) CK(cuMemcpyDtoH(out, dA, N*sizeof(double)));   // y written in place
    else          CK(cuMemcpyDtoH(out, dOut, N*sizeof(double)));

    long bad = 0; double maxerr = 0;
    for (long i = 0; i < N; i++) {
        double e = fabs(out[i] - ref[i]);
        if (e > maxerr) maxerr = e;
        if (e > 1e-9) { if (bad < 5) fprintf(stderr, "  mismatch[%ld] got=%.6f ref=%.6f\n", i, out[i], ref[i]); bad++; }
    }
    printf("CHECK: N=%ld kernel=%s maxerr=%.3e mismatches=%ld\n", N, which, maxerr, bad);
    printf("SAMPLE: out[0]=%.6f ref[0]=%.6f  out[N-1]=%.6f ref[N-1]=%.6f\n",
           out[0], ref[0], out[N-1], ref[N-1]);
    if (bad == 0) { printf("RESULT: %s DEVICE-CORRECT (output == CPU reference)\n", which); return 0; }
    printf("RESULT: %s DEVICE-MISMATCH (%ld bad)\n", which, bad);
    return 1;
}
