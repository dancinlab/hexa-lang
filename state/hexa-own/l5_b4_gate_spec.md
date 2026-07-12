# L5 memory — B4 (borrow-check warn→error) 게이트 스펙

**요약: B4(HX3014 warn→error=빌드거부) GO 조건 = REAL-corpus field-disjoint FP == 정확히 0.** 하나라도 있으면 안전한 프로그램의 빌드를 거부(release-integrity 위반) → N>0이면 B4는 WARN 유지(정직한 terminal), field place-projection 실링리프트 선착륙 후 재센서스.

측정중(aiden pid 3214893 체인·summer는 CUDA env-leak로 실패=infra 격리): `l5_b4_precensus_run.sh origin/main` 광역 adversarial+stdlib+tests field-disjoint FP 카운트. run-validity: ADV_TP_LIVENESS>0(census 살아있음)·ADV_CLEAN_OVERFIRE==0.

핵심: PREREQ-X(free-tree allocator)=MEASURED-TERMINAL(arena #4703/#4706)이므로 bump arena 하에선 borrow 위반이 절대 use-after-free 불가 → **B4는 correctness-LINT(mutate-one-alias-then-read-other 로직버그류)이지 memory-safety/GC-free 게이트 아님.** 따라서 안전코드 N개 빌드거부 vs advisory-급 린트 fatal화 = cost/benefit 역전 → N>0시 NO-GO.

---
## Fable-5/agent B4 게이트 스펙 (origin/main read-only · file:line 증거)

B4 GATE SPEC — L5 Lane-B borrow-check warn→error flip (HX3014). Derived read-only from origin/main: `state/hexa-own/l5_b4_precensus_run.sh`, the `l5_b4_adversarial/` fixtures, and `compiler/lower/hir_to_mir.hexa` (`_bck_check_use`:1923, `_bck_nll_check`:2043, `_emit_hx3014`:1108, whole-local ceiling :5704-5713).

=====================================================================
MECHANISM (what "B4" physically flips)
=====================================================================
B4 = escalate admitted HX3014 from Warning to Severity::Error. The switch already exists: `_emit_hx3014` (hir_to_mir.hexa:1130) does `if _bck_strict { d = diag_with_severity(d, Severity::Error) }` via the sanctioned caller-override (builder.hexa:21-22); the drain fatal-gate `_has_errors` in main.hexa then aborts before codegen = BUILD REFUSAL. B3 today (default-ON, `_bck_warn_default=true`, allowlist `["HX3014","HX3055"]`) force-bands every fire to Warning. B4 removes HX3014 from that forcing (or default-ON's STRICT) so each HX3014 fire refuses the build.

Root defect B4 exposes — the whole-local granularity ceiling (:5704): `obj.f = v` calls `_bck_note_write(fbr.operand.local_id, lhs.children[0].text, …)` keyed on the WHOLE base local, NO place projection. In `_bck_check_use` Rule 1 (:1974) a write through a different name in the block arms the alias for ANY read of that local. So `x.a=…; y.b` (disjoint fields, y aliases x) fires HX3014 identically to `x.a=…; y.a` (same field, real hazard). Field name AND array index are both whole-local — indistinguishable from a true positive in the diag (args are name/other = locals, never places).

=====================================================================
1. GO / NO-GO THRESHOLD
=====================================================================
The gate number is the REAL-corpus (stdlib+tests) field-disjoint FP count — harness fields `FD_HEURISTIC` plus any `PP_INVOLVED` that manual triage resolves to field/element-disjoint. It is NOT the adversarial count.

BAR: **B4 (warn→error) is GO only if the real-corpus field-disjoint FP count = EXACTLY 0.**

Why zero and not a tolerance:
- One real-world field-disjoint FP = a shipped `hexa build`/`run` REFUSING a semantically-safe program (mutate obj.a, read obj.b). That is a direct violation of the top guardrail "release integrity > self-host progress / never break the user-facing path." There is no acceptable non-zero count for a build-refusing gate on the shipping path.
- The bar is on REAL code specifically because the B1 census (#4891) that justified the B3 warn-flip ran only on `compiler/main.hexa` — heavily mut-swept self-host closure that fires ~0 by construction (FLIP-BIASED, as the harness header states). B4-fatal must clear a BROAD adversarial+stdlib+tests corpus, not the self-host closure.

Adversarial fires are NOT part of the gate bar — they are the calibration proof, and they are EXPECTED to be non-zero:
- `ADV_FD_CONFIRMED_FP` (fd_field_disjoint 3 fns + fd_index_disjoint 2 + fd_partial_write 2 = up to 7 sites): these SHOULD fire. Each is safe-by-construction, so each fire is a confirmed FP demonstrating the ceiling. A non-zero here proves the FP class is real, hence B4-fatal is unsafe absent the ceiling lift.
- `ADV_TP_LIVENESS` (controls_truepos, 2 fns, same-place aliased write/read): MUST be > 0 — else the census is DEAD (stale hexat / borrowck off) and every "0" elsewhere is meaningless.
- `ADV_CLEAN_OVERFIRE` (controls_clean, 3 fns): MUST be 0 — a fire is a NON-field-disjoint precision defect (over-fire on same-name / read-only alias / pre-join write) that contaminates the count.

RUN-VALIDITY PRECONDITIONS (check before reading the gate number):
- ADV_TP_LIVENESS > 0, else INVALIDATE the run (dead census).
- ADV_CLEAN_OVERFIRE == 0, else fix that precision regression FIRST — it is not the FD class and inflates the gate.
- The confirmed FP count should be > 0 (the ceiling exists); a 0 there means the adversarial fixtures didn't reach Rule 1 — suspect a build/embed problem, not a clean checker.

=====================================================================
2. IF CENSUS SHOWS N>0 REAL-CORPUS FIELD-DISJOINT FPs
=====================================================================
PREREQ fix = place-projection in MIR write/read events (the ceiling lift), roadmap item A4 "place projection (field-disjoint) = 별도 schema-add".

Feasibility — SPLIT verdict:
- FIELD-disjoint (static `.field`): FEASIBLE without a struct/schema change. The write site ALREADY has the projection token — `lhs.children[0].text` / `lhs.text` is read two arms over (HX3055 arm, :5729) — so mirror the existing parallel-array idiom (`_bck_w_names`/`_bck_w_seqs`/`_bck_w_blocks`): add a push-only `_bck_w_projs` capturing the field token at `_bck_note_write`, capture the read-site field at the field-read hook, and gate Rule 1 (:1974) + the cross-block re-eval in `_bck_nll_check` (:2043) to arm ONLY when write-proj == read-proj (empty proj = whole-value, arms as today). No new Operand field → frozen-seed-safe, matches the "newest-entry-wins parallel array" discipline the whole pass is built on. Moderate, bounded.
- ELEMENT-disjoint (array `[idx]`): PARTIAL. Only constant-index pairs (`a[0]` vs `a[1]`) are statically disjoint. `a[i]` vs `a[j]` with dynamic indices cannot be proven disjoint, so it must stay conservatively ARMED — i.e. it remains a residual FP under B4-fatal. This is the hard wall the fd_index_disjoint fixtures with literal indices pass but a dynamic-index real program would not.

Is the error-flip worth it (factoring PREREQ-X)? The harness header is load-bearing here: PREREQ-X (the free-tree allocator default flip) is MEASURED-TERMINAL (arena-reclaim #4703/#4706, 2-rung wall, do-not-retry). Under the bump arena a borrow violation can NEVER be use-after-free, so **B4 is a correctness-LINT (the mutate-one-alias-then-read-the-other logic-bug class), NOT a memory-safety / GC-free gate.**

Recommendation when N>0:
- **B4 stays WARN — honest terminal — until field place-projection lands.** Rationale: the default-ON warn band (B3, already shipping) ALREADY surfaces the bug class advisorily at zero release-integrity cost (a warning never refuses a build). Flipping to error to make a non-memory-safety lint fatal, while it refuses N real safe programs, inverts the cost/benefit: you trade shipping-safe-code-builds for catching a logic-bug class that is only advisory-grade. That is a NO-GO regardless of N being "small."
- The ONLY GO path with N>0 is: land the field place-projection ceiling lift FIRST (byteeq 3-target GREEN, byte-neutral default-OFF then flip), re-run this precensus, confirm real-corpus FD count drops to 0, THEN flip B4-fatal — and even then only behind `@grace` waivers for the residual dynamic-index element-disjoint cases (separate PR, byteeq 3-target).
- If N==0 across the broad+adversarial corpus AND the adversarial FDs genuinely fire (census live), the ceiling is a non-issue in practice → B4-fatal is viable now behind `@grace` waivers, no schema-add required.

=====================================================================
3. INTERPRETATION RUBRIC — classify each HX3014 fire (--error-format=short)
=====================================================================
Short-format line: `FILE:LINE:COL HX3014 <sev>: … name=<N'> other=<N> … at line <W>`. The diag carries NO field/index info (whole-local), so classification is SOURCE-ANCHORED: read the read-site (FILE:LINE) and the write-site (`at line W`), extract each site's trailing place projection (`.field` / `[idx]` tokens), and compare:

- **FIELD-DISJOINT FP** (`FD_HEURISTIC`) — BOTH sites projected AND projection tokens DIFFER (e.g. read `y.b`, write `x.a`). Safe by construction → false positive. THIS is the B4 gate count. B4-fatal would refuse-build here.

- **PLACE-PROJECTION-INVOLVED candidate** (`PP_INVOLVED`) — ≥1 site projected but not clearly disjoint (same token on both sides, OR only one side projects). Requires manual triage: same field/index = true positive (real aliased hazard); disjoint-on-inspection = fold into the FD FP count. Do NOT auto-trust the heuristic here.

- **WHOLE-VALUE TP** (`WHOLE`) — NEITHER site projects. A whole-handle alias where the read observes the mutation of the same value. Classify case-by-case: a genuine mutate-then-read-the-other-alias = a real logic bug (B4 correctly refuses); an intentional shared-mutation-through-alias (structs are reference values, so this can be deliberate) = benign. Count WHOLE separately — do NOT roll it into the FD FP gate count.

Calibration anchors (ground truth, use to validate the heuristic bucketing on each run):
- Every fire whose FILE matches `l5_b4_adversarial/fd_*` MUST land in the FD-FP bucket (confirmed safe-by-construction).
- Every `controls_truepos` fire = WHOLE/TP (same-place); its count is the liveness assay — must be > 0.
- `controls_clean` fires MUST be 0; any fire there is a non-FD precision defect that invalidates the classification until fixed.

Gate arithmetic the pool number plugs into:
  B4_GATE_FIELD_DISJOINT_CONFIRMED = ADV_FD_N (adversarial, by construction — proof, not gate)
  B4_GATE_FIELD_DISJOINT_TOTAL     = ADV_FD_N + FD_HEUR (+ PP_INVOLVED resolved to FD on triage)
  **DECISION INPUT = FD_HEUR (+ triaged PP_INVOLVED) on the REAL corpus only.**
  == 0  → B4 warn→error GO (behind @grace, byteeq 3-target).
  >  0  → B4 stays WARN (honest terminal); land field place-projection first, re-census.