# hexa 언어 모델 — 정적타입(L4) + 메모리관리(L5) 참조 SSOT

> 이 문서는 hexa 언어의 **타입 시스템**과 **메모리 관리 모델**의 정식 참조(SSOT)다.
> hexa를 소비하는 dancinlab 레포(`.hexa` 사용)와 향후 hexa 도입 레포는 이 모델을 따른다
> (commons `hexa-lang-model`). 설계 SSOT는 `../ARCHITECTURE.json`, 이력은 git.
> 근거는 파일:line 으로 앵커 — 코드가 진실이고 이 문서는 그 요약이다.

---

## 1. 메모리 관리 (L5 memory-management)

### 1.1 기본값 = 함수-스코프 arena 자동관리 (annotation 불필요)

**주석을 아무것도 안 붙인 기본 경로는 자동 메모리 관리다.** `@own` 을 붙일 필요가 없다.

- **메커니즘**: 값 arena가 기본 ON (`hexa_val_arena_on`, default-ON — `compiler/codegen/stream.hexa:67` "the runtime defaults the val arena to ON"). 함수 안에서 만든 composite(배열 리터럴 `[…]` / 구조체 리터럴 `S{…}`)는 그 **함수의 arena scope에 bump-alloc**되고, 함수가 반환하면 `scope_pop`이 **arena를 통째로 자동 회수**한다 (`compiler/diag/catalog.hexa:380` HX arena-escape lint explain: "bump-allocated in that fn's arena scope … `scope_pop` reclaims the arena").
- **탈출값 처리**: 함수의 **반환값만** `__hexa_fn_arena_return`으로 heapify된 뒤 arena가 회수된다. 바깥 배열로의 `hexa_array_push`도 동적으로 heapify된다. 즉 정상적인 값 흐름(반환·push)은 자동으로 안전하다.
- **비유**: 뷔페 쟁반 한 장에 담고 식사 후 쟁반째 반납 — 접시 하나하나 수동으로 안 치운다.
- **결론**: 일반 값(배열/구조체/맵/문자열)은 `@own` 없이도 arena 자동관리(기본 ON). GC도, 수동 free도 필요 없다.

### 1.2 `@own` = opt-in 정밀 소유권 (기본 아님)

- `@own` 은 borrow-check 기반 **ownership 이전 주석**이다 (param에 붙여 소유권을 callee로 이전).
- **현재 corpus 채택 = 0** (`compiler/lower/hir_to_mir.hexa:791/874` "zero corpus @own adoption … inert by construction"). 즉 지금 아무도 안 쓴다.
- 위치: L5 프론티어가 목표하는 **GC-free 정밀 소유권**(region/arena 추론)으로 가는 opt-in 레버지, 기본 동작이 아니다.

### 1.3 `farr_*` 런타임 핸들 = 수동 free + opt-in 누수검사 (별개 세계)

