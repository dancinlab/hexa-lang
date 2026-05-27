# component/ — package / board / system design domain (USDZ producer first)

> **현 단계:** **SCAFFOLD landed** (2026-05-19, Shape-B per
> `AGENTS.tape` g_inbox_processing_loop) — README + PLAN +
> COMPONENT.tape only. No `.hexa` code yet. Implementation in
> phased cycles; **USDZ producer is the first deliverable** (a
> hexa-native wrapper around FreeCAD / gmsh / USDPython called as
> absorbed-substrate subprocesses per `AGENTS.tape` D18 idiom). The
> full 7-verb component domain (per `~/core/demiurge/domains/
> component.md`) is broader scope, deferred to phased cycles.
>
> **Boundary:** top-level `component/` (sibling of `comb/`,
> `stdlib/flame/`, `self/forge/`) — not under `stdlib/` because
> this is a domain campaign, not a leaf library.
>
> **g3 (over-claim 0):** scaffold landed ≠ producer implemented.
> §3 measurement gate is OPEN; no "USDZ produced" claim until a
> real .usdz file emitted from a real BIPV-style die-package
> definition validates against the gate.

---

## 컨셉

```
🍳 HEXA-COMPONENT — "출입절차로 감싼 화덕"

- 하는 일: chip→component seam 의 die-package-board 정의를
           외부 OSS CAE 도구로 풀고, 결과를 USDZ 로 묶어
           cockpit 의 3D 뷰어에 넘긴다
- 비유: 큰 화덕(FreeCAD)·체(gmsh)·접시(USDPython)를 통째 다시
        만들지 않고, 우리 주방의 출입절차로 감싸서 사용
```

```
   hexa-lang/component/                  외부 OSS substrates
   ┌─────────────────────┐              ┌──────────────┐
   │ wrapper.hexa        │──subprocess─▶│   FreeCAD    │
   │ (D18 thin shim)     │              │   (3D CAD)   │
   │                     │              ├──────────────┤
   │ provenance + gate   │──subprocess─▶│    gmsh      │
   │ (rfc_003 idiom)     │              │   (mesher)   │
   │                     │              ├──────────────┤
   │ USDZ packager       │──subprocess─▶│  USDPython   │
   │                     │              │  (.usd→.usdz)│
   └─────────────────────┘              └──────────────┘
            │
            ▼ produced.usdz
   demiurge/cockpit/Sources/CockpitApp/Views/ComponentView3D.swift
   (replaces placeholder geometry)
```

- **비교 vs Cadence Allegro X / Ansys Icepak:** 상용 turnkey
  signoff suite 는 SI/PI/thermal/mechanical 을 한 GUI 에서
  결합한다 — 본 도메인은 그 결합을 *hexa-native dispatch* 로
  자체-구성 (OpenMDAO + FreeCAD + gmsh + CalculiX + ParaView,
  Antmicro 류 chain — `demiurge/domains/component.md` §4 cite).
- **비교 vs comb/:** comb 은 fabric 토폴로지 R&D (T1/T2 sim →
  T3 design handoff to `hexa-arch[chip]`). component 는 *그 die
  를 들고 와 패키지·보드·시스템으로 묶어 USDZ 로 산출* — chain
  의 한 단계 후속, demiurge 의 3rd 7-verb pass 소비자.

---

## §1 출처 (cited public-surface, `demiurge/domains/component.md` §5)

USDZ producer 가 subprocess 로 호출하는 외부 OSS / 환경:

| 도구 | URL | 역할 |
|---|---|---|
| **FreeCAD** | <https://www.freecad.org/> | parametric 3D modeler — die-package-enclosure 형상 정의 |
| **gmsh** | <https://gmsh.info/> | 3D FE mesh generator — 메시·pre/post |
| **USDPython** | <https://developer.apple.com/augmented-reality/tools/> | Apple OSS — `.usd` ↔ `.usdz` 변환 |
| **(대안) Blender USD export** | <https://docs.blender.org/manual/en/latest/addons/import_export/scene_universal_scene_description.html> | Blender 의 OSS USD exporter — USDPython 대체 가능 |
| **OSS electro-thermal chain (참조)** | <https://antmicro.com/blog/2025/03/open-source-thermal-simulation-analysis-and-visualization> | FreeCAD → gmsh → CalculiX → ParaView 파이프라인 사례 |

