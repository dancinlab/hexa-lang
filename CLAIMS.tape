@V := "tape" :: spec [active]
  version = "1.2"

@I := "claims-index" :: identity [active]
  brief = "Single audit index of verifiable hexa-lang claims (claim_manifest)."
  flow  = "claim → hexa verify (g5) → .verdicts/<slug>/<id>.txt → /paper gate (paper_gate)"

# Method legend (claim_verify):
#   atom        — `hexa verify <id>` (atlas atom lookup + closed-form recompute → 🔵)
#   expr        — `hexa verify --expr <fn> <n> <v>` (closed-form → 🔵 / libm → 🟢)
#   fixpoint    — self-host byte-diff / RUNEQ corpus, verdict = run stdout (empirical)
#   fence       — `hexa verify --fence "<claim>"` (honest ⚪ speculation — gated OUT)
#
# Gate (paper_gate): every section claim must be terminal —
#   🔵 formal / 🟢 numerical / 🔴 CLOSED-negative. No 🟠 / 🟡 / ⚪ residual.
# Groups (paper_one_per_group): ATLAS · COMPILER · CANON — one canonical paper each.

# ───────────────────────────────────────────────────────────────────────
# ATLAS — atlas-divisor-sum-sigma (slug · group=ATLAS · paper-track)
# A registered atlas theorem recomputed closed-form by hexa verify.
# σ(6)=12 — the divisor-sum identity 1+2+3+6 = φ·n, perfect-number anchor.
# Positive formal result (REAL verdict persisted).

@C atlas_sigma_six := "sigma(6) = divisor_sum(6) = 1+2+3+6 = 12 (closed-form, atlas foundation atom)" :: formula [slug=atlas-divisor-sum-sigma group=ATLAS]
  method = "expr"
  cmd    = "hexa verify --expr sigma 6 12"
  raw    = ".verdicts/atlas-divisor-sum-sigma/atlas_sigma_six.txt"
  src    = "compiler/atlas/embedded.gen.hexa:7 (@P sigma · foundation [11*])"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

# ───────────────────────────────────────────────────────────────────────
# CANON — canon-codegen-correctness (slug · group=CANON · paper-track)
# The verify-discipline canon: a libm-class numerical bound recomputed
# hexa-native to ε=1e-9. Tsirelson bound 2√2 (RFC 045 CHSH ceiling).
# Positive numerical result (REAL verdict persisted).

@C canon_chsh_tsirelson := "CHSH Tsirelson bound = 2*sqrt(2) = 2.82843 (libm recompute, ε=1e-9)" :: formula [slug=canon-codegen-correctness group=CANON]
  method = "expr"
  cmd    = "hexa verify --expr chsh_tsirelson 2.8284271247461903"
  raw    = ".verdicts/canon-codegen-correctness/canon_chsh_tsirelson.txt"
  src    = "tool/verify (RFC 045 CHSH Tsirelson bound · g5 0-arg atom)"
  status = "🟢 SUPPORTED-NUMERICAL — REAL verdict persisted verbatim. terminal · paper-eligible."

# ───────────────────────────────────────────────────────────────────────
# COMPILER — compiler-selfhost-fixpoint (slug · group=COMPILER · paper-track)
# Self-host correctness: gen1 (hexa_v2→C→clang) and gen2 (aprime_cc native
# path) emit BYTE-IDENTICAL .s of the full compiler closure — a fixpoint.
# Structural STUB — NOT yet a hexa verify atom (run-stdout / md5 evidence
# lives in COMPILER.md S3). Promote only after claim_verify persists a
# terminal verdict (a byte-diff harness emitting a closure glyph).

@C compiler_selfhost_fixpoint := "gen1 and gen2 emit byte-identical .s of compiler closure (md5 29426b80…, 10094662 B)" :: fixpoint [slug=compiler-selfhost-fixpoint group=COMPILER]
  method = "fixpoint"
  cmd    = "tool/build_aprime.sh gen1 + gen2 → diff -q gen1.s gen2.s (md5 compare)"
  raw    = ".verdicts/compiler-selfhost-fixpoint/<id>.txt   # NOT YET PERSISTED"
  src    = "COMPILER.md S3 (2026-05-20 🛸 SELF-HOST FIXPOINT) + RFC 063 P0/P1/P2/P3"
  status = "STUB — terminal verdict NOT persisted (md5/byte-diff evidence is md-only). gated OUT of /paper until claim_verify writes a closure verdict to .verdicts/."

# ───────────────────────────────────────────────────────────────────────
# GPU — fusion-launch-amort (slug · group=GPU · paper-track)
# Whole-program elementwise fusion (GPU.md §5f). A fused single-launch
# >=5-op chain (mul·add·gelu·mul-scale·add-resid) computing
# y = residual + scale·GeLU(a·x+b) vs a per-op eager/library baseline
# (5 separate kernel launches, tensor round-tripping HBM each op).
# Deterministic $0 oracle: launch 1<5, HBM 3<11 transfers/elem; the >=30%
# wall win is UNCONDITIONAL across all n (closed-form from measured
# per-launch overhead F-RFC067-PB-TIMING L=1us). Positive structural +
# numerical-projection result (REAL verdict persisted). Timed silicon wall
# DEFERRED-to-serial (ubu-2 shared) — the §10 >=30% box stays unflipped.

@C fusion_launch_amort := "fused 1-launch 5-op chain beats 5-launch per-op baseline by >=30% unconditionally (launch 1<5, HBM 3<11, bound [72.7%,80%])" :: measurement [slug=fusion-launch-amort group=GPU]
  method = "oracle"
  cmd    = "hexa build archive/fires/gpu_fusion_launch_amort_2026_05_25/oracle.hexa && ./oracle  (exit 0) + ptxas -arch=sm_80 (rc 0)"
  raw    = ".verdicts/fusion-launch-amort/fusion_launch_amort.txt"
  src    = "GPU.md §5f + §1g F-RFC067-PB-TIMING (measured L=1us) · archive/fires/gpu_fusion_launch_amort_2026_05_25/"
  status = "🔵/🟢 SUPPORTED — structural closed-form (launch 1<5 · HBM 3<11) + numerical projection (>=30% unconditional). REAL verdict persisted verbatim. terminal · paper-eligible. Timed silicon wall DEFERRED-to-serial (§10 >=30% box stays [ ])."
