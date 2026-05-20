// RFC 075 P4 — Metal silicon-fire host (Swift)
// Loads vec_add.metallib, runs `vec_add` kernel on N=1024 FP32 buffers,
// compares result vs CPU reference; emits PASS/FAIL with max|Δ|.
//
// Build (user-local Mac, avoid wilson-pool):
//   xcrun --sdk macosx swiftc host.swift -o host
// Run:
//   ./host

import Foundation
import Metal

let N: Int = 1024

guard let device = MTLCreateSystemDefaultDevice() else {
    FileHandle.standardError.write("FAIL: no Metal device\n".data(using: .utf8)!)
    exit(2)
}
print("device: \(device.name)")

// Load metallib from disk (sibling to host binary).
let metallibURL = URL(fileURLWithPath: "vec_add.metallib")
let library: MTLLibrary
do {
    library = try device.makeLibrary(URL: metallibURL)
} catch {
    FileHandle.standardError.write("FAIL: makeLibrary: \(error)\n".data(using: .utf8)!)
    exit(2)
}

guard let kernel = library.makeFunction(name: "vec_add") else {
    FileHandle.standardError.write("FAIL: kernel `vec_add` not found in metallib\n".data(using: .utf8)!)
    exit(2)
}

let pipeline: MTLComputePipelineState
do {
    pipeline = try device.makeComputePipelineState(function: kernel)
} catch {
    FileHandle.standardError.write("FAIL: makeComputePipelineState: \(error)\n".data(using: .utf8)!)
    exit(2)
}

guard let queue = device.makeCommandQueue() else {
    FileHandle.standardError.write("FAIL: makeCommandQueue\n".data(using: .utf8)!)
    exit(2)
}

// Deterministic random fill (seeded LCG so the run is reproducible).
var lcgState: UInt64 = 0xC0FFEE_DEADBEEF
func lcgNext() -> Float {
    lcgState = lcgState &* 6364136223846793005 &+ 1442695040888963407
    let mantissa = (lcgState >> 40) & 0xFFFFFF       // 24-bit
    return Float(mantissa) / Float(1 << 24)          // [0, 1)
}

var aHost = [Float](repeating: 0, count: N)
var bHost = [Float](repeating: 0, count: N)
var cRef  = [Float](repeating: 0, count: N)
for i in 0..<N {
    aHost[i] = lcgNext() * 100.0 - 50.0
    bHost[i] = lcgNext() * 100.0 - 50.0
    cRef[i]  = aHost[i] + bHost[i]
}

// Allocate Metal buffers in shared mode (unified memory on Apple silicon).
let byteCount = N * MemoryLayout<Float>.stride
guard
    let aBuf = device.makeBuffer(bytes: aHost, length: byteCount, options: .storageModeShared),
    let bBuf = device.makeBuffer(bytes: bHost, length: byteCount, options: .storageModeShared),
    let cBuf = device.makeBuffer(length: byteCount, options: .storageModeShared)
else {
    FileHandle.standardError.write("FAIL: makeBuffer\n".data(using: .utf8)!)
    exit(2)
}

// Encode + dispatch.
guard
    let cmd = queue.makeCommandBuffer(),
    let enc = cmd.makeComputeCommandEncoder()
else {
    FileHandle.standardError.write("FAIL: makeCommandBuffer/Encoder\n".data(using: .utf8)!)
    exit(2)
}

enc.setComputePipelineState(pipeline)
enc.setBuffer(aBuf, offset: 0, index: 0)
enc.setBuffer(bBuf, offset: 0, index: 1)
enc.setBuffer(cBuf, offset: 0, index: 2)

let threadsPerThreadgroup = MTLSize(
    width: min(pipeline.maxTotalThreadsPerThreadgroup, 64),
    height: 1, depth: 1
)
let threadsPerGrid = MTLSize(width: N, height: 1, depth: 1)
enc.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
enc.endEncoding()
cmd.commit()
cmd.waitUntilCompleted()

if cmd.status == .error {
    let msg = cmd.error.map { "\($0)" } ?? "(no error object)"
    FileHandle.standardError.write("FAIL: command status .error: \(msg)\n".data(using: .utf8)!)
    exit(2)
}

// Read result back.
let cPtr = cBuf.contents().bindMemory(to: Float.self, capacity: N)
var maxDelta: Float = 0
var mismatchCount: Int = 0
var firstMismatch: (i: Int, gpu: Float, cpu: Float)? = nil
for i in 0..<N {
    let d = abs(cPtr[i] - cRef[i])
    if d > maxDelta { maxDelta = d }
    if d != 0 {
        if mismatchCount == 0 {
            firstMismatch = (i, cPtr[i], cRef[i])
        }
        mismatchCount += 1
    }
}

let verdict = (maxDelta == 0) ? "PASS" : "FAIL"
print("N: \(N)")
print("max_delta: \(maxDelta)")
print("mismatches: \(mismatchCount)")
if let fm = firstMismatch {
    print("first_mismatch: i=\(fm.i) gpu=\(fm.gpu) cpu=\(fm.cpu)")
}
print("verdict: \(verdict)")

// Print a few sample outputs for sanity.
print("samples: c[0]=\(cPtr[0]) ref[0]=\(cRef[0]); c[\(N-1)]=\(cPtr[N-1]) ref[\(N-1)]=\(cRef[N-1])")

// Emit a machine-readable result line (used by result.json composer).
print("RESULT_JSON: {\"verdict\":\"\(verdict)\",\"max_delta\":\(maxDelta),\"mismatches\":\(mismatchCount),\"N\":\(N),\"device\":\"\(device.name)\"}")

exit(verdict == "PASS" ? 0 : 1)
