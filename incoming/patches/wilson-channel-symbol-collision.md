# Symbol collision: `channel_send/recv/close` declared both as fn (stdlib/channel.hexa) and as HexaVal var (native/thread.c)

**Filed by:** wilson. Blocks all wilson builds (parallel pool refactoring session
exposed this). thread.c was added 2026-05-13 with the new channel primitives.

**Date:** 2026-05-13.
**Severity:** every wilson build broken — both `channel_send` and the new
HexaVal globals declared with the same name. clang fails:

```
build/artifacts/wilson.c:826:9: error: redefinition of 'channel_send' as different kind of symbol
/Users/ghost/core/hexa-lang/self/native/thread.c:247:9: note: previous definition is here
build/artifacts/wilson.c:828:9: error: redefinition of 'channel_recv' as different kind of symbol
/Users/ghost/core/hexa-lang/self/native/thread.c:248:9: note: previous definition is here
build/artifacts/wilson.c:830:9: error: redefinition of 'channel_close' as different kind of symbol
/Users/ghost/core/hexa-lang/self/native/thread.c:249:9: note: previous definition is here
```

## Two definitions

### Old (stdlib/channel.hexa via FIFO-based impl)
- `fn channel_send(fd: int, msg: string) -> bool` — sends a JSON line through
  a FIFO-backed channel; used by `plugins/swarm/main.hexa` (channel_send_sync
  wrapper) and earlier by `plugins/pool/main.hexa` before today's refactor.
- Codegen emits `HexaVal channel_send(HexaVal fd, HexaVal msg);` in user.c.

### New (native/thread.c lines 247-249)
```c
HexaVal channel_send;
HexaVal channel_recv;
HexaVal channel_close;
```
These appear to be HexaVal "fn-ref" globals — exposed to the hexa side so
user code can use `channel_send` as a callable value. Likely paired with
`_hexa_init_thread_fn_shims()` (runtime.c:10089) which initializes them.

## Why they collide

clang sees:
1. wilson.c line 826: `HexaVal channel_send(HexaVal, HexaVal);`   (function decl)
2. thread.c line 247: `HexaVal channel_send;`                      (variable decl)
→ "redefinition of 'channel_send' as different kind of symbol"

## Fix options

**A.** Rename thread.c globals — `channel_send` → `__hexa_channel_send_ref`
(or similar). Single line change, three vars. Doesn't break anyone (these
are private bridge symbols).

**B.** Drop the user-side `fn channel_send` declaration — the new primitive
supersedes. Means migrating swarm + pool to the new primitive (already
underway in the parallel pool refactor).

**C.** Namespace the user fn — rename to `fifo_channel_send` (and recv/close)
in stdlib/channel.hexa, update swarm to call those.

Recommend **A** — minimal blast radius, both APIs coexist while the
migration happens.

## Workaround in wilson (rejected)

Wilson could remove pool/swarm from the bundle to bypass — but that breaks
the user's actual functionality. No.

## Wilson commit pinning this

- wilson `c39bd9d` was the last green commit (Sprint 4 modal consumers).
- After c39bd9d, the parallel pool refactoring session pushed pool/main.hexa
  changes that include channel uses — build broke. Identical break would
  hit any code that touches the channel primitives until one side is
  renamed.

넣었다.
