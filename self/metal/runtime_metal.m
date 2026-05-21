/* runtime_metal.m — flame Metal integration step 2 of 5
 *                    (RFC 075 P5, METAL_INTEGRATION.md gap #2)
 *
 * Provides the `_hx_metal_farr_matmul_gpu` extern forward-decl'd by
 * self/runtime.c under `#if defined(__APPLE__) && defined(HEXA_METAL)`
 * (N15 dim-gate, commit 6315b59f). When -DHEXA_METAL is set on a macOS
 * build, this TU compiles + links with `-framework Metal
 * -framework MetalPerformanceShaders -framework Foundation`, giving the
 * runtime's farr_matmul Metal-accelerated path through Apple
 * MPSMatrixMultiplication (FP32 SGEMM, Apple-canonical cuBLAS-equivalent).
 *
 * The body mirrors the proven self/native/hxmetal_macos.m::hxmetal_matmul
 * template (lazy-init device + queue, MPSMatrixDescriptor + MPSMatrix +
 * MPSMatrixMultiplication, MTLResourceStorageModeShared zero-copy
 * unified-memory buffers, single command buffer commit + wait); the
 * delta vs that template is the **FP64↔FP32 cast at the host boundary**
 * — `_hx_farr_table` is packed FP64, but Apple GPUs have no FP64 compute
 * shader path, so this shim down-casts the A,B operands to FP32 before
 * the matmul and up-casts the C result back to FP64 in the caller's farr
 * slot. The runtime.c side gates by shape (M*K > 8192 || K*N > 8192) and
 * emits a once-per-process WARN about the precision loss (~29 mantissa
 * bits per element).
 *
 * Math contract:
 *   A is row-major M×K (FP64), B is row-major K×N (FP64),
 *   C row-major M×N (FP64) is allocated host-side by hexa_farr_zeros
 *   ahead of this call (see runtime.c::hexa_farr_matmul).
 *   We down-cast A,B → FP32, run MPS row-major C_f32 = A_f32 · B_f32,
 *   up-cast C_f32 → FP64 in ce->buf.
 *
 *   Reproducible bit-identity is NOT claimed. The CPU ikj fallback
 *   (FP64 fma) at runtime.c:6220-6240 is the bit-exact path; this Metal
 *   path is the d768-class hot-path lever where ~29 mantissa bits of
 *   precision loss is acceptable (decoder forward, attention/ffn).
 *
 * Error handling: every failure path returns -1 + a one-line NSLog so
 * the runtime.c caller falls through to the CPU ikj loop (safe). No
 * silent fallbacks; no fake results. -1 on no Metal device, MPS init
 * error, OOM, bad ids/shapes, host buf NULL, or len-mismatch.
 *
 * Build (standalone object file, dropped into the runtime.c-as-TU build):
 *   xcrun --sdk macosx clang -c -O3 -fobjc-arc \
 *       -framework Metal -framework MetalPerformanceShaders \
 *       self/metal/runtime_metal.m -o build/runtime_metal.o
 *
 * Link contract (matches HEXA_CUDA / runtime_cuda.c pattern):
 *   clang <stage.c> self/runtime.c build/runtime_metal.o \
 *       -DHEXA_METAL -framework Metal -framework MetalPerformanceShaders \
 *       -framework Foundation -o <out>
 *
 * Honest scope (@D g3, METAL_INTEGRATION.md):
 *   - FP32 only — FP64 down-cast is the elephant; pre-req #1 (HX_FARR32
 *     FP32 farr table) lands in a separate cycle and eliminates the
 *     per-call cast cost.
 *   - MPS is a closed-library blackbox — no whole-program-fusion lever
 *     here. The long-term hexa-native Metal codegen path lives in
 *     compiler/codegen/metal_target.hexa (separate N5 lane).
 *   - This file does NOT call hxmetal_init / share state with
 *     self/native/hxmetal_macos.m. The two shims live in parallel: the
 *     macos.m one is the user-facing dylib (`hexa metal …` verbs); this
 *     one is the runtime-internal MPS dispatcher for farr_matmul. They
 *     can coexist (each owns its own MTLDevice / MTLCommandQueue) at the
 *     cost of one extra Metal-context worth of memory — acceptable on
 *     Apple Silicon unified memory.
 */

