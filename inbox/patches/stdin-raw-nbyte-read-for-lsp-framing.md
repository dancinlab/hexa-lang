# patch: raw N-byte incremental stdin read (`read_stdin_n`) for LSP framing

> filed 2026-05-26 from kosmos G2 (kosmos_lsp.py → kosmos_lsp.hexa port). The
> diagnostics engine (`validate` + `hover` + `--check`) ported byte-parity, but
> the **interactive LSP stdio server could not be ported** — a genuine hexa
> 0.1.0-dispatch capability gap, documented here so it lands upstream.

## 문제

LSP 는 stdin/stdout 에서 다음 프레이밍으로 통신한다:

```
Content-Length: <N>\r\n
\r\n
<N raw bytes of JSON>
```

이 프레임을 live pipe(에디터 ↔ 서버)에서 읽으려면 **"지금 정확히 N바이트를
증분으로 읽는다"** primitive 가 필요하다. 현 hexa stdin 표면은 둘 다 부적합:

| primitive | 동작 | LSP 부적합 이유 |
|---|---|---|
| `read_stdin()` | fd0 **전체 slurp**, EOF 까지 blocking | 에디터는 세션 중 EOF 를 안 보냄 → **deadlock** |
| `input()` | **라인 기반**, `\r` 제거, EOF 에서 `""` 반환 | (1) N-byte 비-라인정렬 body 못 읽음 (2) `\r` 제거로 헤더 종료 `\r\n\r\n` 감지 불가 (3) `""` vs 진짜 EOF 구분 불가 |

## 요청

raw, 비-라인, 증분, EOF-구분 가능한 stdin read:

```
// read exactly n bytes from fd0 (blocking until n read or EOF).
// returns the bytes read (len < n ⟹ EOF reached). NO newline translation.
fn read_stdin_n(n: int) -> [int]      // or -> string (raw, \r preserved)
```

있으면 충분: 헤더를 `read_stdin_n(1)` 루프로 `\r\n\r\n` 까지 읽고 Content-Length
파싱 → body 를 `read_stdin_n(N)` 으로 정확히 읽음. 표준 LSP 루프 그대로 포팅 가능.

## 영향

- `kosmos/lsp/kosmos_lsp.hexa` — validate/hover/--check 는 이미 server-ready.
  `read_stdin_n` 만 생기면 대화형 서버 포팅 즉시 가능 (현재 bin/kosmos-lsp 가
  대화형은 DEPRECATED `.py` 로 폴백 중).
- 일반적으로 hexa 로 작성하는 모든 stdio 프로토콜 서버(LSP·DAP·JSON-RPC)에 필요.

## 검증 제안

`read_stdin_n(3)` 가 `printf 'abc' | hexa run probe.hexa` 에서 `[97,98,99]`,
`printf 'ab' | …` 에서 `[97,98]` (len 2 < 3 = EOF) 를 반환하면 PASS.
