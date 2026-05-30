# UNSHADOW — log

Append-only history sister of `UNSHADOW.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-30T09:00Z — 🎯 roofline 측정대 — 상대 Δ → HW 물리 천장 % 절대 잣대 전환 (MEASURED · g5 5/5 IDENTICAL)

UNSHADOW 측정 잣대를 "vs idiomatic C @ clang -O2"(상대 Δ) 에서 **HW 물리 천장(roofline) %**
(절대) 로 영구 전환. 새 대량 벤치가 아니라 **분모 교체 + 분석적 재계산 + 잣대 전환**.

- [x] **격리 worktree** — `/tmp/uns-roofline` (origin/main 베이스). 공유 트리·타 브랜치 미접촉.
- [x] **achieved-peak 분모 1회 실측** (@L2 · mini Apple M4 · clang -O2 · best-of-5) — 스펙시트
  추정 금지. `tool/unshadow_peak_microbench.hexa`(/tmp 에 ref-C 커널 emit·`.c` 훅 회피):
  - memory-roof STREAM-triad = **92.3–95.2 GB/s** (theoretical LPDDR5X ~120 → 77–79%)
  - compute-roof FMA double = **15.24 GFLOP/s** (theoretical P-core ~17.6 → 87%)
  - compute-roof scalar int = **12.88–13.06 GIOP/s** · ridge-point ≈ 1.08 ops/byte
  - achieved 와 theoretical **나란히** 박제(@L2 정직 — 격차 숨기지 않음).
- [x] **harness 어댑터** (@L3 · `tool/unshadow_bench.hexa`) — 워크로드별 정수-op 계수 +
  binding-roof 자동선택(AI=flops/bytes vs ridge; register-resident 스칼라 → AI≫ridge →
  compute-bound int-roof) + achieved/binding-roof %. 기존 native-vs-clang A/B 출력·JSONL 보존,
  roofline % 컬럼·필드(roof_bound·roofline_pct_{native,clangO2}_x10) 추가. parse-gate PASS.
- [x] **기존 9개 재표기** (@L4 · `UNSHADOW.bench.md §roofline` 표) — ns 재활용 → roofline %:
  - M1 baseline 5/5: hexa C-emit clangO2 arm **2.0–4.6%** · native **1.8–3.1%** of int-roof
    (native 5/5 패배가 roofline % 로도 그대로 드러남 — 정직).
  - #2 hexaval-unbox: BEFORE **9.0%** → AFTER **101.9%** (idiomatic-C anchor, AT PARITY).
  - §unboxed-array c_native(HexaArrI64) **100%**(천장 = STORAGE) · §c-class b_elided **14.3%**(3.25×).
  - 🔵 "안 돌기"(#4 const-fold·B proof-carrying)=**roofline-N/A**(work 제거→분모 anchor 없음,
    wall-Δ 65%·47% 로 보고) · #3 arena RSS=**roofline-N/A**(공간 메트릭) · #2-ext·C 🔴
    CLOSED-NEG=**roofline-N/A**(win arm 부재). 환산 무의미한 것은 정직하게 N/A.
- [x] **g5 게이트** — 5 워크로드 byte-diff **5/5 IDENTICAL**(correctness=MATCH 전부). verdict
  verbatim = `.verdicts/unshadow-roofline-stand/g5-roofline-bench.txt` (원시 JSONL 포함).
- [x] **문서** — `UNSHADOW.bench.md §roofline`(잣대 정의·achieved-peak 분모·재표기 표·정직 해석) ·
  `UNSHADOW.md` roofline 측정대 milestone flip(@goal 은 이미 "roofline % 기준" 반영) · 이 로그.
- [x] **정직 finding** — hexa C-emit 의 절대 천장 % 는 낮다(2–5%, boxed HexaVal ABI). 이득은 raw
  경쟁이 아니라 🟢 벽제거·🔵 우회 — #2 unbox·c_native 가 천장을 닫음(→101.9%·100%). memory-bound
  워크로드는 본 corpus 에 없음(전부 register/L1 compute-bound) — SoA/AoS 케이스는 typed-repr
  frontier 랜딩 후 측정 가능(미수집, 정직). op-count roofline% 는 하한 추정(clang fold) ·
  idiomatic ref-C anchor % 가 보완.
- [x] **hexa-loop bench adapter** (@L5, 별도 ship) — sidecar hexa-loop SKILL.md bench-adapter
  verify 기준을 "byte-diff IDENTICAL + Δ" → "byte-diff IDENTICAL + roofline %" 로 갱신. version
  lockstep bump(g22) + `sidecar sync`. hexa-lang repo 와 분리된 commit.

## 2026-05-30T07:30Z — 📐 typed-repr RFC + 백로그 재개 (DESIGN, 구현 아님)

E(🔴 CLOSED-NEGATIVE)의 근본 원인 "typed 표현 부재(monomorphic struct layout 0 + unboxed-primitive
array 0)" 를 다음 frontier 로 설계·등록. **DOC/RFC only** — codegen 무편집·.c 무생성·측정 없음.

**read-only 조사 (E-finding 정밀 확인)**:
- struct = `hexa_struct_pack_map`(필드명→HexaVal 해시맵, `self/codegen.hexa:8043`) · 필드 접근 =
  `hexa_map_get_ic`(strcmp/inline-cache, `:5394`). **typed monomorphic 레이아웃 부재 확정.**
- valstruct 예외는 일반 메커니즘 **아님** — 인터프리터 hot `Val` 전용(12필드 하드코딩, `:7995`),
  레이아웃 = 고정 12-슬롯 **polymorphic** carrier(`runtime_core_emit.hexa:1207`), 접근도
  `hexa_valstruct_get_by_key`(`:3535`)가 여전히 strcmp 분기 + scalar rebox. 일반화 불가.
- array = `HexaArr { HexaVal* items; int len; int cap }`(`self/runtime.h:74`) = AoP, 각 원소 24B
  boxed. 리터럴 = `hexa_array_push` 체인(`:7594`). **`[i64]`=native `int64_t[]` 아님 확정.**
- §c-class 가 남긴 확장점 = `items[i]` direct read 까지 갔으나 read 가 여전히 boxed HexaVal 산출
  + tag-guard 잔존(bench L577-579 "미측정 lever"). = 옵션 A 진입점.

**feasibility 판정**: 옵션 A(unboxed-primitive array)가 더 작은 첫 걸음. (1) §hexaval-unbox 가
scalar 에서 검증한 박싱-제거 레버(11.30×·gap 100% closed)의 array 축 직계 확장 (2) §c-class 가
typed-context 검출 + 직접 read 를 이미 구현(3.25×) → A 는 그 read 의 box+tag-guard 만 닫음 (3)
블라스트 반경 좁음(element-kind 추론 + 2 emit-site + box/unbox 헬퍼, 기존 BOXED 경로 무변경). 옵션
B(typed monomorphic struct)는 monomorphic 증명·struct 전 경로 공존으로 크고 A 다음 — 단 E 재오픈
선결이라 가치 분명. 둘 다 `.c=0` LTO 졸업과 직교(§c-class 가 codegen 증명은 runtime.o 벽 독립임 입증).

- [x] RFC draft 작성 = `domains/UNSHADOW.typed-repr.md` (§문제·§설계옵션 A/B·§codegen·type-layer
      착지점·§ROI/난이도/선후·§성공게이트, 모든 동기 = 측정된 발견에 묶음, 새 perf 숫자 0)
- [x] UNSHADOW.md 에 milestone `- [ ]` 2줄 등록 (기존 13 `[x]` 무변경) — A(🟢 unboxed-array) ·
      B(🔵 typed monomorphic struct)
- [ ] (다음 사이클) 옵션 A 구현·측정 — byte-diff IDENTICAL + array 축 parity Δ
- [ ] (A 이후) 옵션 B 구현·측정 → 완료 시 E(AoS↔SoA) 재오픈

## 2026-05-30T06:00Z — 🔵 E AoS↔SoA 자동전환 — 🔴 CLOSED-NEGATIVE (typed-struct layout 부재로 축 ruled-out)

UNSHADOW 마지막 open milestone "🔵 E AoS↔SoA 자동전환 OR F CPU/GPU fusion (도메인 택1)" 을 **E 축(codegen-native)** 으로 택해 SCOPED PILOT 수행 (F=GPU fusion 은 flame/forge 도메인 중복+GPU 임대 비용이라 제외, E 가 UNSHADOW 고유 codegen turf). 결과 = **honest closed-negative** — SoA 를 표현할 정적 struct 레이아웃 자체가 hexa 표현계에 없음. 이 축은 `typed monomorphic struct layout` + `unboxed-primitive array` 인프라가 랜딩되기 전까지 결정적으로 ruled-out.

### REALITY CHECK — struct/array-of-struct 표현 전수조사 (구현 전 선행)

- **struct literal 생성** (`self/codegen.hexa:7914 gen2_struct_decl`): 모든 struct 는 `hexa_struct_pack_map("Name", N, _k, _v)` 로 emit — **필드명(string) 키 → HexaVal 값의 해시맵**. 정적 C struct 레이아웃 0. (예외 1건 = `name == "Val" && len(fields)==12` 의 `hexa_valstruct_new_v` flat-struct 특수경로 — 인터프리터 hot Val 1종만 hand-special-case, 12 슬롯 **고정**이고 각 슬롯도 여전히 boxed `HexaVal`. 범용 typed-layout 아님.)
- **필드 접근** (`self/codegen.hexa:5336 k=="Field"`): `obj.field` → `hexa_map_get_ic(obj, "field", &ic)` — per-site inline-cache 해시 조회. `arr[i].field` → `hexa_map_get_ic(hexa_index_get(arr,i), "field", &ic)` (조회 2단).
- **runtime 표현** (`self/runtime.h:74,79-92,130`): `HexaVal` = 태그드 유니온(24B, `tag`+union). struct = `TAG_MAP` → `HexaMap{HexaMapTable*}` (`slots`/`vals`/`order_keys`/...). array = `TAG_ARRAY` → `HexaArr{HexaVal* items; len; cap}`. **array-of-struct = `HexaVal*`(boxed) 배열, 각 원소가 별도 힙 `HexaMap`.** 동일-struct 여부를 정적으로 아는 타입계 부재(런타임 `__type__` 문자열만).

### 왜 SoA 가 표현 불가 (3-fold)

1. **(a) "이 값이 동일-struct 배열이다" 정적 증명 불가** — array 는 `HexaArr` of `HexaVal`(임의 태그 혼재 가능). 원소가 같은 struct 타입임을 보장하는 monomorphic array 타입이 codegen/타입계에 없음.
2. **(b) "루프가 한 필드만 sweep" 분석은 가능하나 무의미** — 필드 접근이 `hexa_map_get_ic`(해시 조회)라 필드-contiguous 메모리가 애초에 존재하지 않음. AoS 조차 진짜 AoS 가 아니라 **AoP**(Array-of-Pointers-to-heap-maps).
3. **(c) re-lay-out / field-contiguous 접근 emit 불가** — SoA = `{xs:[...], ys:[...]}` 의 `xs` 가 `double` contiguous 여야 SIMD/cache-dense 이득. hexa 엔 `double[]` 같은 unboxed-primitive 배열 타입이 없음 (`HexaArr` 은 `HexaVal*` = 24B boxed 스칼라). 필드를 따로 모아도 여전히 boxed `HexaVal` 배열 → cache-density·SIMD 이득의 전제(unboxed contiguous primitive) 불성립.

### 누락된 인프라 (이게 랜딩돼야 E 가 열림)

1. **typed monomorphic struct layout** — `struct Point{x:f64,y:f64}` 를 필드명 해시맵이 아니라 정적 C struct(또는 SoA 변환 가능한 IR 노드)로 codegen 이 다룰 타입계. 현재 0.
2. **unboxed-primitive array** (`[f64]`/`[i64]` = native `double[]`/`int64_t[]`) — boxed `HexaVal*` 가 아닌 contiguous primitive 배열. SoA 의 cache/SIMD 이득은 전적으로 여기에 의존. 현재 0.
3. 위 둘 위에서야 (a) monomorphic AoS 인식 → (b) 단일-필드 sweep 탐지 → (c) SoA 재배치/접근 emit 의 transform 이 비로소 표현 가능.

### 판정

- **🔴 CLOSED-NEGATIVE** — E(AoS↔SoA) 는 hexa 의 현 dynamic-HexaVal 표현계에서 **표현 불가**. 좁은 한 케이스조차 transform 을 emit 할 layout 노드가 없어 byte-diff 검증 대상 자체가 성립 안 함. 거짓 win 강행보다 정직한 ruled-out 이 terminal 결과.
- **확정적으로 배제** — `typed monomorphic struct layout` + `unboxed-primitive array` 두 인프라가 랜딩되기 전까지 E 는 닫힘. (이 typed-repr 인프라는 RUNTIME.flip-floor 의 `.c=0` 졸업과 직교 — 별도 typed-repr RFC 사안. unwall 이 분리해낸 "runtime.h-가시 layout" axis 와도 다름: HexaArr 은 이미 가시지만 boxed HexaVal* 라 SoA 무의미.)
- transform 미구현 → `self/codegen.hexa` 무변경 → byte-diff N/A (검증할 변경 없음). 측정 N/A. cloud/GPU 미사용(E 축, F 미접촉).
- paper_negative_ok ethos 충족: 한 축(데이터 표현 자유 E)을 결정적으로 ruled-out → valid terminal milestone close. UNSHADOW 선언 backlog 의 마지막 open milestone 종결.

## 2026-05-30T00:00Z — 🔵×🟡 same-TU 빌드 기본화 cost/benefit PILOT (measured · opt-in 권고)

§lto-unwall(−31%)을 빌드-레시피로 만든 milestone "same-TU 빌드 기본화" 의 측정 파일럿. 결론 = **opt-in flag, NOT default**.

- [x] cmd_build 에 GATED same-TU MODE 구현 (self/main.hexa · HEXA_SAME_TU=1, opt-in·reversible).
  - codegen 반쪽: HEXA_SAME_TU=1 → transpile 스텝에 `HEXA_USE_RUNTIME_C=1`(기존 codegen.hexa:947 hatch) → user.c `#include "runtime.c"`.
  - link 반쪽: HEXA_SAME_TU=1 → 별 runtime 2nd TU(`_rt_input`) 제거 → 단일 TU 컴파일. `shared/target` 가드. unset → byte-identical legacy walled. parse-gate PASS.
