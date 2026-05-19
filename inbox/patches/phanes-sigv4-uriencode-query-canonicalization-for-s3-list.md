# incoming patch: phanes-sigv4-uriencode-query-canonicalization-for-s3-list — `stdlib/aws/sigv4.hexa` punted the SigV4 `UriEncode()` + query-parameter canonicalization; S3/R2 `ListObjectsV2` (any query-bearing request) fails to sign

> **id**: `phanes-sigv4-uriencode-query-canonicalization-for-s3-list` · **opened**: 2026-05-19 KST · **status**: `resolved-ssot — SigV4 UriEncode + CanonicalQueryString landed in stdlib/aws/sigv4.hexa; sigv4_test 25/25 PASS (compiled path) incl. AWS get-vanilla-query-order-key-case / get-vanilla-query-unreserved / normalize-path/get-space byte-eq oracles (2026-05-19)`
> **trees**: `stdlib/aws/sigv4.hexa` (the signer — the §"Not done" punt) · `stdlib/aws/sigv4_test.hexa` (today only `get-vanilla`; add the `get-*-query` suite cases)
> **source**: downstream `phanes` (`~/core/phanes`, public source-available SaaS)
> **observed**: 2026-05-19 · measured against the live Cloudflare R2 endpoint
> **severity**: medium — `PutObject`/`GetObject`/`DeleteObject` (no query) work byte-eq against live R2; **only query-bearing requests fail**. Blocks `ListObjectsV2`, i.e. phanes Decision 21's "newest-N jobs per tenant" listing. Not a regression — this is the explicitly-deferred follow-up from the original SigV4 patch.

---

## 1. Why this is filed upstream (not fixed in phanes)

`stdlib/aws/sigv4.hexa` landed (resolved-ssot, `phanes-aws-sigv4-signer-for-stdlib.md`) with an explicit honest-scope punt, quoted verbatim from that patch's §"Not done":

> `sigv4.hexa` assumes the caller passes an already-encoded `path` and a
> pre-canonicalised `query` string — it does not implement the SigV4
> `UriEncode()` percent-encoder or query-parameter sorting. … S3 object
> paths with non-trivial keys / query parameters will need a `UriEncode`
> helper added before that surface is signed — punted as a follow-up
> (the `get-*-query` / `get-*-utf8` suite cases are the falsifier for it).

phanes has now reached that surface. Per `@D g_stdlib_ownership`
(hexa-lang owns all stdlib; downstream points, never copies) and `@D g7`
(gaps go upstream), the fix belongs in `stdlib/aws/sigv4.hexa`, not a
private phanes copy — the signer is shared (Bedrock SDK is the other
consumer).

## 2. Measured evidence (live Cloudflare R2, 2026-05-19)

phanes exposes the stdlib signer through `r2_put/r2_get/r2_delete/r2_list`
(→ `sigv4_sign`). Round-trip against the real R2 bucket, same credentials,
same code path — the **only** differentiator is presence of a query string:

```
PHANES_R2_OP=put  key=b3probe/q/a   -> exit 0   (no query)   ✅
PHANES_R2_OP=get  key=b3probe/q/a   -> exit 0   (no query)   ✅
PHANES_R2_OP=del  key=b3probe/q/a   -> exit 0   (no query)   ✅
PHANES_R2_OP=list prefix=b3probe/   -> exit 1   (query:      ❌
                                       list-type=2&prefix=b3probe/)
```

`r2_list` issues `GET /<bucket>?list-type=2&prefix=<p>`. The request is
rejected (signature mismatch) because the canonical request's
`CanonicalQueryString` is not built per SigV4: each parameter name and
value must be `UriEncode()`-percent-encoded (RFC 3986, `/` → `%2F`,
space → `%20`, etc.) **and** parameters sorted by encoded key — the
signer currently passes the raw `query` straight through.

## 3. The precise gap (SigV4 spec)

