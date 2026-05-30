# UNSHADOW — NaN-boxing HexaVal 표현 설계 / feasibility (DESIGN + 최소측정)

> 상태: **DESIGN / feasibility + 최소 A/B 측정** (전역 flip 아님 · 의도적).
> 결론: 전역 ABI 변경이라 1-batch 불가 = multi-session. honest 분해 — 설계 + 규모 산정 +
> 최소 측정(이론 Δ + faithful A/B proxy) + sub-task open 등록. 전역 flip 은 GATED default OFF
> 로 별도 sub-task. SSOT = 이 파일 (UNSHADOW.md milestone `- [ ]` 1줄 유지).
> 측정대 = `tool/unshadow_nanbox_proxy.c` (faithful A/B proxy, B9 self-host regen 벽 밖 · 스펙 허용).

---

## §0 — 사실 정정 (FIRST · honest)

milestone 텍스트 "24B tagged-union → 8B" 의 **24B 는 stale**. 현 `HexaVal` 실측 **`sizeof = 16B`**
(`{ HexaTag tag; union{...} }` — 4B enum + 4B 패딩 + 8B union). `UNSHADOW.bench.md §unboxed-array`
(L701) 가 이미 16B 로 정정 기록. 따라서 NaN-box 의 밀도 이득은 **3× 가 아니라 정확히 2×**
(16B→8B). 본 설계는 16B 기준.

---

## §1 — 현 HexaVal 레이아웃 (read-only 조사, `self/runtime.h:79-92`)

```c
typedef struct HexaVal_ {
    HexaTag tag;          /* 4B enum: TAG_INT..TAG_ENUM (12 tags) + 4B padding */
    union {
        int64_t i; double f; int b; char* s;
        HexaArr* arr_ptr; HexaMap* map_ptr; HexaFn* fn_ptr_d;
        HexaClo* clo_ptr; HexaValStruct* vs;
    };                    /* 8B */
} HexaVal;                /* total 16B */
```

- 접근은 `runtime.h:151-207` 매크로 레이어를 경유 — `HX_INT/HX_FLOAT/HX_BOOL/HX_STR`(payload
  추출) · `HX_IS_INT/.../HX_IS_CLOSURE`(tag 테스트) · `HX_FN_PTR/HX_CLO_*`(포인터-카테고리 필드) ·
  `HX_SET_*`(in-place union 변이).
- **단 매크로가 전부가 아니다**: codegen 이 `((HexaVal){.tag=TAG_INT,.i=(N)})` **compound literal
  로 직접 construct** (§hexaval-unbox·§native-arr 가 emit 하는 그 형식) → `{tag; union}` 레이아웃을
  C 소스 문자열에 박아 emit. 이게 NaN-box 의 핵심 블로커 (아래 §3).

---

## §2 — NaN-box 8B 레이아웃 설계

f64 quiet-NaN 의 미사용 mantissa 비트에 tag+payload 패킹. canonical layout:

```
  63   62────52  51  50──────────────48 47────────────────────────────0
  S    exponent   q   tag(3bit)             payload(48bit)
  1    0x7FF      1   000=INT 001=BOOL ...  int48 / ptr48
```

- **box 마커** = sign(1) | exp(0x7FF=11bit) | qbit(1) = 상위 13비트 `0xFFF8...`. 이 13비트가
  전부 1 이면 "박스" → tag/payload 해석. 아니면 = **진짜 f64** (NaN-box 안 거치고 비트 그대로).
- **float = 박싱 안 함 (passthrough)**: f64 는 자기 비트 그대로 저장. 정수/bool/포인터만 qNaN
  payload 에 패킹. → float-heavy 워크로드는 무손실·무변환.
- **포인터 (TAG_STR/ARRAY/MAP/FN/CLOSURE/VALSTRUCT/ENUM)**: 48비트 payload 에 ptr 패킹. arm64/x86-64
  유저공간 가상주소 = 48비트(상위 16비트 sign-extend canonical) → 정확히 fit. ⚠ 5-level paging
  (LA57, 57비트 주소)·일부 arm64 52비트 VA 구성에선 48비트 초과 → **이식성 제약**(아래 §6).

