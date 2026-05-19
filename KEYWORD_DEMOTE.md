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
- **대안 키워드로 rename** — 구문은 살리되 충돌 없는 새 키워드로. 아래 §대안.

## 대안 키워드 (구문 보존 시)

demote 한 단어의 구문을 유지하려면 식별자 충돌이 거의 없는 대체 표면이 필요.
핵심 원칙: hexa 는 이미 `@`-attribute 체계(`@pure`·`@cite`·`@gpu`·`@invariant`)
보유 — `@` sigil 은 식별자와 **구조적으로 충돌 불가**. 선언/힌트류는 `@`-attr 이
자연스러운 집. 제어흐름 statement 류만 별도 키워드 필요.

| demote | 구문 성격 | 권장 대안 | 비고 |
|--------|----------|----------|------|
| `derive`   | 선언 어노테이션 | **`@derive`** | Rust `#[derive]` 선례. 충돌 0 |
| `optimize` | codegen 힌트 (no-op) | **`@optimize`** | Rust `#[optimize]`. 어노테이션이 정확한 성격 |
| `generate` | compile-time codegen | **`@generate`** | fn/블록에 붙는 어노테이션 |
| `verify`   | 검증 블록 | **`@verify { }`** | attribute-block. `@invariant` 와 일관 |
| `channel`  | 동시성 채널 타입 | **`chan`** | Go 관례. `chan` 은 식별자로 거의 안 쓰임 (short type-keyword) |
| `guard`    | 조기-return 제어흐름 (구문 0) | **`unless`** 또는 제거 | `unless cond { }` — Ruby/Perl 유산, fn명 충돌 ~0. 사용 0 이면 제거가 단순 (`if !cond {}` 슈가) |
| `scope`    | 스코프 블록 (구문 0) | `@scope` 또는 제거 | 사용 0 — 제거 권장 |
| `select`   | 동시성 multiplex (구문 0) | `@select { }` 또는 제거 | 사용 0 — 제거 권장; 미래 동시성-select 면 `@select` 블록 |

요약: **`@`-attribute 화** = derive·optimize·generate·verify (+ borderline effect·
intent·invariant). **타입 키워드 단축** = channel→`chan`. **제어흐름** = guard→
`unless`(유지 시) / select·scope (구문 0 → 제거). 어느 것도 흔한 식별자 단어가
아니라 충돌이 구조적으로 사라짐.

## 혼동 주의 — 렉서 키워드 ≠ CLI 서브커맨드

`verify`(및 후보 중 `select` 등)는 CLI 서브커맨드로도 존재하지만 **레이어가
완전히 다르다**:
- 렉서 키워드 `verify` — `.hexa` 소스 파싱 시 토큰. 이 문서의 demote 대상.
- CLI `hexa verify` — `self/main.hexa` 디스패처의 `if sub == "verify"` — 셸
  argv 에서 온 런타임 **문자열** 비교. 렉서 키워드 테이블과 무관.

→ 렉서 키워드를 demote/제거해도 `hexa verify` CLI 명령어 · `tool/verify_cli.hexa`
· `bin/hexa-verify` 는 **영향 없음**. CLI 서브커맨드는 교체 불필요.

## 다운스트림 blast-radius 측정 (2026-05-19)

HANDOFF §★ 의 글로벌 측정 수행. **git-tracked `.hexa` 만** 집계 — `find` 는
~/core 전체에서 83만 `.hexa` 를 세지만 대부분 비추적 빌드 스냅샷이라 무의미.
다운스트림 = wilson·anima·hexa-bio·hexa-brain·hexa-mind·hexa-chip·phanes·
demiurge·wisp·hexa-meta·hexa-os·hexa-codex (git-tracked: anima 2601 ·
hexa-brain 475 · hexa-bio 208 · wilson 171 · hexa-chip 142 · 나머지 ≤4).

