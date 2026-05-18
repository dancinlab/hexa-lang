#!/usr/bin/env tape
# AGENTS.tape for `dancinlab/hexa-lang` — sole agent-harness + governance.
# AGENTS.md (54-line LATTICE_POLICY wrapper) replaced; the real authorities
# (LATTICE_POLICY · LIMIT_BREAKTHROUGH · SPEC · HEXA-NATIVE-ONLY) remain
# as standalone .md files cross-linked from §6 below.

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §1 Identity ─────────────────────────────────────────────────────

@I id001 := "hexa-lang" :: identity-claim [d=2026-05-14 active]
  kind = "native compiler with atlas-bound theorems"
  brief = "native compiler with atlas-bound theorems · 8 strict-lint stages · no LLVM · no C-transpile"
  parent = "dancinlab"
  axes = "8 strict-lint stages · citation-enforced · no LLVM · no C-transpile"
  signature = "💎 perfect-number programming language · n=6 primitives"
  consumers = "wilson (downstream — runtime/agent) · echoes (downstream — discoveries) · all hexa-* repos"

@I id002 := "hexa-lang.upstream-position" :: identity-claim [d=2026-05-14 active]
  <: id001
  rule = "hexa-lang is the bottom of the dancinlab dependency stack — downstream projects (wilson, echoes, anima, hexa-*) consume; nothing imports from them"
  apply = "when wilson hits a hexa-lang gap, the patch goes to ~/core/hexa-lang/inbox/patches/<descriptive-name>.md (one concept per file), then to upstream — never inline-patched from the consumer"

# ─── §2 Repo layout ──────────────────────────────────────────────────

@L l1 := "hexa-lang-layout" :: structure [active]
  README.md -> "18-block format · multilingual switcher"
  AGENTS.tape -> "this file · sole agent-harness + governance (tape v1.2)"
  CLAUDE.md -> "symlink → AGENTS.tape"
  SPEC.md -> "hexa-lang formal specification (grammar · type system · strict-lint stages · @cite enforcement)"
  ROADMAP.md -> "phased plan SSOT"
  PLAN.md -> "active development plan"
  FLOW.md -> "build / compile / verify pipeline diagram"
  HEXA-NATIVE-ONLY.md -> "policy — no LLVM · no C-transpile · self-hosted"
  LATTICE_POLICY.md -> "project-local copy of dancinlab-wide real-limits standard"
  LIMIT_BREAKTHROUGH.md -> "project-specific limits + breakthrough audit"
  TAPE-AUDIT.md -> "tape v1.x adoption ledger for this repo"
  inbox/patches/ -> "external-contributed patch markdowns (one concept per file)"
  stdlib/qrng/ -> "★ Quantum RNG — 9 backends T0..T3 + NIST SP 800-22 audit. RFC 044 absorption of ~/core/qrng (헌법 v2 룰 4 reference impl). see §0 qrng_stack."
  stdlib/sim_universe/ -> "★ Sim-Universe — virtual-universe runtime (26 modules · ~32k LoC · τ-clock + multiverse + qpu_bridge + 16 experiments). RFC 046 absorption of ~/core/sim-universe. see §0 sim_universe_stack."
  stdlib/quantum/ -> "★ Quantum Mirror — ≤30-qubit laptop-grade substrate (38 module dirs · 62k LoC · Aer-compat state-vector kernel + 27 algorithms + chemistry_vqe). RFC 045 absorption of ~/core/qmirror. see §0 qmirror_stack."

# ─── §0 PROJECT-WIDE QRNG STACK (2026-05-16) ─────────────────────────
# stdlib/qrng/ 는 헌법 v2 룰 4 (외부 자원 try-CLI-or-fallback) 의 모범 사례.
# RFC 044 가 dancinlab/qrng v1.0.0 (4,383 LoC) 을 흡수했고, 묘비는
# dancinlab/qrng GitHub private repo 에 freeze (헌법 v2 룰 3).

@N qrng_stack := "stdlib/qrng — 9-backend QRNG provider + NIST audit" :: note [d=2026-05-16 active]
  provider = "stdlib/qrng/backends/{mock_qrng, anu, curby, nist_beacon, hardware_qrng} (5 IMPLEMENTED T0/T1/T3) + cloud/{ibm_quantum, ionq, rigetti, braket} (4 T2 STUB_CREDENTIALED)"
  algorithm = "stdlib/qrng/audit.hexa — NIST SP 800-22 tier-1+ (5 tests · monobit · freq-block · runs · longest-run · DFT spectral · α=0.01)"
  routing = "stdlib/qrng/registry.hexa + router.hexa — env-driven fallback chain (QRNG_SOURCE · QRNG_FALLBACK_CHAIN · QRNG_LIVE · QRNG_HW_LIVE)"
  entry = "qrng_audited_bytes(n, level, vendor) — entropy + audit 단일 호출; struct AuditedQrngBytes"
  legacy_api = "qrng_anu_uint8 / _live / _chunked / _parse_response / _live_enabled — stdlib/qrng_anu.hexa 흡수 (anima 호환)"
  cli = "hexa qrng <subcmd> — dispatcher = stdlib/qrng/qrng.hexa (status · collect · selftest · chain · meta · --help · --version). self/main.hexa 에 'else if sub == \"qrng\"' 분기 + cmd_help STDLIB CLI 섹션. 별도 tool/hexa_qrng/ 없음 — stdlib 단일 SSOT. 원본 580-LoC subprocess CLI 는 archive_qrng/cli/ 묘비."
  archive = "github.com/dancinlab/qrng (private) — frozen 묘비 (헌법 v2 룰 3). 로컬 archive 폐기 2026-05-17 · see @X x_archive_qrng"
  governance = "see @D g_qrng_audit_required, g_qrng_honest_vendor, g_qrng_provider_only · @F f_qrng_silent_mock_downgrade"
  doi = "10.5281/zenodo.20102966 (dancinlab/qrng v1.0.0)"
  rfc = "RFC 044 (landed 2026-05-16) · RFC 045 qmirror + RFC 046 sim-universe 후속"
  @> README.md

