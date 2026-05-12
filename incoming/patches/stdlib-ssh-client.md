# `stdlib/net/ssh.hexa` — SSH client (then server)

**From:** wilson (downstream) — 2026-05-13. P0 #1 of 5 in the
`u-root/cpu` port — **largest, OK to land last**. Companion meta:
`stdlib-for-cpu-port.md`. Until this lands, downstream code stays on
`exec("ssh", host, cmd)` (acceptable interim — already works, just
ugly).

## Why

The `cpu`-pattern uses SSH as a multiplexed channel transport:
authentication → exec channel → 9P-over-SSH stream. Today wilson
forks `ssh(1)` from every `hexa-r` / `py-r` call — a textbook SPEC
§16 fork-storm. Absorbing SSH into hexa stdlib closes the loop.

Two phases — **client first, server later** (cpu-pattern client and
server have asymmetric needs and the server is much more code):

## Phase 1 — client (this note)

### Surface

```hexa
// stdlib/net/ssh.hexa  (client side)

pub struct ClientConfig {
    user:              string,        // default = $USER
    auth:              [AuthMethod],  // tried in order
    host_key_callback: HostKeyCallback,
    timeout_ms:        u32,           // dial timeout; 0 = no timeout
    keepalive_ms:      u32,           // server keepalive; 0 = off
}

pub enum AuthMethod {
    Password { pass: string },
    PublicKeyFile { path: string, passphrase: string },  // pass="" if unencrypted
    PublicKey { signer: Signer },
    Agent {  },                                          // SSH_AUTH_SOCK
}

pub enum HostKeyCallback {
    InsecureIgnore { },
    FixedKey { algo: string, blob: bytes },
    KnownHostsFile { path: string },                     // ~/.ssh/known_hosts
}

pub fn dial(network: string, addr: string, cfg: ClientConfig)
        -> Result<Client, SshError>
//  network: "tcp" | "tcp4" | "tcp6" | "unix"
//  addr:    "host:port"; default port 22

pub trait Client {
    fn new_session() -> Result<Session, SshError>
    fn dial_tcp(host: string, port: u16) -> Result<Conn, SshError>   // port-fwd
    fn listen_tcp(addr: string) -> Result<Listener, SshError>        // -R port-fwd
    fn close() -> Result<unit, SshError>
}

pub trait Session {
    fn set_env(name: string, value: string) -> Result<unit, SshError>
    fn request_pty(term: string, w: u16, h: u16, modes: [u8]) -> Result<unit, SshError>
    fn exec(cmd: string) -> Result<unit, SshError>          // start
    fn start(cmd: string) -> Result<unit, SshError>         // alias of exec; non-block
    fn wait() -> Result<int, SshError>                      // exit rc

    // streams (set before start())
    fn stdin()  -> Writer
    fn stdout() -> Reader
    fn stderr() -> Reader

    fn close() -> Result<unit, SshError>
}

// terminal modes (RFC 4254 §8) — minimal set for cpu-like cases
pub const TTY_OP_ISPEED : u8 = 128
pub const TTY_OP_OSPEED : u8 = 129
pub const ECHO          : u8 = 53
pub const ICANON        : u8 = 51
// ... full table available behind a const block

// key parsing
pub fn parse_private_key(pem: bytes, passphrase: string)
        -> Result<Signer, SshError>
pub fn parse_authorized_key(line: string)
        -> Result<(string /*algo*/, bytes /*blob*/, string /*comment*/), SshError>

pub struct SshError { code: SshErrorCode, msg: string }
pub enum SshErrorCode {
    DialFailed, AuthFailed, HostKeyMismatch, ChannelClosed,
    ProtocolError, IoError, Cancelled
}
```

### Subset that cpu-client actually needs (MVP)

| feature | cpu uses it? | MVP? |
|---|---|---|
| password auth | rarely | skip MVP |
| public-key file auth | **yes** (`~/.ssh/cpu_rsa` default) | **yes** |
| agent auth | yes | yes |
| host-key fixed / known_hosts | yes | one path is fine (start with InsecureIgnore + KnownHostsFile; Fixed in v2) |
| exec channel + stdin/stdout/stderr | **yes** | **yes** |
| PTY request | yes | **yes** |
| set_env | yes | yes |
| direct-tcpip (port forward, client→remote) | yes | **yes** |
| forwarded-tcpip (-R) | sometimes | v2 |
| sftp subsystem | no | skip |
| keepalive | nice | yes |

MVP can ship with ~60–70% of the surface and `cpu`'s "exec a command
over SSH, optionally with a PTY, optionally with one port forward" is
covered.

## Phase 2 — server (separate note when phase-1 lands)

The cpu **server** (`cpud`) needs an SSH server: `listen_tcp` +
session handler + exec channel handling + 9P-over-the-channel.
Surface ~mirror of client but inversed. Larger code; spec it after
client lands and we know which abstractions worked.

## Crypto dependencies

SSH needs:
- **ed25519** sign/verify (RFC 8709) — most common modern key
- **rsa-sha2-256 / rsa-sha2-512** (RFC 8332) — legacy compat
- **ecdsa-sha2-nistp256/384/521** — common
- **curve25519-sha256** key exchange (RFC 8731)
- **chacha20-poly1305@openssh.com** + **aes128-gcm@openssh.com** ciphers
- **hmac-sha2-256** MAC (when not using AEAD ciphers)

Whether hexa already has these (or how — `stdlib/crypto/*`?) is the
gating question. If hexa has no crypto stdlib, this note has a
prerequisite note: `stdlib-crypto-ssh-suite.md` (ed25519 + rsa +
curve25519 + chacha20-poly1305 + aes-gcm + hmac-sha2). Filing that
prerequisite is recommended even if SSH itself lands much later.

## Open

- **Crypto stdlib state.** Need to confirm what hexa already exposes.
  If nothing crypto-grade, SSH is effectively gated on landing the
  crypto suite — much more than ~2500 LOC then.
- **Bytes/Reader/Writer types.** hexa stdlib's IO abstractions
  (Reader / Writer / Conn) should already exist for `stdlib/net/tcp`
  — SSH reuses them.
- **Async semantics.** SSH channels are concurrent over one TCP
  connection; the surface should pair with `stdlib/channel` /
  `stdlib/jsonl_pool` cleanly.

## Atlas / diagnostics

- **No atlas L candidates.** SSH RFCs are protocol, not law.
- **HX codes**: a new HX86xx series for SSH protocol violations
  (auth failure, bad message type, kex failure). Spec in this file
  when implementing.

## Size estimate

- **Client MVP (the surface above, key auth + exec + PTY + one
  forward type)**: ~1500 hexa LOC + however much crypto already
  exists.
- **Client full (all auth types, ssh_config integration, multiplex)**:
  ~2500.
- **Server (phase 2)**: ~+1500 on top.

If a crypto suite needs to come first, multiply that by 2–3.

## Downstream consumers

- wilson `pool` plugin (POOL.md **stage-C** — last absorption phase).
- Any hexa-native remote-exec / file-transfer tool.

No wilson-side change. Filed per AGENTS.md hexa-lang handoff protocol.
Meta note: `stdlib-for-cpu-port.md`. Largest of the P0 five; expected
to land last.
