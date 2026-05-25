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
# TECS-L — tecs-l-n6-identity (slug · group=TECS-L · paper-track · TECS-L.md M1)
# archive-TECS-L core identity, re-grounded hexa-native via `hexa verify` g5.
#
#   σ(n)·φ(n) = n·τ(n)    ⟺    n ∈ {1, 6}      (TECS-L n6-rep Tier 1)
#
# Components recomputed closed-form (each 🔵). Identity = exact integer
# arithmetic over the verified σ/φ/τ values:
#   n=1 : σφ = 1·1 = 1   nτ = 1·1 = 1   → HOLDS  ✓
#   n=6 : σφ = 12·2 = 24  nτ = 6·4 = 24  → HOLDS  ✓
#   n=28: σφ = 56·12 = 672 nτ = 28·6 = 168 → 672 ≠ 168  → FAILS  ✗
#
# FINDING (terminal 🔴 CLOSED-negative): n=28 is the 2nd PERFECT number
# (is_perfect(28)=1, 🔵) yet the identity FAILS there — so σφ=nτ is NOT a
# perfect-number property; it singles out {1,6}, not the perfect numbers.
# Full ⟺{1,6} uniqueness over all n = 🟡 SUPPORTED-BY-CITATION (archive
# complete proof) — a residual gated OUT of /paper; the n=28 closed-negative
# is the terminal discriminator that is paper-eligible.

