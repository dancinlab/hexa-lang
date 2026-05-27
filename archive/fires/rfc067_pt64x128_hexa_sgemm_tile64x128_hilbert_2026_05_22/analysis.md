# RFC 067 PT64x128 -- 64x128 output tile, 16 warps (512 thd) + Hilbert CTA-swizzle

**Date:** 2026-05-22 | **Host:** ubu-1 (NVIDIA GeForce RTX 5070, sm_120, 48 SMs, driver 13000, CUDA rt 12090)
**Falsifier:** F-RFC067-HEXA-SGEMM-TILE64x128-HILBERT
**Status:** PASS (bit-exact all shapes) -- headline result is a NEGATIVE: 64x128 does NOT beat 64x64.

## Tile configuration

- **64x128 output tile** (64 M-rows x 128 N-cols), **16 warps = 512 thd/CTA**.
- Warp grid 4x4: `m_tile = warp>>2` in [0,4) (16-row band), `n_tile = warp&3` in [0,4) (32-col band).
- Per warp: 16 rows x 32 cols = **4x mma.m16n8k16 per K-step**, 16 f32 acc/lane. MMA body
  byte-identical to N151 PT128H / N89 PS (only the A slab is half-height: 64 rows vs 128).
- K-tile 16. Shared-mem per slot: A = 64x16 fp16 = 2048 B, B = 128x16 fp16 = 4096 B.
  Double-buffered = **12288 B / CTA** (vs N151's 16384, vs N149's 8192).
- Cooperative load: A tile (2048 B = 128 vec16) loaded by tids [0,128); B tile (4096 B = 256
  vec16) loaded by tids [0,256). `cp.async.cg` 16-B vectorised, predicated `@%pload_a`/`@%pload_b`.
- **Hilbert d2xy CTA-swizzle on an ASYMMETRIC grid**: gx = N/128 (N-tiles), gy = N/64 (M-tiles).
  p = next_pow2(max(gx,gy)); launch p x p; d = ctaid.y*p + ctaid.x; (sw_x,sw_y) = hilbert_d2xy(p,d);
  early-return padding (sw_x>=gx || sw_y>=gy). Bijection verified per shape at gen time. d2xy
  unrolled (log2(p) rounds, no runtime loop). PTX is pure-ASCII.

## Measured occupancy (the central lever)

**42 regs/thd, 12288 B shmem -> 3 CTAs/SM** (constant across all 4 shapes). The binding
constraint is **registers**: 65536 / (42 * 512) = 3.04 -> 3 (shmem allows 8, threads allow 4).

This lands EXACTLY where N151's recommendation predicted: ~32 regs / 512 thd to restore occupancy.
Measured 42 regs (a bit above the 32 estimate) / 512 thd -> 3 CTAs/SM -- genuinely in the MIDDLE
between N107's ~8 CTAs/SM (64x64, 128 thd) and N151's 1 CTA/SM (128x128, 1024 thd). The occupancy
collapse that killed N151 IS recovered.

## Results (200 reps, 20 warmup, cuEvent sync each launch)

| M    | hexa TFLOPS | ratio vs cuBLAS | regs | CTAs/SM | maxabs | vs N149 64x64+Hilbert | vs N151 128x128+Hilbert |
|------|-------------|-----------------|------|---------|--------|------------------------|--------------------------|
| 4096 | 46.479      | 0.6701          | 42   | 3       | 0.0    | -18.45% (N149 56.99)   | +26.2%  (N151 36.84)     |
| 5120 | 47.436      | 0.6804          | 42   | 3       | 0.0    | -17.77% (N149 57.69)   | +24.7%  (N151 38.05)     |
| 6144 | 47.769      | 0.6814          | 42   | 3       | 0.0    | -18.32% (N149 58.49)   | +22.5%  (N151 38.98)     |
| 8192 | 47.296      | 0.6739          | 42   | 3       | 0.0    | -20.48% (N149 59.48)   | +24.9%  (N151 37.88)     |

- **Peak: 47.769 TFLOPS @ M=6144** (ratio 0.681).
- cuBLAS HGEMM baseline held ~69.4-70.2 TFLOPS across the sweep (matches N149/N151 substrate).
- **Bit-exact PASS** at every shape: maxabs = 0.0, maxrel = 0.0 vs cuBLAS HGEMM. Falsifier PASS.

