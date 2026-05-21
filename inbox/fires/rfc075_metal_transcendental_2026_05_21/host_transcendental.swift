// host_transcendental.swift — F-RFC075-METAL-TRANSCENDENTAL-NUMERIC-EQ
//
// Silicon-validates the 4 transcendental codegen shapes (vec-exp,
// vec-log, vec-sin, vec-cos) from this RFC 075 P3+ extension on
// Apple M3 vs CPU reference. N=1024 LCG-deterministic FP32 inputs
// (Numerical Recipes seed 0x12345678).
//
// All four are transcendentals — Apple MSL `exp` / `log` / `sin` /
// `cos` builtins (Metal Shading Language Specification §5.10) are
// IEEE-754-flavoured but NOT bit-equal to libm; expected tolerance
// is several ULP. We measure max_ulp and report it (no PASS gate on
// byte-eq for transcendentals).
//
// Input ranges:
//   exp:  raw a in [-1, 1] (LCG output); avoids overflow
//   log:  abs(a) + tiny  in (eps, 1]; avoids log(0) → -inf and log(<0) → NaN
//   sin:  raw a in [-1, 1]
//   cos:  raw a in [-1, 1]
//
// ULP tolerance gates set per-op based on Apple's Metal Shading
// Language Specification §5.10 (math functions) and observed Apple M3
// silicon behaviour. The gates are honest upper bounds; tighter
// observed values will be recorded in result.json max_ulp.

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
for i in 0..<N {
    a[i] = lcg.f32()
}
// vec_log needs positive input. abs(a) is in [0,1]; add tiny epsilon
// to keep input strictly > 0 (log(0) = -inf would mask the comparison).
var a_log = [Float32](repeating: 0, count: N)
for i in 0..<N { a_log[i] = abs(a[i]) + Float32(1.0e-6) }

struct Test {
    let name: String
    let metallib: String
    let kernel: String
    let inputBuffer: [Float32]
    let cpuRef: (Float32) -> Float32
    let ulpTolerance: Int32
}
// Tolerances chosen as conservative upper bounds — Apple MSL §5.10
// transcendentals are typically within a few ULP for in-range inputs.
let tests: [Test] = [
    Test(name: "vec_exp", metallib: "vec_exp.metallib", kernel: "vec_exp",
         inputBuffer: a, cpuRef: { x in Foundation.exp(x) }, ulpTolerance: 8),
    Test(name: "vec_log", metallib: "vec_log.metallib", kernel: "vec_log",
         inputBuffer: a_log, cpuRef: { x in Foundation.log(x) }, ulpTolerance: 8),
    Test(name: "vec_sin", metallib: "vec_sin.metallib", kernel: "vec_sin",
         inputBuffer: a, cpuRef: { x in Foundation.sin(x) }, ulpTolerance: 8),
    Test(name: "vec_cos", metallib: "vec_cos.metallib", kernel: "vec_cos",
         inputBuffer: a, cpuRef: { x in Foundation.cos(x) }, ulpTolerance: 8),
]

var allPass = true
var rows: [[String: Any]] = []

print("\nshape       max|d|      max_ulp    byte_mm    status")
print("---------- ----------- --------- ---------- --------")

for t in tests {
    let library: MTLLibrary
    do {
        library = try device.makeLibrary(URL: URL(fileURLWithPath: t.metallib))
    } catch {
        print("FAIL load \(t.metallib): \(error)"); allPass = false; continue
    }
    guard let fn = library.makeFunction(name: t.kernel) else {
        print("FAIL no fn \(t.kernel)"); allPass = false; continue
    }
    let pipeline: MTLComputePipelineState
    do {
        pipeline = try device.makeComputePipelineState(function: fn)
    } catch {
        print("FAIL pipeline \(t.kernel): \(error)"); allPass = false; continue
    }

    let bytes = N * MemoryLayout<Float32>.stride
    let bufA = device.makeBuffer(bytes: t.inputBuffer, length: bytes, options: .storageModeShared)!
    let bufC = device.makeBuffer(length: bytes, options: .storageModeShared)!
    memset(bufC.contents(), 0, bytes)

    let cmd = queue.makeCommandBuffer()!
    let enc = cmd.makeComputeCommandEncoder()!
    enc.setComputePipelineState(pipeline)
    enc.setBuffer(bufA, offset: 0, index: 0)
    enc.setBuffer(bufC, offset: 0, index: 1)
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
        let ref = t.cpuRef(t.inputBuffer[i])
        let d = abs(gpu[i] - ref)
        if d > maxDiff { maxDiff = d }
        if gpu[i].bitPattern != ref.bitPattern {
            byteMM += 1
            let ulp = Int32(bitPattern: gpu[i].bitPattern) - Int32(bitPattern: ref.bitPattern)
            let absUlp = abs(ulp)
            if absUlp > maxUlp { maxUlp = absUlp }
        }
    }
    let status = maxUlp <= t.ulpTolerance ? "PASS_LOW_ULP" : "FAIL_HIGH_ULP"
    if maxUlp > t.ulpTolerance { allPass = false }
    let nameCol = t.name.padding(toLength: 10, withPad: " ", startingAt: 0)
    let diffCol = String(format: "%11.8f", Double(maxDiff))
    let ulpCol = String(format: "%6d", maxUlp)
    let mmCol = String(format: "%4d/%-5d", byteMM, N)
    print("\(nameCol) \(diffCol) \(ulpCol)    \(mmCol)  \(status)")
    rows.append([
        "shape": t.name,
        "ulp_tolerance": Int(t.ulpTolerance),
        "max_abs_diff": Double(maxDiff), "max_ulp": Int(maxUlp),
        "byte_mismatch": byteMM, "status": status,
    ])
}

print("")
if allPass {
    print("F-RFC075-METAL-TRANSCENDENTAL-NUMERIC-EQ: PASS (max_ulp within tolerance)")
} else {
    print("F-RFC075-METAL-TRANSCENDENTAL-NUMERIC-EQ: FAIL")
}

let json: [String: Any] = [
    "campaign": "rfc075_metal_transcendental_2026_05_21",
    "device": device.name,
    "shapes_tested": ["vec_exp", "vec_log", "vec_sin", "vec_cos"],
    "N": N,
    "seed_hex": "0x12345678",
    "rows": rows,
    "all_pass": allPass,
    "falsifier_F_RFC075_METAL_TRANSCENDENTAL_NUMERIC_EQ": allPass ? "PASS" : "FAIL",
]
if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: URL(fileURLWithPath: "result.json"))
    print("wrote result.json (\(data.count) bytes)")
}
exit(allPass ? 0 : 1)
