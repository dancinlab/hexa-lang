#!/usr/bin/env tape
# ══════════════════════════════════════════════════════════════════════
# atlas/AGENTS.tape — atlas-area governance (tape v1.2 · CLAUDE.md symlink)
# ══════════════════════════════════════════════════════════════════════
# Cross-link: ../AGENTS.tape (project-level g1~g8 — 본 파일은 atlas-area
# specific governance 만; project 거버넌스는 inherit), ../LATTICE_POLICY.md,
# ../HEXA-NATIVE-ONLY.md, INDEX.md, MAIN.tape, VERIFY.tape.
#
# atlas verdict ledger 의 거버넌스. anima g1~g8 carry + atlas-specific
# 추가 3 (g_self_verify · g_tier_default_insufficient · g_external_calc_forbidden).
# ══════════════════════════════════════════════════════════════════════

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §1 Inheritance ──────────────────────────────────────────────────

@I a_inherit := "atlas-area governance inheritance" :: identity-claim [d=2026-05-15 active]
  rule = "atlas/ 디렉토리는 project-level ../AGENTS.tape g1~g8 + LATTICE_POLICY.md + HEXA-NATIVE-ONLY.md 의 모든 거버넌스를 inherit. 본 파일은 atlas-area specific 추가/특화 만 정의."
  why = "single-source governance — atlas 만의 별도 룰 만들지 말고 project 룰 carry"
  apply = "atlas/MAIN.tape verdict entry 작성 시 g1 (real-limits-first) · g2 (lattice-as-tool) · g4 (honesty-obligation-external) · g5 (hexa-native-only) · g6 (citation-enforced) · g7 (inbox-patches-pipeline) · g_arch_vs_log_split 모두 자동 적용"

# ─── §2 anima g1~g8 carry (atlas adaptation) ─────────────────────────

@D g1 := "real-limits-first (atlas)" :: governance [required carry-from:anima]
  rule = "atlas verdict tier 부여 시 verification anchor 는 LATTICE_POLICY.md §1.2 의 REAL limits 중 최소 1개 포함. lattice-tautology (σ·φ=n·τ at n=6) 단독 verification 금지."
  real-limits = [Shannon, Kolmogorov, Bekenstein, c, ℏ, k, Stefan-Boltzmann, Carnot, "compiler invariant (type-soundness · termination · register-allocator NP-completeness)"]
  why = "dancinlab-wide real-limits-first verification policy carry"
  authority = "../LATTICE_POLICY.md §1.2"
  apply = "MAIN.tape entry body 의 anchor field 는 real_limit_anchor sub-field 강제 (verifier 가 stage 9 strict-lint 에서 검사 — Phase 3)"

@D g2 := "lattice-as-tool (atlas)" :: governance [required carry-from:anima]
  rule = "atlas 의 N6-FOUNDATION 도메인 (n=6 + σ/τ/φ/sopfr/J2/μ/M3 primitives + perfect-number lattice) 은 internal arch TOOL. external entry (PHYS-CMB-spectral-index 등) 의 verdict anchor 로 사용 금지."
  apply = "MAIN.tape §1 N6-FOUNDATION 의 entries 는 § verdict 가 다른 § (§2 MATH ~ §9 ENG) 의 anchor 가 될 수 없음. external entry 는 sympy-equiv closed-form / Kuramoto / Onsager 등 own anchor 사용."
  why = "lattice 가 derivation rule 이 아니라 observation. 외부 system 에 강제 시 honesty 위반."
  authority = "../LATTICE_POLICY.md"
  <: g1

@D g3 := "verification-anchor-real-limit (atlas)" :: governance [required carry-from:anima]
  rule = "atlas verdict 의 evidence field 는 Stage 1 symbolic outcome 외 real-limit anchor 추가 mandatory."
  insufficient = "lattice-tautology 단독 (e.g. σ(6)·φ(6)=6·τ(6) 검증 — definitional truth)"
  apply = "MAIN.tape entry body 의 stage field + anchor field 분리 — stage = 'Stage 1 — symbolic identity (W2)' / anchor = '[Bekenstein bound] / [Shannon entropy] / [Carnot]'"
  <: g1

