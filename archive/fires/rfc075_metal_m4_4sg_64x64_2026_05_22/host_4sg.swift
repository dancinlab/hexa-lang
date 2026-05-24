// host_4sg.swift — N138 Apple M4 4-simdgroup 64×64 MMA fire driver.
//
// Drives simdgroup_matmul_4sg_64x64.metallib (single-buffer + double-buffered
// variants) across a shape sweep mirroring N107's NVPTX axis-1 isolation.
//
// Anchors:
//   - N16 M3 simdgroup_matrix peak 911.55 GFLOPS @ 768³ (FP32)
//   - N30 M3 mixed-prec 32×32_tg peak 986.97 GFLOPS @ 1024³
//   - N37 M3 64×64 mixed-prec peak 1519 GFLOPS @ 1024³ (per task brief)
//   - N133 M4 64×64_tg_db peak 1858.35 GFLOPS @ 1024³  ← primary comparator
//   - N107 RTX 5070 4-warp 64×64 NVPTX peak 51.65 TFLOPS @ M=1536, ratio 0.777
//
// Same protocol as N133 (mixed-prec):
//   - LCG-deterministic FP32 inputs → rounded to FP16.
//   - CPU FP32 ikj reference (rounded apples-to-apples).
//   - 5 warmup + 50 timed dispatches, median ms.
//   - rel_err < 1e-4 gate.
//
// Build + run:
//   xcrun --sdk macosx swiftc -O host_4sg.swift -o host_4sg
//   ./host_4sg ./simdgroup_matmul_4sg_64x64.metallib
//
// Dispatch geometry:
//   threads_per_threadgroup = (4, 32, 1) = 128 threads = 4 simdgroups
//   threads_per_grid        = ( ((N+63)/64) * 4, ((M+63)/64) * 32, 1 )

import Foundation
import Metal

// ─── deterministic LCG (Numerical Recipes 32-bit) — same as N133 ─────
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
    print("F-RFC075-METAL-M4-4SIMDGROUP: FAIL (no Metal device)")
    exit(1)
}
print("device_name=\(device.name)")
print("registry_id=\(device.registryID)")
let mtpt = device.maxThreadsPerThreadgroup
print("max_threads_per_threadgroup=\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)")
print("max_threadgroup_memory_length=\(device.maxThreadgroupMemoryLength)")

guard let queue = device.makeCommandQueue() else {
    print("F-RFC075-METAL-M4-4SIMDGROUP: FAIL (no queue)")
    exit(1)
}

let metallibPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1] : "./simdgroup_matmul_4sg_64x64.metallib"
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: URL(fileURLWithPath: metallibPath))
} catch {
    print("F-RFC075-METAL-M4-4SIMDGROUP: FAIL (makeLibrary: \(error))")
    exit(1)
}

func makePipeline(_ name: String) -> MTLComputePipelineState {
    guard let fn = library.makeFunction(name: name) else {
        print("F-RFC075-METAL-M4-4SIMDGROUP: FAIL (no \(name) fn)")
        exit(1)
    }
    do { return try device.makeComputePipelineState(function: fn) }
    catch {
        print("F-RFC075-METAL-M4-4SIMDGROUP: FAIL (pipeline \(name): \(error))")
        exit(1)
    }
}

let pipeSb = makePipeline("simdgroup_matmul_4sg_64x64")
let pipeDb = makePipeline("simdgroup_matmul_4sg_64x64_db")

print("pipeSb  tew=\(pipeSb.threadExecutionWidth)  max=\(pipeSb.maxTotalThreadsPerThreadgroup)  stat_threadgroup_memory_length=\(pipeSb.staticThreadgroupMemoryLength)")
print("pipeDb  tew=\(pipeDb.threadExecutionWidth)  max=\(pipeDb.maxTotalThreadsPerThreadgroup)  stat_threadgroup_memory_length=\(pipeDb.staticThreadgroupMemoryLength)")

struct Result {
    let M: Int; let N: Int; let K: Int
    let kernel: String
    let median_ms: Double
    let gflops: Double
    let max_abs_diff: Float32
    let max_rel_err: Float32
    let pass: Bool
}

