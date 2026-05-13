# Stdlib gap: bidirectional stdio for long-running subprocesses (`exec_stream_write`)

**Filed by:** wilson. Discovered while scaffolding the `mcp` plugin (Model
Context Protocol) — wilson's P0 cluster item #5.

**Date:** 2026-05-13.
**Severity:** blocks full MCP client implementation. Scaffold (config parser +
`/mcp list` slash) is shipped (see `~/core/wilson/plugins/mcp/`), but actual
server spawn + JSON-RPC handshake (initialize → list_tools → call_tool) requires
writing to a child process's stdin while reading stdout. We don't have that.

## What we have today

```hexa
spawn_bg(cmd) -> int                                  // fire-and-forget; rc only
exec_with_status(cmd) -> [stdout, rc]                 // sync, blocks, no streaming
exec_stream_async(cmd) -> int                         // start streaming read
exec_stream_poll(h) -> [done_int, line_str]           // read one line, non-blocking
exec_stream_close(h) -> int                           // close + return exit
```

`exec_stream_async` is one-directional — wilson can read the child's stdout
line-by-line but **cannot write** to the child's stdin. The popen-based impl
opens with `"r"` mode (read pipe).

## What MCP (and similar protocols) need

```
parent → child stdin:  {"jsonrpc":"2.0","id":1,"method":"initialize","params":{...}}\n
child stdout → parent: {"jsonrpc":"2.0","id":1,"result":{"capabilities":...}}\n
parent → child stdin:  {"jsonrpc":"2.0","id":2,"method":"tools/list"}\n
child stdout → parent: {"jsonrpc":"2.0","id":2,"result":{"tools":[...]}}\n
...
```

A long-running subprocess with continuous bidirectional JSON-RPC. Every
mainstream MCP server runs this way (`@github/mcp-server`, `@notion/mcp`,
postgres-mcp, custom ones via `npx`). Without it, wilson can't be an MCP
consumer — only a config viewer.

## Proposed API

Minimal addition:

```hexa
// Open a child with bidirectional pipes (popen with "r+" / socketpair / pipe2).
// Returns handle (>= 0) or -1 on spawn fail.
exec_stream_open(cmd: string) -> int

// Write a line (no newline appended — caller controls framing) to child stdin.
// Returns bytes written (>= 0) or -1 on error.
exec_stream_write(h: int, data: string) -> int

// Read one line from child stdout (non-blocking). Same shape as
// exec_stream_poll: [done_int (1 = EOF/closed), line_str].
exec_stream_read(h: int) -> array

// Close stdin only (signal "no more input"; child may still write outputs).
exec_stream_close_stdin(h: int) -> int

// Close everything + reap. Returns exit status (WEXITSTATUS or -signal).
exec_stream_close(h: int) -> int
```

`exec_stream_open` is the new primitive; `exec_stream_write` /
`exec_stream_close_stdin` are the bidirectional half; `exec_stream_read` mirrors
the existing `exec_stream_poll` (could be the same fn).

## Alternative: socketpair-based duplex

Instead of two pipes (stdin + stdout), use a `socketpair(AF_UNIX, SOCK_STREAM,
0)` and dup2 both ends into the child's stdin+stdout. Single FD on the parent
side, simpler bookkeeping, same JSON-RPC framing. Some MCP servers expect
distinct stdin/stdout though (interactive tools), so two-pipe is more compatible.

## Workaround in wilson (rejected)

We could ship a shim shell script that does the bidirectional plumbing:

```bash
# .wilson/mcp/run-server.sh — receive lines via fifo, write to child stdin,
# read child stdout to another fifo
mkfifo /tmp/wilson-mcp-stdin-$$
mkfifo /tmp/wilson-mcp-stdout-$$
cat /tmp/wilson-mcp-stdin-$$ | <server-cmd> > /tmp/wilson-mcp-stdout-$$ &
```

Then wilson's mcp plugin reads/writes the fifos. But this adds latency,
complicates lifecycle, and reinvents what the OS already provides. Better to
land the primitive.

## What unblocks once this lands

1. `mcp` plugin full client (JSON-RPC over the new bidi stream)
2. `mcp__servername:toolname` tool registration at activate-time
3. `/mcp test <server>` connection check
4. OAuth elicitation handler (server requests user auth → wilson shows modal → reply)
5. Any future bidirectional protocol (LSP, debug adapters, custom RPC)

## Related

- wilson commit pinning the scaffold: `~/core/wilson/plugins/mcp/`
- ORIGIN.md P0 cluster (this is item #5)
- docs/feature-parity-claude-code.md §Part I (Tools, MCP integration)