# — n=6 : identity HOLDS (σφ = 24 = nτ) —
@C tecs_l_n6_sigma := "sigma(6) = 12 (identity LHS factor, σ·φ=n·τ at n=6)" :: formula [slug=tecs-l-n6-identity group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 6 12"
  raw    = ".verdicts/tecs-l-n6-identity/n6_sigma.txt"
  src    = "archive-TECS-L perfect_number_engine.py + CLAUDE.md @I (σ·φ=n·τ) + atlas @P sigma"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6_phi := "phi(6) = 2 (identity LHS factor, σ·φ=n·τ at n=6)" :: formula [slug=tecs-l-n6-identity group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 6 2"
  raw    = ".verdicts/tecs-l-n6-identity/n6_phi.txt"
  src    = "archive-TECS-L perfect_number_engine.py + CLAUDE.md @I (σ·φ=n·τ)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6_tau := "tau(6) = 4 (identity RHS factor, σ·φ=n·τ at n=6)" :: formula [slug=tecs-l-n6-identity group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 6 4"
  raw    = ".verdicts/tecs-l-n6-identity/n6_tau.txt"
  src    = "archive-TECS-L perfect_number_engine.py + CLAUDE.md @I (σ·φ=n·τ)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

# — n=1 : identity HOLDS (σφ = 1 = nτ) — the other member of {1,6} —
@C tecs_l_n1_sigma := "sigma(1) = 1 (identity at n=1, the other member of {1,6})" :: formula [slug=tecs-l-n6-identity group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 1 1"
  raw    = ".verdicts/tecs-l-n6-identity/n1_sigma.txt"
  src    = "archive-TECS-L (σ·φ=n·τ ⟺ n∈{1,6} uniqueness)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n1_phi := "phi(1) = 1 (identity at n=1)" :: formula [slug=tecs-l-n6-identity group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 1 1"
  raw    = ".verdicts/tecs-l-n6-identity/n1_phi.txt"
  src    = "archive-TECS-L (σ·φ=n·τ ⟺ n∈{1,6} uniqueness)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n1_tau := "tau(1) = 1 (identity at n=1)" :: formula [slug=tecs-l-n6-identity group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 1 1"
  raw    = ".verdicts/tecs-l-n6-identity/n1_tau.txt"
  src    = "archive-TECS-L (σ·φ=n·τ ⟺ n∈{1,6} uniqueness)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

# — n=28 : identity FAILS even though 28 IS perfect (the discriminator) —
@C tecs_l_n28_isperfect := "is_perfect(28) = 1 (28 is the 2nd perfect number)" :: formula [slug=tecs-l-n6-identity group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr is_perfect 28 1"
  raw    = ".verdicts/tecs-l-n6-identity/n28_isperfect.txt"
  src    = "archive-TECS-L perfect_number_engine.py (n∈{6,28,496,8128})"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n28_sigma := "sigma(28) = 56 (→ σφ=672, identity LHS at n=28)" :: formula [slug=tecs-l-n6-identity group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 28 56"
  raw    = ".verdicts/tecs-l-n6-identity/n28_sigma.txt"
  src    = "archive-TECS-L (σ·φ=n·τ closed-negative at 2nd perfect number)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n28_phi := "phi(28) = 12 (→ σφ=672, identity LHS at n=28)" :: formula [slug=tecs-l-n6-identity group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 28 12"
  raw    = ".verdicts/tecs-l-n6-identity/n28_phi.txt"
  src    = "archive-TECS-L (σ·φ=n·τ closed-negative at 2nd perfect number)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n28_tau := "tau(28) = 6 (→ nτ=168 ≠ σφ=672, identity FAILS at n=28)" :: formula [slug=tecs-l-n6-identity group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 28 6"
  raw    = ".verdicts/tecs-l-n6-identity/n28_tau.txt"
  src    = "archive-TECS-L (σ·φ=n·τ closed-negative at 2nd perfect number)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

# ───────────────────────────────────────────────────────────────────────
# TECS-L — tecs-l-arith-stdlib (slug · group=TECS-L · TECS-L.md M2)
# hexa-native arithmetic stdlib module σ/τ/φ/sopfr (stdlib/core/math.hexa),
# replacing archive-TECS-L Python model_utils.py. Each public function's
# known value at n∈{1,6,12,28} is cross-checked against the authoritative
# `hexa verify --expr` g5 recompute (🔵 SUPPORTED-FORMAL) and persisted
# verbatim. sopfr is unit-tested in stdlib/core/math_numtheory_test.hexa
# (textbook prime-factor sums — no --expr handle in the verify binary).

# — sigma(n) = Σ_{d|n} d (divisor sum) —
@C tecs_l_arith_sigma_1 := "sigma(1) = 1 (stdlib core/math sigma, divisor sum)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 1 1"
  raw    = ".verdicts/tecs-l-arith-stdlib/sigma_1.txt"
  src    = "stdlib/core/math.hexa sigma · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

@C tecs_l_arith_sigma_6 := "sigma(6) = 12 (stdlib core/math sigma, divisor sum)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 6 12"
  raw    = ".verdicts/tecs-l-arith-stdlib/sigma_6.txt"
  src    = "stdlib/core/math.hexa sigma · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

@C tecs_l_arith_sigma_12 := "sigma(12) = 28 (stdlib core/math sigma, divisor sum)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 12 28"
  raw    = ".verdicts/tecs-l-arith-stdlib/sigma_12.txt"
  src    = "stdlib/core/math.hexa sigma · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

@C tecs_l_arith_sigma_28 := "sigma(28) = 56 (stdlib core/math sigma, divisor sum)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 28 56"
  raw    = ".verdicts/tecs-l-arith-stdlib/sigma_28.txt"
  src    = "stdlib/core/math.hexa sigma · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

# — tau(n) = #{d | n} (divisor count) —
@C tecs_l_arith_tau_1 := "tau(1) = 1 (stdlib core/math tau, divisor count)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 1 1"
  raw    = ".verdicts/tecs-l-arith-stdlib/tau_1.txt"
  src    = "stdlib/core/math.hexa tau · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

@C tecs_l_arith_tau_6 := "tau(6) = 4 (stdlib core/math tau, divisor count)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 6 4"
  raw    = ".verdicts/tecs-l-arith-stdlib/tau_6.txt"
  src    = "stdlib/core/math.hexa tau · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

@C tecs_l_arith_tau_12 := "tau(12) = 6 (stdlib core/math tau, divisor count)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 12 6"
  raw    = ".verdicts/tecs-l-arith-stdlib/tau_12.txt"
  src    = "stdlib/core/math.hexa tau · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

@C tecs_l_arith_tau_28 := "tau(28) = 6 (stdlib core/math tau, divisor count)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 28 6"
  raw    = ".verdicts/tecs-l-arith-stdlib/tau_28.txt"
  src    = "stdlib/core/math.hexa tau · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

# — phi(n) = Euler totient (alias euler_phi) —
@C tecs_l_arith_phi_1 := "phi(1) = 1 (stdlib core/math phi, Euler totient)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 1 1"
  raw    = ".verdicts/tecs-l-arith-stdlib/phi_1.txt"
  src    = "stdlib/core/math.hexa phi/euler_phi · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

@C tecs_l_arith_phi_6 := "phi(6) = 2 (stdlib core/math phi, Euler totient)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 6 2"
  raw    = ".verdicts/tecs-l-arith-stdlib/phi_6.txt"
  src    = "stdlib/core/math.hexa phi/euler_phi · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

@C tecs_l_arith_phi_12 := "phi(12) = 4 (stdlib core/math phi, Euler totient)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 12 4"
  raw    = ".verdicts/tecs-l-arith-stdlib/phi_12.txt"
  src    = "stdlib/core/math.hexa phi/euler_phi · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."

@C tecs_l_arith_phi_28 := "phi(28) = 12 (stdlib core/math phi, Euler totient)" :: formula [slug=tecs-l-arith-stdlib group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 28 12"
  raw    = ".verdicts/tecs-l-arith-stdlib/phi_28.txt"
  src    = "stdlib/core/math.hexa phi/euler_phi · archive-TECS-L model_utils.py"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim."
