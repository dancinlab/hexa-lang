// host_matmul_bf16_codegen.swift — RFC 075 codegen-emit bf16 silicon fire
//
// Drives matmul_bf16.metallib (output of the N41 codegen for STMT_BINOP("matmul_bf16"))
// across 128/256/512/768/1024 cubes. Compares vs N36 hand-emit
// (commit dbb09684, peak 1029.54 GFLOPS @ 1024^3 on 32x32_tg).
//
// The codegen emits a SINGLE kernel — the 32x32_tg variant only — under the
// MIR symbol name `matmul_bf16`. Kernel signature (mechanical from
// _metal_emit_matmul_kernel_signature_bf16):
//
//   kernel void matmul_bf16(
//       device const bfloat* a    [[buffer(0)]],
//       device const bfloat* b    [[buffer(1)]],
//       device       float*  c    [[buffer(2)]],
//       constant     uint&   M    [[buffer(3)]],
//       constant     uint&   N    [[buffer(4)]],
//       constant     uint&   K    [[buffer(5)]],
//       uint2  tgid [[threadgroup_position_in_grid]],
//       uint2  lid  [[thread_position_in_threadgroup]],
//       uint   sgid [[simdgroup_index_in_threadgroup]],
//       uint   slid [[thread_index_in_simdgroup]])
//
// Dispatch geometry mirrors N36's 32x32_tg kernel exactly:
//   threadsPerThreadgroup = (32, 16, 1)              // 16 simdgroups
//   threadsPerGrid        = ((N+31)/32)*32, ((M+31)/32)*16, 1
//
// Build:
//   xcrun --sdk macosx swift host_matmul_bf16_codegen.swift ./matmul_bf16.metallib

import Foundation
import Metal

// ─── deterministic LCG (identical to N36) ──────────────────────────────
var lcg_state: UInt32 = 0x12345678
func lcg_next() -> UInt32 {
    lcg_state = lcg_state &* 1664525 &+ 1013904223
    return lcg_state
}
func lcg_f32() -> Float32 {
    let u = lcg_next()
    return (Float32(u) / Float32(UInt32.max)) * 2.0 - 1.0
}

// ─── FP32 ↔ bf16 (identical to N36) ────────────────────────────────────
@inline(__always)
func fp32_to_bf16_bits(_ f: Float32) -> UInt16 {
    let bits = f.bitPattern
    if (bits & 0x7F80_0000) == 0x7F80_0000 && (bits & 0x007F_FFFF) != 0 {
        return UInt16((bits >> 16) | 0x0040)
    }
    let lsb = (bits >> 16) & 1
    let rounding_bias: UInt32 = 0x7FFF &+ lsb
    let rounded = bits &+ rounding_bias
    return UInt16(truncatingIfNeeded: rounded >> 16)
}
@inline(__always)
func bf16_bits_to_fp32(_ b: UInt16) -> Float32 {
    let bits = UInt32(b) << 16
    return Float32(bitPattern: bits)
}

// ─── CPU FP32 ikj reference on bf16-rounded inputs ─────────────────────
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

