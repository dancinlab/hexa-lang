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
# TECS-L — tecs-l-dedekind-psi-uniqueness (slug · group=TECS-L · TECS-L.md M3)
# Dedekind-ψ discrepancy, re-grounded hexa-native via `hexa verify` g5.
#
#   D(n) = σ(n)·φ(n) − n·τ(n)     D(n) = 0   ⟺   n ∈ {1, 6}
#
# Matches archive-TECS-L math/dfs_dedekind_psi_discrepancy.py D(n)=σφ−nτ
# (σ = divisor sum · τ = divisor count · φ = Euler totient — identical defs).
# There is NO single `--expr` fn for D(n); D(n) is exact integer arithmetic
# over the three g5-verified component values. The terminal result is an
# EXHAUSTIVE FINITE SWEEP n=1..100, cross-checked component-wise against
# `hexa verify --expr` on the load-bearing n:
#   D(1)  = 1·1 − 1·1   = 0           → ZERO  ✓   (member of {1,6})
#   D(6)  = 12·2 − 6·4  = 24−24 = 0   → ZERO  ✓   (member of {1,6})
#   D(28) = 56·12 − 28·6 = 672−168 = 504  → ≠0    (2nd perfect number, is_perfect=1)
#   D(2)  = 3·1 − 2·2   = −1          → ≠0       (only negative D in range)
#   D(3)=2 · D(4)=2 · D(12)=40 · D(30)=336 …  all ≠0
# Sweep zero-count(1..100) = 2, zeros at {1, 6} — exhaustive finite
# confirmation of {1,6} uniqueness over n∈[1,100].
#
# SCOPE (honest): the FINITE sweep 1..100 is the terminal 🔵 (zeros at {1,6})
# + 🔴 CLOSED-negative (D(n)≠0 elsewhere in range) result actually produced.
# The ALL-n (unbounded) uniqueness D(n)=0 ⟺ n∈{1,6} needs the analytic
# argument from archive-TECS-L — cited as 🟡 SUPPORTED-BY-CITATION for the
# unbounded claim, gated OUT of /paper. Do NOT over-claim a full proof from
# a finite sweep.

# — sweep artifact: full n=1..100 σ/φ/τ/D table + "zeros at: 1, 6" line —
@C tecs_l_dpsi_sweep := "D(n)=σφ−nτ sweep n=1..100: zero-count=2, zeros at {1,6} (exhaustive finite)" :: fixpoint [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "fixpoint"
  cmd    = "hexa build tmp_tecs_m3_sweep.hexa && ./tecs_m3_sweep  (σ/φ/τ/D for n=1..100)"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/sweep_D_1_100.txt"
  src    = "archive-TECS-L math/dfs_dedekind_psi_discrepancy.py (D(n)=σφ−nτ, n=6/28 uniqueness)"
  status = "🔵 SUPPORTED-FORMAL (zeros {1,6}) + 🔴 CLOSED-negative (D≠0 elsewhere in 1..100). terminal · paper-eligible. components cross-checked vs `hexa verify --expr`."

# — D(1)=0 : member of {1,6}. components reference existing tecs-l-n6-identity verdicts —
@C tecs_l_dpsi_n1_zero := "D(1) = σ(1)·φ(1) − 1·τ(1) = 1·1 − 1·1 = 0 (member of {1,6})" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 1 1 ; phi 1 1 ; tau 1 1  → D=1·1−1·1=0"
  raw    = ".verdicts/tecs-l-n6-identity/n1_sigma.txt"
  src    = ".verdicts/tecs-l-n6-identity/{n1_sigma,n1_phi,n1_tau}.txt (reused — identical components)"
  status = "🔵 SUPPORTED-FORMAL — components persisted verbatim (n6-identity). D(1)=0 exact-integer. terminal · paper-eligible."

# — D(6)=0 : member of {1,6}. components reference existing tecs-l-n6-identity verdicts —
@C tecs_l_dpsi_n6_zero := "D(6) = σ(6)·φ(6) − 6·τ(6) = 12·2 − 6·4 = 24−24 = 0 (member of {1,6})" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 6 12 ; phi 6 2 ; tau 6 4  → D=12·2−6·4=0"
  raw    = ".verdicts/tecs-l-n6-identity/n6_sigma.txt"
  src    = ".verdicts/tecs-l-n6-identity/{n6_sigma,n6_phi,n6_tau}.txt (reused — identical components)"
  status = "🔵 SUPPORTED-FORMAL — components persisted verbatim (n6-identity). D(6)=0 exact-integer. terminal · paper-eligible."

# — D(28)=504 ≠ 0 : 2nd perfect number where D≠0. components reuse n6-identity —
@C tecs_l_dpsi_n28_nonzero := "D(28) = σ(28)·φ(28) − 28·τ(28) = 56·12 − 28·6 = 672−168 = 504 ≠ 0 (2nd perfect number)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr is_perfect 28 1 ; sigma 28 56 ; phi 28 12 ; tau 28 6  → D=504≠0"
  raw    = ".verdicts/tecs-l-n6-identity/n28_isperfect.txt"
  src    = ".verdicts/tecs-l-n6-identity/{n28_isperfect,n28_sigma,n28_phi,n28_tau}.txt (reused)"
  status = "🔵 SUPPORTED-FORMAL + 🔴 CLOSED-negative — is_perfect(28)=1 yet D(28)=504≠0: D=0 is NOT a perfect-number property. terminal · paper-eligible."

# — representative non-zero n: D(n)≠0 for every n∉{1,6} in 1..100. one @C
#   per persisted component verdict file (1:1 raw pointer, no orphans). the
#   D(n) value of each row is exact integer arithmetic over its 3 components:
#     D(2)=3·1−2·2=−1 (sole negative) · D(3)=4·2−3·2=2 · D(4)=7·2−4·3=2
#     D(12)=28·4−12·6=40 · D(30)=72·8−30·8=336

# D(2) = −1 (the only negative D in range)
@C tecs_l_dpsi_n2_sigma := "sigma(2) = 3 (D(2)=σφ−nτ=3·1−2·2=−1 ≠ 0, sole negative in 1..100)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 2 3"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n2_sigma.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep — sole negative discrepancy in 1..100)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_dpsi_n2_phi := "phi(2) = 1 (D(2)=σφ−nτ=−1 ≠ 0 component)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 2 1"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n2_phi.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_dpsi_n2_tau := "tau(2) = 2 (D(2)=σφ−nτ=−1 ≠ 0 component)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 2 2"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n2_tau.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

