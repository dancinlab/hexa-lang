# L5 field place-projection 설계 (B4-error PREREQ·구현-ready·workflow wf_03c8f90c)

**목적**: census(#4909)가 측정한 REAL-corpus field-disjoint FP=3(logic_synth/passes.hexa)를 해소 = B4(HX3014 warn→error) flip의 PREREQ. borrowck whole-local 천장(x.a=v; y.b도 발화)을 place-projection으로 정밀화.

**상태**: 설계 완결·구현-ready. 구현=다음 라운드(다중사이트 hir_to_mir.hexa 편집 + census 재실행 검증·byteeq-gated). ⚠️ hir_to_mir.hexa는 fast-main으로 이동중 — 구현 전 각 anchor를 origin/main서 재확인(설계의 L1053/1983/2186/4900/5711/5787/7434는 설계 시점 origin/main 기준).

**핵심 판정 요약**:
- **mechanism**: read-side 절반 이미 존재(`_bck_pm_field` L766·field-read arm L7434가 field token 포착). 추가 = write-side `_bck_w_projs` push-only 배열(_bck_note_write에 proj param+push·3 call-site서 field/const-idx token) + read-side 전용 transient `_bck_rd_proj`+`_bck_u_projs`. **no new Operand field**(parallel-array·frozen-seed-safe).
- **gate predicate**: SUPPRESS iff `len(wp)>0 && len(up)>0 && wp!=up`(field/index-disjoint); else ARM(둘다 빈값=whole-value·either 빈값=conservative·equal-nonempty=same-place 실hazard 유지). 삽입=Rule1(_bck_check_use)+M4(_bck_nll_check) 양 gate.
- **FP-resolution**: 3 real FP(passes.hexa: read connect_lhs / write connect_rhs 등 disjoint field)→suppress ✓. controls_truepos(same-place)→계속 발화 ✓(no under-narrow). dynamic-index(a[i] variable)→empty token→conservative arm(sound·residual=element-disjoint dynamic).
- **byteeq-neutral CONFIRMED**: borrowck=OBSERVE-ONLY(never emits stmt/local·hir_to_mir.hexa:471-476)·diag는 별도 _lr_diag list(_bck_diag_push:1099)·codegen은 MIR만 소비 → .o 0바이트 변경. warn-band 좁히기도 .o-neutral(diag는 MIR 밖).
- **scope**: bounded 1-2 round(parallel-array _bck_w_seqs 선례·predicate 2-gate). flip path: 구현→byteeq 3-target GREEN(default-ON-warn-narrowing)→census 재실행 REAL FD==0 확인→@grace로 B4 warn→error(residual element-disjoint dynamic만 @grace).

---
## agent 1 — mechanism/patch
I now have the complete mechanism. Returning the patch design.

---

# HX3014 field/index-projection suppression — patch design

**File (origin/main):** `compiler/lower/hir_to_mir.hexa`
All line numbers below are origin/main (`git show origin/main:…`). Note the task's "~987/~1852/~5704" offsets are stale; the real anchors are given here.

## Key finding: half the read-side machinery already exists

The read-projection capture the task asks me to add is **already threaded for field-reads** as `_bck_pm_field` (decl L766, set L7434-7435). The field-read arm does exactly the right thing:

```
7434  let _bk_pm_saved = _bck_pm_field
7435  if _bck_active && e.children[0].kind == "ident" { _bck_pm_field = e.text }   // e.text = field name
7436  let r = _lower_hexpr(ctx, e.children[0])   // <-- base-ident use funnels to _bck_check_use HERE, sees the field token
7437  _bck_pm_field = _bk_pm_saved
```

So for `m_work.connect_lhs[ti]` the base ident `m_work` funnels into `_bck_check_use` **with the field token `"connect_lhs"` live** (the outer `[ti]`'s base is the *field node*, not an ident, so the index arm never overwrites it). That is precisely the read-projection needed. `_bck_pm_field` is consumed by the HX3042 partial-move lane (`_bck_pm_note_use`, L2013), so to avoid perturbing HX3042 I add a **dedicated** transient global rather than overloading it.

## (a) Write-side projection — `_bck_w_projs`

**Declaration** — add beside the write-event arrays (after L626 `_bck_w_seqs`):
```
pub let mut _bck_w_projs: [string] = []   // per-WRITE place token: field name / const index / "" (whole-value)
```

**Reset** — add after L844 (`_bck_w_seqs = []`):
```
_bck_w_projs = []
```

**`_bck_note_write` (L1053)** — add a `proj` param and push in lockstep:
```
fn _bck_note_write(local_id: i64, name: string, blk: i64, sp: Span, proj: string) {
    let ti = _bck_find_local(local_id)
    if ti < 0 { return }
    _bck_w_grps.push(_bck_groups[ti])
    _bck_w_names.push(name)
    _bck_w_lines.push(sp.line)
    _bck_w_blocks.push(blk)
    _bck_w_seqs.push(_bck_evseq)
    _bck_w_projs.push(proj)          // <-- NEW, one push per event (parallel-array invariant preserved)
    _bck_evseq = _bck_evseq + 1
}
```

**The 3 call sites** (each passes its place token):

| site | line | current arg | added proj |
|---|---|---|---|
| method write `recv.push(x)` | 4900-4901 | `(_bk_recv_local, _bk_recv_name, ctx2.cur_block, e.span)` | `""` — receiver is a bare ident (L4560, only ident receivers are tracked); `.push` mutates the whole array → whole-value/conservative |
| field_set `obj.f = v` | 5711-5712 | `(fbr.operand.local_id, lhs.children[0].text, fctx.cur_block, e.span)` | `lhs.text` — the field name (base ident is `lhs.children[0].text`; the projection token is `lhs.text`) |
| index_set `a[k] = v` | 5787-5788 | `(br.operand.local_id, lhs.children[0].text, ctx_s.cur_block, e.span)` | `_bck_const_idx_tok(lhs.children[1])` — see helper |

**Helper** (const-index → token, else conservative-empty; keeps dynamic `a[i]` sound):
```
fn _bck_const_idx_tok(n: HExpr) -> string {
    if n.kind == "literal_int" || n.kind == "literal_string" { return n.text }
    return ""
}
```

## (b) Read-side projection — dedicated transient + `_bck_u_projs`

**Transient global** (isolated from `_bck_pm_field`/HX3042) — decl near L766:
```
pub let mut _bck_rd_proj: string = ""   // read-site place token for the HX3014 alias gate
```
Reset near L876: `_bck_rd_proj = ""`.

**Set it symmetrically at both read arms** (right where `_bck_pm_field` is / would be set, so it is live when the base ident funnels through `_bck_check_use`):

- field-read arm L7435 — add alongside the existing line (save/restore already bracket L7434/7437):
```
if _bck_active && e.children[0].kind == "ident" { _bck_pm_field = e.text; _bck_rd_proj = e.text }
```
and restore `_bck_rd_proj = _bk_pm_saved_rd` at L7437.

- index-read arm (L7456) — currently sets **no** projection. Mirror the field arm around the base lowering at L7473 (`let lr = _lower_hexpr(ctx, e.children[0])`):
```
let _bk_rd_saved = _bck_rd_proj
if _bck_active && e.children[0].kind == "ident" { _bck_rd_proj = _bck_const_idx_tok(e.children[1]) }
let lr = _lower_hexpr(ctx, e.children[0])   // existing
_bck_rd_proj = _bk_rd_saved
```

**Per-use parallel array** — decl beside `_bck_u_seqs` (after L647), reset after L855:
```
pub let mut _bck_u_projs: [string] = []
_bck_u_projs = []
```
Push in `_bck_check_use` alongside `_bck_u_seqs.push(_bk_ujoin)` at L2003:
```
_bck_u_projs.push(_bck_rd_proj)   // one push per use event (mirrors _bck_u_seqs)
```

## (c) The gate predicate — disjoint ⇒ SUPPRESS

Define field/index-disjointness (both projections known AND different):
```
disjoint(wp, up) := len(wp) > 0 && len(up) > 0 && wp != up
```
- both empty (whole-value / whole-value) → arm as today
- either empty (dynamic index, method-whole, or an untracked read) → **conservative, arm as today**
- equal non-empty (same place, e.g. `x.a=v; y.a`) → arm as today (real hazard preserved)
- **only** unequal non-empty → suppress

**Intra-block Rule 1** (`_bck_check_use`, L1983-1985) — add the guard:
```
if _bck_w_blocks[wi] == blk && _bck_w_names[wi] != name
    && _bck_w_seqs[wi] > _bk_ujoin
    && !(len(_bck_w_projs[wi]) > 0 && len(_bck_rd_proj) > 0
         && _bck_w_projs[wi] != _bck_rd_proj) {
    _emit_hx3014("aliased write", name, _bck_w_names[wi], _bck_w_lines[wi], sp)
}
```

**M4 cross-block** (`_bck_nll_check`, L2186-2191) — same guard against the per-use snapshot:
```
if _bck_w_grps[e] == _bck_u_grps[u]
    && _bck_w_names[e] != _bck_u_names[u]
    && _bck_w_seqs[e] > _bck_u_seqs[u]
    && !(len(_bck_w_projs[e]) > 0 && len(_bck_u_projs[u]) > 0
         && _bck_w_projs[e] != _bck_u_projs[u]) {
    _emit_hx3014("aliased write", _bck_u_names[u], _bck_w_names[e],
                 _bck_w_lines[e], _bck_u_spans[u])
}
```
The move arms (Rule 2, L1990 / L2194) are untouched — projection only gates aliased-*write*.

## Why the census FPs clear

`(x.a = v; … y.a-read)` with `y` aliasing `x`: read-proj `"a"` == write-proj `"a"` → **still fires** (real hazard kept). `(x.a = v; … y.b-read)`: `"b" != "a"` → **suppressed**. The passes.hexa:3331-3333 fires are field-disjoint (`m_work.connect_lhs[ti]` read carries field-proj `"connect_lhs"`; the aliased write carries `connect_rhs`/a different field) → suppressed. Dynamic-index reads/writes (`a[ti]`, `a[str]` with variable subscripts) yield empty tokens → remain conservative/sound, never a new false-negative.

## Why no new `Operand` field (frozen-seed-safe)

- Projection state lives **entirely** in borrowck-local parallel arrays (`_bck_w_projs`, `_bck_u_projs`) plus one transient `string` global (`_bck_rd_proj`). Nothing touches the MIR `Operand` struct.
- `Operand` is part of the **frozen self-host seed**; adding a field changes its layout/ABI and would break the `gen3 ≡ gen4` byte-identical fixpoint. Parallel arrays sidestep that completely.
- **Parallel-array / newest-wins invariant preserved:** exactly one `push` per write event and per use event, in lockstep with the existing `_bck_w_*`/`_bck_u_*` rows — the event counts `nw`/`ne`/`nu` and the `_bck_find_write` end-scan ("newest entry wins") are unchanged; only an extra column is read at the same index.
- **byteeq-neutral:** all appends and the arm-guards are inside `_bck_active` / the borrowck registries, which are empty on the default flag-OFF path. On shipping code the census fires=0, so stderr/artifacts stay byte-identical; the change only *removes* would-be HX3014 warnings under the borrowck flag, never adds any.

## Patch shape summary

- **+1 fn param** `proj: string` on `_bck_note_write` (L1053); 3 call-site updates (L4900, L5711, L5787).
- **+1 helper** `_bck_const_idx_tok` (const index/map-key literal → token).
- **+2 push-only arrays** `_bck_w_projs`, `_bck_u_projs` (decls ~L626/L647; resets ~L844/L855; pushes in `_bck_note_write` and `_bck_check_use` L2003).
- **+1 transient global** `_bck_rd_proj` (decl ~L766, reset ~L876; set at field-read L7435 and index-read ~L7473; consumed at L2003).
- **2 gate edits** — the disjoint-suppress conjunct added to intra-block Rule 1 (L1983) and M4 cross-block (L2186).

No `Operand` change; no new MIR fields; move-rule and all other borrowck lanes untouched.
## agent 2 — FP-resolution

Analysis complete. All reads were from `origin/main` (no edits). Findings below.

---

# B4 A1-predicate verification — FP-resolution + no-under-narrowing

**A1 predicate under test:** at a candidate HX3014 arming, SUPPRESS iff `write_proj != "" AND read_proj != "" AND write_proj != read_proj`; ELSE arm (empty proj = whole-value ⇒ arms as today). `write_proj` = projection token off the tracked base local at the write event; `read_proj` = same off the flagged use.

## AST/mechanism facts confirmed (origin/main `compiler/lower/hir_to_mir.hexa`)

- Field write `x.a=v` is noted at `:5711` via `_bck_note_write(fbr.operand.local_id, lhs.children[0].text=…"x"…, …)` — **name passed is the BASE ident**; the field token is `lhs.text` (for `kind=="field"`, `children[0]`=base ident, `.text`=field name — confirmed by the read-side hook at `:4616-4624` which reads `e.children[i].text` as the field). Gated `lhs.children[0].kind=="ident"` (`:5709`).
- Index write `a[i]=v` noted at `:5787`; index expr = `lhs.children[1]`.
- **Receiver-mutating method `xs.push(v)` is noted at `:4898-4901`** via `_bck_note_write(_bk_recv_local, _bk_recv_name, …)` — the write target is the **bare-ident receiver, NO projection**.
- Rule-1 arm = `_bck_check_use` `:1983`: `_bck_w_blocks[wi]==blk && _bck_w_names[wi]!=name && _bck_w_seqs[wi]>_bk_ujoin`. The name-difference gate fires BEFORE any proj comparison.

## Adversarial fixtures + controls — all CORRECT under A1

| Fixture / fn | write_proj | read_proj | A1 verdict | required | ✓? |
|---|---|---|---|---|---|
| `fd_field_disjoint` FD-1 `x.a=10` / `y.b` | `.a` | `.b` | both≠ → **SUPPRESS** | silence | ✓ |
| FD-2 `y.b=20` / `x.a` | `.b` | `.a` | **SUPPRESS** | silence | ✓ |
| FD-3 `x.a=99` / `z.b` (3-name grp) | `.a` | `.b` | **SUPPRESS** | silence | ✓ |
| `fd_index_disjoint` IDX-1 `a[0]=99` / `b[1]` | `[0]` | `[1]` | both≠ (**literal**) → **SUPPRESS** | silence | ✓ |
| IDX-2 `b[2]=88` / `a[0]` | `[2]` | `[0]` | **SUPPRESS** | silence | ✓ |
| `fd_partial_write` PW-1 `v.x,v.y` / `w.z` | `.x`,`.y` | `.z` | both≠ → **SUPPRESS** | silence | ✓ |
| PW-2 `v.x×2` / `w.y` | `.x` | `.y` | **SUPPRESS** | silence | ✓ |
| `controls_truepos` TP-1 `x.v=99` / `y.v` | `.v` | `.v` | **same → ARM → FIRES** | fire | ✓ |
| TP-2 `a[0]=99` / `b[0]` | `[0]` | `[0]` | same literal → **FIRES** | fire | ✓ |
| `controls_clean` CL-1 same-name `c.a`/`c.b` | — | — | name-eq gate (`:1983`) → never armed | 0 | ✓ |
| CL-2 read-only alias | (no write event) | — | 0 | 0 | ✓ |
| CL-3 write-before-alias | `.a` | — | seq gate `_bck_w_seqs>_bk_ujoin` (`:1984`) → 0 | 0 | ✓ |

A1 gives the correct verdict on **every** adversarial + control fn. Note controls_clean is protected by orthogonal gates (name-difference / gen-kill seq), **not** by the proj predicate — so A1 introduces no clean-corpus regression.

## The 3 REAL FPs (passes.hexa:3331-3333) — A1 does NOT silence them ⚠️

This is the load-bearing negative finding — the census's own open question (l5_b4_gate_spec.md:90 "★place-projection이 3 real FP를 정확히 해소하는지가 다음 라운드 검증 타깃").

**Source (`stdlib/kernels/logic_synth/passes.hexa`, fn `pass_proc_mux`):**
- `:3265` `let mut m_work = m` · `:3266` `keep_lhs:[str]=[]` (built by `.push` from `m.connect_lhs`)
- Flagged uses (col confirms): `:3331:36` = **`keep_lhs`**, `:3332:36` = **`keep_rhs`**, `:3333:37` = **`keep_cond`** — each is the RHS of `let mut final_X:[str] = keep_X`, i.e. a **bare-ident whole-value alias read → read_proj = ""**.
- Writes reported `@3336/3337/3340` = `final_X = final_X.push(…)` — a **mutating-method on a bare-ident receiver** (`:4900` path) → **write_proj = ""**.

**A1 trace:** write_proj `""`, read_proj `""` → NOT both-nonempty → **ARM → STILL FIRES.** All 3 survive. **A1 drops the real-corpus FD count from 3 to 3 (zero reduction).**

**Why the harness bucketed them FD (mis-classification):** the `l5_b4_precensus_result.txt:50-52` tokens are a **source-line text-scan artifact**, not MIR place projections:
- `read:[str]` = the **type annotation** `: [str]` on the `let mut final_lhs: [str] = keep_lhs` line — not a projection at all.
- `write:.push,.connect_lhs,[ti]` = the method selector `.push` + the field/index of the **RHS argument** `m_work.connect_lhs[ti]` — not the write **target**'s projection. (Fire-3 confirms this: `:3340` arg is plain `ccc`, so its token list is just `.push` — the `.connect_lhs`/`[ti]` vanish exactly when the RHS arg has no projection.)

**Real nature of the passes.hexa fires = WHOLE-value benign alias**, not field-disjoint. `keep_X` is dead after the `final_X = keep_X` alias is created; `.push` on `final_X` never observably mutates the dead `keep_X`. Per the spec's own rubric (gate_spec §3) this is the **WHOLE/benign** bucket, which must be counted separately and NOT rolled into the FD gate. The FD_HEURISTIC=3 in the result file is a false bucketing.

**Consequence:** field place-projection (A1) is **necessary-but-insufficient** for B4-GO. It cleanly silences the adversarial field/const-index FPs and preserves the true positives, but the actual shipping-corpus blocker (passes.hexa ×3) is a whole-local dead-alias case that A1 leaves firing. Closing those needs a *different* lever — whole-value alias liveness/deadness (recognize `keep_X` dead at the alias point) or a benign-mutation-of-dead-source rule — not field projection. B4 stays NO-GO after A1 alone.

## Under-narrowing / residual that MUST stay conservatively armed

**Element-disjoint DYNAMIC-index** `a[i]` (write) vs `a[j]`/`a[i+1]`/`a[i]` (read) where the indices may coincide at runtime. If A1 captures the index as a **token string** and compares string-inequality, `[i]`≠`[j]` textually → it would **SUPPRESS a real same-element hazard when i==j at runtime → UNDER-NARROWING (missed real bug).** Same danger for `a[i]` write vs `a[0]` read (dynamic vs constant — unprovable disjoint).

Required guard: the index arm may compare projections **only when BOTH sides are integer literals**; any non-literal index must be treated as whole-local (empty-equivalent → ARM). The `fd_index_disjoint` fixtures pass A1 *only* because they use literal indices (0/1/2); a dynamic-index program is the **residual FP that survives B4-fatal** and is the hard wall flagged in gate_spec §A4/`:49`. Field projection (`.a` vs `.b`) has no analog — struct field tokens are always statically resolved, so the field arm is sound.

Secondary sound-but-note: nested `x.a.b` writes are already SILENT (guard `lhs.children[0].kind=="ident"` fails when the child is itself a `field` node, `:5709`) — a pre-existing under-fire, not introduced by A1. But the read hook must key `read_proj` on the projection **adjacent to the tracked base local** (first projection off the ident), else `x.a` write vs `x.a.b` read (overlapping, real alias) could be mis-compared `.a`≠`.b` and under-narrow.

## Bottom line

- Adversarial FD (7 sites) + const-index: **A1 silences correctly.** True-positives (2) + clean controls (3): **A1 preserves correctly.** No under-narrowing on the field arm or the literal-index arm.
- **A1 does NOT silence the 3 real passes.hexa FPs** — they are whole-local dead-alias (empty proj both sides); the census's FD bucketing is a text-scan artifact. A1 leaves the REAL-corpus gate number at 3, so **B4 warn→error remains NO-GO even after landing A1.**
- Residual requiring conservative arming: **dynamic-index element aliasing** (`a[i]` vs `a[j]`, dynamic-vs-const) — index arm must gate on literal-only, else it under-narrows.

Key files (absolute): `/Users/mini/dancinlab/hexa-lang/compiler/lower/hir_to_mir.hexa` (`:1983` Rule-1, `:4900` method-write note, `:5711`/`:5787` field/index-write notes), `/Users/mini/dancinlab/hexa-lang/stdlib/kernels/logic_synth/passes.hexa:3231-3342` (real FP site), `/Users/mini/dancinlab/hexa-lang/state/hexa-own/l5_b4_precensus_result.txt:50-52` (mis-bucketed tokens), `/Users/mini/dancinlab/hexa-lang/state/hexa-own/l5_b4_adversarial/*.hexa` (fixtures).
## agent 3 — byteeq/scope

Findings returned as data. All reads from `origin/main:compiler/lower/hir_to_mir.hexa` (no edits).

---

## (1) BYTEEQ-NEUTRALITY VERDICT: **NO — place-projection changes ZERO emitted .o bytes**. CONFIRMED.

**Mechanism (the borrowck pass never touches MIR):** The M3/M4 loan pass is declared OBSERVE-ONLY at the source of truth, lines 471-476:
> "the pass only OBSERVES the lowering — it never emits stmts/locals and adds no field to Stmt — so the flag-off MIR (and the emitted binary) is byte-identical".

There is no "MIR-erase" step because there is nothing to erase: **diagnostics never enter MIR at all.** They accumulate in a *separate* list `_lr_diag` (via `_bck_diag_push`, line 1099) that is drained by `main.hexa`, while codegen consumes MIR only. So the `.o`/`.text` derive from MIR, which is provably invariant to borrowck.

**Why narrowing the WARN band specifically stays .o-neutral** — three independent guarantees:
1. **Severity is forced to Warning.** Under `_bck_warn_default` (default-ON, `HEXA_BORROWCK_WARN_DEFAULT!="0"`, line 554), `_bck_diag_push` re-bands every admitted diag to `Severity::Warning` (line 1097). A Warning never trips the `_has_errors` fatal gate, so codegen runs identically whether 3 or 0 HX3014s are admitted.
2. **Warnings are stderr, not artifact.** byteeq compares emitted `.o`/`.text`; the warning text stream is not part of the compared artifact. Suppressing the 3 FP prints changes only stderr.
3. **The place-projection predicate only gates the `_emit_hx3014` call** (Rule 1, lines 1983 and 2187) — it adds/reads parallel-array data and short-circuits emission. It writes no Operand/Stmt/MIR field.

So place-projection **NARROWS which HX3014 warnings print** (suppresses the FP-class at logic_synth/passes.hexa:3331-3333) and touches nothing else.

**One nuance to flag:** the B3 comment (lines 544-561) justifies default-ON by asserting "fires=0 on the whole self-host corpus ⇒ diag stream + emitted binary byte-identical." The #4909 census contradicts the *diag-stream* half of that claim (3 real FPs now print). This does **not** break build byteeq (warnings aren't in `.o`), but the "diag stream byte-identical" sub-claim in that comment is now stale and should be re-worded when place-projection lands — the *artifact* byteeq claim remains true.

---

## (2) FLIP PATH TO B4-ERROR

1. **Land place-projection, default-ON-warn (warn-band NARROWING).** Add write-proj + read-proj tracking; predicate arms Rule 1 only when `write_proj == read_proj`. This is byteeq-neutral per (1) → **byteeq 3-target GREEN is expected to pass unchanged** because no `.o` byte moves; the only observable delta is fewer stderr warnings. Still gate on the 3-target run + install smoke per release-integrity discipline.
2. **Re-run the #4909 census** (`HEXA_BORROWCK_CENSUS=1` lane, lines 534-543 — observe-only, itself byteeq-neutral) on the real corpus.
3. **Confirm REAL field-disjoint FD == 0** (the 3 passes.hexa fires must vanish; no new FP class surfaces).
4. **Only then flip HX3014 warn→error** for the residual element-disjoint dynamic-index cases, behind the existing STRICT escalation path (`_bck_strict` re-bands to `Severity::Error` in `_emit_hx3014`, lines 1123-1131) and/or `@grace`. Note dynamic `a[i]` vs `a[j]` cannot be statically proven disjoint — those stay advisory/@grace, not hard-error, matching the "precision-first: FPs not allowed" stance (line 503).

---

## (3) SCOPE ESTIMATE: **bounded 1–2 rounds. Does not balloon.**

The parallel-array precedent that makes it bounded is `_bck_w_seqs` (L5 round-2b), which added program-order gen/kill gating with **zero structural change**:
- One decl `pub let mut _bck_w_seqs: [i64] = []` (line 626)
- One push in `_bck_note_write` (line 1061)
- One reset in `_bck_reset_fn` (line 844)
- Read in both Rule-1 predicates: intra-block (line 1984) and NLL cross-block (line 2188)

`_bck_w_projs` follows the identical shape — **6th column beside `_bck_w_grps/_names/_lines/_blocks/_seqs`, no new Operand/Stmt field (frozen-seed-safe)**:

**Write side (trivial):** in `_bck_note_write` push the field/index token. The token is already in hand at the write hook — line 5711 passes `lhs.children[0].text` (the base) and the field name is `lhs.text`, exactly the token HX3055 reads at 5729. Reset adds one line at ~844.

**Read side (the one non-trivial bit — still bounded):** the cross-block NLL pass reads `_bck_u_names[u]` from a *recorded* use array (line 2187), so it needs a parallel `_bck_u_projs` pushed alongside `_bck_u_names.push(name)` (~line 1997), mirroring how `_bck_u_seqs` was added. Capturing the use-site's *enclosing* projection requires threading a small context string (e.g. `_bck_cur_read_proj`) around lowering of a field/index base — but this idiom **already exists**: `_bcki_in_place_base` is set/restored around the container base at lines ~5751-5755. Same set-save-restore pattern, string instead of bool. The intra-block Rule 1 (line 1983) has the use context in scope directly, so it needs only the predicate edit.

**Predicate change:** both sites get `&& w_proj == u_proj` appended to the existing `_bck_w_names[..] != name` clause.

**Total surface:** ~2 decls, ~2 pushes, ~2 resets, 1 context-flag thread (existing idiom), 2 predicate edits. This is the same footprint as the round-2b `_bck_w_seqs` landing — a single bounded round for the wiring, plus a second round only for the census re-run + the warn→error flip. No new MIR field, no Operand growth, no codegen path touched → no balloon.
---

## A2 dead-alias redef-cut + 통합 A1+A2 구현 착지 (wf_611eb0f4)

**반증(honesty)**: agent2가 A1 단독으로 3 real FP(passes.hexa:3331-3333)를 해소하지 **못함**을 확정 — 이들은 whole-value **dead-alias**(`keep_X`가 `let mut final_X = keep_X` 후 dead → `final_X = final_X.push(...)`가 죽은 원본의 무해한 clobber). write-proj·read-proj 둘 다 빈값이라 A1의 field/index-disjoint 술어가 걸리지 않음. census FD=3은 source-line text-scan 오분류(`read:[str]`=타입주석·`write:.push,.connect_lhs,[ti]`=RHS 인자의 selector, write **타깃**의 projection 아님).

**A2 = dead-alias redef-cut liveness** (진짜 blocker 해소):
- 순진한 "dead-after-use"는 **unsound** — controls_truepos TP-1(`let y=x; x.v=99; use(y.v)`, write-before-observing-read)을 false-negative로 억제. 설계가 자가교정.
- 정답 criterion: `A2_deadalias(e,u) := NOT( block(e)가 use-local L의 whole-local redef를 거치지 않는 forward CFG 경로로 block(u)에 도달 )`. SUPPRESS iff true. = "write가 쓴 값이 use의 로컬로 관측될 수 있는가"의 부정.
- passes.hexa: write(`final_X.push` @:3336)가 read(`let final_X=keep_X` @:3331)에 도달하는 유일 경로 = 외곽 `while mi` back-edge인데, 그 경로는 `let mut keep_X=[]` (:3266) whole-local 재초기화를 반드시 거침 → redef-cut → SUPPRESS ✓. (오늘 발화 근인: :3266 kill은 keep_X BIRTH 그룹 대상·arming write는 detach로 민 fresh 그룹(no note_kill)이라 group-keyed THROUGH-cut이 안 걸림; A2 redef-cut은 **LOCAL**-keyed라 그룹 무관하게 cut.)
- forward BFS(`_bck_wr_deadalias`, `_reach_from` idiom): seed=succs(src)(never src 자신)·b==dst면 fire(도달=실hazard)·b가 L의 redef 블록이면 CUT(단 dst는 절대 cut 안함=in-block use-before-redef 보존)·drain되면 SUPPRESS.

**구현 사이트(hir_to_mir.hexa · feat/l5-place-projection-deadalias · +173/-16)**:
- A1: `_bck_w_projs`/`_bck_u_projs`/`_bck_rd_proj` 배열+transient·`_bck_const_idx_tok` 헬퍼·`_bck_note_write` proj param+push·3 write call-site(method="" · field_set=lhs.text · index_set=const_idx_tok)·field-read+index-read arm read-proj set·intra Rule1+M4 disjoint conjunct.
- A2: `_bck_u_locals`(per-use local)+`_bck_def_locals`/`_bck_def_blocks`(whole-local redef 이벤트)·`_bck_note_def` 헬퍼·7 whole-local (re)bind arm서 def 기록(설계 명명 5 + @own-detach 2, 전부 genuine ident rebind=spurious 불가)·`_bck_wr_deadalias` BFS·M4에 `&& !_bck_wr_deadalias(e,u)` conjunct(intra는 A1만·A2는 CFG-materialized라 M4 전용).
- 병렬배열 lockstep: u_*(7컬럼)·w_*(6컬럼) 단일 push 사이트 → desync 불가. no new Operand/MIR field(frozen-seed-safe). byteeq중립(borrowck OBSERVE-ONLY:471-476·pure read-only BFS·diag만 _lr_diag서 좁힘·.o 0변경).

**판정 GO-WITH-GUARD**: clears 3 FP✓·over-suppression 경로 0(genuine rebind만·spurious def 구조적 불가·branch-conditional/loop-carried-live 전부 ARM)·controls_truepos(2)+loop-carried 계속 발화✓. **검증중(guard a)**: byteeq 3-target GREEN(PR-CI) + aiden census(REAL FD 3→0·ADV_TP_LIVENESS==2·ADV_CLEAN_OVERFIRE==0·검증하니스 l5_b4_precensus_run.sh 복사). **residual(guard b·소hole 아님)**: dynamic-index element-disjoint(`a[i]` vs `a[j]`)은 A1 literal-only+A2 미커버 → B4 warn→error 시 @grace-gated.

**flip 경로**: 통합 착지(default-ON warn narrowing·byteeq중립) → byteeq 3-target+install smoke GREEN → census REAL FD==0 확인 → @grace로 residual dynamic-index만 waiver·별도 PR로 HX3014 warn→error(`_bck_strict` 경로·correctness-lint framing, NOT memory-safety: PREREQ-X measured-terminal이라 bump arena 하 borrow위반=UAF 불가).