// ─── Metal setup ───────────────────────────────────────────────────────
guard let device = MTLCreateSystemDefaultDevice() else {
    print("F-RFC075-METAL-MATMUL-BF16-CODEGEN-FIRE: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
print("max_threads_per_threadgroup=\(device.maxThreadsPerThreadgroup)")
print("max_threadgroup_memory_length=\(device.maxThreadgroupMemoryLength)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-MATMUL-BF16-CODEGEN-FIRE: FAIL (no queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./matmul_bf16.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-MATMUL-BF16-CODEGEN-FIRE: FAIL (makeLibrary: \(error))")
    exit(1)
}

guard let fn = library.makeFunction(name: "matmul_bf16") else {
    print("F-RFC075-METAL-MATMUL-BF16-CODEGEN-FIRE: FAIL (no matmul_bf16 fn in library)")
    exit(1)
}
let pipeline: MTLComputePipelineState
do { pipeline = try device.makeComputePipelineState(function: fn) }
catch {
    print("F-RFC075-METAL-MATMUL-BF16-CODEGEN-FIRE: FAIL (pipeline: \(error))")
    exit(1)
}
print(String(format: "matmul_bf16 tew=%d max=%d",
             pipeline.threadExecutionWidth, pipeline.maxTotalThreadsPerThreadgroup))

// ─── one shape probe ───────────────────────────────────────────────────
struct Result {
    let M: Int; let N: Int; let K: Int
    let median_ms: Double
    let gflops: Double
    let max_abs_diff: Float32
    let max_rel_err: Float32
    let pass: Bool
}

let TOL_BF16: Float32 = 1e-2

func run_shape(_ M: Int, _ N: Int, _ K: Int,
               warmup: Int, timed: Int,
               aBits: [UInt16], bBits: [UInt16],
               aRounded: [Float32], bRounded: [Float32]) -> Result {

    let ref = cpu_matmul_ref_fp32(aRounded, bRounded, M, N, K)

    let aBytes = M * K * MemoryLayout<UInt16>.stride
    let bBytes = K * N * MemoryLayout<UInt16>.stride
    let cBytes = M * N * MemoryLayout<Float32>.stride

    guard let bufA = device.makeBuffer(bytes: aBits, length: aBytes, options: .storageModeShared),
          let bufB = device.makeBuffer(bytes: bBits, length: bBytes, options: .storageModeShared),
          let bufC = device.makeBuffer(length: cBytes, options: .storageModeShared) else {
        print("F-RFC075-METAL-MATMUL-BF16-CODEGEN-FIRE: FAIL (buffer alloc)"); exit(1)
    }

    var Mv: UInt32 = UInt32(M)
    var Nv: UInt32 = UInt32(N)
    var Kv: UInt32 = UInt32(K)

    // codegen-emitted body uses TG_M=TG_N=32, 16 simdgroups per TG.
    let tg   = MTLSize(width: 32, height: 16, depth: 1)
    let gridW = ((N + 31) / 32) * 32
    let gridH = ((M + 31) / 32) * 16
    let grid  = MTLSize(width: gridW, height: gridH, depth: 1)

    func dispatch_once() -> Double {
        memset(bufC.contents(), 0, cBytes)
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            print("F-RFC075-METAL-MATMUL-BF16-CODEGEN-FIRE: FAIL (encoder)"); exit(1)
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
            print("F-RFC075-METAL-MATMUL-BF16-CODEGEN-FIRE: FAIL (commit: \(err))"); exit(1)
        }
        return (cmd.gpuEndTime - cmd.gpuStartTime) * 1e3
    }

    for _ in 0..<warmup { let _ = dispatch_once() }

    var samples = [Double](); samples.reserveCapacity(timed)
    for _ in 0..<timed { samples.append(dispatch_once()) }
    samples.sort()
    let median = samples[samples.count / 2]

    let gpuRaw = bufC.contents().bindMemory(to: Float32.self, capacity: M * N)
    var max_abs_diff: Float32 = 0
    var max_ref_abs: Float32 = 0
    for i in 0..<(M * N) {
        let g = gpuRaw[i]
        let d = abs(g - ref[i])
        if d > max_abs_diff { max_abs_diff = d }
        let r = abs(ref[i])
        if r > max_ref_abs { max_ref_abs = r }
    }
    let rel_err: Float32 = max_ref_abs > 0 ? max_abs_diff / max_ref_abs : 0
    let flops = 2.0 * Double(M) * Double(N) * Double(K)
    let gflops = flops / (median * 1e-3) / 1e9
    let ok = rel_err < TOL_BF16
    return Result(M: M, N: N, K: K, median_ms: median, gflops: gflops,
                  max_abs_diff: max_abs_diff, max_rel_err: rel_err, pass: ok)
}

// ─── shape sweep ───────────────────────────────────────────────────────
let shapes: [(Int, Int, Int)] = [
    (128, 128, 128),
    (256, 256, 256),
    (512, 512, 512),
    (768, 768, 768),
    (1024, 1024, 1024),
]
let warmup = 5
let timed  = 50

var results: [Result] = []
var allOk = true

