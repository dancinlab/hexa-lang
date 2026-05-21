# hexa-lang Constitution

## Core Principles

### I. Atlas-First Citation (NON-NEGOTIABLE)
Every formula-bearing function MUST carry `@cite(L[id])`, an active `@verify`, or an explicit `@grace`. Uncited formulas are rejected at S8 with `HX8004` — the compiler stays parked, there is no binary. The atlas is compile-time embedded into the compiler; runtime `.n6` overlays are forbidden. `.n6` is an export/inspection format only.

### II. Strict-Lint Gate (NON-NEGOTIABLE)
The 8-stage gate is non-bypassable: S0 parse → S1 resolve → S2 bind → S3 type → S4 domain → S5 units → S6 `@verify` (equational) → S7 `@prove` → S8 citation. No `--no-verify`, no `--skip-stage`, no escape hatches. A failing stage means a failing build; the failure surfaces with the exact rule, not a generic error.

### III. Native Only — No Lowering
hexa-lang generates native code directly. No LLVM, no C-transpile, no foreign IR. The compiler is self-hosted: the toolchain that builds `hexa` is itself written in `.hexa`. Lowering to an external backend is not an option; it would invalidate the gate.

### IV. PR-Only Atlas Mutation
New laws, equations, primitives, constants, and errors enter the embedded atlas only via reviewable PR through `hexa atlas pr`. Direct fold-to-live is forbidden even on the owner repo. Discovered laws follow the cycle: `@verify` → atlas promote → tombstone retroactive sweep → auto-PR. The atlas grows monotonically and traceably.

### V. SSOT for stdlib & Language Semantics
hexa-lang is the single source of truth for the standard library, the atlas, the grammar, lattice policy, the toolchain (`hexa`, `hexa atlas`, `hexa run`, …), and language-level conventions. Downstream consumers — `phanes`, `demiurge`, `wilson`, and any future hexa-native project — are pointers, not forks. They MUST NOT vendor, reimplement, or shadow stdlib primitives; gaps are filed upstream as PRs against this repository. The concrete stdlib surface, inventory, and boundary are defined in the "Standard Library (SSOT)" section below.

### VI. Lattice-as-Tool
The n=6 perfect-number primitives are tools, not constraints. A project's ceiling is set by mathematical and physical reality, NOT by the n=6 lattice. Anti-patterns — fit-to-convenient-number, over-claim, constraining-first-question — are blocked at review. Authority: `LATTICE_POLICY.md` in the repo root.

## Repository Layout

```
hexa-lang/
├── atlas/      # P / C / L / E entries — embedded theorem dictionary (SSOT)
├── compiler/   # 8-stage strict-lint pipeline (S0–S8)
├── comb/       # combinatorial / lattice primitives (n=6 family)
├── component/  # language-level components (intrinsics, traits, …)
├── config/     # toolchain configuration surfaces
├── dist/       # built artifacts (not source of truth)
├── doc/        # specs and reference material
├── bin/        # CLI entrypoints (`hexa`, `hexa atlas`, …)
├── bench/      # performance and gate-cost measurements
└── .specify/   # Spec Kit pipeline artifacts (this constitution lives here)
```

Co-referenced authority files at repo root:
`LATTICE_POLICY.md` · `HEXA-NATIVE-ONLY.md` · `COMPILER.md` · `GOAL.md` · `ROADMAP.md`.

## Standard Library (SSOT)

`hexa-lang/stdlib/` is the canonical public surface for user-importable modules. Users reach it via `import "../stdlib/<name>.hexa"`.

- **Inventory.** `stdlib/STDLIB.json` is the machine-readable SSOT for the public surface. Every add, rename, or removal updates this file in the same PR. A `.hexa` module in `stdlib/` without a matching `STDLIB.json` entry — or a `STDLIB.json` entry without a matching file — is a build-gate failure.
- **Public vs internal boundary.**
  - `stdlib/` — public API. Stable import contract. Changes follow Principle IV (PR-only).
  - `self/lib/` — compiler internals (fraction, simd, sieve, tensor_ops, …). Not for downstream import.
  - `self/stdlib/` — compiler-bound utilities and SDK adapters used during self-host. Not part of the public stdlib contract.
  - These three buckets MUST NOT be merged. The boundary is structural; ergonomic re-shuffling is rejected at review.
- **Categories.** collections · math · string · bytes · hash · I/O (`http`, `http_sse`, `channel`, `cancel`, `future`, `c_ffi`) · numerics (`autograd`, `nn`, `optim`) · domain modules (`consciousness`, `firmware`, `aura`, `brain`, `crystal`, `flame`, `fusion`, …) · low-level primitives under `stdlib/core/` (e.g., `wrap_pi` for angle normalization).
- **Documentation.** AI-readable specs live next to the source as `<name>.ai.md` (e.g., `channel.ai.md`, `cancel.ai.md`, `io.ai.md`, `semver.ai.md`, `yaml.ai.md`). Source and spec move together; orphaned `.ai.md` files are a Principle II violation.
- **Tests.** Module tests are co-located as `<name>_test.hexa` (e.g., `atoms_test.hexa`, `collections_test.hexa`) and run through the same 8-stage gate as production code.
- **Pointer-project usage.** `phanes`, `demiurge`, `wilson`, and other consumers import directly from `hexa-lang/stdlib/`. They do not vendor, copy, or reimplement. Gaps are filed here as PRs; the consumer refreshes its pointer after merge.

## Development Workflow

1. **Constitution Check.** Every plan and spec validates against the six principles above before implementation begins. A principle conflict blocks the plan, not the constitution.
2. **Atlas-driven design.** New formulas start by searching the atlas (`hexa atlas search "<expr>"`). If a matching `L[id]` exists, cite it. If not, the work item is "propose new law via PR", not "inline the formula".
3. **PR cadence.** All atlas mutations and stdlib changes land via PR. Hot-patching the embedded atlas is a Principle IV violation regardless of urgency.
4. **Tombstone discipline.** When a law changes or is retracted, every dependent receives a tombstone and an auto-PR. Manual cleanup of tombstones without atlas action is a violation.
5. **Downstream alignment.** When a pointer project (`phanes`, `demiurge`, `wilson`, …) reports a gap, the fix lands here first; the consumer then refreshes its pointer.

## Governance

- Amendments land via a PR that updates this file and bumps the version per semver: MAJOR = principle removal/redefinition · MINOR = new principle/section · PATCH = wording. Amendments propagate through `.specify/templates/*` in the same PR.
- hexa-lang holds cross-project authority for stdlib, atlas, grammar, and lattice policy. When a downstream project's local constitution conflicts with this one on those subjects, this constitution wins.
- Complexity must be justified inline in the corresponding `design.md` (or equivalent) entry. Default = simpler.

**Version**: 1.0.0 | **Ratified**: 2026-05-21 | **Last Amended**: 2026-05-21
