# PROBE — hexa canonical-deviation audit

@goal: PROBE r14 next-list 23 entries 모두 closed (LANDED PR 또는 filed inbox RFC) — 식별된 canonical deviation 100% 처리. 종료 후 r15 sweep 진입.

표준(Go·Rust·Swift·C#·Python) 모델 대비 hexa의 의미론 이탈을 체계적으로
발굴해 (a) 표면 fix 가능 건은 직접 수정, (b) breaking/design-level 건은
inbox 패치로 제출.

## 진행 (milestones)

- [x] r14 cycle 1-13 surgical+RFC fan-out 완주 (~64 PR 생성 · CHANGELOG/PROBE.log batch sync [#597, #620])
- [x] r14 INBOX 23 entries 모두 closed (LANDED PR 14건 + filed inbox RFC 9건, PROBE.log r14 next-list mass-flip [#620])
- [x] PROBE.log r14 next-list `- [ ]` 23개 → `- [x]` 모두 flip (LANDED PR# 또는 RFC# 표기, [#620])
- [x] PROBE.md coverage table 최종 업데이트 (r14 cycle 7-11 + cycle 13 행 추가, 🔵 inflight → r15-sweep 후보 교체)
- [x] OPEN PR ~36 머지 정리 (~34건 ceremony 머지 완료 · 잔여 #420 admin merge `37b6740d` · #702 g54 보호로 user-review-only)
- [x] r15 sweep 진입 — cycle 1 완료 (8-axis 전수 · 22 deviation 발견 · 8 SURGICAL + 6 RFC backlog · triage `/tmp/probe-r15/cycle1_triage.md`)

## 방법

```
영역별 probe → 격리 .hexa 파일 → hexa run
            → 표준 동작과 비교
            → 이탈 발견 시:
                ├─ surgical fix (header decl · parser tweak · codegen entry)
                │  → worktree from origin/main → 수정 → regen 필요시 + 검증 → PR
                └─ breaking / design-level (전체 마이그레이션 필요)
                   → archive/patches/<slug>.md 제출 → PR
```

## 커버리지

| 상태 | 영역 |
|---|---|
| ✅ probed (canonical, 이상 없음) | 정수 산술 · 음수 modulo · int/float promotion · `**` · 복합대입(`+=`) · 비트(`& \| ^ << >>`) · 문자열 메서드 전체 · bool/string 캐스트 · lambda `\|x\|` · iterator(`for 0..N` `.map` `.fold`) · generic `fn id<T>` · struct · trait/impl(헤더 fix 後) · closure read capture · i64 overflow wrap |
| 🔧 fixed (PR) — round 1-3 | cmd_parse 셸 인젝션 [#342] · 숫자 `as` 캐스트 [#344] · match `=>` [#345] · 명명 fn 일급값 [#346] · `hexa_is_type` 헤더 [#348] · hexa_array_shift decl [#350] · `.rev()` codegen [#351] · `format!()` desugar [#352] · `chr(0)` NUL strbuf [#353] |
| 🔧 fixed (PR) — round 4-8 | match-arm guard incorporation [#379] · OR/Range match pattern [#380] · format brace-escape [#381] · iterator `.first`/`.nth`/`.skip` [#385] · bool→numeric coercion [#393] · runtime.h mass-decl 102 fns [#360, #404, #409] · term_isatty wrappers [#401] · write_file content-leak [#407, #414] · hxlcl_open_sys libc [#407] · posix-fs builtins glob/listdir/tempfile/tempdir [#410] · bare-Ident match arm binding [#412] · hexa_v2 regen [#413, #437, #454] · clang fork-storm token-ring [#408] · closures mut-capture by-reference [#433] (closes #349) · hxlcl_fopen fd<=2 [#426] · stat/fstat/lseek/mmap libc [#431] · exec_with_status3 [#441] |
| 🔧 fixed (PR) — round 9-13 | parser `parse_where_clauses` wire [#417] · parser MacroCall fail-loud [#419] · parser `@derive_meta` + deprecation [#432] · `@derive` repeat + target-validation [#436] · `@cold/@noinline/@hot` fwd decl [#440] · UTF-8 idents [#443, #452] · parse error caret render [#444] · attr whitelist+warn [#448] · trailing comma in call [#449] · pub-use re-export [#447] · IntLit LL suffix [#455] · MapLit infer [#456] · to_string(float) HEXA_FLOAT_REPR [#457] · let const-fold [#459] · `if false {}` DCE [#461] · immutable-let warn + non-exhaustive match warn [#453] · macro expander Phase 1 [#462] · EOF synth-token anchor [#464] · hexa_array_get message [#465] · string OOB throws [#467] · hexa_call0..4 non-callable [#469] · stdlib route utc_now/iso8601_format/iso8601_parse/set_env [#470] |
| 🔧 fixed (PR) — round 14 cycle 7-11 | hex-float lit [#473] · `nil`/`null` reserved 진단 [#474] · NaN/inf casing [#475] · `.codepoints()` alias [#476] · `${...}` JS warn [#478] · open-range slice [#480] · slice negative wrap [#482] · printf/sprintf hint [#484] · `HEXA_STRICT_MATCH` env [#485] · NaN-in-sort comparator [#486] · `inf`/`nan` 상수 [#488] · `HEXA_STRICT_LET` env [#490] · Swift `0...N` alias [#491] · `print_val` NaN/inf parity [#492] · `.graphemes()` stub [#495] · mixed int/float divide IEEE [#497] · bare-block stmt [#498] · `hexa_div` IEEE promo [#499] · `let inf/nan` shadow 진단 [#507] · `is_comparison_op` token-name [#509] · Python f-string [#510] · match multi-arg payload binder [#516] · IfLetExpr codegen [#525] · pipe `\|>` token+desugar [#527] · destructure rename [#529] · `0b/0o` numeric [#537] · struct field defaults [#538] · match-arm guard EnumPath visibility [#543] · smart_ptr Box/Rc/Arc stubs [#549] · lifetime `'a` rejection [#560] · array.pop empty throws [#572] · regex lit [#579] · range `.start/.end/.len` [#581] · enum stack PR-2.1 single TAG_ENUM [#582] · while-let [#584] · non-exhaustive match names [#585] · all-unit-variant TAG_ENUM PR-2.2 [#589] · integer match arm scope leak [#595] |
| 🔧 fixed (PR) — round 14 cycle 13 | raw string `r"..."` [#598] · drill `--rounds` resume [#599] · match as tail-expr [#600] · let-else [#601] · 6 compound assigns [#603] · iterator `.collect/.chain/.count` [#604] · `?.` optional chaining [#607] · comptime mixed-type fold [#613] · HashSet[T] MVP [#616] · enum `<`/`>` ordering [#617] |
| 🟠 filed (inbox PR) | round 5/7/8/9/10 consolidated [#377, #395, #400, #418, #435] · `let` 불변 미강제 + match exhaustiveness [#347] (warn-path landed [#453]) · macro expander pass design RFC [#451] · RFC 087 macro-expander pass design promote [#556] · RFC 090 firmware/rtl codegen lanes [#608] |
| 🟠 filed RFC (round 14) | enum to_string codegen-emit [#489] · macro Phase 2 [#493] · postfix `?` + Result ABI [#494] · shadowing scope codegen 재설계 [#496] · Range repr design [#500] · panic 채널 의미론 [#501] · try-expr + finally [#502] · Some/None prelude 정책 [#505] · tuple type [#506] · raw string [#511] · if-let / while-let [#513] · async/await [#514] · destructure let-decl [#515] · channel + spawn [#517] · multi-line string [#518] · set literal [#519] · pipe operator [#520] · regex literal [#521] · compound assign 완성 [#523] · numeric literal underscore [#524] · struct field defaults [#526] · match-arm guard [#528] · trait dyn dispatch [#532] · iterator alias bundle [#533] · defer 패턴 [#534] · smart pointer [#535] · lifetime `'a` [#536] · enum ordering [#571] · `.pop()` Option [#572] · runtime defer stack [#570] |
| ⛔ STOP / superseded | r14-F enum to_string (architectural, RFC [#489]) · r14-K `-1.0/0.0` (이미 codegen.hexa:4417 landed) · r14-CC multi-arg payload ([#366] already-landed) · r14-OOOO defer hoist ([#570] superset) · r14-PPPP PROBE docs ([#597] sync 이미 land) · r14 regex RFC ([#518] multi-line으로 land) |
| 🟠 filed RFC (r15 cycle 1) | Option/Result `?` operator (D2) · Option/Result `Option[T]=None` assign (D5) · format!() macro expander (D6, [#451] follow-up) · printf-style helper (D8) · unicode byte/codepoint/grapheme len policy (D9) · unicode NFC normalize (D11) · enum single/multi-payload codegen (D15/D16) · shadowing for-loop binding (D19) — RFC backlog 6건 |
| 🔵 r15 cycle 1 발견 SURGICAL (next-batch) | Option/Result D3 pattern-bind `Some(v)` codegen scope (HIGHEST · 30 LoC) · shadowing D17 `{}` block scope (CRITICAL · 40 LoC) · Option/Result D1 `Option[T]` annotation parse (20 LoC) · Option/Result D4 `.unwrap/.unwrap_or/.map` builtin (40 LoC) · range D20 `.rev()` only first (30 LoC) · enum D14 variant identifier codegen (30 LoC) · string_interp D7 f-string `{x:.2}` spec (50 LoC) · unicode D10 `.graphemes()` ZWJ family (80 LoC or RFC) |
| 🔵 inflight (r15 cycle 2 — TBD) | float `0.1+0.2` IEEE 정확도 별도 probe · enum single-payload regression 재확인 ([[project_hexa_lang_enum_payload_works]] 검증) · OOB negative-index policy call · NaN/nan casing 통일 |

## 원칙

- **g1** canonical-first — 표준 모델이 답
- **g11** fix-at-source — workaround 금지, 업스트림으로
- **g4** stacked PRs — 1 logical thing per PR
- **g15** current-state docs — 이력은 `CHANGELOG.md` · `git log` · `PROBE.log.md`

## 진행 로그

체크박스 + 결과 한 줄 — `PROBE.log.md`
