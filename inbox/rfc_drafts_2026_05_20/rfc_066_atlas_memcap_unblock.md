# RFC 066 — Atlas memcap unblock (enable AtlasView materialization)

- status: DRAFT (option survey + recommendation + scaffold pending)
- created: 2026-05-20
- consumer: RFC 065 Phase C-2 (`stdlib/loop/cycle.hexa::cycle_scan`)
  and any future stdlib/* code path needing a populated `AtlasView`
- blocker observed: see `compiler/PLAN.md` 진행 로그 — C-2 attempt at
  `use "compiler/atlas/embedded.gen"` in `stdlib/loop/cycle.hexa`
  triggered `[hexa-runtime] memory cap exceeded: rss=4166MB > cap=4096MB`
  during hexa_v2 transpile. Matches memory
  `project_compiler_selfbuild_blockers` (full flatten ≤31 GB infra cap
  on all hosts).
- authority: AGENTS.tape @D g_atlas_binary_builtin (atlas remains binary
  built-in — this RFC does NOT propose moving atlas to runtime data),
  @D g6 citation-enforced (any partial view must preserve cite semantics).
- sibling: RFC 065 (lens system, blocked at C-2 by this issue).

---

## §1 Problem

The atlas binary built-in (`compiler/atlas/embedded.gen.hexa`) carries
~24 000 `AtlasNode` rodata entries (P/C/L/E/F/R/S/X/Q kinds; ~410
source nodes after wave-1 enrichment, fan-out to ~6594 baked instances
per PLAN.md preamble; physical file size ~10 MB hand-counted as 24k+
struct literals). At compile time, any module that does
`use "compiler/atlas/embedded.gen"` flattens the full rodata block
into the consumer's translation unit, and hexa_v2 transpilation peaks
at >4 GB resident — exceeding the macOS arena's 4 GB cap.

Today only `compiler/atlas/loader.hexa` and `compiler/atlas/static_index.hexa`
consume this import successfully — both are compiled as part of the
`hexa cc --regen` build, which uses the larger transpiler-time arena
(31 GB). Stdlib-side consumers (`hexa loop`, future `hexa atlas pr`
generator, future scanners) hit the user-time arena and fail.

This blocks any stdlib/* module from materializing a populated
`AtlasView` — RFC 065 Phase C-2..C-5 is the immediate consumer.

## §2 Goals

- **G-A0** — stdlib/* modules can construct a populated `AtlasView`
  (or a domain-equivalent partial view) without exceeding the 4 GB
  user-time memcap.
- **G-A1** — preserve `@D g_atlas_binary_builtin`: no atlas data
  moves to runtime-loaded files; atlas remains binary-built-in.
  Any new "summary" or "index" file is itself baked into the
  compiler at build time.
- **G-A2** — preserve `@D g6 citation-enforced`: callers that resolve
  `cite: [atlas_node_id]` to actual node metadata still get the full
  node (not a stub) — the partial view must support lookup-by-id of
  the full record on demand.
- **G-A3** — RFC 065 Phase C-2 unblocks: `stdlib/loop/cycle.hexa`
  can call a `make_atlas_view()` helper that returns a workable
  view, and `falsify_self.cite_unreachable` (currently smoke) can
  be upgraded to actual cite-reachability analysis.

## §3 Non-goals

- **Not a JSON-on-disk atlas.** RFC 028 already moved atlas off
  `.n6` runtime files into `embedded.gen.hexa`; reverting that is
  off-table.
- **Not a partial @cite enforcement.** Strict-lint stage 4 still
  rejects any formula citing an unknown atlas node id — partial
  views must NOT compromise this.
- **Not a full atlas rewrite.** No schema change to `AtlasNode`,
  `GradeInfo`, `EdgeInfo`.

## §4 Three options

### Option A — lazy kind-scoped imports

Split `compiler/atlas/embedded.gen.hexa` into N siblings by kind:
- `compiler/atlas/embedded_p.gen.hexa` (P nodes only, ~400 rows)
- `compiler/atlas/embedded_c.gen.hexa` (C nodes, ~150 rows)
- `compiler/atlas/embedded_l.gen.hexa` (L nodes, ~5000 rows)
- ... one per kind

Consumers import only the kinds they need:
`use "compiler/atlas/embedded_p.gen"` → ATLAS_P_NODES + ATLAS_HASH only.
`AtlasView` is constructed with `[]` for unloaded kinds; views are
deliberately partial. Lens bodies declare which kinds they need
(metadata field on `LensNode`) so the loop runtime imports only the
union.

**Pros**: minimal schema change; the per-kind blobs are themselves
small enough (L is biggest at ~5k entries × ~600 B = ~3 MB per kind);
lazy compilation per consumer.
**Cons**: regen tool must split-emit the bake; every lens declares
its kind footprint; `static_index.hexa`-style holistic consumers must
import all kinds (back to the original size).

### Option B — runtime fetch from on-disk .n6 (without giving up binary built-in)

Bake into the compiler a single `ATLAS_PATH` string constant +
small `atlas_path_resolve()` helper. Bake the FULL atlas at build
time into a side artifact `dist/atlas.hxc` (HXC v2 codec per `@D g_hxc`)
that ships with the install. Stdlib consumers read+parse this file at
runtime via `compiler/atlas/hxc_loader.hexa` (existing) — no
transpile-time flatten, so no memcap hit.

**Pros**: zero transpile-time memcap cost; works for ANY stdlib
consumer including large holistic ones; uses existing HXC layer.
**Cons**: arguably violates `@D g_atlas_binary_builtin` — the data
is no longer literally embedded in the compiler binary, only its
path constant. Counter-argument: the .hxc artifact ships with the
compiler install and is regen'd by `hexa cc`, so the **build product**
is unitary even if the user-visible file is on disk. PLAN.md
2026-05-12 already records `compiler/atlas/hxc_loader.hexa` +
`dist/atlas.hxc` as the canonical Layer 4 sidecar, suggesting this
layering is already legitimized.

### Option C — baked summary view

A new `compiler/atlas/embedded_summary.gen.hexa` carries ONLY the
{id, kind, grade.value, edge-degree, depends_on slugs} per node —
no `raw` field, no full edge buckets. Estimate: ~24 000 entries × ~150 B
= ~3.6 MB. Stdlib consumers get a `summary_view` good enough for
reachability/coverage scans; if they need the FULL `AtlasNode`, they
fall back to Option B (read .hxc on demand for a specific id).

**Pros**: smallest single-file footprint; pure binary-built-in;
covers ~80 % of lens use cases (most lens families don't need the
full `raw` string).
**Cons**: dual maintenance (summary regen-tool); two-tier API
(`view` vs `full_lookup(id)`); strict-lint stage 4 may need a
summary-aware path.

## §5 Recommendation

**Option A (lazy kind-scoped)** for the immediate RFC 065 C-2..C-5
unblock. Justification:

1. **Smallest invariant-stress**: keeps `@D g_atlas_binary_builtin`
   intact and unambiguous (every blob is a literal binary built-in,
   just smaller); avoids Option B's interpretation debate.
2. **Lens metadata fit**: RFC 065 §8 `LensNode` already carries a
   `family` field that aligns well with a `kinds: [string]` field
   addition. Cross-pollinate / counterexample lenses can declare
   `kinds: ["L"]`; falsify-self meta-lenses declare `kinds: []` (no
   atlas dep — they work today, see C-1.b).
3. **Empirical headroom**: per-kind largest blob (L, ~5k entries × ~600 B)
   ≈ 3 MB rodata literal. Flatten 1 such kind in cycle.hexa: ~1.2 GB
   peak (factor ~400× literal-to-AST-peak based on existing
   transpiler-time measurement on the 10 MB full atlas) — well under
   4 GB user-time cap. Multiple kinds union still fits comfortably.

**Fallback B** if A's split tooling proves >2 cycles of work:
the `dist/atlas.hxc` runtime path is already proven (Layer 4 sidecar);
adopting it for cycle.hexa is a 50-line state.hexa-style read_text +
parse helper. The `g_atlas_binary_builtin` ambiguity is a docs
question, not a code question.

**Reject C** — dual maintenance + two-tier API is the worst of both
worlds.

## §6 Phase plan (A as picked)

| phase | deliverable | gate |
|---|---|---|
| **A** — this RFC | spec + recommendation | reviewable, 0 code change |
| **B-1** | `tool/atlas_embed_gen.hexa` learns `--split-by-kind` flag; emits 9 files (P/C/L/E/F/R/S/X/Q) keyed by `ATLAS_<K>_HASH` + per-kind `LOAD_GENERATED_AT`; existing `embedded.gen.hexa` becomes a thin re-export for back-compat | regen produces 9 files, all parse-clean, byte-identical to source-of-truth |
| **B-2** | `compiler/lenses/types.hexa::LensNode` gains `kinds: array` field; `compiler/lenses/embedded.gen.hexa` annotates each of the 32 seeds with its kind footprint | parse-clean; existing dispatch unchanged |
| **B-3** | `stdlib/loop/cycle.hexa::cycle_scan` reads `LENS_NODES[*].kinds` union, imports only those kinds, constructs a partial `AtlasView`. cycle_lens stays the same. | memcap PASS — `hexa run cycle.hexa` does not exceed 4 GB |
| **C-1** | `falsify_self.cite_unreachable` upgraded from smoke (C-1.a) to real cite-reachability analysis using the partial view | emits real candidates from actual atlas inspection |

## §7 Falsifiers

- **F1** — `tool/atlas_embed_gen.hexa --split-by-kind` produces files
  whose union does NOT match the original `embedded.gen.hexa`
  byte-stable on a node-by-node basis (any drift breaks @D g6).
- **F2** — Importing the largest single kind (L) into a stdlib/* test
  module still exceeds 4 GB memcap on hexa_v2 transpile. (If so,
  fallback to Option B is required, not Option A — repair the RFC.)
- **F3** — Any consumer of the partial view emits a Candidate
  citing an atlas_node_id that lies in an UN-imported kind. (Strict
  lint must catch this; if not, F3 fires and partial-view discipline
  needs a typecheck-time enforcement, not just runtime hope.)
- **F4** — `static_index.hexa`-style holistic consumers regress —
  if they cannot import all 9 kinds in their existing
  `hexa cc --regen` build path, F4 fires and the back-compat
  re-export must remain available unchanged.

## §8 Open questions (not gating)

- Should the per-kind file naming be `embedded_p.gen.hexa` (flat) or
  `embedded/p.gen.hexa` (dir)? Convention favors flat (sibling to
  `embedded.gen.hexa` itself).
- How does `hexa atlas pr` interact with the split? A new node likely
  appends to one kind file; `hexa atlas pr` needs to detect kind and
  route. (Mostly mechanical; not gating this RFC.)
- HXC v2 (`@D g_hxc`) could compress the per-kind blobs further; not
  necessary for memcap relief but worth a follow-up RFC.

---

## Sign-off checklist (Phase A landing)

- [x] decision implied by recommendation; no separate design.md
      (option survey IS the decision ledger)
- [x] `compiler/PLAN.md` `## 진행 로그` entry will land in companion
      commit
- [ ] reviewer agree on Option A choice (vs B fallback timing) and
      on the kind-split granularity
- [ ] approved → file moves to `inbox/rfc_landed/` and B-1 starts
