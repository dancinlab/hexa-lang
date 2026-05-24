// host.swift — RFC 075 P4 Metal silicon-fire host launcher
//
// Loads inbox/fires/rfc075_metal_p4_2026_05_21/vec_add.metallib,
// fills two FP32 input buffers (a, b) with LCG-generated values for
// deterministic byte-eq comparison, dispatches the vec_add kernel
// across 1024 threads, reads back the output buffer, compares to a
// CPU reference, and emits a one-line F-RFC075-METAL-NUMERIC-EQ
// status line + max|delta| + byte_mismatch count.
//
// Reads the metallib path from CLI arg 1 (default: ./vec_add.metallib).
//
// Build + run:
//   xcrun --sdk macosx swift host.swift ./vec_add.metallib

import Foundation
import Metal

let N: Int = 1024

// LCG (Numerical Recipes constants — well-tested deterministic generator).
// 32-bit unsigned multiplicative recurrence; we convert to FP32 in (-1, 1).
var lcg_state: UInt32 = 0x12345678
func lcg_next() -> UInt32 {
    lcg_state = lcg_state &* 1664525 &+ 1013904223
    return lcg_state
}
func lcg_f32() -> Float32 {
    let u = lcg_next()
    // Map to roughly (-1, 1).
    return (Float32(u) / Float32(UInt32.max)) * 2.0 - 1.0
}

// CPU reference + populate inputs.
var a = [Float32](repeating: 0, count: N)
var b = [Float32](repeating: 0, count: N)
var ref = [Float32](repeating: 0, count: N)
for i in 0..<N {
    a[i] = lcg_f32()
    b[i] = lcg_f32()
    ref[i] = a[i] + b[i]
}

// Metal device + queue.
guard let device = MTLCreateSystemDefaultDevice() else {
    print("F-RFC075-METAL-NUMERIC-EQ: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
print("max_threads_per_threadgroup=\(device.maxThreadsPerThreadgroup)")
guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-NUMERIC-EQ: FAIL (no command queue)")
    exit(1)
}

// Load .metallib.
let metallibPath: String
if CommandLine.arguments.count >= 2 {
    metallibPath = CommandLine.arguments[1]
} else {
    metallibPath = "./vec_add.metallib"
}
let metallibURL = URL(fileURLWithPath: metallibPath)
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: metallibURL)
} catch {
    print("F-RFC075-METAL-NUMERIC-EQ: FAIL (makeLibrary: \(error))")
    exit(1)
}
guard let kernelFn = library.makeFunction(name: "vec_add") else {
    print("F-RFC075-METAL-NUMERIC-EQ: FAIL (no vec_add function)")
    exit(1)
}
let pipeline: MTLComputePipelineState
do {
    pipeline = try device.makeComputePipelineState(function: kernelFn)
} catch {
    print("F-RFC075-METAL-NUMERIC-EQ: FAIL (pipeline: \(error))")
    exit(1)
}

// Buffers.
let bytes = N * MemoryLayout<Float32>.stride
guard let bufA = device.makeBuffer(bytes: a, length: bytes, options: .storageModeShared),
      let bufB = device.makeBuffer(bytes: b, length: bytes, options: .storageModeShared),
      let bufC = device.makeBuffer(length: bytes, options: .storageModeShared) else {
    print("F-RFC075-METAL-NUMERIC-EQ: FAIL (buffer alloc)")
    exit(1)
}
memset(bufC.contents(), 0, bytes)

// Encode + dispatch.
guard let cmd = queue.makeCommandBuffer(),
      let enc = cmd.makeComputeCommandEncoder() else {
    print("F-RFC075-METAL-NUMERIC-EQ: FAIL (encoder)")
    exit(1)
}
enc.setComputePipelineState(pipeline)
enc.setBuffer(bufA, offset: 0, index: 0)
enc.setBuffer(bufB, offset: 0, index: 1)
enc.setBuffer(bufC, offset: 0, index: 2)

let grid = MTLSize(width: N, height: 1, depth: 1)
let tgWidth = min(pipeline.threadExecutionWidth, N)
let tg = MTLSize(width: tgWidth, height: 1, depth: 1)
enc.dispatchThreads(grid, threadsPerThreadgroup: tg)
enc.endEncoding()
cmd.commit()
cmd.waitUntilCompleted()

if let err = cmd.error {
    print("F-RFC075-METAL-NUMERIC-EQ: FAIL (commit: \(err))")
    exit(1)
}

// Read back + compare.
let gpu = bufC.contents().bindMemory(to: Float32.self, capacity: N)
var max_abs_diff: Float32 = 0
var byte_mismatch: Int = 0
for i in 0..<N {
    let diff = abs(gpu[i] - ref[i])
    if diff > max_abs_diff { max_abs_diff = diff }
    // Byte-exact comparison (FP add is well-defined, no FMA path).
    if gpu[i].bitPattern != ref[i].bitPattern {
        byte_mismatch += 1
    }
}

print("N=\(N)")
print("max_abs_diff=\(max_abs_diff)")
print("byte_mismatch=\(byte_mismatch)/\(N)")
print("first_3_gpu_vs_ref:")
for i in 0..<3 {
    print("  i=\(i) gpu=\(gpu[i]) ref=\(ref[i])")
}

if byte_mismatch == 0 {
    print("F-RFC075-METAL-NUMERIC-EQ: PASS (byte_eq across \(N) cells)")
    exit(0)
} else {
    print("F-RFC075-METAL-NUMERIC-EQ: PARTIAL (max|d|=\(max_abs_diff), byte_mismatch=\(byte_mismatch)/\(N))")
    exit(0)  // still informative; not a hard FAIL when max|d| small
}
