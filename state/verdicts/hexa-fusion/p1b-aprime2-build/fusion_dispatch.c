/* fusion_dispatch.c — P1B-a'' reconstructed L3-fusion + megafwd dispatchers.
 *
 * The l3d-build self/runtime.c base (Jun-3) has every PER-OP dispatcher the
 * P1B-a'' clm_prod.c needs (groupnorm/gelu/moe_router/embedding/residual/…)
 * but NOT the 5 FUSED ops the fusion clm_prod.c also calls:
 *   forge_dispatch_gelu2                    (L3-b — fuse the 2 expert GELUs)
 *   forge_dispatch_groupnorm_gelu           (L3-a — GN+GELU)
 *   forge_dispatch_groupnorm_gelu_residual  (L3-a' — GN+GELU+residual)
 *   forge_dispatch_moe_block2               (L3 — gelu2+pack2+router block)
 *   forge_dispatch_clm_megafwd              (the cooperative megakernel)
 * The matching `_hx_cuda_farr_<op>_gpu` launchers ARE in the racefix
 * runtime_cuda.c; clm_prod.c calls the BARE `forge_dispatch_<op>` symbol
 * (one direct C call each), so this file supplies those bare wrappers.
 *
 * Each wrapper mirrors the l3d hexa_forge_dispatch_groupnorm pattern verbatim:
 * extract farr ids via hexa_as_num, reject bad ids/dims, gate on HEXA_CUDA,
 * call the launcher, return hexa_int(0) on grc==0 else hexa_int(-1) so the
 * clm_prod.c gate falls through to the eager glue on any miss. Launcher
 * arg-order is 1:1 with the clm_prod.c call (verified against runtime_cuda.c).
 */
#include "runtime.h"
#include <stdint.h>

#ifdef HEXA_CUDA
extern int _hx_cuda_farr_gelu2_gpu(int64_t, int64_t, int64_t, int64_t, int64_t);
extern int _hx_cuda_farr_groupnorm_gelu_gpu(int64_t, int64_t, int64_t, int64_t,
                                            int64_t, int64_t, int64_t, int64_t,
                                            int64_t, int64_t, int64_t);
extern int _hx_cuda_farr_groupnorm_gelu_residual_gpu(int64_t, int64_t, int64_t,
                                            int64_t, int64_t, int64_t, int64_t,
                                            int64_t, int64_t, int64_t,
                                            int64_t, int64_t, int64_t);
extern int _hx_cuda_farr_moe_block2_gpu(int64_t, int64_t, int64_t, int64_t,
                                        int64_t, int64_t, int64_t, int64_t,
                                        int64_t, int64_t, int64_t);
extern int _hx_cuda_farr_clm_megafwd_gpu(
    int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
    int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
    int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
    int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
    int64_t, int64_t, int64_t, int64_t, int);
#endif

/* ── L3-b: gelu2(g0,a0,g1,a1,n) ──────────────────────────────────────── */
HexaVal forge_dispatch_gelu2(HexaVal g0_v, HexaVal a0_v, HexaVal g1_v,
                             HexaVal a1_v, HexaVal n_v) {
    int64_t g0 = hexa_as_num(g0_v), a0 = hexa_as_num(a0_v);
    int64_t g1 = hexa_as_num(g1_v), a1 = hexa_as_num(a1_v);
    int64_t n  = hexa_as_num(n_v);
    if (n <= 0 || g0 < 0 || a0 < 0 || g1 < 0 || a1 < 0) return hexa_int(-1);
#ifdef HEXA_CUDA
    if (_hx_cuda_farr_gelu2_gpu(g0, a0, g1, a1, n) == 0) return hexa_int(0);
#endif
    return hexa_int(-1);
}

/* ── L3-a: groupnorm_gelu(x,gamma,beta,y,a,mean,inv,xhat,T,C,G) ───────── */
HexaVal forge_dispatch_groupnorm_gelu(HexaVal x_v, HexaVal gamma_v, HexaVal beta_v,
                                      HexaVal y_v, HexaVal a_v, HexaVal mean_v,
                                      HexaVal inv_v, HexaVal xhat_v,
                                      HexaVal t_v, HexaVal c_v, HexaVal g_v) {
    int64_t x = hexa_as_num(x_v), gm = hexa_as_num(gamma_v), bt = hexa_as_num(beta_v);
    int64_t y = hexa_as_num(y_v), a = hexa_as_num(a_v), mn = hexa_as_num(mean_v);
    int64_t iv = hexa_as_num(inv_v), xh = hexa_as_num(xhat_v);
    int64_t T = hexa_as_num(t_v), C = hexa_as_num(c_v), G = hexa_as_num(g_v);
    if (T <= 0 || C <= 0 || G <= 0 || (C % G) != 0) return hexa_int(-1);
    if (x < 0 || gm < 0 || bt < 0 || y < 0 || a < 0) return hexa_int(-1);
    if (mn < 0 || iv < 0 || xh < 0) return hexa_int(-1);
#ifdef HEXA_CUDA
    if (_hx_cuda_farr_groupnorm_gelu_gpu(x, gm, bt, y, a, mn, iv, xh, T, C, G) == 0)
        return hexa_int(0);
#endif
    return hexa_int(-1);
}