#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Mirror of the HexaFarrEntry layout in self/runtime.c (line ~4486). The
 * runtime.c side exports `_hx_farr_table` and `_hx_farr_count` as
 * non-static under -DHEXA_METAL (mirrors the existing HEXA_CUDA guard);
 * we re-declare the struct here so we can index into the table without
 * pulling in runtime.h (which redefines libc str/mem macros and would
 * collide with the Objective-C / Foundation imports above). */
typedef struct {
    double*  buf;
    int64_t  len;
    void*    d_buf;
    int      loc;
    int      pinned;
    int      dirty_host;
    int      dirty_dev;
} HexaFarrEntry;
extern HexaFarrEntry* _hx_farr_table;
extern int64_t        _hx_farr_count;

/* METAL_INTEGRATION.md step 3 of 5 (2026-05-21): mirror of the
 * HexaFarr32Entry layout in self/runtime.c (added in the step-3 cycle).
 * The runtime.c side exports _hx_farr32_table/_count as non-static under
 * -DHEXA_METAL (same gate pattern as _hx_farr_table). Float storage =
 * no FP64→FP32 down-cast at the dispatch boundary; the entire pipeline
 * (host buffer → MPSMatrix → result) stays in MPSDataTypeFloat32. */
typedef struct {
    float*   buf;
    int64_t  len;
    void*    d_buf;
    int      loc;
    int      pinned;
    int      dirty_host;
    int      dirty_dev;
} HexaFarr32Entry;
extern HexaFarr32Entry* _hx_farr32_table;
extern int64_t          _hx_farr32_count;

/* ═══════════════════════════════════════════════════════════════════
 * Global state — lazy-init on first call (matches hxmetal_macos.m
 * convention; self-contained, owns its own device + queue).
 * ═══════════════════════════════════════════════════════════════════ */
static id<MTLDevice>       g_metal_device = nil;
static id<MTLCommandQueue> g_metal_queue  = nil;
static int                 g_metal_init_done  = 0;
static int                 g_metal_init_error = 0;

/* Returns 0 on success, -1 on any failure. Idempotent. */
static int _metal_ensure_init(void) {
    if (g_metal_init_done) return g_metal_init_error;
    g_metal_init_done = 1;
    g_metal_device = MTLCreateSystemDefaultDevice();
    if (!g_metal_device) {
        fprintf(stderr, "[metal] no MTLCreateSystemDefaultDevice\n");
        g_metal_init_error = -1;
        return -1;
    }
    g_metal_queue = [g_metal_device newCommandQueue];
    if (!g_metal_queue) {
        fprintf(stderr, "[metal] newCommandQueue failed\n");
        g_metal_device = nil;
        g_metal_init_error = -1;
        return -1;
    }
    g_metal_init_error = 0;
    return 0;
}

/* ═══════════════════════════════════════════════════════════════════
 * _hx_metal_farr_matmul_gpu(A, M, K, B, N, C) — MPS SGEMM row-major
 *   C[M,N] = A[M,K] · B[K,N]  (FP32 internal; FP64 host buffers
 *   down-cast on upload, up-cast on download).
 *
 *   - Caller (self/runtime.c::hexa_farr_matmul) has already allocated
 *     c_id host buf len = M·N via hexa_farr_zeros (FP64).
 *   - We allocate three temporary FP32 MTLBuffers (storageModeShared
 *     for zero-copy on Apple Silicon unified memory), copy A,B into
 *     them as float, run MPSMatrixMultiplication, and copy the result
 *     back into ce->buf as double.
 *   - Returns 0 ok / -1 err. Any -1 → runtime.c falls through to the
 *     CPU ikj fallback (safe).
 *
 * Row-major contract: MPSMatrixDescriptor's rowBytes = N * sizeof(float)
 * for an M×N matrix matches the runtime.c row-major convention exactly
 * (each row is N contiguous floats; row stride = N*4 bytes). This is
 * the same convention as the proven host_mps_gemm.swift baseline.
 * ═══════════════════════════════════════════════════════════════════ */
