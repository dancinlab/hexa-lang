#!/usr/bin/env tape
# ══════════════════════════════════════════════════════════════════════
# atlas/VERIFY.tape — 3-stage verification protocol + falsifier ≥5 spec
# ══════════════════════════════════════════════════════════════════════
# Cross-link: INDEX.md (overview), MAIN.tape (verdict ledger using this
# protocol), AGENTS.tape (governance — g_self_verify · g_tier_default_insufficient · CLAUDE.md symlink).
#
# anima 의 3-stage protocol carry + falsifier ≥5 pre-register declarative
# format + tier↔stage mapping + Phase 2 hexa-native verifier registry placeholder.
# ══════════════════════════════════════════════════════════════════════

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §0 TL;DR ────────────────────────────────────────────────────────

@N tldr := "verification-protocol-summary-2026-05-15" :: summary [d=2026-05-15 active]
  body <<~EOF
    atlas verdict 부여 protocol:

    Stage 1 symbolic    — closed-form identity / number-theoretic primitives
                          → 🔵 SUPPORTED-IDENTITY / 🔵 FALSIFIED-FORMAL (PASS or FAIL 모두 closed)
    Stage 2 numerical   — ODE/PDE solver / Kuramoto / Onsager / RG / QHO
                          → 🟢 SUPPORTED / 🔴 FALSIFIED / 🟡 PARTIAL
    Stage 3 cross-meta  — atlas edge graph traversal · sibling consistency
                          → 🟢 SUPPORTED-STRONG / 🟡 PARTIAL-CARRY / cascade

    Each fire-eligible verdict entry: falsifier ≥5 pre-register frozen.
    fire 후 추가/수정 금지 (W8 amendment 만, hash + commit).

    Phase 1 (현재): protocol spec 만. Phase 2: hexa-native verifier engine.
  EOF

# ─── §1 Stage 1 — symbolic ───────────────────────────────────────────

@D stage_1 := "Stage 1 — symbolic / closed-form" :: protocol [required d=2026-05-15 active]
  scope = "number-theoretic identity · symbolic algebra · closed-form derivation"
  primitives_required = [divisor_sum, totient, jordan_totient, mobius, factorize, "sum_prime_factors (sopfr)", mersenne, "symbolic_eq simplification", "closed_form_rewrite"]
  hexa_native_module = "compiler/atlas/symbolic/ (Phase 2 신설)"
  pass_criteria = "symbolic equality after canonicalization (e.g. σ(6)=12 ⇔ 1+2+3+6) — sympy-equivalent verdict"
  fail_criteria = "symbolic equality fails OR domain restriction violated"
  outcome_tier_pass = "🔵 SUPPORTED-IDENTITY"
  outcome_tier_fail = "🔵 FALSIFIED-FORMAL"
  cost = "$0 local, 빠름 (~ms per identity)"
  roi_note = "anima 의 A4 math 8/8 모두 sympy closed — Stage 1 이 가장 ROI 높은 closure path"
  artifact_format = "atlas/state/verify/<entry-id>.json (HXC v2 candidate per g_hxc)"

@D stage_1_phase_2_plan := "Stage 1 hexa-native build-out plan" :: roadmap [d=2026-05-15 draft]
  module_layout <<~EOF
    compiler/atlas/symbolic/
    ├── num_theory.hexa     // divisor_sum, totient, jordan, mobius, sopfr, factorize
    ├── sym_expr.hexa       // SymExpr type, simplify, canonical_form
    ├── closed_form.hexa    // identity rewrite rules
    └── verifier.hexa       // verify_identity(SymExpr, SymExpr) -> {Pass, Fail}
  EOF
  bootstrap_seed = "tool/n6_lattice/ 에 이미 일부 number theory primitives 존재 — refactor + 흡수"
  estimated_effort = "1-2 sessions (number theory + sym_expr + verifier)"

# ─── §2 Stage 2 — numerical sim ──────────────────────────────────────

