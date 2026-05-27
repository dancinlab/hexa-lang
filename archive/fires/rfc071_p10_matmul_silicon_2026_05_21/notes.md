# RFC 071 P10 — NVPTX source-to-silicon matmul fire (retry, 2026-05-22)

## Verdict

**F-RFC071-NVPTX-MATMUL-SOURCE-TO-SILICON-NUMERIC-EQ = FAIL**

N86 (codegen) + N100 (HIR→MIR synthesis + bind) are now **PRESENT on main HEAD `7bc63345`** (no longer the prior wipe pattern). However the N86 PTX-emit produces malformed mnemonics that ptxas rejects, and after hand-correcting 3 mnemonic-shape bugs a 4th addressing/tiling bug remains.

Source-to-silicon E2E **STILL BLOCKED**; the wiring is in place but the strings the emitter writes are wrong.

## Prerequisites — all PRESENT on main

```
$ git rev-parse HEAD
7bc633456d739326e77b3f6b78d0cafd5343aec0

$ grep -c _nvptx_mfunc_is_matmul compiler/codegen/nvptx_target.hexa  # 9 (3 recognisers + 3 dispatcher cases + 3 helper refs)
$ grep -c gpu_matmul compiler/lower/hir_to_mir.hexa                  # 5
$ grep -c gpu_matmul compiler/check/bind.hexa                        # 2
$ ls compiler/codegen/nvptx_p10_matmul_test.hexa                     # 2761 B
```

Origin commits: `7f3448aa` (N86 codegen, "RFC 071 P5+ — matmul + matmul_NT_a + matmul_NT_b shapes") + `f2770d6e` (N100 HIR→MIR + bind + fixture, "closes N86 source-to-silicon E2E").

## What ran end-to-end this cycle

1. `hexa build self/main.hexa -o /tmp/hexa_n122_driver` — PASS.
2. `/tmp/hexa_n122_driver build compiler/codegen/nvptx_p10_matmul_test.hexa --target=nvptx64-nvidia-cuda-sm80` — PASS (4843 B PTX, pure ASCII, phase=P3-PATH-B).
3. ubu-2 `ptxas --gpu-name sm_80 matmul_kernel.sm_80.ptx` — **FAIL**:
   ```
   line 101; error : Unexpected instruction types specified for 'wmma.mma'
   line 110; error : Arguments mismatch for instruction 'wmma.store.d'
   ptxas fatal : Ptx assembly aborted due to errors
   ```
4. ubu-2 driver-JIT (`cuModuleLoadDataEx`) — **FAIL** (same diags, error 218).
5. After 3 surgical PTX edits → `matmul_kernel.sm_80.handfixed.ptx`:
   - ptxas — **PASS** (32 regs, 400 B cmem[0]).
   - driver-JIT — **PASS**.
   - `cuLaunchKernel(grid=(4,4,1), block=(32,1,1))` + `cuCtxSynchronize` — **PASS**.
   - Numeric vs CPU FP32 ref — **FAIL** (`max_abs=13.60`, `max_rel=1479`, all 4096 cells nonzero but wrong).
   - B-pre-transpose host variant — also FAIL (`max_abs=12.7`); not just a layout swap.

## PTX 5-substring audit

| Expected | Emitted by main HEAD | Status |
|---|---|---|
| `.visible .entry matmul_kernel` | `.visible .entry matmul_kernel` | OK |
| `wmma.load.a.sync.aligned.m16n16k16.row.f16` | `wmma.load.a.sync.aligned.row.m16n16k16.f16.shared` | MISFORMED — token order swapped + wrong state-space `.shared` |
| `wmma.load.b.sync.aligned.m16n16k16.col.f16` | `wmma.load.b.sync.aligned.col.m16n16k16.f16.shared` | MISFORMED — same |
| `wmma.mma.sync.aligned.row.col.m16n16k16.f32.f16.f16.f32` | `wmma.mma.sync.aligned.row.col.m16n16k16.f32.f16.f16.f32` | LITERAL MATCH but ptxas REJECTS (the long form requires 4-reg fragments; with 8-b32 A/B + 8-f32 D/C the only ptxas-accepted form is `.f32.f32` short form, per every working f16 oracle PTX in `inbox/fires/`) |
| `wmma.store.d.sync.aligned` | `wmma.store.d.sync.aligned.row.m16n16k16.f32.shared` | substring MATCH but operand order wrong + wrong state-space |

Strict-substring ratio: **3/5**. Concept-present ratio: 5/5. ptxas-accepted ratio: 0/5 (entire emit rejected).

`// unsupported call: gpu_matmul` diagnostic from N108 cycle is **GONE** — that's the one positive delta this cycle. The synthesis fired; only the WMMA-emit grammar is wrong.

## The 4 N86 emit bugs

### Bug 1 — `wmma.load.{a,b}` malformed
- **Emitted:** `wmma.load.a.sync.aligned.row.m16n16k16.f16.shared {...8 regs...}, [%rd8], %r6`
- **Expected:** `wmma.load.a.sync.aligned.row.m16n16k16.global.f16 {...8 regs...}, [%rd8], %r6`
- Two sub-bugs: (a) state-space modifier `.global/.shared/.const` must precede element-type `.f16` per PTX 7.0 grammar, (b) the pointer is generic-from-`.param.u64` (effectively global), not `.shared`.
- Working oracle: `inbox/fires/rfc067_p4_2026_05_20/wmma_16x16.ptx:37,41`.

