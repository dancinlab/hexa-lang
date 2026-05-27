# RFC 067 N200 — TMA + named-bar + Hilbert combined SGEMM

**Hypothesis**: cuBLAS catch-up on RTX 5070 sm_120 needs all 3 together:
- TMA `cp.async.bulk.tensor.2d` (N196) for async DMA loads bypassing thread-side cp.async
- Named barriers (`mbarrier.arrive` / `mbarrier.try_wait.parity`) for per-tile sync (N196 mbarrier mode)
- Hilbert d2xy CTA swizzle (N149) for L2 locality at M >= 4096

Builds on N149 4-warp 64x64 HGEMM base. Replaces `cp.async.cg.shared.global` + `bar.sync` with TMA + mbarrier.
