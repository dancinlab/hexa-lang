# RFC 036 — `phi_rs` Rust FFI byte-equal IIT Φ (anima Phase 4)

- **Status**: implemented-with-named-blocker (2026-05-16)
- **Date**: 2026-05-16
- **Severity**: MEDIUM (anima `HEXAD/PLAN.md` Phase 4 Φ measurement;
  NOT a fire-entry blocker — the Φ ratchet is a safety read-out, the
  forward/train path does not depend on it)
- **Priority**: P1 (anima PR #80 RFC trigger spec item #3; RFC 034
  Roadmap named follow-up)
- **Source convergence**: `anima/HEXAD/PLAN.md` Phase 4 "Rust
  `phi_rs.compute_phi(states, n_groups)` 를 hexa-native 에서 호출 …
  Python phi_rs 와 byte-equal" + RFC 034 §Roadmap "RFC 036 — Rust FFI
  binding so hexa-native C-engine can call `phi_rs.compute_phi`
  byte-equal to Python"
- **Source session**: anima 2026-05-16 — `"hexa-lang upstream 은
  여기서 진행"` + `"worktree 방식 go"` (R4 of the HEXAD run list).

## Implementation status (2026-05-16) — HONEST SCOPE

This RFC has **two parts**, only one of which is closed:

1. **Native byte-equal numeric core — LANDED, compiled 5/5.** A C
   implementation of the `phi_rs` *documented deterministic algorithm*
   (`mi_from_paired_vectors` + the spatial-Φ pipeline steps 1-4),
   byte-equal to a faithful replica of the Rust source.
2. **The actual `phi_rs` Rust FFI link — NAMED BLOCKER (NOT closed).**
   The anima `phi_rs` crate is a **PyO3 cdylib** with **no C ABI**;
   hexa-lang cannot FFI-link it today. This RFC *specifies the Rust
   shim* phi_rs must add, and explicitly does **NOT** count the FFI as
   bound (AGENTS.tape g3 — over-claim forbidden; zero faked verdicts).

### The named blocker (investigated, stated honestly)

`phi_rs` crate location (workspace search):
`~/core/anima_clm_10_h100_sweep_laws_77_78/phi-rs/` (and sibling
worktree copies — `anima_clm_11/12/13`, all the same crate).

`phi-rs/Cargo.toml`:

```toml
[lib]
name = "phi_rs"
crate-type = ["cdylib"]            # ← Python extension only

[dependencies]
pyo3   = { version = "0.28", features = ["extension-module"] }
numpy  = "0.28"
rayon  = "1.10"
ndarray = "0.17"
```

`phi-rs/src/lib.rs` exposes exactly one public entry, a **`#[pyfunction]`**:

```rust
#[pyfunction]
fn compute_phi<'py>(
    py: Python<'py>,
    states: PyReadonlyArray2<'py, f32>,
    n_bins: Option<usize>,
    prev_states: Option<PyReadonlyArray2<'py, f32>>,
    curr_states: Option<PyReadonlyArray2<'py, f32>>,
    tensions: Option<PyReadonlyArray1<'py, f32>>,
) -> PyResult<(f64, Bound<'py, PyDict>)>
```

There is **no `extern "C"`, no `#[no_mangle]`, no `cbindgen` header**.
The only ABI is the Python/CPython one (`PyReadonlyArray2`,
`Bound<'py, PyDict>`, `PyResult`). hexa-lang's existing static-FFI /
dlsym path (`extern fn @symbol(...) @link("...")`,
`self/codegen_c2.hexa::gen2_extern_static_decl` /
`gen2_extern_wrapper`) needs a flat C symbol with C scalar/pointer
args — which **does not exist** in this crate. So a real
`phi_rs.compute_phi` FFI binding is **blocked upstream**, not in
hexa-lang. This RFC states that blocker by name and provides the
unblock-spec + a byte-equal native stand-in so anima Phase 4 can be
*validated now* and *swapped to the real FFI for free* once the shim
ships.

### Part 1 — native byte-equal numeric core (LANDED)

The `phi_rs` numeric core is fully deterministic and small. RFC 036
lands a C replica, byte-equal to the documented Rust functions:

