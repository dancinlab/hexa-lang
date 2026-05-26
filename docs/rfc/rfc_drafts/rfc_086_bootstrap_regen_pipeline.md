# RFC 086 — bootstrap `hexa cc --regen` 파이프라인 복구 + `to_int` root-fix fixpoint

| 축 | 값 |
|---|---|
| 상태 | DRAFT (next-cycle, deeper root-cause traced 2026-05-27) |
| 발견 | 2026-05-27 PR #1334 (to_int .hexa source landed without hexa_cc.c regen) |
| 진단 | `cmd_regen_cc` subprocess `exec` chain truncates `/tmp/_cg.c` to 259-byte stub |

## 발견 상세

PR #1334가 `self/codegen.hexa`의 `to_int` / `int` 이중평가 root-fix를 .hexa SSOT에 landed. 그러나 `self/native/hexa_cc.c` (deployed C transpiler) 재생성이 필요. ubu-2 fresh-clone에서 `hexa cc --regen` 시도 시:

### Error 1 — pre-existing pipeline merge

```
/tmp/toint/self/native/hexa_cc.c.new:11651:22:
  error: call to undeclared function 'codegen_c2_full'; ISO C99 and later do not
  support implicit function declarations
 11651 |     HexaVal c_code = codegen_c2_full(ast);
       |                      ^
note: did you mean '_codegen_c2_init'?
```

`codegen_c2_full` 가 forward-decl 없이 사용. `_codegen_c2_init`은 declared. Phase C MVP merge step의 limitation 명시:
> Phase C MVP done. Merge algorithm limitations:
>   - simple concat; no global symbol collision resolution
>   - main() stripped via awk brace-depth (single-line `}` assumed)

### Error 2 — type mismatch

```
/tmp/toint/self/native/hexa_cc.c.new:11651:13:
  error: initializing 'HexaVal' with an expression of incompatible type 'int'
```

`codegen_c2_full` 반환 타입 추론이 implicit-int (Error 1의 cascading).

### 광범위 divergence

