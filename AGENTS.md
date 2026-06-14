# AGENTS.md — hexa-lang

> 📍 SSOT: [ARCHITECTURE.md](ARCHITECTURE.md) · governance [CLAUDE.md](CLAUDE.md)

AI agent harness entry point (agents.md standard). hexa-lang is a self-hosted native compiler
with an embedded theorem **atlas** and the `hx` package manager — every formula-bearing
function must cite an atlas law, carry an active `@verify`, or declare a `@grace`, or the build
refuses to emit a binary (stage S8, fatal `HX8004`).

Governance, repository structure, and the harness quick reference are maintained in a single
SSOT — see **[CLAUDE.md](CLAUDE.md)** — to avoid drift between the two agent guides. The
architecture SSOT is **[ARCHITECTURE.md](ARCHITECTURE.md)**; history lives in
**[CHANGELOG.md](CHANGELOG.md)**.

## Quick reference

| Command | Purpose |
|---------|---------|
| `.harness-engine/bin/harness docs check` | single-doc discipline (architecture SSOT + log + quickref) |
| `.harness-engine/bin/harness lint` | staged-L0 + freshness + convergence gate |
| `hexa verify` | g5 gate: S6 equational + S8 citation + atlas reverify/auto-fold |
| `hx commit` / `hx push` | SSOT-attested git wrappers |
