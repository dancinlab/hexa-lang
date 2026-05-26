# RFC: import 시 `fn main()` auto-invoke 억제 (라이브러리 재사용)

- 상태: **Draft (설계 제안 — 구현 0, 결정 대기)**
- 출처: INBOX #3 (from anima G2 — `inbox/patches/anima-discovered-2gaps-2026-05-25.md`)
- 영향: **언어 semantics 변경 후보 — blast-radius 有**
- 작성일: 2026-05-27

---

## 1. 요약

hexa-lang 은 컴파일 시 모듈의 top-level `fn main()` 을 프로그램 진입점으로
자동 호출한다. 그런데 한 파일이 다른 모듈을 `use`/`import` 하면, 빌드 단계의
모듈 평탄화(flatten)가 **여러 `fn main()`** 을 한 컴파일 단위로 합치고
**처음 하나만** 진입점으로 남긴다 — 즉 라이브러리 모듈에 `main()` 이 있으면
재사용 시 충돌·드롭이 발생한다. 그 결과 eval/probe 류 모듈(예: anima
`corpus_quality_probe.hexa` 의 TTR 로직)을 라이브러리로 못 쓰고 로직을
호출처에 inline 복제하도록 강제된다. Python 의 `if __name__ == "__main__"`
같은 가드가 없다. 본 RFC 는 이 문제의 정확한 메커니즘을 짚고, 3가지 설계
옵션을 blast-radius 와 함께 비교하여 유지자에게 결정 근거를 제공한다.

---

## 2. 현 메커니즘

### 2.1 auto-invoke 가 일어나는 정확한 위치

| 역할 | 파일:라인 | 코드 |
|---|---|---|
| 진입점 자동 호출 (1차 emit) | `self/codegen.hexa:1439` | `if has_user_main && !has_explicit_main_call { parts.push("    u_main();\n") }` |
| 진입점 자동 호출 (2차 emit, gen2_module) | `self/codegen.hexa:10916` | `if has_user_main && !has_explicit_main_call { out_parts.push("    u_main();\n") }` |
| `has_user_main` 플래그 set | `self/codegen.hexa:1143` (+ `:10681`) | `if ast[i].name == "main" { has_user_main = true }` |
| 명시적 호출 시 억제 | `self/codegen.hexa:1296-1302` (T34) | top-level `main()` ExprStmt 감지 → `has_explicit_main_call = true` |
| 비-entry main 중화 | `self/module_loader.hexa:1306-1311` | `fn main(` → `fn _ml_inert_main_<ei>(` (entry 제외) |

핵심: 생성된 C 의 `int main(int argc, char** argv)` 끝에서
(`codegen.hexa:1419`→`1439`) `u_main();` 을 emit 한다. `u_main` 은
사용자 `fn main` 의 mangled 이름이다. 즉 **hexa 의 `fn main` 자체가
런타임 진입점이 아니라, codegen 이 합성한 C `main` 이 `u_main()` 을
호출하는 구조**다.

### 2.2 single-module vs multi-module (flatten) 흐름

```
[A] single-file 빌드 (hexa build foo.hexa, use 없음)
    ────────────────────────────────────────────────
    foo.hexa (fn main 1개)
        │  codegen.hexa:1143 → has_user_main = true
        ▼
    int main(...) { ... u_main(); }      ← codegen.hexa:1439
        →  foo 의 main 이 정상 fire (의도된 동작)


[B] multi-module 빌드 (hexa build app.hexa, app 가 lib 를 use)
    ────────────────────────────────────────────────
    app.hexa  ── use ──▶  lib.hexa (둘 다 fn main 보유)
        │
        ▼  module_loader.hexa: topo(leaves-first) flatten
    g_order_parts = [ lib.hexa , app.hexa ]   ← entry = 마지막
        │
        │  ei != m-1 (lib, 비-entry):  codegen.hexa 보다 먼저
        │  module_loader.hexa:1306-1311 가 중화
        │      fn main(  →  fn _ml_inert_main_0(   (dead code)
        ▼
    합쳐진 1 TU:  fn _ml_inert_main_0(...)   ← lib 의 main, 호출 안 됨
                  fn main(...)               ← app 의 main (entry)
        │  codegen.hexa:1143 → has_user_main = true (app 의 것)
        ▼
    int main(...) { ... u_main(); }  →  app 의 main 만 fire
```

