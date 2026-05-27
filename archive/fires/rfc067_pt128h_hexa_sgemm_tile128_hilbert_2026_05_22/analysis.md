# RFC 067 PT128H -- 128x128 output tile + Hilbert CTA-swizzle (2026-05-22, RTX 5070 sm_120)

## What this fire combined

- **N89 (PS) body:** 128x128 output tile per CTA, 32 warps (1024 thd/CTA), 47 regs/thd,
  16 f32 acc/lane, 4x mma.m16n8k16 per warp per K-step. MMA math byte-identical to N89/N77.
- **N149 (PHILB) swizzle:** Hilbert space-filling-curve d2xy CTA visitation, ported to the
  128-tile grid (`side = N/128`). Launch `p x p`, `p = next_pow2(side)`,
  `(sw_x,sw_y) = hilbert_d2xy(p, ctaid.y*p+ctaid.x)`, early-return padding CTAs.
  Bijective over the real `side x side` grid (verified in the generator per shape).

The only kernel change vs N89 is replacing the two `mov %r10,%ctaid.y / %r11,%ctaid.x`
with the unrolled Hilbert prologue (outputs `sw_y->%r10`, `sw_x->%r11`); all A/B/C base
address math is otherwise N89-identical, so the per-tile MMA output is bit-exact.

## Host / fire

- ubu-2, NVIDIA GeForce RTX 5070, sm_120, 48 SMs, driver 13000, runtime 12090.
- 200 timed reps + 20 warmup, cudaEventRecord sync per launch.
- Falsifier **F-RFC067-HEXA-SGEMM-TILE128-HILBERT: PASS** -- bit-exact (max_abs=0.0, max_rel=0.0)
  vs cuBLAS HGEMM at all 4 shapes.

## Headline numbers (median TFLOPS, ratio vs THIS-run cuBLAS)

| M    | grid  | p  | CTAs (real/launched) | cuBLAS | N149 64x64+Hilbert | PT128H 128+Hilbert | ratio | %over N149 |
|------|-------|----|----------------------|-------:|-------------------:|-------------------:|------:|-----------:|
| 4096 | 32x32 | 32 | 1024 / 1024          | 70.04  | 56.99 / 0.821      | **36.84 / 0.526**  | 0.526 | **-35.4%** |
| 5120 | 40x40 | 64 | 1600 / 4096          | 70.39  | 57.69 / 0.827      | **38.05 / 0.541**  | 0.541 | **-34.0%** |
| 6144 | 48x48 | 64 | 2304 / 4096          | 70.83  | 58.49 / 0.834      | **38.98 / 0.550**  | 0.550 | **-33.4%** |
| 8192 | 64x64 | 64 | 4096 / 4096          | 70.46  | 59.48 / 0.847      | **37.88 / 0.538**  | 0.538 | **-36.3%** |

Peak PT128H: **38.98 TFLOPS @ M=6144, ratio 0.550.** (N149 64x64+Hilbert peak: 59.48 @ M=8192, 0.847.)

## Did 128x128 + Hilbert beat 64x64 + Hilbert? NO -- decisively, at every shape.

**`tile128_hilbert_beats_hilbert64 = false` for all 4 shapes.** PT128H is ~33-36% slower than
N149 64x64+Hilbert across the entire large-M sweep. The headline M=8192 ratio is 0.538 vs
N149's 0.847 -- a 0.31 ratio deficit, the opposite of the hypothesis.

## Why -- N89's occupancy-collapse finding HOLDS, swizzle cannot rescue it

- **regs/thd = 47, shmem = 16384 B, 1024 thd/CTA -> 1 CTA/SM** (47*1024 = 48128 regs/CTA vs
  64K regs/SM; only 1024/1536 = 67% of the SM thread budget used). Identical register
  pressure to N89 -- the Hilbert prologue is register-neutral (ptxas folds the constant
  s-multiplies, reuses scratch %r100..%r129), exactly as N149 reported. No spill.
