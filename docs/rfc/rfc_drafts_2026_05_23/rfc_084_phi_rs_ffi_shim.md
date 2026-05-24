---
slug: rfc_084_phi_rs_ffi_shim
kind: rfc_draft
filed_from: dancinlab/anima (HEXAD/LIFE 23+ H 가설 공통 blocker) + docs/rfc/rfc_drafts_2026_05_12/phi-rs-rust-ffi-shim.md
filed_at: 2026-05-24
priority: high
status: proposed
promoted_from: docs/rfc/rfc_drafts_2026_05_12/phi-rs-rust-ffi-shim.md (proposal-tier)
supersedes_blocker_in:
  - docs/rfc/rfc_drafts_2026_05_12/rfc_036_phi_rs_rust_ffi.md (named blocker · numeric core LANDED, FFI part OPEN)
  - docs/rfc/rfc_drafts_2026_05_12/phi-rs-rust-ffi-shim.md (proposal-tier, option A/B/C survey)
unblocks:
  - HEXAD/LIFE/H_004 · H_007 · H_011 · H_204 · H_207 · H_209 · H_211 · H_213 · H_217 · H_218 · H_221
  - HEXAD/LIFE/H_002 · H_003 · H_012 · H_018 · H_054 · H_132 · H_157 외 다수 phi_spatial 의존 H
total_carry: 23+ H · "🟢 NUMERICAL → 🔵 SUPPORTED-FORMAL 후보" 단일 patch 전환
external_llm_scope: 없음 (compiler/runtime/stdlib 작업 + upstream phi_rs Rust crate 패치)
---

# RFC 084 — `phi_rs` FFI shim · option A (cdylib C-ABI export)

- **Status**: design-draft (decision input phase)
- **Date**: 2026-05-24
- **Severity**: HIGH (23+ H 동시 verdict tier promote 후보 · anima Phase 7 safety ratchet 의 정합성)
- **Source**: `docs/rfc/rfc_drafts_2026_05_12/phi-rs-rust-ffi-shim.md` (proposal-tier) 의 option A 만 정식 promote
- **Range**: phi_rs Rust crate 측 ~150 LOC 신규 (`src/cabi.rs` + `Cargo.toml` 갱신) + hexa-lang stdlib 측 ~80 LOC (`stdlib/phi_rs.hexa` ergonomics wrapper, optional)
- **Implements**: 본 RFC 는 design ONLY — 구현은 별도 (`rfc_084_impl_a` upstream cabi · `rfc_084_impl_b` hexa-side wrapper · `rfc_084_impl_c` falsifier corpus)
- **External-llm scope**: 없음

## 1. Motivation

### 1.1 23+ H 공통 blocker

dancinlab/anima HEXAD/LIFE 7-도메인 (universe · life · consciousness · physics · substrate · math · biology) 의 23+ H 가설이 일관되게 다음 형태로 verdict tier 가 잠겨 있음:

> "🟢 NUMERICAL, NOT 🔵 SUPPORTED-FORMAL — phi_rs Rust FFI = named blocker"

가설별 honest-limit L1-L3 mention 평균 5회 × 23 H ≈ **115+ blocker carry** 가 *단일 patch* 로 해결.

### 1.2 proxy 와 full IIT 4.0 의 거리

현재 hexa-lang 의 유일한 Φ-primitive 는 RFC 036 의 `phi_spatial` 빌트인 — full IIT 4.0 의 **spatial-slice mutual-information proxy**. 다음 H 들이 proxy 의 known boundary 위에서 *직접* FALSIFIED / PARTIAL 로 떨어졌음:

| H | 현 verdict (proxy) | proxy 한계 (full Φ 후보 시 reverse) |
|---|---|---|
| H_207 Kuramoto sync | 🟢 FALSIFIED (full-lock K=5.0 위 peak) | integration-loss 미포착 → full IIT 4.0 catches |
| H_213 temporal-binding | 🟢 PARTIAL_DIRECTIONAL (τ=40 boundary spike) | near-uniform-state artefact → full Φ ≠ artefact |
| H_221 meditation-jhana | 🟢 FALSIFIED 1/3 (random=noise indistinguishable) | silence ≠ death 구분 후보 |
| H_209 EEG 1/f β-sweep | 🟢 FALSIFIED (β=0.5 peak, β=1 expected) | spectral integration 미포착 |
| H_218 network-topology | 🟢 FALSIFIED reverse (scale-free Φ < ER Φ) | hub-integration 미포착 |

