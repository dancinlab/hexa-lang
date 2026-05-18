# RFC 059 — flame Path-A dual-logits head + multi-term in-autograd grad + PureFieldFFN block (anima-physics decoder hooks)

- **Status**: design-draft + cycle-1 scaffold (2026-05-19) — DESIGN + RFC-only-comment-markers. NO behavior change in the scaffold commit; full implementation = 3 multi-cycle.
- **Date**: 2026-05-19
- **Severity**: P1 (GOAL ① alignment — flame substrate is the only path that meets the d768·12L wall budget per Phase 4-D-9 closure `28e9d648`; anima downstream is blocked from adopting flame for its canonical training model until these three extension surfaces exist on Path-A).
- **Priority**: P1 (no perf regression; gates anima §71 trainer migration off the measured-slow Path-B `ag_tape` route).
- **Builds on**: RFC 040 (device-farr+cuBLAS), RFC 043 (flame compiler-only NN stdlib — Phase 3 LANDED), RFC 045/046/047/048 (Phase 4 fusion lineage), RFC 056 (residency API), RFC 057 (device-authoritative matmul contract), flame Phase 4-D-9 (`28e9d648` — d768·12L wall = MEASURED PASS, 191–268s vs PyTorch 336.85s).
- **Source patch**: `inbox/patches/flame-path-a-dual-head-and-multiterm-grad.md` (anima §71 filing, 2026-05-19).
- **RFC number rationale**: drafts directory `inbox/rfc_drafts_2026_05_12/` ranges 020..058 contiguous tail (last assigned RFC = 058 forge_transpose_scatter_kernel). 059 is the next unused integer.

## 1. Status / Priority / Severity

(see header.) **MULTI-CYCLE DESIGN** with one no-behavior-change cycle-1 scaffold (RFC comment markers at the call sites the implementation will touch). The actual feature is NOT done; three independently-testable cycles follow.

`stdlib/flame/decoder_lib.hexa` + `stdlib/flame/nn_lib.hexa` + `stdlib/flame/train_lib.hexa` host the load-bearing primitives and are interleaved with the Path-A byte-eq oracle (F-RFC043-DECODER-GRAD-EXACT 2/2 PASS @ max rel = 2.66e-08, F-RFC043-TRAIN-{DET,DESCENT,FIT} 3/3 PASS) and the d768·12L F-RFC046-WALL closure. Any extension MUST default-off and preserve all existing falsifiers byte-identical when the extension is unused. RFC-first per `g7` because verified oracle + measured wall both live on the touched files.

## 2. Motivation — anima downstream blocker

anima's canonical training target (ConsciousDecoderV2 d768·12L·V256·nh12·nkv4) maps byte-identically onto the flame Path-A device-resident decoder (per `inbox/patches/flame-path-a-dual-head-and-multiterm-grad.md`, anima d32 oracle reproduces init gn2 7.97113, collapse 8.98e6×, acc 8/8). However the anima training objective is NOT single-head single-CE; three physics overlays require shape-changes to the Path-A layout that anima is forbidden to make downstream (`@F f3` consumer-direct-edit ban):

1. **Dual logits head (Engine A⇄G)** — `logits_a = head_a(x)` AND `logits_g = head_g(x)`, two `Linear(d, V)` projections, `tok_emb ↔ head_a` weight-tied. Current Path-A models ONE logits buffer (`mc_off_logits`) with a single tied head.
2. **Multi-term in-autograd objective** — `L = CE_full + λ_ctl·L_psi_ctl + λ_route·L_tension_route` (+ optional `λ_ptd·L_ptd`). Path-A grad path is single-objective.
3. **PureFieldFFN dual-engine block** — two parallel `Linear→GELU→Linear` with `out = a − g`, `tension = mean(out²)`; replaces SwiGLU FFN (`decoder_block_lib`).

The generic Path-B (`ag_spec`+`ag_tape`) does express these (general autograd + flexible module def) but is measured slow at d768·12L (mk2 cycle SSOT in `stdlib/flame/PLAN.md` — pre-residency >900s/step). With anima blocked off Path-B by wall budget AND off Path-A by API shape, the only forward is upstream extension of Path-A.

