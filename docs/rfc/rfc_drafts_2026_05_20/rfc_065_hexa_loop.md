# RFC 065 — `hexa loop` self-growing atlas cycle (binary built-in lens system)

- status: DRAFT (spec + 8-stage cycle + 8-family seed lens; scaffold pending)
- created: 2026-05-20
- authority:
  - `@D g_atlas_binary_builtin` — atlas is unconditionally binary built-in
    (`compiler/atlas/embedded.gen.hexa`); new equations land via PR
    only — **direct fold-to-live forbidden even on the owner repo**.
    This RFC extends the same shape to a sibling lens SSOT.
  - `@D g6 citation-enforced-strict-lint` — every emitted candidate
    cites a prior atlas node (`@cite <atlas-id>`); stage 4 of strict
    lint rejects un-cited candidates the same way it rejects un-cited
    formulas.
  - `@D g7 inbox-patches-pipeline` — loop output is filed to
    `archive/{atlas,lens}_candidates/` (sibling stream to
    `archive/patches/`), never merged inline.
  - `@D g_interp_deprecated` — `hexa loop` is the compiled-path
    binary, not an interp-mode reflection.
- consumer: new verb `hexa loop` in `self/main.hexa`; new sibling
  `compiler/lenses/embedded.gen.hexa` baked-in at compile time alongside
  `compiler/atlas/embedded.gen.hexa`.
- legacy reference: `dancinlab/archive-nexus` (GitHub private archive,
  2026-04-03 → 2026-05-17 absorbed). "130+ lens engine" framing
  inherited from that archive's `.loop`/`.chain`/`.gap_cooldown`/
  `.goal_growth_*` state-file convention; the engine itself was not
  ported as code (only the optimizer port `self/nexus_port/` was
  absorbed — confirmed empty of lens assets, see §11).
- sibling RFCs: 044 (qrng absorption) · 045 (qmirror) · 046 (sim-
  universe) — same "binary built-in stdlib + frozen archive" shape;
  this RFC adds the **introspective** axis.

---

## §1 Problem

The compiler today carries a 24k-node binary built-in atlas, but has no
mechanism to **grow** it programmatically with falsifier-clean rigor.
Every new equation/constant/law lands by hand: a human authors an
`archive/patches/<slug>.md`, opens a PR, regenerates
`compiler/atlas/embedded.gen.hexa`. There is no in-band way for the
compiler to walk its own atlas, identify under-covered regions, propose
candidate hypotheses, and queue them for review.

`tool/hx_meta_gap_proposer.hexa` is the closest existing seed (mines
`git log` for "workaround"/"hotfix" subjects), but it is a single ad-
hoc tool, runs out of band, and proposes lint-rule gaps — not atlas
hypotheses.

The archive-nexus engine demonstrated a viable shape: a finite-state
cycle (`.loop`/`.chain`/`.gap_cooldown`/`.goal_growth_*`/`.turn`/
`.end`) that runs N lenses over a corpus, emits scored candidates,
and self-terminates on "brainstorm exhaustion" (k cycles consecutive
zero candidates). That archive is frozen; this RFC reconstructs the
shape in-band as a first-class `hexa` verb, with the lens table itself
made binary built-in (symmetric with the atlas).

## §2 Goals

- **G-L0** — `hexa loop` verb registered in `self/main.hexa`; `--help`
  · `--once` · `--budget N` · `--time <duration>` · `--lenses <list>`
  · `--no-fire`/`--fire --budget <USD>` · `--resume` · `--status` ·
  `--dry-run` parse and dispatch.
  - Exit fixture: `hexa loop --once --no-fire --dry-run` runs the full
    8-stage cycle against the current atlas, emits 0..N candidates to
    a tmpdir (not archive/atlas_candidates/), and returns rc=0.
- **G-L1** — `compiler/lenses/embedded.gen.hexa` exists as a sibling
  SSOT to `compiler/atlas/embedded.gen.hexa`; both are merged at compile
  time. Initial 32 seed lenses (8 families × 4 seeds) emit valid
  `LensNode` records with `apply: fn(AtlasView) -> [Candidate]`
  signature.
  - Exit fixture: `hexa atlas verify --include-lenses` reports 32
    lenses bound, 0 schema violations.
- **G-L2** — 8-stage cycle contract (SCAN · LENS · DEDUP · GATE · FIRE
  · DRAFT · AUDIT · EXHAUST?) is implemented in `stdlib/loop/cycle.hexa`
  and round-trips through `$HEXA_LANG/state/loop/<cwd_hash>/{loop,chain,
  gap_cooldown,goal_growth_state.json,growth_last_scan,
  growth_session_snapshot.json,turn,end,guide}`.
  - Exit fixture: two consecutive `hexa loop --once` calls observe
    cooldown carry-over (same slug not re-emitted within N=5).
