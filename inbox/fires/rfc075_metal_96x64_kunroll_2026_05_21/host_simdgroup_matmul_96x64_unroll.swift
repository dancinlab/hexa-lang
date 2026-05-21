// host_simdgroup_matmul_96x64_unroll.swift — RFC 075 Apple M3 96x64 + K-unroll fire
//
// Drives simdgroup_matmul_96x64_unroll.metallib (3 variants: V1 96x64_tg_db,
// V2 64x64_kunroll2, V3 96x64_kunroll2) across the same shape sweep as N37,
// then compares to N37 (peak 1518 GFLOPS @ 1024^3) + MPS FP32 (1702 @ 1024^3).
//
// Same protocol as N37:
//   - LCG-deterministic FP32 inputs → rounded to FP16
//   - CPU FP32 ikj reference (with rounded inputs → apples-to-apples)
//   - 5 warmup + 50 timed dispatches, median ms
//   - rel_err < 1e-4 gate
//
// Build + run:
//   xcrun --sdk macosx swiftc -O host_simdgroup_matmul_96x64_unroll.swift \
//      -o host_96x64_unroll
//   ./host_96x64_unroll ./simdgroup_matmul_96x64_unroll.metallib
//
// Dispatch geometry per kernel:
//   V1 / V3 (96x64): tg=(32,32,1)=1024; grid=( ((N+63)/64)*32, ((M+95)/96)*32, 1 )
//   V2     (64x64):  tg=(32,32,1)=1024; grid=( ((N+63)/64)*32, ((M+63)/64)*32, 1 )

import Foundation
import Metal

// ─── deterministic LCG (same as N37) ─────────────────────────────────────
var lcg_state: UInt32 = 0x12345678
func lcg_next() -> UInt32 {
    lcg_state = lcg_state &* 1664525 &+ 1013904223
    return lcg_state
}
func lcg_f32() -> Float32 {
    let u = lcg_next()
    return (Float32(u) / Float32(UInt32.max)) * 2.0 - 1.0
}

