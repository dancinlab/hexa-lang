// host_vec_add.swift — RFC 075 Apple M4 vec-add measurement
//
// Allocates 3× FP32 buffers @ N=1M, fills with LCG-deterministic values
// (matches M3 baseline N16 protocol), dispatches vec_add kernel 20 warmup +
// 200 timed reps, reports median GB/s + GFLOPS, validates byte-equal vs CPU
// reference (max|d|=0 gate).
//
// Build + run:
//   xcrun --sdk macosx swiftc -O host_vec_add.swift -o host_vec_add
//   ./host_vec_add ./vec_add.metallib

import Foundation
import Metal

// LCG deterministic init (same as M3 baseline)
var lcg_state: UInt32 = 0x12345678
func lcg_next() -> UInt32 {
    lcg_state = lcg_state &* 1664525 &+ 1013904223
    return lcg_state
}
func lcg_f32() -> Float32 {
    let u = lcg_next()
    return (Float32(u) / Float32(UInt32.max)) * 2.0 - 1.0
}

guard let device = MTLCreateSystemDefaultDevice() else {
    print("F-RFC075-METAL-M4-BASELINE: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
let mtpt = device.maxThreadsPerThreadgroup
print("max_threads_per_threadgroup=\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)")
print("max_threadgroup_memory_length=\(device.maxThreadgroupMemoryLength)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-M4-BASELINE: FAIL (no queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./vec_add.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-M4-BASELINE: FAIL (makeLibrary: \(error))")
    exit(1)
}

guard let fn = library.makeFunction(name: "vec_add") else {
    print("F-RFC075-METAL-M4-BASELINE: FAIL (no vec_add fn)")
    exit(1)
}
let pipe: MTLComputePipelineState
do { pipe = try device.makeComputePipelineState(function: fn) }
catch {
    print("F-RFC075-METAL-M4-BASELINE: FAIL (pipeline: \(error))")
    exit(1)
}
print("pipe tew=\(pipe.threadExecutionWidth) max=\(pipe.maxTotalThreadsPerThreadgroup)")

// Multi-shape sweep, matching M3 roofline (65K, 256K, 1M, 4M)
struct Result {
    let N: Int
    let median_ms: Double
    let gb_per_s: Double
    let gflops: Double
    let max_abs_diff: Float32
    let pass: Bool
}

func run_shape(_ N: Int, warmup: Int, timed: Int) -> Result {
    lcg_state = 0x12345678
    var aHost = [Float32](repeating: 0, count: N)
    var bHost = [Float32](repeating: 0, count: N)
    for i in 0..<N { aHost[i] = lcg_f32() }
    for i in 0..<N { bHost[i] = lcg_f32() }

    let bytes = N * MemoryLayout<Float32>.stride
    guard let bufA = device.makeBuffer(bytes: aHost, length: bytes, options: .storageModeShared),
          let bufB = device.makeBuffer(bytes: bHost, length: bytes, options: .storageModeShared),
          let bufC = device.makeBuffer(length: bytes, options: .storageModeShared) else {
        print("F-RFC075-METAL-M4-BASELINE: FAIL (buffer alloc N=\(N))"); exit(1)
    }

    var Nv: UInt32 = UInt32(N)

    let tgSize = min(pipe.maxTotalThreadsPerThreadgroup, 256)
    let tg = MTLSize(width: tgSize, height: 1, depth: 1)
    let grid = MTLSize(width: N, height: 1, depth: 1)

    func dispatch_once() -> Double {
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            print("F-RFC075-METAL-M4-BASELINE: FAIL (encoder)"); exit(1)
        }
        enc.setComputePipelineState(pipe)
        enc.setBuffer(bufA, offset: 0, index: 0)
        enc.setBuffer(bufB, offset: 0, index: 1)
        enc.setBuffer(bufC, offset: 0, index: 2)
        enc.setBytes(&Nv, length: 4, index: 3)
        enc.dispatchThreads(grid, threadsPerThreadgroup: tg)
        enc.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
        if let err = cmd.error {
            print("F-RFC075-METAL-M4-BASELINE: FAIL (commit: \(err))"); exit(1)
        }
        return (cmd.gpuEndTime - cmd.gpuStartTime) * 1e3
    }

    for _ in 0..<warmup { let _ = dispatch_once() }

    var samples = [Double](); samples.reserveCapacity(timed)
    for _ in 0..<timed { samples.append(dispatch_once()) }
    samples.sort()
    let median = samples[samples.count / 2]

    let gpuRaw = bufC.contents().bindMemory(to: Float32.self, capacity: N)
    var max_abs_diff: Float32 = 0
    for i in 0..<N {
        let ref = aHost[i] + bHost[i]
        let d = abs(gpuRaw[i] - ref)
        if d > max_abs_diff { max_abs_diff = d }
    }
    // bytes moved: 3*N*4 (read a, read b, write c)
    let bytes_moved = 3.0 * Double(N) * 4.0
    let gb_per_s = bytes_moved / (median * 1e-3) / 1e9
    let flops = Double(N)  // 1 add per element
    let gflops = flops / (median * 1e-3) / 1e9
    let ok = max_abs_diff == 0
    return Result(N: N, median_ms: median, gb_per_s: gb_per_s, gflops: gflops,
                  max_abs_diff: max_abs_diff, pass: ok)
}

// Shape sweep matching M3 roofline + the canonical N=1M / N=4M comparison points
let shapes: [Int] = [65536, 262144, 1048576, 4194304]
let warmup = 20
let timed  = 200

var results: [Result] = []
var allOk = true

