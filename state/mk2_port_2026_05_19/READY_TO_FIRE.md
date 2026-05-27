# READY_TO_FIRE — mk2 closure port to rfc043-hexa-torch (2026-05-19)

## Status

CPU build PASS on this worktree branch `worktree-agent-ab8967615e174dc79`:

```
HEXA_LANG=/Users/ghost/core/hexa-lang/.claude/worktrees/agent-ab8967615e174dc79 \
HEXA_MAC_BUILD_OK=1 \
/Users/ghost/.hx/bin/hexa build stdlib/flame/flame_d768_12L_agtape_fire.hexa \
  -o build/d768_t
```

Output: `build/d768_t` (531 KB Mach-O arm64 executable, launches cleanly,
prints expected "d768·12L config: T=1024 d=768 nh=12 nkv=4 h=3072 n_layer=12"
banner).

## What was ported

### Flame .hexa surface (verbatim from rfc043-flame-camp e030fa31)

- `stdlib/flame/ag_tape.hexa` — mk2-C1a/C1b/C2/C4/C4-bwd/C5 forge routing:
  - `ag_add` → `farr_add_gpu`
  - `ag_silu_gate` → `farr_silu_gate_gpu`
  - `ag_rmsnorm_mh` → `farr_rmsnorm_mh_gpu`
  - `ag_attn_dt` fwd → `farr_attn_dt_fwd_gpu`
  - `ag_attn_dt` bwd → `farr_attn_dt_bwd_gpu`
  - `ag_linear` bwd → `farr_matmul` + `farr_transpose_2d_gpu` (skips host nn_linear_bwd
    3-loop, the mk2-FINAL #3 blocker)
  - `_ag_reg_acc` → `farr_add_inplace_gpu` (eliminates per-element accumulator)
- `stdlib/flame/nn_lib.hexa` — RFC 059 cycle-1 anchor doc only.
- `stdlib/flame/decoder_block_lib.hexa` — RFC 059 cycle-3 anchor doc only.
- `stdlib/flame/flame_d768_12L_agtape_fire.hexa` — mk2-C3 device-keep toggle
  (`farr_set_out_disposition(1)`) + C5 device slice copies / zero fill /
  in-place add / LCG fill + `_local_*` driver-local helpers bypassing
  main-repo stdlib flatten resolution + `agt_wT_slice`/`agt_wT_off` use
  `farr_transpose_2d_gpu` not host loops.

### Runtime C surface

- `self/runtime.h`:
  - RFC 056 `farr_set_out_disposition` extern carrier + impl prototype.
  - mk2-C5 hexa-prefixed 3-arg builtins (`hexa_farr_zero_slice_gpu`,
    `hexa_farr_add_inplace_gpu`) + extern carriers.
  - mk2-C5 bare 5+/6+/5-arg builtins (`farr_copy_slice_gpu`,
    `farr_transpose_2d_gpu`, `farr_fill_dt_lcg_gpu`).
  - mk2-C2 `farr_rmsnorm_mh_gpu` (7-arg bare).
  - mk2-C4 `farr_attn_dt_fwd_gpu` (9-arg bare).
  - mk2-C4-bwd `farr_attn_dt_bwd_gpu` (12-arg bare).
- `self/runtime.c`:
  - RFC 056 §6.4 lazy-D2H comments updated (cherry-pick 61e29993 conflict
    resolution: comment-only divergence, took flame-camp's newer framing).
  - mk2-C1b `_hx_farr_silu_gate_cpu` + `hexa_farr_silu_gate_gpu` dispatcher
    + carrier (cherry-pick e5faa8b0).
  - mk2-C2 `_hx_dt_sqrt_d` byte-exact 24-iter Newton + `_hx_farr_rmsnorm_mh_cpu`
    + `farr_rmsnorm_mh_gpu` dispatcher.
  - mk2-C4 `_hx_farr_attn_dt_fwd_cpu` + `farr_attn_dt_fwd_gpu` dispatcher.
  - mk2-C4-bwd `_hx_farr_attn_dt_bwd_cpu` + `farr_attn_dt_bwd_gpu` dispatcher.
  - mk2-C5 `_hx_farr_copy_slice_cpu` / `_transpose_2d_cpu` / `_zero_slice_cpu`
    / `_add_inplace_cpu` / `_fill_dt_lcg_cpu` + matching dispatchers.
  - All wrapped in `#pragma STDC FP_CONTRACT OFF/DEFAULT` for byte-eq.
  - All HEXA_CUDA-gated — no-CUDA build uses CPU mirrors byte-eq with
    pre-mk2 ag_tape.hexa host loops.
  - `_hexa_init_fn_shims` registers the 3-arg carriers:
    `farr_zero_slice_gpu` / `farr_add_inplace_gpu`.

## Gate

When this branch is merged to `rfc043-hexa-torch` (or its sibling fire
branch) and the dispatch fired:

```
bash tool/dispatch_agtape_d768_fire.sh
```

**PASS criteria** (g3-honest, ABSOLUTE WALL — NO PyTorch comparison):
- `trainer_rc == 0`
- `step 1 wall ≤ 437.9s` (F-RFC046-AGTAPE-WALL ceiling)
- `GPU util > 50%` during step 1
- per-step wall stable across steps 1-3 (no runaway)

**Falsifier**:
- `trainer_rc == 124` (901s timeout) like fires #1-3 → mk2 port incomplete
  on this branch (some optimization not transferred).
- `step 1 wall > 437.9s` → port lost optimization or branch divergence
  introduced new bottleneck.
- `GPU util ~0%` during run → host-scalar bottleneck remains (look for
  another `_local_*` helper needed in driver, or a missed forge-route).

## Decisions punted to parent

1. **GPU fire timing**: parent fires after merging to rfc043-hexa-torch.
   This worktree does NOT run the fire.
2. **Branch divergence beyond mk2**: rfc043-hexa-torch has `0a5fe5c9` and
   other commits not in rfc043-flame-camp (UTF-8 codepoint methods,
   keyword demotes). If those introduce new flame regressions, may need
   another cycle.
3. **No-op flame helpers in main repo**: due to the documented flatten
   resolution constraint (hexa CLI prefers main repo over worktree
   stdlib), the d768 driver still needs `_local_*` helpers in
   `flame_d768_12L_agtape_fire.hexa` to bypass `nn_decoder_init` from
   `train_lib.hexa`. This is verbatim from camp; not optional.

## Coverage honesty (g3)

What was ported:
- C5 batch builtins (slice/transpose/zero/add-inplace/fill_dt_lcg) — 100%
- C2 rmsnorm_mh — 100% (dt_sqrt mirror included)
- C4 fwd + bwd attn_dt — 100%
- C1b silu_gate forge routing — 100% (already present from prior cherry-pick)
- C3 lazy-D2H — comments updated; the actual D2H path already lives in
  this branch's runtime.c from cff366ae-equivalent state. NOTE: this
  worktree HEAD (9e55b864) does NOT contain cff366ae; the lazy-D2H is
  exercised only on HEXA_CUDA build at the runtime_cuda.c level which is
  unchanged.
- `farr_set_out_disposition` carrier — 100% (declared + registered)

What was DELIBERATELY NOT ported:
- runtime_cuda.c kernel source — touched by camp's cherry-pick path
  but the CUDA file lives at `self/cuda/runtime_cuda.c` and is NOT
  used by the no-CUDA build. The dispatch script ships the camp version
  via `tool/dispatch_agtape_d768_fire.sh` which copies repo files. If
  branch's runtime_cuda.c is stale, the GPU fire will catch it.
- driver-local `_local_decoder_init` / `_local_fill_dt_lcg` / `_local_fill_constant`
  / `_local_*` helpers are IN the d768 driver verbatim from camp.

What may still gap if merged to rfc043-hexa-torch:
- rfc043-hexa-torch HEAD (62753459 — keyword demote Phase 4) is AHEAD of
  this worktree HEAD (9e55b864). The merge target may have its own
  runtime.c/runtime.h that diverged. The mk2 builtins will need conflict
  resolution at merge time. The flame .hexa changes should merge cleanly
  (no overlap with keyword demote).
