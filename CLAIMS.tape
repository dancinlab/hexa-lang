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
# GPU — fusion-epilogue-gemm-bias-gelu (slug · group=GPU · paper-track)
# Whole-program-fusion epilogue: a single hexa-emit kernel computing
# GeLU(A@B + bias) fuses the GEMM + bias-add + GeLU into one launch with the
# M x N result written to HBM ONCE — vs a cuBLAS-using stack (cublasSgemm →
# bias-add kernel → GeLU kernel) = 3 launches + 3x M x N HBM C-write traffic.
# Structural launch+HBM advantage proven closed-form (deterministic oracle,
# compiled hexa) AND ptxas-clean (sm_80). Timed wall DEFERRED (serial).

@C fusion_epilogue_gemm_bias_gelu := "fused GeLU(A@B+bias) = 1 launch + 1x M*N HBM C-write vs cuBLAS 3 + 3x = 66.667% reduction both axes" :: fixpoint [slug=fusion-epilogue-gemm-bias-gelu group=GPU]
  method = "fixpoint"
  cmd    = "tool/fusion_epilogue_structural_oracle.hexa (compiled hexa, deterministic launch/byte count) + ptxas -arch=sm_80 fused_gemm_bias_gelu.ptx"
  raw    = ".verdicts/fusion-epilogue-gemm-bias-gelu/fusion_epilogue_structural.txt"
  src    = "archive/fires/fusion_epilogue_gemm_bias_gelu_2026_05_25/ (fused_gemm_bias_gelu.ptx md5 1d738055… · oracle_run.log · ptxas.log) + GPU.md section 10"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim (oracle PASS 66.667% launch AND HBM reduction · ptxas RC=0 sm_80 0-spill). terminal · paper-eligible. Timed wall DEFERRED to serial follow-up; GPU.md section 10 >=30% box stays [ ]."

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
# GPU — fusion-attention-flash (slug · group=GPU · paper-track · GPU.md §10)
# The §10 moat case cuBLAS structurally CANNOT do: a single fused
# flash-attention kernel computing softmax(Q K^T/sqrt(d))V with online-
# softmax tiling (S never to HBM). Structural clause PROVEN closed-form;
# WALL clause FALSIFIED (closed-negative — naive scalar kernel slower than
# cuBLAS Tensor Cores). Both verdicts terminal, REAL, persisted verbatim.

@C fusion_attn_flash_structural := "fused flash-attention = 1 launch + 0 S-HBM vs cuBLAS-baseline 3 launches + O(N^2) S; total-HBM ratio R(N,d)=1.25+N/d (33.25x @ N=2048,d=64)" :: formula [slug=fusion-attention-flash group=GPU]
  method = "fixpoint"
  cmd    = "cc -O2 structural_oracle.c && ./structural_oracle ; hexa build ratio_check.hexa && ./fa_ratio_check"
  raw    = ".verdicts/fusion-attention-flash/F-FUSION-ATTENTION-FLASH.txt"
  src    = "archive/fires/fusion_attention_flash_2026_05_25/{structural_oracle.c,ratio_check.hexa,flash_attn.ptx}"
  status = "🔵 SUPPORTED-FORMAL — closed-form HBM ratio reproduced by hexa-native compile. REAL verdict persisted verbatim. terminal · paper-eligible."

@C fusion_attn_flash_wall := "a NAIVE fused flash-attention kernel does NOT beat a cuBLAS Tensor-Core attention stack on wall — 1.4-1.5x SLOWER at N in {512..4096} d=64 (RTX 5070, 200 timed)" :: measurement [slug=fusion-attention-flash group=GPU]
  method = "fixpoint"
  cmd    = "ubu-2 RTX 5070: fused_host flash_attn.ptx vs cublas_base, cudaEvent 20 warmup 200 timed median"
  raw    = ".verdicts/fusion-attention-flash/F-FUSION-ATTENTION-FLASH.txt"
  src    = "tool/fusion_attn_flash_host.c + tool/fusion_attn_cublas_baseline.c"
  status = "🔴 CLOSED-NEGATIVE — wall >=30% FALSIFIED, ruled-out axis (fusion alone insufficient; needs Tensor-Core inner GEMMs). REAL verdict persisted verbatim. terminal · paper-eligible."

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

# ───────────────────────────────────────────────────────────────────────
# TECS-L — tecs-l-n6-characterizations (slug · group=TECS-L · TECS-L.md M4)
# archive-TECS-L "206 n=6 characterizations" g5 triage (M4). The headline 206
# is the archive's numbered series #1…#206 (math/README.md line 4437); the
# overwhelming majority are SYMBOLIC uniqueness claims (f(n)=g(n) ⟺ n=6) with
# NO hexa closed-form recompute path for the [2,N] universal — those stay 🟡
# (same handling as the σφ=nτ uniqueness residual in M1). What IS verifiable-
# now: the n=6 GROUND arithmetic values each characterization is built from,
# plus the modular-curve values the catalogue cites (X₀(6) index=σ, cusps=τ,
# genus 0). 15 atoms recomputed closed-form (each 🔵). Triage doc:
# docs/tecs-l/n6-characterizations-triage.md (verifiable / citation / deferred
# counts, honest per M4 method §3). Quality over quantity (method §2 cap).

