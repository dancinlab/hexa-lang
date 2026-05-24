# RFC 056 — forge device-sub-view residence API (persistent residency for GPU-resident training)

- **Status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation
- **Date**: 2026-05-17
- **Severity**: CRITICAL (this is THE measured blocker between flame Phase 4-D GPU-resident trainer and the project GOAL. 9 d768·12L fires; the substrate, dispatcher wiring, and primitive-discipline H2D reduction are all landed/verified, yet step 1 of d768·12L still > 600s because every forge `_gpu` op is self-contained H2D→compute→D2H — there is no API to keep model+cache resident across the step.)
- **Priority**: P0 (gates the GOAL: `flame trains d=768·12L via forge faster than PyTorch, measured`)
- **Builds on**: RFC 040 (device-farr + cuBLAS Dgemm), RFC 041 (Phase B/B2 `.cu` kernels), RFC 044 (regime-tiered substrate), RFC 050 (flame↔forge dispatch API — RFC 056 adds the residence axis the dispatch API assumed but never specified), RFC 043 (flame stdlib design SSOT)
- **Source convergence**:
  - flame Phase 4-D-7 GPU-resident A2 primitive LANDED + Agent #44 residence-state fix (`2b9c868b`) + Phase 4-D-8 redundant-H2D elision (`aa6d70ba`)
  - forge substrate VERIFIED: Phase 4-D-5-3 12 kernels byte-eq on A100 (11/11 + RoPE), `state/forge_phase4d_5_3_2026_05_17/PHASE4D_5_3_ANALYSIS.md`
  - 9-fire d768·12L campaign — fire #5→#9, monotone, every fire removed one concrete blocker, the last blocker now measurement-isolated
- **Source evidence (g3 — every claim traces to a real capture)**:
  - `state/flame_phase4d6_gpu_fire_2026_05_17/PHASE4D6_GPU_FIRE_ANALYSIS.md` — fire #5: GPU ENGAGED 435 MiB, 0 step / 600s, per-call H2D/D2H + CPU non-matmul loops identified
  - `state/flame_phase4d7_gpu_fire_2026_05_17/PHASE4D7_FIRE7_ANALYSIS.md` — fire #7: step 1 entered, `[cuda] d2h state mismatch` → CPU fallback
  - `…/PHASE4D7_FIRE8_ANALYSIS.md` — fire #8: d2h FIXED (zero mismatch), GPU genuinely engaged 25% peak / 581 MiB, still 600s step 1 incomplete; §6 identifies "no working persistent device residency" as the precise blocker
  - `…/PHASE4D7_FIRE9_ANALYSIS.md` — fire #9: Phase 4-D-8 halved-H2D (`aa6d70ba`, byte-eq-exact), `trainer_rc=124 wall=601`, GPU 18%/459 MiB — **decisive measurement: d768·12L wall is NOT duplicate-H2D-bound; it is structural-per-op-round-trip + CPU-non-matmul-glue bound. Primitive-discipline H2D reduction measured insufficient.**
  - Phase 4-D-8 agent code-inspection verdict (worktree `b06f1b0f`): `self/cuda/runtime_cuda.c:_h2d` always issues `cudaMemcpy HostToDevice`; never reads `loc`/`dirty_dev` to skip; no D2H-defer; no device-side slice/offset/view API anywhere in the substrate (grep-verified)

## 1. Status / Date / Priority / Severity

(see header). Re-stated: **DESIGN ONLY, no fire, no implementation in this RFC**. RFC 056 land = a design contract for a forge substrate residence-API change. Because it modifies `self/runtime.c` + `self/cuda/runtime_cuda.c` — the **verified Phase 4-D-5-3 11/11 byte-eq oracle** — it is RFC-first per g7; no substrate edit lands without this contract reviewed.

## 2. Source convergence (the 9-fire campaign converges here)

The d768·12L campaign is a sequence of removed blockers, each measured:

| fire | phase | GPU | result | blocker removed |
|---|---|---|---|---|
| #5 | 4-D-6 | 435 MiB, 0% | 0 step / 600s | (revealed: non-matmul CPU loops + per-call H2D) |
| #7 | 4-D-7 | 1 MiB, 0% | step 1, d2h spam | residence-state contract bug |
| — | Agent #44 `2b9c868b` | — | — | inert+buggy block-boundary to_device/to_host removed |
| #8 | 4-D-7 | 581 MiB, 25% | step 1, d2h FIXED | d2h mismatch (confirmed gone) |
| — | 4-D-8 `aa6d70ba` | — | — | redundant duplicate H2D (byte-eq-exact, ~½ non-cuBLAS H2D) |
| #9 | 4-D-8 | 459 MiB, 18% | step 1, wall=601 | **decisive: proves the residual bound is STRUCTURAL, not duplicate-copy** |