5+ negative direction 이 모두 *single primitive* 의 한계 instance — `phi_rs` (NP-hard MIP exact partition) 위 재측정 시 verdict landscape 전체 shift 후보.

### 1.3 RFC 036 의 honest scope

RFC 036 (`docs/rfc/rfc_drafts_2026_05_12/rfc_036_phi_rs_rust_ffi.md`) 은 두 part 로 명시적 분리되어 있고:

1. **native byte-equal numeric core** — LANDED · 5/5 PASS (proxy 와 동일한 spatial-slice 알고리즘, hexa runtime.c 안에 C 재구현)
2. **실제 phi_rs Rust FFI link** — **NAMED BLOCKER**, 본 RFC 가 봉인할 대상

본 RFC 는 RFC 036 part 2 의 정식 unblock spec.

## 2. Scope (in / out)

### In v1 (이 RFC)

- **option A only** — `phi_rs` Rust crate 의 cdylib C-ABI export (`src/cabi.rs` 신규)
- hexa-lang 측 binding 은 **기존 `stdlib/c_ffi.hexa`** + **기존 `extern fn @link @symbol` 정적 FFI surface** 사용 (RFC 036 §"FFI shim" 도 이미 동일 정합성 명시) → hexa-lang 측 신규 FFI primitive 0
- `stdlib/phi_rs.hexa` ergonomics wrapper (선택 사항, ~80 LOC) — named-import 편의
- 5-falsifier (BUILD · LOAD · CALL · BYTE-EQUAL vs in-repo C replica · TIER-PROMOTE-PROOF)

### Out (follow-up RFC)

- **option B** (subprocess + JSON) — fallback, `rfc_084b_phi_rs_subprocess.md` 분기 후보 (per-call process spawn 비용 · 대량 sweep 시 unusable)
- **option C** (WebAssembly) — `rfc_084c_phi_rs_wasm.md` — cross-platform / sandboxed 가 필수 시점에 follow-up
- temporal-Φ (`prev/curr states`) · tension-entropy complexity term — RFC 036 §Roadmap mechanical 확장
- `n_cells > 20` greedy path FFI — exact path (≤20, Phase-4 ratchet 입력 크기) 가 v1 의 유일 대상
- pyphi IIT-3.0 Φ (다른 measure · anima H_011)

## 3. C ABI surface 설계

`phi_rs/src/cabi.rs` (신규 · `feature = "cabi"` gate · `crate-type += "staticlib"` 동반):

