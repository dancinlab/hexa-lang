#!/usr/bin/env tape
# COMPONENT.tape — package / board / system design domain index
# tape v1.2 grammar: see repo-root AGENTS.tape header primer.
# Sibling layout of comb/COMB.tape, stdlib/flame/FLAME.tape,
# self/forge/FORGE.tape.

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §1 Identity ─────────────────────────────────────────────────────

@I component_id := "component" :: identity-claim [d=2026-05-19 draft]
  kind = "package / board / system design domain · 3D producer first"
  brief = "die-package-board CAE chain wrapped via D18 subprocess + USDZ output for demiurge cockpit"
  alias = "HEXA-COMPONENT / 출입절차 화덕"
  parent = "hexa-lang"
  placement = "루트 직속 component/ — comb · stdlib/flame · self/forge 와 형제 (stdlib 아님)"
  ssot = "component/{README.md, PLAN.md, COMPONENT.tape}"
  status = "SCAFFOLD-ONLY (2026-05-19) — no .hexa code yet, gates OPEN"

@I component_consumer := "demiurge cockpit ComponentView3D" :: identity-claim [d=2026-05-19 active]
  <: component_id
  rule = "component/ 의 .usdz 산출이 ~/core/demiurge/cockpit/Sources/CockpitApp/Views/ComponentView3D.swift placeholder 를 대체"
  apply = "demiurge = consumer (pointer-only · AGENTS.tape g_stdlib_ownership), component/ = SSOT"

# ─── §2 Pattern decision (D18 subprocess vs D15 clean-room) ──────────

@D component_absorption_pattern := "OSS CAE 흡수 방식" :: decision [d=2026-05-19 active]
  status = "RESOLVED — (b) D18 bounded-subprocess (NOT D15 full clean-room)"
  rationale_1 = "FreeCAD / gmsh / USDPython 합산 수십만 줄 — clean-room rederivation 비현실적 (booksim/yosys 가 가능했던 sub-10k 줄 범위 아님)"
  rationale_2 = "Yosys/ABC 가 이미 D18 선례 (AGENTS.tape g5 hybrid exception · rfc_006 §4 ABC=7a bounded-subprocess) — 본 도메인에 동일 패턴 적용"
  rationale_3 = "USDZ 자체가 Apple proprietary container · USDPython OSS / Blender USD export 가 표준 변환 경로 — clean-room 재구현 불가능"
  cross-ref = "AGENTS.tape D18 (n/a) · @D g5 hexa-native-only hybrid exception"
  user_recommendation = "user 2026-05-19 명시적 권장 — '(b) 권장 — FreeCAD/gmsh/USDPython 을 subprocess 로 부르고, hexa-lang/component/ 안에는 얇은 hexa-native wrapper + provenance/gate'"

# ─── §3 Gate ladder (g3 — 게이트 PASS 전 absorbed 주장 금지) ──────

@D component_gate := "USDZ producer 4-gate" :: decision [d=2026-05-19 active]
  status = "OPEN — 모두 미측정"
  g1_round_trip = "die-package spec → FreeCAD STEP → gmsh mesh → USDPython package → .usdz · Reality Composer / Quick Look 정상 렌더링"
  g2_bipv_ref = "demiurge/cockpit/references/bipv-module-exploded-isometric.jpg 와 형태적으로 호환되는 packaged-module USDZ"
  g3_cockpit = "demiurge ComponentView3D.swift 가 produced.usdz 로딩 · 회전·줌 인터랙티브"
  g4_provenance = "모든 subprocess 호출 stderr 에 cited URL + 버전 + exit code · fail-loud exit(91) (rfc_003 idiom)"
  claim_rule = "4-gate 동시 PASS 전: README/PLAN/PATCHES.yaml 어디에도 'USDZ producer absorbed' 류 표기 금지 (g3 over-claim 0)"

# ─── §4 Phase plan (PLAN.md = SSOT, 본 §는 cross-link) ────────────