@D g4 := "honesty-obligation-external (atlas)" :: governance [required deny:write carry-from:anima]
  rule = "external entity (TSMC/ASML/NIST/IEEE/ISO 등) 또는 external compiler ecosystem (Rust/Swift/Zig/OCaml/GHC/LLVM/MSVC/gcc/clang) 에 lattice-fit assertion 금지. atlas verdict 부여 자체 거부."
  remedy = "external ecosystem 의 OWN invariants 사용 (Rust borrow-checker / GHC type-class lookup / LLVM SSA 등)"
  apply = "MAIN.tape 에 'PHYS-* with lattice derivation' 또는 'ENG-rust-borrow-checker SUPPORTED via σ' 같은 entry 거부. 외부 시스템은 own-axiom basis."
  see = "../compiler/atlas/external_entity_audit.hexa (이미 존재하는 audit) 와 통합"

@D g5 := "hexa-native-only (atlas)" :: governance [required deny:write carry-from:anima]
  rule = "atlas verdict 의 verifier 구현은 hexa-lang 자체 (compiler/atlas/symbolic/ + verify/). 외부 sympy/PyPhi/numpy/torch 결과 cite 또는 임포트 금지."
  apply = "Phase 2 Stage 1 symbolic 은 hexa-native number-theoretic primitives. anima 가 sympy 로 한 결과는 evidence-by-citation (🟡 SUPPORTED-BY-CITATION) tier 만 가능, 🔵 SUPPORTED-IDENTITY 자동 부여 X."
  fallback = "C 백엔드는 portable 아티팩트로만 사용 — verifier 자체는 hexa source"
  authority = "../HEXA-NATIVE-ONLY.md"

@D g6 := "citation-enforced-strict-lint (atlas)" :: governance [required carry-from:anima]
  rule = "verdict-bearing entry 의 every formula-bearing line 은 atlas theorem 을 @cite. strict-lint stage 4 가 reject."
  stages = "8 strict-lint stages — atlas integrity check, citation match, formula well-formedness, etc."
  apply = "MAIN.tape verdict entry body 의 formula 는 atlas entry id 로 cite (e.g. evidence = 'σ(6)=12 [@P sigma]'). bare formula 거부."
  authority = "../SPEC.md"

@D g7 := "inbox-patches-pipeline (atlas)" :: governance [required carry-from:anima]
  rule = "atlas 외부 (downstream wilson/echoes/anima · external contributor) 의 새 verdict 제출은 atlas/inbox/<descriptive-name>.md (한 개념 = 한 파일) 통과."
  flow = "[downstream consumer 또는 external] → atlas/inbox/ → reviewer verdict tier 부여 + falsifier ≥5 → atlas/MAIN.tape 의 해당 § 도메인 append → atlas/MAIN.log.tape append (Phase 3)"
  forbidden = "consumer 또는 external 가 atlas/MAIN.tape 직접 편집"

@D g8 := "commit-trailer-co-author" :: governance [recommended carry-from:anima]
  rule = "AI-assisted atlas verdict commit 은 trailer 포함: Co-Authored-By: <model> <noreply@anthropic.com>"

# ─── §3 atlas-specific governance (3 추가) ───────────────────────────

@D g_self_verify := "atlas self-verifying closure" :: governance [required d=2026-05-15 active]
  rule = "atlas 로 들어오는 모든 entry 는 atlas 자체 verifier (hexa-native, compiler/atlas/verify/) 로 검증. 외부 (Python sympy / Mathematica / Wolfram) 결과 cite 만으로 verdict tier 부여 금지."
  why = "self-hosting closure — atlas 가 own verdict 의 SSOT 이자 own verifier 의 SSOT. 외부 결과 의존 시 atlas 의 self-hosted 정체성 깨짐."
  exception = "Phase 2 verifier 미완 동안의 임시 carry — anima 의 sympy 결과 cite 시 🟡 SUPPORTED-BY-CITATION tier 한정. 🔵 SUPPORTED-IDENTITY 는 hexa-native verifier PASS 후에만."
  apply = "MAIN.tape entry 의 verifier field 는 hexa-native verifier path (compiler/atlas/verify/<domain>.hexa::verify_<id>) 또는 'pending Phase 2' 명시"
  authority = "INDEX.md §A1"
  <: g5

