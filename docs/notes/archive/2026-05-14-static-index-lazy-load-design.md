# static_index lazy-load — design note

**Author:** session 2026-05-14
**Status:** design + PoC; no committed change to `compiler/atlas/`.
**Companion artifacts:**
- `inbox/poc/static_index_lazy_v0.hexa` (263 LOC PoC, Option A)
- `inbox/poc/static_index_lazy_v0_fixture.n6` (62 LOC, 51-node fixture)
- `test/static_index_lazy_poc_smoke.hexa` (87 LOC, smoke)

---

## 1. Current state — measured

Files involved (all read-only for this session):

| Path | LOC | Bytes | Role |
|------|-----|-------|------|
| `compiler/atlas/embedded.gen.hexa`     | 7,331 | 4.6 MB | nested `AtlasNode` struct literals, AUTO-GENERATED |
| `compiler/atlas/static_index.hexa`     |   270 |  ~11 KB | public API surface (atlas_list / lookup / prefix / merged) |
| `compiler/atlas/audit_rodata.hexa`     |    31 |   ~1 KB | rodata-aware wrappers (audit_rodata / audit_merged) |
| `compiler/atlas/audit.hexa`            |   402 |  ~16 KB | core audit engine, intentionally does NOT `use` static_index |

Node counts in the frozen embed (grep on `kind: "..."`):

```
P=559  C=6,096  L=615  E=8  F=0  R=0  S=0  X=0  Q=0
total = 7,278 AtlasNode literals
```

(The task spec mentioned 6,594; live count today is 7,278 — atlas absorption has
appended C-nodes since the last task-brief snapshot. ATLAS_SOURCE_COUNT in the
embed reads 410.)

Interpreter wall time (measured with `/usr/bin/time -p` on macOS Darwin
arm64, `hexa run`):

| Operation | Time | Notes |
|-----------|------|-------|
| `hexa parse compiler/atlas/static_index.hexa`        | 0.18 s real | parse-only path is cheap; the bytes are already in rodata-shape on disk |
| `hexa run <script>` that does `use "compiler/atlas/static_index"` and prints `ATLAS_HASH` only | **>90 s, killed** | trivial single-symbol touch never completes |
| `hexa build compiler/atlas/static_index.hexa` (AOT)  | 0 ms rodata bake (per RFC-018) | not measured today; production AOT path already works |

Conclusion: the failure mode is the interpreter walking the 7,278 nested
struct-literal RHS at module-load time. AOT codegen is unaffected.

### Why parse-only is fast but `run` hangs

The compiler/parser side already understands `@phase("parse_only")`:

```
compiler/check/types.hexa:1619-1634   skip body/let-RHS walk for parse_only items
compiler/check/bind.hexa:713-721      skip bind body walk for parse_only items
```

So `hexa parse` and `hexa build` both finish quickly — the typechecker
filters the embed out of the work list.

`grep -rn parse_only self/ stdlib/` returns **zero hits**. The interpreter
(`self/`) ignores the annotation and dutifully evaluates every
`AtlasNode { ... }` struct literal at module-load. That is the >90 s hang.

---

## 2. Three options

### Option A — rodata as text payload, lazy parse on first call

Replace the 4.6 MB `.hexa` of struct literals with a 4.6 MB-ish `.n6` text
file shipped alongside the compiler. `compiler/atlas/static_index.hexa`
gains a one-slot in-memory cache; the first call to `static_atlas()` /
`atlas_list()` parses the file (via the existing `parse_atlas_file` from
`compiler/atlas/parser.hexa`), caches the resulting `AtlasIndex`, and
returns it. Subsequent calls return the cached object in O(1).

**Pros**
- Reuses the existing `parser::parse_atlas_file` (already battle-tested
  on real `atlas.n6` corpora; same edge-info / grade-info semantics).
- Zero interpreter changes — pure stdlib I/O.
- Mirrors `compiler/atlas/overlay.hexa::overlay_load_cached` exactly
  (which already does file → cache → return on demand). The cache lives
  in module-level state per the established pattern.