# ─── §0 PROJECT-WIDE SIM-UNIVERSE STACK (2026-05-16) ──────────────────
# stdlib/sim_universe/ — toy lattice-model substrate at cosmological scale.
# 헌법 v2 룰 2 (algorithm absorption) + 룰 3 (frozen archive).

@N sim_universe_stack := "stdlib/sim_universe — 26-module virtual-universe runtime" :: note [d=2026-05-16 active]
  substrate = "stdlib/sim_universe/{anu_time (τ-clock + Lorentz + mini_world, 5.9k LoC), multiverse (interferometer + KS + MI, 4.2k LoC), qpu_bridge (VQE-H2 + ANU noise, 441 LoC), sim_agent (registry+router, 492 LoC), ouroboros_qrng (consumes stdlib/qrng/, 862 LoC), godel_q (AST mutator + verify-gate, 758 LoC), bostrom_test (235 LoC), sr_harness (800 LoC), atlas_anu_corr (1.0k LoC), anu_stream (903 LoC)} — 10 modules, ~15.6k LoC (RFC 046-A LANDED)"
  experiments = "stdlib/sim_universe/experiments/{fvd (Chao 2026, 1.3k LoC), stark-fragmentation (Wang 2024, 1.2k LoC), quantum-darwinism (Zhu 2025), ca-qm (Elze/van Berkel), supremacy-frontier (Morvan 2024), mbs-revival (Xiang 2024), fock-prethermal-dtc (Bao 2025), z2-gauge-prethermal (Hayata-Hidaka 2024), preheating-analog (Gondret 2025), multipolar-prethermal (Liu 2025), surface-code (Acharya 2024), ssh-topology (SSH 1979), hofstadter (Hofstadter 1976), dqpt-loschmidt (Heyl 2013), wdw-minisuperspace (Basilakos 2025)} — 15 modules, ~14.4k LoC (RFC 046-B LANDED)"
  cli = "hexa sim-universe <subcmd> — dispatcher = stdlib/sim_universe/sim_universe.hexa (status · selftest · anu · multiverse · qpu · qrng · bostrom · godel · sr · 15 experiment subcmds · --help · --version). self/main.hexa 에 'else if sub == \"sim-universe\"' 분기."
  honest_scope = "Toy lattice-model substrate · Bostrom-flavored framing. NOT lattice QCD · NOT Einstein-equation · NOT N-body cosmology · NOT SM physics. Each experiment ships per-module 'honest scope' caveat (NOT decoherent · NOT lab device · NOT L→∞ limit)."
  qrng_dependency = "stdlib/sim_universe/ouroboros_qrng/ consumes stdlib/qrng/ (RFC 044 absorbed) — 4-tier ANU fallback (paid → keyed → legacy → urandom)."
  archive = "github.com/dancinlab/sim-universe (private) — frozen 묘비 (헌법 v2 룰 3). 로컬 archive 폐기 2026-05-17 · see @X x_archive_sim_universe"
  governance = "see @D g_sim_universe_honest_scope, g_sim_universe_qrng_consumer · @F f_sim_universe_lattice_qcd_claim"
  doi = "10.5281/zenodo.20102970 (dancinlab/sim-universe v1.1.0)"
  rfc = "RFC 046 Phase A + 046-A + 046-B LANDED 2026-05-16"
  status = "FULL absorption — substrate + 15 experiments + CLI dispatcher + README + governance + archive ✅"
  @> README.md

# ─── §0 PROJECT-WIDE QUANTUM-MIRROR STACK (2026-05-16) ────────────────
# stdlib/quantum/ — ≤30-qubit laptop-grade QPU-equivalent substrate.
# 헌법 v2 룰 2 (algorithm absorption) + 룰 3 (frozen archive).

