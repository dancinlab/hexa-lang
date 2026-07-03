# RFC: default-ON flip census — opt-in 게임-parity 레버 승격 영향·게이트·순서

> **STATUS: CENSUS / RFC ONLY — DEFAULT byte 0변경.** 이 문서는 측정·코드읽기 기반 분석이며,
> 실제 default-ON flip 코드변경과 fixpoint 재수렴 빌드는 **user-go 인가 전까지 수행하지 않는다**
> (릴리스무결성 절대가드 사안). 산출=문서 1개 + CHANGELOG 1줄. 코드 0변경.
> FLEET #2 capstone · 격리 worktree(`rfc/default-on-flip-census`) · mini=git/gh only.

## 0. 배경 — 무엇이 이미 main 에 있나

게임-parity 캠페인(HEXA-UNBOX)에서 측정·배선·머지된 레버들. **HEXA_PACK_ARRAY 는 이미
default-ON 으로 flip 완료**(#4163, 2026-06-28)이며 나머지는 default-OFF opt-in 으로 거주한다.
전부 dead 아님(측정·배선됨).

| 레버 | 현 polarity | 측정 이득 | 변경 표면 |
|------|-------------|-----------|-----------|
| HEXA_PACK_ARRAY | **DEFAULT-ON** (`!= "0"`, #4163) | 9.78× k3_arrmap (#4114) | x86_64 codegen only |
| HEXA_UNBOX_NATIVE | default-OFF (`== "1"`) | k1 2.95× (#4081) · k2/k4 4.48× · k1 2.35× (#4055) | x86_64 codegen only |
| HEXA_IC_STRUCTID | default-OFF (`#ifdef`) | 1.29× hot map field-read (#4122) | **runtime.o only** (codegen 무변경) |
| HEXA_PACK_ESCAPING | default-OFF (`== "1"`) | coverage 레버(단일 speedup 수치 없음·i64+f64) | **codegen 2-backend + runtime.a** |

(참고: HEXA_THREADS 는 emit-byte flip 이 아니라 stdlib/런타임 spawn opt-in 이라 이 fixpoint
승격 census 범위 밖 — `self/atomic_ops.hexa:153` 등 런타임 게이트.)

---

## 1. 레버별 default-ON flip 영향 census (file:line)

### 1.1 HEXA_PACK_ARRAY — 이미 flip 완료 (승격 reference 선례)

flip 3곳 (전부 `== "1"` → `!= "0"`, #4163):
- `compiler/codegen/x86_64_linux.hexa:1486` — `_pack_array_enabled()`
- `compiler/lower/hir_to_mir.hexa:225` — `_arru_native_enabled()` (type-id stamping gate)
- `compiler/lower/hir_to_mir.hexa:277` — `_arrpk_fuse_enabled()` (elem-type threading)

**왜 flip 이 성공했나 (다른 레버 승격의 청사진):**
1. **runtime 의존이 이미 unguarded.** 비-escaping packed descriptor(`hexa_arr_i64_new`/`push`/
   `len`/`get`/`set` + `HexaArrI64` typedef)는 `#ifdef HEXA_PACK_ESCAPING` *이전*에 default
   runtime.a/runtime.h 에 무조건 포함됨 → default-ON codegen 콜이 링크 OK, **runtime.o byte
   무변경**. 즉 실질 flip 은 codegen-only 였다.
2. **x86_64 codegen 전용** — arm64/gen2/nvptx 에 PACK_ARRAY 게이트 부재 → 그 타깃 emit
   byte-identical (게이트가 없으니 flag 값과 무관).
3. **소프트니스 fixpoint** — #4121 transitive alias-coherence fixpoint → escape-stress 9/9
   OFF==ON bit-exact + PACK-ON full-compiler self-emit byte-identical determinism (2 witness).
4. CI byteeq 3타깃 + nvptx + 출하 smoke GREEN 확인 후 머지.

→ fixpoint reconverge 범위: **x86_64 gen3≡gen4 만** 재수렴(컴파일러 자기 emit 이 packed 경로로
바뀜). arm64-linux·darwin-arm64 는 emit 무변경이므로 기존 fixpoint 그대로.

### 1.2 HEXA_UNBOX_NATIVE — 순수 x86_64 codegen, runtime.a 무관

게이트 1곳:
- `compiler/codegen/x86_64_linux.hexa:1332` — `_unbox_native_enabled()` (`== "1"`)
- 소비처: `_x86_binop_unbox_ok()` (x86_64_linux.hexa:1351) — `_unbox_native_enabled() ||
  _pack_fuse_enabled()` 로 진입(후자는 PACK_ARRAY 경유 이미 default-ON).

**flip 시 DEFAULT emit 변화:** provably-int binop(`+ - *` arith + `< <= > >= ==` cmp, r5b 부터
compile-time 양수 상수 `/` `%` magic-reciprocal 포함)이 boxed `call hexa_mul/add/cmp/div/mod`
→ inline native ALU/cmp 로 lowering. **operand/dst 가 정적 i64(type_id==1)로 증명될 때만**
(const_int/const_bool 리터럴 또는 type_id==1 local). 글로벌은 별도 id space → 보수적 boxed.
div-by-zero throw 필요한 비-상수 `/` `%` 는 boxed 유지.

**runtime 의존: 없음.** 순수 codegen — boxed call 을 inline 명령으로 대체할 뿐 runtime.a
심볼/바이트 무변경. **release runtime.a 무손**.

**fixpoint reconverge 범위:** x86_64 gen3≡gen4 만(컴파일러 자기 코드의 정수 binop 이 inline
화). arm64 게이트 부재 → arm64-linux·darwin-arm64 emit byte-identical. 부작용: x86_64 만 빨라지고
arm64 는 boxed 유지(per-target perf 비대칭 — byteeq-safe, 각 타깃 자기 fixpoint 만 재수렴).

### 1.3 HEXA_IC_STRUCTID — 순수 runtime.o, codegen 무변경

게이트: 런타임 C 매크로 `#ifdef HEXA_IC_STRUCTID` 만 — **compiler/ 전역에 0개**(grep 확인).
- `self/runtime_core_emit.hexa` — 7+ 블록(line 1186/1271/3347/3385/4013/4040 …): `HexaMapTable`
  + `HexaIC` 에 `uint32_t struct_id` 필드, `hmap_alloc_ex` 의 monotonic per-table 카운터,
  IC 비교를 2-word(order_keys ptr+len) → single uint32 비교로 collapse.
- `self/runtime.h:72/76/149/152/782/792` — 동일 ABI 미러(precompiled-runtime.o 경로).

**flip 시 변화:** emitted runtime_core.c(→ runtime.o/runtime.a)만 바뀜. `HexaMapTable`/`HexaIC`
에 4바이트 struct_id 필드 추가(ABI 변화) + shape-check 명령 1개로 축약. **codegen emit
byte-identical**(컴파일러는 같은 콜을 emit, 런타임 구현만 바뀜).

**fixpoint reconverge 범위:** codegen gen3≡gen4 **재수렴 불필요**(컴파일러 emit 무변경) —
runtime.o byte 만 변하고 frozen runtime 재생성(regen)이 필요. #4122 측정: cpp -E flag
UNDEFINED → regenerated runtime_core.c main 과 byte-identical(7609L diff clean), DEFAULT
shim/runtime sha invariant. flip = `#ifdef` 를 무조건화(또는 default define)하는 runtime-side
변경.

### 1.4 HEXA_PACK_ESCAPING — codegen 2-backend + runtime.a (최중량)

게이트 4곳(2 backend + 2 lower):
- `compiler/codegen/x86_64_linux.hexa:1516` — `_pack_escaping_enabled()` (`== "1"`)
- `compiler/codegen/arm64_darwin.hexa:386` — `_arm_pack_escaping_enabled()` (`== "1"`)
- `compiler/lower/hir_to_mir.hexa:226` — `_arru_native_enabled()` OR-clause
- `compiler/lower/hir_to_mir.hexa:277` — `_arrpk_fuse_enabled()` OR-clause

런타임 의존(**결정적 차이점**): `self/runtime_core_emit.hexa` 의 7 `#ifdef HEXA_PACK_ESCAPING`
블록 — `TAG_ARRAY_I64`/`TAG_ARRAY_F64` enum, `hexa_arr_i64_new_esc`/`hexa_arr_f64_new_esc`,
`hexa_arr_poly_{len,get,set,push}` (i64+f64 분기) 가 전부 default runtime.a 에서 **#ifdef 로
제외됨**. 즉 codegen 만 default-ON 으로 flip 하면 default runtime.a 에 poly readers 부재 →
**undefined reference hexa_arr_poly_\* 링크 실패**.

→ **flip prerequisite**: PACK_ARRAY 선례처럼 런타임 poly readers 를 *먼저 unguard*(default
runtime.a 에 무조건 포함)해야 함. 그건 단순 polarity flip 이 아니라 runtime 재설계 + TAG enum
변경(이미 TRUE-LAST append 라 기존값 무shift — #4151 교훈 적용됨) + frozen runtime re-baseline.

**fixpoint reconverge 범위:** codegen x86_64 **AND** arm64(darwin+linux) gen3≡gen4 둘 다 재수렴
+ runtime.a 3타깃 byteeq + frozen 재생성. 단일 perf 수치 없음(escaping 배열 coverage/정확성
레버이지 측정된 speedup 레버 아님).

---

## 2. 레버 상호작용 (overlap census)

- **PACK_ARRAY ↔ PACK_ESCAPING (elem-type stamping 공유):** `hir_to_mir.hexa:225` 의
  `_arru_native_enabled()` 와 `:277` 의 `_arrpk_fuse_enabled()` 는 typed-prim elem-kind
  (type_id 101..104) 스탬핑을 PACK_ARRAY(`!= "0"`, 이미 ON) **또는** PACK_ESCAPING(`== "1"`)
  로 게이트. PACK_ARRAY 가 이미 default-ON 이라 **스탬핑 패스는 이미 매빌드 실행 중** → 컨테이너
  Local 의 type_id 101..104 가 이미 codegen 에 도달. PACK_ESCAPING 를 추가 flip 해도 스탬핑은
  중복 활성(emit-neutral) — esc-mint/poly-route 결정만 codegen 게이트(`:1516`/`:386`)가 추가
  발화. 따라서 PACK_ESCAPING flip 의 lower-side 증분은 0(이미 PACK_ARRAY 가 켰음), codegen+런타임
  side 만 증분.
- **UNBOX_NATIVE ↔ PACK_ARRAY (native-ALU 경로 공유):** `_x86_binop_unbox_ok()`
  (x86_64_linux.hexa:1358)는 `_unbox_native_enabled() || _pack_fuse_enabled()` 로 진입.
  PACK_ARRAY default-ON 으로 `_pack_fuse_enabled()` 가 이미 켜져 packed [i64] element 의
  provably-int binop 은 *이미* native-ALU 직결(boxed call 제거). UNBOX_NATIVE flip 의 증분 =
  **packed-array 경로 밖의** 스칼라 i64 binop(literal/typed local)까지 inline 확장. 두 레버는
  같은 operand/dst 증명·같은 inline emit 을 공유(주석 RECON-2) — 게이트만 넓어짐. 회귀 위험
  공유 표면.
- **IC_STRUCTID:** 독립(map IC runtime 전용) — 다른 3 레버와 코드 표면 겹침 없음.

---

## 3. 측정 재확인 (빌드 없이 changelog/코드 기반)

| 레버 | 측정 출처 | 수치 | reference-match |
|------|-----------|------|------------------|
| PACK_ARRAY | #4114 → #4163 | 9.78× k3_arrmap (raw-8B ⊕ r2c index-unbox ⊕ R5b/r6 scalar-unbox) | V8 PACKED_SMI element-kind |
| UNBOX_NATIVE | #4081 r6 | 2.95× k1 (let-bound-literal const-prop, % M magic) | gcc magic-reciprocal |
| UNBOX_NATIVE | #4055 R5b | 2.35× k1 · 4.48× k2/k4 | — |
| IC_STRUCTID | #4122 | 1.29× (~22%) hot monomorphic field-read, 400M-iter taskset median-9 OFF 0.63s→ON 0.49s | JSC get_by_id (cmp $id; jnz slow) |
| PACK_ESCAPING | #4143/#4151/f64 | escaping [i64]+[f64] worker-buf packed (correctness/coverage, no single speedup) | V8 elements-kind dispatch |

측정은 전부 `tool/measure_codegen_perf.sh` isolated alternating median-7/9(back-to-back ratio
오염 회피 — root-cause ⓓ #4080). **실측 fixpoint 재수렴 빌드는 이 RFC 에서 수행하지 않음**(아래
user-go 게이트 참조).

---

## 4. 승격 순서 권고 (byteeq 리스크 / 이득 / 되돌림 ranking)

reference: rustc edition flip(opt-in→새 edition 까지 default 안 바꿈) · gcc `-O2` default 승격
(증명된 정확성 + 측정 후에만). 정석 = **비가역 표면이 가장 작은 것부터, 측정 이득이 명확한 것**.

| 순위 | 레버 | byteeq 리스크 | 이득 | 되돌림 | 권고 |
|------|------|---------------|------|--------|------|
| **(완료)** | PACK_ARRAY | x86_64 codegen fixpoint (재수렴됨, 3타깃 GREEN) | 9.78× | 1줄 polarity | ✅ #4163 머지됨 (선례) |
| **1st** | UNBOX_NATIVE | x86_64 codegen fixpoint 만 · **runtime.a 무손** · arm64 no-op · 강한 provably-int 게이트 + Gate-4 output parity | 2.35~4.48× (큼) | 1줄 `==1`→`!=0`, ABI 표면 0 | **다음 flip 권고** |
| 2nd | IC_STRUCTID | **codegen fixpoint 재수렴 불필요** · runtime.o byte 만 변경 + ABI 필드 추가 | 1.29× (clean) | `#ifdef` 무조건화 | UNBOX 후 또는 병행(독립 표면) |
| 3rd / blocked | PACK_ESCAPING | **codegen 2-backend + runtime.a #ifdef unguard prerequisite + frozen re-baseline** | coverage(speedup 미측정) | flip 전 runtime 재설계 필요 | **현 시점 부적격** — 런타임 unguard + 측정 선행 필요 |

**근거 요약:**
- **UNBOX_NATIVE 1순위:** 릴리스무결성 절대가드(`hexa`/runtime.a 출하경로 보호)에 가장 안전 —
  runtime.a 를 전혀 안 건드림(순수 컴파일러 emit). 가장 큰 측정 이득. 소프트니스 가장 강함
  (operand/dst 정적 i64 증명 + Gate-4 출력 parity). x86_64-only 라 arm64 byteeq 는 자명히 통과
  (게이트 부재). 되돌림 = 한 줄, ABI 표면 0. PACK_ARRAY 선례와 동일 클래스(codegen-only flip).
- **IC_STRUCTID 2순위(또는 UNBOX 와 병행 가능 — 독립 표면):** codegen fixpoint 재수렴이 아예
  불필요(컴파일러 emit 불변)한 유일한 레버라 그 축에선 가장 저위험. 단 release runtime.a 바이트가
  변하고 HexaMapTable/HexaIC 에 4바이트 ABI 필드가 붙음 — precompiled-runtime.o 경로 일관성 +
  frozen runtime regen 필요. 그래서 "runtime 출하물 변경" 축에서는 UNBOX 보다 표면이 큼. 1.29×
  clean win, ratio≉1.000(storage-flatness pivot 불요).
- **PACK_ESCAPING 후순위/현재 부적격:** 단순 flip 불가 — default runtime.a 에 poly readers 가
  `#ifdef` 로 부재해 codegen flip 단독은 **링크 실패**. 먼저 런타임 readers unguard(PACK_ARRAY
  descriptor 선례처럼) + TAG enum 안정성 재확인 + escaping perf 실측이 prerequisite. 2-backend
  codegen + runtime.a + frozen 전부 이동하는 최대 blast-radius. 측정된 speedup 레버도 아님.

---

## 5. user-go 체크리스트 (각 flip 머지 전 GREEN 필수)

flip 은 DEFAULT emit/runtime byte 를 바꿔 gen3≡gen4 fixpoint 를 비가역 재수렴시키는 변경이라
릴리스무결성 절대가드 사안. **mini=git/gh only → 전부 PR→CI(Blacksmith/self-hosted) 게이트로
받음** (로컬 검증 불가, #4016 이후 정규 CI 는 Blacksmith 아닌 github-hosted/self-hosted).

공통 (모든 flip):
- [ ] **byteeq 3타깃 GREEN** — darwin-arm64 · linux-arm64 · linux-x86_64 selfhost byte-eq
  (gen3≡gen4 재수렴) + determinism + miscompile-zero + codegen-guard + faithful-nobaseline.
- [ ] **nvptx GREEN** (codegen-guard).
- [ ] **출하 smoke GREEN** — install.sh consumer (`hexa --version` + hello/exit42 run) 3타깃.
- [ ] **opt-OUT 보존** — flip 후 명시 OFF 값(`=0` / 매크로 undef)에서 pre-flip origin 과
  byte-identical 확인(폴라리티만 반전).
- [ ] CHANGELOG.jsonl + memory(`project_hexa_runtime_gap_allclosure`) 박제.

UNBOX_NATIVE 추가:
- [ ] x86_64 self-emit byte-identical determinism (≥2 witness, PACK_ARRAY 선례).
- [ ] Gate-4 output-parity 회귀 스위트 (provably-int binop 결과 OFF==ON).
- [ ] arm64 emit byte-identical 확인(게이트 부재 자명 — 명시 검증).

IC_STRUCTID 추가:
- [ ] regenerated runtime_core.c flag-OFF 에서 main byte-identical (#4122 선례 재확인).
- [ ] precompiled-runtime.o 경로(self/runtime.h) ABI 일관성 — struct_id 필드.
- [ ] hit-parity EXACT(OFF/ON 100%) + 정확성 ON==OFF(sink byte-id).
- [ ] frozen runtime re-baseline 절차 확인(runtime.a 출하물 변경).

PACK_ESCAPING 추가 (prerequisite 먼저):
- [ ] **런타임 poly readers unguard** — default runtime.a 에 hexa_arr_poly_*/new_esc/TAG
  무조건 포함(링크 실패 차단). 이게 선행 PR.
- [ ] escaping packed [i64]+[f64] perf 실측 (measured speedup 레버화 — 현재 없음).
- [ ] x86_64 AND arm64 codegen fixpoint 둘 다 재수렴.
- [ ] escape-stress OFF==ON bit-exact (transitive alias-coherence, #4121 류).

---

## 6. 정직 (honest limits)

- 이 RFC 는 **census/코드읽기/changelog 기반** — 실측 fixpoint 재수렴 빌드는 **수행하지 않음**
  (user risk-budget 인가 전까지). 따라서 "flip 시 3타깃 byteeq 가 실제로 재수렴한다"는 **예측**
  이지 실측 아님. PACK_ARRAY(#4163)가 codegen-only flip 의 3타깃 재수렴 선례를 제공하나,
  UNBOX_NATIVE/IC_STRUCTID/PACK_ESCAPING 각각의 재수렴은 user-go 후 CI 에서 확인해야 한다.
- DEFAULT byte 0변경: 이 PR 은 문서 1개 + CHANGELOG 1줄만 — 코드 0변경이라 DEFAULT emit/runtime
  byte-identical 자명.
- arm64-linux 전용 codegen 파일 없음 — `arm64_darwin.hexa` 가 arm64-linux+darwin-arm64 공유
  백엔드(ELF/Mach-O reloc 만 sed-fixup). 따라서 "arm64 게이트 부재"는 두 arm64 타깃 모두에
  적용.
- 측정 수치는 모두 머지된 PR 의 captured median 측정(LLM 자가판정 아님). 단 PACK_ESCAPING 은
  speedup 미측정(coverage/correctness 레버) — 승격 정당화에 perf 근거 부재가 후순위 이유.
