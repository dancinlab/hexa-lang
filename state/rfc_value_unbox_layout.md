# RFC — HexaVal 16B → 8B value-layout (NaN-boxing / SMI reference-gate)

> fleet-full **c frontier** 재구동. research-gate (r1) = web/census·빌드없음·무비용 (MINI-SAFE).
> 목표: 동적언어가 value 를 8B(또는 그 이하)로 packing 하며 dynamism 유지하는 정석을
> reference-match → hexa `HexaVal {tag@+0, payload@+8}` 16B → 8B packing 의 **tractability +
> byteeq 영향** 판정.
>
> SSOT 연계: 메모리 `project_hexa_runtime_gap_allclosure` (k5 cross-fn 박싱 측정음성) ·
> `project_hexa_rfc061_hxlcl_crosstarget_abi_wall` (PAIR-MODEL ABI 벽) ·
> CHANGELOG `perf(game-thread r4): native-unbox job-payload = MEASURED WALL 🧱` (이 RFC 가 재구동).

---

## 0. 문제 (frontier 정의)

현재 hexa 의 모든 동적 값은 16바이트 `HexaVal` 다 (stdlib/runtime/array_core.hexa:17-20):

```
typedef struct { HexaTag tag; union { int64_t i; double d; char* s; void* p; }; } HexaVal;
//                tag @ +0 (8B)        payload @ +8 (8B)                          sizeof = 16
// TAG_INT=0  TAG_FLOAT=1  TAG_BOOL=2  TAG_STR=3  TAG_VOID=4  (TAG_ARRAY/MAP …)
```

이 16B/value stride 가 3중 세금을 매긴다:
- **(a) boxing 세금** — 측정된 4.61× boxed/raw tax (game-thread lane e, CHANGELOG r3/r4).
- **(b) arena race 근원** — 16B 비원자 store(2 word) = 멀티스레드 arena 에서 tag/payload 가
  찢어질 수 있는 word-tearing 면.
- **(c) cache density 절반** — 8B 패킹 대비 element 당 캐시 라인 점유 2배
  (x86_64_linux.hexa:1232-1237 fast-path 도 `imul rax,16` 후 `mov [r11+8]` — 호출은 없애도
  16B traffic 은 그대로, half the cache density).

레퍼런스 질문: **dynamic value 를 single 64-bit word 로 packing 하면서 {int, float, ptr,
bool, str-ptr} 를 모두 구별**할 수 있는가? 모든 주류 동적 VM 이 그렇게 한다 — 정독한다.

---

## 1. Reference 인코딩 (정답지 — 논문/소스 인용)

### 1.1 NaN-boxing — JavaScriptCore (JSValue, 64-bit)

64-bit 플랫폼에서 JSC 는 IEEE-754 double 의 미사용 NaN 공간에 type+value 를 인코딩한다
(JSValue.h `JSCJSValue` 인코딩):

- **Pointer (favored)**: 상위 2바이트가 `0x0000` 인 범위. 포인터는 **마스킹 없이** 그대로
  사용 — JSC 는 pointer 를 "박싱하지 않는다"(다른 모든 값만 박싱). bool/null/undefined 는
  특정 invalid-pointer 값으로 표현(`ValueFalse`/`ValueTrue`/`ValueNull`/`ValueUndefined`).
- **Double**: 저장 시 `DoubleEncodeOffset = 2^49` 를 **64-bit 정수 가산**(원문은 "add 2^48"
  서술 변형 있으나 JSC 소스는 `1ull << 49`). 가산 후 어떤 double 도 `0x0000`/`0xFFFF` 로
  시작하지 않음 → pointer/int 공간과 분리.
- **Integer (Int32)**: 상위 16비트 태그 `0xFFFF` (`NumberTag = 0xFFFF000000000000`),
  하위 32비트에 int32 raw. 즉 `int32 | 0xFFFF000000000000`.
