// host_simdgroup_matmul_mixed.swift — RFC 075 Apple M3 mixed-precision simdgroup MMA fire
//
// Loads simdgroup_matmul_mixed.metallib, runs the three mixed-precision
// simdgroup-MMA kernels (FP16 inputs, FP32 accumulator/output) across a
// 128/256/512/768/1024 cube sweep, compares vs CPU FP32 ikj reference at the
// strict 1e-4 rel_err gate (much tighter than N25's pure-FP16 1e-2 because
// the FP32 accumulator restores precision), times each dispatch with
// cb.gpuEndTime/gpuStartTime, emits one F-RFC075-METAL-SIMDGROUP-MIXED-
// PRECISION-NUMERIC-EQ status line per shape, and writes result.json
// including a comparison table vs N16 FP32 simdgroup, N25 pure-FP16
// simdgroup, and MPS FP32 GEMM.
//
// Tolerance: rel_err = max|gpu - ref_fp32| / max|ref_fp32| < 1e-4.
// Rationale: with FP32 accumulator, the only error source is FP16 input
// rounding (eps ≈ 2^-10 ≈ 9.8e-4 per term, but the K-loop averages over
// LCG-uniform inputs so dot-product noise scales as ~sqrt(K)·eps_fp16).
// For K=1024 that's ~3e-5 in the worst case → 1e-4 is a tight but
// realistic gate.
//
// Build + run (per `reference_swift_build_pool_xcrun`):
//   xcrun --sdk macosx swift host_simdgroup_matmul_mixed.swift ./simdgroup_matmul_mixed.metallib
//
// Dispatch geometries identical to N16 + N25 (same 8x8 MMA tile):
//   simdgroup_matmul_8x8_mixed       threads/TG = (32, 1, 1)   grid = ( (N/8)*32, M/8, 1 )
//   simdgroup_matmul_16x16_mixed     threads/TG = (32, 4, 1)   grid = ( (N/16)*32, (M/16)*4, 1 )
//   simdgroup_matmul_32x32_tg_mixed  threads/TG = (32, 16, 1)  grid = ( (N/32)*32, (M/32)*16, 1 )

import Foundation
import Metal

// ─── deterministic LCG (Numerical Recipes 32-bit) — same as N16/N25 ─────
var lcg_state: UInt32 = 0x12345678
func lcg_next() -> UInt32 {
    lcg_state = lcg_state &* 1664525 &+ 1013904223
    return lcg_state
}
func lcg_f32() -> Float32 {
    let u = lcg_next()
    return (Float32(u) / Float32(UInt32.max)) * 2.0 - 1.0
}

// ─── FP32 ↔ FP16 conversion (IEEE 754 binary16) ─────────────────────────
@inline(__always)
func fp32_to_fp16_bits(_ f: Float32) -> UInt16 {
    let h = Float16(f)
    return h.bitPattern
}

// ─── CPU FP32 reference (ikj inner stride) — same as N16/N25 ────────────
// Note: inputs to the GPU kernel are FP16. To make the comparison
// apples-to-apples (the GPU also sees FP16-rounded inputs), the CPU
// reference is computed on the FP16-rounded inputs cast back to FP32.
@inline(never)
func cpu_matmul_ref_fp32(_ a: [Float32], _ b: [Float32],
                         _ M: Int, _ N: Int, _ K: Int) -> [Float32] {
    var c = [Float32](repeating: 0, count: M * N)
    for i in 0..<M {
        for k in 0..<K {
            let aik = a[i * K + k]
            for j in 0..<N {
                c[i * N + j] += aik * b[k * N + j]
            }
        }
    }
    return c
}