| 키워드 | DS 구문(block) | DS 식별자(fn def) | 해석 |
|--------|---------------|------------------|------|
| `select`   | 0  | 0 | 다운스트림 무사용 — 완전 안전 |
| `channel`  | 0  | 0 | 완전 안전 |
| `guard`    | 0  | 0 | 완전 안전 |
| `scope`    | 0  | 0 | 완전 안전 |
| `derive`   | 0  | 1 | 구문 0 — 안전 |
| `optimize` | 0  | 1 | 구문 0 — 안전 |
| `generate` | 1  | 9 | 구문 소수 + 식별자 9파일 충돌 |
| `verify`   | 16 | 1 | ★ 구문 16파일 — 제거/attribute 불가 |
| `intent`   | 18 | 0 | 구문 heavy — Tier-1 후보 제외 |
| `effect`   | 6  | 0 | 구문 heavy — Tier-1 후보 제외 |

핵심 정정: `verify` 는 다운스트림 16파일이 `verify {}` 구문을 실사용 →
**제거·attribute 이전 불가** (그 16파일은 다운스트림이라 f3 로 직접 수정 금지).
`intent`·`effect` 도 구문 사용이 식별자보다 압도적 → Tier-1 후보에서 **제외**.

## 외부 언어 사례 조사 (web, 2026-05-19)

키워드/식별자 충돌 해소는 모든 주류 언어가 거친 문제. 검증된 3패턴:

1. **soft keyword (contextual keyword)** — 구문 위치에서만 키워드, 그 외엔
   식별자. Python `match`/`case` (PEP 634) · C# `async`·`await`·`partial`·
   `where` · Scala 3 `as`·`derives`·`end` · Kotlin soft keyword. C# 설계
   원칙: "신규 키워드는 구버전 프로그램을 깨지 않도록 contextual 로 추가한다."
   PEP 635: `match` 는 구문·식별자 양쪽으로 너무 흔해 hard keyword 화하면
   거의 모든 기존 코드가 깨짐 → soft 가 유일한 답.
2. **sigil attribute (`@` / `#[...]`)** — Rust `#[derive]`·`#[optimize]`.
   sigil 은 식별자와 구조적으로 충돌 불가 — 선언·힌트류의 정확한 집.
3. **backtick escape** — Swift `` `class` ``. 키워드를 식별자로 탈출.
   강력하지만 렉서 복잡도 + 호출부도 backtick 필요 → hexa 엔 과함, 채택 안 함.

parser 적용성: PEP 634 의 핵심 제약 — "soft keyword 는 parser 가 **다음
토큰**만으로 키워드/식별자를 구분 가능한 위치에만 둬야 한다." hexa 의
hand-written recursive-descent parser 는 2-토큰 lookahead 버퍼링이 가능 →
`verify NAME {` (peek1=ident, peek2=`{`) 면 구문, 아니면 `verify` 를 ident 로
흘려 expression-statement 로 fallthrough. handwritten parser 라 strict
LL(1) 제약을 받지 않음.

## ★ 최종 계획 v2 — perfect design (사용자 지시 2026-05-19)

> 사용자 지시: "현재 이미 사용되고 있는 것 염두하지 말고 완벽하게 가자,
> 코드들 고치면 되니까." → **backward-compat 제약 해제**. v1 의 soft-keyword
> 타협(`verify`·`generate` 구문 보존)을 폐기하고 **이상적 키워드 표면**으로
> 직행한다. 다운스트림 파손은 허용 — 기계적 마이그레이션으로 고친다.

### 설계 원칙

hard keyword 는 (a) 진짜 제어흐름·구조 primitive 이고 (b) 흔한 함수/변수
이름이 아닐 때만. 선언·힌트·검증류는 전부 `@`-attribute 로 — `@` sigil 은
식별자와 **구조적으로** 충돌 불가하고, hexa 는 이미 `@pure`·`@cite`·`@gpu`·
`@invariant` 체계 보유. soft keyword 는 "구문/식별자 둘 다 보존"의 타협일 뿐
— 완벽한 표면이 아니다. 완벽 = sigil 로 충돌을 구조적 소멸.