@D g_tier_default_insufficient := "atlas verdict default tier" :: governance [required d=2026-05-15 active]
  rule = "atlas entry 가 verdict 미부여 상태일 때 default tier 는 🟠 INSUFFICIENT. 자동으로 🟢 SUPPORTED 또는 🔵 SUPPORTED-IDENTITY 부여 금지."
  why = "honesty-by-default — 검증 안 된 entry 는 명시적으로 INSUFFICIENT, '아직 verdict 안 됐다' 가 명확히 보여야 함. silent SUPPORTED 가정은 g4 honesty 위반."
  apply = "MAIN.tape §X 도메인 section 의 entry 가 individual verdict tag 없으면 §X header 의 'default tier: 🟠 INSUFFICIENT' 적용. cycle 진행 시 individual tier 부여 → upgrade."
  cascade = "parent entry INSUFFICIENT 면 daughter (--> edges 로 따라가는 child) 도 자동 PARTIAL-CARRY"

@D g_external_calc_forbidden := "external calc dependency forbidden" :: governance [required deny:write d=2026-05-15 active]
  rule = "atlas verdict tier 부여 시 외부 hardware (GPU 클러스터, EEG 장비, particle accelerator), 외부 dataset (HuggingFace dataset, Kaggle), 외부 API 결과 의존 시 자동 🟠 DEFERRED tier."
  why = "atlas 의 self-verifying closure (g_self_verify) 에서 외부 의존 entry 는 closure 밖. 'verified' claim 부적절."
  apply = "MAIN.tape 의 §15 DEFERRED section 으로 분리. 외부 의존 해소 시 (e.g. EEG 데이터 acquisition + atlas 흡수) → 정식 § 도메인 으로 promote."
  exception = "literature citation (e.g. Onsager 1944, Bekenstein 1981) 은 외부 의존 X — 이미 publish 된 closed-form 의 cite 는 🟡 SUPPORTED-BY-CITATION tier 가능 (g_self_verify exception 과 일관)"
  <: g_self_verify

# ─── §4 Forbidden patterns (atlas-specific 추가) ────────────────────

@F f_atlas_lattice_external := "lattice-fit on external entity in verdict" :: governance [required deny:write]
  pattern = "MAIN.tape 의 PHYS / CHEM / BIO / COSMO / GEO / TOP / ENG / BRIDGES 도메인 entry 의 evidence/anchor field 에 σ(6)=12 / τ(6)=4 / φ(6)=2 / J₂(6)=24 를 derivation rule 로 사용"
  exception = "values may coincidentally match — observation OK in honest_c3 field, derivation NOT OK in evidence field"
  see = "g2 lattice-as-tool"
  <: g4

@F f_atlas_external_verdict := "external-only evidence as 🔵 verdict" :: governance [required deny:write]
  pattern = "external Python sympy/PyPhi/numpy 결과만으로 🔵 SUPPORTED-IDENTITY 또는 🔵 SUPPORTED-FORMAL tier 부여"
  remedy = "🟡 SUPPORTED-BY-CITATION tier 부여 (literature anchor 동급) 또는 Phase 2 hexa-native verifier 완성 후 재검증"
  see = "g_self_verify"

@F f_atlas_silent_upgrade := "silent verdict upgrade without re-verification" :: governance [required deny:write]
  pattern = "이전 verdict 의 evidence/anchor 변경 없이 tier 만 올림 (e.g. 🟠 INSUFFICIENT → 🟢 SUPPORTED)"
  remedy = "tier 변경 시 ~> supersedes edge + 새 evidence/anchor + atlas/MAIN.log.tape append (Phase 3)"
  see = "g_tier_default_insufficient"

# ─── §5 External citations ───────────────────────────────────────────

@X x_anima_index := "anima INDEX.md (carry source)" :: spec [d=2026-05-15 active]
  url = "https://github.com/dancinlab/anima/blob/main/INDEX.md"
  scope = "verdict 검증 기준 SSOT — atlas 는 본 ledger 의 14-tier · 9-axis · 3-stage protocol 을 carry"