### tag 인코딩 — 12 tag > 3비트(8)

현 12 tag 를 3비트(8슬롯)에 못 넣음. 해법 2택:
- (A) **4비트 tag** (51비트 중 4 = tag, 47 = payload). 47비트 payload 는 int47·ptr47
  (현 arm64 48비트 VA 와 1비트 충돌 → ptr 별도 처리 필요). 16 tag fit.
- (B) **2-tier**: 흔한 3 tag(INT/BOOL/포인터-공통) 만 3비트 fast, 포인터는 1슬롯으로 묶고 실제
  카테고리는 가리키는 힙 객체 헤더에서 (현 `HexaArr*`/`HexaMap*` 등이 이미 자기 타입 앎). →
  payload 48비트 유지. **권장** (포인터-카테고리는 deref 시점에 이미 안다).

---

## §3 — 규모 산정 (1-batch 가능 vs multi-session)

NaN-box 는 union 을 **물리적으로 제거**한다 (`HexaVal` = bare `uint64_t`). `.tag`/`.i`/`.f`/`.s`/
`.arr_ptr` 멤버가 사라지므로, 레이아웃을 가정하는 **모든 사이트가 동시에** 비트-추출로 바뀌어야 함.
worktree 격리 grep 실측 (self/codegen.hexa + self/runtime_core_emit.hexa + compiler/):

| surface | 사이트 수 | 비고 |
|---|---|---|
| `HX_*` 매크로 use (payload 추출 + tag 테스트 + SET) | **1151** | 매크로 본문만 바꾸면 흡수되는 부분 多 |
| emitted-C `TAG_*` 리터럴 (codegen 이 C 문자열로 emit) | **430** | tag 비교/구성 — box 인코딩으로 재작성 |
| `((HexaVal){.tag=...,.i=...})` compound-literal 생성자 | **19** | **매크로 우회** — 비트-construct 헬퍼로 전부 교체 必 |

**판정 = multi-session (1-batch 불가)**. 근거:
1. **매크로 레이어가 추상화를 절반만 보장.** `HX_INT(v)`→`((v).i)` 같은 추출은 매크로 본문을
   `unbox_int(v)` 로 바꾸면 1151 use 가 자동 흡수 — 이건 좋은 소식. **그러나** 19개 compound-literal
   construct (`(HexaVal){.tag=..,.i=..}`) 는 매크로 밖 = codegen emit 문자열을 전부 `HX_MK_INT(n)`
   류 생성 매크로로 교체해야 하고, 이건 §hexaval-unbox·§native-arr·§B proof-carrying 가 의존하는
   바로 그 emit 형식 → 회귀 surface 큼.
2. **두 표현 공존 = 진짜 dual ABI.** runtime.o(아말감) 와 user.c 가 같은 `HexaVal` ABI 를 공유 —
   한쪽만 NaN-box 면 모든 경계 호출이 깨짐. GATED flip 은 runtime 전체 + codegen 전체를 **함께**
   재빌드해야 의미 → B9 self-host regen 벽과 정면 충돌 (full rebuild 차단).
3. **float passthrough + NaN-canonicalize 가 모든 float store 에 침투.** 진짜 f64 가 우연히 qNaN
   비트면 박스로 오인 → 모든 float 산출 지점(libm·산술·리터럴)에서 canonicalize 必 (아래 §5).

→ 무리한 전역 flip 금지 (milestone 지시 준수). **설계 + feasibility + 최소측정 + sub-task** 로 분해.

---

## §4 — 최소 측정 (faithful A/B proxy · mini arm64)

측정대 = `tool/unshadow_nanbox_proxy.c` (16B boxed vs 8B NaN-box, 동일 워크로드). B9 self-host
full regen 벽 밖이라 §c-class·§native-arr 와 동일한 faithful-proxy 스펙 허용. 3 축:

