# flame Phase 4-B-1 scaffold — findings (RFC 047)

> Detect-only Phase 4-B scaffold landed 2026-05-17. No source transform,
> no emit; pattern matching + classification + dims_hash only. Findings
> below drive the Phase 4-B-2 design decision (next user-directed cycle).

## What landed

- **`tool/flame_phase4b_scan.hexa`** — text-based call-site scanner for
  `nn_decoder_block_fwd` / `nn_decoder_block_bwd`. Skips fn-decls and
  comments. Paren-balanced multi-line call gather. Classifies last-5 args
  (T, d, nh, nkv, h) as `literal-tuple` / `variable-tuple` / `mixed-tuple`.
  Emits `dims_hash` (djb2 of (T,d,nh,nkv,h) text) for literal-tuple sites.

- **Falsifier F-RFC047-SCAFFOLD-DETECT** — on synthetic source with
  direct-literal call sites, scaffold reports ≥1 literal-tuple. PASS
  verified on `/tmp/literal_site.hexa` (3 literal + 1 mixed; same dims
  fwd+bwd → same hash 0x388e4067 → emit-once-reuse semantic confirmed).

- **Falsifier F-RFC047-SCAFFOLD-FALLBACK** — on real flame sources
  (`flame_block_test.hexa`, `decoder_lib.hexa`, `decoder_block_lib.hexa`,
  `flame_d32_corpus_test.hexa`), scaffold reports zero literal-tuple,
  zero false-positives on fn-decl lines. PASS verified.

## Real-source result matrix (post-fn-decl-skip)

| Source | call sites | literal-tuple | variable-tuple | mixed-tuple |
|---|---|---|---|---|
| `flame_block_test.hexa` | 5 | 0 | 5 | 0 |
| `decoder_lib.hexa` | 2 | 0 | 2 | 0 |
| `decoder_block_lib.hexa` | 0 (fn-decls skipped) | — | — | — |
| `flame_d32_corpus_test.hexa` | 0 (no direct calls) | — | — | — |

## Key finding: zero direct-literal call sites in current flame stack

All real flame sources pass `T, d, nh, nkv, h` as **fn parameters**
threaded from outer scopes. The first literal binding lives in:
- `flame_d32_corpus_test.hexa::main` — `let T = 16, d = 32, nh = 4, nkv = 2, h = 64`
- `flame_block_test.hexa::main` — same shape, smaller (T=3 or T=4)

These literals reach the call site only after **inter-procedural constant
propagation** through `nn_decoder_train_step → nn_decoder_fwd →
nn_decoder_block_fwd` (3-hop chain) or `flame_block_test::*_test →
nn_decoder_block_fwd` (1-hop).

## Implication for Phase 4-B-2

The RFC 047 §39 "extract static dim constants" requirement cannot be
satisfied by purely call-site-local literal matching. The pass needs
ONE of:

**(a) inter-procedural constant propagation** — walk back from the
  block-call site through caller chain until literals are found. Heavy
  machinery; risk: false positives when same caller is reached via
  multiple distinct literal paths (would need to specialize the caller
  too, recursively).

**(b) source-level specialization wrappers** — add `flame_decoder_d32_3L`
  / `flame_decoder_d768_12L` wrappers that bake the dims as literals.
  Block calls become literal-tuple at the wrapper layer. Simpler;
  matches the "ONE specialized fwd + ONE specialized bwd" model from
  RFC 047 §121. Cost: source-level duplication for each target config.

**(c) attribute-driven specialization** — add a `@specialize(T=16, d=32, ...)`
  attribute on `nn_decoder_train_step` that the pass reads. Cleanest
  surface; reuses the hexa-lang attribute machinery (cf. `ai_native_pass.hexa`).
  **Caveat (2026-05-17 audit)**: hexa-lang's existing `@specialize`
  (codegen_c2.hexa §1234, ai_native_pass.hexa M340/M962/M975) is
  **type-specialized only** — emits a first-param type-guard prologue
  (`if type_of(p0) == "int" { __spec_hit = 1 }`). flame's need is
  **value-specialization** (T=16 vs T=4 emit distinct kernels). This
  is an extension to the attribute pass, not a reuse — comparable
  effort to option (b). Lowest-cost path remains option (b).

