# rfc_drafts_2026_05_24 — INDEX

> 5 design-draft RFCs (RFC 084 · 085 · 086 · 087 · 088) — 본 catalog 의 사이클은
> 2026-05-24 일자 cycle 1-5 에서 promote/file 된 RFC 묶음이다.
>
> 각 RFC 는 implementation 전 design 단계 — 핵심 결정 포인트 (Dn) 가
> 표 형태로 enumerate 되어 있고 권고 + falsifier 가 명시되어 있음.
> 사용자 결정 후 별도 `rfc_<n>_impl_*` 시리즈로 implementation 분기.
>
> 본 INDEX 의 의의: 5 RFC 는 각각 독립 PR 로 filed 되었고 (lane fan-out 결과),
> catalog 가 없으면 PROBE / next-cycle 에서 cross-link 추적이 어렵다. INDEX 는
> 단일 진입점 (slug · PR# · 한 줄 요약 · cross-link) 을 제공한다.

## Summary — 본 사이클 5 RFC

| RFC | slug | 영역 | status | priority | filed_at | PR | 한 줄 요약 |
|---|---|---|---|---|---|---|---|
| **084** | `phi_rs_ffi_shim` | FFI (Rust cdylib · C-ABI) | proposed (design-draft) | high | 2026-05-24 | [#546](https://github.com/dancinlab/hexa-lang/pull/546) | `phi_rs` option A (cdylib C-ABI export) 정식 promote — 23+ HEXAD/LIFE H 가설 공통 blocker 단일 patch 해소 후보 |
| **085** | `dispatcher_hygiene` | cross-host dispatcher | proposed (design-draft) | high (P1) | 2026-05-24 | [#552](https://github.com/dancinlab/hexa-lang/pull/552) | RFC 026 (env passthrough + `.hexarc`) + RFC 028 (`--local` / `HEXA_NO_REMOTE`) 통합 promote — silent offload + env loss 해소 |
| **086** | `atlas_memcap_unblock` | atlas SSOT | proposed | high | 2026-05-24 | [#558](https://github.com/dancinlab/hexa-lang/pull/558) | `n6/atlas.n6` 단일 SSOT 시대의 stdlib `AtlasView` 물질화 — RFC 066 paradigm-shift 후속 |
| **087** | `macro_expander_pass` | parser + macro | proposed (design-draft) | medium | 2026-05-24 | [#556](https://github.com/dancinlab/hexa-lang/pull/556) | Phase 2 user-defined macro expander + hygiene + recursion limit — Phase 1 (PR #419/#451/#462) LANDED 후속 |
| **088** | `hexa_cloud_preflight` | hexa-cloud / GPU dispatch | proposed (in-flight) | medium | 2026-05-24 | TBD (lane 4 진행 중) | hexa-cloud preflight + typed env-var — closed-form GPU mem-budget 사전체크 + dispatch env 정합 |

## design-draft — decision input 대기

- **rfc_084** — `phi_rs` FFI shim (option A cdylib). Severity: HIGH (23+ H 공통 blocker · anima Phase 7 safety ratchet 정합). Source = `inbox/rfc_drafts_2026_05_12/phi-rs-rust-ffi-shim.md` proposal-tier 의 option A 만 정식 promote. Range ~150 LOC Rust + ~80 LOC hexa-lang stdlib. 7 decision pt (D1-D7) · 5 falsifier (BUILD · LOAD · CALL · BYTE-EQUAL vs in-tree C replica · TIER-PROMOTE-PROOF). Note: 파일 위치는 [`inbox/rfc_drafts_2026_05_23/rfc_084_phi_rs_ffi_shim.md`](../rfc_drafts_2026_05_23/rfc_084_phi_rs_ffi_shim.md) (slug 이 RFC 083 인접 promote 의 자연 후속이라 numbering 만 2026-05-24).
- **rfc_085** — dispatcher hygiene (RFC 026 + 028 통합). Severity: HIGH (cross-host UX · silent offload pain). 두 RFC 는 dispatch 의 passing surface (026) + gating surface (028) 로 같은 도메인. 5 falsifier (ENV-PASS · HEXARC-LOAD · LOCAL-FLAG · NOREMOTE-ENV · SILENT-OFFLOAD-WARN). Cross-link: `[[feedback_resource_routing_ubu]]` + `[[reference_hexa_module_loader_env_2026_05_20]]`.
- **rfc_086** — atlas memcap unblock. Severity: HIGH (atlas SSOT paradigm-shift 후속). RFC 066 (`inbox/rfc_drafts_2026_05_20/rfc_066_atlas_memcap_unblock.md`) 의 SSOT 가 hxc → `n6/atlas.n6` 로 shift 된 후 stdlib `AtlasView` 물질화가 미정합. governance `@D h_atlas_single_export` 정합 패치. Cross-link: `[[project_atlas_hxc_irreplaceable_ssot]]` (2026-05-22 SSOT shift).
- **rfc_087** — macro-expander pass (Phase 2). Severity: MEDIUM. Phase 1 (parse-time fail-loud + `println!`/`panic!`/`vec!` intrinsics) 는 PR #419 + PR #462 + PR #451 (Phase 1 design stub) LANDED. 본 RFC = user-defined macro expander + gensym hygiene + recursion limit. PR #493 inbox patch open 상태에서 정식 RFC 로 promote. Single-cycle Phase 2a 우선 → 후속 Phase 2b-2e 5-PR stack 권고.
- **rfc_088** — hexa-cloud preflight + typed env-var. Severity: MEDIUM. closed-form GPU mem-budget 사전체크 + dispatch env-var typed 정합. cycle 5 lane 4 진행 중 — PR 번호 미부여. cross-link: `[[project_stdlib_cloud_cycle_a]]` (stdlib/cloud structured-argv dispatch).

## Cross-RFC dependency 해소 상태

```
RFC 084 (phi_rs FFI shim) ─── independent → 단일 patch upstream (Rust crate + hexa stdlib wrapper)
                                            │
                                            ▼ 23+ H downstream tier promote (verdict propagation)

RFC 085 (dispatcher hygiene) ─── independent → env-var allowlist + .hexarc + --local 다섯 falsifier
                                            │
                                            ▼ `[[feedback_resource_routing_ubu]]` 정합

RFC 086 (atlas memcap unblock) ─── @D h_atlas_single_export 정합 → stdlib AtlasView 물질화
                                            │
                                            ▼ RFC 065 / RFC 080 (LANDED) 와 cross-link

RFC 087 (macro-expander Phase 2) ─── Phase 1 LANDED (PR #419/#451/#462) → Phase 2 stack 진입
                                            │
                                            ▼ Phase 2a single-cycle → 2b-2e 5-PR stack 권고

RFC 088 (hexa-cloud preflight) ─── stdlib/cloud structured-argv 정합 → closed-form GPU mem-budget oracle
                                            │
                                            ▼ runpod / vast / ssh dispatch lane 모두 적용
```

본 5 RFC 는 cross-reference 가 약함 — 각각 독립 결정 가능. 권고 결정 순서:

1. **RFC 086** (atlas memcap) — SSOT 정합 가장 시급 (이미 paradigm-shift 됨)
2. **RFC 085** (dispatcher hygiene) — cross-host 사용자 UX (silent offload 통증)
3. **RFC 087** (macro Phase 2) — Phase 1 LANDED 후속 stack 진입
4. **RFC 088** (cloud preflight) — GPU dispatch UX 보강
5. **RFC 084** (phi_rs FFI) — upstream Rust crate 의존 (가장 외부 dep)

## Implementation 분기 (각 RFC 결정 확정 후)

- `rfc_084_impl_a` (upstream cabi) · `rfc_084_impl_b` (hexa-side wrapper) · `rfc_084_impl_c` (falsifier corpus)
- `rfc_085_impl_a..e` (env allowlist · .hexarc loader · --local flag · diagnostic · --local-or-fail)
- `rfc_086_impl_a..` (AtlasView 물질화 phase TBD per RFC 본문)
- `rfc_087_impl_a` (Phase 2a single-cycle) → `rfc_087_impl_b..e` (Phase 2b-2e stack: 2b expand · 2c hygiene · 2d recursion-limit · 2e diagnostics)
- `rfc_088_impl_a..` (preflight oracle + typed env-var, phase TBD)

## 본 디렉토리 구성

```
inbox/rfc_drafts_2026_05_24/
├── INDEX.md                              ← 본 파일
├── rfc_086_atlas_memcap_unblock.md       ← lane 3 (PR #558)
└── rfc_087_macro_expander_pass.md        ← lane 2 (PR #556)
```

추가 RFC 파일 위치 (히스토리 이유로 본 디렉토리 외부):

```
inbox/rfc_drafts_2026_05_23/
└── rfc_084_phi_rs_ffi_shim.md            ← lane 1 (PR #546) · 위치 _05_23 (RFC 083 인접 promote)

inbox/rfc_drafts_2026_05_24/
└── rfc_085_dispatcher_hygiene.md         ← lane 2 (PR #552) · PR diff 에는 _05_24 추가 확인
```

RFC 088 은 cycle 5 lane 4 진행 중이라 파일 미생성. PR filed 후 본 INDEX 를 update 한다.

## 참고

- 본 디렉토리 모든 RFC 의 source: 각 RFC 의 `Source` 필드 + cross-link memory
- 사전 INDEX: [`inbox/rfc_drafts_2026_05_23/INDEX.md`](../rfc_drafts_2026_05_23/INDEX.md) — RFC 081-083
- 사전 INDEX (오래된): [`inbox/rfc_drafts_2026_05_12/INDEX.md`](../rfc_drafts_2026_05_12/INDEX.md) — RFC 024-048
- RFC 066 (RFC 086 supersedes): `inbox/rfc_drafts_2026_05_20/rfc_066_atlas_memcap_unblock.md`
- governance: `@D g_atlas_binary_builtin` · `@D h_atlas_single_export` · `@D g6 citation-enforced-strict-lint`