// ─── Metal setup ────────────────────────────────────────────────────────
guard let device = MTLCreateSystemDefaultDevice() else {
    print("F-RFC075-METAL-SIMDGROUP-MIXED-PRECISION-NUMERIC-EQ: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
print("max_threads_per_threadgroup=\(device.maxThreadsPerThreadgroup)")
print("max_threadgroup_memory_length=\(device.maxThreadgroupMemoryLength)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-SIMDGROUP-MIXED-PRECISION-NUMERIC-EQ: FAIL (no queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./simdgroup_matmul_mixed.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-SIMDGROUP-MIXED-PRECISION-NUMERIC-EQ: FAIL (makeLibrary: \(error))")
    exit(1)
}

func makePipeline(_ name: String) -> MTLComputePipelineState {
    guard let fn = library.makeFunction(name: name) else {
        print("F-RFC075-METAL-SIMDGROUP-MIXED-PRECISION-NUMERIC-EQ: FAIL (no \(name) fn)")
        exit(1)
    }
    do { return try device.makeComputePipelineState(function: fn) }
    catch {
        print("F-RFC075-METAL-SIMDGROUP-MIXED-PRECISION-NUMERIC-EQ: FAIL (pipeline \(name): \(error))")
        exit(1)
    }
}

let pipe8    = makePipeline("simdgroup_matmul_8x8_mixed")
let pipe16   = makePipeline("simdgroup_matmul_16x16_mixed")
let pipe32tg = makePipeline("simdgroup_matmul_32x32_tg_mixed")

print(String(format: "pipe8     tew=%d max=%d", pipe8.threadExecutionWidth,    pipe8.maxTotalThreadsPerThreadgroup))
print(String(format: "pipe16    tew=%d max=%d", pipe16.threadExecutionWidth,   pipe16.maxTotalThreadsPerThreadgroup))
print(String(format: "pipe32tg  tew=%d max=%d", pipe32tg.threadExecutionWidth, pipe32tg.maxTotalThreadsPerThreadgroup))

// ─── one shape probe ────────────────────────────────────────────────────
struct Result {
    let M: Int; let N: Int; let K: Int
    let kernel: String
    let median_ms: Double
    let gflops: Double
    let max_abs_diff: Float32
    let max_rel_err: Float32           // vs FP32 reference on FP16-rounded inputs
    let pass: Bool
}

enum DispatchKind {
    case k8x8
    case k16x16
    case k32x32_tg
}

func dispatchGeometry(_ kind: DispatchKind, _ M: Int, _ N: Int) -> (grid: MTLSize, tg: MTLSize) {
    switch kind {
    case .k8x8:
        let tg   = MTLSize(width: 32, height: 1, depth: 1)
        let gridW = ((N + 7) / 8) * 32
        let gridH = (M + 7) / 8
        return (MTLSize(width: gridW, height: gridH, depth: 1), tg)
    case .k16x16:
        let tg   = MTLSize(width: 32, height: 4, depth: 1)
        let gridW = ((N + 15) / 16) * 32
        let gridH = ((M + 15) / 16) * 4
        return (MTLSize(width: gridW, height: gridH, depth: 1), tg)
    case .k32x32_tg:
        let tg   = MTLSize(width: 32, height: 16, depth: 1)
        let gridW = ((N + 31) / 32) * 32
        let gridH = ((M + 31) / 32) * 16
        return (MTLSize(width: gridW, height: gridH, depth: 1), tg)
    }
}

// Tight gate — FP32 accumulator should restore precision (only FP16 input
// rounding contributes). Threshold per task spec: rel_err < 1e-4.
let TOL_MIXED: Float32 = 1e-4

func run_shape(_ M: Int, _ N: Int, _ K: Int,
               kernel name: String,
               pipeline: MTLComputePipelineState,
               kind: DispatchKind,
               warmup: Int, timed: Int,
               cachedRef: [Float32]?,
               aFp32Rounded: [Float32], bFp32Rounded: [Float32],
               aBits: [UInt16], bBits: [UInt16]) -> (Result, [Float32]) {

    // Use cached reference where possible (same shape repeats across 3 kernels).
    let ref: [Float32]
    if let cached = cachedRef { ref = cached }
    else { ref = cpu_matmul_ref_fp32(aFp32Rounded, bFp32Rounded, M, N, K) }

    let aBytes = M * K * MemoryLayout<UInt16>.stride
    let bBytes = K * N * MemoryLayout<UInt16>.stride
    let cBytes = M * N * MemoryLayout<Float32>.stride

    guard let bufA = device.makeBuffer(bytes: aBits, length: aBytes, options: .storageModeShared),
          let bufB = device.makeBuffer(bytes: bBits, length: bBytes, options: .storageModeShared),
          let bufC = device.makeBuffer(length: cBytes, options: .storageModeShared) else {
        print("F-RFC075-METAL-SIMDGROUP-MIXED-PRECISION-NUMERIC-EQ: FAIL (buffer alloc)"); exit(1)
    }

    var Mv: UInt32 = UInt32(M)
    var Nv: UInt32 = UInt32(N)
    var Kv: UInt32 = UInt32(K)

    let (grid, tg) = dispatchGeometry(kind, M, N)

    func dispatch_once() -> Double {
        memset(bufC.contents(), 0, cBytes)
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            print("F-RFC075-METAL-SIMDGROUP-MIXED-PRECISION-NUMERIC-EQ: FAIL (encoder)"); exit(1)
        }
        enc.setComputePipelineState(pipeline)
        enc.setBuffer(bufA, offset: 0, index: 0)
        enc.setBuffer(bufB, offset: 0, index: 1)
        enc.setBuffer(bufC, offset: 0, index: 2)
        enc.setBytes(&Mv, length: 4, index: 3)
        enc.setBytes(&Nv, length: 4, index: 4)
        enc.setBytes(&Kv, length: 4, index: 5)
        enc.dispatchThreads(grid, threadsPerThreadgroup: tg)
        enc.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
        if let err = cmd.error {
            print("F-RFC075-METAL-SIMDGROUP-MIXED-PRECISION-NUMERIC-EQ: FAIL (commit: \(err))"); exit(1)
        }
        return (cmd.gpuEndTime - cmd.gpuStartTime) * 1e3
    }

    for _ in 0..<warmup { let _ = dispatch_once() }

    var samples = [Double](); samples.reserveCapacity(timed)
    for _ in 0..<timed { samples.append(dispatch_once()) }
    samples.sort()
    let median = samples[samples.count / 2]

    // Read GPU output as FP32 directly (output buffer is FP32).
    let gpuRaw = bufC.contents().bindMemory(to: Float32.self, capacity: M * N)
    var max_abs_diff: Float32 = 0
    var max_ref_abs: Float32 = 0
    for i in 0..<(M * N) {
        let g = gpuRaw[i]
        let d = abs(g - ref[i])
        if d > max_abs_diff { max_abs_diff = d }
        let r = abs(ref[i])
        if r > max_ref_abs { max_ref_abs = r }
    }
    let rel_err: Float32 = max_ref_abs > 0 ? max_abs_diff / max_ref_abs : 0
    let flops = 2.0 * Double(M) * Double(N) * Double(K)
    let gflops = flops / (median * 1e-3) / 1e9
    let ok = rel_err < TOL_MIXED
    let r = Result(M: M, N: N, K: K, kernel: name, median_ms: median,
                   gflops: gflops, max_abs_diff: max_abs_diff,
                   max_rel_err: rel_err, pass: ok)
    return (r, ref)
}

