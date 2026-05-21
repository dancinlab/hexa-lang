// host_reduce.swift — Silicon-fire RFC 075 reduce-sum (first non-element-wise
// Metal codegen shape). Loads reduce_sum.metallib, fills N=1024 input with
// all-1.0s, dispatches threadgroup=32 (matches SIMD-group width), expects
// each output cell to equal 32.0 (per-SIMD-group sum of 32 ones).
//
// Falsifier F-RFC075-METAL-REDUCE-SUM-NUMERIC-EQ: every group output
// must be exactly 32.0 (FP32 sum of 32 exact 1.0s is exactly 32.0).
//
// Usage: xcrun --sdk macosx swift host_reduce.swift

import Foundation
import Metal

let N = 1024
let SIMD_W = 32
let N_GROUPS = N / SIMD_W   // 32 per-SIMD-group outputs

guard let device = MTLCreateSystemDefaultDevice() else { print("FAIL device"); exit(1) }
guard let queue = device.makeCommandQueue() else { print("FAIL queue"); exit(1) }
print("device=\(device.name)")

let a = [Float32](repeating: 1.0, count: N)

let library: MTLLibrary
do { library = try device.makeLibrary(URL: URL(fileURLWithPath: "reduce_sum.metallib")) }
catch { print("FAIL makeLibrary \(error)"); exit(1) }
guard let fn = library.makeFunction(name: "reduce_sum") else {
    print("FAIL no fn"); exit(1)
}
let pipeline: MTLComputePipelineState
do { pipeline = try device.makeComputePipelineState(function: fn) }
catch { print("FAIL pipeline \(error)"); exit(1) }

let bytesA = N * MemoryLayout<Float32>.stride
let bytesC = N_GROUPS * MemoryLayout<Float32>.stride
let bufA = device.makeBuffer(bytes: a, length: bytesA, options: .storageModeShared)!
let bufC = device.makeBuffer(length: bytesC, options: .storageModeShared)!
memset(bufC.contents(), 0, bytesC)

let cmd = queue.makeCommandBuffer()!
let enc = cmd.makeComputeCommandEncoder()!
enc.setComputePipelineState(pipeline)
enc.setBuffer(bufA, offset: 0, index: 0)
enc.setBuffer(bufC, offset: 0, index: 1)
let grid = MTLSize(width: N, height: 1, depth: 1)
// threadgroup must be a multiple of SIMD-group width; force 32 so simd_sum
// reduces over exactly the documented 32 lanes per group.
let tg = MTLSize(width: SIMD_W, height: 1, depth: 1)
enc.dispatchThreads(grid, threadsPerThreadgroup: tg)
enc.endEncoding()
cmd.commit()
cmd.waitUntilCompleted()

let gpu = bufC.contents().bindMemory(to: Float32.self, capacity: N_GROUPS)
let expected: Float32 = Float32(SIMD_W)   // 32 ones → 32.0
var byteMM = 0
var maxDiff: Float32 = 0
for g in 0..<N_GROUPS {
    let d = abs(gpu[g] - expected)
    if d > maxDiff { maxDiff = d }
    if gpu[g].bitPattern != expected.bitPattern { byteMM += 1 }
}

let status = byteMM == 0 ? "PASS" : "FAIL"
print("")
print("kernel       N    groups  expected  max|d|     byte_mm   PASS/FAIL")
print("---------- ---- -------- --------- ---------  ---------  ---------")
print(String(format: "reduce_sum %4d %8d %8.1f  %9.6f  %4d/%-5d  %@",
             N, N_GROUPS, Double(expected), Double(maxDiff), byteMM, N_GROUPS, status))

print("")
let allPass = (byteMM == 0)
if allPass {
    print("F-RFC075-METAL-REDUCE-SUM-NUMERIC-EQ: PASS (\(N_GROUPS) per-SIMD-group outputs all == \(expected))")
} else {
    print("F-RFC075-METAL-REDUCE-SUM-NUMERIC-EQ: FAIL")
}

// Capture a few output samples for the artifact log.
var samples: [Float32] = []
for g in 0..<min(4, N_GROUPS) { samples.append(gpu[g]) }

let json: [String: Any] = [
    "campaign": "rfc075_metal_reduce_2026_05_21",
    "device": device.name,
    "registry_id": device.registryID,
    "shape": "reduce_sum",
    "N_input": N,
    "N_groups": N_GROUPS,
    "simd_group_width": SIMD_W,
    "expected_per_group": Double(expected),
    "max_abs_diff": Double(maxDiff),
    "byte_mismatch": byteMM,
    "samples_first_4": samples.map { Double($0) },
    "all_pass_byte_eq": allPass,
    "falsifier_F_RFC075_METAL_REDUCE_SUM_NUMERIC_EQ": allPass ? "PASS" : "FAIL",
]
if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: URL(fileURLWithPath: "result.json"))
    print("wrote result.json (\(data.count) bytes)")
}
exit(allPass ? 0 : 1)