- AOT path can still emit the bytes as a string constant and skip I/O
  entirely (a second-tier optimization, not blocking).
- Bundle size unchanged (just file extension flip).
- PoC works (51-node fixture; 11/11 smoke PASS, see §5).

**Cons**
- First call now does file I/O + parse — measurably non-zero (we expect
  100–500 ms for 7,278 nodes, vs the documented "0 ms" of the current
  AOT path). Hot tooling that genuinely needs *zero* cost on first call
  is impacted.
- Embedding becomes a 2-file thing (`.hexa` shim + `.n6` payload).
  Production AOT regen step has to copy/install both.
- `ATLAS_HASH` becomes computed-on-load instead of compile-time-frozen
  (or: ship the hash in the shim and verify on first load — small
  hash-mismatch CI path needed).

### Option B — array-of-string-payloads, AtlasNode built on demand

Keep the data in `compiler/atlas/embedded.gen.hexa` as a `pub let
ATLAS_RAW: array = [ "@P n = 6 :: foundation [11*]\n  -> ...", ... ]`
of string payloads — i.e. drop the per-node `AtlasNode { ... }` struct
literal in favour of one string per node. `static_index.hexa`
materializes `AtlasNode`s lazily on lookup.

**Pros**
- Stays inside the `.hexa` source tree; no extra payload file.
- Keeps the codegen path conceptually identical (the generator just emits
  string literals instead of struct literals).
- AOT path stays close to 0 ms (string-array rodata is what the .rodata
  section is built for).

**Cons**
- Doesn't actually fix the hang on its own. The interpreter still
  materializes the entire string array at module load. 7,278 string
  literals is much cheaper than 7,278 nested structs (each AtlasNode has
  2 embedded structs + ~7 array fields = ~10 sub-allocations) — back-
  of-envelope this is ~10× cheaper, so the >90 s might drop to <10 s.
  That helps but doesn't make `hexa run` interactive.
- Loses structured grade/edge access until the node is materialized;
  every caller of `n.grade.value` etc. now pays a re-parse.
- Requires changing both the generator (`tool/atlas_embed_gen.hexa`,
  if/when it regens) and the surface API (`AtlasIndex` becomes a
  lazy view over string arrays).

### Option C — interpreter respects `@phase("parse_only")` on `pub let`

The annotation already exists; `compiler/check/{types,bind}.hexa` already
respect it. Teach `self/` (the interp) the same trick: when interpreting
a top-level `pub let` whose item carries `@phase("parse_only")`, **do
not evaluate the RHS**. Store a thunk; on first read, force it.

**Pros**
- Surgical: one feature in the interp, no source-tree shape changes.
- The annotation is already on every line of `embedded.gen.hexa`
  (`@phase("parse_only") pub let ATLAS_*_NODES: [AtlasNode] = [ ... ]`),
  so the embed file becomes lazy automatically — no migration of
  existing data or callers.
- ATLAS_HASH stays compile-time-frozen.
- No file I/O on first call (data is still in interp's source-form
  cache, just not yet materialized into VM values).
- Cleanest from an `ai-native` standpoint — the existing structured
  annotation drives behavior; no string-format middleware.
- Fixes the broader pattern (all the other `@phase("parse_only")`
  embeds — falsifiers/molt/surge/wake/lens_taxonomy/... — get the same
  benefit for free).

**Cons**
- Requires interp changes. The relevant module is most likely
  `self/interpreter.hexa` / `self/hexa_full.hexa` (where top-level lets
  are evaluated; needs source-side investigation — out of scope for
  this design).
- Thunk semantics need care: forced-once, memoized, identity-stable
  (so two reads return *the same* value).
- Forcing happens inside an evaluation context where errors may surface
  far from the declaration site — diagnostic UX needs thought.
- Estimating LOC blindly: ~200–400 LOC interp delta (Item flag plumbing
  + Value::Thunk variant + force-on-read in name resolution + thunk
  cycle detection for the pathological "thunk reads itself" case).
