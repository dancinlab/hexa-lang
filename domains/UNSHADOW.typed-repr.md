# UNSHADOW — typed-repr RFC (타입 표현 졸업)

> 상태: **DESIGN / RFC draft** (구현·측정 아님). 다음 사이클이 §성공-게이트 기준으로 pick-up.
> 모든 동기는 이미 측정된 UNSHADOW 발견에 묶임 — 새 perf 숫자 발명 없음.
> SSOT = 이 파일 (UNSHADOW.md 에 milestone `- [ ]` 2줄로 등록, UNSHADOW.bench.md 가 측정대).

---

## §문제 — 박싱이 막는 것 (parity 갭 + E 불가)

UNSHADOW 의 두 종착 발견이 **하나의 근본 원인**으로 수렴한다 = **모든 값이 동적 24-byte
boxed `HexaVal`(tagged union)** 이라는 것:

- **(측정 1) raw-parity 갭 7.9×~1263×** — `UNSHADOW.bench.md §parity-attest`. hexa C-emit
  @-O2 / idiomatic ref-C @-O2 비가 1.0 이 아니다. §정직한-발견(L354-369)이 주범으로 지목한
  것 = "emit-C 의 모든 정수 연산이 `HexaVal` 을 경유하고, fast-path 가 아닌 분기·박싱
  구성은 precompiled `runtime.o` 의 out-of-line 호출" → clang 이 그 벽 너머로 fold/LICM
  못 함.