- 핵심 불변: NaN 공간 16-bit hex 패턴 `0xFFFE`/`0xFFFF` 가 type(Pointer/Double/Integer) 을
  denote. 출처: wingolog "value representation in javascript implementations" (2011) +
  witch.work "JS Engines Store Values, Tagged Pointer and NaN Boxing" + JSC `JSCJSValue.h`.

### 1.2 NaN-boxing — SpiderMonkey ("nun-boxing", double-favored)

Mozilla 는 **double 을 favor** (= "nun-boxing"). pointer 를 unpack 하려면 double 공간을
회전시켜야 함. JSC 와 polarity 반대(JSC=pointer-favored). 둘 다 8B single word.
출처: wingolog (2011) — "Mozilla chose to favor doubles … rotating the double space around".

### 1.3 NaN-boxing — LuaJIT 2.0 / 2.1 GC64 (TValue)

LuaJIT 의 NaN-tagging (Mike Pall, 1997 parallel-Haskell 기원·Peter Cawley pioneered):
- **ordinary number = bare double** (태그 없음 — number 가 가장 흔하므로 zero-overhead).
- **non-number (GC64 mode, `LJ_GC64`)**: 상위 13비트 = 1 (NaN signal), 다음 **4비트 itype**
  (TValue type), 하위 **47비트** = pointer | zero-extended 32-bit int | all-1 (primitive).
- 출처: LuaJIT `src/lj_obj.h` (v2.1) `TValue` union + OpenResty "LuaJIT GC64 Mode" blog +
  medium "LuaJIT Source Code Analysis Part 2: Data Type". 47-bit pointer = x86-64/arm64
  user VA 와 호환(상위 17비트 sign-extend canonical) — single 8B word.

### 1.4 SMI / tagged-pointer — V8 (Smi, 31/32-bit unboxed int)

NaN-boxing 과 **다른 계열**: V8 은 double 을 box(heap-allocate)하고 **small int 만 word
안에 unbox**한다:
- **Smi**: 31-bit payload(부호 포함). 최하위 비트로 Smi(=0) vs heap-pointer(=1) 구별 —
  `|___int31_value____0|`. 값 추출 = signed right-shift 1.
- **pointer compression** (v8.dev/blog/pointer-compression): tagged value 를 **하위 32비트
  half-word 만 메모리에 저장** → tagged value 메모리 절반. Smi 는 `|sign…|int31_value 0|`
  로 sign-extend 되어 1-bit arithmetic shift 로 compress/decompress.
- 출처: v8.dev "Pointer Compression in V8" + medium fhinkel "How Small is a Small Integer".
- **핵심 한계**: V8 Smi 는 **double 을 unbox 못 함**(heap box). NaN-boxing 이 double-native
  hexa 수치 워크로드에 더 맞는 이유.

### 1.5 종합 표

| VM | word | int | double | pointer | 정독 출처 |
|----|------|-----|--------|---------|-----------|
| JSC | 8B | `int32 \| 0xFFFF…` | `+2^49` offset | top-2B=0, no mask | JSCJSValue.h / wingolog |
| SpiderMonkey | 8B | tag | bare(favored) | rotate | wingolog |
| LuaJIT GC64 | 8B | 47-bit zext | bare double | 47-bit | lj_obj.h v2.1 |
| V8 Smi+PC | 4B(compressed) | 31-bit unbox | **heap-boxed** | 32-bit offset | v8.dev pointer-compression |

**공통 정석**: int 와 pointer 는 항상 single word 에 unbox 가능. **double 만이 분기점** —
NaN-box(JSC/SM/LuaJIT)는 double 을 word 에 넣지만 int/ptr payload 를 **48~51비트로 제약**;
SMI(V8)는 double 을 box 하지만 pointer-compression 으로 메모리만 줄임.

---

## 2. hexa 16B → 8B 레버 매핑 (tractability)

### 2.1 NaN-box 가능성 — 구조적으로 YES, but full-precision double 과 충돌