@N component_phases := "C1..C6 계획" :: note [d=2026-05-19 active]
  c1 = "component/usdz.hexa — USDPython subprocess (.usd ↔ .usdz)"
  c2 = "component/freecad.hexa — FreeCAD subprocess (parametric → STEP)"
  c3 = "component/gmsh.hexa — gmsh subprocess (STEP → mesh)"
  c4 = "component/component.hexa + hexa component CLI 분기 (self/main.hexa)"
  c5 = "demiurge ComponentView3D.swift placeholder → produced.usdz"
  c6 = "BIPV reference 형상 (G2) + 전체 round-trip 측정 (G1)"
  ssot = "component/PLAN.md"

# ─── §5 cited sources (demiurge/domains/component.md §5 mirror) ────

@X x_freecad := "FreeCAD" :: tool [active]
  url = "https://www.freecad.org/"
  role = "parametric 3D modeler — die-package-enclosure 형상"

@X x_gmsh := "gmsh" :: tool [active]
  url = "https://gmsh.info/"
  role = "3D FE mesh generator + CAD pre/post"

@X x_usdpython := "USDPython" :: tool [active]
  url = "https://developer.apple.com/augmented-reality/tools/"
  role = "Apple OSS — .usd ↔ .usdz 변환 (USDZ producer 의 packager 단계)"

@X x_blender_usd := "Blender USD export" :: tool [active]
  url = "https://docs.blender.org/manual/en/latest/addons/import_export/scene_universal_scene_description.html"
  role = "OSS Blender 의 USD exporter — USDPython 대체 가능"

@X x_antmicro_chain := "Antmicro electro-thermal OSS chain" :: corroboration [active]
  url = "https://antmicro.com/blog/2025/03/open-source-thermal-simulation-analysis-and-visualization"
  scope = "FreeCAD → gmsh → CalculiX → ParaView PCB 열 시뮬 사례 — D18 subprocess chain 의 published precedent"

@X x_demiurge_component := "demiurge domain spec" :: spec [active]
  path = "~/core/demiurge/domains/component.md"
  scope = "public-surface 도구 표 (7-verb 1:1) · cited URLs SSOT · consumer 측 reference"

@X x_demiurge_cockpit_viewer := "demiurge cockpit 3D view placeholder" :: consumer [active]
  path = "~/core/demiurge/cockpit/Sources/CockpitApp/Views/ComponentView3D.swift"
  scope = "component/ 의 .usdz 가 대체할 placeholder viewer (G3 gate)"

@X x_demiurge_bipv_ref := "BIPV 모듈 디자인 reference" :: reference [active]
  path = "~/core/demiurge/cockpit/references/bipv-module-exploded-isometric.jpg"
  scope = "G2 gate 의 형상 reference"

# ─── §6 Notes ────────────────────────────────────────────────────────

@N component_scaffold_only := "현 단계 = SCAFFOLD only (g3 정직 보고)" :: note [d=2026-05-19 active]
  text <<~EOF
    Shape-B per AGENTS.tape g_inbox_processing_loop:
      "RFC drafted + scaffold landed, zero behavior change, 3+ cycle
       phasing, falsifier battery" — implementation 완료 아님.

    landed this cycle:
      - component/README.md (this scaffold spec)
      - component/COMPONENT.tape (this file)
      - component/PLAN.md (phase log SSOT)

    NOT landed yet (future cycles):
      - component/{usdz,freecad,gmsh,component}.hexa (the 4 subprocess
        shims + dispatcher)
      - hexa component CLI subcommand (self/main.hexa branch)
      - demiurge cockpit ComponentView3D.swift rewiring (G3 gate)
      - any actual produced .usdz file
  EOF

@N component_handoff_provenance := "F handoff 출처" :: note [d=2026-05-19 active]
  source = "user directive 2026-05-19 (this session): '두 cross-repo 핸드오프 ... F → ~/core/hexa-lang/component/ (USDZ producer) check 후 진행'"
  context = "user Q2 답변: (b) D18 bounded-subprocess 권장 · demiurge cockpit ComponentView3D.swift 대체 + BIPV reference 영감"
  filing = "본 scaffold 가 그 directive 의 'check 후 진행' 의 '진행' 부분 — '_check_' 는 component/ 부재 확인 (clean clean slate, no conflict) 완료"
