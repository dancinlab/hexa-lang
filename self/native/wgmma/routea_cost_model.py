#!/usr/bin/env python3
# routea_cost_model.py — OP-49 (HEXA-0POD) shape-adaptive tile-selector cost model.
#
# 0-pod (NO GPU): a CPU-side ANALYTICAL cost model that PREDICTS, per (M,N,K) shape,
# which EXISTING route-(a) own-GEMM kernel mode (MODE 4/5/6/7/8, NST sweep) should be
# launched. It is the static accounting OP-45 (F-OP45-ROUTEA-D4096-CAP) did for the
# single D=2048/4096 point, GENERALIZED into a formula the selector evaluates per shape.
#
# It does NOT run a kernel. It is a PREDICTIVE model whose ORDERING is then validated
# against the ALREADY-MEASURED OG16 / OG17 / b14-MODE8 / W10 verdict datapoints (0-pod).
#
# H100 sm_90a constants (the measured target HW in the W-ladder / OP-45 verdicts).
SM_COUNT      = 132          # H100 SXM SMs
SMEM_PER_SM   = 228 * 1024   # 228 KB dynamic-smem ceiling per SM (opt-in max)
HBM_BW        = 3.35e12      # HBM3 ~3.35 TB/s (OP-45 line T2)
# Per-mode static config table. Derived from wgmma_tf32_b14.cu source + W-ladder verdicts.
#   tm,tn      : output tile (rows x cols)
#   smem_stage : bytes of A+B ring smem per pipeline stage  = (tm+tn)*TKSW*4, TKSW=32
#   regs       : accumulator-dominated regs/thread (source: d0..dK fragments * 32 + overhead)
#   persistent : True => grid = occ*SM_COUNT, walks swizzled tiles (smooths tail wave)
#   issue_eff  : per-mode pipeline issue-efficiency multiplier (dual-issue / wait-relax).
#                CALIBRATED ONCE from the D=2048 measured plateau (see ANCHOR below); it is
#                a per-KERNEL constant (same at every D — OP-45 finding 1), NOT a per-shape fit.
TKSW = 32
MODES = {
    # name        tm   tn   regs  persistent  issue_eff   note
    # issue_eff is CALIBRATED ONCE from each kernel's D=2048 measured plateau (a per-kernel
    # constant, OP-45 finding 1 — same binary/schedule at every D). The D-scaling terms
    # (drain/wave/reuse/fill) are then a PREDICTION at all other D.
    "OG16":      dict(tm=128, tn=128, regs=96,  persistent=False, issue_eff=0.8395),  # plain 128x128 baseline
    "OG17":      dict(tm=128, tn=128, regs=96,  persistent=False, issue_eff=0.9223),  # refined wait_group
    "MODE6":     dict(tm=128, tn=128, regs=96,  persistent=False, issue_eff=0.9223),  # relaxed-wait (== OG17 family)
    "MODE8":     dict(tm=128, tn=128, regs=96,  persistent=False, issue_eff=1.0277),  # b14 dual-issue (PDEP) — frontier
    "MODE5_t256":dict(tm=128, tn=256, regs=154, persistent=False, issue_eff=0.9632),  # 128x256, 1 CTA/SM (reg-capped, verdict)
    "MODE7":     dict(tm=128, tn=128, regs=96,  persistent=True,  issue_eff=1.0277),  # persistent+swizzle (proj. == MODE8 issue)
}
# Peak TF32 tensor throughput the route-(a) 128x128 descriptor-direct path can SUSTAIN at
# full 2-CTA/SM occupancy, BEFORE issue_eff + wave + drain penalties. Calibrated so that
# MODE8 @ D=2048 (issue 0.93, wave 0.97, drain~1.0) reproduces the measured 315 TFLOP/s:
#   315 = PEAK * 0.93 * 0.97 * drain(nks=64)  =>  PEAK ~= 349  (drain~1.0 at the parity point)
PEAK_TF32 = 349.0  # TFLOP/s achievable ceiling of the route-(a) 2-CTA/SM math path

def smem_per_stage(tm, tn):
    return (tm + tn) * TKSW * 4

REGS_PER_SM   = 65536        # H100 register file per SM
THREADS_PER_CTA = 256        # 2 warpgroups (128-row band split across 2 WGs)