@N qmirror_stack := "stdlib/quantum — 38-module quantum mirror substrate" :: note [d=2026-05-16 active]
  core = "stdlib/quantum/{engine_aer (Aer-compat state-vector kernel + QASM3 lex/parse/oracle + gates, 2.2k LoC), circuit, sampler, stabilizer, entropy, qrng (consumer-side HMAC-DRBG amplifier), selftest, chsh (CHSH Bell test), iit_mip + phi (IIT 4.0 phi-star), tomography, process_tomography, cscs}"
  algorithms = "27 @D-governed modules each vs a published reference — rqaoa (arXiv:2408.13207) · ctx (2505.21243) · dynghz (2308.13065) · vqd (2502.17932) · stab-ext (2406.16673) · overlap-vqe (2301.10196) · sre (2106.12587) · lg (2411.02301) · pseudo-tel (Mermin 1990) · rpe (1502.02677) · sym-shadow (2310.03071) · hardy (Hardy 1993) · page-curve (Page 1993) · qdrift (Campbell 2019) · cdr (Czarnik 2021) · wigner (Veitch 2014) · qfi (2411.10117) · shallow (2209.12924) · gme-steer (2402.18522) · mabk (Mermin 1990 + Werner-Wolf 2001) · mirror-bench (Proctor 2022)"
  applications = "stdlib/quantum/{chemistry_vqe (29.6k LoC · 59 files · per-molecule CMT hamiltonians 4e4o/4e5o/4e6o + kuPCCGSD + L-BFGS-B), bench (per-molecule 4e4o benchmarks), surface_code_d3}"
  cli = "hexa qmirror <subcmd> — dispatcher = stdlib/quantum/quantum.hexa (status · selftest · chsh · iit · qrng · 27 algorithm subcmds · --help · --version). self/main.hexa 에 'else if sub == \"qmirror\"' 분기. 모듈 = standalone program; subprocess dispatch."
  structure_note = "chemistry_vqe + bench use relative imports (./ and ../../<feature>/module/). The <feature>/module/ directory structure is preserved verbatim under stdlib/quantum/ so all relative imports resolve unchanged — NO flatten, NO rewrite."
  envelope = "Statistical-equivalence substrate for the ≤30-qubit low-noise envelope only. Casio-vs-Rolex analogy. NOT a universal QPU replacement."
  qrng_boundary = "stdlib/quantum/qrng/ is the CONSUMER-side HMAC-DRBG amplifier; stdlib/qrng/ (RFC 044) is the PROVIDER registry. Zero code overlap, struct-shape compat by convention."
  archive = "github.com/dancinlab/qmirror (private) — frozen 묘비 (헌법 v2 룰 3). 로컬 archive 폐기 2026-05-17 · see @X x_archive_qmirror"
  governance = "see @D g_qmirror_envelope, g_qmirror_consumer_qrng · @F f_qmirror_real_qpu_claim"
  doi = "10.5281/zenodo.20102964 (dancinlab/qmirror v2.6.0)"
  rfc = "RFC 045 LANDED 2026-05-16 — 114 .hexa, all parse-clean. dancinlab quantum-stack absorption series (044 qrng + 045 qmirror + 046 sim-universe) COMPLETE."
  @> README.md

# ─── §3 Governance rules ─────────────────────────────────────────────

@D g1 := "real-limits-first" :: governance [required]
  rule = "The project's ceiling is set by REAL math/physics/engineering/compiler limits, NEVER by the n=6 invariant lattice."
  why = "dancinlab-wide real-limits-first verification policy"
  authority = "[@x_lattice_policy]"
  @> AGENTS.md

@D g2 := "lattice-is-tool-not-constraint" :: governance [required]
  rule = "n=6 lattice is a TOOL (used in native lattice spec files), not a CONSTRAINT on what the compiler can express."
  apply = "lattice fits internal architecture (e.g. perfect-number primitives); banned on external systems"
  <: g1
  @> AGENTS.md

@D g3 := "verification-anchor-real-limit" :: governance [required]
  rule = "Verification anchors must include at least one REAL limit from LATTICE_POLICY.md §1.2."
  real-limits = [Shannon, Kolmogorov, Bekenstein, c, ℏ, k, "Stefan-Boltzmann", Carnot, "compiler invariant (e.g. type-soundness theorem · termination · register-allocator NP-completeness)"]
  insufficient = "lattice-tautology checks alone (e.g. σ·φ = 24)"
  <: g1
  @> AGENTS.md

@D g4 := "honesty-obligation-external" :: governance [required deny:write]
  rule = "Claims about external compilers / language ecosystems (Rust · Swift · Zig · OCaml · GHC · LLVM · MSVC · gcc · clang) must NOT include lattice-fit assertions."
  remedy = "Use that ecosystem's OWN invariants (Rust's borrow-checker · GHC's type-class lookup · LLVM's SSA · etc.)"
  @> AGENTS.md

@D g5 := "hexa-native-only" :: governance [required deny:write]
  rule = "hexa-lang is self-hosted. No LLVM, no C-transpile, no third-party codegen backend."
  apply = "compiler emits its own machine code (or its own C as a portable artifact, but the C path is fallback, not the architecture)"
  authority = "[@x_hexa_native_only]"
  @> AGENTS.md

@D g6 := "citation-enforced-strict-lint" :: governance [required]
  rule = "Every formula-bearing code line must @cite an atlas theorem, or strict-lint stage 4 rejects the build."
  stages = "8 strict-lint stages — atlas integrity check, citation match, formula well-formedness, etc."
  authority = "[@x_spec]"
  @> AGENTS.md

@D g7 := "inbox-patches-pipeline" :: governance [required]
  rule = "External patches arrive at inbox/patches/<descriptive-name>.md — one concept per file."
  flow = "[downstream consumer] → file at inbox/patches/ → upstream review → integration to self/ + RFC log"
  forbidden = "downstream consumers (wilson, echoes) editing hexa-lang directly without going through inbox/patches/"
  @> AGENTS.md

@D g8 := "commit-trailer-co-author" :: governance [recommended]
  rule = "AI-assisted commits include trailer: Co-Authored-By: <model> <noreply@anthropic.com>"
  @> AGENTS.md

