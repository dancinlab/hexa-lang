# RFC 033 — `farr_copy` + `farr_add_gaussian_noise` native builtins

- **Status**: draft (2026-05-12)
- **Date**: 2026-05-12
- **Severity**: HIGH (blocks pure-hexa serve-time mitosis hook full impl)
- **Priority**: P0 (anima `tool/hexa_native/mitosis_hook.hexa` prerequisite)
- **Source convergence**: anima REBORN.md §89 (commit `6527cbc80`) — hexa-native
  serve-time mitosis hook RFC dependency catalog explicitly lists the two
  builtins below as the missing primitives.
- **Source session**: anima `tool/hexa_native/mitosis_hook.hexa` parse-only stub
  cannot be promoted to full impl until parent → child weight deepcopy + small
  gaussian perturbation are first-class hexa runtime primitives (the PyTorch
  reference `anima/tool/mitosis.py` L204/L213 does both as one-liners; the
  hexa lane has to match the semantics, not the implementation).

## Problem

The pure-hexa serve-time mitosis hook needs to clone the parent cell's
weight farr buffers into freshly-allocated child slots and then add a small
gaussian perturbation (~10 % of the original weight magnitude, σ controlled
per call site). The current toolbox forces either:

1. A pure-hexa `for i in 0..n { farr_set(dst, i, farr_get(src, i)) }` loop —
   12-88 B HexaVal arena allocation per element. For a 1024×1024 layer (1 M
   doubles) this is ~88 MB scratch per layer, ~2 GB across 24 layers.
2. A pure-hexa Box-Muller transform — needs `cos/sin/log/sqrt` and two
   `uniform(0,1)` calls per pair; each pure-hexa scalar-math op pays the
   same per-call boxing tax.

Both block the `mitosis_hook.hexa` full-impl gate.

## Proposal

Add two new runtime builtins, parallel to RFC 031 / RFC 032 in style:

```hexa
// RFC 033-A — explicit deep copy: returns a fresh farr_id with byte-exact
//             contents of `src`. -1 on invalid handle.
pub fn farr_copy(src: int) -> int

// RFC 033-B — in-place gaussian noise injection: each element receives
//             one independent draw from N(0, sigma^2) added on top of
//             the existing value. Mutates `target` directly; returns
//             nothing (val_void in interp, no C return value used).
//             Reproducibility: see "Seed" section below.
pub fn farr_add_gaussian_noise(target: int, sigma: float) -> ()
```

## Semantics

### `farr_copy(src) -> dst`

1. Resolve `src` against the farr handle table (RFC 025 layout). If `src`
   is out of bounds or the buffer is NULL, return `-1`.
2. Read `n = src.len`.
3. Allocate a new farr via `hexa_farr_zeros(n)` — this returns a fresh
   handle reusing a freelist slot if available (same path RFC 031 / 032
   take, so handle-recycling is consistent across the family).
4. `memcpy(dst.buf, src.buf, n * sizeof(double))` — packed-double byte-
   exact copy.
5. Return the new handle as `hexa_int(dst_id)`.

This is intentionally NOT `farr_zeros(n)` followed by a per-element
`farr_set` loop; the whole point of the builtin is to bypass the per-elem
HexaVal arena pressure. `memcpy` writes are vectorized by the system libc
on every supported host.

### `farr_add_gaussian_noise(target, sigma)`

1. Resolve `target` against the farr handle table. If invalid or NULL,
   return `hexa_void()` with no mutation.
2. Read `n = target.len`. If `n == 0`, return immediately (no-op).
3. Reject negative / non-finite `sigma`. `sigma == 0.0` is allowed and
   produces a no-op (every draw is `0.0 * something = 0.0`).
4. For each pair `(target.buf[2i], target.buf[2i+1])` (with the trailing
   odd element handled separately):
   - Draw two independent uniforms `u1, u2 ∈ (0, 1]` via a static internal
     PRNG (see "Seed" below).
   - Apply the Box-Muller transform:
     ```
     r     = sqrt(-2.0 * log(u1))
     theta = 2.0 * PI * u2
     z0    = r * cos(theta)        // ~ N(0,1)
     z1    = r * sin(theta)        // ~ N(0,1)
     ```
   - Add `sigma * z0` to `target.buf[2i]`, `sigma * z1` to
     `target.buf[2i+1]`.
5. Tail element (when `n % 2 == 1`): draw one extra pair and use only `z0`.

### Seed / PRNG

- Internal `static uint64_t _hx_gauss_rng_state` initialized once on first
  call via `seed = (uint64_t)time(NULL) ^ ((uint64_t)getpid() << 16)`,
  then advanced with `splitmix64` — a 64-bit non-cryptographic PRNG with
  good distributional properties for Monte Carlo noise (no `rand()`
  dependency, deterministic given the state, no global C `srand` side
  effects).
- A side-channel env hook (`__HEXA_FARR_GAUSS_SEED__=<u64-decimal>`)
  lets callers force a specific seed for reproducibility tests (parallel
  to existing `__HEXA_ARENA_RSS_MB__` etc.). Read once at first call,
  cached for the process lifetime.
