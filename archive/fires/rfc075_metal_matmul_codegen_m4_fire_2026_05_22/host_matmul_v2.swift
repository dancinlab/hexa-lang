// host_matmul_v2.swift — RFC 075 P3++ codegen-emitted matmul MSL silicon fire on
// Apple M4 (mini), N166 FULL-TILE variant. Drives matmul_codegen_v2.metallib
// (the verbatim _metal_emit_matmul_body output AFTER the N166 2-bug fix:
//   Fix 1 — make_filled_simdgroup_matrix<float,8,8>(0.0f) template-arg
//   Fix 2 — 4x4 grid of 8x8 fragments = full 32x32 output tile per threadgroup)
// and checks numeric-eq vs a CPU FP32 reference over the WHOLE M*N output.
//
// Unlike the N166 first fire (host_matmul.swift), the kernel now fills every
// element of each 32x32 tile, so there is no covered/uncovered split: the
// numeric check + GFLOPS are over the full M*N matrix (apples-to-apples vs the
// N138 hand-emit).
//
// Anchors (M4, mini):
//   - N133 M4 64x64_tg_db hand-emit peak 1858.35 GFLOPS @ 1024^3
//   - N138 M4 4-simdgroup 64x64 hand-emit peak 2109 GFLOPS @ M=1536
//
// Build + run:
//   xcrun --sdk macosx swiftc -O host_matmul_v2.swift -o host_matmul_v2
//   ./host_matmul_v2 ./matmul_codegen_v2.metallib 256
//
// Dispatch geometry (codegen body semantics, full 32x32 tile / threadgroup):
//   threadsPerThreadgroup = (32, 1, 1)  = 1 simdgroup
//   threadgroups          = (N/32, M/32, 1)

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