@D g_arch_vs_log_split := "v1.2 architecture-vs-history split" :: governance [required d=2026-05-14 active]
  rule = "UPPERCASE.tape files are EDITABLE architecture (latest-wins per id). Append-only event history lives in UPPERCASE.log.tape siblings."
  why = "hexa-lang is the substrate · spec changes evolve continuously; locking them as append-only created noisy histories. v1.2 splits architecture (.tape) from history (.log.tape)."
  applies-to = "AGENTS.tape · all UPPERCASE.tape root files (notably the existing TAPE-AUDIT.md ledger which may have a .tape sibling)"
  authority = "[@x_tape_spec] §Domain-tape sibling §Architecture-vs-history split"
  @> AGENTS.md

@D g_hxc := "hxc-wire-storage-format" :: governance [recommended d=2026-05-15 active]
  rule = "Machine-readable surfaces (JSON / JSONL / config-blob streams) emit / consume via HXC v2 byte-canonical wire format."
  scope = "atlas rodata sidecar · audit ledger streams · dispatch envelopes · witness rows · cycle-JSON artifacts · any structured stream previously encoded as JSON / JSONL"
  out-of-scope = "human-edit SSOT (markdown · RFC · prose) and governance rules (this file's @D entries) stay in markdown / tape v1.2. HXC absorbs the machine side, NOT the human-author side."
  why = "JSON/JSONL surfaces deliver measured 27-96% byte savings on schema-rich streams via HXC's A1-A35 deterministic codec chain. Atlas Layer 4 sidecar (compiler/atlas/hxc_loader.hexa + dist/atlas.hxc) is the canonical in-repo example."
  authority = "[@x_hxc_spec]"
  @> AGENTS.md

@D g_qrng_audit_required := "qrng audit on T1/T3 paths" :: governance [required d=2026-05-16 active]
  rule = "Any code path in stdlib/qrng/ returning live quantum entropy (tier >= T1) MUST be exercisable through qrng_audited_bytes() with NIST SP 800-22 tier-1+ audit."
  apply = "Skipping audit on T1/T3 backends is a release blocker."
  authority = "NIST SP 800-22 Rev. 1a · https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-22r1a.pdf"
  source = "qrng AGENTS.tape g1 (migrated 2026-05-16 RFC 044)"
  @> AGENTS.md

@D g_qrng_honest_vendor := "qrng vendor classification honesty" :: governance [required d=2026-05-16 active]
  rule = "QrngSourceMeta.is_quantum follows vendor self-classification; honest-caveat ships in module docstring + meta.message."
  examples = "nist_beacon.is_quantum=0 (mixed entropy HSM + RNGs); hardware_qrng.is_quantum=1 (IDQ/ESP32 vendor assertion, independent NIST validation NOT performed)."
  source = "qrng AGENTS.tape g2 (migrated 2026-05-16 RFC 044)"
  @> AGENTS.md

@D g_qrng_provider_only := "qrng = provider-side only" :: governance [required deny:write d=2026-05-16 active]
  rule = "stdlib/qrng/ returns raw bytes + provenance only. No HMAC-DRBG / NIST SP 800-90A construction belongs here."
  why = "Amplification is consumer concern (qmirror amplifier · hexa-bio). Provider/consumer boundary deliberate; zero code overlap, struct-shape compat by convention."
  source = "qrng AGENTS.tape g3 (migrated 2026-05-16 RFC 044)"
  @> AGENTS.md

@D g_sim_universe_honest_scope := "sim-universe honest scope" :: governance [required d=2026-05-16 active]
  rule = "Each stdlib/sim_universe/experiments/<name>/ module MUST declare its 'honest scope' in module docstring + README — what it IS (exact ED, closed-form, etc.) and what it is NOT (decoherent, lab device, L→∞ limit, lattice QCD, full SM)."
  examples = "fvd: EXACT 2ᴺ unitary N≤24, NOT lab; supremacy: calibrates XEB ruler at n≲24, NOT a sim-vs-reality claim; surface-code: Gottesman-Knill polynomial tableau, NOT 2ᴺ state vector."
  source = "sim-universe AGENTS.tape g1/g7 (migrated 2026-05-16 RFC 046)"
  @> AGENTS.md

@D g_sim_universe_qrng_consumer := "sim-universe → stdlib/qrng dependency" :: governance [required d=2026-05-16 active]
  rule = "stdlib/sim_universe/ouroboros_qrng/ consumes stdlib/qrng/ (RFC 044) — no own provider implementation. 4-tier ANU fallback (paid → keyed → legacy → urandom) is qrng's responsibility."
  why = "Provider/consumer boundary preserved across the absorption series. ouroboros_qrng is an entropy-consumer (perturbation pipeline), not a provider."
  source = "RFC 044 + RFC 046 cross-link 2026-05-16"
  @> AGENTS.md

@D g_qmirror_envelope := "qmirror ≤30-qubit envelope" :: governance [required d=2026-05-16 active]
  rule = "stdlib/quantum/ is a statistical-equivalence substrate for the ≤30-qubit low-noise envelope ONLY — NOT a universal QPU replacement."
  apply = "Honest analogy: Casio vs Rolex — both tell time, qmirror is the Casio. Claims of QPU-equivalence MUST be scoped to ≤30-qubit low-noise."
  source = "qmirror AGENTS.tape (migrated 2026-05-16 RFC 045)"
  @> AGENTS.md

@D g_qmirror_consumer_qrng := "qmirror.qrng = consumer-side amplifier" :: governance [required d=2026-05-16 active]
  rule = "stdlib/quantum/qrng/ is the CONSUMER-side HMAC-DRBG amplifier; stdlib/qrng/ (RFC 044) is the PROVIDER registry. Zero code overlap; struct-shape compat by convention."
  why = "Dual-home boundary preserved across the absorption series — qmirror amplifies, qrng provides."
  source = "RFC 044 + RFC 045 cross-link 2026-05-16"
  @> AGENTS.md

