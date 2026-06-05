/* clm_megafwd_dispatch.c — P1B-a'' reconstructed forge_dispatch_clm_megafwd.
 *
 * The P1B-a' (#2779) build added `forge_dispatch_clm_megafwd` to its self/
 * runtime.c, but that tree was NOT bundled into ~/hexa-fusion-cuda-kit (only
 * runtime_cuda.c was checked in). The l3d-build/runtime.c base has every other
 * dispatcher this clm_prod.c needs (gelu2/groupnorm_gelu/moe_block2/…, matching
 * HexaVal layout) — this file supplies the ONE missing symbol so the link
 * closes. It mirrors the l3d hexa_forge_dispatch_moe_block2 pattern verbatim:
 * extract farr ids via hexa_as_num, gate on HEXA_CUDA, call the launcher.
 *
 * Arg order is 1:1 with _clm_megafwd's call in clm_prod.c (the same order as
 * the _hx_cuda_farr_clm_megafwd_gpu launcher params + T,D,E,K, assert_eq=0). */
#include "runtime.h"
#include <stdint.h>
#include <stdio.h>

#ifdef HEXA_CUDA
extern int _hx_cuda_farr_clm_megafwd_gpu(
    int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
    int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
    int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
    int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
    int64_t, int64_t, int64_t, int64_t, int);
#endif

HexaVal hexa_forge_dispatch_clm_megafwd(
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
    /* The [MEGAFWD-FIRED] marker is emitted by the launcher itself (only when the
     * cooperative kernel actually launches) — do NOT double-emit here. */
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
#else
    (void)xe;(void)ecW;(void)ecB;(void)tcW;(void)tcB;(void)tgG;(void)tgB;(void)xec;
    (void)hn0;(void)hg0;(void)xt;(void)mean0;(void)inv0;(void)xhat0;(void)rW;(void)rB;
    (void)logr;(void)e0W;(void)e0B;(void)e1W;(void)e1B;(void)eo0;(void)eo1;(void)exout;
    (void)probs;(void)y;(void)noG;(void)noB;(void)yn;(void)meanN;(void)invN;(void)xhatN;
#endif
    return hexa_int(-1);
}

HexaVal forge_dispatch_clm_megafwd(
    HexaVal xe, HexaVal ecW, HexaVal ecB, HexaVal tcW, HexaVal tcB,
    HexaVal tgG, HexaVal tgB, HexaVal xec, HexaVal hn0, HexaVal hg0,
    HexaVal xt, HexaVal mean0, HexaVal inv0, HexaVal xhat0,
    HexaVal rW, HexaVal rB, HexaVal logr, HexaVal e0W, HexaVal e0B,
    HexaVal e1W, HexaVal e1B, HexaVal eo0, HexaVal eo1, HexaVal exout,
    HexaVal probs, HexaVal y, HexaVal noG, HexaVal noB, HexaVal yn,
    HexaVal meanN, HexaVal invN, HexaVal xhatN,
    HexaVal t_v, HexaVal d_v, HexaVal e_v, HexaVal k_v) {
    return hexa_forge_dispatch_clm_megafwd(
        xe, ecW, ecB, tcW, tcB, tgG, tgB, xec, hn0, hg0, xt, mean0, inv0, xhat0,
        rW, rB, logr, e0W, e0B, e1W, e1B, eo0, eo1, exout, probs, y, noG, noB, yn,
        meanN, invN, xhatN, t_v, d_v, e_v, k_v);
}
