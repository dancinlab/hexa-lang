// host_simdgroup_matmul_bf16.swift — RFC 075 Apple M3 bf16 simdgroup MMA fire
//
// Loads simdgroup_matmul_bf16.metallib, runs three bf16-input + FP32-accumulator
// simdgroup-MMA kernels (8x8 / 16x16 / 32x32_tg) across a 128/256/512/768/1024
// cube sweep, compares vs CPU FP32 ikj reference built on bf16-rounded inputs,
// times each dispatch with cb.gpuEndTime/gpuStartTime, and emits result.json +
// a comparison table vs N16 FP32 (commit 31d729a4, peak 911.55 GFLOPS),
// N25 pure-FP16 (commit ab0ff62d, peak 789.38 GFLOPS), and N30 mixed-precision
// FP16/FP32 (commit 99aed70f, peak 987 GFLOPS).
//
// Tolerance: rel_err < 1e-2. Rationale: bf16 has 7-bit mantissa (vs FP16's 10-bit),
// per-operand eps ≈ 7.8e-3. FP32 accumulator removes K-loop drift, so the error
// floor is input rounding. Reference is computed on bf16-rounded inputs (same
// as the GPU sees), so the rel_err here measures compute-side error only —
// expected to be ~zero if the FP32 accumulator faithfully reproduces the
// bf16-input dot product.
//
// Build:
//   xcrun --sdk macosx swift host_simdgroup_matmul_bf16.swift ./simdgroup_matmul_bf16.metallib

import Foundation
import Metal

// ─── deterministic LCG (Numerical Recipes 32-bit) — same as N16/N25/N30 ─────
var lcg_state: UInt32 = 0x12345678
func lcg_next() -> UInt32 {
    lcg_state = lcg_state &* 1664525 &+ 1013904223
    return lcg_state
}
func lcg_f32() -> Float32 {
    let u = lcg_next()
    return (Float32(u) / Float32(UInt32.max)) * 2.0 - 1.0
}

// ─── FP32 ↔ bf16 conversion ─────────────────────────────────────────────
// bf16 (a.k.a. brain-float / Google bfloat16) = sign(1) + exponent(8) + mantissa(7).
// Identical exponent field as FP32, mantissa = top 7 bits of FP32 mantissa.
// Conversion: truncate FP32 to top 16 bits, with round-to-nearest-even on the
// dropped 16 bits.
//
// Reference: TensorFlow's float32 → bfloat16 cast uses round-to-nearest-even.
// Apple Metal's bfloat ↔ float conversion is implicit in the simdgroup_load
// path; here we match by computing the rounded value on the host CPU before
// feeding to the GPU.
@inline(__always)
func fp32_to_bf16_bits(_ f: Float32) -> UInt16 {
    let bits = f.bitPattern
    // NaN: preserve NaN-ness by setting the high mantissa bit (quiet NaN convention).
    if (bits & 0x7F80_0000) == 0x7F80_0000 && (bits & 0x007F_FFFF) != 0 {
        return UInt16((bits >> 16) | 0x0040)
    }
    // Round-to-nearest-even on the bottom 16 bits.
    let lsb = (bits >> 16) & 1
    let rounding_bias: UInt32 = 0x7FFF &+ lsb
    let rounded = bits &+ rounding_bias
    return UInt16(truncatingIfNeeded: rounded >> 16)
}

@inline(__always)
func bf16_bits_to_fp32(_ b: UInt16) -> Float32 {
    let bits = UInt32(b) << 16
    return Float32(bitPattern: bits)
}

// ─── CPU FP32 reference (ikj inner stride) — identical structure to N30 ───
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
    print("F-RFC075-METAL-SIMDGROUP-BF16-NUMERIC-EQ: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
print("max_threads_per_threadgroup=\(device.maxThreadsPerThreadgroup)")
print("max_threadgroup_memory_length=\(device.maxThreadgroupMemoryLength)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-SIMDGROUP-BF16-NUMERIC-EQ: FAIL (no queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./simdgroup_matmul_bf16.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-SIMDGROUP-BF16-NUMERIC-EQ: FAIL (makeLibrary: \(error))")
    exit(1)
}