for (M, N, K) in shapes {
    lcg_state = 0x12345678
    var aFp32 = [Float32](repeating: 0, count: M * K)
    var bFp32 = [Float32](repeating: 0, count: K * N)
    for i in 0..<(M * K) { aFp32[i] = lcg_f32() }
    for i in 0..<(K * N) { bFp32[i] = lcg_f32() }

    var aBits = [UInt16](repeating: 0, count: M * K)
    var bBits = [UInt16](repeating: 0, count: K * N)
    var aRounded = [Float32](repeating: 0, count: M * K)
    var bRounded = [Float32](repeating: 0, count: K * N)
    for i in 0..<(M * K) {
        let bits = fp32_to_bf16_bits(aFp32[i])
        aBits[i] = bits
        aRounded[i] = bf16_bits_to_fp32(bits)
    }
    for i in 0..<(K * N) {
        let bits = fp32_to_bf16_bits(bFp32[i])
        bBits[i] = bits
        bRounded[i] = bf16_bits_to_fp32(bits)
    }

    let r = run_shape(M, N, K, warmup: warmup, timed: timed,
                      aBits: aBits, bBits: bBits,
                      aRounded: aRounded, bRounded: bRounded)
    results.append(r)
    if !r.pass { allOk = false }
    let tag = r.pass ? "PASS" : "FAIL"
    print(String(format: "matmul_bf16 (codegen)  M=%d N=%d K=%d  median=%.4fms  GFLOPS=%.2f  max|d|=%.3e  rel=%.3e  \(tag)",
                 r.M, r.N, r.K, r.median_ms, r.gflops,
                 Double(r.max_abs_diff), Double(r.max_rel_err)))
}

// ─── N36 hand-emit 32x32_tg anchors (commit dbb09684) ───────────────────
struct HandEmitAnchor { let M: Int; let gflops: Double; let rel: Double }
let n36Anchors: [HandEmitAnchor] = [
    HandEmitAnchor(M:  128, gflops:  239.105, rel: 0.0),
    HandEmitAnchor(M:  256, gflops:  527.378, rel: 0.0),
    HandEmitAnchor(M:  512, gflops:  882.648, rel: 0.0),
    // 768 not yet pulled — left 0 if unmatched
    HandEmitAnchor(M:  768, gflops:    0.0,   rel: 0.0),
    HandEmitAnchor(M: 1024, gflops: 1029.536, rel: 0.0),
]
func n36GflopsAt(_ M: Int) -> Double {
    for a in n36Anchors where a.M == M { return a.gflops }
    return 0
}

// ─── result.json emission ───────────────────────────────────────────────
var json = "{\n"
json += "  \"campaign\": \"rfc075_metal_matmul_bf16_codegen_fire_2026_05_21\",\n"
json += "  \"host\": \"Mac (local)\",\n"
json += "  \"platform\": \"darwin-arm64\",\n"
json += "  \"gpu\": \"\(device.name) (registry_id=\(device.registryID))\",\n"
let mtpt = device.maxThreadsPerThreadgroup
json += "  \"max_threads_per_threadgroup\": \"\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)\",\n"
json += "  \"max_threadgroup_memory_length\": \(device.maxThreadgroupMemoryLength),\n"
json += "  \"date_utc\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
json += "  \"toolchain\": \"xcrun --sdk macosx metal / swift (jit)\",\n"
json += "  \"codegen_commit\": \"7b5f4997\",\n"
json += "  \"codegen_source\": \"compiler/codegen/metal_target.hexa::_metal_emit_matmul_bf16_body + _metal_emit_matmul_kernel_signature_bf16\",\n"
json += "  \"reproduction_method\": \"mechanical concatenation of constants + literals from N41 emit fns (no compiler self-host required); .metal byte-for-byte equivalent to what codegen_emit_metal_msl would write for the matmul_bf16 MIR shape\",\n"
json += "  \"baseline_n36_commit\": \"dbb09684\",\n"
json += "  \"baseline_n36_peak_gflops\": 1029.5361136496808,\n"
json += "  \"warmup\": \(warmup),\n"
json += "  \"timed\": \(timed),\n"
json += "  \"tolerance_rel\": 1e-2,\n"
json += "  \"rows\": [\n"
for (idx, r) in results.enumerated() {
    let comma = idx == results.count - 1 ? "" : ","
    let n36 = n36GflopsAt(r.M)
    let ratio = n36 > 0 ? r.gflops / n36 : 0
    json += "    {\n"
    json += "      \"M\": \(r.M), \"N\": \(r.N), \"K\": \(r.K),\n"
    json += "      \"median_ms\": \(r.median_ms),\n"
    json += "      \"gflops_codegen\": \(r.gflops),\n"
    json += "      \"gflops_n36_handemit_32x32_tg\": \(n36),\n"
    json += "      \"ratio_codegen_vs_handemit\": \(ratio),\n"
    json += "      \"max_abs_diff\": \(r.max_abs_diff),\n"
    json += "      \"max_rel_err\": \(r.max_rel_err),\n"
    json += "      \"pass\": \(r.pass)\n"
    json += "    }\(comma)\n"
}
json += "  ],\n"

