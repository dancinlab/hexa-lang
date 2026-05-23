# PROBE — hexa canonical-deviation audit

표준(Go·Rust·Swift·C#·Python) 모델 대비 hexa의 의미론 이탈을 체계적으로
발굴해 (a) 표면 fix 가능 건은 직접 수정, (b) breaking/design-level 건은
inbox 패치로 제출.

## 방법

```
영역별 probe → 격리 .hexa 파일 → hexa run
            → 표준 동작과 비교
            → 이탈 발견 시:
                ├─ surgical fix (header decl · parser tweak · codegen entry)
                │  → worktree from origin/main → 수정 → regen 필요시 + 검증 → PR
                └─ breaking / design-level (전체 마이그레이션 필요)
                   → inbox/patches/<slug>.md 제출 → PR
```

## 커버리지

| 상태 | 영역 |
|---|---|
| ✅ probed (canonical, 이상 없음) | 정수 산술 · 음수 modulo · int/float promotion · `**` · 복합대입(`+=`) · 비트(`& \| ^ << >>`) · 문자열 메서드 전체 · bool/string 캐스트 · lambda `\|x\|` · iterator(`for 0..N` `.map` `.fold`) · generic `fn id<T>` · struct · trait/impl(헤더 fix 後) · closure read capture · i64 overflow wrap |
| 🔧 fixed (PR) — round 1-3 | cmd_parse 셸 인젝션 [#342] · 숫자 `as` 캐스트 [#344] · match `=>` [#345] · 명명 fn 일급값 [#346] · `hexa_is_type` 헤더 [#348] · hexa_array_shift decl [#350] · `.rev()` codegen [#351] · `format!()` desugar [#352] · `chr(0)` NUL strbuf [#353] |
| 🔧 fixed (PR) — round 4-8 | match-arm guard incorporation [#379] · OR/Range match pattern [#380] · format brace-escape [#381] · iterator `.first`/`.nth`/`.skip` [#385] · bool→numeric coercion [#393] · runtime.h mass-decl 102 fns [#360, #404, #409] · term_isatty wrappers [#401] · write_file content-leak [#407, #414] · hxlcl_open_sys libc [#407] · posix-fs builtins glob/listdir/tempfile/tempdir [#410] · bare-Ident match arm binding [#412] · hexa_v2 regen [#413, #437, #454] · clang fork-storm token-ring [#408] · closures mut-capture by-reference [#433] (closes #349) · hxlcl_fopen fd<=2 [#426] · stat/fstat/lseek/mmap libc [#431] · exec_with_status3 [#441] |
| 🔧 fixed (PR) — round 9-13 | parser `parse_where_clauses` wire [#417] · parser MacroCall fail-loud [#419] · parser `@derive_meta` + deprecation [#432] · `@derive` repeat + target-validation [#436] · `@cold/@noinline/@hot` fwd decl [#440] · UTF-8 idents [#443, #452] · parse error caret render [#444] · attr whitelist+warn [#448] · trailing comma in call [#449] · pub-use re-export [#447] · IntLit LL suffix [#455] · MapLit infer [#456] · to_string(float) HEXA_FLOAT_REPR [#457] · let const-fold [#459] · `if false {}` DCE [#461] · immutable-let warn + non-exhaustive match warn [#453] · macro expander Phase 1 [#462] · EOF synth-token anchor [#464] · hexa_array_get message [#465] · string OOB throws [#467] · hexa_call0..4 non-callable [#469] · stdlib route utc_now/iso8601_format/iso8601_parse/set_env [#470] |
| 🔧 fixed (PR) — round 14 cycle 1-3 | `nil`/`null` 진단 [#474] · hex-float `0x1.8p+1` [#473] · `to_string` NaN/inf casing [#475] · slice open-range [#480] · slice neg-wrap [#482] · `printf`/`sprintf` use-format [#484] · `inf`/`nan` 식별자 [#488] · `HEXA_STRICT_MATCH` [#485] · NaN-in-sort [#486] · `print_val` 0.0 parity [#492] · Swift `0...N` [#491] · `HEXA_STRICT_LET` [#490] · `.codepoints()` alias [#476] · JS `${...}` warn [#478] · enum to_string codegen-emit RFC [#489] |
| 🟠 filed (inbox PR) | round 5/7/8/9/10 consolidated [#377, #395, #400, #418, #435] · `let` 불변 미강제 + match exhaustiveness [#347] (warn-path landed [#453]) · macro expander pass design RFC [#451] · enum to_string codegen-emit RFC [#489] |
| 🔵 inflight (round 14 cycle 4-6, OPEN PR) | bare-block stmt [#498] · mixed div codegen [#497] · `.graphemes()` stub [#495] · macro Phase 2 RFC [#493] · postfix `?` + Result ABI RFC [#494] · shadow scope leak RFC [#496] · `?.` optional chaining [#504] · runtime mixed div [#499] · panic 채널 RFC [#501] · try-expr/finally RFC [#502] · Range repr RFC [#500] · `let inf/nan` shadow 진단 [#507] · Some/None prelude RFC [#505] · tuple 타입 RFC [#506] · chained comparison RFC [#508] · (HH match-arm payload bind · JJ Python f-string — no PR yet) |
| ⛔ STOP (round 14) | F enum to_string 직접 fix (architectural → RFC [#489]) · K `-1.0/0.0` (이미 `codegen.hexa:4417` r3/r7 closure) · CC multi-arg enum payload parse (이미 [#366]) |

## 원칙

- **g1** canonical-first — 표준 모델이 답
- **g11** fix-at-source — workaround 금지, 업스트림으로
- **g4** stacked PRs — 1 logical thing per PR
- **g15** current-state docs — 이력은 `CHANGELOG.md` · `git log` · `PROBE.log.md`

## 진행 로그

체크박스 + 결과 한 줄 — `PROBE.log.md`