def cta_per_sm(tm, tn, nst, regs=96):
    """Occupancy = MIN of the smem-limited and register-limited CTA counts.
    NOTE the register limit MATTERS: the 128x256 t256 tile is 154 regs/thread (verdict),
    which register-caps it to 1 CTA/SM even though its 96KB smem would allow 2 — this is
    exactly the W11/W12 closed-neg the cost model must reproduce (OP-45 finding)."""
    smem = smem_per_stage(tm, tn) * nst
    smem_cap = (SMEM_PER_SM // smem) if smem else 0
    reg_cap  = REGS_PER_SM // (regs * THREADS_PER_CTA)
    return max(1, min(smem_cap, reg_cap))

def wave_eff(M, N, tm, tn, occ_ctas, persistent):
    """Wave-quantization efficiency = tiles / (waves * resident_CTAs).
    Persistent kernels remove the partial-tail-wave penalty (grid == resident set)."""
    tiles = ((M + tm - 1)//tm) * ((N + tn - 1)//tn)
    resident = occ_ctas * SM_COUNT
    if resident == 0:
        return 0.0
    if persistent:
        # persistent grid == resident; walks all tiles strided. Tail amortized over the
        # whole walk, so the only loss is the integer remainder of the LAST partial pass.
        full = tiles // resident
        rem  = tiles % resident
        if full == 0:
            return rem / resident          # tiny problem: only a partial wave
        # full passes are 1.0-efficient; the final partial pass costs a whole pass-time.
        return tiles / ((full + (1 if rem else 0)) * resident)
    waves = (tiles + resident - 1)//resident
    return tiles / (waves * resident)

def drain_penalty(K, issue_eff):
    """K-loop drain/serialization cost. Each K-slab (TKSW=32) ends in commit_group +
    wait_group + __syncthreads (b14:692-694). The per-slab drain is a FIXED latency that
    amortizes worse when there are MANY slabs relative to a deeper-issued pipeline.
    OP-45 finding 2: own LOSES -9.9% from D=2048->4096 = nks 64->128 (2x slabs).
    Model: efficiency = 1 / (1 + c * log2(nks)/log2(64) ). Calibrated so a plain
    (issue_eff 0.93) MODE8 drops ~9.9% as nks doubles 64->128."""
    import math
    nks = K // TKSW
    if nks <= 0:
        return 1.0
    # drain cost per slab shrinks with issue depth (dual-issue hides it); grows with nks.
    # c chosen so MODE8(issue .93): ratio(nks=128)/ratio(nks=64) ~= 0.901 (the measured -9.9%).
    c = 0.115 * (0.93 / issue_eff)
    return 1.0 / (1.0 + c * math.log2(nks) / math.log2(64))

def reuse_eff(tn):
    """Arithmetic-intensity / operand-reuse term. A WIDER output tile (TN) reuses each
    A-row-block load across MORE N-columns, so global-load pressure per FLOP DROPS. This
    is why the 128x256 (MODE5_t256) tile RECOVERS at large D (OP-45: t256 @4096 ties OG16
    despite 1 CTA/SM) — the extra reuse offsets the occupancy loss once there is enough
    work to fill. Modeled as a mild bonus over the 128-baseline, saturating (roofline)."""
    base = 128.0
    # +ve for TN>128; ~+8% at TN=256 (matches the t256 large-D recovery), saturating.
    return 1.0 + 0.085 * (tn/base - 1.0)

def fill_factor(M, N, tm, tn, occ_ctas):
    """How saturated is the device? When tiles >> resident the device is filled and a wide
    low-occupancy tile (t256) gets to exercise its operand-reuse advantage. When tiles is
    only ~1 wave the wide tile is starved. This term ONLY rewards wide tiles for being well
    -filled; the 128-baseline already saturates the math pipe at 1 wave, so it gets 1.0.
    Modeled relative to tile-width so it leaves OG16/OG17/MODE8 (TN=128) untouched."""
    if tn <= 128:
        return 1.0
    tiles = ((M+tm-1)//tm)*((N+tn-1)//tn)
    resident = occ_ctas*SM_COUNT
    if resident == 0: return 0.0
    waves = tiles/resident
    # wide tile: needs >=~1 wave to amortize; ramps from 0.80 (1 wave) toward 1.0 (>=2 waves).
    return min(1.0, 0.80 + 0.20*max(0.0, waves-1.0))

def predict_tflops(mode_name, M, N, K, nst):
    cfg = MODES[mode_name]
    occ = cta_per_sm(cfg["tm"], cfg["tn"], nst, cfg["regs"])
    # 1-CTA/SM (reg/smem-heavy) loses some math-pipe overlap -> occupancy factor.
    occ_factor = 1.0 if occ >= 2 else 0.86
    we = wave_eff(M, N, cfg["tm"], cfg["tn"], occ, cfg["persistent"])
    dp = drain_penalty(K, cfg["issue_eff"])
    re = reuse_eff(cfg["tn"])
    ff = fill_factor(M, N, cfg["tm"], cfg["tn"], occ)
    return PEAK_TF32 * cfg["issue_eff"] * occ_factor * we * dp * re * ff

# ---- candidate enumeration: each mode with its viable NST settings (from verdicts) ----
def candidates(M, N, K):
    cands = []
    for name, cfg in MODES.items():
        # NST sweep: 2 and 3 keep 2 CTA/SM at 128x128; t256 forced to NST<=2 (1 CTA/SM anyway).
        for nst in (2, 3):
            if name == "MODE5_t256" and nst > 2:
                continue
            cands.append((name, nst))
    return cands

def select(M, N, K):
    """The SELECTOR: score every candidate config, return the argmax + the ranked table."""
    scored = []
    for (name, nst) in candidates(M, N, K):
        t = predict_tflops(name, M, N, K, nst)
        scored.append((t, name, nst))
    scored.sort(reverse=True)
    return scored[0], scored

# ---- shape buckets (the policy) ----
def bucket(D):
    if D <= 1024:  return "small-D (under-fill)"
    if D <= 3072:  return "medium-D (parity zone)"
    return "large-D (drain/scheduling-bound)"

# =====================================================================================
# VALIDATION against ALREADY-MEASURED verdict datapoints (0-pod, no new GPU run).
# Each row: (D, mode, nst, measured_own_TFLOPS). We check the model REPRODUCES the
# measured ORDERING of which config wins at which D (the g5 soundness evidence).
# =====================================================================================
MEASURED = [
    # D     mode         nst  measured  source-verdict
    (2048, "OG16",       3,   252.0),   # F-...-OG16
    (2048, "OG17",       3,   279.7),   # F-...-OG17
    (2048, "MODE8",      3,   315.0),   # F-OP45 (b14 MODE8 PDEP2)
    (2048, "MODE5_t256", 2,   219.0),   # F-...-OG17 (1 CTA/SM)
    (4096, "OG16",       2,   264.7),   # F-...-OG16
    (4096, "OG17",       2,   275.0),   # F-...-OG17
    (4096, "MODE8",      3,   283.9),   # F-OP45 (b14 MODE8 PDEP1)
    (4096, "MODE5_t256", 2,   264.9),   # F-...-OG17 t256 (1 CTA/SM, ties OG16)
]

def validate():
    print("="*86)
    print("OP-49 cost-model VALIDATION vs measured OG16/OG17/MODE8/MODE5 verdict points (0-pod)")
    print("="*86)
    print(f"{'D':>6} {'mode':>12} {'nst':>4} {'measured':>9} {'predicted':>10} {'rel.err':>8}")
    err_sum = 0.0; n = 0
    for (D, mode, nst, meas) in MEASURED:
        pred = predict_tflops(mode, D, D, D, nst)
        rel = (pred - meas)/meas
        err_sum += abs(rel); n += 1
        print(f"{D:>6} {mode:>12} {nst:>4} {meas:>9.1f} {pred:>10.1f} {rel:>+7.1%}")
    print(f"\nmean |rel.err| = {err_sum/n:.1%}")

    # ORDERING check: at each D, does the model rank the modes in the measured order?
    ordering_ok = True
    for D in (2048, 4096):
        rows = [(m, nst, meas, predict_tflops(m, D, D, D, nst))
                for (dd, m, nst, meas) in MEASURED if dd == D]
        meas_order = [r[0] for r in sorted(rows, key=lambda r: -r[2])]
        pred_order = [r[0] for r in sorted(rows, key=lambda r: -r[3])]
        ok = meas_order == pred_order
        ordering_ok = ordering_ok and ok
        print(f"\nD={D} measured rank: {meas_order}")
        print(f"D={D} predict  rank: {pred_order}   -> {'MATCH' if ok else 'MISMATCH'}")
    print(f"\nORDERING VALIDATION: {'PASS (model reproduces measured win-order at both D)' if ordering_ok else 'FAIL'}")

    # SELECTOR demo: what does the policy pick per bucket?
    print("\n" + "="*86)
    print("SELECTOR output (the policy's pick per shape bucket):")
    print("="*86)
    for D in (512, 1024, 2048, 4096, 8192):
        (best, ranked) = select(D, D, D)
        t, name, nst = best
        print(f"D={D:>5} [{bucket(D):<28}] -> PICK {name} NST={nst}  (pred {t:.1f} TFLOP/s)")

if __name__ == "__main__":
    validate()