func peakGflops() -> Double {
    var best = 0.0
    for r in results { if r.gflops > best { best = r.gflops } }
    return best
}
let peakAny = peakGflops()
let n36Peak: Double = 1029.5361136496808
json += "  \"peak_gflops_codegen\": \(peakAny),\n"
json += "  \"peak_gflops_n36_handemit\": \(n36Peak),\n"
json += "  \"codegen_over_handemit_peak_ratio\": \(peakAny / n36Peak),\n"

var maxRelOverall: Float32 = 0
for r in results { if r.max_rel_err > maxRelOverall { maxRelOverall = r.max_rel_err } }
json += "  \"max_rel_err_overall\": \(maxRelOverall),\n"

let statusStr = allOk ? "PASS" : "FAIL"
json += "  \"falsifier_F_RFC075_METAL_MATMUL_BF16_CODEGEN_FIRE\": \"\(statusStr)\",\n"
json += "  \"headline\": {\n"
json += "    \"codegen_peak_gflops\": \(peakAny),\n"
json += "    \"handemit_peak_gflops\": \(n36Peak),\n"
json += "    \"ratio_codegen_vs_handemit\": \(peakAny / n36Peak),\n"
json += "    \"max_rel_err\": \(maxRelOverall),\n"
json += "    \"verdict\": \"\(statusStr)\"\n"
json += "  },\n"
json += "  \"honest_scope\": [\n"
json += "    \"The .metal source file in this fire was produced by manual concatenation of the constants + string-builder literals in metal_target.hexa::_metal_emit_matmul_bf16_body and friends, NOT by running the hexa compiler end-to-end (the compiler still gates this codegen path behind the MTLGPUFamily.apple9 host runtime feature check). The output is BYTE-EQUIVALENT to what codegen_emit_metal_msl(mod) would write for the matmul_bf16 MIR shape.\",\n"
json += "    \"N41 codegen emits only the 32x32_tg variant of the bf16 matmul. N36 hand-emit had three variants (8x8 / 16x16 / 32x32_tg); the 32x32_tg variant achieved N36's peak 1029 GFLOPS @ 1024^3, so the codegen path covers the highest-throughput shape but does not yet emit the smaller-tile variants.\",\n"
json += "    \"Tolerance 1e-2 matches N36 (bf16 has 7-bit mantissa, FP32 accumulator removes K-loop drift). Reference is built on bf16-rounded inputs identical to what the GPU sees, so rel_err measures compute-side error only.\",\n"
json += "    \"Variance source: Mac is a shared developer laptop; median over 50 timed runs after 5 warmup runs.\"\n"
json += "  ]\n"
json += "}\n"
let jsonPath = "./result.json"
do { try json.write(toFile: jsonPath, atomically: true, encoding: .utf8) }
catch { print("WARN: result.json write failed: \(error)") }

let final = allOk ? "PASS" : "FAIL"
print("F-RFC075-METAL-MATMUL-BF16-CODEGEN-FIRE: \(final)")
print(String(format: "PEAK_CODEGEN_BF16_GFLOPS=%.2f", peakAny))
print(String(format: "PEAK_N36_HANDEMIT_BF16_GFLOPS=%.2f (commit dbb09684, 32x32_tg @ 1024^3)", n36Peak))
print(String(format: "CODEGEN_OVER_HANDEMIT_RATIO=%.3fx", peakAny / n36Peak))
print(String(format: "MAX_REL_ERR_OVERALL=%.3e (gate < 1e-2)", Double(maxRelOverall)))
exit(0)