| 워크로드 | A(16B box) | B(8B NaN-box) | B/A | 판정 |
|---|---|---|---|---|
| **sequential traverse+sum** (8M·rep40) | 0.39s | 1.10s | **2.5–2.8× 느림** | 🔴 NaN-box 패배 |
| **value-pass register-fit** (noinline·4M·rep30, best-of-7) | 0.16s | 0.21s | **1.30–1.36 = 30–36% 느림** | 🔴 NaN-box 패배 |
| **random / cache-pressure** (4M perm-chase) | 0.24s | 0.22s | 0.89–0.93 = **7–11% 빠름** | 🟢 유일 승 |

- **밀도**: sizeof 16→8 (정확히 2×) · N=8M 배열 footprint 128MB→64MB.
- **checksum match = YES** (int round-trip 정확, 48비트 sign-extend).
- ⚠ value-pass 는 **반드시 best-of-N 반복측정** — 단발은 37% 빠름~36% 느림 사이 분산.

### §4 핵심 해석 (honest — register-fit 가설 falsified)

> ⚠ 정직 정정: 초기 단발 측정의 "value-pass 37% 빠름" 은 **측정 artifact** 였다. best-of-7 안정화
> 시 value-pass 는 일관되게 **30–36% 느림**. → milestone 의 register-fit 가설은 이 proxy 에서
> **반증**.

NaN-box 는 **uniform win 이 아니라, 거의 전 축에서 퇴보하고 density 만 작게 이긴다**:
- 🔴 **sequential/vectorizable 패배 (2.5–2.8×).** `is_boxed()`+mask-extract 가 auto-vectorizer 를
  죽인다 (16B box 는 단순 `tag==INT`+직접 load 라 clang -O2 가 SIMD). → §native-arr 가 이미 잡은
  "contiguous int64[]" 워크로드는 NaN-box 가 **퇴보**시킨다 = C1 과 **상충**.
- 🔴 **value-pass 패배 (30–36%).** 8B=1 레지스터 이론 이득보다 매 호출 box/unbox(mask+shift+OR)
  추출비용이 크다. 소유 ABI 라도 추출비용은 공짜가 아니다 — milestone 가설 반증.
- 🟢 **cache-pressure 7–11% 승 (유일).** 밀도 2× 가 random-access working-set 절반 — 단 sequential
  prefetch 가 가리는 워크로드에선 mask 오버헤드가 이김.

→ **per-program GATED 가 정답** (milestone "프로그램별 표현 선택 · default OFF" 와 일치).
단 측정상 우위 종목은 **memory-bound random-access 단 하나**. milestone 의 "전역 캐시밀도 3×" 기대는
(a) 밀도 실제 2× (b) 이득이 wall 로 전환되는 건 random-bound 한정 → **대폭 축소**. 이게 "LLVM-can't"
(C 는 고정 ABI 라 프로그램별 표현 못 고름)의 실측 — **단 우위는 좁고 워크로드-조건부, 가설 일부 반증**.

---

## §5 — NaN-collision 정확성 제약 (milestone 핵심 함정)

- 측정: 진짜 f64 NaN 비트 = `0x7ff8000000000000` (sign=0). box 마커 = `0xFFF8...`(sign=1) →
  canonical **positive** qNaN 은 충돌 안 함 (`is_boxed()=0` 실측).
- **그러나 negative-NaN·signaling-NaN·payload-bearing NaN** 은 `0xFFF8...` 영역과 겹칠 수 있음.
  → **모든 float store 에서 NaN canonicalize 必**: `if (isnan(x)) x = canonical_qnan;` (sign=0).
  이걸 빠뜨리면 사용자가 `0.0/0.0` 의 비트 패턴을 보거나, 음수-NaN 을 박스로 오인 → silent
  miscompile. libm(`sqrt(-1)`·`log(-1)`) 도 음수-NaN 산출 가능 → 경계마다 가드.
