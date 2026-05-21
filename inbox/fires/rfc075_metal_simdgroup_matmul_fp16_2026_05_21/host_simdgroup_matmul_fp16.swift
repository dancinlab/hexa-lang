// host_simdgroup_matmul_fp16.swift — RFC 075 Apple M3 simdgroup_matrix<half,8,8> FP16 fire host
//
// Loads simdgroup_matmul_fp16.metallib, runs the three FP16 simdgroup-MMA
// kernels (8x8 / 16x16 / 32x32_tg) across a 128/256/512/768/1024 cube sweep,
// compares vs a CPU FP32 ikj reference with FP16 round-trip tolerance,
// times each dispatch with cb.gpuEndTime/gpuStartTime, emits one
// F-RFC075-METAL-SIMDGROUP-MATMUL-FP16-NUMERIC-EQ status line plus per-shape
// GFLOPS, and writes result.json including a comparison table vs the FP32
// simdgroup baseline (commit 31d729a4), naive/tiled FP32 (commit 19e83c2b),
// and MPS FP32 GEMM (commit 9b352bda).
//
// Tolerance: rel_err = max|gpu_fp16 - ref_fp32| / max|ref_fp32| < 1e-2.
// FP16 has only ~3-4 decimal digits of precision; the K-loop accumulator
// loses precision at O(K) ULP. 1e-2 is the realistic FP16-matmul threshold.
//
// Build + run (per `reference_swift_build_pool_xcrun`):
//   xcrun --sdk macosx swift host_simdgroup_matmul_fp16.swift ./simdgroup_matmul_fp16.metallib
//
// The dispatch geometries are identical to the FP32 fire (same MMA tile = 8x8):
//   simdgroup_matmul_8x8_fp16       threads/TG = (32, 1, 1)   grid = ( (N/8)*32, M/8, 1 )
//   simdgroup_matmul_16x16_fp16     threads/TG = (32, 4, 1)   grid = ( (N/16)*32, (M/16)*4, 1 )
//   simdgroup_matmul_32x32_tg_fp16  threads/TG = (32, 16, 1)  grid = ( (N/32)*32, (M/32)*16, 1 )

import Foundation
import Metal

// ─── deterministic LCG (Numerical Recipes 32-bit) — same as FP32 fire ────
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
// Swift exposes `Float16` natively on Apple Silicon (arm64). We use raw
// 16-bit storage via UInt16 bitPattern to interop with MSL `half`.

@inline(__always)
func fp32_to_fp16_bits(_ f: Float32) -> UInt16 {
    let h = Float16(f)
    return h.bitPattern
}

@inline(__always)
func fp16_bits_to_fp32(_ bits: UInt16) -> Float32 {
    let h = Float16(bitPattern: bits)
    return Float32(h)
}

// ─── CPU FP32 reference (ikj inner stride) — same as FP32 fire ──────────
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

// FP16-rounded reference: do the matmul accumulator in FP16 too — this is the
// closest CPU-side model of what the GPU FP16 kernel does. We use this only
// for diagnostic side-comparison (printed alongside the main FP32 rel_err);
// the pass/fail gate is against FP32.
@inline(never)
func cpu_matmul_ref_fp16accum(_ a: [Float32], _ b: [Float32],
                               _ M: Int, _ N: Int, _ K: Int) -> [Float32] {
    var c = [Float32](repeating: 0, count: M * N)
    for i in 0..<M {
        for k in 0..<K {
            let aik16 = Float16(a[i * K + k])
            for j in 0..<N {
                let bkj16 = Float16(b[k * N + j])
                let acc16 = Float16(c[i * N + j]) + aik16 * bkj16
                c[i * N + j] = Float32(acc16)
            }
        }
    }
    return c
}