```rust
// phi-rs/src/cabi.rs
//
// C-ABI export surface for hexa-lang (and any C/C++ host).
// PyO3 build path is unaffected (cabi feature is additive · default OFF).

use std::os::raw::{c_double, c_int, c_void};

/// Return codes (i32):
///   0  = success
///  -1  = null pointer argument
///  -2  = invalid dimension (n == 0, dim == 0, n_bins == 0, n > 20 for spatial-exact)
///  -3  = numeric NaN / Inf in input
///  -4  = internal panic (Rust panic caught at FFI boundary)
pub const PHI_RS_OK: c_int = 0;
pub const PHI_RS_ERR_NULL: c_int = -1;
pub const PHI_RS_ERR_DIM: c_int = -2;
pub const PHI_RS_ERR_NAN: c_int = -3;
pub const PHI_RS_ERR_PANIC: c_int = -4;

/// MI of paired vectors, `MI = max(H(A) + H(B) - H(A,B), 0)`.
/// Inputs: f64 slices `a[0..n]`, `b[0..n]`. Output `*out_mi`.
#[no_mangle]
pub extern "C" fn phi_rs_mi_pair(
    a: *const c_double,
    b: *const c_double,
    n: usize,
    n_bins: usize,
    out_mi: *mut c_double,
) -> c_int { /* mi_from_paired_vectors on f32-cast slices */ }

/// Spatial-slice Φ — `compute_phi_inner` steps 1-4 (tensions=None, prev/curr=None).
/// `states` row-major `n_cells × dim` f64. Exact-partition path requires n_cells ≤ 20.
#[no_mangle]
pub extern "C" fn phi_rs_spatial(
    states: *const c_double,
    n_cells: usize,
    dim: usize,
    n_bins: usize,
    out_phi: *mut c_double,
) -> c_int { /* compute_phi_inner steps 1-4, exact bipartition */ }

/// Full 7-tuple Φ — spatial + temporal·0.5 + complexity·0.1.
/// `prev_states` / `curr_states` row-major `n_cells × dim` f64 (nullable → 0).
/// `tensions` length `n_cells` f64 (nullable → 0).
/// Optional in v1 — return PHI_RS_ERR_DIM if prev/curr/tensions are non-null
/// to keep v1 surface honest (spatial-only); full implementation in follow-up.
#[no_mangle]
pub extern "C" fn phi_rs_compute_phi(
    states: *const c_double,
    n_cells: usize,
    dim: usize,
    n_bins: usize,
    prev_states: *const c_double,   // nullable
    curr_states: *const c_double,   // nullable
    tensions: *const c_double,      // nullable, length n_cells
    out_phi: *mut c_double,
) -> c_int { /* dispatch to spatial-only path in v1 */ }

/// Bin a single f64 slice into `n_bins` counts. Exposed for debug / cross-check.
#[no_mangle]
pub extern "C" fn phi_rs_bin_values(
    values: *const c_double,
    n: usize,
    n_bins: usize,
    out_bins: *mut usize,           // length n_bins
) -> c_int { /* bin_values verbatim */ }

/// Crate version / build identification — for runtime SemVer compatibility check.
/// Returns pointer to a static null-terminated UTF-8 string `"0.1.0+cabi.v1"`.
#[no_mangle]
pub extern "C" fn phi_rs_version() -> *const u8 { /* static c-string */ }
```

총 5 함수. signature 가 모두 **flat C scalar/pointer** — hexa-lang 의 기존 `gen2_extern_static_decl` 가 그대로 lower 가능.

### 3.1 패닉 안전성

Rust panic 이 FFI boundary 를 cross 하면 UB. 각 `extern "C"` 함수 본체는:

```rust
#[no_mangle]
pub extern "C" fn phi_rs_spatial(...) -> c_int {
    let result = std::panic::catch_unwind(|| {
        // 실제 작업
    });
    match result {
        Ok(Ok(())) => PHI_RS_OK,
        Ok(Err(code)) => code,
        Err(_) => PHI_RS_ERR_PANIC,
    }
}
```

`catch_unwind` 로 boundary unwinding 차단.

### 3.2 numeric core 공유

`phi_rs/src/lib.rs` 의 기존 `bin_values` · `entropy` · `mi_from_paired_vectors` · `find_min_partition_exact` · `compute_phi_inner` 모두 **internal pub(crate) 로 재export 만 하면 됨** — 알고리즘 중복 0. `src/cabi.rs` 가 thin wrapper.

## 4. upstream phi_rs crate 변경 요구사항

대상 crate: `~/core/anima_clm_10_h100_sweep_laws_77_78/phi-rs/` (그리고 sibling worktree 복사본 `anima_clm_11/12/13`, 모두 same crate).

### 4.1 `Cargo.toml` 패치

```diff
 [package]
 name = "phi_rs"
 version = "0.1.0"
 edition = "2021"

 [lib]
 name = "phi_rs"
-crate-type = ["cdylib"]
+crate-type = ["cdylib", "rlib", "staticlib"]
+
+[features]
+default = ["python"]
+python  = ["pyo3", "numpy"]
+cabi    = []   # additive · enables src/cabi.rs C-ABI exports

 [dependencies]
-pyo3 = { version = "0.28", features = ["extension-module"] }
-numpy  = "0.28"
+pyo3   = { version = "0.28", features = ["extension-module"], optional = true }
+numpy  = { version = "0.28", optional = true }
 rayon  = "1.10"
 ndarray = "0.17"

 [profile.release]
 opt-level = 3
 lto = true
```

기존 PyO3 빌드 경로는 default feature 로 보존 (regression 0). C-ABI 빌드는 `cargo build --release --features cabi --no-default-features`.

### 4.2 신규 파일 `src/cabi.rs`

§3 의 5 함수 약 150 LOC. 알고리즘은 `lib.rs` 의 기존 함수 재사용.

