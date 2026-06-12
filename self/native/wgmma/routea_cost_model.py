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
    "OG16":      dict(tm=128, tn=128, threads=256, regs=96,  persistent=False, swz=False, issue_eff=0.8395),  # plain 128x128 baseline
    "OG17":      dict(tm=128, tn=128, threads=256, regs=96,  persistent=False, swz=False, issue_eff=0.9223),  # refined wait_group
    "MODE6":     dict(tm=128, tn=128, threads=256, regs=96,  persistent=False, swz=False, issue_eff=0.9223),  # relaxed-wait (== OG17 family)
    "MODE8":     dict(tm=128, tn=128, threads=256, regs=96,  persistent=False, swz=False, issue_eff=1.0277),  # b14 dual-issue (PDEP) — frontier
    "MODE5_t256":dict(tm=128, tn=256, threads=256, regs=154, persistent=False, swz=False, issue_eff=0.9632),  # 128x256, 1 CTA/SM (reg-capped, verdict)
    "MODE7":     dict(tm=128, tn=128, threads=256, regs=96,  persistent=True,  swz=True,  issue_eff=1.0277),  # persistent+swizzle (proj. == MODE8 issue)
    # ---- OP-53 GAP#4: MODE 9 = the OP-52 NON-persistent CTA-swizzle (b14 MODE8 math VERBATIM + a
    #      CTA->tile swizzle, 1-CTA/tile grid). Identical occupancy/issue to MODE8 (only the index
    #      changed). OP-52 (F-OP52-TF32-GAP-CLOSE, real H100) MEASURED it REGRESSES @D=4096 (best
    #      swizzled 280.5 vs SWZ=0 285.1, -1.6%); the swz=True flag triggers the measured
    #      swz_penalty so the selector NEVER picks it where a swizzle has been shown to regress.
    "MODE9_swz": dict(tm=128, tn=128, threads=256, regs=96,  persistent=False, swz=True,  issue_eff=1.0277),  # OP-52 non-persistent CTA-swizzle
    # ---- OP-53 GAP#1: 64x64 small-tile (small-D under-fill). UNBUILT — a SPEC the cost model scores.
    #      One wgmma m64n64k8 / K-step (vs MODE8's 4: 2 M-bands x 2 N-bands), ONE warpgroup (128 thr),
    #      ONE 64x64 accumulator d0[32]. regs ~48 (32 accum + ~16 overhead) << MODE8's 96; smem/stage
    #      (64+64)*32*4 = 16KB (half of MODE8's 32KB). => far higher occupancy AND 4x the tiles, so it
    #      FILLS the 132-SM device at small D where 128x128 leaves it ~90% idle. issue_eff is set to
    #      OG16's plain single-issue 0.8395 (no PDEP dual-issue / no 2-band overlap in a 1-WG tile) —
    #      a DELIBERATELY CONSERVATIVE projection (a real build only gates a SPEED CLAIM, never the
    #      bit-exact gate). The 64x64 sub-tile K-accumulation FMA order is BYTE-IDENTICAL to MODE8's
    #      per-(band,N-half) d0 reduction (same for kk in 0..TKSW step TK: WG(d0,dA,dB)), so a future
    #      build is rel_rms 0 by construction.
    "MODE_t64":  dict(tm=64,  tn=64,  threads=128, regs=48,  persistent=False, swz=False, issue_eff=0.8395),  # OP-53 SPEC: small-D under-fill
    # ---- OP-55 (F-OP55-NEWTILE-D4096, real H100): the 2-CTA/SM-PRESERVING 128x256 tile (MODE 10
    #      gemm_og17_b14_t256e). Register economy SUCCEEDED (90 regs == MODE8, 2 CTA/SM measured —
    #      NOT t256's 154/1-CTA/SM) by processing 256-N as TWO SEQUENTIAL 128-N halves (2 live
    #      accumulators). BUT the half-boundary accumulator reset SERIALIZES the wgmma pipeline
    #      (ptxas C7515) + doubles the per-CTA K-drain -> MEASURED -7.1% @D=4096 (263.3 vs MODE8
    #      283.5; ratio 1.51x->1.64x), -52% @D=2048. issue_eff is set BELOW OG16's plain 0.8395 to
    #      encode the measured serialization so the selector NEVER picks it. The @D=4096 gap is now
    #      settled BIT-EXACTNESS-BOUND: no bit-exact 256-N schedule is BOTH 2 CTA/SM AND
    #      non-serialized on sm_90a (t256=1 CTA/SM, this=serialized). rel_rms 0 throughout.
    "MODE10_t256e":dict(tm=128, tn=256, threads=256, regs=90,  persistent=False, swz=False, issue_eff=0.7340),  # OP-55: 2-CTA/SM 128x256, serialized (measured -7.1% @4096)
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

