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
  compiler/lenses/ -> "★ binary built-in lens SSOT (RFC 065) — types.hexa + embedded.gen.hexa (36 lens / 9 family x 4 — adds `unfold` for archive-nexus heritage). 36/36 real bodies measured 2026-05-20. PR-only via @D g_atlas_binary_builtin symmetry."
  compiler/atlas/by_kind/ -> "★ RFC 066 B-1a per-kind atlas split — {p,l,e,f,r,s,x,q}.gen.hexa (8 kinds; C deferred to B-1b HXC sidecar dist/atlas.hxc). stdlib consumers import only the kinds they need, bypassing the 4 GB hexa_v2 memcap of the full embedded.gen.hexa."
  stdlib/loop/ -> "★ `hexa loop` self-growing atlas cycle runtime (RFC 065) — cycle.hexa (8-stage SCAN/LENS/DEDUP/GATE/FIRE/DRAFT/AUDIT/EXHAUST? with inline atlas_enrich) + state.hexa (8-file state I/O at \$HEXA_LANG/state/loop/<cwd_hash>/). Live: 36 lens dispatch -> 91 candidate/cycle -> inbox/atlas_candidates/<slug>.md, PR-only invariant preserved."
  tool/atlas_split_by_kind.hexa -> "RFC 066 B-1a generator — emits compiler/atlas/by_kind/<k>.gen.hexa from compiler/atlas/embedded.gen.hexa. hexa-native (hexa-first guard). C kind skipped (HXC sidecar path)."

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
  do   = "ceiling = real math/physics/engineering/compiler limit (Shannon · c · ℏ · type-soundness · register-allocator NP)"
  dont = "n=6 lattice 를 ceiling 으로 · lattice-fit assertion"
  @> AGENTS.md

@D g2 := "lattice = tool not constraint" :: governance [required]
  do   = "lattice 는 internal architecture (perfect-number primitive 등) 에서 사용"
  dont = "external system 에 lattice fit 강제"
  <: g1
  @> AGENTS.md

@D g3 := "verification anchor = real limit" :: governance [required]
  do   = "verification anchor 에 LATTICE_POLICY.md §1.2 real-limit 1개 이상 (Shannon/Kolmogorov/Bekenstein/c/ℏ/k/Stefan-Boltzmann/Carnot · compiler invariant)"
  dont = "lattice-tautology check (σ·φ=24 류) 단독으로 verification 주장"
  <: g1
  @> AGENTS.md

@D g4 := "honesty obligation — external" :: governance [required deny:write]
  do   = "external compiler/language ecosystem 주장 시 그 ecosystem own invariant 사용 (Rust borrow-checker · GHC type-class lookup · LLVM SSA)"
  dont = "Rust/Swift/Zig/OCaml/GHC/LLVM/MSVC/gcc/clang 에 lattice-fit assertion"
  @> AGENTS.md

@D g5 := "hexa-native-only" :: governance [required deny:write]
  do   = "self-hosted compiler · own machine code 또는 own C (fallback artifact)"
  dont = "LLVM IR backend · C-transpile architecture · 3rd-party codegen 을 default path 로"
  @> AGENTS.md

@D g6 := "citation-enforced strict-lint" :: governance [required]
  do   = "formula-bearing code 라인마다 @cite atlas theorem · 8-stage strict-lint 통과 (atlas integrity · citation match · formula well-formedness 등)"
  dont = "@cite 누락 commit (strict-lint stage 4 에서 reject)"
  @> AGENTS.md

@D g_atlas_binary_builtin := "atlas binary built-in" :: governance [required d=2026-05-19 active]
  do   = "atlas SSOT = compiler/atlas/embedded.gen.hexa (compile-time embedded) · 신규 식 = GitHub PR 로 흡수 (regen + commit embedded source) · .n6 = `hexa atlas export` 출력물만"
  dont = "runtime-loaded live overlay · ~/.hx/data/atlas.overlay.n6 promote path · direct fold-to-live (PR 우회)"
  @> AGENTS.md

@D g_commit_push_deploy := "commit-push = source + binary 동시" :: governance [required d=2026-05-19 active]
  do   = "compiler source (self/{lexer,parser,type_checker,codegen_c2}.hexa · main.hexa · driver tool) 변경 시 same change-set 에 `hexa cc --regen` + hexa_v2 rebuild + driver rebuild + fixpoint byte-identical 확인 (regen 한 hexa_cc.c 가 자기 재현)"
  dont = "source-only commit (binary 미promote = downstream consumer stale 차단, 70c7ab9d→8ff19d2a 사고 패턴)"
  @> AGENTS.md

@D g7 := "inbox-patches pipeline" :: governance [required]
  do   = "downstream patches → inbox/patches/<descriptive>.md (one concept = one file) · upstream review → integration self/ + RFC log"
  dont = "downstream consumer (wilson/echoes/anima/demiurge) 가 hexa-lang 직접 편집 (inbox/patches 우회)"
  @> AGENTS.md

@D g8 := "commit-trailer co-author" :: governance [recommended]
  do   = "AI-assisted commit 에 `Co-Authored-By: <model> <noreply@anthropic.com>` trailer"
  dont = "AI commit trailer 누락"
  @> AGENTS.md

@D g_arch_vs_log_split := "v1.2 arch-vs-history split" :: governance [required d=2026-05-14 active]
  do   = "UPPERCASE.tape = editable architecture (latest-wins per id) · 새 event history = UPPERCASE.log.tape sibling"
  dont = "단일 .tape 에 declarative state + event history 혼재 (noisy append-only)"
  @> AGENTS.md

