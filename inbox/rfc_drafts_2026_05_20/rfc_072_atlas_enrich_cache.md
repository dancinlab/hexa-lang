# RFC 072 — atlas_enrich cache (RFC 067 inline-enrich follow-on)

- status: PHASE 1 LANDED (Option A in-memory scaffold; B/C pending)
- **Phase 1 (Option A) landed 2026-05-20** — `compiler/atlas/parser.hexa::enrich_node` now wraps the parse path with an `_g_enrich_cache: any = {}` id-keyed map. Process-lifetime cache (binary rebuild = fresh process = clean cache; no runtime TTL needed). Observability via `enrich_cache_stats() -> [hits, misses]`. Falsifiers F1/F2/F3 are N/A for Option A (no cross-process / no disk I/O). Phase 2 (Option B disk) + Phase 3 (Option C baked sidecar) tracked in compiler/PLAN.md.
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
| **B** — impl Option B (disk) | `stdlib/loop/state.hexa::enriched_view_*` API + cycle.hexa wire | round-trip test: write+read on synthetic enriched view |
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

- Encoding: JSONL vs HXC v2 (`@D g_hxc`). HXC is canonical for
  machine-readable surfaces — preferred unless decode cost dominates.
- Multi-kind caching: P+L+E unified cache vs per-kind cache. Per-kind
  simpler; unified slightly denser.
- TTL vs HASH-key: HASH-key cleaner; no need for time-based.

## §8 Non-goals

- Not changing `enrich_node` itself (parser surface stays stable).
- Not changing `compiler/atlas/embedded.gen.hexa` schema.
- Not adding new lens body — this is pure performance.

---

## Sign-off

- [x] spec drafted
- [x] **Phase 1 / Option A in-memory scaffold landed (2026-05-20)** — `enrich_node` cache + `enrich_cache_stats()` observability; falsifiers F1/F2/F3 are N/A for Option A
- [ ] reviewer agree on Option B (vs A/C) and on the cache encoding (JSONL vs HXC) for Phase 2
- [ ] Phase B impl (disk cache; Option B)
- [ ] Phase C measurement: cold/warm latency vs RFC 067 baseline

## §9 Measurement environment note (2026-05-20 ubu-2 fire-decision)

A cross-platform measurement attempt on ubu-2 (x86_64 Linux, RTX 5070
sm_120) revealed an infra constraint:

```
build attempt: `hexa build stdlib/loop/cycle.hexa` on ubu-2
result       : sh: self/native/hexa_v2: Exec format error
diagnosis    : ubu-2's self/native/hexa_v2 (and all .bak.*) are Mac arm64
                Mach-O binaries — ubu-2 is a sync receiver, not a native
                Linux compile target (memory ubu_arch_transpiler_constraint:
                "ubu(x86_64) S4 arm64 byte-diff 산출 불가(Mac-intrinsic)")
implication  : RFC 072 Phase C cold/warm latency measurement is
                **macOS-only** (Mac arm64 host) for this spec. A Linux-
                native measurement requires a separate RFC to wire
                `hexa_v2_linux` (x86_64 ELF transpiler) — non-trivial
                because the transpiler emits Mac-intrinsic patterns.

fire-decision: A. fire (genuinely uncertain on ubu-2 portability)
               outcome: SETTLED by single measurement — cross-platform
               build path is blocked at the transpiler-binary layer.
               do NOT re-fire on ubu-2 (analytical: same Exec format
               error guaranteed until hexa_v2_linux exists).
```

Phase C measurement scope therefore narrows to: cold/warm latency on
**Mac arm64 only**, vs the same Mac arm64 RFC 067 baseline. Cross-
platform validation deferred to a separate Linux-toolchain RFC.
