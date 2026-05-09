# RFC-017 — atlas.n6 임베딩 + 실행-차단 수식/공식 lint

- **상태**: **Direction set** (2026-05-09) — native compiler 전환 + atlas 정적 내장 결정
- **작성일**: 2026-05-09
- **모드**: brainstorming → 방향 결정 (구현 미진행)
- **결정 (2026-05-09)**: hexa-lang을 **native 컴파일러**로 전환하고 atlas.n6를 **정적 내장**한다. 인터프리터 + mtime cache 안은 폐기.
- **선행 자산**: `gate/lint.hexa` (현 P8 marker-budget enforcement), `tool/n6_verify.hexa`, `tool/drill_breakthrough_criteria.json` (`shared/n6/atlas.n6`을 외부 SSOT로 인용)
- **영향 영역**: hexa 컴파일러 (신설/재작성), `stdlib/atlas/*` (정적 임베디드 모듈), `gate/lint.hexa` (컴파일러 흡수), `hexa.toml` `[atlas]` 섹션
- **검증**: 미정 — 본 RFC는 방향 설계

---

## 1. 동기 (Why)

1. `atlas.n6` (P/C/L 노드 SSOT)이 `tool/drill_breakthrough_criteria.json` 등에서 외부 참조로만 쓰임. 언어/lint는 이 SSOT를 모름.
2. 현 lint는 marker-budget 기반 "soft" warn — 위반이 누적돼도 실행은 됨.
3. 목표: **Python `SyntaxError` / TypeScript `tsc` strict** 와 동일하게, 위반 시 **컴파일 0줄 통과 안 함, 바이너리 자체가 안 만들어짐**.
4. 수식·공식 작성 시 (`@law`, `@implements`, `@units`, citation `L[*]`) atlas SSOT와 자동 결속해 컴파일 타임에 검증.
5. atlas 본체 4.2 MB / append 409개 (실측) → 인터프리터로 매 실행 검증 시 LSP·CI 비현실적 (200ms × N). **native 컴파일 + 정적 내장**으로 검증을 빌드 타임 1회에 흡수, 런타임 0ms.

---

## 2. atlas.n6 내장 — 방식 스펙트럼

가장 얕은 → 가장 깊은:

| 안 | 설명 | 비고 |
|---|---|---|
| 1. 참조형 (현 상태) | JSON 등에서 외부 path | lang 무지 |
| 2. stdlib 모듈형 | 빌드 타임 codegen → `stdlib/atlas/snapshot.hexa` | `import std.atlas` |
| 3. 컴파일러 임베디드 리소스 | `hexa` 바이너리에 `atlas.bin` + SHA 정적 링크 | `hexa --atlas-info` |
| 4. 언어 키워드형 | `P[…]` `C[…]` `L[…]` 토큰 — 컴파일 시 룩업 | 문법 확장 |
| 5. 타입 시스템 통합 | `Primitive`, `Law`, `Connection`이 nominal type | type 검사 통합 |
| 6. 메타-순환형 | atlas에 hexa-lang 자신의 P/C/L 도 포함 | self-host |

**결정 (2026-05-09)**: **2 + 3 + 4 + 5 모두 채택** — native 컴파일러가 atlas를 정적 임베디드로 들고, 토큰 레벨에서 인식하며, 타입 시스템에 통합. 검증은 컴파일 타임 fatal. 6 (메타-순환)은 후순위.

### 2.1 trade-off (native + 정적 내장 기준)

장점
- 모든 코드/문서/테스트의 노드 인용이 1급 시민
- atlas 검증이 빌드 타임 fatal — 런타임에 "unknown primitive" 불가능
- 외부 atlas 의존 제거, self-contained 단일 바이너리
- 런타임 0ms (atlas 로드/파싱 없음)
- LSP 자동완성·hover (컴파일러가 atlas 인덱스를 in-process로 들고 있음)

단점
- atlas 변경 시 컴파일러 재빌드 (자동화 가능 — atlas mtime → CI 컴파일러 재빌드)
- 사용자 코드도 atlas 변경 후 재빌드 필요 (Rust deps update와 동일)
- bootstrap: 첫 native 컴파일러는 어떻게? → seed atlas로 self-host 후 정착
- 외부 사용자가 다른 atlas 쓰기 → `hexa.toml [atlas] path` 로 override 빌드