- [x] 진단한 링크 모델 = §lto-unwall 과 동일: emit user.c=`#include "runtime.h"` + 별 precompiled runtime.o 2nd TU = 벽. (HEXA_PREBUILT / content-hash `.o` 캐시 / source 3분기.)
- [x] BENEFIT 실측(mini · best-of-5): string-boundary 1.87→1.48s(**−21%**) · HexaVal-arith control 0.58→0.44s(**−24%**). 경계호출 `_u_main` 인라인: `_rt_str_starts_with` 2→0 · `_hexa_contains_poly` 1→0 · `_hexa_int` 12→0 · `_hexa_to_string` 1→0 · `_hexa_bool` 2→0. **win 은 string 전용 아님** — HexaVal 박싱 전체 ABI 개방.
- [x] COST 실측: 빌드시간 walled WARM 0.10s(캐시·live default) vs same-TU 3.55s = **~35× 세금** (런타임이 user TU 에 융합 → runtime.o 캐시 구조적 불가). 바이너리 −0.05%(−192 B · wash). 2차 비용 = default-on 은 generated runtime.c 디스크 의존 재도입(B9 graduation 이 지운 것).
- [x] g5 byte-diff IDENTICAL — 양 workload 양 arm 출력 동일(md5 `0e2afa85` · `657d1ec4`).
- [x] 측정 방법 = 정직한 A/B 프록시(스펙 허용): full self-host rebuild 은 B9 벽으로 차단(runtime.c GENERATED) → 두 빌드 모드·동일 runtime.c 소스(B9-faithful pre-graduation 트리 151c52c8, emitter SSOT 와 byte-identical)·TU/link 만 격리. INSTALLED hexat transpile + runtime.h→runtime.c 텍스트 swap(codegen 반쪽과 동일 변환).
- [x] verdict=`.verdicts/unshadow-same-tu/F-UNSHADOW-SAME-TU.txt` · bench=`UNSHADOW.bench.md §same-tu` · 재현=`tool/unshadow_same_tu_bench.hexa`.
- [x] 권고 = **OPT-IN (HEXA_SAME_TU=1), NOT default** — −21~24% byte-identical win 실재·일반화하나 ~35× 빌드세금 + generated-.c 의존 재도입으로 default-on 은 나쁜 트레이드. release/perf 빌드용 opt-in 가치. terminal.
## 2026-05-30T00:00Z — 🏗️ 적층 원칙 문서화 milestone FLIP — 측정 증거표 추가

원칙(🟡 floor 상속 + 🔵 ceiling 적층 + ⛔ runtime.o ABI 벽 + 🔑 LTO/same-TU)은 #2095 에서
이미 easy.md §HEXA-STACK 으로 명문화됨(ASCII 다이어그램 + compare 표). 이번 milestone =
원칙이 **이번 캠페인 누적 실측으로 뒷받침**됨을 확인 + 빠진 조각(consolidated 측정 증거표)을 채움.

- [x] doc 확인 — easy.md §HEXA-STACK 이 4원칙 모두 캡처(floor=clang -O2 상속·ceiling=인라인/atlas-fold/proof-carrying/check-elision 적층·블로커=runtime.o C-ABI 벽·열쇠=LTO/same-TU) 확인. UNSHADOW.md 전제 절도 동일.
- [x] gap 채움 — easy.md §HEXA-STACK 에 "측정 증거" 표 추가: 각 🔵 ceiling 기법 = 측정 win, 각 🟡/벽 한계 = 정직 finding.
  - 🟡 floor 상속: emit-C @-O0→@-O2 1.19×~1.78× · hot-fn instr −44% (parity §parity-attest)
  - 🔵 #2 cross-layer 인라인: ~28% (1.83→1.31s)
  - 🔵 A atlas const-fold: ~65% (0.26→0.09s)
  - 🔵 B proof-carrying: ~47% (0.36→0.19s)
  - 🟢 arena reclaim: peak RSS −40% · wall −26%
  - 🔴 C tag-elision: CLOSED-NEG (clang -O2 가 이미 dead-elim)
  - 🔑 same-TU unwall: FLIP 🔴→WIN −31% (단 `-flto` 불충분) · C bounds/null 은 🔴 NULL(증명 codegen 필요)
  - 🟢 HexaVal 언박싱 = 미측정 **예측 레버**로만 표기(raw 7.9×~1263× 갭 주범 지목, win 주장 금지)
- [x] milestone "🏗️ 적층 원칙 문서화" → `[x]` flip (UNSHADOW.md). doc-only, 측정 0(전부 기존 verdict 인용).

## 2026-05-29T14:45Z — 🏗️ HEXA-STACK 전략 정식화 — B+C 랜딩 + floor/ceiling 적층 프레임

