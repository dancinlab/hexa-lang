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
  self/ -> "compiler runtime + bootstrap — runtime.c (C runtime), codegen_c2.hexa (SSOT codegen), main.hexa (CLI), module_loader.hexa"
  self/native/ -> "bootstrap + native-support C layer (WIP) — hexa_cc.c + hexa_v2 (bootstrap transpiler), {lexer,parser,type_checker}_v2.c (C frontend), tensor_kernels.c, OS shims (net/thread/pty/mount). ★ also holds GPU code: hxcuda_*.cu · hxmetal_* · gpu_codegen_stub.c (@gpu codegen skeleton, rt#45 — see @N native_dir). NOT forge SSOT."
  self/cuda/ -> "forge CUDA kernels — runtime_cuda.c (cuBLAS Dgemm + .cu kernels). see self/forge/."
  stdlib/flame/ -> "★ NN training stdlib (hexa source, compiler-only PyTorch-equiv) — README · PLAN · FLAME.tape. RFC 043. see §0 nn_stack."
  self/forge/ -> "★ GPU compute substrate SSOT label (cuBLAS + .cu kernels live in self/runtime.c + self/cuda/) — README · PLAN · FORGE.tape. RFC 040+041. see §0 nn_stack."
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

@D g_atlas_binary_builtin := "atlas is unconditionally binary built-in" :: governance [required d=2026-05-19 active]
  rule = "The hexa-lang atlas is unconditionally binary built-in — compile-time embedded. The SSOT is compiler/atlas/embedded.gen.hexa, merged into the compiler at build time. There is no runtime-loaded live overlay."
  why = ".n6 files (atlas.n6 · atlas.overlay.n6 · atlas.append.*.n6) are now ONLY a `hexa atlas export` OUTPUT artifact — produced on demand for interop / inspection / external tooling. The old runtime path (~/.hx/data/atlas.overlay.n6 · discovery → atlas overlay → 3+ hits → promote into rodata regen) is RETIRED. Equations do NOT go through .n6 to reach the live atlas."
  apply = "New equations discovered via `hexa kick` / `hexa verify` are absorbed via GitHub PR directly into the binary built-in atlas — the PR regenerates + commits the embedded atlas source (compiler/atlas/embedded.gen.hexa). Direct fold-to-live is forbidden; every equation lands via reviewable PR."
  authority = "user directive 2026-05-19 'atlas 는 무조건 바이너리 빌트인 · .n6 는 export 출력물 전용 · 신규 식은 GitHub PR 로 빌트인 흡수'; reinforces SPEC.md §2.2 'atlas embedding — static, baked into compiler'."
  cross-ref = "@D g6 citation-enforced-strict-lint (every formula-bearing line @cites the embedded atlas) · upstream principle 'every equation via PR; direct fold-to-live forbidden'"
  @> AGENTS.md

@D g_commit_push_deploy := "commit-push carries the deployed binary — no source/binary drift" :: governance [required d=2026-05-19 active]
  rule = "Any commit/push that changes compiler source (self/{lexer,parser,type_checker,codegen_c2}.hexa · self/main.hexa · tool/* the driver runs) MUST — in the same change-set or an immediately-paired deploy commit — regenerate + promote the bootstrap binary (self/native/hexa_cc.c + self/native/hexa_v2) and rebuild the driver. Source and the deployed binary never land out of sync."
  why = "Commit 70c7ab9d landed the enum-variant fix SOURCE-ONLY; self/native/hexa_cc.c + hexa_v2 were not regenerated, so `hexa run`/`build` kept executing the stale transpiler and the demiurge consumer stayed blocked (RegionShape/TrafficKind undeclared) until a separate deploy commit (8ff19d2a) promoted the binary. 'fix the source, defer the binary' silently ships a no-op to every consumer."
  apply = "Before push: `hexa cc --regen` → rebuild hexa_v2 from the regenerated hexa_cc.c → rebuild the driver → confirm the self-host fixpoint is BYTE-IDENTICAL (a regen of the promoted hexa_cc.c reproduces itself). The commit includes the regenerated self/native/hexa_cc.c + hexa_v2. A compiler-source change whose binary is not promoted is INCOMPLETE — not landed."
  authority = "user directive 2026-05-19 '매 commit push 시에 deployed 필수 진행'; incident: 70c7ab9d source-only enum-fix → demiurge stale-binary block → 8ff19d2a remedial promote."
  cross-ref = "@D g_plan_consolidation (compile-cycle PLAN SSOT) · @D g8 commit-trailer-co-author · self-host fixpoint byte-identical gate"
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

