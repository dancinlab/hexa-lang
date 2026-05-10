# Security policy — hexa-antimatter

> This is a **substrate-spec repo**, not an operational system.  No live
> services, no telemetry endpoints, no auth flow.  The security surface
> is therefore narrow but real.

---

## §1 Threat model

What this repo *can* be attacked:

- **Supply-chain compromise of `.hexa` runtime** — the `hexa` interpreter is a separate `dancinlab/hexa-lang` repo; if compromised, every verifier in this repo runs untrusted code.  Mitigation: use a known-good `~/.hx/packages/hexa/hexa.real`; verify checksum.
- **Malicious PR introducing a backdoor in `.hexa` code** — could exfiltrate via `exec()` calls.  Mitigation: every `.hexa` file is reviewed; `verify/lint_numerics.hexa` enforces the 5-invariant pattern (no `exec()` outside controlled paths); `firmware_phase_d_lint.hexa` enforces structural invariants on Phase D files.
- **`state/*` data poisoning** — fixture rows in `state/*_LOG.hexa` could be falsified to inflate closure metrics.  Mitigation: fixture rows must be **public-domain announcements** with citation; live `state/*` rows (Phase E4) come from instrumented hardware with audit logs.

What this repo *cannot* be attacked:
- there's no live data feed at v1.1.0
- there's no flashed firmware
- there's no running service

---

## §2 Reporting a security issue

If you find a vulnerability:

- **Preferred**: open a private security advisory on GitHub (`Settings → Security → Security advisories → New advisory`)
- **Alternative**: email the maintainer (Github profile, public email)

Please do **NOT** open a public issue or PR for active security issues.

We aim to triage within 7 days.  Patches are released as point versions (e.g. v1.1.1).

---

## §3 Out-of-scope concerns

- **Anti-matter handling safety**: not in scope; this repo is paper-only.  Real Phase E4 operations require licensed cryogenic + radiation safety officers (per `factory/antimatter-factory.md §14 TEAM`).
- **Cyclotron radiation**: hospital PET cyclotrons (Phase E2) are subject to NRC / IAEA / KFDA regulation; not addressable in this repo.
- **CERN AD access**: governed by CERN safety + experimental access policy; not addressable here.
- **48 T magnet quench**: real physical risk if Phase E2 builds proceed; out-of-scope until then.

---

## §4 Code-level hygiene

- All `.hexa` files declare `let mut RUN = 0` + `let mut FAIL = 0`; lint enforces.
- All `.hexa` files declare `FALSIFIERS` list; lint enforces.
- `exec()` calls are limited to `cat`, `[ -f ... ]`, `pwd`, `date -u` — no arbitrary network calls.
- The single network-touching script is `verify/empirical_*_inspire.hexa`, which can be set offline via `HEXA_ANTIMATTER_OFFLINE=1` for fixture-only mode.
- Rust skeletons in `firmware/mcu/*.rs` are `#![no_std]`; no `std`, no `alloc`, no FFI.
- Verilog tops in `firmware/hdl/*.v` are pure RTL — no `$system()`, no `$ifdef SIM` backdoors.

---

## §5 Cryptographic / sensitive content

This repo contains **no** cryptographic keys, no API tokens, no secrets, no PII.  Anyone finding such content in a commit should report it via §2 immediately so it can be rotated and force-pushed-out.