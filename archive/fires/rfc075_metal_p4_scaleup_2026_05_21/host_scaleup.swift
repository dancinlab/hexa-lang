// host_scaleup.swift — RFC 075 Metal P4 follow-on (scale-up + throughput)
//
// Reuses inbox/fires/rfc075_metal_p4_2026_05_21/vec_add.metallib at multiple
// N to characterise Apple-Silicon GPU vec-add throughput. Emits per-shape
// median dispatch wall, derived GB/s effective bandwidth, max|Δ| vs CPU ref,
// and byte_mismatch via Float32.bitPattern.
//
// Usage: xcrun --sdk macosx swift host_scaleup.swift <path/to/vec_add.metallib>

import Foundation
import Metal

// Shapes to sweep.
let SHAPES: [Int] = [1024, 4096, 16384, 65536, 262144, 1048576, 4194304]
let WARMUP_LAUNCHES = 5
let TIMED_LAUNCHES = 50

// LCG (Numerical Recipes constants) — deterministic.
final class LCG {
    var state: UInt32
    init(seed: UInt32) { self.state = seed }
    func next() -> UInt32 {
        state = state &* 1664525 &+ 1013904223
        return state
    }
    func f32() -> Float32 {
        return (Float32(self.next()) / Float32(UInt32.max)) * 2.0 - 1.0
    }
}

// Metal device + queue.
guard let device = MTLCreateSystemDefaultDevice() else {
    print("F-RFC075-METAL-SCALEUP: FAIL (no Metal device)")
    exit(1)
}
print("device=\(device.name) registry=\(device.registryID)")
print("max_threads_per_threadgroup_width=\(device.maxThreadsPerThreadgroup.width)")
guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-SCALEUP: FAIL (no command queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2 ? CommandLine.arguments[1] : "./vec_add.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-SCALEUP: FAIL (makeLibrary: \(error))")
    exit(1)
}
guard let kernelFn = library.makeFunction(name: "vec_add") else {
    print("F-RFC075-METAL-SCALEUP: FAIL (no vec_add)")
    exit(1)
}
let pipeline: MTLComputePipelineState
do {
    pipeline = try device.makeComputePipelineState(function: kernelFn)
} catch {
    print("F-RFC075-METAL-SCALEUP: FAIL (pipeline: \(error))")
    exit(1)
}
print("threadExecutionWidth=\(pipeline.threadExecutionWidth)")
print("maxTotalThreadsPerThreadgroup=\(pipeline.maxTotalThreadsPerThreadgroup)")

// One row per shape — written as JSON at the end.
struct Row {
    let n: Int
    let bytes_total: Int
    let median_ms: Double
    let std_ms: Double
    let min_ms: Double
    let max_ms: Double
    let gb_per_s_effective: Double
    let max_abs_diff: Float32
    let byte_mismatch: Int
}
var rows: [Row] = []

print("\n shape    median_ms     min_ms     max_ms    GB/s    max|d|   byte_mm")
print("-------- ----------- ---------- ---------- -------- -------- ----------")

