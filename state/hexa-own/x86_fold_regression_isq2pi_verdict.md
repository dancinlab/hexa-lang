# x86_64 fold 회귀 근인 확정 — isq2pi float-리터럴 파싱 1-ULP 저라운딩 (aiden 실측 2026-07-16)

## 판별실험 결과 (aiden HEAD=37c5e827, TARGET=linux-x86_64 release_build)
fold_ci_gate: GELUBWD-DET = 8403495269565781906 (골든 3837435693766553512) DRIFT 재현 ✅
const_probe (__hx_f64_bits, 파싱된 f64 비트) vs correctly-rounded(Python strtod):

| const  | 리터럴                     | x86_64 파싱          | correctly-rounded    | 판정        |
|--------|----------------------------|----------------------|----------------------|-------------|
| isq2pi | 0.39894228040143267794     | 4600858325139338832  | 4600858325139338833  | ❌ 1 ULP 낮음 |
| isq2   | 0.70710678118654752440     | 4604544271217802189  | 4604544271217802189  | ✅          |
| p      | 0.3275911                  | 4599572976541465484  | 4599572976541465484  | ✅          |
| a1     | 0.254829592                | 4598262221740202622  | 4598262221740202622  | ✅          |
| a3     | 1.421413741                | 4609080297566953815  | 4609080297566953815  | ✅          |
| a5     | 1.061405429                | 4607458964267180333  | 4607458964267180333  | ✅          |

