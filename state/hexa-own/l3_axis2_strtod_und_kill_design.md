# L3 axis-② — strtod residual-UND kill 정밀 설계 (default-OFF byteeq-neutral)

날짜: 2026-07-17 · 대조: origin/main 1ea66c15e (self/*emit* 3파일은 로컬 HEAD와 diff ∅ = 동일)
게이트 제안: **신규 `HEXA_RT_STRTOD_DROP`** (opt-in, default-OFF)

## 1. strtod UND의 실제 소유 사이트 규명 (검증 결과)

**출하 TU의 살아있는 `strtod(` 호출 = 4사이트** (과제 전제 "3사이트"는 부정확):

| # | emitter:line | 방출 TU | 방출문맥 | 컴파일 조건 |
|---|---|---|---|---|
| S1 | `self/runtime_emit_full.hexa:5240` | runtime.c → runtime.o | `hexa_str_parse_float` | `#ifndef HEXA_HAS_HEXA_RT_STDLIB` — 출하는 이 매크로 **미정의**(stage_resolve:2186 "no HEXA_HAS_HEXA_RT_STDLIB on either TU") → **항상 컴파일** |
| S2 | `self/runtime_emit_full.hexa:14451` | runtime.c → runtime.o | `_shortest_double` C fallback 루프 | **무조건 컴파일** — 네이티브 arm(:14426 `#if defined(HEXA_RT_FORMAT_FLOAT_NATIVE) && defined(HEXA_RT_NUM_PARSE_FLOAT_EXACT)`)은 `#endif`로 닫힐 뿐, 그 아래 strtod 루프는 ON 빌드에서도 텍스트로 남는다. ":14422 dropping … strtod" 주석은 **실행경로** 얘기지 심볼 드롭이 아님 |
| S3 | `self/runtime_core_emit.hexa:8248` | runtime_core.c → runtime_core.o(MULTIOBJ) | `__hexa_format_float_mode` NATIVE arm의 sentinel→strtod 역파스 | `#ifdef HEXA_RT_FORMAT_FLOAT_NATIVE` 안 — 출하 3-seed 타깃 **default-ON** → 컴파일됨 |
| S4 | `self/runtime_core_emit.hexa:8261` | runtime_core.c → runtime_core.o | `__hexa_format_float_mode` REPR_SHORTEST 루프 | **무조건 컴파일** (`HEXA_FLOAT_REPR=shortest` 런타임 도달 가능) |

(제5의 `self/runtime_emit.hexa:348`은 **비출하** — 파일 헤더 명시 "compiled and linked ONLY under the experimental HEXA_ZEROC_DROP_RUNTIME drop path; the DEFAULT / shipping build NEVER compiles this seed". 스코프 외.)

**핵심 판정 — 과제의 ③(`__hexa_num_parse_float` fall-back)은 strtod UND를 지지 않는다 (FALSIFIED):**
- `runtime_core_emit.hexa:2160`의 fall-back은 `hxlcl_atof(cs)` 호출. `hxlcl_atof`는
  - MULTIOBJ 출하: hxlcl_shim.o의 `double hxlcl_atof(const char *s){ return s ? atof(s) : 0.0; }` (`runtime_core_hxlcl_shim_emit.hexa:866`) → 심볼은 **`U atof`** (glibc 내부에서 strtod를 쓰든 말든 아카이브 UND는 atof).
  - 단일-TU: runtime.c의 **static naive** 바디(`runtime_emit_full.hexa:3135`, `#define atof(s) hxlcl_atof(...)` :2909 리다이렉트 존) → libc UND **없음**.
- 따라서 `HEXA_RT_STRTOD_TAIL_NATIVE=1`이든 0이든 **fall-back 경로에서 strtod 심볼 참조는 발생하지 않는다**. strtod-tail 게이트는 "strtod가 서빙하던 입력 도메인"을 네이티브로 옮기는 **행동 계층**이지, 심볼 킬 게이트가 아니다.
- 실물 방증(로컬 darwin 설치본 v0.574.1, 단일-TU shape, stale하지만 형상 확인용): `nm -A ~/.hx/bin/build/runtime.a` → `runtime.o: U _strtod` **정확히 1건**, atof UND **0건**(hxlcl_atof는 `t` local). MULTIOBJ 출하(linux, #4962 확인)에서는 runtime.o(S1·S2)+runtime_core.o(S3·S4) 두 멤버가 U strtod, shim.o가 U atof를 진다.

## 2. 게이트 판정: 기존 게이트 재사용 **불가** → 신규 `HEXA_RT_STRTOD_DROP`

`HEXA_RT_STRTOD_TAIL_NATIVE`(:1298 `:-1` **default-ON**) · `HEXA_RT_NUM_PARSE_FLOAT_EXACT` · `HEXA_RT_FORMAT_FLOAT_NATIVE` · `HEXA_RT_NUM_PARSE_FLOAT_NATIVE` 전부 **출하 default-ON**(seed 존재 시). 이들에 새 arm을 걸면 출하 기본형이 즉시 바뀜 = **byte-CHANGING**. default-OFF byteeq-neutral을 지키려면 신규 매크로가 필수. 신규 게이트는 3-seed 전제 위에서만 켜지게 배선(아래 §5) — extern `rt_*`가 아카이브 내부(num_float_core_native.o / float_parse_exact_native.o / float_parse_hexinfnan_native.o — 전부 이미 출하 ar 멤버·armap 등재 심볼)에서 해소됨을 보장.

## 3. bit-exact 판정 (사이트별)

- **S2·S3·S4 (round-trip 검증 사이트)**: 입력은 항상 `%.*g`(snprintf 또는 rt_format_float_native)의 출력 = 유한 십진 텍스트. `rt_str_parse_float_exact`는 "bit-exact to strtod over the full finite-decimal domain"(#4200; float_parse_exact.hexa:340 계열, decline 조건 = 숫자無/이중점/빈지수/후행junk 뿐). 유한 f에 대해 **결코 decline하지 않음** → round-trip 판정 동일 → 출력 문자열 byte-identical. inf/nan 텍스트가 도달하는 유일 케이스(S2, `_js_emit_value`가 ±inf를 안 거름): exact가 decline → 매 p 불일치 → 종단 `%.17g` = `"inf"` — **기존 경로도 p=1에서 "inf"를 반환**하므로 최종 buf 내용 동일. ⇒ **S2·S3·S4는 ON에서도 byte-exact.** decline arm의 `rp=0.0`은 fail-OPEN(불일치→다음 p→종단 %.17g는 항상 round-trip)이며 f≠0.0 보장(정수값 float는 caller가 선처리).
- **S1 (`hexa_str_parse_float` = 진짜 파서)**: 단순 치환은 **bit-exact 아님** — 3-tier(fast/exact/hexinfnan)는 **후행 junk가 붙은 십진 토큰을 decline**한다(num_float_core.hexa:197-207 "trailing bytes remain → bail"; float_parse_exact.hexa:403). strtod는 **최장 유효 prefix**를 파스("3.14abc"→3.14). naive `hxlcl_atof` tail은 정확반올림이 아니라서 답이 아님. **fix = C17 7.22.1.3 subject-prefix 스캐너**(순수 바이트 로직, libc 0)로 최장 prefix를 뽑아 NUL-복사 후 체인 재실행 → 모든 입력에서 strtod와 bit-exact. hex/inf/nan의 prefix-junk는 hexinfnan tier가 자체 처리(float_parse_hexinfnan.hexa:236-241 — "0x10"→16.0·"0x1pz"→1.0, #4645 Family-B, corpus n=140,678 T_mis=0)이므로 스캐너는 사실상 십진-junk·\v\f-선행 입력용 cold path. 스캐너에 hex/inf/nan 문법도 넣어 tier 내부 동작에 비의존.

## 4. emit-C 편집 (old→new, 전부 4-space `    buf = buf + "…"` · `//`만 · 이스케이프 `\n \t \" \\`(+`\\v` `\\f`=백슬래시 리터럴) · 신규 #define 없음)

### 4a. S1 헬퍼 — `self/runtime_emit_full.hexa` :5232(빈줄 emit) 직후 삽입

```hexa
    buf = buf + "// axis-2 strtod UND-kill (HEXA_RT_STRTOD_DROP, default-OFF): native\n"
    buf = buf + "// parse chain + C17 7.22.1.3 subject-prefix scanner. Chain tiers are\n"
    buf = buf + "// bit-exact to strtod on their domains but decline decimal tokens with\n"
    buf = buf + "// trailing junk; the scanner extracts the longest strtod subject prefix\n"
    buf = buf + "// (dangling-exponent backtrack included) so the retry reproduces strtod\n"
    buf = buf + "// prefix semantics, correctly rounded.\n"
    buf = buf + "#ifdef HEXA_RT_STRTOD_DROP\n"
    buf = buf + "extern HexaVal rt_parse_float_native(HexaVal s);\n"
    buf = buf + "extern HexaVal rt_str_parse_float_exact(HexaVal s);\n"
    buf = buf + "extern HexaVal rt_str_parse_float_hexinfnan(HexaVal s);\n"
    buf = buf + "static HexaVal __hx_parse_float_chain(HexaVal sv) {\n"
    buf = buf + "    HexaVal r = rt_parse_float_native(sv);\n"
    buf = buf + "    if (HX_TAG(r) != TAG_FLOAT) r = rt_str_parse_float_exact(sv);\n"
    buf = buf + "    if (HX_TAG(r) != TAG_FLOAT) r = rt_str_parse_float_hexinfnan(sv);\n"
    buf = buf + "    return r;\n"
    buf = buf + "}\n"
    buf = buf + "// Longest C-strtod subject sequence: ws* sign? (hex|decimal|inf|nan).\n"
    buf = buf + "// *pstart = post-ws token start, *pend = one past the accepted prefix;\n"
    buf = buf + "// *pstart == *pend means no conversion (strtod returns 0.0 there).\n"
    buf = buf + "static void __hx_strtod_prefix_scan(const char* s, unsigned long* pstart, unsigned long* pend) {\n"
    buf = buf + "    unsigned long i = 0;\n"
    buf = buf + "    while (s[i] == ' ' || s[i] == '\\t' || s[i] == '\\n' || s[i] == '\\v' || s[i] == '\\f' || s[i] == '\\r') i++;\n"
    buf = buf + "    *pstart = i; *pend = i;\n"
    buf = buf + "    if (s[i] == '+' || s[i] == '-') i++;\n"
    buf = buf + "    unsigned long dstart = i;\n"
    buf = buf + "    if ((s[i] == 'i' || s[i] == 'I') && (s[i+1] == 'n' || s[i+1] == 'N') && (s[i+2] == 'f' || s[i+2] == 'F')) {\n"
    buf = buf + "        unsigned long e = i + 3;\n"
    buf = buf + "        if ((s[e] == 'i' || s[e] == 'I') && (s[e+1] == 'n' || s[e+1] == 'N') && (s[e+2] == 'i' || s[e+2] == 'I') && (s[e+3] == 't' || s[e+3] == 'T') && (s[e+4] == 'y' || s[e+4] == 'Y')) e = e + 5;\n"
    buf = buf + "        *pend = e; return;\n"
    buf = buf + "    }\n"
    buf = buf + "    if ((s[i] == 'n' || s[i] == 'N') && (s[i+1] == 'a' || s[i+1] == 'A') && (s[i+2] == 'n' || s[i+2] == 'N')) {\n"
    buf = buf + "        unsigned long e = i + 3;\n"
    buf = buf + "        if (s[e] == '(') {\n"
    buf = buf + "            unsigned long j = e + 1;\n"
    buf = buf + "            while ((s[j] >= '0' && s[j] <= '9') || (s[j] >= 'a' && s[j] <= 'z') || (s[j] >= 'A' && s[j] <= 'Z') || s[j] == '_') j++;\n"
    buf = buf + "            if (s[j] == ')') e = j + 1;\n"
    buf = buf + "        }\n"
    buf = buf + "        *pend = e; return;\n"
    buf = buf + "    }\n"
    buf = buf + "    int hex = 0;\n"
    buf = buf + "    if (s[i] == '0' && (s[i+1] == 'x' || s[i+1] == 'X')) { hex = 1; i = i + 2; }\n"
    buf = buf + "    unsigned long ndig = 0; int dot = 0;\n"
    buf = buf + "    while (1) {\n"
    buf = buf + "        char c = s[i];\n"
    buf = buf + "        int isd = hex ? ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) : (c >= '0' && c <= '9');\n"
    buf = buf + "        if (isd) { ndig++; i++; continue; }\n"
    buf = buf + "        if (c == '.' && !dot) { dot = 1; i++; continue; }\n"
    buf = buf + "        break;\n"
    buf = buf + "    }\n"
    buf = buf + "    if (ndig == 0) {\n"
    buf = buf + "        // \"0x\"/\"0x.\" with no hexdigit: strtod converts just the \"0\".\n"
    buf = buf + "        if (hex) *pend = dstart + 1;\n"
    buf = buf + "        return;\n"
    buf = buf + "    }\n"
    buf = buf + "    unsigned long e2 = i;\n"
    buf = buf + "    char lo = hex ? 'p' : 'e'; char up = hex ? 'P' : 'E';\n"
    buf = buf + "    if (s[e2] == lo || s[e2] == up) {\n"
    buf = buf + "        unsigned long j = e2 + 1;\n"
    buf = buf + "        if (s[j] == '+' || s[j] == '-') j++;\n"
    buf = buf + "        if (s[j] >= '0' && s[j] <= '9') { while (s[j] >= '0' && s[j] <= '9') j++; i = j; }\n"
    buf = buf + "    }\n"
    buf = buf + "    *pend = i;\n"
    buf = buf + "}\n"
    buf = buf + "#endif\n"
    buf = buf + "\n"
```

스캐너 검산: `" 3.14abc"`→"3.14" · `"1e+"`→"1"(빈지수 backtrack) · `"1e+5x"`→"1e+5" · `"1.2.3"`→"1.2" · `"+.e3"`→무변환(0.0) · `"0xz"`→"0" · `"-0x."`→"-0" · `"infinityz"`→"infinity" · `"nan(q)x"`→"nan(q)" · `"nan("`→"nan" — 전부 glibc strtod endptr 규칙과 일치.

### 4b. S1 본체 — :5240 교체

old:
```hexa
    buf = buf + "    return hexa_float(strtod(HX_STR(s), NULL));\n"
```
new:
```hexa
    buf = buf + "#ifdef HEXA_RT_STRTOD_DROP\n"
    buf = buf + "    {\n"
    buf = buf + "        const char* cs = HX_STR(s);\n"
    buf = buf + "        if (!cs) return hexa_float(0.0);\n"
    buf = buf + "        HexaVal r = __hx_parse_float_chain(s);\n"
    buf = buf + "        if (HX_TAG(r) == TAG_FLOAT) return hexa_float(HX_FLOAT(r));\n"
    buf = buf + "        // chain declined: ws-led / trailing-junk / partial token. Extract\n"
    buf = buf + "        // the strtod subject prefix and retry on a NUL-terminated copy\n"
    buf = buf + "        // (cold path; never mutates the source string).\n"
    buf = buf + "        unsigned long ps = 0, pe = 0;\n"
    buf = buf + "        __hx_strtod_prefix_scan(cs, &ps, &pe);\n"
    buf = buf + "        if (pe <= ps) return hexa_float(0.0);\n"
    buf = buf + "        unsigned long pl = pe - ps;\n"
    buf = buf + "        char stk[64]; char* pb = stk;\n"
    buf = buf + "        if (pl + 1 > sizeof(stk)) { pb = (char*)hxlcl_malloc(pl + 1); if (!pb) return hexa_float(0.0); }\n"
    buf = buf + "        hxlcl_memcpy(pb, cs + ps, pl); pb[pl] = 0;\n"
    buf = buf + "        r = __hx_parse_float_chain((HexaVal){.tag = TAG_STR, .s = pb});\n"
    buf = buf + "        double out = (HX_TAG(r) == TAG_FLOAT) ? HX_FLOAT(r) : 0.0;\n"
    buf = buf + "        if (pb != stk) hxlcl_free(pb);\n"
    buf = buf + "        return hexa_float(out);\n"
    buf = buf + "    }\n"
    buf = buf + "#else\n"
    buf = buf + "    return hexa_float(strtod(HX_STR(s), NULL));\n"
    buf = buf + "#endif\n"
```
(`(HexaVal){.tag=TAG_STR,.s=…}` 리터럴은 runtime.c 기존 관용구 :7034/:7083/:9005. `hxlcl_malloc/memcpy/free`는 이 지점에서 선언 완료(리다이렉트 존 :2935 이전 전방선언). `!cs` 가드는 기존 strtod(NULL) UB-crash 경로의 방어적 대체 — 실도달 불가.)

### 4c. S2 — :14451 교체

old:
```hexa
    buf = buf + "        if (strtod(buf, NULL) == f) return;\n"
```
new:
```hexa
    buf = buf + "#ifdef HEXA_RT_STRTOD_DROP\n"
    buf = buf + "        // axis-2 strtod UND-kill: buf is snprintf %.*g output. Finite ->\n"
    buf = buf + "        // EXACT parse is bit-exact strtod (#4200); inf/nan text declines ->\n"
    buf = buf + "        // no early return -> the terminal %.17g emits the same bytes.\n"
    buf = buf + "        {\n"
    buf = buf + "            extern HexaVal rt_str_parse_float_exact(HexaVal s);\n"
    buf = buf + "            HexaVal rv = rt_str_parse_float_exact((HexaVal){.tag = TAG_STR, .s = buf});\n"
    buf = buf + "            if (HX_TAG(rv) == TAG_FLOAT && HX_FLOAT(rv) == f) return;\n"
    buf = buf + "        }\n"
    buf = buf + "#else\n"
    buf = buf + "        if (strtod(buf, NULL) == f) return;\n"
    buf = buf + "#endif\n"
```
(runtime.c에는 `HX_MAKE_STR` 없음(runtime_core.c :1543 전용·MULTIOBJ는 `-DHEXA_ZEROC_DROP_RTCORE_INCLUDE`로 미포함) → 컴파운드 리터럴 사용.)

### 4d. S3 — `self/runtime_core_emit.hexa` :8248 교체

old:
```hexa
    buf = buf + "            double rp = (HX_TAG(pv) == TAG_FLOAT) ? HX_FLOAT(pv) : strtod(HX_STR(r), NULL);\n"
```
new:
```hexa
    buf = buf + "#ifdef HEXA_RT_STRTOD_DROP\n"
    buf = buf + "            // axis-2 strtod UND-kill: r is native %.*g text of a FINITE f\n"
    buf = buf + "            // (NaN/inf filtered by callers) -> EXACT parse never declines\n"
    buf = buf + "            // (#4200); the 0.0 arm fails OPEN (mismatch -> next p).\n"
    buf = buf + "            double rp;\n"
    buf = buf + "            if (HX_TAG(pv) == TAG_FLOAT) { rp = HX_FLOAT(pv); }\n"
    buf = buf + "            else {\n"
    buf = buf + "                extern HexaVal rt_str_parse_float_exact(HexaVal s);\n"
    buf = buf + "                HexaVal ev = rt_str_parse_float_exact(r);\n"
    buf = buf + "                rp = (HX_TAG(ev) == TAG_FLOAT) ? HX_FLOAT(ev) : 0.0;\n"
    buf = buf + "            }\n"
    buf = buf + "#else\n"
    buf = buf + "            double rp = (HX_TAG(pv) == TAG_FLOAT) ? HX_FLOAT(pv) : strtod(HX_STR(r), NULL);\n"
    buf = buf + "#endif\n"
```

### 4e. S4 — :8261 교체

old:
```hexa
    buf = buf + "        double rp = strtod(buf, NULL);\n"
```
new:
```hexa
    buf = buf + "#ifdef HEXA_RT_STRTOD_DROP\n"
    buf = buf + "        // axis-2 strtod UND-kill: buf = snprintf %.*g of a FINITE double\n"
    buf = buf + "        // (callers filter NaN/inf) -> EXACT parse == strtod bit-exact\n"
    buf = buf + "        // (#4200); decline fails OPEN to 0.0 (bit-mismatch -> next p).\n"
    buf = buf + "        double rp;\n"
    buf = buf + "        {\n"
    buf = buf + "            extern HexaVal rt_str_parse_float_exact(HexaVal s);\n"
    buf = buf + "            HexaVal ev = rt_str_parse_float_exact(HX_MAKE_STR(buf));\n"
    buf = buf + "            rp = (HX_TAG(ev) == TAG_FLOAT) ? HX_FLOAT(ev) : 0.0;\n"
    buf = buf + "        }\n"
    buf = buf + "#else\n"
    buf = buf + "        double rp = strtod(buf, NULL);\n"
    buf = buf + "#endif\n"
```

## 5. tool/stage_resolve_runtime_a 배선

`rt_strtod_tail_def` 블록(:2087-2092) 직후 삽입:

```sh
    # axis-2 strtod UND-KILL (HEXA_RT_STRTOD_DROP, opt-IN default-OFF): swap the 4
    # direct strtod( sites (runtime.c hexa_str_parse_float + _shortest_double,
    # runtime_core.c __hexa_format_float_mode x2) to the native parse chain. Requires
    # ALL THREE float seeds resolved (fast+EXACT+hexinfnan) so the extern rt_* resolve
    # archive-internally. Unset -> def empty -> the emitter #ifdef arms are dead ->
    # runtime.o/runtime_core.o byte-identical (byteeq-NEUTRAL).
    local rt_strtod_drop_def=""
    if [ "${HEXA_RT_STRTOD_DROP:-0}" = "1" ]; then
        if [ -n "$rt_numf_def" ] && [ -n "$rt_numf_exact_def" ] && [ -n "$rt_strtod_tail_def" ]; then
            rt_strtod_drop_def="-DHEXA_RT_STRTOD_DROP=1"
            echo "[stage_resolve_runtime_a] axis-2 STRTOD-DROP: HEXA_RT_STRTOD_DROP=1 - 4 strtod( sites -> native chain"
        else
            echo "[stage_resolve_runtime_a] axis-2 STRTOD-DROP: HEXA_RT_STRTOD_DROP=1 IGNORED - needs NUM_PARSE_FLOAT_NATIVE+EXACT+STRTOD_TAIL seeds active" >&2
        fi
    fi
```

`$rt_strtod_drop_def`를 `$rt_strtod_tail_def` 바로 뒤에 **5개 컴파일 라인 전부** 추가: :4267(MULTIOBJ runtime.o) · :4272(MULTIOBJ runtime_core.o) · :4359(MULTIOBJ CUDA host) · :4379(단일-TU runtime.o) · :4387(단일-TU CUDA). CUDA 누락 = regex-flip 회귀(#4451)와 같은 스큐이므로 필수. `build_aprime.sh`는 stage_resolve 위임(:140)이라 추가 배선 불요(#4969 seed-skew 재발 없음).

## 6. byteeq 판정 (1줄)

**게이트 unset ⇒ `rt_strtod_drop_def=""` ⇒ 5개 TU 전부 -D 부재 ⇒ 신규 #ifdef 4블록+헬퍼2는 전처리 소거·`#else` arm은 현행과 문자열 동일 ⇒ runtime.o/runtime_core.o/runtime.a 3-target byte-identical (동일 파일 default-OFF 게이트-블록 삽입 선례 #4646/#4651/#4856 GREEN; 단 byteeq 비교는 같은 cwd에서 — DWARF-cwd 아티팩트 주의).**

## 7. ON-path 검증 (aiden-only)

1. `HEXA_RT_STRTOD_DROP=1 HEXA_RT_MULTIOBJ=1 bash tool/stage_resolve_runtime_a` 후:
   `nm -A build/runtime.a | grep -w strtod` → **UND 0** (특히 runtime.o·runtime_core.o 멤버). shim.o의 `U atof`는 잔존(별도 축 — `HEXA_RT_NATIVE_ATOF` 소관, 이번 스코프 아님).
2. #4651 parity corpus 재실행(n=140,678): parse_float 표면 + repr round-trip **T_mis=0** 요구.
3. 신규 prefix-junk corpus vs glibc strtod A/B: `"3.14abc"` `" \v1e5x"` `"1e+"` `"0x1p"` `"0x."` `"0xz"` `"infinityz"` `"nan(q)x"` `"nan("` `"."` `"+.e3"` `"1.2.3"` + 800자리 subnormal+junk — **bit-diff 0** 요구 (특히 스캐너 문법·hexinfnan의 p-없는 hex 수용은 소스 주석 근거이므로 corpus가 최종 판정).
4. RUN A/B: `HEXA_RT_STRTOD_DROP=1` vs `=0` — stdlib selftest + json stringify 스위트 stdout **byte-diff 0**.
5. 머지 게이트: default-OFF 상태 byteeq 3-target GREEN + shipping smoke → (이후 별도 라운드) default-ON RECONVERGE-flip은 1–4 GREEN 후.

## 8. honest-negative / 리스크 명시

- **"3사이트 단순 치환"은 UND를 못 없앤다** — S2는 이미 native arm이 있어도 `#endif` 뒤 C 루프가 무조건 컴파일되고, S4는 과제 목록에 아예 없던 4번째 사이트다. 그리고 ③(fall-back)은 strtod가 아니라 **atof**를 진다(§1).
- S1 without 스캐너(체인만+atof/naive tail)는 prefix-junk 입력에서 **byte-CHANGING** — 그래서 스캐너가 설계의 필수 요소.
- `HEXA_RT_NATIVE_ATOF=1`(별도 게이트, naive 바디)와의 상호작용: 그 플립은 `hxlcl_atof` 정확도를 떨어뜨리는 별도 문제이며 이 설계는 hxlcl_atof에 새 의존을 만들지 않음(S1 tail은 자체 체인).
- 스캐너는 C 로케일 전제(hexa 런타임은 setlocale 안 함 — strtod와 동일 조건).
- `self/runtime_emit.hexa:348`(비출하 실험 lane)은 미편집 — 그 lane을 출하로 승격하는 날 미러 필요.
- 검증 없이 단정하지 않은 것: hexinfnan의 p-없는 hex/hex-prefix-junk 수용(:236-241 주석+#4645 corpus 근거·소스 재확인함), exact의 %g-출력 전역 무-decline(#4200 주석 근거) — 둘 다 §7-2/3 corpus가 실측 판정.