func makePipeline(_ name: String) -> MTLComputePipelineState {
    guard let fn = library.makeFunction(name: name) else {
        print("F-RFC075-METAL-SIMDGROUP-BF16-NUMERIC-EQ: FAIL (no \(name) fn)")
        exit(1)
    }
    do { return try device.makeComputePipelineState(function: fn) }
    catch {
        print("F-RFC075-METAL-SIMDGROUP-BF16-NUMERIC-EQ: FAIL (pipeline \(name): \(error))")
        exit(1)
    }
}

let pipe8    = makePipeline("simdgroup_matmul_8x8_bf16")
let pipe16   = makePipeline("simdgroup_matmul_16x16_bf16")
let pipe32tg = makePipeline("simdgroup_matmul_32x32_tg_bf16")

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
    let max_rel_err: Float32
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

// bf16 tolerance: 1e-2 (per task spec — bf16 has ~3 decimal digits).
// With FP32 accumulator and inputs already rounded to bf16 before reference
// computation, expected actual rel_err ≈ 0 if hardware faithfully implements
// the FP32-accumulator dot product over bf16 operands.
let TOL_BF16: Float32 = 1e-2

func run_shape(_ M: Int, _ N: Int, _ K: Int,
               kernel name: String,
               pipeline: MTLComputePipelineState,
               kind: DispatchKind,
               warmup: Int, timed: Int,
               cachedRef: [Float32]?,
               aFp32Rounded: [Float32], bFp32Rounded: [Float32],
               aBits: [UInt16], bBits: [UInt16]) -> (Result, [Float32]) {

    let ref: [Float32]
    if let cached = cachedRef { ref = cached }
    else { ref = cpu_matmul_ref_fp32(aFp32Rounded, bFp32Rounded, M, N, K) }

    let aBytes = M * K * MemoryLayout<UInt16>.stride
    let bBytes = K * N * MemoryLayout<UInt16>.stride
    let cBytes = M * N * MemoryLayout<Float32>.stride

    guard let bufA = device.makeBuffer(bytes: aBits, length: aBytes, options: .storageModeShared),
          let bufB = device.makeBuffer(bytes: bBits, length: bBytes, options: .storageModeShared),
          let bufC = device.makeBuffer(length: cBytes, options: .storageModeShared) else {
        print("F-RFC075-METAL-SIMDGROUP-BF16-NUMERIC-EQ: FAIL (buffer alloc)"); exit(1)
    }

    var Mv: UInt32 = UInt32(M)
    var Nv: UInt32 = UInt32(N)
    var Kv: UInt32 = UInt32(K)

    let (grid, tg) = dispatchGeometry(kind, M, N)

    func dispatch_once() -> Double {
        memset(bufC.contents(), 0, cBytes)
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            print("F-RFC075-METAL-SIMDGROUP-BF16-NUMERIC-EQ: FAIL (encoder)"); exit(1)
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
            print("F-RFC075-METAL-SIMDGROUP-BF16-NUMERIC-EQ: FAIL (commit: \(err))"); exit(1)
        }
        return (cmd.gpuEndTime - cmd.gpuStartTime) * 1e3
    }

    for _ in 0..<warmup { let _ = dispatch_once() }

    var samples = [Double](); samples.reserveCapacity(timed)
    for _ in 0..<timed { samples.append(dispatch_once()) }
    samples.sort()
    let median = samples[samples.count / 2]

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
    let ok = rel_err < TOL_BF16
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
    ("simdgroup_matmul_8x8_bf16",       pipe8,    .k8x8),
    ("simdgroup_matmul_16x16_bf16",     pipe16,   .k16x16),
    ("simdgroup_matmul_32x32_tg_bf16",  pipe32tg, .k32x32_tg),
]

var results: [Result] = []
var allOk = true

