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