@D g_hxc := "hxc wire/storage format" :: governance [recommended d=2026-05-15 active]
  do   = "machine-readable surface (JSON/JSONL/config-blob stream) = HXC v2 byte-canonical wire (atlas rodata sidecar · audit ledger · dispatch envelope · witness row · cycle-JSON)"
  dont = "human-edit SSOT (markdown/RFC/prose/governance @D) 를 HXC 로 (그건 tape/markdown 유지)"
  @> AGENTS.md

@D g_qrng_audit_required := "qrng audit on T1/T3" :: governance [required d=2026-05-16 active]
  do   = "stdlib/qrng/ T1/T3 live quantum entropy = qrng_audited_bytes() NIST SP 800-22 tier-1+ audit 통과 후 release"
  dont = "T1/T3 backend audit skip (release blocker)"
  @> AGENTS.md

@D g_qrng_honest_vendor := "qrng vendor honesty" :: governance [required d=2026-05-16 active]
  do   = "QrngSourceMeta.is_quantum = vendor self-classification · honest-caveat 는 module docstring + meta.message (예: nist_beacon=0 mixed HSM, hardware_qrng=1 IDQ vendor assertion)"
  dont = "독립 NIST validation 없이 vendor 주장 super-claim · is_quantum 누락"
  @> AGENTS.md

@D g_qrng_provider_only := "qrng = provider only" :: governance [required deny:write d=2026-05-16 active]
  do   = "stdlib/qrng/ = raw bytes + provenance only · amplification = consumer (qmirror amplifier / hexa-bio)"
  dont = "stdlib/qrng/ 안에 HMAC-DRBG / NIST SP 800-90A construction"
  @> AGENTS.md

@D g_sim_universe_honest_scope := "sim-universe honest scope" :: governance [required d=2026-05-16 active]
  do   = "stdlib/sim_universe/experiments/<name>/ 마다 'honest scope' = module docstring + README 명시 (IS = exact ED/closed-form/Gottesman-Knill 등 · IS NOT = decoherent/lab/L→∞/lattice QCD/full SM)"
  dont = "lattice QCD · Einstein N-body · full SM · 'reality simulable' 주장 (Bostrom toy-substrate framing 만)"
  @> AGENTS.md

@D g_sim_universe_qrng_consumer := "sim-universe consumes qrng" :: governance [required d=2026-05-16 active]
  do   = "stdlib/sim_universe/ouroboros_qrng/ = stdlib/qrng/ (RFC 044) 소비 (4-tier ANU fallback = qrng 책임)"
  dont = "own provider implementation · qrng 우회 entropy source"
  @> AGENTS.md

@D g_qmirror_envelope := "qmirror ≤30-qubit envelope" :: governance [required d=2026-05-16 active]
  do   = "stdlib/quantum/ = statistical-equivalence substrate (≤30-qubit low-noise envelope 만) · Casio-vs-Rolex framing"
  dont = "universal QPU replacement 주장 · ≤30-qubit 환경 밖 equivalence claim"
  @> AGENTS.md

@D g_qmirror_consumer_qrng := "qmirror amplifies, qrng provides" :: governance [required d=2026-05-16 active]
  do   = "stdlib/quantum/qrng/ = consumer-side HMAC-DRBG amplifier · stdlib/qrng/ = provider registry (zero code overlap, struct-shape compat by convention)"
  dont = "amplifier/provider 경계 흐림 · code overlap"
  @> AGENTS.md

@D g_plan_consolidation := "compile PLAN = compiler/PLAN.md" :: governance [required d=2026-05-17 active]
  do   = "compile cycle 진행 로그 = `compiler/PLAN.md` `## 진행 로그` append · 도메인 예외 = stdlib/flame/PLAN.md · self/forge/PLAN.md · tape/PLAN.md · RFC drafts (inbox/rfc_drafts_*)"
  dont = "신규 `PLAN-*.md` 작성 (compile 관련) · 분산 doc 으로 cycle 일목요연 깨기"
  @> AGENTS.md

@D g_interp_deprecated := "interpreter RETIRED" :: governance [required d=2026-05-19 active]
  do   = "모든 `.hexa` 실행 = compiled (`hexa run`/`build`/`batch`/23 absorbed-verb dispatch all compile-then-exec) · 검증 = `hexa build` · syntactic = `hexa parse`"
  dont = "신규 code/tool/test 가 interp 에 의존 · self/hexa_full.hexa / interpreter.hexa 재도입"
  @> AGENTS.md

@D g_inbox_processing_loop := "inbox 처리 SOP" :: governance [recommended d=2026-05-19 active]
  do   = "7-step loop: (1) git status untracked, (2) explicit-path file commit, (3) general-purpose sub-agent isolation=worktree run_in_background, (4) agent SSOT edit + parse-gate + status flip + PLAN.md single entry, (5) cherry-pick -x, (6) AA inbox→theirs / UU PLAN→ours+append, (7) binary promote 는 별도 deploy step"
  dont = "ad-hoc 동시 편집 (3abf9f8e print_err lost case) · 본 loop 에 binary promote 포함 · 다른 세션 WIP file (parity_*.sh / hexa_v2) touch"
  @> AGENTS.md

@D g_stdlib_ownership := "stdlib ⊂ hexa-lang only" :: governance [required deny:write d=2026-05-19 active]
  do   = "모든 stdlib/ 모듈 = hexa-lang 단독 SSOT · 다운스트림 = pointer/cross-link/import 만 · 변경 필요 시 inbox/patches/ (g7)"
  dont = "다운스트림 (demiurge/wilson/echoes/anima/phanes/hexa-*) 가 stdlib 복사·vendoring·fork · 흡수된 외부 lib (qrng/qmirror/sim-universe) 를 dual-home 취급"
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