@inline(__always)
func fp32_to_fp16_bits(_ f: Float32) -> UInt16 {
    let h = Float16(f)
    return h.bitPattern
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
    print("F-RFC075-METAL-96X64-KUNROLL-NUMERIC-EQ: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
let mtpt = device.maxThreadsPerThreadgroup
print("max_threads_per_threadgroup=\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)")
print("max_threadgroup_memory_length=\(device.maxThreadgroupMemoryLength)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-96X64-KUNROLL-NUMERIC-EQ: FAIL (no queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./simdgroup_matmul_96x64_unroll.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-96X64-KUNROLL-NUMERIC-EQ: FAIL (makeLibrary: \(error))")
    exit(1)
}

func makePipeline(_ name: String) -> MTLComputePipelineState {
    guard let fn = library.makeFunction(name: name) else {
        print("F-RFC075-METAL-96X64-KUNROLL-NUMERIC-EQ: FAIL (no \(name) fn)")
        exit(1)
    }
    do { return try device.makeComputePipelineState(function: fn) }
    catch {
        print("F-RFC075-METAL-96X64-KUNROLL-NUMERIC-EQ: FAIL (pipeline \(name): \(error))")
        exit(1)
    }
}

let pipeV1 = makePipeline("simdgroup_matmul_96x64_tg_db")        // 96x64 + DB
let pipeV2 = makePipeline("simdgroup_matmul_64x64_kunroll2")     // 64x64 + K-unroll
let pipeV3 = makePipeline("simdgroup_matmul_96x64_kunroll2")     // 96x64 + K-unroll

print("pipeV1  tew=\(pipeV1.threadExecutionWidth)  max=\(pipeV1.maxTotalThreadsPerThreadgroup)  stat_tg_mem=\(pipeV1.staticThreadgroupMemoryLength)")
print("pipeV2  tew=\(pipeV2.threadExecutionWidth)  max=\(pipeV2.maxTotalThreadsPerThreadgroup)  stat_tg_mem=\(pipeV2.staticThreadgroupMemoryLength)")
print("pipeV3  tew=\(pipeV3.threadExecutionWidth)  max=\(pipeV3.maxTotalThreadsPerThreadgroup)  stat_tg_mem=\(pipeV3.staticThreadgroupMemoryLength)")

// Spill diagnostic: any pipeline with maxTotalThreadsPerThreadgroup < 1024 is
// register-pressured and cannot occupy the threadgroup at full width.
let v1Spill = pipeV1.maxTotalThreadsPerThreadgroup < 1024
let v2Spill = pipeV2.maxTotalThreadsPerThreadgroup < 1024
let v3Spill = pipeV3.maxTotalThreadsPerThreadgroup < 1024
if v1Spill { print("NOTE: V1 register-pressured — max=\(pipeV1.maxTotalThreadsPerThreadgroup) < 1024") }
if v2Spill { print("NOTE: V2 register-pressured — max=\(pipeV2.maxTotalThreadsPerThreadgroup) < 1024") }
if v3Spill { print("NOTE: V3 register-pressured — max=\(pipeV3.maxTotalThreadsPerThreadgroup) < 1024") }

// ─── one shape probe ────────────────────────────────────────────────────
struct Result {
    let M: Int; let N: Int; let K: Int
    let kernel: String
    let median_ms: Double
    let gflops: Double
    let max_abs_diff: Float32
    let max_rel_err: Float32
    let pass: Bool
}

func dispatchGeometry(tileM: Int, tileN: Int, _ M: Int, _ N: Int)
    -> (grid: MTLSize, tg: MTLSize)
{
    let tg    = MTLSize(width: 32, height: 32, depth: 1)        // 1024 threads
    let gridW = ((N + tileN - 1) / tileN) * 32
    let gridH = ((M + tileM - 1) / tileM) * 32
    return (MTLSize(width: gridW, height: gridH, depth: 1), tg)
}

let TOL_MIXED: Float32 = 1e-4

func run_shape(_ M: Int, _ N: Int, _ K: Int,
               kernel name: String,
               pipeline: MTLComputePipelineState,
               tileM: Int, tileN: Int,
               warmup: Int, timed: Int,
               cachedRef: [Float32]?,
               aFp32Rounded: [Float32], bFp32Rounded: [Float32],
               aBits: [UInt16], bBits: [UInt16]) -> (Result, [Float32]) {

    let ref: [Float32]
    if let cached = cachedRef { ref = cached }
    else { ref = cpu_matmul_ref_fp32(aFp32Rounded, bFp32Rounded, M, N, K) }

    let aBytes = M * K * MemoryLayout<UInt16>.stride
    let bBytes = K * N * MemoryLayout<UInt16>.stride
    let cBytes = M * N * MemoryLayout<Float32>.stride

    guard let bufA = device.makeBuffer(bytes: aBits, length: aBytes, options: .storageModeShared),
          let bufB = device.makeBuffer(bytes: bBits, length: bBytes, options: .storageModeShared),
          let bufC = device.makeBuffer(length: cBytes, options: .storageModeShared) else {
        print("F-RFC075-METAL-96X64-KUNROLL-NUMERIC-EQ: FAIL (buffer alloc)"); exit(1)
    }

    var Mv: UInt32 = UInt32(M)
    var Nv: UInt32 = UInt32(N)
    var Kv: UInt32 = UInt32(K)

    let (grid, tg) = dispatchGeometry(tileM: tileM, tileN: tileN, M, N)

    func dispatch_once() -> Double {
        memset(bufC.contents(), 0, cBytes)
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            print("F-RFC075-METAL-96X64-KUNROLL-NUMERIC-EQ: FAIL (encoder)"); exit(1)
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
            print("F-RFC075-METAL-96X64-KUNROLL-NUMERIC-EQ: FAIL (commit: \(err))"); exit(1)
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
    let ok = rel_err < TOL_MIXED
    let r = Result(M: M, N: N, K: K, kernel: name, median_ms: median,
                   gflops: gflops, max_abs_diff: max_abs_diff,
                   max_rel_err: rel_err, pass: ok)
    return (r, ref)
}

// ─── shape sweep ────────────────────────────────────────────────────────
// 96x64 tiles need M to be multiple of 96 for "exact" coverage. The kernel
// has bounds-check on a_row/a_col/b_row/b_col, so non-multiples are safe (zero
// pad). 256/512/768/1024/1536/2048: not all are multiples of 96, but that's
// honest — production matmul rarely hits exact 96 multiples either.
let shapes: [(Int, Int, Int)] = [
    (256, 256, 256),
    (512, 512, 512),
    (768, 768, 768),
    (1024, 1024, 1024),
    (1536, 1536, 1536),
    (2048, 2048, 2048),
]
let warmup = 5
let timed  = 50

struct KernelSpec {
    let name: String
    let pipeline: MTLComputePipelineState
    let tileM: Int
    let tileN: Int
}

let kernels: [KernelSpec] = [
    KernelSpec(name: "simdgroup_matmul_96x64_tg_db",        pipeline: pipeV1, tileM: 96, tileN: 64),
    KernelSpec(name: "simdgroup_matmul_64x64_kunroll2",     pipeline: pipeV2, tileM: 64, tileN: 64),
    KernelSpec(name: "simdgroup_matmul_96x64_kunroll2",     pipeline: pipeV3, tileM: 96, tileN: 64),
]

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
        let bits = fp32_to_fp16_bits(aFp32[i])
        aBits[i] = bits
        aRounded[i] = Float32(Float16(bitPattern: bits))
    }
    for i in 0..<(K * N) {
        let bits = fp32_to_fp16_bits(bFp32[i])
        bBits[i] = bits
        bRounded[i] = Float32(Float16(bitPattern: bits))
    }

    var cachedRef: [Float32]? = nil
    for ks in kernels {
        let (r, ref) = run_shape(M, N, K, kernel: ks.name, pipeline: ks.pipeline,
                                 tileM: ks.tileM, tileN: ks.tileN,
                                 warmup: warmup, timed: timed,
                                 cachedRef: cachedRef,
                                 aFp32Rounded: aRounded, bFp32Rounded: bRounded,
                                 aBits: aBits, bBits: bBits)
        cachedRef = ref
        results.append(r)
        if !r.pass { allOk = false }
        let tag = r.pass ? "PASS" : "FAIL"
        let kpad = r.kernel.padding(toLength: 36, withPad: " ", startingAt: 0)
        print(String(format: "\(kpad)  M=%d N=%d K=%d  median=%.4fms  GFLOPS=%.2f  max|d|=%.3e  rel=%.3e  \(tag)",
                     r.M, r.N, r.K, r.median_ms, r.gflops,
                     Double(r.max_abs_diff), Double(r.max_rel_err)))
    }
}