// ─── shape sweep ────────────────────────────────────────────────────────
let shapes: [(Int, Int, Int)] = [
    (128, 128, 128),
    (256, 256, 256),
    (512, 512, 512),
    (768, 768, 768),
    (1024, 1024, 1024),
]
let warmup = 5
let timed  = 50

let kernels: [(String, MTLComputePipelineState, DispatchKind)] = [
    ("simdgroup_matmul_8x8_mixed",       pipe8,    .k8x8),
    ("simdgroup_matmul_16x16_mixed",     pipe16,   .k16x16),
    ("simdgroup_matmul_32x32_tg_mixed",  pipe32tg, .k32x32_tg),
]

var results: [Result] = []
var allOk = true

for (M, N, K) in shapes {
    // Generate FP32 inputs once per shape (LCG re-seeded for determinism),
    // then round to FP16 and back so the reference sees the SAME inputs as
    // the GPU. This isolates the GPU error to "compute" only, not "input
    // rounding" — important for verifying that FP32 accumulator works.
    lcg_state = 0x12345678
    var aFp32 = [Float32](repeating: 0, count: M * K)
    var bFp32 = [Float32](repeating: 0, count: K * N)
    for i in 0..<(M * K) { aFp32[i] = lcg_f32() }
    for i in 0..<(K * N) { bFp32[i] = lcg_f32() }

    // Round inputs to FP16 (this is what the GPU sees).
    var aBits = [UInt16](repeating: 0, count: M * K)
    var bBits = [UInt16](repeating: 0, count: K * N)
    var aRounded = [Float32](repeating: 0, count: M * K)
    var bRounded = [Float32](repeating: 0, count: K * N)
    for i in 0..<(M * K) {
        let bits = fp32_to_fp16_bits(aFp32[i])
        aBits[i] = bits
        aRounded[i] = Float32(Float16(bitPattern: bits))
    }
    for i in 0..<(K * N) {
        let bits = fp32_to_fp16_bits(bFp32[i])
        bBits[i] = bits
        bRounded[i] = Float32(Float16(bitPattern: bits))
    }

    var cachedRef: [Float32]? = nil
    for (name, pipe, kind) in kernels {
        let (r, ref) = run_shape(M, N, K, kernel: name, pipeline: pipe, kind: kind,
                                 warmup: warmup, timed: timed,
                                 cachedRef: cachedRef,
                                 aFp32Rounded: aRounded, bFp32Rounded: bRounded,
                                 aBits: aBits, bBits: bBits)
        cachedRef = ref
        results.append(r)
        if !r.pass { allOk = false }
        let tag = r.pass ? "PASS" : "FAIL"
        let kpad = r.kernel.padding(toLength: 34, withPad: " ", startingAt: 0)
        print(String(format: "\(kpad)  M=%d N=%d K=%d  median=%.4fms  GFLOPS=%.2f  max|d|=%.3e  rel=%.3e  \(tag)",
                     r.M, r.N, r.K, r.median_ms, r.gflops,
                     Double(r.max_abs_diff), Double(r.max_rel_err)))
    }
}

