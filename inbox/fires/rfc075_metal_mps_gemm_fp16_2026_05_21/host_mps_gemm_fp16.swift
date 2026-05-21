// host_mps_gemm_fp16.swift — RFC 075 Metal/MPS FP16 GEMM baseline (Apple-side, FP16 dtype)
//
// Companion to host_mps_gemm.swift (FP32 baseline @ commit 9b352bda).
// Asks the Apple M3 FP16 hypothesis: does MPSMatrixMultiplication on FP16 inputs
// hit ~2× FP32 throughput (indicating a dedicated FP16 MMA path Apple uses
// internally but does NOT expose via simdgroup_matrix<half>) — or ~1× FP32
// (Apple M3 truly has no FP16 boost anywhere)?
//
// N25 (rfc075_metal_simdgroup_matmul_fp16_2026_05_21) showed hand-emit
// simdgroup_matrix<half> FP16 peaked at 789 GFLOPS — 0.87× the FP32 simdgroup
// peak (911 GFLOPS @ 768^3). MPS is the next probe surface.
//
// Apple docs:
//   - MPSMatrixDescriptor.dataType: https://developer.apple.com/documentation/metalperformanceshaders/mpsmatrixdescriptor
//   - MPSDataType: https://developer.apple.com/documentation/metalperformanceshaders/mpsdatatype
//
// FP16 numeric tolerance: rel_err < 1e-2 vs FP16-accum CPU reference (FP16 mantissa
// is ~3-4 decimal digits, K-loop accumulator loses O(K) ULP).
//
// Build/run:
//   xcrun --sdk macosx swiftc -O host_mps_gemm_fp16.swift -o host_mps_gemm_fp16
//   ./host_mps_gemm_fp16

import Foundation
import Metal
import MetalPerformanceShaders

// ---- deterministic LCG (matches N7/N25 convention) ----
struct LCG {
    var state: UInt64
    init(_ seed: UInt64) { self.state = seed }
    mutating func nextF32() -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let bits24 = UInt32(truncatingIfNeeded: state >> 40) & 0xFFFFFF
        return (Float(bits24) / Float(1 << 23)) - 1.0
    }
}

// Fill an MTLBuffer with FP16 values derived from LCG-generated FP32 → Float16.
func fillBufferFP16(_ buf: MTLBuffer, count: Int, seed: UInt64) -> [Float] {
    let ptr = buf.contents().bindMemory(to: Float16.self, capacity: count)
    var lcg = LCG(seed)
    var fp32_mirror: [Float] = []
    fp32_mirror.reserveCapacity(count)
    for i in 0..<count {
        let v = lcg.nextF32()
        ptr[i] = Float16(v)
        fp32_mirror.append(Float(ptr[i])) // round-trip via FP16 so CPU ref sees the
                                          // same quantization the GPU does
    }
    return fp32_mirror
}

// ---- stats ----
struct Stats {
    let median_ms: Double
    let mean_ms: Double
    let std_ms: Double
    let min_ms: Double
    let max_ms: Double
}

func stats(_ samples: [Double]) -> Stats {
    let sorted = samples.sorted()
    let n = sorted.count
    let median = (n % 2 == 1)
        ? sorted[n/2]
        : 0.5 * (sorted[n/2 - 1] + sorted[n/2])
    let mean = samples.reduce(0, +) / Double(n)
    let varSum = samples.reduce(0.0) { acc, v in acc + (v - mean) * (v - mean) }
    let std = (n > 1) ? (varSum / Double(n - 1)).squareRoot() : 0.0
    return Stats(
        median_ms: median,
        mean_ms: mean,
        std_ms: std,
        min_ms: sorted.first ?? 0,
        max_ms: sorted.last ?? 0
    )
}

// ---- CPU ref: FP16-accum matmul of A_fp32_mirror * B_fp32_mirror (small shapes only)
// For larger shapes, skip ref to keep wall time sane; we accept a smaller sample
// for the numeric check at d=256 and trust the kernel for d≥512.
func cpu_ref_fp16_accum(_ A: [Float], _ B: [Float], M: Int, N: Int, K: Int) -> [Float] {
    var C = [Float](repeating: 0, count: M * N)
    for i in 0..<M {
        for j in 0..<N {
            var acc: Float16 = 0  // FP16 accumulator to match likely GPU accumulator
            for k in 0..<K {
                acc = acc + Float16(A[i*K + k]) * Float16(B[k*N + j])
            }
            C[i*N + j] = Float(acc)
        }
    }
    return C
}

