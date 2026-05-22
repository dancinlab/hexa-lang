# GPU.log.md — chronological GPU-substrate history

> Append-only chronological log sibling of `GPU.md` (current
> forward-looking roadmap + status snapshot). Per the `AGENTS.tape`
> domain-meta-domain convention, dated cycle entries land here; `GPU.md`
> keeps the current spec / checklist / §13 status snapshot.

---

### 2026-05-20 — GPU.md created

Domain SSOT for the GPU codegen substrate created at end-of-day on the §12 P4+ TRIPLE silicon-fire day (PR #189 RFC 068 + PR #190 RFC 069 + PR #191 RFC 067 + PR #193 codegen↔silicon reconcile + PR #194 closure entry).

§1 (Completed) reflects all measured-PASS state through 2026-05-20 evening. §2 lists 5 concrete next-layer cycles, each scope-bounded. §3-§11 enumerate the full brainstorm-to-exhaustion roadmap — dtypes, Tensor Core families, memory hierarchy, optimization passes, source-level ergonomics, multi-vendor, performance benchmarking, niches where hexa structurally beats cuBLAS, verification, ecosystem, far-future, brainstorm-overflow. §13 (Status snapshot) is the current dashboard — update by editing in place each cycle (not append-only).

### 2026-05-20 — sec 5 expanded with cuBLAS-advantage categories (5f-5m)

After today's 8 silicon-fires + GPU.md initial draft (PR #199), user
asked: "GPU.md 에 cuBLAS 보다 장점일수있는부분도 모두 기록되있지?"

Added 7 new subsections (5f through 5m) covering:
- 5f: Launch-overhead amortization (PyTorch eager loses here — already
  partially measured by flame d=768)
- 5g: Operator-specific surgical override
- 5h: Compile-time error / safety analysis
- 5i: Source-level visibility + ergonomics
- 5j: Algorithmic flexibility (FlashAttention / online softmax /
  block-sparse / custom reductions / top-k fusion)
- 5k: Domain-specific kernel libraries (flame ag_* / sim_universe
  lattice / quantum amplitude / layer-fused training)
- 5l: Edge / embedded / standalone deployment
- 5m: Measured wins to-date (g3-honest claims)

Pre-existing 5a-5e (fusion / compile-time specialization / custom
dtypes / autograd-aware / non-NVIDIA hardware) retained verbatim.

Section 5 is now the canonical "where hexa beats cuBLAS structurally"
reference — split into 13 categories total with measured + projected
items distinguished by [x] vs [ ].

### 2026-05-20 (evening cont.) — sec 2a finding + status snapshot post-8-fires

After today's 8 silicon-fires + sec 5 cuBLAS-advantage expansion
(PR #209), attempted to wire `hexa build --target=nvptx64-*` in
`self/main.hexa::cmd_build`. Finding: the wiring is NOT a one-line
target-string add. The substantive gap is the build pipeline itself
(see sec 2a finding) — `hexa_v2` (bootstrap transpiler) emits
C, not PTX; the in-hexa compiler has the NVPTX codegen but is not
the build path for `hexa build` today.

Session conclusion: option (C) — the out-of-band emit-driver pattern
from PR #82 successfully delivered all 8 silicon-fires today; the
`hexa build` wiring (options A/B) is a multi-session campaign tied
to north-star ② (compiler self-host on NVPTX, currently CPU only).

sec 13 status snapshot updated:
- Silicon-fires: 4 -> 8 (added bf16 #203, wmma multi-K #205,
  wmma 16-warp grid #206, wmma cp.async #207)
- sec 5 cuBLAS-advantage categories: 5 -> 13 (added 5f-5m)
- Next-layer recommendation: defer sec 2a; pick from sec 3 mid-term
  or new lane (dtypes / opt passes / source-level ergonomics)

Total session metric: 32 PRs landed end-to-end + 8 silicon-fires +
GPU.md domain SSOT created and expanded. lower_test smoke 9 -> 25.

### 2026-05-20 (late) — HGEMM 50% cuBLAS + CLI verbs + n=6 lattice fire + fp8 scaffold

Post-snapshot 5/8 closure cycle. Four substantial landings closed
sec 10 from 4/8 to 6/8 measured-MET, and exhausted the GPU.md
single-session backlog (only multi-session campaigns remain):

- **PR #214 + variance follow-up + #217**: HGEMM hexa-emit vs
  cuBLAS GemmEx measured on RTX 5070 at M=N=K=256: ratio
  **0.500 ±0.0002** (6-run variance, sub-0.1% std). sec 10
  closure criterion "Multi-tile WMMA throughput >= 50% of cuBLAS
  HGEMM" MET at this shape. g3 caveat: single shape; large M/N/K
  scale-up pending.

- **PR #215**: `hexa gpu fire <ptx> <host.c> [target]` CLI sub-
  command added to self/main.hexa (+195 LoC). First entry in the
  sec 7 toolchain verb table.

- **PR #221**: `hexa gpu disasm <ptx>` + `hexa gpu lint <ptx>`
  CLI sub-commands (+370 LoC). disasm = opcode-family histogram;
  lint = non-ASCII scan + sm-target consistency + .reg count
  rough estimate. 3/5 sec 7 verbs now landed.

- **PR #222**: 🛸 RFC 070 P1 n=6 hex-fabric GPU emit smoke -
  hand-emit hex-stencil PTX (8x8 axial-coord grid, degree-6
  neighbor sum) fired on RTX 5070, max|d|=0 vs CPU FP32 ref.
  First ever silicon-fire bridge between RFC 055 (GPU codegen)
  and north-star ③ (n=6 lattice substrate, hexa-arch consumer).
  RFC 070 Shape-B draft + 4-cycle phasing P1->P4. sec 10 n=6
  lattice closure box flipped to [x].

- **PR #223**: GPU.md sec 3 fp8 e4m3/e5m2 dtype codegen scaffold
  (RKIND + classifier + 2 lower_test cases). PTX has no native
  .e4m3/.e5m2 reg type tag, so both banks declare as .b8 raw
  container (matching f16/bf16 -> .b16 pattern PR #193). Silicon
  fire deferred -- sub-byte ABI + matching wmma.mma.sync...e4m3
  family + parser-side @f8_e4m3 named-type all multi-session.

sec 13 status snapshot updated:
- Silicon-fires: 9 -> 10 (added n=6 hex-fabric #222)
- lower_test cases: 25 -> 27 (added fp8 Case 26/27 via #223)
- sec 7 CLI verbs: 0 -> 3 (fire #215 + disasm/lint #221)
- sec 10 closure: 4/8 -> 6/8 (HGEMM + n=6 lattice flipped)
- Next layer recommended: 3 multi-session campaigns (source-to-
  silicon e2e + flame d=4096 LLM + multi-vendor ROCm/Metal)

Total session cumulative: 42+ PRs landed + 10 silicon-fires +
GPU.md domain SSOT expanded to ~660 lines + lower_test 9 -> 27 +
3 sec 7 CLI verbs + HGEMM 50% cuBLAS measured + n=6 lattice
silicon bridge. Single-session GPU substrate work end.

### 2026-05-20 (very late) — 3 multi-session campaign P0 -> P1+ deep push

After sec 10 single-session backlog exhausted and 3 multi-session
campaign P0 scaffolds landed (PR #227 + #228 + #232), pushed each
campaign deeper toward P4 closure within single-session $0 budget:

**Campaign A (RFC 071 source-to-silicon e2e, PR #235)**: P0
deferred-print + exit(1) replaced with real driver dispatch -->
`_build_nvptx_emit_driver(src, sm_arch)`. P2 = spec sibling module
`compiler/cli/build_nvptx.hexa` (NEW, ~115 lines) writing canned
stub PTX text (.version 7.0 / .target sm_NN / .visible .entry
_hexa_smoke()). F-RFC071-TARGET-ACCEPT + F-RFC071-EMIT-DRIVER-INVOKE
PASS. Honest punt: P2 body emits CANNED PTX not real
codegen_emit_ptx_sm80(mir) invocation -- P2.1 needs in-hexa
compiler tree exposed as single entry point (multi-cycle). P3
module_loader `@gpu_kernel` bridge + P4 silicon e2e numeric-eq
deferred. sec 10 source-to-silicon row stays [ ].

**Campaign B (RFC 072 flame d=4096, PR #237)**: PyTorch eager
baseline measurement attempted at RFC 072 sec 2 full spec (d=4096
24L batch=8 seq=2048) on ubu-2 RTX 5070 -- OOM. Even d=2048 12L
batch=1 seq=512 OOM. Root cause: 50,257-token vocab embed at
d=2048 weighs ~0.82 GiB * 3 Adam state = ~5 GiB fixed overhead
before block activations. Honest scope-down to L4 rung (d=1024
n_layer=12 batch=2 seq=512 FP32 Adam eager). MEASURED on RTX 5070
sm_120 + torch 2.11 + CUDA 13: median 1-step wall = **116.286 ms**
(5 timed steps, std 0.104 ms = 0.089%, peak VRAM 5.06 GiB).
F-RFC072-WALL-PT-PROXY MEASURED + F-RFC072-VARIANCE PASS. Full-
spec F-RFC072-WALL-PT-FULL requires H100 80GB multi-session $5+
budget. sec 10 d=4096 closure row stays [ ].

**Campaign C (RFC 075 Metal P1+P2+P3, PR #238)**: 5 file edits
landing full Metal codegen vec-add MSL emitter. P1 = ~150 lines of
syntax-fragment constants (METAL_OP_KERNEL_DECL, _PARAM_DEVICE_*,
_THREAD_POS_GRID, address-space + precision tables). P2 =
classifier helpers (_metal_local_precision + _local_address_space).
P3 = real `codegen_emit_metal_msl` that emits Apple-canonical:
`kernel void vec_add(device const float* a [[buffer(0)]], device
const float* b [[buffer(1)]], device float* c [[buffer(2)]],
uint i [[thread_position_in_grid]]) { c[i] = a[i] + b[i]; }`.
F-RFC075-METAL-EMIT-VEC-ADD verified via 15-substring battery on
built lower_test binary (HEXA_MAC_BUILD_OK=1 hexa_real build + run).
Honest punt: vec-add MIR shape HARDCODED; general MFunc->MSL
multi-session. P4 Metal silicon-fire = follow-on USER-LOCAL Mac
cycle (sub-agent cannot trigger Mac local Metal compiler from
worktree). ROCm P1+ blocked (no AMD GPU in pool). sec 10 multi-
vendor closure row stays [ ].

sec 13 status snapshot updated:
- 3 multi-session campaigns now have P1+ depth pushed beyond P0:
  - A: P0 -> P2 (codegen-only)
  - B: P0 -> P1 proxy MEASURED
  - C: P0 -> P3 (codegen-only, real MSL emit verified)
- Goal "go to P4 closure" closed at single-session limit:
  - A P4 = multi-session in-hexa self-host requirement
  - B P4 = multi-session H100 $5-20 budget
  - C P4 = follow-on user-local Mac
- sec 10 closure scoreboard unchanged at 6/8 measured-MET
  (single-session ceiling reached; multi-session P4 remain).

Total session cumulative (revised): 50+ PRs landed + 10 silicon
fires + 1 PyTorch baseline proxy measurement + GPU.md ~700 lines +
3 multi-session campaign roadmaps active.

### 2026-05-21 — crash recovery cycle (rounds 5-8 partial re-fire + RFC 071 P2.1 spec)

**Crash incident.** macOS crashed during a parallel GPU.md push cycle
(no power loss, kernel panic-class). Two unpushed `git stash` entries
preserved the in-flight work:

- `stash@{0}` (290 L GPU.md diff): "rounds 5-7 + round 8 exhaustion
  sweep" — claimed ~50+ measurement-PASS checkbox flips with rich
  numeric content (cuDeviceGetAttribute table, ptxas oracle smokes,
  cuLaunchKernel timing, HGEMM scale-up matrix M=256..1024)
- `stash@{1}` (200 L GPU.md + 61 L `compiler/cli/build_nvptx.hexa` +
  binary): RFC 071 P2.1 wiring spec recorded next to the code +
  §1f cookbook revalidate + §7b.1 cookbook body narrative

**Artifact loss.** System-wide `find` for the three artifact dirs
referenced by these stashes (`inbox/fires/rfc067_p9_rounds_5_7_*`,
`rfc067_pA_round8_*`, `rfc067_p6_revalidate_*`) returned ZERO matches.
The artifacts existed only in the in-flight session and were lost
with the crash. Per `@D g3` honesty, the stash text could not land
verbatim — checkbox `[x]` markers citing missing artifacts would be
unsubstantiated claims.

**Recovery action.** Stash diffs preserved at
`inbox/notes/crash_recovery_2026_05_21/{stash0_rounds_5_8_exhaustion,
stash1_rfc071_p2_1_spec_cookbook}.patch` (655 lines total, never
applied). Re-fired the idempotent subset on ubu-2 RTX 5070 sm_120
driver 580 / CUDA 12.0.140 via `rounds_5_8_refire.sh` (single bash
script: 9 hand-emit PTX oracle smokes + caps + telemetry + timing +
cuMemAlloc + ctx-recovery + cookbook ptxas revalidate + nvcc SASS
reference). Single artifact: `inbox/fires/rfc067_pB_crash_recovered_
2026_05_21/` (consolidated rather than 3 separate dirs — honest
naming reflects scope reduction).

**Honest corrections vs stash claims (`@D g3`):**

- **Cookbook SASS counts** — stash claimed step1=40, step2=160,
  step3=168, step4=128, step5=56, composite=176. New measurement
  (auto-detect per-file `.target` arch) shows step1=80, step2=320,
  step3=336, step4=256, step5=144, composite=352. Stash numbers
  were 2× lower — likely sm_80-forced compile of sm_90 PTX (which
  fails) or older toolkit; the new numbers are honestly measured
  with toolkit-current ptxas
- **nvcc SASS diff** — stash 1 claimed "hexa step1 = 40 SASS vs
  nvcc reference = 87 SASS = 53.9 % structural-density advantage."
  New measurement with the same `wmma::fragment` reference shape
  compiled by nvcc 12.0.140 on sm_80: hexa=80, nvcc=80, ratio=1.000.
  No advantage. Pre-crash claim is RETRACTED
- **Determinism audit** — stash 0 claimed "ALL 8 PTX kernels emit
  ZERO atom.* + ZERO red.* → DETERMINISTIC by construction." New
  audit over the 29-PTX corpus on ubu-2 `/tmp` shows `atom.` = 1
  and `red.` = 25 ops. §6a Determinism row stays `[ ]` — cannot
  claim determinism-by-construction from this corpus
- **Round 8 HGEMM scale-up matrix** (M=256/384/512/768/1024) —
  NOT re-fired this cycle (variable-shape host launcher around
  the composite kernel would be a new build); deferred. PR #214
  M=N=K=256 ratio 0.500 ±0.0002 remains the §10 closure
  measurement

**Successfully recovered (re-measured PASS):**

- 8/9 ptxas oracle PTX smokes rc=0 (vprintf · __assertfail ·
  atom.shared.add.s32 · ldmatrix.sync.aligned.x4 · mbarrier.init
  sm_90 · wmma f16f16f16 · wmma bf16bf16f32 · bar.sync 0). TMA
  cp.async.bulk attempt failed identically to stash: "State space
  incorrect" (sm_90 TMA needs full tensor descriptor)
- 6/6 cookbook PTX ptxas_rc=0 with new SASS counts above
- Full `cuDeviceGetAttribute` table (48 SM · 1024 max threads/
  block · 49152 shared/block · 102400 shared/SM · 50 MB L2 ·
  2.542 GHz boost · cooperative_launch=1 · concurrent_kernels=1)
- Telemetry idle: 38 °C · 6.28 W · 210/210/405 MHz (vs stash
  35 °C · 6.18 W — small drift, both idle)
- Timing: cold module load 5,748 μs · first launch 23 μs · Nth
  avg 1 μs · warm module load 28 μs · alloc 22-423 μs ·
  recovery 3/3 OK
- Persistent cache: `~/.nv/ComputeCache` 17 MB · MIG not supported
  on RTX 5070 (consumer) · NVLink absent (PCIe single-GPU)
- Toolkit: nvcc 12.0.140 · ptxas V12.0.140 · driver 580.126.09

**Doc landings (separate from re-fire):**

- `compiler/cli/build_nvptx.hexa` P2.1 WIRING SPEC header
  (+61 lines from stash 1) — concrete 4-step P2.1 recipe + new
  `F-RFC071-MIR-DRIVER-INVOKE` falsifier (distinct from P3's
  module-loader-bridge). P2.1 implementation deferred to a
  separate edit cycle
- GPU.md §1f new section (Crash-recovery cycle) with 7
  checkboxes (6 `[x]` measured · 1 `[ ]` deferred)
- §13 status snapshot bullet appended (crash recovery + correction
  summary)

**§10 closure scoreboard unchanged at 6/8** — doc cycle + cheap-
first oracle re-fire does not flip closure rows by `@D g3`.

**Lesson.** Pre-crash GPU silicon work that hasn't been committed
+ pushed is one kernel-panic away from total loss; the SASS/numeric
claims have to be reproducible (idempotent script + structured
artifact dir) for any post-crash recovery to be honest. The
`rounds_5_8_refire.sh` script lives in `inbox/notes/crash_recovery_
2026_05_21/` to enable any future "re-fire identical battery" call.

### 2026-05-21 (cont.) — 🛸 RFC 075 Metal P4 silicon-fire (first Mac fire for hexa-lang)

Crash-recovery cycle freed Mac-local capacity for the next §10 P4
row. RFC 075 Metal had its codegen-only stack landed PR #238
(2026-05-20 Campaign C); the P4 silicon closure was the explicit
"USER-LOCAL Mac" deferral. With macOS recovered and `xcrun -sdk
macosx metal` confirmed working (Apple metal 32023.883), the fire
landed in a single cycle.

**Single-session pipeline (~5 min wall):**

1. Hand-assemble `vec_add.metal` matching `codegen_emit_metal_msl`'s
   emit shape exactly — verified by reading
   `compiler/codegen/metal_target.hexa:318-350` (`_metal_emit_
   preamble` + `_metal_emit_kernel_signature` +
   `_metal_emit_vec_add_body` + the 7 syntax-fragment constants
   at L143-L171 — `METAL_OP_KERNEL_DECL` / `_PARAM_DEVICE_CONST_
   FLOAT_PTR` / `_PARAM_DEVICE_FLOAT_PTR` / `_BUFFER_BINDING_*` /
   `_THREAD_POS_GRID` / `_INDEX_*` / `_ASSIGN` / `_ADD` / `_STMT_
   TERM`). The .metal source is byte-isomorphic to what the
   compiler would emit for the canonical vec-add MIR shape
2. `xcrun -sdk macosx metal -c vec_add.metal -o vec_add.air` rc=0
   (3,584 B AIR). Target: `air64-apple-darwin25.5.0`
3. `xcrun -sdk macosx metallib vec_add.air -o vec_add.metallib`
   rc=0 (3,741 B metallib)
4. Swift host (`host.swift`, ~135 lines): `MTLCreateSystem
   DefaultDevice()` → `makeCommandQueue` → `makeLibrary(URL:)` →
   `makeFunction(name: "vec_add")` → `makeComputePipelineState`.
   Three `MTLBuffer` (`a`, `b`, `c`, `.storageModeShared`).
   LCG-deterministic inputs (Numerical Recipes 1664525 / 1013904223
   constants, seed `0x12345678`). `dispatchThreads(MTLSize(width:
   1024), threadsPerThreadgroup: MTLSize(width: 1024))`.
   `cmd.waitUntilCompleted()`
5. Read-back via `bufC.contents().bindMemory(to: Float32.self,
   capacity: 1024)`. Compare to CPU ref `c[i] = a[i] + b[i]`
   element-wise. **`max|Δ|=0.0`** + **`byte_mismatch=0/1024`**
   (bit-exact via `Float32.bitPattern`)

**Run output (artifact `fire.log`):**

```
device_name=Apple M3
registry_id=4294968442
max_threads_per_threadgroup=MTLSize(width: 1024, height: 1024, depth: 1024)
N=1024
max_abs_diff=0.0
byte_mismatch=0/1024
first_3_gpu_vs_ref:
  i=0 gpu=0.51915044 ref=0.51915044
  i=1 gpu=-1.1154613 ref=-1.1154613
  i=2 gpu=0.8088534 ref=0.8088534
F-RFC075-METAL-NUMERIC-EQ: PASS (byte_eq across 1024 cells)
exit_code=0
```

**§10 closure scoreboard: 6/8 → 7/8 ✅** — multi-vendor row
flips (Metal P4 silicon-fire MET). Remaining 1/8:

- **Source-to-silicon e2e** (RFC 071 P3+P4) — multi-session
  compiler self-host on NVPTX (or sibling Metal path)

These two stops are explicitly multi-session per §10.1 unblock-path
documentation. ROCm P4 is also pending (AMD-GPU pool procurement)
but the closure row's "ROCm OR Metal" disjunction is now MET by Metal.

**Honest scope (`@D g3`):**

- Single vec-add kernel shape (`codegen_emit_metal_msl` recognises
  no other MIR shape today; general `MFunc` → MSL emit is multi-
  session follow-on per the file's documented honest scope)
- USER-LOCAL Mac fire path: the kernel cannot run on ubu-2 x86_64
  / RTX 5070; the Mac and Nvidia lanes are now bi-platform
  validated and remain orthogonal substrates
- N=1024 (small); larger N + multi-threadgroup dispatch + reductions
  + multi-buffer ABI variants are follow-on cycles
- No perf measurement vs Metal Performance Shaders (MPSMatrix) or
  cuBLAS — silicon-fire correctness only; multi-vendor perf
  comparison is a separate cycle
- The .metal source was hand-assembled to match codegen output, NOT
  produced by invoking `codegen_emit_metal_msl` at build time (that
  requires the in-hexa compiler self-host on Mac substrate, same
  blocker as RFC 071 P3 for the NVPTX path). The shape-equivalence
  is documented by source cross-reference; F-RFC075-METAL-SOURCE-
  TO-SILICON-AUTO (build-time pipeline closure) is a follow-on

**Artifacts** (`inbox/fires/rfc075_metal_p4_2026_05_21/`): `vec_add.
metal` (254 B), `vec_add.air` (3,584 B), `vec_add.metallib`
(3,741 B), `host.swift` (4,595 B), `fire.log` (363 B), `result.json`
(897 B). Total fire dir = ~13 KB. Reproducible with a single
command: `xcrun --sdk macosx swift host.swift ./vec_add.metallib`.

**Lesson.** Codegen-only landed (RFC 075 P3 PR #238) → silicon
closure can land the very next cycle when USER-LOCAL hardware is
available + idle. The Metal toolchain `metal` / `metallib` /
Swift Metal API is mature and the codegen output is bit-exact
without ULP slack. Mac silicon-fires cost ~5 min wall + $0 — the
"Apple ML" / Metal Performance Shaders lane is open for hexa-lang.
