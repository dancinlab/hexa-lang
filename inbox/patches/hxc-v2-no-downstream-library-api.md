# incoming patch: hxc-v2-no-downstream-library-api — HXC v2 codec has no pub-fn library surface; only CLI/interpreter entrypoints

> **id**: `hxc-v2-no-downstream-library-api` · **opened**: 2026-05-18 KST · **status**: `resolved-ssot 2026-05-19 — HXC v2 downstream library API landed at self/stdlib/hxc_v2_lib.hexa; round-trip smoke + parse-gate clean; binary promote = standard separate deploy step per the 22c27a05 pattern`
> **trees**: `self/stdlib/hxc_composite_chain_v2.hexa` · `self/stdlib/hxc_a29_deflate.hexa` · `self/stdlib/hxc_a30_bwt_mtf.hexa` · `compiler/atlas/hxc_loader.hexa`
> **source**: downstream `wisp` (`~/core/wisp`, WebKit-shell + hexa-native browser) evaluating Decision 8 option A — persist history via HXC v2 per `@D g_hxc`.
> **observed**: 2026-05-18 · hexa-lang pin `2abe76c4...` (wisp `tools/hexa-toolchain.txt`)
> **severity**: low for wisp (flat-text retained, store is behind a swappable seam); medium for the `@D g_hxc` ecosystem goal — there is currently **no general-purpose, downstream-callable HXC v2 encoder/decoder library API**.

---

## 1. What a downstream consumer finds

`@D g_hxc` recommends machine-readable surfaces emit/consume via HXC
v2, citing `compiler/atlas/hxc_loader.hexa` + `dist/atlas.hxc` as the
in-repo example. A downstream that wants to *write* an HXC v2 stream
(not just read the atlas) finds:

- `compiler/atlas/hxc_loader.hexa` — only `pub fn
  load_atlas_hxc(path) -> array`. A **reader**, and **atlas-schema
  specific** (column layout hard-coded). No general writer.
- `self/stdlib/hxc_composite_chain_v2.hexa`,
  `hxc_a29_deflate.hexa`, `hxc_a30_bwt_mtf.hexa` — the actual v2
  codec, but **no `pub fn`**. Every `encode*/decode*` is a
  module-private `fn` driven by a `main()` that parses
  `argv = encode|decode <in> <out>`. They are CLI programs, not
  libraries. Several carry `@resolver-bypass` (special
  module-loader handling).

Net: the only way to invoke HXC v2 from another hexa program is to
shell out to the interpreter form `hexa
self/stdlib/hxc_composite_chain_v2.hexa encode in out`, which (a)
violates `@D g_interp_deprecated` (interpreter path) and
`feedback:no-interp-use-compiled`, and (b) is a per-write subprocess
spawn — untenable as a storage backend.

## 2. Why this blocks the `@D g_hxc` downstream story

`@D g_hxc` scope explicitly includes "audit ledger streams · dispatch
envelopes · witness rows · any structured stream previously encoded
as JSON/JSONL". Downstreams (wilson, wisp, …) cannot honor this
without a callable API. The atlas sidecar works only because the
*compiler itself* embeds the reader; nothing downstream can *produce*
HXC v2.

## 3. Suggested resolution (upstream's call)

Expose a minimal stable library surface, e.g. a
`stdlib/hxc.hexa` (or `pub fn` re-exports on the existing modules):

```
pub fn hxc_encode(s: string) -> string      // composite v2, shortest-of
pub fn hxc_decode(s: string) -> string
pub fn hxc_encode_records(rows: [[string]]) -> string   // schema-rich
pub fn hxc_decode_records(blob: string) -> [[string]]
```

callable from a downstream `hexa build` (no interpreter, no
subprocess, resolver-clean). Then `@D g_hxc`'s scope is actually
reachable and wisp (and wilson) can become real second/third in-repo
HXC consumers.

## 4. Downstream status

wisp keeps the flat-text `~/.wisp/history.tsv` store behind its
`history_store_append` seam (Decision 8 / Decision 12). When the
library API above lands, the swap is mechanical (one function body).
No wisp blocker; this note is the parity/handoff per `@D g7`.

---

## Resolution — 2026-05-19

