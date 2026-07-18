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
- ⚠️ **문자열은 arena 값이 아니다 (기본 빌드)** — 배열/구조체/맵과 달리 **유저가 보는 hexa 문자열은 기본 빌드에서 전부 malloc** 이다:
  `hexa_strbuf_alloc` 의 arena 분기는 `#ifdef HEXA_ZEROC_RT_CORE_STRBUF` 가드 안에 있고(`self/runtime_core.c:839`),
  그 매크로는 **zeroc 실험 전용**(`tool/zeroc_*.sh`)이라 메인라인 빌드(`self/main.hexa` · `compiler/`)가 정의하지 않는다.
  `rt_read_file`(`:8898`)은 양 분기 모두 `hexa_str_own(buf)` 로 반환하고 `hexa_str_own → hexa_strbuf_dup_n → hexa_strbuf_alloc` = **malloc 복사**(중간 buf 가 arena 여도 반환값은 힙).
  `hexa_str_concat` 도 arena 를 **스크래치로만** 쓰고 `hexa_str_own` 으로 복사해 반환한다.
  ⟹ 기본 빌드에서 문자열은 **scope_pop 이 되감을 수 없고**, `hexa_val_heapify` 의 TAG_STR arena-strdup 분기는 **발화하지 않는 방어경로**다.
  `HEXA_ZEROC_RT_CORE_STRBUF` 를 켠 구성에서만 문자열이 arena-backed 가 되어 아래 §1.4 escape 규칙의 대상이 된다.
  🕳️ **오독 주의**: "str-arena default ON"(`:4980`)은 **concat 스크래치 버퍼**의 기본값이지 **문자열 값의 거처가 아니다.**
  이 한 줄을 값의 거처로 읽어 소비 레포에서 없는 버그를 "수리"한 사례가 있다(anima #3917 → #3931 정정).
- **결론**: 일반 composite(배열/구조체/맵)는 `@own` 없이도 arena 자동관리(기본 ON). GC도, 수동 free도 필요 없다.
  **문자열은 기본 빌드에서 malloc** 이라 arena 규칙 밖이지만, 사용자 입장의 결론은 같다 — 아무것도 안 해도 된다.

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
- ✅ **필드셋/인덱스셋은 escape 아니다** — `G.f = local` · `G[i] = local` 은 런타임 **store-barrier 가 default-ON 으로 heapify** 한다
  (`hexa_map_set_impl` `self/runtime_core.c:3771` · 인덱스셋 `:3324` · `hexa_arr_water_on()` 는 env 미설정 시 1 · `:2506`; heapify 는 ARRAY/MAP/STR 재귀 = 중첩 deep-heapify).
  `compiler/diag/catalog.hexa:380` 이 이들을 "later rungs"로 적은 것은 **린트 커버리지 공백이지 soundness 공백이 아니다.**
  §1.4 가 "모듈-전역 **직접** 대입"만 유일 위반이라 한 게 정확하다. 단 `HEXA_ARR_HEAPIFY_WATER_OFF`(컴파일) 또는 `HEXA_ARR_HEAPIFY_WATER=0`(env)으로 배리어를 끄면 이 안전성은 소멸한다.
- ⚠️ **`@no_arena` fn 은 "반환 = 안전" 법칙의 예외** — 이 속성이 붙으면 codegen 이 arena enter/return 자체를 생략하므로
  (`self/codegen.hexa:3473`) 반환값이 heapify 되지 않고 로컬이 **호출자 arena** 에 쌓인다.
  마찬가지로 region-returns 토글(`self/runtime_core.c:6051` · `RETURN_REGION_ON__` 빌트인)이 켜지면 `__hexa_fn_arena_return` 이 malloc 대신 **호출자 arena 로 승격**하므로 `global = f()` 조차 escape 가 된다. 둘 다 opt-in 이며 기본 경로가 아니다.

### 1.5 `alloc_raw`/`free_raw` = 제3의 수동 세계 (raw malloc · FFI 전용)

- arena도 `farr_*` 핸들도 아닌 **세 번째 메모리 세계**다. codegen 이 `alloc_raw → hexa_ptr_alloc`, `free_raw → hexa_ptr_free` 로 매핑하고
  (`self/codegen/arm64_darwin.hexa:2135`) 구현은 그냥 `malloc`/`free` (`self/runtime.c:16364`).
- 값이 **TAG_INT 스칼라(raw 포인터)** 라 arena composite 가 아니다 ⟹ `scope_pop` 대상 아님 · 전역 대입도 §1.4 escape 아님 · `__hexa_fn_arena_return` 의 primitive short-circuit 으로 heapify 도 우회한다.
- **leak-lane(HX3061)이 추적하지 않는다** — 생산자 테이블은 `farr_zeros/farr_copy/farr_int_zeros/farr_int_copy/farr32_zeros` 뿐이다(`compiler/lower/hir_to_mir.hexa:903`). 즉 `alloc_raw` 누수는 **어떤 계기도 잡아주지 않는다.**
- 용도: extern C out-param · cuBLAS 스칼라 버퍼 · 커널 arg 팩 등 FFI 에 본질적으로 필요한 곳. 그 외엔 쓰지 마라.
- 규율: **짝을 손으로 맞춰라** — 에러 경로 포함 모든 exit 에서 `free_raw`, 또는 프로세스-생애 영속 버퍼라면 그 의도를 주석으로 명시하고 shutdown 훅에서 해제.

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

**메모리 세계 3개 — 어디에 사는지가 규율을 정한다 (§1.1·§1.3·§1.5)**

```
 값 종류                  거처(기본 빌드)      해제        escape 규칙(§1.4)
──────────────────────────────────────────────────────────────────────────
 배열·구조체·맵           fn arena (bump)      자동        ⚠️ 전역 직접대입 = 위반
 문자열                   malloc               자동        해당없음(arena 아님)
                          ↳ arena 는 zeroc                  ↳ zeroc 구성서만 위반
                            opt-in 에서만
 farr_* device 핸들       핸들 테이블 슬롯     수동 free   해당없음(i64 슬롯)
 alloc_raw 포인터         malloc (raw)         수동 free   해당없음(TAG_INT)
                                               ↳ 계기 없음
```

- **핵심**: 일반 composite 는 `@own` 없이 arena로 자동 관리된다. `@own`(정밀 소유권)과 언박싱(정적 타입)은 그 위에 얹는 **opt-in 최적화/안전성 레버**이며, 측정·byteeq 게이트 뒤에만 default로 승격한다.
- 수동-free 대상은 **둘**: GPU `farr_*` 핸들(opt-in leak-lane 이 감시) · `alloc_raw` 포인터(**감시 계기 없음** — 손으로 짝을 맞춰야 한다).

## 4. 소비 레포 적용 지침 (commons `hexa-lang-model`)

hexa를 소비하는 레포(`.hexa` 사용)는:
- 일반 값은 arena 자동관리를 신뢰하고 수동 free 코드를 넣지 않는다 (arena가 회수).
- 모듈-전역에 fn-로컬 composite(배열/구조체/맵)를 직접 대입하지 않는다 (arena-escape). 반환/모듈스코프 빌드로 우회.
  필드셋·인덱스셋(`G.f = local`)은 store-barrier 가 heapify 하므로 **허용**된다(§1.4).
- **문자열은 arena 규칙 밖이다**(기본 빌드 = malloc · §1.1). 문자열 전역대입을 arena-escape 로 오진하지 마라 —
  `HEXA_ZEROC_RT_CORE_STRBUF` 를 켠 구성에서만 대상이 된다.
- `farr_*` device 핸들은 반드시 `farr_free`로 해제 (leak-lane이 잡는 대상).
- `alloc_raw` 는 FFI 로 불가피할 때만 쓰고 **짝을 손으로 맞춘다**(§1.5) — 이 lane 은 감시 계기가 없다.
- 정적 타입을 최대한 확정 가능하게 작성 (언박싱 레버가 걸릴 수 있게).
- 이 모델과 어긋난 기존 코드는 수정한다.

## 5. 이 문서를 읽는 법 (소비 레포가 데인 함정)

- 🕳️ **문서 한 줄을 값의 성질로 일반화하지 마라 — 실제 빌드에 그 분기가 컴파일되는지까지 봐라.**
  `#ifdef` 가드 + 메인라인 `-D` 조립부를 확인하라. "default ON" 이라는 말이 **무엇의** 기본값인지 코드로 확인하라
  (str-arena 는 concat 스크래치의 기본값이지 문자열 값의 거처가 아니다 · §1.1).
- 🧪 **계기의 0 을 정합으로 읽지 마라 — 양성통제를 먼저 통과시켜라.** leak-lane(HX3061)은 `hir_to_mir` **lowering** 패스에서 발화하므로
  `hexa typecheck`(diagnostics only, no codegen)로는 **절대 측정되지 않는다** — 0 이 나와도 그건 "누수 없음"이 아니라 "계기 미도달"이다.
  정식 경로 = from-source `aprime_cc`(`tool/build_aprime.sh`) + `--emit=asm` + GATE-D 픽스처 자기검증(`test/borrowck/handle_leak/`).
- 📌 **근거 줄을 인용할 때 그 줄이 실제로 무엇인지 확인하라.** 예: "모듈-init = 힙경로"의 근거로 `runtime_core.c:4715` 를 인용하면 틀린다
  (그 줄은 `hexa_valstruct_new_v` 이고 `from_arena=0` 은 mark 와 무관하게 무조건).
  진짜 근거 = codegen 이 top-level 을 `main()` 안에 `__hexa_fn_arena_enter()` **없이** 펼치고(`self/codegen.hexa:1554`·`17045` · enter 는 `gen2_fn_decl:3478` 에서만 emit),
  val-arena 할당 경로가 전부 `__hexa_val_mark_top > 0` 게이트라는 사실이다.
