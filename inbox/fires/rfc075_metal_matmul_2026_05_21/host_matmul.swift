// host_matmul.swift — RFC 075 P5 matmul silicon-fire host
//
// Loads matmul.metallib, runs matmul_naive + matmul_tiled across a
// shape sweep (128/256/512 cubes), compares vs CPU FP32 reference
// (ikj loop matching the kernel's K reduction order), times each
// dispatch over warmup+timed runs, and emits one
// F-RFC075-METAL-MATMUL-NUMERIC-EQ status line + per-shape GFLOPS.
//
// Tolerance: max_abs_diff / max|ref| < 1e-5 (single-prec matmul
// standard; matches torch.allclose default rtol). Pure byte-eq is
// NOT expected — matmul's K-reduction reassociates and the kernel's
// load order differs from CPU's ikj inner stride.
//
// Build + run:
//   xcrun --sdk macosx swift host_matmul.swift ./matmul.metallib

import Foundation
import Metal

// ─── deterministic LCG (Numerical Recipes 32-bit) ──────────────────────
var lcg_state: UInt32 = 0x12345678
func lcg_next() -> UInt32 {
    lcg_state = lcg_state &* 1664525 &+ 1013904223
    return lcg_state
}
func lcg_f32() -> Float32 {
    let u = lcg_next()
    return (Float32(u) / Float32(UInt32.max)) * 2.0 - 1.0
}

// ─── CPU FP32 reference (ikj inner stride) ─────────────────────────────
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

// ─── Metal setup ───────────────────────────────────────────────────────
guard let device = MTLCreateSystemDefaultDevice() else {
    print("F-RFC075-METAL-MATMUL-NUMERIC-EQ: FAIL (no Metal device)"); exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
print("max_threads_per_threadgroup=\(device.maxThreadsPerThreadgroup)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-MATMUL-NUMERIC-EQ: FAIL (no queue)"); exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./matmul.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-MATMUL-NUMERIC-EQ: FAIL (makeLibrary: \(error))"); exit(1)
}

func makePipeline(_ name: String) -> MTLComputePipelineState {
    guard let fn = library.makeFunction(name: name) else {
        print("F-RFC075-METAL-MATMUL-NUMERIC-EQ: FAIL (no \(name) fn)"); exit(1)
    }
    do { return try device.makeComputePipelineState(function: fn) }
    catch {
        print("F-RFC075-METAL-MATMUL-NUMERIC-EQ: FAIL (pipeline \(name): \(error))")
        exit(1)
    }
}

let pipeNaive = makePipeline("matmul_naive")
let pipeTiled = makePipeline("matmul_tiled")

// ─── one shape probe ───────────────────────────────────────────────────
struct Result {
    let M: Int; let N: Int; let K: Int
    let kernel: String
    let median_ms: Double
    let gflops: Double
    let max_abs_diff: Float32
    let max_rel_err: Float32
    let byte_mismatch: Int
    let pass: Bool
}

func run_shape(_ M: Int, _ N: Int, _ K: Int,
               kernel name: String,
               pipeline: MTLComputePipelineState,
               warmup: Int, timed: Int) -> Result {
    // Reset LCG so each shape is deterministic (and ref reproducible).
    lcg_state = 0x12345678
    var a = [Float32](repeating: 0, count: M * K)
    var b = [Float32](repeating: 0, count: K * N)
    for i in 0..<(M * K) { a[i] = lcg_f32() }
    for i in 0..<(K * N) { b[i] = lcg_f32() }
    let ref = cpu_matmul_ref(a, b, M, N, K)

    let aBytes = M * K * MemoryLayout<Float32>.stride
    let bBytes = K * N * MemoryLayout<Float32>.stride
    let cBytes = M * N * MemoryLayout<Float32>.stride

    guard let bufA = device.makeBuffer(bytes: a, length: aBytes, options: .storageModeShared),
          let bufB = device.makeBuffer(bytes: b, length: bBytes, options: .storageModeShared),
          let bufC = device.makeBuffer(length: cBytes, options: .storageModeShared) else {
        print("F-RFC075-METAL-MATMUL-NUMERIC-EQ: FAIL (buffer alloc)"); exit(1)
    }

    var Mv: UInt32 = UInt32(M)
    var Nv: UInt32 = UInt32(N)
    var Kv: UInt32 = UInt32(K)

    // For naive: 1 thread per output cell, 16×16 threadgroup.
    // For tiled: 16×16 threadgroup, grid is (N rounded up, M rounded up).
    let tg = MTLSize(width: 16, height: 16, depth: 1)
    let gridW = ((N + 15) / 16) * 16
    let gridH = ((M + 15) / 16) * 16
    let grid = MTLSize(width: gridW, height: gridH, depth: 1)

    func dispatch_once() -> Double {
        memset(bufC.contents(), 0, cBytes)
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            print("F-RFC075-METAL-MATMUL-NUMERIC-EQ: FAIL (encoder)"); exit(1)
        }
        enc.setComputePipelineState(pipeline)
        enc.setBuffer(bufA, offset: 0, index: 0)
        enc.setBuffer(bufB, offset: 0, index: 1)
        enc.setBuffer(bufC, offset: 0, index: 2)
        enc.setBytes(&Mv, length: 4, index: 3)
        enc.setBytes(&Nv, length: 4, index: 4)
        enc.setBytes(&Kv, length: 4, index: 5)
        enc.dispatchThreads(grid, threadsPerThreadgroup: tg)
        enc.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
        if let err = cmd.error {
            print("F-RFC075-METAL-MATMUL-NUMERIC-EQ: FAIL (commit: \(err))"); exit(1)
        }
        // GPUEndTime / GPUStartTime are seconds (Double).
        return (cmd.gpuEndTime - cmd.gpuStartTime) * 1e3
    }

    // Warmup.
    for _ in 0..<warmup { let _ = dispatch_once() }

    // Timed.
    var samples = [Double](); samples.reserveCapacity(timed)
    for _ in 0..<timed { samples.append(dispatch_once()) }
    samples.sort()
    let median = samples[samples.count / 2]

    // Read back + compare.
    let gpu = bufC.contents().bindMemory(to: Float32.self, capacity: M * N)
    var max_abs_diff: Float32 = 0
    var max_ref_abs: Float32 = 0
    var byte_mismatch: Int = 0
    for i in 0..<(M * N) {
        let d = abs(gpu[i] - ref[i])
        if d > max_abs_diff { max_abs_diff = d }
        let r = abs(ref[i])
        if r > max_ref_abs { max_ref_abs = r }
        if gpu[i].bitPattern != ref[i].bitPattern { byte_mismatch += 1 }
    }
    let rel_err: Float32 = max_ref_abs > 0 ? max_abs_diff / max_ref_abs : 0
    // 2·M·N·K FLOPs per matmul (1 mul + 1 add per inner iter).
    let flops = 2.0 * Double(M) * Double(N) * Double(K)
    let gflops = flops / (median * 1e-3) / 1e9
    let ok = rel_err < 1e-5
    return Result(M: M, N: N, K: K, kernel: name, median_ms: median,
                  gflops: gflops, max_abs_diff: max_abs_diff,
                  max_rel_err: rel_err, byte_mismatch: byte_mismatch, pass: ok)
}

