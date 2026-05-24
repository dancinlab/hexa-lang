---
slug: stdlib_module_test_and_builtin_findings
kind: notes
filed_from: dancinlab/anima (STDLIB domain · M3 + cycle-full)
filed_at: 2026-05-24
priority: medium
relates_to: stdlib_scaffold, RFC-016
---

# note: stdlib 모듈 테스트 부재 + builtin-first 규칙 (STDLIB M3/cycle-full 발견)

anima STDLIB 도메인이 8 stdlib 모듈(#769 · #780 · #781 · #782 · #783)을 land 하며 발견한 hexa-lang 측 갭 3건.

## 1. CI bootstrap 이 stdlib 모듈을 테스트하지 않음 (coverage gap)
- `.github/workflows/bootstrap.yml` 은 compiler self-bootstrap + 단일 `hi.hexa` smoke transpile 만 검증.
- `stdlib/**/*_test.hexa` (위 8 모듈 각각의 test 포함)는 CI 에서 실행되지 않음.
- 영향: stdlib 모듈의 회귀/링크오류가 CI 로 안 잡힘. stdlib 가 빠르게 성장 중(수십 모듈)인 만큼 test runner 단계 권장 — `module_loader` flatten → build → run all `stdlib/**/*_test.hexa`.

## 2. 단일파일 `hexa build <f>` 가 import flatten 안 함 (DX)
- `import "stdlib/..."` 를 가진 파일을 `hexa build <f>` 하면 imported `pub fn` 이 extern 처리 → `ld: undefined symbol`.
- CI 는 `module_loader` 로 flatten 후 transpile 하는 2-step (bootstrap.yml) 사용. 단일파일 build 경로엔 이 flatten 이 없음.
- 회피: cross-module 코드 검증 시 self-contained 인라인 copy 빌드(알고리즘만) + cross-import 은 통합/부트스트랩에서. 개선: `hexa build` 자동 flatten 또는 docs 명시.

## 3. RFC 는 builtin-first 로 확인할 것 (RFC stdlib_scaffold 갱신)
- RFC stdlib_scaffold 는 `log2`/`pow2`/`bit_set` 를 "missing builtin" 으로 가정 → `stdlib/math/log.hexa` 제안.
- 실측: `log2` · `abs` · `fabs` · `sqrt` · `pow` · `floor` · `log` 전부 동작 builtin (`self/codegen.hexa` is_builtin + `runtime_core.c`). #769 에서 log module DROP, abs_f(77 dup)/sqrt_newton(17 dup) 도 builtin 으로 sweep 가능(새 모듈 아님).
- 권장: 새 stdlib 수치 primitive 제안 전 `git grep 'if s == "<name>"' self/codegen.hexa` 로 builtin 존재 확인.
- byte-equal 주의: libm builtin (log2/pow/exp) 은 hand-rolled (log/log(2.0) · Taylor) 와 ulp 다름 — frozen baseline 보존 consumer 는 builtin 으로 swap 금지 (entropy · voss 가 그 사례).

## 참고
- dancinlab/anima `STDLIB.log.md` (M3 + cycle-full closure)
- #769 (info+math scaffold) · #780 (phi_spatial) · #781 (stats/correlation) · #782 (wolfram/ca) · #783 (signal/voss)