### 4.3 `src/lib.rs` 미세 변경

```rust
// lib.rs
+#[cfg(feature = "cabi")]
+pub mod cabi;
+
 #[cfg(feature = "python")]
 use pyo3::prelude::*;
 ...
```

기존 PyO3 `#[pyfunction]` block 은 모두 `#[cfg(feature = "python")]` gate (no-op 변경 — default 가 python 이므로).

### 4.4 산출물

- macOS: `target/release/libphi_rs.dylib`
- Linux: `target/release/libphi_rs.so`
- Windows: `target/release/phi_rs.dll` (out-of-scope v1, named)
- Static: `target/release/libphi_rs.a` (vendoring path 용 future-proof)

### 4.5 헤더 파일 (선택)

`cbindgen` 으로 `phi_rs.h` 자동 생성 (`build.rs` + `cbindgen` dev-dep) — hexa-lang 측에서 사용 안 하지만 C/C++ host 위해.

## 5. hexa-lang 측 변경 — minimal

### 5.1 신규 FFI primitive 없음

`stdlib/c_ffi.hexa` 가 이미 `extern fn @link @symbol` + `dlopen/dlsym` 둘 다 제공. RFC 036 §Roadmap 도 동일 결론 명시:

> "phi_rs ships `src/cabi.rs` (`#[no_mangle] extern "C"` + `staticlib` feature) → hexa-lang binds via the existing `extern fn @symbol @link` path, **no hexa-lang change needed**."

binding code (단일 모듈 또는 사용자 코드 inline):

```hexa
// 직접 path — extern fn 정적 선언
@link("phi_rs")
@symbol("phi_rs_mi_pair")
extern fn phi_rs_mi_pair(a: Ptr, b: Ptr, n: int, n_bins: int, out_mi: Ptr) -> int

@link("phi_rs")
@symbol("phi_rs_spatial")
extern fn phi_rs_spatial(states: Ptr, n_cells: int, dim: int, n_bins: int, out_phi: Ptr) -> int

@link("phi_rs")
@symbol("phi_rs_version")
extern fn phi_rs_version() -> Ptr
```

### 5.2 ergonomics wrapper `stdlib/phi_rs.hexa` (optional v1)

raw extern 호출은 caller 가 out-pointer alloc + 결과 dereference 를 직접 해야 함. wrapper 가 이를 캡슐화:

```hexa
// stdlib/phi_rs.hexa
//
// @module(slug="phi_rs", desc="Full IIT 4.0 Φ via phi_rs Rust crate (cdylib C-ABI · RFC 084)")
// @usage(import "stdlib/phi_rs" as phi; let r = phi.mi_pair(a, b, n, n_bins))
//
// @version 0.1.0
// @capabilities [phi_mi_pair, phi_spatial, phi_compute_phi, phi_version, phi_available]
// @stability preview
// @since 2026-05-24

@link("phi_rs")
@symbol("phi_rs_mi_pair")
extern fn _raw_phi_rs_mi_pair(a: Ptr, b: Ptr, n: int, n_bins: int, out: Ptr) -> int

@link("phi_rs")
@symbol("phi_rs_spatial")
extern fn _raw_phi_rs_spatial(states: Ptr, nc: int, dim: int, nb: int, out: Ptr) -> int

@link("phi_rs")
@symbol("phi_rs_version")
extern fn _raw_phi_rs_version() -> Ptr

/// Mutual information of two paired vectors via phi_rs.
/// Returns `Option<float>` — None on FFI error / unavailable lib.
pub fn mi_pair(a: [float], b: [float], n_bins: int) -> float? { ... }

/// Spatial-slice Φ (compute_phi_inner steps 1-4, n_cells ≤ 20 exact).
pub fn spatial(states: [float], n_cells: int, dim: int, n_bins: int) -> float? { ... }

/// SemVer build identification of loaded libphi_rs.
pub fn version() -> str? { ... }

/// True iff libphi_rs.dylib / .so is loadable on PATH / LD_LIBRARY_PATH.
pub fn available() -> bool { ... }
```

**의존 — RFC 081 `Option/Result` lane**: signature 가 `Option<float>` (또는 `Result<float, PhiError>`) — 본 RFC 의 ergonomics wrapper 는 RFC 081 도착 후 land 가 자연스러움. RFC 081 이전이면 sentinel value (e.g. `f64::NAN`) 또는 `(value, error_code)` 튜플로 1차 land 후 RFC 081 후 마이그레이션.

