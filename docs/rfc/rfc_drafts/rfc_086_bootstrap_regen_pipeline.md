# RFC 086 — bootstrap `hexa cc --regen` 파이프라인 복구 + `to_int` root-fix fixpoint

| 축 | 값 |
|---|---|
| 상태 | DRAFT (next-cycle, blocked on bootstrap pipeline diagnostic) |
| 발견 | 2026-05-27 PR #1334 (to_int .hexa source landed without hexa_cc.c regen) |
| 차단 issue | `hexa cc --regen` produces hexa_cc.c.new with 2 errors |

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
