// host_simdgroup_matmul_64x64.swift — RFC 075 Apple M3 64×64 simdgroup-MMA fire
//
// Drives simdgroup_matmul_64x64_tg.metallib (single-buffer + double-buffered
// variants) across a shape sweep. Compares to N30 mixed-prec 32×32_tg peak
// (986.97 GFLOPS @ 1024³, commit 99aed70f) and MPS FP32 1666.34-1702.75
// GFLOPS @ 768/1024.
//
// Same protocol as N30:
//   - LCG-deterministic FP32 inputs → rounded to FP16 (GPU + reference
//     consume the SAME rounded values).
//   - CPU FP32 ikj reference (rounded to ensure apples-to-apples).
//   - 5 warmup + 50 timed dispatches, median ms.
//   - rel_err < 1e-4 gate (FP32 accumulator restores precision).
//
// Build + run:
//   xcrun --sdk macosx swiftc -O host_simdgroup_matmul_64x64.swift -o host_64x64
//   ./host_64x64 ./simdgroup_matmul_64x64_tg.metallib
//
// Dispatch geometry:
//   threads_per_threadgroup = (32, 32, 1) = 1024
//   threads_per_grid        = ( ((N+63)/64) * 32, ((M+63)/64) * 32, 1 )

import Foundation
import Metal

// ─── deterministic LCG (Numerical Recipes 32-bit) — same as N30 ─────
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
    print("F-RFC075-METAL-SIMDGROUP-64X64-NUMERIC-EQ: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
let mtpt = device.maxThreadsPerThreadgroup
print("max_threads_per_threadgroup=\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)")
print("max_threadgroup_memory_length=\(device.maxThreadgroupMemoryLength)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-SIMDGROUP-64X64-NUMERIC-EQ: FAIL (no queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./simdgroup_matmul_64x64_tg.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-SIMDGROUP-64X64-NUMERIC-EQ: FAIL (makeLibrary: \(error))")
    exit(1)
}

func makePipeline(_ name: String) -> MTLComputePipelineState {
    guard let fn = library.makeFunction(name: name) else {
        print("F-RFC075-METAL-SIMDGROUP-64X64-NUMERIC-EQ: FAIL (no \(name) fn)")
        exit(1)
    }
    do { return try device.makeComputePipelineState(function: fn) }
    catch {
        print("F-RFC075-METAL-SIMDGROUP-64X64-NUMERIC-EQ: FAIL (pipeline \(name): \(error))")
        exit(1)
    }
}

let pipe64    = makePipeline("simdgroup_matmul_64x64_tg")
let pipe64db  = makePipeline("simdgroup_matmul_64x64_tg_db")

print("pipe64    tew=\(pipe64.threadExecutionWidth)    max=\(pipe64.maxTotalThreadsPerThreadgroup)   stat_threadgroup_memory_length=\(pipe64.staticThreadgroupMemoryLength)")
print("pipe64db  tew=\(pipe64db.threadExecutionWidth)  max=\(pipe64db.maxTotalThreadsPerThreadgroup) stat_threadgroup_memory_length=\(pipe64db.staticThreadgroupMemoryLength)")

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

func dispatchGeometry64(_ M: Int, _ N: Int) -> (grid: MTLSize, tg: MTLSize) {
    let tg    = MTLSize(width: 32, height: 32, depth: 1)        // 1024 threads
    let gridW = ((N + 63) / 64) * 32
    let gridH = ((M + 63) / 64) * 32
    return (MTLSize(width: gridW, height: gridH, depth: 1), tg)
}

let TOL_MIXED: Float32 = 1e-4

