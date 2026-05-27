// host_shapes.swift — Silicon-fire all 3 RFC 075 Metal codegen shapes.
//
// Reuses the canonical 1024-cell LCG-deterministic byte-eq pattern from
// the original Metal P4 host. Loads three separate .metallib files (one
// per shape: vec_add / vec_mul / vec_scale) and runs each with the
// matching CPU reference: a+b / a*b / a*const.
//
// Usage: xcrun --sdk macosx swift host_shapes.swift

import Foundation
import Metal

let N = 1024

final class LCG {
    var state: UInt32
    init(seed: UInt32) { self.state = seed }
    func next() -> UInt32 { state = state &* 1664525 &+ 1013904223; return state }
    func f32() -> Float32 { return (Float32(self.next()) / Float32(UInt32.max)) * 2.0 - 1.0 }
}

guard let device = MTLCreateSystemDefaultDevice() else { print("FAIL device"); exit(1) }
guard let queue = device.makeCommandQueue() else { print("FAIL queue"); exit(1) }
print("device=\(device.name)")

// Re-prep deterministic inputs (same per kernel for clean compare).
let lcg = LCG(seed: 0x12345678)
var a = [Float32](repeating: 0, count: N)
var b = [Float32](repeating: 0, count: N)
for i in 0..<N { a[i] = lcg.f32(); b[i] = lcg.f32() }

struct ShapeTest {
    let name: String
    let metallib: String
    let kernel: String
    let cpuRef: (Float32, Float32) -> Float32
}
let SCALE: Float32 = 2.5
let tests: [ShapeTest] = [
    ShapeTest(name: "vec_add",   metallib: "vec_add.metallib",   kernel: "vec_add",   cpuRef: { x, y in x + y }),
    ShapeTest(name: "vec_mul",   metallib: "vec_mul.metallib",   kernel: "vec_mul",   cpuRef: { x, y in x * y }),
    ShapeTest(name: "vec_scale", metallib: "vec_scale.metallib", kernel: "vec_scale", cpuRef: { x, _ in x * SCALE }),
]

var allPass = true
var rows: [[String: Any]] = []

print("\nshape       max|d|    byte_mm    PASS/FAIL")
print("---------- --------- ---------- ---------")

for t in tests {
    let library: MTLLibrary
    do { library = try device.makeLibrary(URL: URL(fileURLWithPath: t.metallib)) }
    catch { print("\(t.name): FAIL makeLibrary \(error)"); allPass = false; continue }
    guard let fn = library.makeFunction(name: t.kernel) else {
        print("\(t.name): FAIL no fn"); allPass = false; continue
    }
    let pipeline: MTLComputePipelineState
    do { pipeline = try device.makeComputePipelineState(function: fn) }
    catch { print("\(t.name): FAIL pipeline \(error)"); allPass = false; continue }

    let bytes = N * MemoryLayout<Float32>.stride
    let bufA = device.makeBuffer(bytes: a, length: bytes, options: .storageModeShared)!
    let bufB = device.makeBuffer(bytes: b, length: bytes, options: .storageModeShared)!
    let bufC = device.makeBuffer(length: bytes, options: .storageModeShared)!
    memset(bufC.contents(), 0, bytes)

    let cmd = queue.makeCommandBuffer()!
    let enc = cmd.makeComputeCommandEncoder()!
    enc.setComputePipelineState(pipeline)
    enc.setBuffer(bufA, offset: 0, index: 0)
    enc.setBuffer(bufB, offset: 0, index: 1)
    enc.setBuffer(bufC, offset: 0, index: 2)
    let grid = MTLSize(width: N, height: 1, depth: 1)
    let tg = MTLSize(width: min(pipeline.threadExecutionWidth, N), height: 1, depth: 1)
    enc.dispatchThreads(grid, threadsPerThreadgroup: tg)
    enc.endEncoding()
    cmd.commit()
    cmd.waitUntilCompleted()

    let gpu = bufC.contents().bindMemory(to: Float32.self, capacity: N)
    var maxDiff: Float32 = 0
    var byteMM = 0
    for i in 0..<N {
        let r = t.cpuRef(a[i], b[i])
        let d = abs(gpu[i] - r)
        if d > maxDiff { maxDiff = d }
        if gpu[i].bitPattern != r.bitPattern { byteMM += 1 }
    }
    let status = byteMM == 0 ? "PASS" : "FAIL"
    if byteMM != 0 { allPass = false }
    let nameCol = t.name.padding(toLength: 10, withPad: " ", startingAt: 0)
    let diffCol = String(format: "%9.6f", Double(maxDiff))
    let mmCol = String(format: "%4d/%-5d", byteMM, N)
    print("\(nameCol) \(diffCol)  \(mmCol)  \(status)")
    rows.append([
        "shape": t.name, "kernel": t.kernel,
        "N": N, "max_abs_diff": Double(maxDiff), "byte_mismatch": byteMM, "status": status,
    ])
}

print("")
if allPass {
    print("F-RFC075-METAL-SHAPES-NUMERIC-EQ: PASS (all 3 shapes byte_eq across \(N) cells)")
} else {
    print("F-RFC075-METAL-SHAPES-NUMERIC-EQ: PARTIAL")
}

let json: [String: Any] = [
    "campaign": "rfc075_metal_p4_shapes_2026_05_21",
    "device": device.name,
    "registry_id": device.registryID,
    "shapes_tested": ["vec_add", "vec_mul", "vec_scale"],
    "N": N,
    "rows": rows,
    "all_pass_byte_eq": allPass,
    "falsifier_F_RFC075_METAL_SHAPES_NUMERIC_EQ": allPass ? "PASS" : "PARTIAL",
]
if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: URL(fileURLWithPath: "result.json"))
    print("wrote result.json (\(data.count) bytes)")
}
exit(allPass ? 0 : 1)
