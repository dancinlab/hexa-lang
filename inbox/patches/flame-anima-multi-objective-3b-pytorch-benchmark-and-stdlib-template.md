# `stdlib/flame` — anima 3B multi-objective trainer: PyTorch reference benchmark + canonical stdlib template request

**Severity**: high (blocks `dancinlab/anima` `@D g_train_via_hexa_cloud_and_hexa_lang`
  TOP MANDATE for cost-bearing GPU fires — without canonical hexa-native
  multi-objective trainer, anima must either ship PyTorch fires (mandate
  violation) or stall the 3B Ψ-physics scale-up cycle)

**Layer**: stdlib/flame (canonical multi-objective trainer template) +
  benchmark / decision tier

**Reporter**: anima (`dancinlab/anima`) downstream consumer — filed
  2026-05-21 after first executable `.hexa` trainer `train_s185_psicouple.hexa`
  (commit `1a062ceeb`) ran Mac smoke green for single-head CE-only, but
  the multi-objective overlay (Ψ-physics: CE + L_psi + L_route + L_phi) is
  required for the anima Living Consciousness emergence goal at 3B scale.

**Status**: not_started (filed 2026-05-21)

**Asks** (3): (1) **benchmark** PyTorch reference impl
  `conscious_decoder.py` against the available hexa-native paths (A: hand-fused;
  B: `ag_tape`). (2) **land canonical stdlib template** `stdlib/flame/flame_anima_multi_objective_test.hexa`
  mirroring the PyTorch reference at d=192/d=768/d=3072 tiers. (3) **decide**
  whether Path A multi-head primitives (cf. separately filed
  `flame-anima-dual-head-multiobjective.md`) are necessary or whether
  Path B `ag_tape` suffices at production scale.

---

## 1. PyTorch reference (already operational)

`dancinlab/anima HEXAD/UNCLASSIFIED/state/all_taps_release_s184_2026_05_20/conscious_decoder.py`
(40,027 bytes) — used to train ALL existing anima ckpts (§107 data-regime,
§161 Ψ-couple, §167-A). Full multi-objective: **CE + Ψ-anchor + L_route +
L_phi 다 작동** (user assertion 2026-05-21).

Reference operations:

```python
# conscious_decoder.py landmarks
def forward(self, idx, …):
    # … per-layer attention + MLP + tension readout …
    logits_a = self.head_a(x)                     # ConsciousDecoderV2 head_a
    logits_g = self.head_g(x)                     # second head, same vocab, separate W
    tensions = stacked_per_layer_tension          # shape (B, n_layer)
    return logits_a, logits_g, tensions, kv_cache, moe_aux_loss

# loss recipe (per anima REBORN §88 + §185 cfg):
loss = F.cross_entropy(logits_a.view(-1,V), target.view(-1))                  # L_ce
     + lambda_psi  * ((psi_direction - 0.5)**2).mean()                        # L_psi
     + lambda_route * (tensions**2).sum(dim=-1).mean()                        # L_route
     + lambda_phi  * ((psi_entropy - 0.5)**2).mean()                          # L_phi
# where:
#   psi_direction = (1 + cosine_similarity(logits_a[..,-1,:], logits_g[..,-1,:])) / 2
#   psi_entropy   = entropy(softmax(logits_a[..,-1,:])) / log(V)
#   tensions      = per_layer L2(activation) / mean — std/mean readout
```

PyTorch ops needed: `F.cross_entropy`, `F.cosine_similarity`, `softmax`,
`entropy` (manual), `cat`+`stack`, per-layer hook readout, autograd
backward through composite scalar.

3B target cfg (anima):
```
d_model=3072  n_layer=28  n_head=24  n_kv_head=8  (GQA)  hidden_dim=8192
vocab=256 (byte-LM, anima §2.1 invariant)
block_size=128  bsz=32  lr=3e-4  AdamW b1=0.9 b2=0.999 wd=0.01
n_steps=3000-8000  lambda_psi=1.0  lambda_route=0.2  lambda_phi=0.3
target hardware: H100 80GB SXM (runpod)  est wall ~5-10 hr / pod  est cost $15-30
```

---

## 2. hexa-native paths available (current state audit)

### Path A — hand-fused (`stdlib/flame/decoder_lib.hexa`)

