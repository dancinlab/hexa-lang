# PROBE log — hexa canonical-deviation audit

체크박스 append-only 로그. snapshot = `PROBE.md`.

## 2026-05-23 라운드 1 — 기본 의미론

- [x] 정수 산술 · 음수 modulo · int/float promotion — canonical
- [x] `**` · 복합대입(`+=`) · 비트 (`& | ^ << >>`) — canonical
- [x] 문자열 메서드 (`to_lower` `to_upper` `trim` `contains` `starts_with` `ends_with` `replace` `index_of` `substring` `split` `len`) — canonical
- [x] 컬렉션 (배열 push/pop/len · dict lookup) · bool/string 캐스트 — canonical
- [x] `cmd_parse`/`cmd_build` 셸 인젝션 — FIXED [#342]
- [x] 숫자 `as` 캐스트 codegen no-op — FIXED [#344]
- [x] match arm `=>` 미수용 (legacy `->`만) — FIXED [#345]
- [x] 명명 fn 일급값 (`let f = add`) C 타입에러 — FIXED [#346]
- [x] `let` 비-mut 재할당 자유 (`mut` 무의미) — FILED [#347]
- [x] 비-exhaustive match → silent `void` — FILED [#347]

## 2026-05-23 라운드 2 — trait/generic/iterator/closure

- [x] iterator (`for 0..N` `.map` `.fold`) — canonical
- [x] generic `fn id<T>(x: T) -> T` — canonical
- [x] struct (필드 접근) — canonical
- [x] trait/impl dispatch — `hexa_is_type` 헤더 누락 → FIXED [#348]
- [x] closure read capture — canonical
- [x] closure 가변 capture by-value (snapshot, mutation 손실) — FILED [#349]
- [x] i64 overflow — wrap (Go/Rust release 모드 일치)

## 2026-05-23 라운드 3 — 전수조사 (8 bg agent · probe-only)

### Option/Result + `?` (#1 / a4dd90e2)
- [x] try/catch 기본 · 중첩 rethrow · 비-string throw · panic 메시지 · `T?` 타입 suffix · `??` null-coalesce · enum-기반 Option/Result+match — canonical
- [x] postfix `?` error-propagation — parse error → INBOX (Result ABI 결정 필요)
- [x] `?.` 옵셔널 체이닝 — lexer 토큰만 있고 parser/codegen 미완성 → FIX 가능 (lexer 재생성 + codegen OptField 추가)
- [x] built-in `Some/None` — 없음, 매-파일 hand-roll → INBOX (prelude 정책)
- [x] `nil`/`null` — `nil` silent void · `null` undeclared → FIX (alias 또는 reserved 진단)
- [x] panic은 try/catch도 recover도 못 잡음 → INBOX (채널 의미론 결정)
- [x] `try`-as-expression · `finally` — 미지원 → INBOX

### String interpolation (#2 / a7224dce)
- [x] `format("...{}", x)` 함수형 (Rust 스타일) · concat baseline · 표준 escape — canonical
- [x] `${name}` JS 템플릿 — silent literal 유지 → INBOX
- [x] `f"x={x}"` Python — codegen 에러 → FIX-SURGICAL (lexer.hexa:298 prefix 진단)
- [x] `"x=\(x)"` Swift — `\` silent drop → FIX-SURGICAL (lexer.hexa:359 unknown escape)
- [x] `format!("...", x)` Rust macro — parser AST 만들고 codegen 미처리 → **FIX-SURGICAL (codegen_c2.hexa:6014 — desugar to format)**
- [x] `printf`/`sprintf` — undeclared → INBOX

### String unicode (#3 / adf2c218)
- [x] `.len()` byte · `.char_count()` codepoint · `.chars()` codepoint walk · `.bytes()` · `chr/ord` symmetric · `bytes_to_str_raw` NUL-safe — canonical
- [x] **`chr(0)` NUL-truncate (`.len()`=0)** — FIX-SURGICAL (runtime.c:4728 `malloc`→`hexa_strbuf_alloc`, RFC 030 패턴)
- [x] embedded NUL concat 절단 — 동일 root
- [x] `.codepoints()` 별칭 부재 (Rust 명명) → INBOX (alias)
- [x] `.graphemes()` UAX-29 — INBOX (stdlib gap)
- [x] `rt_str_chars` pure-hexa fallback byte-walk (compiled은 codepoint) → FIX-SURGICAL (rt/string.hexa:32)
- [x] 기존 `chr-byte-vs-codepoint-asymmetry.md` — 헤더 closure 유효, 잔여 NUL은 분리

### Array index OOB (#4 / aeef94a2)
- [x] positive in-bounds · OOB throw with line · negative wraparound (Python-style) · index-set · slice positive · 중첩 — canonical
- [x] **`hexa_array_shift` 런타임 정의 있으나 header decl 누락** → **FIX-SURGICAL (runtime.h, #348 패턴 1-line)**
- [x] **문자열 OOB → silent `""`** (should throw) → FIX-SURGICAL (runtime_core.c:4562)
- [x] **음수 OOB 에러 메시지가 정규화된 값 노출** (원본 `-10` 손실) → FIX-SURGICAL (runtime_core.c:1996/2021)
- [x] **문자열 index-set 에러 메시지 부정확** (`container is not an array (tag=3)`) → FIX-SURGICAL (runtime_core.c:2017)
- [x] slice negative wrap silently clamp (Python wrap 아님) → INBOX
- [x] `[].pop()` → silent void (Rust None / Python IndexError) → INBOX (Option lane 연계)
- [x] `[..b]` / `[a..]` open-range slice — parse error → INBOX (parser slice form)

### enum / sum types (#5 / a0e3ba3a)
- [x] enum 키워드 · `::`/`.` 접근 · single-arg payload 생성+match · 구조체-embed payload · 등호 · `_` wildcard arm — canonical
- [x] **`to_string(Color::Red)` → `"0"` (tag 노출)** — `test_compact_enum.hexa` 14 FAIL 기록됨 → INBOX
- [x] **multi-arg payload 생성 `Shape::Square(3,4)` parse 거부** (decl LANDED, expr 1-expr만) → **FIX-SURGICAL (parser.hexa:3173)**
- [x] non-exhaustive match → silent void (PR #347 연계) — INBOX
- [x] 미인식 variant `Color::Purple` → clang 에러 (hexa-레벨 아님) → INBOX (typechecker)
- [x] enum `<`/`>` ordering by tag — INBOX (spec 결정)

### Shadowing (#6 / adcc3f69)
- [x] 같은 스코프 `let` reshadow · 안쪽 스코프 새 이름 · 타입 변경 shadow · `let mut` → `let` — canonical
- [x] **안쪽 스코프 `let`이 외부로 누출** (`{ let x = 100 }` 후 outer = 100) — `_gen2_collect_lets` flat-hoist (함수당 단일 `HexaVal x`) → INBOX (codegen 스코프 재설계, PR #347과 묶을 후보)
- [x] match-arm `let`도 동일 누출 — 동일 root
- [x] bare-block `{ … }` statement parse 거부 → FIX-SURGICAL (parser StmtBlock)

### Range types (#7 / aaffd149)
- [x] `0..N` exclusive · `0..=N` inclusive · negative bounds · descending=empty · range-as-value · `.contains/.len/.map/.fold/.reverse` — canonical
- [x] **`.rev()` codegen 미정의** → **FIX-SURGICAL (codegen_c2.hexa:3386, alias `reverse`)**
- [x] **`.step_by(n)` codegen 미정의** (런타임 step 매개변수는 wired) → **FIX-SURGICAL (codegen_c2.hexa)**
- [x] **`step` 키워드 (`0..10 step 2`) — lexer 미발행** (parser/codegen wired) → **FIX-SURGICAL (lexer.hexa keyword)**
- [x] `r.start`/`.end` — Range가 array로 materialize되며 메타 손실 → INBOX (Range repr)
- [x] Swift `0...5` inclusive — INBOX (`..=` 정준 채택)

### Float NaN/Inf/IEEE 754 (#8 / a2c46b9f)
- [x] NaN ≠ NaN · -0.0 sign bit · inf arithmetic · subnormal · sqrt(-1) · 정수 1/0 throw · IEEE 비교 — canonical
- [x] **`-1.0/0.0` throw "division by zero"** (should `-inf` per IEEE) → FIX-SURGICAL (codegen_c2.hexa:3959 fold UnaryMinus(FloatLit) OR runtime_core.c:6887)
- [x] mixed int/float div-zero throw → FIX-SURGICAL 동일 site
- [x] `println(0.0)`=`0` vs `to_string(0.0)`=`0.0` 내부 불일치 → FIX-SURGICAL (runtime_core.c:5222)
- [x] hex-float `0x1.8p+1` literal — INBOX (lexer 문법 확장)
- [x] `inf`/`nan` 키워드 상수 부재 — INBOX (stdlib)
- [x] `to_string` nan/inf casing (`"nan"`/`"inf"` vs Rust `"NaN"`/`"inf"`) — INBOX
- [x] NaN-in-sort silent reorder — INBOX

## 2026-05-23 라운드 3 — 직렬 fix 단계 (closed)

- [x] PR — runtime.h `hexa_array_shift` decl — LANDED [#350] (mass-decl backstop [#360])
- [x] PR — `.rev()` codegen alias — LANDED [#351]
- [x] PR — Rust `format!(...)` MacroCall → format() desugar — LANDED [#352]
- [x] PR — `chr(0)` NUL-truncate strbuf_alloc — LANDED [#353]
- [x] inbox PR — round 5 consolidated (6 axes) — LANDED [#377]

## 2026-05-23 라운드 4-6 — fix 패스 (campaign)

- [x] match-arm guard incorporated into condition (silent miscompile) — FIXED [#379]
- [x] OR-pattern + Range pattern in match (silent miscompile) — FIXED [#380]
- [x] format brace-escape `{{`/`}}` unify paths — FIXED [#381]
- [x] iterator method aliases `.first`/`.nth`/`.skip` (Rust canonical) — FIXED [#385]
- [x] bare-Ident match arm = binding pattern, not equality — FIXED [#412]
- [x] bool → numeric coercion (Python canonical, silent miscompile cluster) — FIXED [#393]
- [x] closures capture mutable outer by reference — FIXED [#433] (closes round-2 #349)
- [x] codegen identifier rename `codegen_c2` → `codegen` — LANDED [#387, #403, #411]

## 2026-05-23 라운드 7-8 — consolidated audits

- [x] inbox PR — round 7 consolidated (3 axes) — LANDED [#395]
- [x] inbox PR — round 8 consolidated (3 axes + CRITICAL) — LANDED [#400]
- [x] write_file content-leak root cause (CRITICAL) — FIXED [#407, #414]
- [x] hxlcl_open_sys via libc open() — carry-flag failure detection — FIXED [#407]
- [x] runtime.h: term_isatty wrappers decl-only — FIXED [#401]
- [x] runtime.h: declare 7 codegen-called defined-but-undeclared fns — FIXED [#404]
- [x] runtime.h: json_decode/encode/ptr_null decl-only — unblock all builds — FIXED [#409]
- [x] glob / listdir / tempfile / tempdir posix-fs builtins — LANDED [#410]
- [x] hxlcl_fopen fd<=2 guard (syscall carry-flag class) — FIXED [#426]
- [x] stat/fstat/lseek/mmap libc-wrappers — Darwin arm64 syscall class — FIXED [#431]
- [x] exec_with_status — fix 2-tuple comment + 3-tuple migration RFC — DOCS [#427]
- [x] clang fork-storm source-block — token-ring cap=2 — FIXED [#408]

## 2026-05-23 라운드 9 — consolidated + design-honesty

- [x] inbox PR — round 9 consolidated (4 axes) — LANDED [#418]
- [x] parser MacroCall fail-loud at parse-time (r9-6) + expander design — LANDED [#419]
- [x] parser wire `parse_where_clauses` into `parse_fn_decl` (r9-14) — FIXED [#417]
- [x] parser regression-guard pub(crate/super/self) (r9-19 VERIFIED-CLOSED) — TEST [#428]
- [x] parser `@derive_meta` surface + `@derive` deprecation (r9 #7) — LANDED [#432]

## 2026-05-23 라운드 10 — consolidated 4 axes + P0 CRITICAL

- [x] inbox PR — round 10 consolidated (4 axes + P0 CRITICAL) — LANDED [#435]
- [x] parser `@derive` repeat + target-validation diagnostic (r10-P1) — FIXED [#436]
- [x] codegen `@cold/@noinline/@hot` on fwd decl, not defn (r10-15g) — FIXED [#440]
- [x] runtime exec_with_status3 — canonical 3-tuple — LANDED [#441]
- [x] r10-P0 long-ident codegen truncation — VERIFIED-ALREADY-FIXED [#442]
- [x] lexer UTF-8 identifiers — high-bit accepted as ident (r10-4) — LANDED [#443]
- [x] parse error render — source snippet + caret pointer (r10-18d) — LANDED [#444]
- [x] parser attr whitelist + conflict warnings (r10-15b/c/d) — FIXED [#448]
- [x] parser trailing comma in call args `f(a, b,)` (r10-8) — FIXED [#449]
- [x] modules: pub-use re-export + alias/dup-import diagnostic — LANDED [#447]
- [x] lexer unicode identifiers — Go/Rust canonical (r10-4) — LANDED [#452]
- [x] inbox: macro expander pass detailed design RFC (#419 follow-up) — LANDED [#451]

## 2026-05-23 라운드 11 — type/trait/const-fold (cycle 10)

- [x] codegen IntLit-fold emits `LL` suffix — `1 << 62` UB fix (A2) — FIXED [#455]
- [x] type_checker tc_infer_expr MapLit branch returns "map" (B5) — FIXED [#456]
- [x] runtime to_string(float) honors HEXA_FLOAT_REPR env (B6) — FIXED [#457]
- [x] codegen comptime-fold immutable `let x = 2+3` to literal (B3) — LANDED [#459]
- [x] codegen comptime-DCE `if false {}` at statement position (B4) — LANDED [#461]
- [x] type_checker warn on immutable-let reassignment + non-exhaustive match — LANDED [#453]
- [x] hexa_v2 regen activate cycle-3 batch (unicode idents · trailing comma · exec3) — LANDED [#454]

## 2026-05-23 라운드 12 — runtime correctness P1

- [x] parser EOF synth-token anchors at last real token line/col (P1) — FIXED [#464]
- [x] runtime hexa_array_get clearer message for void/map/str container (#10) — FIXED [#465]
- [x] runtime string OOB throws (align with array OOB) (#16) — FIXED [#467] (closes r3 #4 silent "" silent void)
- [x] runtime hexa_call0/1/2/3/4 throw on non-callable target (#17) — FIXED [#469]

## 2026-05-23 라운드 13 — stdlib route completion

- [x] codegen stdlib route completion — utc_now / iso8601_format / iso8601_parse / set_env — LANDED [#470]

## 2026-05-23 macro expander Phase 1 + parser macros

- [x] parser macro expander Phase 1 — println!/panic!/vec! intrinsics — LANDED [#462] (per #451 design)

## 2026-05-23 misc infra + ship batch

- [x] CHANGELOG.md establish + session ship batch — DOCS [#463]
- [x] wrapper hexa → exec -a hexa hxv2 — AMFI SIGKILL bypass + stdout-truncation removal — FIXED [#421, #422]
- [x] runtime exec_capture select()-multiplexed drain — pipe deadlock fix — FIXED [#423]
- [x] inbox exec-printf-stdout-swallow — working-as-designed — RETRACTED [#424]
- [x] inbox hx-reinstall-runtime-artifact-block — resolved (rm -rf in place) — CLOSED [#425]
- [x] inbox audit round-5 + round-8 — CRITICAL clusters closed — DOCS [#415]
- [x] inbox write-file-content-leak — FIXED by #407 — DOCS [#416]
- [x] inbox hexa-cloud-argv-guard-shell-redirect-falsepos — already-resolved-in-source — DOCS [#405]
- [x] inbox naming-generic audit — 1 rename + 8 legitimate + 3 time-gated — DOCS [#391]
- [x] gov project.tape — naming_generic + granular B-form — LANDED [#384, #390]
- [x] wrapper !hexa exception in .gitignore — recurrence guard — FIXED [#446]
- [x] .gitignore drop hexa — root wrapper consistently tracked — FIXED [#466]
- [x] build install scripts emit `hxv2` instead of `hexa.real` — FIXED [#422]
- [x] stdlib runpod_list_pods — runpodctl 2.x/1.x bridge — LANDED [#388]
- [x] stdlib net native ws:// WebSocket client + SHA-1 primitive — LANDED [#434]
- [x] stdlib plot minimal native SVG charting — paper-figure gap — LANDED [#430]
- [x] stdlib cloud vast.ai pod-lifecycle backend — LANDED [#429]
- [x] stdlib json_object: json_object_delete + json_object_has (no regen) — LANDED [#439]
- [x] hexa_v2 regen: closure-by-ref + sha1 codegen (cycle-1 batch) — REGEN [#437]
- [x] hexa_v2 regen: rebuild transpiler — activate pending codegen-fix batch — REGEN [#413]
- [x] domain: HEXA-LANG.md + HEXA-LANG.log.md deferred RFC tracking — LANDED [#471]
- [x] inbox stdlib-for-cpu-port umbrella — all 5 sub-patches landed — DOCS [#468]
- [x] inbox exec() builtin silently swallows child stdout under hexa run — FILED [#398]

## 2026-05-23 라운드 14 cycle 1-6 — surgical sweep

### cycle 1 (5 fan-out, 4 PR landed + 1 dup-skip)

- [x] r14-A `nil`/`null` reserved-name 진단 — LANDED [#474]
- [x] r14-B hex-float `0x1.8p+1` lexer — LANDED [#473]
- [x] r14-C slice open-range `[..b]`/`[a..]`/`[..]` — DUP-skipped (landed via [#480] other session)
- [x] r14-D slice neg-wrap (Python canonical) — LANDED [#482]
- [x] r14-E `to_string` NaN/inf Rust casing — LANDED [#475]

### cycle 2 (5 fan-out, 4 PR landed + 1 STOP)

- [⛔] r14-F enum `to_string` variant name — STOP (architectural, RFC filed [#489])
- [x] r14-G `printf`/`sprintf` use-format hint — LANDED [#484]
- [x] r14-H `inf`/`nan` 식별자 상수 magic — LANDED [#488]
- [x] r14-I `HEXA_STRICT_MATCH` env gate (warn → error) — LANDED [#485]
- [x] r14-J NaN-in-sort canonical comparator — LANDED [#486]

### cycle 3 (5 fan-out, 4 PR landed + 1 STOP + RFC R)

- [⛔] r14-K `-1.0/0.0 → -inf` fold — STOP (already landed via `codegen.hexa:4417-4440`, PROBE r3+r7 closure)
- [x] r14-L `print_val` NaN/inf + 0.0 parity — LANDED [#492]
- [x] r14-M Swift `0...N` inclusive parser (alias `0..=N`) — LANDED [#491]
- [x] r14-N `HEXA_STRICT_LET` env gate — LANDED [#490]
- [x] r14-R enum `to_string` codegen-emit RFC (F follow-up) — LANDED [#489]

### cycle 4 (6 fan-out — surgical + design RFC mix, all OPEN)

- [ ] r14-S bare-block `{ … }` statement parse — OPEN [#498]
- [ ] r14-T mixed int/float div codegen fold — OPEN [#497]
- [ ] r14-U `.graphemes()` UAX-29 minimal stub — OPEN [#495]
- [ ] r14-W macro expander Phase 2 design RFC — OPEN [#493]
- [ ] r14-X postfix `?` + Result ABI design RFC — OPEN [#494]
- [ ] r14-AA shadowing scope leak codegen-redesign RFC — OPEN [#496]

### cycle 5 (6 fan-out, all OPEN + 1 DUP-skip)

- [ ] r14-BB optional chaining `?.` for struct fields — OPEN [#504]
- [⛔] r14-CC multi-arg enum payload parse — DUP-skipped (already landed [#366])
- [ ] r14-DD `hexa_div` mixed int/float canonical IEEE promotion (runtime) — OPEN [#499]
- [ ] r14-EE panic channel semantics design RFC — OPEN [#501]
- [ ] r14-FF try-as-expression + finally clause design RFC — OPEN [#502]
- [ ] r14-GG Range repr `.start`/`.end` metadata design RFC — OPEN [#500]

### cycle 6 (6 fan-out — 3 surgical + 3 RFC)

- [ ] r14-HH match-arm multi-arg enum payload bind (codegen) — IN-FLIGHT (no PR yet)
- [ ] r14-II `let inf`/`nan` shadow-of-reserved 진단 (H follow-up) — OPEN [#507]
- [ ] r14-JJ Python `f"x={x}"` lexer — IN-FLIGHT (no PR yet)
- [ ] r14-KK Option `Some`/`None` prelude policy RFC — OPEN [#505]
- [ ] r14-LL tuple type design RFC — OPEN [#506]
- [ ] r14-MM chained comparison Python-style design RFC — OPEN [#508]

### cycle 1-6 요약

- merged 14 (cycle 1-3 surgical) + open 14 (cycle 4-6 mix) + in-flight 2 (HH/JJ, no PR yet) + STOP 3 (F → RFC #489 · K already-landed · CC already-landed #366) = 33 items
- surgical lane = 16 (lexer/parser/codegen/runtime/type_checker)
- design-RFC lane = 11 (postfix `?` · `?.` · shadow scope · macro Phase 2 · panic · try-expr · Range repr · Some/None prelude · tuple · chained cmp · enum to_string)

## 잔여 (cycle 7+ candidates)

- [ ] r14-NN `is_comparison_op` token-name fix (MM finding)
- [ ] Swift `"x=\(x)"` interp 표현 (r3 #2)
- [ ] underscore numeric separator `1_000_000` (lexer)
- [ ] iterator `.take/.collect/.sum/.filter` aliases (codegen, #385 follow-up)
- [ ] hexa_v2 regen batch — cycle 4-6 `.hexa` changes activation
- [ ] `codegen.hexa:3106` panic recover comment doc-bug (EE finding)
- [ ] raw string `r"..."` literal (design RFC pending)
- [ ] multi-line `"""..."""` literal (design RFC pending)
- [ ] if-let / while-let (Rust/Swift, design RFC pending)
- [ ] async/await (design RFC pending)
- [ ] destructuring `let {x, y}` / `let [a, b]` (design RFC pending)
- [ ] hex-float regen activation ([#473] follow-up)
- [ ] f-string regen activation (cycle 6 JJ follow-up)
- [ ] `non-exhaustive match` warn → error strict path ([#453] follow-up, #347 cluster)
- [ ] `[].pop()` Option lane (r3 INBOX)
- [ ] enum `<`/`>` ordering spec (r3 INBOX)
- [ ] `${name}` JS 템플릿 silent literal 진단 (r3 INBOX, [#478] warn-only landed)