SigV4 `CanonicalQueryString` =
`UriEncode(name1)=UriEncode(value1)&…` with pairs **sorted by
`UriEncode(name)`**, and `UriEncode()` is RFC-3986 unreserved-only
(`A-Za-z0-9-_.~` unescaped; everything else `%XX`, uppercase hex; the
S3-path variant does **not** encode `/`, the query variant **does**).
The signer needs:

1. a `UriEncode(s, is_path)` helper (path vs query `/` rule), and
2. canonical-query assembly: split the caller's `query` on `&`, split
   each on the first `=`, `UriEncode` name and value, sort by encoded
   name, re-join. (Equivalently: accept a `[(k,v)]` list and build it.)

`path` should likewise be `UriEncode`d per-segment (so object keys with
spaces / unicode / `+` sign correctly) — same helper, `is_path=true`.

## 4. Suggested resolution (upstream's call)

- Add `UriEncode()` + canonical-query construction to
  `stdlib/aws/sigv4.hexa` (pure, no I/O — unit-testable).
- Extend `stdlib/aws/sigv4_test.hexa` with the official
  `aws-sig-v4-test-suite` **`get-vanilla-query*` / `get-utf8` /
  `normalize-path`** fixtures (byte-eq oracles, zero AWS/network) — the
  falsifier the original patch already named.
- Optional live cross-check: a Cloudflare R2 `ListObjectsV2`
  (`GET /<bucket>?list-type=2&prefix=…`) returning HTTP 200 — phanes can
  re-run its `r2_list` round-trip to confirm once landed.

## 5. Scope / honesty (g3)

- Observation + precise gap, **not** a request for phanes to patch
  stdlib. Filed per `@D g7` / `@D g_stdlib_ownership` / `@I id002`.
- phanes is **not fully blocked**: B3's core record storage
  (tenant token, job record `put`/`get`/`del`) is measured-working on
  live R2 today; only the *listing* surface (newest-N jobs) waits on
  this. phanes will use a maintained index object as an interim only if
  this lingers — preference is to consume the upstream fix.
- Pure & deterministic — landing needs no live AWS; the AWS
  `get-*-query` suite fixtures are the byte-level falsifier.

## 6. Cross-refs

- `inbox/patches/phanes-aws-sigv4-signer-for-stdlib.md` §"Not done" — the
  original punt this realises.
- `self/stdlib/bedrock_sdk.hexa` — the other SigV4 consumer (JSON APIs:
  empty query, so unaffected today, but benefits from a complete signer).
- phanes `design.md` Decision 21 (R2 datastore — `ListObjectsV2` for
  newest-N jobs) + Decision 23 (R2 system-of-record).
- AWS SigV4 test suite: https://docs.aws.amazon.com/IAM/latest/UserGuide/create-signed-request.html

---

## Resolution (2026-05-19 — upstream, Shape A)

Implemented in `stdlib/aws/sigv4.hexa` (the SSOT — phanes consumes via
`import`, no copy, per `@D g_stdlib_ownership`). Pure & deterministic; no
network, no AWS account needed.

**Files changed**

- `stdlib/aws/sigv4.hexa`
  - `sigv4_uri_encode(s, is_path)` — RFC 3986 §2.3: `A-Za-z0-9-_.~`
    unescaped, everything else `%XX` uppercase-hex. Byte-wise (UTF-8
    encodes per byte). `/` passes through only when `is_path=true`
    (S3-path rule); `is_path=false` (query) encodes `/` → `%2F`.
  - `sigv4_canonical_uri(path)` — empty → `/`; else `UriEncode(path,
    is_path=true)`. Idempotent on already-safe `/` (AWS JSON-API
    callers) and on already-encoded segments' unreserved bytes.
  - `sigv4_canonical_query(query)` — split raw caller query on `&`,
    split each pair on the **first** `=`, `UriEncode` name+value
    (`is_path=false`), stable-sort by encoded name (encoded-value
    tie-break), re-join `k=v&k=v`. Empty query → `""`.
  - `sigv4_canonical_request` now feeds the **raw** caller path + query
    through the two helpers — the signer owns the encoding (patch §3;
    callers pass `/`-joined paths and `a=b&c=d` strings unchanged).
