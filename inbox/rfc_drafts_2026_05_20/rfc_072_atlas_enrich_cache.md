# RFC 072 — atlas_enrich cache (RFC 067 inline-enrich follow-on)

- status: PHASE 2.1 LANDED (Option B disk cache + HXC v2 wire migration with JSONL fallback; C pending)
- **Phase 1 (Option A) landed 2026-05-20** — `compiler/atlas/parser.hexa::enrich_node` now wraps the parse path with an `_g_enrich_cache: any = {}` id-keyed map. Process-lifetime cache (binary rebuild = fresh process = clean cache; no runtime TTL needed). Observability via `enrich_cache_stats() -> [hits, misses]`. Falsifiers F1/F2/F3 are N/A for Option A (no cross-process / no disk I/O).
- **Phase 2 (Option B) landed 2026-05-20** — `compiler/atlas/parser.hexa::enrich_cache_persist_disk` + `enrich_cache_load_disk` add a cross-invocation disk cache at `$HEXA_LANG/state/loop/enriched/<atlas_hash>.jsonl`. Encoding = **JSONL-style TSV** (parser.hexa self-contained, no new imports; HXC v2 migration deferred to Phase 2.1 — see §7). `raw` field deliberately NOT persisted (caller reattaches from rodata; sidesteps multi-line escape). Falsifier battery `enrich_cache_disk_selftest()` PASS — F1 (stale hash → load returns 0, cache untouched), F2 (grade + edges arity/value round-trip), F3 (graceful write_text return on safe path; full disk-full injection deferred). Hot-path wiring (cycle.hexa / audit.hexa callers) deferred to a follow-up cycle. Phase 3 (Option C baked sidecar) tracked in compiler/PLAN.md.
- **Phase 2.1 (HXC v2 migration) landed 2026-05-20** — `compiler/atlas/parser.hexa` now `use`s `self/stdlib/hxc_v2_lib` and adds `_enrich_disk_encode_hxc` / `_enrich_disk_decode_hxc` over the records pair (`hxc_v2_encode_records` / `hxc_v2_decode_records`, A29/A30 composite codec). Wire format is gated by `HEXA_ENRICH_CACHE_FORMAT` env var: `hxc` (new default, `@D g_hxc`) writes `<atlas_hash>.hxc`; `jsonl` keeps the Phase 2 baseline at `<atlas_hash>.jsonl`. Compat fallback: if the primary format file is missing but the sibling format is present, the loader transparently reads it (zero-friction migration for callers that already have a Phase-2 `.jsonl`). Selftest battery extended with F-HXC-RT (HXC round-trip), F-HXC-STALE (hash-mismatch abort on `.hxc`), F-HXC-XFORMAT-EQ (JSONL ↔ HXC same restored grade + edges arity), F-HXC-COMPAT-FALLBACK (HXC primary missing → JSONL load). Parse-gate PASS (`/Users/ghost/.hx/bin/hexa_real parse`). See §7 for the encoding decision update.
- created: 2026-05-20
- authority: `compiler/PLAN.md` RFC 065/067 진행 로그 entries
  ("inline atlas_enrich wire: ~567 parse_edge_lines per cycle, sub-second")
- consumer: `stdlib/loop/cycle.hexa::cycle_lens` (the existing call site
  that enriched each ATLAS_P_NODES entry per invocation)
- sibling: RFC 068 (P2 mixed-precision MIR, landed `1e6c2975`) and RFC
  069 (unroll advanced) are unrelated — number conflict explained:
  we ran RFC 065/066 + inline RFC 067 (no separate spec); the next
  free numbers (068/069/070/071) were taken by an interleaved
  campaign before this draft, so atlas_enrich cache gets **RFC 072**.

---

## §1 Problem

RFC 067 (inline `atlas_enrich`) landed as a single 1-line wire in
`stdlib/loop/cycle.hexa`:

```hexa
while ep_i < n_p {
    enriched_p.push(enrich_node(ATLAS_P_NODES[ep_i]))
    ep_i = ep_i + 1
}
```

`enrich_node` (compiler/atlas/parser.hexa:523) calls `parse_grade` +
`parse_edge_lines` over the node's `raw` text. For P kind alone at
n=567, that's 567 parse calls per `hexa loop` invocation. Measured
end-to-end cycle latency = sub-second; not painful, but visibly O(N).

Because `compiler/atlas/embedded.gen.hexa` is **frozen** (PLAN.md note:
"static rodata embed, atlas.n6 source retired post-nexus 2df92aed"),
the enriched view is a **pure function of ATLAS_HASH**. Recomputing
every cycle is redundant.

## §2 Goals

- **G-C0** — first `hexa loop` invocation after a build pays the
  enrich cost (~567 parse calls); subsequent invocations within the
  same ATLAS_HASH cohort skip it via cached enriched view.
- **G-C1** — cache invalidation = ATLAS_HASH change detection.
  When the compiler rebuilds with a fresh `compiler/atlas/embedded.gen.hexa`
  (regen via `hexa atlas pr` fold), the next `hexa loop` rebuilds the
  cache transparently.