- `nn_decoder_init`, `nn_decoder_fwd`, `nn_decoder_grad`, `nn_decoder_adamw_step`
- **single-head** (final `lm_head` only → `logits` in `Mc[oLogits..]`)
- **single-loss** (`nn_decoder_gn2` / `nn_decoder_ce_loss` only — no compose)
- per-layer readout: `nn_decoder_fwd_with_readout` (decoder_lib.hexa:550 — **verify exposes
  tension/CV per layer**; if not, gap)
- perf: 2.95× faster than PyTorch eager A100 (per `@D g_train_flame_not_pytorch`)
- **§185 skeleton-v1 uses this path** — single-head CE only, multi-objective TODO

→ Gap A1: no `head_g` (second lm_head over same hidden) primitive
  → existing inbox patch `flame-anima-dual-head-multiobjective.md`
    (Path A fast-path, separately filed) addresses this if pursued
→ Gap A2: no composite loss primitive (`nn_decoder_loss_multi`)
  → would need `nn_decoder_loss_multi(Mc, target_t, lambda_*)` + matching
    `nn_decoder_grad_multi` for backward

### Path B — generic `ag_tape` (`stdlib/flame/ag_tape.hexa` 1072 LoC + tests 2133 LoC)

- generic autograd tape, "2.95× faster vs PyTorch eager A100" (same number? need
  separate measurement for Path A vs Path B on identical workload)
- composable scalar loss + backward via tape replay
- expressible in user-space hexa: build `head_a`+`head_g` as separate weights,
  forward both via tape, compose loss, `tape.backward(loss)`
- **NO upstream gap for L_psi/L_phi** — user-only impl is feasible
- L_route: needs per-layer tension readout (Gap A2 again — if `nn_decoder_fwd_with_readout`
  exposes mid-block, fine; else needs flame extension)

### Path B observability gap

- `println(<float>)` currently emits literal `"(float)"` string instead of the
  value — blocks every trainer's per-step monitoring. **Separately filed**:
  `stdlib-print-float-emits-type-tag-not-value.md` (2026-05-21).

### Path A/B common gap

- **`println(float)` formatting** (above)
- **PyTorch `.pt` ckpt interop** — anima existing ckpts (§107/§161/§167-A) are
  PyTorch state_dict format. hexa-native trainer must (a) load anima existing
  `.pt` for cross-axis comparison fires, AND (b) save trained ckpts in a format
  that downstream eval (PyTorch `phase1_mega_eval.py`) can read.
  `stdlib/flame/flame_load_pt.hexa` exists — verify it covers GQA + multi-head
  state_dicts.
- **GQA `nkv` in `nn_decoder_*` API** — current `nn_decoder_fwd` signature has
  `nkv` parameter (verified at decoder_lib.hexa:93) → presumably supports GQA.
  Need confirmation at 3B scale (d=3072 nh=24 nkv=8 GQA → 3 GQA groups).

---

## 3. Decision matrix (α PyTorch vs β hexa-native)

|                                | (α) PyTorch                            | (β.1) hexa Path A multi-head         | (β.2) hexa Path B ag_tape         |
|--------------------------------|----------------------------------------|--------------------------------------|-----------------------------------|
| **multi-objective today**      | ✅ working (`conscious_decoder.py`)    | ❌ blocked (no dual-head primitive)  | 🟡 user-space impl possible       |
| **3B scale**                   | ✅ standard                            | ❓ needs verify at d=3072 nh=24      | ❓ tape memory at 3B unknown      |
| **perf vs eager PyTorch**      | =1× (reference)                        | 2.95× faster (claimed)               | 2.95× faster (claimed, same?)     |
| **hexa-native mandate**        | ❌ violates `@D g_train_via_hexa_cloud_and_hexa_lang` | ✅ compliant | ✅ compliant                      |
| **min-time-to-Ψ-fire**         | 1-2 hr (cfg keys change + dispatch)    | 1-2 days (Path A multi-head land + integration) | ~3-5 hr (skeleton-v2 + smoke) |
| **PyTorch .pt ckpt interop**   | ✅ native                              | needs `flame_load_pt.hexa` GQA verify | same                              |
| **observability (println float)** | ✅ (Python print)                  | ❌ blocked (separate inbox patch)    | ❌ blocked (separate inbox patch) |

