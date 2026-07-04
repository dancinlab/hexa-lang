# HEXA-OWN own-lane 종착 — @own FP-probe 직접증명 + L3-M6 NO-GO

## 1. @own FP-probe 실측 (aiden · ~/hx-m0 aprime_cc M3+M4 @ f91712309 · 2026-07-04)

M0 remeasure가 남긴 유일 열린 후속 = "#4088의 ~950 FP shape가 M3+M4에서 재현되나?"를 **실제 parse 경로**로 직접 측정. probe = `state/hexa-own/fp_probes.hexa` (l3_m0_measurement.md probe matrix 정합).

| probe | shape | #4088 walker | M3+M4 HX3014(ON) | OFF |
|---|---|---|---|---|
| p_fp_callarg | `foo(a)` non-@own param 후 `a[0]` | **FP ×1** | **0** ✅ | 0 |
| p_fp_arr_alias_read | `let b=a; a[0]+b[1]` (read-only) | **FP ×1** | **0** ✅ | 0 |
| p_hz_write_alias | `let b=a; b[0]=99; a[0]` | ✓ ×1 | **1** ✅ (line35) | 0 |
| p_fp_write_same_name | `a[0]=1; a[0]` (no alias) | 0 | 0 | 0 |
| p_fp_copy_int | `let a=x; let b=x` (int) | 0 | 0 | 0 |
| **합계** | | ~2 FP + 1 TP | **1 (TP만)** | **0** |

**직접증명 (verdict)**: #4088이 구별 못하던 **동일-shape alias 쌍**(`hz_write_alias` vs `fp_arr_alias_read`)을 M3+M4 Rule 1이 정확히 판별 — write-through-alias만 발화(1), read-only aliasing은 침묵(0), non-@own call-arg도 침묵(0). **#4088의 ~950 FP shape는 재현되지 않음**(fp_callarg·fp_arr_alias_read 둘 다 0). OFF-control 전부 0 = byteeq-neutral. M0 remeasure의 "카운트 대조는 like-for-like 아님" 한계를 이 실측이 정면 해소 = **precision 직접 증명**.

## 2. L3-M6 borrow-checker GO/NO-GO census (workflow w6jaifuf2)

**verdict = NO-GO** (full rustc-parity &/&mut·NLL). 측정 근거:

1. **residual 측정됨·정당화 결함클래스 없음**: 고가치 클래스(write-aliasing)는 M3+M4 Rule 1이 이미 잡음(위 실측). closure double-mut(#4088 HX2008)=코퍼스 0 hits. @own UAF(Rule 2)=코퍼스 @own 채택 0. field-disjoint borrow(`&mut x.a`+`&mut x.b`)=precision-only, soundness 0.
2. **enforcement가 arena 하에서 vacuous**: bump-arena는 scope 중간에 free 안 함 → aliasing-XOR-mutation이 memory-unsafe일 수 없음. full checker는 비-arena allocator(HEXA_STREAM_RECLAIM, 현재 gated-live·non-default)가 default 되기 전까지 당길 soundness 레버가 없음 = **M6-enforcement BLOCKED-by-design**.
3. **substrate가 flagship precision을 막음**: MIR Operand=local_id만(place projection 없음)·TypeRef=name-string(reference type lattice 없음)·frozen lexer(`&`/`&mut` 문법 없음).

⟹ **L3-M4 = own 레인의 measured honest ceiling 🧱** (under-invest 아님·측정된 벽). M5+ 재개 조건 = 새 residual 결함클래스가 실코퍼스/self-source에서 측정될 때만(예: thread/spawn 표면의 실제 closure double-mut · whole-local granularity가 실제 annotated 코드를 막는 FP · 비-arena allocator default 착지).

## 3. own 레인 잔여 = #4506(M4) 머지뿐
M4(#4506)는 CI에서 코어게이트 GREEN(gen3≡gen4 darwin·faithful·miscompile·determinism), selfhost-byteeq-real만 pending. green 시 squash = own 레인 종결.
