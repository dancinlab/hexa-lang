# gold-v2 campaign — measurement artifacts (#21 device-decode ByteGPT-303M vs PyTorch)

Verdict-bearing logs + guard output from the gold-v2 decode campaign (summer RTX5070 sm_120, 303M h1129). Migrated from summer `/tmp` per the preserve-state rule. Headline: full native-fp32 decode stack reached **1.00× PyTorch-TF32 @N=1 short-gen** (0.73× @gen=240 — attn context-scaling wall).

| state/ file | summer /tmp source | what it is |
|---|---|---|
| gold-v2-consolidation-own-tf32.log | gg_c1_own.log | task#6 gold table: own-TF32 N-sweep |
| gold-v2-consolidation-cublas-tf32.log | gg_c2_cublas.log | task#6: cuBLAS-TF32 N-sweep |
| gold-v2-torch-strictfp32.log / -tf32.log | gg_torch_fp32.log / gg_torch_tf32.log | task#6 torch refs |
| gold-v2-torch-*-fresh.log | gg_torch_{fp32,tf32}_fresh.log | fresh torch refs (r7 phase) |
| gold-v2-torch-gen240.log | gg_torch_gen240.log | torch @gen=240 (context-scaling ref) |
| gold-v2-r1-fexp.log | gg_r1_on.log | r1 fp32 __expf attn (10.35× kernel) |
| gold-v2-r3-junroll.log | gg_r1r3.log | r3 4-row j-unroll (bit-identical) |
| gold-v2-r4-gelu-stacked.log | gg_r4_r1g4.log | r4 fp32-erff GELU (r1+r4) |
| gold-v2-r6-fusedqkv.log | gg_r6u4.log | r6 fused-QKV (+u4) |
| gold-v2-r7-epifuse.log / -plus-r6.log | gg_r7.log / gg_r7r6.log | r7 fused resid+LN (full+r7, +r6) |
| gold-v2-compound-fexp-cublas.log | gg_compound.log | fexp+cuBLAS compound (0.87× @N=1) |
| gold-v2-fullstack-nou4.log / -u4.log | gg_fullstack.log / gg_fsu4.log | full stack ±u4 |
| gold-v2-gen240-x7.log | run_r7long_driver.log | gen=240 ×7 stability (defensible N=1) |
| gold-v2-batched-async-{off,on}.log | gg_batch_{off,on}.log | LEVER-3 batched async neutrality |
| gold-v2-epi_fuse_guard.txt | epi_fuse_guard (re-run) | r7 byte-eq guard PASS |

nsys captures (`/tmp/*.nsys-rep`, binary, ~10MB each) left on summer — kernel-share tables are summarized in the campaign SSOT.
