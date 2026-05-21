// host_simdgroup_matmul_64x64_async.swift — RFC 075 Apple M3 async-copy probe.
//
// Drives simdgroup_matmul_64x64_async.metallib (sw / swpipe / split variants)
// across N37's shape sweep (256/512/768/1024/1536/2048). Compares to:
//   - N37 DB peak 1518.73 GFLOPS @ 1024 (commit 9d31fd32)
//   - MPS GEMM peak 1702.75 GFLOPS @ 1024 (commit 9b352bda)
//   - Apple M3 advertised peak FP32 ~3.5 TFLOPS
//
// Same protocol as N37:
//   - LCG-deterministic FP32 inputs → rounded to FP16
//   - CPU FP32 ikj reference
//   - 5 warmup + 50 timed dispatches, median ms
//   - rel_err < 1e-4 gate (FP32 accumulator)

import Foundation
import Metal

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

guard let device = MTLCreateSystemDefaultDevice() else {
    print("F-RFC075-METAL-ASYNC-COPY: FAIL (no Metal device)"); exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
let mtpt = device.maxThreadsPerThreadgroup
print("max_threads_per_threadgroup=\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)")
print("max_threadgroup_memory_length=\(device.maxThreadgroupMemoryLength)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-ASYNC-COPY: FAIL (no queue)"); exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./simdgroup_matmul_64x64_async.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-ASYNC-COPY: FAIL (makeLibrary: \(error))"); exit(1)
}

func makePipeline(_ name: String) -> MTLComputePipelineState {
    guard let fn = library.makeFunction(name: name) else {
        print("F-RFC075-METAL-ASYNC-COPY: FAIL (no \(name) fn)"); exit(1)
    }
    do { return try device.makeComputePipelineState(function: fn) }
    catch {
        print("F-RFC075-METAL-ASYNC-COPY: FAIL (pipeline \(name): \(error))"); exit(1)
    }
}

let pipeSw     = makePipeline("simdgroup_matmul_64x64_async_sw")
let pipeSwpipe = makePipeline("simdgroup_matmul_64x64_async_swpipe")
let pipeSplit  = makePipeline("simdgroup_matmul_64x64_async_split")

print("pipeSw      tew=\(pipeSw.threadExecutionWidth)     max=\(pipeSw.maxTotalThreadsPerThreadgroup)     stat_tg_mem=\(pipeSw.staticThreadgroupMemoryLength)")
print("pipeSwpipe  tew=\(pipeSwpipe.threadExecutionWidth) max=\(pipeSwpipe.maxTotalThreadsPerThreadgroup) stat_tg_mem=\(pipeSwpipe.staticThreadgroupMemoryLength)")
print("pipeSplit   tew=\(pipeSplit.threadExecutionWidth)  max=\(pipeSplit.maxTotalThreadsPerThreadgroup)  stat_tg_mem=\(pipeSplit.staticThreadgroupMemoryLength)")

struct ResultRow {
    let M: Int; let N: Int; let K: Int
    let kernel: String
    let median_ms: Double
    let gflops: Double
    let max_abs_diff: Float32
    let max_rel_err: Float32
    let pass: Bool
}

func dispatchGeometry64(_ M: Int, _ N: Int) -> (grid: MTLSize, tg: MTLSize) {
    let tg    = MTLSize(width: 32, height: 32, depth: 1)
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
               aBits: [UInt16], bBits: [UInt16]) -> (ResultRow, [Float32]) {

    let ref: [Float32]
    if let cached = cachedRef { ref = cached }
    else { ref = cpu_matmul_ref_fp32(aFp32Rounded, bFp32Rounded, M, N, K) }

    let aBytes = M * K * MemoryLayout<UInt16>.stride
    let bBytes = K * N * MemoryLayout<UInt16>.stride
    let cBytes = M * N * MemoryLayout<Float32>.stride

    guard let bufA = device.makeBuffer(bytes: aBits, length: aBytes, options: .storageModeShared),
          let bufB = device.makeBuffer(bytes: bBits, length: bBytes, options: .storageModeShared),
          let bufC = device.makeBuffer(length: cBytes, options: .storageModeShared) else {
        print("F-RFC075-METAL-ASYNC-COPY: FAIL (buffer alloc)"); exit(1)
    }

    var Mv: UInt32 = UInt32(M)
    var Nv: UInt32 = UInt32(N)
    var Kv: UInt32 = UInt32(K)

    let (grid, tg) = dispatchGeometry64(M, N)

    func dispatch_once() -> Double {
        memset(bufC.contents(), 0, cBytes)
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            print("F-RFC075-METAL-ASYNC-COPY: FAIL (encoder)"); exit(1)
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
            print("F-RFC075-METAL-ASYNC-COPY: FAIL (commit: \(err))"); exit(1)
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
    let row = ResultRow(M: M, N: N, K: K, kernel: name, median_ms: median,
                        gflops: gflops, max_abs_diff: max_abs_diff,
                        max_rel_err: rel_err, pass: ok)
    return (row, ref)
}

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
    ("simdgroup_matmul_64x64_async_sw",     pipeSw),
    ("simdgroup_matmul_64x64_async_swpipe", pipeSwpipe),
    ("simdgroup_matmul_64x64_async_split",  pipeSplit),
]