### 2.2 버전 정책 후보

- `ATLAS_MIN` / `ATLAS_MAX` — 컴파일러 허용 atlas hash 범위 핀
- atlas semver — P/C/L 추가=MINOR, 제거=MAJOR
- drift detector — CI에서 atlas 변경 시 자동 PR로 컴파일러 hash 동기화
- freeze window — atlas는 월말 스냅, lang은 그 hash만 본다

---

## 3. 실행-차단 lint — Python/TS strict 모델

핵심: **`hexa run x.hexa`가 본문 실행 첫 줄 전에 죽는다**. lint는 별도 명령이 아니라 인터프리터의 준비 단계 (resolve → type → verify) 에 inline.

### 3.1 검증 사다리

| 단계 | 검사 | fatal? | 비고 |
|---|---|---|---|
| S0 Parse | 문법 | ✅ | Python `SyntaxError` 동급 |
| S1 Resolve | atlas 노드 P[*]/C[*]/L[*] 존재 | ✅ | TS "Cannot find name" |
| S2 Bind | 자유변수 scope | ✅ | pre-run NameError |
| S3 Type | nominal type, generic | ✅ | TS strict |
| S4 Domain | ℝ/ℕ/ℤ 도메인 일관 | ✅ | type 확장 |
| S5 Units | 단위 차원 분석 | ✅ (default) | F=ma 단위 mismatch |
| S6 Equational | LHS=RHS canonical, sample counter-example | ⚙️ opt-in | `@verify` 어노테이션 시 |
| S7 SMT proof | Z3/CVC5 등 | ⚙️ opt-in | `@prove` 어노테이션 시 |
| S8 Citation | atlas L[*] 인용 누락 | ✅ | "공식 인용 없는 수식" 차단 |

**의견**: **S0–S5, S8 default fatal, S6–S7 opt-in fatal** (어노테이션 단 건만). marker-budget 같은 soft warn 단계 없음 — 0건 또는 abort.

### 3.2 실패 동작 (UX 시안)

```
$ hexa run example/foo.hexa
HexaError [S1: AtlasResolve] example/foo.hexa:42:11
    let p = P[einstien-mass-energy]
                ^^^^^^^^^^^^^^^^^^^
    atlas v2.3 has no primitive `einstien-mass-energy`
    did you mean: `einstein-mass-energy` (distance=1)?
    atlas hash: a3f9...c2 (pinned in hexa.toml)

HexaError [S5: Units] example/foo.hexa:88:5
    let f: Force = m + a
                   ^^^^^
    expected: kg·m/s² (Force)
    got:      kg + m/s²  (incompatible: cannot add Mass to Acceleration)

aborted: 2 errors before execution. exit 1.
```

규칙
- 첫 에러에서 멈추지 않음 — TS처럼 모아서 보여줌, 단 코드는 실행 안 함
- exit code 1 = fatal lint, exit code 2 = parse/syntax (Python 호환)
- stderr JSON 라인도 동시 출력 (현 `lint_log.jsonl` 호환)

### 3.3 opt-out 정책 — "거의 없다"

| 플래그 | 효과 | 권한 |
|---|---|---|
| `--no-verify=S6,S7` | opt-in 단계만 끔 | 누구나 |
| `--unsafe` | S5까지 끔 | 발 자르기, gate 차단 |
| `--unsafe-atlas-mismatch` | atlas hash mismatch만 묵인 | dev only, CI 금지 |
| `HEXA_STRICT=0` 환경변수 | **무시** | 의도적으로 무시 |

**의견**: opt-out은 어노테이션이지 CLI 플래그가 아니다. 코드에 `@allow_unverified("legacy migration", until="2026-06-01")` 처럼 **기한 만료 어노테이션**만 우회 허용. 만료 지나면 자동 fatal.

### 3.4 인터프리터 진입 시퀀스

`hexa run x.hexa` 진입 시:

```
1. parse(x.hexa)              → S0 fail시 abort (exit 2)
2. load_atlas_snapshot()      → atlas hash mismatch면 abort
3. resolve_refs(ast)          → S1 fail 누적
4. bind_scopes(ast)           → S2 fail 누적
5. type_check(ast)            → S3, S4 fail 누적
6. unit_check(ast)            → S5 fail 누적
7. citation_check(ast)        → S8 fail 누적
8. verify_annotated(ast)      → S6, S7 (어노테이션 있는 것만)
9. if errors > 0 → emit + exit 1
10. exec(ast)                 ← 여기 처음 도달
```

현 `gate/lint.hexa`는 별도 프로세스 → **인터프리터 내장 모듈로 흡수**.

### 3.5 수식 표기 후보

```hexa
// (a) attribute 어노테이션
@law("E = m * c^2", units="J = kg·m²/s²")
fn relativistic_energy(m: Mass, c: Velocity) -> Energy { m * c * c }

// (b) 1급 expression
formula einstein { E == m * c**2 } where { E: J, m: kg, c: m/s }

// (c) inline doc 인용
/// $$ \nabla \cdot \vec{E} = \rho / \epsilon_0 $$  // L[gauss-flux]
fn gauss(...) { ... }

// (d) atlas 노드와 직접 묶기
@implements(L[einstein-mass-energy])
fn rel_energy(...) { ... }
```

**의견**: (a) + (d) 조합 — 어노테이션이 hexa-native라 lint가 AST에서 바로 본다. LaTeX 인용은 보조.

### 3.6 bootstrap 전략 (기존 트리 호환)

| 안 | 설명 | 위험 |
|---|---|---|
| A. Big bang | 한 PR에 전부 통과 | 高 |
| B. Phased | S0 (이미 됨) → S1 → S2… 단계 승격 | 中 |
| C. Allowlist 만료 | 기존 파일에 `@allow_unverified(until="...")` 자동 부여 | 低, 만료 강제 |
| D. 두 트랙 | `hexa run` strict vs `--legacy` (6개월 후 제거) | 中 |

**의견**: B + C 결합. atlas refs (S1) 가장 영향 큼 → snapshot 안정화 후 S1 fatal. 단계당 1주.

---

## 4. 속도 분석 — 매번 읽기 vs 완전 내장

### 4.1 실측 (2026-05-09, `~/core/nexus/n6/`)

| 항목 | 값 |
|---|---|
| `atlas.n6` 본체 | **4.2 MB** (60,760 lines) |
| `atlas.append.*.n6` | **409 개** |
| `n6/` 디렉토리 총합 | **37 MB** |
| 마지막 수정 | 2026-05-08 (활발히 일일 변경) |

→ atlas가 **L tier 상단** (4 MB+ 본체) + **활발히 append 됨**. 정적 내장 시 매일 컴파일러 재빌드해야 하는 마찰 발생.

### 4.2 비용 항목별 추정 (실측 4.2 MB 기준)

**런타임 비용** (hexa로 컴파일된 사용자 바이너리 실행 시):

| 단계 | 인터프리터 매번 읽기 | 인터프리터 + mtime cache | **native + 정적 내장 (채택)** |
|---|---|---|---|
| open + read 4.2 MB | cold ~80–150 ms / warm ~20–40 ms | 0 (mmap) | **0** (binary 안에 있음) |
| 파싱 + index | ~100–260 ms | 0 (hit) | **0** (빌드 타임 완료) |
| **런타임 합계** | **~180–410 ms** | ~1–2 ms | **0 ms** |
| 메모리 상주 | ~15–30 MB | ~1–2 MB | **~1–2 MB packed (정적 const)** |
| per-lookup `P[id]` | ~100 ns | ~100 ns | ~100 ns |

**빌드 타임 비용** (native 컴파일러가 atlas를 처리):

