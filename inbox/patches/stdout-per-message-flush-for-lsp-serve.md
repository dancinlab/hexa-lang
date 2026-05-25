# stdout per-message flush — LSP stdio serve 의 write-side 카운터파트

- **kind**: patches
- **status**: open
- **filed**: 2026-05-26
- **relates**: #1163 (read_stdin_n raw fd-0 read — read-side), kosmos PR #6 (`--stdio` serve)

## 문제

`#1163` 이 raw N-byte stdin read(`read_stdin_n_c`)를 추가해 LSP stdio 서버의 **읽기**
쪽이 hexa-native 로 가능해졌고, kosmos PR #6 이 그 위에 Content-Length framed
JSON-RPC serve 루프를 올렸다 (`hexa run lsp/kosmos_lsp.hexa --stdio`).

남은 갭은 **쓰기** 쪽이다. 서버는 응답을 `print(...)` (no-newline) 으로 내보내는데,
stdout 이 **pipe 일 때 block-buffered** 라 응답이 4KB 버퍼가 차거나 프로세스가 종료할
때까지 전달되지 않는다. 즉:

- 파이프 배치 입력(스모크 테스트)은 EOF 에서 버퍼가 drain → 정상 동작.
- 살아있는 에디터 세션(LSP 클라이언트)은 `initialize` 응답이 버퍼에 갇혀 전달 안 됨
  → 클라이언트는 응답 대기, 서버는 다음 요청 대기 → **deadlock**.

그래서 kosmos `bin/kosmos-lsp` 는 라이브 에디터 세션에 대해 아직 `.py` 를 유지한다.

## 요청

메시지마다 stdout 을 비울 수단:

- `flush()` / `flush_stdout()` 빌트인 (가장 단순), **또는**
- dispatch 런타임의 stdout 을 unbuffered / line-buffered 로 설정 (`setvbuf(stdout, NULL, _IONBF, 0)` 류).

framing 출력은 line 경계가 없으므로(`Content-Length: N\r\n\r\n<body>` 에 trailing
newline 없음) line-buffered 만으로는 부족할 수 있다 → **명시적 flush 빌트인**이 가장 견고.

## 효과

flush 가 들어오면 hexa-native LSP stdio 서버가 라이브 에디터에서 동작 →
`bin/kosmos-lsp`(및 hxc LSP)가 `.py` 폴백을 떼고 완전 hexa-native 로 전환 가능.
read_stdin_n_c(읽기) + flush(쓰기)로 stdio JSON-RPC 의 양방향이 닫힌다.
