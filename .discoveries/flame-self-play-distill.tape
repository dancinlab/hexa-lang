@V := "tape" :: spec [active]
  version = "1.2"

@I := "flame-self-play-distill-discovery" :: identity [active]
  brief = "Discovery log — self-play dispatch-KL self-distillation on CLMConvMoE (lever A · P4 §2 · NO external teacher)."
  flow  = "discovery → CLAIMS.tape → hexa run (g5) → .verdicts/ → paper_on_discovery"

# ───────────────────────────────────────────────────────────────────────
# F-FLAME-SELF-DISTILL — self-play dispatch-KL self-distillation.
# Falsifier: held-out gain ∧ external-LLM 0. HOST-CLOSEABLE (algorithm, not hardware).

@C disc_flame_self_play_distill := "model distils from its OWN sharper-rung dispatch; held-out gain is the falsifier" :: discovery [slug=flame-self-play-distill group=FLAME-PERF]
  id           = "F-FLAME-SELF-DISTILL"
  seed         = "CLMConvMoE router dispatch q=softmax(z/tau) (tau<1, sharper, detached) as soft target for student p=softmax(z); add lam·KL(q||p) into the router-logit grad seed (dL_kl/dz=lam·(p-q)) riding the GRAD-EXACT bwd chain; ZERO external LLM (self-play, structural). falsifier = held-out CE(distill) < held-out CE(baseline) ∧ external-LLM 0."
  date         = "2026-06-01"
  host         = "darwin arm64 · hexa 0.1.0-dispatch · hexa run (interp/native) · toy CLMConvMoE T=4 d=8 E=2 V=256 K=3"
  verdict_tier = "🔴 CLOSED-NEGATIVE — external-LLM 0 holds, NO held-out gain on this toy task (ruled-out axis)"
  target       = "FLAME-PERF lever A (P4 §2) self-play dispatch-KL self-distillation box"
  finding      = "external-LLM 0 = TRUE by construction (the teacher is the model's own sharper-temperature dispatch; no socket/http/llm-cmd in the loop). HELD-OUT GAIN = NOT OBSERVED on the toy task: both arms (CE-only baseline vs CE+self-KL) trained from IDENTICAL init / same #steps / same AdamW memorize the fixed train batch (train CE → ~1e-4) and the self-KL arm is fractionally WORSE on the held-out split (delta = base−distill < 0, ~−4e-6). Dispatch-KL self-sharpening did not improve generalization here."
  ruled_out    = "entropy-style self-distillation on the router dispatch ALONE does not yield held-out generalization gain on a memorizable single-batch toy task — the held-out split is disjoint-vocab (untransferable by construction) and the model overfits train before the KL term can shape transferable routing. NEGATIVE is HONEST (not fabricated); the gain axis is closed for this regime."
  next         = "a fair positive test would need (a) a non-memorizable train regime (multi-batch shared-vocab corpus, early-stop) and (b) a transferable held-out split — both currently blocked by the host memory ceiling on per-step tensor churn (hexa run OOM under contention)."