for N in SHAPES {
    let bytes = N * MemoryLayout<Float32>.stride

    // Input setup (allocate once per shape).
    let lcg = LCG(seed: 0x12345678)
    var a = [Float32](repeating: 0, count: N)
    var b = [Float32](repeating: 0, count: N)
    var ref = [Float32](repeating: 0, count: N)
    for i in 0..<N {
        a[i] = lcg.f32()
        b[i] = lcg.f32()
        ref[i] = a[i] + b[i]
    }

    guard let bufA = device.makeBuffer(bytes: a, length: bytes, options: .storageModeShared),
          let bufB = device.makeBuffer(bytes: b, length: bytes, options: .storageModeShared),
          let bufC = device.makeBuffer(length: bytes, options: .storageModeShared) else {
        print("F-RFC075-METAL-SCALEUP: FAIL (buffer alloc at N=\(N))")
        exit(1)
    }
    memset(bufC.contents(), 0, bytes)

    let grid = MTLSize(width: N, height: 1, depth: 1)
    let tgWidth = min(pipeline.threadExecutionWidth, N)
    let tg = MTLSize(width: tgWidth, height: 1, depth: 1)

    // Warmup.
    for _ in 0..<WARMUP_LAUNCHES {
        let cmd = queue.makeCommandBuffer()!
        let enc = cmd.makeComputeCommandEncoder()!
        enc.setComputePipelineState(pipeline)
        enc.setBuffer(bufA, offset: 0, index: 0)
        enc.setBuffer(bufB, offset: 0, index: 1)
        enc.setBuffer(bufC, offset: 0, index: 2)
        enc.dispatchThreads(grid, threadsPerThreadgroup: tg)
        enc.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
    }

    // Timed.
    var samples: [Double] = []
    samples.reserveCapacity(TIMED_LAUNCHES)
    for _ in 0..<TIMED_LAUNCHES {
        memset(bufC.contents(), 0, bytes)
        let cmd = queue.makeCommandBuffer()!
        let enc = cmd.makeComputeCommandEncoder()!
        enc.setComputePipelineState(pipeline)
        enc.setBuffer(bufA, offset: 0, index: 0)
        enc.setBuffer(bufB, offset: 0, index: 1)
        enc.setBuffer(bufC, offset: 0, index: 2)
        enc.dispatchThreads(grid, threadsPerThreadgroup: tg)
        enc.endEncoding()
        let t0 = Date()
        cmd.commit()
        cmd.waitUntilCompleted()
        let t1 = Date()
        let ms = t1.timeIntervalSince(t0) * 1000.0
        samples.append(ms)
    }
    samples.sort()
    let median = samples[samples.count / 2]
    let minMs = samples.first!
    let maxMs = samples.last!
    let mean = samples.reduce(0, +) / Double(samples.count)
    let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(samples.count)
    let std = sqrt(variance)

    // Effective bandwidth: 2 reads + 1 write = 3 * N * 4 bytes / median_seconds.
    let bytes_total = 3 * N * 4
    let gb_per_s = (Double(bytes_total) / 1e9) / (median / 1000.0)

    // Numerical check.
    let gpu = bufC.contents().bindMemory(to: Float32.self, capacity: N)
    var maxDiff: Float32 = 0
    var byteMM: Int = 0
    for i in 0..<N {
        let d = abs(gpu[i] - ref[i])
        if d > maxDiff { maxDiff = d }
        if gpu[i].bitPattern != ref[i].bitPattern { byteMM += 1 }
    }

    let row = Row(n: N, bytes_total: bytes_total, median_ms: median, std_ms: std,
                  min_ms: minMs, max_ms: maxMs, gb_per_s_effective: gb_per_s,
                  max_abs_diff: maxDiff, byte_mismatch: byteMM)
    rows.append(row)
    print(String(format: "%8d  %9.4f  %9.4f  %9.4f  %7.2f  %7.4f  %4d/%-7d",
                  N, median, minMs, maxMs, gb_per_s, Double(maxDiff), byteMM, N))
}

// Pass criterion: every shape byte-eq.
let allPass = rows.allSatisfy { $0.byte_mismatch == 0 }
print("")
if allPass {
    print("F-RFC075-METAL-SCALEUP-NUMERIC-EQ: PASS (byte_eq across all \(SHAPES.count) shapes)")
} else {
    print("F-RFC075-METAL-SCALEUP-NUMERIC-EQ: PARTIAL (\(rows.filter { $0.byte_mismatch == 0 }.count)/\(rows.count) shapes byte-eq)")
}

// Dump JSON for artifact.
let resultPath = "result.json"
var jsonRows: [[String: Any]] = []
for r in rows {
    jsonRows.append([
        "N": r.n,
        "bytes_total": r.bytes_total,
        "median_ms": r.median_ms,
        "std_ms": r.std_ms,
        "min_ms": r.min_ms,
        "max_ms": r.max_ms,
        "gb_per_s_effective": r.gb_per_s_effective,
        "max_abs_diff": Double(r.max_abs_diff),
        "byte_mismatch": r.byte_mismatch,
    ])
}
let json: [String: Any] = [
    "campaign": "rfc075_metal_p4_scaleup_2026_05_21",
    "device": device.name,
    "registry_id": device.registryID,
    "thread_execution_width": pipeline.threadExecutionWidth,
    "max_total_threads_per_threadgroup": pipeline.maxTotalThreadsPerThreadgroup,
    "warmup_launches": WARMUP_LAUNCHES,
    "timed_launches": TIMED_LAUNCHES,
    "shapes": jsonRows,
    "all_pass_byte_eq": allPass,
    "falsifier_F_RFC075_METAL_SCALEUP_NUMERIC_EQ": allPass ? "PASS" : "PARTIAL",
]
if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: URL(fileURLWithPath: resultPath))
    print("wrote \(resultPath) (\(data.count) bytes)")
}

exit(allPass ? 0 : 1)
