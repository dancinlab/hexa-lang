---
slug: phi-rs-rust-ffi-shim
kind: rfc_draft
filed_from: dancinlab/anima (HEXAD/LIFE session, 23+ H files)
filed_at: 2026-05-24
priority: high
status: proposed
blocker_for:
  - HEXAD/LIFE/H_004 cycle #1 Φ-function dissociation (cross-link)
  - HEXAD/LIFE/H_007 CA→Φ edge-of-chaos
  - HEXAD/LIFE/H_204 weak-panpsy autopoietic threshold (★, Cycle #2 MAPPING_STRONG ρ=1.0)
  - HEXAD/LIFE/H_211 shannon-entropy-Φ-correlate (Pearson r=0.933)
  - HEXAD/LIFE/H_217 phase-transition-Φ-derivative (cross-substrate)
  - HEXAD/LIFE/H_207 Kuramoto sync (boundary peak artefact — phi_spatial L6 ex-ante)
  - HEXAD/LIFE/H_209 EEG 1/f spectrum (β-sweep peak misalignment)
  - HEXAD/LIFE/H_213 temporal-binding-window (boundary spike artefact)
  - HEXAD/LIFE/H_221 meditation-jhana (silence ≠ death 구분 못 함)
  - HEXAD/LIFE/H_002/H_003/H_012/H_018/H_054/H_132/H_157/H_018/H_018 외 다수 — 모든 phi_spatial 사용 H 의 Honest Limit L1-L3 공통
total_carry: 23+ H · 모두 "🟢 NUMERICAL, NOT 🔵, phi_rs Rust FFI = named blocker" 일관 mention
---

# RFC draft: phi_rs Rust FFI shim — hexa-lang upstream patch

## 한 줄 요약

RFC 036 `phi_spatial` runtime builtin (현재 hexa 의 유일한 Φ-primitive) 은 full IIT 4.0
의 *spatial-slice mutual-information proxy* — 모든 dancinlab/anima HEXAD/LIFE 가설 (23+)
이 verdict tier 를 **🟢 NUMERICAL 으로만 닫고 있고 🔵 SUPPORTED-FORMAL 으로 올라가지
못함**. 실제 full IIT 4.0 Φ 는 Rust crate `phi_rs` (NP-hard MIP 정확 partition search)
가 있으나, **hexa-lang 에 Rust FFI primitive 부재 + PyO3 cdylib 가 C ABI 미노출** —
shim path 부재가 23+ H 의 공통 명명된 blocker.

## 배경 — proxy vs full IIT 4.0

| metric | implementation | tier 최대 | semantic |
|--------|---------------|----------|----------|
| **phi_spatial** | RFC 036 hexa runtime builtin (binning + KL div) | 🟢 NUMERICAL | spatial-slice mutual-information **proxy** — full IIT 4.0 의 *slice* 일 뿐 |
| **phi_rs** | Rust crate (NP-hard MIP all-partition exhaustive) | 🔵 SUPPORTED-FORMAL 후보 | full IIT 4.0 — cause-effect structure + exclusion postulate + Φ_max over MIP |

phi_spatial 의 known boundary (다수 H 위 직접 관측):
- **H_207 Kuramoto** (FALSIFIED) — full-lock K=5.0 위 phi_spatial peak (IIT integration-loss 미포착)
- **H_213 temporal-binding** (PARTIAL_DIRECTIONAL) — τ=40 boundary spike artefact (near-uniform state 위)
- **H_221 meditation-jhana** (FALSIFIED 1/3) — random uniform (Φ=0.590) vs rule-110 high-noise (Φ=0.589) 미구분
- **H_209 EEG 1/f β-sweep** (FALSIFIED) — β=0.5 peak instead of β=1
- **H_218 network-topology** (FALSIFIED, reverse) — scale-free Φ < ER Φ (sub-cluster artefact, freeze 가 Φ 증가시키는 node 존재)

이 5 negative direction 가 모두 *spatial-slice proxy 한계* 의 instance 일 가능성 — full
IIT 4.0 phi_rs 위 측정 시 verdict 가 뒤집힐 candidate.

## 제안 — Rust FFI shim path

### 옵션 A: cdylib C ABI export (recommended)

phi_rs Rust crate 를 `cdylib` crate-type 으로 빌드, C ABI 함수 export:

```rust
#[no_mangle]
pub extern "C" fn phi_rs_compute_phi(
    state_ptr: *const u8, n: usize, dim: usize,
    out_phi: *mut f64,
) -> i32 { /* ... */ }
```

hexa-lang 측 추가 builtin:

```hexa
// hypothetical
let phi = ffi_call_c_lib("libphi_rs.dylib", "phi_rs_compute_phi",
                        state, n, dim);
```

- 장점: 표준 Rust pattern · `pub extern "C"` 만 marking 필요 · dlopen / FFI 표준
- 단점: hexa-lang 에 C-ABI FFI primitive 자체 부재 (RFC 신설 필요)

### 옵션 B: subprocess + stdin/stdout JSON (fallback)

`phi_rs_cli` binary 가 stdin 으로 state 받고 stdout 으로 Φ 출력. hexa 측에서 `Command::run`
analog 로 호출.

- 장점: FFI primitive 부재 시도 가능 · zero ABI dependency
- 단점: per-call overhead (process spawn) · 대량 sweep 시 unusable

### 옵션 C: WebAssembly (cross-platform)

phi_rs → `wasm32-unknown-unknown` target compile. hexa-lang 측 wasm runtime 추가.

- 장점: cross-platform · sandboxed · OS 비의존
- 단점: hexa runtime 추가 부담 · wasm-bindgen Rust 의존성

## 측정 — full IIT 4.0 promote 시 expected gain

23 H × 평균 5 honest_limit-mention = 115+ "L1-L3 phi_rs blocker" carry 가 *단일 patch*
로 해결.

| H | current verdict | phi_rs 후 expected | 발견 strength |
|---|----------------|---------------------|---------------|
| H_007 | 🟢 SUPPORTED Class-IV peak | 🔵 SUPPORTED-FORMAL (full Φ_max) | medium |
| H_204 | 🟢 PARTIAL inverse-U | 🔵 if inverse-U holds with full Φ | high (★ cross-substrate ρ=1.0) |
| H_211 | 🟢 PARTIAL r=0.933 | 🔵 H × Φ-true correlation | high (IIT primitive) |
| H_207 | 🟢 FALSIFIED (boundary peak) | possibly INVERSED if full Φ catches integration loss | very high |
| H_213 | 🟢 PARTIAL_DIRECTIONAL (boundary spike) | possibly SUPPORTED if full Φ ≠ near-uniform-artefact | high |
| H_221 | 🟢 FALSIFIED 1/3 (random=noise indistinguishable) | possibly recovers silence > random distinction | medium |
| H_218 | 🟢 FALSIFIED (reverse) | possibly inverts if full Φ catches hub-integration | medium |

5+ FALSIFIED 또는 PARTIAL 결과의 *re-tier 가능* — verdict landscape 전체 shift 후보.

## 우선순위 근거

- **23+ H 동시 unblock** — leverage 매우 큼 (per-H 따로 fix 불가능, primitive 단일 origin)
- **dancinlab/anima HEXAD/LIFE 의 7-domain 모든 axis 에 phi 측정 의존** (universe/life/consciousness/physics/substrate/math/biology)
- **anima 의 substrate-Φ ratchet (ConsciousnessEngine.Φ input)** 도 동일 primitive 사용 → 본 patch 가 anima runtime 의 Φ-quality 도 직접 향상

## hexa-lang upstream 측 결정 권장

1. RFC 신설 (FFI primitive · C ABI · cdylib loading)
2. phi_rs Rust crate 의 cdylib build target 추가
3. hexa builtin `phi_rs_*` family (옵션 A path) 또는 wasm runtime (옵션 C)
4. 기존 RFC 036 phi_spatial 은 *proxy* 로 명시적 유지 (빠른 dev cycle 용), phi_rs 는 *formal* path

## 본 inbox 의 sender 결정 권장

- option A 가 recommend — Rust standard cdylib 가 가장 직접 path
- option B 는 prototype/CI-only fallback
- option C 는 cross-platform 이 필수 시점 후순위

## Cross-link

- RFC 036 `phi_spatial` (hexa-lang) — 본 proxy 의 source spec
- dancinlab/anima/HEXAD/LIFE/ — 23+ H 의 honest-limit anchor
- dancinlab/anima/HEXAD/CHECK/ — verification frontier (Φ / IIT / closed-form)
- TECS-L rubric — 🔵 ≠ 🟢 distinction (`hexa verify rubric`)

본 inbox 는 *patch design draft*, RFC 신설 / 구현 결정은 hexa-lang maintainer 의 권한.
proposal-tier — 본 entry 가 RFC promote 또는 patch land 되면 dancinlab/anima 측 23+ H
의 verdict 재측정 가능.