// 4 simdgroups → tg width 4 (in simdgroup index axis), 32 (lane axis), 1.
func dispatchGeometry4sg(_ M: Int, _ N: Int) -> (grid: MTLSize, tg: MTLSize) {
    let tg = MTLSize(width: 4, height: 32, depth: 1)         // 128 threads
    let gridW = ((N + 63) / 64) * 4
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
        print("F-RFC075-METAL-M4-4SIMDGROUP: FAIL (buffer alloc)"); exit(1)
    }

    var Mv: UInt32 = UInt32(M)
    var Nv: UInt32 = UInt32(N)
    var Kv: UInt32 = UInt32(K)

    let (grid, tg) = dispatchGeometry4sg(M, N)

    func dispatch_once() -> Double {
        memset(bufC.contents(), 0, cBytes)
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            print("F-RFC075-METAL-M4-4SIMDGROUP: FAIL (encoder)"); exit(1)
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
            print("F-RFC075-METAL-M4-4SIMDGROUP: FAIL (commit: \(err))"); exit(1)
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

// Shape sweep mirrors N107 sweep (256/512/768/1024/1536). N133 added 2048,
// but mini is 16 GB — 2048³ FP16 buffers fit fine; include for symmetry.
let shapes: [(Int, Int, Int)] = [
    (256, 256, 256),
    (512, 512, 512),
    (768, 768, 768),
    (1024, 1024, 1024),
    (1536, 1536, 1536),
]
let warmup = 5
let timed  = 50

let kernels: [(String, MTLComputePipelineState)] = [
    ("simdgroup_matmul_4sg_64x64",    pipeSb),
    ("simdgroup_matmul_4sg_64x64_db", pipeDb),
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
        let kpad = r.kernel.padding(toLength: 36, withPad: " ", startingAt: 0)
        print(String(format: "\(kpad)  M=%d N=%d K=%d  median=%.4fms  GFLOPS=%.2f  max|d|=%.3e  rel=%.3e  \(tag)",
                     r.M, r.N, r.K, r.median_ms, r.gflops,
                     Double(r.max_abs_diff), Double(r.max_rel_err)))
    }
}

