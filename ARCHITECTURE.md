# hexa-lang — Architecture (SSOT)

> Single source of truth for the final architecture. **Update this file in place** (not append-only).
> History and decisions live in [CHANGELOG.md](CHANGELOG.md). Governance lives in [CLAUDE.md](CLAUDE.md).

## Overview

`hexa-lang` is a self-hosted native compiler for the `.hexa` language, shipped with the
`hx` package manager. There is **no LLVM anywhere in the toolchain**. The self-host backend
lowers source directly through its own IR to native objects (ELF64 / Mach-O arm64) and links
them with its own linker (`hexa_ld`); this native-emit path is a proven byte-identical fixpoint
(`gen3 ≡ gen4`) and is the default for `--emit`. Two pieces of C remain, by policy, not as
unfinished port debt — see [Self-host status](#self-host-status) for the honest accounting:
a C-transpile **fallback delegate** still serves some full `hexa build`/`run` flows until the
native end-to-end path lands, and an irreducible ~5.5k-LOC **C runtime substrate** (libc/syscall
floor, generated from `.hexa` emitter SSOTs) is compiled and linked into every binary
(RFC 061 §4.1 / g5 §7 permit substrate C; they forbid only a C-transpile *backend*).
Its defining feature is an embedded **atlas** — a ~4.2 MB theorem
dictionary (P primitives / C constants / L laws / E errors) baked statically into the binary.
Every formula-bearing function must either cite an atlas law (`@cite(L[id])`), carry an active
`@verify`, or declare an explicit `@grace`; otherwise the build refuses to produce a binary
(stage S8, fatal `HX8004`). Enforcement happens at the **build gate**, not at runtime — the
atlas adds 0 ms of runtime cost.

The compiler runs eight ordered strict-lint stages (S0 parse → S1 resolve → S2 bind →
S3 type → S4 domain → S5 units → S6 equational `@verify` → S7 proof `@prove` → S8 citation).
A binary appears only when every fatal stage passes. After the gate, source is lowered
HIR → MIR (SSA) → LIR and emitted per target. The compiler is self-hosting: the compiler
that builds `.hexa` is itself written in `.hexa` (`self/`).

## Self-host status

Honest accounting of where self-hosting actually stands (no overclaim — `git log` + the
`.verdicts/` tree are the evidence):

| Layer | State | Evidence |
|-------|-------|----------|
| Native-emit backend (own IR → Mach-O / ELF, no LLVM) | ✅ **byte-identical fixpoint** `gen3 ≡ gen4` | `.verdicts/.../N5-FIXPOINT-ACHIEVED`, `tool/selfhost_byteeq_gate.sh` |
| Default toolchain promotion (`--emit` → native gen3) | ✅ **flipped + persisted** across `hx install` | `tool/promote_selfhost.sh`, marker `~/.hx/.selfhost-default` |
| Multi-target bootstrap | ✅ arm64-darwin · linux-arm64 (real-HW byte-eq) · x86_64 (RUNG 1+3) | SELFHOST-NEXT domain ledger |
| `hexa run` routing | 🟡 **native-first + C-transpile delegate-fallback** (safety > coverage) | shim, native-route landing |

**Remaining residuals** (tracked, not silent):

- **x86_64 RUNG 2** — `print(str)` mis-prints because the x86_64 `STMT_CALL` path does not
  yet materialise the 16-byte `HexaVal {tag,payload}` SysV register-pair (arg0 → rdi:rsi).
- **Full native `hexa build` end-to-end** — gen3 owning the link + runtime orchestration, so
  the C-transpile delegate-fallback can be retired.
- **Irreducible C floor** — `self/runtime*.c` (~5.5k LOC tier-A: libc/libm/syscall/`HexaVal`
  arena) is **policy-accepted permanent C**, generated from `*_emit.hexa` SSOTs, not authored
  by hand and not port debt. A literal `ls self/*.c` empty tree (the HEXA-SELFHOST+ meta
  graduation bar) collides with this floor and is a definition question, not engineering debt.

## Component map

| Component | Path | Role |
|-----------|------|------|
| Compiler driver | `compiler/main.hexa` | Entry point: arg parse, atlas load, S0–S8 dispatch, codegen routing, emit/link orchestration |
| Lex (S0) | `compiler/lex/lexer.hexa` | Tokenize `.hexa` source → token stream |
| Parse (S0) | `compiler/parse/parser.hexa` | Token stream → module AST |
| Resolve (S1) | `compiler/check/resolve.hexa` | Symbol resolution, import binding, scope graph |
| Bind (S2) | `compiler/check/bind.hexa` | Identifier binding, declaration ordering, duplicate detection |
| Types (S3) | `compiler/check/types.hexa` | Type inference, typecheck, arity, generic constraints |
| Domain (S4) | `compiler/check/` | Domain / value-range validation |
| Units (S5) | `compiler/check/units.hexa` | Dimensional analysis (SI units, conversion validation) |
| Equational verify (S6) | `compiler/check/equational.hexa` | `@verify` gate: normalization + sample-eval counter-example search (`HX6001`/`HX6002`) |
| Proof (S7) | `compiler/check/` | `@prove` proof-obligation checking |
| Citation (S8) | `compiler/check/citation.hexa` | Atlas binding check (`@cite`/`@implements`/`@discover`) → fatal `HX8001`/`HX8002`/`HX8004`/`HX1099` |
| Atlas (embedded) | `compiler/atlas/embedded.gen.hexa` | ~4.2 MB rodata: the baked-in atlas nodes (P/C/L/E) |
| Atlas index | `compiler/atlas/static_index.hexa` | In-memory parsed atlas served to S8 (`static_atlas()`) |
| Atlas merger / fold | `compiler/atlas/merger.hexa`, `compiler/atlas/embed.hexa` | Merge rodata + `.n6` overlay; fold new nodes into `embedded.gen.hexa` |
| Lower → HIR | `compiler/lower/ast_to_hir.hexa` | AST → high-level IR (desugaring, let-flattening) |
| Lower → MIR | `compiler/lower/hir_to_mir.hexa` | HIR → middle IR (SSA, control-flow graph) |
| Optimize | `compiler/optimize/` | Const-fold, DCE, inline (opt-level 0–3) |
| Codegen (LIR) | `compiler/codegen/{arm64_darwin,x86_64_linux,thumbv7em_eabihf,nvptx_target}.hexa` | MIR → LIR, target-specific regalloc + instruction selection |
| Emit (asm/object) | `compiler/emit/{asm,macho_arm64,elf_x86_64,elf_arm64}.hexa` | LIR → assembly text or direct native object serialization |
| Linker | `tool/hexa_ld.hexa` | Native static linker (`hexa_ld`) → ELF64 / Mach-O arm64 binary |
| Diagnostics | `compiler/diag/{catalog,builder,render}.hexa` | Error catalog `HX0001`–`HX8004`, pretty/json/github rendering |
| Self-host bootstrap | `self/bootstrap.hexa`, `self/main.hexa` | Compiler written in `.hexa` that builds itself |
| stdlib | `stdlib/` ([STDLIB.md](STDLIB.md)) | Runtime + domain modules: io/math/thread/posix, collections, crypto, codec, bio, chem, cloud, `flame` (NN training), `forge` (GPU substrate) |
| Atlas CLI | `tool/atlas_cli.hexa` → `bin/hexa-atlas` | `hexa atlas {register,verify,reverify,search,cascade,proof,diff,infer-edges,stats}` |
| hx package manager | `tool/hx.hexa` | Git-like CLI with SSOT attestation: `commit`/`push`/`edit`/`build`/`verify`/`install`/`search` |
| CLI front-ends | `bin/hexa-*` | `hexa-run`, `hexa-fast`, `hexa-commit`, `hexa-push` driver shims |

## Data flow

```
source (.hexa)
     │
     ▼  S0–S8 strict-lint gate (fatal on error → NO binary)
  lex → parse → resolve → bind → types → domain → units → @verify → citation
                                                              │
                                          static_atlas() ─────┘   (embedded.gen.hexa)
     │
     ▼  lowering (target-agnostic)
  AST → HIR → MIR (SSA) → optimize
     │
     ▼  backend (target-specific)
  codegen (LIR) → emit (.s / .o)
     │
     ▼  link
  hexa_ld → ELF64 / Mach-O arm64 static
     │
     ▼
  native binary
```

The atlas is consulted only at the S8 citation gate; once the gate passes, lowering and
codegen run with no atlas dependency, so the produced binary carries zero verification
overhead.

## Verify gate (g5)

`hexa verify` is the single canonical verification surface and the project's g5 gate:

- **S6 equational `@verify`** (in-compiler): canonicalizes LHS/RHS (const-fold, associativity,
  commutativity), checks equality, then does a deterministic sample-eval counter-example search.
  Failures surface as `HX6001` (normalization mismatch) or `HX6002` (witness found).
- **S8 citation** (in-compiler): every formula-bearing function must resolve its cited
  `L[id]` in `static_atlas()`, with kind match and tombstone check, else fatal `HX8004`/`HX1099`.
- **`hexa atlas verify` / `reverify`** (tool-level): recomputes atlas F/P nodes and reports
  `MATCH`/`DRIFT`/`UNVERIFIABLE` against the recorded claim (ε tolerance); a successful verify
  **auto-folds** the verified atom into the atlas (`embedded.gen.hexa`) — verify is ambient,
  not a separate `atlas register` ceremony.

CI runs the same gate (`.github/workflows/lint.yml`); `hx commit`/`hx push` re-run the lint
gate and stamp a `raw-all-attest` trailer so every commit is attested against the SSOT.
