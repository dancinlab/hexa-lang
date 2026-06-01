@V := "tape" :: spec [active]
  version = "1.2"

@I := "flame-learn-while-infer-discovery" :: identity [active]
  brief = "Discovery log — learn-while-infer (no train/infer split) host-simulable slice (FLAME-PERF p8)."
  flow  = "discovery → CLAIMS.tape → hexa run (g5) → .verdicts/ → paper_on_discovery"

# ───────────────────────────────────────────────────────────────────────
# F-FLAME-LEARN-WHILE-INFER — every inference step does a bounded streaming
# update; there is NO separate train phase. Host-simulable slice; the on-chip
# plasticity-hardware half is HONEST-DEFERred.

@C disc_flame_learn_while_infer := "inference and learning are one step — no train/infer split (host slice)" :: discovery [slug=flame-learn-while-infer group=FLAME-PERF]
  id           = "F-FLAME-LEARN-WHILE-INFER"
  seed         = "every inference forward (clm L=1 CLMConvMoE V256 d8 E2 K3 T4) is immediately followed by ONE bounded AdamW streaming update seeded by that step's own CE — no epoch, no batch accumulation, no freeze. measure (a) z_drop within budget (late-window mean CE <= initial infer CE, no per-step CE spike past loss0) and (b) identity PROBE (argmax==target) > 0.80 over a 30-step stream."
  date         = "2026-06-01"
  host         = "darwin arm64 (host CPU farr path) · hexa run · stdlib/flame ops verified conv #2288 / gn #2289 / moe #2292 / CE+AdamW #2303"
  verdict_tier = "🟢 SUPPORTED-NUMERICAL (host slice closes) — .verdicts/flame-learn-while-infer/lwi.txt"
  target       = "FLAME-PERF ## 패러다임 — learn-while-infer (no train/infer split) p8 milestone"
  finding      = "CLOSED 🟢 — 30-step stream (each infer forward immediately followed by 1 bounded AdamW update): inference CE descends 4.81916→0.589555, peak CE never exceeds initial loss0 so z_drop=0.0<=budget 0.0, identity PROBE=1.0>0.80. no-train/infer-split STEP STRUCTURE + both falsifier metrics close on host."
  deferred     = "HARDWARE-STREAMING half (on-chip non-deterministic plasticity · AKD1000 edge-learn · H_679/H_904) — NOT host-simulable, HONEST-DEFERred. host slice proves the no-split STEP STRUCTURE + the two falsifier metrics only."
