# rfc_drafts_2026_05_23 — INDEX

> 4 design-draft RFCs (RFC 081 · 082 · 083 · 084) — HEXA-LANG.md "Deferred RFC 사이클"
> 의 RFC 후보 1·2·3 + dancinlab/anima HEXAD/LIFE 23+ H 공통 blocker (phi_rs FFI shim)
> design + decision input 단계.
>
> 각 RFC 는 implementation 전 design 단계 — 핵심 결정 포인트 (Dn) 가
> 표 형태로 enumerate 되어 있고 권고가 명시되어 있음. 사용자 결정 후 별도
> `rfc_<n>_impl_*` 시리즈로 implementation 분기.

## Summary — D1-D7 ALL DECIDED 2026-05-23 · RFC 084 추가 2026-05-24

| RFC | 영역 | 결정 (D1-Dn) | 상태 |
|---|---|---|---|
| **081** | Option / Result lane | A · A · A · A v1 · A · B | 🟢 design complete · impl 진입 가능 |
| **082** | trait operator overload | A v1 · A · D3a=NO/D3b=YES · A · C · A · deferred | 🟢 design complete · impl phase a scaffold 진입 가능 |
| **083** | TLS primitive | D · C · A+C · A v1/B follow-up · A+B opt-in · A · B | 🟢 design complete · impl 진입 가능 (RFC 081 D4 의존 해소 후) |
| **084** | phi_rs FFI shim (option A cdylib) | C · A · B · A · A · A · B | 🟢 design complete · impl_a (upstream cabi) 진입 가능 · impl_b (wrapper) RFC 081 후 |

## Cross-RFC dependency 해소 상태

```
RFC 082 D1 (static only) ────── 🟢 결정 → impl phase a 직접 진입 가능
RFC 081 D4 (Result<T,E> generic) ────── 🟢 결정 → RFC 081 impl 가능 (RFC 082 후 alias 추가)
RFC 083 D4 (opaque handle API) ────── 🟢 결정 → RFC 081 Result lane 사용
```

## design-draft — decision input 대기

- **rfc_081** — Option / Result lane (canonical-audit round-3). Severity: HIGH. trait-인접 (D4 boxed error 는 RFC 082 의존). 6 decision pt.
- **rfc_082** — trait operator overload (canonical-audit round-7). Severity: HIGH. dispatch model (D1) 가 가장 큰 결정 — 권고 static-only v1. 7 decision pt.
- **rfc_083** — TLS primitive. Severity: HIGH. 가장 큰 결정은 D1 (TLS 라이브러리 선택) — 권고 system 동적 링크. 7 decision pt.
- **rfc_084** — phi_rs FFI shim · option A cdylib (`phi-rs-rust-ffi-shim.md` proposal-tier 의 promote). Severity: HIGH. 23+ H 공통 blocker · D1 (cabi 범위 — full signature with spatial-only dispatch 권고) 가 핵심. 7 decision pt. RFC 036 part 2 의 named blocker 와 일대일 매칭.

## 결정 순서 권고

세 RFC 가 cross-reference 있음. 권고 결정 순서:

1. **RFC 082** D1 (dispatch model) — Static-only vs dyn 동시
2. **RFC 081** D4 (boxed error) — RFC 082 D1 결과에 의존
3. **RFC 081** D1-D3, D5, D6 — 나머지 (가장 광범위 corpus 영향)
4. **RFC 082** D2-D7 (D1 외 나머지)
5. **RFC 083** D1 (TLS lib 선택) — 보안 영향 가장 큼
6. **RFC 083** D2-D7

## Implementation 분기 (각 RFC 결정 확정 후)

- `rfc_081_impl_a..e` (5 phase)
- `rfc_082_impl_a..g` (7 phase)
- `rfc_083_impl_a..g` (7 phase)
- `rfc_084_impl_a..e` (5 phase — upstream cabi · hexa wrapper · falsifier corpus · RFC 036 honesty gate 전환 · anima 23+ H 재측정 cycle)

## Cross-RFC dependency

```
RFC 082 (trait)  ─── D1 dispatch model 결정 ───┐
                                                 ▼
RFC 081 (Option/Result) ─ D4 (boxed error) ─── trait 의존
        │
        ▼ Result type 사용
RFC 083 (TLS primitive) ─ Result<T, TlsError> API
        │
        ▼ D4 follow-up
        method-bearing builtin struct ── trait 의존 (다시 RFC 082)

RFC 081 (Option/Result) ────────────────────┐
        │                                    ▼
        └─ Option<float> 시그니처 ─── RFC 084 (phi_rs FFI shim) D3=B wrapper
                                              │
                                              ▼ D5=A (impl_a 우선 land, wrapper 후)
                                              upstream phi_rs Rust crate 측 src/cabi.rs
                                              (hexa-lang corpus 영향 0 · stdlib/c_ffi 위에서 binding)
```

## 참고

- 본 디렉토리 모든 RFC 의 source: [[HEXA-LANG.md]] §"Deferred RFC 사이클"
- 인접 RFC: [[rfc_074_enum_multi_field_payload]] (enum payload lowering — RFC 081 의존)
- 사전 RFC 위치: `inbox/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md` (최신 numbering 기준)