GOAL ① alignment: flame's measured d768·12L wall win (Phase 4-D-9, `28e9d648`) is conditional on the Path-A device-resident decoder being the inference vehicle. Extending Path-A to host anima's physics-overlay decoders is what turns that single-config wall pass into "PyTorch general replacement" (cf. memory `project_flame_general_pytorch_replacement_goal`).

## 3. Three extension surfaces

### 3.1 Dual logits head (Engine A⇄G) — `mc_off_logits_g`, `m_off_head_g`

**Current shape** (`stdlib/flame/decoder_lib.hexa`):
```
M layout (params):
  tok_emb [V·d]         offset = 0          (tied with logits head — single)
  gF      [d]           offset = V·d
  block[l]              offset = V·d + d + l·bp_total
M_total = V·d + d + n_layer·bp_total

Mc layout (cache):
  X       [T·d]         offset = 0
  logits  [V]           offset = T·d        ← SINGLE logits buffer
  zr      [d], zT_xn [d], zT_inv [1]
  block[l] [bc_total]
Mc_total = T·d + V + 2·d + 1 + n_layer·bc_total
```

**Target shape** (extension OFF = byte-identical to current; extension ON = additive):
```
M layout (dual-head):
  tok_emb [V·d]         offset = 0          (still tied with head_a)
  gF      [d]
  block[l]              offset = V·d + d + l·bp_total
  head_g  [V·d]         offset = V·d + d + n_layer·bp_total    ← NEW (dual-head ON only)
M_total_dual = V·d + d + n_layer·bp_total + V·d

Mc layout (dual-head):
  X, logits_a [V], zr, zT_xn, zT_inv, block[l]   ← unchanged offsets (so when OFF,
                                                    everything is byte-identical)
  logits_g [V]                                   ← NEW, at end of Mc (dual-head ON only)
Mc_total_dual = Mc_total + V
```

**Symbol-level diff sketch** (decoder_lib.hexa):
- New helpers:
  - `pub fn m_off_head_g(d, nh, nkv, h, V, n_layer) -> int` — returns `V*d + d + n_layer*bp_total(...)`. Used ONLY when `dual_head=true`.
  - `pub fn mc_off_logits_g(T, d, nh, nkv, h, V, n_layer) -> int` — returns `mc_total(T, d, nh, nkv, h, V, n_layer)` (i.e. starts at end of current Mc).
  - `pub fn m_total_dual(d, nh, nkv, h, V, n_layer) -> int` — returns `m_total(...) + V*d`.
  - `pub fn mc_total_dual(T, d, nh, nkv, h, V, n_layer) -> int` — returns `mc_total(...) + V`.
- Function signatures (option A — separate dual variants, recommended):
  - `nn_decoder_fwd_dual(ids, M, Mc, cos, sin, T, d, nh, nkv, h, V, n_layer)` — calls existing fwd to fill `logits_a`, then a second matvec `M[m_off_head_g..] · zT → Mc[mc_off_logits_g..]`. Existing `nn_decoder_fwd` unchanged.
  - `nn_decoder_grad_dual(ids, target_t, M, Mc, Mg, cos, sin, T, d, nh, nkv, h, V, n_layer)` — single CE on `logits_a` (anima §71 default); the extra physics terms enter via §3.2's aux-grad hook, NOT here.
  - `nn_decoder_gn2_a` / `nn_decoder_gn2_g` (campaign metric, per-head).
- **Default preserves byte-eq**: every existing caller of `nn_decoder_fwd` / `nn_decoder_grad` is unchanged; dual variants are NEW symbols.

### 3.2 Multi-term in-autograd grad composition — `nn_decoder_grad_with_aux`

**Current shape** (`stdlib/flame/decoder_lib.hexa::nn_decoder_grad`):
```hexa
pub fn nn_decoder_grad(ids: int, target_t: int,
                       M: int, Mc: int, Mg: int,
                       cos: int, sin: int,
                       T: int, d: int, nh: int, nkv: int, h: int,
                       V: int, n_layer: int) {
    // step 1: dl[k] = softmax(logits)[k] - [k == target_t]   ← SINGLE-OBJECTIVE
    // step 2: tied-head bwd + RMSNorm bwd + block stack bwd + embed scatter
}
```

The seed `dl[k] = softmax − onehot` is the ONLY entry point for per-token loss into the fused backward. The patch's load-bearing request: expose an additive hook so the caller composes `d L_extra / d logits` (a pure function of `logits_a` / `logits_g` / `tensions` — all already on the device-resident cache) and the fused backward adds it into `dl` before propagating.