hexa `HexaVal` 의 payload union 은 **full 64-bit `double d`** 를 carry 한다
(x86_64_linux.hexa:3246 "The 8-byte payload IS the IEEE-754 bit pattern; movq"). 이게
NaN-boxing 과 정면 충돌하는 hexa 고유 제약:

- NaN-box 는 double 을 **그대로(또는 offset 가산해서) 64비트에 담고**, int/ptr 를
  **남는 NaN payload 비트(47~51bit)** 에 우겨넣는다. 즉 int·pointer 가 48비트로 좁아진다.
- hexa 는 **현재 int 도 float 도 둘 다 full 64비트**다(tag 가 별도 word 라 payload 가 통째로
  64비트). NaN-box 로 single word 화하면:
  - **int64 → 48~51bit 로 손실** (LuaJIT 47bit, JSC int32 만 안전). hexa `i64` 는
    full-width 정수 산술(codegen 이 raw-int 1-register 모델, x86_64_linux.hexa:1923)을
    가정하므로 **상위비트 절단 = miscompile**.
  - **pointer 48bit** 는 현 x86-64/arm64 user-VA 에서 OK(LuaJIT 실증), 하지만 hexa arena 가
    상위비트 미사용을 보장하는지 미검증.
- → **double-favored NaN-box(SM/LuaJIT)** 는 hexa double-native 수치 스택(qforge/flame/
  signal — full f64)에 가장 적합하나, **i64 full-width 를 깨므로** byteeq-safe 가 아님.
- → **V8 SMI 계열**은 int 만 unbox(31bit)+double box — hexa 수치 워크로드(f64 다수)엔
  역효과(double 매번 heap box). 부적합.

### 2.2 핵심 발견 — tag 는 이미 별도 word 라서 NaN-box 가 *불필요한 곳*에선 무이득, *필요한
곳*에선 i64 절단

hexa 의 16B 는 **explicit tag word** 모델이다. NaN-box 의 가치는 "tag 를 위한 별도 word 를
없앤다"는 것 — 즉 16B→8B 는 정확히 **tag word 제거**다. 그런데 tag word 제거 = payload 에
tag 를 섞어 넣기 = **payload 가 더 이상 full 64비트가 아님**. hexa 의 두 가지 full-64
payload(i64, f64)가 **동시에** full-width 일 수 없다 — NaN-box 는 둘 중 하나(보통 double)만
full, 나머지는 제약. 이건 임의 선택이 아니라 **정보이론적 천장**: 64비트 안에 {64-bit
double 전체} + {64-bit int 전체} + {tag} 를 무손실로 담을 수 없다.

### 2.3 범위 (scope) — 만약 강행하면

8B 전환이 건드릴 표면(census):
- **codegen 2 백엔드** — x86_64_linux.hexa(91 "16" 사이트) + arm64_darwin.hexa(80) 의
  PAIR-MODEL ABI 전체. 현재 모든 builtin call 이 `{tag,payload}` 를 **register PAIR**
  (rdi:rsi / x0:x1, return rax:rdx / x0:x1)로 전달(x86_64_linux.hexa:1917-1927,
  arm64_darwin.hexa:597). 8B 는 이걸 **single-register ABI** 로 재설계 = RFC061
  `hxlcl_crosstarget_abi_wall` 과 **정확히 같은 클래스의 전면 ABI 재설계**.
- **runtime stride 사이트** — array_core/map_core/intern_core 의 `idx*16`+`@+8` 전부
  (array_core.hexa:113, map_core.hexa:28). + 352 helper 호출(`__hx_make_val`/`__hx_payload_add`/
  `__hx_tag`/`__hx_ptr_load64`).
- **float ABI** — x86_64_linux.hexa:3246-3330 `__hx_to_double` (payload bits == IEEE754,
  tag==TAG_FLOAT 분기). NaN-box 면 이 분기 자체가 인코딩에 흡수(재설계).
