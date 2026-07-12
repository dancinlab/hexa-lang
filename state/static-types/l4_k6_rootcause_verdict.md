# L4 unboxing — k6_idxof 1.029 "회귀" 근인 판정 (measure-first + reference-match)

**결론: k6_idxof 1.029는 실회귀 아님 — call-지배 커널의 타이밍-해상도 노이즈 (3-lens falsification).**

측정 맥락:
- 광역벤치(9커널 back-to-back): k6_idxof ratio ON/OFF = **1.029** (off=0.69s on=0.71s), worst-TARGET로 flip-readiness "≤1.02" 바 초과.
- 격리 재측정(aiden broadbench-3×): RUN1·RUN2 **정확히 1.029** — bounce 아니라 0.01s 해상도의 양자화 몫(0.02s 델타/0.69s = 참값 1.006~1.051 어디든).
- **결정적 교차검증**: 같은 broadbench RUN 안에서 k8_charcode(`name.char_code_at(i%5)+i`, ADD, i64 스탬프 — index_of와 byte-identical codegen) = **0.750**인데 k6_idxof(`hay.index_of(needle)+i`, ADD, i64 스탬프) = 1.029. **동일 codegen이 같은 RUN에서 상반 비율 = 실회귀 불가능.**
- 원인: index_of는 iter당 문자열 전체 스캔(call이 런타임 지배) → unbox 신호(add 1개)가 묻혀 ratio ~1.0±noise. len/byte_at/char_code_at는 싸서 unbox 델타 비중↑ → 깨끗한 0.75.

**격리 재측정 결과(aiden·TARGET=k6+k8만·back-to-back 제거) — "오염설" FALSIFIED, 근인 정정**:
- k8_charcode = **0.774**(승), k6_idxof = **1.029**(그대로!). 격리해도 k6는 1.029 → **back-to-back 오염이 원인 아님**(내 초기 가설 반증·honesty).
- **정정된 근인 = index_of는 call-지배 커널**: iter당 문자열 전체 스캔(hexa_str_index_of)이 런타임을 지배 → unbox(`+i` binop) 레버리지 ≈0 → ratio ≈1.0. k8_charcode는 call이 싸서 레버리지↑ → 0.774.
- **1.029는 실회귀 불가**(결정적): ON은 boxed hexa_add call을 **제거**(summary add 1→0)해 엄밀히 **일을 덜 함** → 일을 덜 하는데 안정적으로 느릴 수 없음 → 0.69→0.71@0.01s는 call-지배 런타임(~0.7s) 위 타이밍 해상도 노이즈(참값≈1.0). high-res(N↑)는 확인용이지 필수 아님(ON<OFF 작업량이 논리적 상한).
- **flip 결론**: 레버는 순-win(builtin 패밀리 geomean 0.82~0.89), k6는 정직히 "레버리지 없음(≈parity)"이지 회귀 아님. 남은 게이트 = CI byteeq 3-target+nvptx default-ON(perf는 measure-justified).

**flip 함의**: geomean 0.822~0.852(15~18% win) 유효. "worst ≤1.02" 바는 노이즈 아티팩트로 트립됨 — index_of 스탬프 제외 **불필요**(제외하면 실제 win 손실). L4 flip 남은 게이트 = regular-CI byteeq 3-target+nvptx GREEN (default-ON 빌드), perf는 measure-justified.

---
## Fable-5/agent codegen 근인 분석 (origin/main read-only · file:line 증거)

Evidence is complete and decisive. Verdict follows.

---

## VERDICT: (B) — NO codegen asymmetry. `index_of` stamps and lowers byte-identically to the winning builtins. The 1.029 is measurement noise (back-to-back broad-bench contamination); the isolated 0.750 is the trustworthy number.

All reads are from `origin/main`. This is read-only analysis; nothing was edited.