**Target shape** (extension OFF = nil/zero aux = byte-identical to current):
```hexa
pub fn nn_decoder_grad_with_aux(ids: int, target_t: int,
                                M: int, Mc: int, Mg: int,
                                cos: int, sin: int,
                                T: int, d: int, nh: int, nkv: int, h: int,
                                V: int, n_layer: int,
                                d_aux_logits_a: int,   // farr_id or 0 (nil)
                                d_aux_logits_g: int)   // farr_id or 0 (nil)
{
    // step 1a: dl_a[k] = softmax(logits_a)[k] - [k == target_t]
    // step 1b: if d_aux_logits_a != 0: dl_a[k] += d_aux_logits_a[k]
    // step 1c (dual-head only): dl_g[k] = if d_aux_logits_g != 0 { d_aux_logits_g[k] } else { 0 }
    // step 2: SAME bwd pipeline — tied-head + RMSNorm + blocks + scatter, plus
    //         head_g bwd if dual-head, accumulating both dl_a and dl_g into Mg.
}
```

- `nn_decoder_grad(...)` becomes a thin wrapper: `nn_decoder_grad_with_aux(..., 0, 0)`. Existing callers compile unchanged AND produce byte-identical Mg (single-objective CE).
- The caller computes physics terms (Ψ-CTL · tension-route · PTD-MSE) outside the fused decoder backward as pure functions of `Mc` slices, allocates a `[V]`-len farr per head with `d L_extra / d logits_*`, and passes it in. This isolates anima physics from flame's per-layer backward (which never changes its math).
- The grad path is still a single fused backward — no double-pass over the block stack. The composition is `dl_a += d_aux_logits_a` (linearity of vjp w.r.t. the seed), not an extra reverse traversal.

### 3.3 PureFieldFFN dual-engine block — block-layout swap

**Current shape** (`stdlib/flame/decoder_block_lib.hexa`):
```
Bp (per-block params) layout — SwiGLU FFN:
  g1 [d], Wq [d·d], Wk [kvd·d], Wv [kvd·d], Wo [d·d], g2 [d],
  Wg [h·d], Wu [h·d], Wd [h·d]                  ← SwiGLU: 3 ffn matrices
bp_total = 2·d + 2·d·d + 2·kvd·d + 3·h·d
```

**Target shape** (per-layer mode flag — block layout swap):
```
Bp layout — PureFieldFFN (dual-engine, GELU):
  g1, Wq, Wk, Wv, Wo, g2,
  Wa_in [h·d], Wa_out [d·h],     ← engine A: Linear → GELU → Linear
  Wg_in [h·d], Wg_out [d·h]      ← engine G: Linear → GELU → Linear
bp_total_purefield = 2·d + 2·d·d + 2·kvd·d + 4·h·d
forward: out = engine_A(x) − engine_G(x); tension = mean(out²) (exposed in Bc).
```

- Two block layouts coexist. Selection is per-layer (anima §71 may use mixed-FFN — needs confirmation). Simplest implementation: a `block_mode[n_layer]` array on the decoder driver, OR a separate `nn_decoder_purefield_*` family of symbols that fully owns the alternate block.
- Strictly more invasive than §3.1 / §3.2 because `bp_total` (and therefore every per-layer offset in M, Mc, Mg) changes. This is why the patch deprioritizes it ("anima can initially run the canonical decoder with the stock SwiGLU FFN and treat PureFieldFFN as a follow-up").
- **Default preserves byte-eq**: existing `decoder_block_lib` symbols and SwiGLU layout are unchanged; PureFieldFFN ships as a parallel module with its own `bp_total_purefield`, fwd, bwd, and per-block offset helpers.

## 4. Byte-eq oracle preservation — non-negotiable

The d768·12L Path-A primary path's byte-eq + wall numbers MUST stay measurement-identical when the extension is OFF.

