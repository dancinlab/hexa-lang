# RFC 067 PS -- TILE128 fire analysis (2026-05-21, RTX 5070 sm_120)

## Variant chosen

**V1** -- 128x128 output tile per CTA, 32 warps (1024 thd/CTA), each warp does 4x mma.m16n8k16 per K-step (16 row x 32 col per warp; A frag reused across 2 N sub-tiles).

V2 fallback (64x128) was NOT needed: ptxas fit V1 at 47 regs/thread comfortably; max_thd_per_block reported back as 1024 with no occupancy override needed at load time.

## Headline numbers (median TFLOPS, 200 reps + 20 warmup, cuEvent sync each iter)

| Shape | cuBLAS HGEMM | N77 (PP) | PS tile128 | ratio vs cuBLAS | pct over N77 |
|-------|-------------:|---------:|-----------:|----------------:|-------------:|
| 256   | 4.99         | 4.62     | **2.18**   | 0.437           | **-52.8%**   |
| 384   | 16.77        | 12.25    | **5.58**   | 0.333           | **-54.5%**   |
| 512   | 24.82        | 17.33    | **10.49**  | 0.422           | **-39.5%**   |
| 768   | 47.66        | 29.90    | **25.28**  | 0.530           | **-15.4%**   |
| 1024  | 54.30        | 29.04    | **23.24**  | 0.428           | **-20.0%**   |
| 1536  | 66.60        | 36.06    | **37.07**  | **0.557**       | **+2.81%**   |

**Bit-exact:** maxabs = 0.0 vs cuBLAS HGEMM at all 6 shapes (consumer mma path is identical to N77 -> identical output).

## Peak

**37.07 TFLOPS @ M=1536, ratio 0.557 vs cuBLAS HGEMM 66.60.**

Marginal +2.81% over N77's 36.06 TFLOPS at M=1536.

## Register / occupancy notes (ptxas + cuFuncGetAttribute)

- **regs/thread = 47**. 47 * 1024 = 48128 regs/CTA.
- RTX 5070 (sm_120) has 64K regs/SM.
  - PS: floor(64K / 48128) = **1 CTA/SM** (theoretical max).
  - N77 with 512 thd/CTA at ~32 regs/thread: ~16K regs/CTA -> 3-4 CTA/SM.
- **shmem/CTA = 16384 B**; well under both the 48 KB default and 100 KB sm_120 cap.
- **threads/CTA = 1024** vs sm_120 cap of 1536 thd/SM. With 1 CTA/SM we use only 1024/1536 = 67% of thread budget.
- **Cumulatively: occupancy drops ~3x vs N77.**

## SM-starvation arithmetic at small M

RTX 5070 has 40-48 SMs (exact count varies by SKU). CTA count per kernel:

| Shape | N77 CTAs (64x64) | PS CTAs (128x128) | PS CTA / SM (40) |
|-------|-----------------:|------------------:|-----------------:|
| 256   | 16               | **4**             | 0.10             |
| 384   | 36               | **9**             | 0.225            |
| 512   | 64               | **16**            | 0.4              |
| 768   | 144              | **36**            | 0.9              |
| 1024  | 256              | **64**            | 1.6              |
| 1536  | 576              | **144**           | 3.6              |

For M <= 512, PS has *fewer CTAs than SMs* -> most SMs idle the entire kernel.

For M=1024, 64 CTAs but only 1 CTA/SM occupancy from regs -> ~24-30 SMs idle a chunk of the runtime.

For M=1536, 144 CTAs / 1 CTA-resident = ~3.6 waves on 40 SMs -> close to saturation, hence the only positive (+2.81%).

## Conclusion (g3-honest)

- **Win is marginal** (+2.8% at M=1536) and only at the largest shape tested.
- **Tile128 monolithic is the wrong knob** for RTX 5070 at these shapes; it cuts CTA count by 4x faster than it cuts time-per-CTA, so SM utilisation drops.
- The N48 Apple-M3 finding "wider tile loses to occupancy" **also holds on Nvidia RTX 5070** for the M sweep tested, modulo the very tail where SMs are saturated either way.
- Future direction: **persistent kernel** (1 CTA/SM, looped over multiple output tiles) might claw back the small-M loss while keeping the +2.8% at M=1536; or **V2 64x128 / 128x64** with 16 warps + 2x output -> ~32 regs/thread / 512 thd/CTA -> retain higher occupancy.

## Bit-exact provenance

All 6 shapes: maxabs = 0.0, maxrel = 0.0 vs cuBLAS HGEMM. The mma.m16n8k16 ops are identical to N77; only changes: tile geometry, thread mapping, output store offsets. Bit-equality confirms the new C-store epilogue (4 sub-tile stores at N-offsets 0/32/64/96 B) and reused-A-frag mma scheduling are correct.

## Artifacts (this dir)

- `gen_sgemm_tile128_ptx.py` -- PTX generator (6 shapes)
- `host.c` -- driver with cuBLAS comparator + per-shape ptxas info dump
- `measure.sh` -- plain `ssh ubu-2` driver
- `compile.log` -- nvcc build (clean)
- `fire.log` -- 200-rep measurement transcript
- `ptxas_info.log` -- per-shape regs/shmem/max_thd
- `result.json` -- structured measurement
- `sgemm_tile128_{256,384,512,768,1024,1536}x{...}_grid.ptx` -- 6 emitted PTX (all 128-aligned)
