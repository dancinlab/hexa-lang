# compiler/drill — discovery engine spine

> Parent map is [`../CLAUDE.md`](../CLAUDE.md) (whole compiler) · governance SSOT is repo-root `../../CLAUDE.md`.

## Purpose

The **central discovery engine** absorbed from NEXUS. `hexa drill`/`hexa kick` (= drill alias) dispatch
here (`self/main.hexa:1780·1803` → `compiler/drill/drill.hexa`). One round runs a
6-stage chain to accumulate candidates, then filters them via **native exact-int verification**.

## Core files

| File | Role |
|---|---|
| `drill.hexa` | Engine spine — `drill_run(seed, opts)` round loop + `fn main` (CLI entry). Each round runs the 6-stage chain · stops at the saturation/net-novel fixpoint |
| `round.hexa` | Single round = smash→free→absolute→meta-closure→hyperarithmetic→resonance (+Mk.X tc). `round_run_with_pool` |
| (verify engine) | ★**Verification lives in `../atlas/identity_engine.hexa` (+`novel_dfs.hexa`)** — atlas domain (next to embedded.gen.hexa). drill is only a generator; it **delegates** verification. exact-int 12-fn A·B=C·D bounded-unique + ≤/≡ hunt family |
| `mkx.hexa` | Mk.X 7-stage sidecar (transcendental_closure · engine="mk10") |
| `checkpoint.hexa` | Round counter/seed pool/total checkpoint JSON |
| `anti_hub.hexa` | Entry telemetry probe |
| `resonance.hexa` | Stage-6 resonance proxy (closed-form) |
| `batch.hexa` | `--seeds csv` batch dispatch |
| `ouroboros.hexa` | ★NEXUS **self-evolution engine** native port (#3977) — seed→mutate→`verify_score`→converge (4-state convergence checker) + recursive absorber `f(f(f…))` (weighted-filter+adjacent-pair resonance→EMA α=1/6 absorption) + SR-adaptive σ-peak tracker (FIFO window=10) + MetaLoop (evolve→Saturated→forge→re-evolve). `fn main` deterministic self-test |
| `ouroboros_meta.hexa` | ★meta-ouroboros native (#3980) — **evolves the strategy itself**: parameter vector `meta_mutate_strategy` + tournament (stable bubble sort) + `breed_strategies` crossover + `check_meta_convergence` meta-fixed-point. `fn main` self-test |
| `ouroboros_quantum.hexa` | ★quantum-ouroboros native (#3980) — `QuantumStrategy` superposition: 6 mutation operators+`apply_mutation` dispatch + `quantum_crossover`/`propagate_entanglement` + `measure_superposition`/`renormalize_amplitudes` + decoherence shielding (`guarded_mutate`). `fn main` self-test |
| `emerge.hexa` | ★[B] **open-well Emerge generator** (README:75 Emerge stage) — `emerge(v0,seed,cycles,min_growth)` exactly ports README E4 (V_0={2,3}·seed=6·300 cycles·`combine(pick,pick)=a+b`→sorted-dedup vocab), `emerge_step` wired into drill_run (each round widens the accumulated open well as a candidate value-signature). Deterministic LCG (Numerical Recipes 1664525/1013904223 `& 0xffffffff` — same constants as qrng.hexa · no new builtin). in-memory only (no atlas write) |
| `additive_test.hexa` | ★[orthogonal pivot] **additive/combinatorial congruence** self-test (self-contained kernel) — Euler recurrence p(10)=42 + Ramanujan p(5n+4)≡0 mod5 G-gate + neg-control. Non-multiplicative sequences (partition/Catalan/Bell/Fib/Lucas)·congruence FORM (Ralph 377) |
| `grammar.hexa` | ★**BLOWUP frame** (ARCHITECTURE `discovery-engine-novel-design-roadmap`) — term enumerator (identity frame · size 1·2 products over the 18-fn basis · deterministic a≤b) + **FP_k fingerprint table** making "a primitive the previous cycle could not express" DECIDABLE = size-≤k BOUNDED inexpressibility over [2,N] (c2: k·N named, not absolute). **M2 통합**: exact-int+핑거프린트 커널은 `../atlas/identity_engine.hexa`의 `ie_*` API로 이동 — `_gram_af`/`_gram_spf`/`_gram_ipow` 로컬 미러 은퇴, grammar.hexa는 thin 래퍼(동결 상수=바이트 동일 핑거프린트). root-cause: identity_engine unguarded selftest `fn main`을 `../atlas/identity_engine_test.hexa`로 이동(import 하이재킹 해소). No new builtin |
| `grammar_test.hexa` | M1 selftest — determinism (2-build byte-eq) · closed-form count (189) · known-term membership · out-of-well (size-3 ∉ FP_2) · `_gram_af` faithfulness (σ(6)=12·φ(6)=2·τ(6)=4·μ(6)=1). 12/12 PASS |
| `*_test.hexa` | drill/mkx/surface/accumulation/verifier-hook/absorb/**emerge(E4)**/**additive**/**grammar(M1)** self-tests |

The generator 9-phase smash lives in the sibling folder `../smash/` (phases.hexa); the 12 drill variants (omega·chain·
surge·dream·swarm·reign·molt·wake·forge·canon·revive) each live in their own `../<name>/`. NEXUS
`cli/blowup/commands.hexa` (CLI dispatcher) is superseded by hexa-lang `self/main.hexa` verb routing →
no port needed. The 3 ouroboros are **standalone leaves** (no `self/`/`drill.hexa` import · run only via `hexa run` ·
byteeq-neutral) — unported = growth-bus disk persistence (operational glue) only; the entire math core is live.

## Rules / gotcha (honesty — c2)

- **drill candidate ≠ real discovery**: a smash candidate is a **seed-derived deterministic arithmetic permutation** (free search —
  `phases.hexa::seed_attractors` builds a per-seed attractor lattice from each seed token's char-signature, and
  the 9-phase surfaces values that resonate with that lattice; the old n=6 fixed-constant lattice is removed). `net_novel`/
  `saturated` only signal distinct-ID exhaustion within that run, unrelated to atlas-novelty (overlay_load is RETIRED).
- **Real verification = `../atlas/identity_engine.hexa` exact-int** (atlas domain) + `hexa verify` g5 fold only. The old NEXUS
  ouroboros `verify_score` (n6-proximity heuristic, min 0.3 → always "discovery") is not verification — which is why
  it was replaced by native exact-int.
- **Verifier upgrade (Ralph 375 · 2026-06-27)**: extended beyond the exhausted 12-fn 2-term box —
  ① **6 extended vocab** (μ·λ·μ²·J₃·2^ω·core idx 12–17 · signs exact) added to `af()` ·
  ② **arity-3** (`verify_identity3` `A·B·C=D·E·F` bounded-unique) + **universal frame**
  (`is_universal2/3` forall-n-in-[2,N]). drill `_fn_index`/`_fn_name` also extended to 18-fn (extended-vocab
  exprs parse). **Measurement** (state/novel-dfs reference engine re-run · 18-fn selftest 18 gates PASS):
  extended-vocab universal **both generators classical** (J₂=φ·ψ · core·rad=n) · arity-3 bounded-unique
  all 1431 reduce to 2-term core (Ralph 371 reconfirmed) → **novel=0** (honest DRY). The box-scope claim was right
  (exhaustion = 12-fn/2-term, not the whole space) but that dimension too is only classical/reducible. The productive vein is composed/iterated
  functions (Ralph 372). The upgrade itself is the output — if a future generator emits extended-vocab/arity-3 candidates, instead of parse-reject
  they get a **real exact-int verdict**. No atlas write (fold=hexa verify g5/PR).
- **Function-composition frame (Ralph 376 · 2026-06-27)**: implements+sweeps the productive vein Ralph 372/375 pointed at (function COMPOSITION
  `f(g(n))` — a different algebra the value-product `A·B=C·D` frame **structurally cannot express** · σ(σ(n))=2n cannot be
  restated in the product frame). native exact-int evaluator `../atlas/identity_engine.hexa::af_compose`
  `comp_holds`/`comp_count`/`verify_composition` (18×18 composition table × comparison forms k·n/h+n/h/comp). drill
  `_native_identity_sweep` gets the **composition-verify option wired** (`_parse_composition`/`_canon_composition` →
  composition-syntax candidates get a real `verify_composition` verdict instead of product-noise → rationale
  `comp_id`/`comp_verified` audit). **Measurement** (state/novel-dfs/composition_hunt.py · N=2·10⁴):
  superperfect σ∘σ=2n {2,4,16,64,4096} (Suryanarayana 1969 / A019279) + Mersenne σ∘σ=σ+n
  {3,7,31,127,8191} exactly rediscovered (sanity PASS) · **novel PROMOTABLE composition law = 0 (DRY)** — bounded-unique
  singleton is single-point coincidence, |sol|≥3 structural set is a thin-restricted-domain coincidence (p² etc. · forall UNPROVEN), universal is
  just structural restatement. Reaches the **same terminus (novel=0) honestly in a different algebra** than the product frame. selftest=
  `composition_test.hexa` (superperfect/Mersenne G-gate) + identity_engine main CMP1–5. No atlas write
  (fold=hexa verify g5/PR). frozen blob 151c52c8 new builtin/method 0 (existing integer ops/nested calls only).
- **LLM-conjecture verify-gate (Ralph 378 · 2026-06-27)**: drill is a *generator* (float-permutation) that almost never emits identifier-syntax
  candidates (`identity=0`), so the real overtake lever = **LLM conjectures a new proposition → exact-int verification**.
  The canonical surface for that (`hexa loop --dfs --llm-cmd` · RFC 080 · `stdlib/loop/cycle.hexa`+`dfs.hexa`) had its
  child gate looking only at cite/English/non-trivial heuristics with no exact-int connection — that gap is now **wired into the verify engine here**:
  new module `stdlib/loop/conjecture.hexa::cj_verdict` extracts the child body's `CONJECTURE:` line and
  routes it to `../atlas/identity_engine.hexa` (identity→`verify_identity`/`is_universal2` · composition→
  `verify_composition` · congruence→`verify_congruence`) → `""` (prose)/unparseable/unverified/
  verified-known/verified-novel. `dfs_verify_child` **DROPs unverified/unparseable children** (false conjectures
  auto-rejected), surviving children get an `exact_verify:` label + `dfs_run` counts `[dfs] exact-verify: novel/known/prose`.
  The prompt (`dfs_build_prompt`) asks the LLM for **NOVEL** conjectures in verifiable syntax (18-fn vocab) (verifier is judge). The parser
  ports drill `_parse_identity`/`_parse_composition`. selftest=
  `stdlib/loop/conjecture_test.hexa`. **byteeq-neutral** (loop=cmd_run dispatch · outside self/ closure) ·
  no atlas write (fold=hexa verify g5/PR) · frozen 151c52c8 new builtin 0.
- **Default verification is ON (not a flag)**: when no external verifier is installed, `drill.hexa::_native_identity_sweep`
  runs by default every round — it directly calls `../atlas/identity_engine.hexa::verify_identity` (exact-int 12-fn
  A·B=C·D bounded-unique) and emits the round verdict as a `DRILL_VERIFIER` stderr line with the
  actual value (`pass`/`continue` + `rationale=identity_sweep:identity=…,verified=…,noise=…`)
  (old `"skip"` short-circuit removed · #4015). External dependence (opt-OUT) is only via the `HEXA_DRILL_NO_VERIFY=1` constraint —
  setting it reverts to legacy `"skip"` (pure surfacing, no verification) (native-canonical polarity).
  pluggable `--verifier <cmd>` is for an external/tenant oracle (opt-in constraint).
  · **Honesty (c2)**: the current generator (smash P2–P9) emits float-permutation exprs, so in standard vocab
  `identity=0/verified=0/noise=N` → verdict `continue` is normal (honest 0-verified report). Identifier-syntax
  candidate generation is the [B] generator campaign area — [A] only goes as far as "verification emits a real verdict, not a skip".
- **ouroboros absorb loop = closed (2026-06-27)**: the defining mechanism of the primordial NEXUS blowup (feeding a verified
  primitive back into the next blowup tick to *widen the well*) is now live inside the engine. `drill.hexa`
  `_native_identity_sweep_absorb` collects, from a round's candidates, **only the exact-int VERIFIED ones (bounded-unique n≥4)**
  as canonical exprs (`_canon_identity` commutativity collapse + `_is_known_identity`
  known/novel), and `drill_run` **feeds-forward** the accumulated `absorbed_pool` (in-memory) into the round N+1 smash axiom
  seed (on top of the existing seed-derived pool · `_absorb_merge` dedup) → `DRILL_ABSORB`
  stderr audit. **SAFE**: ⓐ absorbs VERIFIED only (noise 0·fabrication 0) ⓑ **in-memory ONLY** — does not WRITE to embedded
  atlas (fold is `hexa verify` g5/PR) ⓒ honest known/novel label. **Honesty (c2)**: standard vocab is
  measured-exhausted, so even a widened well mostly re-derives classics → **novel=0 expected** (live-ifying the mechanism is the scope ·
  not a guarantee of new-math discovery). `absorb_test.hexa` = collect/collapse/accumulate verification with synthetic verified candidates.
- **[B] open-well Emerge stage = live (2026-06-27)**: the Emerge stage of the NEXUS 5-phase (Blowup→Contract→**Emerge**→
  Singularity→Absorb · `archive-nexus/README.md:67,75`) is live inside the engine — interlocked with the [A] absorb
  loop it "combines two absorbed primitives to make a new structure (new wall) the previous cycle couldn't express"
  (README:75/83/115 "open well — each Absorb widens the wall"). `compiler/drill/emerge.hexa`:
  ⓐ `emerge(v0,seed,cycles,min_growth)` = README:372-379 **E4 exact port** (V_0={2,3}·seed=6·300 cycles·
  `vocab.add(pick(sorted)+pick(sorted))`→sorted-dedup i64 vocab = set semantics · deterministic LCG
  Numerical Recipes 1664525/1013904223 `& 0xffffffff`, same constants as `qrng.hexa::_qrng_step` · no new
  builtin). ⓑ `emerge_step` **wired** into `drill_run` (production — each round absorbs the accumulated `emerge_well` as a
  candidate value-signature + widens it with EMERGE_CYCLES=32 combine) → `DRILL_EMERGE` stderr audit (open_well
  growth vs frozen_llm=2 fixed contrast MEASURED). **SAFE**: in-memory only (no atlas write · fold is
  `hexa verify` g5/PR) · deterministic (byte-eq). `emerge_test.hexa` = E4 self-test (growth=259>=50 PASS ·
  frozen LLM len==|V_0|=2). **Honesty (c2)**: E4 falsifies **structural emergence** (vocab cardinality growth ≥50) —
  README is at that level too (integer-sum set growth). The reference is CPython `Random(6)` (Mersenne Twister) but
  E4 scores set-growth only, so with LCG the STRUCTURE/verdict is reference-faithful, only the exact vocab members differ
  (residual honestly recorded). Whether compound primitives yield a new VERIFIED math identity is a separate question (exact-int
  `verify_identity`) — standard 2-term is measured-exhausted → **likely novel=0** (do not confuse with E4 PASS).
- **Orthogonal pivot — additive/combinatorial number theory (Ralph 377 · 2026-06-27)**: multiplicative vocab (σ,φ,…) is measured-exhausted,
  so switch to **non-multiplicative generating-function/recurrence sequences** (partition p(n)·Catalan·Bell·Fibonacci·Lucas). The new identity
  FORM = arithmetic-progression congruence `a(αn+β)≡0 (mod m)` (Ramanujan p(5n+4)≡0 mod5 = a canonical with no multiplicative analog).
  native exact-int lives in `../atlas/identity_engine.hexa` (`partition_p`/`catalan`/`bell`/`fib`/
  `lucas`/`tri`/`pent`/`sq` + mod-m table + `verify_congruence`). drill wiring=`_native_additive_screen`
  (each round rediscovers Ramanujan 3-congruence sanity + novel count → `DRILL_ADDITIVE` stderr audit ·
  in-memory·byteeq-neutral). selftest=`additive_test.hexa` (self-contained). **Measurement** (reference engine
  `../../ATLAS/state/novel-dfs/additive_partition_hunt.py` N=4000): sanity 8/8 PASS·congruence sweep
  RAMANUJAN=3·KNOWN=752·**NOVEL=0**·cross-seq bounded-unique=0 → orthogonal but the same DRY (all classical
  Touchard/Lucas/Deutsch–Sagan). Honest 0 (no fabrication)·congruence [0,N] bounded·∀n UNPROVEN (c2). No atlas write
  (fold=hexa verify g5/PR). Next unexplored=composed/iterated functions (Ralph 372).
- **Standard-vocab math discovery = measurement-terminated (🧱)**: `../../ATLAS/README.md` DFS r1~r4 — @F 1557 fold ·
  novel-fold 0 · gates 21/21. The engine is real but standard-vocab novelty=0 (no fabrication). New discovery is
  new vocab/domain (ATLAS/state/novel-dfs reference engine).
- **codegen/runtime-adjacent changes require byteeq 3-target** (drill is a `fn main` absorb verb · the CLI
  compiles and runs it). Confirm the frozen-blob symbol set before introducing a new builtin/symbol.
- Build/smoke = aiden/summer pool (mini=git/gh·akida forbidden).