### v2 키워드 운명표 (10 후보)

| 키워드 | v2 방식 | 비고 |
|--------|---------|------|
| `select`   | **제거** | 구문 0 — 죽은 무게 |
| `scope`    | **제거** | 구문 0 |
| `guard`    | **제거** | `if !cond {}` 슈가, 구문 0 |
| `channel`  | **제거** | 구문 0. 동시성 채널이 실제 필요해지면 `chan` (Go convention) 으로 신규 도입 |
| `derive`   | **`@derive`**   | Rust `#[derive]` |
| `optimize` | **`@optimize`** | codegen no-op 힌트 — attribute 가 정확한 성격 |
| `generate` | **`@generate`** | compile-time codegen 어노테이션 |
| `verify`   | **`@verify { }`** | attribute-block — `@invariant` 와 일관 |
| `intent`   | **`@intent`** | 선언 어노테이션 |
| `effect`   | **`@effect`** | EffectDecl = codegen-skip, 어노테이션 성격 |

**유지 (hard keyword)**: `proof` · `theorem` (atlas-bound theorem = hexa
정체성 핵심, named block, 식별자 충돌 0) · `spawn` (동시성 primitive, 충돌 0).
이들은 "흔한 식별자 단어"가 아니고 진짜 일급 구문이라 키워드가 맞다.

→ 10 후보 = **4 제거 + 6 `@`-attribute**. 남는 hard keyword 는 전부 진짜
primitive 거나 정체성-핵심 + 충돌 0. (`intent`·`effect` 는 v1 에서 "borderline,
제외"였지만 v2 는 backward-compat 제약 해제 → 같은 `@`-attribute 패밀리로
편입. 일관성 ↑.)

### 다운스트림 마이그레이션 (flag-day, 기계 치환)

backward-compat 제거 → 이상 표면 직행. dual-accept 같은 transitional cruft
없음 ("완벽" = 과도기 없음). hexa-lang 이 언어 변경을 land 하는 시점에
다운스트림을 lockstep 마이그레이션:

| 패턴 | 치환 | 다운스트림 파일수 | hexa-lang 파일수 |
|------|------|------------------|------------------|
| `^verify NAME {`   | `@verify NAME {`   | 16 | 1 |
| `^intent ...`      | `@intent ...`      | 18 | 1 |
| `^effect ...`      | `@effect ...`      | 6  | 2 |
| `^generate ...`    | `@generate ...`    | 1  | 1 |
| `^derive ...`      | `@derive ...`      | 0  | ≤1 |
| `^optimize ...`    | `@optimize ...`    | 0  | ≤1 |

`fn verify(...)`·`fn generate(...)` 등 **식별자 정의는 자동 합법화** —
마이그레이션 불필요 (그게 핵심 이득).

치환은 줄-시작 토큰 sed-scriptable. f3 (consumer-direct-edit 금지) 준수 방식:
hexa-lang 세션은 (a) 언어 변경 land + (b) `tool/migrate_kw_v2.sh` 스크립트
제공. 각 다운스트림 repo 는 자기 커밋으로 스크립트 적용 (또는 별도 세션).
hexa-lang 세션이 다운스트림 트리를 inline-편집하지 않는다.

### 4-페이즈 롤아웃 (위험 오름차순)

**Phase 1 — 제거 4개 (`select` · `scope` · `guard` · `channel`).** 순수
빼기. `self/lexer.hexa` 키워드 등록 1줄 + `self/parser.hexa` dispatch 분기 +
`parse_*_stmt` 함수 + `self/codegen_c2.hexa` AST kind 핸들러 삭제. parser
surgery 최소. 다운스트림 영향 0 (구문 사용 전부 0).

**Phase 2 — `@`-attribute 인프라 + 무위험 2개 (`derive` · `optimize`).**
`@derive`·`@optimize` 파싱·codegen 경로 추가 (기존 `@pure`/`@cite` 메커니즘
확장). hexa-lang 내 구문 사용 ≤1파일 마이그레이션 → 옛 키워드 lexer 등록
제거. 다운스트림 영향 0.