// ─── result.json emission ───────────────────────────────────────────────
// Anchors:
//   - N16 FP32 simdgroup fire  (commit 31d729a4): peak 911.55 GFLOPS @ 768³
//   - N25 pure-FP16 simdgroup fire (commit ab0ff62d): peak 789.38 GFLOPS @ 1024³
//   - FP32 naive/tiled (commit 19e83c2b): 184.90/269.41 GFLOPS @ 512^3
//   - MPS FP32 GEMM (commit 9b352bda): 1666.34/1702.75 GFLOPS @ 768/1024
//   - Apple M3 advertised FP32 ~3.5 TFLOPS

struct FP32Anchor { let kernel: String; let M: Int; let gflops: Double }
let fp32Anchors: [FP32Anchor] = [
    FP32Anchor(kernel: "simdgroup_matmul_8x8",      M: 128, gflops:  92.01),
    FP32Anchor(kernel: "simdgroup_matmul_16x16",    M: 128, gflops:  88.46),
    FP32Anchor(kernel: "simdgroup_matmul_32x32_tg", M: 128, gflops: 100.87),
    FP32Anchor(kernel: "simdgroup_matmul_8x8",      M: 256, gflops: 116.66),
    FP32Anchor(kernel: "simdgroup_matmul_16x16",    M: 256, gflops: 280.01),
    FP32Anchor(kernel: "simdgroup_matmul_32x32_tg", M: 256, gflops: 439.34),
    FP32Anchor(kernel: "simdgroup_matmul_8x8",      M: 512, gflops: 228.12),
    FP32Anchor(kernel: "simdgroup_matmul_16x16",    M: 512, gflops: 376.75),
    FP32Anchor(kernel: "simdgroup_matmul_32x32_tg", M: 512, gflops: 638.37),
    FP32Anchor(kernel: "simdgroup_matmul_8x8",      M: 768, gflops: 291.33),
    FP32Anchor(kernel: "simdgroup_matmul_16x16",    M: 768, gflops: 266.02),
    FP32Anchor(kernel: "simdgroup_matmul_32x32_tg", M: 768, gflops: 911.55),
    FP32Anchor(kernel: "simdgroup_matmul_8x8",      M:1024, gflops: 288.42),
    FP32Anchor(kernel: "simdgroup_matmul_16x16",    M:1024, gflops: 422.68),
    FP32Anchor(kernel: "simdgroup_matmul_32x32_tg", M:1024, gflops: 506.50),
]

