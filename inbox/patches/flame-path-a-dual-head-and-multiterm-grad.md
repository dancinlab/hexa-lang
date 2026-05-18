# flame Path-A: dual logits head + multi-term in-autograd grad composition

**Filed by**: anima (downstream consumer) — §71 flame substrate migration
(2026-05-19). anima edits NO flame/hexa-lang source per
`g_train_flame_not_pytorch upstream_downstream_invariant`; this is a
patch-request only.

**Status**: `rfc-drafted 2026-05-19 — RFC 059 drafted (3-cycle phasing:
dual-logits → multi-term grad → PureFieldFFN); first-cycle scaffold
landed; full implementation = multi-cycle, tracked by RFC 059`.

## Problem

anima's canonical training model is ConsciousDecoderV2
(d768·12L·V256·nh12·nkv4·n_layer12). Its **vanilla transformer core**
(RoPE+SwiGLU+RMSNorm+GQA+AdamW) maps **byte-identically** onto the
flame Path-A device-resident decoder
(`stdlib/flame/flame_d768_12L_corpus_test.hexa` config) — confirmed,
no gap there. The anima §71 trainer
(`HEXAD/FLAME/anima_flame_trainer.hexa`, downstream consumer) compiles
clean in both MODE_VERIFY (d32·3L) and MODE_CANON (d768·12L) and the
$0 d32 oracle reproduces the anima convergence trajectory
(init gn2 7.97113, collapse 8.98e6×, acc 8/8).

But anima's training objective is NOT single-head single-CE. Three
anima-specific physics overlays cannot be expressed on the current
Path-A fused decoder layout, and anima **cannot work around them
downstream** because they require the device-resident decoder's
parameter layout (`m_total`/`mc_total`) and gradient path
(`nn_decoder_gn2`/`nn_decoder_grad`/`nn_decoder_adamw_step`) to change
shape — which is exactly the flame source anima is forbidden to edit:

1. **Dual logits head** (Engine A⇄G): anima emits `logits_a =
   head_a(x)` AND `logits_g = head_g(x)` — two `Linear(d, V)`
   projections, weight-tying `tok_emb ↔ head_a`. `m_total` /
   `mc_off_logits` currently model ONE output projection / one logits
   buffer. A second parallel head + its `nn_lm_head_bwd` is a
   device-resident layout extension.

2. **Multi-term in-autograd objective**: anima's loss is
   `L = CE_full + λ_ctl·L_psi_ctl + λ_route·L_tension_route`
   (+ optional `λ_ptd·L_ptd` aux MSE head). The Path-A grad path
   (`nn_decoder_gn2` → `nn_decoder_grad`) is single-objective. anima
   needs the grad path to compose extra gradient-bearing loss terms
   that backprop into the same decoder.

3. **PureFieldFFN dual-engine block**: anima's FFN is two parallel
   `Linear→GELU→Linear` engines with `out = a − g` and
   `tension = mean(out²)`, replacing the SwiGLU FFN
   (`decoder_block_lib` is SwiGLU-shaped).

These are not bugs in flame — flame Path-A is a correct vanilla decoder.
They are a **missing extension surface** for anima-physics decoders on
the device-resident path. On generic Path-B (`ag_spec`+`ag_tape`)
these ARE expressible (general autograd + flexible module def), but
Path-B is measured slow at d768·12L (per
`g_train_flame_not_pytorch perf_claim_honesty`: generic ag_tape large
step >900s, mk2/RFC056 in progress) — so the large anima model is
forced onto Path-A, where the extension does not exist.

## Minimal requested primitive (one concept)

A Path-A device-resident **dual-logits + multi-loss-term hook** for the
fused decoder, minimal surface:

- An `nn_decoder_init` / `m_total` variant that allocates a **second
  output projection** (head_g) alongside head_a (head_a stays tied to
  `tok_emb`); a paired `mc_off_logits_g` buffer.
- A `nn_decoder_fwd` that returns both `logits_a` and `logits_g`
  buffers (or writes both into `Mc`).