**Phase 3 — `@`-attribute 4개 (`generate` · `verify` · `intent` · `effect`).**
attribute-block 형식 (`@verify NAME { }`) 파싱 포함. hexa-lang 내 구문 사용
마이그레이션 (verify 1 · intent 1 · effect 2 · generate 1 = 5파일). 옛
키워드 lexer 등록 제거. 발단 버그 `tool/n6_verify.hexa` 의 `VerifyStmt` 는
이 Phase 에서 해소.

**Phase 4 — 다운스트림 flag-day 마이그레이션.** `tool/migrate_kw_v2.sh` 배포.
영향받는 다운스트림 repo: anima (verify·intent·effect 다수) · hexa-brain ·
hexa-bio · wilson · hexa-chip · 기타. 각 repo 자기 커밋. CI 게이트:
영향받는 모든 repo 의 `hexa parse` 통과.

각 페이즈 = 독립 커밋 + 독립 검증 (검증 절차는 아래 §검증 동일).

### 검증 절차 (페이즈별)

1. `hexa parse` parse-gate — `lexer`·`parser`·`codegen_c2`·`main.hexa`.
2. `hexa cc --regen` → hexa_v2 재빌드 (regen step-3 `-x c runtime.o` 버그
   회피: `.new`→`.c` 복사 후 clang; 런타임 split — `runtime.c` 가
   `#include "runtime_core.c"`).
3. 433-파일 transpile-sweep 재측정 — unhandled kind 0.
4. `atlas_verify_smoke` 118/118 + self-host fixpoint byte-identical.
5. hexa.real 설치 · 커밋 · push.

Phase 4 추가: 다운스트림 12 repo `hexa parse` smoke (스크립트 적용 후 0
파손 확인).

## 상태

- ✅ v2 perfect design 확정 (backward-compat 제약 해제, 사용자 지시
  2026-05-19). 10 후보 = 4 제거 + 6 `@`-attribute, hard keyword 잔류 3개
  (`proof`·`theorem`·`spawn`).
- ✅ **Phase 1 LANDED (worktree `kw-demote-phase1`)** — `select`·`scope`·
  `guard`·`channel` 4 키워드 제거. lexer 4줄 + parser ~133줄 + codegen ~47줄
  + formatter ~18줄 + lsp 키워드 목록 + VSCode tmLanguage 정규식 정리. 6/6
  parse-gate PASS, 30/30 sample test parse-gate PASS, identifier-as-`guard`
  4 파일 PASS. 다운스트림 영향 0.
- ✅ **Phase 2 LANDED (worktree `kw-demote-phase1`)** — `derive`·`optimize`
  → `@derive`·`@optimize` attribute. M0 attribute collection (`self/parser.hexa`
  L697 인근) 이 이미 `@<keyword>` 와 `@<ident>` 양쪽을 처리하므로 추가 인프라
  없이 lexer 키워드 등록 제거만으로 자동 활성화. parser ~64줄 + codegen ~17줄
  + formatter ~23줄 정리. hexa-lang 내부 1파일 마이그레이션
  (`self/test_keyword_audit.hexa` L347: `optimize fn` → `@optimize fn`).
  6/6 parse-gate PASS, 30/30 smoke PASS. 다운스트림 영향 0.
- ✅ **Phase 3 LANDED (worktree `kw-demote-phase1`)** — `generate`·`verify`·
  `intent`·`effect` → `@`-attribute. M0 dispatch 분기 4개 신설 (`@invariant {}`
  패턴 mirror, 2-token lookahead 로 attribute-block vs 일반 attribute 식별).
  parse_*_stmt 4 함수에서 leading `p_advance()` 제거 (M0 이 이미 키워드를
  consume). parse_stmt dispatch + p_generate_is_stmt_here + tier-2
  reserved-id 헬퍼 정리. hexa-lang 내부 5파일 마이그레이션
  (test_keyword_audit.hexa 4개 + tool/pkg/packages/token-forge/forge.hexa 3개).
  source-level 6/6 parse-gate PASS + smoke 30/30 PASS. 마이그레이션된 .hexa 5
  파일은 *post-regen* 검증 (현재 installed binary 는 새 dispatch 미보유, 다음
  regen 후 신 parser 로 정상 처리).