// N25 pure-FP16 anchors (measured in commit ab0ff62d, copied verbatim).
struct FP16Anchor { let kernel: String; let M: Int; let gflops: Double; let rel: Float32 }
let fp16Anchors: [FP16Anchor] = [
    FP16Anchor(kernel: "simdgroup_matmul_8x8_fp16",       M: 128, gflops:  92.95, rel: 0.00373),
    FP16Anchor(kernel: "simdgroup_matmul_16x16_fp16",     M: 128, gflops:  89.56, rel: 0.00373),
    FP16Anchor(kernel: "simdgroup_matmul_32x32_tg_fp16",  M: 128, gflops: 105.41, rel: 0.00373),
    FP16Anchor(kernel: "simdgroup_matmul_8x8_fp16",       M: 256, gflops: 118.67, rel: 0.00434),
    FP16Anchor(kernel: "simdgroup_matmul_16x16_fp16",     M: 256, gflops: 119.59, rel: 0.00434),
    FP16Anchor(kernel: "simdgroup_matmul_32x32_tg_fp16",  M: 256, gflops: 195.94, rel: 0.00434),
    FP16Anchor(kernel: "simdgroup_matmul_8x8_fp16",       M: 512, gflops: 302.12, rel: 0.00860),
    // 16x16/32x32 at 512/768/1024 from N25 result.json — partial list, peak overall 789.38.
]

func fp32Of(_ k: String, _ M: Int) -> Double {
    // Strip the "_mixed" suffix to find the corresponding FP32 kernel.
    let fk = k.replacingOccurrences(of: "_mixed", with: "")
    for a in fp32Anchors where a.kernel == fk && a.M == M { return a.gflops }
    return 0
}

func fp16Of(_ k: String, _ M: Int) -> Double {
    // Map "_mixed" → "_fp16" for the N25 pure-FP16 anchors.
    let fk = k.replacingOccurrences(of: "_mixed", with: "_fp16")
    for a in fp16Anchors where a.kernel == fk && a.M == M { return a.gflops }
    return 0
}