- The PRNG state is process-local, NOT thread-local — current hexa
  interp is single-threaded; if/when we add threads we'll revisit
  per-thread RNG (cheap retrofit: thread-local `_hx_gauss_rng_state`).

## Memory cost

- `farr_copy`: one fresh farr buffer (`n * 8` bytes via `calloc` in
  `hexa_farr_zeros`) + one `memcpy(n * 8)`. No HexaVal arena allocation
  beyond the single returned `hexa_int(dst_id)`.
- `farr_add_gaussian_noise`: zero new buffer (in-place). Zero HexaVal
  arena allocation in the hot loop. Two `log` + two trig calls per pair
  of elements — the only non-arithmetic ops, both bounded `O(n)`.

## Falsifiers (≥ 9 required by directive; we ship 10)

### `farr_copy` falsifiers

- **F-RFC-033-COPY-SIZE**: `farr_len(farr_copy(src)) == farr_len(src)` for
  `src.len ∈ {0, 1, 8, 1024}`.
- **F-RFC-033-COPY-EXACT**: byte-exact parity — for each index `i` in
  `[0, n)`, `farr_get(dst, i) == farr_get(src, i)`. Tested with mixed
  finite values, `+inf`, `-inf`, `NaN`, `+0.0`, `-0.0`.
- **F-RFC-033-COPY-INDEPENDENCE**: mutating `dst` does NOT mutate `src`
  (deep copy, not handle alias). Write `dst[0] = 99.0`, verify
  `src[0]` unchanged.
- **F-RFC-033-COPY-INVALID**: `farr_copy(-1)` returns `-1`; no crash.
  `farr_copy(<freed_handle>)` returns `-1` (buf NULL).
- **F-RFC-033-COPY-EMPTY**: `farr_copy(<n=0 src>)` returns a valid handle
  with `farr_len(dst) == 0`.

### `farr_add_gaussian_noise` falsifiers

- **F-RFC-033-GAUSS-MEAN**: with `n = 100_000` zero-initialized elements
  and `sigma = 1.0`, sample mean satisfies `|mean| < 3 / sqrt(n)`
  (3-sigma CI; failure rate < 0.3 % under H0).
- **F-RFC-033-GAUSS-STD**: with the same setup, sample std satisfies
  `|std - 1.0| < 0.01` (relative tolerance, comfortable at n=100k).
- **F-RFC-033-GAUSS-IN-PLACE**: zero-init farr A; pass to noise call;
  observe non-zero values afterward (the function mutates, doesn't return
  a new handle).
- **F-RFC-033-GAUSS-SIGMA-SCALE**: with `sigma = 5.0`, sample std ≈ 5.0
  (`|std - sigma| / sigma < 0.02`). Linearity check.
- **F-RFC-033-GAUSS-ZERO-SIGMA**: `sigma == 0.0` is a no-op; every
  element retains its pre-call value (tested by writing 7.0 first, then
  calling, then reading).
- **F-RFC-033-GAUSS-INVALID**: `farr_add_gaussian_noise(-1, 1.0)` is a
  no-op (no crash, returns void). `sigma < 0` rejected as no-op.
- **F-RFC-033-GAUSS-SEED-REPRO**: with the env hook
  `__HEXA_FARR_GAUSS_SEED__=42` set, two consecutive runs produce the
  same noise sequence (byte-exact farr contents after the call).

## Risks

- **Numerical**: Box-Muller can produce subnormal `r` when `u1 ≈ 1.0`
  (giving `log(u1) ≈ 0`). The implementation generates `u1 ∈ (2^-53, 1]`
  to keep `r` finite. Worst-case `r ≈ sqrt(-2 * log(2^-53)) ≈ 8.6` — within
  IEEE-754 double range with vast headroom.
- **Aliasing**: `farr_copy` allocates a fresh slot; no aliasing risk. The
  noise function mutates in-place; caller responsible for not interleaving
  reads from a parent during a child's noise step (mitosis_hook caller
  copies first, then noises, so this is naturally serialized).
