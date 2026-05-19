# incoming patch: phanes-sigv4-uriencode-query-canonicalization-for-s3-list — `stdlib/aws/sigv4.hexa` punted the SigV4 `UriEncode()` + query-parameter canonicalization; S3/R2 `ListObjectsV2` (any query-bearing request) fails to sign

> **id**: `phanes-sigv4-uriencode-query-canonicalization-for-s3-list` · **opened**: 2026-05-19 KST · **status**: `resolved-ssot (CODE COMPLETE + MEASURED 25/25) — landing deferred: see §Resolution. The fix is committed & verified on git branch worktree-agent-aad5ba5db26ff6b18 (commits c3bbdffe + 11735bd); it is NOT yet on a mainline hexa-lang branch because this checkout was on an unrelated session branch (stdlib-atoms-stage2-cif) and the shared-worktree-branch hazard forbids hijacking it. Upstream owner: cherry-pick -x c3bbdffe 11735bd onto a clean hexa-lang main/feature branch.`

> **§Resolution (2026-05-19, measured by the phanes session, independent of the authoring agent):**
> `stdlib/aws/sigv4.hexa` gained `UriEncode(s,is_path)` (RFC-3986; `/` kept on path, `%2F` on query) + sorted CanonicalQueryString + per-segment CanonicalURI; `stdlib/aws/sigv4_test.hexa` gained the AWS `get-vanilla-query-order-key-case` / `-query-unreserved` / `normalize-path` (`get-space`) fixtures + 6 UriEncode unit oracles. **Measured: `sigv4_test` build-exit 0 and `PASS 25/25`** (original 9 `get-vanilla` still byte-eq + 6 UriEncode + 3 new AWS query/path fixtures byte-eq to published `.creq`/`.sts`/`.authz`). No case deleted or weakened.
> **Build-harness lesson (orthogonal, important):** a fresh `git worktree` has no compiled `build/hexa_module_loader`; `cmd_build`'s flatten then silently falls back to raw-src (`[flat] warn ... falling back to raw src`) and mis-transpiles any `import`-bearing entry into `extern` stubs with no struct constructors → spurious clang "undeclared `Sigv4Header`" errors that look like a code defect but are not. Fix: build with `HEXA_MODULE_LOADER=<main-checkout>/build/hexa_module_loader`. (Independently reproduced: baseline pre-change test fails identically loader-less, builds clean with the loader — the differentiator is the loader, not this patch's code.) This is a pre-existing `self/main.hexa` build-harness gap (raw-src fallback should fail loud, not emit a broken binary), left documented for the owner — not in this patch's scope.
> **Not covered (honest, code unchanged):** RFC-3986 dot-segment normalization (`../`,`./`) — out of S3/R2 ListObjectsV2 scope; no live-R2 cross-check (no upstream R2 creds in the authoring context — but the phanes session can re-run its `r2_list` round-trip once landed).
>
> **id**: `phanes-sigv4-uriencode-query-canonicalization-for-s3-list` · **opened**: 2026-05-19 KST · **prior status**: `open — measured downstream, upstream owns the fix (@D g7 / @D g_stdlib_ownership)`
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