@D g_interp_deprecated := "interpreter RETIRED — R7 CLOSED (Cycle C step-1+2 complete)" :: governance [required d=2026-05-19 active]
  rule = "인터프리터는 RETIRED. (1) 소스 삭제 완료 — `self/hexa_full.hexa` · `self/interpreter.hexa` · `test_interp*.hexa` · `tool/{rebuild,build}_interp*.hexa` (16 파일 · 25,548 줄). (2) `self/main.hexa::cmd_run` 은 compile-then-exec 으로 재배선 완료 — 더 이상 interp 바이너리에 위임 안 함. 모든 `.hexa` 실행 경로 (`hexa run` · `hexa batch` · 23 absorbed-verb dispatch) 가 compiled. 신규 코드 · 도구 · 테스트 harness 가 interp 에 의존하는 것 금지. 검증은 `hexa build`, syntactic 은 `hexa parse`."
  why = "interp 는 (1) compiled 대비 corpus 커버리지 미달, (2) macOS 4GB memcap 초과로 대형 입력에 죽음, (3) latent 버그 보유. R7 measured-cutover 캠페인이 interp↔compiled byte-eq parity gate 를 PASS (13→0 gate-relevant · 75 MATCH · 0 DIVERGE/RC_DIFF/COMPILED_REGRESS) — compiled 가 interp 를 회귀 0 으로 대체함을 삭제 前 측정으로 입증."
  cycle_c_status = "Cycle C COMPLETE. step-1 (origin/main ab7015fa) — interp 소스 16 파일 · 25,548 줄 삭제. step-2 (origin/main 25a9031d) — cmd_run 본체를 197→80 줄 compile-then-exec 으로 재작성 (cmd_run_last_rc · auto_marker_write · cmd_run_no_exit_mode contract 보존; 23 호출처 무변경). 검증: HEXA_FORCE_INTERP=1 run / plain run / build / parse 4/4 rc-eq, mini build_aprime fixpoint PASS, atlas 118/118."
  parity_proof = "tool/parity_interp_vs_compiled.sh — 삭제 前 100 test/*.hexa PARITY GATE PASS 2026-05-19 (13→0). 삭제 後 harness 의 'interp arm' 도 compiled (interp 은퇴) — corpus regression smoke 로 전환. compiler/PLAN.md SSOT."
  residual = "build/hexa_interp 바이너리 + resolve_interp() dead-code 는 무해 잔재 — 다음 tidy cycle 에서 물리 제거 (런타임 무참조). R7 의 실질 종결은 본 commit (cmd_run interp-free)."
  authority = "user directive 2026-05-17 '인터프리터 폐기예정' → 2026-05-18 'measured cutover' → 2026-05-19 '(a) Cycle C 실행' + '/goal step all closure'. measured proof: parity gate PASS + 4/4 cmd_run path rc-eq."
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