- With 1 CTA/SM there is **no inter-CTA latency hiding**: when the single resident CTA stalls
  on cp.async / bar.sync, the SM has no second CTA to switch to. The 64x64 4-warp kernel runs
  3-4 CTAs/SM (~16K regs/CTA), so it overlaps memory latency across co-resident CTAs.
- The Hilbert swizzle DID do its job on the L2 axis: the PT128H ratio is **flat at 0.53-0.55**
  across M=4096..8192 (no cliff decay), the signature of a working L2-locality fix -- same
  flat-ratio signature N149 showed. But the flat line sits at ~0.54, capped by occupancy,
  far below the 64x64+Hilbert flat line at ~0.83.
- **Conclusion: the L2-locality unlock does NOT change the tile-size tradeoff on RTX 5070.**
  The 128x128 tile's 1-CTA/SM occupancy collapse dominates the per-CTA latency-hiding loss,
  and that loss is independent of (and not recoverable by) the CTA visitation order. Bigger
  tile remains the wrong knob; this corroborates N89's M<=1536 finding and extends it cleanly
  into the large-M regime that N89 never measured.

## Honest g3 caveats

- **Two-sided test, negative arm confirmed.** This is the "if 128x128 still loses to 64x64
  even with Hilbert, N89's finding holds" branch. The result is unambiguous (33-36% deficit,
  all shapes, low variance: std < 0.004 ms), not a marginal call.
- **Non-pow2 launch overhead is real but NOT the cause.** M=5120 (40x40, p=64, 61% padding
  CTAs) and M=6144 (48x48, p=64, 44% padding) launch enclosing p=64 squares with early-return
  padding. Yet the pure-pow2 shapes M=4096 (-35.4%) and M=8192 (-36.3%) -- which launch ZERO
  padding CTAs -- show the SAME deficit. So the loss is the occupancy collapse, not the padding
  launches. (At the 128-tile grid the padding fraction is also lower than N149's 64-tile grid
  since side is halved, e.g. M=8192 is 64x64 pow2 here vs 128x128 pow2 there.)
- **Register count measured, not estimated:** cuFuncGetAttribute reports 47 regs/thd for all 4
  shapes (ptxas_info.log). The compile.log is clean (no spill / occupancy warnings).
- **Bit-exact is the gate, not a bonus:** both the tile geometry (N89) and the swizzle (N149)
  are semantic-preserving; max_abs=0.0 confirms the spliced Hilbert prologue + 128-tile address
  math is correct (the Hilbert d2xy bijection is asserted in the generator before emission).

## Verdict for the RFC 067 SGEMM line

N149's 64x64 + Hilbert (ratio 0.847 @ M=8192) remains the best large-M configuration.
Combining it with the bigger 128x128 tile is a regression: the occupancy ceiling set by
1 CTA/SM is the binding constraint at large M, and no CTA-swizzle can lift it. To make a
128x128 tile competitive on RTX 5070 you would need to restore occupancy (e.g. a persistent
kernel looping a 1-CTA/SM resident over many output tiles, or a 64x128 / 128x64 16-warp
variant at ~32 regs/thd / 512 thd/CTA) -- a different lever entirely from CTA visitation order.

## Artifacts (this dir)

- `gen_sgemm_tile128_hilbert_ptx.py` -- combined PTX generator (4 shapes, bijection-verified)
- `host.c` -- driver with cuBLAS comparator, N149 64x64+Hilbert baselines, ptxas info dump
- `measure.sh` -- plain `ssh ubu-2` driver (NO SIDECAR_NO_POOL)
- `compile.log` -- nvcc build (clean, empty)
- `fire.log` -- 200-rep measurement transcript
- `ptxas_info.log` -- per-shape regs/shmem/max_thd (47 / 16384 / 1024 all shapes)
- `result.json` -- structured measurement + per-shape % over N149
- `sgemm_tile128_hilbert_{4096,5120,6144,8192}x{...}_grid.ptx` -- 4 emitted PTX (pure-ASCII)