즉 빌드 경로에서는 module_loader 가 **비-entry 모듈의 `main` 을
inert 로 강등**(`self/module_loader.hexa:1295-1311`, R7 track B
2026-05-18 `a9286eb1`)하므로, 라이브러리 모듈의 `main` 이 호출되지는
않는다. **그러나** lib 의 `main` 바디는 그대로 flatten 되어 컴파일된다 —
그 안에서 참조하는 심볼·side-effect 가 dead-code 로 남고, 동명 `fn`
충돌(first-wins drop, `codegen.hexa:1116-1141`)이나 `let` redeclaration
같은 부수 위험을 만든다. 또한 인터프리터(`hexa run`) 경로는 이 중화가
없어 모든 top-level `main()` 을 auto-invoke 하여 **dual-path 동작 불일치**
가 생긴다 (`self/module_loader.hexa:1442-1452` 의 dual-path 주석 참조).

### 2.3 문제의 본질

- 진짜 차단은 "main 이 fire 된다"가 아니라 **"라이브러리 모듈에 `main` 을
  둘 수 없다"** 는 컨벤션 부재다. 모듈 저자는 `pub fn` 로 로직을, `main()`
  으로 자가검증을 나누는 규율을 알아야만 재사용이 가능하다.
- 가드 문법(`if __name__ == "__main__"`)이 없어, 저자가 규율을 모르면
  로직을 inline 복제하게 된다 (anima TTR witness).

---

## 3. 설계 옵션

| | Option A: import 시 auto-main 억제 | Option B: `_selftest()` 분리 컨벤션 (이미 landed) | Option C: 명시적 `@entry`/`@no_auto_main` annotation |
|---|---|---|---|
| **메커니즘** | "entry 모듈만 `main` fire" 를 semantics 로 격상. codegen/module_loader 가 이미 비-entry main 을 중화 중 — 이를 정식 규칙으로 문서화하고 인터프리터 경로(`hexa run`)도 동일하게 비-entry main skip 하도록 통일. Python `__main__` 등가. | 언어 변경 0. 모듈 저자가 재사용 로직은 `pub fn`, 자가검증은 `fn main()`/`fn _selftest()` 으로 분리. CI `stdlib_selftest_aggregate` 가 `_selftest`/`main` 을 수집. `@selftest_skip`/`@ci_gate` 마커로 게이트 제어. | `@entry` 부착된 `main` 만 진입점, 미부착 `main` 은 라이브러리로 간주(skip). 또는 역으로 `@no_auto_main` 으로 opt-out. parser/codegen 에 attr 인식 추가. 기존 `@manual_main`(`self/attrs/manual_main.hexa`) 의 자매. |
| **blast-radius** | 中. 빌드 경로는 **이미 비-entry main 을 중화**하므로 동작 변화 없음(§4). 인터프리터 경로만 동작이 바뀜(비-entry main 더 이상 fire 안 함) — `hexa run` 의존 코드 영향. 단 `@D g_interp_deprecated` 로 interp 는 폐기 방향. | 0. 코드 변경 없음. 트리 전수 영향 없음. | 中-高. 새 attr 2개 등록(parser `_registry`·codegen branch). 기존 `fn main` 보유 모듈 전부에 `@entry` 부착 마이그레이션 필요(opt-in 형태면) 또는 신규 라이브러리만 `@no_auto_main`(opt-out 형태면). |
| **마이그레이션 비용** | 低. 빌드 경로는 무변경. 문서 + 인터프리터 경로 1곳 통일. interp 폐기 진행 중이라 사실상 文서화. | 0 (이미 landed). | 中. attr 인식 surface 4곳(parser registry·codegen emit·bind allowlist·meta SSOT) + 마이그레이션 스윕. |
| **backward-compat** | 빌드: 완전 호환(현 동작 = 비-entry skip). interp: **breaking**(비-entry main 더 이상 fire). | 완전 호환. | opt-out(`@no_auto_main`) 형태면 호환. opt-in(`@entry` 필수) 형태면 **breaking**(기존 main 전부 무시됨). |
| **Occam (g0)** | 중간 — 코드는 거의 안 건드리나 semantics 격상 결정 필요. | **최소** — 추가 변경 0. | 가장 무거움 — 새 문법 surface. |