@D g_stdlib_ownership := "hexa-lang owns ALL stdlib — downstream repos point, never copy" :: governance [required deny:write d=2026-05-19 active]
  rule = "모든 stdlib/ 모듈은 hexa-lang 소유이며 hexa-lang 에만 존재한다 — hexa-lang 이 stdlib 의 단일 SSOT. 다운스트림 repo (demiurge, wilson, echoes, anima, phanes, 모든 hexa-*) 는 stdlib 모듈을 POINTER (cross-link · import 경로) 로만 참조한다. 복사·vendoring·fork 금지."
  why = "stdlib 모듈당 SSOT 1개 = drift 0. 다운스트림 복사본은 조용히 발산하지만 pointer 는 발산할 수 없다. 특히 demiurge 는 pointer — hexa-lang stdlib 를 참조할 뿐 vendoring 하지 않는다 (demiurge = pointer, hexa-lang = SSOT)."
  apply = "다운스트림이 stdlib 변경이 필요하면 inbox/patches/ 로 file (g7) — 자기 트리에 stdlib/<mod>.hexa 복사 금지. 흡수된 외부 라이브러리 (qrng · qmirror · sim-universe) 는 흡수에 의해 hexa-lang stdlib 가 된 것 — 이제 hexa-lang 소유이며 dual-home 아님."
  authority = "user directive 2026-05-19 'hexa-lang=SSOT, demiurge=pointer · 모든 stdlib 는 hexa-lang 소유'"
  cross-ref = "@I id002 upstream-position · @D g7 inbox-patches-pipeline · @F f3 consumer-direct-edit"
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

@N n_citations := "External citations -> CITATIONS.tape" :: note [d=2026-05-20 active]
  text = "Extracted to CITATIONS.tape on 2026-05-20 (wilson-minimal-keep) — reference material, not session-required guardrail. Full citations preserved verbatim in CITATIONS.tape."

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

@N native_dir := "self/native/ — bootstrap + native-support C layer (WIP)" :: note [d=2026-05-19 active]
  text <<~EOF
    self/native/ is the C-level bootstrap + native-support directory.
    Status: WORK-IN-PROGRESS — mixed, no own README/tape yet. Recognized
    here so sessions/agents do not rediscover it ad-hoc.

    Contents (git-tracked):
    - bootstrap transpiler: hexa_cc.c + hexa_v2 (the canonical .hexa→C
      path, @N n1) + many hexa_v2.bak.* / .pre* snapshots.
    - C frontend mirror: lexer_v2.c · parser_v2.c · type_checker_v2.c
      · codegen_c2_v2.c (the *.hexanoport siblings are no-port marks).
    - kernels + OS shims: tensor_kernels.c · net.c · thread.c · pty.c
      · mount.c · namespace.c · wait.c · crypto_*.c · proc_fork.c.
    - GPU code (NOT forge SSOT — forge = self/cuda/ per FORGE.tape):
      hxcuda_conv1d/fused/stft.cu · lora_cuda.cu · hxqwen14b_cuda.cu
      · hxmetal_kernels.metal + hxmetal_macos.m · hxblas/hxccl/hxflash/
      hxlayer/hxlmhead/hxvdsp_linux.c accelerator shims.
    - ★ gpu_codegen_stub.c — a `@gpu` codegen backend SKELETON
      ("rt#45-research scaffold", placeholder-only, locks the C ABI
      for a future GPU codegen backend). This PRE-DATES RFC 055
      (hexa-src→NVPTX); RFC 055 should reconcile with / supersede this
      stub rather than ignore it. Companion `docs/rt-45-gpu-design.md`
      is referenced by the stub header but currently MISSING.

    Boundary: self/native/ ≠ self/forge/ (forge = self/cuda/ +
    runtime.c GPU dispatch, RFC 040/041). self/native/ GPU files are
    a separate, older, partly-stale layer; treat as WIP, do not assume
    they are wired into the flame/forge path.
  EOF

# ─── §7 Generator hooks ──────────────────────────────────────────────

@H h1 := "agents-md-replaced" :: generator [active]
  note = "AGENTS.md (54-line wrapper) replaced by this AGENTS.tape — LATTICE_POLICY rules are now @D g1..g4, hexa-native-only is g5, citation-enforced is g6, inbox-patches is g7."
  fallback = "tape_to_agents_md (planned) can regenerate AGENTS.md from this file for tools that don't speak .tape natively"

@H h2 := "claude-md-symlink" :: generator [active]
  rule = "CLAUDE.md → AGENTS.tape symlink — Claude Code auto-discovery picks up tape grammar primer first"
  command = `ln -sf AGENTS.tape CLAUDE.md`
  status = "updated 2026-05-14"