@D stage_2 := "Stage 2 — numerical sim / formal model" :: protocol [required d=2026-05-15 active]
  scope = "ODE/PDE solver · phase transition · oscillator network · RG flow · eigenvalue · Monte Carlo"
  models_in_scope = [Kuramoto, "Onsager 2D Ising", "Ginzburg-Landau φ⁴", "RG Wilson-Fisher", "QHO eigenvalue", "Hopf bifurcation", "Lotka-Volterra", BKT, "Hodgkin-Huxley", STDP, NMDA]
  hexa_native_module = "compiler/atlas/verify/{phys,chem,bio,cosmo}.hexa (Phase 2+ 신설)"
  pass_criteria = "numerical solution within tolerance + cross-check against analytic limit"
  fail_criteria = "numerical divergence OR systematic bias > tolerance"
  outcome_tier_pass = "🟢 SUPPORTED · 🟢 SUPPORTED-STRONG (다중 evidence) · 🔵 SUPPORTED-FORMAL (deterministic formal)"
  outcome_tier_fail = "🔴 FALSIFIED · 🟡 PARTIAL (mixed)"
  cost = "$0 local Mac (CPU) — heavy sim 은 ~10min"
  external_forbidden = "GPU cluster · external dataset · external API → 🟠 DEFERRED (g_external_calc_forbidden)"
  pyphi_iit_status = "PyPhi 등가물은 Phase 1 미포함 — anima 가 떠안음. atlas 는 sympy-tier (Stage 1) 까지만 Phase 1, IIT formal 은 deferred."
  artifact_format = "atlas/state/verify/<entry-id>.json (HXC v2 candidate)"

@D stage_2_phase_2_plan := "Stage 2 hexa-native build-out plan" :: roadmap [d=2026-05-15 draft]
  module_layout <<~EOF
    compiler/atlas/verify/
    ├── ode_solver.hexa     // RK4 · adaptive step
    ├── linalg.hexa         // eigvals · matmul · SVD
    ├── kuramoto.hexa       // mean-field K_c = √(8/π)
    ├── ising.hexa          // Onsager T_c = 2J/log(1+√2)
    ├── rg.hexa             // Wilson-Fisher β(g*)
    ├── qho.hexa            // E_n = ℏω(n+1/2)
    └── domain_dispatch.hexa // route by atlas entry domain prefix
  EOF
  estimated_effort = "3-5 sessions (linalg + ODE + per-model verifier)"
  fft_status = "FFT 빌트인은 Phase 3+ (현재 numerical sim 의 critical path 아님)"

# ─── §3 Stage 3 — cross-meta ─────────────────────────────────────────

@D stage_3 := "Stage 3 — cross-meta consistency" :: protocol [required d=2026-05-15 active]
  scope = "atlas edge graph traversal · sibling consistency · family cohesion · W11 (Red-team) · W9 (sibling)"
  edge_types = ["== continues", "<- caused-by", "-> triggers", ":> generalizes", "<: specializes", "?> soft-depends", "!> conflicts-with"]
  hexa_native_module = "compiler/atlas/verify/cross.hexa (Phase 2+ 신설)"
  pass_criteria = "all sibling entries share verdict tier within ±1 grade · no !> conflicts-with edge to SUPPORTED entry"
  fail_criteria = "sibling tier mismatch > ±1 grade · conflicts-with edge to SUPPORTED entry exists"
  outcome_tier_pass = "🟢 SUPPORTED-STRONG (multi-evidence) · upgrade Stage 2 SUPPORTED → SUPPORTED-STRONG"
  outcome_tier_fail = "🟡 PARTIAL-CARRY · cascade FALSIFIED to daughter entries (-> edges)"
  cost = "$0 local — graph traversal on rodata (compiler/atlas/embedded.gen.hexa ~410 nodes)"
  cascade_pattern = "anima H_191 cascade 패턴 — parent FALSIFIED → daughter PARTIAL-CARRY (Hc_1276/77/78/84)"

# ─── §4 Tier ↔ Stage mapping ─────────────────────────────────────────

@C tier_stage_map := "verdict tier reachability by stage" :: mapping [d=2026-05-15 active]
  tier_🔵_supported_identity = "Stage 1 PASS only"
  tier_🔵_supported_formal = "Stage 2 deterministic PASS (formal sim, e.g. PyPhi-equivalent)"
  tier_🔵_falsified_formal = "Stage 1 FAIL OR Stage 2 deterministic FAIL"
  tier_🟢_supported = "Stage 2 numerical PASS"
  tier_🟢_supported_strong = "Stage 2 PASS + Stage 3 cross-meta PASS"
  tier_🟢_supported_by_proxy = "Stage 3 anchor entry SUPPORTED + carry edge"
  tier_🟡_supported_by_citation = "external literature anchor only (no internal Stage 1/2 PASS) — g_self_verify exception"
  tier_🟡_partial = "Stage 1 partial OR Stage 2 mixed evidence"
  tier_🟡_partial_carry = "Stage 3 parent partial cascade"
  tier_🟠_insufficient = "Stage 1 not attempted OR Stage 2 sim 미실행 (default tier per g_tier_default_insufficient)"
  tier_🟠_deferred = "Stage 1 not applicable (external dependency) — g_external_calc_forbidden"
  tier_🟠_at_risk = "Stage 2 surrogate vs formal sim mismatch"
  tier_🔴_falsified = "Stage 2 numerical FAIL (not formally closed)"
  tier_⚪_not_measured = "no closed-form test exists OR cluster pointer (meta-level)"