- **frozen seed** — PAIR-MODEL 은 frozen blob `151c52c8` 의 ABI. 8B 전환 = 모든 native
  seed(.s) 재생성 + gen3≡gen4 fixpoint 재수렴 = **byteeq 전면 flip**.

### 2.4 opt-in 가능성 (felt-default 보존) — NO (전역 ABI)

byteeq-neutral opt-in 토글(`HEXA_*`)로 격리 **불가**. 이유: value stride 는 **메모리
레이아웃 + register ABI** 둘 다라서, 한 함수만 8B 로 바꾸면 그 함수와 caller/array/map 가
ABI-불일치(16B 호출규약 vs 8B). PAIR vs single-register 는 **전역 일관성**이 필요 —
`project_hexa_rfc061_ladder` 의 per-symbol native-replace 처럼 부분 격리가 안 된다.
(access-unbox `HEXA_UNBOX_ARRAY_NATIVE` 가 opt-in 가능했던 건 그게 **호출만 제거**하고
16B traffic·ABI 는 그대로 뒀기 때문 — CHANGELOG r4. 레이아웃 자체 변경은 그 격리가 불가.)

---

## 3. byteeq / 판정

### 3.1 byteeq 영향 — 전면 flip (neutral-opt-in 불가)

- value 모델 16B→8B = codegen PAIR-MODEL → single-register ABI 전면 재설계 +
  frozen seed(151c52c8) 전 재생성 + gen3≡gen4 재수렴. **byteeq-safe 아님**,
  default-OFF 격리 **불가**(§2.4).
- 같은 클래스: `project_hexa_rfc061_hxlcl_crosstarget_abi_wall` —
  "codegen PAIR-MODEL{tag,payload}(rdi:rsi) vs raw-C-ABI(rdi=char*)" 가 INFEASIBLE 로
  측정된 그 벽. value-unbox 는 그 ABI 벽을 **value 전체로 확대**한 것.

### 3.2 honest verdict — 🧱 MEASURED WALL (정보이론 + ABI 같은 클래스)

**🧱 close (reopenable).** 두 독립 천장이 동시에 막는다:

1. **정보이론 천장 (file:line)** — `array_core.hexa:17` `{tag, payload}` 에서 hexa 는
   **i64 와 f64 를 둘 다 full-width**로 carry 한다(payload union, x86_64_linux.hexa:3246
   "payload IS the IEEE-754 bit pattern"). NaN-box single-word 는 둘 중 하나만 full-width
   가능(48~51bit 제약) → **i64 절단 = miscompile**. 이건 dynamic `{tag,payload}` 천장과
   **같은 클래스** (정보이론적, 우회불가): 64비트에 {full f64}+{full i64}+{tag} 무손실
   불가능.

2. **ABI 천장 (file:line)** — `compiler/codegen/x86_64_linux.hexa:1917-1927` +
   `arm64_darwin.hexa:597` PAIR-MODEL register ABI. 8B = single-register ABI 전면 재설계 =
   `rfc061_hxlcl_crosstarget_abi_wall` 와 **동일 클래스의 frozen-seed 전면 flip**,
   opt-in 격리 불가(§2.4).

→ 16B→8B 는 **tractable 하지 않다** (full-width i64+f64 무손실 + opt-in 격리 둘 다 불가).
이전 game-thread r4 의 "memory-layout wall 🧱" 을 reference-match 로 **재확인 + 근거 격상**:
r4 는 "16B traffic = half cache density" 를 measured 했고, 이 r1 은 **왜 8B 로 못 가는지**의
정답지 근거(NaN-box 가 i64 를 절단)를 추가했다.

### 3.3 정직 — value 모델 재설계 = dynamic {tag,payload} 천장과 같은 클래스

