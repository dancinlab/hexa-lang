# hexa vs cuBLAS — unified comparison (N171 conditional-swizzle production kernel)

Single ubu-2 session (RTX 5070 sm_120, idle), full M range, one binary.
No cross-host/cross-run variance. FP16-in / FP32-acc HGEMM. Bit-exact all shapes (maxabs=0).

| M    | hexa TFLOPS | cuBLAS TFLOPS | ratio   | regime   | note |
|------|-------------|---------------|---------|----------|------|
| 256  |  4.46       |  4.48         | 0.9957  | identity | near-parity (launch-bound) |
| 384  | 15.00       | 11.84         | **1.2669** | identity | 🛸 cuBLAS-BEAT (cuBLAS launch-dip) |
| 512  | 19.76       | 23.05         | 0.8575  | identity | |
| 1024 | 39.29       | 53.18         | 0.7389  | identity | trough (cuBLAS compute-bound engages) |
| 2048 | 54.59       | 66.75         | 0.8178  | identity | |
| 4096 | 57.17       | 70.01         | 0.8166  | identity | |
| 6144 | 59.01       | 70.78         | 0.8336  | hilbert  | swizzle auto-engages (>4096 CTAs) |
| 8192 | 59.45       | 70.46         | 0.8437  | hilbert  | cliff flattened |

## Summary
- **Production single kernel** (N171): identity CTA-map at small M (≤4096 CTAs), Hilbert d2xy at large M — divergence-free runtime branch, regs=64 both paths.
- **cuBLAS-BEAT**: M=384 (1.267× this run); M=256 near-parity (0.996). Small-shape launch-overhead regime where cuBLAS heuristic kernel is itself launch-bound.
- **Compute-bound steady-state**: hexa holds 0.82-0.84 of cuBLAS at M≥4096 (Hilbert flattens the L2 cliff that otherwise collapsed to 0.23 — see N130/N134/N149/N167).
- **Trough at M=1024** (0.739): cuBLAS engages its compute-bound kernel (+49% over launch floor) while hexa's 64×64 tile is mid-transition.
- cuBLAS peak ~70-71 TFLOPS steady M≥4096; hexa ~57-59 TFLOPS.

## Single-session campaign progression (RTX 5070, M=8192 ratio)
N38 baseline 0.263 → N76 ldmatrix 0.46 → N77 stack 0.53 → N107 4-warp → N130 cliff 0.30 → N134 super-block 0.62 → **N149 Hilbert 0.847** → N171 conditional 0.84 unified.

bit-exact maxabs=0 every shape. Direct ubu-2 fire (Anthropic API 529-overloaded, drove via Bash ssh).