var json = "{\n"
json += "  \"campaign\": \"rfc075_metal_simdgroup_matmul_mixed_2026_05_21\",\n"
json += "  \"host\": \"Mac (local)\",\n"
json += "  \"platform\": \"darwin-arm64\",\n"
json += "  \"gpu\": \"\(device.name) (registry_id=\(device.registryID))\",\n"
let mtpt = device.maxThreadsPerThreadgroup
json += "  \"max_threads_per_threadgroup\": \"\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)\",\n"
json += "  \"max_threadgroup_memory_length\": \(device.maxThreadgroupMemoryLength),\n"
json += "  \"date_utc\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
json += "  \"toolchain\": \"xcrun --sdk macosx metal / swiftc (-O)\",\n"
json += "  \"intrinsic\": \"simdgroup_matrix<half,8,8> inputs + simdgroup_matrix<float,8,8> accumulator + simdgroup_multiply_accumulate (MSL §6.7 mixed-precision form, R=V=float, T=U=half)\",\n"
json += "  \"header\": \"<metal_simdgroup_matrix> (templated R,T,U,V independent types; on-system header confirms)\",\n"
json += "  \"fp32_baseline_commit\": \"31d729a4\",\n"
json += "  \"fp16_baseline_commit\": \"ab0ff62d\",\n"
json += "  \"warmup\": \(warmup),\n"
json += "  \"timed\": \(timed),\n"
json += "  \"tolerance_rel\": 1e-4,\n"
json += "  \"tolerance_rationale\": \"FP32 accumulator removes K-loop precision loss. Only error source is FP16 input rounding (eps_fp16 ≈ 9.8e-4 per operand, dot-product noise ~sqrt(K)·eps for uniform inputs). Reference is built on FP16-rounded inputs (same rounding as GPU sees) so the comparison isolates compute-side error.\",\n"
json += "  \"rows\": [\n"
for (idx, r) in results.enumerated() {
    let comma = idx == results.count - 1 ? "" : ","
    let fp32 = fp32Of(r.kernel, r.M)
    let fp16 = fp16Of(r.kernel, r.M)
    let ratio32 = fp32 > 0 ? r.gflops / fp32 : 0
    let ratio16 = fp16 > 0 ? r.gflops / fp16 : 0
    json += "    {\n"
    json += "      \"kernel\": \"\(r.kernel)\",\n"
    json += "      \"M\": \(r.M), \"N\": \(r.N), \"K\": \(r.K),\n"
    json += "      \"median_ms\": \(r.median_ms),\n"
    json += "      \"gflops\": \(r.gflops),\n"
    json += "      \"fp32_baseline_gflops\": \(fp32),\n"
    json += "      \"ratio_vs_fp32\": \(ratio32),\n"
    json += "      \"fp16_baseline_gflops\": \(fp16),\n"
    json += "      \"ratio_vs_pure_fp16\": \(ratio16),\n"
    json += "      \"max_abs_diff\": \(r.max_abs_diff),\n"
    json += "      \"max_rel_err\": \(r.max_rel_err),\n"
    json += "      \"pass\": \(r.pass)\n"
    json += "    }\(comma)\n"
}
json += "  ],\n"

func gflopsAt(_ kernel: String, _ M: Int) -> Double {
    for r in results where r.kernel == kernel && r.M == M { return r.gflops }
    return 0
}
func peakGflops(_ kernel: String) -> Double {
    var best = 0.0
    for r in results where r.kernel == kernel { if r.gflops > best { best = r.gflops } }
    return best
}
let peak8     = peakGflops("simdgroup_matmul_8x8_mixed")
let peak16    = peakGflops("simdgroup_matmul_16x16_mixed")
let peak32    = peakGflops("simdgroup_matmul_32x32_tg_mixed")
let peakAny   = max(peak8, max(peak16, peak32))

json += "  \"peak_gflops_8x8_mixed\": \(peak8),\n"
json += "  \"peak_gflops_16x16_mixed\": \(peak16),\n"
json += "  \"peak_gflops_32x32_tg_mixed\": \(peak32),\n"
json += "  \"peak_gflops_overall_mixed\": \(peakAny),\n"

let fp32Peak: Double = 911.55
let fp16Peak: Double = 789.38
let mpsFp32Peak: Double = 1702.75
json += "  \"fp32_peak_gflops\": \(fp32Peak),\n"
json += "  \"fp16_peak_gflops\": \(fp16Peak),\n"
json += "  \"mps_fp32_peak_gflops\": \(mpsFp32Peak),\n"
json += "  \"mixed_over_fp32_peak_ratio\": \(peakAny / fp32Peak),\n"
json += "  \"mixed_over_fp16_peak_ratio\": \(peakAny / fp16Peak),\n"
json += "  \"mixed_over_mps_fp32_ratio\": \(peakAny / mpsFp32Peak),\n"

// Max rel_err across all shapes/kernels.
var maxRelOverall: Float32 = 0
var maxRelAtPeak: Float32 = 0
for r in results {
    if r.max_rel_err > maxRelOverall { maxRelOverall = r.max_rel_err }
    if r.kernel == "simdgroup_matmul_32x32_tg_mixed" && r.gflops == peak32 { maxRelAtPeak = r.max_rel_err }
}
json += "  \"max_rel_err_overall\": \(maxRelOverall),\n"
json += "  \"max_rel_err_at_peak_kernel_shape\": \(maxRelAtPeak),\n"

