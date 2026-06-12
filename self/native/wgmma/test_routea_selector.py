#!/usr/bin/env python3
# test_routea_selector.py — OP-60 (HEXA-0POD) REGRESSION LOCK for the route-(a) own-GEMM
# shape-adaptive selector (OP-49 cost model + OP-53 launcher design, OP-58 parity map).
#
# 0-pod (NO GPU). This is a PURE-CPU regression test: it imports the validated host-side
# selector (`selected_config` / `select_config` from routea_cost_model.py) and ASSERTS that,
# for a canonical square-shape set, it reproduces the ALREADY-MEASURED / cost-model-VALIDATED
# selection. It encodes NO new measurement — it LOCKS the measured ordering so a future edit
# to the cost model that makes the selector pick a measured-BAD config FAILS this test.
#
# Each asserted pick traces to a cited verdict (g5):
#   - MODE8 @ D>=1024 ............ F-OP45GPU-OCCUPANCY-SWEEP (MODE8 NST3 measured winner @2048/4096)
#                                  + F-OP58-OWNGEMM-PARITY-MAP (the settled regime map)
#   - MODE_t64 small-tile @ small-D  F-OP53-SMALLTILE-LAUNCHER-DESIGN (cost-model VAL-2: 64x64
#                                  fills the device 3.1x better @D<=512; honest crossover by D~1024)
#   - NEVER a swizzle mode ....... F-OP52-TF32-GAP-CLOSE (CTA-swizzle measured -1.6% closed-neg)
#   - @D=4096 is MODE8, NOT t256e/MODE10  F-OP55-NEWTILE-D4096 (128x256 2-CTA/SM regresses -7.1%)
#                                  + F-OP45GPU T1 (MODE5 t256 1-CTA/SM closed-neg)
#
# Run: python3 self/native/wgmma/test_routea_selector.py   ->  prints "ALL PASS" on success,
# else prints the first failing assertion and exits non-zero (the regression-lock teeth).

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import routea_cost_model as rc

# ---- canonical shape set (square D) + the LOCKED expected pick per shape. ----------------
# `expect_mode` is the VALIDATED selector pick; `regime` documents WHY (verdict-traced).
# These are the picks the OP-53 harness already prints (F-OP53 SELECTOR block) — re-asserted
# here as a standalone, future-edit-guarding lock.
CANONICAL = [
    # D     expect_mode   regime / verdict trace
    (256,   "MODE_t64",   "small-D under-fill: 64x64 fills 132 SMs better (F-OP53 VAL-2)"),
    (512,   "MODE_t64",   "small-D under-fill: 64x64 3.1x better fill @D<=512 (F-OP53 VAL-2)"),
    (768,   "MODE8",      "crossover zone: 128x128 retakes (F-OP53 honest crossover by D~1024)"),
    (1024,  "MODE8",      "crossover: 128x128 covers ~half device, retakes (F-OP53)"),
    (1536,  "MODE8",      "medium-D parity zone: 128x128 (F-OP58 parity map)"),
    (2048,  "MODE8",      "medium-D PARITY: MODE8 NST3 measured winner (F-OP45GPU T5, 1.08x)"),
    (4096,  "MODE8",      "large-D drain-bound: MODE8, NOT t256/t256e (F-OP45GPU/F-OP55 closed-neg)"),
]

# modes the selector must NEVER auto-pick (every swizzle mode — OP-52 measured closed-neg).
SWZ_MODES = {m for m, c in rc.MODES.items() if c.get("swz")}
# the @D=4096 measured-BAD 256-N tiles the selector must NEVER pick (OP-55 + OP-45GPU T1).
BAD_AT_4096 = {"MODE5_t256", "MODE10_t256e"}


