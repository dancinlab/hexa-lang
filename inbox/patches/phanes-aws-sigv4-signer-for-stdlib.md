# incoming patch: phanes-aws-sigv4-signer-for-stdlib — stdlib has no AWS SigV4 request signer; add `stdlib/aws/sigv4.hexa` (+ a byte-level HMAC-SHA256)

> **id**: `phanes-aws-sigv4-signer-for-stdlib` · **opened**: 2026-05-19 KST · **status**: `resolved-ssot — stdlib/aws/sigv4.hexa + stdlib/core/hash/hmac.hexa landed, AWS test-suite byte-eq verified (see resolution note)`
> **trees**: `stdlib/aws/` (new — proposed home) · `stdlib/core/hash/sha256.hexa` (has `sha256_hex`, byte-capable `sha256_hash_bytes`) · `self/std_crypto.hexa` (has `hmac_sha256`, but string-in / hex-out — see §3) · `self/stdlib/bedrock_sdk.hexa` (already DEFERs its SigV4 path — this patch un-blocks it)
> **source**: downstream `phanes` (`~/core/phanes`, public source-available SaaS).
> **observed**: 2026-05-19 · hexa-lang pin: `6f9962e5`
> **severity**: medium — blocks phanes' Decision 15 (DynamoDB + S3 datastore) and would un-defer the Bedrock SDK's SigV4 path. Not a bug; a missing stdlib capability.

---

## 1. Why this is filed upstream (not built in phanes)

phanes' design.md Decision 15 moves its datastore to **DynamoDB + S3**.
Both are reached over their HTTP/JSON APIs — which require every request
to carry an **AWS Signature Version 4** `Authorization` header. SigV4 is
not phanes-specific: it is the auth primitive for *every* AWS service
over HTTP. Per `@D g_stdlib_ownership` (hexa-lang owns all stdlib;
downstream repos point, never copy) and `@D g7` (gaps go upstream), a
SigV4 signer belongs in hexa-lang's stdlib, and phanes should `import`
it — not vendor a private copy.

This is also already a *known* hexa-lang gap. `self/stdlib/bedrock_sdk.hexa`
states it outright in its header:

```
//   .ts side imports `@aws-sdk/client-bedrock-runtime` which depends on:
//     1. SigV4 request signing (HMAC-SHA256 chain + canonical request)
//   Hexa-lang stdlib has neither HMAC-SHA256 nor a binary event-stream
//   parser — see no-hardcode9 GAP-D / GAP-E below.
//   ... SigV4 path: DEFER (return exit-1 stub ...).
```

So Bedrock shipped a bearer-token bypass and deferred SigV4. Landing a
stdlib SigV4 signer un-defers that path *and* unblocks phanes — one
capability, two consumers.

## 2. What SigV4 needs (the algorithm)

AWS SigV4 is four deterministic steps (no network, fully unit-testable):

1. **Canonical request** — `HTTPMethod \n CanonicalURI \n CanonicalQuery
   \n CanonicalHeaders \n SignedHeaders \n HexSHA256(payload)`.
2. **String to sign** — `"AWS4-HMAC-SHA256" \n <amz-date> \n
   <date>/<region>/<service>/aws4_request \n HexSHA256(canonicalRequest)`.
3. **Signing key** — a four-link HMAC chain:
   `kDate    = HMAC("AWS4"+secretKey, dateStamp)`
   `kRegion  = HMAC(kDate, region)`
   `kService = HMAC(kRegion, service)`
   `kSigning = HMAC(kService, "aws4_request")`
   then `signature = HexEncode(HMAC(kSigning, stringToSign))`.
4. **Authorization header** — `AWS4-HMAC-SHA256
   Credential=<accessKey>/<scope>, SignedHeaders=<...>, Signature=<...>`.

Crypto primitives required: SHA-256 and HMAC-SHA256. SHA-256 is present
(`stdlib/core/hash/sha256.hexa` `sha256_hex`, and the byte-capable
`sha256_hash_bytes` in `self/std_crypto.hexa`). HMAC is the gap — §3.

## 3. The precise primitive gap — HMAC must be byte-level

`self/std_crypto.hexa` has `hmac_sha256(key, data)`, but its surface is
**string-in, hex-out**:

```
fn hmac_sha256(key, data) -> string {
    let key_bytes = string_to_bytes(key)        // key taken as a string
    ...
    return bytes_to_hex(result)                 // returns a 64-char hex string
}
```

SigV4 step 3 chains HMAC outputs *as keys*: `kRegion = HMAC(kDate, ...)`
where `kDate` is **32 raw bytes**. With the current function,
`hmac_sha256(hmac_sha256(...), ...)` feeds a 64-char hex *string* (then
`string_to_bytes` → 64 ASCII bytes) as the next key — not the 32 raw
bytes. The chain silently produces a wrong signing key.

**Needed**: a byte-level variant, e.g.

```
pub fn hmac_sha256_bytes(key: [int], data: [int]) -> [int]
```

key and result both raw `[int]` bytes. The existing `hmac_sha256` body
already works internally on byte arrays (`ipad`/`opad` from `key_bytes`,
`sha256_hash_bytes`) — only the input/output framing needs the
byte-array form. The string/hex `hmac_sha256` can stay as a thin wrapper
over it.

## 4. Suggested resolution (upstream's call)

