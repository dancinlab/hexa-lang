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

## Cross-references

- `self/native/gpu_codegen_stub.c` — existing `@gpu` codegen skeleton
- `self/forge/PLAN.md` — GPU substrate roadmap (match → exceed cuBLAS)
- `HEXA-NATIVE-ONLY.md` — the policy this closes the carve-out for