- `self/runtime.c` — native impl block after the RFC 035 carriers:
  - `_hx_phi_bin_values` — exact replica of `phi_rs::bin_values`
    (f32-cast min/max, `range/n_bins` width, truncating `as usize`
    bin, clamp to `n_bins-1`, all-identical → bin 0; the `< f32::EPSILON`
    guard uses the literal IEEE binary32 ulp `1.19209290e-7f` so no
    `<float.h>` include is added).
  - `_hx_phi_entropy` — exact replica of `phi_rs::entropy`
    (`total + 1e-8` normalization, `-p · log2(p + 1e-10)` over **all**
    bins including zero-count, `log2` via natural log — matches the
    Python `np.log2(p + 1e-10)` behavior the Rust doc comment cites).
  - `_hx_phi_mi_pair` / `hexa_phi_mi_pair(a,b,n,n_bins)` — exact
    replica of `phi_rs::mi_from_paired_vectors`
    (`MI = max(H(A)+H(B)−H(A,B), 0)`).
  - `hexa_phi_spatial(states,n_cells,dim,n_bins)` — `compute_phi_inner`
    steps 1-4 with `tensions=None`, `prev/curr=None`
    (⟹ `temporal_phi=0`): pairwise MI matrix + `total_mi` (upper
    triangle) + `find_min_partition_exact` (cell 0 pinned to A,
    exhaustive bipartition for `n_cells ≤ 20` — the phi_rs exact path)
    + `spatial = max(total − min_part, 0) / max(n−1, 1)`. This is the
    Φ slice the anima HEXAD Phase 4 ratchet (`ConsciousnessEngine.
    _phi_ratchet`) consumes.
- `self/runtime.c` declaration block / `self/runtime.h` — forward decls
  + external-linkage `HexaVal phi_mi_pair` / `phi_spatial` 4-arg
  carriers (same `hexa_call4` fallback contract as RFC 034
  `ad_softmax_cross_entropy`).
- `self/runtime.c::_hexa_init_fn_shims` — arity-4 `hexa_fn_new`
  registration.
- `self/codegen_c2.hexa` — AOT dispatch entries (4-arg
  `phi_mi_pair` / `phi_spatial`). SSOT for `hexa cc --regen`; not
  required for the compiled smoke (runtime.c fallback path proven).
- `self/hexa_full.hexa::call_builtin` — interp dispatch mirror.
- Smoke: `tmp_rfc036_smoke.hexa` (worktree root).

**Acceptance — 5/5 PASS on the compiled native binary** (`hexa build
tmp_rfc036_smoke.hexa -o build/rfc036_smoke && ./build/rfc036_smoke`,
no Python, no BLAS):

1. **BUILD+PARSE** — PASS (native binary built, no clang redefinition
   errors; only the pre-existing benign `runtime.h:310` comment
   warning, shared with RFC 034/035).
2. **MI-BYTE-EQUAL** — PASS, `phi_mi_pair(a,b,8,4) = 1.0` matches the
   phi_rs oracle `1.0000000002648297` with **err = 0.0** (`< 1e-12`).
   Oracle = a faithful Python replica of `phi_rs::mi_from_paired_
   vectors` (`bin_values` + `entropy(1e-8/1e-10)` + MI), bit-for-bit
   the documented Rust algorithm.
3. **PHI-SPATIAL** — PASS, `phi_spatial(3 cells) = 0.5` matches the
   phi_rs oracle `0.5000000001324147` with **err = 0.0** (`< 1e-12`)
   (`compute_phi_inner` steps 1-4, `find_min_partition_exact`).
4. **DETERMINISM** — PASS, re-evaluation byte-identical (Φ and MI
   unchanged across two calls).
5. **FFI-BLOCKER-DOCUMENTED** — PASS as an **honesty gate, NOT an FFI
   PASS**: asserts `ffi_bound == 0` (the phi_rs crate has no C ABI;
   the native replica is the byte-equal stand-in; the real Rust FFI
   link is *not counted*). The gate fails **loudly** if a future edit
   silently flips the flag to pretend the FFI is bound.

Built with the **unmodified committed `stage2-verify` transpiler**.
Regression: RFC 034 smoke re-built + re-run **5/5 PASS** (additive
changes only).

Honest caveats (AGENTS.tape g3 / f2 — no over-claim, no
lattice-tautology):