보조 사실:
- 이미 `@manual_main` attr(`self/attrs/manual_main.hexa`)이 존재하나 이는
  "explicit `main()` 호출 + `fn main` 동시 작성 시 double-invoke 검사 우회"
  용도이지, 라이브러리/진입점 구분용은 아니다. Option C 가 이 attr 패밀리를
  확장하는 형태가 될 수 있다.
- 빌드 경로의 비-entry 중화는 R7 track B(`a9286eb1`)로 이미 production 이며,
  Option A 의 빌드측 semantics 는 사실상 **현 구현된 동작의 정식화**다.

---

## 4. blast-radius 분석

### 4.1 측정 방법

```
사용/import 타깃 추출:   git grep -hoE '(use|import) +"[^"]+"' -- '*.hexa'
                         → 경로 정규화 → /tmp/used_clean.txt   (380 고유 .hexa 타깃)
fn main 보유 모듈:       git grep -lE '^\s*fn main\(' -- '*.hexa'
                         → 1821 파일
교집합(basename 매칭):   comm -12  →  56 모듈
```

### 4.2 결과

| 지표 | 값 | 비고 |
|---|---|---|
| `fn main()` 보유 `.hexa` 파일 총수 | **1821** | 대다수는 test/smoke/CLI 진입점 (재사용 대상 아님) |
| `use`/`import` 타깃으로 등장하는 고유 모듈 | 380 | 동적 문자열 `use` 노이즈 제외 후 |
| **`fn main()` 보유 ∩ import 타깃 (basename)** | **56** | 상한값(upper bound) — basename 충돌로 과대계상 가능 |

상한 56개 목록(발췌): `qrng`, `entropy`, `verify`, `sampler`, `target`,
`state_vector`, `hexa_ld`, `oeis`, `arxiv`, `pubchem`, `iit_mip`,
`process_tomography_native`, `chemistry_vqe*`(13개) …

### 4.3 확인된 구체 케이스

```
compiler/hw_probes/probes_test.hexa:19   import "./qrng.hexa"
compiler/hw_probes/qrng.hexa:149         fn main()           ← 진짜 blast-radius
```

→ probe 모듈을 import 하면 그 `main` 이 flatten 에 끌려 들어온다(빌드 경로는
중화되어 호출은 안 되나 dead-code 로 컴파일됨; interp 경로는 fire).

### 4.4 Option별 영향

| 옵션 | 깨지는/달라지는 케이스 |
|---|---|
| **A** | 빌드 경로: **0** (이미 비-entry skip 동작). 인터프리터 경로: ≤56 모듈의 비-entry main 이 더 이상 auto-fire 안 함 — 단 interp 는 `@D g_interp_deprecated` 폐기 방향이라 실질 영향 적음. |
| **B** | **0** (이미 landed, 코드 무변경). |
| **C** | opt-in(`@entry` 필수): 1821개 main 전부 마이그레이션 필요(대규모 breaking). opt-out(`@no_auto_main`): 0 호환이나 신규 라이브러리만 수동 표기 — Option B 와 효과 동일하면서 문법 surface 추가. |

핵심 관찰: **빌드 경로는 이미 "entry 만 fire" 로 동작**(Option A 의 빌드측
semantics 가 실제 구현됨). 따라서 라이브러리 재사용을 막는 진짜 잔여 문제는
"semantics 미정의 + 가드 문법 부재로 저자가 안심하고 `main` 을 못 둠"이라는
**문서/규약 차원**이지, 빌드 동작 차원이 아니다.

