# component/ PLAN — phase log SSOT

> 본 파일이 `component/` 도메인의 진행 로그 SSOT.
> `AGENTS.tape` g_plan_consolidation 의 도메인-예외: compile cycle 이
> 아닌 도메인 작업이므로 `compiler/PLAN.md` 대신 본 파일 사용
> (stdlib/flame/PLAN.md · self/forge/PLAN.md 와 동일 패턴).

---

## 현재 상태

**SCAFFOLD-ONLY** (2026-05-19) — 게이트 4 개 모두 OPEN.

| Phase | 산출 | 상태 |
|---|---|---|
| **C0 scaffold** | README · COMPONENT.tape · PLAN.md | ✅ landed 2026-05-19 |
| **C1 USDZ shim** | `component/usdz.hexa` (USDPython subprocess) | ⏳ pending |
| **C2 FreeCAD shim** | `component/freecad.hexa` | ⏳ pending |
| **C3 gmsh shim** | `component/gmsh.hexa` | ⏳ pending |
| **C4 dispatcher** | `component/component.hexa` + `hexa component` CLI 분기 | ⏳ pending |
| **C5 cockpit wiring** | demiurge `ComponentView3D.swift` placeholder 교체 (G3) | ⏳ pending — demiurge 측 작업 |
| **C6 measurement** | round-trip + BIPV 형상 + 4-gate PASS | ⏳ pending |

---

## 4-gate (g3 — PASS 전 "USDZ producer" 주장 금지)

`COMPONENT.tape::component_gate` 참조. 요약:

- **G1** round-trip — die-package → FreeCAD STEP → gmsh mesh →
  USDPython → `.usdz` (Reality Composer / Quick Look 정상 렌더링)
- **G2** BIPV reference 호환 — `bipv-module-exploded-isometric.jpg`
  와 형태적으로 매칭되는 packaged-module USDZ
- **G3** cockpit wiring — `ComponentView3D.swift` 가 produced.usdz
  로딩, 회전·줌 인터랙티브
- **G4** provenance — 모든 subprocess 호출 stderr 에 cited URL +
  버전 + exit code · fail-loud `exit(91)`

---

## 진행 로그

### 2026-05-19 — C0 scaffold landed

**커밋:** (이 commit)

**산출:**

- `component/README.md` (157 줄) — 1-pager, friendly 7-요소 패턴,
  §1 cited sources (FreeCAD/gmsh/USDPython/Blender USD/Antmicro chain),
  §2 demiurge consumer 측 reference, §3 4-gate, §4 cross-link, §5 phase
  요약.
- `component/COMPONENT.tape` (90 줄) — tape v1.2 governance: identity,
  pattern decision (D18 subprocess), gate ladder, phase plan, cited
  sources (8 X-tags), scaffold-only honest 보고 note.
- `component/PLAN.md` (this file) — phase log SSOT.

**검증:**

- `component/` 가 hexa-lang 트리에 부재하던 상태 확인 (check 단계).
- 기존 sibling 패턴 (`comb/`, `stdlib/flame/`, `self/forge/`) 과 형태
  일관성 확인.
- `demiurge/domains/component.md` §5 cited URLs 미러 — 본 도메인
  README 와 COMPONENT.tape `@X` 엔트리 일치.

**SCAFFOLD-ONLY (g3 정직 보고):**

NOT landed this cycle —

- `component/*.hexa` 4 파일 (usdz, freecad, gmsh, component dispatcher)
- `self/main.hexa` 의 `hexa component` 분기
- demiurge `ComponentView3D.swift` 리와이어링
- 실제 `.usdz` 산출
- G1-G4 게이트 어느 하나도 측정 수행 안 됨

**다음 사이클 (제안 — user 승인 대기):**

- **C1 USDZ shim** 부터 시작 — USDPython 이 가장 외부 의존성 작고
  (`.usd ↔ .usdz` 단일 변환만), G4 provenance 패턴 정착 vehicle.
- C2 (FreeCAD) / C3 (gmsh) 는 더 큰 외부 도구라 환경 의존성 검증
  필요 — C1 패턴 확립 후 적용.
- C5 (demiurge cockpit) 는 user 측 demiurge 세션에서 처리하거나
  hexa-lang inbox handoff 로 별도 파일링.

---

## 알려진 미정 (open question — user 결정 필요)

1. **C1 의 외부 의존성 검증 방법:** USDPython 이 시스템에 설치되어
   있다고 가정? 혹은 `hexa component setup` 같은 부트스트랩 verb?
2. **`.usdz` 산출 위치:** `component/output/` (트리 내) 임시 → user
   수동 이동? 혹은 `~/.hx/cache/component/` (`AGENTS.tape` HX_DATA_DIR)
   convention?
3. **gate 측정 자동화:** G1 의 "Reality Composer / Quick Look 정상
   렌더링" 은 macOS 수동 검증. CI 자동화 가능한 헤더 검증
   (`xcrun usdchecker` 가 있는지) 으로 대체할지?
4. **(F 와 D 의 관계):** F (component USDZ) 는 D (Yosys §4 + §5
   area-oracle) 산출의 die area 정의를 consume 할 수 있음 — die area →
   package 결정의 한 입력. 단 본 사이클에서는 그 chain 을 묶지 않음
   (independent scaffold).

---

## cross-link

- `AGENTS.tape` — g5 hexa-native-only · D18 bounded-subprocess hybrid
  exception · g7 inbox-patches-pipeline · g_stdlib_ownership pointer-only
  · g_plan_consolidation 도메인-예외
- `component/COMPONENT.tape` — architecture (latest-wins)
- `~/core/demiurge/domains/component.md` — consumer 측 7-verb 도구 표
- `~/core/hexa-lang/comb/PLAN.md` — sibling 도메인 패턴 reference