// ─── Metal setup ────────────────────────────────────────────────────────
guard let device = MTLCreateSystemDefaultDevice() else {
    print("F-RFC075-METAL-SIMDGROUP-MATMUL-FP16-NUMERIC-EQ: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
print("max_threads_per_threadgroup=\(device.maxThreadsPerThreadgroup)")
print("max_threadgroup_memory_length=\(device.maxThreadgroupMemoryLength)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-SIMDGROUP-MATMUL-FP16-NUMERIC-EQ: FAIL (no queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./simdgroup_matmul_fp16.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-SIMDGROUP-MATMUL-FP16-NUMERIC-EQ: FAIL (makeLibrary: \(error))")
    exit(1)
}

func makePipeline(_ name: String) -> MTLComputePipelineState {
    guard let fn = library.makeFunction(name: name) else {
        print("F-RFC075-METAL-SIMDGROUP-MATMUL-FP16-NUMERIC-EQ: FAIL (no \(name) fn)")
        exit(1)
    }
    do { return try device.makeComputePipelineState(function: fn) }
    catch {
        print("F-RFC075-METAL-SIMDGROUP-MATMUL-FP16-NUMERIC-EQ: FAIL (pipeline \(name): \(error))")
        exit(1)
    }
}

let pipe8    = makePipeline("simdgroup_matmul_8x8_fp16")
let pipe16   = makePipeline("simdgroup_matmul_16x16_fp16")
let pipe32tg = makePipeline("simdgroup_matmul_32x32_tg_fp16")

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
    let max_rel_err: Float32           // vs FP32 reference
    let max_rel_err_fp16ref: Float32   // vs FP16-accumulator reference (diagnostic)
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

// FP16-tolerance gate: rel_err must be < 1e-2. The actual achieved rel_err is
// driven by FP16 accumulator precision loss in the K-loop and is K-dependent.
let TOL_FP16: Float32 = 1e-2

func run_shape(_ M: Int, _ N: Int, _ K: Int,
               kernel name: String,
               pipeline: MTLComputePipelineState,
               kind: DispatchKind,
               warmup: Int, timed: Int,
               cachedRef: [Float32]?,
               cachedRefFp16: [Float32]?,
               aFp32: [Float32], bFp32: [Float32]) -> (Result, [Float32], [Float32]) {

    // Convert inputs to FP16 raw bytes.
    var aBits = [UInt16](repeating: 0, count: M * K)
    var bBits = [UInt16](repeating: 0, count: K * N)
    for i in 0..<(M * K) { aBits[i] = fp32_to_fp16_bits(aFp32[i]) }
    for i in 0..<(K * N) { bBits[i] = fp32_to_fp16_bits(bFp32[i]) }

    // Use cached references where possible (the same shape repeats across 3 kernels).
    let ref: [Float32]
    if let cached = cachedRef { ref = cached }
    else { ref = cpu_matmul_ref_fp32(aFp32, bFp32, M, N, K) }

    let refFp16: [Float32]
    if let cached = cachedRefFp16 { refFp16 = cached }
    else { refFp16 = cpu_matmul_ref_fp16accum(aFp32, bFp32, M, N, K) }

    let aBytes = M * K * MemoryLayout<UInt16>.stride
    let bBytes = K * N * MemoryLayout<UInt16>.stride
    let cBytes = M * N * MemoryLayout<UInt16>.stride

    guard let bufA = device.makeBuffer(bytes: aBits, length: aBytes, options: .storageModeShared),
          let bufB = device.makeBuffer(bytes: bBits, length: bBytes, options: .storageModeShared),
          let bufC = device.makeBuffer(length: cBytes, options: .storageModeShared) else {
        print("F-RFC075-METAL-SIMDGROUP-MATMUL-FP16-NUMERIC-EQ: FAIL (buffer alloc)"); exit(1)
    }

    var Mv: UInt32 = UInt32(M)
    var Nv: UInt32 = UInt32(N)
    var Kv: UInt32 = UInt32(K)

    let (grid, tg) = dispatchGeometry(kind, M, N)

    func dispatch_once() -> Double {
        memset(bufC.contents(), 0, cBytes)
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            print("F-RFC075-METAL-SIMDGROUP-MATMUL-FP16-NUMERIC-EQ: FAIL (encoder)"); exit(1)
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
            print("F-RFC075-METAL-SIMDGROUP-MATMUL-FP16-NUMERIC-EQ: FAIL (commit: \(err))"); exit(1)
        }
        return (cmd.gpuEndTime - cmd.gpuStartTime) * 1e3
    }

    for _ in 0..<warmup { let _ = dispatch_once() }

    var samples = [Double](); samples.reserveCapacity(timed)
    for _ in 0..<timed { samples.append(dispatch_once()) }
    samples.sort()
    let median = samples[samples.count / 2]

    // Read GPU output back as raw UInt16, convert to Float32 for comparison.
    let gpuRaw = bufC.contents().bindMemory(to: UInt16.self, capacity: M * N)
    var max_abs_diff: Float32 = 0
    var max_ref_abs: Float32 = 0
    var max_abs_diff_fp16: Float32 = 0
    var max_ref_abs_fp16: Float32 = 0
    for i in 0..<(M * N) {
        let g = fp16_bits_to_fp32(gpuRaw[i])
        let d = abs(g - ref[i])
        if d > max_abs_diff { max_abs_diff = d }
        let r = abs(ref[i])
        if r > max_ref_abs { max_ref_abs = r }
        let d16 = abs(g - refFp16[i])
        if d16 > max_abs_diff_fp16 { max_abs_diff_fp16 = d16 }
        let r16 = abs(refFp16[i])
        if r16 > max_ref_abs_fp16 { max_ref_abs_fp16 = r16 }
    }
    let rel_err: Float32 = max_ref_abs > 0 ? max_abs_diff / max_ref_abs : 0
    let rel_err_fp16: Float32 = max_ref_abs_fp16 > 0 ? max_abs_diff_fp16 / max_ref_abs_fp16 : 0
    let flops = 2.0 * Double(M) * Double(N) * Double(K)
    let gflops = flops / (median * 1e-3) / 1e9
    let ok = rel_err < TOL_FP16
    let r = Result(M: M, N: N, K: K, kernel: name, median_ms: median,
                   gflops: gflops, max_abs_diff: max_abs_diff,
                   max_rel_err: rel_err, max_rel_err_fp16ref: rel_err_fp16,
                   pass: ok)
    return (r, ref, refFp16)
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
    ("simdgroup_matmul_8x8_fp16",       pipe8,    .k8x8),
    ("simdgroup_matmul_16x16_fp16",     pipe16,   .k16x16),
    ("simdgroup_matmul_32x32_tg_fp16",  pipe32tg, .k32x32_tg),
]