YES. `array_core.hexa:17` `{tag@+0, payload@+8}` 의 16B 는 **dynamic value 가 i64·f64·ptr·
bool·str-ptr 를 무손실 구별**하려는 요구의 직접 귀결이다. NaN-box(JSC/LuaJIT)가 8B 로 가는
대가는 **payload 폭 제약**(i64 절단) — hexa 가 그 제약을 받아들이지 않는 한(full i64 산술
유지) 16B 는 irreducible. 이건 우회 가능한 구현 결함이 아니라 **모델 천장**이다.

---

## 4. 다음 (next) — implement 아니라 reopen-targets

implement r2 **없음** (16B→8B 는 measured-infeasible, byteeq 전면 flip + i64 절단).
대신 **인접 reopenable 표적** (이 frontier 의 진짜 레버는 이미 알려진 우회):

- **(T1) packed unboxed array (이미 LANDED — 정답)** — `farr64`/`farr32` (per-elem tag 없는
  8B/4B raw, read-path boxing-unbox #3641/#3643, 522× RSS lever). 16B HexaVal 을 **개별
  값마다** 줄이는 대신, **typed 동질 배열을 통째로 unbox** 한다 — NaN-box 의 i64-절단
  없이 dense packing 달성. 올바른 guidance = `use farr not []` (CHANGELOG r4 결론과 일치).
  → frontier 의 (a)(c) 세금은 farr 경로가 이미 해소. **(b) arena race** 만 미해소.
- **(T2) arena race (b) 단독 reopen** — frontier 의 멀티스레드 word-tearing 은 8B 전환
  없이도 **per-value atomic store** 또는 **thread-local arena** 로 분리 공략 가능
  (레이아웃 ABI 안 건드림 → byteeq-neutral 가능성). 이게 **honest next research-gate** —
  value 폭과 무관한 동시성 축. 표적: stdlib/runtime arena store 사이트 + arena race census.
- **(T3) reopen 조건** — 만약 hexa 가 미래에 **i64→i48 narrow 를 felt-default 로 수용**
  (대부분 동적값이 48비트로 충분하다는 측정이 나오면), NaN-box 가 tractable 해진다.
  그때 LuaJIT GC64 47-bit 인코딩(lj_obj.h)을 reference 로 재구동. 현재는 i64-full 가정이
  raw-int codegen 에 박혀 있어(x86_64_linux.hexa:1923) 불가.

---

## 5. 산출 / 게이트

- **doc-only** (이 파일 + CHANGELOG 1줄). 코드/seed/ARCHITECTURE.json 미변경. 빌드 없음
  (research-gate, mini=git/gh).
- aiden 게이트 **불요** (implement 없음 — measured wall).
- T2(arena race) 가 honest next 면 그건 **별도 research-gate** 로 (이 RFC 와 분리,
  value-width 와 독립 축).

### 핵심 reference 인용 (정답지)
- NaN-box JSC: wingolog 2011 "value representation in JS implementations" + JSC
  `JSCJSValue.h` (`NumberTag=0xFFFF…`, `DoubleEncodeOffset=1<<49`, pointer top-2B=0 no-mask).
- NaN-box LuaJIT GC64: `LuaJIT/src/lj_obj.h` v2.1 `TValue` (13-bit NaN + 4-bit itype +
  47-bit payload) — Mike Pall, 1997 parallel-Haskell 기원.
- SMI V8: v8.dev "Pointer Compression in V8" (`|___int31_value____0|`, signed-shift-1,
  half-word compress) — double=heap-boxed.

### hexa file:line (천장 근거)
- `stdlib/runtime/array_core.hexa:17` — `{tag@+0, payload@+8}` 16B stride (모델 SSOT).
- `compiler/codegen/x86_64_linux.hexa:3246` — "payload IS the IEEE-754 bit pattern"
  (f64 full-width 증거 → NaN-box 와 충돌).
- `compiler/codegen/x86_64_linux.hexa:1917-1927` + `arm64_darwin.hexa:597` — PAIR-MODEL
  register ABI (8B = single-register 전면 재설계 = rfc061 ABI 벽 같은 클래스).