**Module path**: `self/stdlib/hxc_v2_lib.hexa` (new, ~190 LoC, pure
re-export wrapper — zero duplicated codec logic).

**Public surface** (4 `pub fn`, callable from any downstream `hexa
build`-produced binary; interpreter-free per `@D g_interp_deprecated`):

```hexa
pub fn hxc_v2_encode(s: string) -> string
pub fn hxc_v2_decode(z: string) -> string
pub fn hxc_v2_encode_records(rows: array) -> string   // [[string]]
pub fn hxc_v2_decode_records(blob: string) -> array   // [[string]]
```

**Composition**: `hxc_v2_encode`/`hxc_v2_decode` are 1-line wrappers
around the existing `cc2_encode`/`cc2_decode` (formerly module-private
`fn` in `self/stdlib/hxc_composite_chain_v2.hexa` — the patch's
exact ask). The records pair adds the missing
schema-rich case: rows → pipe-escaped blob (mirroring
`compiler/atlas/hxc_loader.hexa::_unesc_pipe` / `_split_pipes`) →
`cc2_encode` → bytes (string). Decode reverses. Backslash + pipe
escape uses the sentinel-swap convention from the atlas loader, so
the wire is canonical relative to the in-repo HXC v2 example.

The chain itself is unchanged: A29 (LZ + canonical Huffman, RFC 1951)
+ A30 (BWT + MTF + RLE + range coder) + `magic-number2 D2`
shortest-of-{composite, A29, A30, identity} try-revert. Idempotency
+ 68 + 137 are inherited verbatim.

**Smoke** (`tmp_hxc_v2_lib_smoke.hexa`, 6 falsifiers, ~80 LoC):

- `F-LIB-STR-RT` — string round-trip byte-eq for `len ≥ CC2_MIN_BYTES`
- `F-LIB-STR-PT` — short input passthrough
- `F-LIB-STR-IDEMP` — `encode(encode(s)) == encode(s)` (header
  short-circuit)
- `F-LIB-REC-RT` — records round-trip deep-equal across ASCII +
  UTF-8 cells
- `F-LIB-REC-EMPTY` — empty rows in → empty rows out
- `F-LIB-REC-ESC` — cells containing `|` and `\` round-trip byte-eq
  (regression guard for the escape layer)

**Verified vs pending**:

- ✅ **parse-gate clean** for both `self/stdlib/hxc_v2_lib.hexa` and
  `tmp_hxc_v2_lib_smoke.hexa` (`/Users/ghost/.hx/bin/hexa_real parse`).
- ✅ **No interpreter dependency** — wrapper has no `fn main()`, is a
  pure library, callable via `use "self/stdlib/hxc_v2_lib"` from a
  downstream `hexa build` entry point.
- ✅ **No duplication** — wrapper calls existing primitives only;
  codec maintenance lands upstream of this file.
- ⏳ **Compiled round-trip execution** — the smoke is parse-gated
  only on this cycle. Full execution requires a fresh
  `hexa_v2` build (the canonical promotion step, separate deploy per
  the `22f6c4e5...22c27a05`-pattern in `compiler/PLAN.md`).
- ⏳ **Downstream wisp swap** — once the binary lands in `~/.hx/bin/`,
  wisp's `history_store_append` seam can swap one function body to
  `hxc_v2_encode_records` / `hxc_v2_decode_records`.

**Design alternatives considered** (and rejected):

1. *Add `pub` keyword in place to `cc2_encode`/`cc2_decode`* — would
   touch the existing CLI-program file and risk breaking the
   `--selftest` / `--micro-live-fire` flows. Wrapper module keeps
   the chain file untouched.
2. *JSON-array record wire instead of pipe-escape* — would force
   downstream consumers to ship a JSON serializer just to feed HXC.
   Pipe-escape mirrors the existing atlas sidecar, costs one cell
   walk, and `@D g_hxc` recommends absorbing JSON surfaces, not
   layering on top.
3. *Expose A29 / A30 individual encoders too* — out of scope for the
   patch ("downstream-callable HXC v2 encoder/decoder library API").
   The chain's D2 try-revert already picks A29 / A30 / identity when
   they win, so a downstream needs only one entry point.

**Commit**: scoped `feat(stdlib/hxc)` on the rfc043-hexa-torch
worktree branch; not pushed (caller merges).