// ─── anchors ────────────────────────────────────────────────────────────
let n133_m4_db_anchor: [Int: Double] = [
    256: 695.43,
    512: 884.71,
    768: 1839.07,
    1024: 1858.35,
    1536: 1852.58,
]
let n133_m4_sb_anchor: [Int: Double] = [
    256: 683.04,
    512: 822.48,
    768: 1724.15,
    1024: 1722.87,
    1536: 1674.62,
]
let n37_m3_64x64_anchor: [Int: Double] = [
    1024: 1519.0,
]
let n16_m3_simdgroup_fp32_anchor: [Int: Double] = [
    768: 911.55,
]
// N107 NVPTX 4-warp RTX 5070 (TFLOPS → GFLOPS).
let n107_nvptx_4warp_gflops: [Int: Double] = [
    256: 5282.5,
    512: 22610.8,
    768: 39875.4,
    1024: 40017.2,
    1536: 51651.6,
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
func gflopsAt(_ kernel: String, _ M: Int) -> Double {
    for r in results where r.kernel == kernel && r.M == M { return r.gflops }
    return 0
}

let peakSb = peakGflops("simdgroup_matmul_4sg_64x64")
let peakDb = peakGflops("simdgroup_matmul_4sg_64x64_db")
let peakSbM = peakShape("simdgroup_matmul_4sg_64x64")
let peakDbM = peakShape("simdgroup_matmul_4sg_64x64_db")
let peakAny = max(peakSb, peakDb)

let n133_m4_peak_db: Double = 1858.35
let n37_m3_peak: Double = 1519.0
let n107_nvptx_peak: Double = 51651.6

var json = "{\n"
json += "  \"campaign\": \"rfc075_metal_m4_4sg_64x64_2026_05_22\",\n"
json += "  \"host\": \"mini (Apple M4)\",\n"
json += "  \"platform\": \"darwin-arm64\",\n"
json += "  \"gpu\": \"\(device.name) (registry_id=\(device.registryID))\",\n"
json += "  \"max_threads_per_threadgroup\": \"\(mtpt.width)x\(mtpt.height)x\(mtpt.depth)\",\n"
json += "  \"max_threadgroup_memory_length\": \(device.maxThreadgroupMemoryLength),\n"
json += "  \"date_utc\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
json += "  \"toolchain\": \"xcrun --sdk macosx metal / swiftc (-O)\",\n"
json += "  \"intrinsic\": \"simdgroup_matrix<half,8,8> inputs + simdgroup_matrix<float,8,8> acc + simdgroup_multiply_accumulate (mixed-prec, same as N133)\",\n"
json += "  \"tile\": \"64x64 output, 4 simdgroups/TG in 2x2 grid (vs N133's 32 sg/TG 8x4 grid), 16 sub-tiles per simdgroup, TG_K=16\",\n"
json += "  \"threads_per_threadgroup\": 128,\n"
json += "  \"threadgroup_mem_single_buffer\": \"4 KiB (2x 2 KiB)\",\n"
json += "  \"threadgroup_mem_double_buffer\": \"8 KiB (4x 2 KiB)\",\n"
json += "  \"n107_pattern_ported\": \"4 warps -> 4 simdgroups, 64x64 tile, K=16/step\",\n"
json += "  \"warmup\": \(warmup),\n"
json += "  \"timed\": \(timed),\n"
json += "  \"tolerance_rel\": 1e-4,\n"
json += "  \"static_threadgroup_memory_pipeSb_bytes\": \(pipeSb.staticThreadgroupMemoryLength),\n"
json += "  \"static_threadgroup_memory_pipeDb_bytes\": \(pipeDb.staticThreadgroupMemoryLength),\n"
json += "  \"pipeSb_max_threads_per_threadgroup\": \(pipeSb.maxTotalThreadsPerThreadgroup),\n"
json += "  \"pipeDb_max_threads_per_threadgroup\": \(pipeDb.maxTotalThreadsPerThreadgroup),\n"
json += "  \"rows\": [\n"
for (idx, r) in results.enumerated() {
    let comma = idx == results.count - 1 ? "" : ","
    let n133sb = n133_m4_sb_anchor[r.M] ?? 0
    let n133db = n133_m4_db_anchor[r.M] ?? 0
    let n133cmp = r.kernel.hasSuffix("_db") ? n133db : n133sb
    let ratioN133 = n133cmp > 0 ? r.gflops / n133cmp : 0
    let n37 = n37_m3_64x64_anchor[r.M] ?? 0
    let ratioN37 = n37 > 0 ? r.gflops / n37 : 0
    json += "    {\n"
    json += "      \"kernel\": \"\(r.kernel)\",\n"
    json += "      \"M\": \(r.M), \"N\": \(r.N), \"K\": \(r.K),\n"
    json += "      \"median_ms\": \(r.median_ms),\n"
    json += "      \"gflops\": \(r.gflops),\n"
    json += "      \"n133_m4_64x64_same_variant_gflops\": \(n133cmp),\n"
    json += "      \"ratio_vs_n133_m4_same_variant\": \(ratioN133),\n"
    json += "      \"n37_m3_64x64_gflops\": \(n37),\n"
    json += "      \"ratio_vs_n37_m3\": \(ratioN37),\n"
    json += "      \"max_abs_diff\": \(r.max_abs_diff),\n"
    json += "      \"max_rel_err\": \(r.max_rel_err),\n"
    json += "      \"pass\": \(r.pass)\n"
    json += "    }\(comma)\n"
}
json += "  ],\n"

json += "  \"peak_gflops_sb\": \(peakSb),\n"
json += "  \"peak_shape_sb\": \(peakSbM),\n"
json += "  \"peak_gflops_db\": \(peakDb),\n"
json += "  \"peak_shape_db\": \(peakDbM),\n"
json += "  \"peak_gflops_overall\": \(peakAny),\n"
json += "  \"n133_m4_64x64_db_peak_gflops\": \(n133_m4_peak_db),\n"
json += "  \"n37_m3_64x64_peak_gflops\": \(n37_m3_peak),\n"
json += "  \"n107_nvptx_4warp_peak_gflops\": \(n107_nvptx_peak),\n"
json += "  \"ratio_vs_n133_m4_peak\": \(peakAny / n133_m4_peak_db),\n"
json += "  \"ratio_vs_n37_m3_peak\": \(peakAny / n37_m3_peak),\n"
json += "  \"ratio_vs_n107_nvptx_peak\": \(peakAny / n107_nvptx_peak),\n"

let g_4sg_db_1536 = gflopsAt("simdgroup_matmul_4sg_64x64_db", 1536)
let g_4sg_sb_1536 = gflopsAt("simdgroup_matmul_4sg_64x64", 1536)
let best_1536 = max(g_4sg_db_1536, g_4sg_sb_1536)
let n133_1536_db = n133_m4_db_anchor[1536] ?? 0
let ratio_1536_vs_n133 = n133_1536_db > 0 ? best_1536 / n133_1536_db : 0
json += "  \"peak_at_1536_gflops\": \(best_1536),\n"
json += "  \"ratio_1536_vs_n133_m4_db\": \(ratio_1536_vs_n133),\n"

var maxRelOverall: Float32 = 0
for r in results { if r.max_rel_err > maxRelOverall { maxRelOverall = r.max_rel_err } }
json += "  \"max_rel_err_overall\": \(maxRelOverall),\n"

// Verdict logic per task brief:
//   - if peakAny matches or beats N133 → 4-simdgroup pattern compounds vs M4 baseline
//   - if peakAny regresses → architectural difference (occupancy / scheduler)
let compoundsVsN133 = peakAny >= n133_m4_peak_db
let plateauVsN133 = peakAny >= n133_m4_peak_db * 0.95 && peakAny < n133_m4_peak_db
let regressesVsN133 = peakAny < n133_m4_peak_db * 0.95
let verdict: String
if compoundsVsN133 { verdict = "COMPOUNDS" }
else if plateauVsN133 { verdict = "PLATEAU" }
else { verdict = "REGRESSES" }

json += "  \"verdict_vs_m4_baseline_n133\": \"\(verdict)\",\n"
json += "  \"compounds_vs_n133\": \(compoundsVsN133),\n"
json += "  \"plateau_vs_n133\": \(plateauVsN133),\n"
json += "  \"regresses_vs_n133\": \(regressesVsN133),\n"

json += "  \"headline\": {\n"
json += "    \"peak_gflops\": \(peakAny),\n"
json += "    \"peak_at_1536_gflops\": \(best_1536),\n"
json += "    \"vs_n133_m4_db_ratio\": \(peakAny / n133_m4_peak_db),\n"
json += "    \"vs_n37_m3_ratio\": \(peakAny / n37_m3_peak),\n"
json += "    \"vs_n107_nvptx_ratio\": \(peakAny / n107_nvptx_peak),\n"
json += "    \"verdict\": \"\(verdict)\"\n"
json += "  },\n"

json += "  \"comparison_table\": {\n"
json += "    \"columns\": [\"approach\", \"shape\", \"GFLOPS\", \"rel_err\", \"source\"],\n"
json += "    \"rows\": [\n"
json += "      [\"N16 M3 simdgroup FP32\", \"768^3\", 911.55, 0.0, \"N16 (commit 31d729a4)\"],\n"
json += "      [\"N37 M3 64x64 mixed-prec\", \"1024^3\", 1519.0, 0.0, \"N37 task brief anchor\"],\n"
json += "      [\"N133 M4 64x64_tg (sb)\", \"1024^3\", 1722.87, 0.0, \"N133 M4 baseline\"],\n"
json += "      [\"N133 M4 64x64_tg_db (peak)\", \"1024^3\", 1858.35, 0.0, \"N133 M4 baseline peak\"],\n"
for r in results {
    let mShape = "\(r.M)^3"
    json += "      [\"\(r.kernel)\", \"\(mShape)\", \(r.gflops), \(r.max_rel_err), \"this fire\"],\n"
}
json += "      [\"N107 NVPTX 4-warp 64x64 (RTX 5070)\", \"1536^3\", 51651.6, 0.0, \"N107 (rfc067_pY)\"]\n"
json += "    ]\n"
json += "  },\n"

let statusStr = allOk ? "PASS" : "PARTIAL"
json += "  \"falsifier_F_RFC075_METAL_M4_4SIMDGROUP\": \"\(statusStr)\",\n"
json += "  \"honest_scope\": [\n"
json += "    \"4 simdgroups/TG = 128 threads/TG (vs N133's 32 sg/TG = 1024 threads). N107's NVPTX axis-1 was tile-shrink + warp-count-drop compounding for 1->8x CTA/SM occupancy lift on RTX 5070's 40-SM grid; M4 GPU has 10 cores (much smaller) and a different scheduling discipline. Whether the occupancy lever applies is the test.\",\n"
json += "    \"Each simdgroup carries 16 FP32 accumulators (4x4 grid of 8x8 sub-tiles spanning 32M x 32N). Register pressure on M4 unknown - if budget overflows, perf degrades. N133's 32 sg/TG carried 2 accs/SG, this carries 16 - 8x more register-resident state per SG.\",\n"
json += "    \"TG_K=16 mirrors N107's K=16/step. Threadgroup memory single-buffer 4 KiB, double-buffer 8 KiB - both well under 32 KiB M4 limit. Lower TG_K than N133's 32 means more outer K-iterations but smaller per-load slab.\",\n"
json += "    \"FP16 inputs + FP32 accumulator (same as N133). max_rel_err < 1e-4 gate.\",\n"
json += "    \"Verdict logic: peak >= N133 peak (1858.35) -> 4-simdgroup pattern compounds (axis-1 cross-vendor). peak >= 95% of N133 -> plateau. peak < 95% -> regress (architectural difference).\",\n"
json += "    \"REGRESSION on M4 is a USEFUL negative measurement per @D g3 - it falsifies the 'tile-shrink + few-warps universal axis' hypothesis at the Apple architectural boundary.\",\n"
json += "    \"Note Apple's 8x8x8 simdgroup MMA shape requires more issue per K-step than Nvidia's m16n8k16 to cover the same C tile; the SG carries 16 accumulators vs Nvidia warp carrying 8 - issue-density ratio is 2x higher per Apple-simdgroup vs Nvidia-warp.\"\n"
json += "  ]\n"
json += "}\n"
let jsonPath = "./result.json"
do { try json.write(toFile: jsonPath, atomically: true, encoding: .utf8) }
catch { print("WARN: result.json write failed: \(error)") }

let final = allOk ? "PASS" : "PARTIAL"
print("F-RFC075-METAL-M4-4SIMDGROUP: \(final)")
print(String(format: "PEAK_GFLOPS=%.2f (best of sb + db, across shape sweep)", peakAny))
print(String(format: "PEAK_SB=%.2f @ M=%d", peakSb, peakSbM))
print(String(format: "PEAK_DB=%.2f @ M=%d", peakDb, peakDbM))
print(String(format: "PEAK_AT_1536=%.2f", best_1536))
print(String(format: "VS_N133_M4_DB_RATIO=%.3fx (N133 M4 peak = %.2f GFLOPS)", peakAny / n133_m4_peak_db, n133_m4_peak_db))
print(String(format: "VS_N37_M3_RATIO=%.3fx (N37 M3 = %.2f GFLOPS)", peakAny / n37_m3_peak, n37_m3_peak))
print(String(format: "VS_N107_NVPTX_RATIO=%.4fx (N107 NVPTX = %.2f GFLOPS)", peakAny / n107_nvptx_peak, n107_nvptx_peak))
print("VERDICT=\(verdict)")
print(String(format: "MAX_REL_ERR_OVERALL=%.3e (gate < 1e-4)", Double(maxRelOverall)))
exit(0)