current `hexa_cc.c` vs `.new` 의 diff: parser_sl slot 100+ renumbered (parser.hexa의 PR #1313 "shared" annotation 추가 등 누적). 단순 to_int change 패치가 아닌 broad regen baseline reset 필요.

## 2026-05-27 추가 진단 — exec-context cg.c 절단

위의 Error 1/2는 **표면적 증상**이고, 실제 root cause는 더 깊다:

### 재현
| 단계 | 호출 방식 | `/tmp/_cg.c` 크기 |
|---|---|---|
| direct shell | `HEXA_VAL_ARENA=0 hexa_v2 codegen.hexa /tmp/_cg.c` | **940036 B** (정상, 381× `codegen_full`) |
| serial 4× shell | lexer + parser + tc + codegen (manual sequence) | **940036 B** (정상) |
| `hexa cc --regen` (cmd_regen_cc) | `regen_one_module` exec chain | **259 B** (skeleton only, `int main()` shell) |

동일 binary, 동일 args, 동일 env. **유일한 차이**: cmd_regen_cc가 hexa runtime `exec()` (subprocess wrapper) 통해 호출. shell 직접 호출은 정상.

### 영향

`/tmp/_cg.c` 가 259 B skeleton이므로:
- merged `hexa_cc.c.new` 에 `codegen_full` 정의 부재 (lexer/parser/tc만 머지됨, ~11659 lines, 전체 ~43000 예상 대비 27% 짜리)
- 부착된 main wrapper (heredoc)이 `codegen_full(ast)` 호출 → undefined function → compile fail
- (이전에 보고된 `codegen_c2_full` 는 stale wrapper text였고 source는 이미 `codegen_full` 로 rename 완료)

### Hypothesis들

1. **stdout buffer block**: `2>&1` redirect + `exec` reads stdout fully; child가 940KB stdout 쓰면 OS pipe buffer (64KB Linux default) 막힘 → SIGPIPE → 조기 종료. 그러나 hexa_v2는 stdout에 `OK: <path>` 1줄만 쓰고 .c 파일은 별도 fd로 씀 → 이론적으로 무관.
2. **inherited fd leak**: 부모 hexa가 큰 메모리/fd state를 inherit 시키고 child가 시작 직후 OOM/EBADF.
3. **race on /tmp/_cg.c**: 부모가 4번 같은 path 재사용; ext4 + open(O_TRUNC) 직후 child fork 시 race.
4. **arena size**: HEXA_VAL_ARENA=0 가 inherit 되지만 child의 자체 transpile arena가 부모 RSS와 경쟁; 큰 codegen.hexa는 더 큰 arena 필요.

### 단일 PR 우회 (sed-fix) 실패

sed로 `.new`의 `codegen_c2_full` → `codegen_full` 으로 치환 후 clang 시도 → `codegen_full` undeclared. 즉 함수 정의가 아예 없음 (위 root cause 확인). 표면 sed로는 해결 불가.

### 권장 우회 경로 (단일 cycle 가능)

1. **manual merge bypass** — `cmd_regen_cc` 우회 + 직접 shell sequence:
   - `tool/regen_cc_manual.sh` 스크립트: 4× `hexa_v2 <module>.hexa /tmp/_<m>.c` 순차 실행 → manual cat + dedup + main wrapper
   - 결과 .new를 `hexa cc.c` 로 promote
   - 이후 `--regen` 자체 fix는 별도 PR (root cause 4 hypotheses 중 하나 좁히기)
2. **runtime exec rework** — 위의 hypothesis 1-4 조사 + `exec()` 구현 (self/runtime.c의 hexa_exec / exec_capture) 패치

### 최소-fix path (1 PR)

`tool/regen_cc_manual.sh` 작성:
```bash
#!/bin/sh
H="/Users/ghost/core/hexa-lang"  # adjust per host
V2="$H/self/native/hexa_v2"
HEXA_VAL_ARENA=0 "$V2" "$H/self/lexer.hexa" /tmp/_lexer.c
HEXA_VAL_ARENA=0 "$V2" "$H/self/parser.hexa" /tmp/_parser.c
HEXA_VAL_ARENA=0 "$V2" "$H/self/type_checker.hexa" /tmp/_tc.c
HEXA_VAL_ARENA=0 "$V2" "$H/self/codegen.hexa" /tmp/_cg.c
# Merge: awk-strip individual mains, dedup #includes, append common main.
# (the awk logic lives in main.hexa::merge_modules_awk — port to shell here)
```

이걸로 4× cg.c 940KB 보장 → merge 정상 → clang OK → `.new` byte-eq vs current `hexa_cc.c` + to_int delta only.

## 우선순위

| 우선 | 항목 | scope |
|---|---|---|
| P0 | tool/regen_cc_manual.sh shell bypass 작성 + 1회 fixpoint | 1 PR |
| P1 | exec-context cg.c 절단 root cause 좁히기 (hypothesis 1-4) | 1-2 PR |
| P2 | hexa runtime `exec()` 패치 (P1 결과 의존) | 1-2 PR |
| P3 | `cmd_regen_cc` re-enable + CI 게이트 | 1 PR |

## 권장 복구 path

### Phase 1: 진단
- `tool/regen_cc.hexa` 또는 `tool/build_hexa_cli.sh`의 merge step 분석
- `codegen_c2_full` declaration 위치 확인 + `.new` merge 누락 원인 파악
- awk brace-depth 가정 (`single-line }`) 위반 case 식별

### Phase 2: merge step 수정
- forward-decl 자동 합성 (모든 fn name → prototype emit)
- 또는 codegen_c2 모듈을 self/codegen.hexa에 흡수 (현재는 사이드 모듈)
- main() strip awk를 multi-line `}` 지원으로 강화

### Phase 3: fixpoint
- 깨끗한 `cc --regen` 한 라운드 → `.new` compile OK
- promote `.new` → `hexa_cc.c`
- 재regen → gen1.c ≡ gen2.c byte-identical fixpoint
- PR: 단일 commit `regen(self/native): hexa_cc.c — picks up to_int root-fix + parser sl slot baseline reset`

### Phase 4: validation
- existing test 모두 PASS
- to_int double-eval miscompile family 재발 없음 ([[reference_to_int_double_eval_miscompile]] 패턴 시나리오 silicon test)

## 차단 해제 estimate

Phase 1 디버그 1-2 cycle. Phase 2 fix 1-3 PR. Phase 3-4 1 cycle. Total 약 4-6 dedicated cycles의 bootstrap 작업 — GPU 도메인과 직교.

## 관련 PR

- PR #1334 (to_int root-fix, .hexa-only landed) — 이 RFC가 hexa_cc.c regen을 처리하면 자연 picks-up
- PR #1335 (rsqrt) / #1333 (exp polynomial) — 동일 .hexa source SSOT 패턴이지만 nvptx codegen 측이라 hexa_cc.c regen 무관

## g0 sanity check

> "Occam's razor — simplest sufficient path"

현재 hexa-lang의 bootstrap pipeline은 두 개의 진실 소스(.hexa source SSOT + .c artifact cache) 사이의 동기 메커니즘이 fragile. RFC 086은 이 fragility를 인지하고 단계적 복구를 제안 — `.new` 파일 자동 검증 게이트 + forward-decl 자동 합성이 핵심.
