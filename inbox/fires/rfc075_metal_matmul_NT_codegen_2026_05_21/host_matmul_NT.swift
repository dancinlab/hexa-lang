// host_matmul_NT.swift — Apple M3 silicon-fire driver for the
// codegen-emitted matmul_NT_a + matmul_NT_b kernels.
//
// Validates F-RFC075-METAL-MATMUL-NT-CODEGEN-NUMERIC-EQ — the emitted
// MSL kernels (compiled to matmul_NT.metallib) numerically match a
// double-precision CPU reference for a small set of cube shapes.
//
// - matmul_NT_a — C = A^T · B, A is K×M, B is K×N. C is M×N.
// - matmul_NT_b — C = A · B^T, A is M×K, B is N×K. C is M×N.

import Foundation
import Metal

// ───────── CPU references ─────────

func cpuMatmulNTA(_ A: [Float], _ B: [Float], M: Int, N: Int, K: Int) -> [Float] {
    // A is K×M (row-major), B is K×N (row-major), C is M×N (row-major).
    // C[i,j] = sum_k A[k,i] * B[k,j]
    var C = [Float](repeating: 0, count: M * N)
    for i in 0..<M {
        for j in 0..<N {
            var acc: Double = 0
            for k in 0..<K {
                acc += Double(A[k * M + i]) * Double(B[k * N + j])
            }
            C[i * N + j] = Float(acc)
        }
    }
    return C
}

func cpuMatmulNTB(_ A: [Float], _ B: [Float], M: Int, N: Int, K: Int) -> [Float] {
    // A is M×K (row-major), B is N×K (row-major), C is M×N (row-major).
    // C[i,j] = sum_k A[i,k] * B[j,k]
    var C = [Float](repeating: 0, count: M * N)
    for i in 0..<M {
        for j in 0..<N {
            var acc: Double = 0
            for k in 0..<K {
                acc += Double(A[i * K + k]) * Double(B[j * K + k])
            }
            C[i * N + j] = Float(acc)
        }
    }
    return C
}

// ───────── deterministic input init ─────────

func makeInput(_ count: Int, seed: UInt64) -> [Float] {
    var s = seed | 1  // odd seed for LCG
    var out = [Float](repeating: 0, count: count)
    for i in 0..<count {
        // 32-bit xorshift then to [-1, 1)
        s ^= s << 13
        s ^= s >> 7
        s ^= s << 17
        let u = UInt32(truncatingIfNeeded: s)
        out[i] = (Float(u) / Float(UInt32.max)) * 2.0 - 1.0
    }
    return out
}

// ───────── GPU dispatch ─────────

func gpuFire(
    device: MTLDevice, queue: MTLCommandQueue, library: MTLLibrary,
    kernelName: String, A: [Float], B: [Float],
    M: Int, N: Int, K: Int
) -> (output: [Float], elapsedMs: Double) {
    guard let function = library.makeFunction(name: kernelName) else {
        fatalError("kernel \(kernelName) not found in library")
    }
    let pipeline: MTLComputePipelineState
    do {
        pipeline = try device.makeComputePipelineState(function: function)
    } catch {
        fatalError("makeComputePipelineState failed: \(error)")
    }

    let bytesA = A.count * MemoryLayout<Float>.stride
    let bytesB = B.count * MemoryLayout<Float>.stride
    let bytesC = M * N * MemoryLayout<Float>.stride
    let bufA = device.makeBuffer(bytes: A, length: bytesA, options: .storageModeShared)!
    let bufB = device.makeBuffer(bytes: B, length: bytesB, options: .storageModeShared)!
    let bufC = device.makeBuffer(length: bytesC, options: .storageModeShared)!

    var mU = UInt32(M)
    var nU = UInt32(N)
    var kU = UInt32(K)
    let bufM = device.makeBuffer(bytes: &mU, length: 4, options: .storageModeShared)!
    let bufN = device.makeBuffer(bytes: &nU, length: 4, options: .storageModeShared)!
    let bufK = device.makeBuffer(bytes: &kU, length: 4, options: .storageModeShared)!

    let cmdBuf = queue.makeCommandBuffer()!
    let enc = cmdBuf.makeComputeCommandEncoder()!
    enc.setComputePipelineState(pipeline)
    enc.setBuffer(bufA, offset: 0, index: 0)
    enc.setBuffer(bufB, offset: 0, index: 1)
    enc.setBuffer(bufC, offset: 0, index: 2)
    enc.setBuffer(bufM, offset: 0, index: 3)
    enc.setBuffer(bufN, offset: 0, index: 4)
    enc.setBuffer(bufK, offset: 0, index: 5)

    // Per N24 kernel comment: threads_per_grid = ((N/32)*32, (M/32)*16, 1)
    // threads_per_threadgroup = (32, 16, 1). 32×16=512 threads/TG = 16 SGs.
    let tgWidth = 32
    let tgHeight = 16
    let gridX = ((N + 31) / 32) * tgWidth
    let gridY = ((M + 31) / 32) * tgHeight
    let threadsPerGrid = MTLSize(width: gridX, height: gridY, depth: 1)
    let threadsPerTg = MTLSize(width: tgWidth, height: tgHeight, depth: 1)
    enc.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerTg)
    enc.endEncoding()

    let start = Date()
    cmdBuf.commit()
    cmdBuf.waitUntilCompleted()
    let elapsedMs = Date().timeIntervalSince(start) * 1000.0

    let outPtr = bufC.contents().bindMemory(to: Float.self, capacity: M * N)
    let out = Array(UnsafeBufferPointer(start: outPtr, count: M * N))
    return (out, elapsedMs)
}

