@V := "tape" :: spec [active]
  version = "1.2"

@I := "flame-onchip-plasticity-discovery" :: identity [active]
  brief = "Discovery log — on-chip non-deterministic plasticity = sole deployment learner (FLAME-PERF P6)."
  flow  = "discovery -> CLAIMS.tape -> hexa run (g5) -> .verdicts/ -> paper_on_discovery (host half only)"

# ───────────────────────────────────────────────────────────────────────
# FLAME-PERF P6 — "온칩 비경첩 가소성 = 유일 학습자".
# Paradigm: deployment LEARNING happens ON-CHIP via local non-deterministic
# plasticity (H_679 / H_904 / anima a_train_flame_forge); GPU does PLASTI-SIM
# instrumentation only. The full falsifier is an ON-CHIP edge-learn BOUND
# (RETAIN ∧ GAIN) on neuromorphic silicon (AKIDA).
#
# HONEST SPLIT (g63): the hardware BOUND needs AKIDA — we have none. This
# discovery closes only the HOST half: a pure-hexa simulation of the local
# plasticity update rule (no global backprop) MEASURED on a toy task. The
# hardware half stays OPEN and is HONEST-DEFERRED.

@C disc_onchip_plasti_host := "local plasticity (no backprop) RETAINs ∧ GAINs in host sim; hardware BOUND open" :: discovery [slug=flame-onchip-plasticity group=FLAME-PERF]
  id           = "F-ONCHIP-PLASTI-SIM"
  seed         = "single-layer competitive learner: drive[i] = -||W[i]-x||^2; winner-take-all; LOCAL Hebbian move-toward-input on the WINNER row only (lr*(x-W)), clip [0,w_max], optional L1 homeostasis. NO label, NO loss gradient, NO backprop. Readout = frozen majority-vote prototype->label map (labels touch readout ONLY, never weights). Prototypes sample-seeded (k-means++ flavour) to avoid single-winner collapse."
  date         = "2026-06-01"
  host         = "darwin arm64 (Apple Silicon) · hexa 0.1.0-dispatch · `hexa run` interp path · CPU only · NO neuromorphic hardware"
  verdict_tier = "🟢 SUPPORTED-NUMERICAL (host sim) — on-chip hardware BOUND OPEN (🟠 deferred to AKIDA)"
  target       = "FLAME-PERF P6 'on-chip non-deterministic plasticity = sole deployment learner' — host micro-falsifier half"
  falsifier    = "toy 3-cluster (D=8, K=4) task. GAIN: held-out test acc > chance(1/3); gate >= 0.80. RETAIN: after CONTINUED local learning on a NEW class (3) appended, original-class (0..2) acc does NOT collapse; gate >= 0.70 (catastrophic-forgetting bound). FALSIFIED if either gate fails."
  finding      = "BOTH gates PASS. GAIN = 0.916667 (chance 0.333333). RETAIN = 1.0 after +class3 (was 0.916667 — NO forgetting; spare prototypes absorbed the new class without disturbing settled ones). Sanity: new-class-3 acc = 1.0. Byte-identical across 2 runs (deterministic)."
  confirmed    = "On a toy task, a STRICTLY LOCAL competitive-plasticity learner (winner-row-only Hebbian update, no backprop, no global error) both GENERALIZES above chance AND RETAINs prior classes through continual learning — the locality that makes it on-chip-friendly is the SAME property that protects unused prototypes from catastrophic forgetting (only the winner row moves)."
  ruled_out    = "NOTHING about hardware is ruled in or out. The host sim does NOT establish the on-chip BOUND; deployment-on-silicon RETAIN∧GAIN under AKIDA's non-deterministic stochastic plasticity + device noise + quantized weights is UNMEASURED."
  deferred     = "REAL on-chip edge-learn BOUND -> AKIDA neuromorphic hardware (no device available). Sub-axes left open: (1) stochastic/non-deterministic synaptic update vs the deterministic move-toward-input oracle here; (2) low-bit weight quantization; (3) device-noise robustness of RETAIN; (4) realistic (non-toy) sensory streams. The single-winner-collapse fix (sample-seeding) must be reproduced under hardware init constraints."
  verdict_ptr  = ".verdicts/flame-onchip-plasticity/F-ONCHIP-PLASTI-SIM.txt"
  artifact     = "stdlib/flame/plasti_sim.hexa (host oracle) + stdlib/flame/plasti_sim_test.hexa (micro-falsifier harness)"
  honest_note  = "This is DESIGN + SIMULATION, not a closed hardware falsifier. The verdict tier 🟢 applies to the HOST micro-claim ONLY. Do NOT cite this as an on-chip result."
  next_claim   = "Port the local update to a stochastic (non-deterministic) variant + low-bit weights and re-run the SAME RETAIN∧GAIN falsifier in host sim, as a closer proxy for AKIDA before any hardware run."
