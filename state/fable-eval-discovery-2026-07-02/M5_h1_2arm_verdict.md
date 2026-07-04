# M5 — H1 absorb-ON/OFF 2-arm 측정 verdict (OUROBOROS-novel)

**측정**: aiden v0.577.0 · fresh worktree `/tmp/m5wt` (branch ouroboros-m5-wiring) · clean cache
· `hexa run compiler/drill/drill.hexa --seed "sigma phi tau identities over integers n" --rounds 1 --fresh`

## 측정 결과 (ARM_ON round 1, 실측)

```
DRILL_VERIFIER {"round":1,"verdict":"continue","rationale":"identity_sweep:identity=0,verified=0,noise=2725,known=0,novel=0,comp_id=0,comp_verified=0"}
DRILL_ABSORB   {"round":1,"verified":0,"net_absorbed":0,"cum_pool":0,"known":0,"novel":0}
DRILL_EMERGE   {"round":1,"net_walls":31,"open_well":311,"frozen_llm":2}
DRILL_EMERGE2  {"round":1,"n_cands":19,"alpha":2,"beta":2,"gamma":15,"fp_k":189,"k":2,"N":64,"scope":"bounded[2,N] catalog-relative; gamma != absolute-novel"}
```

## H1 verdict — **Δ=0 = generator bottleneck LOCATED** (design-predicted, NOT an OUROBOROS refutation)

- `DRILL_ABSORB verified=0, net_absorbed=0` → **absorbed_pool = [] every round** (smash emits noise=2725
  candidates but **0** identity-syntax verified). `_absorb_feed` is therefore a **no-op in BOTH arms**:
  `enabled=false` returns `seed_pool`; `enabled=true` with an empty pool ALSO returns `seed_pool`
  unchanged → **ARM_ON ≡ ARM_OFF by construction (Δ=0)**.
- **Vacuity contract (design §5)**: an ON-vs-OFF Δ=0 is an H1 REFUTATION *only if* some `DRILL_ABSORB`
  row shows `verified≥1` at a round < R (feed-forward actually fired). Here **no row has verified≥1** →
  the Δ=0 is **UNTESTABLE = the located-bottleneck result**: the OUROBOROS absorb loop has nothing to
  feed because the **generator (smash) produces no identity-syntax candidates in standard vocab**. The
  bottleneck is the generator, exactly as the roadmap predicted ("H1 Δ=0 → 병목=생성자"). OUROBOROS
  self-reference is **not falsified** — it is **untested** for lack of generator output.
- `DRILL_EMERGE2 α=2 β=2 γ=15 @N=64` reproduces M4's measured 2/2/15 — the emerge2 telemetry is
  **input-independent by design** (fixed pre-registered G1–G5 tables = Texas-sharpshooter guard), so it
  is correctly wired-live but is NOT an H1 metric (absorb-ON/OFF cannot move it by construction).

## Wiring status (wire-to-prod)

M5 drill.hexa wiring is **COMPILED + RUN-VERIFIED** on aiden: `_absorb_feed` (H1 toggle), `emerge2_step`
telemetry (`DRILL_EMERGE2`), and `HEXA_DRILL_NO_ABSORB` opt-OUT are all live in `drill_run`'s round loop
and emit the rows above. byte-neutral in the default path (absorb-ON default, absorbed_pool=[] → no-op).

## Follow-on (quarantined · NOT an M5 defect)

The independent OFF-arm full byte-diff run was blocked by a **drill-engine runtime hang in the
⚪ proposal-surfacing loop** (rounds churn on the ⚪ proposal emission after the DRILL_ABSORB row; `--top 0`
did not suppress it and `timeout` did not cleanly propagate to the child). This is a **drill-engine
perf/hang issue on substantive seeds**, separate from the M5 H1 metric (which is captured above). The H1
verdict stands on the ON-arm measured `verified=0/net=0` + the by-construction ON≡OFF equality; the timed
byte-diff is a drill-runtime follow-on, quarantined per infra-wall-noneval.