- Add `stdlib/aws/sigv4.hexa` — a pure function that, given
  `{ method, host, region, service, path, query, headers, payload,
  access_key, secret_key, amz_date }` (+ optional STS `session_token`),
  returns the `Authorization` header value and the `x-amz-date` /
  `x-amz-content-sha256` headers. No network, no I/O — pure, so it is
  fully unit-testable.
- Add the byte-level `hmac_sha256_bytes` (§3), most naturally in a
  `stdlib/core/hash/` HMAC module so `sha256.hexa` and it sit together;
  re-express the existing string/hex `hmac_sha256` as a wrapper.
- Verify against the **AWS-published SigV4 test suite** (the official
  `aws-sig-v4-test-suite` — canonical-request / string-to-sign /
  signature `.txt` fixtures per case) and the worked
  "signature calculations" example in the AWS General Reference
  (the `iam` / `us-east-1` / `20150830` derivation has a published
  known signing key + signature). These give exact byte-level oracles —
  correctness is measurable with zero AWS account or network.

## 5. Scope / honesty (g3)

- This is an observation + a precise gap analysis, **not** a request for
  phanes to patch stdlib. Filed per `@D g7` / `@D g_stdlib_ownership` /
  `@I id002` — downstream surfaces the gap, upstream owns the fix.
- phanes is **not blocked today**: Decision 15 (the DynamoDB/S3
  migration) is itself a future ROADMAP item. This patch is filed now so
  the stdlib capability is ready when that migration starts, and so the
  Bedrock SDK's deferred SigV4 path has a single shared signer to adopt.
- SigV4 is pure and deterministic — landing it needs no live AWS; the
  AWS test-suite fixtures are the falsifier.

## 6. Cross-refs

- `self/stdlib/bedrock_sdk.hexa` — header §GAP-D, the deferred SigV4 path.
- `stdlib/core/hash/sha256.hexa` — `sha256_hex` / `sha256_hash_bytes`.
- `self/std_crypto.hexa` — the string/hex `hmac_sha256` to be re-based.
- phanes `design.md` Decision 13 (Stripe — also HTTP-API, separate) +
  Decision 15 (DynamoDB + S3 — the consumer of this signer).
- AWS SigV4 test suite: https://docs.aws.amazon.com/IAM/latest/UserGuide/create-signed-request.html (worked example) · the `aws-sig-v4-test-suite` fixture set.

---

## 7. Resolution (2026-05-19 — resolved-ssot)

Landed as **Shape A** (real implementation, not RFC scaffold): SigV4 is pure,
deterministic, and fully unit-testable against AWS-published oracles, so a
direct implementation with byte-eq falsifier is the natural fit.

**Files added:**
- `stdlib/core/hash/hmac.hexa` — byte-level `hmac_sha256_bytes(key: [int],
  data: [int]) -> [int]` (raw bytes in, raw bytes out — the §3 gap). Carries
  its own pure-hexa SHA-256-over-bytes core (`sha256_digest_bytes`) because
  the runtime `sha256` builtin is string-in/hex-out only and cannot be fed
  the intermediate ipad/opad blocks. Also ships `hmac_sha256_hex`,
  `sha256_hex_bytes`, and the thin `hmac_sha256_str` string/hex wrapper that
  re-expresses the legacy `self/std_crypto.hexa::hmac_sha256` surface on top
  of the byte-level core (§3 suggested re-base).
- `stdlib/core/hash/hmac_test.hexa` — FIPS 180-4 SHA-256 vectors (empty,
  "abc") + RFC 4231 §4 HMAC-SHA256 known-answer vectors (cases 1 & 2) +
  a chaining proof that byte-key ≠ hex-key (the exact §3 bug).
- `stdlib/aws/sigv4.hexa` — pure `sigv4_sign(req: Sigv4Request) -> Sigv4Result`.
  No network, no I/O. Implements the 4-step algorithm verbatim; returns the
  `Authorization` header value plus `x-amz-date` / `x-amz-content-sha256`,
  and exposes the canonical-request / string-to-sign intermediates for
  assertion. Optional STS `session_token` field is on the request struct.
- `stdlib/aws/sigv4_test.hexa` — the official `aws-sig-v4-test-suite`
  `get-vanilla` fixture as a byte-eq self-test.

**Verification (measured, compiled path — `hexa build`, interp not used):**
- `hmac_test`: 8/8 PASS — SHA-256 + HMAC-SHA256 byte-equal to FIPS 180-4 /
  RFC 4231 published vectors.
- `sigv4_test`: 9/9 PASS — canonical request, full string-to-sign (incl. the
  published canonical-request hash `bb579772317eb040ac9ed261061d46c1f17a8133879d6129b6e1c25292927e63`),
  signature `5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31`,
  and the complete `Authorization` header all byte-equal to the AWS
  `get-vanilla` oracle. Zero AWS account / network used.

**Not done (honest scope):** `sigv4.hexa` assumes the caller passes an
already-encoded `path` and a pre-canonicalised `query` string — it does not
implement the SigV4 `UriEncode()` percent-encoder or query-parameter
sorting. For AWS JSON APIs (DynamoDB, Bedrock, STS) the path is always `/`
and the query is empty, so the `get-vanilla` case fully exercises the live
path. S3 object paths with non-trivial keys / query parameters will need a
`UriEncode` helper added before that surface is signed — punted as a
follow-up (the `get-*-query` / `get-*-utf8` suite cases are the falsifier
for it). `self/std_crypto.hexa::hmac_sha256` was left untouched (it predates
the retired interpreter and uses interp-era builtins); `hmac_sha256_str`
in the new module is the compiled-path replacement and the suggested
re-base target.
