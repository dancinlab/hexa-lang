# RFC 075 P3++ — N166 2-bug FIX + full-tile codegen matmul fire (Apple silicon)

Date: 2026-05-22 · Branch `worktree-agent-ae99f4559ff53bfad` · codegen commit `affcd459`.

## What changed (the 2 codegen bugs N166 found — both FIXED in source)

`compiler/codegen/metal_target.hexa::_metal_emit_matmul_body`:

**Fix 1 — template-arg (the N166 compile blocker).** The body emitted
`make_filled_simdgroup_matrix(simdgroup_float8x8, 0.0f)` which does NOT compile
under `xcrun metal` — Apple takes the matrix element type + dims as TEMPLATE
params, not a runtime first arg. Now emits the canonical
`make_filled_simdgroup_matrix<float, 8, 8>(0.0f)`.

**Fix 2 — 32×32 sub-tile loop.** The prior body computed exactly ONE 8×8
fragment per 32×32 threadgroup tile (56/64 sub-tiles left zero,
`full_tile_max_rel_err = 1.0` in the N166 fire). Now emits a 4×4 grid of 8×8
`simdgroup_float8x8` accumulators (`c_frag[4][4]`), loads 4 A + 4 B sub-tiles
per K-step via scalar-origin `simdgroup_load` (the N166-verified-compiling form,
no `ulong2` origin), issues 4×4 = 16 `simdgroup_multiply_accumulate` MMAs, then
`simdgroup_store`s all 16 fragments — the FULL 32×32 output tile.

Sub-tile pointer arithmetic (canonical row-major):
- A (sub_m, kk): `a + (row_tile + sm*8) * K + kk`, stride K
- B (sub_n, kk): `b + kk * N + (col_tile + sn*8)`, stride N
- C (sub_m, sub_n): `c + (row_tile + sm*8) * N + (col_tile + sn*8)`, stride N

## Verification (Mac-local)

- `hexa parse compiler/codegen/metal_target.hexa` → rc=0
- `hexa parse compiler/codegen/metal_lower_test.hexa` → rc=0
- **lower_test case 16 PASS** (built locally `HEXA_MAC_BUILD_OK=1`, ran the real
  compiled binary). Case 16 extended with template-arg + full-tile assertions:
  `make_filled_simdgroup_matrix<float, 8, 8>(0.0f)`, `c_frag[4][4]`,
  `for (uint sm = 0; sm < 4`, `for (uint sn = 0; sn < 4`, `c_frag[sm][sn]`,
  and a NEGATIVE assert that the broken `(simdgroup_float8x8` fill form is gone.
- `matmul_codegen_v2.metal` is **BYTE-IDENTICAL** to the actual codegen emit
  (extracted from the lower_test stdout matmul block, `diff` clean).
- **Emitted MSL compiles via `xcrun metal`** → AIR → metallib, NO template-arg
  error (the N166 compile blocker is closed).

## Silicon fire — Apple M3 (local), full-tile numeric

The M4 (mini) host was unreachable (sshd down: ICMP up, port 22 "Host is down")
during this cycle. The numeric correctness of the fix is architecture-independent,
so the full-tile math was validated on the local Apple **M3** GPU (`xcrun metal`
+ Swift MTLComputePipelineState). dispatch: tg=(32,1,1), groups=(N/32, M/32).

| host | shape | full_tile_max_rel_err | zero_missing | median_ms | full_tile_gflops |
|------|-------|------------------------|--------------|-----------|------------------|
| M3   | 256³  | 2.56e-7                | 0 / 65536    | 0.318     | 105.5            |
| M3   | 512³  | 3.28e-7                | 0 / 262144   | 0.771     | 348.4            |

`F-RFC075-METAL-MATMUL-CODEGEN-M4-FULLTILE: PASS` on M3 — full 32×32 tiling now
fills EVERY output element (`zero_inside_missing = 0`, vs N166's `full_rel = 1.0`),
and the math is FP32-round-off exact (rel_err ~2.6e-7 << TOL 1e-3).

## M4 (mini) fire — pending host availability

`measure_v2.sh` + `host_matmul_v2.swift` + `matmul_codegen_v2.metal` are staged
to fire on mini (M4) the moment sshd returns, for the GFLOPS-vs-N138 anchor
(N138 4-simdgroup hand-emit = 2109 GFLOPS @ M=1536; N133 = 1858 @ 1024³).

## GFLOPS — codegen vs hand-emit (honest, `@D g3`)

The full-tile codegen GFLOPS (M3: 105–348) is far below the N138 hand-emit
(2109 @ M4) for known first-tier codegen reasons, NOT a correctness gap:
1. **One simdgroup (32 threads) per threadgroup** — N138 uses 4 simdgroups /
   128 threads / TG for occupancy + register reuse.
2. **No threadgroup-memory tiling / cooperative loads** — every fragment is
   re-loaded from device memory each K-step (the codegen has no `threadgroup`
   scratch, no `threadgroup_barrier`, no coalesced cooperative load).
3. **FP32 inputs** — N138 uses FP16 inputs / FP32 accum for ~2× MMA throughput.
4. **No double-buffering / K-blocking.**

These are the SAME quality gaps the NVPTX matmul codegen had at first-tier emit.
The N166 closure criterion is "compiles + runs + full-tile numeric ≤1e-3"; the
2109-GFLOPS hand-emit parity is a separate multi-cycle codegen-quality follow-up
(4-simdgroup TG + threadgroup-mem tiling + FP16 inputs in the emit).

## Closure status

**Metal source-to-silicon matmul: numeric+full-tile CLOSED on Apple silicon (M3).**
- Codegen-emitted MSL compiles? **YES** (template-arg fix).
- Full 32×32 tile (not single fragment)? **YES** (sub-tile loop fix,
  zero_missing=0).
- Numerically exact on Apple GPU? **YES** (rel_err 2.6e-7).
- M4-specific GFLOPS-vs-N138 anchor: **pending mini sshd** (queued, harness ready).
- Codegen-quality (throughput) parity with N138 hand-emit: **NOT closed** —
  documented multi-cycle follow-up (4-SG TG + tg-mem tiling + FP16).

## Artifacts

- `matmul_codegen_v2.metal` — byte-identical to the post-fix codegen emit
- `host_matmul_v2.swift` — full-tile Swift host (whole-M*N numeric, full GFLOPS)
- `measure_v2.sh` — compile MSL → AIR → metallib → build host → fire 256+512
- `result_v2_m3_256.json` / `result_v2_m3_512.json` — M3 full-tile results
- (M4 `result_v2_*.json` will land when mini sshd returns)