var results: [ResultRow] = []
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
        let kpad = r.kernel.padding(toLength: 40, withPad: " ", startingAt: 0)
        print(String(format: "\(kpad)  M=%d N=%d K=%d  median=%.4fms  GFLOPS=%.2f  max|d|=%.3e  rel=%.3e  \(tag)",
                     r.M, r.N, r.K, r.median_ms, r.gflops,
                     Double(r.max_abs_diff), Double(r.max_rel_err)))
    }
}

let n37_db_anchor: [Int: Double] = [
    256: 408.37,
    512: 1369.86,
    768: 1041.34,
    1024: 1518.73,
    1536: 1247.22,
    2048: 1123.05,
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

let peakSw     = peakGflops("simdgroup_matmul_64x64_async_sw")
let peakSwpipe = peakGflops("simdgroup_matmul_64x64_async_swpipe")
let peakSplit  = peakGflops("simdgroup_matmul_64x64_async_split")
let peakSwM     = peakShape("simdgroup_matmul_64x64_async_sw")
let peakSwpipeM = peakShape("simdgroup_matmul_64x64_async_swpipe")
let peakSplitM  = peakShape("simdgroup_matmul_64x64_async_split")
let peakAny = max(peakSw, max(peakSwpipe, peakSplit))

let n37_peak: Double = 1518.73
let mps_peak: Double = 1702.75
let m3_theoretical: Double = 3500.0

let gapClosurePct: Double = ((peakAny - n37_peak) / (mps_peak - n37_peak)) * 100.0

var json = "{\n"
json += "  \"campaign\": \"rfc075_metal_async_copy_2026_05_21\",\n"
json += "  \"host\": \"Mac (local)\",\n"
json += "  \"platform\": \"darwin-arm64\",\n"
json += "  \"gpu\": \"\(device.name) (registry_id=\(device.registryID))\",\n"
json += "  \"max_threads_per_threadgroup\": \"\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)\",\n"
json += "  \"max_threadgroup_memory_length\": \(device.maxThreadgroupMemoryLength),\n"
json += "  \"date_utc\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
json += "  \"toolchain\": \"Apple metal 32023.883 / xcrun --sdk macosx (metalfe air64-apple-darwin25.5.0)\",\n"
json += "  \"goal\": \"Probe Apple M3 async-copy / cp.async-equivalent path to close N37 DB peak 1518 GFLOPS -> MPS 1703 (11% gap).\",\n"
json += "  \"api_gap_finding\": {\n"
json += "    \"status\": \"BLOCKED\",\n"
json += "    \"missing_symbols\": [\n"
json += "      \"simdgroup_event\",\n"
json += "      \"simdgroup_async_copy_2d\",\n"
json += "      \"async_work_group_copy\",\n"
json += "      \"wait_group_events\",\n"
json += "      \"event_t\"\n"
json += "    ],\n"
json += "    \"verification\": \"probe_async_api.metal (simdgroup_event / simdgroup_async_copy_2d) and probe2_async_api.metal (event_t / async_work_group_copy / wait_group_events) BOTH fail to compile against -std=metal3.0, -std=metal3.1, -std=metal3.2 on this host. Header grep over metal_stdlib tree finds zero async-copy symbols.\",\n"
json += "    \"interpretation\": \"Apple's MSL spec documents simdgroup_event / simdgroup_async_copy_2d in later MSL releases, but the installed macOS 26.4 Metal toolchain (Apple metal 32023.883) does NOT expose them. Either platform-gated (iOS/visionOS only) or hidden behind a build flag not surfaced via xcrun.\",\n"
json += "    \"workaround_attempted\": \"Software emulations: (sw) inline DB baseline, (swpipe) hoist all 12 simdgroup_loads above 8 FMAs, (split) issue 1/4 of next-slot device-tg copy in each inner MMA substep\"\n"
json += "  },\n"
json += "  \"warmup\": \(warmup),\n"
json += "  \"timed\": \(timed),\n"
json += "  \"tolerance_rel\": 1e-4,\n"
json += "  \"static_tg_mem_sw_bytes\": \(pipeSw.staticThreadgroupMemoryLength),\n"
json += "  \"static_tg_mem_swpipe_bytes\": \(pipeSwpipe.staticThreadgroupMemoryLength),\n"
json += "  \"static_tg_mem_split_bytes\": \(pipeSplit.staticThreadgroupMemoryLength),\n"
json += "  \"rows\": [\n"
for (idx, r) in results.enumerated() {
    let comma = idx == results.count - 1 ? "" : ","
    let n37 = n37_db_anchor[r.M] ?? 0
    let mps = mps_anchor[r.M] ?? 0
    let ratioN37 = n37 > 0 ? r.gflops / n37 : 0
    let ratioMPS = mps > 0 ? r.gflops / mps : 0
    json += "    {\n"
    json += "      \"kernel\": \"\(r.kernel)\",\n"
    json += "      \"M\": \(r.M), \"N\": \(r.N), \"K\": \(r.K),\n"
    json += "      \"median_ms\": \(r.median_ms),\n"
    json += "      \"gflops\": \(r.gflops),\n"
    json += "      \"n37_db_baseline_gflops\": \(n37),\n"
    json += "      \"ratio_vs_n37_db\": \(ratioN37),\n"
    json += "      \"mps_baseline_gflops\": \(mps),\n"
    json += "      \"ratio_vs_mps\": \(ratioMPS),\n"
    json += "      \"max_abs_diff\": \(r.max_abs_diff),\n"
    json += "      \"max_rel_err\": \(r.max_rel_err),\n"
    json += "      \"pass\": \(r.pass)\n"
    json += "    }\(comma)\n"
}
json += "  ],\n"
json += "  \"peak_gflops_sw\": \(peakSw),\n"
json += "  \"peak_shape_sw\": \(peakSwM),\n"
json += "  \"peak_gflops_swpipe\": \(peakSwpipe),\n"
json += "  \"peak_shape_swpipe\": \(peakSwpipeM),\n"
json += "  \"peak_gflops_split\": \(peakSplit),\n"
json += "  \"peak_shape_split\": \(peakSplitM),\n"
json += "  \"peak_gflops_overall_async_probe\": \(peakAny),\n"
json += "  \"n37_db_peak_gflops\": \(n37_peak),\n"
json += "  \"mps_fp32_peak_gflops\": \(mps_peak),\n"
json += "  \"apple_m3_theoretical_fp32_gflops\": \(m3_theoretical),\n"
json += "  \"ratio_async_over_n37_db\": \(peakAny / n37_peak),\n"
json += "  \"ratio_async_over_mps\": \(peakAny / mps_peak),\n"
json += "  \"ratio_async_over_apple_theoretical\": \(peakAny / m3_theoretical),\n"
json += "  \"gap_closure_percent_vs_mps\": \(gapClosurePct),\n"

var maxRelOverall: Float32 = 0
for r in results { if r.max_rel_err > maxRelOverall { maxRelOverall = r.max_rel_err } }
json += "  \"max_rel_err_overall\": \(maxRelOverall),\n"

let pushedPast1518 = peakAny > 1518.73
let pushedPast1700 = peakAny > 1700.0
json += "  \"headline\": {\n"
json += "    \"async_copy_api_available\": false,\n"
json += "    \"peak_async_probe_gflops\": \(peakAny),\n"
json += "    \"pushed_past_n37_db_1518\": \(pushedPast1518),\n"
json += "    \"reached_mps_level_1700\": \(pushedPast1700),\n"
json += "    \"vs_n37_db_ratio\": \(peakAny / n37_peak),\n"
json += "    \"vs_mps_ratio\": \(peakAny / mps_peak),\n"
json += "    \"gap_closure_percent\": \(gapClosurePct),\n"
json += "    \"sw_emulation_best_kernel\": \"\(peakSw >= peakSwpipe && peakSw >= peakSplit ? "async_sw" : (peakSwpipe >= peakSplit ? "async_swpipe" : "async_split"))\"\n"
json += "  },\n"

json += "  \"comparison_table\": {\n"
json += "    \"columns\": [\"approach\", \"shape\", \"GFLOPS\", \"rel_err\", \"source\"],\n"
json += "    \"rows\": [\n"
json += "      [\"simdgroup_matmul_64x64_tg_db (N37)\", \"1024^3\", 1518.73, 0.0, \"N37 (commit 9d31fd32)\"],\n"
for r in results {
    let mShape = "\(r.M)^3"
    json += "      [\"\(r.kernel)\", \"\(mShape)\", \(r.gflops), \(r.max_rel_err), \"this fire\"],\n"
}
json += "      [\"MPS GEMM\", \"1024^3\", 1702.75, 1e-6, \"host_mps_gemm fire (commit 9b352bda)\"],\n"
json += "      [\"Apple M3 advertised peak FP32\", \"-\", \(m3_theoretical), 0, \"Apple GPU spec sheet\"]\n"
json += "    ]\n"
json += "  },\n"

let statusStr = allOk ? "PASS" : "PARTIAL"
json += "  \"falsifier_F_RFC075_METAL_ASYNC_COPY\": \"\(statusStr)\",\n"
json += "  \"honest_scope\": [\n"
json += "    \"Apple M3 / macOS 26.4 / Apple metal 32023.883: NO async-copy API available. simdgroup_event / simdgroup_async_copy_2d / async_work_group_copy all undeclared. Verified via probe files + header grep.\",\n"
json += "    \"Software emulations (sw / swpipe / split) cannot achieve real load-vs-compute overlap without a DMA engine; they only let the GPU instruction scheduler reorder LDS reads with FMAs within a simdgroup.\",\n"
json += "    \"swpipe variant hoists 12 simdgroup_loads above 8 FMAs in the inner K-substep. This is the closest available approximation to async-copy semantics on this Mac toolchain.\",\n"
json += "    \"split variant fragments the next-slot device-tg copy into 4 chunks (1/4 per inner MMA substep) to give the HW scheduler more interleaving opportunities.\",\n"
json += "    \"If swpipe ~ swsync (~1500 GFLOPS @ 1024): instruction-scheduler already does this; explicit hoisting is not the bottleneck.\",\n"
json += "    \"If split < swsync: fine-grained interleave costs more (register pressure + extra branch overhead) than the prefetch gains; HW already pipelines monolithic loads well.\",\n"
json += "    \"To genuinely close the 11% MPS gap requires either (1) Apple expose simdgroup_async_copy_2d in macOS toolchain, (2) move to iOS/visionOS where it IS exposed (Apple M3-class chips), or (3) larger output tile + register-resident accumulators (separate cycle).\",\n"
json += "    \"rel_err < 1e-4 gate (FP32 accumulator restores precision); max_rel_err_overall reported above.\",\n"
json += "    \"Mac is shared developer laptop; median over 50 timed runs after 5 warmups; variance noisier than ubu-2 cuBLAS measurements.\"\n"
json += "  ]\n"
json += "}\n"
let jsonPath = "./result.json"
do { try json.write(toFile: jsonPath, atomically: true, encoding: .utf8) }
catch { print("WARN: result.json write failed: \(error)") }

let final = allOk ? "PASS" : "PARTIAL"
print("F-RFC075-METAL-ASYNC-COPY: \(final)")
print(String(format: "PEAK_ASYNC_PROBE_GFLOPS=%.2f (best of sw / swpipe / split)", peakAny))
print(String(format: "PEAK_SW=%.2f @ M=%d",     peakSw, peakSwM))
print(String(format: "PEAK_SWPIPE=%.2f @ M=%d", peakSwpipe, peakSwpipeM))
print(String(format: "PEAK_SPLIT=%.2f @ M=%d",  peakSplit, peakSplitM))
print(String(format: "VS_N37_DB_RATIO=%.3fx (N37 DB peak = %.2f GFLOPS)", peakAny / n37_peak, n37_peak))
print(String(format: "VS_MPS_RATIO=%.3fx (MPS peak = %.2f GFLOPS)", peakAny / mps_peak, mps_peak))
print(String(format: "GAP_CLOSURE_VS_MPS=%.1f%%", gapClosurePct))
print(String(format: "MAX_REL_ERR_OVERALL=%.3e (gate < 1e-4)", Double(maxRelOverall)))
print("ASYNC_COPY_API_AVAILABLE=false (see api_gap_finding in result.json)")
exit(0)