@X x_archive_tecs_l := "archive-TECS-L docs/proofs T-series" :: archive [d=2026-05-15 active]
  url = "local: ~/core/archive-TECS-L/docs/proofs/"
  scope = "T0/T1/T2 proofs 43 — MAIN.tape §2 MATH 의 anchor seed source. T0-01 sigma-perfect-6 / T1-26 phi-sigma-unique / T1-30 ising-critical / T1-23 137-from-sigma-tau 등"

@X x_n6_replication := "n6-replication tier model" :: spec [d=2026-05-15 active]
  url = "local: ~/core/archive-TECS-L/n6-replication/"
  scope = "Tier 1 (pure-math, ~30s) / Tier 2 (full numerical, ~10min) / Tier 3 (GPU, deferred) — atlas 의 --tier 1/2 CLI 모델"

@X x_hexa_native_only := "../HEXA-NATIVE-ONLY.md" :: policy [active]
  url = "../HEXA-NATIVE-ONLY.md"
  scope = "no LLVM · no C-transpile · self-hosted — g5 + g_self_verify 의 authority"

@X x_lattice_policy := "../LATTICE_POLICY.md" :: policy [d=2026-05-12 active]
  url = "../LATTICE_POLICY.md"
  scope = "dancinlab-wide real-limits-first verification standard — g1 + g3 의 authority"

# ─── §6 Notes ────────────────────────────────────────────────────────

@N n_self_verify_phase := "self-verify phased rollout" :: note [active]
  text <<~EOF
    g_self_verify 는 strict 정책이지만 Phase 2 (hexa-native verifier 완성) 까지는
    fallback 적용 — anima 의 sympy/PyPhi 결과를 🟡 SUPPORTED-BY-CITATION tier 로
    carry 가능. Phase 2 완성 후 모든 carry entry 를 hexa-native 로 재검증하여
    🔵 SUPPORTED-IDENTITY / 🔵 SUPPORTED-FORMAL upgrade.

    Phase 1 (현재) 의 MAIN.tape 는 다수 🟠 INSUFFICIENT + 일부 🟡
    SUPPORTED-BY-CITATION (T-proofs anchor seed) 로 시작.
  EOF

@N n_default_insufficient_pragma := "default INSUFFICIENT pragmatic" :: note [active]
  text <<~EOF
    g_tier_default_insufficient 는 'verdict 안 부여된 entry 는 모두 🟠
    INSUFFICIENT' 라는 default. ~410 atlas entry 중 Phase 1 에서 explicit
    verdict 부여는 ~30-50 (T-proofs anchor seed). 나머지 ~360+ 는 자동 INSUFFICIENT.
    Phase 2/3 에서 hexa-native verifier 가동되면 batch upgrade.
  EOF

@N n_layer_split := "spec/engine layer split" :: note [active]
  text = "atlas verdict 는 spec layer (atlas/*.tape, 사람이 편집) 와 engine layer (compiler/atlas/verify/*.hexa, 컴파일러가 실행) 두 layer. spec 이 단일 SSOT, engine 은 codegen tool (tool/atlas_verify_gen.hexa Phase 2) 로 generated. 양쪽 동기화는 strict-lint stage 9 (Phase 3) 가 검사."

# ─── §7 Generator hooks ──────────────────────────────────────────────

@H h_atlas_md_replaced := "atlas governance via tape" :: generator [active]
  note = "atlas 영역의 governance 는 본 atlas/AGENTS.tape (tape v1.2, CLAUDE.md symlink) — anima g1~g8 carry + atlas-specific g_self_verify / g_tier_default_insufficient / g_external_calc_forbidden 추가."
  parent = "../AGENTS.tape (project-level)"

@H h_phase_2_engine_codegen := "Phase 2 engine codegen" :: generator [planned]
  rule = "Phase 2 시 tool/atlas_verify_gen.hexa 가 atlas/MAIN.tape + VERIFY.tape 를 읽어 compiler/atlas/verify/<domain>.hexa 생성. spec → engine 단방향 codegen."
  status = "deferred to Phase 2 (next session+)"