@D g_plan_consolidation := "single-source compile PLAN tracking — compiler/PLAN.md" :: governance [required d=2026-05-17 active]
  rule = "Compile 관련 (compiler/ · self/ · 부트스트랩 · test sweep · interp-retirement · aprime_cc · hexa-build 등) cycle 진행 로그 는 `compiler/PLAN.md` 의 `## 진행 로그` 섹션에 append. 신규 `PLAN-*.md` 파일 작성 금지 — 기존 `PLAN-interp-retirement.md` · `PLAN-stage3-*.md` 는 closure 까지 유지, 신규 entry 만 `compiler/PLAN.md` 로 redirect."
  why = "문서분산 방지. cycle 단위 일목요연 파악 = `compiler/PLAN.md` 한 파일. parser/codegen/lower/runtime 부분 수정 + 부트스트랩 재빌드 + smoke sweep 측정 + interp-retirement cleanup 모두 동일한 진행 로그 stream."
  applies-to = "전체 compile pipeline deliverable. `compiler/`, `self/`, test/ smoke 측정, 부트스트랩 (`self/native/hexa_v2`), 3-tier wrapper (`bin/hexa-run-native`), aprime_cc-direct path."
  exception = "별도 도메인 SSOT 자체는 자체 위치 유지: `stdlib/flame/PLAN.md` (NN training stdlib) · `self/forge/PLAN.md` (GPU compute substrate) · `tape/PLAN.md` 등. RFC drafts (`inbox/rfc_drafts_*`) 는 자체 파일."
  authority = "user directive 2026-05-17 'PLAN 은 compile 관련 폴더/PLAN.md 파일을 업데이트해나가면되' + 'AGENTS.tape 에도 기록해놔줘 문서분산 방지'. 사전 forge/PLAN.md 위치 시도 (commit d6ef09ab) 는 본 cycle 이 forge 아닌 compile 작업임을 정정한 04fd46b2 에서 revert."
  @> AGENTS.md

@D g_interp_deprecated := "interpreter deprecated — option B: user-facing warning, sources preserved" :: governance [required d=2026-05-17 active]
  rule = "인터프리터 경로 (`hexa run` · `self/hexa_full.hexa` · `build/hexa_interp.real`) 는 DEPRECATED. 신규 코드 · 도구 · 테스트 harness · 빌드 스크립트 · 다운스트림 통합이 인터프리터에 의존하는 것 금지. 검증은 `hexa build` (compiled) · syntactic 체크는 `hexa parse`. 신규 기능은 compiled 경로 (hexa_v2 → C, 또는 aprime_cc-direct) 에만 land."
  why = "interp 는 (1) compiled 경로 대비 corpus 커버리지 미달이지만 SSOT 는 compiled, (2) macOS 4GB memcap 초과로 대형 입력에 죽음, (3) chr-byte / atlas parser-drift / enum-eq / bitwise / match-as-expr 등 입증된 latent 버그 보유. 신규 의존을 막아야 R7 폐기 시 회귀 0."
  applies-to = "신규 .hexa 도구 · 테스트 harness · 빌드 스크립트 · 다운스트림 (wilson / echoes / anima) 통합. 기존 interp 의존은 R7 track-B closure 까지 유지하되 신규는 금지."
  exception = "(1) interp 자체 유지보수 — bug 픽스 시 [@x_handoff] dual-track per g_inbox_dual_track 적용. (2) self/main.hexa 의 16+ absorbed-verb 분기 (lsp / test / check / qrng / sim-universe / qmirror / batch / …) 가 interp 바이너리에 위임 중 — R7 track B (sub-binary 재라우팅, multi-cycle) 까지 보존. (3) 부득이 interp 필요 시 ubu 원격 (macOS memcap 회피)."
  r7_status = "R7 gate ①②③④ 모두 충족 (gate ① — tier-1 codegen gap 0; gate ②③④ — CLI compiled · atlas SIGSEGV 종결 · module_loader interp-free). R7 Phase 1 entanglement map 작성 완료 (compiler/PLAN.md). R7 Phase 2 = option B 채택: 인터프리터 소스 보존 + user-direct `hexa run <file>` 와 hexa://run URL 에 stderr deprecation warning emit (silenceable via `HEXA_INTERP_QUIET=1`). 16+ absorbed-verb 는 functionality 보존 (loss = 0) — track B 로 분리."
  user_warning = "`hexa run <file>` 와 `hexa://run` URL action 호출 시 stderr 에 1회 deprecation warning. silence = `HEXA_INTERP_QUIET=1` env. self/main.hexa::cmd_run_user_direct 에 wired."
  sunset = "R7 track B (16+ absorbed-verb 의 sub-binary 재라우팅, multi-cycle) 완료 → 인터프리터 소스 일괄 삭제 → 본 룰 폐기."
  authority = "user directive 2026-05-17 '인터프리터 폐기예정 표시 / 신규 의존 금지 => go' + 2026-05-18 'R7 option B' 선택; feedback memory no-interp-use-compiled."
  @> AGENTS.md