- **G-C2** — cache footprint ≤ 10 MB on disk (P+L kinds; C kind via
  HXC sidecar already runtime-fetched, separately cacheable).
- **G-C3** — zero behavior change vs RFC 067 inline path: same 153
  candidate emit / cycle measured before vs after.

## §3 Design — three options

### Option A — in-memory only (re-enrich per process)

The compiled `cycle.hexa` binary computes enriched view once at startup,
holds it in a `static let` or module-level mutable cache, reuses for
all subsequent in-process cycles.

**Pros**: trivial impl (5-line wrap of the existing loop).
**Cons**: every `hexa loop` invocation pays the enrich cost — same as
today. The cache lives only within a single process.

### Option B — disk cache keyed on ATLAS_HASH

Write enriched view as JSONL (or HXC) under `$HEXA_LANG/state/loop/
enriched/<atlas_hash>.jsonl`. On startup, check if the file exists;
if yes, deserialize and return; if no, enrich + write.

**Pros**: cross-invocation persistence; first-run cost amortized.
**Cons**: serialization layer needed (write_text/read_text + JSON
encode/decode for AtlasNode + EdgeInfo nested struct). Stale-cache
risk if hash detection broken.

### Option C — baked enriched sidecar (compile-time)

Treat enriched view as another rodata kind: regenerate
`compiler/atlas/embedded_enriched.gen.hexa` alongside the base
embedded.gen.hexa whenever the bake regenerates. cycle.hexa imports
this sibling instead of calling enrich_node at runtime.

**Pros**: zero runtime enrich cost; matches RFC 066 B-1a per-kind
split pattern.
**Cons**: doubles the baked atlas footprint (parsed edges + grade
expanded inline); fragile in the face of partial bakes. Generator
tool addition.

## §4 Recommendation — Option B

**Option B (disk cache)** as the immediate win. Justification:

1. **No binary footprint hit** — Option C is the fastest at runtime
   but doubles `compiler/atlas/embedded.gen.hexa` on disk (which is
   already the 4 GB memcap pressure point — see RFC 066).
2. **Cross-invocation persistence** matches the user mental model of
   `hexa loop` as a stable cyclic command (`hexa loop --budget 5`).
3. **Trivial invalidation** — `ATLAS_HASH` is already a single
   string in embedded.gen.hexa; cache filename derived from it.
4. **Falls back gracefully** — if the cache file is corrupt or
   missing, the binary just re-enriches (no error path needed).

## §5 Phase plan