- `stdlib/aws/sigv4_test.hexa` — +16 assertions (was 9, now 25).

**Measured test counts (compiled path — `hexa build`, interp not used,
per `@D g_interp_deprecated`)**

```
sigv4_test  25/25 PASS   (0 FAIL)
  - 9  original get-vanilla   (UNCHANGED — backward-compat byte-eq)
  - 6  UriEncode unit oracles (unreserved / space / slash path|query /
       '+'&'=' / UTF-8 byte-wise %E1%88%B4)
  - 4  get-vanilla-query-order-key-case  (raw "Param2=value2&Param1=
       value1" → sorted; sts c30…/816cd5b4…, sig b97d918c…) byte-eq
  - 3  get-vanilla-query-unreserved      (sig 9c3e54bf…) byte-eq
  - 3  normalize-path/get-space ("/example space/" → "/example%20
       space/"; sig 652487583200…) byte-eq
```

All canonical-request / string-to-sign-hash / signature values are byte-
equal to the official AWS `aws-sig-v4-test-suite` published
`.creq`/`.sts`/`.authz` fixtures.

**Honest scope (g3 — what is NOT covered)**

- Implemented: query-parameter UriEncode + sort, path UriEncode (space /
  UTF-8 / `+`), backward-compatible empty-query / `/` passthrough — i.e.
  exactly the S3/R2 `ListObjectsV2` (`?list-type=2&prefix=…`) surface the
  patch blocks.
- NOT implemented: RFC-3986 **dot-segment path normalization** (`../`,
  `./` collapsing — the suite's `normalize-path/get-relative*` cases).
  Out of scope: S3/R2 object keys contain no dot-segments and the patch
  §3 ask is UriEncode + query-sort only. Filing a follow-up is
  unnecessary for the phanes listing surface; revisit only if a non-S3
  consumer needs path normalization.
- No live-R2 cross-check run here (upstream has no R2 creds); the patch
  §4 "optional live cross-check" remains phanes' to re-run `r2_list`
  against the real bucket to confirm HTTP 200 once this lands.

**Measured re-verification (2026-05-19, worktree
`agent-aad5ba5db26ff6b18`)**

The original landing commit (`c3bbdffe`) was documented `25/25 PASS` but
not measured in the worktree at commit time. Re-run, exact command +
output (compiled path, `@D g_interp_deprecated`):

```
HEXA_MAC_BUILD_OK=1 HEXA_LANG=$PWD \
  HEXA_MODULE_LOADER=<repo>/build/hexa_module_loader \
  /tmp/hexadrv_fix build stdlib/aws/sigv4_test.hexa -o /tmp/sigv4t
  → build-exit 0  (module_loader flatten → hexa_v2 → clang OK)
/tmp/sigv4t
  → PASS 25/25   (run-exit 0)
```

`build && run` combined exit 0. **The +661-line code is correct as
committed** — the SigV4 `sigv4.hexa` source and the 25-case test compile
and pass byte-eq with no source change. The earlier "does not compile"
report was a *worktree-harness artifact*, not a code defect: a fresh
worktree has no compiled `build/hexa_module_loader`, so `hexa build`'s
flatten step hit `[flat] warn: compiled module_loader not found —
falling back to raw src` and transpiled the *un-flattened*
`sigv4_test.hexa` (which only `import`s `sigv4.hexa`). That raw unit
emits `extern` stubs for `sigv4_*` but never defines the `Sigv4Header` /
`Sigv4Request` struct constructors → ~10 clang `undeclared function`
errors. The control (baseline `14fdca36` test) reproduces the *same*
failure in the loader-less worktree and builds clean in the main
checkout — confirming the differentiator is the presence of the
compiled `module_loader`, not the new query/UriEncode code. Building
with `HEXA_MODULE_LOADER` pointed at any compiled loader (the main
checkout ships one at `build/hexa_module_loader`) restores correct
flatten and 25/25. No test case was deleted or weakened.