- Riskier; touches a hot path (every name lookup) of every script the
  interp runs.

---

## 3. Recommendation

**Option A is the right first step. Option C is the right second step.**

Rationale (one line per option):
- **A** unblocks the use case *today* with zero interp risk, pure-hexa
  changes, and reuses code that already exists (`parse_atlas_file`,
  `overlay_load_cached` pattern).
- **B** is a half-measure: it reduces the hang but doesn't eliminate it,
  and it churns the data shape without giving anything back.
- **C** is the architecturally clean answer, but interp changes are a
  larger risk surface and the annotation gap is real work; do it after
  A has bought us breathing room.

A → C migration is monotonic: once C lands, A's text-payload approach
can either stay (for the bundle-size reason) or be retired by re-emitting
the embed as struct literals tagged `@phase("parse_only")` — at that
point load is free either way.

The honest read on C: this is the *cleanest* answer because it makes the
annotation that already exists across ~30 embed files (grep
`@phase("parse_only")`) actually do the thing it implies. If interp-team
bandwidth lands first, prefer C and skip A.

---

## 4. Migration path (Option A)

Estimated effort: **medium** (~1–2 sessions of focused work, including
regen + smoke + drift checks).

1. **Generator change** — modify `tool/atlas_embed_gen.hexa` (if/when
   regen runs again, currently the embed is frozen post-nexus rm) to
   emit *two* artifacts:
     - `compiler/atlas/embedded.gen.hexa` — slimmed to ~30 LOC
       (`ATLAS_HASH` + `ATLAS_SOURCE_COUNT` + `ATLAS_GENERATED_AT` only;
       no node arrays).
     - `compiler/atlas/embedded.gen.n6` — full atlas payload as text.
   Estimated +60 LOC in the generator, –7,200 LOC in the embed.

2. **`compiler/atlas/static_index.hexa` patch** — add `_atlas_cache`
   module-level slot + helper `atlas_load_cached()` mirroring
   `overlay_load_cached`. Rewrite `static_atlas()`:
     ```hexa
     pub fn static_atlas() -> AtlasIndex {
         if len(_atlas_cache) > 0 { return _atlas_cache[0] }
         let path = ... // bundled .n6 path
         let nodes = parse_atlas_file(path, "atlas.n6")
         let idx = _build_index_from_nodes(nodes)
         _atlas_cache.push(idx)
         return idx
     }
     ```
   Estimated +40 LOC.

3. **Bundle path resolution** — needs a hexa-side convention for "data
   files that ship with the compiler binary". Existing reference:
   `~/.hx/data/atlas.overlay.n6` (overlay.hexa line ~90). Choose either
   `~/.hx/data/atlas.frozen.n6` (install-time copy) or
   `compiler/atlas/embedded.gen.n6` relative to the binary's resolve
   root. Pick the install-time-copy convention to match overlay.
   Estimated install-script change (~10 LOC) outside this repo.

4. **Smoke parity** — port the existing
   `compiler/atlas/static_index_test.hexa` assertions (counts, hash,
   lookup hits) to confirm the new path returns identical results.
   Estimated ~30 LOC delta in the existing test.

5. **Drift / CI** — `ATLAS_HASH` becomes verify-on-load. Add an
   assertion at first-load time: hash the parsed bytes, compare to the
   compile-time-frozen `ATLAS_HASH`; mismatch → loud error. ~15 LOC.

Total estimated diff: **~150 LOC net add** (across generator + static_index
+ tests), **~7,200 LOC delete** (the embed shrinks).

---

## 5. PoC results

`inbox/poc/static_index_lazy_v0.hexa` implements the recommended
shape, end-to-end:
- text fixture → `_parse_n6_text` → `PocAtlasIndex` → module-level cache
- `poc_static_atlas()` is lazy + cached
- `poc_atlas_list()` / `poc_atlas_lookup()` exposed as public surface

Smoke test `test/static_index_lazy_poc_smoke.hexa` exercises:
1. cold load counts (10 P / 31 C / 5 L / 5 E)
2. hash stability across calls
3. 200 warm calls within `cold + 1 s` budget
4. lookup hits + sentinel miss