int _hx_metal_farr_matmul_gpu(int64_t a_id, int64_t M, int64_t K,
                              int64_t b_id, int64_t N,
                              int64_t c_id) {
    if (_metal_ensure_init() != 0) return -1;
    if (a_id < 0 || b_id < 0 || c_id < 0) {
        fprintf(stderr, "[metal] matmul: bad ids %lld %lld %lld\n",
                (long long)a_id, (long long)b_id, (long long)c_id);
        return -1;
    }
    if (a_id >= _hx_farr_count || b_id >= _hx_farr_count ||
        c_id >= _hx_farr_count) {
        fprintf(stderr, "[metal] matmul: ids out of range "
                        "(a=%lld b=%lld c=%lld count=%lld)\n",
                (long long)a_id, (long long)b_id, (long long)c_id,
                (long long)_hx_farr_count);
        return -1;
    }
    if (M <= 0 || K <= 0 || N <= 0) {
        fprintf(stderr, "[metal] matmul: bad shape M=%lld K=%lld N=%lld\n",
                (long long)M, (long long)K, (long long)N);
        return -1;
    }
    HexaFarrEntry* ae = &_hx_farr_table[a_id];
    HexaFarrEntry* be = &_hx_farr_table[b_id];
    HexaFarrEntry* ce = &_hx_farr_table[c_id];
    if (!ae->buf || !be->buf || !ce->buf) {
        fprintf(stderr, "[metal] matmul: NULL host buf\n");
        return -1;
    }
    if (ae->len < M * K || be->len < K * N || ce->len < M * N) {
        fprintf(stderr, "[metal] matmul: host len mismatch "
                        "(a=%lld<%lld b=%lld<%lld c=%lld<%lld)\n",
                (long long)ae->len, (long long)(M*K),
                (long long)be->len, (long long)(K*N),
                (long long)ce->len, (long long)(M*N));
        return -1;
    }

    @autoreleasepool {
        NSUInteger a_count = (NSUInteger)(M * K);
        NSUInteger b_count = (NSUInteger)(K * N);
        NSUInteger c_count = (NSUInteger)(M * N);
        NSUInteger a_bytes = a_count * sizeof(float);
        NSUInteger b_bytes = b_count * sizeof(float);
        NSUInteger c_bytes = c_count * sizeof(float);

        /* Allocate fresh MTLBuffers (storageModeShared = unified-memory
         * mapped, no explicit copy on Apple Silicon). Down-cast inputs
         * FP64→FP32 directly into the buffer's host-visible contents. */
        id<MTLBuffer> a_buf = [g_metal_device newBufferWithLength:a_bytes
                                                          options:MTLResourceStorageModeShared];
        id<MTLBuffer> b_buf = [g_metal_device newBufferWithLength:b_bytes
                                                          options:MTLResourceStorageModeShared];
        id<MTLBuffer> c_buf = [g_metal_device newBufferWithLength:c_bytes
                                                          options:MTLResourceStorageModeShared];
        if (!a_buf || !b_buf || !c_buf) {
            fprintf(stderr, "[metal] matmul: newBufferWithLength OOM "
                            "(a=%llu b=%llu c=%llu bytes)\n",
                    (unsigned long long)a_bytes,
                    (unsigned long long)b_bytes,
                    (unsigned long long)c_bytes);
            return -1;
        }

        float* a32 = (float*)[a_buf contents];
        float* b32 = (float*)[b_buf contents];
        float* c32 = (float*)[c_buf contents];
        const double* a64 = ae->buf;
        const double* b64 = be->buf;
        /* FP64 → FP32 down-cast. ~29 mantissa bits lost per element;
         * this is the documented carve-out (runtime.c warn). */
        for (NSUInteger i = 0; i < a_count; i++) a32[i] = (float)a64[i];
        for (NSUInteger i = 0; i < b_count; i++) b32[i] = (float)b64[i];
        /* C left zero-init (storageModeShared buffers are zeroed by
         * Metal on alloc; matches host_mps_gemm.swift convention). */

        MPSMatrixDescriptor* a_desc =
            [MPSMatrixDescriptor matrixDescriptorWithRows:(NSUInteger)M
                                                  columns:(NSUInteger)K
                                                 rowBytes:(NSUInteger)(K * sizeof(float))
                                                 dataType:MPSDataTypeFloat32];
        MPSMatrixDescriptor* b_desc =
            [MPSMatrixDescriptor matrixDescriptorWithRows:(NSUInteger)K
                                                  columns:(NSUInteger)N
                                                 rowBytes:(NSUInteger)(N * sizeof(float))
                                                 dataType:MPSDataTypeFloat32];
        MPSMatrixDescriptor* c_desc =
            [MPSMatrixDescriptor matrixDescriptorWithRows:(NSUInteger)M
                                                  columns:(NSUInteger)N
                                                 rowBytes:(NSUInteger)(N * sizeof(float))
                                                 dataType:MPSDataTypeFloat32];

        MPSMatrix* a_mat = [[MPSMatrix alloc] initWithBuffer:a_buf descriptor:a_desc];
        MPSMatrix* b_mat = [[MPSMatrix alloc] initWithBuffer:b_buf descriptor:b_desc];
        MPSMatrix* c_mat = [[MPSMatrix alloc] initWithBuffer:c_buf descriptor:c_desc];
        if (!a_mat || !b_mat || !c_mat) {
            fprintf(stderr, "[metal] matmul: MPSMatrix init failed\n");
            return -1;
        }

        MPSMatrixMultiplication* mm =
            [[MPSMatrixMultiplication alloc] initWithDevice:g_metal_device
                                              transposeLeft:NO
                                             transposeRight:NO
                                                 resultRows:(NSUInteger)M
                                              resultColumns:(NSUInteger)N
                                            interiorColumns:(NSUInteger)K
                                                      alpha:1.0
                                                       beta:0.0];
        if (!mm) {
            fprintf(stderr, "[metal] matmul: MPSMatrixMultiplication init failed\n");
            return -1;
        }

        id<MTLCommandBuffer> cmd = [g_metal_queue commandBuffer];
        if (!cmd) {
            fprintf(stderr, "[metal] matmul: commandBuffer alloc failed\n");
            return -1;
        }
        [mm encodeToCommandBuffer:cmd
                       leftMatrix:a_mat
                      rightMatrix:b_mat
                     resultMatrix:c_mat];
        [cmd commit];
        [cmd waitUntilCompleted];
        if (cmd.status != MTLCommandBufferStatusCompleted) {
            fprintf(stderr, "[metal] matmul: command buffer status=%ld "
                            "(err=%s)\n",
                    (long)cmd.status,
                    cmd.error ? [[cmd.error description] UTF8String]
                              : "(nil)");
            return -1;
        }

        /* FP32 → FP64 up-cast into the caller's pre-allocated C farr
         * host buffer. */
        double* c64 = ce->buf;
        for (NSUInteger i = 0; i < c_count; i++) c64[i] = (double)c32[i];
    } /* @autoreleasepool */

    return 0;
}