- A grad-path entry that accepts an **extra per-token loss-gradient
  buffer** (the caller computes `d L_extra / d logits` for the in-graph
  physics terms — Ψ-CTL, tension-route, PTD-MSE — as a pure function of
  `logits_a`/`logits_g`/`tensions`, all of which flame already has) and
  adds it to the CE gradient before the AdamW step. i.e. expose
  `nn_decoder_grad_with_aux(..., d_aux_logits)` so anima composes the
  physics objective downstream WITHOUT touching flame's internal
  per-layer backward.

The PureFieldFFN dual-engine block (#3) is a separate, lower-priority
block-layout concern — anima can initially run the canonical decoder
with the stock SwiGLU FFN and treat PureFieldFFN as a follow-up
(it changes only the FFN sub-block, not the head/objective). Filing it
here only as context; the load-bearing request is the dual-head +
aux-grad hook (#1 + #2), which anima genuinely cannot synthesize
downstream from the current single-head single-objective Path-A API.

## Why anima can't work around it downstream

The dual head + multi-term gradient must live INSIDE the
device-resident parameter layout and the fused grad path
(`m_total`/`mc_total`/`nn_decoder_grad`/`nn_decoder_adamw_step`). anima
only *calls* these — it cannot add a second projection's parameters or
inject an extra loss gradient into the fused backward without editing
flame source, which `g_train_flame_not_pytorch upstream_downstream_
invariant` (≅ hexa-lang AGENTS.tape g7 / @F f3 sibling-SSOT-lock)
forbids. Hence: upstream patch-request, not a downstream workaround.

g3: no unmeasured perf/compat claim. The vanilla core IS confirmed
Path-A compatible (measured: compiles + d32 oracle converges). Only
the physics-overlay extension surface is the gap.

## Resolution-plan — 2026-05-19

- **RFC drafted**: `inbox/rfc_drafts_2026_05_12/rfc_059_flame_path_a_dual_head_multiterm_grad_purefieldffn.md`
  (number chosen as next-unused after RFC 058 forge_transpose_scatter_kernel;
  drafts dir contiguous tail at 020..058).
- **3-cycle phasing** (each cycle = independent commit + falsifier gate):
  1. **Cycle 1** — dual logits head (§3.1 of RFC). Adds
     `m_off_head_g`, `mc_off_logits_g`, `m_total_dual`, `mc_total_dual`,
     `nn_decoder_fwd_dual`, `nn_decoder_grad_dual`. Existing symbols
     (`m_total`, `nn_decoder_fwd`, `nn_decoder_grad`, `nn_lm_head_bwd`)
     untouched → F-RFC059-D32-PRESERVE + F-RFC059-D768-PRESERVE byte-eq.
  2. **Cycle 2** — multi-term aux-grad seed (§3.2). Renames
     `nn_decoder_grad` impl → `nn_decoder_grad_with_aux(...,
     d_aux_logits_a, d_aux_logits_g)`; original symbol becomes wrapper
     that passes `0, 0` (= byte-identical). F-RFC059-C2-NIL-AUX-PRESERVE
     + F-RFC059-C2-LINEARITY.
  3. **Cycle 3** — PureFieldFFN block-layout swap (§3.3). Parallel
     module `decoder_block_purefield_lib.hexa` with
     `bp_total_purefield = 2*d + 2*d*d + 2*kvd*d + 4*h*d` (Wa_in,
     Wa_out, Wg_in, Wg_out + GELU). SwiGLU layout unchanged →
     F-RFC059-C3-SWIGLU-PRESERVE.
- **First-cycle scaffold landed** (this commit): RFC comment markers at the
  5 touched call sites in `stdlib/flame/{decoder_lib,nn_lib,decoder_block_lib}.hexa`.
  Zero behavior change. All parse clean via `hexa_real parse`. The d=768·12L
  Path-A primary path's byte-eq is unaffected (no code change, only
  comments). Existing F-RFC043-DECODER-GRAD-EXACT + F-RFC043-TRAIN-* +
  d768·12L wall closure (Phase 4-D-9 `28e9d648`) all preserved by construction.
- **Open design decisions** (RFC §10 — user-confirmable before cycle 1
  implementation starts): aux-seed interface granularity (separate vs
  fused), nil sentinel convention, GELU exact-vs-tanh, per-layer block-mode
  mechanism.
- **Out-of-scope of this resolution-plan**: interp dual-track exempt
  (`g_flame_compiler_only` — flame is compiled-native only).