- **근본 제약 (honest)**: 사용자가 raw f64 비트를 직접 관찰/구성하는 프로그램(bit-cast·직렬화·
  hash-of-double) 은 NaN-box 가 안전하게 못 덮는다 = 이 표현의 **결정적 한계**. 이 경우 GATED OFF
  유지가 정답. byte-diff IDENTICAL 게이트는 이 corpus(음수-NaN·NaN-payload·bit-cast)를 반드시
  포함해야 통과 — full corpus 게이트는 전역 flip sub-task 의 선결.

---

## §6 — 이식성 제약

- **48비트 VA 가정**: LA57(x86 5-level paging) · arm64 52비트 VA 구성에서 ptr 가 48비트 초과 →
  payload 에 안 들어감. mini(Apple M4, 47비트 user VA)는 안전하나 **이식성 risk**. 해법 = ptr 을
  base-relative offset 으로(힙 arena base 기준) 또는 §2(B) 2-tier(포인터는 1슬롯, 카테고리는 deref).

---

## §7 — 의존성 (C1 native-arr · C13 escape)

- **C1 (native HexaArrI64) = 부분 착지(`[~]`)**. milestone 텍스트 "C1·C13 이후" 의 C1 은 선결로
  지목됐으나, §4 측정이 **반전**을 드러냄: NaN-box 는 sequential-array 에서 **퇴보** → C1(native
  contiguous int64[]) 과 NaN-box 는 **상충**하는 종목. C1 이 먼저 잡은 array hot-loop 에 NaN-box 를
  씌우면 손해. → 의존이 아니라 **분리**가 맞다 (서로 다른 워크로드 종목).
- **C13 (escape→stack)**: 공간축. NaN-box 의 밀도(8B)는 stack-alloc 과 시너지(스택 frame 절반) —
  진짜 시너지 종목. C13 먼저가 합리.

---

## §8 — sub-task (open, GATED default OFF)

전역 flip 은 아래 선결 충족 시 별도 sub-task:

1. **construct 헬퍼 통일** — codegen 의 19개 `((HexaVal){...})` compound-literal → `HX_MK_INT(n)`/
   `HX_MK_FLOAT(f)`/`HX_MK_PTR(tag,p)` 생성 매크로로 교체 (NaN-box 와 box 양쪽이 같은 매크로 본문
   토글로 표현 전환 가능하게). 이게 전역 flip 의 **단일 토글 지점**이 됨.
2. **NaN-canonicalize 침투** — 모든 float store 경계 가드 (§5).
3. **full-corpus byte-diff 게이트** — int/float/ptr/bool round-trip + 음수-NaN·NaN-payload·bit-cast
   corpus IDENTICAL (§5 제약 corpus 포함).
4. **GATED 재빌드** — runtime + codegen 동시 NaN-box 재빌드 (B9 벽 해소 = `.c=0` 졸업 의존 OR
   faithful dual-ABI proxy 측정).
5. **워크로드-조건부 발화** — §4 가 입증: value-pass/cache-pressure 만 ON, sequential-array 는 OFF
   (atlas-PGO C17 와 결합 = 어느 프로그램에 켤지 결정).

---

## §9 — 참조

- 현 레이아웃: `self/runtime.h:79-92`(HexaVal) · `:151-207`(HX_* 매크로) · `:74`(HexaArr)
- sizeof 16B 정정: `UNSHADOW.bench.md §unboxed-array`(L701)
- C1 부분착지: `UNSHADOW.md` milestone "native HexaArrI64" (`[~]`) · `self/runtime_core_emit.hexa:1120`
- 측정대: `tool/unshadow_nanbox_proxy.c` · bench=`UNSHADOW.bench.md §nanbox`
- LLVM-can't 근거: `UNSHADOW.easy.md §E "per-program NaN-box"` (단 §4 가 우위=워크로드-조건부로 정정)
