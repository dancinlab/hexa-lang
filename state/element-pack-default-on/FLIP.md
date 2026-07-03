# element-pack default-ON flip — HEXA_PACK_ARRAY polarity 전환 (wire-to-prod)

HEXA-UNBOX 캠페인 · branch `perf/element-pack-default-on` · 2026-06-28 · **PR→CI 게이트 (verdict pending)**

## 무엇을 / 왜

머지·soundness-검증 완료된 **9.78× element-pack fused 레버**(#4114: raw-8B storage ⊕ r2c
index-unbox ⊕ R5b/r6 scalar-op unbox 三일체)는 `HEXA_PACK_ARRAY=1` **opt-in default-OFF**
이라 production 에서 아무도 켜지 않아 **dead** 였다. commons `wire-to-prod` — "production
배선까지가 완료, 미배선 = dead until wired". 캠페인의 실제 런타임 가속은 이 flip 으로만 실현된다.

`native-canonical-default` 폴라리티: 기본 경로 = hexa-native packed, 외부/legacy 제약은
opt-OUT 플래그. → `HEXA_PACK_ARRAY` 를 **default-ON, opt-OUT via `=0`** 로 전환.

## FLIP — 3 로직라인 (`== "1"` → `!= "0"`) + 주석

| 위치 | 함수 | 역할 |
|---|---|---|
| `compiler/codegen/x86_64_linux.hexa:1486` | `_pack_array_enabled()` | codegen consumer (packed 경로 게이트) |
| `compiler/lower/hir_to_mir.hexa:225` | `_arru_native_enabled()` | type_id 101..104 stamping (element-kind 신호) |
| `compiler/lower/hir_to_mir.hexa:277` | `_arrpk_fuse_enabled()` | element-type THREADING (index-dst/let-copy/binop-result) |

`HEXA_PACK_ESCAPING`(#4140/#4158 descriptor-discriminator escaping lane)은 **opt-in 유지** —
별 레버이며 perf 미측정. default-ON 대상은 비-escaping 9.78× 레버뿐.

## 런타임 링크 정합 (검증)

비-escaping packed descriptor `hexa_arr_i64_new/push/len/get/set` + `HexaArrI64` typedef 는
`self/runtime_core_emit.hexa` 에서 **unguarded** emit (L2603-2638, `#ifdef HEXA_PACK_ESCAPING`
블록 L2647 이전) → default runtime.a/runtime.h 에 이미 존재 → default-ON codegen 콜 링크 OK.
(escaping `*_esc` mint + poly-readers 만 `#ifdef HEXA_PACK_ESCAPING` 뒤·opt-in 유지.)

## 안전 근거 (escape-soundness + determinism, 이미 측정됨)

- **#4121 transitive alias-coherence fixpoint**: per-local→alias-set 전이 void(V8 PACKED→HOLEY)
  → escape-stress **9/9 OFF==ON bit-exact**(ka 4096·kc alias·kg/kh PASS).
- **PACK-ON full-compiler self-emit byte-identical determinism** (2 witness, sha c831d969 /
  4dca7b23, ENCODE-MISS=0) — 즉 PACK-ON 에서 gen3≡gen4 fixpoint 성립 증거.
- **x86_64 codegen 전용**: arm64/gen2/nvptx no-op (escape-relax no-op sound by construction).
- **byte-OUT**: `HEXA_PACK_ARRAY=0` 이면 lattice `[]` → pre-flip origin 과 byte-identical
  (폴라리티만 반전, 기본값이 packed).

## GATE (release-integrity > self-host · 머지 전 필수)

mini = git/gh only → 로컬 byteeq 빌드 불가 → **PR 열어 정규 CI 로 검증**:
- selfhost byte-eq 3타깃 (darwin-arm64 · linux-arm64 · linux-x86_64)
- determinism · miscompile-zero · codegen-guard · faithful-nobaseline ×3
- nvptx · 출하 smoke
- **Blacksmith 아님** (#4016 revert · CI=무료 github-hosted + self-hosted pool 유지)

**3타깃 byteeq + smoke GREEN 전 머지 금지.** GREEN → 캠페인 wire-to-prod 종결(9.78× production
default). RED → root-cause (PACK-ON fixpoint 발산점 특정).

## verdict — PENDING (CI 결과 대기)

SSOT = memory `project_hexa_runtime_gap_allclosure`.
