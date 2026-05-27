# RFC-019 — hexa 에러 메시지 흡수 spec

- **상태**: **Spec draft** (2026-05-09) — 미구현
- **작성일**: 2026-05-09
- **선행 RFC**: RFC-017 (실행-차단 lint), RFC-018 (native codegen)
- **질문 (사용자)**: "Python/TS 스타일 메시지를 hexa-lang 자체가 빠르게 흡수할 수 있나?"
- **답변 요지**: **예. atlas SSOT + hexa로 작성된 catalog + diagnostic builder API + i18n 분리** 4축으로 빠른 흡수 가능. 본 spec 은 그 메커니즘.

---

## 1. 동기

| 언어 | 강점 | 약점 |
|---|---|---|
| Rust | 에러 코드, fix-it, 색상, 정밀 span | 길어서 noisy |
| TypeScript | 타입 차이 정확, "did you mean", 모아 출력 | strict 모드에서 갯수 압도 |
| Elm | 가장 친절, 예시 동봉 | 빌드 시간 |
| Python | 짧고 명료 | strict 부족 |
| **hexa 채택 모델** | **Rust 베이스 (코드/span/fix-it) + Elm의 친절함 (예시/원인) + atlas 결속** | — |

핵심: 메시지가 **hexa 자체 자산** (catalog/atlas) 이라야 빠르게 흡수·확장·검증 가능.

---

## 2. 에러 코드 카탈로그

### 2.1 코드 형식

`HX[CCCC]` 4자리. 그룹별 1000번대 분배:

| 범위 | 그룹 | 단계 (RFC-017 § 3.1) |
|---|---|---|
| HX0xxx | parse / lex | S0 |
| HX1xxx | atlas resolve | S1 |
| HX2xxx | bind / scope | S2 |
| HX3xxx | type | S3 |
| HX4xxx | domain (ℝ/ℕ/ℤ) | S4 |
| HX5xxx | units | S5 |
| HX6xxx | equational verify | S6 |
| HX7xxx | smt prove | S7 |
| HX8xxx | citation (atlas L[*] 인용) | S8 |
| HX9xxx | codegen / linker / runtime panic | RFC-018 |

### 2.2 카탈로그 저장 위치

`stdlib/diagnostics/catalog.hexa` — **hexa 자체로 작성**. 컴파일러 빌드 시 정적 임베드.

```hexa
@diagnostic(HX1042)
diag atlas_node_not_found {
    title    = "atlas 노드 없음"
    severity = error
    stage    = S1
    message  = "atlas {atlas_hash} 에 `{node_id}` 라는 {kind} 노드 없음"
    explain  = """
        이 식별자는 P/C/L 토큰 중 하나로 사용됐지만,
        hexa.toml 에 핀된 atlas 버전에 존재하지 않습니다.
        오타이거나 atlas 업데이트 후 컴파일러 재빌드가 필요할 수 있습니다.
    """
    suggest  = did_you_mean(atlas, node_id)   // fn 호출
    fix_it   = replace_token(node_id, suggest) if suggest
    related  = [HX1041 /* atlas hash mismatch */]
    examples = [
        { bad: "P[einstien]",  good: "P[einstein]"  }
    ]
}
```

### 2.3 self-bootstrap 검증

- 컴파일러가 자기 자신의 catalog 를 검증 (모든 emit 지점이 catalog 에 있는 코드만 사용)
- catalog 내 P/C/L/E 인용은 atlas-resolved (RFC-017 S1)
- 메시지 텍스트도 회귀 테스트 (snapshot)

---

## 3. 메시지 구조 (사용자에게 보이는 형태)

```
HexaError [HX1042] example/foo.hexa:42:11–28
    let p = P[einstien-mass-energy]
                ^^^^^^^^^^^^^^^^^^^   atlas 노드 없음

    원인: atlas a3f9...c2 에 P 노드 `einstien-mass-energy` 없음
    추천: P[einstein-mass-energy]      (Levenshtein distance 1)
    수정: hexa fix --apply HX1042 example/foo.hexa  (자동 수정 가능)

    참고: atlas 버전은 hexa.toml [atlas].hash 에 핀됨
    설명: hexa explain HX1042
```

라인 분해
1. **헤더**: `HexaError`/`HexaWarn` + 코드 + path:line:col-col
2. **소스 발췌**: ±2 라인 컨텍스트, span underline
3. **원인** (`원인:`): 1줄, 무엇이 어떻게 틀렸는지
4. **추천** (`추천:`): did-you-mean / 가능한 변환
5. **수정** (`수정:`): fix-it 가능 시 명령어
6. **참고**: 관련 정보 (핀 위치, 관련 에러 코드 등)
7. **설명**: `hexa explain` 진입점