### Bug 2 — `wmma.mma` long-form type spec with 8-reg fragments
- **Emitted:** `wmma.mma.sync.aligned.row.col.m16n16k16.f32.f16.f16.f32 {D8}, {A8}, {B8}, {C8}`
- **ptxas:** `Unexpected instruction types specified for 'wmma.mma'`
- Per PTX 7.0 spec, the long form `.f32.f16.f16.f32` is reserved for the 4-reg fragment layout (used by bf16/u8/s8). For f16 m16n16k16 with the 8-`b32` A/B + 8-`f32` D/C layout — which is what this kernel emits — the canonical ptxas-accepted form is the short form `.f32.f32` (the input element type is implicit in the .b32 register packing).
- Working oracles: every `wmma.mma.sync.aligned.row.col.m16n16k16` in `inbox/fires/rfc067_*` uses `.f32.f32` (10+ files, all ptxas-accepted).

### Bug 3 — `wmma.store.d` malformed operand order + state space
- **Emitted:** `wmma.store.d.sync.aligned.row.m16n16k16.f32.shared {...8 regs...}, [%rd14], %r5`
- **Expected:** `wmma.store.d.sync.aligned.row.m16n16k16.global.f32 [%rd14], {...8 regs...}, %r5`
- Three sub-bugs: (a) state-space `.global` not `.shared`, (b) state-space precedes element-type, (c) operand order is destination address first, then fragment, then stride.
- Working oracle: `inbox/fires/rfc067_p4_2026_05_20/wmma_16x16.ptx:62`.

### Bug 4 — addressing/tiling/layout
- After bugs 1-3 fixed, ptxas PASSes and kernel launches/returns, but `max_abs=13.6` and the value pattern doesn't match CPU FP32 reference. Pre-transposing B to col-major in the host also fails.
- Suspects: row-major A + col-major B convention mismatch with test fixture layout; OR stride is byte-stride vs element-stride mismatch; OR per-tile A/B offset computation off (the kernel computes `row_tile*K+kk` for A and `kk*N+col_tile` for B which assumes A=row-major + B=row-major, but loads B with `.col` mnemonic, which is internally inconsistent).
- This bug cannot be diagnosed further without N86 codegen edit access.

## Wipe-chain status — POSITIVE delta vs N108

Last cycle (N108, 2026-05-21) the verdict was BLOCKED because all 3 prereqs (N86 recognisers, N100 synthesis, fixture) were **missing on main**. This cycle (N122, 2026-05-22) all 3 prereqs are **PRESENT** on main HEAD `7bc63345` via commits `7f3448aa` (N86) and `f2770d6e` (N100). The re-restore documented in `cfd056e4` ("N105 ... + N108 BLOCKED diagnosis + N86/N100 re-restored") landed correctly.

So the wiring/dispatch problem is closed. The remaining problem is **codegen string correctness** — the emitter writes ptxas-invalid mnemonics.

## Honest scope (`@D g3`)

Task brief explicitly said: *"If WMMA emit has bug (shape mismatch), document precisely"* and *"DO NOT touch compiler source — pure rebuild + fire cycle"*. Both honored. Source-to-silicon matmul E2E closure status: **NOT CLOSED**. Verdict downgraded from "Source-to-silicon CLOSED" to "wiring closed, emit-grammar bug" — a smaller but real positive delta vs the N108 BLOCKED verdict.

## Artifacts in this dir

- `matmul_kernel.sm_80.ptx` — original main-HEAD emit (4843 B, 112 lines, ptxas REJECTS).
- `matmul_kernel.sm_120.ptx` — same emitter at sm_120 (4845 B, same shape).
- `matmul_kernel.sm_80.handfixed.ptx` — 3 surgical edits to test if bugs 1-3 are the only issues (ptxas PASS, numeric FAIL).
- `host_matmul.c` — silicon-fire harness (unchanged from N108).
- `fire.log` — original-emit ptxas FAIL + hand-fixed-emit numeric FAIL.
- `result.json` — machine-readable verdict + bug catalog + remediation pointer.

## Next-cycle remediation

Edit `compiler/codegen/nvptx_target.hexa` (probably `_nvptx_emit_matmul_body` or whatever helper emits the WMMA mnemonics — search for "wmma.load.a" string):

1. Change `wmma.load.a.sync.aligned.row.m16n16k16.f16.shared` → `wmma.load.a.sync.aligned.row.m16n16k16.global.f16`.
2. Change `wmma.load.b.sync.aligned.col.m16n16k16.f16.shared` → `wmma.load.b.sync.aligned.col.m16n16k16.global.f16`.
3. Change `wmma.mma.sync.aligned.row.col.m16n16k16.f32.f16.f16.f32` → `wmma.mma.sync.aligned.row.col.m16n16k16.f32.f32`.
4. Change `wmma.store.d.sync.aligned.row.m16n16k16.f32.shared {regs}, [addr], stride` → `wmma.store.d.sync.aligned.row.m16n16k16.global.f32 [addr], {regs}, stride`.
5. Audit addressing for bug 4 against `inbox/fires/rfc067_p5_perf_hgemm_2026_05_20/wmma_256x256_grid.ptx` (working 256×256 HGEMM, row-major A + col-major B layout, ptxas-accepted, silicon-verified).

After bugs 1-4 fixed, re-fire this exact harness; expected outcome on closure: `max_abs ≤ 4e-6` at M=N=K=64 (4 ULP × max_ref ~1.2e-7).
