#!/usr/bin/env tape
# NEXUS.tape — hexa-lang shared substrate hub (SSOT)
# Canonical code home (@D d3) + atlas (verified atoms) — the ONE shared substrate
# of the dancinlab ecosystem. All projects draw from here (star topology).
# Governance: commons @D g67 (intra-project reuse) + g68 (shared substrate hub).
# Atlas-backed: atom-level discoveries live in compiler/atlas/embedded.gen.hexa
# (auto-folded on every `hexa verify` / `hexa atlas register`); this NEXUS.tape
# lists STABLE module-level provides, NOT per-atom enumeration.

@V := "tape" :: spec [active]
  version = "1.2"

@I nexus := "hexa-lang shared substrate hub" :: identity [active]
  kind     = "canonical code home (d3) + atlas (verified atoms) — the ONE shared substrate of dancinlab"
  scope    = "cross-project STAR hub (@D g68) — all repos draw from here · NOT a peer inter-project mesh"
  ssot     = "this file (NEXUS.tape) + compiler/atlas/embedded.gen.hexa (live atom registry)"
  governs  = "commons @D g67 (intra-project reuse) + g68 (shared substrate hub)"
  topology = "star: 8 consumer repos -> hexa-lang (demiurge, anima, airgenome, echoes, ghost, growth, forge, hexa-codex)"

# === 1. provides[] registry — stable stdlib module families ===

@X p_magnet := "stdlib/material/magnet" :: provides [active]
  primitive = "current_loop_offaxis (elliptic K/E on-axis B Green fn · NOVEL-TOOL M2.4)"
  consumers = "demiurge RTSC · demiurge ANTIMATTER (Ioffe-Pritchard trap)"
  evidence  = "demiurge NEXUS.tape e1·e2 · PR #900 -> #168"

@X p_supercon := "stdlib/material (supercon fns)" :: provides [active]
  primitive = "McMillan Tc · Allen-Dynes · WHH · BCS gap ratio"
  consumers = "demiurge RTSC (V2 closed-form + V3 numerical push)"
  evidence  = "demiurge RTSC.md V2/V3 ledger · PR #745"

@X p_rtsc_templates := "stdlib/rtsc/templates" :: provides [active]
  primitive = "Wheeler on-axis B verifier · getdp 4.0 solenoid_axisym.geo/.pro"
  consumers = "demiurge RTSC · demiurge ANTIMATTER (6) trap inheritance"
  evidence  = "demiurge RTSC commit 3b33c26 · ANTIMATTER #168"

@X p_antimatter := "stdlib/antimatter + tool/verify_cli" :: provides [active]
  primitive = "penning_omega_plus/minus/invariance · pair_threshold_factor/kinetic/total · ioffe_loop_bz/mirror_*/trap_depth_k · mu_b_over_kb · h1s2s_rydberg · transition_factor_1s2s · cyclotron_cool_bexponent/bratio/massspeedup · recomb_3body_exponent/tratio/density_power · rel_kinetic_from_p · rel_p_from_kinetic"
  consumers = "demiurge ANTIMATTER (16 verified atoms · 7/7 process stages)"
  evidence  = "demiurge ANTIMATTER.md V4 ledger · PRs #157·#158·#159·#162·#164·#166·#168"

@X p_cern := "stdlib/cern" :: provides [active]
  primitive = "plasma-wakefield cold-linear fns"
  consumers = "demiurge CERN (plasma-wakefield cell)"
  evidence  = "hexa-lang PR #1007 · demiurge CERN.md"

@X p_atlas := "compiler/atlas (verified-atom registry)" :: provides [active]
  primitive = "embedded.gen.hexa SSOT · `hexa atlas lookup/stats/register --from-verify`"
  consumers = "ALL projects (universal discovery substrate)"
  evidence  = "every `hexa verify` folds an atom · cross-project query surface"

# === 2. hub -> consumer star edges (from-hexa · verified by sibling NEXUS.tape evidence) ===

@X e1 := "stdlib/material/magnet -> demiurge" :: reuse-edge [active]
  provides  = "hexa-lang stdlib/material/magnet"
  primitive = "current_loop_offaxis"
  reused_by = "demiurge RTSC + ANTIMATTER (6) trap"
  evidence  = "demiurge NEXUS.tape e1·e2 -> PR #168"