- **G-L3** — exhaustion criterion fires deterministically: 3 cycles
  consecutive 0 candidates AND cooldown set empty → `.end` is touched,
  process exits rc=0, stdout reports `🎯 brainstorm exhausted`.
  - Exit fixture: synthetic atlas with all lenses pre-cooldowned
    reaches exhaustion in exactly 3 cycles.
- **G-L4** — fire gate is opt-in: `--no-fire` (default) emits only
  analytically-resolvable candidates; `--fire --budget <USD>` raises
  the gate and routes measurement to the wilson-pool (ubu-2 GPU lane
  for forge-class fires, local clang for cheap fires).
  - Exit fixture: `--no-fire` cycle with 1 fire-required candidate
    emits it as `STATUS: deferred-fire` in `archive/atlas_candidates/`;
    a follow-up `--fire --budget 5` re-promotes and emits as
    `STATUS: measured`.
- **G-L5** — PR-only invariant: loop never writes to
  `compiler/atlas/embedded.gen.hexa` or
  `compiler/lenses/embedded.gen.hexa` directly. All output is
  `archive/{atlas,lens}_candidates/<slug>.md`. `hexa atlas pr` /
  `hexa lens pr` (new sibling verb) is the only path to baked-in.
  - Exit fixture: `audit_forbidden_exts.hexa`-style check; loop write
    set must be a subset of `{archive/atlas_candidates/**, $HEXA_LANG/state/loop/**,
    /tmp/**}`.

## §3 Non-goals

- **Not an LLM agent.** Lenses are deterministic functions over the
  atlas. No model calls inside the cycle. (A future RFC may add an
  LLM-backed `lens_llm` family; out of scope here.)
- **Not a fuzzer.** Candidates are atlas hypotheses with explicit
  derivation chains (`@cite` + reasoning trail), not random inputs.
- **Not auto-merge.** The PR-only invariant is non-negotiable; the
  loop never bakes itself in.
- **Not a CI replacement.** `hexa verify` / `hexa build` are still the
  release gate. `hexa loop` runs offline at author intent.

## §4 Decision ledger (cross-link)

The 7 architectural decisions for this RFC are recorded in
`docs/rfc/rfc_drafts_2026_05_20/design.md` (sibling file) per
`@D g_inbox_processing_loop` step-by-step convention:

| # | Decision | Picked |
|---|---|---|
| 1 | Lens storage location | `compiler/lenses/embedded.gen.hexa` neighbor of atlas |
| 2 | Lens seed source | hybrid (8 family × 4 = 32 from-scratch; nexus_port was optimizer port, not lens engine) |
| 3 | State file location | `$HEXA_LANG/state/loop/<cwd_hash>/` (XDG-style, qrng/qmirror sibling) |
| 4 | Candidate output trays | `archive/{atlas,lens}_candidates/` sibling streams |
| 5 | Cooldown policy | hard-block N=5 cycles (slug forbidden for re-emission) |
| 6 | Fire license default | `--no-fire` default; opt-in `--fire --budget <USD>` |
| 7 | Exhaustion criterion | 3 cycles consecutive 0 candidates ∧ cooldown empty |

## §5 CLI surface

```
hexa loop [--once | --budget N | --time <dur>]
          [--lenses <family,family,... | id,id,...>]
          [--no-fire | --fire --budget <USD>]
          [--resume]
          [--status]
          [--dry-run]
          [--help]
```

- `--once` — run a single cycle and exit (default for CI).
- `--budget N` — run up to N cycles or until exhaustion.
- `--time <dur>` — run until wall-clock budget exhausted (`30m`, `1h`).
- `--lenses` — restrict active lens set by family or id (default = all
  registered).
- `--no-fire` — analytical-only (Wilson fire-gate "settled" branch);
  default.
- `--fire --budget <USD>` — opt-in measurement, capped at budget.
- `--resume` — read `$HEXA_LANG/state/loop/<cwd_hash>/loop` and
  continue from cycle counter.
- `--status` — print current state (cycle counter · lens roster ·
  cooldown set size · goal_growth scores) and exit.
- `--dry-run` — emit candidates to tmpdir not archive/atlas_candidates/, no
  `growth_last_scan` mutation.

## §6 State files (`$HEXA_LANG/state/loop/<cwd_hash>/`)

`<cwd_hash>` is a 12-char hex of SHA-256(cwd), so `hexa loop` in
different repos sandboxes independently.