B(#2093)·C(#2094) 두 evidence 브랜치 랜딩 완료 후 UNSHADOW 의 전제를 **HEXA-STACK** 으로 정식화.

- [x] B(#2093) MERGED — proof-carrying 인라인. 검증된 identity(`lambda_eliashberg(M0)≡2·M0`, atlas `verified-lambda_eliashberg-num` 🟢)를 license 로 opaque cross-ABI call 을 layout-only 인라인 치환. g5 byte-diff IDENTICAL · single-eval 증명(calls=1) · 핫루프 0.36→0.19s (**~47% faster**, `bl _lambda_eliashberg` 소거).
- [x] C(#2094) MERGED — unary-plus `+literal` tag-guard 삭제. correctness PROVEN(g5 byte-diff IDENTICAL, md5 `e8060fb1`/`8de57030`) · perf **🔴 CLOSED-NEGATIVE** — clang -O2 가 리터럴-tag guard 를 이미 dead-eliminate.
- [x] 🏗️ HEXA-STACK 프레임 명문화 — 🟡 FLOOR = clang -O2 **상속**(C-emit 경로가 이미 통과, loop-unroll/reg-alloc/SIMD/sched 공짜, 재구현 0; M1 baseline 이 native-asm 5/5 패배 입증) + 🔵 CEILING = hexa 고유 우위(인라인·atlas-fold·proof-carrying·check-elision) **적층**. "LLVM 이기기"가 아니라 "올라타기".
- [x] 🔑 수렴된 ABI-벽 meta-finding — 이번 사이클 두 closed-negative(#2-ext rt_str · C tag-elision)가 **한 블로커로 수렴**: precompiled `runtime.o` 의 C-ABI 경계. 경계 너머로는 clang 최적화(🟡 손실)도 🔵 cross-layer 변환도 불가. B 와 #2(hexa_int)가 통과한 이유 = **layout-only**(경계 안쪽 runtime.h-가시)였기 때문. 열쇠 = LTO/same-TU = `.c=0` 졸업(RUNTIME.flip-floor) → 벽 제거 시 #2-ext·C 가 🔴→win 으로 전환될 것으로 예측 (새 milestone 으로 실측 대기).
- [x] UNSHADOW.md 전제 = HEXA-STACK 재작성 + 3 신규 milestone 추가 (🟡 parity 상속 명문화 · 🔵×🟡 LTO/same-TU unwall 측정 · 🏗️ 적층 원칙 문서화). UNSHADOW.easy.md 에 🏗️ HEXA-STACK 적층 섹션(ASCII 다이어그램 + compare 표) 추가.

## 2026-05-29T14:00Z — 🔵 C refinement-type tag-check elision pilot — 🔵 correctness PROVEN · 🔴 perf CLOSED-NEGATIVE

🟡 reg-alloc 무손실 우회("don't run the check" = prove-then-delete). 타입/흐름 정보가
정적으로 보증하는 런타임 검사를 codegen 이 **삭제**한다. 딱 1건만 실증 (general
flow-analysis framework 아님). host = mini (macOS arm64).

**ELIDED CHECK**: unary-plus `+x` 의 numeric-operand tag-guard (`self/codegen.hexa`
`gen2_expr` UnaryOp arm).
```
base:  ({ HexaVal __upx = (OPERAND); if (!(HX_IS_INT(__upx)||HX_IS_FLOAT(__upx)||HX_TAG(__upx)==TAG_CHAR)) hexa_throw(hexa_str("unary + requires a numeric operand")); __upx; })
new :  (OPERAND)        // only when _is_known_int(operand) || _is_known_float(operand)
```
**STATIC PROOF**: operand 이 IntLit/FloatLit/UnaryOp(-lit) → `HX_IS_INT||HX_IS_FLOAT`
가 정적으로 TRUE → `hexa_throw` arm 은 unreachable dead code. unary `+` 는 numeric
identity → 치환 후 값 == operand 정확히 동일.

**GUARD EXACT (comptime-fold-shadow family 회피)**: `_is_known_int`/`_is_known_float`
(IntLit/FloatLit/immutable-typed Ident 만 certify) 가 참일 때만 elide. 그 외 모든
operand (unknown-tag Ident · Call · Field …) 은 full guard 유지 = general-case zero
change. local let Ident 은 `_is_known_int_name` 의 fn-local-shadow bail 로 보수적으로
elide 안 함 (그 family 의 silent-miscompile 재진입 방지).

**g5 byte-diff (program output md5, base vs new — 동일 runtime.o)**:
- HIT  (`+5`,`+3.5`,`+c`,`+(-7)`, hot-loop `+1`): base=`e8060fb1e37a28301afe3a0d34c9bb08`
  · new=`e8060fb1e37a28301afe3a0d34c9bb08` → **IDENTICAL** · out `5|3.5|10|-7|15000`.
- NO-HIT (`+ident(p)`,`+ident(i)`): base=`8de5703038f59d6723697d1c24baf7fd`
  · new=`8de5703038f59d6723697d1c24baf7fd` → **IDENTICAL** · out `42|499500`.
- emitted-C isolation: HIT 에서 base 는 statement-expr guard, new 는 bare `(((HexaVal)
  {.tag=TAG_INT,.i=(5)}))` (guard DELETED). NO-HIT 의 base/new C 는 **byte-identical**
  (guard kept on opaque operand = inert).

**perf (60M-iter hot loop, `sum += (+1)`, clang -O2)**:

      | arm   | -O2 u_main | bl _hexa_throw | wall (s)  | -O0 throw |
      |-------|-----------|----------------|-----------|-----------|
      | base  | 66 instrs | 0              | ~0.16     | 1         |
      | new   | 66 instrs | 0              | ~0.16     | 0         |

  -O2 에서 **base/new asm IDENTICAL** (66 instr · throw 0개 양쪽) — clang -O2 가
  `{.tag=TAG_INT}` compound literal 에 constant-prop 해서 guard 를 이미 dead-eliminate.
  -O0 에서만 base 에 `hexa_throw` 1개 잔존, new 0개 (소스 elision 가시) — 단 wall
  win 없음 (debug 빌드는 perf 타깃 아님).

**정직한 finding (g5 · roofline)**:
- correctness = **PROVEN** — byte-identical (HIT+NO-HIT), 무손실 elision, elided arm
  은 정적 unreachable. LOSSLESS 원칙 충족.
- perf = **🔴 CLOSED-NEGATIVE** — codegen 이 inline 으로 emit 하는 elidable 검사
  (리터럴-tag guard) 는 **clang -O2 가 이미 fold** → 소스 elision 은 -O2 와 중복(no Δ).
  elision 은 clang-가시 리터럴에서만 fire 하는데 거기가 바로 clang 이 이미 하는 곳.
  진짜 win 이 날 검사(opaque runtime 값의 bounds/null)는 `hexa_array_get` 안 =
  precompiled runtime.o ABI 뒤 → call-site elision 은 runtime.h 내부 매크로(`HX_ARR_LEN`)
  필요 = #2-EXT `rt_str_starts_with` 와 **동일한 ABI 벽**.
- **RULED-OUT AXIS**: 소스레벨 tag-elision 은 inline-가시 검사에서 clang -O2 를 못 이김
  (중복); opaque-value bounds/null 검사는 ABI-walled. 무손실 우회의 perf 여지는
  runtime.h 경계를 넓히지 않는 한 없음.

verdict 원문: `.verdicts/unshadow-C-tag-elision/F-UNSHADOW-C-TAG-ELISION.txt` (verbatim).
bench: `self/bench/unshadow_c_tag_elision_bench.hexa`.

Build note (codegen-change landing recipe · B9): `hexa_cc.c` 는 gitignored generated
artifact → SSOT = `self/codegen.hexa` 한 파일. mini 검증 = fresh worktree 에 main 의
`hexa_cc.c` seed → `hexa cc --regen` (base=origin/main codegen, new=elision codegen)
→ 두 `.new` object 를 설치 `~/.hx/packages/hexa/self/runtime.o` (arm64) 와 clang 링크
→ 2 standalone hexat → corpus DIRECT 트랜스파일 → A/B byte-diff. merged-amalgam
smoke 의 link 실패는 PRE-EXISTING merge-MVP 한계 (DIRECT 경로로 우회).

## 2026-05-29 — #B proof-carrying 최적화 + cross-layer 인라인 — 🔵🟢 g5 IDENTICAL · ~47% faster

UNSHADOW.easy.md §B ("증명-허가"): VERIFIED semantic identity 가 codegen 에게
opaque cross-ABI call 을 proven-equivalent closed form 으로 치환하도록 license.
#4(atlas verdict=license) + #2(layout-only cross-ABI inline) 의 **결합** 1건.
🟡 SIMD 항목의 무손실 🔵 우회 — raw SIMD 재구현 아님.

**The license (proof — 없으면 transform 은 UNSOUND)**: atlas SSOT 노드
`compiler/atlas/embedded.gen.hexa:9196` (VERBATIM):
```
@F verified-lambda_eliashberg-num = lambda_eliashberg(0.5) = 1.0 :: formula [d=2026-05-24 active]
  tier = "🟢 SUPPORTED-NUMERICAL"
  verified-by = "hexa verify --expr lambda_eliashberg 0.5 1.0"
  cite = "TECS-L n6-rep Tier2 — hexa-native libm-class numerical recompute (ε=1e-9)"
```
identity `lambda_eliashberg(M0) ≡ 2·M0` (검증 도메인 M0≥0; guard M0<0→
_NOCALC_F=-999999.0, verify_cli.hexa:1490) 보증. codegen 은 fn body 를 모름 —
오직 atlas verdict 만이 opaque call → closed-form 치환을 허가. LLVM 불가
(precompiled runtime.o symbol · no LTO/cross-TU · theorem DB 부재).
정직 caveat: mini 설치 패키지는 af645e419(stale runtime.h `rt_read_lines`
미선언) 라 verify_cli/atlas_cli rebuild 둘 다 실패 → live `hexa verify` 재실행
미획득. 커밋된 atlas 노드가 persisted verdict(=plan 의 "documented atlas
property" license source). 전체 = `.verdicts/unshadow-B-proof-carrying/F-UNSHADOW-B-PROOF-CARRYING.txt`.

**The transform (self/codegen.hexa, gen2_expr Call→Ident, #4 fold 직후)**:
```
lambda_eliashberg(EXPR)
  → ({ HexaVal __le_x = (EXPR);
       HX_FLOAT(__le_x) < 0.0 ? hexa_float(-999999.0)
                              : ((HexaVal){.tag=TAG_FLOAT,.f=(2.0 * HX_FLOAT(__le_x))}); })
```
layout-only(#2 교훈): runtime.h-가시 심볼만 — TAG_FLOAT(40)·HX_FLOAT(v)=(v).f(156)
·hexa_float(229)·HexaVal{tag;union{double f}}(79). 내부 헬퍼 0(cf. #2-ext
rt_str_*→HX_STRLEN link-fail). GUARD EXACT: name 일치 + `_is_known_fn_global`
+ `!_gen2_has_decl` + arg 1개. canonical top-level fn 정의 시에만 fire(fold-off=
실제 call → byte-comparable). 그 외 모든 호출 통과.

**DOUBLE-EVAL SAFE (#2-ext 교훈 — expr 인자는 let-bind 필수)**: EXPR 를 `__le_x`
로 단 1회 bind, guard+2 multiplicand 에서 3× 읽음. corpus_se.hexa 의
side-effecting 인자 `bump_then(4.0)` → INLINED arm 도 **calls=1** (단일 평가 증명).

**g5 byte-diff (mini macOS arm64; hexat.base vs hexat.new · 동일 runtime.o)**:
- HIT (corpus_B.hexa, expr 인자+음수): `1/3/6.5/-999999/-999999` 양 arm 동일,
  md5 `570eaa6582498425d615c71d83456309` 양쪽 → BYTE-IDENTICAL.
  음수 입력 guard 경로(-999999)도 정확히 보존 = faithful inline.
- single-eval (corpus_se.hexa): base `val=8 calls=1` · new `val=8 calls=1`,
  md5 `d44d54acb80a2420b5b19e51fbd7a5d1` 양쪽 → BYTE-IDENTICAL.
- NO-HIT (corpus_nohit.hexa, global lambda_eliashberg 없음): emit C base vs new
  BYTE-IDENTICAL = transform inert, general-case zero behavior change.

**perf (mini · 30M-iter 핫루프 · clang -O2 · 5 interleaved trials)**:

      | arm  | wall (s, 5 trials)          | best  |
      |------|-----------------------------|-------|
      | base | 0.36 0.36 0.36 0.36 0.36    | 0.36  |
      | new  | 0.19 0.19 0.19 0.20 0.20    | 0.19  |

      Δ ≈ 47% faster · acc=1.8e+08 양 arm 동일. asm(`_u_main` -O2 -S): base 는
      iter 마다 `bl _lambda_eliashberg`, new 는 이를 **소거**(inlined stmt-expr)
      → const-fold 막던 opaque cross-ABI call 제거 = #2 boundary-removal thesis.

Honesty (roofline · g5): REAL win. fold-on 은 opaque call 을 아예 안 함 → clang
이 인라인된 분기를 hot loop 에 직접 펼침. 검증된 identity 가 license 인 "안 돌기"
(🔵) — raw SIMD/벡터 재구현(🟡) 아님. LLVM 비교대상 없음(verdict DB 부재).

Build note (codegen-change landing recipe · B9): SSOT=`self/codegen.hexa` 1파일.
A/B = 동일 origin/main(b639ed090) fresh-clone build tree 에 codegen.base/new 각각
overlay → `hexa cc --regen` → `hexa_cc.c.new` clang → 설치 패키지의 runtime.o/.h
(`f41d5142` 일관 set) 와 링크 → 2 standalone hexat. 두 hexat 의 emit C 만 콜사이트
상이(나머지 동일). /tmp executable reaper 회피 위해 ~/unshadow-B-bin 으로 relink.

## 2026-05-29 — #2 EXTENSION (rt_str_* string prim inline) — 🔴 CLOSED-NEGATIVE (ABI 경계 차단)

#2 hexa_int 인라인을 STRING 런타임 prim 으로 확장 시도. 결론: **rt_str_\* prim 의 body 를
codegen 콜사이트에 인라인하는 것은 `runtime.h` export 경계로 인해 구조적으로 불가** —
publishable closed-negative. milestone flip 없음(확장 로그 only). verdict 원문:
`.verdicts/unshadow-2ext-rt-str-inline/F-UNSHADOW-2EXT-RT-STR-INLINE.txt`.

- [x] prim 선정: `rt_str_starts_with` (HexaVal 2-arg · PURE · 비할당 · LIVE). 후보 조사에서 발견한 함정:
      `str_len` free-fn 경로는 dead — `cg_rt_target()=="c"` 라 `rt_str_len_v`/`rt_str_*` 분기는 도달 불가이고,
      `str_len` 빌트인은 `hexa_str_len(HexaVal)`(컴파일 불가) 를 emit하는 latent 버그 경로. 실제 작동하는
      문자열-길이 경로는 `.len()` → `hexa_int(hexa_len(...))` 로 **이미** 직접 export 콜(추가 인라인 여지 없음).
- [x] codegen 구현: 3개 `.starts_with()` 콜사이트(self/codegen.hexa) 를 GCC statement-expression 인라인으로 교체.
      DOUBLE-EVAL 가드 적용 — 두 인자 모두 `__sw_s`/`__sw_p` 로 **단 한 번** let-bind (expr 인자라 필수).
- [x] g5 격리 byte-diff: base vs inline emitted C 가 **콜사이트 라인만** 상이(나머지 byte-identical). verbatim:
      `< ...rt_str_starts_with(__hexa_sl_0, __hexa_sl_1)...`
      `> ...({ HexaVal __sw_s = (__hexa_sl_0), __sw_p = (__hexa_sl_1); (!HX_IS_STR(__sw_s)||!HX_IS_STR(__sw_p))?0:(hxlcl_strncmp(HX_STR(__sw_s),HX_STR(__sw_p),HX_STRLEN(__sw_p))==0); })...`
- [x] single-eval 가드 검증: emitted C 에서 각 인자가 정확히 1회 let-bind 됨이 육안 확인. BASE single-eval 레퍼런스
      `make_str().starts_with("hello")` → `calls=1`. 가드 **설계는 정상** — 반증은 가드가 아니라 링크 경계.
- [x] **THE WALL** (반증): inline arm 링크 실패 — `Undefined symbols: "_HX_STRLEN", referenced from _u_main` (x8).
      근본원인: `grep -c "HX_STRLEN|hxlcl_strncmp" self/runtime.h` = **0**. runtime.h 는 `<string.h>` 도 미포함,
      HexaVal-레벨 ABI 함수만 export(`rt_str_starts_with` 자체는 runtime.h:257 export). `HX_IS_STR`/`HX_STR` 는
      export 되지만 `HX_STRLEN`/`hxlcl_strncmp` 는 runtime.c amalgam 내부에만 존재 → emitted 프로그램에서 참조 불가.
- [x] **정직한 finding (ruled-out axis)**: hexa_int 가 성공한 이유 = box-literal `((HexaVal){.tag=TAG_INT,.i=N})`
      이 runtime.h-가시 struct 레이아웃 + 리터럴만 사용(내부 헬퍼 0). 모든 의미있는 rt_str_\* body 는 내부 스칼라
      헬퍼(HX_STRLEN/strncmp)를 건드려 순수-레이아웃 인라인 형태가 없음. 인라인하려면 (a) runtime.h 에 내부
      헬퍼 export(=UNSHADOW 가 없애려는 경계를 도로 넓힘) 또는 (b) 전역 emit 프리앰블에 `#include <string.h>`
      추가(콜사이트 surgical 인라인 아님 + strncmp/strlen 매크로-shadow 충돌 재유발) 필요. 둘 다 스코프 밖 → CLOSED.
- [x] 정확성 우선: silent miscompile 위험 회피 위해 codegen 변경 **revert**(인라인은 `_HX_STRLEN` 미정의로 빌드 자체 실패).
      bench/log/verdict 만 commit. UNSHADOW.md cross-layer milestone **미변경**(extension).
## 2026-05-29T12:59Z — #4 atlas-guided const-fold pilot — 🔵🟢 g5 IDENTICAL · ~65% faster

UNSHADOW.easy.md §A ("루프/호출을 안 돌기"): codegen 이 PURE·atlas-검증
fn 을 모든 인자 리터럴로 호출하는 것을 보면, 런타임 call 대신 atlas 가
보증한 리터럴 결과를 **직접 emit** 한다. LLVM 은 theorem/verdict DB 가
없어 구조적으로 불가능한 최적화. 좁게 **딱 1건**만 실증 (general fold
framework 아님).

**Pilot fn**: `beenet_grid_bins(ω_max, Δω) = floor(ω_max/Δω)+1`
(RTSC d7 α²F grid bin 수 · verify_cli.hexa:1500 `_beenet_grid_bins`).

**Atlas verdict (g5 · @D h_verify_auto_absorb · VERBATIM)**:
```
verify --expr beenet_grid_bins(100.0,10.0)=11.0
  calc   = 11.0  ≈ expected 11.0  (|Δ|=0.0 ≤ ε=1e-9)
  tier   = 🟢 SUPPORTED-NUMERICAL  (hexa-native libm-class recompute, TECS-L n6-rep Tier2)
  absorb = · already in atlas — idempotent skip (default · @D g69)
```
(`hexa verify --expr beenet_grid_bins 100.0 10.0 11` · 로컬 prebuilt
`bin/hexa-verify` 2026-05-29.)

**Codegen fold (self/codegen.hexa, gen2_expr Call → Ident 분기 최상단)**:
```
if name == "beenet_grid_bins" && _is_known_fn_global(name)
    && !_gen2_has_decl(name) && len(node.args) == 2 {
    let _fa0 = node.args[0]; let _fa1 = node.args[1]
    if _fa0.kind == "FloatLit" && _fa1.kind == "FloatLit"
        && _fa0.value == "100.0" && _fa1.value == "10.0" {
        return "hexa_int(11)"   // atlas-verified literal — skip the call
    }
}
```
GUARD 가 EXACT (comptime-fold-shadow family 회피): (a) 이름 정확히
일치, (b) top-level fn 으로 해석 (`_is_known_fn_global` — fold-off=실제
user call → byte 비교 가능), (c) 인자 정확히 2개, (d) 둘 다 FloatLit 이고
소스 토큰이 검증쌍 `"100.0"`/`"10.0"` 와 정확히 일치. 그 외 모든 호출
(다른 인자·비리터럴 인자·local-let shadow) 은 변경 없이 통과 =
general-case zero behavior change. DOUBLE-EVAL SAFE: 리터럴 인자는
평가되지 않고 호출 전체가 상수로 치환 → double-eval surface 자체가 없음.

**g5 correctness (host=mini macOS arm64; hexat.base vs hexat.new 2개
트랜스파일러 빌드 · 동일 runtime.o 링크)**:
- HIT corpus (`beenet_grid_bins(100.0,10.0)`): base=`11` · new=`11` →
  **BYTE-IDENTICAL** (md5 `166d77ac1b46a1ec38aa35ab7e628ab5` 양쪽).
- NO-HIT corpus (`(50.0,5.0)` · `(200.0,10.0)` · `(var,10.0)`):
  base=`11/21/11` · new=`11/21/11` → **BYTE-IDENTICAL**. emit C 도 두
  arm 이 **완전 동일** = fold 가 비매칭 site 에서 inert (general-case 증거).
- isolation (emit C): HIT `u_main` 에서 base 는
  `beenet_grid_bins(hexa_float(100.0), hexa_float(10.0))` (실제 call),
  new 는 `hexa_int(11)` (folded). 정확히 의도한 치환 1곳만.

**perf (mini · 30M-iter 핫루프 · clang -O2 · 5 interleaved trials)**:

      | arm              | wall (s, 5 trials)          | best  |
      |------------------|-----------------------------|-------|
      | base (real call) | 0.26 0.26 0.26 0.26 0.26    | 0.26  |
      | new  (folded)    | 0.09 0.09 0.09 0.09 0.09    | 0.09  |

      Δ ≈ 65% faster. asm: `u_main` 의 `bl` 호출 13 (base) → 11 (new) —
      핫루프에서 `beenet_grid_bins` call + arena/box call 2개 소거.
      sum 출력 `330000000` (=11×30M) 양 arm 동일.

Honesty (roofline · g5): REAL win. fold-on 은 호출을 아예 안 함 → clang
이 상수 `11` 을 루프 밖으로 hoist. 이것이 UNSHADOW §A 가 예측한
"루프를 빨리 돌기(🟡)" 가 아니라 "루프를 안 돌기(🔵)" — 검증된
closed-form/리터럴 치환. LLVM 비교대상 없음 (theorem DB 부재).

Build note (codegen-change landing recipe · B9):
- `hexa_cc.c` 는 B9 generated boot image (`.hexanoport` · gitignored
  `.new`) → commit 대상 아님. SSOT = `self/codegen.hexa` 한 파일만.
- regen 은 `$HEXA_LANG/self/native/hexa_cc.c` 가 존재해야 `resolve_hxroot`
  가 build tree 를 고름 (설치 패키지에서 seed 후 `hexa cc --regen`).
- merged-amalgam smoke 의 link 실패는 PRE-EXISTING merge-MVP 한계
  (concat + main-strip). 검증은 DIRECT 경로: `hexa cc --regen` 의 `.new`
  를 `clang -c` → 설치 `runtime.o` 와 링크 → standalone hexat → corpus
  직접 트랜스파일. base/mine 두 hexat 으로 A/B byte-diff.
- mini 의 `hexa verify` (verify_cli 빌드) 는 `bessel_j0`/`bessel_j1` 가
  math-builtin 으로 codegen Call 분기에 미배선 → dup-symbol/undeclared
  로 clang 실패 (별개 pre-existing codegen gap). verdict 는 로컬
  prebuilt `bin/hexa-verify` 로 획득 (값은 atlas 에 이미 존재 · idempotent).
## 2026-05-29T02:00Z — #3 arena-reclaim 측정 (UNSHADOW item #3) — 🟢 MEASURED Δ (RSS −40% · wall −26%)

워크로드 = `self/bench/arena_reclaim_bench.hexa` (+ `bench_str` 순수 string churn 변형).
leaf fn `churn(seed)` 가 호출마다 64 transient concat string 을 만들고 int 만 반환 — 전부 dead.
생성 C 에서 `__hexa_fn_arena_enter()`/`__hexa_fn_arena_return(acc)` emit 확인.

- [x] **scope 확인**: 새 allocator 안 만듦. 기존 region-reclaim opt-in 측정 = `HEXA_VAL_ARENA`(per-fn scope rewind, default ON · `runtime_core_emit.hexa` L3831/L3933/L3755) + `HEXA_STR_ARENA`(bump concat, default ON). 별도 dormant opt-in `__HEXA_ARENA_RETURN_REGION_ON__`(region returns) 는 static int=0, env 미배선 = 휴면.
- [x] **peak RSS (주, N=400k, `/usr/bin/time -l`, raw 바이너리)**: VAL=1·STR=def **3.73GB** (−39.7%) · VAL=0·STR=1 4.97GB · STR=0 6.19GB · fully-off 6.19GB.
- [x] **wall (부, best-of-3 real)**: default 9.24s (−26.4%) · VAL=0 11.08s · VAL=1·STR=0 11.73s · fully-off 12.56s.
- [x] **scaling**: peak RSS 가 N 에 정확히 선형 (100k/200k/400k = 1×/2×/4×, 두 모드 모두) · arena-ON/OFF 비 ≈ 0.75 고정.
- [x] **g5 byte-diff**: 4 config (VAL∈{0,1}×STR∈{0,1}) stdout 전부 IDENTICAL (`total=347288960`). VERDICT verbatim = `IDENTICAL across all 4 reclaim configs`.
- [x] **정직한 finding**: reclaim 은 real win (RSS −40% + wall −26%, byte-clean) 이지만 peak RSS 를 *bound* 하지 못함 — 세 config 다 N 에 선형. rewind 가 빈 블록을 재사용은 하되 OS 반납 안 함(블록 free 경로 부재, `hexa_arena_destroy` 미정의) + leaf 반환 후 살아남는 string retention 경로 잔존 시사. constant-factor win 이지 size-class 닫힘 아님.
- [x] **분리한 blocker (후속)**: peak RSS bound = (a) rewind 시 빈 trailing 블록 OS 반납 opt-in(`HEXA_ARENA_RELEASE_BLOCKS` 류, 미배선) + (b) string retention 추적. 둘 다 runtime emitter 변경 + self-host 2-바이너리 A/B 재빌드 요구 → 본 milestone(기존 opt-in 측정) 범위 밖. 플랜의 "force 하지 말고 blocker 분리" 지침 적용.
- [x] 결과 fold: `UNSHADOW.bench.md` §arena-reclaim 신규 표(knob matrix · wall · scaling · byte-diff · 해석). milestone #3 flip (`UNSHADOW.md`) — 다른 milestone 줄 미변경(sibling 브랜치 충돌 회피).

## 2026-05-29T00:00Z — M1 harness

- [x] A/B micro-bench 측정대 실측 완료 — `mini` (macOS arm64) 단일 호스트, 두 arm back-to-back.
- [x] arm A = `HEXA_BACKEND=native` (aprime_cc → arm64 asm) · arm B = clang -O2 (기본 C 경로) · 둘 다 동일 `self/runtime.c` 링크.
- [x] g5 정확성 게이트: 5/5 워크로드 stdout byte-diff = **IDENTICAL** (native asm 정수 의미론 ≡ clang -O2 C).
- [x] 5/5 측정 (warmup 3 · iters 7 · min_ms 기준): sieve −25.0% · fib −39.0% · hash −61.1% · collatz −10.2% · mixmul −39.6%.
- [x] **정직한 finding**: native backend 는 정확성 PASS, 속도는 5/5 전부 clang -O2 에 진다. scalar/integer hot loop 에서 clang -O2 는 roofline 근접 — 예상된 baseline, 함정 아님. 분기-bound(collatz) 일수록 격차 최소(−10.2%) = 향후 추월 단서.
- [x] 결과 fold: `UNSHADOW.bench.md` §baseline 표 + §정직한 해석 채움. 원시 JSONL verbatim 보존(mini `state/perf/unshadow_ab.jsonl`).
- [x] M1 milestone flip (`UNSHADOW.md`). cross-layer 인라인 milestone 은 sibling 브랜치 소유 — 미변경.

## 2026-05-29 — #2 cross-layer inline pilot (hexa_int integer-literal box) — 🟢 MEASURED Δ ≈ 28%

Pilot prim: `hexa_int(N)` — the small-int box (highest-frequency runtime primitive;
emitted for every integer literal). One-line codegen change in `self/codegen.hexa`
`gen2_expr` IntLit case:

```
- if k == "IntLit" { return "hexa_int(" + node.value + ")" }
+ if k == "IntLit" { return "((HexaVal){.tag=TAG_INT,.i=(" + node.value + ")})" }
```

Lowers an integer literal to a C compound literal instead of an out-of-line
`hexa_int()` call across the precompiled-runtime.o C-ABI boundary. DOUBLE-EVAL
SAFE: `node.value` is a pure literal token (never a side-effecting expression),
so the single textual expansion is the only evaluation — no fold-shadow /
double-eval class reintroduced. Byte-equivalent to runtime.c hexa_int(), which
returns exactly `{ .tag = TAG_INT, .i = n }`. No 4-surface registration needed
(no new builtin — pure inlining of an existing lowering).

- [x] correctness (g5): corpus (fib/while/array/arith) — base `hexa_int(N)` arm vs
      inlined arm → program output BYTE-IDENTICAL, same md5 `5dd08ae3b866d834b822eea5d28c0ffa`.
- [x] isolation: hexat_base vs hexat_mine emitted C on the corpus AND on codegen.hexa
      itself differs ONLY at IntLit sites (the sole non-IntLit diff lines are `}` rows
      shifted by the multi-token expansion = context noise, identical content).
- [x] determinism (fixpoint): hexat_mine ∘ codegen.hexa run twice → byte-identical.
- [x] perf (host=pool mini, macOS arm64; 1M-iter hot loop × 200 rounds + 3 warmup;
      clang -O2 compile-then-link vs SAME runtime.o; 5 interleaved trials):

      | arm                | wall (s, 5 trials)            | best  |
      |--------------------|-------------------------------|-------|
      | base (hexa_int)    | 1.83 1.84 1.83 1.83 1.83      | 1.83  |
      | mine (inlined)     | 1.31 1.32 1.31 1.31 1.27      | 1.27  |

      Δ ≈ 28% faster. Assembly (`-O2 -S`) hot() loop: `bl _hexa_int` call
      instructions 13 (base) → 5 (mine); whole file 23 → 8. The opaque C-ABI call
      blocked clang's const-fold; inlining the compound literal unblocked it.

Honesty (roofline): a REAL win, not a manufactured one. NOT redundant-vs-LTO — the
runtime is a precompiled `runtime.o` (no LTO / no cross-TU visibility), so
`hexa_int` was a genuine opaque out-of-line call. NOT bandwidth-bound — the
workload is call-overhead + box-construction bound, exactly the boundary the
UNSHADOW thesis predicts ownership unlocks. The win is the boundary removal
enabling const-fold, per UNSHADOW.easy.md.

Build note: `hexa_cc.c` is now a B9 generated artifact (`hexa_cc.c.hexanoport`
+ gitignored `.new`), NOT a committed file — the `.hexa` emitter is the only
SSOT to commit. Regen pipeline `hexa cc --regen` requires `$HEXA_LANG/self/native/
hexa_cc.c` to exist for `resolve_hxroot()` to pick the build tree (seed it from the
installed package first). The merged-smoke `compiled=no` is a PRE-EXISTING merge MVP
limitation (baseline shows it too) — verification used the DIRECT compile-then-link
path against the build tree's `.new`, not the merged smoke.

---

## 🔵×🟡 LTO/same-TU unwall 측정 — runtime.o ABI 벽 제거 (2026-05-30, mini macOS arm64)

THE ROI gate the UNSHADOW campaign pointed to. 이번 사이클 두 closed-negative
(#2-ext rt_str inline · C bounds/null tag-elision)가 수렴한 **단일 블로커 =
precompiled `runtime.o` C-ABI 벽**을 제거(LTO 또는 same-TU)하면 둘이 🔴→win 으로
뒤집히는지 실측. SSOT 도구 = `tool/unshadow_lto_unwall_bench.hexa` (parse-gate PASS ·
compiled-build PASS · run PASS on mini). verdict = `.verdicts/unshadow-lto-unwall/`.

### 진단 — 링크 모델 (= 벽, 졸업 후에도 살아있음)

emit 된 user.c 는 `#include "runtime.h"` (codegen.hexa:948) 하고, 최종 링크는 **별도
precompiled runtime 오브젝트를 2nd TU 로** 소비한다 (`self/main.hexa` cmd_build ~L3009–3041):
(1) `HEXA_PREBUILT_RUNTIME` set → 미리 빌드된 `runtime.o`/`.a` 직접 링크,
(2) **기본 (HOME 존재) → content-hash 캐시 `clang -O2 -c runtime.c -o runtime.<sha>.o` →
그 오브젝트 링크 (현 라이브 기본 = 벽)**, (3) 첫 빌드/no HOME/--shared/cross → `runtime.c`
소스를 2nd source 로 동일 clang 호출(그래도 별 TU; -flto 없음). `runtime.h` 는 HexaVal-
레벨 ABI 만 export — 진짜 인라인이 필요로 하는 내부 헬퍼 `HX_STRLEN`·`hxlcl_strncmp`·
`HX_ARR_LEN` 은 **runtime.c 아말감 안에만** 정의(`runtime.c:1211 #include "runtime_core.c"`,
emit=`runtime_core_emit.hexa:763/1090`). 졸업 후 `self/runtime.c` 는 repo 에 부재(B9 generated);
영속 산출물은 precompiled `runtime.o` 뿐 — **벽은 구조적으로 살아있다.**

### unwall 방법 (cheapest-first) — ① `-flto` 불충분, ② same-TU 가 열쇠

- **① `-flto`** (inline_walled.c + runtime.o 링크): **STILL FAIL** — `hxlcl_strncmp`/
  `HX_STRLEN` undeclared 가 **컴파일-타임**에 터짐. LTO 는 링크-타임 최적화라 user.c 가
  컴파일조차 안 되면 발화 못 한다. textual-helper 클래스(#2-ext)에 ① 은 **불충분**.
- **② same-TU** (emit user.c=`#include "runtime.c"`): 아말감이 textual scope 에 들어와
  `HX_STRLEN`/`hxlcl_strncmp`/`HX_ARR_LEN` 가시 → #2-ext 인라인 **LINK OK**.

### 측정 (best-of-5 wall, 두 arm back-to-back, mini)

**#2-ext** (60M-iter × 3 call-site, g5 byte-diff):

| arm | built (링크) | 출력 md5 | wall (s) |
|---|---|---|---|
| base_walled (runtime.o, out-of-line) | yes | `f869400e…` | 0.36 |
| inline_walled (runtime.h + 인라인 본문) | **no (LINK FAIL)** | — | — |
| inline_lto (+ `-flto`) | **no (STILL FAIL)** | — | — |
| base_samtu (runtime.c, out-of-line) | yes | `f869400e…` | **0.25** |
| inline_samtu (runtime.c, 인라인) | yes | `f869400e…` | **0.25** |

asm (60M-iter, `-O2 -S`): base_walled `bl _rt_str_starts_with`=3 → same-TU=1
(`bl _hxlcl_strncmp`=9, clang 가 본문 인라인+언롤).

**C — hexa_array_get bounds elision** (idx 구조적 `[0,len)`, 2M×256):

| arm | built | 출력 md5 | wall (s) | bounds-check 잔존? |
|---|---|---|---|---|
| cbase_walled (runtime.o) | yes | `fda59d53…` | 0.73 | (벽 안) |
| csamtu (runtime.c, same-TU) | yes | `fda59d53…` | 0.72 | **yes** (`bl _hexa_throw`=1·oob-string×2) |

same-TU 에서도 main-region `bl _hexa_array_get`=1 (양쪽 동일) — fn 이 너무 커서 clang 이
루프에 인라인 안 함 → 인라인 0, elision 0, Δ 0.

### 정직한 verdict — #2-ext FLIP (same-TU), C NULL

- **#2-ext = 🔵×🟡 FLIPPED 🔴→WIN** by same-TU unwall: 0.36→0.25s = **−31%**,
  byte-identical(md5 `f869400e`). 단 결정적 Δ 는 same-TU **컴파일 자체**에서 온다 —
  clang -O2 가 런타임 본문을 보고 `rt_str_starts_with` 를 스스로 cross-TU 인라인/언롤
  (`bl` 3→1). codegen 의 맞춤 INLINE emit(inline_samtu)은 same-TU out-of-line call 대비
  **추가 win 0** (0.25=0.25, asm 동일). 즉 #2-ext 의 블로커(링크 벽)는 실재하고 same-TU 가
  제거하지만, 가치는 경계가 열리면 clang -O2 의 cross-TU 인라이너가 따낸다 — 맞춤 인라인은
  unwall 후 redundant. `-flto` 는 이 클래스에 불충분.
- **C = 🔵 correctness lossless · 🔴 perf NULL.** 벽을 없애고 `hexa_array_get` 본문이 다
  보여도 clang -O2 는 opaque bounds check 를 elide 안 한다(throw+oob-string 잔존, Δ 0).
  clang 은 push-된 배열에 `i < HX_ARR_LEN(arr)` 를 증명 못 함(`hexa_array_push` realloc 가능).
  진짜 bounds-elision win 은 **🔵 proof-carrying CODEGEN 변환**(index in-range 증명 시
  bounds-free get emit)을 요구 — deferred 🔵 축이며 unwall 단독으로 안 열린다. **valid null**.

**한 줄**: same-TU unwall 이 #2-ext 를 −31% 로 FLIP(byte-identical)하지만 그 win 은 clang -O2
의 것(맞춤 인라인 redundant); `-flto` 는 불충분; C bounds elision 은 unwall 만으로는 NULL
(proof-carrying codegen 이 진짜 열쇠). 캠페인의 thesis "졸업해야 막혔던 최적화를 할 수 있다"
는 #2-ext 에서 입증되고, C 에서는 "벽 제거는 필요조건일 뿐 — 🔵 codegen 변환이 추가로 필요"
로 정직하게 좁혀졌다.

> caveat: 단일 호스트(mini) 단일 세션 · wall = best-of-5 real · 측정대는 설치 toolchain 의
> `runtime.h`/`runtime.c`/`runtime.o` 사용 · 재현 = `tool/unshadow_lto_unwall_bench.hexa`.
## 2026-05-30 · 🟡 parity 상속 명문화 (measurement + doc, NO codegen change)

milestone `🟡 parity 상속 명문화` 실측. HEXA-STACK 🟡 floor 명제 = hexa 의 C-emit
경로가 emit 한 C 를 그대로 `clang -O2` 에 먹이므로(self/main.hexa L3041 final-link
하드코딩) LLVM 최적화 패스를 재구현 0 으로 상속한다. 이 사이클은 그 상속을 **두 축**
으로 측정해 못 박았다. 코드 변경 0 — 측정대(`tool/unshadow_bench.hexa`) + 손수 짠 ref-C
(/tmp, hook 회피) 재사용. host = mini (macOS arm64, clang 21.0.0). 워크로드 3종 =
fib_heavy · hash_heavy · sieve_heavy (M1 스칼라/정수 hot loop).

방법: 워크로드마다 4 바이너리 — (a) idiomatic plain-`long` ref-C @ clang -O2, @ -O0;
(b) hexa emit-C(`build/artifacts/<stem>.c`) @ clang -O2, @ -O0. 둘 다 같은
캐시 `runtime.o` 링크. ref-C 는 repo 밖 `/tmp/unshadow_parity/*.c` 에서만 작성·컴파일
(hexa-native hook 회피, repo 안 `.c` 0개).

- [x] g5 (value): 워크로드마다 ref-C·hexaO2·hexaO0 stdout 3/3 byte-identical (verbatim):
      `fib 614004930000000 / hash 295847716000000 / sieve 1020000` — 세 바이너리 동일.
- [x] 축 1 (LLVM 패스 상속, emit-C O0/O2 같은 TU):
      | workload | hexaO0 ms | hexaO2 ms | O0/O2 speedup |
      |---|---|---|---|
      | fib_heavy   | 1556 | 1263 | 1.23× |
      | hash_heavy  | 2302 | 1295 | 1.78× |
      | sieve_heavy | 266  | 224  | 1.19× |
      → emit-C 에 LLVM 패스가 실제 적용됨(O0 대비 -O2 1.19×~1.78× 빠름). disasm:
      hash_range hot fn instr 155→87 (−44%) at -O2, fast-path `hexa_add`/`hexa_cmp_lt`
      가 runtime.h static-inline 매크로라 clang 이 inline+fold. **"rides clang -O2" 참.**
- [x] 축 2 (raw parity, hexa @-O2 / idiomatic ref-C @-O2):
      | workload | ref-C @-O2 ms | hexa @-O2 ms | ratio |
      |---|---|---|---|
      | fib_heavy   | 1   | 1263 | 1263× |
      | hash_heavy  | 163 | 1295 | 7.9×  |
      | sieve_heavy | 8   | 224  | 28×   |
      → ratio ≈1.0 **아님**. 정직 보고.

정직한 발견 (HONEST): **상속은 참(축 1) · raw parity 는 🔴 NOT free(축 2)**, 원인 =
이미 문서화된 blocker. emit-C 의 모든 정수 op 는 `HexaVal` 경유이고 fast-path 외 분기·
박싱·`hexa_mod` 등은 precompiled `runtime.o` 안의 out-of-line 호출(hash_range O2 에서도
`bl` 17개 잔존). clang 은 이 C-ABI 벽 **너머로** fold/LICM 못 한다. fib 1263× 는
idiomatic ref-C 에서 clang 이 `fib_iter(40)` invariant 를 증명해 바깥 6M 루프를 통째
elide(ref O0 333→O2 1ms) 했기 때문 — hexa emit-C 는 opaque `HexaVal` 반환이라 그 LICM
불가 → 6M 번 전부 실행. 즉 🟡 floor 의 두 얼굴: (a) emit-C **내부** 패스는 공짜 상속
(축 1, 참), (b) **runtime.o 벽 너머** cross-TU 최적화는 상속 안 됨(축 2, 막힘). 이 벽은
`UNSHADOW.md` 전제 blocker(#2-EXT·C tag-elision closed-negative 수렴점)와 동일.
raw parity ≈1.0 은 `.c=0` LTO/same-TU 졸업(RUNTIME.flip-floor) 의존 → 다음 milestone
`🔵×🟡 LTO/same-TU unwall 측정` 가 정확히 그것을 측정한다.

attestation: 🟡 floor = clang -O2 **부분 상속** 확인 — emit-C 내부 패스 재구현 0 상속
(O0→O2 1.19×~1.78× · hot-fn instr −44%), raw parity ratio 는 7.9×~1263×(≠1.0) 로
runtime.o C-ABI 벽이 cross-TU fold/LICM 차단 → parity free 아님, `.c=0` LTO 졸업 의존.
상세 = `UNSHADOW.bench.md §parity-attest`. NO codegen change.

## 2026-05-30 — 🟢 HexaVal 언박싱 / register-pack pilot (MEASURED WIN)

milestone `🟢 HexaVal 언박싱 / register-pack` — 좁은 PILOT 으로 발화·실측.

**unbox 지점 + 정적 증명**: `self/codegen.hexa` STRUCTURAL-2 known-int BinOp fast-path
(L5127). 이 경로는 두 피연산자가 **정적으로 TAG_INT** (IntLit 또는 불변 int-only `let`,
`_is_known_int` 인증)임을 이미 증명한다 → 결과도 정적 TAG_INT. origin/main 은 이 결과를
**out-of-line `hexa_int(…)`** 로 재박싱한다(`runtime.h` 가 `hexa_int` 를 함수 선언으로만
export → -O2 에서 `bl _hexa_int` opaque ABI 호출 = §parity-attest 가 raw 7.9×~1263× 갭
주범으로 지목한 `runtime.o` C-ABI 벽). pilot 은 결과를 **inline C compound literal**
`((HexaVal){.tag=TAG_INT,.i=(…)})` 로 emit → 핫루프 매 산술 step 의 박싱 ABI 호출 제거,
clang -O2 가 누산기를 레지스터에 유지·체인 fold.

**byte-equivalence (정적 증명)**: `self/runtime_core_emit.hexa:1371` —
`HexaVal hexa_int(int64_t n) { return (HexaVal){.tag=TAG_INT, .i=n}; }`. inline literal 은
이 함수 본문과 **글자 그대로 동일**한 값. tag/repr 혼동 0. DOUBLE-EVAL SAFE (l·r 각 1회
전개, 기존 `hexa_int(…)` 형과 동일) · FOLD-SHADOW SAFE (`_is_known_int` 는 불변 int-only
`let`/IntLit 만 인증 — mut/param/rebind 없음). #2 IntLit-inline pilot(L4867)이 이미 동일
construct 의 byte-eq 를 입증함.

**g5 byte-diff IDENTICAL**: faithful C A/B (BEFORE=out-of-line rebox, AFTER=inline literal,
같은 `runtime.o`·clang -O2). known-int 핫루프 워크로드 + ref-C 3-way:
  before/after/ref stdout = `34200003330000000` (전부 동일, md5 `63888b02`).
  asm: hot `mix()` `bl _hexa_int` **17→0** (total bl 19→2). AFTER `mix()` = 순수 레지스터
  arith(`add`/`sub`/`lsl` in x8..x11), HexaVal spill 0.

**측정 (mini macOS arm64 · clang 21.0.0 · best-of-11 wall ms)**:
  ref-C @-O2 = 54 · before(boxed rebox) = 599 · after(inline literal) = 53.
  → unbox speedup = **11.30×** (91.2% wall drop) ·
    parity gap **before 11.09× → after 0.98×** (AT PARITY) ·
    known-int 워크로드의 before-parity 갭 **100% closed**.

**정직 caveat**: 측정은 **faithful C A/B proxy** (두 arm 이 각 codegen variant 의 call-site
emit 을 정확히 미러) — full self-host transpiler rebuild 아님. 이유 = **B9 빌드 벽**
(origin/main HEAD 에 일관된 generated-.c 셋 부재 + 설치 트리 runtime.h ABI skew →
`hexa cc --regen` merge forward-decl 버그·module link skew 로 canonical 재빌드 차단,
메모리 `reference_b9_generated_c_no_checkout_shortcut` 와 정확히 일치). proxy 가 sound 한
근거 = byte-equivalence 가 **runtime 소스에서 증명**됨 + 변경 변수 1개(out-of-line rebox
vs inline literal)만 격리. codegen 편집 자체는 parse-clean + emit 문자열이 AFTER arm 형태와
정확히 일치(구성으로 검증). 갭-클로저 절대값은 known-int 비율이 높은 워크로드 기준 — fib_heavy
류(피연산자가 mut 누산기 → known-int 미발화)는 이 pilot 미적용(별도 mut-accumulator 언박싱
필요). 상세 = `UNSHADOW.bench.md §hexaval-unbox` · verdict = `.verdicts/unshadow-hexaval-unbox/`.


## 🔵 C-class proof-carrying bounds-check elision — WIN (2026-05-30)

milestone "🔵 C-class proof-carrying bounds/null elision" 종결 = WIN. §lto-unwall 이 NULL 로
분리해낸 axis(벽 제거 단독 불충분, CODEGEN 증명 필요)를 실측으로 따냄.

**전제(unwall 진단)**: runtime.o 벽을 없애고 `hexa_index_get` 본문이 다 보여도 clang -O2 는
opaque(realloc-able) 배열의 bounds check 를 elide 못 함. 진짜 win = codegen 이 static fact 로
elision 을 라이선스.

**구현(self/codegen.hexa, +241 / -0)**:
- `_inrange_facts` 스택 + helpers(`_node_is_int_zero`·`_len_call_target_ident`·
  `_name_resized_in_body`·`_inrange_push/pop/_inrange_counter_for`).
- ForStmt range fast-path: `for i in 0..len(arr)` 가 (배타 range · lower=0 리터럴 ·
  upper=`len(arr)`/`arr.len()` bare Ident · body 가 arr resize/reassign·`i` reassign 안 함)
  이면 in-range fact push, loop exit 에 pop.
- Index emit: 그 read `arr[i]` 를 `(HX_IS_ARRAY(arr) ? arr.arr_ptr->items[counter] :
  hexa_index_get(arr, hexa_int(counter)))` 로 emit — bounds+throw 삭제, array-tag guard 1개만
  잔존(untyped codegen, OOB-안전). HexaArr+arr_ptr 가 runtime.h public → runtime.o 벽 관통.

**측정(mini macOS arm64, A/B proxy, best-of-9)**: 256-elem int array hot loop
**1.88→0.56s = 3.25× (−69%)**. g5 byte-diff IDENTICAL(`fda59d53`). asm: arm B inner loop
= 직접 `items[i]` 로드, `bl _hexa_index_get` 은 cold non-array fallback 으로 hoist.

**무결성 게이트 PASS**: `arr[len]` OOB 접근은 양쪽 arm 모두 throw(검증식 안 덮는 read=검사형).
증명-안전한 read 만 삭제 — OOB read 없음.

**정직**: full self-host regen 은 B9 generated-runtime 벽으로 차단(`hexa cc --regen` →
amalgam merge 가 pre-existing 타입에러로 실패, 내 edit 무관) → faithful A/B 프록시(emit 문자열
codegen L7661 과 byte-동일·스펙 허용). 잔존 lever = known-array 추적기(생기면 tag-guard 도 삭제).
verdict=`.verdicts/unshadow-cclass-bounds/` · 재현=`tool/unshadow_cclass_bounds_bench.hexa`.

---

## 🟢 unboxed-primitive array (axis A, typed-repr RFC) — 2026-05-30

§c-class 가 남긴 미측정 lever("known-array 추적기가 생기면 tag-guard 도 삭제")를 측정했다.
**결과 = correctness WIN · perf 🔴 CLOSED-NEGATIVE** — 갭이 tag-guard 가 아니라 **저장 표현**
에 산다는 것을 결정적으로 못 박았다.

**element-kind 증명 + unbox site (self/codegen.hexa).**
- `_is_int_literal_array(node)` — 배열 리터럴 `[1,2,3,…]` 의 모든 원소가 IntLit 인지 (정확·좁은
  monomorphic-i64 증명, Ident·call·float·nesting 전부 거부).
- LetStmt 등록 (`gen2_stmt`, ~L2897): 불변 `let xs=[int-lit…]` → `_known_intarr_add(xs)`.
  AssignStmt LHS Ident 재대입 → `_known_intarr_void` (re-let 비-int-array 도 void). LetMutStmt 제외.
- Index emit (~L7666): `xs[i]` 가 live in-range fact 로 덮이고(`_inrange_counter_for`) `xs` 가
  known-int-array 이면 → §c-class ternary `(HX_IS_ARRAY(xs)?items[i]:checked)` 대신 **direct
  `(xs.arr_ptr->items[ctr])`** (array-tag guard 삭제, array-ness 정적증명).
- `_is_known_int(node)` (~L9981): `node` 가 known-int-array 의 in-range read `arr[i]` 면 true →
  주변 sum/dot BinOp 가 raw `.i` 를 HX_INT 로 추출(원소-당 tag dispatch 0). 두 게이트 모두
  immutable-let 등록 AND live in-range fact 둘 다 요구 → unproven/boxed 접근엔 절대 발화 안 함.

**byte-diff IDENTICAL (g5, mini best-of-9).** 4-arm(ref_c·a_boxed=§c-class·b_unbox=신규·c_native
=ceiling) stdout md5 전부 `35470124…`. **무결성 게이트 PASS**: typed `[i64]` 배열을
polymorphic site(`hexa_len`+checked element fetch)로 흘려보낸 boundary corpus — boxed/unbox
양쪽 arm md5 `9efbbf5d…` 동일. unbox 는 값을 절대 안 바꾸고, typed array 는 동적 경계서 정확히 box.

**perf 🔴 CLOSED-NEGATIVE.** b_unbox 1.12s ≈ a_boxed 1.12s = **~0% Δ**. tag-guard
`HX_IS_ARRAY(arr)?` 는 **loop-invariant** 라 clang -O2 가 이미 hot loop 밖으로 hoist — 삭제해도
(asm `bl _hexa_index_get` 1→0, cold fallback 제거) wall 무변. 진짜 벽 = **boxed 저장**:
`sizeof(HexaVal)=16` → `HexaArr.items[]` 는 16B-stride 박스 배열, clang 이 SIMD-gather 불가
(a_boxed/b_unbox = 5 vec-op). native `int64_t[]`(c_native, 8B contiguous)만 vectorize
(23 vec-op)해 갭 100% close (c_native 0.08s ≈ ref 0.08s). asm=`.verdicts/unshadow-unboxed-array/asm_simd.txt`.

**누락 인프라 (축 ruled-out).** 진짜 native `int64_t[]`/`double[]` 저장 표현(`HexaArrI64`/`F64`)
이 **없다** — `HexaArr` 는 boxed `HexaVal*` 전용. 그건 RUNTIME 변경(새 struct + box/unbox 헬퍼 +
모든 array primitive 가 element-kind 분기)이고 B9 벽 밖·codegen-only pilot 범위 밖. → axis A 가
**"codegen-only unbox(tag-guard 삭제 + boxed `.i` read)는 perf 레버가 아니다"** 를 결정적으로
배제. 갭은 STORAGE 에 산다. paper_negative_ok: 데이터-표현 축 결정적 배제 = valid terminal.

**정직 caveat**: full self-host regen 은 B9 generated-runtime 벽 차단 → faithful A/B 프록시
(b_unbox emit 은 codegen L7666 신규 arm 과 byte-동일·스펙 허용, prior round 들과 동일). 단일
호스트(mini)·best-of-9·양 arm 동일 runtime.o·repo 안 `.c` 0개. codegen 변경은 byte-identical
+ provably-dead guard 삭제(무회귀)라 axis B(monomorphic struct)의 element-kind 증명·box/unbox
경계 규율 기반으로 유지. verdict=`.verdicts/unshadow-unboxed-array/` ·
재현=`tool/unshadow_unboxed_array_bench.hexa`.

## 2026-05-30 — 🪆 거울방 mining cycle — paradigm-axis 채굴 → milestone 등록 (DISCOVERY only)

`/mining`(divergence→convergence) + `/mirror-loop`(거울방 ouroboros) 패러다임을 UNSHADOW 에 적용.
**측정·codegen·cloud 0 — doc/discovery only.** 14/15 milestone 의 모든 closed-negative 가
한 점으로 수렴한다는 메타-발견을 광맥으로 채굴: **경계 = 데이터-표현 주권**(전부 boxed HexaVal).

**DIVERGENCE (5 렌즈 saturate, 24 후보).**
- L1 same-formula: §hexaval-unbox(scalar 박싱제거 11.30×·gap 100% close) 의 동형 — native array(C1)·
  NaN-box(C2)·small-value-opt(C3)·ptr-compress(C4)·intern(C6)·COW(C7)·monomorph(C8).
- L2 dimensional: 14 milestone 전부 time-축 → 공간(C13 escape→stack·C14 region-GC)·startup(C11 AOT-atlas)·
  link(C12 tree-shake)·compile(C9/C10, 🟡) 축 미채굴.
- L3 tension: 동적 HexaVal↔unboxed typed 의 하이브리드 경계(C15) = 모든 표현-축의 공유 규율.
- L4 ouroboros: atlas 자산화 — atlas-PGO(C17)·검증 memo(C18)·rewrite-feedback(C19)·proof-carrying(C20).
- L5 combinatorial: native-array×SIMD(C21→C1 흡수)·NaN-box×region-GC(C22)·monomorph×atlas-PGO(C23→C16).

**CONVERGENCE (3 family).**
- F1 🪆 데이터-표현 주권 — closed-negative 가 수렴한 광맥. C1=축A 가 결정적으로 지목한 그 자리.
- F2 📐 미채굴 perf 축 — 공간/startup/link/compile. C13/C14=🔵 타입구동, C9/C10=🟡 catch-up.
- F3 ♾️ atlas-as-perf-asset / 거울방 — easy §G 의 측정-frontier(지금까지 §A const-fold 1건만).

**RANKING (ROI · lossless-first · tier 정직).** 1)C1 native-array(🔵·headline·갭이 사는 곳) 2)C18 검증
memo(🔵·측정 깔끔) 3)C13 escape→stack(🔵·공간축 첫 채굴) 4)C2 NaN-box(🔵·블라스트 大→후순위)
5)C17 atlas-PGO(🔵). C8 monomorph·C11 AOT-atlas=deferred, C9/C10=🟡 측정-격차-확인-시만.

**MIRROR-ROOM fold.** 채굴 trail → `domains/UNSHADOW.MINING.md`(SSOT·거울 표면). survivor 5건 →
UNSHADOW.md `- [ ]` milestone 등록(14 [x]+B line 무손). 모두 이미-측정 발견 OR LLVM-can't 근거에 묶임,
새 perf 숫자 발명 0. ruled-out(codegen-only unbox 축A🔴·AoS↔SoA-without-typed-repr E🔴) 재제안 안 함.
**next-frontier seed = C1 native HexaArrI64/F64** — 축A 의 closed-negative 가 "갭은 STORAGE 에
산다(codegen-only unbox 아니다)" 를 결정적으로 못 박았으니, 다음 frontier 는 runtime-레벨 native
저장 표현(B9 벽 밖·codegen-only 범위 밖)이다. 거울방 다음 회전의 진입점.

## 2026-05-30 — 🔵 native HexaArrI64 저장 표현 [HEADLINE] (부분 착지 + 천장 실증)

**축A 확증.** §unboxed-array closed-negative 가 "갭은 STORAGE(boxed 16B-stride)에 산다"를
지목 → 이 사이클이 native contiguous `int64_t[]` 표현을 runtime+codegen 에 실착지하고 천장
실증으로 확인.

**착지**: (1) runtime ABI `self/runtime_core_emit.hexa` — `HexaArrI64 {int64_t* data;int len;
int cap}` + `hexa_arr_i64_new/push/len/box` public-in-runtime.h(§c-class 벽 관통, layout=
HexaArr 동offset → polymorphic hexa_len 작동). (2) codegen `self/codegen.hexa` — §unboxed-array
`_known_intarr` 추론기 재사용, `HEXA_NATIVE_ARR=1` GATED opt-in(default OFF) 시 monomorphic-i64
리터럴 → native 구성 + raw inline-literal read. real self-host codegen 발화 검증(transpile
+632 lines: FLAG ON=hexa_arr_i64_new/push, FLAG OFF=boxed 무변경).

**측정(mini arm64 best-of-9·faithful A/B proxy)**: byte-diff 4/4 IDENTICAL(`35470124`)+동적경계
IDENTICAL(`9efbbf5d`). a_boxed 3.17s → b_native(LANDED) 2.68s(1.18×) → d_ideal(CEILING) 0.18s
≈ref 0.15s(**gap→0.83× AT PARITY**). native storage 가 갭을 parity 까지 닫음 = 축A 예측 확증.

**정직 한계**: LANDED 가 천장의 1/15 만 잡음 — read 가 boxed HexaVal surface 유지(누산기 acc=
untyped let mut → §hexaval-unbox 체인이 sum 까지 안 뻗어 per-read box 가 vectorize 차단,
vec-op 8<28). full 천장 = known-int accumulator 일반화(sub-task open). inline literal 필수
(out-of-line hexa_int 더 느림=runtime.o 벽 re-box). GATED opt-in=무회귀. F64+no-escape 자동발화=open.

verdict=`.verdicts/unshadow-native-arr/`·bench=`UNSHADOW.bench.md §native-arr`·재현=
`tool/unshadow_native_arr_bench.hexa`. **next sub-task seed = known-int accumulator(read→sum raw 체인)**.

## 🔵 typed monomorphic struct layout — flat C-struct + offset field access (부분 착지) 2026-05-30

milestone "🔵 typed monomorphic struct layout (flat C-struct typedef + offset field access)"
부분 착지. E(AoS↔SoA) 재오픈 선결 — E closed-negative 가 SoA 불가의 (b)(c) 원인으로 지목한
"struct=`hexa_struct_pack_map` 해시맵·field=`hexa_map_get_ic` strcmp/IC 프로브" 를 제거하는 레버.

**착지물** (`self/codegen.hexa`, GATED `HEXA_TYPED_STRUCT=1` · default OFF=무회귀):
- `_typed_struct_enabled()` 게이트 + `_is_flat_eligible_struct`(monomorphic 증명=declared·비-empty
  닫힌 필드집합) + `_flat_field_index`(정적 필드→슬롯 인덱스) + `_flat_var_add/void/type`(불변
  `let p=Pt{…}`/`Pt(…)` 직접-construction 바인딩 → struct 타입 추적, re-let void).
- `gen2_struct_decl`: flat-eligible → `gen2_flat_struct_typedef` — per-type `typedef struct
  Name__flat { HexaVal f0; HexaVal f1; … }` + positional flat ctor(`HexaVal Name(HexaVal x,…){
  malloc; s->f0=x; …; v.tag=TAG_ARRAY; v.vs=(HexaValStruct*)s; }`). 시그니처는 hash ctor 와
  동일(call site 무변경). flat ptr 이 public HexaVal `vs` union slot 에 타 → runtime.h 무변경.
- Field arm(`:5389`): 정적 flat 수신자(`_flat_var_type` 매칭) + 선언된 필드(`_flat_field_index>=0`)
  → offset 로드 `(((Name__flat*)(recv).vs)->f<idx>)`. else `hexa_map_get_ic` **무변경**(동적-키·
  비-flat 수신자·typo 필드 idx<0 전부 fall-through).

**측정 (mini Apple M4 arm64 · best-of-9 · faithful A/B proxy · full self-host regen=B9 벽 차단·스펙 허용)**:
- g5 byte-diff **3/3 IDENTICAL** (`0f047a3268a6e167334f5a28a80ea668`) — ref_c·a_hashmap·b_flat
  동일 stdout. 무손실.
- 무결성: 동적-키 struct(런타임 결정 키) offset arm 미발화 → `hexa_map_get_ic` hash-map 유지
  (`1dcca233…`, 정확히 5 read). 다형/동적-키 struct 무변경.
- a_hashmap 5.48s → b_flat(LANDED) 0.05s = **109× · −99% · gap 547×→5× AT PARITY**(ref 0.01s).
  asm call+branch 프로브 신호 19→4(hexa_struct_pack_map + 2× hexa_map_get_ic strcmp/IC → offset
  로드, clang loop-invariant fold). 벤치는 per-iter construction 포함이라 109× 는 read+construct 합산.

**LLVM-can't**: 해시맵→offset 재작성은 우리 소유 표현에 대한 타입-레벨 shape 증명. clang 은
`hexa_map_get_ic` 를 runtime.o C-ABI 벽 너머 opaque 호출로만 보아 hash probe 를 load 로 fold 못 함.
flat typedef 는 user.c 안 emit(runtime 무변경) — RFC §codegen-landing 그대로.

**honest scope (착지 슬라이스, over-promise 금지)**:
- 발화 = 불변 직접-construction 바인딩(`let p=Pt{…}`/`Pt(…)`) + 정적 필드 read 만. struct 가
  fn 인자/반환으로 흘러간 수신자(타입 추적 끊김)·mut 재대입·eq/serialize/map-interop polymorphic
  연산·중첩 struct 필드 = **미발화**(hash-map 유지) = open sub-task.
- real self-host codegen 발화 검증(transpile)은 deferred — emit 문자열이 `gen2_flat_struct_typedef`
  + Field arm 과 byte-동일함은 정적 확인(proxy 가 그 문자열을 그대로 모델). full regen=B9 generated-
  runtime 벽 차단(§c-class·§native-arr 와 동일 스펙 허용).
- GATED opt-in(default OFF) = 무회귀 보장.

verdict=`.verdicts/unshadow-typed-struct/typed-struct.txt`·bench=`UNSHADOW.bench.md §typed-struct`·
재현=`HEXA_TYPED_STRUCT=1 tool/unshadow_typed_struct_bench.hexa --rt ~/.hx/packages/hexa/self --runs 9`.
**next sub-task seed = 변수-흐름 typed-struct 추적(fn 인자/반환 수신자) + real self-host transpile 발화검증**.
