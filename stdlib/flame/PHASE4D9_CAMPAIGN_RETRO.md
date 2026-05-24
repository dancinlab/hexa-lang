# Phase 4-D-9 — Campaign Retro (instrument-first 가 16-fire 좌초를 해소한 회고)

> Authored 2026-05-18, after fire #17 100% closure (commit 28e9d648).
> Goal of this retro: capture the *trap* + the *methodology* that broke it
> so the next d=768-scale campaign (or any device-residency work in flame /
> forge / wilson downstream) does not pay this debt again.

---

## 1. Campaign goal + verdict

**Gate**: `F-RFC046-WALL` — d=768·12L decoder 1 AdamW step wall ≤ 437.9 s
on A100 SXM (= 1.3× PyTorch eager 336.85 s).

**Verdict (fire #17, commit 28e9d648, 100% CLOSURE)**:
- step 1 wall = **191–268 s** (30 s polling quantization window).
- F-RFC046-WALL ≤ 437.9 s → **PASS** with ≥170 s margin.
- vs PyTorch eager 336.85 s → flame 57–80 %× wall (20–43 % faster).
- gn2 = 3.98438 stable across init ↔ step 1 (NaN/inf = 0).

Per-step trajectory + tightened step-1 wall measurement: fire #18
(this retro's sibling cycle).

---

## 2. The trap that ate 15 fires

**Mechanism — three RFC-056 surfaces interacting catastrophically**:

```
  flame_block_generic_fwd_primitive_gpu  (entry)
    │
    ├─ §6.3 pin_device(Bc)            ← Bc snapshot @ host all-zero
    │     (loc=MIRRORED, dirty_host=0)
    │
    ├─ RMSNorm step                   ← writes raw host pointer for oRin
    │     (correct value on host, but dirty_host NEVER set)
    │
    ├─ next GPU op needs Bc
    │   │
    │   └─ §6.1 _h2d(Bc) check        ← loc∈{DEVICE,MIRRORED} && !dirty_host
    │         → H2D upload SKIPPED    ← stale device snapshot wins
    │
    └─ scatter wrapper forces _d2h(Bc) ← stale device (Bc[oRin]=0) clobbers
                                        the correct host value
```

**Net effect**: `Bc[oRin]` becomes 0 by block exit. matmul reads BEFORE the
clobber (oQ byte-eq with CPU = 1.776e-15), so the *forward output is
correct* — but the bwd path reads the clobbered cache, propagating a stale
rin → gn2 drift → NaN explosion after a few steps.

**Why it survived 15 fires**:
- The forward output looked fine on quick spot-checks (`oXout=0` — small,
  fits within noise).
- Only `oRin` (bwd-cache field) carried the corruption.
- gn2 is an *integrated scalar* — one corrupted cache field per layer per
  step accumulates silently into "gn2 drift" or `-nan`, with no information
  about *which field* failed.
- d=768 trainer fires give one bit of information per ~$0.15 ($1.50/hr ×
  6 min ≈ "step 1 completed?"); they cannot localize the failing field.

This is the campaign-scale equivalent of debugging a memory corruption
crash by re-running the program — eventually you guess, but you don't
*localize*.

---

## 3. What broke the trap

**Methodology (in order applied)**:

1. **Replace integrated metrics with per-field oracles** — `tool/
   flame_phase4d9_block_fwd_oracle.{c,sh}` splices the block primitive
   verbatim, runs `_cpu` vs `_gpu` at d=384, and prints per-field max|Δ|
   for `oXout, oHstate, oP, oSwS, oQ, oRin`. One $0–$0.20 oracle fire
   ≡ ~6 d768 trainer fires of information, with field-level resolution.

2. **Run oracles cheap-first** — d=384, no-CUDA `_cpu` byte-eq run is $0
   on the M-Mac. Use that as the protected baseline ("hard gate by
   construction"). Promote to GPU only after the no-CUDA + d=32 hard
   gates are green.

3. **Build an in-process model of the substrate** — `tool/
   flame_phase4d9_orin_clobber_oracle.{c,sh}` faithfully models the
   `runtime_cuda.c` state machine (`_h2d` / `_d2h` / `pin` / H2D-skip).
   This let us *predict* the GPU oracle's exact failure value
   (`max|Δ|=1.704301e-01`) BEFORE renting GPU, and verify on GPU that
   fix is real. Predictive faithfulness of the model is the
   "$0 → GPU-confirmed" independent verification axis.

4. **g3 정직 — name the over-claim risk every time** — until the real
   substrate confirms, every "fix landed" was stated as `$0` tier with
   the GPU-confirmation step explicitly pending. This kept the
   campaign from over-committing budget on misdiagnoses.

5. **Decision-gate each branch** — eps=0 RMSNorm vs offset-bug vs
   pin-clobber were three hypotheses; each got a single $0 oracle test
   to falsify, in priority order. eps was falsified within one $0.20
   fire ("PRE-fix and POST-fix bit-identical → eps is a red herring").

**Net cost**: ~$1 in cheap oracle fires + 2 d768 trainer fires (#16, #17)
≈ **$1.7 to close, after $2.5 of blind d768 fires that closed nothing.**

---

## 4. Block-oracle's 3 catches (cumulative score)

1. **eps red-herring identified** (PRE/POST-fix bit-identical) — saved
   maybe 2–3 more d768 fires on a path that didn't help.
2. **oRin localized** as the corrupted field (vs the 5 other cache
   fields that were byte-eq) — gave the search a single target.
3. **Root cause + minimal fix** (§6.3 Bc-pin × §6.1 H2D-skip ×
   raw-host-write, fix = 2-line `pin/unpin_device(Bc)` removal) +
   independent GPU confirmation. The fix is the smallest change that
   preserves `Bp` (read-only weights) pin while restoring
   "Bc host-authoritative" — the block's own PART 1 invariant that
   §6.3 had silently regressed.

---

## 5. Generalizable lessons

These apply to any future device-residency work (forge phase-R, hexa-chip
runtime, wilson plugins that bind to GPU substrates):

- **Integrated scalars (gn2, loss, accuracy) are the WORST diagnostic
  signal for cache-field corruption.** They aggregate the corrupt and
  the correct into a single number with no inversion. Every campaign-
  scale debug should have at least one *per-field* oracle before any
  cost-bearing fire.

- **A faithful in-process substrate model is the single best investment
  per dollar.** The oRin oracle predicted the GPU failure to 5 decimals
  before renting GPU. That is *independent verification* — the model
  could have been wrong; it wasn't; that confirmed predictive
  faithfulness. Future campaigns should budget one cycle to write this
  model BEFORE the first d-scale fire.

- **`pin_device` is a contract: "I promise the device snapshot is
  current."** If you can't prove that promise at the call site (e.g.
  the buffer is freshly host-written and `dirty_host` isn't set), don't
  pin. Read-only weights (`Bp`) are fine to pin; per-step caches
  (`Bc`, `Bg`) are not, unless every prior write goes through a
  `dirty_host=1` discipline that the H2D-skip respects.

- **g3 정직 (over-claim 0) compounds** — every fire that ended in "fix
  landed, GPU verify pending" instead of "DONE" preserved campaign
  honesty and prevented downstream consumers (wilson, anima) from
  picking up a fake closure. The retro of the retro: never bank a
  win that the real substrate hasn't confirmed.

- **bwd primitive carries the analogous pin** (`tool/flame_phase4d7_
  block_bwd_primitive.c:534`). It was *not* the cause of fire #16 / #17
  closure (forward fix alone was sufficient), but it remains a latent
  hazard for any path that tries to use Bc residency across bwd. If
  ever wired in, the same 2-line removal pattern applies. See
  `PLAN.md` § "bwd primitive 동형 pin-clobber 가설".

---

## 6. What this retro is NOT

- It is **not** a substrate redesign. The 2-line fix is surgical; the
  `runtime_cuda.c` H2D-skip / pin / D2H state machine itself is sound.
  The trap was a *contract violation at the primitive*, not a bug in
  the runtime.

- It is **not** a claim that bwd dev_view chain is unnecessary in
  general. PHASE4D9 §3's "wall is all-or-nothing" theory was over-
  pessimistic given that the 15-fire trap was numerical (step never
  completed), but for **longer training runs / larger d** the bwd
  residency might still matter. That's a future-RFC measurement, not
  a present-campaign blocker.

- It is **not** a claim that 191–268 s is the final precise wall. Fire
  #18 narrows that window via per-step `time(NULL)` printf in the
  trainer C, and verifies the model actually *learns* (step-10/step-20
  gn2 trajectory). The gate-margin (170 s+) dominates the polling
  quantization, so the closure verdict is robust.

---

## 7. Cross-links

- `stdlib/flame/PLAN.md` — full chronological log (fires #5 through #17).
- `tool/flame_phase4d9_block_fwd_oracle.{c,sh}` — per-field block oracle
  (the catcher of all 3 catches).
- `tool/flame_phase4d9_orin_clobber_oracle.{c,sh}` — in-process
  substrate model (the predictor of GPU oRin=0.17).
- `docs/rfc/rfc_drafts_2026_05_12/rfc_056_forge_device_subview_residence_api.md` — RFC 056 (the surface
  whose §6.3 Bc-pin × §6.1 H2D-skip combination created the trap).
- `state/flame_phase4d7_d768_fire1{6,7,8}_dispatch.log` — the three
  closure fires (#16 first step, #17 wall PASS, #18 precision +
  trajectory).