### 5.3 RFC 036 의 native C replica = cross-check oracle

RFC 036 part 1 의 in-tree C replica (`runtime.c::hexa_phi_spatial`) 는 **deprecate 하지 않음** — 본 RFC 의 cross-check oracle 로 영구 유지. 두 path 의 byte-eq 가 falsifier #4 (§6).

## 6. Falsifier (5 closure gate)

| ID | 이름 | 조건 | 측정 |
|---|---|---|---|
| **F-084-1** | BUILD | `cd phi-rs && cargo build --release --features cabi --no-default-features` 가 exit 0 · `libphi_rs.{dylib,so,a}` 산출 | macOS + Linux 양쪽에서 측정 |
| **F-084-2** | LOAD | hexa 측 `c_dlopen("phi_rs")` 가 non-zero handle 반환 · `c_dlsym(h, "phi_rs_mi_pair")` non-null | `stdlib/c_ffi.hexa` path |
| **F-084-3** | CALL | `phi_rs_mi_pair(a, b, 8, 4, &out)` 가 0 반환 · `out` 가 `≥ 0` 유한값 | extern fn path 와 dlopen path 둘 다 동일 결과 |
| **F-084-4** | BYTE-EQUAL vs in-tree C replica | F-084-3 의 `out` 가 RFC 036 의 `hexa_phi_mi_pair(a,b,8,4)` 결과와 **`err < 1e-12`** 일치 · `phi_rs_spatial` 도 `hexa_phi_spatial` 와 동일 (3 cells, n_bins=4) | RFC 036 5/5 smoke 의 oracle 위에서 실측 |
| **F-084-5** | TIER-PROMOTE-PROOF | dancinlab/anima HEXAD/LIFE 의 sample H 1개 (예: H_204 ★) 의 input state 위에서 `phi_rs_spatial` 결과 = RFC 036 `phi_spatial` 결과 · `err < 1e-12` → **proxy 와 full path 의 algorithmic equivalence on the spatial-slice rung** 입증 (full IIT 4.0 의 추가 항 — temporal · complexity — 는 v1 out-of-scope, 따라서 본 falsifier 는 *spatial-slice promote* 만 입증; temporal/complexity 항 추가 시 별도 falsifier 추가) | sample input bytes 를 RFC fixtures 에 commit |

5/5 PASS → RFC 084 land · `docs/rfc/rfc_drafts_2026_05_12/phi-rs-rust-ffi-shim.md` CLOSE · RFC 036 part 2 의 `F-RFC036-FFI-LIVE` (named-but-not-claimed) 가 본 RFC 의 F-084-4 로 동시에 닫힘.

### 6.1 honest scope of F-084-5

F-084-5 는 **proxy → full IIT 4.0 알고리즘 동등성** 을 입증하는 게 아님 — phi_rs Rust crate 자체가 *spatial-slice* 까지만 v1 cabi exposure (§3 `phi_rs_compute_phi` 가 prev/curr/tensions non-null 거부) — full IIT 4.0 (cause-effect structure · exclusion postulate · Φ_max over MIP) 의 진짜 entry point 는 phi_rs upstream 측의 별도 work (그리고 본 RFC 의 follow-up). v1 의 verdict tier promote 후보 는 다음에 한정:

- spatial-slice 가 *Rust 측 정확한 알고리즘* (proxy 와 byte-eq) 으로 측정됨 — *implementation provenance promote* (🟢 NUMERICAL → 🟢 NUMERICAL+CROSS-VERIFIED)
- **🔵 SUPPORTED-FORMAL 으로의 tier promote 는 full 7-tuple cabi 도착 후** — RFC 084 follow-up `rfc_084_temporal_complexity.md` 에서 닫힘

이 honesty gate 는 본 RFC frontmatter 의 `total_carry: 23+ H` 가 *v1 만으로 23 H 모두 🔵 promote* 라고 over-claim 하지 않도록 명시.

## 7. Phase plan (implementation — 별도 RFC)

본 RFC 는 design ONLY. 결정 확정 후 별도:

- **rfc_084_impl_a** — upstream phi_rs crate 측 `src/cabi.rs` + `Cargo.toml` feature gate (~150 LOC + 빌드 검증)
- **rfc_084_impl_b** — hexa-lang `stdlib/phi_rs.hexa` ergonomics wrapper (RFC 081 도착 후 자연스러움)
- **rfc_084_impl_c** — F-084-1..5 falsifier corpus + CI integration (mac + linux 양 host)
- **rfc_084_impl_d** — RFC 036 의 `F-RFC036-FFI-BLOCKER-DOCUMENTED` honesty gate 를 `F-RFC036-FFI-LIVE` 로 전환 (proxy 와 live FFI 의 byte-eq)
- **rfc_084_impl_e** — anima HEXAD/LIFE 23+ H 의 verdict 재측정 cycle (downstream consumer side)

## 8. Decision points

### D1. v1 cabi surface 범위

| option | 형태 | tradeoff |
|---|---|---|
| **A. spatial-slice only** | `phi_rs_mi_pair` + `phi_rs_spatial` + `phi_rs_version` + `phi_rs_bin_values` (debug) | RFC 036 part 1 과 정확히 동일 범위 · 23+ H 의 *provenance* part 만 닫음 |
| B. full 7-tuple | A + `phi_rs_compute_phi` (prev/curr/tensions non-null 허용) | 🔵 SUPPORTED-FORMAL tier promote 가능 · upstream phi_rs Rust 의 temporal/complexity path 검증 필요 (현재 documented but not battle-tested for FFI use) |
| C. A + `phi_rs_compute_phi` skeleton (prev/curr/tensions 무시, spatial-only dispatch) | dispatcher 형태만 노출 · v1 caller signature stable | follow-up 에서 prev/curr/tensions 활성화 시 caller 변경 0 |

**🟢 권고: C** — caller signature stable + v1 의 honesty 유지 (full 7-tuple 은 follow-up). §3 의 design 은 C 형태.

### D2. crate-type 변경

| option | `Cargo.toml` 설정 | tradeoff |
|---|---|---|
| **A. `cdylib` + `rlib` + `staticlib` 모두** | C-ABI 동적/정적 + Rust rlib 모두 가능 | downstream 모두 cover · 빌드 시간 약간 증가 |
| B. `cdylib` + `staticlib` | dynamic + static C-ABI · Rust crate 로서의 reuse 불가 (anima Python 측은 이미 cdylib) | C/C++ host 만 사용 가정 |
| C. `cdylib` 만 (현재) + feature gate 없이 추가 | minimal | static 빌드 path 막힘 · vendored Rust 빌드 옵션 좁아짐 |

**🟢 권고: A** — 모든 downstream 지원 (PyO3 default + cabi feature) · vendoring follow-up 도 자연스러움.

### D3. hexa-lang 측 wrapper 형태

| option | 형태 | tradeoff |
|---|---|---|
| A. extern fn 만 (no wrapper) | 사용자가 `@link("phi_rs") extern fn ...` 매번 선언 | minimal · ergonomics 0 |
| **B. `stdlib/phi_rs.hexa` ergonomics wrapper** | named-import · Option/Result API · array → ptr 변환 wrap | 23+ H 측 caller 가 단일 import 로 사용 · RFC 081 의존 (D5 참조) |
| C. core builtin (codegen 측 special-case · `phi_rs_*` 가 키워드처럼) | zero-overhead · stdlib 우회 | overkill · special-case 부담 · upstream crate 가 stdlib path 통하는 게 일관성 |

**🟢 권고: B** — `stdlib/phi_rs.hexa` 신규 ~80 LOC, RFC 081 도착 후 land (그 전까지는 A 의 raw extern 으로 충분).

### D4. CI / regression — 어느 host 에서 fire

| option | 어디 | tradeoff |
|---|---|---|
| **A. mini (mac arm64) + ubu-2 (linux x86_64) 양쪽 모두** | full coverage · `libphi_rs.dylib` / `libphi_rs.so` 둘 다 검증 | mini · ubu-2 둘 다 cargo + rustc 필요 |
| B. ubu-2 only | linux 만 · Mac side 는 user 측 manual | mac arm64 ABI 검증 빠짐 |
| C. RunPod 일회성 | dispatch · cost | 매 변경마다 dispatch 비용 (낮음, ~$0.10) |