## 로그

- 2026-05-19 — `tool/n6_verify.hexa` VerifyStmt 충돌에서 출발. 433-파일 sweep
  + 키워드 사용량 측정 → Tier-1 8개 후보군 확정. 이 파일 생성. demote 미착수.
- 2026-05-19 — 다운스트림 blast-radius 측정 (git-tracked `.hexa`, 12 repo) +
  web 외부 사례조사 (Python PEP 634 · C# · Rust · Scala 3 · Swift). v1: 8
  후보를 3 방식(제거 4 / `@`-attribute 2 / soft keyword 2)으로 확정,
  backward-compat 보존.
- 2026-05-19 — 사용자 지시 "완벽하게 가자, 코드 고치면 되니까" → **v1 폐기,
  v2 perfect design 확정**. backward-compat 제약 해제. 10 후보 (intent·effect
  편입) = 4 제거 + 6 `@`-attribute. soft keyword 미사용 — sigil 로 충돌 구조적
  소멸. 다운스트림 flag-day 마이그레이션 (총 ~46파일, 기계 치환) Phase 4.
  코드 변경은 여전히 미착수.
- 2026-05-19 — **Phase 1 LANDED** (worktree branch `kw-demote-phase1`,
  commit `5c90a78a`). `select`·`scope`·`guard`·`channel` 4 키워드 제거.
  7 파일 수정 (lexer · parser · codegen_c2 · formatter · lsp · VSCode
  syntax · 본 문서). Parse-gate 6/6 PASS, 30/30 sample test PASS,
  identifier-as-`guard` 4 파일 PASS. 다운스트림 영향 0. bootstrap regen +
  433-파일 sweep + atlas verify 는 사용자의 다음 정기 regen 사이클에서
  (오늘 시점의 로컬 `hexa.real` 은 타 세션 WIP 로 인해 corrupted 상태).
- 2026-05-19 — **Phase 2 LANDED** (same branch, follow-up commit).
  `derive`·`optimize` → `@derive`·`@optimize` attribute. M0 attribute
  collector 가 이미 `@<keyword>` + `@<ident>` 양쪽 처리 → lexer 등록 제거만
  으로 자동 활성. 7 파일 수정 (lexer · parser · codegen · formatter · lsp ·
  VSCode syntax · test_keyword_audit 1줄 migrate). +13/-103 lines.
  parse-gate 6/6 PASS, smoke 30/30 PASS.
- 2026-05-19 — **Phase 3 LANDED** (same branch, third commit).
  `generate`·`verify`·`intent`·`effect` → `@`-attribute. M0 dispatch 분기
  4개 신설 (peek + peek_ahead(1) lookahead 로 attribute-block 식별; 비-block
  사용은 일반 attribute 경로로 fallthrough). parse_*_stmt 4 함수의 leading
  `p_advance()` 제거. parse_stmt dispatch + `p_generate_is_stmt_here` +
  tier-2 reserved-id 헬퍼 정리. AST kind 명세 doc 업데이트. lexer/lsp/VSCode
  syntax 정리. 5 hexa-lang 파일 마이그레이션 (test_keyword_audit 4개 +
  tool/pkg/packages/token-forge/forge.hexa 3개). source-level 6/6 parse-gate
  PASS + 30/30 smoke PASS. 마이그레이션된 .hexa 5 파일의 parse-gate 는
  post-regen (installed binary 는 새 M0 dispatch 미보유). v2 design 의 핵심
  발단 버그 `tool/n6_verify.hexa` 의 `VerifyStmt` 충돌이 본 phase 에서 해소.