@C tecs_l_n6char_sigma := "sigma(6) = 12 (divisor sum; shared factor of σφ=nτ #1, σ=nφ #81, 2σ=nτ #60, X₀(36) cusps=σ)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma 6 12"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_sigma.txt"
  src    = "archive-TECS-L math/README.md #1/#81/#60 + characterization_verifier.py KNOWN_CHARS"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_tau := "tau(6) = 4 (divisor count; factor of n-2=τ Cayley #59, σφ=nτ #1, τ=2φ)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr tau 6 4"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_tau.txt"
  src    = "archive-TECS-L math/README.md #59/#1"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_phi := "phi(6) = 2 (Euler totient; factor of φ²=τ #33, σ=nφ #81, self-mirror CY₃ h11=h21=φ #208)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr phi 6 2"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_phi.txt"
  src    = "archive-TECS-L math/README.md #33/#81/#208"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_mu := "mu(6) = 1 (Mobius; +1 since 6=2·3 has an even number of prime factors; factor of μ·s=n #86)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr mu 6 1"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_mu.txt"
  src    = "archive-TECS-L math/README.md #86 (Mobius × aliquot)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_is_perfect := "is_perfect(6) = 1 (6 = 1st perfect number, σ(6)=2·6; anchor of all perfect-number characterizations)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr is_perfect 6 1"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_is_perfect.txt"
  src    = "archive-TECS-L perfect_number_engine.py (n∈{6,28,496,8128})"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_aliquot := "aliquot(6) = 6 (proper-divisor sum s(6)=σ-n=6=n, the perfect-number defn; value in s(n)=6 ⟺ {6,25} #72)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr aliquot 6 6"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_aliquot.txt"
  src    = "archive-TECS-L math/README.md #72 (aliquot sum = P₁)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_sigma0 := "sigma_0(6) = 4 (σ_k at k=0 = τ; divisor count via the σ_k family)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma_0 6 4"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_sigma0.txt"
  src    = "archive-TECS-L math/README.md (σ_k divisor-power family)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_sigma2 := "sigma_2(6) = 50 (sum of squares of divisors 1+4+9+36; LHS of σ₂=φ·sopfr² #92 = 2·25, σ₂=2·sopfr² #152)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma_2 6 50"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_sigma2.txt"
  src    = "archive-TECS-L math/README.md #92/#152"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_sigma3 := "sigma_3(6) = 252 (sum of cubes of divisors 1+8+27+216; σ_k family k=3, σ₃=τ(2ⁿ-1) #H-CODE-1)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr sigma_k 6 3 252"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_sigma3.txt"
  src    = "archive-TECS-L math/README.md #H-CODE-1 (σ₃ divisor-cube)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_gamma0_index := "gamma0_index(6) = 12 = sigma(6) (Γ₀(6) index = σ; X₀(36) cusps = 12 = σ, math/README.md line 1285)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr gamma0_index 6 12"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_gamma0_index.txt"
  src    = "archive-TECS-L math/README.md line 1285/677 (modular curve X₀(6) / level n²)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_gamma0_cusps := "gamma0_cusps(6) = 4 = tau(6) (Γ₀(6) cusp count = τ)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr gamma0_cusps 6 4"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_gamma0_cusps.txt"
  src    = "archive-TECS-L math/README.md (X₀(6) cusps)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_gamma0_genus := "gamma0_genus(6) = 0 (X₀(6) is the unique genus-0 modular curve among perfect numbers, math/README.md line 2612)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr gamma0_genus 6 0"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_gamma0_genus.txt"
  src    = "archive-TECS-L math/README.md line 2612/416 (genus X₀(6)=0, unique perfect)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_first_cusp_weight := "first_cusp_form_weight(6) = 4 = tau(6) (smallest weight with a nonzero cusp form for Γ₀(6); calc-fn defn, NOT the archive's lcm(4,6)=12 reading)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr first_cusp_form_weight 6 4"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_first_cusp_form_weight.txt"
  src    = "hexa calc first_cusp_form_weight (archive line 1550 uses a different defn — honest divergence noted in triage §1 C13)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_dim_cusp_forms := "dim_cusp_forms(6,2) = 0 (dimension of weight-2 cusp forms on Γ₀(6) = 0, consistent with genus 0)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr dim_cusp_forms 6 2 0"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_dim_cusp_forms.txt"
  src    = "archive-TECS-L math/README.md line 2612 (genus 0 ⟹ S₂ dim 0)"
  status = "🔵 SUPPORTED-FORMAL — REAL verdict persisted verbatim. terminal · paper-eligible."

@C tecs_l_n6char_conductor := "pair_threshold_factor(6) = 36 = n² (conductor n²=36 for X₀ at level n, math/README.md line 677)" :: formula [slug=tecs-l-n6-characterizations group=TECS-L]
  method = "expr"
  cmd    = "hexa verify --expr pair_threshold_factor 6 36"
  raw    = ".verdicts/tecs-l-n6-characterizations/n6_conductor.txt"
  src    = "archive-TECS-L math/README.md line 677 (Conductor = n² = 36)"
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