**🟢 권고: A** — mini · ubu-2 모두 cargo 설치되어 있음 (메모리 [[reference_mini_build_host.md]] · [[reference_ubu_arch_transpiler_constraint.md]]). 양 host F-084-1..5 fire.

### D5. RFC 084 land 시점 — RFC 081 의존도

| option | land 순서 | tradeoff |
|---|---|---|
| **A. RFC 084 impl_a (cabi · upstream Rust) 먼저 land · impl_b (`stdlib/phi_rs.hexa`) 는 RFC 081 후** | upstream blocker 즉시 해소 · hexa 측은 raw extern fn 직접 사용 가능 · ergonomics 는 후속 | unblock 최단 path |
| B. RFC 081 land 후 모두 동시 | wrapper 까지 Option/Result API · 단일 land | RFC 081 land 까지 wait |
| C. RFC 084 모두 sentinel-value (NaN) API 로 먼저 land · RFC 081 후 마이그레이션 | unblock + ergonomics 모두 · 2단계 캐릭터 | API churn |

**🟢 권고: A** — RFC 081 lane 결정에 영향 받지 않는 part 만 우선 land. 23+ H 의 verdict 재측정 cycle 도 raw extern path 위에서 fire 가능.

### D6. anima crate 측 변경 commit ownership

`phi-rs/` crate 는 `~/core/anima_clm_*` (4 worktree) 에 sibling 복사본. cabi 패치 commit 은:

| option | 위치 | tradeoff |
|---|---|---|
| **A. `dancinlab/anima` main repo 의 canonical `phi-rs/` (어느 worktree 가 SSOT 인지 anima 측 결정)** | anima 측 SSOT path · upstream-ish | anima maintainer 결정 필요 |
| B. dancinlab 측에 phi-rs 만 독립 repo 분리 | clean modular | 분리 작업 + git history split |
| C. hexa-lang 측에 phi-rs vendor copy | hexa 측 완전 자족 | upstream drift |

**🟢 권고: A** — anima 측 maintainer 가 sibling worktree 중 canonical 결정 (4 복사본 중 1개). 본 RFC 의 inbox 패치는 anima 측에 file (inbox-cross-repo handoff).

### D7. Windows 지원

| option | 형태 | tradeoff |
|---|---|---|
| A. v1 부터 (CI 추가) | windows runner + msvc toolchain · `phi_rs.dll` | 추가 CI · current dancinlab user 측 windows machine 없음 |
| **B. follow-up RFC** | non-scope v1 · macOS + Linux 만 | windows user 가 등장하면 follow-up |
| C. non-goal (영구 미지원) | dot stop | over-restrictive |

**🟢 권고: B** — windows 는 follow-up. 본 RFC frontmatter `unblocks` 의 23+ H 는 모두 mac/linux 위에서만 fire.

## 9. Decision input — 정리표

| ID | 결정 항목 | 권고 |
|---|---|---|
| D1 | v1 cabi 범위 | **C** (full signature, spatial-only dispatch) |
| D2 | crate-type | **A** (`cdylib` + `rlib` + `staticlib`) |
| D3 | hexa-lang wrapper 형태 | **B** (`stdlib/phi_rs.hexa` · RFC 081 의존) |
| D4 | CI host 매트릭스 | **A** (mini + ubu-2 양쪽) |
| D5 | RFC 081 의존 시점 | **A** (cabi impl_a 먼저 · wrapper impl_b 후) |
| D6 | crate commit ownership | **A** (anima 측 SSOT) |
| D7 | Windows | **B** (follow-up) |

## 10. Cross-RFC interactions