// ───────── comparison ─────────

func compare(_ ref: [Float], _ got: [Float], tag: String, K: Int) -> (maxAbs: Float, maxRel: Float, ok: Bool) {
    // FP32 dot-product accumulation noise for length-K sums of [-1, 1]
    // operands is bounded by ~K * ε * E[|product|] ≈ K * 1.2e-7 * 0.33
    // → ~4e-5 for K=512. Use absolute tolerance scaled by K (with a
    // 1e-4 floor) and relative tolerance with a denominator floor to
    // avoid divide-by-near-zero amplification on the dot-product
    // outputs that happen to land near zero.
    var maxAbs: Float = 0
    var maxRelStrict: Float = 0  // only counted where |ref| > floor
    var firstFailIdx = -1
    let absFloor: Float = max(1e-4, Float(K) * 1e-7 * 4.0)
    let relTol: Float = 1e-3
    let denomFloor: Float = 1e-3
    for i in 0..<ref.count {
        let absDiff = abs(ref[i] - got[i])
        if absDiff > maxAbs { maxAbs = absDiff }
        if abs(ref[i]) > denomFloor {
            let rel = absDiff / abs(ref[i])
            if rel > maxRelStrict { maxRelStrict = rel }
            if rel > relTol && firstFailIdx < 0 { firstFailIdx = i }
        }
    }
    let ok = (maxAbs <= absFloor) || (maxRelStrict <= relTol)
    print("  [\(tag)] max|abs|=\(maxAbs)  max|rel(|ref|>\(denomFloor))|=\(maxRelStrict)  abs-floor=\(absFloor)  ok=\(ok)")
    if !ok, firstFailIdx >= 0 {
        print("    first-fail @ idx \(firstFailIdx): ref=\(ref[firstFailIdx]) got=\(got[firstFailIdx])")
    }
    return (maxAbs, maxRelStrict, ok)
}

// ───────── driver ─────────

let args = CommandLine.arguments
let libPath = args.count > 1 ? args[1] : "matmul_NT.metallib"

guard let device = MTLCopyAllDevices().first else {
    print("F-RFC075-METAL-NT-FIRE: FAIL — no Metal device")
    exit(1)
}
print("device: \(device.name)")

let libURL = URL(fileURLWithPath: libPath)
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: libURL)
} catch {
    print("F-RFC075-METAL-NT-FIRE: FAIL — makeLibrary: \(error)")
    exit(1)
}

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-NT-FIRE: FAIL — no command queue")
    exit(1)
}

// Test shapes — must be multiples of 32 (TG_M = TG_N = 32) for the
// codegen's hardcoded tile. K must be multiple of 8 (TG_K).
let shapes: [(M: Int, N: Int, K: Int)] = [
    (128, 128, 128),
    (256, 256, 256),
    (512, 512, 512)
]

var allOk = true

for (idx, shape) in shapes.enumerated() {
    let (M, N, K) = shape
    print("")
    print("=== shape \(idx+1)/\(shapes.count): M=\(M) N=\(N) K=\(K) ===")
    let seed = UInt64(0x9E3779B97F4A7C15 &+ UInt64(idx))

    // ── matmul_NT_a: A is K×M, B is K×N ──
    do {
        let A = makeInput(K * M, seed: seed)
        let B = makeInput(K * N, seed: seed &+ 1)
        let cpuRef = cpuMatmulNTA(A, B, M: M, N: N, K: K)
        let (gpuOut, ms) = gpuFire(
            device: device, queue: queue, library: library,
            kernelName: "matmul_NT_a", A: A, B: B, M: M, N: N, K: K
        )
        let (_, _, ok) = compare(cpuRef, gpuOut, tag: "matmul_NT_a", K: K)
        let flops = 2.0 * Double(M) * Double(N) * Double(K)
        let gflops = flops / (ms / 1000.0) / 1e9
        print("  [matmul_NT_a] \(ms) ms  ~\(String(format: "%.1f", gflops)) GFLOPS")
        if !ok { allOk = false }
    }

    // ── matmul_NT_b: A is M×K, B is N×K ──
    do {
        let A = makeInput(M * K, seed: seed &+ 2)
        let B = makeInput(N * K, seed: seed &+ 3)
        let cpuRef = cpuMatmulNTB(A, B, M: M, N: N, K: K)
        let (gpuOut, ms) = gpuFire(
            device: device, queue: queue, library: library,
            kernelName: "matmul_NT_b", A: A, B: B, M: M, N: N, K: K
        )
        let (_, _, ok) = compare(cpuRef, gpuOut, tag: "matmul_NT_b", K: K)
        let flops = 2.0 * Double(M) * Double(N) * Double(K)
        let gflops = flops / (ms / 1000.0) / 1e9
        print("  [matmul_NT_b] \(ms) ms  ~\(String(format: "%.1f", gflops)) GFLOPS")
        if !ok { allOk = false }
    }
}

print("")
if allOk {
    print("F-RFC075-METAL-MATMUL-NT-CODEGEN-NUMERIC-EQ: PASS")
    exit(0)
} else {
    print("F-RFC075-METAL-MATMUL-NT-CODEGEN-NUMERIC-EQ: FAIL")
    exit(1)
}