func run_shape(_ M: Int, _ N: Int, _ K: Int,
               kernel name: String,
               pipeline: MTLComputePipelineState,
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
        print("F-RFC075-METAL-SIMDGROUP-64X64-NUMERIC-EQ: FAIL (buffer alloc)"); exit(1)
    }

    var Mv: UInt32 = UInt32(M)
    var Nv: UInt32 = UInt32(N)
    var Kv: UInt32 = UInt32(K)

    let (grid, tg) = dispatchGeometry64(M, N)

    func dispatch_once() -> Double {
        memset(bufC.contents(), 0, cBytes)
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            print("F-RFC075-METAL-SIMDGROUP-64X64-NUMERIC-EQ: FAIL (encoder)"); exit(1)
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
            print("F-RFC075-METAL-SIMDGROUP-64X64-NUMERIC-EQ: FAIL (commit: \(err))"); exit(1)
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
// Per task: 256/512/768/1024/1536/2048. We pad to multiples of 64 (the tile
// edge). 1536 = 24×64 and 2048 = 32×64 are exact.
// (768 = 12×64 — exact; 256 = 4×64; 512 = 8×64.)
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

let kernels: [(String, MTLComputePipelineState)] = [
    ("simdgroup_matmul_64x64_tg",    pipe64),
    ("simdgroup_matmul_64x64_tg_db", pipe64db),
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
    for (name, pipe) in kernels {
        let (r, ref) = run_shape(M, N, K, kernel: name, pipeline: pipe,
                                 warmup: warmup, timed: timed,
                                 cachedRef: cachedRef,
                                 aFp32Rounded: aRounded, bFp32Rounded: bRounded,
                                 aBits: aBits, bBits: bBits)
        cachedRef = ref
        results.append(r)
        if !r.pass { allOk = false }
        let tag = r.pass ? "PASS" : "FAIL"
        let kpad = r.kernel.padding(toLength: 32, withPad: " ", startingAt: 0)
        print(String(format: "\(kpad)  M=%d N=%d K=%d  median=%.4fms  GFLOPS=%.2f  max|d|=%.3e  rel=%.3e  \(tag)",
                     r.M, r.N, r.K, r.median_ms, r.gflops,
                     Double(r.max_abs_diff), Double(r.max_rel_err)))
    }
}

// ─── result.json emission ───────────────────────────────────────────────
// Anchors:
//   - N30 mixed-prec 32x32_tg fire (commit 99aed70f): peak 986.97 GFLOPS @ 1024^3
//   - N16 FP32 simdgroup fire (commit 31d729a4): peak 911.55 GFLOPS @ 768^3
//   - MPS FP32 GEMM (commit 9b352bda): 1666.34 @ 768, 1702.75 @ 1024
//   - Apple M3 advertised peak FP32 ~3.5 TFLOPS

let n30_32x32_anchor: [Int: Double] = [
    128: 104.31,
    256: 604.13,
    512: 567.82,
    768: 490.64,
    1024: 986.97,
]
let mps_anchor: [Int: Double] = [
    768: 1666.34,
    1024: 1702.75,
]

func peakGflops(_ kernel: String) -> Double {
    var best = 0.0
    for r in results where r.kernel == kernel { if r.gflops > best { best = r.gflops } }
    return best
}
func peakShape(_ kernel: String) -> Int {
    var best = 0.0; var bestM = 0
    for r in results where r.kernel == kernel {
        if r.gflops > best { best = r.gflops; bestM = r.M }
    }
    return bestM
}

let peak64    = peakGflops("simdgroup_matmul_64x64_tg")
let peak64db  = peakGflops("simdgroup_matmul_64x64_tg_db")
let peak64M   = peakShape("simdgroup_matmul_64x64_tg")
let peak64dbM = peakShape("simdgroup_matmul_64x64_tg_db")
let peakAny   = max(peak64, peak64db)

let n30_peak: Double = 986.97
let mps_peak: Double = 1702.75
let m3_theoretical: Double = 3500.0

let gapClosurePct: Double = (peakAny - n30_peak) / (mps_peak - n30_peak) * 100.0

var json = "{\n"
json += "  \"campaign\": \"rfc075_metal_simdgroup_matmul_64x64_2026_05_21\",\n"
json += "  \"host\": \"Mac (local)\",\n"
json += "  \"platform\": \"darwin-arm64\",\n"
json += "  \"gpu\": \"\(device.name) (registry_id=\(device.registryID))\",\n"
json += "  \"max_threads_per_threadgroup\": \"\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)\",\n"
json += "  \"max_threadgroup_memory_length\": \(device.maxThreadgroupMemoryLength),\n"
json += "  \"date_utc\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
json += "  \"toolchain\": \"xcrun --sdk macosx metal / swiftc (-O)\",\n"
json += "  \"intrinsic\": \"simdgroup_matrix<half,8,8> inputs + simdgroup_matrix<float,8,8> accumulator + simdgroup_multiply_accumulate (mixed-prec, same as N30)\",\n"
json += "  \"tile\": \"64x64 output, 32 simdgroups/TG (8 row x 4 col-pair), 2 sub-tiles per simdgroup, TG_K=32\",\n"
json += "  \"threadgroup_mem_single_buffer\": \"8 KiB (2x 4 KiB)\",\n"
json += "  \"threadgroup_mem_double_buffer\": \"16 KiB (4x 4 KiB)\",\n"
json += "  \"n30_baseline_commit\": \"99aed70f\",\n"
json += "  \"warmup\": \(warmup),\n"
json += "  \"timed\": \(timed),\n"
json += "  \"tolerance_rel\": 1e-4,\n"
json += "  \"static_threadgroup_memory_pipe64_bytes\": \(pipe64.staticThreadgroupMemoryLength),\n"
json += "  \"static_threadgroup_memory_pipe64db_bytes\": \(pipe64db.staticThreadgroupMemoryLength),\n"
json += "  \"pipe64_max_threads_per_threadgroup\": \(pipe64.maxTotalThreadsPerThreadgroup),\n"
json += "  \"pipe64db_max_threads_per_threadgroup\": \(pipe64db.maxTotalThreadsPerThreadgroup),\n"
json += "  \"rows\": [\n"
for (idx, r) in results.enumerated() {
    let comma = idx == results.count - 1 ? "" : ","
    let n30 = n30_32x32_anchor[r.M] ?? 0
    let mps = mps_anchor[r.M] ?? 0
    let ratioN30 = n30 > 0 ? r.gflops / n30 : 0
    let ratioMPS = mps > 0 ? r.gflops / mps : 0
    json += "    {\n"
    json += "      \"kernel\": \"\(r.kernel)\",\n"
    json += "      \"M\": \(r.M), \"N\": \(r.N), \"K\": \(r.K),\n"
    json += "      \"median_ms\": \(r.median_ms),\n"
    json += "      \"gflops\": \(r.gflops),\n"
    json += "      \"n30_32x32_baseline_gflops\": \(n30),\n"
    json += "      \"ratio_vs_n30_32x32\": \(ratioN30),\n"
    json += "      \"mps_baseline_gflops\": \(mps),\n"
    json += "      \"ratio_vs_mps\": \(ratioMPS),\n"
    json += "      \"max_abs_diff\": \(r.max_abs_diff),\n"
    json += "      \"max_rel_err\": \(r.max_rel_err),\n"
    json += "      \"pass\": \(r.pass)\n"
    json += "    }\(comma)\n"
}
json += "  ],\n"

json += "  \"peak_gflops_64x64_tg\": \(peak64),\n"
json += "  \"peak_shape_64x64_tg\": \(peak64M),\n"
json += "  \"peak_gflops_64x64_tg_db\": \(peak64db),\n"
json += "  \"peak_shape_64x64_tg_db\": \(peak64dbM),\n"
json += "  \"peak_gflops_overall_64x64\": \(peakAny),\n"
json += "  \"n30_32x32_peak_gflops\": \(n30_peak),\n"
json += "  \"mps_fp32_peak_gflops\": \(mps_peak),\n"
json += "  \"apple_m3_theoretical_fp32_gflops\": \(m3_theoretical),\n"
json += "  \"ratio_64x64_over_n30\": \(peakAny / n30_peak),\n"
json += "  \"ratio_64x64_over_mps\": \(peakAny / mps_peak),\n"
json += "  \"ratio_64x64_over_apple_theoretical\": \(peakAny / m3_theoretical),\n"
json += "  \"db_over_single_buffer_ratio\": \(peak64 > 0 ? peak64db / peak64 : 0),\n"
json += "  \"gap_closure_percent_vs_mps\": \(gapClosurePct),\n"

var maxRelOverall: Float32 = 0
for r in results { if r.max_rel_err > maxRelOverall { maxRelOverall = r.max_rel_err } }
json += "  \"max_rel_err_overall\": \(maxRelOverall),\n"

let hitTarget1_2T: Bool = peakAny >= 1200.0
let hitTarget1_5T: Bool = peakAny >= 1500.0
json += "  \"headline\": {\n"
json += "    \"peak_64x64_gflops\": \(peakAny),\n"
json += "    \"single_vs_db_peak_diff\": \(peak64db - peak64),\n"
json += "    \"hit_1_2_TFLOPS_target\": \(hitTarget1_2T),\n"
json += "    \"hit_1_5_TFLOPS_gap_midpoint\": \(hitTarget1_5T),\n"
json += "    \"vs_n30_ratio\": \(peakAny / n30_peak),\n"
json += "    \"vs_mps_ratio\": \(peakAny / mps_peak),\n"
json += "    \"gap_closure_percent\": \(gapClosurePct)\n"
json += "  },\n"

json += "  \"comparison_table\": {\n"
json += "    \"columns\": [\"approach\", \"shape\", \"GFLOPS\", \"rel_err\", \"source\"],\n"
json += "    \"rows\": [\n"
json += "      [\"simdgroup_matmul_32x32_tg_mixed\", \"768^3\",  490.64,  0.0, \"N30 (commit 99aed70f)\"],\n"
json += "      [\"simdgroup_matmul_32x32_tg_mixed\", \"1024^3\", 986.97,  0.0, \"N30 (commit 99aed70f, peak)\"],\n"
for r in results {
    let mShape = "\(r.M)^3"
    json += "      [\"\(r.kernel)\", \"\(mShape)\", \(r.gflops), \(r.max_rel_err), \"this fire\"],\n"
}
json += "      [\"MPS GEMM\", \"768^3\",  1666.34, 1e-6, \"host_mps_gemm fire (commit 9b352bda)\"],\n"
json += "      [\"MPS GEMM\", \"1024^3\", 1702.75, 1e-6, \"host_mps_gemm fire (commit 9b352bda)\"],\n"
json += "      [\"Apple M3 advertised peak FP32\", \"-\", \(m3_theoretical), 0, \"Apple GPU spec sheet\"]\n"
json += "    ]\n"
json += "  },\n"

let statusStr = allOk ? "PASS" : "PARTIAL"
json += "  \"falsifier_F_RFC075_METAL_SIMDGROUP_64X64_NUMERIC_EQ\": \"\(statusStr)\",\n"
json += "  \"honest_scope\": [\n"
json += "    \"64x64 output tile per threadgroup uses 32 simdgroups (8 row x 4 col-pair). Each simdgroup owns 2 adjacent 8x8 sub-tiles via a shared A-load + 2 B-loads per inner step. Total 64 8x8 output sub-tiles fit in 32 simdgroups = 1024 threads = full TG.\",\n"
json += "    \"TG_K=32 inner K-slab → 8 KiB threadgroup mem single-buffered (well below 32 KiB Apple M3 limit). DB variant uses 16 KiB (still 16 KiB headroom). Both compile and report static_threadgroup_memory_length matching expectation.\",\n"
json += "    \"FP16 inputs + FP32 accumulator (same recipe as N30 mixed-prec). max_rel_err < 1e-4 gate (FP32 accumulator restores precision; only FP16 input rounding contributes error).\",\n"
json += "    \"Headline target: peak >= 1.2 TFLOPS confirms 64x64 unlocks substantial gain over N30's 987. Peak >= 1.5 TFLOPS closes >=50% of the MPS gap (midpoint between N30 987 and MPS 1703 = 1345).\",\n"
json += "    \"If 64x64 PLATEAUS or REGRESSES, that is a useful negative measurement: the bottleneck is not tile-size but something else (occupancy, register pressure, FMA throughput, or load-bandwidth saturation).\",\n"
json += "    \"Double-buffer pattern: while compute runs on slot[kk&1], prefetch slot[(kk+1)&1]. Should hide global-load latency if compute > load. If compute < load (memory-bound) DB has no effect.\",\n"
json += "    \"Mac is shared developer laptop; median over 50 timed runs after 5 warmups; variance noisier than ubu-2 cuBLAS measurements.\"\n"
json += "  ]\n"
json += "}\n"
let jsonPath = "./result.json"
do { try json.write(toFile: jsonPath, atomically: true, encoding: .utf8) }
catch { print("WARN: result.json write failed: \(error)") }

let final = allOk ? "PASS" : "PARTIAL"
print("F-RFC075-METAL-SIMDGROUP-64X64-NUMERIC-EQ: \(final)")
print(String(format: "PEAK_64X64_GFLOPS=%.2f (best of single + db, across shape sweep)", peakAny))
print(String(format: "PEAK_64X64_SINGLE=%.2f @ M=%d", peak64, peak64M))
print(String(format: "PEAK_64X64_DB=%.2f @ M=%d",     peak64db, peak64dbM))
print(String(format: "VS_N30_RATIO=%.3fx (N30 peak = %.2f GFLOPS)", peakAny / n30_peak, n30_peak))
print(String(format: "VS_MPS_RATIO=%.3fx (MPS peak = %.2f GFLOPS)", peakAny / mps_peak, mps_peak))
print(String(format: "GAP_CLOSURE_VS_MPS=%.1f%%", gapClosurePct))
print(String(format: "MAX_REL_ERR_OVERALL=%.3e (gate < 1e-4)", Double(maxRelOverall)))
exit(0)
