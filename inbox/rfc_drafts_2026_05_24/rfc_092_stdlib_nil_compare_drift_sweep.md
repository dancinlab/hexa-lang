---
rfc: 092
title: stdlib nil-compare drift sweep — cycle 13 #618 carry-forward
status: in-flight (B1 LANDED · B2-B5 pending)
priority: medium
filed: 2026-05-24
filed_by: claude-code worktree agent-aa65e9c131586e0bf
target_ssot: self/stdlib/ · stdlib/ · self/ml/ · self/serve/ · self/runtime/ · compiler/link/
unblocks:
  - verify/atlas CLI flatten of fs.hexa-importing tools (cycle 10 #609 finding)
  - 미래 self-host rebuild — parser strict gate가 stable해진 후 모든 모듈이 균질하게 통과
related:
  - PR #618 (cycle 13 lane 4 · OPEN · `fix(stdlib/fs): replace 'if st == nil' with 'if !st' — parser nil-compare drift`)
  - PR #609 (cycle 10 lane 1 finding · MERGED · stdlib-fs-nil-parser-reject-drift inbox note pickup)
  - inbox/notes/2026-05-24-stdlib-fs-nil-parser-reject-drift.md (원본 finding · 워크어라운드 검증)
  - PR #585/#594/#595 그룹 (cycle 7-11 parser 강화 — `'nil' is not a value in hexa` reject)
governance:
  - "@D wipe_guard — sweep PR는 파일별 <200 line · 정확한 surgical edit · 'WIPE-OK' trailer 불요"
  - "@D diff_guard — staging 전 `git diff main...HEAD` 로 의도 외 라인 0건 확인"
---

# RFC 092 — stdlib nil-compare drift sweep (cycle 13 #618 carry-forward)

## §1 동기 (motivation)

cycle 7-11 의 parser 강화 batch (PR #585/#594/#595 그룹) 가 `nil` 을 값-비교
대상으로 쓰는 `if x == nil` / `if x != nil` 패턴을 거부하도록 만들었다. 거부
메시지는 다음과 같다:

```
Parse error at <line>: 'nil' is not a value in hexa
  — use 'None' (Option<T>) or omit the binding
```

cycle 10 lane 1 (#609 finding) 가 `self/stdlib/fs.hexa` 의 5건 drift 를 처음
발견했고, cycle 13 lane 4 (#618, **OPEN**) 가 그 5건을 fix 한다. 그러나 동일
패턴이 **stdlib · ml · serve · runtime · compiler/link 전반에 광범위하게
잔존**한다 — 본 RFC 의 §2 inventory 가 그 정량적 매트릭스다.

다음 self-host rebuild 또는 `tool/verify_cli.hexa` 류 도구의 flatten 시점에
이 drift 가 connecting failure 를 일으킨다. 체계적 sweep 없이는 cycle 마다
개별 file fix PR 로 분산되어 거버넌스 비용 (review · pr-cycle · diff_guard)
이 누적된다.

## §2 inventory — drift 매트릭스 (11 files · 55 locations)

`grep -rn 'if [a-zA-Z_][a-zA-Z0-9_]* \(==\|!=\) nil' self/stdlib/ stdlib/
compiler/ self/` (testdata · `ai_native_pass.hexa` 의 코멘트 매처 본문 제외)
결과:

| file | hits | 비고 |
|---|---:|---|
| `self/serve/serve_alm.hexa` | 18 | ALM serve 핸들러 — body/data/lname/adapter null 검사 | 
| `self/ml/lora_serve.hexa` | 11 | LoRA serve — adapter/rank_t/alpha_t/probe 검사 |
| `self/stdlib/fs.hexa` | 10 | **PR #618 (OPEN) 이 5건 fix · 남은 5건은 동일 패턴 잔존** |
| `compiler/link/incr_cache.hexa` | 4 | incremental cache — bytes/rows/blob null guard |
| `self/runtime/arena_pure.hexa` | 3 | arena alloc null check (`test_arena_pure.hexa` 사본도 동일) |
| `stdlib/net/http_request.hexa` | 2 | headers / value null guard |
| `self/serve/serve.hexa` | 2 | `SERVER_MODEL` / `g_model` null guard |
| `self/ml/eval_harness.hexa` | 2 | eval batch end-of-stream 검사 |
| `stdlib/net/http_response.hexa` | 1 | extra_headers null guard |
| `stdlib/net/concurrent_serve.hexa` | 1 | resp null guard |
| `self/ml/distributed_train.hexa` | 1 | batch null guard |
| **합계** | **55** | |

대표 line 위치 (full 매트릭스는 sweep PR diff 의 stat block 으로 노출):

- `self/stdlib/fs.hexa` — L243 L249 L486 L515 L529 (cycle 13 #618 cover) + 5 잔존
- `self/serve/serve_alm.hexa` — L756 L997 L1001 L1005 L1022 L1026 L1031 L1046 L1050 L1054 L1061 L1076 L1080 L1084 L1087 L1102 L1140 L1170
- `self/ml/lora_serve.hexa` — L79 L114 L120 L126 L160 L167 L202 L255 L267 L310 L314
- `compiler/link/incr_cache.hexa` — L162 L259 L273 L295
- `self/runtime/arena_pure.hexa` — L108 L115 L136

자체 사본 `self/test_arena_pure.hexa` 의 3건은 동일 패턴이며 sweep 범위에
포함 (테스트 모듈 — parse-gate 가 보호 대상).

## §3 fix 패턴

PR #618 + inbox/notes/2026-05-24-stdlib-fs-nil-parser-reject-drift.md 에서
검증된 1:1 매핑:

| before | after | 비고 |
|---|---|---|
| `if x == nil { ... }` | `if !x { ... }` | truthy 강등 — `hexa_void()` / `nil` 모두 falsy |
| `if x != nil { ... }` | `if x { ... }` | 동일 |
| `if x == nil \|\| x == "" { ... }` | `if !x \|\| x == "" { ... }` | 복합 — 좌측만 강등, 우측 string-eq 유지 |
| `if x == nil \|\| y == nil { ... }` | `if !x \|\| !y { ... }` | 양쪽 강등 |

**범위 외** (sweep 에서 건드리지 않음):

- `self/ai_native_pass.hexa` L11718/L11723 — `is_nil_check` 분석기 본문의
  매처 코멘트. 의도된 AST 검사 코드라 형태 그대로 유지.
- 테스트 baseline 으로 parser reject 를 의도적으로 fire 하는 케이스 (현재
  inventory 에는 없음 · 향후 추가 시 본 RFC 의 후속 amendment 로 처리).

## §4 단계적 batch — sub-200-line PRs

| batch | files | hits | 예상 LoC delta | status |
|---|---|---:|---:|---|
| B1 | `self/stdlib/fs.hexa` (남은 5건 잔존분) | 5 | ~10 | **LANDED 2026-05-24 — `fix/rfc-092-b1-fs-nil-drift-batch-2026-05-24` (#618 OPEN supersede)** |
| B2 | `compiler/link/incr_cache.hexa` + `stdlib/net/{http_request,http_response,concurrent_serve}.hexa` | 8 | ~16 | pending |
| B3 | `self/runtime/arena_pure.hexa` + `self/test_arena_pure.hexa` | 6 | ~12 | pending |
| B4 | `self/ml/{lora_serve,eval_harness,distributed_train}.hexa` | 14 | ~28 | pending |
| B5 | `self/serve/{serve_alm,serve}.hexa` | 20 | ~40 | pending |

**전제 갱신 (2026-05-24)**: PR #618 은 OPEN 상태로 머지되지 않았다 (grace-consent
CI 실패). B1 은 본 brnch (`fix/rfc-092-b1-fs-nil-drift-batch-2026-05-24`) 가
동일 5곳 surgical edit 으로 supersede — PR #618 close 권고.
**전제**: 각 batch 는 단일 PR · 단일 모듈군 · 200 line 미만 · 자동 pr-cycle
머지 가능.

선후 의존성:

```
PR #618 (cycle 13) ─┐
                    ├─► B1 (fs.hexa 잔존) ─► B2 (compiler/link + stdlib/net) ─► B3 (runtime/arena) ─► B4 (self/ml) ─► B5 (self/serve)
RFC 092 (this PR) ──┘
```

순서가 강제는 아님 (각 batch 가 독립 modular) 이나 review 부담 최소화 위해
직렬 권고.

## §5 falsifiers

### F-PARSE-PASS — 모든 모듈 parse-gate 통과
```
HEXA_LANG=$PWD HEXA_MAC_BUILD_OK=1 hexa parse self/stdlib/fs.hexa
HEXA_LANG=$PWD HEXA_MAC_BUILD_OK=1 hexa parse self/serve/serve_alm.hexa
HEXA_LANG=$PWD HEXA_MAC_BUILD_OK=1 hexa parse self/ml/lora_serve.hexa
# (각 batch 머지 후 해당 파일 parse exit 0)
```
실패 시 (parser strict gate 가 잡아내는 추가 패턴 발견) sweep 미완 — 본
RFC 의 §2 inventory 를 amendment 로 확장.

### F-REGRESSION-ZERO — 머지 후 verify/atlas verbs 동작
```
hexa verify --expr welch_t_crit 1 12.706         # 🟢 SUPPORTED-NUMERICAL
hexa verify --expr wilson_hilferty_p 0 10 1.0    # 🟢 SUPPORTED-NUMERICAL
hexa verify --expr ssh_winding 1 2 1             # 🔵 SUPPORTED-FORMAL
hexa verify --expr tknn_chern 2 5 1 3            # 🔵 SUPPORTED-FORMAL
hexa atlas stats                                  # 통계 출력 정상
```
inbox/notes/2026-05-24-stdlib-fs-nil-parser-reject-drift.md §재현 의 4 verdict 모두
재현되어야 한다.

### F-SWEEP-COMPLETE — 새 drift 0건
```
grep -rn 'if [a-zA-Z_][a-zA-Z0-9_]* \(==\|!=\) nil' self/stdlib/ stdlib/ compiler/ self/ \
  | grep -v 'test_\|tests/\|^[^:]*://\|ai_native_pass'
# expected: empty
```
실패 시 — 잔존 위치 inventory amendment → 후속 PR.

### F-SEMANTICS-PRESERVED — `!x` 강등의 의미 동일성
`fs_stat` 등 nil-returning fn 의 `hexa_void()` 와 `nil` 모두 falsy 임을 확인:

```
HEXA_LANG=$PWD hexa run -e 'let v = hexa_void(); if !v { println("falsy") } else { println("truthy") }'
# expected: falsy
HEXA_LANG=$PWD hexa run -e 'let v = nil; if !v { println("falsy") } else { println("truthy") }'
# expected: falsy
```

실패 시 — `!x` 강등이 부적절. `Option<T>` 정식 마이그레이션 필요 (큰
follow-up RFC).

## §6 cross-link

- **cycle 13 lane 4 #618** — `fix(stdlib/fs): replace 'if st == nil' with 'if !st' — parser nil-compare drift` (OPEN). 본 RFC 의 batch B1 직접 carry-forward.
- **cycle 10 lane 1 #609** — `atlas(RFC 047+046): register welch_t · wilson · ssh_winding · tknn_chern` (MERGED). PR body 하단 "inbox 정리" 섹션에서 본 finding 파일 (`2026-05-24-stdlib-fs-nil-parser-reject-drift.md`) 을 산출물로 명시.
- **cycle 7-11 parser strict gate** — `'nil' is not a value in hexa — use 'None' (Option<T>) or omit the binding` 거부 메시지의 도입 PR 그룹 (#585/#594/#595 류). 본 sweep 은 그 강화의 자연스러운 stdlib downstream cleanup.
- **memory `[[feedback_no_interp_use_compiled]]`** — sweep 검증은 `hexa parse` 단계에서 충분 (compiled run 까지 갈 필요 없음).
- **memory `[[reference_shared_worktree_branch_hazard]]`** — 각 batch PR 은 격리 worktree 에서 발사 권고 (parser/codegen 강화 다발 시 충돌 회피).

## §7 비-범위 (out of scope)

- `Option<T>` 정식 도입은 별도 RFC. 본 sweep 은 truthy 강등 (`!x` / `x`) 만
  적용 — 의미 보존 + 변경량 최소.
- parser deprecation warning path (예: `== nil` 을 warn-only 로 강등 후
  점진적 reject) — finding note §조치 제안 (2) 항목으로 거론되었으나 본
  sweep 의 범위 밖. parser 정책 변경은 별도 design RFC 필요.
- 테스트 baseline 의 의도적 reject 케이스 — 현재 inventory 에 없음 · 발생
  시 amendment.

## §8 closure verdict

본 RFC 가 머지되면:

- batch B1-B5 의 발사 순서와 범위가 SSOT 화된다.
- 각 batch PR 은 본 RFC §3 매핑 + §5 falsifiers 만 참조하면 됨 — 거버넌스
  중복 제거.
- 다음 self-host rebuild 또는 verify/atlas 도구의 stdlib 의존 확장 시 parser
  strict gate 와 stdlib 간 drift 0건이 보장된다.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