def main():
    fails = []

    def check(cond, msg):
        if not cond:
            fails.append(msg)

    # ---- 1. canonical-shape selection LOCK -----------------------------------------------
    print("="*86)
    print("OP-60 REGRESSION LOCK — route-(a) own-GEMM shape-adaptive selector canonical picks")
    print("="*86)
    print(f"{'D':>6} {'expect':>12} {'got':>12} {'tile':>10} {'NST':>4} {'swz':>5} {'pred':>9}  {'':>3}")
    for (D, expect, regime) in CANONICAL:
        cfg = rc.selected_config(D)
        got = cfg["mode"]
        ok = (got == expect)
        check(ok, f"D={D}: selector picked {got}, expected {expect}  ({regime})")
        # structural: the selector must NEVER return a swizzle mode (OP-52 closed-neg).
        check(not cfg["swizzle"], f"D={D}: selector returned a SWIZZLE mode {got} (OP-52 closed-neg)")
        check(got not in SWZ_MODES, f"D={D}: selector picked a swizzle-table mode {got}")
        mark = "OK" if ok else "FAIL"
        tile = f"{cfg['tile'][0]}x{cfg['tile'][1]}"
        print(f"{D:>6} {expect:>12} {got:>12} {tile:>10} {cfg['nst']:>4} "
              f"{str(cfg['swizzle']):>5} {cfg['pred_tflops']:>9}  {mark:>3}")

    # ---- 2. @D=4096 is MODE8, explicitly NOT a 256-N tile (OP-55/OP-45GPU closed-neg) ----
    cfg4096 = rc.selected_config(4096)
    check(cfg4096["mode"] == "MODE8",
          f"@D=4096: selector picked {cfg4096['mode']}, must be MODE8 (F-OP45GPU)")
    check(cfg4096["mode"] not in BAD_AT_4096,
          f"@D=4096: selector picked a measured-bad 256-N tile {cfg4096['mode']} (F-OP55 -7.1%)")
    print(f"\n@D=4096 pick = {cfg4096['mode']} (tile {cfg4096['tile'][0]}x{cfg4096['tile'][1]}, "
          f"NST={cfg4096['nst']}) -> "
          f"{'OK (MODE8, not a measured-bad 256-N tile)' if cfg4096['mode']=='MODE8' else 'FAIL'}")

    # ---- 3. small-D under-fill: 64x64 small-tile IS picked where it fills better ----------
    check(rc.selected_config(256)["mode"] == "MODE_t64",
          "@D=256: small-tile MODE_t64 not picked (F-OP53 VAL-2 small-D fill win)")
    check(rc.selected_config(512)["mode"] == "MODE_t64",
          "@D=512: small-tile MODE_t64 not picked (F-OP53 VAL-2 small-D fill win)")
    print("small-D under-fill: MODE_t64 picked @D=256 and D=512 -> "
          f"{'OK' if rc.selected_config(512)['mode']=='MODE_t64' else 'FAIL'}")

    # ---- 4. NEGATIVE CONTROL: the lock has TEETH. If a swizzle mode were ever the argmax
    #         (e.g. a future edit dropped the swz_penalty), the structural swizzle check above
    #         fires. Here we directly assert the swizzle modes score BELOW MODE8 @D=4096 (the
    #         compute-bound regime OP-52 measured), so they can never become the argmax there. -
    for swz in sorted(SWZ_MODES):
        p_swz = rc.predict_tflops(swz, 4096, 4096, 4096, 3)
        p_m8  = rc.predict_tflops("MODE8", 4096, 4096, 4096, 3)
        check(p_swz < p_m8,
              f"@D=4096: swizzle mode {swz} ({p_swz:.1f}) scored >= MODE8 ({p_m8:.1f}) — "
              f"swz_penalty broken (F-OP52 measured -1.6% regress)")
    print(f"swizzle modes {sorted(SWZ_MODES)} all score < MODE8 @D=4096 (OP-52 anti-pref intact) -> "
          f"{'OK' if not any('swizzle mode' in f for f in fails) else 'FAIL'}")

    # ---- 5. the underlying cost-model self-validation must STILL pass (ordering anchors). -
    #         We re-assert the measured ORDERING at D=2048/4096 here so a cost-model edit that
    #         breaks the anchor ordering fails THIS test too (not only the harness).
    for D in (2048, 4096):
        rows = [(m, nst, meas, rc.predict_tflops(m, D, D, D, nst))
                for (dd, m, nst, meas) in rc.MEASURED if dd == D]
        meas_order = [r[0] for r in sorted(rows, key=lambda r: -r[2])]
        pred_order = [r[0] for r in sorted(rows, key=lambda r: -r[3])]
        check(meas_order == pred_order,
              f"@D={D}: predicted rank {pred_order} != measured rank {meas_order} (F-OP45GPU ordering)")
    print("measured ordering @D=2048 and @D=4096 reproduced (F-OP45GPU anchors intact) -> "
          f"{'OK' if not any('rank' in f for f in fails) else 'FAIL'}")

    print("\n" + "="*86)
    if fails:
        print(f"OP-60 SELECTOR REGRESSION LOCK: FAIL ({len(fails)} assertion(s) broken)")
        for f in fails:
            print(f"  - {f}")
        print("="*86)
        sys.exit(1)
    print("OP-60 SELECTOR REGRESSION LOCK: ALL PASS "
          "(canonical picks match measured reality · never a swizzle · @D=4096 is MODE8 · "
          "small-D 64x64 fill · ordering anchors intact)")
    print("="*86)


if __name__ == "__main__":
    main()
