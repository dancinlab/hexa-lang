# 대공사(daegongsa) 캐노니컬 레퍼런스 3종

hexa-own 보로우체커/데이터플로 대공사 rung은 rustc 를 1:1 reference-match 한다.
아래 3개가 캐노니컬 소스 (구현 전 반드시 소스를 읽고 자구·의미를 맞춘다).

1. **rustc_borrowck** (NLL borrow checker) — `rustc/compiler/rustc_borrowck/`
   - loan liveness / two-phase borrow / E0502(E0499)·E0503·E0505·E0506·E0507·E0594·E0596.
   - hexa 대응: `_bck_*` 계열 (M3 intra-block + M4 cross-block NLL fixpoint) →
     HX3014/HX3019/HX3021/HX3023/HX3027/HX3028/HX3029/HX3031/HX3032/HX3034.

2. **rustc_mir_dataflow — `MaybeUninitializedPlaces`** —
   `rustc/compiler/rustc_mir_dataflow/src/impls/initialized.rs`.
   - MAY(union/OR-join) forward analysis: bit=1 ⇔ place가 maybe-uninitialized.
   - must-init AND-join 의 정확한 DUAL. E0381 (use of possibly-uninitialized).
   - hexa 대응: `_bcki_*` (round8-1) → **HX3035**. seed IN[entry]=1 · kill=INIT ·
     OR-join preds · 같은-블록 순서 정밀 emit.

3. **rust error index — E0381 / E0503 / E0505 …** — <https://doc.rust-lang.org/error_codes/>
   - 각 진단의 사용자 문구·fix 가이드·경계(conservative fire vs FP)의 정답지.
   - hexa catalog `explain` 블록이 여기에 정합해야 한다.

## 대공사 rung 공통 규율
- 전부 `_bck_active` 게이트 (기본 false, `HEXA_BORROWCK=1` / `_STRICT=1`) → flag-OFF byteeq-neutral.
- OBSERVE-ONLY: MIR stmt/local/block 무변경.
- Warning band 기본 + STRICT→Error 재밴딩 (`diag_with_severity(d, Severity::Error)`).
- catalog DiagSpec 는 완결 블록(자체 `fix_it_kind: FixItKind::None` + `},`) — parity
  `grep -c 'DiagSpec {' == grep -c 'fix_it_kind:'`.
- companion probe 는 자립 balanced 블록 (line-union 금지), 3-mode(OFF/ON/STRICT) 검증.
- 앵커는 라인 아님 **심볼**(grep 재-anchor) — round5-7 머지 드리프트 대비.
