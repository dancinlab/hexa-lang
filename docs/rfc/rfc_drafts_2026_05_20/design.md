# RFC 065 — `hexa loop` design decision ledger

Companion to `rfc_065_hexa_loop.md`. Each decision recorded per
`@D g_inbox_processing_loop` step-by-step convention (one user
confirmation gate per decision, never batched). Decisions 1-4
confirmed by user; Decisions 5-7 auto-locked under "추천으로 진행해줘"
authorization (autonomy mode within the bounded decision set).

---

### Decision 1 — Lens storage location

- **picked**: `compiler/lenses/embedded.gen.hexa` (neighbor of
  `compiler/atlas/embedded.gen.hexa`)
- **rationale**:
  - atlas and lens are both binary built-in compile-time knowledge
    — sibling directory structure makes the symmetry visible
  - each gets its own PR flow (`hexa atlas pr` · `hexa lens pr`),
    each its own dedicated SSOT, no schema merge complexity
  - `@D g_atlas_binary_builtin` "direct fold-to-live forbidden"
    extends cleanly to a sibling without re-arguing the invariant
- **rejected**:
  - **B** (add LensNode kind to atlas embedded.gen.hexa) — atlas.n6
    export schema would inflate to carry lens records; mixes two
    PR cadences in one file
  - **C** (stdlib/loop/lenses/*.hexa, not baked) — violates
    `@D g_atlas_binary_builtin` symmetry; lens becomes wild-west
    while atlas stays PR-gated, asymmetry will be regretted

---

### Decision 2 — Lens seed source

- **picked**: hybrid (8 family × 4 = 32 from-scratch); A (extract from
  `self/nexus_port/`) was the initial pick but fallback fired on
  inspection
- **rationale**:
  - `self/nexus_port/` inspection showed 7 modules (algebraic,
    approximate, gate, lazy, parallel, specialize, symbolic) — these
    are compile-time optimizer ports, NOT lens engines
  - the "archive-nexus 130+ lens engine absorbed" framing in the
    tombstone refers to firmware/RTL-side absorption, not code-lens
  - 8-family × 4-seed = 32 covers all canonical breakthrough lens
    families documented in `LIMIT_BREAKTHROUGH.md`; reaches 130+ by
    PR-driven expansion, not selective design
- **rejected**:
  - **A original** (extract from `self/nexus_port/`) — auto-fallback
    fired; no lens code present at extraction site
  - **C** (full from-scratch 130-spec then bulk implement) — spec-
    first risk: many of 130 may have effective coverage of zero;
    iterative expansion is the safer regime

---

### Decision 3 — State file location

- **picked**: `$HEXA_LANG/state/loop/<cwd_hash>/` (XDG-style global,
  cwd-hashed for multi-repo isolation)
- **rationale**:
  - matches existing `state/hx_meta_gap.json` pattern from
    `tool/hx_meta_gap_proposer.hexa` (already canonical location for
    loop-class state)
  - matches qrng / sim_universe / qmirror sibling stdlib pattern (all
    write to `$HEXA_LANG/state/<domain>/`)
  - cwd_hash subkey gives multi-checkout / multi-repo isolation
    without per-repo gitignore noise
- **rejected**:
  - **B** (`./.hexa/loop/` repo-local) — git-status noise, gitignore
    needed, multi-checkout collisions, asymmetric with absorbed
    stdlib governance
  - **C** (`~/.hx/loop/`) — single global state forces all repos to
    share cooldown; defeats independent cycle progress

---

### Decision 4 — Loop output trays

- **picked**: `archive/atlas_candidates/` + `archive/lens_candidates/`
  (new sibling streams)
- **rationale**:
  - atlas and lens each have their own PR flow; separate trays make
    each stream's pipeline visible at directory granularity
  - `archive/patches/` (downstream consumer requests) stays
    semantically isolated from self-generated candidates — no
    priority confusion in `ls archive/patches/`
  - the same SOP from `@D g_inbox_processing_loop` applies (filing →
    sub-agent → cherry-pick), just with two trays
- **rejected**:
  - **B** (reuse `archive/patches/` with slug prefix) — consumer
    patches and self-generated candidates would share one tray;
    `ls` loses information about pipeline kind
  - **C** (single `archive/loop_proposals/` tray) — PR flow forks
    two ways but tray is unified; `ls` again loses info

---

### Decision 5 — Cooldown policy

- **picked**: hard-block N=5 cycles (slug forbidden from re-emission
  for 5 cycles after last emit)
- **rationale**:
  - deterministic exhaustion guarantee: with hard-block, the
    candidate space is monotonically decreasing per cycle (modulo
    new corpus content); soft-deprioritize allows asymptotic
    creep that never terminates
  - matches archive-nexus `.gap_cooldown` original semantics
    (cooldown is the EXIT condition, not a weighting hint)
  - N=5 is short enough for genuine re-discovery if corpus
    changed materially, long enough that local thrashing is
    impossible
- **rejected**:
  - **soft-deprioritize** (weight × 0.5 per re-emit) — defeats
    exhaustion guarantee; loop may run forever with diminishing
    candidates
  - **N=1** — too short, immediate re-emission noise
  - **N=10+** — too long, blocks legitimate re-evaluation after
    corpus shift

---

### Decision 6 — Fire license default

- **picked**: `--no-fire` default; opt-in `--fire --budget <USD>`
- **rationale**:
  - matches Wilson fire-gate "settled-by-default, fire only when
    genuinely uncertain" discipline (`/wilson-fire-gate sample`)
  - safe default: `hexa loop` in CI or unattended cron does not
    accidentally burn budget on a GPU pool
  - explicit budget cap (`--budget 5` = $5 USD) makes the cost
    surface explicit at invocation, not hidden in config
  - settled-branch candidates still emit (with `STATUS:
    deferred-fire`); a follow-up `--fire` run can re-promote
- **rejected**:
  - **fire-default + --no-fire opt-out** — Wilson fire-gate
    inversion; unattended runs default-spend on measurement;
    cost surprises
  - **mandatory `--fire`** (no `--no-fire` at all) — blocks
    cheap analytical cycles entirely

---

### Decision 7 — Exhaustion criterion

- **picked**: 3 cycles consecutive 0 candidates AND
  `gap_cooldown` set empty (all expired) → touch `.end`, exit rc=0
- **rationale**:
  - matches archive-nexus original convention (k=3 in observed
    `.loop`/`.chain` semantics)
  - "AND cooldown empty" prevents premature exhaustion when
    candidates are merely temporarily blocked, not genuinely absent
  - deterministic: combined with Decision 5 hard-block, gives a
    formally finite cycle bound = `len(active_lenses) × N=5`
  - cheap to check (O(1) per cycle on two counters)
- **rejected**:
  - **k=5 consecutive 0** — slower exhaustion; per cost analysis
    above, k=3 is already provably finite
  - **derivative threshold** (lens-per-lens slope `dN/dt < ε`) —
    sound but expensive; non-trivial to define ε across families
  - **manual `.end` only** — eliminates auto-exhaustion property
    that the entire RFC is named for

---

## Cross-references

- `@D g_atlas_binary_builtin` — atlas / lens dual-SSOT invariant
- `@D g_inbox_processing_loop` — decision-gate convention
- `@D g7 inbox-patches-pipeline` — output tray governance
- `@D g_plan_consolidation` — single PLAN.md SSOT
- `@D g_interp_deprecated` — compiled-path verb
- archive-nexus tombstone (GitHub `dancinlab/archive-nexus`, 2026-05-17)
- `tool/hx_meta_gap_proposer.hexa` — existing seed for lens family
  `empty_space.coverage_hole` (relink in Phase B)
