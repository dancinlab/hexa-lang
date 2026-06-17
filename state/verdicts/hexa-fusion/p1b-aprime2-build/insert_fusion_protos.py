import sys
path = sys.argv[1]
s = open(path).read()
if "P1B-a'' fusion dispatcher protos" in s:
    print("already inserted"); sys.exit(0)
anchor = """HexaVal forge_dispatch_groupnorm(HexaVal x_v, HexaVal gamma_v, HexaVal beta_v,
                             HexaVal y_v, HexaVal mean_v, HexaVal inv_v,
                             HexaVal xhat_v, HexaVal t_v, HexaVal c_v,
                             HexaVal g_v);"""
if anchor not in s:
    print("ANCHOR NOT FOUND"); sys.exit(1)
block = '''

/* P1B-a'' fusion dispatcher protos — the 5 FUSED ops (gelu2 / groupnorm_gelu /
 * groupnorm_gelu_residual / moe_block2 / clm_megafwd) the l3d base lacks.
 * Bodies live in fusion_dispatch.c; these protos let clm_prod.c's direct C
 * calls type-check (without them the call is implicit-int -> "invalid
 * initializer" on `HexaVal rc = forge_dispatch_<op>(...)`). */
HexaVal forge_dispatch_gelu2(HexaVal g0_v, HexaVal a0_v, HexaVal g1_v,
                             HexaVal a1_v, HexaVal n_v);
HexaVal forge_dispatch_groupnorm_gelu(HexaVal x_v, HexaVal gamma_v, HexaVal beta_v,
                                      HexaVal y_v, HexaVal a_v, HexaVal mean_v,
                                      HexaVal inv_v, HexaVal xhat_v,
                                      HexaVal t_v, HexaVal c_v, HexaVal g_v);
HexaVal forge_dispatch_groupnorm_gelu_residual(
        HexaVal x_v, HexaVal gamma_v, HexaVal beta_v, HexaVal r_v,
        HexaVal y_v, HexaVal a_v, HexaVal out_v, HexaVal mean_v,
        HexaVal inv_v, HexaVal xhat_v,
        HexaVal t_v, HexaVal c_v, HexaVal g_v);
HexaVal forge_dispatch_moe_block2(HexaVal eo0_v, HexaVal eo1_v, HexaVal logits_v,
                                  HexaVal ex0_v, HexaVal ex1_v, HexaVal ex_out_v,
                                  HexaVal probs_v, HexaVal y_v,
                                  HexaVal t_v, HexaVal e_v, HexaVal c_v);
HexaVal forge_dispatch_clm_megafwd(
        HexaVal xe, HexaVal ecW, HexaVal ecB, HexaVal tcW, HexaVal tcB,
        HexaVal tgG, HexaVal tgB, HexaVal xec, HexaVal hn0, HexaVal hg0,
        HexaVal xt, HexaVal mean0, HexaVal inv0, HexaVal xhat0,
        HexaVal rW, HexaVal rB, HexaVal logr, HexaVal e0W, HexaVal e0B,
        HexaVal e1W, HexaVal e1B, HexaVal eo0, HexaVal eo1, HexaVal exout,
        HexaVal probs, HexaVal y, HexaVal noG, HexaVal noB, HexaVal yn,
        HexaVal meanN, HexaVal invN, HexaVal xhatN,
        HexaVal t_v, HexaVal d_v, HexaVal e_v, HexaVal k_v);'''
s = s.replace(anchor, anchor + block, 1)
open(path, "w").write(s)
print("inserted OK")