색상: TTY 일 때만 ANSI escape. JSON 모드에선 색상 없음.

---

## 4. 흡수 메커니즘 — 빠른 추가/확장의 5축

### 축 A — atlas E 노드 통합

에러도 atlas SSOT의 일부 (`E[*]`).
```
atlas.n6 에 E[atlas-node-not-found] 추가
  ↓
catalog.hexa 가 그 E 노드를 인용 (@diagnostic(HX1042) → E[atlas-node-not-found])
  ↓
컴파일러가 빌드 시 자동으로 catalog ↔ atlas 일치 검증
```

장점: 새 검사 추가 = atlas E 노드 1줄 + catalog 1 블록 + 컴파일러 emit 지점 1줄 = **3 곳 수정**.

### 축 B — Diagnostic builder API

컴파일러 내부에서 에러 emit 시:
```hexa
Diagnostic::new(HX1042)
    .span(token.span)
    .arg("atlas_hash", atlas.hash_short())
    .arg("node_id", token.text)
    .arg("kind", "P")
    .suggest(did_you_mean(atlas, token.text))
    .emit(ctx)
```

builder가 catalog 의 message template 을 읽어 자동 포맷. 컴파일러 본체에 hardcoded 메시지 텍스트 없음.

### 축 C — 메시지 텍스트와 로직 분리 (ENGLISH ONLY, 결정 2026-05-09)

```
stdlib/diagnostics/messages.hexa    ← English message templates
stdlib/diagnostics/catalog.hexa     ← code / structure
```

- catalog 는 메시지 키만 (`message_key = "atlas_node_not_found.message"`)
- `messages.hexa` 가 키 → 영어 템플릿 매핑
- **i18n / 다국어는 채택하지 않음** — 사용자 결정으로 영어 단일 고정
- 메시지 변경 시 회귀 (snapshot) 자동 검증으로 일관성 유지

### 축 D — 회귀 테스트가 자동

```hexa
// stdlib/diagnostics/tests/HX1042_test.hexa
@error_test(HX1042)
test_atlas_node_typo {
    input    = "let p = P[einstien]"
    expect_diag = {
        code: HX1042,
        span: 9..18,
        suggest: "P[einstein]",
    }
}
```

메시지 텍스트 변경 시 snapshot 비교 회귀 (CI 게이트).

### 축 E — fix-it / LSP 통합

각 diag 에 `fix_it` 필드 (optional):
- `replace_token(span, new_text)`
- `insert(pos, text)`
- `delete(span)`
- `multi(actions...)`

LSP 가 code action 으로 자동 노출. CLI에선 `hexa fix --apply HX1042 file.hexa`.

---

## 5. did-you-mean 엔진

| 케이스 | 알고리즘 |
|---|---|
| atlas 노드 typo (`P[einstien]`) | atlas 노드 이름 trie + Levenshtein ≤ 2 |
| 변수 typo (`prnt(x)`) | scope 안 식별자 + Levenshtein ≤ 2 |
| 단위 mismatch (`m + s`) | 가능한 변환 / dimensional analysis 제안 |
| 함수 시그니처 (`fn f(x: i32)` 호출 `f("a")`) | 인자 타입 + nearest call site 찾기 |
| import 경로 (`import std.atlsa`) | stdlib 트리 + Levenshtein |

캐시: 컴파일러 시작 시 atlas 노드 trie 한 번 빌드 (정적 const 라 ~ms).

---

## 6. 다중 에러 정책

| 규칙 | 동작 |
|---|---|
| 모아서 출력 | 첫 에러에서 멈추지 않음 (TS 모델) |
| cascade 압축 | "타입 X가 정의 안 됨" → "X를 사용한 5곳" 은 1건으로 압축 |
| 페이지네이션 | 50건 초과 시 첫 50 + `... and 47 more (use --all)` |
| Threshold abort | 200건 초과 시 더 이상 누적 안 함 (성능 보호) |
| sort | 파일 → 라인 순 |

---

## 7. 출력 모드

| 모드 | 트리거 | 용도 |
|---|---|---|
| pretty (default) | TTY | 사람 |
| short | `--error-format=short` | grep 친화 |
| json | `--error-format=json` | IDE/CI, 한 줄 1 diag, `lint_log.jsonl` 호환 |
| github | `--error-format=github` | `::error file=...,line=...` GitHub Actions annotation |