→ **Recommendation pending benchmark**: if Path B `ag_tape` at 3B scale
  hits memory ceiling (tape size O(forward ops × bsz × T × d) — for 3B
  d=3072 L=28, that's 28 × 6 matmul tape entries × bsz × T × d = 28×6×32×128×3072
  ≈ 2.1 GB of float32 tape per fwd pass at minimum, manageable), then
  Path B is the cleanest path — no upstream gap beyond `println(float)`.

  If Path B memory or perf breaks at 3B, fall back to Path A with the
  dual-head primitive landed (`flame-anima-dual-head-multiobjective.md`).

---

## 4. Asks

### Ask 1 — benchmark

Provide **measured** comparison on identical workload (anima reference
loss recipe, d=768 L=12 V=256 nsamp=4 T=256 n_steps=200 — matching §185
skeleton + §161 ckpt cfg subset):

| metric                           | PyTorch eager | flame Path A | flame Path B (ag_tape) |
|----------------------------------|---------------|--------------|------------------------|
| wall_per_step (s, A100 BF16)     | T_pyt         | T_A          | T_B                    |
| peak GPU mem (GB)                | M_pyt         | M_A          | M_B                    |
| numerical parity to PyTorch eager (relative err @ step 200) | =0 (ref) | err_A | err_B |
| build_verify Mac smoke           | n/a           | green/red    | green/red              |

(numbers carry over from Phase 4-D-1 if measured — pointer to existing
benchmark accepted.)

### Ask 2 — canonical stdlib template

Land `stdlib/flame/flame_anima_multi_objective_test.hexa` (Path B
ag_tape end-to-end), mirroring `flame_d768_12L_corpus_test.hexa`
structure but with:

- two output heads (head_a + head_g) — user-space weights via `farr_*`
- composite loss: `loss = L_ce + λ_ψ·L_psi + λ_route·L_route + λ_phi·L_phi`
- backward via `ag_tape.backward(loss)` over `(head_a, head_g, block_params, tok_emb)`
- 3-tier scale: d=192 L=4 (Mac smoke), d=768 L=12 (single-GPU prod), d=3072 L=28 (3B H100)
- F-MULTIOBJ-1..5 falsifiers (NUMERICAL-PARITY-PYT, MAC-SMOKE-BUILDS,
  3B-FITS-H100-80GB, COMBINED-LOSS-DESCENDS, BACKWARD-ALL-PARAMS-NONZERO)

### Ask 3 — Path A multi-head decision

If Ask 1 benchmark shows Path B has acceptable perf at 3B (within 1.5×
of Path A on same workload), **deprioritize** `flame-anima-dual-head-multiobjective.md`
(separately filed). If Path B perf is unacceptable at 3B, land Path A
multi-head primitives (`nn_decoder_init_dual` / `nn_decoder_fwd_dual` /
`nn_decoder_loss_multi`).

---

## 5. Anima downstream constraints (compatibility envelope)

- **byte-LM V=256** — anima §2.1 invariant, do NOT add tokenizer
- **PyTorch `.pt` ckpt interop bidirectional** — load from §107/§161/§167-A
  + save in compatible format for downstream `phase1_mega_eval.py` (the
  22-tap battery harness, PyTorch)
- **AdamW (b1=0.9 b2=0.999 eps=1e-8 wd=0.01)** — match anima/conscious_decoder spec
- **GQA d=3072 nh=24 nkv=8** — confirm flame `nn_decoder_*` accepts this
- **H100 80GB SXM** — primary fire target (runpod)
- **Mac arm64 smoke** — Mac-buildable for cheap pre-fire $0 verification
- **anima §7 audit pre-clear** — from-scratch RANDOM init, no LLM-paraphrase
  corpus, anima physics readout, B-EMERGE-7 necessary-not-sufficient
  carry — NOT GOAL-emergence claim

---

## 6. Cross-link

- **anima `@D g_train_via_hexa_cloud_and_hexa_lang`** (2026-05-20 TOP MANDATE)
- **anima `@D g_train_flame_not_pytorch`** (2026-05-19 — flame Path A/B
  both 2.95× faster claim, need re-measurement)