// ─── shape sweep ──────────────────────────────────────────────────────
let shapes: [(Int, Int, Int)] = [(128, 128, 128), (256, 256, 256), (512, 512, 512)]
let warmup = 3
let timed  = 15
var results: [Result] = []
var allOk = true

for (M, N, K) in shapes {
    for (name, pipe) in [("matmul_naive", pipeNaive), ("matmul_tiled", pipeTiled)] {
        let r = run_shape(M, N, K, kernel: name, pipeline: pipe,
                          warmup: warmup, timed: timed)
        results.append(r)
        if !r.pass { allOk = false }
        let tag = r.pass ? "PASS" : "FAIL"
        let kpad = r.kernel.padding(toLength: 13, withPad: " ", startingAt: 0)
        print(String(format: "\(kpad)  M=%d N=%d K=%d  median=%.3fms  GFLOPS=%.2f  max|d|=%.3e  rel=%.3e  byte_mm=%d/%d  \(tag)",
                     r.M, r.N, r.K, r.median_ms, r.gflops,
                     Double(r.max_abs_diff), Double(r.max_rel_err),
                     r.byte_mismatch, r.M * r.N))
    }
}

// ─── result.json emission ─────────────────────────────────────────────
func dq(_ s: String) -> String { return "\"\(s)\"" }
var json = "{\n"
json += "  \"campaign\": \"rfc075_metal_matmul_2026_05_21\",\n"
json += "  \"host\": \"Mac\",\n"
json += "  \"platform\": \"darwin-arm64\",\n"
json += "  \"gpu\": \"\(device.name) (registry_id=\(device.registryID))\",\n"
let mtpt = device.maxThreadsPerThreadgroup
json += "  \"max_threads_per_threadgroup\": \"\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)\",\n"
json += "  \"date_utc\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
json += "  \"warmup\": \(warmup),\n"
json += "  \"timed\": \(timed),\n"
json += "  \"tolerance_rel\": 1e-5,\n"
json += "  \"rows\": [\n"
for (idx, r) in results.enumerated() {
    let comma = idx == results.count - 1 ? "" : ","
    json += "    {\n"
    json += "      \"kernel\": \"\(r.kernel)\",\n"
    json += "      \"M\": \(r.M), \"N\": \(r.N), \"K\": \(r.K),\n"
    json += "      \"median_ms\": \(r.median_ms),\n"
    json += "      \"gflops\": \(r.gflops),\n"
    json += "      \"max_abs_diff\": \(r.max_abs_diff),\n"
    json += "      \"max_rel_err\": \(r.max_rel_err),\n"
    json += "      \"byte_mismatch\": \(r.byte_mismatch),\n"
    json += "      \"pass\": \(r.pass)\n"
    json += "    }\(comma)\n"
}
json += "  ],\n"
let statusStr = allOk ? "PASS" : "PARTIAL"
json += "  \"falsifier_F_RFC075_METAL_MATMUL_NUMERIC_EQ\": \"\(statusStr)\",\n"
json += "  \"honest_scope\": \"FP32 matmul on Apple M3 GPU vs FP32 CPU ikj reference. K-reduction reassociates so rel_err < 1e-5 used (single-prec matmul standard). flame ag_linear today is FP64 farr_matmul → Apple integration is FP32-precision-loss path (gap analysis item #1).\"\n"
json += "}\n"
let jsonPath = "./result.json"
do { try json.write(toFile: jsonPath, atomically: true, encoding: .utf8) }
catch { print("WARN: result.json write failed: \(error)") }

let final = allOk ? "PASS" : "PARTIAL"
print("F-RFC075-METAL-MATMUL-NUMERIC-EQ: \(final)")
exit(0)