@X e2 := "stdlib/rtsc/templates -> demiurge" :: reuse-edge [active]
  provides  = "hexa-lang stdlib/rtsc/templates"
  primitive = "Wheeler verifier + getdp solenoid templates"
  reused_by = "demiurge RTSC + ANTIMATTER (6) trap"
  evidence  = "RTSC commit 3b33c26 -> ANTIMATTER #168"

@X e3 := "stdlib/antimatter -> demiurge ANTIMATTER" :: reuse-edge [active]
  provides  = "hexa-lang antimatter family (16 fns) + tool/verify_cli"
  primitive = "penning_* · pair_threshold_* · ioffe_* · h1s2s · cyclotron_cool_* · recomb_3body_* · rel_*"
  reused_by = "demiurge ANTIMATTER (V4 ledger 7/7 process stages closed)"
  evidence  = "demiurge ANTIMATTER.md · 7 merged PRs (#157·#158·#159·#162·#164·#166·#168)"

@X e4 := "compiler/atlas -> ALL projects" :: reuse-edge [active]
  provides  = "compiler/atlas (live verified-atom registry)"
  primitive = "embedded.gen.hexa SSOT + atlas CLI"
  reused_by = "demiurge · anima · airgenome · echoes · ghost · growth · forge · hexa-codex"
  evidence  = "every NEXUS.tape's discovery-substrate pointer · 22+ atoms folded by ANTIMATTER alone"

# === 3. candidate edges (stdlib families with no project NEXUS.tape edge yet) ===

@X c1 := "stdlib/bio -> consumer" :: reuse-candidate [proposed draft]
  note = "bio-kernel fns exist · no project NEXUS.tape currently records a from-hexa edge"

@X c2 := "stdlib/chem -> consumer" :: reuse-candidate [proposed draft]
  note = "stdlib/chem family · no project NEXUS.tape edge yet"

@X c3 := "stdlib (other families) -> consumer" :: reuse-candidate [proposed draft]
  note = "alloc · aura · aws · booksim · bot · brain · cert · ... — provides exist, downstream edges pending"

# === 4. notes — atlas live · consumer star · usage protocol ===

@N n1 := "atlas live registry — auto-updating discovery surface" :: note [active]
  ssot      = "compiler/atlas/embedded.gen.hexa (auto-folded on every `hexa verify` / `hexa atlas register`)"
  query     = "hexa atlas stats · hexa atlas lookup <id> · hexa atlas lookup --prefix=<p>"
  policy    = "this NEXUS.tape lists STABLE module-level provides; per-atom discoveries are atlas-backed (not enumerated here · keeps NEXUS.tape stable as stdlib grows)"

@N n2 := "consumer star — 8 distinct projects draw from this hub" :: note [active]
  consumers = "demiurge · anima · airgenome · echoes(=canon) · ghost · growth · forge · hexa-codex"
  graph <<~STAR
                       +---------- hexa-lang stdlib + atlas ----------+
                       |    (canonical code home d3 · shared SSOT)    |
                       +----------------------+-----------------------+
                                              |
              +----------------+--------------+--------------+----------------+
              |                |              |              |                |
              v                v              v              v                v
          demiurge          anima         airgenome        ghost           growth
              ^                ^              ^              ^                ^
              |                |              |              |                |
          (from-hexa: each repo's NEXUS.tape records what it consumes from the hub)
                                              ^
                              +---------------+---------------+
                              |               |               |
                            echoes          forge        hexa-codex
  STAR

@N n3 := "usage protocol — atlas-first + hub-consume (g67 + g68)" :: note [active]
  step1 = "before building a primitive — `hexa atlas lookup --prefix=<topic>` (atlas auto-updates · live)"
  step2 = "grep hexa-lang/stdlib/<family> for an existing module providing the primitive"
  step3 = "consume it — record `from-hexa[]` in your repo's NEXUS.tape per g68 · do NOT fork (@D d3)"
  step4 = "on adding a NEW stdlib primitive — register the verified atom via `hexa atlas register --from-verify` (live fold · no manual sync)"