| file | role | format |
|---|---|---|
| `loop` | cycle counter + lens cursor | single line `cycle=N lens_idx=M ts=<iso>` |
| `chain` | derivation chain across cycles | append-only JSONL, one row per emitted candidate |
| `gap_cooldown` | cooldown blocklist | JSON map `{slug: expiry_cycle}` |
| `goal_growth_state.json` | per-north-star score (① flame, ② self-host, ③ comb) | JSON `{star_id: {score, last_delta, ts}}` |
| `growth_last_scan` | corpus hash of last SCAN | single line `hash=<sha256> ts=<iso>` |
| `growth_session_snapshot.json` | session-local candidate stack pre-DRAFT | JSON array |
| `turn` | turn counter (LLM-budget shadow, currently always inc by 1) | integer |
| `end` | exhaustion sentinel | touch-file; if present, `hexa loop` rc=0 noop |
| `guide` | user-provided focus prompt (optional) | free text; weights lens scoring |

All files are HXC v2 emit-able (`@D g_hxc`) when read by external
tooling — internal write path uses plain JSON for greppability.

## §7 8-stage cycle contract (`stdlib/loop/cycle.hexa`)

```
1. SCAN   — read compiler/atlas/embedded.gen.hexa + recent N commits +
            archive/patches/ + compiler/PLAN.md unresolved TODO → corpus
            hash. If hash == growth_last_scan.hash AND --resume,
            short-circuit to LENS with cached corpus.
2. LENS   — for each active lens (filtered by --lenses), call
            apply(AtlasView) -> [Candidate]. Concatenate.
3. DEDUP  — drop candidates whose slug is in gap_cooldown (unexpired)
            OR matches an existing atlas/lens node id OR matches an
            existing archive/{atlas,lens}_candidates/<slug>.md.
4. GATE   — classify each surviving candidate per Wilson fire-gate:
            settled (analytical) vs genuinely-uncertain (needs fire).
5. FIRE   — if --no-fire: defer uncertain candidates (STATUS:
            deferred-fire). If --fire: route to wilson-pool, attach
            measurement to candidate.
6. DRAFT  — write archive/{atlas,lens}_candidates/<slug>.md with full
            derivation trail (@cite list, lens id, cycle id, fire
            result if any).
7. AUDIT  — append to chain (JSONL row per candidate), update
            gap_cooldown (slug → cycle + 5), update
            goal_growth_state.json (per north-star delta).
8. EXHAUST?— if last 3 cycles ALL emitted 0 candidates AND
            gap_cooldown is empty (all expired) → touch end, exit.
            Else: increment cycle counter, loop.
```

## §8 Lens trait + binary built-in schema

```hexa
// compiler/lenses/embedded.gen.hexa  (auto-regenerated by `hexa lens pr`)
struct LensNode {
    kind: string,         // "L" (lens)
    id: string,           // canonical slug, e.g. "empty_space.unmapped_axis"
    family: string,       // one of 8: empty_space | paradigm_shift |
                          //   cross_pollinate | counterexample_mine |
                          //   invariant_stress | scale_extrapolate |
                          //   constraint_flip | falsify_self
    cite: array,          // [atlas_node_id, ...] prior bindings
    apply: fn(view: AtlasView) -> array,  // -> [Candidate]
}
struct Candidate {
    slug: string,         // unique stable id (used by cooldown)
    family: string,
    proposed: string,     // human-readable hypothesis
    cite: array,          // [atlas_node_id, ...]
    fire_needed: bool,    // GATE stage 4 classification
    fire_estimate_usd: float,  // populated by lens, used by --budget
}
```

`AtlasView` is the read-only view over `compiler/atlas/embedded.gen
.hexa` exposed by `compiler/atlas/loader.hexa` (already exists for
existing atlas consumers).

## §9 8 family seeds (32 initial lenses, family × 4)

| family | seed lenses (4 per family) |
|---|---|
| `empty_space` | unmapped_axis · degree_hole · cross_product_gap · zero_coverage_quadrant |
| `paradigm_shift` | inversion · dual · adjoint · op_lift |
| `cross_pollinate` | borrow_from_qrng · borrow_from_qmirror · borrow_from_sim_universe · borrow_from_forge |
| `counterexample_mine` | n7_break · n5_break · scale_break · regime_break |
| `invariant_stress` | conservation_violation · symmetry_break · monotonicity_break · idempotence_break |
| `scale_extrapolate` | N→2N · N→N/2 · 1D→2D · 2D→3D |
| `constraint_flip` | flip_sign · flip_ordering · flip_topology · flip_dim |
| `falsify_self` | re_cite_audit · @cite_unreachable · stale_node_decay · contradiction_pair |

Each seed lens ships with a 5-line docstring stating its derivation
basis and `@cite` chain. The 130+ target is reached by per-family
expansion in subsequent PRs (not gated on this RFC).

## §10 Governance compliance matrix

