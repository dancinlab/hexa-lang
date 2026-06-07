/* HEXA-FUSION FF-VALLEY — runtime.c HexaVal wrappers for the persistent
 * VALLEY-ONLY fusion glue kernels. Build splice: APPEND to runtime.c (gitignored
 * amalgam) after hexa_forge_dispatch_clm_megafwd, OR keep in the kit splice bundle.
 *
 * Routes to _hx_cuda_farr_clm_valley1_gpu / _hx_cuda_farr_clm_valley2_gpu (emitted
 * into runtime_cuda.c from self/cuda/runtime_cuda_emit.hexa). Env HEXA_FUSE_VALLEY
 * gates the .hexa call-site; these wrappers route to the cooperative launchers,
 * which return -1 if the device lacks cooperativeLaunch -> the .hexa caller runs the
 * eager separate-kernel glue (the byte-eq reference). The [VALLEY{1,2}-FIRED] probe
 * prints once on the device path. */

/* VALLEY-A: groupnorm#1 + gelu + residual (xt = xec + gelu(hn0)). */
HexaVal hexa_forge_dispatch_clm_valley1(HexaVal h0_v, HexaVal xec_v, HexaVal tgG_v, HexaVal tgB_v,
                                  HexaVal hn0_v, HexaVal mean0_v, HexaVal inv0_v, HexaVal xhat0_v,
                                  HexaVal hg0_v, HexaVal xt_v, HexaVal t_v, HexaVal d_v) {
    int64_t h0_id   = hexa_as_num(h0_v);
    int64_t xec_id  = hexa_as_num(xec_v);
    int64_t tgG_id  = hexa_as_num(tgG_v);
    int64_t tgB_id  = hexa_as_num(tgB_v);
    int64_t hn0_id  = hexa_as_num(hn0_v);
    int64_t mean0_id= hexa_as_num(mean0_v);
    int64_t inv0_id = hexa_as_num(inv0_v);
    int64_t xhat0_id= hexa_as_num(xhat0_v);
    int64_t hg0_id  = hexa_as_num(hg0_v);
    int64_t xt_id   = hexa_as_num(xt_v);
    int64_t T       = hexa_as_num(t_v);
    int64_t D       = hexa_as_num(d_v);
    if (T <= 0 || D <= 0) return hexa_int(-1);
    if (h0_id < 0 || xec_id < 0 || xt_id < 0) return hexa_int(-1);
#ifdef HEXA_CUDA
    extern int _hx_cuda_farr_clm_valley1_gpu(
        int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
        int64_t, int64_t, int64_t, int64_t);
    int grc = _hx_cuda_farr_clm_valley1_gpu(
        h0_id, xec_id, tgG_id, tgB_id, hn0_id, mean0_id, inv0_id, xhat0_id,
        hg0_id, xt_id, T, D);
    if (grc == 0) return hexa_int(0);
#endif
    return hexa_int(-1);
}

/* VALLEY-B: gelu2 + expert-pack + moe-router(softmax+combine) + groupnorm#2. */
HexaVal hexa_forge_dispatch_clm_valley2(HexaVal eo0_v, HexaVal eo1_v, HexaVal logits_r_v,
                                  HexaVal noG_v, HexaVal noB_v, HexaVal ex_out_v, HexaVal probs_v,
                                  HexaVal y_v, HexaVal yn_v, HexaVal meanN_v, HexaVal invN_v,
                                  HexaVal xhatN_v, HexaVal t_v, HexaVal d_v, HexaVal e_v) {
    int64_t eo0_id  = hexa_as_num(eo0_v);
    int64_t eo1_id  = hexa_as_num(eo1_v);
    int64_t logr_id = hexa_as_num(logits_r_v);
    int64_t noG_id  = hexa_as_num(noG_v);
    int64_t noB_id  = hexa_as_num(noB_v);
    int64_t exout_id= hexa_as_num(ex_out_v);
    int64_t probs_id= hexa_as_num(probs_v);
    int64_t y_id    = hexa_as_num(y_v);
    int64_t yn_id   = hexa_as_num(yn_v);
    int64_t meanN_id= hexa_as_num(meanN_v);
    int64_t invN_id = hexa_as_num(invN_v);
    int64_t xhatN_id= hexa_as_num(xhatN_v);
    int64_t T       = hexa_as_num(t_v);
    int64_t D       = hexa_as_num(d_v);
    int64_t E       = hexa_as_num(e_v);
    if (T <= 0 || D <= 0 || E <= 0) return hexa_int(-1);
    if (eo0_id < 0 || eo1_id < 0 || logr_id < 0 || y_id < 0 || yn_id < 0) return hexa_int(-1);
#ifdef HEXA_CUDA
    extern int _hx_cuda_farr_clm_valley2_gpu(
        int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
        int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t);
    int grc = _hx_cuda_farr_clm_valley2_gpu(
        eo0_id, eo1_id, logr_id, noG_id, noB_id, exout_id, probs_id, y_id, yn_id,
        meanN_id, invN_id, xhatN_id, T, D, E);
    if (grc == 0) return hexa_int(0);
#endif
    return hexa_int(-1);
}

HexaVal forge_dispatch_clm_valley1(HexaVal h0_v, HexaVal xec_v, HexaVal tgG_v, HexaVal tgB_v,
                                  HexaVal hn0_v, HexaVal mean0_v, HexaVal inv0_v, HexaVal xhat0_v,
                                  HexaVal hg0_v, HexaVal xt_v, HexaVal t_v, HexaVal d_v) {
    return hexa_forge_dispatch_clm_valley1(h0_v, xec_v, tgG_v, tgB_v, hn0_v, mean0_v,
                                  inv0_v, xhat0_v, hg0_v, xt_v, t_v, d_v);
}
HexaVal forge_dispatch_clm_valley2(HexaVal eo0_v, HexaVal eo1_v, HexaVal logits_r_v,
                                  HexaVal noG_v, HexaVal noB_v, HexaVal ex_out_v, HexaVal probs_v,
                                  HexaVal y_v, HexaVal yn_v, HexaVal meanN_v, HexaVal invN_v,
                                  HexaVal xhatN_v, HexaVal t_v, HexaVal d_v, HexaVal e_v) {
    return hexa_forge_dispatch_clm_valley2(eo0_v, eo1_v, logits_r_v, noG_v, noB_v, ex_out_v,
                                  probs_v, y_v, yn_v, meanN_v, invN_v, xhatN_v, t_v, d_v, e_v);
}
