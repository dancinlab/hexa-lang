# N149 Hilbert cross-host reproduction on ubu-2 (2026-05-22)

Direct re-fire (no sub-agent — Anthropic API 529-overloaded, drove ssh ubu-2 via Bash).
N149 originally fired on ubu-1; this reproduces on ubu-2 (summer, RTX 5070 sm_120, idle load 0.00).

| M | hexa-PHILB TFLOPS | ratio vs cuBLAS | cuBLAS TFLOPS | maxabs |
|------|-------------------|-----------------|---------------|--------|
| 4096 | 57.49 | 0.8207 | 70.04 | 0.0 |
| 5120 | 58.28 | 0.8280 | 70.39 | 0.0 |
| 6144 | 58.53 | 0.8265 | 70.82 | 0.0 |
| 8192 | 59.45 | **0.8397** | 70.80 | 0.0 |

Bit-exact all shapes (maxabs=0, maxrel=0). regs=64, shmem=8192 B, 1024 thd/CTA.
Matches N149 ubu-1 (56.99/57.69/58.49/59.48 TFLOPS, ratio 0.821/0.827/0.834/0.847) within run-to-run + cross-host noise.

**Headline confirmed cross-host**: N149 Hilbert 4-warp 64x64 large-M ratio ~0.82-0.84 reproduces on independent RTX 5070 (ubu-2), bit-exact. Cliff-flattened (no decay 4096→8192). cuBLAS held ~70-71 TFLOPS steady.