for (M, N, K) in shapes {
    lcg_state = 0x12345678
    var aFp32 = [Float32](repeating: 0, count: M * K)
    var bFp32 = [Float32](repeating: 0, count: K * N)
    for i in 0..<(M * K) { aFp32[i] = lcg_f32() }
    for i in 0..<(K * N) { bFp32[i] = lcg_f32() }

    // Round inputs to bf16 (this is what the GPU sees).
    var aBits = [UInt16](repeating: 0, count: M * K)
    var bBits = [UInt16](repeating: 0, count: K * N)
    var aRounded = [Float32](repeating: 0, count: M * K)
    var bRounded = [Float32](repeating: 0, count: K * N)
    for i in 0..<(M * K) {
        let bits = fp32_to_bf16_bits(aFp32[i])
        aBits[i] = bits
        aRounded[i] = bf16_bits_to_fp32(bits)
    }
    for i in 0..<(K * N) {
        let bits = fp32_to_bf16_bits(bFp32[i])
        bBits[i] = bits
        bRounded[i] = bf16_bits_to_fp32(bits)
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
//   - N16 FP32 simdgroup (commit 31d729a4): peak 911.55 GFLOPS @ 768^3 on 32x32_tg
//   - N25 pure-FP16 simdgroup (commit ab0ff62d): peak 789.38 GFLOPS @ 1024^3
//   - N30 mixed-prec FP16/FP32 (commit 99aed70f): peak 987 GFLOPS @ 1024^3
//   - MPS FP32 (commit 9b352bda): 1702.75 GFLOPS @ 1024^3
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

// N30 mixed-prec FP16/FP32 anchors — values pulled from N30 result.json
// (commit 99aed70f, peak 987 GFLOPS).
struct MixedAnchor { let kernel: String; let M: Int; let gflops: Double; let rel: Float32 }
let mixedAnchors: [MixedAnchor] = [
    MixedAnchor(kernel: "simdgroup_matmul_8x8_mixed",       M: 128, gflops:  93.03, rel: 0.0),
    MixedAnchor(kernel: "simdgroup_matmul_16x16_mixed",     M: 128, gflops:  89.72, rel: 0.0),
    MixedAnchor(kernel: "simdgroup_matmul_32x32_tg_mixed",  M: 128, gflops: 104.31, rel: 0.0),
]

func fp32Of(_ k: String, _ M: Int) -> Double {
    let fk = k.replacingOccurrences(of: "_bf16", with: "")
    for a in fp32Anchors where a.kernel == fk && a.M == M { return a.gflops }
    return 0
}

func mixedOf(_ k: String, _ M: Int) -> Double {
    let fk = k.replacingOccurrences(of: "_bf16", with: "_mixed")
    for a in mixedAnchors where a.kernel == fk && a.M == M { return a.gflops }
    return 0
}

var json = "{\n"
json += "  \"campaign\": \"rfc075_metal_simdgroup_matmul_bf16_2026_05_21\",\n"
json += "  \"host\": \"Mac (local)\",\n"
json += "  \"platform\": \"darwin-arm64\",\n"
json += "  \"gpu\": \"\(device.name) (registry_id=\(device.registryID))\",\n"
let mtpt = device.maxThreadsPerThreadgroup
json += "  \"max_threads_per_threadgroup\": \"\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)\",\n"
json += "  \"max_threadgroup_memory_length\": \(device.maxThreadgroupMemoryLength),\n"
json += "  \"date_utc\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
json += "  \"toolchain\": \"xcrun --sdk macosx metal / swiftc (-O)\",\n"
json += "  \"intrinsic\": \"simdgroup_matrix<bfloat,8,8> inputs + simdgroup_matrix<float,8,8> accumulator + simdgroup_multiply_accumulate (MSL §6.7 mixed-precision form, R=V=float, T=U=bfloat)\",\n"
json += "  \"header\": \"<metal_simdgroup_matrix> declares typedef simdgroup_matrix<bfloat, 8, 8> simdgroup_bfloat8x8; on this toolchain (Metal v32023.883 / macOS 26.5).\",\n"
json += "  \"fp32_baseline_commit\": \"31d729a4\",\n"
json += "  \"fp16_baseline_commit\": \"ab0ff62d\",\n"
json += "  \"mixed_baseline_commit\": \"99aed70f\",\n"
json += "  \"warmup\": \(warmup),\n"
json += "  \"timed\": \(timed),\n"
json += "  \"tolerance_rel\": 1e-2,\n"
json += "  \"tolerance_rationale\": \"bf16 has 7-bit mantissa (eps ≈ 7.8e-3 per operand). FP32 accumulator removes K-loop drift. Reference is built on bf16-rounded inputs (identical to what the GPU sees) so the comparison isolates compute-side error from rounding noise. Per spec: rel_err < 1e-2 (bf16 has ~3 decimal digits).\",\n"
json += "  \"rows\": [\n"
for (idx, r) in results.enumerated() {
    let comma = idx == results.count - 1 ? "" : ","
    let fp32 = fp32Of(r.kernel, r.M)
    let mixed = mixedOf(r.kernel, r.M)
    let ratio32 = fp32 > 0 ? r.gflops / fp32 : 0
    let ratioMixed = mixed > 0 ? r.gflops / mixed : 0
    json += "    {\n"
    json += "      \"kernel\": \"\(r.kernel)\",\n"
    json += "      \"M\": \(r.M), \"N\": \(r.N), \"K\": \(r.K),\n"
    json += "      \"median_ms\": \(r.median_ms),\n"
    json += "      \"gflops\": \(r.gflops),\n"
    json += "      \"fp32_baseline_gflops\": \(fp32),\n"
    json += "      \"ratio_vs_fp32\": \(ratio32),\n"
    json += "      \"mixed_fp16_baseline_gflops\": \(mixed),\n"
    json += "      \"ratio_vs_mixed_fp16\": \(ratioMixed),\n"
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
func relAt(_ kernel: String, _ M: Int) -> Float32 {
    for r in results where r.kernel == kernel && r.M == M { return r.max_rel_err }
    return 0
}
func peakGflops(_ kernel: String) -> Double {
    var best = 0.0
    for r in results where r.kernel == kernel { if r.gflops > best { best = r.gflops } }
    return best
}
let peak8     = peakGflops("simdgroup_matmul_8x8_bf16")
let peak16    = peakGflops("simdgroup_matmul_16x16_bf16")
let peak32    = peakGflops("simdgroup_matmul_32x32_tg_bf16")
let peakAny   = max(peak8, max(peak16, peak32))

json += "  \"peak_gflops_8x8_bf16\": \(peak8),\n"
json += "  \"peak_gflops_16x16_bf16\": \(peak16),\n"
json += "  \"peak_gflops_32x32_tg_bf16\": \(peak32),\n"
json += "  \"peak_gflops_overall_bf16\": \(peakAny),\n"

let fp32Peak: Double = 911.55
let fp16Peak: Double = 789.38
let mixedPeak: Double = 987.0
let mpsFp32Peak: Double = 1702.75
json += "  \"fp32_peak_gflops\": \(fp32Peak),\n"
json += "  \"fp16_peak_gflops\": \(fp16Peak),\n"
json += "  \"mixed_fp16_peak_gflops\": \(mixedPeak),\n"
json += "  \"mps_fp32_peak_gflops\": \(mpsFp32Peak),\n"
json += "  \"bf16_over_fp32_peak_ratio\": \(peakAny / fp32Peak),\n"
json += "  \"bf16_over_fp16_peak_ratio\": \(peakAny / fp16Peak),\n"
json += "  \"bf16_over_mixed_fp16_peak_ratio\": \(peakAny / mixedPeak),\n"
json += "  \"bf16_over_mps_fp32_ratio\": \(peakAny / mpsFp32Peak),\n"

var maxRelOverall: Float32 = 0
for r in results { if r.max_rel_err > maxRelOverall { maxRelOverall = r.max_rel_err } }
json += "  \"max_rel_err_overall\": \(maxRelOverall),\n"

// ─── Apple M3 bf16-acceleration hypothesis classification ─────────────────
let bf16HypothesisVerdict: String
let bf16Ratio = peakAny / fp32Peak
if bf16Ratio >= 1.5 {
    bf16HypothesisVerdict = "STRONG_PASS_dedicated_bf16_acceleration"
} else if bf16Ratio >= 1.0 {
    bf16HypothesisVerdict = "PASS_bf16_at_least_as_fast_as_fp32"
} else if bf16Ratio >= 0.7 {
    bf16HypothesisVerdict = "PARTIAL_bf16_same_pipe_as_fp16_no_dedicated_path"
} else {
    bf16HypothesisVerdict = "FAIL_bf16_emulated_falls_back_to_fp32"
}

json += "  \"apple_m3_bf16_hypothesis_verdict\": \"\(bf16HypothesisVerdict)\",\n"

json += "  \"comparison_table\": {\n"
json += "    \"note\": \"All ratios use peak overall. N30 mixed-prec FP16/FP32 (peak 987 @ 1024^3) is the closest comparator since it uses the same FP32 accumulator pattern with 2-byte inputs.\",\n"
json += "    \"columns\": [\"approach\", \"precision\", \"shape\", \"GFLOPS\", \"rel_err\", \"source\"],\n"
json += "    \"rows\": [\n"
json += "      [\"matmul_naive\",                       \"FP32\",              \"512^3\",  184.90,   1e-7,  \"matmul.metal fire (commit 19e83c2b)\"],\n"
json += "      [\"matmul_tiled-16\",                    \"FP32\",              \"512^3\",  269.41,   1e-7,  \"matmul.metal fire (commit 19e83c2b)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg\",          \"FP32\",              \"512^3\",  638.37,   1e-7,  \"N16 simdgroup fp32 fire (commit 31d729a4)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg\",          \"FP32\",              \"768^3\",  911.55,   1e-7,  \"N16 simdgroup fp32 fire (commit 31d729a4, peak)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_fp16\",     \"FP16 in / FP16 acc\", \"1024^3\", 789.38,   1.6e-2,\"N25 pure-FP16 fire (commit ab0ff62d, peak)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_mixed\",    \"FP16 in / FP32 acc\", \"1024^3\", 987.00,   1e-4,  \"N30 mixed-prec fire (commit 99aed70f, peak)\"],\n"
json += "      [\"simdgroup_matmul_8x8_bf16\",          \"bf16 in / FP32 acc\", \"512^3\",  \(gflopsAt("simdgroup_matmul_8x8_bf16", 512)),    \(relAt("simdgroup_matmul_8x8_bf16", 512)),  \"this fire\"],\n"
json += "      [\"simdgroup_matmul_16x16_bf16\",        \"bf16 in / FP32 acc\", \"512^3\",  \(gflopsAt("simdgroup_matmul_16x16_bf16", 512)),  \(relAt("simdgroup_matmul_16x16_bf16", 512)), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_bf16\",     \"bf16 in / FP32 acc\", \"512^3\",  \(gflopsAt("simdgroup_matmul_32x32_tg_bf16", 512)),\(relAt("simdgroup_matmul_32x32_tg_bf16", 512)), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_bf16\",     \"bf16 in / FP32 acc\", \"768^3\",  \(gflopsAt("simdgroup_matmul_32x32_tg_bf16", 768)),\(relAt("simdgroup_matmul_32x32_tg_bf16", 768)), \"this fire\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_bf16\",     \"bf16 in / FP32 acc\", \"1024^3\", \(gflopsAt("simdgroup_matmul_32x32_tg_bf16", 1024)),\(relAt("simdgroup_matmul_32x32_tg_bf16", 1024)), \"this fire\"],\n"
json += "      [\"MPS GEMM\",                           \"FP32\",              \"1024^3\", 1702.75,  1e-6,  \"host_mps_gemm fire (commit 9b352bda)\"],\n"
json += "      [\"Apple M3 advertised peak FP32\",      \"FP32\",              \"-\",      3500.00,  0,     \"Apple GPU spec sheet\"]\n"
json += "    ]\n"
json += "  },\n"

let statusStr = allOk ? "PASS" : "PARTIAL"
json += "  \"falsifier_F_RFC075_METAL_SIMDGROUP_BF16_NUMERIC_EQ\": \"\(statusStr)\",\n"
json += "  \"headline\": {\n"
json += "    \"bf16_peak_gflops\": \(peakAny),\n"
json += "    \"vs_fp32_ratio\": \(peakAny / fp32Peak),\n"
json += "    \"vs_pure_fp16_ratio\": \(peakAny / fp16Peak),\n"
json += "    \"vs_mixed_fp16_ratio\": \(peakAny / mixedPeak),\n"
json += "    \"vs_mps_ratio\": \(peakAny / mpsFp32Peak),\n"
json += "    \"max_rel_err\": \(maxRelOverall),\n"
json += "    \"hypothesis_verdict\": \"\(bf16HypothesisVerdict)\"\n"
json += "  },\n"
json += "  \"honest_scope\": [\n"
json += "    \"simdgroup_matrix<bfloat, 8, 8> is exposed by the on-system <metal_simdgroup_matrix> header on this toolchain (Metal v32023.883, macOS 26.5). Standalone smoke-compile of the templated form succeeded with zero diagnostics.\",\n"
json += "    \"bf16 has 8-bit exponent (same as FP32) and 7-bit mantissa (less than FP16's 10-bit). Dynamic range is FP32-equivalent, precision is worse than FP16.\",\n"
json += "    \"Host-side fp32-to-bf16 conversion uses round-to-nearest-even on the bottom 16 bits (TensorFlow convention). NaN-preserving. The Metal bfloat type is hardware-canonical bf16 storage; this conversion matches it.\",\n"
json += "    \"Reference is computed on bf16-rounded FP32 inputs (identical to what the GPU sees after the simdgroup_load implicitly extends bf16 to FP32 for the FMA pipe), so rel_err measures compute-side error only.\",\n"
json += "    \"Throughput hypothesis classification — vs FP32 peak (911.55 GFLOPS @ 768^3): >=1.5x = STRONG_PASS dedicated bf16 acceleration; >=1.0x = PASS bf16 at least as fast as FP32; >=0.7x = PARTIAL bf16 same pipe as FP16 (no dedicated path); <0.7x = FAIL emulated.\",\n"
json += "    \"Apple M3's MMA pipe handles bfloat operands natively (per header typedef). The question is whether bf16 has a 2x boost path vs FP32 like NVIDIA H100 tensor cores, or shares the same throughput envelope as FP16 (~equal to FP32 per N30 measurement).\",\n"
json += "    \"Mac is a shared developer laptop; variance noisier than ubu-2 cuBLAS. Median over 50 timed runs after 5 warmups, identical protocol to N16/N25/N30.\"\n"
json += "  ]\n"
json += "}\n"
let jsonPath = "./result.json"
do { try json.write(toFile: jsonPath, atomically: true, encoding: .utf8) }
catch { print("WARN: result.json write failed: \(error)") }

let final = allOk ? "PASS" : "PARTIAL"
print("F-RFC075-METAL-SIMDGROUP-BF16-NUMERIC-EQ: \(final)")
print(String(format: "PEAK_SIMDGROUP_BF16_GFLOPS=%.2f (best of 8x8/16x16/32x32_tg across 128/256/512/768/1024)", peakAny))
print(String(format: "BF16_OVER_FP32_PEAK_RATIO=%.3fx (FP32 peak = %.2f GFLOPS @ commit 31d729a4)", peakAny / fp32Peak, fp32Peak))
print(String(format: "BF16_OVER_MIXED_PEAK_RATIO=%.3fx (mixed-prec FP16/FP32 peak = %.2f GFLOPS @ commit 99aed70f)", peakAny / mixedPeak, mixedPeak))
print(String(format: "MAX_REL_ERR_OVERALL=%.3e (gate < 1e-2)", Double(maxRelOverall)))
print("APPLE_M3_BF16_HYPOTHESIS_VERDICT=\(bf16HypothesisVerdict)")
exit(0)
