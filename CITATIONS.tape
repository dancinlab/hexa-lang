#!/usr/bin/env tape
# CITATIONS.tape for `dancinlab/hexa-lang` — external citations extracted
# from AGENTS.tape on 2026-05-20 (wilson-minimal-keep cleanup) to keep the
# per-session agent-context file lean. Reference material, not session-
# required guardrail.

@V := "tape" :: spec [active]
  version = "1.2"

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