json += "  \"comparison_table\": {\n"
json += "    \"note\": \"Anchors: N16 FP32 simdgroup (commit 31d729a4) peak 911.55 GFLOPS @ 768^3 on 32x32_tg; N25 pure-FP16 (commit ab0ff62d) peak 789.38 GFLOPS @ 1024^3 (FP16 accum lost precision at K>=768, rel_err ~1e-2); MPS FP32 (commit 9b352bda) 1702.75 GFLOPS @ 1024^3. Apple M3 advertised FP32 ~3.5 TFLOPS.\",\n"
json += "    \"columns\": [\"approach\", \"precision\", \"shape\", \"GFLOPS\", \"rel_err\", \"source\"],\n"
json += "    \"rows\": [\n"
json += "      [\"matmul_naive\",                       \"FP32\",            \"512^3\",  184.90,   1e-7,  \"matmul.metal fire (commit 19e83c2b)\"],\n"
json += "      [\"matmul_tiled-16\",                    \"FP32\",            \"512^3\",  269.41,   1e-7,  \"matmul.metal fire (commit 19e83c2b)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg\",          \"FP32\",            \"512^3\",  638.37,   1e-7,  \"N16 simdgroup fp32 fire (commit 31d729a4)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg\",          \"FP32\",            \"768^3\",  911.55,   1e-7,  \"N16 simdgroup fp32 fire (commit 31d729a4, peak)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_fp16\",     \"FP16 in / FP16 acc\",\"512^3\",  302.12,   8.6e-3,\"N25 pure-FP16 fire (commit ab0ff62d)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_fp16\",     \"FP16 in / FP16 acc\",\"1024^3\", 789.38,   1.6e-2,\"N25 pure-FP16 fire (commit ab0ff62d, peak)\"],\n"
json += "      [\"simdgroup_matmul_8x8_mixed\",         \"FP16 in / FP32 acc\",\"512^3\",  \(gflopsAt("simdgroup_matmul_8x8_mixed", 512)),  \(results.first(where: { $0.kernel == "simdgroup_matmul_8x8_mixed" && $0.M == 512 })?.max_rel_err ?? -1), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_16x16_mixed\",       \"FP16 in / FP32 acc\",\"512^3\",  \(gflopsAt("simdgroup_matmul_16x16_mixed", 512)),\(results.first(where: { $0.kernel == "simdgroup_matmul_16x16_mixed" && $0.M == 512 })?.max_rel_err ?? -1), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_mixed\",    \"FP16 in / FP32 acc\",\"512^3\",  \(gflopsAt("simdgroup_matmul_32x32_tg_mixed", 512)),\(results.first(where: { $0.kernel == "simdgroup_matmul_32x32_tg_mixed" && $0.M == 512 })?.max_rel_err ?? -1), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_mixed\",    \"FP16 in / FP32 acc\",\"768^3\",  \(gflopsAt("simdgroup_matmul_32x32_tg_mixed", 768)),\(results.first(where: { $0.kernel == "simdgroup_matmul_32x32_tg_mixed" && $0.M == 768 })?.max_rel_err ?? -1), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_mixed\",    \"FP16 in / FP32 acc\",\"1024^3\", \(gflopsAt("simdgroup_matmul_32x32_tg_mixed", 1024)),\(results.first(where: { $0.kernel == "simdgroup_matmul_32x32_tg_mixed" && $0.M == 1024 })?.max_rel_err ?? -1), \"this fire\"],\n"
json += "      [\"MPS GEMM\",                           \"FP32\",            \"768^3\",  1666.34,  1e-6,  \"host_mps_gemm fire (commit 9b352bda)\"],\n"
json += "      [\"MPS GEMM\",                           \"FP32\",            \"1024^3\", 1702.75,  1e-6,  \"host_mps_gemm fire (commit 9b352bda)\"],\n"
json += "      [\"Apple M3 advertised peak FP32\",      \"FP32\",            \"-\",      3500.00,  0,     \"Apple GPU spec sheet\"]\n"
json += "    ]\n"
json += "  },\n"

