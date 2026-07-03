코드 조사 완료 — 필요한 근거(시임 구조, strtod 선례 전체 파이프라인, `extra_obj` 흐름, 심볼 노출 실측)를 모두 확보했습니다. 설계문입니다.

---

# 설계: `rt_regex_*` standalone-`runtime.a` 해소 — regex flip(#4451 재도전) 배선

zero-c #29 · regex reduction 후속. 대상 브랜치 소스 = `selfhost/floor-regex-native` (dc971de05, #4445 머지분과 동일 내용 — 로컬 main은 #4439에서 stale이라 브랜치에서 직접 확인).

## 0. 결론 (추천)

**계열 1 — `.s` frozen-seed (strtod `float_parse_hexinfnan` 선례의 정확한 미러) + 심볼 강등(post-pass) 추가.**

- 신규: `tool/regen_regex_rt_native_s.sh` (hexinfnan regen의 쌍둥이) → `self/native/regex_rt_{arm64,x86_64,arm64-linux}.s` 3개 frozen seed 커밋.
- `tool/stage_resolve_runtime_a`: `resolve_native_regex_rt_seed()` 리졸버 + `$extra_obj`/`-D` 배선 (기존 14개 `resolve_native_*_seed` 패턴 복사).
- **regex 고유 추가분 = `.globl` 강등 post-pass**: seed 안의 ~86개 전역 심볼 중 6개 `rt_regex_*`만 남기고 전부 local로 강등 — 이것이 strtod엔 없던, regex에만 실재하는 중복-심볼 위험(§5.1)의 해소책.
- Phase A(이번 PR) = default-OFF opt-IN → byteeq-중립. Phase B(flip PR) = 리졸버 gate를 opt-OUT 자동활성으로 전환 → RECONVERGE-flip 게이트로 승격.

## 1. 실패 원인 재확인 (읽은 코드 기준)

#4445의 seam은 emitted `runtime.c`의 6개 `hexa_regex_*` 본체를 `#ifdef HEXA_REGEX_NATIVE` → `extern HexaVal rt_regex_*(…)` 1-line delegate / `#else` → libc 본체 VERBATIM으로 나눈다 (`self/runtime_emit_full.hexa`, regex.h include도 `#ifndef HEXA_REGEX_NATIVE` gate). `rt_regex_*` 6종의 정의는 `stdlib/runtime/regex_rt.hexa`(356 LOC, thompson/backtrack backing)에 있고, 이것은 `compiler/main.hexa:71`의 import로 **컴파일러 closure에만** 들어간다.

`runtime.a`를 **단독으로** 링크하는 두 소비자를 확인했다:

- `grace_consent.yml` L57-79: `check_grace_consent.hexa`를 C로 transpile → `clang … check_grace_consent.c build/runtime.a` — closure에 regex_rt 없음.
- `nobaseline-gate.yml` L516-628: `stage_resolve_runtime_a`로 `runtime.a` 재조립 → `HEXA_PREBUILT_RUNTIME`로 exit42/hello live-link.

flip ON이면 `runtime.o`가 `rt_regex_*` 6종을 UND로 갖는데 archive 안에 정의 멤버가 없어 두 링크가 ld에서 죽는다. 해소 조건 = **`rt_regex_*` 정의가 `runtime.a`의 멤버로 존재**할 것. 두 소비자 모두 `stage_resolve_runtime_a`가 만든 archive를 그대로 쓰므로, 리졸버가 seed `.o`를 ar하면 두 링크가 **자동으로** 닫힌다 — 추가 워크플로 수정 불요.

## 2. 계열 비교

### 계열 1 — `.s` frozen-seed (strtod 미러) ✅ 채택

strtod 파이프라인 전체를 읽고 확인한 작동 구조:

1. `tool/regen_float_parse_hexinfnan_native_s.sh`: `aprime_cc _drv.hexa --emit=asm --target=<triple> -o out.s <SSOT.hexa>` → `.file` 경로 정규화 + frozen 헤더 prepend → cross-assemble sanity(대상 심볼 `.globl` 확인). 3 타깃(arm64-apple-darwin Mach-O / x86_64-linux-gnu ELF / arm64-linux-gnu ELF).
2. `stage_resolve_runtime_a::resolve_native_float_parse_hexinfnan_seed()` (워크트리 L702-735): TARGET 매칭 seed 선택(`-musl`/`-cuda` 접미사 strip 포함) → `.globl` 개수 SAFETY 체크 → `// ` 헤더 strip 후 `$CC -c` → `build/*.o` + env export.
3. 컴파일 블록(L1238-1243): env ON이고 `.o` 존재 시 `-DHEXA_RT_STRTOD_TAIL_NATIVE` + `extra_obj` 추가.
4. `$extra_obj`는 **세 가지 archive 형태 전부**에 들어간다 — 단일-TU `ar rcs "$RA" build/runtime.o $extra_obj` (L2618), MULTIOBJ (L2593), **CUDA consumer archive** `runtime.cuda.a` (L2626, 멤버-parity FATAL 체크 L2630) — 한 곳만 고치면 전 경로 커버.
5. seed 내부의 hexa 캐리어 참조(`hexa_string_byte_at`/`__hx_make_val`/…)는 "resolve WITHIN runtime.a"가 명시적 선례(hexinfnan regen 헤더 L17-20) — regex_rt도 동일 부류(@pure, string/array 캐리어만 사용, **libc UND 0 추가**).

regex에 그대로 적용 가능하고, 콜드-스타트 제약(runtime.a는 컴파일러보다 먼저 빌드됨)을 frozen 아티팩트로 우회하는 것이 이 메커니즘의 존재 이유다("frozen dough", 스크립트 헤더 L10-12).

**크기 실측 추정** (요구사항: NFA 크기 손흔들기 금지):

| 소스 | LOC | fn 수 |
|---|---|---|
| `stdlib/runtime/regex_rt.hexa` | 356 | ~18 |
| `stdlib/regex/thompson.hexa` | 687 | 36 |
| `stdlib/regex/backtrack.hexa` | 850 | 32 |
| **합** | **1,893** | **~86** |

캘리브레이션: `float_parse_exact.hexa` 479 LOC → `float_parse_exact_x86_64.s` **5,729줄** (≈12 .s줄/LOC), `.globl` 17개(헬퍼 `fpe_*` 전부 전역 — 실측). 따라서 regex seed ≈ **~22-23k줄/타깃 × 3 = ~68k줄(~2.5-3MB) frozen 텍스트**. 현존 최대 seed(`runtime_hi_x86_64.s` 3,762줄)의 ~6배로 최대 seed가 되지만, frozen-generated 텍스트(리뷰 대상은 regen 스크립트와 SSOT .hexa)이므로 질적 문제는 아니고 양적 커밋 부피 문제일 뿐이다.

### 계열 2 — runtime-emitter 인라인 C (glob/fgets/qsort 미러) ❌

선례 실측: native glob은 `runtime_emit_full.hexa` L13176~ 의 **~60-100줄 자급자족 C**(getdents64 스캔 + 인라인 star-matcher)다. regex는 thompson NFA + backtrack VM + 6 shim = 1,893 LOC hexa ≈ **1,500-2,500줄 C** — 규모가 20-30배 다르고, 결정적으로 **두 번째 regex 엔진 SSOT**가 생긴다(stdlib .hexa 엔진과 C-mirror가 영구 이중화 — FIX-A~D 같은 reference-match 수정을 항상 두 곳에 반영해야 함). 또한 캠페인 방향("emitted-C substrate는 reducible RUNTIME-PORT 대상, 축소가 목표")에 정면 역행 — libc 심볼 3개를 지우려고 C를 2천 줄 늘리는 교환이다. glob류가 인라인으로 간 것은 "작고 자급자족"이라는 전제가 성립했기 때문이고 regex는 성립하지 않는다.

### 계열 3 — 빌드마다 컴파일하는 `.o` ❌

`stage_resolve_runtime_a`는 컴파일러가 존재하기 전( CI 콜드-스타트, seeds-removed 브랜치)에 돈다 — 이 스크립트가 hexa 러너 의존을 awk un-escape로까지 밀어낸 이유가 정확히 "러너/hexat 둘 다 FLAKY" (L79-82, L145-153). 매 빌드 `aprime_cc`로 regex_rt→`.o` 컴파일은 그 의존을 되살린다. 부차적으로 runtime.a 바이트가 빌드 컴파일러 버전에 종속돼 byteeq/재현성 관리 축이 하나 늘어난다. frozen-seed가 이 계열의 상위호환이므로 기각.

## 3. 채택안 상세 설계

### 3.1 신규 파일

**`tool/regen_regex_rt_native_s.sh`** — `regen_float_parse_hexinfnan_native_s.sh`를 복사해 다음만 바꾼다:

- `SRC` = 3파일: `stdlib/runtime/regex_rt.hexa stdlib/regex/thompson.hexa stdlib/regex/backtrack.hexa` (aprime 인자열이 파일 리스트를 받는 기존 형태 `"$APRIME" _drv.hexa --emit=asm --target=… -o out.s $SRC` 그대로; `use` import가 자동 해소되면 regex_rt 단독으로 족하나 — **검증항목 V1**, §6).
- 출력: `self/native/regex_rt_arm64.s` / `regex_rt_x86_64.s` / `regex_rt_arm64-linux.s`.
- **심볼 강등 post-pass (regex 고유 신규 단계)**: sed로 `.globl _?<sym>` 라인 중 `rt_regex_(match|match_full|search|findall|split|replace)`에 매치하지 않는 것을 전부 삭제 (darwin `_` 접두 포함 매치). 실측 근거: exact seed의 seed-내부 호출은 전부 직접 `call fpe_*`(61곳)이고 GOT/PLT 참조 0 → `.globl` 삭제만으로 같은-TU local label 해소가 성립한다.
- sanity 강화: (a) `.globl` 잔존 == 정확히 6, (b) cross-assemble 후 `nm`으로 6개 `T` + UND 집합에 **libc 심볼 무추가** assert (hexa 캐리어 `hexa_*`/`__hx_*`만 허용 — floor 축소가 목적이므로 이 assert가 본질 게이트).
- frozen 헤더에 SSOT 3파일 경로 + regen 커맨드 명기 (선례 포맷).

### 3.2 `tool/stage_resolve_runtime_a` 수정 (3곳)

1. **`resolve_native_regex_rt_seed()`** — hexinfnan 리졸버(L702-735) 복사:
   ```
   Phase A gate:  [ "${HEXA_REGEX_NATIVE:-0}" = "1" ] || return 0     # opt-IN, default-OFF
   seed 선택:     darwin-arm64 → self/native/regex_rt_arm64.s / linux-x86_64 → …_x86_64.s / linux-arm64 → …_arm64-linux.s
                  (tgt="${tgt%-musl}"; tgt="${tgt%-cuda}" 접미사 strip 선례 유지)
   SAFETY:        grep -cE '^\.globl[[:space:]]+_?rt_regex_(match|match_full|search|findall|split|replace)$' == 6
                  + grep -cE '^\.globl' == 6  (강등 누락 = 즉시 C-path fallback + 경고)
   assemble:      grep -vE '^// ' → $CC -c → build/regex_rt_native.o → export HEXA_REGEX_NATIVE=1
   ```
2. **컴파일-블록** (strtod L1238-1243 미러): ON + `.o` 존재 시 `rt_regex_def="-DHEXA_REGEX_NATIVE=1"` + `extra_obj="$extra_obj build/regex_rt_native.o"`. `rt_regex_def`는 **`runtime.c`를 컴파일하는 모든 지점**(단일-TU, MULTIOBJ의 runtime.o/runtime_core.o, CUDA의 `runtime_cuda_host.o`)에 다른 `rt_*_def`들과 같은 자리로 삽입 — CUDA host TU 누락 시 `runtime.cuda.a`만 libc-arm으로 갈라지는 skew가 생기므로 grep으로 삽입 지점 수를 기존 `rt_strtod_tail_def`와 일치시킬 것.
3. **호출부** (L2757 부근): `resolve_native_float_parse_hexinfnan_seed` 옆에 `resolve_native_regex_rt_seed` 추가.

`$extra_obj`가 세 archive 전부(L2593/2618/2626)에 이미 흐르고 CUDA 멤버-parity FATAL 체크(L2630)가 있으므로 archive 쪽 추가 수정은 없다.

### 3.3 기존 산출물과의 관계

- `self/runtime_emit_full.hexa` **수정 없음** — #4445 seam이 그대로 필요 형태다 (emitted C 텍스트는 flag 무관 불변; arm 선택은 컴파일-타임 `-D`).
- `compiler/main.hexa` import **유지** — 컴파일러 closure 링크에서는 closure 자신이 `rt_regex_*`를 정의하므로 `runtime.o`의 UND가 closure `.o`에서 먼저 해소되고, archive 멤버 pull 규칙상 seed 멤버는 당겨지지 않는다(중복 없음). standalone 링크에서만 seed가 당겨진다.
- `CHANGELOG.jsonl` 동반 갱신 (L0/게이트 파일 수정 규칙).

## 4. OFF-경로 byteeq-중립성 / ON flip 게이트

