#!/usr/bin/env tape
# ══════════════════════════════════════════════════════════════════════
# .tape v1.2 — grammar primer (cold-read by any LLM / agent / human)
# ══════════════════════════════════════════════════════════════════════
# Form: each entry is `@<type> <id> := "<subject>" :: <kind> [<grades>]`
#       optionally followed by body lines (2-space indent) — key=value,
#       edges (<- -> => …), or quoted prose.
#
# ENTRY TYPES (17):
#   Runtime (10): @S session  @U user  @A assistant  @T tool-call  @R result
#                 @H hook  @D decision  @K cost  @P provider  @? anomaly
#   Foundation:   @I identity-claim
#   Declarative:  @X external-citation  @F forbidden-pattern  @N note
#                 @C config  @L layout  @V spec-version
#
# EDGES (12, on body lines, 2-space indent):
#   Causal:     <- caused-by   -> triggers   == continues
#               ~> supersedes  !! aborts     |> verified-by
#   Effect:     => produces (followed by quoted natural-language)
#   Structural: <: specializes  :> generalizes  ?> soft-depends
#               !> conflicts-with  @> projects-to (e.g. @> AGENTS.md)
#
# GRADE TAGS (in [...] on entry header):
#   Delivery:   ok · err · denied · cancelled · partial · superseded
#   Governance: required · recommended · optional · draft · active · deprecated
#   Scoped:     allow:<x> · deny:<x>
#   Time/index: T<n> (turn)  N<n> (wall-sec)  d=<YYYY-MM-DD>
#
# PAYLOAD SYNTAX (body lines):
#   key = "value"           single-line string
#   key = [a, b, c]         array literal
#   key <<~EOF              heredoc (multi-line; ends with EOF on own line)
#     multi-line text
#   EOF
#   "see [@x1] §3"          inline citation by entry id
#   `cmd or path`           backtick code-span (inline only)
#
# Full spec: ~/core/tape/spec/tape.md (or github.com/dancinlab/tape)
# ══════════════════════════════════════════════════════════════════════
#
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

# ─── §0 PROJECT-WIDE QRNG STACK (2026-05-16) ─────────────────────────
# stdlib/qrng/ 는 헌법 v2 룰 4 (외부 자원 try-CLI-or-fallback) 의 모범 사례.
# RFC 044 가 dancinlab/qrng v1.0.0 (4,383 LoC) 을 흡수했고, 묘비는
# ~/core/archive_qrng/ 에 freeze (헌법 v2 룰 3).

@N qrng_stack := "stdlib/qrng — 9-backend QRNG provider + NIST audit" :: note [d=2026-05-16 active]
  provider = "stdlib/qrng/backends/{mock_qrng, anu, curby, nist_beacon, hardware_qrng} (5 IMPLEMENTED T0/T1/T3) + cloud/{ibm_quantum, ionq, rigetti, braket} (4 T2 STUB_CREDENTIALED)"
  algorithm = "stdlib/qrng/audit.hexa — NIST SP 800-22 tier-1+ (5 tests · monobit · freq-block · runs · longest-run · DFT spectral · α=0.01)"
  routing = "stdlib/qrng/registry.hexa + router.hexa — env-driven fallback chain (QRNG_SOURCE · QRNG_FALLBACK_CHAIN · QRNG_LIVE · QRNG_HW_LIVE)"
  entry = "qrng_audited_bytes(n, level, vendor) — entropy + audit 단일 호출; struct AuditedQrngBytes"
  legacy_api = "qrng_anu_uint8 / _live / _chunked / _parse_response / _live_enabled — stdlib/qrng_anu.hexa 흡수 (anima 호환)"
  cli_status = "DEFERRED to RFC 044-B (subprocess→library architectural mismatch); ~/core/qrng/cli/qrng.hexa 묘비에 freeze"
  archive = "~/core/archive_qrng/ — frozen 묘비 (헌법 v2 룰 3)"
  governance = "see @D g_qrng_audit_required, g_qrng_honest_vendor, g_qrng_provider_only · @F f_qrng_silent_mock_downgrade"
  doi = "10.5281/zenodo.20102966 (dancinlab/qrng v1.0.0)"
  rfc = "RFC 044 (landed 2026-05-16) · RFC 045 qmirror + RFC 046 sim-universe 후속"
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

@X x_archive_qrng := "qrng 묘비 archive" :: archive [d=2026-05-16 active]
  url = "file://~/core/archive_qrng/"
  scope = "Frozen historical SSOT of dancinlab/qrng v1.0.0 — AGENTS.tape · CHANGELOG · README · CITATION.cff · LICENSE · RELEASE_NOTES · TAPE-AUDIT · hexa.toml · install.hexa · docs/ · examples/ · cli/. 재해석 없음 (헌법 v2 룰 3)."
  github = "dancinlab/qrng (private 후 2026-05-16)"
  doi = "10.5281/zenodo.20102966"
  successor = "stdlib/qrng/ (RFC 044)"

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