- GPU/텐서 device 핸들(`farr_*`)은 런타임 핸들 테이블의 i64 **슬롯 인덱스**라, 일반 arena 값과 달리 **수동 `farr_free`** 규율을 따른다 (안 풀면 슬롯이 freelist로 안 돌아가 프로세스 생애 동안 pinned).
- opt-in leak-lane `HEXA_BORROWCK_LEAK=1` (default-OFF)이 미해제 핸들 누수를 감지한다. HX3061 handle-LEAK 규칙 = HX3060 UAF의 DUAL, forward MAY OR-join fixpoint.
- **escape-widening 라운드**(2026-07, byteeq-neutral·default-OFF): 핸들이 함수 밖으로 소유권 이전되면 leak 의무를 KILL(escape)해 오탐 제거 —
  - R3 (#4984): mutation/pass store — field_set `s.f=h` · index_set `a[i]=h` · global store · `@own`-param pass
  - R4 (#4989): literal construction — struct/array 리터럴 · enum-constructor payload (`S{f:h}`/`[h]`/`Variant(h,..)`)
  - R5 (#4991): closure env-capture (`\|\| { … h … }`) + `_bck_active` 게이트
  - R6 (#4992): 기존 9 사이트에 `_bck_active` 게이트 — 람다-frame local-id 재시작 false-match로 인한 spurious escape(under-report·soundness) 봉합

### 1.4 arena-escape 예외 (opt-in lint)

- 기본 arena가 **안전하지 않은 유일 케이스** = 함수-로컬 composite를 **모듈-레벨 전역 `let`**에 저장 → `scope_pop` 후 dangling (unheapified escape · `self/runtime_core.c:3432` runtime-admitted).
- opt-in lint `HEXA_ARENA_ESCAPE_LINT=1` (HEXA-OWN L2.5·default-OFF·non-fatal WARNING·byteeq-neutral)이 `global = local_composite` 직접대입을 경고한다. 해결: 반환해서 caller에서 대입 / 모듈 스코프에서 값 빌드 / element-by-element 힙복사.

---

## 2. 정적 타입 (L4 static-typing)

### 2.1 목표 = 컴파일타임 타입확정 → boxed-HexaVal 언박싱

- hexa 값은 기본적으로 16B boxed `HexaVal`로 실린다. **정적 타입 강화**로 컴파일타임에 타입이 확정되면 그 boxing tax(16B/kernel)를 벗겨(unbox) 네이티브 스칼라로 낮춘다.
- 규율: **measure-first** — 언박싱 레버는 측정된 census 수치 위에서만 flip (LLM 판단 금지). 레버는 default-OFF byteeq-neutral로 머지 후 byteeq 3-target + nvptx GREEN 확인 뒤 default-ON.

### 2.2 census 계측기 (측정 도구)

- `HEXA_BOXOP_CENSUS` / `HEXA_CALLTYPE_CENSUS` (#4979, default-OFF·eprintln-gated·byteeq-neutral): producer/consumer boxing 사이트를 계량. 언박싱 대상 규모를 측정.
- 수치 산출은 aiden from-source 빌드 필요(mini는 계측기 authoring만).

---

## 3. 두 축 한눈에

```
                 기본값 (annotation 無)         opt-in 레버
────────────────────────────────────────────────────────────
 메모리(L5)   arena 자동회수 (fn-scope bump    @own 정밀소유권(borrowck·채택0)
              · scope_pop reclaim · 반환/push  HEXA_BORROWCK_LEAK 누수검사
              auto-heapify) = 자동 GC-free      HEXA_ARENA_ESCAPE_LINT
────────────────────────────────────────────────────────────
 타입(L4)     16B boxed HexaVal                컴파일타임 타입확정→언박싱
              (동적)                            (measure-first·census-gated)
```

- **핵심**: 일반 값은 `@own` 없이 arena로 자동 관리된다. `@own`(정밀 소유권)과 언박싱(정적 타입)은 그 위에 얹는 **opt-in 최적화/안전성 레버**이며, 측정·byteeq 게이트 뒤에만 default로 승격한다.
- GPU `farr_*` 핸들만 별도 수동-free + opt-in 누수검사 대상이다.

## 4. 소비 레포 적용 지침 (commons `hexa-lang-model`)

hexa를 소비하는 레포(`.hexa` 사용)는:
- 일반 값은 arena 자동관리를 신뢰하고 수동 free 코드를 넣지 않는다 (arena가 회수).
- 모듈-전역에 fn-로컬 composite를 직접 대입하지 않는다 (arena-escape). 반환/모듈스코프 빌드로 우회.
- `farr_*` device 핸들은 반드시 `farr_free`로 해제 (leak-lane이 잡는 대상).
- 정적 타입을 최대한 확정 가능하게 작성 (언박싱 레버가 걸릴 수 있게).
- 이 모델과 어긋난 기존 코드는 수정한다.
