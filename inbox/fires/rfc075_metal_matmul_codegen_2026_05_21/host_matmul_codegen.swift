// host_matmul_codegen.swift — RFC 075 silicon-fire of the hexa-codegen-
// emitted MMA matmul kernel on Apple M3. Loads the metallib built from
// the codegen-emitted MSL (compiler/codegen/metal_target.hexa
// `_metal_emit_matmul_body`) and verifies it numerically against a CPU
// FP32 ikj reference at d ∈ {128, 256, 512}.
//
// Build + run:
//   xcrun -sdk macosx metal -c /tmp/emitted_matmul_clean.metal -o /tmp/emitted_matmul.air
//   xcrun -sdk macosx metallib /tmp/emitted_matmul.air -o /tmp/emitted_matmul.metallib
//   xcrun --sdk macosx swift host_matmul_codegen.swift /tmp/emitted_matmul.metallib
//
// Tolerance rel_err < 1e-5 (matches N16 hand-emit verifier).

import Foundation
import Metal

var lcg_state: UInt32 = 0x12345678
func lcg_next() -> UInt32 {
    lcg_state = lcg_state &* 1664525 &+ 1013904223
    return lcg_state
}
func lcg_f32() -> Float32 {
    let u = lcg_next()
    return (Float32(u) / Float32(UInt32.max)) * 2.0 - 1.0
}

@inline(never)
func cpu_matmul_ref(_ a: [Float32], _ b: [Float32],
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

guard let device = MTLCreateSystemDefaultDevice() else {
    print("F-RFC075-METAL-MATMUL-CODEGEN-NUMERIC-EQ: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-MATMUL-CODEGEN-NUMERIC-EQ: FAIL (no queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "/tmp/emitted_matmul.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-MATMUL-CODEGEN-NUMERIC-EQ: FAIL (makeLibrary: \(error))")
    exit(1)
}
guard let fn = library.makeFunction(name: "matmul") else {
    print("F-RFC075-METAL-MATMUL-CODEGEN-NUMERIC-EQ: FAIL (no matmul fn)")
    exit(1)
}
let pipe: MTLComputePipelineState
do { pipe = try device.makeComputePipelineState(function: fn) }
catch {
    print("F-RFC075-METAL-MATMUL-CODEGEN-NUMERIC-EQ: FAIL (pipeline: \(error))")
    exit(1)
}
print("pipe.threadExecutionWidth=\(pipe.threadExecutionWidth) max=\(pipe.maxTotalThreadsPerThreadgroup)")

func fire(_ M: Int, _ N: Int, _ K: Int) -> Bool {
    let aLen = M * K, bLen = K * N, cLen = M * N
    var a = [Float32](repeating: 0, count: aLen)
    var b = [Float32](repeating: 0, count: bLen)
    lcg_state = 0x12345678
    for i in 0..<aLen { a[i] = lcg_f32() }
    for i in 0..<bLen { b[i] = lcg_f32() }
    let ref = cpu_matmul_ref(a, b, M, N, K)

    let aBuf = device.makeBuffer(bytes: a, length: aLen*4, options: .storageModeShared)!
    let bBuf = device.makeBuffer(bytes: b, length: bLen*4, options: .storageModeShared)!
    let cBuf = device.makeBuffer(length: cLen*4, options: .storageModeShared)!
    var Mv = UInt32(M), Nv = UInt32(N), Kv = UInt32(K)

    let cb = queue.makeCommandBuffer()!
    let enc = cb.makeComputeCommandEncoder()!
    enc.setComputePipelineState(pipe)
    enc.setBuffer(aBuf, offset: 0, index: 0)
    enc.setBuffer(bBuf, offset: 0, index: 1)
    enc.setBuffer(cBuf, offset: 0, index: 2)
    enc.setBytes(&Mv, length: 4, index: 3)
    enc.setBytes(&Nv, length: 4, index: 4)
    enc.setBytes(&Kv, length: 4, index: 5)
    // dispatch geometry: threads_per_grid = ((N/32)*32, (M/32)*16, 1)
    // threads_per_threadgroup = (32, 16, 1) = 16 simdgroups × 32 lanes = 512 threads.
    let tgX = (N + 31) / 32
    let tgY = (M + 31) / 32
    let threadsPerGrid = MTLSize(width: tgX * 32, height: tgY * 16, depth: 1)
    let threadsPerTG = MTLSize(width: 32, height: 16, depth: 1)
    enc.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerTG)
    enc.endEncoding()
    cb.commit()
    cb.waitUntilCompleted()

    if let err = cb.error {
        print("  d=\(M) FAIL: cb.error=\(err)")
        return false
    }
    let out = UnsafeBufferPointer(start: cBuf.contents().assumingMemoryBound(to: Float32.self),
                                  count: cLen)
    var maxAbsErr: Float32 = 0
    var maxAbsRef: Float32 = 0
    for i in 0..<cLen {
        let e = abs(out[i] - ref[i])
        if e > maxAbsErr { maxAbsErr = e }
        let r = abs(ref[i])
        if r > maxAbsRef { maxAbsRef = r }
    }
    let relErr = maxAbsRef > 0 ? maxAbsErr / maxAbsRef : maxAbsErr
    let elapsed_ns = cb.gpuEndTime - cb.gpuStartTime
    let gflops = (2.0 * Double(M) * Double(N) * Double(K)) / (elapsed_ns * 1e9)
    let pass = relErr < 1e-5
    print(String(format: "  d=%d  max|Δ|=%.3e  max|ref|=%.3e  rel_err=%.3e  %.2f GFLOPS  %@",
                 M, Double(maxAbsErr), Double(maxAbsRef), Double(relErr),
                 gflops, pass ? "PASS" : "FAIL"))
    return pass
}

var allOk = true
for d in [128, 256, 512] {
    if !fire(d, d, d) { allOk = false }
}
print(allOk
      ? "F-RFC075-METAL-MATMUL-CODEGEN-NUMERIC-EQ: PASS (3/3 shapes)"
      : "F-RFC075-METAL-MATMUL-CODEGEN-NUMERIC-EQ: FAIL")
exit(allOk ? 0 : 1)
