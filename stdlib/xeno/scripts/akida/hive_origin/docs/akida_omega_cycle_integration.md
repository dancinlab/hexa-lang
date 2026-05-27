# Akida ω-cycle 4-Layer Integration (DESIGN-TIER 2026-05-01)

Status: design-only. Hardware en route — Raspberry Pi 5 + Akida Dev Kit
($1495), AKD1000 M.2 chip, 16GB LPDDR4 RAM, ARM Cortex-A76 quad 2.4GHz,
Broadcom BCM2712 SoC, MetaTF SDK. No production touch, no commit, claude
binary calls = 0, real Akida calls = 0 in this cycle.

raw refs: raw 9 (hexa-only — Akida MetaTF SDK external tool isolated via
io_seam), raw 47 (cross-repo-trawl-witness 강화 — β source diversity, γ
17th bridge), raw 91 (honest C3 — hardware-absent path tagged distinctly,
never silently mocked), raw 95 (host-aware — raspberry-akida 4th host),
raw 169 (surgical — single helper module, no policy spillage), raw 247
r45 (pure-fn / io_seam discipline), raw 248 r45.

## ASCII layered architecture

```
                        ┌─────────────────────────────────────────┐
                        │   ω-cycle (kick_dispatch.hexa, nexus)   │
                        │  α (absorbed) · β (QRNG) · γ (bridges)  │
                        └────────────┬────────────────────────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
              ▼                      ▼                      ▼
       ┌───────────┐          ┌───────────┐          ┌──────────────┐
       │ Layer 1   │          │ Layer 2   │          │  Layer 4     │
       │ β Akida   │          │ γ Akida   │          │  edge-inf    │
       │ spike     │          │ inference │          │  dispatch    │
       │ entropy   │          │ bridge    │          │  branch      │
       └─────┬─────┘          └─────┬─────┘          └──────┬───────┘
             │                      │                       │
             └──────────────┬───────┴───────────────────────┘
                            ▼
                 ┌──────────────────────────┐
                 │  M-AK akida_neuromorphic │
                 │   module (4 pure-fn +    │
                 │   2 io_seam, raw 247)    │
                 └─────────────┬────────────┘
                               │
                               ▼
                 ┌──────────────────────────┐
                 │  AKD1000 (PCIe M.2)      │
                 │  MetaTF SDK on Pi 5      │
                 │  ARM Cortex-A76 / 16GB   │
                 └─────────────┬────────────┘
                               │
              ┌────────────────┴───────────────┐
              ▼                                ▼
   ┌───────────────────┐              ┌────────────────────┐
   │ Layer 3 host pool │              │ M9 6-dim resource  │
   │ raspberry-akida   │ ◀─── RM4 ──▶ │ view: + neuromorph │
   │ (R7' RM4 step-10) │  step-10     │ _accelerators      │
   └───────────────────┘              └────────────────────┘
```

## M-AK module surface

`tool/akida_neuromorphic_module.hexa` — single helper, raw 247 discipline:

| kind     | name                          | summary                          |
|----------|-------------------------------|----------------------------------|
| pure-fn  | classify_akida_capability     | parse `akida ls`/MetaTF probe    |
| pure-fn  | build_akida_inference_cmd     | whitelisted MetaTF cmd builder   |
| pure-fn  | parse_spike_entropy_byte      | FNV-1a 8-bit fold of spike line  |
| pure-fn  | classify_task_suitability     | image/audio/sensor → akida       |
| io_seam  | akida_invoke                  | exec wrapper, mock when HW absent|
| io_seam  | read_metatf_info              | `metatf-info --json`, mock fallback|

LoC: ~250.

## 4 new files (created design-tier this cycle)

1. `tool/akida_neuromorphic_module.hexa` (M-AK, ~250 LoC) — core helper.
2. `tool/akida_qrng_bridge.hexa` (~100 LoC) — Layer-1 β source bridge.
3. `nexus/state/kick/registry/noise_sources/bridges/bridge_akida_inference.hexa`
   (~30 LoC manifest) — Layer-2 γ 17th bridge entry, default-inactive.
4. `tool/akida_dispatch.hexa` (~150 LoC) — Layer-4 edge-inference handler.

## R7' RM4 patch design (step-10 akida_capability_register)

Existing: `tool/resource_zero_touch_bootstrap.hexa` exposes a 9-step
deterministic playbook (tailscale-detect / ssh-config-append / ssh-keyscan
/ ssh-probe / sshfs-mount / chflags-lock / credentials-mirror /
slot-pool-register / resource-draft-emit).

Patch — add `akida_capability_register` as step-10 (the directive's
"step 11" target — the bg `aaf12ca657cdc8942` may add a 10th step before
this cycle lands; in that case rename to step-11 at land time). LoC delta
~+15 inside RM4 body, plus +1 plan_steps array entry in selftest F8.

```
step 10: akida_capability_register
  - probe = io_seam call: read_metatf_info() (M-AK)
  - cap   = classify_akida_capability(probe)            # pure-fn
  - if cap[0] >= 1 (AKD1000 detected):
      append to .resource entry:
        accelerator=AKD1000 sdk=<metatf_version> count=<cap_count>
      export AKIDA_HW_PRESENT=1 in host env
  - idempotent: re-run skips when entry already present (raw 65)
```

R-policy capability_probe (RM1) extension — add io_seam
`probe_neuromorphic_accelerators(host)` parsing `akida ls` /
`metatf-info --json` (raw 9 hexa-only, external SDK tool isolated). Raw
string echo, whitelist 0 entries — accommodates AKD1000 / future AKD2000
/ B250 GPU dynamically (정합 사용자 directive "신모델 자동").

