# incoming patch: hxc-v2-no-downstream-library-api — HXC v2 codec has no pub-fn library surface; only CLI/interpreter entrypoints

> **id**: `hxc-v2-no-downstream-library-api` · **opened**: 2026-05-18 KST · **status**: `reported (downstream deferred HXC adoption, kept flat-text)`
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
