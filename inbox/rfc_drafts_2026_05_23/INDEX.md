# rfc_drafts_2026_05_23 — INDEX

> 3 design-draft RFCs (RFC 081 · 082 · 083) — HEXA-LANG.md "Deferred RFC 사이클"
> 의 RFC 후보 1·2·3 design + decision input 단계.
>
> 각 RFC 는 implementation 전 design 단계 — 핵심 결정 포인트 (Dn) 가
> 표 형태로 enumerate 되어 있고 권고가 명시되어 있음. 사용자 결정 후 별도
> `rfc_<n>_impl_*` 시리즈로 implementation 분기.

## Summary

| RFC | 영역 | 결정 포인트 | 권고 default | 상태 |
|---|---|---|---|---|
| **081** | Option / Result lane | 6 (D1-D6) | A/A/A/A·B follow-up/A/B | design-draft |
| **082** | trait operator overload | 7 (D1-D7) | A/A/공식표 참조/A/C/A/deferred | design-draft |
| **083** | TLS primitive | 7 (D1-D7) | D/C/A/A/A+B/A/B | design-draft |

## design-draft — decision input 대기

- **rfc_081** — Option / Result lane (canonical-audit round-3). Severity: HIGH. trait-인접 (D4 boxed error 는 RFC 082 의존). 6 decision pt.
- **rfc_082** — trait operator overload (canonical-audit round-7). Severity: HIGH. dispatch model (D1) 가 가장 큰 결정 — 권고 static-only v1. 7 decision pt.
- **rfc_083** — TLS primitive. Severity: HIGH. 가장 큰 결정은 D1 (TLS 라이브러리 선택) — 권고 system 동적 링크. 7 decision pt.

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
```

## 참고

- 본 디렉토리 모든 RFC 의 source: [[HEXA-LANG.md]] §"Deferred RFC 사이클"
- 인접 RFC: [[rfc_074_enum_multi_field_payload]] (enum payload lowering — RFC 081 의존)
- 사전 RFC 위치: `inbox/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md` (최신 numbering 기준)