---

## 5. 권고

**Option B (이미 landed 된 `_selftest()`/`pub fn` 분리 컨벤션)로 충분하며,
추가 semantics-change 는 불필요하다.** (g0 Occam)

근거:
1. **빌드 경로는 이미 Option A 의 목표 동작을 한다** — module_loader 가
   비-entry main 을 중화(`self/module_loader.hexa:1306-1311`)하므로, 라이브러리
   모듈의 `main` 이 진입점을 가로채지 않는다. 즉 "import 시 auto-main 이
   진입점을 fire 한다"는 INBOX 원 진술은 **빌드 경로에서는 이미 거짓**이다.
2. 남는 위험(dead-code 컴파일, 동명 fn first-wins drop, interp dual-path
   불일치)은 **모두 "라이브러리 모듈에 `main` 을 두지 말라"는 규약**으로
   회피된다 — 이것이 정확히 `stdlib/README.md:47-55` 에 landed 된 내용이다.
3. Option A 의 추가 가치는 **인터프리터 경로 통일**뿐인데, interp 는
   `@D g_interp_deprecated` 로 폐기 진행 중이라 ROI 가 낮다.
4. Option C(annotation)는 새 문법 surface 4곳 + 마이그레이션을 추가하면서
   Option B 대비 실효 이득이 없다 — g0 위반.

**조건부 후속(선택)**: 만약 유지자가 인터프리터 경로의 dual-path 불일치를
명시적으로 닫고 싶다면, **Option A 의 "문서화 절반"만** 채택 — 즉
"entry 모듈의 `main` 만 진입점이다"를 언어 spec 에 정식 문장으로 박고,
인터프리터의 비-entry main auto-invoke 를 빌드 경로와 동일하게 skip 하도록
1곳만 통일한다. 새 문법·attr 은 도입하지 않는다.

---

## 6. 마이그레이션 / 롤아웃

- **Option B (권고)**: 추가 작업 없음. `stdlib/README.md` 컨벤션이 SSOT.
  신규/기존 라이브러리 모듈 저자는 재사용 로직을 `pub fn` 로, 자가검증을
  `fn main()`/`fn _selftest()` 로 분리. CI `stdlib_selftest_aggregate` 가
  `@selftest_skip`/`@ci_gate` 마커로 수집 범위 제어.
- **조건부 Option A-문서화만 채택 시**:
  1. 언어 spec 에 "entry-only main fire" 문장 추가(문서).
  2. 인터프리터 비-entry main auto-invoke skip — module_loader flatten 의
     entry 판정(`g_order_parts` 마지막)을 interp eval 경로에서도 적용. 1곳.
  3. 회귀: interp 로 `main()` 을 의존하던 코드 스윕(≤56 모듈, 대부분 test).
  4. 빌드 경로는 무변경(이미 동작).

---

## 7. 참고

- **출처**: anima G2 — `inbox/patches/anima-discovered-2gaps-2026-05-25.md`,
  witness = anima `corpus_quality_probe.hexa` TTR 로직 inline 복제.
- **이미 landed 된 "안전한 절반"**: `stdlib/README.md:47-55`
  (`fn main()` auto-fire 컨벤션 #3 — 로직=`pub fn`, 자가검증=`main`/`_selftest`,
  `@selftest_skip`/`@ci_gate` 마커).
- **메커니즘 코드**:
  - `self/codegen.hexa:1439` / `:10916` — `u_main()` auto-call emit
  - `self/codegen.hexa:1143` — `has_user_main` set
  - `self/codegen.hexa:1296-1302` (T34) — explicit-call 억제
  - `self/module_loader.hexa:1306-1311` — 비-entry main 중화 (R7 track B `a9286eb1`)
- **관련 attr**: `self/attrs/manual_main.hexa` — `@manual_main`
  (double-invoke 검사 우회; Option C 가 확장할 패밀리).
- **관련 거버넌스**: `@D g_interp_deprecated` (interp 폐기 방향 — Option A 의
  인터프리터 통일 가치를 낮춤).
