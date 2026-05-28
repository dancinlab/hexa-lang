# hexa-lsp — capability matrix

> Status: **Phase 4 Step 2 skeleton** · LSP spec target: **3.17**
> Roadmap: `.roadmap.lsp` (LP1 close 2026-05-06)

This file is the SSOT for what hexa-lsp does and does not implement, so
IDE consumers can plan integration without reading the source.

> **갱신 (2026-05-29) — 실제 빌드되는 서버는 `self/lsp.hexa` (monolith)**.
> 이 디렉터리(`self/lsp/`)는 진단 중심 스켈레톤이고, 디스패처
> (`self/main.hexa`의 `lsp` 분기)가 `exec_replace`하는 산출물은
> `tool/build_hexa_lsp.hexa`가 빌드한 `bin/hexa-lsp` = `self/lsp.hexa`이다.
> 아래 매트릭스의 ❌ Step 3+ 였던 항목들은 monolith에서 이미 동작한다:
>
> | method | monolith 상태 |
> |---|---|
> | `textDocument/completion` | ✅ keyword + builtin + **stdlib `pub fn` 라이브 스캔** + 파일-로컬 심볼 |
> | `textDocument/hover` | ✅ keyword/builtin/심볼 doc |
> | `textDocument/definition` | ✅ 파일-로컬 심볼 |
> | `textDocument/references` | ✅ (capability + dispatch 추가됨) |
> | `textDocument/rename` | ✅ (orphan이던 핸들러 dispatch 배선) |
> | `textDocument/semanticTokens/full` | ✅ lexer SSOT 기반 |
>
> **멀티메시지 framing**: body를 헤더와 같은 `term_read_byte` 스트림으로
> 정확히 `Content-Length` 바이트만 읽도록 고쳐(`read_n_bytes`), 첫 메시지
> 이후 프레임이 드롭되던 문제를 해소 — 실-에디터 세션이 정상 동작한다.
>
> **agent용 one-shot CLI 모드** (editor 없이 grep 대체, stale-immune):
> `hexa-lsp <def|refs|sig|sym|complete> [name]` — daemon과 같은 심볼 surface를
> 재사용해 실제 트리를 매 호출 파싱한다.
>
> **자동반영**: `lsp-rebuild` 훅이 `self/lsp.hexa` / `self/lsp/*.hexa` 편집 시
> `bin/hexa-lsp`를 백그라운드 재빌드한다 (tape/n6/kosmos와 동일 패턴).

## JSON-RPC envelope
| Direction | Format | Implemented |
|---|---|---|
| Request | `{jsonrpc, id, method, params}` | ✅ |
| Response | `{jsonrpc, id, result\|error}` | ✅ |
| Notification | `{jsonrpc, method, params}` | ✅ |

## Server capabilities (from `init_capabilities` in `protocol.hexa`)
| Capability | Value | Notes |
|---|---|---|
| `textDocumentSync.openClose` | `true` | didOpen / didClose tracked |
| `textDocumentSync.change` | `1` (full) | full sync per change; incremental deferred |
| `textDocumentSync.willSave` | `true` | willSave notification accepted |
| `textDocumentSync.willSaveWaitUntil` | `true` | request handled (returns empty TextEdit) |
| `textDocumentSync.save.includeText` | `true` | didSave carries post-save bytes |
| `diagnosticProvider.interFileDependencies` | `false` | per-file only |
| `diagnosticProvider.workspaceDiagnostics` | `false` | push model only |

## Method matrix
| Method | Kind | Status | Handler | Notes |
|---|---|---|---|---|
| `initialize` | request | ✅ | `handle_initialize` | Returns capabilities + serverInfo |
| `initialized` | notif | ✅ | (no-op) | |
| `textDocument/didOpen` | notif | ✅ | `handle_did_open` | Triggers law_check, emits diagnostics |
| `textDocument/didChange` | notif | ✅ | `handle_did_change` | Re-runs law_check (full sync) |
| `textDocument/willSave` | notif | ✅ | `handle_will_save` | No-op (notification spec) |
| `textDocument/willSaveWaitUntil` | request | ✅ (stub) | `handle_will_save_wait_until` | Always returns `[]` — TextEdit auto-fix is Step 3+ |
| `textDocument/didSave` | notif | ✅ | `handle_did_save` | Legacy law gate + per-rule (lint-rules) granular diagnostics |
| `shutdown` | request | ✅ | `handle_shutdown` | Returns null |
| `exit` | notif | ✅ | (process exit 0) | |
| `textDocument/completion` | request | ❌ Step 3+ | — | not advertised in capabilities |
| `textDocument/hover` | request | ❌ Step 3+ | — | not advertised in capabilities |
| `textDocument/definition` | request | ❌ Step 3+ | — | not advertised in capabilities |
| `textDocument/references` | request | ❌ Step 3+ | — | not advertised in capabilities |
| `textDocument/rename` | request | ❌ Step 3+ | — | not advertised in capabilities |
| `textDocument/formatting` | request | ❌ Step 3+ | — | not advertised in capabilities |
| `workspace/diagnostic` | request | ❌ Step 3+ | — | pull-model deferred |

## Diagnostic surface
Granular per-rule diagnostics emitted by `raw_diagnostics.hexa`:

| Rule | Enforcer | Severity | Notes |
|---|---|---|---|
| hexa-only | `tool/hexa_only_lint.hexa` | Error (1) | Banned-extension on staged paths |
| ai-native (ai-native-enforce) | `tool/ai_native_lint.hexa` | Error (1) | `path:line:col: [tag L# ...] msg` parsing |
| silent-error (silent-error) | `tool/error_propagation_lint.hexa` | Error (1) | `level[@rule] locus: msg` parsing |

Skipped on per-keystroke save (cost > benefit):
honest-caveat proof-carrying · no-hardcode no-hardcode · self-host fixpoint self-host-fixpoint.

## IDE compatibility notes
- **VS Code**: Use `vscode-languageclient` with stdio transport. The skeleton
  reads stdin once per invocation; an editor extension should keep the
  process alive (LSP standard) — this is a Step 3 lift.
- **Neovim built-in LSP**: same caveat — needs persistent stdin.
- **Helix / Zed**: untested; should work given LSP 3.17 conformance.

## Known gaps (not yet roadmapped)
- `read_message` reads entire stdin at once instead of doing
  Content-Length framed loop. See `server.hexa` line 50 comment.
- JSON parsing is substring-based regex-lite; no proper escape handling
  beyond the basic four (`\"`, `\\`, `\n`, `\t`). UTF-8 multi-byte intact.
- Document store (`doc_store`) is single-process and never garbage-
  collected — Step 3 should add a uri-keyed map with TTL/explicit close.
