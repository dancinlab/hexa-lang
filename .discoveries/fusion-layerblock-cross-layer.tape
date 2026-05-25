@V := "tape" :: spec [active]
  version = "1.2"

@I := "fusion-layerblock-cross-layer-discovery" :: identity [active]
  brief = "Discovery log — whole-graph cross-layer transformer-block fusion (GPU axis C moat)."
  flow  = "discovery -> CLAIMS.tape -> hexa verify (g5) -> .verdicts/ -> paper_on_discovery (round 9 once timed wall lands)"

# ----------------------------------------------------------------------
# F-FUSION-LAYERBLOCK-CROSS-LAYER -- whole-graph cross-layer fusion moat
# (GPU.md §10 new axis-C row). Round-8 = structural+codegen-clean (BLUE);
# round-9 (separate agent) = timed wall confirmation.

@C disc_fusion_layerblock_cross_layer := "cross-layer transformer-block fusion structurally undercuts PyTorch eager / cuBLAS-using stack: 3 launches vs 11, 9.667x lower activation-HBM, with hexa-emitted PTX ptxas-clean on sm_80/90 and driver-JIT-clean on sm_120 RTX 5070" :: discovery [slug=fusion-layerblock-cross-layer group=GPU]
  id            = "F-FUSION-LAYERBLOCK-CROSS-LAYER"
  axis          = "C  --  whole-graph cross-layer fusion (third moat axis orthogonal to axis-A memory-bound and axis-B compute-bound)"
  seed          = "transformer block { LayerNorm -> QKV-proj -> attn -> OUT-proj -> +residual1 -> LayerNorm -> FFN(up*gate*SiLU*down) -> +residual2 } compiled as 3 cross-layer-fused kernels with intermediate activations held in smem/registers across all seams -- vs PyTorch eager's ~11 per-op launches"
  date          = "2026-05-25"
  host          = "ubu-2 RTX 5070 sm_120 driver 580.159.03  -  CUDA 12.0 ptxas  -  no timed GPU (round-8 deterministic)"
  verdict_tier  = "BLUE SUPPORTED-FORMAL (structural + ptxas-clean codegen); timed wall = DEFERRED round 9"
  target        = "GPU.md §10 NEW axis-C row 'Cross-layer transformer-block fusion vs PyTorch eager stack' (third moat axis -- complements 'Whole-program-fusion >=30%' which closure-criterion is axis-B-style above-cuBLAS)"
  finding       = "structural clause PROVEN closed-form: launches hexa 3 vs eager 11 (3.667x fewer); activation-HBM hexa 3*BSd*4 vs eager (13d+4dff)*BS*4 = 9.667x at dff=4d; ptxas-clean sm_80 (39/32 regs, 0 spill) + sm_90 (32/32 regs, 0 spill) + sm_120 driver-JIT cuModuleLoad rc=0. hexa-native compiled ratio_check.hexa reproduces R = 29/3 = 9.667x exactly across 5 shapes (flame d=768, rfc072 d=1024, gpt3 d=4096)."
  existence     = "flame d=768 12L step1 wall 191-268s vs PyTorch eager 336.85s = 20-43% above PyTorch (commit 28e9d648 2026-05-18, project_flame_phase4d9_closure). axis-C closure-criterion = ABOVE the library/eager stack (NOT at cuBLAS roofline) -- the LIBRARY API itself forbids cross-op fusion, so closure is at the eager-stack ceiling."
  ruled_out     = "N/A round-8 (no wall recorded). round-9 honest-record: structural moat may or may not convert to wall on naive scalar inner GEMMs -- axis-B precedent (F-FUSION-ATTN-WMMA) showed single-CTA TC-fused 9.4-15.5x SLOWER on attn; flame's hand-tuned codegen produced the 3.84x existence proof, so the wall axis is achievable but needs codegen quality, not just fusion topology."
  numeric_plan  = "round-9: f64 CPU reference, rel-err <= 1e-2 per-row-scale (mirrors F-FUSION-ATTENTION-FLASH numeric harness which achieved max_rel ~1e-6)."
  ptxas         = "pure-ASCII; ptxas sm_80 rc=0 (k1 39 regs 3584 stack 0 spill 432 cmem; k2 32 regs 3072 stack 0 spill 424 cmem); ptxas sm_90 rc=0 (both 32 regs 0 spill); driver-JIT sm_120 cuModuleLoad rc=0 both kernels."
  verdict_ptr   = ".verdicts/fusion-layerblock-cross-layer/F-FUSION-LAYERBLOCK-CROSS-LAYER.txt"
  artifact      = "archive/fires/fusion_layerblock_cross_layer_2026_05_25/ {structural_oracle.c, ratio_check.hexa, block_fused_k1.ptx, block_fused_k2.ptx, result.json}"
  next_claim    = "F-FUSION-LAYERBLOCK-CROSS-LAYER-WALL  -- round-9 timed wall on ubu-2 RTX 5070: cuEvent K1+K2 pair vs PyTorch d=768 12L eager 116.286 ms (RFC 072 P1 PROXY, PR #237); rel-err <= 1e-2 vs f64 CPU; flip §10 axis-C box [ ] -> [x] if ratio >= 1 OR honest-RED if structural-moat fails to convert (axis-B precedent)."