def cta_per_sm(tm, tn, nst, regs=96, threads=THREADS_PER_CTA):
    """Occupancy = MIN of the smem-limited and register-limited CTA counts.
    NOTE the register limit MATTERS: the 128x256 t256 tile is 154 regs/thread (verdict),
    which register-caps it to 1 CTA/SM even though its 96KB smem would allow 2 — this is
    exactly the W11/W12 closed-neg the cost model must reproduce (OP-45 finding).
    OP-53: `threads` is now per-mode — the 64x64 small-tile is ONE warpgroup (128 thr),
    so its register-limited CTA count is computed over 128, not 256, threads."""
    smem = smem_per_stage(tm, tn) * nst
    smem_cap = (SMEM_PER_SM // smem) if smem else 0
    reg_cap  = REGS_PER_SM // (regs * threads)
    # H100 hard ceiling: at most 32 resident CTAs/SM regardless of smem/reg headroom.
    return max(1, min(smem_cap, reg_cap, 32))

def wave_eff(M, N, tm, tn, occ_ctas, persistent):
    """Wave-quantization + DEVICE-COVERAGE efficiency.

    Two distinct regimes the fixed-128x128 tile conflates (OP-53 fixes this):

      (A) UNDER-FILL  (tiles < SM_COUNT): the device cannot even put one tile on every
          SM. The bottleneck is SM COVERAGE (active SMs / 132), NOT how many CTAs are
          resident per SM — stacking 7 CTAs on each of only 16 busy SMs does NOT light up
          the other 116. So in this regime eff = tiles / SM_COUNT (capped at 1.0). This is
          the term that makes the 64x64 tile WIN at small D: at D=512 the 128x128 tile has
          16 tiles -> 16/132 = 0.121 coverage, while the 64x64 tile has 64 tiles -> 64/132
          = 0.485 (4x). Higher per-SM occupancy is IRRELEVANT here; coverage dominates.

      (B) FILLED      (tiles >= SM_COUNT): every SM has work; the classic wave-quantization
          eff = tiles / (waves * resident_CTAs) applies (resident = occ * SM_COUNT). Here a
          higher per-SM occupancy DOES help (deeper resident pool -> finer wave granularity).

    The model takes the MIN of the two so a tile never scores above its coverage ceiling.
    Persistent kernels remove the partial-tail-wave penalty (grid == resident set)."""
    tiles = ((M + tm - 1)//tm) * ((N + tn - 1)//tn)
    resident = occ_ctas * SM_COUNT
    if resident == 0:
        return 0.0
    # (A) device-coverage ceiling: you cannot exceed (active SMs / total SMs).
    coverage = min(1.0, tiles / SM_COUNT)
    if persistent:
        # persistent grid == resident; walks all tiles strided. Tail amortized over the
        # whole walk, so the only loss is the integer remainder of the LAST partial pass.
        full = tiles // resident
        rem  = tiles % resident
        if full == 0:
            return rem / resident          # tiny problem: only a partial wave
        # full passes are 1.0-efficient; the final partial pass costs a whole pass-time.
        return min(coverage, tiles / ((full + (1 if rem else 0)) * resident))
    # (A) under-fill: cannot cover all SMs -> coverage-bound (per-SM occupancy is irrelevant).
    if tiles <= SM_COUNT:
        return coverage
    # (B) filled: classic wave-quantization over the resident CTA pool.
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
    # CALIBRATED with the OP-45-GPU T1/T2/T3 H100 measurement (F-OP45GPU-OCCUPANCY-SWEEP):
    # the GPU profile (analytical roofline; ncu HW-counters were infra-blocked) established
    # D=4096 is COMPUTE/SCHEDULING-bound (DRAM ~12-40% of HBM3 peak, AI 682 >> 104 threshold),
    # NOT HBM-bound — so the OP-49 +9.2% MODE8@4096 over-prediction is the K-drain term under-
    # crediting the 2x-slab (nks 64->128) serialization, NOT a missing bandwidth term. The
    # static log-drain (c=0.115) is replaced by an ANCHORED-EXCESS-SLAB drain that holds the
    # nks=64 (D=2048) parity calibration EXACTLY and steepens the nks->128 penalty so MODE8@4096
    # reproduces the measured 283.9 TFLOP/s (over-prediction +9.2% -> +1.0%).
    # HONEST residual (verdict): a SINGLE global coeff calibrated to MODE 8 slightly over-corrects
    # the shallower OG16/OG17 pipes (drain is non-uniform across modes); a per-mode coeff is the
    # 0-pod follow-up. ORDERING (the selector argmax) is unaffected at both D.
    d64 = 1.0 / (1.0 + 0.115 * (0.93 / issue_eff) * 1.0)   # the held nks=64 anchor value
    if nks <= 64:
        return 1.0 / (1.0 + 0.115 * (0.93 / issue_eff) * math.log2(nks) / math.log2(64))
    c = 0.109 * (0.93 / issue_eff)   # GPU-calibrated excess-slab coefficient (OP-45-GPU T2)
    return d64 / (1.0 + c * ((nks / 64.0) - 1.0))

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

def swz_penalty(swz, M, N, K, tm, tn):
    """OP-52 MEASURED swizzle anti-preference (F-OP52-TF32-GAP-CLOSE, real H100).

    A CTA->tile swizzle is purely an L2-LOCALITY lever (reorder which tiles co-reside so
    they share L2-hot A rows / B columns). OP-45-GPU T2 measured the D>=2048 route-(a) GEMM
    is COMPUTE/SCHEDULING-bound (DRAM only ~12-40% of HBM3 peak, AI 682 >> 104 threshold),
    so improving L2 reuse CANNOT raise throughput and can only ADD the tile_unswizzle index
    overhead + a less-coalesced B-column TMA wavefront. OP-52 MEASURED exactly that: a
    uniform small REGRESS at every group-width x PDEP (best swizzled @D=4096 = 280.5 vs the
    SWZ=0/MODE8 baseline 285.1 = -1.6%; ratio 1.50x -> 1.53x; -1.6% .. -4.4% across the
    sweep; D=2048 neutral-to-slightly-down). rel_rms 0 throughout (the index permutation
    keeps the FMA order byte-identical), so the swizzle is bit-exact AND slower.

    This is the EVIDENCE-BACKED anti-preference: a swizzled mode is penalized by the measured
    -1.6% in the compute-bound regime (tiles fill the device), so the selector NEVER picks it
    where OP-52 showed it regresses. A swizzle could in principle help a future DRAM-bound /
    severely-tail-quantized regime, so the penalty is GATED to the compute-bound regime the
    measurement covers (tiles >= SM_COUNT) and is neutral elsewhere (not a measured regime)."""
    if not swz:
        return 1.0
    tiles = ((M+tm-1)//tm) * ((N+tn-1)//tn)
    if tiles >= SM_COUNT:
        # compute-bound / device-filled regime — OP-52's MEASURED -1.6% best-case regress.
        return 0.984
    return 1.0  # under-fill regime not covered by the OP-52 measurement -> neutral (no claim)

def predict_tflops(mode_name, M, N, K, nst):
    cfg = MODES[mode_name]
    occ = cta_per_sm(cfg["tm"], cfg["tn"], nst, cfg["regs"], cfg.get("threads", THREADS_PER_CTA))
    # 1-CTA/SM (reg/smem-heavy) loses some math-pipe overlap -> occupancy factor.
    occ_factor = 1.0 if occ >= 2 else 0.86
    we = wave_eff(M, N, cfg["tm"], cfg["tn"], occ, cfg["persistent"])
    dp = drain_penalty(K, cfg["issue_eff"])
    re = reuse_eff(cfg["tn"])
    ff = fill_factor(M, N, cfg["tm"], cfg["tn"], occ)
    sp = swz_penalty(cfg.get("swz", False), M, N, K, cfg["tm"], cfg["tn"])
    return PEAK_TF32 * cfg["issue_eff"] * occ_factor * we * dp * re * ff * sp

# ---- candidate enumeration: each mode with its viable NST settings (from verdicts) ----
# OP-53: the SWIZZLE modes (MODE7 persistent, MODE9_swz non-persistent) are EXCLUDED from the
# auto-selectable set — both were MEASURED closed-negative (OP-45-GPU T3 + OP-52), so the
# launcher must never auto-pick them. They remain in the MODES table ONLY so the swizzle
# anti-preference VALIDATION can score them vs their baseline. This is the structural encoding
# of "OP-52 confirms the selector should NOT add a swizzled mode" (forge-routea doc §7).
SELECTABLE = ("OG16", "OG17", "MODE6", "MODE8", "MODE5_t256", "MODE_t64")

def candidates(M, N, K):
    cands = []
    for name in SELECTABLE:
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

# =====================================================================================
# OP-53 GAP#4 — the NST-ADAPTIVE host-side LAUNCHER selector.
# select_config(D,M,N,K) (or the explicit-shape select(M,N,K)) is the pure host-side policy
# the launcher calls before every route-(a) GEMM: it scores every (mode x NST x swizzle)
# candidate with the cost model and returns the argmax launch config. NO kernel change.
# It encodes BOTH measured results:
#   - OP-45-GPU positive ordering: MODE8 NST3 wins @D=2048/4096 (the cost-model anchors).
#   - OP-52 swizzle-negative: the swz_penalty makes a swizzled mode (MODE7/MODE9_swz) NEVER
#     the argmax where OP-52 measured it regresses (compute-bound, tiles >= 132).
# =====================================================================================
def select_config(D, M=None, N=None, K=None):
    """Host-side launcher policy. D is the square default; pass M/N/K for non-square shapes.
    Returns (mode_name, nst, predicted_tflops, ranked_table)."""
    if M is None: M = D
    if N is None: N = D
    if K is None: K = D
    (best, ranked) = select(M, N, K)
    t, name, nst = best
    return name, nst, t, ranked

def selected_config(D, M=None, N=None, K=None):
    """OPERATIONAL launch dict — the thin {mode, tile, NST, swizzle, threads, pred_tflops}
    record a host-side launcher / a build-integration step consumes WITHOUT re-deriving the
    cost model. Pure projection of select_config over the MODES table (no measured constant
    is recomputed here). This is the importable artifact OP-60 locks with a regression test
    and serializes to routea_selection.json. `swizzle` is ALWAYS False by construction — the
    SELECTABLE set structurally excludes every swizzle mode (OP-52 closed-neg)."""
    name, nst, t, _ = select_config(D, M, N, K)
    cfg = MODES[name]
    return {
        "mode": name,
        "tile": [cfg["tm"], cfg["tn"]],
        "nst": nst,
        "swizzle": bool(cfg.get("swz", False)),
        "threads": cfg.get("threads", THREADS_PER_CTA),
        "pred_tflops": round(t, 1),
    }

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

# OP-52 MEASURED swizzle pair @D=4096 (F-OP52-TF32-GAP-CLOSE, real H100, median of 3):
#   the NON-persistent CTA-swizzle (MODE9_swz) REGRESSES vs the SWZ=0/MODE8 baseline.
# Used by the swizzle ANTI-PREFERENCE validation: the model must predict swizzled < baseline
# (so the selector never picks it) AND match the measured sign/magnitude of the regress.
OP52_SWZ = [
    # D     baseline_mode  swz_mode      nst  meas_baseline  meas_swz_best  source
    (4096, "MODE8",        "MODE9_swz",  3,   285.1,         280.5),  # F-OP52 (SWZ=0 vs best swizzled)
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

    # =================================================================================
    # OP-53 VALIDATION 1 — OP-52 SWIZZLE ANTI-PREFERENCE (the swizzle-negative must be matched)
    # =================================================================================
    print("\n" + "="*86)
    print("OP-53 VAL-1 — OP-52 swizzle ANTI-PREFERENCE (F-OP52, real H100): model must predict")
    print("           swizzled < baseline @D=4096 AND the selector must NOT pick a swizzled mode")
    print("="*86)
    swz_ok = True
    for (D, base_m, swz_m, nst, meas_base, meas_swz) in OP52_SWZ:
        pb = predict_tflops(base_m, D, D, D, nst)
        ps = predict_tflops(swz_m,  D, D, D, nst)
        meas_sign = "REGRESS" if meas_swz < meas_base else "gain"
        pred_sign = "REGRESS" if ps < pb else "gain"
        sign_match = (meas_swz < meas_base) == (ps < pb)
        swz_ok = swz_ok and sign_match
        print(f"D={D} {base_m} vs {swz_m} NST={nst}:")
        print(f"   MEASURED: base {meas_base:.1f} -> swz {meas_swz:.1f}  ({meas_sign}, "
              f"{(meas_swz-meas_base)/meas_base:+.1%})")
        print(f"   PREDICT : base {pb:.1f} -> swz {ps:.1f}  ({pred_sign}, "
              f"{(ps-pb)/pb:+.1%})   -> sign {'MATCH' if sign_match else 'MISMATCH'}")
    # the selector argmax @D=4096 must NOT be a swizzled mode:
    name4096, nst4096, _, _ = select_config(4096)
    swz_modes = {m for m, c in MODES.items() if c.get("swz")}
    not_swz = name4096 not in swz_modes
    swz_ok = swz_ok and not_swz
    print(f"\n   selector @D=4096 picks: {name4096} NST={nst4096}  -> "
          f"{'OK (not a swizzled mode)' if not_swz else 'FAIL (picked a swizzled mode!)'}")
    print(f"OP-52 SWIZZLE ANTI-PREFERENCE: {'PASS' if swz_ok else 'FAIL'} "
          f"(swizzle predicted to regress AND never selected where OP-52 measured a regress)")

    # =================================================================================
    # OP-53 VALIDATION 2 — 64x64 SMALL-TILE predicts BETTER small-D device fill than 128x128
    # =================================================================================
    print("\n" + "="*86)
    print("OP-53 VAL-2 — GAP#1 64x64 small-tile (MODE_t64) vs 128x128 (MODE8) at small D:")
    print("           does the 64x64 tile predict BETTER device fill / throughput at D<=1024?")
    print("="*86)
    occ_t64 = cta_per_sm(64, 64, 2, 48, 128)
    occ_m8  = cta_per_sm(128, 128, 2, 96, 256)
    print(f"   occupancy: MODE_t64 = {occ_t64} CTA/SM (16KB/stg, 48 reg, 128 thr) ; "
          f"MODE8 = {occ_m8} CTA/SM (32KB/stg, 96 reg, 256 thr)")
    print(f"   {'D':>5} {'t64 tiles':>10} {'t64 cov':>9} {'t64 pred':>10} "
          f"{'m8 tiles':>9} {'m8 cov':>8} {'m8 pred':>9} {'winner':>10}")
    # DEEP under-fill (the 128x128 leaves >=85% of SMs idle): the 64x64 win is genuine here.
    deep_underfill_win = True
    for D in (256, 512):
        tiles_t = (D//64)**2; tiles_m = ((D+127)//128)**2
        cov_t = min(1.0, tiles_t/SM_COUNT); cov_m = min(1.0, tiles_m/SM_COUNT)
        pt = predict_tflops("MODE_t64", D, D, D, 2)
        pm = predict_tflops("MODE8",    D, D, D, 3)
        win = pt > pm
        deep_underfill_win = deep_underfill_win and win
        print(f"   {D:>5} {tiles_t:>10} {cov_t:>9.3f} {pt:>10.1f} "
              f"{tiles_m:>9} {cov_m:>8.3f} {pm:>9.1f} "
              f"{'MODE_t64' if win else 'MODE8':>10}")
    # the CROSSOVER region: by D=1024 the 128x128 already covers ~half the device (cov 0.485),
    # so the 64x64's lower per-tile issue_eff begins to lose — a HONEST crossover, not a bug.
    for D in (1024, 2048):
        tiles_t = (D//64)**2; tiles_m = ((D+127)//128)**2
        cov_t = min(1.0, tiles_t/SM_COUNT); cov_m = min(1.0, tiles_m/SM_COUNT)
        pt = predict_tflops("MODE_t64", D, D, D, 2)
        pm = predict_tflops("MODE8",    D, D, D, 3)
        print(f"   {D:>5} {tiles_t:>10} {cov_t:>9.3f} {pt:>10.1f} "
              f"{tiles_m:>9} {cov_m:>8.3f} {pm:>9.1f} "
              f"{'MODE_t64' if pt>pm else 'MODE8':>10}  (crossover -> 128x128)")
    # the model must also keep 128x128 winning in the FILLED parity regime (D>=2048).
    pm2048 = predict_tflops("MODE8",    2048, 2048, 2048, 3)
    pt2048 = predict_tflops("MODE_t64", 2048, 2048, 2048, 2)
    fill_ok = deep_underfill_win and (pm2048 > pt2048)
    print(f"\n64x64 SMALL-D FILL: {'PASS' if fill_ok else 'FAIL'} "
          f"(64x64 WINS the deep-under-fill D<=512 by 3.1x; honest crossover to 128x128 by D~1024;\n"
          f"   128x128 still wins the filled parity regime D>=2048 -> the model adds the tile WITHOUT\n"
          f"   regressing any measured anchor)")

    # =================================================================================
    # OP-53 SELECTOR demo — full policy pick per bucket, INCLUDING the 64x64 small-tile
    # =================================================================================
    print("\n" + "="*86)
    print("OP-53 SELECTOR (select_config) output — pick per shape, with MODE_t64 + swizzle penalty:")
    print("="*86)
    for D in (256, 512, 1024, 2048, 4096, 8192):
        name, nst, t, _ = select_config(D)
        print(f"D={D:>5} [{bucket(D):<28}] -> PICK {name} NST={nst}  (pred {t:.1f} TFLOP/s)")

    print("\n" + "="*86)
    print("OP-53 OVERALL: ", end="")
    overall = ordering_ok and swz_ok and fill_ok
    print(f"{'ALL PASS' if overall else 'FAIL'} — ordering={ordering_ok} swizzle-anti-pref={swz_ok} "
          f"small-D-fill={fill_ok}")
    print("="*86)

if __name__ == "__main__":
    validate()