Every infrastructure and primitive-discipline lever available at $0 has been pulled. fire #9 is the measurement that **justifies** (not designs-first) the remaining architecture: persistent device residency requires a substrate residence-API change, because the substrate has no mechanism to (a) keep a farr resident across ops, (b) skip H2D for an already-resident input, (c) defer D2H of an intermediate, or (d) address a sub-view (offset/len) of a resident base buffer.

## 3. Source evidence (g3 — fire data direct trace)

1. **fire #9 decisive measurement** (`PHASE4D7_FIRE9_ANALYSIS.md` §3): halving non-cuBLAS H2D moved step-1 completion by 0 (wall 600→601s, GPU 25%→18%/581→459 MiB — within noise). The d768·12L per-step wall is structural-round-trip + CPU-glue bound, NOT duplicate-H2D bound. This is the empirical refutation of "primitive-discipline is enough."
2. **substrate code-inspection** (Phase 4-D-8 agent, grep-verified): `runtime_cuda.c:_h2d` unconditional `cudaMemcpy HostToDevice`; clears `dirty_dev`/sets `loc=MIRRORED` only *after* the copy, never *reads* them to skip; every `*_gpu` wrapper does `_h2d(inputs); kernel; _d2h_out(output)` with no defer; **no `(base_id, offset, len)` device-view API exists anywhere**.
3. **substrate is verified** (`PHASE4D_5_3_ANALYSIS.md`): 12 kernels (11 Phase B/B2 + RoPE) byte-eq on A100, 11/11 PASS. RFC 056 MUST preserve this oracle — a resident buffer is bit-identical to its host copy by construction, so a correctly-implemented residence-skip changes no bytes.
4. **model/cache scale** (fire #8/#9 trainer.out): model 104,024,832 doubles + cache 346,842,881 doubles ≈ **3.6 GB**, of which only ≤581 MiB was ever resident — the bulk round-trips per op.

## 4. Scope (DESIGN ONLY)

RFC 056 specifies:

- A **device residence state contract** extending RFC 040's `HexaFarrEntry.{loc,dirty_host,dirty_dev,d_buf}` with explicit FARR_HOST / FARR_MIRRORED / FARR_DEVICE transitions and the invariant each forge op must honor
- **H2D-skip rule**: a forge `_gpu` op whose input farr is `loc∈{DEVICE,MIRRORED} && !dirty_host` MUST NOT re-issue `cudaMemcpy HostToDevice`
- **D2H-defer rule**: a forge `_gpu` op output consumed by a subsequent GPU op stays `loc=DEVICE, dirty_dev=1`; D2H happens only when a host-side reader touches it (lazy materialization, RFC 040 arena ownership preserved)
- A **device-sub-view API**: `(base_id, offset, len)` device triple so the A2 primitive can hand forge a slice of a resident base buffer (Bc cache offsets) without a host round-trip or a re-upload
- **Residence anchor primitive**: `hexa_farr_pin_device(id)` / `hexa_farr_unpin_device(id)` so the A2 primitive pins model weights (Bp) + cache (Bc) once per step (or across steps)
- 7 pre-registered falsifiers (Stage 2 — verified by post-land d768 fire)

RFC 056 does NOT specify:

- New `.cu` kernel math (RFC 040/041/044 cover kernel bodies — RFC 056 only changes the H2D/D2H wrapper discipline + adds the view-arg, never the compute)
- flame public API change (`g_flame_api_fixed` — residence is internal to the compiled stdlib + A2 primitive)
- flame IR-pass internals (RFC 047/048)
- Precision/regime axes (RFC 049/050 — orthogonal; RFC 056 is the residence axis they assumed)
- Multi-GPU residence / NVLink peer (out of scope, future RFC)

## 5. Problem — no persistent device residency mechanism in the substrate

The flame:forge::torch:ATen substrate has device-farr (RFC 040) and verified kernels (RFC 041 / 4-D-5-3), and the A2 primitive correctly drives them (post Agent #44). But every forge `_gpu` op is **self-contained**: it H2D-uploads its inputs, computes, D2H-downloads its output, host stays authoritative. At d768·12L (T=1024, 12 layers, ~7 matmul + attention + 2 RMSNorm + RoPE + SwiGLU per layer) this is **thousands of PCIe round-trips per training step** over a 3.6 GB model+cache. fire #9 measured that even halving the non-cuBLAS half of that traffic does not complete step 1 in 600s.

There is no API to express "this buffer is already on the device, operate in place" — so the GPU-resident trainer cannot actually be resident. This is the precise, measured, sole remaining architectural gap to the GOAL.

## 6. Proposal — device residence contract + sub-view API

### 6.1 Residence state machine (extends RFC 040 HexaFarrEntry)

```
FARR_HOST     : d_buf == NULL; host buf authoritative
FARR_MIRRORED : d_buf valid; host buf == device bytes (clean both sides)
FARR_DEVICE   : d_buf valid; device authoritative; host buf stale (dirty_dev=1)
```

Transitions (the contract every forge op honors):

| op input state | action | post-state |
|---|---|---|
| FARR_HOST | `cudaMemcpy H2D` (as today) | FARR_MIRRORED |
| FARR_MIRRORED && !dirty_host | **SKIP H2D** | FARR_MIRRORED |
| FARR_DEVICE | **SKIP H2D** (device already authoritative) | FARR_DEVICE |
| FARR_* && dirty_host | `cudaMemcpy H2D` (host changed) | FARR_MIRRORED |

| op output disposition | action | post-state |
|---|---|---|
| consumed by next GPU op (dispatcher hint) | **DEFER D2H** | FARR_DEVICE, dirty_dev=1 |
| host reader touches it | `cudaMemcpy D2H` (lazy) | FARR_MIRRORED |
| step boundary scalar (loss/grad-norm) | `cudaMemcpy D2H` | FARR_MIRRORED |

**Byte-eq invariant (preserves the 11/11 oracle)**: a SKIP-H2D is correct iff device bytes already equal what the H2D would have written. FARR_MIRRORED/DEVICE with `!dirty_host` guarantees exactly that (the device buffer was written by the authoritative path and host has not mutated it since). Therefore RFC 056 changes **zero output bytes** vs the verified Phase 4-D-5-3 path — the falsifier F-RFC056-BYTEEQ-PRESERVE re-runs the 12-kernel oracle and requires `max|Δ|=0.0`.

### 6.2 Device-sub-view API

The A2 primitive slices the Bc cache (346M doubles) into per-op offsets. Today each slice is a host-side copy → forces a fresh farr → fresh H2D. RFC 056 adds a non-owning device view:

```c
// forge substrate — device-sub-view (non-owning, no alloc, no copy)
int hexa_farr_dev_view(long base_id, long offset, long len, long* out_view_id);
// out_view_id is a lightweight handle: {base_id, offset, len}; its d_buf
// = base.d_buf + offset*sizeof(double); shares base residence state.
// forge _gpu kernels accept a view_id wherever they accept a farr id.
```

A view never owns memory (RFC 035/040 arena ownership unchanged); it is invalidated if the base is freed or migrated. Out-of-range `(offset,len)` → return error, no UB.

### 6.3 Residence anchor primitive

```c
int hexa_farr_pin_device(long id);    // force FARR_DEVICE, H2D once, hold
int hexa_farr_unpin_device(long id);  // allow eviction, D2H if dirty_dev
```

The A2 primitive calls `pin_device(Bp_id)` + `pin_device(Bc_id)` once at step entry (or once across steps if the optimizer updates in place on device). Forge ops on pinned bases + their views then run fully resident; only the per-step scalar comes back via the lazy D2H rule.

### 6.4 Dispatcher "consumed-by-next-GPU-op" hint

D2H-defer needs to know an output feeds another GPU op. The A2 primitive already knows the op sequence (it emits it). RFC 056 adds a per-call `out_disposition` arg to the forge `_gpu` wrappers: `FORGE_OUT_DEVICE_KEEP` (defer D2H, stay resident) | `FORGE_OUT_HOST_NOW` (D2H immediately, as today). Default = `FORGE_OUT_HOST_NOW` so any caller not updated keeps exact current behavior (backward-safe, byte-eq-safe).

### 6.5 Non-matmul CPU glue (the other half of the fire #9 bound)

fire #9 isolated TWO bound components: structural per-op round-trip (above) AND CPU non-matmul loops (attention softmax / RMSNorm / RoPE / SwiGLU at d768·12L). The forge substrate **already has verified kernels** for these (Phase 4-D-5-3: `softmax_rows`, `rmsnorm_rows`, `rmsnorm_bwd_rows`, `silu`, `silu_grad`, `mul`, `add`, `scale`, RoPE). RFC 056 §6.1-6.4 makes routing the A2 primitive's CPU loops to those kernels *worthwhile* (without residency, dispatching them just adds more round-trips — which is why fire #5→#9 left them on CPU). Residency + already-verified kernels together = the GPU-resident block. The kernel-routing itself is flame Phase 4-D-9 work, gated on RFC 056.

## 7. Falsifier battery (7 pre-registered, Stage 2 verified by post-land d768 fire)

Compiled-native path only. Reference = the verified Phase 4-D-5-3 oracle + fire #8/#9 measured wall anchors. No fabricated targets.

### F-RFC056-BYTEEQ-PRESERVE
Re-run the Phase 4-D-5-3 12-kernel byte-eq oracle with the residence-skip + sub-view path active. Requirement: **`max|Δ|=0.0`, 12/12 PASS**, identical to the pre-RFC-056 substrate. (A resident buffer == its host copy by construction; any Δ ≠ 0 is a residence-state bug, not a precision tradeoff.)

### F-RFC056-D32-BYTEEQ
flame d=32·3L `verify_all` 26/26 byte-eq PASS, `max|Δ|=0.0`, unchanged (d=32 is the CPU/threshold-gated path; RFC 056 must not perturb it).

### F-RFC056-RESIDENT-MEM
d768·12L fire: GPU resident memory reaches **≥ 3.0 GB** (model 104M + cache 346M doubles ≈ 3.6 GB, allow margin) sustained across step 1 — vs fire #9's 459 MiB. Direct nvidia-smi capture.

### F-RFC056-H2D-COUNT
Per-step `cudaMemcpy HostToDevice` call count drops from O(thousands) to **O(few)**: model+cache pinned once + per-step input batch; instrumented count. Anchor: fire #9 structural-bound diagnosis.

### F-RFC056-STEP-COMPLETES
d768·12L **step 1 completes** (prints post-update gn2) within the 600s budget — the first time in the campaign. Binary PASS/FAIL, honest (fires #5–#9 all FAILed this).

### F-RFC056-WALL (the GOAL falsifier)
d768·12L full `train_step` wall **≤ 437.9s** (F-RFC046-EAGER-PYTORCH-MATCH = 1.3× of 336.85s PyTorch eager). This is THE GOAL gate. Honest: may FAIL on first fire even with residency (CPU-glue routing is Phase 4-D-9); if so, RFC 056 still PASSes its own §7.1-7.5 falsifiers and the residual is re-measured (no fudge).

### F-RFC056-VIEW-SAFETY
`hexa_farr_dev_view` out-of-range `(offset,len)` returns error (no UB, no crash); freeing/migrating a base invalidates its views (use-after-free guarded). Tested with deliberate out-of-range + free-then-use fixtures.

## 8. Honest caveats (g3 / f1 / f2)

### 8.1 RFC 056 touches the VERIFIED substrate — highest-risk RFC in the campaign
`self/runtime.c` + `self/cuda/runtime_cuda.c` are the Phase 4-D-5-3 11/11 byte-eq oracle. Every prior cycle's instruction was "do not modify the verified substrate." RFC 056 is the deliberate, reviewed exception — which is exactly why it is RFC-first (g7) and why F-RFC056-BYTEEQ-PRESERVE (oracle re-run, `max|Δ|=0.0`) is falsifier #1. The kernel **math** is untouched; only the H2D/D2H **wrapper discipline** + a non-owning view arg change.

### 8.2 Residency alone may not hit F-RFC056-WALL
fire #9 isolated two bound components (structural round-trip + CPU glue). RFC 056 removes the first and *enables* removing the second (§6.5), but the CPU-glue→verified-kernel routing is flame Phase 4-D-9 (gated on this RFC). Honest: the first post-RFC-056 fire may complete step 1 (F-RFC056-STEP-COMPLETES PASS) yet still miss F-RFC056-WALL until 4-D-9 lands. That is acceptable — the falsifiers are scoped so RFC 056 is judged on residency, not on the full GOAL in one shot.

### 8.3 Backward-safe by default
`out_disposition` defaults to `FORGE_OUT_HOST_NOW` and H2D-skip only triggers on a provably-clean resident input. Any caller not updated to the new contract gets byte-identical current behavior. No flag-day; the A2 primitive opts in incrementally, each step re-runnable against the oracle.

### 8.4 Cross-step residency is a follow-on
§6.3 allows pinning across steps (optimizer in-place on device). Whether the flame optimizer can update Bp in place on device is a flame Phase 4-D-9+ question; RFC 056 only guarantees within-step residency. Cross-step is a stated extension, not a falsifier here.

### 8.5 No lattice numerology (f1/f2 deny)
Every threshold (≥3.0 GB resident, ≤437.9s wall, H2D count) traces to fire #5–#9 measured captures or the F-RFC046 PyTorch-eager anchor. No perfect-number/lattice constants in the state machine, the view API, or the falsifier targets.

## 9. Non-goals

- No `.cu` kernel math change (only wrapper H2D/D2H discipline + view arg)
- No flame public API change (`g_flame_api_fixed`)
- No flame IR-pass change (RFC 047/048)
- No precision/regime change (RFC 049/050 orthogonal)
- No multi-GPU / NVLink-peer residence (future RFC ≥ 060)
- No supersession of RFC 040/041/044/050 — RFC 056 adds the residence axis they assumed
- No claim that RFC 056 alone achieves the GOAL — it removes the measured structural blocker; F-RFC056-WALL is honest about the CPU-glue residual

## 10. Cross-RFC dependency

- **RFC 040** (device-farr + cuBLAS) — RFC 056 extends its `HexaFarrEntry` residence flags into an explicit contract; cuBLAS Dgemm path unchanged (final fallback)
- **RFC 041** (Phase B/B2 `.cu` kernels) — those verified kernels gain H2D-skip/D2H-defer wrappers; bodies untouched
- **RFC 043** (flame stdlib design) — north-star consumer; the GOAL is its d768·12L fire
- **RFC 044** (regime-tiered substrate) — residence is orthogonal to regime; both compose
- **RFC 050** (flame↔forge dispatch API) — RFC 050's lifetime contract ("caller allocates, dispatcher reads/writes, no hidden alloc") is preserved; RFC 056 adds the residence/disposition args RFC 050 §6.5 left implicit
- **RFC 055** (hexa→NVPTX codegen) — independent; when forge becomes hexa-native, the residence contract carries over as the same state machine
- **flame Phase 4-D-9** (future) — routes A2 CPU non-matmul loops to verified forge kernels; gated on RFC 056 (without residency it adds round-trips — fire #5–#9 proved this)

## 11. Cross-link

### flame SSOTs
- `stdlib/flame/PLAN.md` §"진행 로그 — Phase 4-D-6 → 4-D-8 + fire #5→#9" — the campaign log this RFC concludes
- `stdlib/flame/FLAME.tape` — consumer-side SSOT
- `GOAL.md` (repo root) — the one-sentence north-star RFC 056 is P0 for

### forge SSOTs
- `self/forge/PARADIGM.md` — measurement-anchored thesis
- `self/forge/PLAN.md` — substrate phases; RFC 056 = a Phase 4 residence sub-phase
- `self/forge/FORGE.tape` — `x_oracle_cublas` (the byte-eq oracle RFC 056 must preserve)

### fire evidence (g3 — every RFC 056 claim sourced here)
- `state/flame_phase4d6_gpu_fire_2026_05_17/PHASE4D6_GPU_FIRE_ANALYSIS.md` (fire #5)
- `state/flame_phase4d7_gpu_fire_2026_05_17/PHASE4D7_FIRE{7,8,9}_ANALYSIS.md` (fires #7/#8/#9 — #9 = the decisive measurement)
- `state/forge_phase4d_5_3_2026_05_17/PHASE4D_5_3_ANALYSIS.md` (12-kernel byte-eq oracle — the invariant)

## Authority

- AGENTS.tape `g3` (real-limits-first) — every threshold traces to fire #5–#9 captures or the F-RFC046 PyTorch-eager anchor; fire #9 is the experiment that justifies this architecture (not design-first)
- AGENTS.tape `g5` (hexa-native-only) — forge substrate = C/CUDA portable artifact; RFC 056 changes wrapper discipline, no LLVM/C-transpile backend
- AGENTS.tape `g7` (inbox-patches-pipeline) — RFC 056 filed at `docs/rfc/rfc_drafts_2026_05_12/`; RFC-first because it touches the verified substrate
- AGENTS.tape `g_arch_vs_log_split` — RFC 056 = architecture draft; land event appends to FORGE.tape + FLAME.tape ## Log
- AGENTS.tape §0 `nn_stack` — forge=substrate, flame=consumer; RFC 056 is a substrate-internal residence contract
- LATTICE_POLICY `f1`/`f2` — no lattice numerology; all anchors measured
- HEXA-NATIVE-ONLY — forge dispatcher is C runtime via hexa builtin convention (RFC 040 pattern)
- `g_flame_api_fixed` — no flame public API change
- `g_forge_substrate_role` / `g_flame_compiler_only` — residence is compiled-native, no interp dispatch
- `g_forge_verify_oracle` — F-RFC056-BYTEEQ-PRESERVE re-runs the 12-kernel oracle at `max|Δ|=0.0`; no-fake-PASS preserved
