#include "runtime.h"
/* M5 eager-path build against p1kit runtime: the L1/L3 fusion-glue dispatchers
 * are declared in runtime.h but NOT defined in p1kit's runtime.c (they postdate
 * the p1kit snapshot). Define them as no-op stubs returning -1 so each
 * clm_prod.hexa fusion gate (_fuse_on(...)) takes its HOST-FALLBACK branch
 * (byte-eq to the eager reference). The heavy conv GEMMs run on GPU via the
 * p1kit-defined forge_dispatch_matmul / _matmul_batched (UNAFFECTED) — so the
 * GEMM-fill axis (M = B*Tw rows) is measured faithfully on the H100. */
#define ST(name, ...) HexaVal name(__VA_ARGS__){return hexa_int(-1);}
#define H HexaVal
ST(forge_dispatch_adamw_keepmv,H,H,H,H,H,H,H,H,H,H,H)
ST(forge_dispatch_ce_grad,H,H,H,H,H)
ST(forge_dispatch_db_colsum,H,H,H,H)
ST(forge_dispatch_embedding,H,H,H,H,H)
ST(forge_dispatch_embedding_bwd_scatter,H,H,H,H,H,H)
ST(forge_dispatch_expert_pack2,H,H,H,H)
ST(forge_dispatch_expert_unpack2,H,H,H,H)
ST(forge_dispatch_gelu,H,H,H)
ST(forge_dispatch_gelu2,H,H,H,H,H)
ST(forge_dispatch_gelu_bwd,H,H,H,H)
ST(forge_dispatch_grad_sum2,H,H,H,H)
ST(forge_dispatch_grad_sum3,H,H,H,H,H)
ST(forge_dispatch_groupnorm,H,H,H,H,H,H,H,H,H,H)
ST(forge_dispatch_groupnorm_bwd,H,H,H,H,H,H,H,H,H,H)
ST(forge_dispatch_groupnorm_gelu,H,H,H,H,H,H,H,H,H,H,H)
ST(forge_dispatch_groupnorm_gelu_residual,H,H,H,H,H,H,H,H,H,H,H,H,H)
ST(forge_dispatch_int4_quant,H,H,H,H,H,H,H)
ST(forge_dispatch_int4_quant_bwd,H,H,H,H)
ST(forge_dispatch_moe_block2,H,H,H,H,H,H,H,H,H,H,H)
ST(forge_dispatch_moe_router,H,H,H,H,H,H,H)
ST(forge_dispatch_moe_router_bwd,H,H,H,H,H,H,H,H)
ST(forge_dispatch_residual_add,H,H,H,H)
