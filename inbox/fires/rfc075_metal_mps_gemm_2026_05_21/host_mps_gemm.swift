// host_mps_gemm.swift — RFC 075 Metal/MPS FP32 GEMM baseline (Apple-side cuBLAS-equivalent)
//
// Measures MPSMatrixMultiplication FP32 throughput on Apple M3 across the same shape
// matrix used for the Nvidia cuBLAS HGEMM characterisation (commit d9f9446a / RFC 067 pD).
// Honest scope: cuBLAS side is FP16 WMMA (HGEMM). This is FP32 SGEMM via MPS — the closest
// matching "vendor library" baseline available without a hexa-emit GEMM Metal kernel yet.
//
// Apple docs:
//   - MPSMatrix:                 https://developer.apple.com/documentation/metalperformanceshaders/mpsmatrix
//   - MPSMatrixMultiplication:   https://developer.apple.com/documentation/metalperformanceshaders/mpsmatrixmultiplication
//   - MPSMatrixDescriptor:       https://developer.apple.com/documentation/metalperformanceshaders/mpsmatrixdescriptor
//
// Output: stdout JSON-array of per-shape records (timing in ms, throughput in TFLOPS).
// Build/run via xcrun (per reference_swift_build_pool_xcrun memory):
//   xcrun --sdk macosx swiftc -O host_mps_gemm.swift -o host_mps_gemm
//   ./host_mps_gemm

import Foundation
import Metal
import MetalPerformanceShaders

// ---- deterministic LCG (matches the hexa fire convention; seed-stable per shape) ----
struct LCG {
    var state: UInt64
    init(_ seed: UInt64) { self.state = seed }
    mutating func nextF32() -> Float {
        // Numerical Recipes LCG; map low 24 bits → [-1, 1)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let bits24 = UInt32(truncatingIfNeeded: state >> 40) & 0xFFFFFF
        return (Float(bits24) / Float(1 << 23)) - 1.0
    }
}

func fillBuffer(_ buf: MTLBuffer, count: Int, seed: UInt64) {
    let ptr = buf.contents().bindMemory(to: Float.self, capacity: count)
    var lcg = LCG(seed)
    for i in 0..<count { ptr[i] = lcg.nextF32() }
}

// ---- one shape benchmark ----
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

func benchShape(
    device: MTLDevice,
    queue: MTLCommandQueue,
    M: Int, N: Int, K: Int,
    warmup: Int, timed: Int
) -> Stats {
    let rowBytesA = K * MemoryLayout<Float>.stride
    let rowBytesB = N * MemoryLayout<Float>.stride
    let rowBytesC = N * MemoryLayout<Float>.stride

    // Storage-mode-shared = unified-memory friendly on Apple Silicon (no explicit copy).
    let bufA = device.makeBuffer(length: M * rowBytesA, options: .storageModeShared)!
    let bufB = device.makeBuffer(length: K * rowBytesB, options: .storageModeShared)!
    let bufC = device.makeBuffer(length: M * rowBytesC, options: .storageModeShared)!

    fillBuffer(bufA, count: M * K, seed: 0x1234_5678 ^ UInt64(M) &+ UInt64(K) << 16)
    fillBuffer(bufB, count: K * N, seed: 0x9ABC_DEF0 ^ UInt64(K) &+ UInt64(N) << 16)
    // C left zero-init.

    let descA = MPSMatrixDescriptor(rows: M, columns: K, rowBytes: rowBytesA, dataType: .float32)
    let descB = MPSMatrixDescriptor(rows: K, columns: N, rowBytes: rowBytesB, dataType: .float32)
    let descC = MPSMatrixDescriptor(rows: M, columns: N, rowBytes: rowBytesC, dataType: .float32)

    let matA = MPSMatrix(buffer: bufA, descriptor: descA)
    let matB = MPSMatrix(buffer: bufB, descriptor: descB)
    let matC = MPSMatrix(buffer: bufC, descriptor: descC)

    // alpha=1, beta=0 → standard C = A*B (no accumulate).
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
        // GPU-side timing: use command buffer GPU start/end timestamps for precision.
        let gpu_s = cb.gpuEndTime - cb.gpuStartTime  // seconds
        samples_ms.append(gpu_s * 1000.0)
    }

    return stats(samples_ms)
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
    let st = benchShape(device: device, queue: queue, M: S, N: S, K: S,
                       warmup: warmup, timed: timed)
    // FLOPs = 2 * M * N * K  (mul + add per inner-product term).
    let flops = 2.0 * Double(S) * Double(S) * Double(S)
    let tflops = flops / (st.median_ms * 1e-3) / 1e12
    let comma = (idx == shapes.count - 1) ? "" : ","
    print("""
      { "M": \(S), "N": \(S), "K": \(S), \
"mps_tflops": \(tflops), \
"mps_median_ms": \(st.median_ms), \
"mps_mean_ms": \(st.mean_ms), \
"mps_std_ms": \(st.std_ms), \
"mps_min_ms": \(st.min_ms), \
"mps_max_ms": \(st.max_ms) }\(comma)
""")
    FileHandle.standardError.write(
        String(format: "shape=%d  median=%.4f ms  TFLOPS=%.3f\n",
               S, st.median_ms, tflops).data(using: .utf8)!
    )
}
print("]")