# D(3) = 2
@C tecs_l_dpsi_n3_sigma := "sigma(3) = 4 (D(3)=σφ−nτ=4·2−3·2=2 ≠ 0)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 3 4"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n3_sigma.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep — non-member of {1,6})"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_dpsi_n3_phi := "phi(3) = 2 (D(3)=2 ≠ 0 component)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 3 2"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n3_phi.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_dpsi_n3_tau := "tau(3) = 2 (D(3)=2 ≠ 0 component)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 3 2"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n3_tau.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

# D(4) = 2
@C tecs_l_dpsi_n4_sigma := "sigma(4) = 7 (D(4)=σφ−nτ=7·2−4·3=2 ≠ 0)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 4 7"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n4_sigma.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep — non-member of {1,6})"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_dpsi_n4_phi := "phi(4) = 2 (D(4)=2 ≠ 0 component)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 4 2"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n4_phi.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_dpsi_n4_tau := "tau(4) = 3 (D(4)=2 ≠ 0 component)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 4 3"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n4_tau.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

# D(12) = 40
@C tecs_l_dpsi_n12_sigma := "sigma(12) = 28 (D(12)=σφ−nτ=28·4−12·6=40 ≠ 0)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 12 28"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n12_sigma.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep — non-member of {1,6})"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_dpsi_n12_phi := "phi(12) = 4 (D(12)=40 ≠ 0 component)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 12 4"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n12_phi.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_dpsi_n12_tau := "tau(12) = 6 (D(12)=40 ≠ 0 component)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 12 6"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n12_tau.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

# D(30) = 336
@C tecs_l_dpsi_n30_sigma := "sigma(30) = 72 (D(30)=σφ−nτ=72·8−30·8=336 ≠ 0)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 30 72"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n30_sigma.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep — non-member of {1,6})"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_dpsi_n30_phi := "phi(30) = 8 (D(30)=336 ≠ 0 component)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 30 8"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n30_phi.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_dpsi_n30_tau := "tau(30) = 8 (D(30)=336 ≠ 0 component)" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 30 8"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/n30_tau.txt"
  src    = "archive-TECS-L (D(n)=σφ−nτ sweep)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

# — unbounded uniqueness residual (honest scope statement) —
@C tecs_l_dpsi_unbounded := "D(n)=0 ⟺ n∈{1,6} for ALL n (unbounded) — analytic argument from archive" :: formula [slug=tecs-l-dedekind-psi-uniqueness group=TECS-L]
  method = "fence"
  cmd    = "archive-TECS-L math/dfs_dedekind_psi_discrepancy.py (analytic n→∞ argument)"
  raw    = ".verdicts/tecs-l-dedekind-psi-uniqueness/sweep_D_1_100.txt   # finite witness only — NOT a proof of the unbounded claim"
  status = "🟡 SUPPORTED-BY-CITATION — unbounded claim cited (archive); finite sweep 1..100 is the terminal witness. residual gated OUT of /paper. do NOT over-claim full proof from finite sweep."
