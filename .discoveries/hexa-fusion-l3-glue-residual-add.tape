@discovery := "HEXA-FUSION ⑤/③ first slice — device residual-add glue fusion" :: lane [active]
  id     = "F-CLM-DEVFEED-RESIDUAL-EQ"
  seed   = "③ fwd-only 0% util floor — inter-op host glue (add/gelu/groupnorm/moe-router) still INTERPRETED on host between device GEMM spikes; device-resident tensors necessary but NOT sufficient. First slice = fuse the highest-frequency glue op (residual xt = xec + hg0, T·d host t_get/t_set per step) onto the device."
  target = "🟢 numerical — byte-eq max|Δ|=0 oracle (device residual-add == host scalar add), all F-CLM-DEVFEED-* held at 0.0, env-gated CLM_PROD_DEVRESIDENT default-off byte-identical"
  verdict = ".verdicts/hexa-fusion-l3-glue/F-CLM-DEVFEED-RESIDUAL-EQ.txt"
  result = "F-CLM-DEVFEED-RESIDUAL-EQ = 1 (max|Δ|=0.0); ALL-PASS exit 0; default-off host loop byte-identical to pre-slice inline loop"
  next   = "remaining interpreted glue inventory toward MEAN→20%: nn_gelu_fwd ×3 (hg0/ex0/ex1) · nn_groupnorm_fwd ×2 (h0/y) · expert-pack copy j-loop (T·d) · nn_moe_router_fwd · nn_embedding_fwd gather — each is a host scalar loop between device GEMM spikes; fuse next-highest-freq (gelu epilogue) into adjacent conv epilogue. W2 self-host pod util fire gated on these landing."