**Recommended for first emission attempt (Phase 4-B-2)**: option (b) —
the wrapper approach. Lowest risk (no compiler-internals access), gives
the literal-tuple call site the scaffold needs, and is reversible. If
performance proves out, option (c) becomes the productionization.

## Per-build IPCP feasibility audit (2026-05-17)

After the audit above, option (a) is more tractable than initially
framed. Per-build (per module_loader expanded source) caller cardinality:

**flame_d32_corpus_test build:**
- main() — single literal source at lines 50-54 (T=16, d=32, nh=4, nkv=2, h=64)
- nn_decoder_train_step — 1 caller (main), passes T/d/... as variables
- nn_decoder_fwd — 3 call sites, all in flame_d32_corpus_test (lines 136, 176, 235)
- nn_decoder_grad — 1 call site (line 186)
- nn_decoder_block_fwd / _bwd — internal to decoder_lib, single-caller per level

**All 4 nn_decoder_* callers in this build pass THE SAME variables**
(`T, d, nh, nkv, h`) traceable to the SAME literal source. Per-build
IPCP collapses to ONE specialization per fn — no multi-version explosion.

**Cross-test dims cardinality** (across all flame tests; per-build remains
single-version):

| Config | Tests using it |
|---|---|
| (T=16, d=32, nh=4, nkv=2, h=64) | flame_d32_corpus_test, flame_perf_breakdown_test |
| (T=3, d=8, nh=2, nkv=1, h=12) | flame_train_test, flame_decoder_test, flame_block_test |

Two distinct configs across the suite, but each build only ever sees
one of them. This means the Phase 4-B IR pass does NOT need to handle
multi-version dispatch within a single build — a single specialized
emission per fn suffices, conditional on the (T, d, nh, nkv, h) literal
source found in the build's main().

**Revised recommendation for Phase 4-B-2**: option (a) per-build IPCP
becomes competitive with option (b) for this specific use case. The
algorithm for the d=32·3L build is:

1. Scan expanded source for top-level `let T = <lit>; let d = <lit>; ...`
   bindings (line-adjacency heuristic for 5-tuple discovery).
2. Substitute these as literal binding rewrites in every fn that
   receives them as args.
3. Recurse: re-scan; nn_decoder_block_fwd call sites now become
   literal-tuple → eligible for specialization emission.

The IPCP substitution is purely textual: same fn body, replace `T` token
with `16` everywhere it appears post-substitution. clang -O2 then sees
the constants and unrolls. RFC 040 §2.2 fp-tol class preserved (no
reduction-order change vs Phase 3-J + 4-A-bwd baseline — preserves
F-RFC047-FALLBACK-PRESERVED + RFC 045 algorithm-byte-eq with anima).

**Path C lesson applies**: per the 2026-05-17 dV revert (commit `23705dc5`),
any emission path must preserve the SHARED reference path's reduction
order. Textual IPCP substitution achieves this by construction — the
substituted body executes the same operations in the same order, only
with constants where there were variables.

## IPCP prototype landed 2026-05-17 (commit pending)

`tool/flame_phase4b_ipcp.hexa` — text-based IPCP rewriter:
1. Scans expanded source for top-level `let T = …; let d = …; let nh = …;
   let nkv = …; let h = …` 5-tuple (line-adjacency heuristic, ≤30 non-blank
   lines lookahead).
2. For each fn in allow-list (`nn_decoder_block_fwd`, `_bwd`,
   `nn_decoder_fwd`, `nn_decoder_grad`, `nn_decoder_train_step`):
   - Locates fn body via brace-balance.
   - Word-boundary substitutes T/d/nh/nkv/h tokens with literals.
3. Writes rewritten source to `<input>.ipcp`.

Substitution count on `flame_d32_corpus_test` expanded source (5-tuple
at line 2552):