# ─── §5 Falsifier ≥5 pre-register declarative format ─────────────────

@D falsifier_format := "falsifier ≥5 pre-register declarative spec" :: protocol [required d=2026-05-15 active]
  rule = "각 fire-eligible verdict entry 는 falsifier 5개 (declarative @F entry) pre-register frozen 후 fire."
  frozen_after_fire = "fire 후 falsifier 추가/수정 금지. W8 amendment (additive_only_mutation) 만 허용 — pre-register hash + sha256 commit."
  declarative_template <<~EOF
    @F f_<entry-id>_<n> := "<falsifier description>" :: falsifier [d=YYYY-MM-DD active]
      parent_entry = "<entry-id from MAIN.tape>"
      pre_register_hash = "<sha256 of falsifier text frozen at fire>"
      executable_form = "compiler/atlas/verify/<domain>.hexa::falsifier_<entry-id>_<n> (Phase 2+)"
      verdict_if_fired = "🔴 FALSIFIED" or "🟡 PARTIAL"  // depends on falsifier severity
      pattern <<~INNER
        구체적 falsifier 텍스트 — 어떤 measurement / sim / identity 가 어떤 결과 나오면
        parent_entry 의 verdict 가 무효화되는지 명확히. ambiguous 금지.
      INNER
  EOF
  count_minimum = 5
  count_maximum = "no upper bound — 더 많을수록 entry 가 robust"
  amendment_pathway = "W8: additive_only_mutation — 새 falsifier 추가 OK, 기존 수정/삭제 금지. 추가 시 새 sha256 + atlas/MAIN.log.tape append (Phase 3)"
  why_5 = "anima 의 W1+W2 verification ladder carry. <5 면 cherry-pick 위험, 5+ 면 entry 가 multiple independent attack 견디는지 체크 가능."

@D falsifier_executable_phase_2 := "Phase 2 executable falsifier form" :: roadmap [d=2026-05-15 draft]
  rule = "Phase 2 시 declarative falsifier 와 동기화되는 executable form: pub fn falsifier_<entry_id>_<n>() -> FalsifierResult"
  return_type <<~EOF
    pub enum FalsifierResult {
      Pass,           // falsifier 가 fire 안 함 — entry verdict 유지
      Fire(String),   // falsifier 가 fire — entry verdict 무효화 (이유 포함)
      Inconclusive,   // 미실행 OR 실행 가능하지만 결과 노이즈 한계 미만
    }
  EOF
  registry = "compiler/atlas/verify/falsifier_registry.hexa — declarative @F id → executable fn pointer mapping"
  ci_integration = "strict-lint stage 9 (Phase 3) 가 모든 fire-eligible entry 의 declarative + executable falsifier presence 검사"

# ─── §6 Tier-aware build (CLI plan) ──────────────────────────────────

@D tier_build := "tier-aware atlas verify CLI" :: roadmap [d=2026-05-15 draft]
  cli_subcommands <<~EOF
    hexa atlas verify [--tier N] [--domain D] [--id ID]
      --tier 1     // Stage 1 symbolic only · pure closed-form (~30s)
      --tier 2     // Stage 2 numerical sim · ODE/PDE (~10min)
      --tier 3     // n/a — atlas 거부 (g_external_calc_forbidden)

    hexa atlas tier <entry-id>            // 현재 tier 조회
    hexa atlas falsifier <entry-id>       // falsifier 5+ 목록
    hexa atlas cycle append <log-entry>   // MAIN.log.tape append (Phase 3)
  EOF
  tool_entry_point = "tool/atlas_verify.hexa (Phase 2 신설)"
  carry_from = "n6-replication tier model (~/core/archive-TECS-L/n6-replication/registry/tier2.json)"

# ─── §7 Verifier registry (Phase 2 placeholder) ──────────────────────

