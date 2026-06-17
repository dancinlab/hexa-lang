# F-SHA256-PURE-HEXA-CODEGEN-WALL — 🔴 CLOSED-NEGATIVE (for a quick stdlib fix)

Handoff **0b23189b** — "pure-hexa sha256 ~100–280× slower than CPython C
hashlib; blocks forge crypto-bound hot paths (forge_utxo_dump 163M-row UTXO
parse, per-row double-sha256 + bech32)."

**Verdict: case (a) — a GENERAL codegen/runtime substrate wall, NOT a fixable
stdlib inefficiency.** The pure-hexa `sha256_digest_bytes` algorithm is already
optimal; the cost is HexaVal boxing + polymorphic index dispatch emitted on
every 32-bit integer op. **There is, however, an immediate actionable answer for
forge: the runtime C `sha256` builtin — already exposed in stdlib as
`sha256_hex` / `sha256_of_string` / `sha256_bytes` — runs at C/OpenSSL parity
(~200 ns/hash). Forge's hot path should route to it, not to the pure-hexa core.**

Date: 2026-06-14 · base: origin/main @ b7784d0e5 · host: pool `summer`
(Ryzen, Linux 6.17, 12 cores, CPU-only) · backend: C-transpile default
(`hexa 0.1.0-dispatch`, clang -O2). Method: build + `/usr/bin/time -p`.
Correctness gate = FIPS 180-4 vectors, EXACT match required.

---

## 1. Reproduction — the gap is REAL but ~56× on summer (not 100–280×)

The handoff's 100–280× was measured on a slower Mac build; on summer the
pure-hexa core is ~56× slower than CPython. Both surfaces are byte-correct.

```
=== 100k sha256("abc"), user-time, x3 each ===

pure-hexa  sha256_digest_bytes (hash/hmac.hexa)   1.13s  = 11,300 ns/hash
python3    hashlib.sha256 (C / OpenSSL)           0.0201s =    201 ns/hash
                                                  → pure-hexa ≈ 56× slower

runtime C  sha256 builtin (exec_argv_sha256.c)    0.02s  =    200 ns/hash
           exposed as stdlib sha256_hex/_of_string → C/OpenSSL PARITY
```

Correctness (both pure-hexa and runtime-builtin), EXACT FIPS 180-4 match:

```
abc   = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad   PASS
empty = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855   PASS
```

## 2. Profile — where the 11,300 ns goes (case a, not b)

The generated C for the compression hot loop (`hexa cc` C-transpile default)
lowers EVERY 32-bit integer operation to a boxed `HexaVal` runtime call:

```c
// build/artifacts/.../bench_inline.c  — one schedule-extend line, verbatim:
w = hexa_index_set(w, si,
      hexa_mod(hexa_add(hexa_add(hexa_add(
        hexa_index_get(w, hexa_sub(si, hexa_int(16))), s0),
        hexa_index_get(w, hexa_sub(si, hexa_int(7)))), s1),
      hexa_int(4294967296)));
```

Every `hexa_add` / `hexa_mul` / `hexa_mod` / `hexa_sub` is a tagged-union
dynamic-dispatch call (`_HX_COERCE_BOOL` + `HX_IS_INT` tag checks + branch +
re-box). Every `w[i]` / `msg[off]` / `K[ri]` is `hexa_index_get`, which checks
map → valstruct → string tags before reaching the bounds-checked array path
(`self/runtime_core.c:3366`). SHA-256 is ~64 rounds × ~30 such ops + ~6 indexed
reads per round = thousands of boxed calls per hash. THAT is the 56×.

## 3. The fix that ISN'T — modulo→mask is byte-correct but 0% faster

The obvious algorithmic suspect — `% 4294967296` → `& 4294967295` (mask is
cheaper than modulo) — was applied and measured. It stays EXACT-correct but
buys NOTHING, because both lower to an equally-cheap `hexa_*` boxed call
dominated by the surrounding HexaVal dispatch:

```
pure-hexa  % 4294967296  (original)   1.13s   (abc/empty PASS)
pure-hexa  & 4294967295  (mask)       1.13s   (abc/empty PASS)   → Δ = 0
```

This is the decisive falsifier for case (b): the modular-arithmetic primitive
is not the lever. Other candidate (b) fixes are already absent as problems —
the round-constant table `HMAC_SHA256_K` is a module-level `let` (not recomputed
per call), `w` is preallocated once per block, and the message buffer is a
single `msg` (no per-byte re-alloc storm in the compression loop itself).

## 4. What the real lever would be (NOT a quick fix)

The wall is the codegen substrate: pure-hexa `int` is a boxed `HexaVal`, not a
native `uint32_t`, and indexing is polymorphic. Closing it would require a
codegen specialization pass (monomorphize `int`-typed hot loops to native
machine ints + unchecked array access where provably in-bounds) — a large,
separate codegen effort, not a stdlib edit. This is exactly the "pure-hexa
arithmetic/array ops are inherently ~50–100× slower than C" known limitation.

## 5. Resolution for the forge handoff (the actionable part)

forge's `forge_utxo_dump` (163M rows × double-sha256) must NOT use the pure-hexa
`sha256_digest_bytes`. It should call the runtime builtin already shipped in
`stdlib/core/hash/sha256.hexa`:

- raw bytes  → `sha256_bytes(data)` → 32-byte `[int]` digest (binary-safe,
  libsodium-gated; the path used by `sha256_of_bytes`)
- string     → `sha256_hex(s)` / `sha256_of_string(s)` (libsodium-FREE C
  reference impl; NUL-truncating per the module's L1 note — string inputs only)

At ~200 ns/hash that is C/OpenSSL parity and removes the 56× penalty entirely.
The pure-hexa core remains the libsodium-free *correctness reference* (and the
HMAC ipad/opad intermediate-block path that the string builtin cannot express);
it is not, and need not become, the production hot path.

---

**Handoff 0b23189b → documented finding (case a).** Quick stdlib speedup
CLOSED-NEGATIVE; correct production path (runtime builtin) IDENTIFIED and already
shipped. Do NOT re-attempt a pure-hexa sha256 micro-optimization — measured
exhausted (modulo→mask = 0% on byte-correct code).
