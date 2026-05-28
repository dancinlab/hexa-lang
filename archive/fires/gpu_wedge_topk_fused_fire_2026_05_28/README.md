# F-WEDGE-TOPK-FUSED-WALL fire (2026-05-28)

Falsifier: hand-emit GEMM + streaming top-K fused kernel vs
cublasSgemm + cub::DeviceSegmentedRadixSort. LM-head decode regime.

Shapes:
- decode-8tok-LLaMA-vocab (M=8, K=4096, N=32000)
- small-batch-Qwen-vocab (M=32, K=4096, N=151643)

K_TOP = 8. FP32. cuEvent 20 warmup + 200 timed median.

Source: tool/gpu_wedge_topk_fused_handemit.cu

Host: ubu-2 RTX 5070 sm_120, nvcc driver JIT, $0/run.

See result.json + sweep.log for outcome.
