# KEYWORD_DEMOTE — hexa-lang 키워드/식별자 충돌 감사 + demote 후보

> 루트 UPPERCASE.md 작업 로그. hexa-lang 렉서가 hard keyword 로 등록한 단어 중
> 흔한 영단어라 사용자 식별자(함수명·변수명)와 충돌하는 것들을 측정으로 추려
> demote(soft-keyword 또는 제거) 후보군을 확정한다.
> 발단: `tool/n6_verify.hexa` 가 `unhandled statement kind: VerifyStmt` — `verify`
> 를 함수명으로 쓴 게 `verify` hard keyword 와 충돌.

## 측정 (2026-05-19)

433-파일 transpile-sweep (test/ 100 + tool/ + stdlib/flame/) → codegen 미처리
kind 0건, 단 `tool/n6_verify.hexa` 1건만 VerifyStmt (= 키워드 충돌, codegen 갭
아님). 이어 키워드별 「구문(블록) 사용 파일수 vs 식별자 사용 파일수」 측정:

| 키워드 | 구문 사용 | 식별자 사용 | 판정 |
|--------|----------|------------|------|
| `select`   | 0  | 13 | ★★★ 최우선 demote |
| `generate` | 1  | 6  | ★★ demote |
| `channel`  | 0  | 6  | ★★ demote |
| `verify`   | 1  | 4  | ★★ demote |
| `derive`   | 0  | 3  | ★★ demote (구문 0) |
| `optimize` | 1  | 2  | ★ demote (OptimizeFnStmt = codegen no-op hint) |
| `guard`    | 0  | 2  | ★ demote |
| `scope`    | 0  | 1  | ○ 약 demote |
| `intent`   | 1  | 1  | ○ borderline |
| `effect`   | 2  | 2  | ○ borderline (EffectDecl 는 codegen-skip 됨 — cf113765) |
| `proof`    | 13 | 0  | ✋ 유지 — 실사용 多, 충돌 0 |
| `theorem`  | 2  | 0  | ✋ 유지 |
| `spawn`    | 4  | 3  | ✋ 유지 (동시성 실사용) |
| `recover` / `with` / `yield` | 0 | 0 | 구문·식별자 둘 다 0 — 충돌 없음 (정리 optional) |

측정 방법은 heuristic grep (블록 = `^\s*<kw> [A-Za-z{"]` 에서 `<kw>(`·`fn <kw>`
제외; 식별자 = `fn <kw>(` 또는 호출 `<kw>(`). 정확값 아닌 신호 — 그래도
`select` 0/13 같은 격차는 명확.

## 추천 demote 후보군 — Tier-1 (8)

```
select  generate  channel  verify  derive  optimize  guard  scope
```

- 8개 모두 함수/변수명으로 흔한 영단어 + 구문 사용 0~1 파일.
- `select`: 구문 0 / 식별자 13 — 손실 0, 충돌 최대 → 단독으로도 명백 이득.
- `optimize`: OptimizeFnStmt 는 codegen 이 이미 skip 하는 no-op 힌트.

## 유지 (후보 제외)

`proof` (구문 13파일·충돌 0), `theorem`, `spawn` — 실사용 있고 충돌 증거 없음.

## demote 방식

- **soft keyword** — 구문 위치에서만 키워드, 그 외엔 식별자. 구문 보존. parser
  surgery 중간 (`p_expect_ident` + expression parser 가 해당 토큰을 ident 로
  수용해야 함; `fn <kw>` 정의 + `<kw>(` 호출 양쪽).
- **키워드 제거** — lexer 키워드 등록 1줄 제거 + parser dispatch 분기 제거 +
  AST kind / parse_*_stmt 정리. 구문 폐기. 사용 0~1 인 키워드엔 이쪽이 단순.

## 상태

- 측정·후보군 확정 완료 (이 파일).
- **코드 변경 없음** — 어느 키워드를 어느 방식으로 demote 할지 = 언어 표면
  변경이라 사용자 결정 대기 (decision-gate).

## 로그

- 2026-05-19 — `tool/n6_verify.hexa` VerifyStmt 충돌에서 출발. 433-파일 sweep +
  키워드 사용량 측정 → Tier-1 8개 후보군 확정. 이 파일 생성. demote 미착수.