for N in shapes {
    let r = run_shape(N, warmup: warmup, timed: timed)
    results.append(r)
    if !r.pass { allOk = false }
    let tag = r.pass ? "PASS" : "FAIL"
    print(String(format: "vec_add  N=%7d  median=%.4fms  GB/s=%.3f  GFLOPS=%.3f  max|d|=%.3e  \(tag)",
                 r.N, r.median_ms, r.gb_per_s, r.gflops, Double(r.max_abs_diff)))
}

// M3 anchors from rfc075_metal_roofline_2026_05_21/result.json (vec_add_1op)
let m3_anchor: [Int: Double] = [
    65536:    3.6069,
    262144:  13.2671,
    1048576: 34.2816,
    4194304: 34.9051,
]

func peakGB() -> (Double, Int) {
    var best = 0.0; var bestN = 0
    for r in results { if r.gb_per_s > best { best = r.gb_per_s; bestN = r.N } }
    return (best, bestN)
}
let (peakGBs, peakN) = peakGB()

var json = "{\n"
json += "  \"campaign\": \"rfc075_metal_m4_baseline_2026_05_22\",\n"
json += "  \"host\": \"mini (Apple M4)\",\n"
json += "  \"platform\": \"darwin-arm64\",\n"
json += "  \"gpu\": \"\(device.name) (registry_id=\(device.registryID))\",\n"
json += "  \"max_threads_per_threadgroup\": \"\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)\",\n"
json += "  \"max_threadgroup_memory_length\": \(device.maxThreadgroupMemoryLength),\n"
json += "  \"date_utc\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
json += "  \"toolchain\": \"xcrun --sdk macosx metal / swiftc -O\",\n"
json += "  \"kernel\": \"vec_add (FP32 element-wise add)\",\n"
json += "  \"warmup\": \(warmup),\n"
json += "  \"timed\": \(timed),\n"
json += "  \"pipe_max_threads_per_threadgroup\": \(pipe.maxTotalThreadsPerThreadgroup),\n"
json += "  \"pipe_thread_execution_width\": \(pipe.threadExecutionWidth),\n"
json += "  \"rows\": [\n"
for (idx, r) in results.enumerated() {
    let comma = idx == results.count - 1 ? "" : ","
    let m3 = m3_anchor[r.N] ?? 0
    let ratio = m3 > 0 ? r.gb_per_s / m3 : 0
    json += "    {\n"
    json += "      \"N\": \(r.N),\n"
    json += "      \"median_ms\": \(r.median_ms),\n"
    json += "      \"gb_per_s\": \(r.gb_per_s),\n"
    json += "      \"gflops\": \(r.gflops),\n"
    json += "      \"max_abs_diff\": \(r.max_abs_diff),\n"
    json += "      \"m3_gb_per_s\": \(m3),\n"
    json += "      \"m4_over_m3_ratio\": \(ratio),\n"
    json += "      \"pass\": \(r.pass)\n"
    json += "    }\(comma)\n"
}
json += "  ],\n"
json += "  \"peak_gb_per_s\": \(peakGBs),\n"
json += "  \"peak_at_N\": \(peakN),\n"
let m3PeakGBs: Double = 52.37  // M3 vec_add_16op @ N=4M; vec_add_1op peak was 34.9
let m3PeakGBs_1op: Double = 34.9051  // direct apples-to-apples (1 op/elem)
json += "  \"m3_peak_gb_per_s_1op\": \(m3PeakGBs_1op),\n"
json += "  \"m3_peak_gb_per_s_anyop\": \(m3PeakGBs),\n"
json += "  \"m4_over_m3_ratio_1op_peak\": \(peakGBs / m3PeakGBs_1op),\n"
let statusStr = allOk ? "PASS" : "FAIL"
json += "  \"falsifier_F_RFC075_METAL_M4_BASELINE\": \"\(statusStr)\",\n"
json += "  \"honest_scope\": [\n"
json += "    \"FP32 vec-add minimum element-wise kernel (3*N*4 bytes moved, 1 flop/element — bandwidth-bound).\",\n"
json += "    \"M3 anchor from rfc075_metal_roofline_2026_05_21 (vec_add_1op kernel; 5 warmup + 50 timed).\",\n"
json += "    \"M4 fire uses 20 warmup + 200 timed for tighter variance estimate.\",\n"
json += "    \"max|d|=0 byte-eq gate validates kernel correctness on M4 chip; CPU ref = aHost[i]+bHost[i] in IEEE-754 FP32.\",\n"
json += "    \"Apple M4 10-core GPU spec ≈ 4.6 TFLOPS FP32 / 120 GB/s LPDDR5X-7500 (16GB unified memory variant).\",\n"
json += "    \"Apple M3 8-core GPU spec ≈ 3.5 TFLOPS FP32 / 100 GB/s LPDDR5-6400 (typ. 16GB unified).\",\n"
json += "    \"Expected M4/M3 vec-add bandwidth ratio ~1.2x (LPDDR5 6400 -> LPDDR5X 7500); reality depends on driver and Metal compiler.\"\n"
json += "  ]\n"
json += "}\n"

try? json.write(toFile: "./result.json", atomically: true, encoding: .utf8)

let final = allOk ? "PASS" : "FAIL"
print("F-RFC075-METAL-M4-BASELINE: \(final)")
print(String(format: "PEAK_GB_PER_S=%.2f @ N=%d", peakGBs, peakN))
print(String(format: "M3_BASELINE_1OP_PEAK=%.2f GB/s", m3PeakGBs_1op))
print(String(format: "M4_OVER_M3_RATIO=%.3fx", peakGBs / m3PeakGBs_1op))
exit(allOk ? 0 : 1)