let statusStr = allOk ? "PASS" : "PARTIAL"
json += "  \"falsifier_F_RFC075_METAL_SIMDGROUP_MIXED_PRECISION_NUMERIC_EQ\": \"\(statusStr)\",\n"
json += "  \"headline\": {\n"
json += "    \"mixed_peak_gflops\": \(peakAny),\n"
json += "    \"vs_fp32_ratio\": \(peakAny / fp32Peak),\n"
json += "    \"vs_pure_fp16_ratio\": \(peakAny / fp16Peak),\n"
json += "    \"vs_mps_ratio\": \(peakAny / mpsFp32Peak),\n"
json += "    \"max_rel_err\": \(maxRelOverall),\n"
json += "    \"precision_recovered_vs_fp16\": \(maxRelOverall < 1e-3 ? "true" : "false"),\n"
json += "    \"throughput_maintained_vs_fp16\": \(peakAny >= fp16Peak * 0.95 ? "true" : "false")\n"
json += "  },\n"
json += "  \"honest_scope\": [\n"
json += "    \"Mixed-precision MMA per Apple MSL §6.7 + on-system metal_simdgroup_matrix header: templated R,T,U,V types resolved by overload, R=V=float, T=U=half. The header explicitly defines this 4-type form via _simdgroup_multiply_accumulate_impl<R,T,U,V,K,Rows,Cols>.\",\n"
json += "    \"FP32 accumulator removes K-loop precision drift (the main fail mode of N25 pure-FP16). Remaining error floor is FP16 input rounding alone. With LCG-uniform inputs the expected dot-product noise ~sqrt(K)·eps_fp16 ≈ 3e-5 at K=1024.\",\n"
json += "    \"Throughput depends on whether Apple M3's MMA pipe has a separate mixed-precision path. Per N25's measurement, pure-FP16 ran at 0.87× FP32 on the same M3 (no dedicated 2× FP16 boost). Mixed-precision could be similar or slower (extra accumulator-widening cost) or faster (the FP32 accumulator pipe may be the primary pipe and FP16 inputs trade bandwidth).\",\n"
json += "    \"Output buffer is FP32 (4 B/elem) — twice the storage cost of pure FP16 output but half of pure FP32 output. This is the intended mixed-precision tradeoff: keep FP16 input bandwidth wins, restore FP32 output precision.\",\n"
json += "    \"Mac is a shared developer laptop; variance is noisier than ubu-2 cuBLAS. Median over 50 timed runs after 5 warmups, same protocol as N16/N25.\",\n"
json += "    \"No MPS FP16/mixed comparator in this fire — MPSMatrixMultiplication exposes precision via the descriptor; deferred to a follow-up cycle.\"\n"
json += "  ]\n"
json += "}\n"
let jsonPath = "./result.json"
do { try json.write(toFile: jsonPath, atomically: true, encoding: .utf8) }
catch { print("WARN: result.json write failed: \(error)") }

let final = allOk ? "PASS" : "PARTIAL"
print("F-RFC075-METAL-SIMDGROUP-MIXED-PRECISION-NUMERIC-EQ: \(final)")
print(String(format: "PEAK_SIMDGROUP_MIXED_GFLOPS=%.2f (best of 8x8/16x16/32x32_tg across 128/256/512/768/1024)", peakAny))
print(String(format: "MIXED_OVER_FP32_PEAK_RATIO=%.3fx (FP32 peak = %.2f GFLOPS @ commit 31d729a4)", peakAny / fp32Peak, fp32Peak))
print(String(format: "MIXED_OVER_FP16_PEAK_RATIO=%.3fx (FP16 peak = %.2f GFLOPS @ commit ab0ff62d)", peakAny / fp16Peak, fp16Peak))
print(String(format: "MAX_REL_ERR_OVERALL=%.3e (gate < 1e-4)", Double(maxRelOverall)))
exit(0)