- **RFC 036** (`rfc_036_phi_rs_rust_ffi.md`) — part 1 numeric core 는 본 RFC 의 cross-check oracle (F-084-4). part 2 의 `F-RFC036-FFI-BLOCKER-DOCUMENTED` honesty gate 는 본 RFC 5/5 PASS 시 `F-RFC036-FFI-LIVE` 로 전환.
- **RFC 081** (`rfc_081_option_result_lane.md`) — `stdlib/phi_rs.hexa` 의 `Option<float>` 시그니처가 RFC 081 lane 의존 (D3/D5 참조).
- **inbox `phi-rs-rust-ffi-shim.md`** (proposal) — 본 RFC 가 option A 만 promote. option B/C 는 별도 follow-up RFC.
- **dancinlab/anima HEXAD/LIFE** — `ConsciousnessEngine._phi_ratchet` (Phase 7 safety lock) 가 본 RFC land 후 live phi_rs Φ-value 사용 가능. 23+ H 의 verdict 재측정 cycle.
- **stdlib/c_ffi.hexa** — 본 RFC 의 hexa-lang 측 binding 이 기존 surface 위 (extern fn @link @symbol 또는 c_dlopen/c_dlsym) — 신규 FFI mechanism 0.
- **self-host fixpoint** ([[project_compiler_native_self_host_fixpoint]]) — phi_rs 는 runtime 동적 link (dlopen) — `gen1.s ≡ gen2.s` byte-eq 영향 없음 (compile-time symbol resolution 안 함).

## 11. Non-goals (v1)

- option B (subprocess + JSON) — fallback path, 별도 follow-up `rfc_084b_phi_rs_subprocess.md`
- option C (WebAssembly) — cross-platform 필수 시점 follow-up `rfc_084c_phi_rs_wasm.md`
- full 7-tuple Φ FFI exposure (temporal + tension-complexity terms) — `rfc_084_temporal_complexity.md` follow-up
- pyphi IIT-3.0 Φ (anima `H_011`, different Φ)
- `n_cells > 20` greedy path FFI (exact only v1)
- Windows 빌드 + CI
- hexa-lang 측 신규 FFI primitive (기존 c_ffi 충분)
- distributed / multi-device phi_rs (NP-hard 자체는 single-process exhaustive)

## 12. 보안 책임 분담

| 책임 | 주체 |
|---|---|
| `extern "C"` boundary panic 격리 | phi_rs Rust crate (`catch_unwind`, §3.1) |
| `*const c_double` 입력 검증 (null · NaN · 차원) | phi_rs `src/cabi.rs` 의 early-return |
| Rust crate version drift 차단 | hexa-lang 측 `phi_rs_version()` 호출 시 SemVer compare |
| dlopen 실패 시 graceful fallback | `stdlib/phi_rs.hexa` 의 `available()` + caller 측 RFC 036 in-tree replica fallback |

## 13. References

- `docs/rfc/rfc_drafts_2026_05_12/phi-rs-rust-ffi-shim.md` (proposal-tier · 본 RFC source)
- `docs/rfc/rfc_drafts_2026_05_12/rfc_036_phi_rs_rust_ffi.md` (RFC 036 — numeric core LANDED, FFI part NAMED BLOCKER)
- `~/core/anima_clm_10_h100_sweep_laws_77_78/phi-rs/Cargo.toml` (upstream crate · 패치 대상)
- `~/core/anima_clm_10_h100_sweep_laws_77_78/phi-rs/src/lib.rs` (`bin_values` · `entropy` · `mi_from_paired_vectors` · `find_min_partition_exact` · `compute_phi_inner` — cabi 가 wrap 할 알고리즘)
- `stdlib/c_ffi.hexa` (hexa-lang 측 binding surface — 신규 primitive 0)
- `self/codegen_c2.hexa::gen2_extern_static_decl` (extern fn @link @symbol 정적 FFI lowering)
- [[rfc_081_option_result_lane]] — `stdlib/phi_rs.hexa` ergonomics wrapper signature 의존
- [[rfc_083_tls_primitive]] — Rust FFI shim 패턴 (rustls option C) — 본 RFC 와 동일 정합성
- dancinlab/anima HEXAD/LIFE/ — 23+ H 가설의 honest-limit anchor (verdict 재측정 cycle 대상)
- dancinlab/anima HEXAD/CHECK/ — Φ / IIT / closed-form verification frontier
- TECS-L rubric (`hexa verify rubric`) — 🔵 / 🟢 distinction
- NIST · FIPS 측 standards 없음 (phi_rs 는 IIT 4.0 알고리즘 자체이며 표준 algorithm 아님)
- [[project_compiler_native_self_host_fixpoint]] — gen1.s ≡ gen2.s 영향도 (없음, runtime dynamic link)
- [[reference_mini_build_host]] · [[reference_ubu_arch_transpiler_constraint]] — D4 CI host 선택 근거