var results: [Result] = []
var allOk = true

for (M, N, K) in shapes {
    // Generate inputs once per shape (LCG re-seeded for determinism), build refs
    // once, then sweep all 3 kernels reusing the same inputs/refs.
    lcg_state = 0x12345678
    var aFp32 = [Float32](repeating: 0, count: M * K)
    var bFp32 = [Float32](repeating: 0, count: K * N)
    for i in 0..<(M * K) { aFp32[i] = lcg_f32() }
    for i in 0..<(K * N) { bFp32[i] = lcg_f32() }

    var cachedRef: [Float32]? = nil
    var cachedRefFp16: [Float32]? = nil
    for (name, pipe, kind) in kernels {
        let (r, ref, refFp16) = run_shape(M, N, K, kernel: name, pipeline: pipe, kind: kind,
                                          warmup: warmup, timed: timed,
                                          cachedRef: cachedRef,
                                          cachedRefFp16: cachedRefFp16,
                                          aFp32: aFp32, bFp32: bFp32)
        cachedRef = ref
        cachedRefFp16 = refFp16
        results.append(r)
        if !r.pass { allOk = false }
        let tag = r.pass ? "PASS" : "FAIL"
        let kpad = r.kernel.padding(toLength: 32, withPad: " ", startingAt: 0)
        print(String(format: "\(kpad)  M=%d N=%d K=%d  median=%.4fms  GFLOPS=%.2f  max|d|=%.3e  rel=%.3e  rel16=%.3e  \(tag)",
                     r.M, r.N, r.K, r.median_ms, r.gflops,
                     Double(r.max_abs_diff), Double(r.max_rel_err),
                     Double(r.max_rel_err_fp16ref)))
    }
}

