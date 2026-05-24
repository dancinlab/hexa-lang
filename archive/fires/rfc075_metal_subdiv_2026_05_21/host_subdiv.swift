// host_subdiv.swift — F-RFC075-METAL-SUBDIV-NUMERIC-EQ
//
// Silicon-validates the 2 new codegen shapes from commit ca49aea1
// (vec-sub, vec-div) on Apple M3 vs CPU reference. N=1024 LCG-deterministic
// FP32 inputs. Float divide is NOT bit-exact across compiler decompositions
// (rcp + mul vs div), so compare with a small ULP tolerance for vec_div.

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

let lcg = LCG(seed: 0x12345678)
var a = [Float32](repeating: 0, count: N)
var b = [Float32](repeating: 0, count: N)
for i in 0..<N {
    a[i] = lcg.f32()
    var bv = lcg.f32()
    if abs(bv) < 0.01 { bv = bv >= 0 ? 0.01 : -0.01 }
    b[i] = bv
}

struct Test {
    let name: String
    let metallib: String
    let kernel: String
    let cpuRef: (Float32, Float32) -> Float32
    let exactExpected: Bool
}
let tests: [Test] = [
    Test(name: "vec_sub", metallib: "vec_sub.metallib", kernel: "vec_sub",
         cpuRef: { x, y in x - y }, exactExpected: true),
    Test(name: "vec_div", metallib: "vec_div.metallib", kernel: "vec_div",
         cpuRef: { x, y in x / y }, exactExpected: false),
]

var allPass = true
var rows: [[String: Any]] = []

print("\nshape       max|d|      max_ulp    byte_mm    status")
print("---------- ----------- --------- ---------- --------")

for t in tests {
    let library = try device.makeLibrary(URL: URL(fileURLWithPath: t.metallib))
    guard let fn = library.makeFunction(name: t.kernel) else {
        print("FAIL no fn \(t.kernel)"); allPass = false; continue
    }
    let pipeline = try device.makeComputePipelineState(function: fn)

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
    cmd.commit(); cmd.waitUntilCompleted()

    let gpu = bufC.contents().bindMemory(to: Float32.self, capacity: N)
    var maxDiff: Float32 = 0
    var maxUlp: Int32 = 0
    var byteMM = 0
    for i in 0..<N {
        let ref = t.cpuRef(a[i], b[i])
        let d = abs(gpu[i] - ref)
        if d > maxDiff { maxDiff = d }
        if gpu[i].bitPattern != ref.bitPattern {
            byteMM += 1
            let ulp = Int32(bitPattern: gpu[i].bitPattern) - Int32(bitPattern: ref.bitPattern)
            let absUlp = abs(ulp)
            if absUlp > maxUlp { maxUlp = absUlp }
        }
    }
    let status: String
    if t.exactExpected {
        status = byteMM == 0 ? "PASS_BYTEEQ" : "FAIL_BYTEEQ"
        if byteMM != 0 { allPass = false }
    } else {
        // div: tolerate up to 4 ULP (typical GPU rcp+mul vs IEEE div)
        status = maxUlp <= 4 ? "PASS_LOW_ULP" : "FAIL_HIGH_ULP"
        if maxUlp > 4 { allPass = false }
    }
    let nameCol = t.name.padding(toLength: 10, withPad: " ", startingAt: 0)
    let diffCol = String(format: "%11.8f", Double(maxDiff))
    let ulpCol = String(format: "%6d", maxUlp)
    let mmCol = String(format: "%4d/%-5d", byteMM, N)
    print("\(nameCol) \(diffCol) \(ulpCol)    \(mmCol)  \(status)")
    rows.append([
        "shape": t.name, "exact_expected": t.exactExpected,
        "max_abs_diff": Double(maxDiff), "max_ulp": Int(maxUlp),
        "byte_mismatch": byteMM, "status": status,
    ])
}

print("")
if allPass {
    print("F-RFC075-METAL-SUBDIV-NUMERIC-EQ: PASS (vec_sub byte_eq + vec_div ≤4 ULP)")
}

let json: [String: Any] = [
    "campaign": "rfc075_metal_subdiv_2026_05_21",
    "device": device.name,
    "shapes_tested": ["vec_sub", "vec_div"],
    "N": N,
    "rows": rows,
    "all_pass": allPass,
    "falsifier_F_RFC075_METAL_SUBDIV_NUMERIC_EQ": allPass ? "PASS" : "FAIL",
]
if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: URL(fileURLWithPath: "result.json"))
    print("wrote result.json (\(data.count) bytes)")
}
exit(allPass ? 0 : 1)