- **F-RFC059-D32-PRESERVE** (hard gate #1): `flame_full_grad_exact_libm_test.hexa` (F-RFC043-DECODER-GRAD-EXACT, 2/2 PASS @ max rel ≤ 2.66e-08) re-runs identical on `nn_decoder_grad` (the thin wrapper into `nn_decoder_grad_with_aux(..., 0, 0)`). Bit-identical Mg.
- **F-RFC059-D768-PRESERVE** (hard gate #2): `flame_d768_12L_corpus_test.hexa` step 1 byte-eq + step-1 wall (191–268s vs PyTorch 336.85s, Phase 4-D-9 `28e9d648`). Extension OFF defaults.
- **F-RFC059-TRAIN-DESCENT** (hard gate #3): F-RFC043-TRAIN-{DET,DESCENT,FIT} 3/3 PASS unchanged (toy d=8·2L 80-step descent oracle, gn2 collapse byte-eq).
- **F-RFC059-AGTAPE-WALL-NONREGRESSION**: F-RFC046-WALL (mk2 in-flight) numbers stay within instrument noise — extension OFF should not perturb the generic Path-B mk2 cycle either (extension is Path-A only; Path-B carries no `d_aux_logits` parameter).

Cycle-1 commit scaffolds NOTHING that runs — the falsifiers stay PASS trivially.

## 5. Phasing — 3 cycles, each independently testable

### Cycle 1 — Dual logits head (§3.1)

- **Surface**: add `m_off_head_g`, `mc_off_logits_g`, `m_total_dual`, `mc_total_dual`, `nn_decoder_fwd_dual`, `nn_decoder_grad_dual` (single-objective default), `nn_decoder_gn2_a`, `nn_decoder_gn2_g`.
- **Existing symbols**: zero edits to `m_total`, `mc_total`, `mc_off_logits`, `nn_decoder_fwd`, `nn_decoder_grad`, `nn_lm_head_bwd`, `nn_decoder_adamw_step`. AdamW step is shape-agnostic (operates on flat M of length `n`) so passing `m_total_dual` is a parameter, not a code change.
- **Falsifier**: 
  - F-RFC059-C1-EXISTING-PRESERVE: every existing test in `stdlib/flame/flame_*_test.hexa` PASS byte-identical.
  - F-RFC059-C1-DUAL-FWD-MATH: `nn_decoder_fwd_dual` produces `logits_a` identical to `nn_decoder_fwd`'s `logits` AND `logits_g[k] = Σ_j head_g[k·d+j] · zT[j]` (closed-form matvec verified vs scratch reference).
  - F-RFC059-C1-DUAL-GRAD-EXACT: central-diff vs analytic at one probe each in `tok_emb` (tied to head_a), `gF`, `head_g`, `block[0].Wq` — proves the dual-head backward composes.
- **Blockers**: none anticipated. Pure-additive layout extension; tied weight semantics preserved (head_a remains tied to tok_emb; head_g is independent).

### Cycle 2 — Multi-term in-autograd grad composition (§3.2)

- **Surface**: rename `nn_decoder_grad` → `nn_decoder_grad_with_aux` (real impl) + `pub fn nn_decoder_grad(...) { nn_decoder_grad_with_aux(..., 0, 0) }` thin wrapper. Same surgery on dual variant from cycle 1: `nn_decoder_grad_dual_with_aux(..., d_aux_logits_a, d_aux_logits_g)`.
- **Additional surface (downstream-side, scaffold only)**: stub helper symbol names anima will consume: `_aux_d_logits_psi_ctl(Mc, lam_ctl, T, d, V, ...)` etc. — these compute `d L_psi_ctl / d logits_*` as a pure function of cache slices. flame ships the entry-point; anima provides the closed-form derivative (per the patch's principle: "anima composes the physics objective downstream WITHOUT touching flame's internal per-layer backward").
- **Falsifier**:
  - F-RFC059-C2-NIL-AUX-PRESERVE: `nn_decoder_grad(... )` and `nn_decoder_grad_with_aux(..., 0, 0)` produce byte-identical Mg (the wrapper is the same call site after compilation; this is testing that the seed `dl_a += 0` path is truly a no-op — no fp-rounding from spurious `+0.0`).
  - F-RFC059-C2-LINEARITY: with non-zero `d_aux_logits_a`, the resulting Mg = (Mg from CE-only) + (Mg from `d_aux_logits_a`-only). Linearity of reverse-mode vjp w.r.t. the seed; central-diff vs analytic at 2 probes.
- **Blockers**: ambiguity in patch about per-head aux distribution — does anima want a single `d_aux_logits` summed across heads or separate `d_aux_logits_{a,g}`? **Open design decision** — see §10.

### Cycle 3 — PureFieldFFN dual-engine block (§3.3)

- **Surface**: parallel module `stdlib/flame/decoder_block_purefield_lib.hexa` mirroring `decoder_block_lib.hexa` surface (`bp_total_purefield`, `bp_off_*` for new Wa_in/Wa_out/Wg_in/Wg_out, `nn_decoder_block_purefield_{fwd,bwd}`). Decoder-level integration via either `block_mode[n_layer]` array or a separate `nn_decoder_purefield_*` family.
- **Additional surface**: per-block `tension` exposure in Bc (anima needs `mean(out²)` per layer for the tension-route physics term — that lands in cycle 2's `d_aux_logits` derivative, but the value must be precomputed in cycle 3's fwd cache).
- **Falsifier**:
  - F-RFC059-C3-GRAD-EXACT: central-diff vs analytic at one probe each in Wa_in, Wa_out, Wg_in, Wg_out — proves the dual-engine bwd is exact.
  - F-RFC059-C3-SWIGLU-PRESERVE: existing SwiGLU `decoder_block_lib` tests untouched; `flame_block_test.hexa` PASS byte-identical.
  - F-RFC059-C3-INTEGRATION: a 1-layer purefield + 1-layer swiglu mixed-decoder fwd/bwd at d=8·2L converges on a memorization probe (sanity, not byte-eq vs anima — that requires anima's anchored config).
- **Blockers**: 
  - GELU implementation choice — flame currently uses `silu` (SwiGLU); need `gelu` (exact vs tanh-approx). `flame_math.hexa` would gain `dt_gelu` + analytic derivative `dt_gelu_d`. **Open design decision** — see §10.
  - Per-layer mode mechanism — array vs separate decoder symbols. **Open design decision** — see §10.

## 6. Falsifier battery (composite — measurable test that "extension works AND vanilla unchanged")

Pre-registered. Each falsifier is a single command + a numeric oracle.

| ID | Verifier | Oracle |
|---|---|---|
| F-RFC059-D32-PRESERVE | `flame_full_grad_exact_libm_test` | `max rel ≤ 2.66e-08`, 2/2 PASS, bit-identical to pre-RFC. |
| F-RFC059-D768-PRESERVE | `flame_d768_12L_corpus_test` step 1 | wall ≤ 268s (Phase 4-D-9 closure upper bound `28e9d648`); gn2 init byte-identical; step-1 post-update gn2 byte-identical. |
| F-RFC059-TRAIN-DESCENT | `flame_train_test` | F-RFC043-TRAIN-{DET,DESCENT,FIT} 3/3 PASS unchanged. |
| F-RFC059-C1-DUAL-FWD-MATH | new `flame_dual_head_test` | `logits_a` byte-eq vs `nn_decoder_fwd`; `logits_g` matches scratch matvec; closed-form check. |
| F-RFC059-C1-DUAL-GRAD-EXACT | new `flame_dual_head_grad_test` | central-diff vs analytic at 4 probes, `max rel ≤ 1e-7`. |
| F-RFC059-C2-NIL-AUX-PRESERVE | new `flame_aux_grad_nil_test` | Mg from `nn_decoder_grad(...)` == Mg from `nn_decoder_grad_with_aux(..., 0, 0)`, byte-eq. |
| F-RFC059-C2-LINEARITY | new `flame_aux_grad_linearity_test` | Mg(aux=A) = Mg(aux=0) + ΔMg(aux=A-only), `max rel ≤ 1e-7`. |
| F-RFC059-C3-GRAD-EXACT | new `flame_purefield_block_test` | central-diff vs analytic at 4 probes (Wa_in/Wa_out/Wg_in/Wg_out), `max rel ≤ 1e-7`. |
| F-RFC059-C3-SWIGLU-PRESERVE | `flame_block_test` | F-RFC043-BLOCK-{DET,GRAD-EXACT} 2/2 PASS unchanged. |
| F-RFC059-ANIMA-INTEGRATION | (downstream — anima runs against flame) | anima d32 oracle: init gn2 7.97113, collapse 8.98e6×, acc 8/8 (per the patch's measured anima trajectory). NOT in-tree; anima reports back. |

g3 note: numeric tolerances (`1e-7` central-diff) match the existing F-RFC043-DECODER-GRAD-EXACT discipline; the d768 wall threshold (`≤268s`) is the measured Phase 4-D-9 upper bound, not a lattice-fit number.

## 7. Honest caveats (g3 / f1 / f2)

### 7.1 The actual feature is NOT done
RFC 059 ships as RFC + cycle-1 scaffold = RFC comment markers only. Behavior change is zero in the scaffold commit. Cycle 1 ≠ cycle 1 complete; cycle 1 = "dual-head fwd/grad symbols land, falsifiers PASS, byte-eq oracle untouched". Cycle 2 and Cycle 3 are subsequent commits — separately user-gated.

### 7.2 Path-A device-residency status is mk2-in-flight
flame `PLAN.md` mk2 ROADMAP (2026-05-19) tracks cycle-by-cycle device residency for the *generic* Path-B (`ag_tape`). RFC 059 is **Path-A only**. The mk2 cycles and RFC 059 cycles do NOT share substrate. Path-A's device residency is already proven by Phase 4-D-9 `28e9d648` — RFC 059 extends Path-A's *shape*, not its residency mechanism. RFC 056/057 substrate primitives carry over unchanged.

### 7.3 PureFieldFFN open questions
Cycle 3 has unresolved design choices (GELU exact vs tanh-approx, per-layer mode mechanism). The patch deprioritizes cycle 3 ("a follow-up"); RFC 059 honors that — cycle 1+2 are the load-bearing path for anima §71. Cycle 3 may slip or land separately.

### 7.4 No fabricated speedup / parity claim
RFC 059 introduces no perf claim. The Phase 4-D-9 `28e9d648` wall closure is cited as-measured (191–268s vs PyTorch 336.85s, memory `project_flame_phase4d9_closure`). Extension-ON wall is unmeasured because the extension is unimplemented — that's the whole point of multi-cycle. No d=N claim made for anima physics terms; that's anima's responsibility to verify when cycle 2 lands.

### 7.5 No lattice numerology (f1/f2)
Every dimension is anchored to anima's measured ConsciousDecoderV2 config or flame's existing bp_total/m_total. No perfect-number / n=6 derivation; observation-only on coincidental matches.

### 7.6 Single-side fix risk (g_inbox_dual_track)
flame is compiler-only (`g_flame_compiler_only`) — no interpreter dispatch. `g_inbox_dual_track` exempts compile-only stdlib; cycles 1–3 land on `hexa build` native only. Documented exemption.

## 8. Non-goals

- No change to `decoder_block_lib` SwiGLU shape (cycles 1+2 are decoder-level; cycle 3 is a parallel block module, not an edit).
- No change to forge substrate (no RFC 040/056/057 surface edits).
- No new builtins (no `farr_*_gpu`, no runtime.c edits, no `runtime.h` proto additions).
- No interpreter path (`g_flame_compiler_only`).
- No PyTorch-parity perf claim under extension-ON.
- No multi-objective dispatch outside the explicit `d_aux_logits_*` seed surface (anima's physics derivatives compute downstream).

## 9. Cross-RFC dependency

- RFC 043 (flame compiler-only NN stdlib) — RFC 059 extends Path-A shape; foundation.
- RFC 040 (device-farr + cuBLAS) — Path-A primary substrate; unchanged.
- RFC 045/046/047/048 — Phase 4 fusion lineage; Phase 4-D-9 `28e9d648` is the measured wall closure RFC 059 must preserve.
- RFC 056 (device residency) / RFC 057 (device-authoritative matmul) — substrate prerequisites for the d768 Path-A wall; RFC 059 inherits.
- RFC 058 (forge transpose/scatter kernel) — orthogonal; no shared surface.
- Future (RFC 060+): if cycle 3 PureFieldFFN demands GELU on forge GPU substrate, that's a separate forge-side RFC.

## 10. Open design decisions — user-confirmable before cycle 1 lands

1. **Cycle 1 — head_g placement in M**: append at end (`offset = V·d + d + n_layer·bp_total`) ✅ (recommended — keeps existing offsets stable) vs interleave (rejected — breaks all existing block-offset arithmetic).
2. **Cycle 1 — tying convention**: head_a tied to tok_emb (current, unchanged) ✅, head_g independent (no tying) ✅ (default, matches patch language); alternative — head_g also tied to tok_emb (would collapse to single-head with two read-heads, semantically different).
3. **Cycle 2 — aux seed interface**: separate `d_aux_logits_a` + `d_aux_logits_g` farr_id arguments (proposed) vs single fused `d_aux_logits` of length `2*V` (more compact, less ergonomic). The patch language is ambiguous.
4. **Cycle 2 — nil convention**: `farr_id == 0` as nil sentinel ✅ (matches current flame style — `0` is "no farr allocated"; cf. existing `nn_lib.hexa` allocator returns) vs a separate boolean flag pair (more explicit, more parameters).
5. **Cycle 3 — GELU implementation**: exact (`0.5·x·(1+erf(x/√2))`) vs tanh-approx (`0.5·x·(1+tanh(√(2/π)·(x+0.044715·x³)))`). anima §71 may have a specific choice; pinning it determines whether `flame_math.hexa` needs `dt_erf` or just tanh.
6. **Cycle 3 — per-layer block-mode mechanism**: `block_mode[n_layer]` array on the decoder-init API vs a fully separate `nn_decoder_purefield_*` family that always uses PureFieldFFN for every layer (simpler, less flexible). Patch wording "two parallel `Linear→GELU→Linear` engines" suggests all-or-nothing per-decoder; default = full-purefield decoder (simpler).
7. **Per-cycle landing**: should cycle 2 wait for cycle 1 to ship, or can cycle 2 stage on top of an in-flight cycle 1 branch? — gated on the dual-head landing rhythm and anima's §71 readiness.

## 11. Cross-link

- Inbox patch (this RFC's source filing): `inbox/patches/flame-path-a-dual-head-and-multiterm-grad.md`
- flame primary roadmap SSOT: `stdlib/flame/PLAN.md` (`## 진행 로그` 2026-05-19 entry for this RFC)
- flame architecture SSOT: `stdlib/flame/FLAME.tape` (`@L flame_layout` — new dual-head + purefield additions land here when cycle 1/3 ships)
- Path-A primitives touched: `stdlib/flame/decoder_lib.hexa` (M/Mc layout + fwd/grad), `stdlib/flame/nn_lib.hexa` (`nn_lm_head_bwd`), `stdlib/flame/train_lib.hexa` (`nn_decoder_train_step`/`nn_decoder_adamw_step`), `stdlib/flame/decoder_block_lib.hexa` (cycle 3 — block layout).
- d768·12L Path-A entry point: `stdlib/flame/flame_d768_12L_corpus_test.hexa`.
- Measured wall closure: Phase 4-D-9 `28e9d648` (memory `project_flame_phase4d9_closure`).
- Cycle-1 scaffold commit: this commit (RFC comment markers at the 5 touched call sites; zero behavior change).

## Authority

- AGENTS.tape `g3` — every claim in §§4/6/7 is bound to an existing measured falsifier or stays unmeasured (extension-ON wall) by design. No fabricated perf claim.
- AGENTS.tape `g5` — flame is hexa-source, compiles to C; RFC 059 adds no LLVM/transpile backend; pure stdlib shape extension.
- AGENTS.tape `g6` — formula-bearing helpers ship with closed-form analytic vjp derivations (cycle-1 already cites the standard tied-LM-head vjp; cycle 3 GELU derivative cites a published reference per `g6`).
- AGENTS.tape `g7` — RFC-first because the touched files host the d768 wall oracle (`flame_d768_12L_corpus_test.hexa`) and the GRAD-EXACT oracle (`flame_full_grad_exact_libm_test.hexa`). RFC 059 lives in `inbox/rfc_drafts_2026_05_12/` per convention.
- FLAME.tape `g_flame_api_fixed` — RFC 059 keeps existing API surface byte-identical when extensions are OFF; new symbols are additive. "PyTorch-parity → exceed" via implementation maturity, not API churn — satisfied.
- FLAME.tape `g_flame_compiler_only` — cycle 1–3 ship as `hexa build` native; no interp dispatch.
- FLAME.tape `g_flame_verify_anchor` — every new fwd/bwd ships with a closed-form analytic vjp + central-diff oracle (F-RFC059-C1/C2/C3-*).
- LATTICE_POLICY `f1`/`f2` — no lattice numerology; every shape extension anchored to anima's measured ConsciousDecoderV2 config or flame's existing offset arithmetic.
- Patch authority: `inbox/patches/flame-path-a-dual-head-and-multiterm-grad.md` (anima §71 filing, 2026-05-19, downstream-to-upstream per `@F f3` / `g7`).
