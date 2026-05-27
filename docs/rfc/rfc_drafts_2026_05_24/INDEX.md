# rfc_drafts_2026_05_24 — INDEX

> 6 design-draft RFCs (RFC 084 · 085 · 086 · 087 · 088 · 089) — 본 catalog 의 사이클은
> 2026-05-24 일자 cycle 1-10 에서 promote/file 된 RFC 묶음이다.
>
> 각 RFC 는 implementation 전 design 단계 — 핵심 결정 포인트 (Dn) 가
> 표 형태로 enumerate 되어 있고 권고 + falsifier 가 명시되어 있음.
> 사용자 결정 후 별도 `rfc_<n>_impl_*` 시리즈로 implementation 분기.
>
> 본 INDEX 의 의의: 6 RFC 는 각각 독립 PR 로 filed 되었고 (lane fan-out 결과),
> catalog 가 없으면 PROBE / next-cycle 에서 cross-link 추적이 어렵다. INDEX 는
> 단일 진입점 (slug · PR# · 한 줄 요약 · cross-link) 을 제공한다.
>
> **갱신 이력**: cycle 1-5 catalog 가 [PR #564](https://github.com/dancinlab/hexa-lang/pull/564) 로 086-087 + 084/085/088 cross-link entry 를 filed. cycle 6-10 batch (RFC 076 lane 측정 + RFC 088 filed + RFC 089 filed) 가 본 update 의 대상이다. cycle 11 lane 2 RFC 090 (firmware+RTL codegen) 은 scaffold 단계 (`inbox/rfc_090_target_firmware_rtl-2026-05-24` 브랜치) — 미파일.

## Summary — 본 사이클 6 RFC

| RFC | slug | 영역 | status | priority | filed_at | PR | 한 줄 요약 |
|---|---|---|---|---|---|---|---|
| **084** | `phi_rs_ffi_shim` | FFI (Rust cdylib · C-ABI) | proposed (design-draft) | high | 2026-05-24 | [#546](https://github.com/dancinlab/hexa-lang/pull/546) | `phi_rs` option A (cdylib C-ABI export) 정식 promote — 23+ HEXAD/LIFE H 가설 공통 blocker 단일 patch 해소 후보 |
| **085** | `dispatcher_hygiene` | cross-host dispatcher | proposed (design-draft) | high (P1) | 2026-05-24 | [#552](https://github.com/dancinlab/hexa-lang/pull/552) | RFC 026 (env passthrough + `.hexarc`) + RFC 028 (`--local` / `HEXA_NO_REMOTE`) 통합 promote — silent offload + env loss 해소 |
| **086** | `atlas_memcap_unblock` | atlas SSOT | proposed | high | 2026-05-24 | [#558](https://github.com/dancinlab/hexa-lang/pull/558) | `n6/atlas.n6` 단일 SSOT 시대의 stdlib `AtlasView` 물질화 — RFC 066 paradigm-shift 후속 |
| **087** | `macro_expander_pass` | parser + macro | proposed (design-draft) | medium | 2026-05-24 | [#556](https://github.com/dancinlab/hexa-lang/pull/556) | Phase 2 user-defined macro expander + hygiene + recursion limit — Phase 1 (PR #419/#451/#462) LANDED 후속 |
| **088** | `hexa_cloud_preflight` | hexa-cloud / GPU dispatch | proposed (design-draft) | medium | 2026-05-24 | [#563](https://github.com/dancinlab/hexa-lang/pull/563) | hexa-cloud preflight + typed env-var — closed-form GPU mem-budget 사전체크 + dispatch env 정합 |
| **089** | `ld_shared_dlopen` | compiler/link · runtime dlopen | proposed (design-draft) | high | 2026-05-24 | [#580](https://github.com/dancinlab/hexa-lang/pull/580) | RFC 070 (`hexa_ld --shared` + runtime `dlopen`) 정식 번호 promote + 잔여 phase 정리 — wilson plugin 동적 로딩 unblocker, `stdlib/c_ffi.hexa` 와 방향 반대 (consume vs produce+consume) |

## design-draft — decision input 대기

- **rfc_084** — `phi_rs` FFI shim (option A cdylib). Severity: HIGH (23+ H 공통 blocker · anima Phase 7 safety ratchet 정합). Source = `docs/rfc/rfc_drafts_2026_05_12/phi-rs-rust-ffi-shim.md` proposal-tier 의 option A 만 정식 promote. Range ~150 LOC Rust + ~80 LOC hexa-lang stdlib. 7 decision pt (D1-D7) · 5 falsifier (BUILD · LOAD · CALL · BYTE-EQUAL vs in-tree C replica · TIER-PROMOTE-PROOF). Note: 파일 위치는 [`docs/rfc/rfc_drafts_2026_05_23/rfc_084_phi_rs_ffi_shim.md`](../rfc_drafts_2026_05_23/rfc_084_phi_rs_ffi_shim.md) (slug 이 RFC 083 인접 promote 의 자연 후속이라 numbering 만 2026-05-24).
- **rfc_085** — dispatcher hygiene (RFC 026 + 028 통합). Severity: HIGH (cross-host UX · silent offload pain). 두 RFC 는 dispatch 의 passing surface (026) + gating surface (028) 로 같은 도메인. 5 falsifier (ENV-PASS · HEXARC-LOAD · LOCAL-FLAG · NOREMOTE-ENV · SILENT-OFFLOAD-WARN). Cross-link: `[[feedback_resource_routing_ubu]]` + `[[reference_hexa_module_loader_env_2026_05_20]]`.
- **rfc_086** — atlas memcap unblock. Severity: HIGH (atlas SSOT paradigm-shift 후속). RFC 066 (`docs/rfc/rfc_drafts_2026_05_20/rfc_066_atlas_memcap_unblock.md`) 의 SSOT 가 hxc → `n6/atlas.n6` 로 shift 된 후 stdlib `AtlasView` 물질화가 미정합. governance `@D h_atlas_single_export` 정합 패치. Cross-link: `[[project_atlas_hxc_irreplaceable_ssot]]` (2026-05-22 SSOT shift).
- **rfc_087** — macro-expander pass (Phase 2). Severity: MEDIUM. Phase 1 (parse-time fail-loud + `println!`/`panic!`/`vec!` intrinsics) 는 PR #419 + PR #462 + PR #451 (Phase 1 design stub) LANDED. 본 RFC = user-defined macro expander + gensym hygiene + recursion limit. PR #493 inbox patch open 상태에서 정식 RFC 로 promote. Single-cycle Phase 2a 우선 → 후속 Phase 2b-2e 5-PR stack 권고.
- **rfc_088** — hexa-cloud preflight + typed env-var. Severity: MEDIUM. closed-form GPU mem-budget 사전체크 + dispatch env-var typed 정합. cycle 5 lane 4 PR #563 filed → merged 2026-05-23. cross-link: `[[project_stdlib_cloud_cycle_a]]` (stdlib/cloud structured-argv dispatch).
- **rfc_089** — `hexa_ld --shared` + runtime `dlopen` (RFC 070 promote). Severity: HIGH (wilson "core + N plugin" 의 재컴파일 0 경로 unblocker). cycle 7 lane filed → PR #580 머지. **§5 audit**: codegen `--shared` emit-body (GOT-load) + CLI-wire + `link_shared` ET_DYN/MH_DYLIB + capability/ABI 게이트 skeleton 모두 LANDED — 잔여 = runtime host surface (G7-C `hexa_dlopen`/`dlsym`/`dlclose`/`dlerror` + `stdlib/dynlink.hexa`) + visibility 좁히기 (G7-A.native impl.visibility, 단일 `.globl`) + `@plugin` parser + section emit (G7-D.impl). **`stdlib/c_ffi.hexa` 와 경계**: c_ffi = 외부 libc-ABI `.so` consume / RFC 089 = hexa-emit `.so` produce+consume + nanbox 단일-심볼 dispatch — 방향이 반대. Cross-link: `[[reference_hexa_module_loader_env_2026_05_20]]` · `archive/patches/g7-hexa-ld-dlopen.md` · `docs/rfc/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md`.

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

RFC 089 (ld --shared + dlopen) ─── RFC 070 promote → wilson plugin 동적 로딩 unblocker
                                            │
                                            ▼ G7-C runtime host surface + visibility + G7-D.impl
```

본 6 RFC 는 cross-reference 가 약함 — 각각 독립 결정 가능. 권고 결정 순서:

1. **RFC 086** (atlas memcap) — SSOT 정합 가장 시급 (이미 paradigm-shift 됨)
2. **RFC 085** (dispatcher hygiene) — cross-host 사용자 UX (silent offload 통증)
3. **RFC 089** (ld --shared + dlopen) — RFC 070 substantial progress 잔여 phase, wilson plugin 경로
4. **RFC 087** (macro Phase 2) — Phase 1 LANDED 후속 stack 진입
5. **RFC 088** (cloud preflight) — GPU dispatch UX 보강
6. **RFC 084** (phi_rs FFI) — upstream Rust crate 의존 (가장 외부 dep)

## Implementation 분기 (각 RFC 결정 확정 후)

- `rfc_084_impl_a` (upstream cabi) · `rfc_084_impl_b` (hexa-side wrapper) · `rfc_084_impl_c` (falsifier corpus)
- `rfc_085_impl_a..e` (env allowlist · .hexarc loader · --local flag · diagnostic · --local-or-fail)
- `rfc_086_impl_a..` (AtlasView 물질화 phase TBD per RFC 본문)
- `rfc_087_impl_a` (Phase 2a single-cycle) → `rfc_087_impl_b..e` (Phase 2b-2e stack: 2b expand · 2c hygiene · 2d recursion-limit · 2e diagnostics)
- `rfc_088_impl_a..` (preflight oracle + typed env-var, phase TBD)
- `rfc_089_impl_a` (G7-C runtime host surface — `hexa_dlopen`/`dlsym`/`dlclose`/`dlerror` + `stdlib/dynlink.hexa`) · `rfc_089_impl_b` (G7-A visibility 좁히기 — `.hidden`/`.private_extern` 디폴트 + 단일 `.globl`) · `rfc_089_impl_c` (G7-D.impl — `@plugin` parser + section emit + `dynlink_caps` 게이트 wiring) · `rfc_089_impl_d` (falsifier corpus — SHARED-EMIT · DLOPEN-LOAD · SINGLE-SYMBOL-DISPATCH · CROSS-PLATFORM · NO-LLVM)

## 본 디렉토리 구성

```
docs/rfc/rfc_drafts_2026_05_24/
├── INDEX.md                                          ← 본 파일
├── rfc_076_non_pow2_adaptive_tile_scheduling.md      ← (PR #574) · 별도 lineage (GPU SGEMM perf)
├── rfc_085_dispatcher_hygiene.md                     ← lane 2 (PR #552)
├── rfc_086_atlas_memcap_unblock.md                   ← lane 3 (PR #558)
├── rfc_087_macro_expander_pass.md                    ← lane 2 (PR #556)
├── rfc_088_hexa_cloud_preflight.md                   ← lane 4 (PR #563)
└── rfc_089_ld_shared_dlopen.md                       ← cycle 7 lane (PR #580)
```

추가 RFC 파일 위치 (히스토리 이유로 본 디렉토리 외부):

```
docs/rfc/rfc_drafts_2026_05_23/
└── rfc_084_phi_rs_ffi_shim.md            ← lane 1 (PR #546) · 위치 _05_23 (RFC 083 인접 promote)
```

**진행 중 (미파일)**: RFC 090 (firmware+RTL codegen, cycle 11 lane 2) — 브랜치 `inbox/rfc_090_target_firmware_rtl-2026-05-24` 만 scaffold 상태, RFC 본문/PR 없음. PR filed 후 본 INDEX 를 update 한다.

## 추가 RFC (별도 lineage — GPU SGEMM perf)

본 catalog (084-089) 와 lineage 가 다른 design-draft. numbering 은 첫 빈
슬롯 (076; 084-089 보다 앞) 을 채운다.

| RFC | slug | 영역 | status | priority | filed_at | PR | 한 줄 요약 |
|---|---|---|---|---|---|---|---|
| **076** | `non_pow2_adaptive_tile_scheduling` | GPU SGEMM (RFC 067 N201 후속) | proposed (design-draft) | medium | 2026-05-24 | [#574](https://github.com/dancinlab/hexa-lang/pull/574) | RFC 067 N201 9-shape sweep 의 M=384 ratio dip (0.8930, 다른 8 shape >= 0.93) 의 근본원인 3복합 (Hilbert padding idle 43.8% · K_TILES_OUTER non-2^k · 고정 64x64 vs cuBLAS adaptive) → 설계 옵션 A/B/C + 권고 B (raster fallback) + falsifier (M=384 ratio >= 0.93 AND 회귀 0) |

- **rfc_076** — non-2^k adaptive tile scheduling. Severity: MEDIUM
  (M=384-특이 perf dip · design only). Source = RFC 067 fire
  `archive/fires/rfc067_ptma_swizzle128_2026_05_22/` (notes.md + result.json,
  cycle 4 E · PR #540). 권고 = 옵션 B (Hilbert padding 제거 / raster
  fallback, 회귀 위험 최저). primary falsifier = F-RFC076-B-M384-RATIO
  (>= 0.93) AND F-RFC076-B-NO-REGRESS (다른 8 shape 회귀 0). Cross-link:
  `[[reference_gpu_fire_infra]]` · `[[reference_ptx_diff_perf_oracle]]` ·
  `[[feedback_instrument_first_methodology]]`.

## 참고

- 본 디렉토리 모든 RFC 의 source: 각 RFC 의 `Source` 필드 + cross-link memory
- 사전 INDEX: [`docs/rfc/rfc_drafts_2026_05_23/INDEX.md`](../rfc_drafts_2026_05_23/INDEX.md) — RFC 081-083
- 사전 INDEX (오래된): [`docs/rfc/rfc_drafts_2026_05_12/INDEX.md`](../rfc_drafts_2026_05_12/INDEX.md) — RFC 024-048
- RFC 066 (RFC 086 supersedes): `docs/rfc/rfc_drafts_2026_05_20/rfc_066_atlas_memcap_unblock.md`
- governance: `@D g_atlas_binary_builtin` · `@D h_atlas_single_export` · `@D g6 citation-enforced-strict-lint`
