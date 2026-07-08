# missing-return E0308 (HX3047) — CFG-reachability check · P1 opt-in default-OFF

다음 altitude ① checker-only capability. `fn -> T`(non-unit)인데 body가 return 없이 끝나는 경로 = rustc E0308("mismatched types: expected `T`, found `()`").

## 구현 (P1 = env-gated default-OFF·byteeq중립)
- `_missret_on`(HEXA_MISSING_RETURN=1·lower_hir서 1회 latch·default OFF) — OFF면 `_missret_check` 즉시 return → diag 스트림+.text byte-identical.
- `_missret_check`(hir_to_mir.hexa): materialized per-fn CFG(`_lr_blocks` blocks+succs)서 **SOUND** 판정 — `ctx.has_returned`(FP-unsound: match join reset·while-true 미set) 안 씀. entry_id서 forward BFS(monotone bitset·defensive id2ix·nb*4+8 cap·non-converge silent bail) → reachable·no-succ·terminal이 CONCRETE non-call(STMT_ASSIGN/BINOP/UNOP/LOAD/STORE) leaf면 발화.
- wire=`_lower_fn` `!ctx.has_returned` 가드(synthetic STMT_RETURN 직전·CFG 완성 지점).
- `_emit_hx3047`(→ `_lr_diag`)·catalog HX3047 Error/S3(parity 91/91).

## FP=0 by construction (핵심)
발화=provable non-call fall-off만. divergence 전부 "returns" 처리: return/throw tail(leaf가 STMT_RETURN/THROW→fall-off set 아님)·if/else both(lowering `_set_returned`→ctx.has_returned→check skip)·match all-arms(returning arm이 to-join edge 생략→join unreachable→BFS 미도달)·try/catch both+defer(exit block STMT_RETURN→skip)·while-true(empty after block 0 stmt→fall-off set 아님)·모든 unrecognized tail(STMT_CALL diverging-or-not·indirect·nested try·empty·break/continue)=returns. callee allowlist 無(user `fn die(){exit(1)}` 오탐 불가).

## 검증/게이트
- test=`compiler/check/missing_return_test.hexa`(discriminator hz_missing_return ×1 vs fp_return 0 + FP 컨트롤 6종·OFF 0-diag).
- P1 착지 게이트: gates-summary GREEN + byteeq-neutral(OFF). ★corpus census(P2)=offline HEXA_MISSING_RETURN=1로 21,188 -> T fn 0 false-reject → P3 faithful×3 flag-ON → P4 default-ON flip(never x86-only). census/flip은 follow-up.

## 이력
- agent(ab506a10) 구현 후 census(P2) 직전 API rate-limit 사망(infra·코드무관) → 오케스트레이터 인수·리뷰·bookkeeping·커밋. reference-match design=missing_return_design.md(wf wdj112g8d).