| 단계 | 비용 | 빈도 |
|---|---|---|
| atlas.n6 + append/* parse + merge | ~30–80 ms (native compiler) | 컴파일러 빌드 1회 / atlas 변경 시 |
| atlas hash 계산 + bake | ~10 ms | 동일 |
| 사용자 코드 검증 (S0–S5, S8) | ~소스 라인에 비례 | 사용자 빌드마다 |

> 인터프리터는 하나의 .hexa 실행마다 위 모든 비용 지불. native 컴파일러는 atlas는 빌드 시 1회만, 사용자 검증도 빌드 시 1회.

### 4.3 시나리오별 영향 (실측 4.2 MB 기준, 채택안 = native + 정적 내장)

| 시나리오 | 인터프리터 매번 읽기 | 인터프리터 + cache | **native + 정적 내장** |
|---|---|---|---|
| A. 사용자 바이너리 일회성 실행 | +200 ms | +2 ms | **0 ms** |
| B. pre-commit 100 파일 | 20 초 | 0.2 초 | 검증은 빌드 타임에 끝남 |
| C. CI 5000 파일 | ~17 분 | ~10 초 | 빌드 캐시 있으면 ~수초 |
| D. IDE LSP 키 입력 | 200 ms lag | 1 ms | 0 ms (LSP가 컴파일러 in-process 인덱스 재사용) |
| E. atlas.n6 편집 직후 | 즉시 | mtime 즉시 | 컴파일러 자동 재빌드 (CI hook) |
| F. atlas append 일일 추가 | 즉시 | 즉시 | 컴파일러 nightly 재빌드 → 사용자 코드도 재빌드 |
| G. 배포 바이너리 → 다른 머신 실행 | atlas 파일 동봉 필요 | 동일 | **단일 바이너리, atlas 동봉 불필요** |

### 4.4 옵션 매트릭스 (4가 채택)

| 안 | 동작 | 런타임 cold | drift 반영 | 구현 비용 | 채택? |
|---|---|---|---|---|---|
| 1. 인터프리터 + 매번 읽기 | 호출마다 fs+parse | ~200 ms | 즉시 | 낮음 | ❌ (LSP/CI 비현실) |
| 2. 인터프리터 + 프로세스 캐시 | 첫 호출 후 in-memory | ~200 ms | stale | 낮음 | ❌ |
| 3. 인터프리터 + mtime cache | `atlas.bin` 캐시 | 1–2 ms | mtime 즉시 | 중간 | ❌ (인터프리터 자체 폐기) |
| **4. native + 정적 내장** | 빌드 타임 codegen, 바이너리 임베드 | **0 ms** | 컴파일러 재빌드 (자동화) | 高 (native 컴파일러 신설) | ✅ |

### 4.5 채택안 — native 컴파일러 + atlas 정적 내장

```
[빌드 타임]
  hexa 컴파일러 빌드 시:
    atlas.n6 + atlas.append.*.n6
        ↓ parse + merge + dedup
    packed atlas (~1–2 MB)
        ↓ codegen
    컴파일러 바이너리에 정적 const 로 임베드
        + atlas SHA256 hash 핀

  사용자 .hexa 빌드 시:
    소스 → parse → S0–S5,S8 검증 (정적 atlas 인덱스 사용)
        ↓ 위반 1건이라도 있으면 abort, 바이너리 안 만듦
    검증 통과 → native 기계어 → 단일 사용자 바이너리
        + 사용된 atlas 노드들도 사용자 바이너리에 임베드 (실행 시 reflect/log용)

[런타임]
  사용자 바이너리 실행:
    atlas 로드/파싱 0 ms
    이미 컴파일 타임에 모든 검증 통과한 코드만 존재
```

자동화
- atlas mtime 변경 → CI가 컴파일러 재빌드 (nightly 또는 mtime hook)
- 컴파일러 hash 변경 → 사용자 코드 재빌드 (Rust deps update와 동일)
- atlas semver: P 추가 = MINOR (BC), P 제거/L 시그니처 변경 = MAJOR (코드 fix 필요)

옵션
- `hexa.toml [atlas] path = "..."` — 외부 사용자가 다른 atlas 쓰는 경우, 컴파일러 빌드 시 override
- `hexa.toml [atlas] hash = "..."` — 명시적 핀, drift 시 빌드 실패

### 4.6 캐싱 레이어 (참고용 — native + 정적 내장에선 L0만 사용)

| 레이어 | 효과 | 비용 | 채택안 사용? |
|---|---|---|---|
| L0 정적 const (정적 내장) | 0 ms | 컴파일 재빌드 | ✅ 디폴트 |
| L1 mmap parsed | ~100 ns/lookup | 파일 1개 | 컴파일러 자체 빌드 캐시용 |
| L2 프로세스 hashmap | ~100 ns/lookup | RAM 1MB | LSP / `hexa check` 워치 모드 |
| L3 디스크 parse cache | ~1 ms 시작 | mtime check | 컴파일러 incremental build |
| L4 raw .n6 read | ~150–300 ms 시작 | 항상 최신 | 폐기 |

---

## 5. 단계적 로드맵 (native + 정적 내장 기준)

| Phase | 산출물 | 예상 노력 |
|---|---|---|
| **A0** | **native 컴파일러 backend 결정** (LLVM? C-trans? 직접 codegen?) | L |
| **A1** | hexa 파서 + AST를 native 컴파일러용으로 재작성 / 분리 | L |
| **A2** | atlas.n6 + append/* 머지·파서 (컴파일러 내부 모듈) | M |
| **A3** | atlas → packed const codegen + 컴파일러 바이너리 정적 임베드 | M |
| **A4** | atlas hash 핀, `hexa.toml [atlas]`, drift CI hook | S |
| **B1** | S0–S2 (parse, atlas-resolve, bind) 컴파일 타임 fatal | M |
| **B2** | S3–S4 (type, domain) 통합 | M |
| **B3** | `@units` + S5 (단위 차원 분석) | M |
| **B4** | `@law` / `@implements` 어노테이션 + S8 (citation) | M |
| **C1** | `@verify` sampling (S6, opt-in) | L |
| **C2** | `@prove` SMT bridge (S7, optional dep) | L |
| **D1** | LSP — 컴파일러 in-process 인덱스 재사용 | M |
| **D2** | `hexa check --watch` incremental | M |
| **E1** | bootstrap — 기존 인터프리터 → native 컴파일러 마이그레이션 | L |
| **E2** | 기존 `.hexa` 트리 마이그레이션 (allowlist 만료 정책) | L |

---

## 6. 미해결 질문 / 실측 필요 항목

1. ~~실제 atlas.n6 크기~~ — **실측: 본체 4.2 MB / 60,760 lines, append 409개, n6/ 총 37 MB** (2026-05-09)
2. `hexa_interp`의 `.n6` 파싱 throughput (KB/s) — 실측 필요
3. 노드 lookup 빈도 — 파일 평균 인용 회수
4. CI에서 lint 돌리는 `.hexa` 파일 수
5. ~~atlas.n6 mtime 변경 빈도~~ — **실측: 일일 변경 + append 활발**
6. atlas의 P/C/L 정의 자체가 hexa로 작성되어 있는지 (메타-순환 가능성)
7. atlas semver 단위 결정 (P 추가만 MINOR? L 시그니처 변경은 MAJOR?)
8. 외부 사용자가 다른 atlas 쓰는 use case 실재 여부
9. append 머지 의미론 — 단순 concat? id 충돌 시 last-wins? 명시 필요

---

## 7. 한 줄 결론 (2026-05-09 결정)

- **언어 형태**: hexa-lang을 **인터프리터에서 native 컴파일러로 전환**
- **atlas 임베딩**: 컴파일러 바이너리에 **정적 내장** (packed const + hash 핀)
- **검증 사다리**: 참조 → bind → type → 단위 → citation 을 **컴파일 타임 fatal** — 위반 시 바이너리 자체가 안 만들어짐 (TypeScript `tsc` 모델 + Rust 수준 strict)
- **수식 표기**: `@law` / `@implements` / `@units` 어노테이션이 atlas와 직접 결속
- **opt-out**: CLI 플래그 아닌 **기한 만료 어노테이션**만 허용
- **속도**: 인터프리터 매번 읽기 ~200ms → native + 정적 내장 시 **런타임 0ms**, 검증은 빌드 타임 1회
- **drift 자동화**: atlas 변경 → CI가 컴파일러 재빌드 → 사용자 코드 재빌드 트리거 (Rust deps update 모델)