@D g_inbox_processing_loop := "inbox 처리 SOP — filing → worktree sub-agent → cherry-pick" :: governance [recommended d=2026-05-19 active]
  rule = "다운스트림이 file 한 inbox/{patches,notes}/<slug>.md 는 7단계 loop 로 처리한다 — (1) git status 로 untracked filing 식별, (2) explicit-path commit 으로 main 에 filing land, (3) general-purpose sub-agent 를 isolation=worktree + run_in_background=true 로 dispatch, (4) agent 는 SSOT 수정 + local parse-gate + 패치 markdown status reported→resolved-ssot + compiler/PLAN.md 단일 entry + worktree branch commit, (5) 완료 알림 받으면 main 으로 cherry-pick -x, (6) 표준 충돌패턴 해결, (7) binary promote 는 별도 standard deploy step (commit 22c27a05 / e5c4c0ef 패턴) — 본 cycle 에 포함 금지."
  why = "이 SOP 가 2026-05-19 session 에서 7건 inbox (print_err parity + phanes×3 + wisp/anima 패치 + flame RFC 059 + kick-engine + stdlib/net) 을 race-condition 0 으로 land 시킨 측정-증명 절차. ad-hoc 동시-편집은 e5c4c0ef-style deploy regen 으로 SSOT 가 wipe 될 수 있음 (`3abf9f8e` print_err 가 한 번 lost → `1a133068` 재적용 회복). worktree 격리 + cherry-pick 패턴은 그 회귀를 방지한다."
  steps <<~EOF
    1. CHECK   : `git status --short` · `git ls-files --others --exclude-standard inbox/` — 새 untracked 식별.
    2. FILE    : `git add <explicit-path>` + commit (`docs(inbox): file <slug> ...`). 다른 세션 WIP 절대 미포함; 메시지는 source/severity/요약 + Co-Authored-By trailer.
    3. DISPATCH: Agent tool — `subagent_type=general-purpose` · `isolation=worktree` · `run_in_background=true`. 프롬프트에 (a) 패치 markdown 전체 읽기, (b) @D g5/g6/g7/g_plan_consolidation/g_interp_deprecated 컨텍스트, (c) Shape-A(surgical) vs Shape-B(RFC+scaffold) 자율 결정 권한, (d) 절대경로는 worktree 내부만, (e) /Users/ghost/.hx/bin/hexa_real parse 후 edit-gate, (f) binary promote 금지, (g) inbox/PATCHES.yaml 미터치 명시.
    4. AGENT   : SSOT 수정 → parse-gate → markdown status flip → compiler/PLAN.md (또는 도메인-예외 PLAN.md) 단일 entry → commit on worktree branch · 보고 (branch + hash + files + 1-paragraph g3-honest summary + 결정 punted).
    5. PICK    : `git -C /Users/ghost/core/hexa-lang cherry-pick -x <hash>` (절대경로 권장 — cwd 가 sub-worktree 로 shift 될 수 있음).
    6. RESOLVE : 표준 conflict 두 가지 — (i) `AA inbox/{patches,notes}/<slug>.md` add/add → `git checkout --theirs <path>` (agent 의 resolved-ssot 버전 우선), (ii) `UU compiler/PLAN.md` 또는 `stdlib/<domain>/PLAN.md` drift → `git checkout --ours` + `git show <hash> -- <plan> | grep ^+ | sed s/^+//` 로 agent 의 실제 추가 텍스트만 추출해서 끝에 append. drill.hexa 등 같은 .hexa 파일 다중 변경은 git auto-merge 가 region 다르면 통과.
    7. PROMOTE : 별도 deploy step. 본 loop 미포함. SSOT 갭 closed, 바이너리는 standard cycle 에서 자연 promote.
  EOF
  conflict_pattern = "AA inbox markdown → --theirs · UU PLAN.md → --ours + append actual-diff · same-file region-disjoint .hexa → auto-merge"
  hazard_guards = "(a) commit 전 `git -C <main> branch --show-current` 필수 (shared-worktree-branch-hazard 메모리). (b) cherry-pick 중 cwd jump 감지 시 `git -C /Users/ghost/core/hexa-lang ...` 절대경로 fallback (wilson-pool 또는 외부 hook 이 cwd 변경 가능). (c) `self/codegen_c2.hexa` 가 deploy commit (22c27a05·e5c4c0ef 류) 에서 regen 되면 SSOT 편집 wipe 되므로 재적용 commit 준비. (d) 다른 세션 WIP 파일 (예: tool/parity_*.sh · self/native/hexa_v2) 은 status 에 보이더라도 절대 미터치."
  scope_split = "Shape A (minimum surgical) — SSOT 1~3 file edit, byte-eq preserved, single commit. Shape B (RFC + scaffold) — multi-cycle 작업은 inbox/rfc_drafts_*/rfc_<next>_*.md draft + RFC-comment-marker 만 (zero behavior change) + 3+ cycle phasing + falsifier battery. g3 over-claim 0 — Shape B 는 'implementation 완료' 아니라 'RFC drafted + scaffold landed' 로 정직 보고."
  task_tracking = "각 inbox item 당 TaskCreate · in_progress → completed. 동시 dispatch 가능 (병렬 fan-out)."
  applies-to = "inbox/patches/ · inbox/notes/ 양쪽. patches = bug/feature 요청, notes = 에스컬레이션/observation. 동일 SOP."
  authority = "user directive 2026-05-19 'inbox 처리해달라고 하면 이런식으로 처리하면되 AGENTS.tape 기록' + session 2026-05-19 측정 패턴 (7 inbox: print_err·HX_DATA_DIR·verifier-hook·HXC v2 lib·RFC 059·kick --dump-overlay·stdlib/net surgical — 모두 본 loop 으로 land 성공). cross-link: @D g7 inbox-patches-pipeline (filing 의무), @D g_plan_consolidation (PLAN.md 단일 SSOT), @D g_interp_deprecated (compiled-path-only 검증), @D g8 commit-trailer-co-author."
  cross-ref = "[@x_handoff] downstream→upstream 흐름 spec · feedback memory `shared worktree branch hazard`"
  @> AGENTS.md