**Phase A (이번 PR, default-OFF)**: 리졸버 gate가 opt-IN(`:-0`)이므로 env 미설정 시 함수가 즉시 return — `-D` 없음, `extra_obj` 불변, `runtime.a` **바이트 동일**. emitted `runtime.c` 텍스트는 #4445에서 이미 OFF-중립 검증됨(regex 영역 191줄 0-diff). 신규 커밋 파일은 seed 3개 + regen 스크립트뿐. 게이트 = 통상 PR CI(변경 무해성) + pool 1회 `HEXA_REGEX_NATIVE=1` 수동 검증(§Phase B 전제).

**Phase B (flip PR, default-ON)**: 리졸버 gate만 뒤집는다 — `[ "${HEXA_REGEX_NATIVE:-x}" = "0" ] && return 0` (rt_hi Z2a의 opt-OUT 자동활성 패턴). seed 미존재/assemble 실패/강등-누락 시 C-path fallback 유지(#3583 교훈: no-seed fallback은 링크를 깨지 않는다). 이는 **RECONVERGE-flip**(runtime.o/runtime.a 바이트 변화, cc-genN 불변 — byteeq oracle인 `build_selfhost.sh`는 flag-free 자체 rt.o를 쓰므로 구조적으로 무관, 단 규정대로 실행) — 게이트 체크리스트:

1. byteeq 3-target GREEN (형식 요건 + 회귀 감지).
2. `nobaseline-gate` faithful GREEN ×3 타깃 — exit42/hello live-link + nm-UND 덤프에서 **regcomp/regexec/regfree 소멸 + 신규 libc UND 0** 캡처 (이 캡처가 flip의 존재 증명).
3. `grace_consent` consent-checker 링크 GREEN.
4. install.sh consumer smoke GREEN (3/3 규칙 — "only x86 green" 승격 금지).
5. **regex 정합성 corpus**: ON/OFF 차분을 glibc + Apple libc oracle 대비 실행 (FIX-B/C/D가 겨냥한 케이스: `(?i)`, `\d`-literal, backref/lookaround reject, `{n,m}` bt-route + findall/split/replace zero-width 루프). #4445 커밋이 "flip + corpus = follow-on"으로 명시적으로 미룬 부채이므로 flip PR의 필수 동반물.
6. `build_cuda_runtime` 경로: `runtime.cuda.a` 멤버-parity 로그에 `regex_rt_native.o` 포함 확인 (ar x stale 주의 — 기존 메모).

## 5. 크로스타깃 seed 해저드 (선제 조치)

1. **중복-심볼 (regex 고유 · 최대 리스크)**: strtod와 달리 seed의 backing(`stdlib/regex/thompson.hexa`)은 **사용자가 직접 import하는 공개 stdlib 모듈**이다. 실측상 hexa fn은 이름 그대로 전역 emit되므로(`fpe_*` 17개 `.globl` 증거), 강등 없이는 "사용자 프로그램이 thompson만 import(regex_rt 없이) + flip-ON runtime.a 링크" 시 `runtime.o`의 UND `rt_regex_*`가 seed 멤버를 당기고, seed의 `regex_compile` 등이 사용자 `.o`의 동명 정의와 **duplicate symbol**로 충돌한다. §3.1의 `.globl` 강등이 이를 원천 차단(외부 계약 = 6심볼뿐)하고, 리졸버의 `.globl==6` SAFETY가 강등 누락 seed를 거부한다.
2. **darwin `_` 접두**: emitted C의 `extern rt_regex_match` → Mach-O `_rt_regex_match`. aprime의 `arm64-apple-darwin` emit이 접두를 자체 처리(hexinfnan ABI 주석으로 확인)하므로 hand-sed 불요 — 단 강등 sed와 SAFETY grep은 `_?` 패턴으로 양쪽 매치.
3. **arm64-linux `@PAGE`→`:lo12:`**: 과거 seed에서 sed 교정이 필요했던 이슈지만, 현행 `regen_float_parse_hexinfnan_native_s.sh`는 `arm64-linux-gnu`를 sed 없이 직접 emit한다(교정 코드 부재 = 컴파일러가 해소했다는 증거). regen 스크립트의 cross-assemble sanity(`clang -target aarch64-linux-gnu -c`)가 잔존 회귀를 잡는다 — 유지.
4. **musl/cuda 타깃 변주**: `tgt="${tgt%-musl}"; tgt="${tgt%-cuda}"` strip을 리졸버에 그대로 복사 (ELF/SysV 공유 — 선례 주석 근거).
5. **seed 드리프트**: thompson/backtrack에 reference-match 수정이 들어가면 seed 3개 재생성이 필수인데 `.globl` 카운트로는 못 잡는다. regen 헤더에 SSOT 3파일의 내용 해시를 박고, 경량 lint(pre-commit ADVISORY — `stdlib/regex/*.hexa`·`regex_rt.hexa` 변경 + seed 미변경 시 경고)를 flip PR에 동반한다 (골든-드리프트 선례: num-float #3689).

## 6. 리스크 / 열린 질문 (pool 검증 항목)

- **V1 — 다중-파일 `--emit=asm`**: 기존 regen은 전부 단일-SSOT 파일이다. `aprime_cc`가 3파일 인자열(또는 `use` 자동 해소)로 하나의 `.s`를 내는지, `use` + 명시 인자 병용 시 이중 포함이 없는지 — aiden/summer에서 1회 emit으로 즉시 판정. 실패 시 대안: regex_rt만 인자로 주고 import 해소에 맡기거나, 3파일을 각각 emit해 3-멤버 `.o`로 ar (강등은 이 경우 **cross-`.o` 참조 심볼을 남겨야 하므로** 단일-`.s`가 강하게 선호됨 — 단일화가 안 되면 강등 대상을 "타 `.o`가 참조하지 않는 심볼"로 좁히는 재설계 필요).
- **V2 — HexaVal-boundary ABI**: `rt_regex_*`의 `-> bool`/`[int]`/`[[int]]`/`[string]`/`string` 네이티브 반환이 C `extern HexaVal` 경계로 박싱되는 규약(rt_to_bool 선례)이 **seed(.s) 경유에서도** 성립하는지 — #4445는 closure-링크 경유만 검증했다. exit42 + 6-fn 스모크(각 shim 1회 호출)로 판정. hxlcl pair-model ABI 벽(메모리)은 raw-C-ABI 케이스라 무관하지만, 확인 전 가정 금지.
- **V3 — 구조체/캐리어 내부성**: `Regex`/`BtProg` struct 전달·fn-value가 seed 내부에서만 오가는지 (강등 후 링크가 곧 증명 — 외부로 새는 참조가 있으면 UND로 드러남).
- **성능**: `_rt_re_ascii_fold`류의 byte-단위 `out + chr(c)` 연결은 할당-heavy지만 self-host closure는 regex 0회, 소비자 경로도 희소 — flip 게이트에 perf 항목은 두지 않되 faithful 빌드 시간 회귀만 관찰.
- **커밋 부피**: ~68k줄 frozen `.s` 3개는 저장소 최대 seed가 된다. 대안 축소(darwin만 우선 등)는 "3-target GREEN 아니면 승격 금지" 원칙과 충돌하므로 3개 동시 커밋이 맞다 — 부피는 수용.
- **`>50줄 삭제` 가드/WIPE-OK**: 본 설계는 순-추가라 해당 없음. flip PR도 emitter 삭제가 없다(리졸버 gate 1줄 전환).

## 7. 산출물 요약 (구현 단위)

| PR | 내용 | 게이트 |
|---|---|---|
| **PR-A (배선, default-OFF)** | `tool/regen_regex_rt_native_s.sh` 신규 · `self/native/regex_rt_{arm64,x86_64,arm64-linux}.s` 3 seed 커밋 · `stage_resolve_runtime_a` 리졸버+`-D`+`extra_obj`(opt-IN) · CHANGELOG | byteeq-중립(무설정 시 바이트 불변) + pool에서 `HEXA_REGEX_NATIVE=1` 수동: consent-link·exit42·6-fn 스모크 캡처 |
| **PR-B (flip, default-ON)** | 리졸버 gate opt-IN→opt-OUT 1줄 · regex corpus 추가 · seed-드리프트 ADVISORY lint | byteeq 3-target + faithful-nobaseline ×3 (regcomp/regexec/regfree 소멸 캡처) + consent + install smoke + corpus GREEN |

핵심 한 줄: **strtod가 이미 닦아 놓은 frozen-`.s`→`extra_obj`→`runtime.a` 고속도로를 그대로 타되, regex만의 신규 위험(공개 stdlib 모듈이 seed 안에 통째로 들어와 생기는 ~80개 전역 심볼)을 `.globl` 강등으로 6-심볼 계약으로 봉인한다.**