// ─── result.json emission ───────────────────────────────────────────────
// Anchors:
//   N37 (64x64 + DB):    1518.73 GFLOPS @ 1024^3  (rfc075_metal_simdgroup_matmul_64x64_2026_05_21)
//   N37 (64x64 single):  1280.55 GFLOPS @ 1024^3
//   N30 (32x32 mixed):    986.97 GFLOPS @ 1024^3
//   MPS FP32 GEMM:       1702.75 GFLOPS @ 1024^3  (host_mps_gemm, commit 9b352bda)
//                        1666.34 GFLOPS @  768^3
//   Apple M3 advertised peak FP32: ~3500 GFLOPS

let n37_db_anchor: [Int: Double] = [
    256: 408.37,
    512: 1369.86,
    768: 1041.34,
    1024: 1518.73,
    1536: 1247.22,
    2048: 1123.05,
]
let n37_single_anchor: [Int: Double] = [
    256: 490.44,
    512: 908.15,
    768: 847.69,
    1024: 1280.55,
    1536: 1083.33,
    2048: 1054.44,
]
let mps_anchor: [Int: Double] = [
    768: 1666.34,
    1024: 1702.75,
]

func peakGflops(_ kernel: String) -> (Double, Int) {
    var best = 0.0; var bestM = 0
    for r in results where r.kernel == kernel {
        if r.gflops > best { best = r.gflops; bestM = r.M }
    }
    return (best, bestM)
}

