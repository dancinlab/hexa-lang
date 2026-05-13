# `stdlib/9p.hexa` — Plan 9 9P2000.L message codec + `Attacher` interface

> **status (MVP)**: `applied` (2026-05-14 KST) — `self/stdlib/p9/codec.hexa` ships the wire codec for the core message subset: Tversion/Rversion, Tattach/Rattach, Twalk/Rwalk, Topen/Ropen, Tread/Rread, Twrite/Rwrite, Tclunk/Rclunk, Rerror, plus the Qid struct, LE encode/decode helpers (u8/u16/u32/u64/str/bytes/qid), framing helpers (`p9_wrap_frame`, `p9_parse_header`), and a generic `p9_decode` dispatch. Pure hexa, no C bindings (composes with `hexa_net_read` / `hexa_net_write`). Live verified end-to-end via `/tmp/test_9p` — every encode→decode round-trip PASS including frame-size invariant (Tclunk frame=11B, header.size==11). Wilson 23/23 smoke PASS. **Deferred to v2**: getattr/setattr/readlink/readdir/fsync/rename/link/symlink/mknod/lock/getlock/xattr* (9P2000.L extras), Attacher/Session traits + `serve_attacher` message loop, async dispatch over `Tflush`.

**From:** wilson (downstream) — 2026-05-13. P0 #2 of 5 in the
`u-root/cpu` port. Companion meta: `stdlib-for-cpu-port.md`. Needs
`stdlib/net/socket.hexa` (already in hexa stdlib for TCP; UNIX
domain may need a small addition — see P1 #6).

## Why

The `cpu`-pattern transports the caller's namespace to the remote
host as a **9P share** mounted over the SSH channel. Without a
hexa-native 9P stack, downstream (wilson `pool`) must keep the Go
`u-root/cpu` binary in `~/.hx/bin` indefinitely — the largest single
piece of "the SPEC §16 fork-storm we still tolerate."

9P is the right protocol because:
- The **Linux kernel's `v9fs`** is the in-tree 9P client. It already
  knows how to mount a 9P share — hexa needs to be the **server** side
  (export a tree) and **client codec** (so a hexa daemon can also
  *consume* a 9P export, symmetric).
- The wire format is small (~20 message pairs) and stable since 2007.
- It's the canonical "files as namespace" protocol; SPEC §16's
  absorbed-intrinsics philosophy lines up exactly (`cwd → cwd()`,
  `ls → list_dir()` — 9P is the network projection of that).

## Surface — proposed

### Wire codec

The 9P2000.L variant (Linux flavor, with extra messages over the
classic 9P2000). Messages live in pairs (`T<x>` = request, `R<x>` =
response):

```
T/R-version, T/R-auth, T/R-attach, T/R-error (R only), T/R-flush,
T/R-walk, T/R-open, T/R-create, T/R-read, T/R-write, T/R-clunk,
T/R-remove, T/R-stat, T/R-wstat,
T/R-getattr, T/R-setattr,   (9P2000.L additions)
T/R-readlink, T/R-readdir, T/R-fsync, T/R-rename, T/R-link,
T/R-symlink, T/R-mknod, T/R-lock, T/R-getlock,
T/R-xattrwalk, T/R-xattrcreate
```

Surface shape (sketch):

```hexa
// stdlib/9p/codec.hexa

pub struct Header { size: u32, mtype: u8, tag: u16 }

pub enum Msg {
    Tversion { msize: u32, version: string },
    Rversion { msize: u32, version: string },
    Tattach  { fid: u32, afid: u32, uname: string, aname: string, uid: u32 },
    Rattach  { qid: Qid },
    Twalk    { fid: u32, newfid: u32, wnames: [string] },
    Rwalk    { wqids: [Qid] },
    Topen    { fid: u32, mode: u32 },                    // 9P2000.L: l_open
    Ropen    { qid: Qid, iounit: u32 },
    Tread    { fid: u32, offset: u64, count: u32 },
    Rread    { data: bytes },
    Twrite   { fid: u32, offset: u64, data: bytes },
    Rwrite   { count: u32 },
    Tclunk   { fid: u32 },
    Rclunk   { },
    Tgetattr { fid: u32, request_mask: u64 },
    Rgetattr { ... },
    // ... rest of 9P2000.L
    Rerror   { ecode: u32 }                              // .L flavor: numeric errno
}

pub struct Qid { qtype: u8, version: u32, path: u64 }

pub fn encode(m: Msg, tag: u16) -> bytes
pub fn decode(buf: bytes) -> Result<(Msg, u16), DecodeError>

// negotiated msize for the connection — clamp on encode
pub fn max_msg_size() -> u32   // default 8192 + 24 header etc.
```

### `Attacher` interface (server side)

Same shape as `hugelgupf/p9` — gives the hexa user a way to *expose*
their own tree as 9P without writing the wire layer:

```hexa
pub trait Attacher {
    fn attach() -> File
}

pub trait File {
    fn walk(names: [string]) -> Result<(File, [Qid]), int>
    fn open(mode: u32) -> Result<(Qid, u32), int>      // (qid, iounit)
    fn read_at(buf: bytes, offset: u64) -> Result<u32, int>
    fn write_at(buf: bytes, offset: u64) -> Result<u32, int>
    fn get_attr(mask: u64) -> Result<Attr, int>
    fn set_attr(mask: u64, attr: Attr) -> Result<unit, int>
    fn readdir(offset: u64, count: u32) -> Result<[DirEntry], int>
    fn close() -> Result<unit, int>
    // ... (symlink, mknod, lock, xattr — full surface)
}
```

A **`serve_attacher(conn, root)`** helper drives the message loop
(decode → dispatch → encode → send), so a downstream just implements
`Attacher`/`File` for their tree.

### Client side

Symmetric — the hexa side can also *consume* a 9P export programmatically
(useful for testing without involving `v9fs`):

```hexa
pub fn dial(conn: Conn) -> Result<Session, int>
pub trait Session {
    fn attach(uname: string, aname: string) -> Result<RemoteFile, int>
}
pub trait RemoteFile {
    fn walk(...) ; fn open(...) ; fn read_at(...) ; ...   // mirrors File
}
```

## Open

- **9P2000 vs 9P2000.L vs 9P2000.u.** The Linux kernel mounts 9P2000.L
  natively. Plan 9 / 9front + diod also support .L. Recommend .L as
  the v1 target; .u/classic 9P can be a flag (`Tversion` carries the
  version string).
- **Async vs sync handling.** 9P has `Tflush` to cancel an in-flight
  request — the server must support concurrent operations on the
  same connection. Hexa channel/jsonl_pool primitives line up; the
  surface should clarify expectations (sequential within a tag,
  concurrent across tags).
- **Endianness.** All ints little-endian. Trivial but easy to
  get wrong; the codec needs explicit `u32_le` / `u64_le` helpers
  (or `stdlib/encoding/binary.hexa` if that exists).

## Atlas / diagnostics

- **Atlas L-candidate**: the on-wire invariant *"`size` field equals
  the total length of the framed message including the size field
  itself."* — a small L node (`L[9p.frame.size.is.total]`) about the
  framing law. Not high-priority for atlas growth but a clean example
  of a protocol invariant as L node.
- **Diagnostics — new HX85xx series** for codec violations:
  - `HX8501` "9p: malformed frame, size N < header"
  - `HX8502` "9p: unknown message type"
  - `HX8503` "9p: msize exceeded by Rread/Twrite payload"
  - `HX8504` "9p: tag reuse before reply"
  These fire only inside `decode()` / `encode()` and the server loop.

## Size estimate

~1000–1500 hexa LOC. The codec is ~600 (one encode/decode pair per
message type, ~20 pairs). The Attacher trait + `serve_attacher` is
~400. Client mirror is ~300. Tests should fixture-replay
`hugelgupf/p9`'s known-good wire dumps.

## Downstream consumers

- wilson `pool` plugin (POOL.md stage-B). Server side to export the
  caller's tree to the remote cpu daemon; client side to consume a
  remote's tree symmetrically.
- Any future hexa "files-over-network" pattern.

No wilson-side change. Filed per AGENTS.md hexa-lang handoff protocol.
Meta note: `stdlib-for-cpu-port.md`.