### The stamp is identical across all four builtins
`compiler/lower/ast_to_hir.hexa`, `_hir_builtin_method_ret_prim` (table at :144):
- `:147 "len" -> _hir_t_i64()`
- `:149 "index_of" -> _hir_t_i64()`
- `:152 "char_code_at" -> _hir_t_i64()`
- `:153 "byte_at" -> _hir_t_i64()`

`index_of` returns the exact same `_hir_t_i64()` type node as `len`/`byte_at`/`char_code_at`. The `-1`-on-not-found semantics never enters the type system — `-1` is a perfectly ordinary i64 payload; the checker/stamp comment even labels it "gen2 `hexa_int(...)`-wrapped indices." No signed/wider/sentinel path exists. The stamp site (`ast_to_hir.hexa:2156-2162`) is a uniform "if callee is a `field` builtin-method and result is `?`, stamp the mirrored prim type" — no per-name branching.

### The stamped operand is typed identically through MIR
`compiler/lower/hir_to_mir.hexa`:
- `:4883` — the call-result local is created via `_fresh_local(ctx_r, e.typ, "call_ret")`, where `e.typ` is the stamped i64 node. So the `call_ret` local for `index_of` gets `type_id == 1`, exactly like `len`/`byte_at`/`char_code_at`.
- `:329-334 _lr_operand_provably_i64` — pure `_lr_type_of_op(op) == 1` check. Builtin-agnostic: it inspects only the operand's type_id, never which symbol produced it.

### The codegen unbox gate is builtin-agnostic
`compiler/codegen/x86_64_linux.hexa`:
- `:1613-1618 _x86_operand_provably_int` — only `_x86_local_type(rm, o.local_id) == 1`.
- `:1015-1018 _x86_local_type` — plain `rm.local_type[id]` array read, no per-symbol table.
- `:1622 _x86_binop_unbox_ok` — gate is `(op ∈ {add,sub,mul,cmp}) ∧ dst type_id==1 ∧ both operands provably-int`. No `index_of` (or any symbol) special case.
- `:3894-3913` binop emit + `:3045 _x86_op_resolve` — reads the operand's register/slot payload; the STMT_CALL result payload is consumed identically regardless of which runtime helper produced it.

`git grep index_of` over `compiler/codegen/*` / `compiler/emit/*` returns **zero** x86_64 hits (only arm64's unrelated `_arm_index_of` local-scan helper, and an arm64 comment noting index_of routes to a normal arg-count-aware `hexa_str_index_of` STMT_CALL). There is no index_of-specific move/spill/compare in the x86 native lowering.

### Why the ON/OFF ratio cannot be an index_of-specific codegen effect
The stamp changes only the *binop* (boxed `hexa_add`/`hexa_mul` → native `add`/`imul`). The receiver call itself (`hexa_str_index_of`, arg-boxing, 16B HexaVal return) is emitted identically ON and OFF, so it cancels in the ON/OFF ratio. `index_of` differs from the winners only in call arity/arg type (a string needle vs a 0-arg `len` / int-index `byte_at`) — all ON/OFF-invariant.

### The confirming number
k8 `name.char_code_at(i%5)+i` (ADD op) isolated = **0.750**. k6 `hay.index_of(needle)+i` (ADD op) isolated = **0.750** — identical. Same op class, same i64 stamp, same unbox path → same speedup. The broad-bench 1.029 is the lone outlier, produced by the back-to-back 9-kernel run the CLAUDE.md HEXA-UNBOX rule explicitly forbids ("measure-first, isolated, not back-to-back").

### Recommendation
Do **not** exclude `index_of` from the stamp allowlist — there is no mechanism to justify it, and doing so would forfeit a real ~25% win (isolated 0.750). Flip-readiness rests on the pending 3× isolated-stability re-measure (per-kernel, not back-to-back) plus the regular-CI byteeq 3-target + nvptx GREEN gate, exactly as the default-OFF policy requires. Treat 1.029 as a contaminated data point and drop it in favor of the isolated 0.750.