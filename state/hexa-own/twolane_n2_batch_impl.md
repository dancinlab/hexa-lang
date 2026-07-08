# 2-lane N2 batch — RUNG-1 (builtin bool/f64 infer) + RUNG-2 (HX3045 E0384)

branch: `feat/types-2lane-n2-batch` (off origin/main 6f4117c07, post #4722/#4724)

## RUNG-1 — types.hexa builtin-method-ret bool/f64 inference (byteeq-neutral)
`_types_builtin_method_ret` (compiler/check/types.hexa) 에 6 arm 추가:
`has_key`/`contains_key`/`has`/`any`/`all` → `_types_t_bool()`, `mean` → `_types_t_f64()`.
새 진단 코드 없음 — 태그가 기존 HX3011/HX3003/HX3004 (E0308) assignability 검사로 흐름.
docstring `mean (array-only)` 과대보수 제외 삭제.

reference-match 재확인 (전 arm bool/f64 receiver-independent):
- contains_key/has_key/has → self/codegen.hexa:6042/6045/6050 `hexa_bool(hexa_map_contains_key(...))`
- any/all → codegen 6111/6114 → runtime_emit hexa_array_any/all: 전 경로 hexa_bool;
  map-delegate arms hexa_map_any/hexa_map_all 도 전 emitter(runtime_core_emit 4597/4602 #if·#else,
  native rtcore_map-query-dispatch_emit 137/142)에서 hexa_bool → receiver-independent 확인
- mean → codegen 6265 → runtime_emit hexa_array_mean: non-array fallback도 hexa_float(0.0) → f64 receiver-independent
제외 arm 없음 (전 6 arm 착지).

BAND: has_key = corpus-0-by-construction (tree 0 occ). 나머지 = FLIP-3 `_types_strict_for` band.
test: types_test.hexa `(bu)` `_build_case_builtin_bool_f64_infer` — has_key/contains_key→bool + mean→f64
ok sinks (0) + bool→i64 + f64→string mismatch → 2 HX3011.

## RUNG-2 — HX3045 (Rust E0384) cannot assign twice to immutable variable
opt-in HEXA_BORROWCK / `_bck_active` (default OFF) · warning-band DEFAULT · STRICT re-band Error.

### ★ 설계 편차 (adapt+report) — 1-column mirror FALSIFIED
설계는 "_bck_track 위 1-column `_bck_local_mut` mirror"를 명세했으나, `_bck_track` 은
AGGREGATE(array/struct lit·tracked-ident copy)만 그룹-트래킹 — scalar `let x=1` 은 Copy라
never grouped. 정준 E0384 케이스(`let x=1; x=2`, scalar)가 mirror로는 불가시.
→ scalar를 덮으려면 전용 per-binding 레지스트리 필요. 이는 예산된 1-column mirror보다 크나,
`_bcki_*` uninit 레지스트리와 동일 성격의 flow-INSENSITIVE append-only 3-column 레인이지
새 dataflow AXIS(fixpoint/reach-matrix) 아님. honest-STOP 임계 미달 판단 → 구현 + 보고.

### 신규 인프라 (hir_to_mir.hexa)
- `_bckm_ids: [i64]` / `_bckm_mut: [bool]` / `_bckm_wr: [bool]` — per-fn, `_bck_reset_fn` 리셋
- `_bckm_find(id)` newest-wins · `_bckm_track(id, is_mut, initialized)`
- emitter `_bck_emit_reassign_immut` — `_bck_emit_use_while_mut` 클론 (same-site dedup + `_bck_strict` Error re-band)
- 등록: let-arm (`_bind` 직후) — is_mut = `e.text` `mut:` prefix, initialized = `len(e.children)>0`
- 발화: assign-arm bare-ident hook (round8-1 W3 직후) — `_bckm_find(dst.id)` immut AND `_bckm_wr` set → emit;
  unset → deferred-init 첫 assign이므로 mark written(silent)

FP=0 boundary: bare-ident LHS만(field/index 제외) · immutable만(`let mut` silent) · same-fn ·
deferred `let x; x=1` 첫=init silent 둘째 fire · shadow `let x;let x`=fresh id silent · global 제외(is_global)

test: borrowck_test.hexa `_run_e0384_probe` ×4 — hz_immut_reassign(1) · fp_mut_reassign(0) ·
fp_deferred_init(0) · fp_shadow_rebind(0) · OFF-gate 전 0 · STRICT error-band.

### 코퍼스 스캔 (STRICT-promotion 게이트용, 이번 PR 승격 없음)
per-fn mut-aware scan (git-tracked non-test *.hexa): ~1653 in-fn immutable-reassign 사이트 /146 files
(self 77 · example 37 · stdlib 12 …). hexa가 immutable reassign을 현재 silent 허용 →
`let x=0; x=x+1` (bench/unshadow·verdicts 등) 실사용 다수. ★HX3045 는 real i64 source에서 fire →
warning-band DEFAULT 필수 · STRICT-Error 승격은 코퍼스 마이그레이션(`let mut`) 후 follow-up.

## byteeq-neutral 증명
- RUNG-1: 타입 태그 MIR erase → codegen .text 불변
- RUNG-2: `_bck_active` default OFF → 등록/발화 전무 → .text byte-identical
PR-CI byteeq 3-target = authoritative (#4722/#4724 동형).
catalog 88→89 (DiagSpec==fix_it_kind==89). types_test label next-free bu · borrowck 소스-스트링 probe.
