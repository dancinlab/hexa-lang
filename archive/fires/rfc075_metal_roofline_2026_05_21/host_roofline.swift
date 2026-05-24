// host_roofline.swift — Apple M3 GPU arithmetic-intensity roofline probe.
//
// Drives 5 kernels at varying ops-per-element (1/4/16/64/256). For each
// (kernel, N) pair: 5 warmup + 50 timed dispatches, reports median ms +
// GB/s effective bandwidth + GFLOPS achieved + roofline regime estimate.
// CPU verification not done for >1-op kernels (the chained-add reference
// would need bit-exact matching across re-association; not the point).
//
// Usage: xcrun --sdk macosx swift host_roofline.swift kernels.metallib

import Foundation
import Metal

let SHAPES: [Int] = [65536, 262144, 1048576, 4194304]
let KERNELS: [(name: String, ops: Int)] = [
    ("vec_add_1op",   1),
    ("vec_add_4op",   4),
    ("vec_add_16op",  16),
    ("vec_add_64op",  64),
    ("vec_add_256op", 256),
]
let WARMUP = 5
let TIMED = 50

guard let device = MTLCreateSystemDefaultDevice() else {
    print("FAIL: no Metal device"); exit(1)
}
print("device=\(device.name)")

guard let queue = device.makeCommandQueue() else { print("FAIL: queue"); exit(1) }

let metallibPath = CommandLine.arguments.count >= 2 ? CommandLine.arguments[1] : "./kernels.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("FAIL: makeLibrary \(error)"); exit(1)
}

// Pre-build pipeline states.
var pipelines: [String: MTLComputePipelineState] = [:]
for k in KERNELS {
    guard let fn = library.makeFunction(name: k.name) else {
        print("FAIL: no fn \(k.name)"); exit(1)
    }
    pipelines[k.name] = try device.makeComputePipelineState(function: fn)
}

// Result row.
struct Row {
    let n: Int
    let kernel: String
    let ops_per_elem: Int
    let median_ms: Double
    let gb_per_s: Double
    let gflops: Double
}
var rows: [Row] = []

print("\nN          kernel          ops  median_ms    GB/s   GFLOPS")
print("---------- --------------- ---- ----------  ------- --------")

for N in SHAPES {
    let bytes = N * MemoryLayout<Float32>.stride
    guard let bufA = device.makeBuffer(length: bytes, options: .storageModeShared),
          let bufB = device.makeBuffer(length: bytes, options: .storageModeShared),
          let bufC = device.makeBuffer(length: bytes, options: .storageModeShared) else {
        print("FAIL: buffer alloc N=\(N)"); exit(1)
    }

    // Fill A and B with 1.0 / 0.5 (deterministic, simple).
    let pA = bufA.contents().bindMemory(to: Float32.self, capacity: N)
    let pB = bufB.contents().bindMemory(to: Float32.self, capacity: N)
    for i in 0..<N {
        pA[i] = 1.0
        pB[i] = 0.5
    }
    memset(bufC.contents(), 0, bytes)

    let grid = MTLSize(width: N, height: 1, depth: 1)

    for k in KERNELS {
        let pipeline = pipelines[k.name]!
        let tgWidth = min(pipeline.threadExecutionWidth, N)
        let tg = MTLSize(width: tgWidth, height: 1, depth: 1)

        // Warmup.
        for _ in 0..<WARMUP {
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
        for _ in 0..<TIMED {
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
            samples.append(t1.timeIntervalSince(t0) * 1000.0)
        }
        samples.sort()
        let median = samples[samples.count / 2]

        // Effective bandwidth: 3 * N * 4 bytes (memory-bound formula).
        let gb = (Double(3 * N * 4) / 1e9) / (median / 1000.0)
        // GFLOPS: N * ops / (median * 1e6).
        let gflops = (Double(N) * Double(k.ops)) / (median * 1e6)

        let row = Row(n: N, kernel: k.name, ops_per_elem: k.ops,
                      median_ms: median, gb_per_s: gb, gflops: gflops)
        rows.append(row)
        print(String(format: "%-10d %-15s %4d  %9.4f  %7.2f  %8.2f",
                     N, k.name, k.ops, median, gb, gflops))
    }
}

// Per-N: identify roofline crossover (where GFLOPS plateaus = compute-bound).
print("\n=== Roofline crossover per N ===")
for N in SHAPES {
    let nRows = rows.filter { $0.n == N }
    // Compute peak GB/s and peak GFLOPS for this N.
    let peakGB = nRows.map { $0.gb_per_s }.max() ?? 0
    let peakFLOPS = nRows.map { $0.gflops }.max() ?? 0
    print("N=\(N):  peak GB/s = \(String(format: "%.2f", peakGB)),  peak GFLOPS = \(String(format: "%.2f", peakFLOPS))")
}

// Save JSON.
var jsonRows: [[String: Any]] = []
for r in rows {
    jsonRows.append([
        "N": r.n, "kernel": r.kernel, "ops_per_elem": r.ops_per_elem,
        "median_ms": r.median_ms, "gb_per_s": r.gb_per_s, "gflops": r.gflops,
    ])
}
let json: [String: Any] = [
    "campaign": "rfc075_metal_roofline_2026_05_21",
    "device": device.name,
    "shapes": SHAPES,
    "kernels": KERNELS.map { ["name": $0.name, "ops_per_elem": $0.ops] },
    "warmup": WARMUP,
    "timed": TIMED,
    "rows": jsonRows,
]
if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: URL(fileURLWithPath: "result.json"))
    print("\nwrote result.json (\(data.count) bytes)")
}
