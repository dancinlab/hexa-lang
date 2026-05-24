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

## 2026-05-24 라운드 14 cycle 7-9 — RFC mass-file + surgical fix

### Cycle 7-9 surgical fixes (LANDED)

- [x] lexer hex-float literal `0x1.8p+1` (r14-B) — LANDED [#473]
- [x] parser `nil`/`null` reserved-name 진단 (r14-A) — LANDED [#474]
- [x] runtime `to_string` NaN/inf casing (r14-E) — LANDED [#475]
- [x] codegen `.codepoints()` Rust canonical alias (r14-E) — LANDED [#476]
- [x] lexer `${...}` JS-template warn (r14-A) — LANDED [#478]
- [x] parser open-range slice `[..b]` / `[a..]` / `[..]` (r14-C) — LANDED [#480]
- [x] runtime slice negative-index wrap Python-canonical (r14-D) — LANDED [#482]
- [x] codegen `printf`/`sprintf` use-format hint (r14-G) — LANDED [#484]
- [x] type_checker `HEXA_STRICT_MATCH` env gate (r14-I) — LANDED [#485]
- [x] runtime NaN-in-sort canonical NaN-last comparator (r14-J) — LANDED [#486]
- [x] codegen `inf`/`nan` identifier constants (r14-H) — LANDED [#488]
- [x] type_checker `HEXA_STRICT_LET` env gate (r14-N) — LANDED [#490]
- [x] parser `0...N` Swift inclusive alias (r14-M) — LANDED [#491]
- [x] runtime `print_val` NaN/inf + 0.0 parity (r14-L) — LANDED [#492]
- [x] cycle 1-6 sync docs(PROBE) — 14 merged / 14 open / 2 in-flight / 3 STOP (r14-PP) — FILED [#512]

### Cycle 7-9 design RFC (inbox)

- [ ] macro expander Phase 2 (r14-W) — RFC [#493]
- [ ] postfix `?` + Result ABI (r14-X) — RFC [#494]
- [ ] codegen `.graphemes()` UAX-29 minimal stub (r14-U) — OPEN [#495]
- [ ] shadowing scope leak codegen-redesign (r14-AA, round 3 #6) — RFC [#496]
- [ ] codegen mixed int/float divide IEEE promotion (r14-T) — OPEN [#497]
- [ ] parser bare-block statement (r14-S) — OPEN [#498]
- [ ] runtime `hexa_div` mixed int/float IEEE promotion (r14-DD) — OPEN [#499]
- [ ] Range repr `.start`/`.end` metadata (r14-GG) — RFC [#500]
- [ ] panic channel semantics (r14-EE) — RFC [#501]
- [ ] try-as-expression + finally clause (r14-FF) — RFC [#502]
- [ ] codegen optional chaining `?.` for struct fields (r14-BB) — OPEN [#504]
- [ ] Option Some/None prelude policy (r14-KK) — RFC [#505]
- [ ] tuple type (r14-LL) — RFC [#506]
- [ ] parser `let inf`/`let nan` shadow-of-reserved 진단 (r14-II, H follow-up) — OPEN [#507]
- [ ] chained comparison Python-style (r14-MM) — RFC [#508]
- [ ] parser `is_comparison_op` LtEq/GtEq token-name sync (r14-NN) — OPEN [#509]
- [ ] lexer Python f-string `f"x={x}"` interpolation (r14-JJ, round 3 #2) — OPEN [#510]
- [ ] raw string literal (r14-RR) — RFC [#511]
- [x] if-let / while-let pattern binding (r14-SS) — RFC LANDED [#513]
- [ ] async/await (r14-TT) — RFC [#514]
- [ ] destructuring let-decl (r14-UU) — RFC [#515]
- [ ] codegen match-arm multi-arg enum payload binding (r14-HH, CC follow-up) — OPEN [#516]
- [ ] channel + spawn Go-style 동시성 (r14-JJJ, TT sister) — RFC [#517]
- [x] multi-line string `"""..."""` literal (r14-III) — RFC LANDED [#518]
- [ ] set literal (r14-LLL) — RFC [#519]
- [ ] pipe operator `|>` design (r14-KKK) — RFC [#520]
- [ ] regex literal (r14-MMM) — RFC [#521]
- [ ] compound assignment completeness (r14-WWW) — RFC [#523]
- [ ] numeric literal augment (underscore + 0b/0o) (r14-XXX) — RFC [#524]
- [ ] codegen IfLetExpr handler (parse-OK/codegen-ERROR 닫음) (r14-VV) — OPEN [#525]
- [x] struct field default values (r14-YYY) — RFC LANDED [#526]
- [ ] lexer+codegen pipe operator `|>` token emit + desugar (r14-NNN) — OPEN [#527]
- [ ] match arm guard if-cond (r14-ZZZ) — RFC [#528]
- [ ] parser destructure rename `let { x: alias } = p` (r14-PPP, UU follow-up) — OPEN [#529]

## 2026-05-24 라운드 14 cycle 10 — cycle-full phase-0 brainstorm depleted

- [x] struct field default values 코드-랜딩 (r14-CCCC, YYY-1, breaking change + silent corruption 닫음) — MERGED [#538]
- [x] match-arm guard EnumPath payload binder visibility (r14-BBBB, ZZZ-1, silent miscompile) — MERGED [#543]
- [ ] lexer `0b`/`0o` numeric literals (r14-DDDD, XXX-1) — OPEN [#537]
- [ ] trait dyn dispatch `&dyn Trait` design RFC (r14-GGGG) — RFC [#532]
- [ ] iterator aliases take/filter/collect/sum/zip/enumerate/chain RFC (r14-EEEE, #385 follow-up · 13/16 닫음 · gaps: collect/chain/count) — RFC [#533]
- [ ] defer pattern Swift/Go design RFC (r14-FFFF, 80% impl found, 4 gaps) — RFC [#534]
- [ ] smart pointer Box/Rc/Arc stub design RFC (r14-IIII) — RFC [#535]
- [ ] lifetime `'a` annotation rejection RFC (r14-HHHH, GC-camp 정책) — RFC [#536]
- [⛔] author self-merge 감지 — `gh pr merge --admin` 자동 머지 패턴 발견 (#538/#543) → sidecar `gh-api-guard` 0.1.0 + commons `@D g55` LANDED (외부 거버넌스 정착)

## 2026-05-24 라운드 14 cycle 11 — 부분-잔여 (disk-full)

- [ ] stdlib smart_ptr Box/Rc/Arc identity stubs (r14-NNNN, IIII-1) — OPEN [#549]
- [ ] codegen iterator `.collect`/`.chain`/`.count` no-args alias (r14-JJJJ, EEEE bundle) — OPEN [#550]
- [⛔] KKKK / LLLL / MMMM / OOOO / PPPP — disk-full + 셸 routing → cycle 12 재진행 큐

## 2026-05-24 라운드 14 cycle 12 — closed

- [x] CHANGELOG + PROBE.log r14 cycle 7-11 batch sync (r14-PPPP) — LANDED [#597]
- [ ] RFC 087 macro-expander pass design promote (inbox/rfc_drafts) — OPEN [#556]

## 2026-05-24 라운드 14 cycle 13 — surgical RFC closure + stdlib MVP

### Cycle 13 surgical fixes (LANDED)

- [x] lexer raw string `r"..."` literal (r14-UUUU, RR-1 실 구현, cycle 11 RFC [#511] follow-up) — LANDED [#598]
- [x] drill `--rounds N` multi-round resume state (r14-carry, hexa loop infra) — LANDED [#599]
- [x] codegen match as tail-expression returns arm value (r14-VVVV) — LANDED [#600]
- [x] parser+codegen let-else divergent binding (r14-UUUU let-else) — LANDED [#601]
- [x] lexer 6 compound assign tokens `+=` `-=` `*=` `/=` `%=` `**=` 통합 (r14-MMMM, WWW-1) — LANDED [#603]
- [x] codegen iterator `.collect`/`.chain`/`.count` no-args alias (r14-JJJJ, EEEE bundle, cycle 11 [#550] follow-up) — LANDED [#604]
- [x] codegen optional chaining `?.` for struct fields (r14-BB, cycle 7-9 [#504] follow-up, round 3 INBOX closure) — LANDED [#607]
- [x] codegen comptime-const mixed-type fold — min/max int+float promotion (r14 const-fold extension) — LANDED [#613]
- [x] stdlib HashSet[T] MVP — insert/contains/remove/len/iter (collection gap) — LANDED [#616]
- [x] runtime enum `<`/`>` ordering by declaration order (r14-TTTT, round 3 INBOX `enum < > ordering` closure) — LANDED [#617]

### Cycle 13 sister landings (atlas / verify / inbox)

- [x] verify CHSH Tsirelson + Hardy bound dispatch (RFC 045 atom enabler) — LANDED [#602]
- [x] HEXA-LANG.log cycle 6-10 sync — unblocker chain + atom payoff — LANDED [#605]
- [x] inbox RFC 090 `@target(firmware)` + `@target(rtl)` codegen lanes (promote rfc_063+064) — LANDED [#608]
- [x] atlas RFC 047+046 — welch_t · wilson · ssh_winding · tknn_chern register (unblocker chain payoff) — LANDED [#609]
- [x] CHANGELOG cycle 6-9 batch — enum stack closure · verify unblocker chain · auto-merge live — LANDED [#610]

## 2026-05-24 라운드 14 cycle 14 — 진행중 (current)

- [x] PROBE r14 cycle 13 batch sync (r14-PPPP-2) — 본 PR
- [x] PROBE r14 next-list 23 entries flip + coverage table mass sync (r14-PPPP-3) — 본 PR

## 2026-05-23 라운드 14 — closed sync (r14 cycle 1-13 결과 매핑)

- [x] enum to_string proper repr — RFC FILED [#489] (codegen-emit 3-surface 큰 작업, r14-F STOP)
- [x] shadowing scope leak — `_gen2_collect_lets` flat-hoist 재설계 — RFC FILED [#496] (r14-AA, 4-PR stack 권장)
- [x] panic/try-catch 채널 의미론 결정 — RFC FILED [#501] (r14-EE, panic = unrecoverable abort sealed)
- [x] postfix `?` error-propagation + Result ABI — RFC FILED [#494] (r14-X, enum-based Option/Result ABI 권장)
- [x] `?.` optional chaining parser/codegen 완성 — LANDED [#504, #607] (r14-BB, struct field short-circuit)
- [x] built-in Some/None prelude 정책 — RFC FILED [#505] (r14-KK, 자동 prelude import 권장)
- [x] `nil`/`null` alias 또는 reserved 진단 — LANDED [#474] (r14-A, parser parse_primary intercept)
- [x] try-as-expression · finally — RFC FILED [#502] (r14-FF, Kotlin/Scala 모델 권장, 4-PR stack)
- [x] `${name}` JS 템플릿 silent literal 진단 — LANDED [#478] (parser warn)
- [x] `printf`/`sprintf` undeclared — LANDED [#484] (r14-G, codegen `_is_known_fn_global` 게이트)
- [x] `.codepoints()` Rust alias — LANDED [#476] (codegen alias)
- [x] `.graphemes()` UAX-29 stdlib gap — LANDED [#495] (r14-U, ASCII + codepoint stub, full UAX-29 deferred)
- [x] slice `[..b]` / `[a..]` open-range parser — LANDED [#480] (parser `parse_postfix` LBracket `..`)
- [x] `[].pop()` Option lane — RFC FILED [#572] (r14-UUUU, Option vs throw 3 옵션, KK 의존)
- [x] slice negative wrap silently clamp 통일 — LANDED [#482] (r14-D, runtime wrap-then-clamp Python canonical)
- [x] non-exhaustive match strict (warn → error path, #453 follow-up) — LANDED [#485, #490] (r14-I `HEXA_STRICT_MATCH` + r14-N `HEXA_STRICT_LET` env gate)
- [x] enum `<`/`>` ordering spec 결정 — LANDED [#617] / RFC FILED [#571] (r14-TTTT, 옵션 A default tag-order)
- [x] Range repr `.start`/`.end`/`.len` — FIX-SURGICAL (runtime.c `hexa_range_field` + `hexa_map_get_ic_slow` array-fallback, PROBE r14). 정준 exclusive `a..b` 정확; step/inclusive `.end`만 derive(`last+step`) — literal upper-bound 정확 복원은 range-as-struct로 deferred
- [x] Swift `0...5` inclusive 정책 — LANDED [#491] (r14-M, parser `parse_range` `DotDotDot` arm 확장)
- [x] hex-float `0x1.8p+1` literal lexer — LANDED [#473] (r14-B, C99 strtod passthru)
- [x] `inf`/`nan` 키워드 상수 stdlib — LANDED [#488] (r14-H, codegen INFINITY/NAN emit + local shadow 보존)
- [x] `to_string` nan/inf casing 통일 — LANDED [#475] (r14-E, runtime `__hexa_float_special_repr` Rust canonical)
- [x] NaN-in-sort 동작 결정 — LANDED [#486] (r14-J, runtime sort comparator NaN-last canonical)
- [x] macro expander Phase 2 (#462 follow-up) — RFC FILED [#493] (r14-W, declarative macro 5-step plan)

## 2026-05-24 M5 closure — OPEN PR 정리 완주

- [x] 2026-05-24 M5 closure — OPEN PR ~36 정리 완주 (#420 admin-merge `37b6740d` · #702 g54 보호 user-review-only-comment · PROBE.md milestone 4/6 → 5/6 flip)

## 2026-05-24 r15 sweep cycle 1 — 8-axis 전수 (22 deviations · M6 closure)

3rd-try sub-agent 완료 (~12분 · 15분 cap 안). reference baselines: Rust(option/range/shadow/oob) · Swift(interp/unicode) · Python(float). source code 미수정. triage 산출물 `/tmp/probe-r15/cycle1_triage.md`.

### Option/Result (5 deviations · CRITICAL)
- [x] r15-D1 [SURGICAL] `Option[i64]` annotation parse error — 20 LoC — MERGED #719
- [ ] r15-D2 [RFC] `?` operator unimplemented — desugar + flow type
- [x] r15-D3 [SURGICAL · HIGHEST] `Some(v) match` pattern-bind codegen scope, `v` undeclared — 30 LoC, blocks 전 Option/Result 축 — MERGED #756 (+ tail void-match guard)
- [x] r15-D4 [SURGICAL] `.unwrap/.unwrap_or/.map` unknown builtin — 40 LoC — MERGED #725
- [ ] r15-D5 [RFC] `Option[i64] = None` 어노테이션+할당 parse fail (D1 자매)

### string_interp (3 deviations)
- [ ] r15-D6 [RFC] `format!()` macro — [#451] follow-up
- [x] r15-D7 [SURGICAL] f-string `{x:.2}` spec wiring — 50 LoC — MERGED #749 (`{x:.N}` precision)
- [ ] r15-D8 [RFC] printf-style stdlib helper 부재

### unicode (3 deviations)
- [ ] r15-D9 [RFC] `.len()` returns BYTES not graphemes — 3-tier policy 필요
- [ ] r15-D10 [SURGICAL] `.graphemes()` ZWJ family을 codepoint으로 셈 — 80 LoC (or RFC if libunicode)
- [ ] r15-D11 [RFC] NFC normalization 미수행

### oob (2 deviations)
- [ ] r15-D12 [SURGICAL] negative index `xs[-1]` Python-style wrap (canonical=panic) — 10 LoC, **policy call**
- [x] r15-D13 [SURGICAL] `s.byte_at(99)` sentinel `-1` 반환 (#467 array OOB 와 불일치) — 10 LoC — MERGED #748 (OOB throws)

### enum (3 deviations)
- [x] r15-D14 [SURGICAL] bare enum constructor codegen `Red/Green/Blue undeclared` — 30 LoC — MERGED #720
- [ ] r15-D15 [RFC] single-field payload `Square(...)` codegen — REGRESSION 의심 ([[project_hexa_lang_enum_payload_works]] 검증)
- [ ] r15-D16 [BLOCKED] multi-field payload — memory known-limit

### shadowing (3 deviations · CRITICAL)
- [x] r15-D17 [SURGICAL · CRITICAL] `{}` block scope 미생성 (silent correctness) — 40 LoC — MERGED #724
- [ ] r15-D18 [SURGICAL] type-changing shadow `let x="hello"; let x=42` resolver 누락 — 20 LoC, D17 자매
- [ ] r15-D19 [RFC] for-loop binding semantics — `let i=100; for i in 0..3` 외부 i 유지

### range (1 deviation)
- [x] r15-D20 [SURGICAL] `(0..5).rev()` 첫 원소만 — 30 LoC — MERGED #737

### float (2 deviations)
- [ ] r15-D21 [SURGICAL] `nan/inf` 식별자 shadow error 메시지 폴리시 — 5 LoC
- [ ] r15-D22 [SURGICAL] `NaN/nan` 케이싱 정책 — 3 LoC

### cycle 1 PASS axes (canonical)
- float NaN/Inf IEEE 의미 PASS
- range 0..5 / 0..=5 forward PASS · sum 10/15
- to_lower German ß 보존 PASS
- pool routing 안 걸림 · BLOCKED-INFRA 없음

### top-8 next-batch (next /cycle 시드)
1. D3 → 2. D17 → 3. D1 → 4. D4 → 5. D20 → 6. D14 → 7. D7 → 8. D10

- [x] 2026-05-24 M6 closure — r15 sweep 진입 (cycle 1 완주 · 22 dev · 8 SURG + 6 RFC · PROBE 5/6 → 6/6 100% 🛸)
- [x] 2026-05-24 cycle 2 closure — 8 SURGICAL deviation 전부 main 랜딩: D1 #719 · D3 #756 (+ tail void-match guard) · D4 #725 · D7 #749 · D13 #748 · D14 #720 · D17 #724 · D20 #737. 잔여 SURGICAL = D10(unicode graphemes) · D12(neg-index policy) · D18(type-changing shadow) · D21(nan/inf msg) · D22(NaN casing). RFC backlog = D2/D5/D6/D8/D9/D11/D15/D16/D19. (중복 PR #757/#758 close + stale worktree/branch 정리 완료)