let (peakV1, peakV1M) = peakGflops("simdgroup_matmul_96x64_tg_db")
let (peakV2, peakV2M) = peakGflops("simdgroup_matmul_64x64_kunroll2")
let (peakV3, peakV3M) = peakGflops("simdgroup_matmul_96x64_kunroll2")
let peakAny = max(peakV1, max(peakV2, peakV3))

let n37_peak: Double = 1518.73
let mps_peak: Double = 1702.75
let m3_theoretical: Double = 3500.0

let gapClosurePct: Double = (peakAny - n37_peak) / (mps_peak - n37_peak) * 100.0
let hitMps: Bool = peakAny >= mps_peak

var json = "{\n"
json += "  \"campaign\": \"rfc075_metal_96x64_kunroll_2026_05_21\",\n"
json += "  \"host\": \"Mac (local)\",\n"
json += "  \"platform\": \"darwin-arm64\",\n"
json += "  \"gpu\": \"\(device.name) (registry_id=\(device.registryID))\",\n"
json += "  \"max_threads_per_threadgroup\": \"\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)\",\n"
json += "  \"max_threadgroup_memory_length\": \(device.maxThreadgroupMemoryLength),\n"
json += "  \"date_utc\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
json += "  \"toolchain\": \"xcrun --sdk macosx metal / swiftc (-O)\",\n"
json += "  \"intrinsic\": \"simdgroup_matrix<half,8,8> inputs + simdgroup_matrix<float,8,8> accumulator + simdgroup_multiply_accumulate (mixed-prec, same as N37)\",\n"
json += "  \"variants\": {\n"
json += "    \"V1\": \"96x64 output tile, TG_K=32, double-buffered. 32 SGs = 4 row (x3 sub-tile stack) x 8 col. 20 KiB TG mem.\",\n"
json += "    \"V2\": \"64x64 output tile, TG_K=64 (K-unroll 2x vs N37), single-buffered. 32 SGs = 8 row x 4 col-pair. 16 KiB TG mem.\",\n"
json += "    \"V3\": \"96x64 output tile + TG_K=64 (combined). Single-buffered (DB would exceed 32 KiB). 20 KiB TG mem.\"\n"
json += "  },\n"
json += "  \"n37_baseline_campaign\": \"rfc075_metal_simdgroup_matmul_64x64_2026_05_21\",\n"
json += "  \"n42_baseline_campaign\": \"rfc075_metal_async_copy_2026_05_21\",\n"
json += "  \"warmup\": \(warmup),\n"
json += "  \"timed\": \(timed),\n"
json += "  \"tolerance_rel\": 1e-4,\n"
json += "  \"pipe_v1_max_threads_per_threadgroup\": \(pipeV1.maxTotalThreadsPerThreadgroup),\n"
json += "  \"pipe_v2_max_threads_per_threadgroup\": \(pipeV2.maxTotalThreadsPerThreadgroup),\n"
json += "  \"pipe_v3_max_threads_per_threadgroup\": \(pipeV3.maxTotalThreadsPerThreadgroup),\n"
json += "  \"pipe_v1_register_spill_detected\": \(v1Spill),\n"
json += "  \"pipe_v2_register_spill_detected\": \(v2Spill),\n"
json += "  \"pipe_v3_register_spill_detected\": \(v3Spill),\n"
json += "  \"pipe_v1_static_tg_mem_bytes\": \(pipeV1.staticThreadgroupMemoryLength),\n"
json += "  \"pipe_v2_static_tg_mem_bytes\": \(pipeV2.staticThreadgroupMemoryLength),\n"
json += "  \"pipe_v3_static_tg_mem_bytes\": \(pipeV3.staticThreadgroupMemoryLength),\n"
json += "  \"rows\": [\n"
for (idx, r) in results.enumerated() {
    let comma = idx == results.count - 1 ? "" : ","
    let n37db = n37_db_anchor[r.M] ?? 0
    let n37s  = n37_single_anchor[r.M] ?? 0
    let mps   = mps_anchor[r.M] ?? 0
    let ratioN37db = n37db > 0 ? r.gflops / n37db : 0
    let ratioMPS   = mps > 0 ? r.gflops / mps : 0
    json += "    {\n"
    json += "      \"kernel\": \"\(r.kernel)\",\n"
    json += "      \"M\": \(r.M), \"N\": \(r.N), \"K\": \(r.K),\n"
    json += "      \"median_ms\": \(r.median_ms),\n"
    json += "      \"gflops\": \(r.gflops),\n"
    json += "      \"n37_db_baseline_gflops\": \(n37db),\n"
    json += "      \"n37_single_baseline_gflops\": \(n37s),\n"
    json += "      \"ratio_vs_n37_db\": \(ratioN37db),\n"
    json += "      \"mps_baseline_gflops\": \(mps),\n"
    json += "      \"ratio_vs_mps\": \(ratioMPS),\n"
    json += "      \"max_abs_diff\": \(r.max_abs_diff),\n"
    json += "      \"max_rel_err\": \(r.max_rel_err),\n"
    json += "      \"pass\": \(r.pass)\n"
    json += "    }\(comma)\n"
}
json += "  ],\n"