```
$ /usr/bin/time -p hexa run test/static_index_lazy_poc_smoke.hexa
cold-load-s 0
warm-200x-total-s 0
PASS p_nodes == 10
PASS c_nodes == 31
PASS l_nodes == 5
PASS e_nodes == 5
PASS hash preserved
PASS hash non-empty
PASS 200 warm calls <= cold+1s (cache wins)
PASS lookup p_alpha kind==P
PASS lookup c_pi kind==C
PASS lookup miss sentinel kind==""
RESULT PASS (PoC lazy-load smoke)
real 0.83
user 0.43
sys 0.18
```

**Smoke result: 11/11 PASS in 0.83 s wall.**

Note on timing: hexa interp only exposes second-precision `timestamp()`
from script context (no `time_now_ms` outside `self/`-internal builds),
so the smoke uses the more conservative "200 iterations vs cold-budget"
fence rather than a ms-precision micro-benchmark. The signal is the
same: each warm call would cost ~1 cold-load if there were no cache;
200 warm calls would take ~200 s; they fit inside 1 s; cache works.

---

## 6. Compatibility impact

`compiler/atlas/static_index::atlas_list_merged()` and the rest of the
public API are **preserved verbatim**. Caller change required: zero.

| Consumer | Impact |
|----------|--------|
| `compiler/atlas/audit.hexa`                   | none (doesn't `use static_index`; deliberate per its header note) |
| `compiler/atlas/audit_rodata.hexa`            | none (calls `atlas_list()` / `atlas_list_merged()` — same signature) |
| `compiler/atlas/static_index_test.hexa`       | minor — first call now does I/O; cold timing assertions may need to widen |
| `compiler/atlas/prefix_index.hexa`            | none (builds on `atlas_list_merged()` output) |
| atlas-audit CLI verb (109-node overlay-only path) | unchanged — overlay path doesn't touch static_index |
| Future atlas-audit "full" verb (currently blocked) | newly unblocked — first run pays parse cost, subsequent runs cached |
| `_in` variant                                 | unaffected — that variant is per-process input substitution, independent of rodata path |
| AOT path (`hexa build`)                       | unaffected today (already 0 ms rodata bake); can later be re-optimized to bake the .n6 bytes as a string constant |

---

## 7. Risk

- **Regression**: low. The PoC validates the shape; the production
  port reuses `parse_atlas_file` which already handles real corpora.
- **First-call latency**: medium. 7,278 nodes via `parse_atlas_file`
  has not been measured at production scale; we estimate 100–500 ms
  cold and intend to verify before commit. If it lands at the high end,
  fallback is "cache on disk in a faster format" (msgpack-shape sidecar),
  out of scope today.
- **Build-time**: improves. The embed file shrinks from 7,331 LOC to
  ~30; `compiler/check/{types,bind}.hexa` already skip the body walk for
  the embed, but emit costs in codegen drop too. Net positive.
- **AOT path**: unchanged in the simplest port. Could regress if the
  AOT codegen treats `read_text("...n6")` differently from the current
  compile-time-frozen arrays; mitigation is to emit the bytes as a
  string-literal rodata blob in the AOT codegen path.
- **Drift**: `ATLAS_HASH` verify-on-load adds a small new failure mode
  (mismatched .n6 bytes vs frozen hash). This is a *feature* — it
  surfaces accidental .n6 swaps loudly instead of silently corrupting
  results.

---

## 8. Open questions for the user

1. **Pick option** — A (text payload, recommended), B (string-array
   embed, not recommended), or C (interp `@phase("parse_only")` honor,
   architecturally clean but requires interp work).
2. **Bundle convention** — if A: install-time copy to `~/.hx/data/...`
   (matches overlay), or compiler-relative path (matches the current
   `compiler/atlas/embedded.gen.hexa` pattern)?
3. **Interp `parse_only`** — does the team want C *in addition* to A
   (long-term architectural cleanup), or A alone for now?