@inline(never)
func cpu_matmul_ref_fp32(_ a: [Float32], _ b: [Float32],
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

// ─── Metal setup ────────────────────────────────────────────────────────
guard let device = MTLCreateSystemDefaultDevice() else {
    print("F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
let mtpt = device.maxThreadsPerThreadgroup
print("max_threads_per_threadgroup=\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: FAIL (no queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./matmul_codegen_v2.metallib"
let DIM = CommandLine.arguments.count >= 3 ? (Int(CommandLine.arguments[2]) ?? 256) : 256

let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: FAIL (makeLibrary: \(error))")
    exit(1)
}

guard let fn = library.makeFunction(name: "matmul_kernel") else {
    print("F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: FAIL (no matmul_kernel fn)")
    exit(1)
}
let pipe: MTLComputePipelineState
do { pipe = try device.makeComputePipelineState(function: fn) }
catch {
    print("F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: FAIL (pipeline: \(error))")
    exit(1)
}
print("VALID_PIPELINE matmul_kernel  tew=\(pipe.threadExecutionWidth)  max=\(pipe.maxTotalThreadsPerThreadgroup)")

// ─── single shape fire ────────────────────────────────────────────────
let M = DIM, N = DIM, K = DIM
print("shape M=\(M) N=\(N) K=\(K)")

var a = [Float32](repeating: 0, count: M * K)
var b = [Float32](repeating: 0, count: K * N)
for i in 0..<(M * K) { a[i] = lcg_f32() }
for i in 0..<(K * N) { b[i] = lcg_f32() }

let ref = cpu_matmul_ref_fp32(a, b, M, N, K)

let aBytes = M * K * MemoryLayout<Float32>.stride
let bBytes = K * N * MemoryLayout<Float32>.stride
let cBytes = M * N * MemoryLayout<Float32>.stride

guard let bufA = device.makeBuffer(bytes: a, length: aBytes, options: .storageModeShared),
      let bufB = device.makeBuffer(bytes: b, length: bBytes, options: .storageModeShared),
      let bufC = device.makeBuffer(length: cBytes, options: .storageModeShared) else {
    print("F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: FAIL (buffer alloc)"); exit(1)
}

var Mv: UInt32 = UInt32(M)
var Nv: UInt32 = UInt32(N)
var Kv: UInt32 = UInt32(K)

// Full-tile codegen body: tg = threadgroup_position_in_grid; each threadgroup
// fills its full 32x32 output tile (4x4 grid of 8x8 fragments). One simdgroup
// (32 threads) per threadgroup.
let tg = MTLSize(width: 32, height: 1, depth: 1)
let groups = MTLSize(width: N / 32, height: M / 32, depth: 1)

func dispatch_once() -> Double {
    memset(bufC.contents(), 0, cBytes)
    guard let cmd = queue.makeCommandBuffer(),
          let enc = cmd.makeComputeCommandEncoder() else {
        print("F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: FAIL (encoder)"); exit(1)
    }
    enc.setComputePipelineState(pipe)
    enc.setBuffer(bufA, offset: 0, index: 0)
    enc.setBuffer(bufB, offset: 0, index: 1)
    enc.setBuffer(bufC, offset: 0, index: 2)
    enc.setBytes(&Mv, length: 4, index: 3)
    enc.setBytes(&Nv, length: 4, index: 4)
    enc.setBytes(&Kv, length: 4, index: 5)
    enc.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
    enc.endEncoding()
    cmd.commit()
    cmd.waitUntilCompleted()
    if let err = cmd.error {
        print("F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: FAIL (commit: \(err))"); exit(1)
    }
    return (cmd.gpuEndTime - cmd.gpuStartTime) * 1e3
}

let warmup = 5, timed = 50
for _ in 0..<warmup { let _ = dispatch_once() }
var samples = [Double](); samples.reserveCapacity(timed)
for _ in 0..<timed { samples.append(dispatch_once()) }
samples.sort()
let median = samples[samples.count / 2]

let gpuRaw = bufC.contents().bindMemory(to: Float32.self, capacity: M * N)

// ── FULL-tile numeric check over EVERY output element ──
var full_max_abs: Float32 = 0
var full_max_ref: Float32 = 0
var zero_count = 0   // GPU outputs left at zero (would indicate a missing sub-tile)
for r in 0..<M {
    for cc in 0..<N {
        let idx = r * N + cc
        let g = gpuRaw[idx]
        let rf = ref[idx]
        let d = abs(g - rf)
        let ar = abs(rf)
        if d > full_max_abs { full_max_abs = d }
        if ar > full_max_ref { full_max_ref = ar }
        if g == 0 && rf != 0 { zero_count += 1 }
    }
}
let full_rel: Float32 = full_max_ref > 0 ? full_max_abs / full_max_ref : 0

// Full-tile GFLOPS — every element computed, apples-to-apples vs hand-emit.
let full_flops = 2.0 * Double(M) * Double(N) * Double(K)
let full_gflops = full_flops / (median * 1e-3) / 1e9

let TOL: Float32 = 1e-3
let pass = full_rel < TOL && zero_count == 0

print("--- RESULT ---")
print("full_tile_max_abs_diff=\(full_max_abs)")
print("full_tile_max_rel_err=\(full_rel)")
print("zero_inside_missing=\(zero_count)  (expected 0 for full-tile)")
print("median_ms=\(median)")
print("full_tile_gflops=\(full_gflops)")
print("TOL=\(TOL)")
if pass {
    print("F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: PASS (full-tile rel_err=\(full_rel) < \(TOL), zero_missing=0)")
} else {
    print("F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: FAIL (full rel_err=\(full_rel), zero_missing=\(zero_count))")
}

// ─── result.json ───────────────────────────────────────────────────────
let json = """
{
  "fire": "rfc075_metal_matmul_codegen_m4_fulltile",
  "host": "mini (Apple M4 10-core GPU)",
  "device_name": "\(device.name)",
  "kernel": "matmul_kernel",
  "source": "matmul_codegen_v2.metal (verbatim _metal_emit_matmul_body AFTER N166 2-bug fix: template-arg + 4x4 32x32 sub-tile loop)",
  "input_dtype": "FP32 (codegen emits device const float*)",
  "accum_dtype": "FP32 (simdgroup_float8x8)",
  "shape": { "M": \(M), "N": \(N), "K": \(K) },
  "dispatch": { "threads_per_threadgroup": "32x1x1", "threadgroups": "\(N/32)x\(M/32)x1" },
  "full_tile_max_abs_diff": \(full_max_abs),
  "full_tile_max_rel_err": \(full_rel),
  "zero_inside_missing": \(zero_count),
  "median_ms": \(median),
  "full_tile_gflops": \(full_gflops),
  "tol": \(TOL),
  "F_RFC075_METAL_MATMUL_CODEGEN_M4_FULLTILE": "\(pass ? "PASS" : "FAIL")",
  "anchors": { "N133_baseline_gflops": 1858.35, "N138_handemit_4sg_gflops": 2109.0 }
}
"""
do {
    try json.write(toFile: "result.json", atomically: true, encoding: .utf8)
    print("wrote result.json")
} catch {
    print("WARN could not write result.json: \(error)")
}