# ─── §4 Forbidden patterns ───────────────────────────────────────────

@F f1 := "lattice-fit-on-external-language" :: governance [required deny:write]
  pattern = "applying n=6 lattice as derivation rule to Rust / Swift / Zig / OCaml / GHC / LLVM / MSVC / gcc / clang internals"
  exception = "values may coincidentally match — observation OK, derivation NOT OK"

@F f2 := "llvm-c-transpile-backend" :: governance [required deny:write]
  pattern = "adding LLVM IR backend, C-transpile architecture, or third-party codegen as a default path"
  why = "hexa-native-only policy · [@x_hexa_native_only]"
  exception = "fallback C emission (already exists for portability) — but not part of the architecture spec"

@F f3 := "consumer-direct-edit" :: governance [required deny:write]
  pattern = "wilson / echoes / anima / hexa-* consumer repo editing hexa-lang directly without going through inbox/patches/"
  why = "upstream-downstream invariant; one-way flow per [@x_handoff]"

@F f_qrng_silent_mock_downgrade := "qrng silent mock downgrade" :: governance [required deny:write d=2026-05-16 active]
  pattern = "Router falls back to mock_qrng (T0) without preserving tier/vendor/message in audit_level_delivered or RouterResult.attempts/reasons."
  remedy = "router MUST set audit_level_delivered to 'tier1-none' or 'none' and record attempts list; caller SHOULD check tier != 'T0' before security use."
  source = "qrng AGENTS.tape f_weak_entropy (migrated 2026-05-16 RFC 044)"

@F f_sim_universe_lattice_qcd_claim := "sim-universe overreach claim" :: governance [required deny:write d=2026-05-16 active]
  pattern = "Claiming stdlib/sim_universe/ is lattice QCD · Einstein-equation N-body cosmology · Standard-Model physics · or a measurement of 'whether reality is simulable'."
  remedy = "Frame as 'toy lattice-model substrate with QRNG-anchored entropy · Bostrom-flavored simulation framing'. Per-module honest-scope box explicit (e.g. 'NOT decoherent · NOT lab device · NOT L→∞')."
  source = "sim-universe README §Caveats raw10 C3 (migrated 2026-05-16 RFC 046)"

@F f_qmirror_real_qpu_claim := "qmirror real-QPU overreach" :: governance [required deny:write d=2026-05-16 active]
  pattern = "Claiming stdlib/quantum/ IS a real QPU, or equivalent beyond the ≤30-qubit low-noise envelope."
  remedy = "Scope all equivalence claims to the ≤30-qubit low-noise envelope. State statistical-equivalence, not physical identity. Casio-vs-Rolex framing."
  source = "qmirror AGENTS.tape (migrated 2026-05-16 RFC 045)"

# ─── §5 External citations ───────────────────────────────────────────