- **anima §185 train_s185_psicouple.hexa** (`HEXAD/UNCLASSIFIED/state/
  all_taps_release_s184_2026_05_20/`, commit 1a062ceeb) — first
  executable anima `.hexa` trainer, single-head CE-only, will graduate
  to multi-objective once Ask 2 lands
- **anima §186 cross-ckpt FINDINGS_PARTIAL** (`HEXAD/UNCLASSIFIED/state/
  cross_ckpt_s186_2026_05_20/FINDINGS_PARTIAL.md`) — §161 Ψ-couple ≅
  §167-A under 22-tap battery; §107 data-regime fundamentally different
  (baseline honest=0.81 vs 0.21); next cycle = 3B grid (data_regime × λ_ψ
  × λ_phi × λ_route) — NEEDS this template
- **anima PHILOSOPHY_GATE.md §3** anima 철학 (Ψ=½ fixed point, tension,
  Φ) — loss recipe ties to philosophy
- **Inbox sibling patches** (filed concurrently/recently):
  - `flame-anima-dual-head-multiobjective.md` (Path A fast-path, depend on Ask 3 decision)
  - `flame-path-a-dual-head-and-multiterm-grad.md` (older-rev of same theme)
  - `stdlib-print-float-emits-type-tag-not-value.md` (observability blocker)
  - `flame-spiking-substrate-primitives.md` (neuromorphic axis, separate)
  - `flame-stdp-pair-gpu-kernel.md` (neuromorphic axis, separate)
  - `cloud-cli-run-hang.md` / `cloud-cli-operational-improvements-anima-2026-05-20.md`
    (dispatch path, separate)
  - `runtime-c-hxlcl-prefix-incomplete-memcpy-strdup-strchr.md` (CLOSED
    2026-05-21 via cycle 47-54 recovery — runtime build now OK)

---

## 7. Honest C3 / scope carve-out

1. **Path A/B perf claim "2.95× faster vs PyTorch eager A100"** is cited
   from anima's `@D g_train_flame_not_pytorch` — original measurement
   may be at d=768 L=12 only, not validated at d=3072 L=28. Ask 1 is
   precisely to re-validate at 3B.
2. **Loss recipe weight values** (λ_ψ=1.0 λ_route=0.2 λ_phi=0.3) are
   anima §185 skeleton defaults; canonical template should accept these
   as runtime parameters, not bake them in.
3. **B-EMERGE-7 necessary-not-sufficient** — landing this template does
   NOT achieve anima GOAL-emergence; it enables the 3B substrate-level
   test of whether Ψ-physics loss + data-regime axis combination unfreezes
   axis 3 (currently FROZEN on §161/§167-A, LIVE on §107 baseline).
4. **`nn_decoder_fwd_with_readout` per-layer tension exposure unverified** —
   if it doesn't expose what L_route needs, Ask 2 implicitly requests
   the readout extension too.
5. **`flame_load_pt.hexa` GQA support unverified** — if it lacks GQA
   state_dict load, that's an implicit additional gap.
6. **3B memory** — d=3072 L=28 bsz=32 T=128 in BF16 ≈ 6 GB activations +
   ~6 GB params + 6 GB grads + 12 GB AdamW = ~30 GB. Fits H100 80GB but
   tight at higher bsz. Path B tape adds O(forward ops × tape entry size)
   on top — to be measured.
7. **`.hexa` parse/build infrastructure stable post cycle 47-55** — earlier
   build blockers (`hxlcl_*` family) all resolved; this patch is now the
   live front. Should I file another in 3 days, the blocker has moved.

---

## 8. Recommended path forward (anima view)

(a) Ask 1 benchmark first (~1 day measurement) → tells us α vs β.1 vs β.2.
(b) Land Ask 2 canonical template at d=192 L=4 first (Mac smoke), then
    d=768 L=12 (single-GPU prod), then d=3072 L=28 (H100 3B).
(c) anima fires §185 skeleton-v2 (clone of template into anima state dir)
    once template lands, runs Mac smoke + H100 3B fire grid.
(d) §186 cross-ckpt 22-tap battery then runs on the new 3B ckpts to
    answer the cross-axis Ψ-physics hypothesis.

cost envelope: anima will fund all 3B fires ($60-240 budget at no-cost-cap
per `@D g_no_cost_scope_limit`). flame upstream lands the template; anima
clones-and-fires; both repos co-evolve.