| rule | how this RFC complies |
|---|---|
| `@D g_atlas_binary_builtin` | new lens SSOT mirrors the same "binary built-in, PR-only, .n6 export-only" shape |
| `@D g6 citation-enforced` | every Candidate carries `cite: [atlas_node_id, ...]`; lint stage 4 applies |
| `@D g7 inbox-patches-pipeline` | output trays are sibling streams (`archive/{atlas,lens}_candidates/`) |
| `@D g_interp_deprecated` | `hexa loop` is the compiled-path binary; no interp surface |
| `@D g_commit_push_deploy` | lens PR includes regenerated `compiler/lenses/embedded.gen.hexa` + paired binary promote |
| `@D g_plan_consolidation` | per-cycle progress lands in `compiler/PLAN.md` `## 진행 로그`; this RFC is one entry |
| `@D g_stdlib_ownership` | `stdlib/loop/` is hexa-lang owned; downstream consumes via verb, never copies |
| `@D g3 verification-anchor-real-limit` | FIRE stage results MUST tie to a real-limit anchor (Shannon, Kolmogorov, c, ℏ, compiler invariant) |
| Wilson fire-gate | GATE stage 4 applies measure-vs-predict natively; `--no-fire` honors the "settled" branch |

## §11 Anti-claims (false starts ruled out)

- **archive-nexus 130+ lens engine is NOT inherited as code.**
  `self/nexus_port/` (the absorption sink) holds only 7 compile-time
  optimizer modules (algebraic · approximate · gate · lazy · parallel
  · specialize · symbolic) — none are lens engines. Decision 2 was
  picked as A (extract from `self/nexus_port/`); on inspection,
  fallback to B (32 hybrid from-scratch) auto-fired. The "130+"
  framing is a roadmap target reached by PR-driven expansion, not a
  day-one promise.
- **archive-nexus 130+ lens engine is NOT inherited as a dot-file
  convention.** Only the state-file *names* are reused (`.loop` ·
  `.chain` · `.gap_cooldown` · `.goal_growth_state.json` · etc.); the
  underlying schemas are re-specified in §6.
- **Not a replacement for `hexa kick` (RFC-pending in `docs/notes/`).**
  `hexa kick` is a one-shot autonomous cycle; `hexa loop` is the
  repeated, cooldown-bound, exhaust-terminating variant. They may
  share a runner backend in a future RFC.

## §12 Falsifiers

The RFC is wrong if any of these fire:

- **F1** — A `hexa loop --once --no-fire --dry-run` invocation mutates
  `compiler/atlas/embedded.gen.hexa` or
  `compiler/lenses/embedded.gen.hexa`. (PR-only invariant breach.)
- **F2** — Two consecutive `--once` calls re-emit the same slug
  within 5 cycles. (Cooldown breach.)
- **F3** — A synthetic atlas where every lens emits 0 fails to reach
  exhaustion in exactly 3 cycles (off-by-one OR infinite loop).
- **F4** — `--fire --budget 0` performs any measurement.
- **F5** — Any emitted Candidate lacks a `cite:` field, or cites an
  atlas node id that does not exist in `compiler/atlas/embedded.gen
  .hexa`. (Strict-lint stage 4 breach.)

## §13 Phase plan

| phase | deliverable | gate |
|---|---|---|
| **A** — this RFC | spec + decision ledger + PLAN entry | reviewable, 0 code change |
| **B** — scaffold | `compiler/lenses/embedded.gen.hexa` skeleton (8 seed × 4 = 32 lenses, all returning `[]`) + `stdlib/loop/cycle.hexa` 8-stage shell + `self/main.hexa` verb + `--dry-run` selftest | G-L0 + G-L1 exit fixtures |
| **C** — measurement | seed lens bodies populated, `--no-fire` produces first real candidates, `archive/atlas_candidates/` first PR | G-L2..G-L5 exit fixtures |

Phases B and C are separate RFCs (or RFC-scoped patches landed
incrementally). This RFC ships the spec only.

## §14 Open questions (not gating)

- **lens authoring DSL?** Currently lenses are plain `.hexa` functions.
  A future RFC may add a sugar layer (`@lens(family="empty_space")
  fn unmapped_axis(...)`).
- **goal_growth_state.json scoring?** Currently per-north-star delta is
  `+1 per emitted candidate that cites a node touching that star`.
  A more principled metric (information gain · MDL) is future work.
- **multi-host parallel cycle?** `hexa loop` runs single-process. A
  fan-out across wilson-pool hosts (one family per host) is plausible
  future RFC.

---

## Sign-off checklist (Phase A landing)

- [x] decision ledger sibling (`design.md`) committed
- [x] `compiler/PLAN.md` `## 진행 로그` single-entry append
- [ ] reviewer agree on schema (§8), exhaustion (§7), governance (§10)
- [ ] reviewer agree on falsifier set (§12)
- [ ] approved → file moves to `archive/patches/rfc_landed/` and Phase B starts
