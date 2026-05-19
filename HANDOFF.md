# HANDOFF — 키워드 demote 작업 (다른 세션 인계용)

> 작성 2026-05-19. hexa-lang 의 충돌-위험 키워드 demote 작업을 다른 세션이
> 이어받기 위한 인계 문서. 분석은 끝났고 **코드 변경 전** 단계에서 멈춤.

## 무슨 작업인가

hexa-lang 렉서가 hard keyword 로 등록한 단어 중 흔한 영단어(함수명·변수명으로
자연히 쓰임)와 충돌하는 것들을 demote(soft-keyword / `@`-attribute 화 / 제거)한다.
발단: `tool/n6_verify.hexa` 가 `fn verify(...)` 를 정의 → `verify` hard keyword 와
충돌 → `codegen ERROR: unhandled statement kind: VerifyStmt`.

## 현재 상태 (코드 변경 0)

- ✅ 분석·후보군·대안키워드 확정 — **`KEYWORD_DEMOTE.md`** (root, SSOT). 커밋
  `dffb4ab5` · `34f06ad2` · `99a0eb43`, origin/rfc043-hexa-torch 푸시됨.
- ✅ 측정: hexa-lang 내부 433-파일 transpile-sweep + 키워드별 사용량.
- ⛔ **demote 코드 변경 미착수.**

## ★ 인계 핵심 — 먼저 할 일: `~/core/*` 전체 blast-radius 측정

hexa-lang 은 의존성 스택의 **최하단** — 키워드 변경은 `~/core/*` 의 모든
다운스트림 `.hexa`(wilson · echoes · anima · hexa-* 등)에 영향. demote 착수 전
반드시 글로벌 사용량을 측정한다:

1. `~/core/*/**/*.hexa` (`.git` 제외) 에서 후보 키워드별로:
   - **construct-form** 사용 (`select { }`, `verify NAME { }` 등) → demote 가
     이걸 **깨뜨림**. 0 이어야 안전.
   - **identifier-form** 사용 (`fn select`, `select(...)`) → demote 가 이걸
     **고침** (현재 충돌로 깨져 있음).
2. construct-form 사용이 0 이면 그 키워드 demote 는 순수 이득(다운스트림
   식별자 충돌 해소, 깨지는 것 0). 0 이 아니면 그 다운스트림은 마이그레이션
   필요 → §거버넌스 참조.

(이 측정 Bash 가 한 번 거부됨 — 사용자가 본 HANDOFF 로 전환 지시. 다음 세션이
read-only grep 으로 수행.)

## 거버넌스 제약 (AGENTS.tape g7 / f3)

hexa-lang 은 upstream — **다운스트림 repo 를 직접 inline-편집 금지** (f3
consumer-direct-edit). 키워드 변경으로 다운스트림 `.hexa` 가 깨지면: (a) demote
를 backward-compatible(soft-keyword)로 설계하거나, (b) 다운스트림 repo 가 자체
수정(그쪽 세션), (c) heads-up 을 남긴다. hexa-lang 세션이 ~/core/wilson 등을
직접 고치지 않는다. (단 read-only grep 측정은 무방.)

## demote 후보군 (KEYWORD_DEMOTE.md §Tier-1 — 8개)

```
select  generate  channel  verify  derive  optimize  guard  scope
```
- `select` 가 최우선: hexa-lang 내부 construct 사용 0 / 식별자 13. 손실 0.
- 대안 키워드: 선언·힌트류(derive·optimize·generate·verify) → `@`-attribute,
  channel → `chan`, guard → `unless`(유지 시), select·scope → 제거. 상세는
  `KEYWORD_DEMOTE.md §대안 키워드`.
- 유지: `proof`(실사용 13)·`theorem`·`spawn` — 충돌 0.

## hexa-lang 측 수정 지점 (키워드 1개당)

1. `self/lexer.hexa` — keyword 등록 줄 제거 (예 `if word == "select"`).
2. `self/parser.hexa` — statement dispatch 분기 (`if kind == "Select"...`) +
   `parse_*_stmt` 함수. soft-keyword 면 `p_expect_ident`/expression parser 가
   해당 토큰을 ident 로 수용하게; 제거면 분기·parse 함수 삭제.
3. `self/codegen_c2.hexa` — 해당 AST kind 핸들러 (제거 시 정리).
4. AST kind 가 `@`-attribute 로 이동하면 attribute 파싱·codegen 경로로.

## 검증 절차 (키워드 demote 후)

1. `hexa parse` parse-gate (lexer/parser/codegen_c2/main.hexa).
2. `hexa cc --regen` → 후보 hexa_v2 빌드 (regen step-3 의 `-x c runtime.o` 버그
   회피: `.new` → `.c` 복사 후 clang. 런타임은 split 구조 — runtime.c 가
   `#include "runtime_core.c"`).
3. 433-파일 transpile-sweep 재측정 (test/ + tool/ + stdlib/flame/) — unhandled
   kind 0 확인.
4. `atlas_verify_smoke` 118/118 + self-host fixpoint byte-identical (regen diff 0).
5. hexa.real 설치, 커밋, push.

## 참고 — 이번 세션 컨텍스트 (오리엔테이션용)

- RFC 062 (argv[0] dedup) LANDED `26a785af`. RFC 061-P1 (runtime 2-layer split,
  runtime.c → runtime_core.c) LANDED `4fb439fc` — 런타임은 이제 split 구조.
- 인터프리터 잔재 제거: run/batch dead code · verify_interp_builtins · bc-VM
  클러스터(16,685줄) 삭제됨. codegen 의 EffectDecl 갭 fix `cf113765`.
- 브랜치 `rfc043-hexa-torch`. `~/core/hexa-lang` 메인 체크아웃은 ~8세션 공유 —
  커밋 전 `git branch --show-current` 확인, 격리 worktree 권장.

## 로그

- 2026-05-19 — HANDOFF 생성. KEYWORD_DEMOTE 분석 완료, demote 미착수.
  다음 세션: `~/core/*` blast-radius 측정 → 안전 키워드부터 demote.