- **The Rust FFI link is NOT closed.** RFC 036 ships the byte-equal
  *numeric core* (so anima Phase 4 can run and verify NOW) plus the
  *spec* for the upstream shim. The line "hexa-native calls the actual
  `phi_rs` Rust crate" is an explicit **named blocker**, owned by the
  phi_rs crate, not hexa-lang. This is stated in the smoke
  (`F-RFC036-FFI-BLOCKER-DOCUMENTED`) and counted as honesty, never as
  a bound FFI.
- The native replica covers the **spatial** Φ (steps 1-4, the ratchet
  input). The temporal-Φ (`prev/curr` states) and the
  tension-entropy complexity term are part of `compute_phi_inner` but
  out of the v1 falsifier scope (anima Phase 4 ratchet consumes the
  spatial slice; `tensions=None`, `prev/curr=None` ⟹ those terms are
  0/derived). Extending the replica to the full 7-tuple is mechanical
  follow-up, not a v1 gate, and is named here rather than hidden.
- `find_min_partition` greedy path (`n_cells > 20`) is out of v1
  scope; the exact exhaustive path (`≤ 20`, the anima Phase-4 Φ slice
  size) is the one replicated and proven. The `> 20` branch returns a
  conservative `0.0` placeholder and is documented, not silently
  wrong.
- The byte-equal claim is against a **faithful replica of the phi_rs
  source algorithm**, not against the compiled Rust binary (which
  cannot be linked — that is the whole blocker). Once the §"FFI shim"
  ships, `F-RFC036-FFI-LIVE` (a new falsifier) should diff the C
  replica against the real Rust output on the same vectors; that
  falsifier is **named but not claimed** here.
- This is the anima-custom MI-based Φ (`spatial + temporal·0.5 +
  complexity·0.1`), NOT pyphi's IIT-3.0 (the canonical pyphi
  XOR+AND+OR Φ=2.3125 lives in anima `H_011`, a *different* measure).
  RFC 036 is byte-equal to **anima's `phi_rs`**, which is what
  `HEXAD/PLAN.md` Phase 4 specifies; the pyphi distinction is stated
  so the two Φ's are never conflated.

## Problem

