# INBOX — log

Append-only history sister of `INBOX.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-25 — codegen: 파라미터명이 호출부 struct 필드명과 같으면 미스컴파일

- [ ] `tool/atlas_cli.hexa` 작업 중 발견. `fn f(raw: string)`를 `f(ev.raw)`로 호출하면 함수 body의 `raw`가 호출부 인자값(394자 문자열)이 아니라 `"x"`(len 1)로 바인딩됨 — 파라미터명이 호출부 struct 필드 접근명(`raw`)과 충돌하는 codegen aliasing. `node_raw`로 rename하면 정상. 재현: 3-string-param fn에 `.<param명과 동일한>` 필드접근 인자 전달 → 빌드는 통과하나 런타임에 잘못된 값. 임시회피=param rename, 근본수정=codegen name-resolution (compiler/codegen 영역).

