/* HEXA-FUSION B3 (REAL-TRAINER) — runtime.c HexaVal wrapper for the full-fwd
 * clm_prod MEGAKERNEL. Build splice: APPEND this to runtime.c (gitignored
 * amalgam) after the hexa_forge_dispatch_moe_block2 wrappers, OR keep it in the
 * kit splice bundle. Mirrors hexa_forge_dispatch_moe_block2 / the P2A
 * megakernel_wrapper.c exactly, extended to the WHOLE fwd DAG operands.
 *
 * Routes to _hx_cuda_farr_clm_megafwd_gpu (emitted into runtime_cuda.c from
 * self/cuda/runtime_cuda_emit.hexa — the B2 _hx_k_clm_megafwd cooperative
 * kernel, PR #2743). Env HEXA_CLM_MEGASTEP gates the .hexa call-site
 * (_clm_megafwd in stdlib/flame/clm_prod.hexa); this wrapper just routes to the
 * cooperative launcher, which returns -1 if the device lacks cooperativeLaunch
 * OR if the TF32-own-GEMM precision-eq contract is not asserted -> the .hexa
 * caller runs the eager FP64 fwd (the byte-eq reference). The [MEGAFWD-FIRED]
 * probe prints once on the device path. */
HexaVal hexa_forge_dispatch_clm_megafwd(HexaVal xe_v, HexaVal ecWq_v, HexaVal ecB_v,
                                  HexaVal tcWq_v, HexaVal tcB_v, HexaVal tgG_v, HexaVal tgB_v,
                                  HexaVal xec_v, HexaVal hn0_v, HexaVal hg0_v, HexaVal xt_v,
                                  HexaVal mean0_v, HexaVal inv0_v, HexaVal xhat0_v,
                                  HexaVal rWq_v, HexaVal rB_v, HexaVal logits_r_v,
                                  HexaVal e0Wq_v, HexaVal e0B_v, HexaVal e1Wq_v, HexaVal e1B_v,
                                  HexaVal eo0_v, HexaVal eo1_v, HexaVal ex_out_v, HexaVal probs_v, HexaVal y_v,
                                  HexaVal noG_v, HexaVal noB_v, HexaVal yn_v, HexaVal meanN_v,
                                  HexaVal invN_v, HexaVal xhatN_v,
                                  HexaVal t_v, HexaVal d_v, HexaVal e_v, HexaVal k_v) {
    int64_t xe_id   = hexa_as_num(xe_v);
    int64_t ecWq_id = hexa_as_num(ecWq_v);
    int64_t ecB_id  = hexa_as_num(ecB_v);
    int64_t tcWq_id = hexa_as_num(tcWq_v);
    int64_t tcB_id  = hexa_as_num(tcB_v);
    int64_t tgG_id  = hexa_as_num(tgG_v);
    int64_t tgB_id  = hexa_as_num(tgB_v);
    int64_t xec_id  = hexa_as_num(xec_v);
    int64_t hn0_id  = hexa_as_num(hn0_v);
    int64_t hg0_id  = hexa_as_num(hg0_v);
    int64_t xt_id   = hexa_as_num(xt_v);
    int64_t mean0_id= hexa_as_num(mean0_v);
    int64_t inv0_id = hexa_as_num(inv0_v);
    int64_t xhat0_id= hexa_as_num(xhat0_v);
    int64_t rWq_id  = hexa_as_num(rWq_v);
    int64_t rB_id   = hexa_as_num(rB_v);
    int64_t logr_id = hexa_as_num(logits_r_v);
    int64_t e0Wq_id = hexa_as_num(e0Wq_v);
    int64_t e0B_id  = hexa_as_num(e0B_v);
    int64_t e1Wq_id = hexa_as_num(e1Wq_v);
    int64_t e1B_id  = hexa_as_num(e1B_v);
    int64_t eo0_id  = hexa_as_num(eo0_v);
    int64_t eo1_id  = hexa_as_num(eo1_v);
    int64_t exout_id= hexa_as_num(ex_out_v);
    int64_t probs_id= hexa_as_num(probs_v);
    int64_t y_id    = hexa_as_num(y_v);
    int64_t noG_id  = hexa_as_num(noG_v);
    int64_t noB_id  = hexa_as_num(noB_v);
    int64_t yn_id   = hexa_as_num(yn_v);
    int64_t meanN_id= hexa_as_num(meanN_v);
    int64_t invN_id = hexa_as_num(invN_v);
    int64_t xhatN_id= hexa_as_num(xhatN_v);
    int64_t T       = hexa_as_num(t_v);
    int64_t D       = hexa_as_num(d_v);
    int64_t E       = hexa_as_num(e_v);
    int64_t K       = hexa_as_num(k_v);
    if (T <= 0 || D <= 0 || E <= 0 || K <= 0) return hexa_int(-1);
    if (xe_id < 0 || ecWq_id < 0 || tcWq_id < 0 || rWq_id < 0) return hexa_int(-1);
    if (xt_id < 0 || yn_id < 0 || eo0_id < 0 || eo1_id < 0 || y_id < 0) return hexa_int(-1);
#ifdef HEXA_CUDA
    extern int _hx_cuda_farr_clm_megafwd_gpu(
        int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
        int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
        int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
        int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
        int64_t, int64_t, int64_t, int64_t, int64_t,
        int64_t, int64_t, int64_t, int64_t);
    int grc = _hx_cuda_farr_clm_megafwd_gpu(
        xe_id, ecWq_id, ecB_id, tcWq_id, tcB_id, tgG_id, tgB_id,
        xec_id, hn0_id, hg0_id, xt_id, mean0_id, inv0_id, xhat0_id,
        rWq_id, rB_id, logr_id, e0Wq_id, e0B_id, e1Wq_id, e1B_id,
        eo0_id, eo1_id, exout_id, probs_id, y_id, noG_id, noB_id,
        yn_id, meanN_id, invN_id, xhatN_id, T, D, E, K, /*assert_eq=*/0);
    if (grc == 0) {
        static int _b3_fired = 0;
        if (!_b3_fired) { _b3_fired = 1; fprintf(stderr, "[MEGAFWD-FIRED]\n"); }
        return hexa_int(0);
    }
#endif
    return hexa_int(-1);
}
HexaVal forge_dispatch_clm_megafwd(HexaVal xe_v, HexaVal ecWq_v, HexaVal ecB_v,
                                  HexaVal tcWq_v, HexaVal tcB_v, HexaVal tgG_v, HexaVal tgB_v,
                                  HexaVal xec_v, HexaVal hn0_v, HexaVal hg0_v, HexaVal xt_v,
                                  HexaVal mean0_v, HexaVal inv0_v, HexaVal xhat0_v,
                                  HexaVal rWq_v, HexaVal rB_v, HexaVal logits_r_v,
                                  HexaVal e0Wq_v, HexaVal e0B_v, HexaVal e1Wq_v, HexaVal e1B_v,
                                  HexaVal eo0_v, HexaVal eo1_v, HexaVal ex_out_v, HexaVal probs_v, HexaVal y_v,
                                  HexaVal noG_v, HexaVal noB_v, HexaVal yn_v, HexaVal meanN_v,
                                  HexaVal invN_v, HexaVal xhatN_v,
                                  HexaVal t_v, HexaVal d_v, HexaVal e_v, HexaVal k_v) {
    return hexa_forge_dispatch_clm_megafwd(xe_v, ecWq_v, ecB_v, tcWq_v, tcB_v, tgG_v, tgB_v,
                                  xec_v, hn0_v, hg0_v, xt_v, mean0_v, inv0_v, xhat0_v,
                                  rWq_v, rB_v, logits_r_v, e0Wq_v, e0B_v, e1Wq_v, e1B_v,
                                  eo0_v, eo1_v, ex_out_v, probs_v, y_v, noG_v, noB_v,
                                  yn_v, meanN_v, invN_v, xhatN_v, t_v, d_v, e_v, k_v);
}