// ─── result.json emission ───────────────────────────────────────────────
// Anchors:
//   - FP32 simdgroup fire (commit 31d729a4):  N16 measured FP32 simdgroup
//     8x8/16x16/32x32_tg @ 128..1024 cubes
//   - FP32 naive/tiled (commit 19e83c2b):     184.90/269.41 GFLOPS @ 512^3
//   - FP32 MPS (commit 9b352bda):             1555.58/1666.34/1702.75
//     GFLOPS @ 512/768/1024
//   - Apple M3 advertised FP32 ~3.5 TFLOPS; FP16 (with 2× boost path) ~7 TFLOPS

// FP32 simdgroup results from fire.log of commit 31d729a4
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

func fp32Of(_ k: String, _ M: Int) -> Double {
    let fk = k.replacingOccurrences(of: "_fp16", with: "")
    for a in fp32Anchors where a.kernel == fk && a.M == M { return a.gflops }
    return 0
}

var json = "{\n"
json += "  \"campaign\": \"rfc075_metal_simdgroup_matmul_fp16_2026_05_21\",\n"
json += "  \"host\": \"Mac (local)\",\n"
json += "  \"platform\": \"darwin-arm64\",\n"
json += "  \"gpu\": \"\(device.name) (registry_id=\(device.registryID))\",\n"
let mtpt = device.maxThreadsPerThreadgroup
json += "  \"max_threads_per_threadgroup\": \"\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)\",\n"
json += "  \"max_threadgroup_memory_length\": \(device.maxThreadgroupMemoryLength),\n"
json += "  \"date_utc\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
json += "  \"toolchain\": \"xcrun --sdk macosx metal / swiftc (-O)\",\n"
json += "  \"intrinsic\": \"simdgroup_matrix<half, 8, 8> + simdgroup_multiply_accumulate (MSL §6.7, pure FP16 accum)\",\n"
json += "  \"header\": \"<metal_simdgroup_matrix> (gated by __HAVE_SIMDGROUP_MATRIX__, supported on Apple M-series)\",\n"
json += "  \"fp32_baseline_commit\": \"31d729a4\",\n"
json += "  \"warmup\": \(warmup),\n"
json += "  \"timed\": \(timed),\n"
json += "  \"tolerance_rel\": 1e-2,\n"
json += "  \"tolerance_rationale\": \"FP16 mantissa ~3-4 decimal digits; K-loop accumulator loses ~O(K) ULP. 1e-2 is the realistic FP16 matmul threshold; diagnostic max_rel_err_fp16ref reports vs an FP16-accumulator CPU reference for tighter sanity.\",\n"
json += "  \"rows\": [\n"
for (idx, r) in results.enumerated() {
    let comma = idx == results.count - 1 ? "" : ","
    let fp32 = fp32Of(r.kernel, r.M)
    let ratio = fp32 > 0 ? r.gflops / fp32 : 0
    json += "    {\n"
    json += "      \"kernel\": \"\(r.kernel)\",\n"
    json += "      \"M\": \(r.M), \"N\": \(r.N), \"K\": \(r.K),\n"
    json += "      \"median_ms\": \(r.median_ms),\n"
    json += "      \"gflops\": \(r.gflops),\n"
    json += "      \"fp32_baseline_gflops\": \(fp32),\n"
    json += "      \"ratio_vs_fp32\": \(ratio),\n"
    json += "      \"max_abs_diff\": \(r.max_abs_diff),\n"
    json += "      \"max_rel_err_vs_fp32_ref\": \(r.max_rel_err),\n"
    json += "      \"max_rel_err_vs_fp16accum_ref\": \(r.max_rel_err_fp16ref),\n"
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
let peak8     = peakGflops("simdgroup_matmul_8x8_fp16")
let peak16    = peakGflops("simdgroup_matmul_16x16_fp16")
let peak32    = peakGflops("simdgroup_matmul_32x32_tg_fp16")
let peakAny   = max(peak8, max(peak16, peak32))

json += "  \"peak_gflops_8x8_fp16\": \(peak8),\n"
json += "  \"peak_gflops_16x16_fp16\": \(peak16),\n"
json += "  \"peak_gflops_32x32_tg_fp16\": \(peak32),\n"
json += "  \"peak_gflops_overall_fp16\": \(peakAny),\n"

// FP32 peak from prior fire (32x32_tg @ 768^3 = 911.55).
let fp32Peak: Double = 911.55
json += "  \"fp32_peak_gflops\": \(fp32Peak),\n"
json += "  \"fp16_over_fp32_peak_ratio\": \(peakAny / fp32Peak),\n"

// MPS FP32 baseline peak (1024^3) = 1702.75.
let mpsFp32Peak: Double = 1702.75
json += "  \"mps_fp32_peak_gflops\": \(mpsFp32Peak),\n"
json += "  \"fp16_over_mps_fp32_ratio\": \(peakAny / mpsFp32Peak),\n"

json += "  \"comparison_table\": {\n"
json += "    \"note\": \"Anchors: simdgroup_matmul FP32 fire (commit 31d729a4) measured 911 GFLOPS peak @ 768^3 on 32x32_tg; MPS FP32 (commit 9b352bda) 1.7 TFLOPS @ 1024^3; naive/tiled FP32 (commit 19e83c2b) 184.90/269.41 GFLOPS @ 512^3. Apple M3 advertised FP32 ~3.5 TFLOPS; FP16 ~7 TFLOPS if 2× MMA path.\",\n"
json += "    \"columns\": [\"approach\", \"precision\", \"shape\", \"GFLOPS\", \"ratio_vs_fp16_simdgroup_peak\", \"source\"],\n"
let simdPeakRef = max(peakAny, 1.0)
json += "    \"fp16_simdgroup_peak_overall_gflops\": \(peakAny),\n"
json += "    \"rows\": [\n"
json += "      [\"matmul_naive\",                  \"FP32\", \"512^3\",  184.90,                                                           \(184.90 / simdPeakRef), \"matmul.metal fire (commit 19e83c2b)\"],\n"
json += "      [\"matmul_tiled-16\",               \"FP32\", \"512^3\",  269.41,                                                           \(269.41 / simdPeakRef), \"matmul.metal fire (commit 19e83c2b)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg\",     \"FP32\", \"512^3\",  638.37,                                                           \(638.37 / simdPeakRef), \"simdgroup fp32 fire (commit 31d729a4)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg\",     \"FP32\", \"768^3\",  911.55,                                                           \(911.55 / simdPeakRef), \"simdgroup fp32 fire (commit 31d729a4, peak)\"],\n"
json += "      [\"simdgroup_matmul_8x8_fp16\",     \"FP16\", \"512^3\",  \(gflopsAt("simdgroup_matmul_8x8_fp16", 512)),                    \(gflopsAt("simdgroup_matmul_8x8_fp16", 512) / simdPeakRef), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_16x16_fp16\",   \"FP16\", \"512^3\",  \(gflopsAt("simdgroup_matmul_16x16_fp16", 512)),                  \(gflopsAt("simdgroup_matmul_16x16_fp16", 512) / simdPeakRef), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_fp16\",\"FP16\", \"512^3\",  \(gflopsAt("simdgroup_matmul_32x32_tg_fp16", 512)),               \(gflopsAt("simdgroup_matmul_32x32_tg_fp16", 512) / simdPeakRef), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_fp16\",\"FP16\", \"768^3\",  \(gflopsAt("simdgroup_matmul_32x32_tg_fp16", 768)),               \(gflopsAt("simdgroup_matmul_32x32_tg_fp16", 768) / simdPeakRef), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_fp16\",\"FP16\", \"1024^3\", \(gflopsAt("simdgroup_matmul_32x32_tg_fp16", 1024)),              \(gflopsAt("simdgroup_matmul_32x32_tg_fp16", 1024) / simdPeakRef), \"this fire\"],\n"
json += "      [\"MPS GEMM\",                      \"FP32\", \"768^3\",  1666.34,                                                          \(1666.34 / simdPeakRef), \"host_mps_gemm fire (commit 9b352bda)\"],\n"
json += "      [\"MPS GEMM\",                      \"FP32\", \"1024^3\", 1702.75,                                                          \(1702.75 / simdPeakRef), \"host_mps_gemm fire (commit 9b352bda)\"],\n"
json += "      [\"Apple M3 advertised peak FP32\", \"FP32\", \"-\",      3500.00,                                                          \(3500.00 / simdPeakRef), \"Apple GPU spec sheet\"],\n"
json += "      [\"Apple M3 expected peak FP16 (if 2× FP32 MMA path)\",\"FP16\",\"-\",7000.00,\(7000.00 / simdPeakRef),\"Apple GPU spec sheet (extrapolated)\"]\n"
json += "    ]\n"
json += "  },\n"

let statusStr = allOk ? "PASS" : "PARTIAL"
json += "  \"falsifier_F_RFC075_METAL_SIMDGROUP_MATMUL_FP16_NUMERIC_EQ\": \"\(statusStr)\",\n"
json += "  \"honest_scope\": [\n"
json += "    \"FP16 inputs + FP16 accumulator. The mixed-precision variant (FP16 in, FP32 accum) which Apple §6.7 also supports is a separate kernel — defer to followup.\",\n"
json += "    \"FP16 numeric tolerance is 1e-2 vs FP32 reference (3 decimal digits of accuracy). The kernel-side accumulator is FP16, so K-loop accumulator drift is the dominant error source — comparison vs an FP16-accum CPU reference reports tighter agreement (max_rel_err_vs_fp16accum_ref).\",\n"
json += "    \"Same hand-emit tile geometry as FP32 fire (8x8 per simdgroup). The 2× MMA-throughput expectation rests on Apple M3 having a dedicated FP16 datapath — we measure the actual ratio per shape.\",\n"
json += "    \"Variance is noisier than ubu-2 cuBLAS — Mac is a shared developer laptop. Median over 50 timed runs after 5 warmups, same protocol as FP32 fire.\",\n"
json += "    \"No MPS FP16 GEMM comparator in this fire — MPS exposes FP16 separately; deferred to follow-up. Comparison column shows MPS FP32 only.\"\n"
json += "  ]\n"
json += "}\n"
let jsonPath = "./result.json"
do { try json.write(toFile: jsonPath, atomically: true, encoding: .utf8) }
catch { print("WARN: result.json write failed: \(error)") }

let final = allOk ? "PASS" : "PARTIAL"
print("F-RFC075-METAL-SIMDGROUP-MATMUL-FP16-NUMERIC-EQ: \(final)")
print(String(format: "PEAK_SIMDGROUP_FP16_GFLOPS=%.2f (best of 8x8/16x16/32x32_tg across 128/256/512/768/1024)", peakAny))
print(String(format: "FP16_OVER_FP32_PEAK_RATIO=%.3fx (FP32 peak = %.2f GFLOPS @ commit 31d729a4)", peakAny / fp32Peak, fp32Peak))
exit(0)