D18 ("bounded-subprocess + provenance + fail-loud") 패턴 — Yosys/ABC
와 동일 흡수 idiom (`AGENTS.tape` g5 hybrid exception).

---

## §2 demiurge 측 소비자 (3D viewer 대체 대상)

`component/` 가 산출한 `.usdz` 가 다음을 대체:

- `~/core/demiurge/cockpit/Sources/CockpitApp/Views/ComponentView3D.swift`
  — 현재 placeholder geometry (직육면체/球 등 stub).
- `~/core/demiurge/cockpit/references/bipv-module-exploded-isometric.jpg`
  — 디자인 reference (BIPV 모듈 폭발도). 최초 산출의 형상 영감.

demiurge 는 consumer; `component/` 는 SSOT (downstream-from-hexa-lang
관점에서 `component/` 모듈을 *pointer* 로만 import, 복사 금지 —
`AGENTS.tape` g_stdlib_ownership).

---

## §3 측정 게이트 (g3 — 게이트 닫히기 전까지 "USDZ producer" 주장 금지)

`producer absorbed` 주장은 다음이 동시에 PASS 한 후에만 가능:

- **G1 round-trip:** 입력 die-package spec → FreeCAD STEP → gmsh
  mesh → USDPython packaging → 출력 `.usdz` 가 Reality Composer /
  Quick Look 에서 정상 렌더링 (수동 시각 확인 + 자동 헤더 검증).
- **G2 BIPV reference:** 위 reference jpg 와 형태적으로 호환되는
  packaged-module USDZ 가 produced (수동 비교 가능 수준).
- **G3 cockpit wiring:** demiurge `ComponentView3D.swift` 가 placeholder
  대신 produced.usdz 를 로드하고 사용자가 회전·줌 인터랙션 가능.
- **G4 provenance:** 모든 subprocess 호출이 stderr 에 cited URL +
  버전 + exit code 기록, fail-loud (`exit(91)` rfc_003 idiom).

게이트 4 개 모두 닫히기 전까지: 본 README + PLAN 에 GATE-OPEN
표기 유지, PATCHES.yaml / inbox / README "DELIVERED" 표기 금지.

---

## §4 본 SSOT 와 cross-link

- `component/COMPONENT.tape` — tape v1.2 governance (identity, axes,
  gates, decisions). 본 도메인의 architecture-vs-history split 의
  architecture 쪽 (`AGENTS.tape` g_arch_vs_log_split).
- `component/PLAN.md` — 진행 로그 SSOT (`AGENTS.tape`
  g_plan_consolidation 의 도메인-예외 — `compiler/PLAN.md` 가
  아니라 본 도메인의 자체 PLAN).
- `~/core/demiurge/domains/component.md` — public-surface 도구 표
  + cited URLs SSOT (consumer 측 reference).
- `AGENTS.tape` — 거버넌스 (g5 hexa-native-only + D18 bounded-subprocess
  exception, g7 inbox flow, g_stdlib_ownership pointer-only,
  g_plan_consolidation).

---

## §5 다음 사이클 (PLAN.md 가 SSOT — 본 §는 요약)

1. **C1** USDPython subprocess shim (`component/usdz.hexa`)
   `.usd → .usdz` round-trip · G4 provenance fail-loud · self-test.
2. **C2** FreeCAD subprocess shim — parametric die-package box
   생성 → STEP export.
3. **C3** gmsh subprocess shim — STEP → mesh.
4. **C4** dispatcher (`component/component.hexa`) + `hexa component`
   CLI subcommand · `self/main.hexa` 분기 추가.
5. **C5** demiurge cockpit wiring (G3) — `ComponentView3D.swift`
   produced.usdz 로딩.
6. **C6** BIPV reference 형상 (G2) + 전체 라운드트립 (G1) 측정.

게이트 4 개 모두 PASS 후에만 `archive/patches/PATCHES.yaml` 에
`component-usdz-producer` 엔트리 추가 + status `applied`.