| fn | substitutions |
|---|---|
| nn_decoder_block_fwd | 212 |
| nn_decoder_block_bwd | 254 |
| nn_decoder_fwd | 106 |
| nn_decoder_grad | 124 |
| nn_decoder_train_step | 19 |
| **total** | **715** |

Scaffold rescan of rewritten source: 2/2 call sites → literal-tuple
(was 0/2 on input). dims_hash `0x388e4067` for both fwd and bwd —
emit-once-reuse-many semantic confirmed.

### Verification matrix (5-run convention per PERF.md)

| Falsifier | Result |
|---|---|
| F-RFC047-IPCP-SOURCE-FOUND | PASS (anchor at line 2552) |
| F-RFC047-IPCP-SUBST-COUNT | PASS (715 total, ≥1 per fn) |
| F-RFC047-IPCP-RESCAN-LITERAL | PASS (0 → 2 literal-tuple sites) |
| F-RFC047-IPCP-BYTE-EQ | PASS (baseline vs IPCP stdout byte-identical) |
| F-RFC047-BLOCK-WALL-IMPROVED | **PARTIAL** (1.28×, below ≥2× minimum) |

**Wall measurement (5-run on M-Mac, var noted per PERF.md convention):**

| State | walls (s) | avg | var |
|---|---|---|---|
| baseline (Phase 4-A-bwd 5602833f) | 12.806, 12.725, 12.575, 12.419, 12.344 | 12.574 | 3.7% |
| IPCP rewrite (this prototype) | 9.727, 9.840, 9.895, 9.817, 9.793 | **9.814** | 1.7% |

**Speedup = 12.574 / 9.814 = 1.28× (22% wall reduction)**

### Honest assessment vs RFC 047 §137 F-RFC047-BLOCK-WALL-IMPROVED

The ≥3× target requires kernel emission (Phase 4-B-3), not IPCP alone.
clang -O2 with constants visible still must call separate fns
(block_fwd → attn_core_fwd → swiglu_fwd → ...) — fn call overhead +
memory traffic dominate at sub-25ms-per-step granularity.

IPCP delivers what it can: per-statement constant folding + loop-bound
unrolling hints + small-array stack allocation when sizes become literals.
Measured 1.28× is the floor of the Phase 4-B mechanism family; the
≥3× ceiling requires the emission step.

**Decision**: ship IPCP as Phase 4-B-2 increment (22% wall reduction +
zero correctness risk + byte-eq verified) — it's shippable on its own
merits. The ≥3× target moves to Phase 4-B-3 (kernel emission), where
the IPCP-rewritten source becomes the input.

### Why IPCP alone delivers less than expected

Hypothesis (testable in future cycles):
1. fn call overhead at ~200K calls/run (T=16 × 80 steps × ~150 inner
   fn calls per block_fwd) — non-constant share.
2. Per-block farr alloc/free pattern (Bp_l, Bc_l, Xc scratch buffers)
   dominates total wall — same allocator pressure regardless of
   constants visible.
3. dt_sqrt / dt_exp / dt_ln Taylor-series fn calls — same iteration
   count regardless of constant args.

Targeting (1) + (2) is Phase 4-B-3 emission scope; targeting (3) is
RFC 040 §3 transcendental routing (orthogonal).

## Reproducible build wrapper (2026-05-17)

`tool/flame_phase4b_build.sh` — single-command reproducible IPCP build:
1. module_loader flatten → `/tmp/<stem>_expanded.hexa`
2. flame_phase4b_ipcp rewriter → `/tmp/<stem>_ipcp.hexa`
3. hexa_v2 transpile → `build/artifacts/<stem>_ipcp.c`
4. clang -O2 → output binary

Verified: re-running the wrapper yields byte-identical output to the
ad-hoc pipeline used in the IPCP commit measurement
(F-RFC047-IPCP-REPRO-BYTE-EQ PASS via diff).

### Cross-config IPCP robustness (2026-05-17)

Verified IPCP across 3 distinct flame test configs:

| test source | dims | substitutions | byte-eq vs baseline |
|---|---|---|---|
| flame_d32_corpus_test | (T=16, d=32, nh=4, nkv=2, h=64) | 715 | PASS |
| flame_perf_breakdown_test | (T=16, d=32, nh=4, nkv=2, h=64) | 715 | TIMING-DIFF-EXPECTED |
| flame_decoder_test | (T=3, d=8, nh=2, nkv=1, h=12) | 696 | PASS |
| flame_block_test | (T=3, d=8, nh=2, nkv=1, h=12) | 466 | PASS |

The `TIMING-DIFF-EXPECTED` marker on flame_perf_breakdown_test is honest:
that test reports its own measured wall in the stdout (`fwd: 3 ms avg
(range 3-4ms; 18%)` baseline vs `3 ms avg (range 3-3ms; 25%)` IPCP).
The algorithm-level outputs (loss values, accuracies) remain byte-eq
across configs — the diff is intentional measurement-of-measurement.

substitution counts differ across configs because:
- toy configs (T=3·d=8) lack `nn_decoder_train_step` callers (flame_block_test)
  or test-harness lacks `train_step` (flame_decoder_test)
- substitution count IS proportional to the # of usage sites for each
  target fn in the build's expanded source

**Implication for Phase 4-B-3-2 emission**: emitter must handle multiple
dims_hash tuples per build cleanly. Currently only one config per build
in the flame suite, but the dims_hash-driven emit-once-reuse semantic
(verified: same hash for fwd/bwd at same dims) gracefully scales to
multi-config builds if the design allows. RFC 047 §121's "ONE
specialized fwd + ONE specialized bwd per (T,d,nh,nkv,h) tuple"
remains the correct invariant.

Usage:
```bash
tool/flame_phase4b_build.sh \
    stdlib/flame/flame_d32_corpus_test.hexa \
    build/flame_d32_corpus_ipcp
```

## Inconclusive: clang -flto probe (2026-05-17, no claim filed)

Tried adding `-flto` to the clang -O2 step on the IPCP-rewritten C.
Result: 5-run avg 9.459s (range 8.95-10.52, var 16.5%) — apparent
3.6% improvement over IPCP-only 9.814s, but **dominated by measurement
variance**. macOS scheduler/thermal effects produce 1.5s wall drift
across consecutive runs on this workload, swamping any sub-5%
optimization gain.

Re-run on second pass: 5-run avg 10.899s (range 10.30-11.42, var 4.9%).
This is **higher** than the first pass — confirming the variance is
NOT a stable measurement.

Decision: do NOT ship -flto for Phase 4-B-2. The signal-to-noise
ratio at this wall scale is insufficient for honest claim-filing.
Re-evaluate at Phase 4-B-3 when kernel emission collapses fn-call
overhead and exposes a larger expected gain.

Also: `flame_d32_baseline_lto` link FAILED (`symbol(s) not found for
arm64`) when -flto applied to the production hexa_v2-emitted C
without prior IPCP — the runtime symbols' LTO marker visibility
diverges between the two pipelines. Separate investigation if -flto
returns to consideration.

## What's NOT in scope for Phase 4-B-1 scaffold

- Build flag `--flame-phase4b` (next cycle — wire to `cmd_build`)
- AST-level walking (text-scan is sufficient for detect-only)
- Source rewriting (no emit yet)
- Inter-procedural CP (option (a) above — separate Phase 4-B-1.5 if pursued)

## Algorithm self-anchor

`dims_hash = djb2((T,d,nh,nkv,h) text)` — deterministic, 31-bit positive int.
Same tuple text always hashes to same value → idempotent + duplicate-free
across multiple call sites with the same dims. Verified: `T=16, d=32,
nh=4, nkv=2, h=64` → `0x388e4067` for both fwd and bwd calls (same hash =
emit-once-reuse semantic, RFC 047 §121).

## Cross-link

- RFC 047 §39 (pass placement) + §54 (pattern matching) + §144 (Phase 4-B-1)
- PERF.md "Path C attempt" (REVERTED 2026-05-17) — lesson for Phase 4-B-2
  emission: must operate on SHARED reference path or preserve reduction
  order, else Phase 2 strict byte-eq regresses
- `tool/flame_phase4b_scan.hexa` — the scaffold tool itself