/* ═══════════════════════════════════════════════════════════════════
 * METAL_INTEGRATION.md step 3 of 5 (2026-05-21): native FP32 SGEMM.
 *
 * _hx_metal_farr32_matmul_gpu(A, M, K, B, N, C) — same row-major
 *   contract as the FP64 variant above, but the host buffers are
 *   already float (HexaFarr32Entry.buf) — NO down-cast, NO up-cast.
 *
 *   This is the gap-#1 closer in METAL_INTEGRATION.md: the FP64
 *   variant above loses ~29 mantissa bits per element on the host-
 *   boundary cast. This FP32 variant is bit-identical to a pure-CPU
 *   FP32 SGEMM (modulo MPS's internal reduce ordering, which is
 *   tile-major and matches the host_mps_gemm.swift baseline).
 *
 *   Memcpy strategy: storageModeShared MTLBuffers on Apple Silicon
 *   are unified-memory mapped, but the safe portable pattern is
 *   still a memcpy in (host → buffer.contents). The cost is N*sizeof
 *   (float) bytes per operand vs the FP64 variant's 2× cast loop;
 *   same bandwidth budget, half the work.
 *
 *   Caller (self/runtime.c::hexa_farr32_matmul) has already allocated
 *   c_id host buf len = M·N via hexa_farr32_zeros (FP32).
 *
 *   Returns 0 ok / -1 err. Any -1 → runtime.c falls through to the
 *   CPU ikj fallback (safe).
 * ═══════════════════════════════════════════════════════════════════ */