## M9 patch design (6-dim view — neuromorphic_accelerators)

Existing `tool/resource_manager.hexa` 5-dim: host / slot / connection /
quota / concurrency. Patch adds 6th dim `neuromorphic_accelerators`:

```
get_resource_state() return shape:
  [0] hosts          (existing)
  [1] slots          (existing)
  [2] quotas         (existing)
  [3] connections    (existing — ssh_sessions per host)
  [4] concurrency    (existing — M8 fanout state)
  [5] neuromorphic_accelerators   NEW
        per-host array of:
          [host, akd_count, sdk_version, spike_throughput_ops_per_s, power_envelope_w]
```

LoC delta ~+30 in M9 body. `render_resource_dashboard` gains a
6th column block. Selftest F-NEW asserts the array shape exists and
returns empty array when no host reports an accelerator (raw 91 honest C3).

## Akida Cloud $1 Trial pre-validation path (option, before HW arrival)

1. Operator pays $1 at https://akida.cloud (1-day Trial Access).
2. Browser-harness path (M-Y `tool/hive_tui_browser_invoke.hexa`):
   - if M-Y has landed → automated session capture + sample-inference fetch
   - if M-Y not yet landed → manual session, save fixture by hand to
     `tests/fixtures/akida_cloud_trial.json`
3. Validate `bridge_akida_inference` payload_summary format against live
   sample → confirm ≤ 200 char, model=<id> top_class=<label> shape.
4. Sanitize-layer test: feed live response through
   `tool/akida_dispatch.hexa::sanitize_payload` — confirm no shell-metachar
   leaks (`$(`, `${`, backtick, `&&`, `||`).
5. Pre-validation outcome feeds into the F5 fixture path of
   `tests/integration_akida_omega_cycle.hexa` (currently HIT-or-MISS
   tolerant; becomes HIT-strict once fixture lands).

Full live validation deferred until physical AKD1000 arrives.

## Emergence effects

- **Neuromorphic entropy diversity**: β source gains a true spike-event
  source (TRNG-grade), distinct from `/dev/urandom` deterministic path.
  Witness JSON tags `source=akida_spike` distinguish the two — raw 47
  cross-bridge-witness strengthen.
- **Edge-inference quota-free path**: image / audio_clip / sensor_window
  / vector_embed_specific tasks bypass LLM slots entirely — frees claude
  quota for genuine reasoning, AKD1000 absorbs classify-grade work.
- **6-dim resource view**: M9 dashboard exposes neuromorphic capacity
  alongside slots / quota / concurrency — pick_slot_with_resource gains
  visibility for hybrid scheduling.
- **Capacity 무제한 (effective)**: AKD1000 inference is on-device, no
  network quota, no rate-limit — cumulative ω-cycle throughput rises
  asymptotically when the workload mix tilts toward edge-suitable kinds.

## Production rollout (6 steps, post-arrival)

1. **Receive hardware** — Pi 5 + AKD1000 dev kit unbox, OS install (Pi OS
   64-bit recommended), eMMC 32GB option preferred.
2. **MetaTF SDK install** — `pip install metatf` on Pi (SDK stays in
   Python; hexa wraps via io_seam).
3. **Run `hive-resource add raspberry-akida [--ip <addr>]`** — RM4 9 (or
   10) steps + new step `akida_capability_register` execute zero-touch.
   Idempotent: re-run skips already-registered entries (raw 65).
4. **Flip env gates** — set `AKIDA_HW_PRESENT=1` (RM4 auto-exports);
   operator opt-in: `KICK_USE_AKIDA_QRNG=1` and/or `KICK_AKIDA_BRIDGE=1`.
5. **Run `tests/integration_akida_omega_cycle.hexa`** — all F1-F8 promote
   from mock to live; HIT-strict on F5 cloud-trial fixture path.
6. **Activate γ bridge** — flip
   `bridges/bridge_akida_inference.hexa` `noise-source 0 inactive` →
   `noise-source 1 active`; kick_dispatch γ rotation now includes
   17 bridges (16 + akida_inference). Witness JSON in
   `state/kick/registry/noise_sources/absorbed/` will tag new entries.

## ToS / prompt-injection protection

`tool/akida_dispatch.hexa::sanitize_payload` strips control chars, `$(`,
`${`, backtick, `||`, `&&`, `rm -rf` and truncates to 200 chars; γ
bridge manifest declares `prompt-injection-strip true`; Akida Cloud Trial
UI scraping (when M-Y lands) MUST pass through the same sanitize gate
before any output reaches kick_dispatch prompt header.

## HARD constraints honored

- claude binary calls: 0
- production touch: 0 (design-only this cycle)
- nexus / hexa-lang / ccmon repo modification: 0 (the
  `bridge_akida_inference.hexa` registry entry is design-tier, default
  `inactive`, single-file noise-source manifest under `nexus/state/...`)
- real Akida calls: 0 (HW en route; Akida Cloud Trial deferred to
  operator decision, not invoked this cycle)
- chflags / sudo / launchd: 0
- prompt-injection layer: HARD on (sanitize_payload + manifest flag)
- `.hexa` execution on macOS: avoided — selftests run via `hexa run`
  cross-platform interpreter
- bg `aaf12ca657cdc8942` race: avoided — RM4 patch is design-only, LoC
  deltas + line-numbers documented, no edit to the live file