@X x_spec := "SPEC.md" :: spec [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/SPEC.md"
  scope = "hexa-lang formal specification · 8 strict-lint stages · @cite enforcement · type system"

@X x_hexa_native_only := "HEXA-NATIVE-ONLY.md" :: policy [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/HEXA-NATIVE-ONLY.md"
  scope = "no LLVM · no C-transpile · self-hosted policy"

@X x_lattice_policy := "LATTICE_POLICY.md" :: policy [d=2026-05-12 active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/LATTICE_POLICY.md"
  scope = "dancinlab-wide real-limits-first verification standard · also at echoes/LATTICE_POLICY.md (cross-project SSOT)"

@X x_limit_breakthrough := "LIMIT_BREAKTHROUGH.md" :: audit [d=2026-05-12 active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/LIMIT_BREAKTHROUGH.md"
  scope = "hexa-lang-specific real-limits + per-limit breakthrough assessment (Wave M)"
  classifications = [HARD_WALL, SOFT_WALL, BREAKABLE_WITH_TECH, UNCLEAR]

@X x_handoff := "wilson AGENTS.tape g7 hexa-lang-handoff-protocol" :: principle [d=2026-05-14 active]
  url = "https://github.com/dancinlab/wilson/blob/main/AGENTS.tape"
  scope = "downstream-to-upstream patch flow — wilson, echoes, anima file at inbox/patches/"

  scope = "honest-caveat origin · forbidden lattice-fit on external entities"

@X x_tape_spec := "tape v1.2 spec" :: spec [d=2026-05-14 active]
  url = "https://github.com/dancinlab/tape/blob/main/spec/tape.md"
  scope = "this file's grammar reference"

@X x_tape_audit := "TAPE-AUDIT.md" :: ledger [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/TAPE-AUDIT.md"
  scope = "tape v1.x adoption ledger for this repo"

@X x_hxc_spec := "HXC v2 spec" :: spec [d=2026-05-15 active]
  url = "https://github.com/dancinlab/hxc/blob/main/spec/hxc.md"
  scope = "byte-canonical wire / storage format for AI-native pipelines · KV-cache prefix stable · 31 deterministic algorithms (A1-A35) · ASCII-stable line-oriented · absorbs JSON/JSONL surfaces"
  in-repo-example = "compiler/atlas/hxc_loader.hexa + tool/atlas_build_hxc.hexa + dist/atlas.hxc (Atlas Layer 4 sidecar)"

@X x_archive_qrng := "qrng 묘비 archive" :: archive [d=2026-05-17 active]
  url = "https://github.com/dancinlab/qrng"
  scope = "Frozen historical SSOT of dancinlab/qrng v1.0.0 — AGENTS.tape · CHANGELOG · README · CITATION.cff · LICENSE · RELEASE_NOTES · TAPE-AUDIT · hexa.toml · install.hexa · docs/ · examples/ · cli/ · 14 module dirs · tests/. 재해석 없음 (헌법 v2 룰 3)."
  github = "dancinlab/qrng (private 2026-05-16)"
  preservation = "GitHub private repo 가 SSOT. 로컬 ~/core/archive_qrng/ 는 2026-05-17 폐기 (working-tree state 는 stdlib/qrng/ 에 흡수 보존; 원본 history 는 GitHub private)."
  doi = "10.5281/zenodo.20102966"
  successor = "stdlib/qrng/ (RFC 044)"

@X x_archive_sim_universe := "sim-universe 묘비 archive" :: archive [d=2026-05-17 active]
  url = "https://github.com/dancinlab/sim-universe"
  scope = "Frozen historical SSOT of dancinlab/sim-universe v1.1.0 — AGENTS.tape · CHANGELOG · README · CITATION · LICENSE · DESIGN_IDEAS · FALSE_VACUUM · STARK_FRAGMENTATION · hexa.toml · install.hexa · cli/ · docs/ · MODULE/ · examples/ · tests/ · tool/ · 26 module dirs verbatim. 재해석 없음 (헌법 v2 룰 3)."
  github = "dancinlab/sim-universe (private 2026-05-16)"
  preservation = "GitHub private repo 가 SSOT. 로컬 ~/core/archive_sim-universe/ 는 2026-05-17 폐기 (working-tree state 는 stdlib/sim_universe/ 에 흡수 보존; 원본 history 는 GitHub private)."
  doi = "10.5281/zenodo.20102970"
  successor = "stdlib/sim_universe/ (RFC 046 LANDED 2026-05-16)"

@X x_archive_qmirror := "qmirror 묘비 archive" :: archive [d=2026-05-17 active]
  url = "https://github.com/dancinlab/qmirror"
  scope = "Frozen historical SSOT of dancinlab/qmirror v2.6.0 — AGENTS.tape · CHANGELOG · README · CITATION · LICENSE · LICENSING · BENCH.tape · IDENTITY.tape · PLAN.md · AER_HEXA_ABSORPTION_PLAN · CHEMISTRY_VQE_PYSCF_BACKEND_PLAN · hexa.toml · install.hexa · cli/ · docs/ · MODULE/ · examples/ · tests/ · tools/ · 38 module dirs verbatim. 재해석 없음 (헌법 v2 룰 3)."
  github = "dancinlab/qmirror (private 2026-05-16)"
  preservation = "GitHub private repo 가 SSOT. 로컬 ~/core/archive_qmirror/ 는 2026-05-17 폐기 (working-tree state 는 stdlib/quantum/ 에 흡수 보존; 원본 history 는 GitHub private)."
  doi = "10.5281/zenodo.20102964"
  successor = "stdlib/quantum/ (RFC 045 LANDED 2026-05-16)"

# ─── §6 Notes ────────────────────────────────────────────────────────

@N n1 := "self-hosted-toolchain" :: note [active]
  text <<~EOF
    The transpiler hexa_v2 (in self/) is currently the canonical path:
    .hexa source → hexa_v2 → C → clang → ELF / Mach-O.
    The C emission is a portable artifact — the ARCHITECTURE remains
    self-hosted (HEXA-NATIVE-ONLY policy). Future: direct native codegen
    (no C step) is on the roadmap (PLAN.md).
  EOF

@N n2 := "atlas-binding-citation" :: note [active]
  text = "Every theorem-bearing line must @cite the atlas. Strict-lint stage 4 rejects formula code without a citation marker."

@N n3 := "inbox-patches-from-consumers" :: note [active]
  text = "wilson, echoes, anima, getting-started, hexa-* family — all file upstream patch requests at inbox/patches/<descriptive>.md, one concept per file. Emoji '넣었다' marks delivery."

@N n_log_separation := "hexa-lang specific" :: note [active]
  text = "hexa-lang's stdlib/RFC/codegen progress lands as commits — each commit hook should append @A entries to per-domain .log.tape (e.g. CODEGEN.log.tape, STDLIB.log.tape) rather than mutating the architecture .tape files."

# ─── §7 Generator hooks ──────────────────────────────────────────────

@H h1 := "agents-md-replaced" :: generator [active]
  note = "AGENTS.md (54-line wrapper) replaced by this AGENTS.tape — LATTICE_POLICY rules are now @D g1..g4, hexa-native-only is g5, citation-enforced is g6, inbox-patches is g7."
  fallback = "tape_to_agents_md (planned) can regenerate AGENTS.md from this file for tools that don't speak .tape natively"

@H h2 := "claude-md-symlink" :: generator [active]
  rule = "CLAUDE.md → AGENTS.tape symlink — Claude Code auto-discovery picks up tape grammar primer first"
  command = `ln -sf AGENTS.tape CLAUDE.md`
  status = "updated 2026-05-14"