int _hx_metal_farr32_matmul_gpu(int64_t a_id, int64_t M, int64_t K,
                                int64_t b_id, int64_t N,
                                int64_t c_id) {
    if (_metal_ensure_init() != 0) return -1;
    if (a_id < 0 || b_id < 0 || c_id < 0) {
        fprintf(stderr, "[metal] farr32_matmul: bad ids %lld %lld %lld\n",
                (long long)a_id, (long long)b_id, (long long)c_id);
        return -1;
    }
    if (a_id >= _hx_farr32_count || b_id >= _hx_farr32_count ||
        c_id >= _hx_farr32_count) {
        fprintf(stderr, "[metal] farr32_matmul: ids out of range "
                        "(a=%lld b=%lld c=%lld count=%lld)\n",
                (long long)a_id, (long long)b_id, (long long)c_id,
                (long long)_hx_farr32_count);
        return -1;
    }
    if (M <= 0 || K <= 0 || N <= 0) {
        fprintf(stderr, "[metal] farr32_matmul: bad shape "
                        "M=%lld K=%lld N=%lld\n",
                (long long)M, (long long)K, (long long)N);
        return -1;
    }
    HexaFarr32Entry* ae = &_hx_farr32_table[a_id];
    HexaFarr32Entry* be = &_hx_farr32_table[b_id];
    HexaFarr32Entry* ce = &_hx_farr32_table[c_id];
    if (!ae->buf || !be->buf || !ce->buf) {
        fprintf(stderr, "[metal] farr32_matmul: NULL host buf\n");
        return -1;
    }
    if (ae->len < M * K || be->len < K * N || ce->len < M * N) {
        fprintf(stderr, "[metal] farr32_matmul: host len mismatch "
                        "(a=%lld<%lld b=%lld<%lld c=%lld<%lld)\n",
                (long long)ae->len, (long long)(M*K),
                (long long)be->len, (long long)(K*N),
                (long long)ce->len, (long long)(M*N));
        return -1;
    }

    @autoreleasepool {
        NSUInteger a_bytes = (NSUInteger)(M * K) * sizeof(float);
        NSUInteger b_bytes = (NSUInteger)(K * N) * sizeof(float);
        NSUInteger c_bytes = (NSUInteger)(M * N) * sizeof(float);

        id<MTLBuffer> a_buf = [g_metal_device newBufferWithLength:a_bytes
                                                          options:MTLResourceStorageModeShared];
        id<MTLBuffer> b_buf = [g_metal_device newBufferWithLength:b_bytes
                                                          options:MTLResourceStorageModeShared];
        id<MTLBuffer> c_buf = [g_metal_device newBufferWithLength:c_bytes
                                                          options:MTLResourceStorageModeShared];
        if (!a_buf || !b_buf || !c_buf) {
            fprintf(stderr, "[metal] farr32_matmul: newBufferWithLength OOM "
                            "(a=%llu b=%llu c=%llu bytes)\n",
                    (unsigned long long)a_bytes,
                    (unsigned long long)b_bytes,
                    (unsigned long long)c_bytes);
            return -1;
        }

        /* Native FP32: straight memcpy host → MTLBuffer.contents, no
         * per-element cast. This is the step-3 win over the FP64 path
         * (gap #1 of METAL_INTEGRATION.md closed). */
        memcpy([a_buf contents], ae->buf, a_bytes);
        memcpy([b_buf contents], be->buf, b_bytes);
        /* C zero-init: storageModeShared buffers are zeroed by Metal on
         * alloc; matches host_mps_gemm.swift convention. */

        MPSMatrixDescriptor* a_desc =
            [MPSMatrixDescriptor matrixDescriptorWithRows:(NSUInteger)M
                                                  columns:(NSUInteger)K
                                                 rowBytes:(NSUInteger)(K * sizeof(float))
                                                 dataType:MPSDataTypeFloat32];
        MPSMatrixDescriptor* b_desc =
            [MPSMatrixDescriptor matrixDescriptorWithRows:(NSUInteger)K
                                                  columns:(NSUInteger)N
                                                 rowBytes:(NSUInteger)(N * sizeof(float))
                                                 dataType:MPSDataTypeFloat32];
        MPSMatrixDescriptor* c_desc =
            [MPSMatrixDescriptor matrixDescriptorWithRows:(NSUInteger)M
                                                  columns:(NSUInteger)N
                                                 rowBytes:(NSUInteger)(N * sizeof(float))
                                                 dataType:MPSDataTypeFloat32];

        MPSMatrix* a_mat = [[MPSMatrix alloc] initWithBuffer:a_buf descriptor:a_desc];
        MPSMatrix* b_mat = [[MPSMatrix alloc] initWithBuffer:b_buf descriptor:b_desc];
        MPSMatrix* c_mat = [[MPSMatrix alloc] initWithBuffer:c_buf descriptor:c_desc];
        if (!a_mat || !b_mat || !c_mat) {
            fprintf(stderr, "[metal] farr32_matmul: MPSMatrix init failed\n");
            return -1;
        }

        MPSMatrixMultiplication* mm =
            [[MPSMatrixMultiplication alloc] initWithDevice:g_metal_device
                                              transposeLeft:NO
                                             transposeRight:NO
                                                 resultRows:(NSUInteger)M
                                              resultColumns:(NSUInteger)N
                                            interiorColumns:(NSUInteger)K
                                                      alpha:1.0
                                                       beta:0.0];
        if (!mm) {
            fprintf(stderr, "[metal] farr32_matmul: "
                            "MPSMatrixMultiplication init failed\n");
            return -1;
        }

        id<MTLCommandBuffer> cmd = [g_metal_queue commandBuffer];
        if (!cmd) {
            fprintf(stderr, "[metal] farr32_matmul: "
                            "commandBuffer alloc failed\n");
            return -1;
        }
        [mm encodeToCommandBuffer:cmd
                       leftMatrix:a_mat
                      rightMatrix:b_mat
                     resultMatrix:c_mat];
        [cmd commit];
        [cmd waitUntilCompleted];
        if (cmd.status != MTLCommandBufferStatusCompleted) {
            fprintf(stderr, "[metal] farr32_matmul: command buffer "
                            "status=%ld (err=%s)\n",
                    (long)cmd.status,
                    cmd.error ? [[cmd.error description] UTF8String]
                              : "(nil)");
            return -1;
        }

        /* Native FP32 result: straight memcpy MTLBuffer.contents → host.
         * No up-cast. Bit-identical to a pure-CPU FP32 SGEMM modulo MPS
         * tile-major reduce ordering. */
        memcpy(ce->buf, [c_buf contents], c_bytes);
    } /* @autoreleasepool */

    return 0;
}

