# stdlib/ — 사용자용 라이브러리

사용자가 `import "../stdlib/xxx.hexa"` 로 쓰는 고수준 모듈.

전체 인벤토리는 `hexa stdlib` 로 조회 — 각 모듈의 첫 줄 헤더 코멘트
(`// <prefix> — <purpose>`) 에서 purpose 를 자동 추출. JSON 출력은
`hexa stdlib list --json`. 이 README 의 표는 자주 쓰는 일부 발췌.

| 파일 | 역할 |
|---|---|
| collections.hexa | 컬렉션 (List, Set, Map 확장) |
| math.hexa | 수학 함수 (core/math/ 에 `wrap_pi` 등 각도 normalize primitive 포함) |
| nn.hexa | 신경망 |
| optim.hexa | 옵티마이저 |
| string.hexa | 문자열 유틸 |
| consciousness.hexa | anima 의식 모듈 |

`self/lib/` 와 구분:
- **stdlib/** = 사용자 import (public API)
- **self/lib/** = 컴파일러 내부 유틸 (fraction, simd, sieve, tensor_ops 등)

병합 금지 — 역할 다름.

## 모듈 작성 노트 (authoring · INBOX #5②③ · #3 컨벤션)

### builtin-first — 새 수치 primitive 제안 전 codegen 확인 (#5③)
`log2`·`abs`·`fabs`·`sqrt`·`pow`·`floor`·`log` 등은 이미 **동작하는 builtin**
(`self/codegen.hexa` is_builtin + `runtime_core.c`). 새 수치 함수를 stdlib 에
추가하기 전:

```
git grep 'if s == "<name>"' self/codegen.hexa   # 이미 builtin 인지 확인
```

으로 중복을 막는다. ⚠ **byte-eq 주의**: libm builtin(`log2`/`pow`/`exp`)은
hand-rolled(`log/log(2.0)`·Taylor)와 ulp 가 달라, frozen-baseline 을 보존해야
하는 consumer(예: entropy·voss)는 builtin 으로 swap 하면 안 된다.

### 단일파일 빌드는 import 를 flatten 하지 않는다 (#5② DX)
`import "stdlib/…"` 를 가진 파일을 단일 `hexa build <f>` 로 빌드하면 imported
`pub fn` 이 extern 처리되어 `ld: undefined symbol` 로 링크 실패한다. import
closure 는 `module_loader` 가 먼저 flatten 해야 한다(이것이 CI bootstrap 의
2-step). cross-module 코드를 로컬 검증할 때는 ⓐ **module_loader 2-step**
(`HEXA_MODULE_LOADER=<repo>/build/hexa_module_loader hexa build …`) 또는
ⓑ 알고리즘만 떼어낸 **self-contained 인라인 copy**(use 0개) 빌드를 쓴다.

### `fn main()` auto-fire — 라이브러리 재사용 컨벤션 (#3)
`import <mod>` 만 해도 모듈의 top-level `fn main()` 이 auto-fire 한다(Python 의
`if __name__=="__main__"` 가드가 아직 없음 — 언어 semantics 변경은 RFC 대상).
그동안 **재사용 가능한 로직은 `main()` 에 넣지 말 것**: 로직은 `pub fn` 으로,
자가-검증은 `fn main()`(또는 `fn _selftest()`) 으로 분리한다. CI 의
`stdlib_selftest_aggregate` 가 돌리면 안 되는 비-run-assert 파일(codegen smoke
등)은 첫 10줄에 `// @selftest_skip` 마커를, CI 게이트에 포함할 순수·deterministic
테스트는 `// @ci_gate` 마커를 단다(`hexa tool/stdlib_selftest_aggregate.hexa
--ci-gate`).
