# strict-citations default-flip 캠페인 (HX8004 Warning→Error)

SSOT 보조 런북. 보드 항목 = ING "strict-citations default-flip 캠페인".

## 목표
컴파일러가 formula-bearing fn에 대해 atlas 인용(`@cite`/`@implements`/`@discover`)을
**빌드 fatal**로 강제하도록 `--strict-citations` default를 OFF→ON으로 뒤집는다.
(RFC-017 §3.1 S8 fatal-citation semantics 복원.)

## 반증 (blind flip 금지 근거) — 실측
- `compiler/main.hexa:408` `let mut strict_citations = false` (default OFF).
- `compiler/main.hexa:742` soft 모드에선 `citation_check` walk를 **통째 skip** (C12 최적화) → 진단 0개.
- `compiler/main.hexa:402-407` 주석이 이유 명시: **"compiler/ source is not yet fully
  cite-bound — every implementation function would need an @implements/@discover
  annotation otherwise."**
- ⇒ default를 ON으로 뒤집으면 **컴파일러 소스 자신**이 unbound라 셀프호스트 빌드가
  codegen 전 abort(exit 1). **릴리즈-무결성(top 가드레일) 위반.** 1줄 flip 불가.

## 트리거 (HX8004) — `compiler/check/citation.hexa:20-23`
formula-bearing item = `@verify`/`@law` 애노를 달았거나, body가 atlas `L[*]` 노드
(`ExprKind::AtlasRef`, kind="L")를 참조 — 그런데 `@implements(L[*])`/`@discover(kind="L")`
바인딩이 없으면 HX8004(Error, S8 fatal).

## 정적 sizing (근사 · origin/main · pool 빌드가 진짜 SSOT)
- 트리거 애노: `@verify` 15, `@law` 15 (compiler) · stdlib 0
- 바인딩 애노: `@implements` 20, `@discover` 12, `@grace` 16, `@cite` 1(comp)+6(std)
- body `L[` 참조: ~111 (주석·배열 오염 포함 → 과대)
- ⇒ 백로그 **수십 규모**로 추정. 진짜값은 파서 AST 판정 필요 → pool 빌드 필수.

## staged plan
1. **측정** — pool(summer)서 origin/main fresh 부트스트랩(`tool/build_hexa_cli.hexa`,
   hexat+clang+runtime.c) 후 `HEXA_STRICT_CITATIONS=1`로 compiler(+stdlib) 컴파일
   → HX8004 실카운트 = 드레인 백로그.
   - ⚠️ summer 설치 hexa v0.609.0 = strict 미지원(구버전) → fresh 빌드 없이는 불가.
   - ⚠️ 클로버 방지: `git worktree add` 격리 체크아웃에서 빌드.
2. **드레인** — 무-바인딩 formula-bearing fn 전부 `@cite`/`@implements`/`@discover`
   부착 → strict 카운트 0. (byteeq-neutral: 게이트만 변경, emit 바이트 불변 —
   codegen은 atlas 무시 `main.hexa:646`.)
3. **flip** — `main.hexa:408` default `false`→`true` + help 텍스트 lockstep
   (`main.hexa:187-188`). byteeq 3-target GREEN + shipping smoke 게이트 후 merge.

## next
① sizing 빌드 (컴퓨트-지출 · user go 대기) — recipe 검증 후 blind 아닌 proper 발사.
   pool 여유(summer load↓) + 정확한 compiler-only 빌드타겟 확정이 선결.