/* ═══════════════════════════════════════════════════════════════════
 * METAL_INTEGRATION.md step 4 of 5 (2026-05-21): native FP32 SGEMM
 * with B transposed on the right.
 *
 * _hx_metal_farr32_matmul_NT_b_gpu(A, M, K, B, N, C) —
 *   C[M, N] = A[M, K] · B[N, K]^T   (B as passed is N×K row-major;
 *                                     MPS transposes internally)
 *   C[i, j] = sum_{k=0..K-1} A[i, k] * B[j, k]
 *
 *   This is the bwd-input matmul shape for ag_linear via
 *   matmul_bwd_auto (stdlib/flame/ag_tape.hexa:630). Same row-major
 *   FP32 contract as _hx_metal_farr32_matmul_gpu, but the MPS
 *   constructor flips transposeRight to YES.
 *
 *   Apple docs reference:
 *     MPSMatrixMultiplication.init(device:transposeLeft:transposeRight:
 *                                  resultRows:resultColumns:
 *                                  interiorColumns:alpha:beta:)
 *   When transposeRight=YES, MPS interprets the right matrix as
 *   logically (interiorColumns × resultColumns) = (K × N) but
 *   PHYSICALLY laid out as N rows × K columns row-major — exactly
 *   matching B's N×K row-major storage in _hx_farr32_table.
 *
 *   Memcpy strategy: same as the no-T variant — straight memcpy host
 *   float buf → MTLBuffer.contents → MPS → memcpy back. No transpose
 *   on the host; MPS handles it via its tile scheduler.
 *
 *   Returns 0 ok / -1 err. Any -1 → runtime.c falls through to the
 *   CPU ikj-NT fallback (safe).
 * ═══════════════════════════════════════════════════════════════════ */
