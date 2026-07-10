# axis-③ L1 — field-key interning + struct-lit map right-sizing (design, round-2)

> Basis: origin/main **590aa1129** · census SSOT `state/hexa-own/axis3-frontend-arena-census-r1.md` (#4812).
> Scope: **runtime-substrate only** (`self/runtime_core_emit.hexa` + 2 mirror shards). Zero compiler/codegen edits.
> Claim to hold: emitted `self.o` stays byte-identical (sha `165ffa6f7fb4…`, 6,869,920 B).

## 0. TL;DR

Both L1 mechanisms live in the **runtime generator lane** — the emitted `runtime_core.c`
allocator, not either backend's lowering. One census correction matters for soundness:
**map keys are NOT "free-never"** — there are exactly two key-free sites (×2 copies each,
main emitter + SELFEMIT mirror shard). Mechanism A therefore needs an ownership
discriminator; the exact, layout-neutral one is a **pointer-identity probe against the
already-existing global intern table** (`hexa_intern`, which `hexa_str` already uses on
every short string — Optimization #11). Mechanism B is a 3-line cap-floor drop; the grow
path already exists and never reassigns `struct_id`. A+B ship as **one round, two commits,
one PR**, gated on byteeq 3-target + self.o sha pin + summer re-census (target ≥ −4 GB).

## 1. Ground truth (all cites at 590aa1129)

### 1.1 The allocation shape being attacked
Native own-emit `struct_lit` (the lane the self-emit compiler binary itself runs on):
`compiler/codegen/x86_64_linux.hexa:3284-3313` — `call hexa_map_new` (:3287) then one
`call hexa_map_set` per field (:3306), key passed as a **`.rodata` label address** via
`_x86_emit_cstr_key` (:3299 — "lea the ADDRESS, not the content"). No `__type__` insert on
this lane (":3286 comment — map-backed v1 ignores type_str"). `enum_ctor` (:3317+) has the
identical map_new+map_set shape. arm64 mirror: `compiler/codegen/arm64_darwin.hexa:2319+`.
**So the caller already hands the runtime a process-lifetime-stable constant pointer — and
the runtime strdup's it anyway.** That strdup is the A target.

Per-instance cost today (e = field count; glibc chunk arithmetic):
`hexa_map_new` = HexaMap header only, **no table** (`runtime_core_emit.hexa:3836-3841`);
first `hexa_map_set` lazily allocates `hmap_alloc(HMAP_INIT_CAP=16)` (:3974) →
table hdr ~64 B + slots 16×16 B + vals 16×16 B + order_keys 16×8 B + order_vals 16×16 B
(`hmap_alloc_ex`, :3627-3663; order floor 8 at :3629) ≈ **992 B fixed + e×32 B key strdups**
≈ the census's ~1.1 KB/instance floor. Census maps these to generated `runtime_core.c`
lines `:1175` (INIT_CAP), `:3326-3352` (hmap_alloc_ex), `:3619/:3689` (key strdups);
authoritative editable source = the emitter lines cited here.

### 1.2 Key lifecycle census (the soundness inventory)
Key-CREATE sites (strdup/dup of a field-name key):
| # | site | emitter line | lane |
|---|---|---|---|
| C1 | `hexa_map_set_impl` INSERT `t->slots[idx].key = hxlcl_strdup(key)` | `self/runtime_core_emit.hexa:4011` | **all lanes** — the native map_core port covers ONLY the in-place UPDATE branch; INSERT stays C (`stdlib/runtime/map_core.hexa:144-152`) |
| C2 | `hexa_struct_pack_map` field key, non-arena arm | `:3925` | gen2 C-backend structs (`self/codegen.hexa:11081-11109` emits `_k`/`_v` static-literal arrays; pack_map contract at :3848 already says "strings must be string literals (stable)") |
| C3 | `hexa_struct_pack_map` `"__type__"` key, non-arena arm | `:3902` | gen2 lane |
| C4 | pack_map arena arms (arena kdup) | `:3886-3888`, `:3919-3922` | HEXA_VAL_ARENA opt-in only — **inert on the self-emit lane** (census: `arena_live=0` every row) |
| C5 | `hmap_heapify` copy `hxlcl_strdup(k)` | `:5650` | arena-heapify only — inert on self-emit lane |

Key-FREE sites (census's "free-never" is false for keys; strings-never-freed is a separate,
true claim at :860):
| # | site | line |
|---|---|---|
| F1 | `hexa_map_remove_impl` → `free(t->slots[si].key)` | `self/runtime_core_emit.hexa:4722` |
| F2 | `hexa_val_free_tree` TAG_MAP arm → `free(t->slots[i].key)` | `:6096` |
| F1' | mirror shard (HEXA_RT_CORE_COLLECTION_MUTATE_NATIVE lane) | `self/native/rtcore_collection-mutate_emit.hexa:216` |
| F2' | mirror shard (HEXA_RT_CORE_RUNTIME_MISC_NATIVE lane) | `self/native/rtcore_runtime-misc_emit.hexa:296` |

That is the exhaustive list (`grep 'free(' × '.key'` over the emitter + shards). Both are
**cold paths** (user `map.remove`; `free_tree` = arena-heapify temp release :6268 +
gated STREAM_RECLAIM lane).

### 1.3 The interning mechanism ALREADY EXISTS
`hexa_intern` — `self/runtime_core_emit.hexa:942-998`: global open-addressing table
(`:796`), `INTERN_INIT_CAP=1024`/`INTERN_MAX_LEN=64`/load 75 (`:743-746`), lazy init,
canonical copies **header-allocated via `hexa_strbuf_dup_n`** (:995 → HX_STRLEN-safe),
returns NULL for strings ≥64 B, and — decisive properties:
- bucket **strings are never freed and never move** (grow reallocs the bucket *array*
  only, `:805-826`); contract at :932: "callers must NOT free".
- `hexa_str` already routes **every** short string through it (Optimization #11,
  `:2306-2318`) → map-key interning adds **no new thread-safety or lifetime class**;
  whatever the concurrency story of the intern table is, it is pre-existing and shared
  with all string creation.
- Field names are identifiers ≪ 64 B → always internable.

## 2. Mechanism A — field-key interning (exact change)

### A1. Create sites: intern-or-dup
At **C1** (`:4011`), replace
```c
t->slots[idx].key  = hxlcl_strdup(key);
```
with
```c
const char* __ik = hexa_intern(key);                 /* NULL when len >= 64 */
t->slots[idx].key  = __ik ? (char*)__ik : hxlcl_strdup(key);
```
Same two-line swap at **C2** (`:3925`) and **C3** (`:3902` — `"__type__"` interns once
process-wide). C4/C5 (arena lanes) stay unchanged this round: they are inert on the
self-emit lane, and their existing owned-dup behavior remains sound under A2's
discriminator (an owned dup is pointer-distinct from any intern bucket → still freed).
Optional follow-up, not L1: intern C5 to share across heapify copies.

The key pointer is stored once and shared into `order_keys` (":4046 — shared pointer,
not a copy") — single ownership decision point per entry; remove/compact logic untouched.

### A2. Free sites: exact ownership discriminator (the soundness crux)
Maps cannot assume owned keys anymore. **No slot-layout change** (a tag field would widen
`HexaMapSlot` 16→24 B = +128 B/table at cap 16, eating the win). Instead add one exported
helper emitted next to `hexa_intern`:
```c
/* 1 iff p is a canonical intern-table pointer. Exact: buckets hold unique
 * strings, are never freed, never move (grow reallocs the array, not the
 * strings). Probe ends at the first empty bucket, same as hexa_intern. */
int hexa_intern_owns(const char* p) {
    if (!p || !__hexa_intern.buckets) return 0;
    size_t n = hxlcl_strlen(p);
    if (n >= INTERN_MAX_LEN) return 0;               /* never interned */
    uint32_t h = hexa_fnv1a(p, n);
    uint32_t mask = (uint32_t)(__hexa_intern.cap - 1);
    uint32_t idx = h & mask;
    while (__hexa_intern.buckets[idx]) {
        if (__hexa_intern.buckets[idx] == p) return 1;   /* pointer identity */
        idx = (idx + 1) & mask;
    }
    return 0;
}
```
Must be **extern** (not static like `hexa_intern` at :942) so the mirror shards can call
it across .o boundaries inside runtime.a. Then at F1/F2/F1'/F2' replace `free(k)` with
`if (!hexa_intern_owns(k)) free(k);` — all four sites, main emitter + shards in lockstep
(the shards fully redefine `hexa_map_remove_impl` / `hexa_val_free_tree` for the
RT-NATIVE flag lanes; editing only the main emitter would leave a double-lifecycle bug
on those lanes).

Why exact: an owned `hxlcl_strdup`/`hmap_heapify` copy is a fresh allocation, never
pointer-equal to a bucket; an interned key is by construction the bucket pointer itself
and its string sits on its own probe chain → the pointer-equal hit is found before the
first empty slot. Rodata pointers never enter slots (the runtime always interns-or-dups
at C1-C3), so the probe never has to classify foreign memory beyond "not a bucket".
Cost: strlen+FNV+short probe on **cold** paths only.

Remove→reinsert cycle: remove leaves the interned bucket alive (skip free, NULL the
slot), reinsert re-interns to the same pointer. Idempotent, no double-free, ASAN-clean.

### A3. Accepted semantics note (report, don't hide)
Dynamic dict keys (`m[k]=v` via `hexa_to_cstring`, emitter :4838-4841) <64 B now also
intern and are retained for process lifetime even after `remove` — the exact retention
policy `hexa_str` already applies to every short string VALUE since Optimization #11.
Scoping interning to struct-lit-only would require a new runtime entry point called from
codegen → changes emitted bytes → not L1 (that door belongs to L2/pack_map). Accept
uniform policy; the drain case (unbounded unique short keys + remove) is bounded by the
same exposure hexa_str already has.

## 3. Mechanism B — struct-lit map-table right-sizing (exact change)

`HMAP_INIT_CAP=16` is defined at `self/runtime_core_emit.hexa:1286` and consumed at
exactly two sites (no shard uses it):
1. **`hexa_map_set_impl` lazy first-insert** `hmap_alloc(HMAP_INIT_CAP)` (`:3974`) —
   **this is the native struct_lit lane**; field count is not in the ABI here, so
   right-sizing = drop the floor and let the existing doubling grow
   (`hmap_grow` :3669-3706 — frees old non-arena buffers :3689-3690, does **not**
   allocate a new table or reassign `struct_id`) absorb larger maps.
2. **`hexa_struct_pack_map` pre-size floor** `int cap = HMAP_INIT_CAP; while (cap < need) cap <<= 1;`
   (`:3856-3859`) — the need-formula already right-sizes UP; only the floor is wrong.

Change (policy = **next-pow2 ≥ need, floor 4**):
- `:1286` → `#define HMAP_INIT_CAP 4`  (single knob; both consumers inherit)
- `:3629` order-array floor `order_init = ht_cap < 8 ? 8 : ht_cap` → `ht_cap < 4 ? 4 : ht_cap`
  (order arrays already double via realloc at :4025-4041).

Resulting fixed floor per struct instance (native lane, load-max 75 → grow when
`len*100/cap ≥ 75` i.e. at len 3 for cap 4, len 6 for cap 8):
| entries e | table caps hit | slots+vals+order | today (cap16) | Δ |
|---|---|---|---|---|
| ≤3 (LOperand/PReg/Span…) | 4 | 64+64+32+64 = 224 B | 896 B | **−672 B** |
| 4-6 (Stmt/HExpr/LInstr) | 4→8 (1 transient grow) | 128+128+64+128 = 448 B | 896 B | **−448 B** |
| 7-12 (rare wide nodes) | 4→8→16 (2 grows) | same 896 B + transient churn | 896 B | ~0 |
Plus A removes e×32 B key chunks and e mallocs per instance. Combined ≈ **−45…−65 % of
the ~1.1 KB fixed floor** on 2-6-field nodes — consistent with the census's −4…−7 GB
(20-35 % of 19.75 GB) band, since LIR+HIR carriers (12.7 GB) are almost entirely this floor
plus boxed payloads.

Rejected variant: `hexa_map_new_sized(n)` called from `struct_lit` — needs a codegen call-site
change → emitted bytes change → that is L2's flag-gated territory (and `hexa_struct_pack_map`
already IS the bulk sized ABI if L2 wants it).

Consumer safety: `hmap_find`/insert/remove/grow all mask by `ht_cap` (power-of-2 preserved,
4 ≥ 1); nothing assumes cap ≥ 16 (verified over the emitter's slot loops; re-verify at
review). Registries/env caches built through map_set just take 2 extra early grows
(4→8→16), amortized doubling thereafter — churn bounded, measured at the gate.

## 4. Byteeq-neutrality argument (and why the gate still runs)

`self.o` is a pure function of (source, compiler code): L1 touches neither
`compiler/codegen/*` nor any lowering — only how the **compiler's own process** stores its
map-backed structs. Output could only shift if compiler control flow observes allocation
details. Checked observables:
- **Lookup**: content-based — FNV + strcmp (`hmap_find`), unchanged. Pointer-equality
  fast paths (hexa_str interning) only gain hits; their fallback is strcmp → same verdict.
- **Iteration**: `keys()/values()/for-in/to_string/heapify` all walk the insertion-order
  arrays (`:4504`, `:4536`, `:4548`, `:4579`, `:4616`; `hmap_heapify` explicitly
  "Re-insert by walking the order arrays" `:5633-5658`). **Slot order — the thing B
  reshuffles — is never enumerated into a program-visible result** (slot walks exist only
  in remove's order_idx fixup and free paths).
- **`struct_id` sequence**: assigned solely in `hmap_alloc_ex` (`:3656-3660`); `hmap_grow`
  reallocs in place with no new id; allocation-call sequence unchanged → identical ids.
- **Key immutability**: slot keys are read-only strcmp handles (":3905 — slot.key is a raw
  char* used only for strcmp"); language strings are immutable; `keys()` materializes via
  `hexa_str(order_keys[i])` which re-interns to the same canonical pointer.
- **runtime.a delta**: runtime bytes change (that's the point) → every linked binary
  changes **identically**; gen3≡gen4 fixpoint compares generations linking the *same*
  runtime.a → holds by construction. `self.o` (relocatable codegen output, runtime not
  included) must stay sha-identical.
So: **byteeq-neutral by construction, no default-OFF flag needed** — but the claim is
verified, not trusted: gate below pins the self.o sha and runs byteeq 3-target. If either
trips, some hidden slot-order/pointer dependence exists → stop, bisect commit-B vs
commit-A, re-land the offender behind a default-OFF `-DHEXA_MAP_KEY_INTERN_OFF` /
`HMAP_INIT_CAP` build knob per release-integrity rule.

## 5. Round plan + backend split

**One round, one PR, two commits** (independent sites; bisectable):
1. **Commit 1 = B** (3 lines: `:1286`, `:3629`; zero soundness surface) — land-ready first.
2. **Commit 2 = A** (C1/C2/C3 intern-or-dup + `hexa_intern_owns` + F1/F2/F1'/F2' guards).
Census predicts A as the larger win; my chunk arithmetic (§3) says B's table slack
(−448…−672 B) ≥ A's key chunks (−96…−192 B) per instance. Don't argue — **measure both**:
the re-census runs once after commit-1 and once after commit-2 (two ~3-min summer runs).

**Backend split (R6 lesson applied)**: the self-emit compiler's memory is fixed by
**runtime.a**, not by either backend's `.hexa` lowering — its struct-lit machine code
(emitted by `compiler/codegen/x86_64_linux.hexa` when the binary was built) just calls
`hexa_map_new`/`hexa_map_set`; the allocation strategy lives behind those symbols.
Files touched, exhaustively:
- `self/runtime_core_emit.hexa` (generator of `runtime_core.c` — C1-C3, F1, F2, B knobs,
  `hexa_intern_owns`)
- `self/native/rtcore_collection-mutate_emit.hexa:216` (F1' mirror)
- `self/native/rtcore_runtime-misc_emit.hexa:296` (F2' mirror)
- **NOT** `compiler/codegen/*` (would change aprime OUTPUT = L2), **NOT**
  `self/codegen.hexa` (gen2 templates already call pack_map; its body lives in the
  runtime emitter). Regen + `runtime.a` via canonical `tool/stage_resolve_runtime_a`.
Bonus scope: the win applies to hexat-built AND aprime-built binaries and every user
program, not just self-emit.

## 6. Verify gate

1. **Regen + build**: regen runtime_core.c + shards, faithful runtime.a rebuild
   (`stage_resolve_runtime_a`, beware `ar x` stale members), BOTH backends
   (release_build AND aprime_cc — aprime-only = FALSE-green).
2. **Output pin**: re-run the census driver on summer (idle 30 G) — `self.o` must be
   **6,869,920 B, sha256 `165ffa6f…` unchanged**.
3. **byteeq 3-target GREEN + shipping smoke** (PR CI, github-hosted) before merge;
   `selfhost-gates-summary` required.
4. **Memory re-census** (methodology = census r1; `HEXA_ALLOC_STATS` atexit does NOT fire
   on the raw `exit_group` lane — use per-phase `-v rss=` ΔRSS + `/usr/bin/time` VmHWM):
   PASS = peak **≤ 15.7 GB** (−4 GB floor of the band) with per-phase deltas shrinking in
   LIR/HIR proportionally; record per-mechanism split (post-commit-1 vs post-commit-2).
5. **Soundness smoke** (new, small): struct maps + dict maps with short and ≥64 B keys,
   remove-all → reinsert → free_tree, under `clang -fsanitize=address` on the standalone
   C-runtime smoke link (dev-only) — no leak-of-owned, no free-of-interned.
6. **Perf guard**: census wall (190 s baseline) and a stdlib selftest wall must not
   regress > ~2 % (grow churn + intern probes).

## 7. Kill criteria (measured, per mechanism)

- **A killed** iff ownership can't be discriminated soundly & cheaply: a key-free site
  exists outside F1/F2/F1'/F2' (ASAN or grep finds one), or a workload shows hot
  `map.remove` where `hexa_intern_owns` measurably regresses (>2 % wall) — because the
  only exact alternative (slot ownership bit) widens HexaMapSlot 16→24 B = +128 B per
  cap-16 table, i.e. the representation change costs what interning saves.
- **B killed** iff any consumer proves to assume `ht_cap ≥ 16` (crash/infinite probe) or
  early-grow churn regresses compile wall >2 % → fallback floor 8 (halves the win) before
  killing outright.
- **Either killed globally** iff byteeq 3-target or the self.o sha pin trips after the
  bisect in §4 — then the offender is NOT output-neutral and must wait for an L2-style
  default-OFF flag round.

## 8. What this round does NOT do
No codegen `struct_lit` change, no `hexa_map_new_sized` ABI, no flat-struct lowering
(L2, `HEXA_STRUCT_FLAT`, attacks the 86.7 s codegen wall + 4× carrier shrink), no process
split (L3, deferred), no arena-lane rework (C4/C5), no check-registry reclaim (M1,
unrecoverable on the malloc-only lane).
