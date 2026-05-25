@V := "tape" :: spec [active]
  version = "1.2"

@I := "fusion-attention-wmma-discovery" :: identity [active]
  brief = "Discovery log — Tensor-Core (wmma) fused flash-attention; round 3 of the GPU §10 moat wall."
  flow  = "discovery → CLAIMS.tape → compiled-hexa oracle (g5 broken on ubu) → .verdicts/ → paper_on_discovery"

# ───────────────────────────────────────────────────────────────────────
# F-FUSION-ATTN-WMMA-WALL — Tensor-Core fused flash-attention (GPU §10).
# Round 2 of 3: codegen + ptxas-clean + $0 structural oracle. The naive-scalar
# round-1 kernel lost the wall (1.4-1.5x slower); this round puts the inner
# QK^T and P.V GEMMs on Tensor Cores (wmma.mma.sync m16n16k16) with the S tile
# resident in shared memory. Wall clause (b) DEFERRED to round 3 (timed fire).

@C disc_fusion_attention_wmma := "Tensor-Core fused flash-attention emits + ptxas-clean + moat preserved; wall deferred" :: discovery [slug=fusion-attention-wmma group=GPU]
  id           = "F-FUSION-ATTN-WMMA-WALL"
  seed         = "softmax(Q K^T / sqrt(d)) V fused in ONE kernel with inner QK^T + P.V GEMMs on wmma.mma.sync m16n16k16 (f16 mul, f32 acc), online softmax, S tile in SHARED MEMORY (never HBM) — the Tensor-Core successor to the naive-scalar round-1 kernel"
  date         = "2026-05-25"
  host         = "ubu-2 RTX 5070 sm_120 driver 580 · CUDA 12.0 V12.0.140 ptxas · GPU uncontended (0%/5MiB)"
  verdict_tier = "🔵 SUPPORTED-FORMAL (codegen + structural moat + Tensor-Core inner GEMMs); wall (b) DEFERRED-to-round-3"
  target       = "§10 cuBLAS-GEMM-fusion wall axis (attention) — the box is already [x] via launch-amort; THIS axis needs the round-3 timed TC wall"
  finding      = "WMMA fused flash-attention EMITS + is ptxas-clean on sm_80/sm_90 (rc=0) + driver-JIT sm_120 (rc=0). 48 regs, 5824 B smem, 0 spill — fits RTX 5070 envelope (65536 regs, 49152 B smem/block). Structural moat PRESERVED: 1 launch + 0 S-HBM (only the final O write touches global; S uses wmma.store.d ...shared.f32). Tensor-Core confirmed: 5 wmma.mma.sync (1 QK^T row.col + 4 P.V row.row) vs round-1 ZERO. Root cause of round-1 wall loss (scalar inner GEMMs) ADDRESSED."
  wall_status  = "DEFERRED-to-round-3 — NOT claimed won (round 1 proved structural != wall; only a real timed silicon fire settles it). Harness ready: fa_wmma_host.c (fused, f64 ref, 20+200 cuEvent) + fa_cublas_tc_baseline.c (cuBLAS TENSOR_OP 3-launch, 20+200 cuEvent), both nvcc -c clean."
  ptxas        = "pure-ASCII (0 non-ascii bytes), ptxas sm_80 rc=0, sm_90 rc=0, driver-JIT sm_120 rc=0; 48 regs / 5824 B smem / 0 spill."
  oracle       = "compiled-hexa structural_oracle.hexa (hexa build + run) PASS — hexa verify g5 broken on both ubu hosts so compiled-hexa per task brief; stdout verbatim in verdict."
  verdict_ptr  = ".verdicts/fusion-attention-wmma/F-FUSION-ATTN-WMMA-WALL.txt"
  artifact     = "archive/fires/fusion_attention_wmma_2026_05_25/ (flash_attn_wmma.ptx + .sm80.ptx + jit_load_probe.c + structural_oracle.hexa + fa_wmma_host.c + fa_cublas_tc_baseline.c + result.json + fire.log)"
  invariants   = "@F f1 no LLVM · @F f2 no C-transpile changes (compiler/codegen/*.hexa UNTOUCHED — hand-emit PTX following RFC 067 WMMA cookbook + _nvptx_wmma_mnemonic emit family)"
  next_claim   = "round 3: timed silicon fire — does the TC-fused flash-attention beat cuBLAS-batched-TC-GEMM+softmax by >=30% wall at N in {512,1024,2048,4096}, d=64? (parent runs serially, uncontended GPU)"