@C verifier_registry := "hexa-native verifier registry" :: registry [d=2026-05-15 placeholder]
  status = "Phase 2 신설 — 본 entry 는 plan 만"
  spec_location = "atlas/MAIN.tape § 도메인 entry body 의 verifier field"
  engine_location = "compiler/atlas/verify/<domain>.hexa::verify_<entry-id>"
  per_domain_files <<~EOF
    compiler/atlas/verify/
    ├── math.hexa           // §2 MATH verifier (Stage 1 dominant)
    ├── phys.hexa           // §3 PHYS verifier (Stage 1 + Stage 2)
    ├── chem.hexa           // §4 CHEM verifier (Stage 2 dominant)
    ├── bio.hexa            // §5 BIO verifier (Stage 2 + AT-RISK 다수)
    ├── cosmo.hexa          // §6 COSMO verifier (Stage 1 + 🟡 SUPPORTED-BY-CITATION)
    ├── geo.hexa            // §7 GEO verifier (Stage 2 + ⚪ NOT-MEASURED 다수)
    ├── top.hexa            // §8 TOP verifier (Stage 1 + Galois closed)
    ├── eng.hexa            // §9 ENG verifier (Stage 2 + ⚪ NOT-MEASURED 다수)
    ├── foundation.hexa     // §1 N6-FOUNDATION verifier (Stage 1 only)
    ├── bridges.hexa        // §10 BRIDGES verifier (Stage 3 cross-meta dominant)
    ├── cross.hexa          // Stage 3 graph traversal engine
    ├── ode_solver.hexa     // Stage 2 ODE primitives
    ├── linalg.hexa         // Stage 2 eigvals · matmul
    ├── falsifier_registry.hexa // declarative ↔ executable mapping
    └── domain_dispatch.hexa // entry id prefix → verifier dispatch
  EOF
  codegen = "tool/atlas_verify_gen.hexa (Phase 2) — atlas/MAIN.tape + VERIFY.tape 읽어 stub generate"

# ─── §8 Cycle protocol ───────────────────────────────────────────────

@D cycle := "verdict cycle protocol" :: protocol [d=2026-05-15 active]
  steps <<~EOF
    1. Submit: atlas/incoming/<descriptive-name>.md (한 개념 = 한 파일)
    2. Reviewer attaches verdict tier (default 🟠 INSUFFICIENT) + axis (도메인 §X) +
       evidence + anchor (real-limit per g3) + falsifier ≥5 pre-register
    3. Falsifier fire pre-register hash frozen + committed
    4. Stage 1/2/3 verifier 실행 (Phase 2+) OR manual cite (Phase 1, 🟡 SUPPORTED-BY-CITATION 한정)
    5. Tier 결정 (PASS → SUPPORTED-tier ladder · FAIL → FALSIFIED-tier · partial → PARTIAL)
    6. Append to atlas/MAIN.tape § 해당 도메인 section
    7. Append to atlas/MAIN.log.tape (Phase 3 automation)
    8. Optional: cascade check — daughter entries (-> edges) 의 verdict 재평가 (Stage 3)
  EOF
  log_format = "tape v1.2 — UPPERCASE.log.tape sibling per g_arch_vs_log_split"
  amendment = "verdict 변경 시 ~> supersedes edge + 새 evidence/anchor + atlas/MAIN.log.tape append (절대 silent upgrade 금지 per f_atlas_silent_upgrade)"

# ─── §9 Phase rollout ────────────────────────────────────────────────

@D phase_rollout := "VERIFY.tape phase plan" :: roadmap [d=2026-05-15 active]
  phase_1_done = "spec layer (本 VERIFY.tape + MAIN.tape + INDEX.md + AGENTS.tape + incoming/) — 2026-05-15"
  phase_2_next <<~EOF
    Stage 1 hexa-native: compiler/atlas/symbolic/ (number theory + sym_expr + verifier)
    tool/atlas_verify.hexa CLI entry point
    --tier 1 동작
    domain dispatch (math.hexa 부터)
    Stage 1 으로 닿는 anchor entry 들 🔵 SUPPORTED-IDENTITY upgrade
  EOF
  phase_3_landed <<~EOF
    ✅ Stage 2 hexa-native (libm sqrt/log/exp/lgamma + Newton — cycle 008-015·019)
    ✅ Stage 3 cross-meta engine (compiler/atlas/verify/cross.hexa — cycle 019)
    ✅ Falsifier executable form + sha256 freeze registry (falsifier.hexa — cycle 021-022)
    ✅ strict-lint stage 9 atlas-verdict-check (test/atlas_verify_smoke.hexa CI gate — cycle 024;
       14-module full-suite regression gate, exit(1) + grep-detectable FAIL string,
       runnable via `hexa run test/atlas_verify_smoke.hexa`)
    ✅ T2-01 χ→Monster full 8-step chain (modular.hexa — cycle 023)
  EOF
  phase_3_deferred <<~EOF
    Stage 2 BIO PyPhi-equiv (V8 mechanism real impl — anima carry, IIT 3.0 large sprint)
    atlas/MAIN.log.tape append automation (commit hook)
    hexa dispatcher binary rebuild → `hexa atlas-verify` activation (currently source-wired)
    falsifier sha256-commit hook automation (currently source = registry)
    wilson chat 통합 (wilson atlas verify)
    HTML 시각화 (atlas/MAIN.tape → static HTML codegen)
    falsifier batteries 나머지 ~85 🔵 entries 확장 (현재 8 batteries)
  EOF