// ---- one shape benchmark ----
func benchShape(
    device: MTLDevice,
    queue: MTLCommandQueue,
    M: Int, N: Int, K: Int,
    warmup: Int, timed: Int,
    runNumericCheck: Bool
) -> (Stats, Float, Float) {
    // FP16 stride = 2 bytes
    let stride16 = MemoryLayout<Float16>.stride
    let rowBytesA = K * stride16
    let rowBytesB = N * stride16
    let rowBytesC = N * stride16

    let bufA = device.makeBuffer(length: M * rowBytesA, options: .storageModeShared)!
    let bufB = device.makeBuffer(length: K * rowBytesB, options: .storageModeShared)!
    let bufC = device.makeBuffer(length: M * rowBytesC, options: .storageModeShared)!

    let A_mirror = fillBufferFP16(bufA, count: M * K,
                                  seed: 0x1234_5678 ^ UInt64(M) &+ UInt64(K) << 16)
    let B_mirror = fillBufferFP16(bufB, count: K * N,
                                  seed: 0x9ABC_DEF0 ^ UInt64(K) &+ UInt64(N) << 16)

    // Zero-init C (FP16 zeroes are still 0x0000).
    memset(bufC.contents(), 0, M * rowBytesC)

    let descA = MPSMatrixDescriptor(rows: M, columns: K, rowBytes: rowBytesA, dataType: .float16)
    let descB = MPSMatrixDescriptor(rows: K, columns: N, rowBytes: rowBytesB, dataType: .float16)
    let descC = MPSMatrixDescriptor(rows: M, columns: N, rowBytes: rowBytesC, dataType: .float16)

    let matA = MPSMatrix(buffer: bufA, descriptor: descA)
    let matB = MPSMatrix(buffer: bufB, descriptor: descB)
    let matC = MPSMatrix(buffer: bufC, descriptor: descC)

    let mm = MPSMatrixMultiplication(
        device: device,
        transposeLeft: false,
        transposeRight: false,
        resultRows: M,
        resultColumns: N,
        interiorColumns: K,
        alpha: 1.0,
        beta: 0.0
    )

    // ---- warmup ----
    for _ in 0..<warmup {
        let cb = queue.makeCommandBuffer()!
        mm.encode(commandBuffer: cb, leftMatrix: matA, rightMatrix: matB, resultMatrix: matC)
        cb.commit()
        cb.waitUntilCompleted()
    }

    // ---- timed ----
    var samples_ms: [Double] = []
    samples_ms.reserveCapacity(timed)
    for _ in 0..<timed {
        let cb = queue.makeCommandBuffer()!
        mm.encode(commandBuffer: cb, leftMatrix: matA, rightMatrix: matB, resultMatrix: matC)
        cb.commit()
        cb.waitUntilCompleted()
        let gpu_s = cb.gpuEndTime - cb.gpuStartTime
        samples_ms.append(gpu_s * 1000.0)
    }

    // ---- numeric correctness (only at smallest shape to keep wall time sane) ----
    var max_abs_diff: Float = 0
    var max_rel_err: Float = 0
    if runNumericCheck {
        let C_ref = cpu_ref_fp16_accum(A_mirror, B_mirror, M: M, N: N, K: K)
        let C_ptr = bufC.contents().bindMemory(to: Float16.self, capacity: M * N)
        for idx in 0..<(M * N) {
            let gpu_val = Float(C_ptr[idx])
            let ref_val = C_ref[idx]
            let abs_diff = abs(gpu_val - ref_val)
            if abs_diff > max_abs_diff { max_abs_diff = abs_diff }
            let denom = max(abs(ref_val), Float(1e-6))
            let rel = abs_diff / denom
            if rel > max_rel_err { max_rel_err = rel }
        }
    }

    return (stats(samples_ms), max_abs_diff, max_rel_err)
}

// ---- driver ----
guard let device = MTLCreateSystemDefaultDevice() else {
    FileHandle.standardError.write("no Metal device\n".data(using: .utf8)!)
    exit(2)
}
guard let queue = device.makeCommandQueue() else {
    FileHandle.standardError.write("no command queue\n".data(using: .utf8)!)
    exit(2)
}

FileHandle.standardError.write("device: \(device.name)\n".data(using: .utf8)!)

let shapes = [256, 384, 512, 768, 1024]
let warmup = 5
let timed = 50

print("[")
for (idx, S) in shapes.enumerated() {
    let doCheck = (S == 256)  // FP16 CPU ref O(N^3) — cheap only at 256
    let (st, max_abs, max_rel) = benchShape(
        device: device, queue: queue,
        M: S, N: S, K: S,
        warmup: warmup, timed: timed,
        runNumericCheck: doCheck
    )
    let flops = 2.0 * Double(S) * Double(S) * Double(S)
    let tflops = flops / (st.median_ms * 1e-3) / 1e12
    let comma = (idx == shapes.count - 1) ? "" : ","
    let checkStr = doCheck
        ? ", \"max_abs_diff\": \(max_abs), \"max_rel_err_vs_fp16accum\": \(max_rel)"
        : ", \"max_abs_diff\": null, \"max_rel_err_vs_fp16accum\": null"
    print("""
      { "M": \(S), "N": \(S), "K": \(S), \
"mps_fp16_tflops": \(tflops), \
"mps_fp16_median_ms": \(st.median_ms), \
"mps_fp16_mean_ms": \(st.mean_ms), \
"mps_fp16_std_ms": \(st.std_ms), \
"mps_fp16_min_ms": \(st.min_ms), \
"mps_fp16_max_ms": \(st.max_ms)\(checkStr) }\(comma)
""")
    let suffix = doCheck
        ? String(format: "  max_abs=%.4f  max_rel=%.4f", max_abs, max_rel)
        : ""
    FileHandle.standardError.write(
        String(format: "shape=%d  median=%.4f ms  TFLOPS=%.3f%@\n",
               S, st.median_ms, tflops, suffix).data(using: .utf8)!
    )
}
print("]")