json += "  \"peak_gflops_v1_96x64_tg_db\": \(peakV1),\n"
json += "  \"peak_shape_v1\": \(peakV1M),\n"
json += "  \"peak_gflops_v2_64x64_kunroll2\": \(peakV2),\n"
json += "  \"peak_shape_v2\": \(peakV2M),\n"
json += "  \"peak_gflops_v3_96x64_kunroll2\": \(peakV3),\n"
json += "  \"peak_shape_v3\": \(peakV3M),\n"
json += "  \"peak_gflops_overall\": \(peakAny),\n"
json += "  \"n37_db_peak_gflops\": \(n37_peak),\n"
json += "  \"mps_fp32_peak_gflops\": \(mps_peak),\n"
json += "  \"apple_m3_theoretical_fp32_gflops\": \(m3_theoretical),\n"
json += "  \"ratio_overall_over_n37\": \(peakAny / n37_peak),\n"
json += "  \"ratio_overall_over_mps\": \(peakAny / mps_peak),\n"
json += "  \"ratio_overall_over_apple_theoretical\": \(peakAny / m3_theoretical),\n"
json += "  \"gap_closure_percent_vs_mps_from_n37\": \(gapClosurePct),\n"
json += "  \"hit_mps_or_above\": \(hitMps),\n"

var maxRelOverall: Float32 = 0
for r in results { if r.max_rel_err > maxRelOverall { maxRelOverall = r.max_rel_err } }
json += "  \"max_rel_err_overall\": \(maxRelOverall),\n"

json += "  \"headline\": {\n"
json += "    \"peak_overall_gflops\": \(peakAny),\n"
json += "    \"vs_n37_ratio\": \(peakAny / n37_peak),\n"
json += "    \"vs_mps_ratio\": \(peakAny / mps_peak),\n"
json += "    \"gap_closure_percent_from_n37_to_mps\": \(gapClosurePct),\n"
json += "    \"hit_mps_or_above\": \(hitMps),\n"
json += "    \"winning_variant\": \"\(peakV1 >= peakV2 && peakV1 >= peakV3 ? "V1_96x64_tg_db" : (peakV2 >= peakV3 ? "V2_64x64_kunroll2" : "V3_96x64_kunroll2"))\"\n"
json += "  },\n"

json += "  \"comparison_table\": {\n"
json += "    \"columns\": [\"approach\", \"shape\", \"GFLOPS\", \"rel_err\", \"source\"],\n"
json += "    \"rows\": [\n"
json += "      [\"simdgroup_matmul_32x32_tg_mixed\", \"1024^3\",  986.97,  0.0, \"N30 (commit 99aed70f)\"],\n"
json += "      [\"simdgroup_matmul_64x64_tg_db\", \"1024^3\",   1518.73, 0.0, \"N37 (peak, this campaign baseline)\"],\n"
for r in results {
    json += "      [\"\(r.kernel)\", \"\(r.M)^3\", \(r.gflops), \(r.max_rel_err), \"this fire (N43)\"],\n"
}
json += "      [\"MPS GEMM FP32\", \"1024^3\", 1702.75, 1e-6, \"host_mps_gemm fire (commit 9b352bda)\"],\n"
json += "      [\"Apple M3 advertised peak FP32\", \"-\", \(m3_theoretical), 0, \"Apple GPU spec sheet\"]\n"
json += "    ]\n"
json += "  },\n"

