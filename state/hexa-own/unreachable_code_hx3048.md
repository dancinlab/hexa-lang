# unreachable-code HX3048 (rustc unreachable_code) — CFG-reachability · P1 opt-in default-OFF

다음 altitude ① checker-only capability. missing-return(HX3047·#4751) 바로 다음 rung. 실행 불가(dead) 블록이 캐리하는 user statement = rustc `unreachable_code` (warn-by-default lint). **JUST-VERIFIED**한 `_reach_from` forward-BFS 인프라를 공유.

## SHAPE A only (SHAPE B = NOT-VIABLE-AT-MIR)
- **SHAPE A** = `match`에서 arm이 ALL diverge(return/throw) + last arm이 irrefutable(wildcard `_` 또는 bare-binding non-const ident) + unguarded → match join_id가 preds==[] / reach==0 인데 post-match user statement를 캐리. 메커니즘(하나하나 origin/main서 재확인): match join 신규 생성(preds 無) → 각 arm join-edge는 `if !ctx2.has_returned`서만 추가(:6467)→ all-diverge면 join-edge 0 → irrefutable last arm은 edge-less `STMT_BR arm_id`(next_id/join edge 無, wildcard :5865 / bare-ident :5930) → match가 `_set_cur_block(join_id)`로 has_returned=false RESET → outer block loop가 post-match stmt를 join_id에 계속 lower. 결과: join_id orphaned + user stmt 캐리 = real unreachable_code.
- **SHAPE B**(같은 block의 post-return/throw dead tail) = **NOT-VIABLE-AT-MIR**: block-stmt loop가 tail lower 전에 has_returned서 break → tail이 Stmt 0개 생성·어떤 Block에도 안 들어감. HIR level에만 잔존. 원하면 별도 HIR-hook rung(:5379 break site). MIR reach==0 스캔으로 시도 금지.

## 구현 (P1 = env-gated default-OFF·byteeq중립)
- `_reach_from(entry_id)->[i64]` **공유 helper**: `_missret_check`의 inline BFS(id2ix build + reach[entry_ix]=1 seed + monotone forward fixpoint over Block.succs + cap nb*4+8)를 factor-out. **byteeq-neutral 추출** — `_missret_check`는 `let reach=_reach_from(entry_id)`로 소비, post-BFS predicate verbatim 유지 → reach[] 배열 bit-identical → 동작 불변.
- `_deadblock_on`(HEXA_UNREACHABLE_CODE=1·lower_hir서 1회 latch·default OFF) — OFF면 `_deadblock_check` 즉시 return → diag+.text byte-identical.
- `_deadblock_check`(hir_to_mir.hexa): `_reach_from` 실행 후 per-block SHAPE-A predicate — `reach[bi]==0`(bi!=entry_ix subsume: entry는 항상 seed reach==1) && `preds==[]`(dead-region ROOT key·region당 1회) && `len(stmts)>0` && last-stmt.kind ∈ {STMT_BINOP/UNOP/LOAD/STORE/CALL, 또는 carrier 아닌 STMT_ASSIGN}. carrier op 제외={let, if_val, sc_val, bind}("match_result"는 op 아니라 LOCAL name).
- wire=`_lower_fn`서 `_missret_check` 옆·**UNCONDITIONAL**(`!ctx.has_returned` 밖 — dead match-join은 overall-return fn에도 존재 가능)·synthetic fall-off STMT_RETURN push 직전(CFG 완성 지점, join의 post-match tail이 아직 last stmt).
- `_emit_hx3048`(→ `_lr_diag`·fn span: mir Stmt엔 span field 無→FP-safe·byteeq중립)·catalog HX3048 **Warning**/S3(rustc unreachable_code=warn-by-default·parity 92/92).

## FP=0 by construction (핵심)
opt-in flag default-OFF 위에: empty block(0 stmt→len>0서 제외)·scaffold/carrier last-stmt(STMT_BR/BR_COND/RETURN/TRY_* + carrier ASSIGN→whitelist서 제외)·refutable/guarded last arm(const-ident/literal else·guard가 next_id/join edge 추가→join reach==1→스캔 미진입, SELF-EXCLUDING)·zero-arm match(empty join→len>0서 제외)·entry block(reach==1)·defer/catch epilogue(always wired→reach==1). Sound under-approximation(FP 아님): `while true` after-block은 header→after always wired→reach==1→미탐.

## 검증/게이트
- test=`compiler/check/unreachable_code_test.hexa`(discriminator hz_dead_after_match ×1 vs fp_normal_match 0 + FP 컨트롤 fp_guarded_last/fp_refutable_last/fp_no_trailing 0·OFF 0-diag·WARN-band).
- P1 착지 게이트: gates-summary GREEN + byteeq-neutral(OFF). ★corpus census(P2)=offline HEXA_UNREACHABLE_CODE=1로 compiler/+production stdlib 0 false-warn(shipping엔 x0 예상·shape A는 rare) → P3 faithful×3 flag-ON → P4 default-ON flip(never x86-only). census/flip은 follow-up.
- **가치 정직**: shipping tree엔 real post-match-diverge 사이트 거의 없음(Part 2 census: post-return 0 real). 이 rung은 INFRA-READY지만 shipping엔 x0 발화 가능 — byteeq중립·default-OFF·HX3047 미러·reach[]-BFS diagnostic family 완성(공유 helper 1 + predicate 1). live bug 잡는다고 oversell 금지·가치=completeness + future/user code용 ready lint.

## 이력
- 오케스트레이터 구현·리뷰·bookkeeping·커밋. design=unreachable_code_design.md(verdict READY-WARN-BAND). reuse=missing_return(HX3047·#4751)의 `_reach_from` BFS(empirically GREEN).