/* ── L3-a': groupnorm_gelu_residual(x,gamma,beta,r,y,a,out,mean,inv,xhat,T,C,G) ── */
HexaVal forge_dispatch_groupnorm_gelu_residual(
        HexaVal x_v, HexaVal gamma_v, HexaVal beta_v, HexaVal r_v,
        HexaVal y_v, HexaVal a_v, HexaVal out_v, HexaVal mean_v,
        HexaVal inv_v, HexaVal xhat_v,
        HexaVal t_v, HexaVal c_v, HexaVal g_v) {
    int64_t x = hexa_as_num(x_v), gm = hexa_as_num(gamma_v), bt = hexa_as_num(beta_v);
    int64_t r = hexa_as_num(r_v), y = hexa_as_num(y_v), a = hexa_as_num(a_v);
    int64_t out = hexa_as_num(out_v), mn = hexa_as_num(mean_v);
    int64_t iv = hexa_as_num(inv_v), xh = hexa_as_num(xhat_v);
    int64_t T = hexa_as_num(t_v), C = hexa_as_num(c_v), G = hexa_as_num(g_v);
    if (T <= 0 || C <= 0 || G <= 0 || (C % G) != 0) return hexa_int(-1);
    if (x < 0 || gm < 0 || bt < 0 || r < 0 || y < 0 || a < 0 || out < 0) return hexa_int(-1);
    if (mn < 0 || iv < 0 || xh < 0) return hexa_int(-1);
#ifdef HEXA_CUDA
    if (_hx_cuda_farr_groupnorm_gelu_residual_gpu(x, gm, bt, r, y, a, out, mn, iv, xh, T, C, G) == 0)
        return hexa_int(0);
#endif
    return hexa_int(-1);
}

/* ── L3: moe_block2(eo0,eo1,logits,ex0,ex1,ex_out,probs,y,T,E,C) ──────── */
HexaVal forge_dispatch_moe_block2(HexaVal eo0_v, HexaVal eo1_v, HexaVal logits_v,
                                  HexaVal ex0_v, HexaVal ex1_v, HexaVal ex_out_v,
                                  HexaVal probs_v, HexaVal y_v,
                                  HexaVal t_v, HexaVal e_v, HexaVal c_v) {
    int64_t eo0 = hexa_as_num(eo0_v), eo1 = hexa_as_num(eo1_v), lg = hexa_as_num(logits_v);
    int64_t ex0 = hexa_as_num(ex0_v), ex1 = hexa_as_num(ex1_v), exo = hexa_as_num(ex_out_v);
    int64_t pr = hexa_as_num(probs_v), y = hexa_as_num(y_v);
    int64_t T = hexa_as_num(t_v), E = hexa_as_num(e_v), C = hexa_as_num(c_v);
    if (T <= 0 || E <= 0 || C <= 0) return hexa_int(-1);
    if (eo0 < 0 || eo1 < 0 || lg < 0 || ex0 < 0 || ex1 < 0 || exo < 0 || pr < 0 || y < 0)
        return hexa_int(-1);
#ifdef HEXA_CUDA
    if (_hx_cuda_farr_moe_block2_gpu(eo0, eo1, lg, ex0, ex1, exo, pr, y, T, E, C) == 0)
        return hexa_int(0);
#endif
    return hexa_int(-1);
}

/* ── megafwd: the cooperative megakernel (37 farr ids + T,D,E,K) ──────── */
HexaVal forge_dispatch_clm_megafwd(
        HexaVal xe, HexaVal ecW, HexaVal ecB, HexaVal tcW, HexaVal tcB,
        HexaVal tgG, HexaVal tgB, HexaVal xec, HexaVal hn0, HexaVal hg0,
        HexaVal xt, HexaVal mean0, HexaVal inv0, HexaVal xhat0,
        HexaVal rW, HexaVal rB, HexaVal logr, HexaVal e0W, HexaVal e0B,
        HexaVal e1W, HexaVal e1B, HexaVal eo0, HexaVal eo1, HexaVal exout,
        HexaVal probs, HexaVal y, HexaVal noG, HexaVal noB, HexaVal yn,
        HexaVal meanN, HexaVal invN, HexaVal xhatN,
        HexaVal t_v, HexaVal d_v, HexaVal e_v, HexaVal k_v) {
    int64_t T = hexa_as_num(t_v), D = hexa_as_num(d_v),
            E = hexa_as_num(e_v), K = hexa_as_num(k_v);
    if (T <= 0 || D <= 0 || E <= 0 || K <= 0) return hexa_int(-1);
#ifdef HEXA_CUDA
    /* [MEGAFWD-FIRED] is emitted by the launcher itself only when the
     * cooperative kernel actually launches — do NOT double-emit here. */
    int grc = _hx_cuda_farr_clm_megafwd_gpu(
        hexa_as_num(xe), hexa_as_num(ecW), hexa_as_num(ecB), hexa_as_num(tcW), hexa_as_num(tcB),
        hexa_as_num(tgG), hexa_as_num(tgB), hexa_as_num(xec), hexa_as_num(hn0), hexa_as_num(hg0),
        hexa_as_num(xt), hexa_as_num(mean0), hexa_as_num(inv0), hexa_as_num(xhat0),
        hexa_as_num(rW), hexa_as_num(rB), hexa_as_num(logr), hexa_as_num(e0W), hexa_as_num(e0B),
        hexa_as_num(e1W), hexa_as_num(e1B), hexa_as_num(eo0), hexa_as_num(eo1), hexa_as_num(exout),
        hexa_as_num(probs), hexa_as_num(y), hexa_as_num(noG), hexa_as_num(noB), hexa_as_num(yn),
        hexa_as_num(meanN), hexa_as_num(invN), hexa_as_num(xhatN),
        T, D, E, K, 0);
    if (grc == 0) return hexa_int(0);
#endif
    return hexa_int(-1);
}