## Headline: did the middle tile beat 64x64?

**NO.** 64x128 (middle occupancy, 512 thd) LOSES to N149's 64x64+Hilbert by **-17.8% to -20.5%**
across the entire large-M sweep. The loss is monotone-ish and worst at M=8192 (-20.5%), exactly
where N149's 64x64+Hilbert peaks (ratio 0.847).

It DOES beat N151's occupancy-dead 128x128+Hilbert by +22-26% (ratio 0.67 vs ~0.54), confirming
the occupancy recovery is real and substantial -- but recovering occupancy was not enough to
overtake the 64x64 baseline.

## Honest g3 interpretation -- this is the STRONG STRUCTURAL FINDING branch

Per the pre-registered two-sided test:

> "If 64x128 matches/loses to 64x64 (no gain), tile size beyond 64x64 doesn't help on RTX 5070
> even at the right occupancy -- 64x64 4-warp is structurally optimal. Strong structural finding."

We are firmly in this branch, and it is now triangulated by three points along the
output-per-CTA / occupancy axis at fixed large M:

  - **64x64,   128 thd,  ~8 CTAs/SM (N149):  ratio 0.821-0.847  -- BEST**
  - **64x128,  512 thd,   3 CTAs/SM (this):  ratio 0.670-0.681  -- MIDDLE**
  - **128x128, 1024 thd,  1 CTA/SM  (N151):  ratio 0.526-0.550  -- WORST**

The ratio is **monotone-increasing in CTAs/SM** (equivalently monotone-DECREASING in tile size /
thd-per-CTA) at fixed large M. The middle occupancy point (3 CTAs/SM) sits cleanly between the
two endpoints, both in occupancy AND in performance. This rules out the alternative hypothesis
that N151 failed only because of an EXTREME occupancy cliff (1 CTA/SM = no inter-CTA latency
hiding at all): a comfortable 3 CTAs/SM still underperforms 64x64 by ~18-20%. There is no
"sweet spot" at 512 thd -- more output-per-CTA monotonically hurts on this SM in this regime.

**Conclusion:** on the RTX 5070 (sm_120), bigger output tiles than 64x64 are the WRONG knob for
large-M HGEMM even after the occupancy collapse is repaired. The structural reason: a 64x64
4-warp tile already saturates the SM's tensor-core throughput while keeping ~8 resident CTAs for
deep latency hiding; enlarging the tile trades that latency-hiding depth for L2/working-set
locality the Hilbert swizzle already provides cheaply at 64x64. The win lever in this RFC 067
SGEMM line remains the CTA-VISITATION ORDER (Hilbert L2 reuse, N149), NOT the tile geometry.
N149's 64x64+Hilbert (M=8192 ratio 0.847) stands as the best large-M config.

This corroborates N123 ("warp-count axis INERT at fixed tile") from the orthogonal direction:
the warp-count/tile-size axis simply does not buy throughput on this SM once 64x64 is reached;
data movement / visitation order does.

## Cost / honesty notes

- regs/thd = 42 (above the ~32 N151 estimate; the 16-warp 4x4 indexing + asymmetric-grid Hilbert
  prologue costs a few extra registers). Even so the register limit (3 CTAs/SM) is the binding
  occupancy constraint, not shmem (8) or threads (4).
- Asymmetric grid (gx=N/128 N-tiles x gy=N/64 M-tiles) means more padding-return CTAs on non-pow2
  shapes than the symmetric 64x64 grid: M=5120 launches 16384, only 3200 real (13184 padding,
  80%); M=6144 launches 16384, 4608 real (72% padding). These padding CTAs early-return with no
  MMA work but consume scheduler slots -- a real (small) cost folded into the measured numbers,
  and part of why the asymmetric 64x128 tile is at a structural disadvantage vs the square grids.
  M=4096 (gx=32, gy=64, p=64, 50% padding) and M=8192 (gx=64, gy=128, p=128, 50% padding) are
  cleaner but still 50% padding due to the 2:1 aspect ratio forcing a square enclosing power-of-2.
- All four shapes bit-exact (maxabs=0.0) -- the 64x128 geometry + asymmetric Hilbert bijection is
  numerically correct; the MMA math is byte-identical to N151/N89.
- Fire: plain `ssh ubu-1` (no SIDECAR_NO_POOL), driver-JIT pure-ASCII PTX, clean nvcc compile.