JSON 스키마
```json
{
  "code": "HX1042",
  "severity": "error",
  "stage": "S1",
  "file": "example/foo.hexa",
  "span": { "line": 42, "col_start": 11, "col_end": 28 },
  "message": "...",
  "args": { "node_id": "einstien", "atlas_hash": "a3f9..." },
  "suggest": "P[einstein-mass-energy]",
  "fix_it": { "kind": "replace", "span": [...], "text": "..." },
  "related": ["HX1041"]
}
```

---

## 8. `hexa explain HX1042`

binary 안 `.hexa.diag` 섹션에서 catalog 의 `explain` + `examples` 추출 → stdout.

```
$ hexa explain HX1042
HX1042 — atlas 노드 없음 (S1)

설명:
    이 식별자는 P/C/L 토큰 중 하나로 사용됐지만,
    ...

예시:
    bad:  let p = P[einstien]
    good: let p = P[einstein]

관련:
    HX1041  atlas hash mismatch
    HX1043  atlas append schema invalid
```

---

## 9. 통계 / telemetry (opt-in)

- `hexa.toml [diagnostic] telemetry = true` 시
- 컴파일 실패 시 (코드, 빈도) 로컬 카운트 → `~/.cache/hexa/diag_stats.jsonl`
- `hexa diag-stats` 로 가장 흔한 에러 보기 → 메시지 개선 우선순위 결정
- 기본 OFF, 외부 전송 절대 X

---

## 10. 빠른 흡수 — 새 에러 1건 추가하는 법 (목표 ≤ 5분)

| 단계 | 파일 | 작업 |
|---|---|---|
| 1 | `~/core/nexus/n6/atlas.append.*.n6` | 새 `E[my-new-error]` 노드 1줄 추가 |
| 2 | `stdlib/diagnostics/catalog.hexa` | `@diagnostic(HX2099)` 블록 1개 추가, message_key 정의 |
| 3 | `stdlib/diagnostics/messages.hexa` | `"my_new_error.message" = "..."` (English) 1줄 |
| 4 | 컴파일러 emit 지점 (예: `compiler/check/types.hexa`) | `Diagnostic::new(HX2099)...emit(ctx)` |
| 5 | `stdlib/diagnostics/tests/HX2099_test.hexa` | snapshot 테스트 1개 |
| 6 | (CI 자동) | atlas 변경 → 컴파일러 재빌드 → catalog ↔ atlas 일치 검증 |

→ 4–6 곳 수정. atlas E 노드 일치 검증, snapshot 회귀 모두 자동.

---

## 11. 단계적 로드맵

| Phase | 산출물 |
|---|---|
| 1 | `stdlib/diagnostics/catalog.hexa` 스켈레톤 + HX0xxx (parse) 정의 |
| 2 | `Diagnostic` builder API + span 표시 + 색상 |
| 3 | did-you-mean (atlas trie + Levenshtein) |
| 4 | 다중 에러 collector + cascade 압축 |
| 5 | JSON / github 출력 모드 |
| 6 | `hexa explain` (binary 추출) |
| 7 | fix-it / `hexa fix --apply` |
| 8 | (skipped — ENGLISH ONLY 결정 2026-05-09) |
| 9 | atlas E 노드 통합 + catalog ↔ atlas drift CI |
| 10 | LSP code action + telemetry opt-in |

---

## 12. 미해결

1. 메시지 텍스트의 a11y (스크린리더) 가이드라인
2. 색상 팔레트 (red/yellow/cyan) — 색맹 친화 옵션
3. `hexa explain` 의 in-binary 디스크 비용 (`.hexa.diag` 섹션 크기)
4. 다국어 추가 시 catalog 의 변수 보간 일관성 (Korean vs English 어순)
5. fix-it 다중 케이스 충돌 시 우선순위
6. catalog 자체 RFC drift 정책 (HX 코드 retire 절차)

---

## 13. 한 줄 결론

에러 메시지 = **atlas E 노드 + hexa-작성 catalog + builder API + (English-only) message templates + snapshot 회귀** 5축으로 hexa-lang이 자체 흡수. 새 에러 1건 추가는 4–6 파일 수정 / 5분 이내 / 자동 검증. Rust 의 풍부함 + Elm 의 친절함 + atlas 결속으로 hexa 고유의 검증력 확보.