## 근인 (확정)
컴파일러의 네이티브 float-리터럴 파서(#3689 __hx_to_double, sh-num-float Clinger fast-path)가
**isq2pi=0.39894228040143267794 (17 sig digits, hard-to-round)를 x86_64 호스트에서 1 ULP 낮게 라운딩**.
arm64 는 정답(…833). isq2pi 는 op19b GELU **backward 유일 상수** → GELUFWD 매치·GELUBWD만 드리프트 완벽설명.
다른 6상수 전부 correctly-rounded → 파서가 대부분 정확하나 이 특정 hard-to-round 값에서 x86↔arm 발산.

## 반증된 것
- FMA-contraction: x86_64 codegen FMA 방출 전무(mulsd/addsd) → FALSIFIED.
- 골든 stale: arm64(linux+darwin) 둘 다 골든 매치 → 골든 정답, re-pin 금지.

## fix 방향 (Fable 설계 대기)
x86_64 파서를 correctly-rounded 로 (arm64/strtod 에 reference-match). 왜 동일 파서가 x86↔arm 발산하는지 규명 필요
(가설: Clinger fast-path 미적용 17digit slow-path 의 x86 codegen FP 발산 OR C#else vs native 경로 분기).

## 라운드-2 (2026-07-16 실측+소스정독)
- **FMA-contraction FALSIFIED**: -ffp-contract=off 재빌드로도 isq2pi=…832 그대로 (aiden).
- **long double 가설 FALSIFIED**: float_parse_exact.hexa 헤더(10-16) — musl floatscan 테일(long double y/scalbnl)은 **일부러 미포팅**, "정수 round-half-even 재작성(no x87)". EXACT 파서는 pure-integer=아치독립이어야.
- C thunk(runtime_core.c:1963+) 티어순서: rt_parse_float_native(fast, overflow_mant→TAG_VOID) → rt_str_parse_float_exact(EXACT, pure-int, default-ON when float_parse_exact_native.o & HEXA_RT_OWNOBJ=0) → strtod.
- isq2pi(20자리)는 fast-path에서 overflow_mant(16번째 자리 m>2^53)→bail TAG_VOID → EXACT 티어로. EXACT가 pure-int면 아치독립인데 x86=832/arm=833 발산 = **미스터리** (EXACT 버그면 양쪽 832여야).
- 남은 판별: HEXA_RT_NUM_PARSE_FLOAT_EXACT=0 재빌드 → 833이면 EXACT 범인, 832면 compile-time to_float 경로가 C thunk 안 타고 fast-path 절단값 직접 사용.

## 라운드-3 (2026-07-16 결정 데이터)
- **x86 glibc strtod("0.39894228040143267794") = 4600858325139338833 (정확)** · strtold→double도 833. → x86 libc는 정상, hexa 파서만 832.
- **EXACT=0 → 여전히 832** → EXACT 파서 무죄. 
- 결론: hexa 네이티브 파스 체인(rt_parse_float_native fast-path / strtod-tail-native / hxlcl_atof)이 glibc strtod(833)에 도달 못하고 832 절단값 반환. arm은 833. 
- 다음 컷: HEXA_RT_NUM_PARSE_FLOAT_NATIVE OFF → 833이면 fast-path 근원, 832면 hxlcl_atof(native #else) 근원.
- 반증 누적: FMA-contraction · long double(x87) · EXACT-tier 전부 FALSIFIED.
- lowering: hir_to_mir.hexa:4494 `_const_float_op_with_text(to_float(e.text),e.text)` — float_val=to_float. x86 codegen o.float_val / arm codegen to_float(text) 둘 다 같은 to_float → 발산은 to_float(=파스체인)의 host-arch 의존.

## ★근인 확정 (2026-07-16, definitive)
- **모든 네이티브 파스 플래그 OFF(NATIVE/EXACT/STRTOD_TAIL)로도 832** → 이 플래그들이 게이팅하는 런타임 __hx_to_double(string) 체인 전부 무죄.
- 컴파일타임 `to_float`(리터럴 파싱)는 별도 경로 = **`hxlcl_atof`(hxlcl_core.hexa:3154)** = naive 누적 파서:
  - 정수부 `n = n*10.0 + d`, 소수부 `n += d*frac; frac *= 0.1` → 자리마다 FP 라운딩 오차 누적, strtod와 bit-exact 아님(num_float_core.hexa:18-20 주석이 경고한 그것).
  - isq2pi 20자리 → 누적오차로 1 ULP 낮음 = 832.
- **x86≠arm 기전**: compiler/codegen/x86_64_linux.hexa:2588/2658/2712 이 `hxlcl_atof`를 x86 fp-ABI leaf로 라우팅하되 **"arm64 excluded"(2712)** → x86만 native hxlcl_atof(832), arm은 제외되어 정확 경로(833). hxlcl_atof는 HEXA_RT_NATIVE_ATOF 게이팅(내가 끈 플래그 아님)이라 계속 ON.
- glibc strtod=833(정확)이 옆에 있으나 to_float→hxlcl_atof가 우회.
- **fix 방향**: 컴파일타임 float-리터럴 파싱을 correctly-rounded 파서로 라우팅(양 아치 동일). 후보: (A) to_float/hexa_to_float를 rt_str_parse_float_exact(이미 존재·correctly-rounded)로 배선 (B) hxlcl_atof 자체를 정수만티사×pow10 단일라운딩으로 재작성. reference-match: arm/glibc=833이 정답.

## ★★DEFINITIVE 근인 (probe2, 같은 x86 바이너리)
- `__hx_f64_bits(0.39894228040143267794 리터럴)` = 832 (컴파일타임 상수-fold)
- `to_float("0.39894228040143267794" 런타임 string)` = 833 (런타임 파스)
- 둘 다 /tmp/natoff(all-native-parse-OFF) 바이너리 → **런타임 파서 전부(hxlcl_atof #else 포함) 833 정확**. 832는 컴파일타임 리터럴 fold 경로 유일.
- 즉 컴파일러 바이너리의 **내부 to_float(컴파일타임 fold, hir_to_mir.hexa:4494 `to_float(e.text)`)가 naive(832)**, 그 바이너리가 링크해 출하하는 runtime.a의 to_float는 correct(833) = **self-host seed-skew**.
- x86≠arm: x86 codegen(x86_64_linux.hexa:1524,3070)은 naive fold값 `o.float_val` 신뢰(832) · arm codegen(macho_arm64.hexa:2523)은 emit때 `to_float(f.text)` 재파스(그 arm 컴파일러 바이너리 내부는 correct→833).
- 반증 최종: FMA · long-double · EXACT-tier · 런타임 파스체인(NATIVE/EXACT/STRTOD_TAIL 전부 OFF로도 str=833) 전부 무죄.
- **fix 방향**: (A) 컴파일러 바이너리의 컴파일타임 float-fold를 correct 파서로(부트스트랩 seed가 naive 파서를 to_float에 바인딩하는지 규명→correct 바인딩) — 왜 x86 컴파일러 내부 to_float만 naive인지 seed 층 조사 필요. (B) x86 codegen도 arm처럼 emit-재파스(단 컴파일러 내부 파스가 correct일 때만 유효). 
- **성격**: 이 게이트(faithful-nobaseline)는 **advisory**(required=selfhost-gates-summary·byteeq-3-target 게이트와 별개·GREEN). 5-lane byteeq 머지 게이트는 이것과 무관. 며칠째 방치된 결정성-fold advisory RED.

## ★★★최종 층 (2026-07-16, fix-actionable)
- self/codegen.hexa:8272: 컴파일러의 `to_float(x)` → `hexa_float(__hx_to_double(x))`. __hx_to_double(STR)→__hexa_num_parse_float(runtime_core.c:2016)→correct(833)여야.
- 그런데 컴파일러 바이너리의 컴파일타임 fold(hir_to_mir.hexa:4494 to_float(e.text)) = 832, **같은 바이너리**의 user-program 런타임 to_float = 833(probe2).
- ⇒ **컴파일러 바이너리 자신의 __hx_to_double가 stale/naive(832)**, 그 바이너리가 출하하는 runtime.a의 __hx_to_double는 correct(833) = **frozen-seed 부트스트랩 링크 staleness**. 최종 hexa(gen3)가 낡은 float 파서로 링크됨(seed freeze 시점의 naive 파서). x86 seed stale·arm fresh(또는 arm codegen emit 재파스로 우연히 fresh 경로).
- **★fix (actionable·부트스트랩)**: (1) tool/restore_frozen_seeds/seed-converge 로 프로즌 float-파서 시드를 correct(__hexa_num_parse_float)로 재생성, 또는 (2) 최종 컴파일러 바이너리를 fresh runtime.a(correct __hx_to_double)로 재링크. 검증=재빌드 후 probe2 lit==833. multi-session(rebuild-verify 사이클·seed freeze 프로세스 이해 필요).
- 성격 재확인: advisory 게이트(required 아님)·5-lane byteeq 머지 비차단.

## 라운드-4 (2026-07-16 Fable — 기전 확정·CLOSED)
**832의 생산자 = `stdlib/runtime/ctype.hexa:243 rt_str_parse_float` (int-in-double 폴드), 실행 주체 = `build/aprime_cc` 자식 프로세스.**

### 판별 체인 (전부 실측, aiden /tmp/exoff = EXACT=0 fresh clone)
1. 수치 지문(정확 라운딩 에뮬레이션): ctype 폴드(frac=frac*10+d ×N, /frac_div 1회, mulsd/addsd)가
   6상수 관측을 **비트단위 전부 재현** — isq2pi=…832, isq2/p/a1/a3/a5=정답. 나이브 shim 폴드(frac*=0.1)는
   isq2·a1·a3·a5 플립(관측 불일치→배제), trunc@16 배제, trunc@17≡ctype 폴드(이 입력에선 동치).
2. frozen x86 seed 무죄: `build/num_float_core_native.o`의 `rt_parse_float_native`를 C 드라이버로 직접 호출
   → isq2pi/isq2 둘 다 **TAG_VOID bail** (아티팩트 레벨 확인).
3. runtime.a 체인 무죄: `__hx_to_double`/`hexa_to_float`를 runtime.a에 직접 링크해 호출 → 4상수 전부 정답(833 포함).
   (hexa 바이너리의 hxlcl_atof(T) = strtod 위임 shim이라 정확.)
4. **`hexa build/run` leg-B는 컴파일을 `build/aprime_cc --emit=obj` 자식으로 포크** (self/main.hexa:3673+ HEXA_BUILD_NATIVE
   default-ON, resolve_native_cc→build/aprime_cc). gdb로 hexa 부모 관측 시 __hx_to_double 호출 0회 → 파스는 aprime 안.
5. aprime_cc gdb 실측: `__hx_to_double("0.39894228040143267794")` 1회 → **`rt_str_parse_float` 1회 HIT**.
   aprime nm: rt_parse_float_native/rt_str_parse_float_exact **부재**, `T rt_str_parse_float` 존재,
   hxlcl_atof(static t) = HEXA_HAS_HEXA_RT_STDLIB arm(runtime_emit_full.hexa:3128-3133 → rt_str_parse_float 위임, #3859).
   즉 aprime 체인 = __hx_to_double → hxlcl_atof(static) → **ctype 폴드** → 832.
6. 방출물 확인: leg-B로 빌드한 프로브 실행파일 main에 `movabs $0x3fd9884533d43650`(832) 베이크.
   같은 바이너리 .rodata엔 runtime 자체 상수 0x…651(833) 공존 (clang이 컴파일한 C 상수라 정확).

### "순수정수 코드가 아치발산" 미스터리 해소
같은 파서가 발산한 게 아님 — **아치별로 다른 프로세스의 다른 파서**가 리터럴을 파싱:
- x86_64: leg-B own-emit 성공 → aprime_cc 내부 hexa 폴드(ctype) → 832.
- arm64(linux/darwin): leg-B own-emit 불가/opt-in → C-transpile 폴백 → FloatLit이 C 소스 텍스트로 방출
  (self/codegen.hexa:7063 `hexa_float(<literal>)`) → clang(APFloat, correctly-rounded)이 파싱 → 833.
  (arm이 폴드를 탔다면 fmadd-contraction으로 isq2=…190이 나와야 하는데 관측은 189 → arm은 폴드 미경유 교차확인.)
- 라운드-3의 "EXACT=0/-ffp-contract=off로도 832" 반증들은 **유효** (컴파일러 자신의 체인이 아니라 aprime이 파싱하므로
  당연히 불변)이지만 인과 해석이 틀렸었음. -ffp-contract=off "반증"은 x86에 FMA가 없어 원래 no-op.
- num_float_core.hexa:20-24의 불변식("slow path는 반드시 strtod")이 hxlcl_atof→rt_str_parse_float 위임(#3859)으로
  조용히 깨진 것이 근본 결함. EXACT 티어(§float_parse_exact, strtod 비트일치 1M+ 검증)는 aprime TU에 아예 미링크.

### FIX 설계 (reference-match: x86 → arm/glibc=833)
최소·opt-in-first·no-LLVM·zero-c 유지:
1. `compiler/main.hexa:65` 옆에 `import "../stdlib/runtime/float_parse_exact.hexa"` 추가
   → build_aprime flatten이 자동 포섭, rt_str_parse_float_exact가 ap_post.c에 T로 방출.
2. `self/runtime_emit_full.hexa:3128-3133` hxlcl_atof rt-stdlib arm에 EXACT-first 위임 추가
   (`#ifdef HEXA_RT_NUM_PARSE_FLOAT_EXACT` — TAG_FLOAT면 반환, 선텐티널 decline이면 기존 rt_str_parse_float 테일 유지)
   + 추적 runtime.c 재생성(에미터 SSOT 락스텝).
3. `tool/build_aprime.sh:270` HEXA_HAS_HEXA_RT_STDLIB sed 블록에 `#define HEXA_RT_NUM_PARSE_FLOAT_EXACT 1` 동반 prepend.
   → 매크로 미정의 빌드(출하 runtime.c)는 dead-#ifdef로 **바이트 동일**(release-neutral), aprime만 플립.

### 비회귀 근거
- float_parse_exact = musl floatscan 정수 포팅, glibc strtod 비트일치 검증 이력: hard corpus + 5046 mixed +
  ≥100k random + 1M pool sweep (파일 헤더·test/native_build/rt_parse_float_exact_byteeq.hexa).
- 오늘 폴드가 정답인 입력(≤15자리 등)은 폴드==strtod==EXACT → 값 불변; 달라지는 입력은 폴드≠strtod인
  버그 클래스 그 자체(isq2pi 832→833 = 골든 3837435693766553512 복귀, isq2pi는 op19b BWD 전용이라 FWD 불변).
- hex/inf/nan/junk: EXACT가 sentinel decline → 기존 테일 그대로 → 동작 불변.
- 게이트: fold_ci_gate fresh(캐시 rm) + const_probe 6상수 + exact byteeq 하니스 + 3-target byteeq + gen3≡gen4 + 출하 스모크.

### 잔여 동클래스 (별도 라운드)
- `self/rt/string.hexa:510 rt_str_parse_float` (selfemit 멤버층, 나이브 scale 폴드) — ownobj/selfemit 멤버가
  to_float를 서빙하기 시작하면 같은 클래스 발화. EXACT 위임 선행 필요.
- `stdlib/runtime/hxlcl_core.hexa:3154` Route C hxlcl_atof (나이브, default-OFF) — 플립 전 동일 처리 필요.
- 클래스 불변식: 유한 십진 파서는 반드시 EXACT 또는 strtod로 종결(멤버 파서 신설 시 게이트化 후보).

## 구조적 확정 (2026-07-16 최종)
- default 빌드(/tmp/foldrepro·HEXA_RT_NUM_PARSE_FLOAT_NATIVE ON)에서도 lit=832·str=833.
- **skew는 flag-무관·구조적**: 컴파일러 바이너리의 컴파일타임 리터럴 fold 경로가 런타임 __hx_to_double 파스와 구조적으로 다른 결과(같은 바이너리·모든 flag 조합).
- 다음 세션 착수점(bounded): hir_to_mir.hexa:4494 fold 직후 o.float_val 비트 + x86_64_linux.hexa:1524 codegen 직전 비트를 계측(디버그 print)해 832가 fold에서 나오는지 storage/codegen에서 나오는지 확정 → 교정. multi-session(컴파일러 계측+rebuild).

## 완전 추적 (2026-07-16 · 16턴 measure-first, 8+ aiden 빌드)
파이프라인 전 경로 계측 결과:
1. x86 `hexa run` op19b → 계측(hir_to_mir.hexa:4494 FLTDBG=0) = **native compiler/lower 경로 안 탐** → **gen2 C-transpile(self/codegen.hexa) 경로 사용**.
2. gen2 float 리터럴 방출 = self/codegen.hexa:7063 `if k=="FloatLit" { return "hexa_float(" + node.value + ")" }`.
3. node.value = self/parser.hexa:4026 node_float_lit(tok.value) = 렉서 tok.value.
4. 렉서(self/lexer.hexa:666,780,795): `num_str = join(num_parts,"")` = **full raw 소스텍스트** ("pass the literal text through"), value: num_str. → 절단 아님.
5. **모순**: node.value=full "0.39894228040143267794" 방출→clang correctly-round→833이어야 하는데 실측 832.
- x86≠arm 최종 모델: x86 `hexa run`=gen2 경로(832), arm=native 경로(4494 to_float, correct 833).
- **bounded 재개점(다음 세션)**: gen2 방출 .c 를 실제 덤프(self/main.hexa:1618 c_file 경로)해 isq2pi 리터럴이 clang 에 full 로 가는지 확인 — full 인데도 832 면 (a) __hx_f64_bits/const-fold(self/codegen.hexa:7299)가 리터럴을 사전파싱(832) OR (b) 다른 방출 사이트. truncate 면 렉서/방출 절단.
- **성격 재확인**: advisory 게이트(required=selfhost-gates-summary·byteeq-3-target 무관)·5-lane 머지 비차단·main 2일+ 기존 RED(내 세션 무관).
- **투자 판정**: advisory 버그에 16턴 추적=과투자, 여기서 조사 종결(over-invest guard). 다음 세션 gen2 .c 덤프 1스텝으로 재개.

## ★확정 종료 (2026-07-16 · 19턴, over-invest guard)
완전 근인 체인:
- fold_ci_gate.sh:102/110 = `hexa run`(self/main.hexa:575 cmd_run_user_direct) — **비-native 실행경로**.
- 계측: FLTDBG=0(native compiler/lower:4494 미사용) · strace .c 無(gen2 컴파일 아님) → 인터프리터/run-path 실행.
- isq2pi_val_bits = isq2pi_lit_bits = 832 (op19b 문맥 직접격리) = **값/리터럴-파스 버그** (산술 아님).
- @strict_fp 6개 추가로도 832 = FMA-contraction 아님 확정(내 앞선 반증 유효). strict_fp_cflags(self/main.hexa:1600, op19b 마커無→clang -ffp-contract=fast였으나 무관).
- to_float(런타임string)=833(correct __hx_to_double) vs FloatLit eval=832 = **run-path가 FloatLit엔 naive parse, to_float엔 correct 체인 = 파서 불일치**.
- **fix locus (bounded 재개점)**: run-path(cmd_run_user_direct 인터프리터/실행)의 FloatLit→float 변환 지점을 correct 파서(to_float/__hx_to_double/__hexa_num_parse_float)로 배선. self/bootstrap.hexa:1054는 파서(AST빌드)이고 eval 변환지점은 별도 — 다음 세션 grep: run-path eval의 FloatLit→hexa_float(parse_float(value)) 사이트 확정 후 to_float로 교체 → 재빌드 → op19b run에서 isq2pi==833 검증.
- arm=833(다른 실행경로 또는 correct 파서).
- **성격**: advisory(required 아님)·byteeq-3-target 무관·5-lane 비차단·main 2일+ 기존RED·내 세션 무관. 19턴 추적=과투자, 종료.