- **Strict aliasing**: pure `double*` arithmetic, no type-punning needed
  (different from RFC 031's bf16-as-uint16 reinterpretation).
- **Determinism**: WITHOUT `__HEXA_FARR_GAUSS_SEED__`, draws differ per
  run (PID + wall-clock seed). WITH the env, byte-exact reproducibility
  across runs — required for the SEED-REPRO falsifier.

## Cross-RFC dependency

- **RFC 025** (mmap zero-copy farr handle table) — direct extension; both
  builtins live on the existing farr handle table, no new tables.
- **RFC 031** (BF16 reader) — a typical mitosis flow loads parent
  weights via `safetensors_mmap_read_bf16_to_f32_farr` → `farr_copy` →
  `farr_add_gaussian_noise`. RFC 033 is the missing middle hop.
- **RFC 032** (`farr_matmul`) — independent; child weights produced by
  RFC 033 are then fed to RFC 032 forward passes inside the spawned cell.

## Anima-side unblock

`anima/tool/hexa_native/mitosis_hook.hexa` (currently parse-only stub,
anima REBORN.md §89, commit `6527cbc80`) becomes full-impl-ready once
RFC 033 lands. Direct one-to-one mapping with `anima/tool/mitosis.py`:

```python
# anima/tool/mitosis.py L200-L215 (PyTorch reference)
child_state = {
    name: parent_state[name].clone()                      # L204
    for name in parent_state
}
for name, w in child_state.items():
    if w.dtype.is_floating_point:
        w.add_(torch.randn_like(w) * 0.1 * w.std())       # L213
```

Becomes (hexa lane):

```hexa
// anima/tool/hexa_native/mitosis_hook.hexa (full impl, post-RFC 033)
fn split_cell(parent_farr_ids: [int], sigma_frac: float = 0.1) -> [int] {
    let mut child_ids = []
    for id in parent_farr_ids {
        let child = farr_copy(id)
        let sigma = sigma_frac * farr_std(id)             // RFC 034 future
        farr_add_gaussian_noise(child, sigma)
        child_ids.append(child)
    }
    return child_ids
}
```

(`farr_std` is the natural next builtin — RFC 034 candidate — but not on
the RFC 033 critical path; the `sigma` value can come from caller for v1.)

## Implementation pointers

```c
// self/runtime.c (after hexa_farr_matmul block, ~L8060)

// Forward decl (alongside RFC 031/032):
HexaVal hexa_farr_copy(HexaVal src_v);
HexaVal hexa_farr_add_gaussian_noise(HexaVal target_v, HexaVal sigma_v);
static HexaVal farr_copy_shim;
static HexaVal farr_add_gaussian_noise_shim;

// PRNG state (file scope, single-threaded):
static uint64_t _hx_gauss_rng_state = 0;
static int      _hx_gauss_rng_inited = 0;

static uint64_t _hx_splitmix64(uint64_t* x) {
    uint64_t z = (*x += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

static double _hx_uniform01_open(uint64_t* state) {
    // Map to (2^-53, 1] — avoids log(0).
    uint64_t r = _hx_splitmix64(state) >> 11;          // 53-bit mantissa
    if (r == 0) r = 1;
    return (double)r * (1.0 / 9007199254740992.0);     // 2^53
}

HexaVal hexa_farr_copy(HexaVal src_v) {
    int64_t src_id = hexa_as_num(src_v);
    if (src_id < 0 || src_id >= _hx_farr_count) return hexa_int(-1);
    HexaFarrEntry* se = &_hx_farr_table[src_id];
    if (!se->buf && se->len > 0)                return hexa_int(-1);
    int64_t n = se->len;
    HexaVal dst_handle = hexa_farr_zeros(hexa_int(n));
    int64_t dst_id = HX_INT(dst_handle);
    if (dst_id < 0 || dst_id >= _hx_farr_count) return hexa_int(-1);
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    if (n > 0 && de->buf && se->buf) {
        memcpy(de->buf, se->buf, (size_t)n * sizeof(double));
    }
    return dst_handle;
}

HexaVal hexa_farr_add_gaussian_noise(HexaVal target_v, HexaVal sigma_v) {
    int64_t id = hexa_as_num(target_v);
    double  sigma = __hx_to_double(sigma_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_void();
    HexaFarrEntry* e = &_hx_farr_table[id];
    if (!e->buf || e->len <= 0)         return hexa_void();
    if (!(sigma == sigma) || sigma < 0.0) return hexa_void();   // reject NaN, negative
    if (sigma == 0.0)                   return hexa_void();     // no-op
    if (!_hx_gauss_rng_inited) {
        const char* env = getenv("__HEXA_FARR_GAUSS_SEED__");
        if (env && *env) {
            _hx_gauss_rng_state = strtoull(env, NULL, 10);
        } else {
            _hx_gauss_rng_state = (uint64_t)time(NULL) ^
                                  ((uint64_t)getpid() << 16);
        }
        if (_hx_gauss_rng_state == 0) _hx_gauss_rng_state = 1;
        _hx_gauss_rng_inited = 1;
    }
    int64_t n = e->len;
    int64_t i = 0;
    for (; i + 2 <= n; i += 2) {
        double u1 = _hx_uniform01_open(&_hx_gauss_rng_state);
        double u2 = _hx_uniform01_open(&_hx_gauss_rng_state);
        double r  = sqrt(-2.0 * log(u1));
        double th = 2.0 * 3.14159265358979323846 * u2;
        e->buf[i]   += sigma * r * cos(th);
        e->buf[i+1] += sigma * r * sin(th);
    }
    if (i < n) {
        double u1 = _hx_uniform01_open(&_hx_gauss_rng_state);
        double u2 = _hx_uniform01_open(&_hx_gauss_rng_state);
        double r  = sqrt(-2.0 * log(u1));
        double th = 2.0 * 3.14159265358979323846 * u2;
        e->buf[i] += sigma * r * cos(th);
    }
    return hexa_void();
}
```

## Unblocks

- anima `tool/hexa_native/mitosis_hook.hexa` parse-only stub → full impl
- v5-mitosis PyTorch arch spec hexa sister lane closure (REBORN §89)
- future RFC 034 (`farr_std`, `farr_mean`) — natural follow-up but NOT on
  the RFC 033 critical path
