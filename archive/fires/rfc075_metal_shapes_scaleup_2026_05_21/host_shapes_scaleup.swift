// host_shapes_scaleup.swift — Metal vec_add/vec_mul/vec_scale scale-up.
//
// Reuses the 3 metallibs from rfc075_metal_p4_shapes_2026_05_21/.
// Sweeps N for each shape, reports median ms + GB/s + byte-eq vs CPU ref.
//
// Usage: xcrun --sdk macosx swift host_shapes_scaleup.swift <shapes_dir>

import Foundation
import Metal

let SHAPES: [Int] = [1024, 4096, 16384, 65536, 262144, 1048576, 4194304]
let WARMUP = 5
let TIMED = 50
let SCALE: Float32 = 2.5

final class LCG {
    var state: UInt32
    init(seed: UInt32) { self.state = seed }
    func next() -> UInt32 { state = state &* 1664525 &+ 1013904223; return state }
    func f32() -> Float32 { return (Float32(self.next()) / Float32(UInt32.max)) * 2.0 - 1.0 }
}

guard let device = MTLCreateSystemDefaultDevice() else { print("FAIL device"); exit(1) }
guard let queue = device.makeCommandQueue() else { print("FAIL queue"); exit(1) }
print("device=\(device.name)")

let shapesDir = CommandLine.arguments.count >= 2 ? CommandLine.arguments[1] : "../rfc075_metal_p4_shapes_2026_05_21"

struct KernelInfo {
    let name: String
    let metallibPath: String
    let cpuRef: (Float32, Float32) -> Float32
}
let kernels: [KernelInfo] = [
    KernelInfo(name: "vec_add",   metallibPath: "\(shapesDir)/vec_add.metallib",   cpuRef: { x, y in x + y }),
    KernelInfo(name: "vec_mul",   metallibPath: "\(shapesDir)/vec_mul.metallib",   cpuRef: { x, y in x * y }),
    KernelInfo(name: "vec_scale", metallibPath: "\(shapesDir)/vec_scale.metallib", cpuRef: { x, _ in x * SCALE }),
]

struct Row {
    let shape: String
    let n: Int
    let median_ms: Double
    let gb_per_s: Double
    let byte_mismatch: Int
}
var rows: [Row] = []

var pipelines: [String: MTLComputePipelineState] = [:]
for k in kernels {
    let library = try device.makeLibrary(URL: URL(fileURLWithPath: k.metallibPath))
    guard let fn = library.makeFunction(name: k.name) else { print("FAIL no fn \(k.name)"); exit(1) }
    pipelines[k.name] = try device.makeComputePipelineState(function: fn)
}

print("\nshape       N         median_ms     GB/s     byte_mm")
print("---------- --------- ----------- ---------- -----------")

for N in SHAPES {
    // Prep deterministic inputs once per N.
    let lcg = LCG(seed: 0x12345678)
    var a = [Float32](repeating: 0, count: N)
    var b = [Float32](repeating: 0, count: N)
    for i in 0..<N { a[i] = lcg.f32(); b[i] = lcg.f32() }

    let bytes = N * MemoryLayout<Float32>.stride
    let bufA = device.makeBuffer(bytes: a, length: bytes, options: .storageModeShared)!
    let bufB = device.makeBuffer(bytes: b, length: bytes, options: .storageModeShared)!
    let bufC = device.makeBuffer(length: bytes, options: .storageModeShared)!

    let grid = MTLSize(width: N, height: 1, depth: 1)

    for k in kernels {
        let pipeline = pipelines[k.name]!
        let tgWidth = min(pipeline.threadExecutionWidth, N)
        let tg = MTLSize(width: tgWidth, height: 1, depth: 1)
        memset(bufC.contents(), 0, bytes)

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
            cmd.commit(); cmd.waitUntilCompleted()
        }

        // Timed.
        var samples: [Double] = []
        for _ in 0..<TIMED {
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
            cmd.commit(); cmd.waitUntilCompleted()
            let t1 = Date()
            samples.append(t1.timeIntervalSince(t0) * 1000.0)
        }
        samples.sort()
        let median = samples[samples.count / 2]
        let gb = (Double(3 * N * 4) / 1e9) / (median / 1000.0)

        // Verify byte-eq.
        let gpu = bufC.contents().bindMemory(to: Float32.self, capacity: N)
        var byteMM = 0
        for i in 0..<N {
            let r = k.cpuRef(a[i], b[i])
            if gpu[i].bitPattern != r.bitPattern { byteMM += 1 }
        }
        let row = Row(shape: k.name, n: N, median_ms: median, gb_per_s: gb, byte_mismatch: byteMM)
        rows.append(row)
        let nameCol = k.name.padding(toLength: 10, withPad: " ", startingAt: 0)
        let nCol = String(format: "%8d", N)
        let medCol = String(format: "%9.4f", median)
        let gbCol = String(format: "%8.2f", gb)
        let mmCol = String(format: "%3d/%-7d", byteMM, N)
        print("\(nameCol) \(nCol)  \(medCol)  \(gbCol)  \(mmCol)")
    }
}

let allPass = rows.allSatisfy { $0.byte_mismatch == 0 }
print("")
if allPass {
    print("F-RFC075-METAL-SHAPES-SCALEUP-NUMERIC-EQ: PASS (all \(kernels.count) shapes × \(SHAPES.count) sizes byte_eq)")
}

var jsonRows: [[String: Any]] = []
for r in rows {
    jsonRows.append([
        "shape": r.shape, "N": r.n,
        "median_ms": r.median_ms, "gb_per_s": r.gb_per_s, "byte_mismatch": r.byte_mismatch,
    ])
}
let json: [String: Any] = [
    "campaign": "rfc075_metal_shapes_scaleup_2026_05_21",
    "device": device.name,
    "shapes": kernels.map { $0.name }, "sizes": SHAPES,
    "warmup": WARMUP, "timed": TIMED,
    "rows": jsonRows,
    "all_pass_byte_eq": allPass,
    "falsifier_F_RFC075_METAL_SHAPES_SCALEUP_NUMERIC_EQ": allPass ? "PASS" : "PARTIAL",
]
if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: URL(fileURLWithPath: "result.json"))
    print("wrote result.json (\(data.count) bytes)")
}

// Per-shape peak GB/s summary.
print("\n=== Peak GB/s per shape ===")
for k in kernels {
    let nRows = rows.filter { $0.shape == k.name }
    let peakGB = nRows.map { $0.gb_per_s }.max() ?? 0
    let peakN = nRows.first(where: { $0.gb_per_s == peakGB })?.n ?? 0
    print("\(k.name): peak \(String(format: "%.2f", peakGB)) GB/s @ N=\(peakN)")
}

exit(allPass ? 0 : 1)
