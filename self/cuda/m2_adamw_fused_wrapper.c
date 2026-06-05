/* HEXA-FUSION M2 (FULL-STEP) — runtime.c HexaVal wrapper for the fused
 * cooperative AdamW that collapses the clm_prod optimizer tail (~36 separate
 * _adam launches) into ONE cudaLaunchCooperativeKernel. Build splice: APPEND
 * this to runtime.c (gitignored amalgam) after the b3_clm_megafwd wrapper, OR
 * keep it in the kit splice bundle. Mirrors b3_clm_megafwd_wrapper.c.
 *
 * The .hexa caller (_adam_fused in stdlib/flame/clm_prod.hexa, gated by env
 * HEXA_CLM_FULLSTEP) marshals the param tensors as FIVE packed id/len farrs:
 *   w_ids_v / m_ids_v / v_ids_v / g_ids_v hold the np farr-ids as doubles,
 *   n_v holds the np per-tensor lengths as doubles.
 * This wrapper reads their HOST buffers (HexaFarrEntry.buf), casts to int64,
 * and routes to _hx_cuda_farr_adamw_fused_gpu (emitted into runtime_cuda.c
 * from self/cuda/runtime_cuda_emit.hexa — the _hx_k_adamw_fused cooperative
 * kernel). Returns -1 if the device lacks cooperativeLaunch -> the .hexa caller
 * runs the per-param _adam loop (byte-eq reference). The [FULLSTEP-FIRED] probe
 * prints once on the device path. */
HexaVal hexa_forge_dispatch_adamw_fused(HexaVal w_ids_v, HexaVal m_ids_v,
                                  HexaVal v_ids_v, HexaVal g_ids_v, HexaVal n_v,
                                  HexaVal np_v, HexaVal lr_v, HexaVal b1_v,
                                  HexaVal b2_v, HexaVal eps_v, HexaVal wd_v,
                                  HexaVal t_v) {
    int64_t w_farr  = hexa_as_num(w_ids_v);
    int64_t m_farr  = hexa_as_num(m_ids_v);
    int64_t v_farr  = hexa_as_num(v_ids_v);
    int64_t g_farr  = hexa_as_num(g_ids_v);
    int64_t n_farr  = hexa_as_num(n_v);
    int     np      = (int)hexa_as_num(np_v);
    double  lr      = __hx_to_double(lr_v);
    double  b1      = __hx_to_double(b1_v);
    double  b2      = __hx_to_double(b2_v);
    double  eps     = __hx_to_double(eps_v);
    double  wd      = __hx_to_double(wd_v);
    int64_t step_t  = hexa_as_num(t_v);
    if (np <= 0 || np > 64 || step_t < 1) return hexa_int(-1);
    if (w_farr < 0 || m_farr < 0 || v_farr < 0 || g_farr < 0 || n_farr < 0)
        return hexa_int(-1);
    if (w_farr >= _hx_farr_count || m_farr >= _hx_farr_count ||
        v_farr >= _hx_farr_count || g_farr >= _hx_farr_count ||
        n_farr >= _hx_farr_count) return hexa_int(-1);
#ifdef HEXA_CUDA
    /* the packed id/len farrs must each hold >= np doubles on the host */
    HexaFarrEntry* we = &_hx_farr_table[w_farr];
    HexaFarrEntry* me = &_hx_farr_table[m_farr];
    HexaFarrEntry* ve = &_hx_farr_table[v_farr];
    HexaFarrEntry* ge = &_hx_farr_table[g_farr];
    HexaFarrEntry* ne = &_hx_farr_table[n_farr];
    if (!we->buf || !me->buf || !ve->buf || !ge->buf || !ne->buf) return hexa_int(-1);
    if (we->len < np || me->len < np || ve->len < np || ge->len < np || ne->len < np)
        return hexa_int(-1);
    int64_t w_ids[64], m_ids[64], v_ids[64], g_ids[64], ns[64];
    for (int p = 0; p < np; p++) {
        w_ids[p] = (int64_t)((double*)we->buf)[p];
        m_ids[p] = (int64_t)((double*)me->buf)[p];
        v_ids[p] = (int64_t)((double*)ve->buf)[p];
        g_ids[p] = (int64_t)((double*)ge->buf)[p];
        ns[p]    = (int64_t)((double*)ne->buf)[p];
    }
    extern int _hx_cuda_farr_adamw_fused_gpu(const int64_t*, const int64_t*,
        const int64_t*, const int64_t*, const int64_t*, int,
        double, double, double, double, double, int64_t);
    int grc = _hx_cuda_farr_adamw_fused_gpu(w_ids, m_ids, v_ids, g_ids, ns, np,
                                            lr, b1, b2, eps, wd, step_t);
    if (grc == 0) return hexa_int(0);
#endif
    return hexa_int(-1);
}
HexaVal forge_dispatch_adamw_fused(HexaVal w_ids_v, HexaVal m_ids_v,
                                  HexaVal v_ids_v, HexaVal g_ids_v, HexaVal n_v,
                                  HexaVal np_v, HexaVal lr_v, HexaVal b1_v,
                                  HexaVal b2_v, HexaVal eps_v, HexaVal wd_v,
                                  HexaVal t_v) {
    return hexa_forge_dispatch_adamw_fused(w_ids_v, m_ids_v, v_ids_v, g_ids_v, n_v,
                                  np_v, lr_v, b1_v, b2_v, eps_v, wd_v, t_v);
}