- **(측정 2) HexaVal 언박싱 = 11.30× · gap 11.09×→0.98×** — `§hexaval-unbox`. known-int BinOp
  rebox 를 inline literal 로 바꾸자 **scalar** 축에서 parity 갭이 **100% closed**(53ms ≈
  ref 54ms). 즉 박싱 제거가 갭을 닫는 검증된 레버임이 실측됨 — **단 scalar known-int 한 점**.
  array/struct 는 여전히 boxed (bench L425-427 caveat 가 명시: "known-int 비율이 높은
  워크로드 기준 … array 는 별도").
- **(측정 3) E(AoS↔SoA) = 🔴 CLOSED-NEGATIVE** — `UNSHADOW.md` milestone E. SoA 표현이 불가능한
  3-fold 근본 원인 = (a) monomorphic struct-array 타입 없음 (b) 필드-contiguous 메모리가
  애초 없음(struct = `hexa_struct_pack_map` 해시맵, `self/codegen.hexa:8043` · 필드 접근 =
  `hexa_map_get_ic` strcmp/IC, `:5394`) (c) `double[]` unboxed-primitive 배열 타입 없음
  (`HexaArr { HexaVal* items; ... }`, `self/runtime.h:74` = AoP, 각 원소 24B boxed).

**핵심**: (2)는 박싱 제거가 갭을 닫음을 scalar 에서 **증명**했고, (1)은 그 갭이 array/hot-loop
에도 있음을 측정했고, (3)은 데이터-구조-수준 최적화(SoA)가 typed 표현 부재로 막혀 있음을 결정적
으로 못 박았다. → **"typed representation"** 이 다음 실재하는 frontier 레버.

### 현 표현의 정밀 확인 (read-only 조사, 2026-05-30)

- **struct** = `hexa_struct_pack_map("Name", N, _k, _v)` (필드명→HexaVal 해시맵). 생성자가
  키 배열 + 값 배열을 bulk-insert (`gen2_struct_decl`, `self/codegen.hexa:8008-8046`).
  필드 접근 `obj.field` → `hexa_map_get_ic(obj,"field",&ic)` (per-site inline-cache 슬롯,
  여전히 strcmp-chain, `:5373-5394`).
- **valstruct 예외 = 일반 메커니즘 아님.** `hexa_valstruct_new_v` 라는 "flat-struct" 가
  존재하지만 (`self/runtime_core_emit.hexa:3478`) 인터프리터의 hot `Val` 타입(정확히 12
  필드) 전용으로 **하드코딩**됨 (`gen2_struct_decl` 의 `if name == "Val" && len==12`,
  `:7995`). 레이아웃 = 고정 12-슬롯 **polymorphic** carrier (`tag_i/int_val/float_val/
  bool_val` + 8개 named `HexaVal` 슬롯, `runtime_core_emit.hexa:1207-1228`). 접근도
  `hexa_valstruct_get_by_key` 가 여전히 **strcmp 분기**로 슬롯 찾고 scalar 는 다시 HexaVal 로
  rebox (`:3535`). → 사용자-typed-monomorphic offset 접근이 **아님**. 일반화 불가.
- **array** = `HexaArr { HexaVal* items; int len; int cap }` (`self/runtime.h:74`). 리터럴
  `[a,b,c]` → `hexa_array_push(hexa_array_new(), ...)` 체인, 각 원소 boxed HexaVal
  (`gen2_expr` ArrayLit, `self/codegen.hexa:7594-7611`). `[i64]` 가 native `int64_t[]` 가
  **아니라** 24B-boxed-HexaVal 배열.
- **c-class WIN 이 남긴 정확한 확장점** — `§c-class` (bench L577-579)가 명시: bounds-check
  를 elide 해 `arr.arr_ptr->items[i]` 직접 read 까지 갔지만, **그 read 가 여전히 boxed
  HexaVal 을 산출**하고 array-tag guard 1개가 잔존한다. "known-array 추적기가 생기면 tag-guard
  도 삭제 가능(미측정 lever)". = Option A 의 정확한 진입점.

---

## §설계 옵션

### 옵션 A — unboxed-primitive array (`[i64]`/`[f64]` → native scalar array)

원소 타입이 정적으로 `i64`(또는 `f64`)로 증명되는 배열을, boxed `HexaVal*` 대신 **native
`int64_t*`/`double*`** 로 저장. 박싱은 **동적 경계에서만** (배열이 untyped 컨텍스트로 흘러가거나
`HexaVal` 로 surface 될 때) 발생.

- **표현**: `HexaArr` 에 element-kind 태그를 추가하거나(`HEXA_ARR_I64`/`F64`/`BOXED`), 별도
  병렬 표현 `HexaArrI64 { int64_t* data; int len; int cap }` 를 두고 `HexaVal` union 에
  슬롯/태그를 추가. boxed 와 unboxed 가 공존 — 기존 동적 경로는 BOXED 유지(무변경 보장).
- **발화 조건**: 원소 타입을 정적으로 증명 가능한 곳에서만 — 동질 리터럴 `[1,2,3]`(IntLit
  전부) · `let xs: [i64]` 주석 · 증명된 `[i64]` 반환. 미증명이면 기존 boxed emit (= 일반
  경로 무변경, hexaval-unbox 와 동일한 "증명 시만 발화, else 기존" 규율).
- **읽기/쓰기**: `arr[i]` read 가 `data[i]` (native scalar) 를 직접 산출, HexaVal box 는
  hot-loop 내에서 제거 (§c-class 가 남긴 tag-guard + box-on-read 를 닫음). 동적 surface 에서만
  `hexa_int(data[i])`.

### 옵션 B — typed monomorphic struct layout (flat C-struct + offset field access)

특정 struct 타입이 monomorphic 임을 컴파일러가 증명하면, `hexa_struct_pack_map`(해시맵) 대신
**flat C-struct** 로 emit 하고 필드 접근을 **offset** 으로 (strcmp/IC 아님).

- **표현**: struct decl 마다 `typedef struct { int64_t f0; double f1; HexaVal f2; ... }`
  를 emit (필드 선언 순서 = 슬롯 순서). 생성자가 `hexa_map_set` 대신 멤버 직접 대입.
  `valstruct` 와 달리 **타입별 레이아웃** (고정 12-슬롯 carrier 아님).
- **발화 조건**: struct 가 monomorphic — 필드 집합이 닫혀 있고(동적 키 추가 없음), 모든 접근이
  정적으로 알려진 필드명. 다형/동적-키 struct 는 기존 hash-map 유지.
- **읽기**: `obj.field` → `obj.vs->f_k` (컴파일-타임 결정 offset), strcmp-chain 제거.
- **선결 = E 재오픈**: 이게 있어야 array-of-struct 가 SoA(필드-contiguous)로 재배열 가능 —
  E 의 (a)(b) 차단을 해소.

---

## §각 옵션의 codegen / type-layer 착지점

| 레이어 | 옵션 A (unboxed array) | 옵션 B (typed struct) |
|---|---|---|
| **type/check** (`compiler/check/`) | element-kind 추론 (동질 리터럴·`:[i64]` 주석·반환타입). 좁음 — 단일 element-kind | monomorphic struct 증명 (닫힌 필드집합·정적 필드 접근). 넓음 — struct 단위 shape |
| **parser** (`compiler/parse/`) | `[i64]`/`[f64]` 타입 주석 파싱 (대부분 이미 존재) | 변경 거의 없음 (struct decl 이미 파싱) |
| **codegen** (`self/codegen.hexa`) | ArrayLit emit(`:7594`) + Index read(`:7661`, §c-class 가 이미 만진 지점) 에 typed-array arm 추가. 박싱 경계 emit | `gen2_struct_decl`(`:7982`) 에 flat-struct typedef arm + 생성자 멤버대입. Field access(`:5373`) 에 offset arm |
| **runtime** (`self/runtime_core_emit.hexa`, `runtime.h`) | `HexaArrI64`/`F64` 표현 + box/unbox 헬퍼(public, runtime.h 가시 → §c-class 처럼 벽 관통) | per-type flat-struct 는 user.c 안 typedef 라 runtime 변경 최소; eq/print 등 polymorphic 연산만 dispatch 갱신 |
| **블라스트 반경** | **좁음** — 기존 BOXED 경로 무변경, 새 typed arm 추가만. c-class 확장점 직계 | **넓음** — struct 전 경로(생성·접근·eq·serialize·map-interop) 가 두 표현 공존 |

---

## §ROI · 난이도 · 선후

**옵션 A 가 더 작은 첫 걸음 — 먼저.** 근거:

1. **검증된 레버의 직계 확장.** `§hexaval-unbox` 가 scalar 에서 박싱 제거 = 11.30× · gap
   100% closed 를 **실측**. A 는 그 동일 박싱 제거를 **array 축**으로 확장 — `§parity-attest`
   가 갭의 주범으로 지목한 바로 그 박싱.
2. **인프라가 절반 이미 있다.** `§c-class` 가 codegen 의 typed-context 검출(`for i in
   0..len(arr)`) + 직접 `items[i]` read 를 이미 구현·측정(3.25×). A 는 그 read 가 남긴
   "boxed HexaVal 산출 + tag-guard 잔존"(bench L577-579 가 미측정 lever 로 명시)을 닫는 것 =
   증명된 진입점.
3. **블라스트 반경이 좁다.** element-kind 추론 + ArrayLit/Index 2개 emit-site + runtime box/unbox
   헬퍼. struct 전 경로를 건드리는 B 보다 narrow. 기존 BOXED 경로 무변경 = 회귀 위험 낮음.

**옵션 B 는 더 크고, A 다음.** 근거:
- monomorphic 증명이 struct 단위 shape 분석 (닫힌 필드집합·다형 배제) 으로 type-layer 가 무겁다.
- struct 전 경로(생성·접근·eq·serialize·map-interop)가 두 표현 공존 → 회귀 surface 큼.
- 단 **E 재오픈의 선결**이라 가치는 분명 — A 로 unboxed-array 패턴(box/unbox 경계·typed-arm
  codegen)을 먼저 확립하면 B 의 flat-struct emit 이 그 패턴을 재사용 가능.

**선후**: A (unboxed-primitive array) → B (typed monomorphic struct) → (B 완료 시) E(AoS↔SoA)
재오픈. 둘 다 `.c=0` LTO 졸업(RUNTIME.flip-floor)과 **직교** — typed 표현은 runtime.o 벽과
독립한 별도 축 (§c-class 가 입증: codegen 증명은 벽과 무관하게 발화).

---

## §성공 게이트

UNSHADOW 의 g5 규율 + roofline-% 기준 (CLAUDE.md `feedback_closure_is_physical_limit`):

- **(필수) byte-diff IDENTICAL** — typed arm ON/OFF 양쪽, HIT+NO-HIT, in-range+OOB 모두 stdout
  byte-동일 (md5). 무손실이 correctness 전제. 기존 BOXED 경로는 변경 0임을 byte-diff 로 증명.
- **(필수) 무결성 게이트** — A: 동적 경계(untyped 컨텍스트로 흘러간 배열)에서 box 가 정확히
  발생, OOB read 없음. B: 다형/동적-키 struct 는 hash-map 경로 유지.
- **(측정) parity Δ** — A: `[i64]`/`[f64]` hot-loop 의 parity 갭 측정 — `§parity-attest`
  (7.9×~1263×) · `§hexaval-unbox`(scalar 0.98×) 기준선 대비 array 축 Δ. B: struct 필드 접근
  hot-loop 의 hash-lookup→offset Δ (instr count + wall).
- **측정대 재사용** = `tool/unshadow_*_bench.hexa` 패턴 (faithful A/B proxy; full self-host
  regen 은 B9 벽 차단 — 기존 milestone 들과 동일 스펙 허용). verdict = `.verdicts/<slug>/`.
- **honest caveat 필수** — 발화 안 하는 케이스(다형 배열·동적-키 struct·mut-누산기) 명시.
  closed-negative 도 valid (paper_negative_ok) — 단 데이터-표현 축을 결정적으로 배제할 때만.

---

## §참조

- 동기 측정: `UNSHADOW.bench.md` §parity-attest(L289) · §hexaval-unbox(L382) · §c-class(L521)
- E closed-negative: `UNSHADOW.md` milestone "🔵 E AoS↔SoA"
- 현 표현 조사: `self/codegen.hexa`(struct `:8008` · field `:5373` · array `:7594`/`:7661`) ·
  `self/runtime.h`(HexaVal `:79` · HexaArr `:74`) · `self/runtime_core_emit.hexa`(valstruct
  `:1207`/`:3478`/`:3535`)
- 스택 원칙: `UNSHADOW.easy.md` §HEXA-STACK (🟡 floor 상속 + 🔵 ceiling 적층)