int _hx_metal_farr32_matmul_NT_b_gpu(int64_t a_id, int64_t M, int64_t K,
                                     int64_t b_id, int64_t N,
                                     int64_t c_id) {
    if (_metal_ensure_init() != 0) return -1;
    if (a_id < 0 || b_id < 0 || c_id < 0) {
        fprintf(stderr, "[metal] farr32_matmul_NT_b: bad ids %lld %lld %lld\n",
                (long long)a_id, (long long)b_id, (long long)c_id);
        return -1;
    }
    if (a_id >= _hx_farr32_count || b_id >= _hx_farr32_count ||
        c_id >= _hx_farr32_count) {
        fprintf(stderr, "[metal] farr32_matmul_NT_b: ids out of range "
                        "(a=%lld b=%lld c=%lld count=%lld)\n",
                (long long)a_id, (long long)b_id, (long long)c_id,
                (long long)_hx_farr32_count);
        return -1;
    }
    if (M <= 0 || K <= 0 || N <= 0) {
        fprintf(stderr, "[metal] farr32_matmul_NT_b: bad shape "
                        "M=%lld K=%lld N=%lld\n",
                (long long)M, (long long)K, (long long)N);
        return -1;
    }
    HexaFarr32Entry* ae = &_hx_farr32_table[a_id];
    HexaFarr32Entry* be = &_hx_farr32_table[b_id];
    HexaFarr32Entry* ce = &_hx_farr32_table[c_id];
    if (!ae->buf || !be->buf || !ce->buf) {
        fprintf(stderr, "[metal] farr32_matmul_NT_b: NULL host buf\n");
        return -1;
    }
    /* B is N×K row-major (transposed view of K×N original). Validate
     * against N*K, not K*N. */
    if (ae->len < M * K || be->len < N * K || ce->len < M * N) {
        fprintf(stderr, "[metal] farr32_matmul_NT_b: host len mismatch "
                        "(a=%lld<%lld b=%lld<%lld c=%lld<%lld)\n",
                (long long)ae->len, (long long)(M*K),
                (long long)be->len, (long long)(N*K),
                (long long)ce->len, (long long)(M*N));
        return -1;
    }

    @autoreleasepool {
        NSUInteger a_bytes = (NSUInteger)(M * K) * sizeof(float);
        NSUInteger b_bytes = (NSUInteger)(N * K) * sizeof(float);
        NSUInteger c_bytes = (NSUInteger)(M * N) * sizeof(float);

        id<MTLBuffer> a_buf = [g_metal_device newBufferWithLength:a_bytes
                                                          options:MTLResourceStorageModeShared];
        id<MTLBuffer> b_buf = [g_metal_device newBufferWithLength:b_bytes
                                                          options:MTLResourceStorageModeShared];
        id<MTLBuffer> c_buf = [g_metal_device newBufferWithLength:c_bytes
                                                          options:MTLResourceStorageModeShared];
        if (!a_buf || !b_buf || !c_buf) {
            fprintf(stderr, "[metal] farr32_matmul_NT_b: newBufferWithLength "
                            "OOM (a=%llu b=%llu c=%llu bytes)\n",
                    (unsigned long long)a_bytes,
                    (unsigned long long)b_bytes,
                    (unsigned long long)c_bytes);
            return -1;
        }

        /* Native FP32: memcpy in, no per-element cast. */
        memcpy([a_buf contents], ae->buf, a_bytes);
        memcpy([b_buf contents], be->buf, b_bytes);

        /* Descriptors:
         *   A: M rows × K cols row-major, rowBytes = K*4
         *   B: N rows × K cols row-major, rowBytes = K*4
         *      (transposeRight=YES tells MPS to interpret as K×N)
         *   C: M rows × N cols row-major, rowBytes = N*4 */
        MPSMatrixDescriptor* a_desc =
            [MPSMatrixDescriptor matrixDescriptorWithRows:(NSUInteger)M
                                                  columns:(NSUInteger)K
                                                 rowBytes:(NSUInteger)(K * sizeof(float))
                                                 dataType:MPSDataTypeFloat32];
        MPSMatrixDescriptor* b_desc =
            [MPSMatrixDescriptor matrixDescriptorWithRows:(NSUInteger)N
                                                  columns:(NSUInteger)K
                                                 rowBytes:(NSUInteger)(K * sizeof(float))
                                                 dataType:MPSDataTypeFloat32];
        MPSMatrixDescriptor* c_desc =
            [MPSMatrixDescriptor matrixDescriptorWithRows:(NSUInteger)M
                                                  columns:(NSUInteger)N
                                                 rowBytes:(NSUInteger)(N * sizeof(float))
                                                 dataType:MPSDataTypeFloat32];

        MPSMatrix* a_mat = [[MPSMatrix alloc] initWithBuffer:a_buf descriptor:a_desc];
        MPSMatrix* b_mat = [[MPSMatrix alloc] initWithBuffer:b_buf descriptor:b_desc];
        MPSMatrix* c_mat = [[MPSMatrix alloc] initWithBuffer:c_buf descriptor:c_desc];
        if (!a_mat || !b_mat || !c_mat) {
            fprintf(stderr, "[metal] farr32_matmul_NT_b: MPSMatrix init failed\n");
            return -1;
        }

        /* The transpose-right magic: MPS computes A · B^T natively.
         * transposeLeft:NO + transposeRight:YES. resultRows=M,
         * resultColumns=N, interiorColumns=K — matches the math
         * contract C[i,j] = sum_k A[i,k] * B[j,k] verbatim. */
        MPSMatrixMultiplication* mm =
            [[MPSMatrixMultiplication alloc] initWithDevice:g_metal_device
                                              transposeLeft:NO
                                             transposeRight:YES
                                                 resultRows:(NSUInteger)M
                                              resultColumns:(NSUInteger)N
                                            interiorColumns:(NSUInteger)K
                                                      alpha:1.0
                                                       beta:0.0];
        if (!mm) {
            fprintf(stderr, "[metal] farr32_matmul_NT_b: "
                            "MPSMatrixMultiplication init failed\n");
            return -1;
        }

        id<MTLCommandBuffer> cmd = [g_metal_queue commandBuffer];
        if (!cmd) {
            fprintf(stderr, "[metal] farr32_matmul_NT_b: "
                            "commandBuffer alloc failed\n");
            return -1;
        }
        [mm encodeToCommandBuffer:cmd
                       leftMatrix:a_mat
                      rightMatrix:b_mat
                     resultMatrix:c_mat];
        [cmd commit];
        [cmd waitUntilCompleted];
        if (cmd.status != MTLCommandBufferStatusCompleted) {
            fprintf(stderr, "[metal] farr32_matmul_NT_b: command buffer "
                            "status=%ld (err=%s)\n",
                    (long)cmd.status,
                    cmd.error ? [[cmd.error description] UTF8String]
                              : "(nil)");
            return -1;
        }

        memcpy(ce->buf, [c_buf contents], c_bytes);
    } /* @autoreleasepool */

    return 0;
}

#ifdef __cplusplus
}
#endif