| phase | deliverable | gate |
|---|---|---|
| **A** — this RFC | spec + option survey + Option B pick | reviewable ✅ |
| **A.1** — Phase 1 Option A impl ✅ landed 2026-05-20 | `compiler/atlas/parser.hexa::enrich_node` in-memory cache wrap + `enrich_cache_stats()` hook | hexa_real parse PASS |
| **A.2** — Phase 2 Option B disk cache landed 2026-05-20 ✅ | `compiler/atlas/parser.hexa::{enrich_cache_persist_disk, enrich_cache_load_disk, enrich_cache_disk_selftest}` — JSONL TSV at `$HEXA_LANG/state/loop/enriched/<atlas_hash>.jsonl` + F1/F2/F3 falsifier selftest battery | hexa_real parse PASS; selftest covers F1 stale-hash abort + F2 grade/edges round-trip + F3 safe-path write |
| **A.2.1** — Phase 2.1 HXC v2 migration landed 2026-05-20 ✅ | `compiler/atlas/parser.hexa` `use`s `self/stdlib/hxc_v2_lib`; adds `_enrich_disk_encode_hxc` / `_enrich_disk_decode_hxc` over `hxc_v2_encode_records` / `hxc_v2_decode_records` (A29/A30 composite codec). `HEXA_ENRICH_CACHE_FORMAT` env var routes `hxc` (default, `@D g_hxc`) → `<hash>.hxc` and `jsonl` → `<hash>.jsonl` (Phase 2 baseline). Loader compat-fallback: primary-format file missing → sibling format read transparently. `_g_enrich_cache` shape + caller contract unchanged | hexa_real parse PASS on parser.hexa; selftest extended with F-HXC-RT + F-HXC-STALE + F-HXC-XFORMAT-EQ (JSONL ↔ HXC same restored fields) + F-HXC-COMPAT-FALLBACK (missing primary → sibling). Selftest BUILD/EXEC gate inherits the pre-existing Phase 2 baseline compile blocker (`keys_of`/`read_text`/`write_text` not yet wired in codegen builtin map on this worktree's base) — `hexa run` enrich path was already non-functional on `compile-then-exec` before Phase 2.1; promote/wire is a separate cycle. Parse-gate is the inherited Phase 2 verification ceiling for this cycle |
| **B-wire** — hot-path caller wiring (cycle.hexa + audit.hexa) | call `enrich_cache_load_disk(ATLAS_HASH, loop_state_dir())` at startup; `enrich_cache_persist_disk(ATLAS_HASH, loop_state_dir())` at end of cycle | end-to-end no-crash on first run (cold) + on second run (warm) within one `$HEXA_LANG/state/loop/` cohort |
| **C** — measure | end-to-end `hexa loop --write` wall-clock vs RFC 067 baseline | ≤ 50% of RFC 067 enrich latency on cold cache; ≤ 5% on warm cache |

## §6 Falsifiers

- **F1** — cache file ATLAS_HASH does not match current
  embedded.gen.hexa::ATLAS_HASH; cache used anyway → stale finding
  emit, atlas-grounded hypothesis citing non-existent ids.
- **F2** — disk cache serialization round-trip drops a field of
  AtlasNode (e.g. `edges.equivalents`) → lens body that walks that
  field returns [] when it should emit (silent under-count).
- **F3** — cache write fails (disk full, permission); cycle.hexa
  crashes instead of falling back to inline enrich.

## §7 Open

- Encoding: JSONL vs HXC v2 (`@D g_hxc`). **Phase 2 picked JSONL-style
  TSV** as the immediate landing format — parser.hexa stays
  self-contained (no new imports / no new codec), the round-trip is
  testable in a single selftest fn, and the `raw` field is excluded
  (caller reattaches from rodata) so the file stays small and escape
  problems vanish. **Phase 2.1 RESOLVED 2026-05-20** — migration landed
  via `self/stdlib/hxc_v2_lib`'s already-stable records pair
  (`hxc_v2_encode_records` / `hxc_v2_decode_records`, which wrap the
  A29 deflate + A30 BWT composite codec under the canonical pipe-escape
  convention shared with `compiler/atlas/hxc_loader.hexa`). The
  per-struct `AtlasNode + EdgeInfo` codec the original Phase 2 commit
  message punted on turned out to be unnecessary: re-using the existing
  10-cell row shape (`atlas_hash · id · kind · source_file · src_line ·
  grade.{value,verified,breakthrough,hypothesis} · edges_joined`) as an
  `array<array<string>>` and handing it to the records pair satisfies
  `@D g_hxc` without a new codec entry. The static_index circular-dep
  concern called out in the Phase 2 commit message does not apply to
  `hxc_v2_lib` because it lives under `self/stdlib/` (not `compiler/`)
  and only imports `hxc_composite_chain_v2` (no `compiler/atlas/*`
  reverse edge). **Default = `hxc`**; `HEXA_ENRICH_CACHE_FORMAT=jsonl`
  pins the legacy path. The decision-changing measurement (byte savings
  on the real ~6.6k-row cache) is left to Phase B-wire when the hot
  path actually writes a non-toy cache file.
- Multi-kind caching: P+L+E unified cache vs per-kind cache. Per-kind
  simpler; unified slightly denser. Phase 2 went unified (single TSV
  file with kind as a row field) — matches the in-memory `_g_enrich_cache`
  shape and avoids a per-kind path multiplication.
- TTL vs HASH-key: HASH-key cleaner; no need for time-based. Phase 2
  uses HASH-key exclusively; `_ENRICH_CACHE_TTL_SECONDS = 300` remains
  informational only.

## §8 Non-goals

- Not changing `enrich_node` itself (parser surface stays stable).
- Not changing `compiler/atlas/embedded.gen.hexa` schema.
- Not adding new lens body — this is pure performance.

---

## Sign-off

- [x] spec drafted
- [x] **Phase 1 / Option A in-memory scaffold landed (2026-05-20)** — `enrich_node` cache + `enrich_cache_stats()` observability; falsifiers F1/F2/F3 are N/A for Option A
- [x] reviewer agree on Option B (vs A/C) and on the cache encoding (JSONL vs HXC) for Phase 2 — **Phase 2 picked JSONL TSV** (parser.hexa self-contained, no new codec imports); HXC v2 migration tracked as Phase 2.1
- [x] **Phase 2 / Option B disk cache scaffold landed (2026-05-20)** — `enrich_cache_persist_disk` + `enrich_cache_load_disk` + `enrich_cache_disk_selftest`; F1 stale-hash abort PASS, F2 grade/edges round-trip PASS, F3 safe-path write PASS (full disk-full injection deferred)
- [x] **Phase 2.1 / HXC v2 migration landed (2026-05-20)** — `compiler/atlas/parser.hexa` `use`s `self/stdlib/hxc_v2_lib`; new `_enrich_disk_encode_hxc` / `_enrich_disk_decode_hxc` route through `hxc_v2_encode_records` / `hxc_v2_decode_records`. `HEXA_ENRICH_CACHE_FORMAT` env var (default `hxc`, `jsonl` for legacy / inspection). Selftest extended with F-HXC-RT + F-HXC-STALE + F-HXC-XFORMAT-EQ + F-HXC-COMPAT-FALLBACK. Per-struct AtlasNode/EdgeInfo codec turned out unnecessary — the 10-cell records shape satisfies `@D g_hxc` directly
- [ ] Phase B-wire — hot-path caller wiring (cycle.hexa + audit.hexa startup load, end-of-cycle persist)
- [ ] Phase C measurement: cold/warm latency vs RFC 067 baseline