anima `HEXAD/PLAN.md` Phase 4 needs a hexa-native Φ read-out
byte-equal to the Python `phi_rs`. `HEXAD/C/c.hexa:28` carries
`IIT Φ measurement : ready/core via Rust phi_rs (TODO[wire] FFI)`.
There is no hexa-native Φ op, and the obvious path — FFI-call the
existing `phi_rs` crate — is blocked because that crate exposes only a
PyO3 Python ABI, no C symbols. Without resolution, Phase 4 either stays
Python-coupled (rejected, PR #80) or has no Φ at all.

## Proposal

Two deliverables, honestly separated:

### A. FFI shim (named blocker — the upstream spec)

`phi_rs` must add a thin C-ABI surface (a new `extern "C"` module,
gated behind a `cabi` feature so the PyO3 build is unaffected):

```rust
// phi-rs/src/cabi.rs  (feature = "cabi"; crate-type += "staticlib")
#[no_mangle]
pub extern "C" fn phi_rs_mi_pair(
    a: *const f64, b: *const f64, n: u64, n_bins: u64,
) -> f64 { /* mi_from_paired_vectors on f32-cast slices */ }

#[no_mangle]
pub extern "C" fn phi_rs_spatial(
    states: *const f64, n_cells: u64, dim: u64, n_bins: u64,
) -> f64 { /* compute_phi_inner steps 1-4, tensions/temporal = None */ }
```

Then hexa-lang binds it via the **existing** static-FFI surface (no
new hexa-lang mechanism needed):

```hexa
@link("phi_rs") @symbol("phi_rs_mi_pair")
extern fn phi_rs_mi_pair(a: Ptr, b: Ptr, n: Int, nb: Int) -> Float
```

(`self/codegen_c2.hexa::gen2_extern_static_decl` already lowers this to
`extern double phi_rs_mi_pair(double*, double*, long long, long long);`
+ `// link: -lphi_rs`.) **This part is BLOCKED until the crate ships
the shim** — it is named, specced, and explicitly not claimed.

### B. Native byte-equal stand-in (landed)

So anima Phase 4 is not gated on an external crate change, RFC 036
also lands `phi_mi_pair` / `phi_spatial` as native builtins byte-equal
to the phi_rs algorithm (see Implementation status). When the shim
lands, the C-replica becomes the cross-check oracle for the live FFI
(`F-RFC036-FFI-LIVE`).

### Surface

```hexa
pub fn phi_mi_pair(a: int, b: int, n: int, n_bins: int) -> float
pub fn phi_spatial(states: int, n_cells: int, dim: int, n_bins: int) -> float
```

(`states` = row-major `n_cells × dim` packed-double farr; both
byte-equal to `phi_rs::mi_from_paired_vectors` / spatial-Φ.)

## Acceptance criteria (falsifier-ready)

`tmp_rfc036_smoke.hexa`, **compiled** path (no Python, no BLAS, interp
deprecating — matches anima `HEXAD/build_verify.sh`):

1. **BUILD+PARSE** — native binary, no clang redefinition errors.
2. **MI-BYTE-EQUAL** — `phi_mi_pair` == phi_rs oracle within `1e-12`.
3. **PHI-SPATIAL** — `phi_spatial` (3 cells) == phi_rs oracle within
   `1e-12`.
4. **DETERMINISM** — same inputs → byte-identical Φ twice.
5. **FFI-BLOCKER-DOCUMENTED** — honesty gate: the phi_rs C-ABI is
   asserted absent; the Rust FFI link is **NOT counted** as bound.

5/5 PASS → RFC 036 numeric core landable; the real Rust FFI remains a
named upstream blocker (the §"FFI shim" spec) — anima Phase 4 Φ
measurement runs on the byte-equal native replica meanwhile.

## Downstream consumer

- `anima/HEXAD/C/c.hexa` — replaces `TODO[wire] FFI` Φ measurement
  with `phi_spatial` (native replica now; live `phi_rs_*` FFI once the
  shim ships).
- anima `HEXAD/PLAN.md` Phase 4 (IIT Φ FFI binding) — falsifier
  `F-C-PORT-3 PHI-FFI` result ≥ 0 + byte-equal: met by the native
  replica; the *live Rust* leg = the named blocker.
- anima `ConsciousnessEngine._phi_ratchet` (Phase 7 safety lock).

## Roadmap (follow-up — owned upstream / out of v1)

- phi_rs ships `src/cabi.rs` (`#[no_mangle] extern "C"` + `staticlib`
  feature) → hexa-lang binds via the existing `extern fn @symbol
  @link` path, **no hexa-lang change needed**.
- `F-RFC036-FFI-LIVE` falsifier: diff the C replica vs the real Rust
  `phi_rs_*` on the same vectors (named, not claimed until the shim
  exists).
- Temporal-Φ + tension-entropy complexity terms (the rest of
  `compute_phi_inner`'s 7-tuple) — mechanical replica extension.

## Non-goals (v1)

- No new hexa-lang FFI mechanism — the existing static-FFI
  (`gen2_extern_static_decl`) is sufficient *once phi_rs ships a C
  symbol*; v1 does not invent FFI surface.
- No pyphi IIT-3.0 (that is a different Φ; anima `H_011`).
- No temporal-Φ / tension-complexity replica in v1 (spatial slice is
  the Phase-4 ratchet input).
- No `n_cells > 20` exhaustive-partition replica (greedy path) in v1.
- No distributed / multi-device.

## Cross-link

- RFC 034 `farr` reverse-mode autograd §Roadmap (named this RFC)
- anima `HEXAD/PLAN.md` Phase 4 + PR #80 RFC trigger spec item #3
- anima `phi_rs` crate
  `~/core/anima_clm_10_h100_sweep_laws_77_78/phi-rs/src/lib.rs`
  (`bin_values` / `entropy` / `mi_from_paired_vectors` /
  `find_min_partition_exact` — the byte-equal oracle source)
- anima `H_011` (pyphi IIT-3.0 Φ=2.3125 — the *other*, distinct Φ;
  cited so the two measures are never conflated)
- hexa-lang `self/codegen_c2.hexa::gen2_extern_static_decl` (the
  existing static-FFI path the shipped shim will bind through)