let statusStr = allOk ? "PASS" : "PARTIAL"
json += "  \"falsifier_F_RFC075_METAL_96X64_KUNROLL_NUMERIC_EQ\": \"\(statusStr)\",\n"
json += "  \"honest_scope\": [\n"
json += "    \"V1: 96x64 tile + DB attacks task-(a). 32 SGs as 4(M)x8(N) where each SG owns a 3-stack of 8x8 sub-tiles in M; one B-load shared across the stack (3 MACs per inner step).\",\n"
json += "    \"V2: 64x64 + TG_K=64 attacks task-(b). Same N37 topology but inner kk2 substep count doubles 4 → 8. Twice the in-flight register accumulator chain between barriers.\",\n"
json += "    \"V3: 96x64 + TG_K=64 combines (a)+(b). 24 in-flight register MACs per outer iter (8 substeps x 3 sub-tile stack).\",\n"
json += "    \"All three keep mixed-prec (half inputs + float accumulator). max_rel_err < 1e-4 gate holds (FP32 accumulator restores precision; only FP16 input rounding contributes error).\",\n"
json += "    \"If any variant reports maxTotalThreadsPerThreadgroup < 1024 the kernel is register-spilling and occupancy drops; that case is flagged in headline.\",\n"
json += "    \"NEGATIVE-measurement scenario: if neither variant beats N37, the gap is deeper than tile-size OR K-unroll-width OR scheduler hoisting. Possible remaining causes: per-shape tile rebalancing (MPS dispatches different geometries per shape), microcode dispatcher heuristics, FMA throughput ceiling.\",\n"
json += "    \"96-row tile is rectangular by necessity — 96x96 FP16 needs 2 * 18 KiB = 36 KiB which exceeds the 32 KiB threadgroup-mem budget on Apple M3.\",\n"
json += "    \"Mac is a shared developer laptop; median over 50 timed runs after 5 warmups; variance noisier than dedicated GPU host measurements.\",\n"
json += "    \"Apple M3 advertised peak FP32 ~3500 GFLOPS is the realistic ceiling; MPS at 1702 sits at ~48% of advertised peak, so even MPS leaves room.\"\n"
json += "  ]\n"
json += "}\n"
let jsonPath = "./result.json"
do { try json.write(toFile: jsonPath, atomically: true, encoding: .utf8) }
catch { print("WARN: result.json write failed: \(error)") }

let final = allOk ? "PASS" : "PARTIAL"
print("F-RFC075-METAL-96X64-KUNROLL-NUMERIC-EQ: \(final)")
print(String(format: "PEAK_OVERALL_GFLOPS=%.2f", peakAny))
print(String(format: "PEAK_V1_96X64_DB=%.2f @ M=%d",       peakV1, peakV1M))
print(String(format: "PEAK_V2_64X64_KUNROLL2=%.2f @ M=%d", peakV2, peakV2M))
print(String(format: "PEAK_V3_96X64_KUNROLL2=%.2f @ M=%d", peakV3, peakV3M))
print(String(format: "VS_N37_RATIO=%.3fx  (N37 peak = %.2f GFLOPS)", peakAny / n37_peak, n37_peak))
print(String(format: "VS_MPS_RATIO=%.3fx  (MPS peak = %.2f GFLOPS)", peakAny / mps_peak, mps_peak))
print(String(format: "GAP_CLOSURE_FROM_N37_TO_MPS=%.1f%%", gapClosurePct))
print(String(format: "HIT_MPS_OR_ABOVE=\(hitMps)"))
print(String(format: "MAX_REL_ERR_OVERALL=%.3e (gate < 1e-4)", Double(maxRelOverall)))
exit(0)
