# gpu — design ledger

> Decision ledger for the hexa-native GPU kernel effort. Append
> `### Decision N` blocks as choices are made.

## Context

forge runs hand-written `self/native/hxcuda_*.cu` (CUDA) +
`hxmetal_kernels.metal` (Metal) + `lora_cuda.cu`. The goal: author
kernels in hexa and let the compiler emit per-backend device code.
`self/native/gpu_codegen_stub.c` is the existing `@gpu` codegen
skeleton this builds on.

## Decisions

### Decision 1 — B: `.hexa` + `@gpu` annotation (kernel source format)

How is a GPU kernel written, and where does it live?

**Candidate A — `.hxk` dedicated extension**

Kernels live in standalone `.hxk` files, in an `hx*` namespace
alongside `.hexa` and `.hxc`.

- `+` kernel vs host code split by file — explicit, greppable at a
  directory glance
- `+` kernel-only lint rules (no recursion, no heap allocation,
  bounded loops) attach cleanly to the file type
- `+` 1:1 mental map with the `.cu` files being replaced — easy
  migration story
- `−` new file type — lexer / parser / build-graph / editor syntax
  highlighting / LSP language ID each need a separate path
- `−` host and device code cannot share a file → more boilerplate at
  the call boundary

**Candidate B — `.hexa` + `@gpu` annotation**

Kernels are `@gpu fn ...` blocks inside ordinary `.hexa` files;
`self/native/gpu_codegen_stub.c` already presupposes `@gpu`.

- `+` zero new file types — lexer / parser / type checker / atlas
  citation enforcement all reused unchanged
- `+` host + device code in one file, one language
- `+` mirrors CUDA's own model — `.cu` is C++ with
  `__global__` / `__device__` annotations, not a separate language;
  the extension only flips a compiler mode
- `+` incremental adoption — annotate one `fn` at a time
- `−` kernel boundary is an annotation, not a file → less visible
  when scanning a directory
- `−` kernel-only constraints enforced by a compiler pass rather than
  by file type

**picked:** B — `.hexa` + `@gpu` annotation (2026-05-19)

**rationale:**
- toolchain cost is zero — `@gpu` rides the existing attribute
  machinery (`attr_ecosystem/`, `attr_format/`); no new lexer / parser
  path, and no new LSP language ID / `ftdetect` / tree-sitter file
  type to register
- matches the modern GPU-kernel norm — CUDA (`__global__`
  annotation), Triton (`@triton.jit`), JAX Pallas all use
  host-language + annotation, not a separate kernel language
- consistent with code already in tree — `self/native/gpu_codegen_stub.c`
  is already registered as the `@gpu` codegen skeleton; Candidate A
  would have stranded it on a wrong assumption
- host + device code share one file and one scope — struct / const /
  type definitions need no duplication or import boilerplate
- Candidate A's only real edge (a `.hxk` brand / hard file split) is a
  marketing motive, not an engineering one, and is fully served by
  `grep @gpu` + an annotation-keyed compiler pass

Candidate A is rejected; kept above as the audit trail.

### Decision 2 — `gpu/` (directory name)

This effort's home directory under `hexa-lang/`.

- candidate `hxk` — `hx*` namespace (`.hexa` / `.hxc` / `hxcuda_`),
  but a codename needing a gloss, and — with Decision 1 picking
  annotations — it reads as if a `.hxk` extension exists. It does not.
- candidate `gpu` — self-describing; matches hexa-lang's short
  single-word top-level dir style (`comb` / `gate` / `spec`).

**picked:** `gpu` (2026-05-19)

**rationale:**
- self-describing — a reader sees `gpu/` and knows; no codename gloss
- `hxk` would actively mislead toward a `.hxk` extension that
  Decision 1 rejected
- matches hexa-lang's existing short-word top-level dir convention
  (`comb`, `gate`, `spec`, `self`, `atlas`)
- the one concern — overlap with GPU runtime code under `self/` — is
  resolved by scope: `gpu/` is design / spec only; runtime stays in
  `self/native/`, `self/cuda/`, `self/forge/` (stated in README)

### Decision 3 — `gpu/SPEC.md` = the `@gpu` subset SSOT; RFC 055 §6 references it

`gpu/` (this design directory) and **RFC 055** (`hexa-src → NVPTX codegen
backend`) were discovered to be two records of the *same* hexa-native GPU
kernel effort — both pick the `@gpu` annotation model, both build on
`gpu_codegen_stub.c`. They had diverged: RFC 055 §6 re-specified the
`@gpu` surface (attributes, intrinsics, launch ABI) independently of
`gpu/`, and `HANDOFF.md` was written unaware of RFC 055. Writing
`gpu/SPEC.md` fresh per the HANDOFF step-1 brief would have produced a
*third* diverging spec.

Three reconciliations were considered: (A) RFC 055 = implementation SSOT,
`gpu/SPEC.md` a thin pointer to RFC 055 §6; (B) `gpu/SPEC.md` = the
standalone full spec, RFC 055 §6 reduced to a reference; (C) retire
`gpu/`, fold everything into RFC 055.

**picked:** B — `gpu/SPEC.md` is the standalone full `@gpu` subset spec
(2026-05-19)

**rationale:**
- a language-surface spec and a codegen-target implementation are
  genuinely different artifacts with different change cadences — the
  `@gpu` subset (what a kernel author may write) is stable; the NVPTX
  lowering (RFC 055) churns phase by phase. One SSOT each, cleanly split.
- `gpu/` is already the *design* home (Decisions 1–2 live here); the
  surface spec belongs with the design ledger, not buried in a
  codegen-implementation RFC. A reader asking "what can I write in a
  `@gpu fn`?" looks in `gpu/`, not in an `inbox/rfc_drafts/` file.
- RFC 055 explicitly scopes itself **compiler-domain, codegen only**
  ("forge and flame are consumers, not the subject"); a user-facing
  language-surface spec sitting inside it is a scope smell. Option B
  removes it — RFC 055 keeps §6.1–6.3 (IR / codegen target) and points
  §6.4–6.5 at `gpu/SPEC.md`.
- option A inverts the natural ownership (design dir pointing into an RFC
  draft); option C destroys the design-ledger audit trail and overloads a
  single RFC file with surface-spec + codegen + phasing.

Consequence: `gpu/SPEC.md` written as the SSOT; RFC 055 §6.4/§6.5 reduced
to a pointer; `gpu_codegen_stub.c`'s intrinsic table + allowlist are the
in-tree reference the spec is kept consistent with.

## Cross-references

- `gpu/SPEC.md` — the `@gpu` subset SSOT (Decision 3)
- `self/native/gpu_codegen_stub.c` — existing `@gpu` codegen skeleton
- `inbox/rfc_drafts_2026_05_12/rfc_055_hexa_nvptx_codegen_backend.md` —
  the NVPTX codegen implementation that consumes `gpu/SPEC.md`
- `self/forge/PLAN.md` — GPU substrate roadmap (match → exceed cuBLAS)
- `HEXA-NATIVE-ONLY.md` — the policy this closes the carve-out for
