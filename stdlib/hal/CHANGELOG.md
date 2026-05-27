# stdlib/hal CHANGELOG

## [1.25.0] - 2026-05-09

### Added — `numerics_ai_native_pdk_set.hexa` F-AI-NATIVE-6 T2 (★ triple-axis sat-1 milestone)
- `numerics_ai_native_pdk_set.hexa` (~225 lines) — **6th + LAST T2
  fixture for AI-native axis**. Cross-checks the 3-PDK paper backend
  set (sky130 / tsmc_n5 / samsung_sf3p) against on-disk
  backend/ai_native/<pdk>.hexa files.

  6 numerical checks:
    1. all 3 backend/ai_native/<pdk>.hexa files present
    2. each declares PDK_NODE_NM with expected values (130 / 5 / 3)
    3. OVERHEAD_BP = 278 consistent across all 3 PDKs (φ/σ_n=1/36 ≈ 2.78%)
    4. N_TILES = 6 consistent across all 3 PDKs (mirror of ai.hexa)
    5. node sizes monotonic descending: SKY130 > TSMC N5 > SF3P
    6. PDK_NAME strings match canonical (sky130/tsmc_n5/samsung_sf3p)

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_AI_NATIVE_PDK_SET__ PASS`.

  Pattern: numerics_gpgpu_lattice.hexa (multi-backend on-disk check).

  **F-AI-NATIVE-6 closure lifted: 33% → 67%** (T1 ✓ + T2 ✓; T3 deferred
  per canon §7.5).

  ★ **F-AI-NATIVE axis sat-1 milestone REACHED** ★ — all 6
  F-AI-NATIVE falsifiers now at 67% closure (T1+T2 ✓ across the board).
  6/6 T2 fixtures landed (100%). T3 (silicon RTL bench + actual
  per-PDK tape-out) blocked on foundry MOU + downstream FFI;
  lifts each F-AI-NATIVE 67% → 100% only when tape-out lands.

  ★★ **TRIPLE-AXIS 3/3 SAT-1 LEDGER COMPLETE** ★★ —
    F-HAL-1..5         HW-12 axis        sat-1 ✓ since v0.3.0  (fc2eeb2f)
    F-GPGPU-1..6       GPGPU axis        sat-1 ✓ since v1.18.0 (198ca58b)
    F-AI-NATIVE-1..6   AI-native axis    sat-1 ✓ since v1.25.0 (this iter)

  Total: **17 falsifiers** across 3 independent lattice axes, all at
  ≥ 67% closure (T1+T2 ✓), every T2 fixture either on disk or formally
  preregistered. T3 universally deferred per canon §7.5 FFI-downstream
  rule (HW-12 needs Renode silicon emulator; GPGPU needs GPU runtime
  FFI; AI-native needs RTL synthesis + tape-out).

  Phase G iter 9+5+13.

## [1.24.0] - 2026-05-09

### Added — `numerics_ai_native_bt_coverage.hexa` F-AI-NATIVE-5 T2 numerical (lifts to 67%)
- `numerics_ai_native_bt_coverage.hexa` (~165 lines) — fifth T2 fixture
  for AI-native axis. Cross-checks BT_COVERAGE = sopfr(n)+φ = 7 audit
  coverage + BT_RESERVED..BT_547 = 0..7 enumeration against on-disk
  ai.hexa source.

  7 BTs (Clay Math Millennium Prize Problems + Riemann zeros):
    BT_541 Riemann zeros / BT_542 P vs NP / BT_543 Yang-Mills /
    BT_544 Navier-Stokes / BT_545 Hodge / BT_546 BSD /
    BT_547 Poincaré

  8 numerical checks: ai.hexa present / SOPFR_N=5 / PHI=2 /
  BT_COVERAGE=7 / sopfr(n)+φ=BT_COVERAGE algebraic identity / BT_*
  contiguous 0..7 (1 reserved + 7 named, no gaps/dupes).

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_AI_NATIVE_BT_COVERAGE__ PASS`.
  Pattern: numerics_ai_native_lattice.hexa (sister; algebraic identity
  + enumeration check).

  **F-AI-NATIVE-5 closure lifted: 33% → 67%**. 5/6 T2 fixtures landed
  for AI-native axis (83%); only F-AI-NATIVE-6 pdk_set remaining
  (planned v1.25.0). Phase G iter 9+5+12.

## [1.23.0] - 2026-05-09

### Added — `numerics_ai_native_tile_count.hexa` F-AI-NATIVE-4 T2 numerical (lifts to 67%)
- `numerics_ai_native_tile_count.hexa` (~155 lines) — fourth T2 fixture
  for AI-native axis. Cross-checks n_tiles = σ/φ = 6 native tiles per
  HEXA-AI chip + provenance overhead denominator σ_n = σ·n_tiles = 72
  against on-disk ai.hexa source.

  8 numerical checks: ai.hexa present / SIGMA=12 / PHI=2 / N_TILES=6 /
  SIGMA_N=72 / σ/φ=N_TILES (algebraic identity) / σ·n_tiles=σ_n
  (overhead denom identity) / fn ai_invariant_n_tiles accessor present.

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_AI_NATIVE_TILE_COUNT__ PASS`.
  Pattern: numerics_ai_native_lattice.hexa (sister F-AI-NATIVE-1 T2).

  **F-AI-NATIVE-4 closure lifted: 33% → 67%**. 4/6 T2 fixtures landed
  for AI-native axis (67%); remaining 2 (bt_coverage/pdk_set) planned
  v1.24.0+. Phase G iter 9+5+11.

## [1.22.0] - 2026-05-09

### Added — `numerics_ai_native_prov_dichotomy.hexa` F-AI-NATIVE-3 T2 numerical (lifts to 67%)
- `numerics_ai_native_prov_dichotomy.hexa` (~140 lines) — third T2
  fixture for AI-native axis. Cross-checks the φ=2 provenance dichotomy
  (FACT / HYPOTHESIS) + promotion-counter-MMU threshold range
  [φ²=4, σ=12] against on-disk ai.hexa source.

  8 numerical checks: ai.hexa present / PHI=2 / PROV_FACT=0 /
  PROV_HYPOTHESIS=1 / strict dichotomy (distinct values) / THRESHOLD_MIN=4
  (= φ²) / THRESHOLD_MAX=12 (= σ) / THRESHOLD_MIN = φ² algebraic identity
  from on-disk PHI.

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_AI_NATIVE_PROV_DICHOTOMY__ PASS`.
  Pattern: numerics_gpgpu_ir_dichotomy.hexa (sister φ=2 dichotomy
  fixture for GPGPU axis).

  **F-AI-NATIVE-3 closure lifted: 33% → 67%**. 3/6 T2 fixtures landed
  for AI-native axis (50%); remaining 3 (tile_count/bt_coverage/pdk_set)
  planned v1.23.0+. Phase G iter 9+5+10.

## [1.21.0] - 2026-05-09

### Added — `numerics_ai_native_lifecycle.hexa` F-AI-NATIVE-2 T2 numerical (lifts to 67%)
- `numerics_ai_native_lifecycle.hexa` (~135 lines) — second T2 fixture
  for AI-native axis. Cross-checks the τ=4 lifecycle stage table
  (configure/start/serve/report = 0/1/2/3) against on-disk ai.hexa.

  7 numerical checks: ai.hexa present / TAU=4 / STAGE_CONFIGURE=0 /
  STAGE_START=1 / STAGE_SERVE=2 / STAGE_REPORT=3 / contiguous 0..3
  no-gaps-no-dupes.

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_AI_NATIVE_LIFECYCLE__ PASS`.
  Pattern: numerics_gpgpu_mem_tiers.hexa (cardinality + value enumeration).

  **F-AI-NATIVE-2 closure lifted: 33% → 67%**. 2/6 T2 fixtures landed
  for AI-native axis; remaining 4 (prov_dichotomy/tile_count/bt_coverage/
  pdk_set) planned v1.22.0+. Phase G iter 9+5+9.

## [1.20.0] - 2026-05-09

### Added — `numerics_ai_native_lattice.hexa` F-AI-NATIVE-1 T2 numerical (lifts to 67%)
- `numerics_ai_native_lattice.hexa` (~175 lines) — first T2 fixture for
  the AI-native silicon axis. Cross-checks J₂ = σ·φ = 24 lattice
  cardinality against on-disk ai.hexa source.

  9 numerical checks:
    1. ai.hexa present at stdlib/hal/ai.hexa
    2. ai.hexa declares SIGMA = 12
    3. ai.hexa declares PHI = 2
    4. ai.hexa declares J2 = 24
    5. ai.hexa declares MACS_PER_TILE = 24 (= J₂)
    6. ai.hexa declares MACS_PER_ARRAY = 288 (= σ²·φ)
    7. σ · φ = J₂ algebraic identity from on-disk values
    8. σ² · φ = MACS_PER_ARRAY chip-level peak identity
    9. ai.hexa declares fn ai_invariant_macs_per_tile / per_array accessors

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_AI_NATIVE_LATTICE__ PASS`.

  Pattern: numerics_gpgpu_lattice.hexa (sister F-GPGPU-1 T2). Same
  _check/RUN/FAIL harness, same _extract_let_int helper, same
  algebraic-identity-on-disk-values check.

  **F-AI-NATIVE-1 closure lifted: 33% → 67%** (T1 ✓ + T2 ✓; T3 deferred).
  1/6 T2 fixtures landed; remaining 5 (numerics_ai_native_{lifecycle,
  prov_dichotomy, tile_count, bt_coverage, pdk_set}.hexa) planned
  v1.21.0+.

  Phase G iter 9+5+8.

## [1.19.0] - 2026-05-09

### Added — `falsifier_ai_native_check.hexa` F-AI-NATIVE axis preregister + tracker
- `falsifier_ai_native_check.hexa` (~280 lines) — third axis closure
  tracker. Companion to:
    `falsifier_check.hexa`        (HW-12 axis F-HAL-1..5)
    `falsifier_gpgpu_check.hexa`  (GPGPU axis F-GPGPU-1..6)

  Preregisters **F-AI-NATIVE-1..6** for the AI-native silicon axis
  introduced at v1.8.0 (ai.hexa) + populated at v1.9.0 / v1.10.0 /
  v1.11.0 (3-PDK paper backends sky130 / tsmc_n5 / samsung_sf3p).

  **Falsifiers registered**:
    F-AI-NATIVE-1: J₂ = σ·φ = 24 native MAC slots × prov kinds per tile
    F-AI-NATIVE-2: 4-stage τ-lifecycle (configure/start/serve/report)
    F-AI-NATIVE-3: φ=2 provenance kinds (FACT / HYPOTHESIS)
    F-AI-NATIVE-4: n_tiles = σ/φ = 6 native tiles per HEXA-AI chip
    F-AI-NATIVE-5: BT_COVERAGE = sopfr(n)+φ = 7 (BT_541..BT_547)
    F-AI-NATIVE-6: 3-PDK paper backend set (sky130+tsmc_n5+samsung_sf3p)

  **T1 satisfiers** (all on disk now): ai.hexa + 3 PDK backend.hexa
  files. F-AI-NATIVE-6 specifically requires ALL 3 PDK paper backends
  present; F-AI-NATIVE-1..5 each reuse ai.hexa (different invariant
  consumed per falsifier).

  **T2 preregister** (planned v1.20.0+, file names committed):
    numerics_ai_native_lattice.hexa
    numerics_ai_native_lifecycle.hexa
    numerics_ai_native_prov_dichotomy.hexa
    numerics_ai_native_tile_count.hexa
    numerics_ai_native_bt_coverage.hexa
    numerics_ai_native_pdk_set.hexa

  **T3 deferred** (canon §7.5 + roadmap §G.5): silicon-tier RTL bench
  (refuse_event silicon trace + BT ledger silicon mirror + per-PDK
  P&R + tape-out) is downstream. Lifts each F-AI-NATIVE 67% → 100%
  only when actual tape-out lands (post-foundry-MOU territory).

  **Closure status at v1.19.0**:
    sat-2 (every F-AI-NATIVE has ≥1 T1 satisfier): EXPECTED PASS
    sat-1 (every F-AI-NATIVE ≥ 67% closure): NOT YET (pending T2)

  PASS sentinel: `__HEXA_LANG_HAL_FALSIFIER_AI_NATIVE_CHECK__ PASS`.

  Pattern: falsifier_gpgpu_check.hexa (sister GPGPU axis tracker).
  Same closure_pct formula (0/33/67/100), same sat_1/sat_2 saturation
  milestones, same regression-gate semantics.

  **Three-axis closure ledger now formalized**:
    F-HAL-1..5         HW-12 axis        sat-1 ✓ since v0.3.0 (fc2eeb2f)
    F-GPGPU-1..6       GPGPU axis        sat-1 ✓ since v1.18.0 (198ca58b)
    F-AI-NATIVE-1..6   AI-native axis    sat-1 pending (T2 fixtures)

  Phase G iter 9+5+7.

## [1.18.0] - 2026-05-09

### Added — `numerics_gpgpu_barriers.hexa` F-GPGPU-6 T2 numerical (★ F-GPGPU sat-1 milestone)
- `numerics_gpgpu_barriers.hexa` (~190 lines) — **sixth + last T2
  fixture for the GPGPU axis**. Cross-checks the 4 barrier scopes
  (subgroup / workgroup / cluster / grid) against on-disk vendor
  backend SCOPE_* declarations.

  Barrier-scope name mapping (canon §4 axis 4):
    SCOPE_SUBGROUP   → warp / wavefront / simdgroup / __syncwarp
    SCOPE_WORKGROUP  → block / threadgroup / __syncthreads / barrier()
    SCOPE_CLUSTER    → CUDA Hopper SM 9.0+ cluster.sync (newest;
                        emerged 2022 with H100)
    SCOPE_GRID       → cooperative_groups::grid_group::sync

  4 numerical checks:
    1. |barrier_scopes| = τ = 4 cardinality re-assert
    2. compute.hexa root declares all 4 SCOPE_* with values 0..3
    3. every vendor backend declares all 4 SCOPE_* with values 0..3
    4. SCOPE_* values are CONSISTENT across all 6 vendor backends

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_GPGPU_BARRIERS__ PASS`.

  Pattern: numerics_gpgpu_mem_tiers.hexa (sister F-GPGPU-5 T2 — both
  check 4-tier cardinality + cross-vendor agreement on integer ID
  consistency).

  **F-GPGPU-6 closure lifted: 33% → 67%** (T1 ✓ + T2 ✓; T3 deferred
  per canon §7.5 FFI-downstream rule).

  ★ **F-GPGPU axis sat-1 milestone REACHED** ★ — all 6 F-GPGPU
  falsifiers now at 67% closure (T1+T2 ✓ across the board). 6/6 T2
  fixtures landed (100%). T3 (cross-vendor SAXPY benchmark) remains
  blocked on GPU runtime FFI; lifts each F-GPGPU 67% → 100% when it
  lands. The F-GPGPU ledger now mirrors F-HAL's sat-1 milestone
  (reached at v0.3.0 fc2eeb2f for the embedded HW-12 axis) on the
  separate GPGPU axis.

  Phase G iter 9+5+6.

## [1.17.0] - 2026-05-09

### Added — `numerics_gpgpu_mem_tiers.hexa` F-GPGPU-5 T2 numerical (lifts to 67%)
- `numerics_gpgpu_mem_tiers.hexa` (~190 lines) — fifth T2 fixture for
  the GPGPU axis. Cross-checks the 4 memory tiers (private / group /
  device / constant) against on-disk vendor backend TIER_* declarations.

  Memory-tier name mapping (canon §4.2):
    TIER_PRIVATE  → register / per-thread / .local / private (SPIR-V)
    TIER_GROUP    → shared / threadgroup / workgroup / local (OpenCL)
    TIER_DEVICE   → global / storage / .global / StorageBuffer
    TIER_CONSTANT → constant / uniform (read-only, cached)

  4 numerical checks:
    1. |memory_tiers| = τ = 4 cardinality re-assert
    2. compute.hexa root declares all 4 TIER_* with values 0..3
       AND fn compute_invariant_tiers() accessor is present
    3. every vendor backend declares all 4 TIER_* with values 0..3
    4. TIER_* values are CONSISTENT across all 6 vendor backends
       (same numeric ID for same tier name; catches re-ordered drift)

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_GPGPU_MEM_TIERS__ PASS`.

  Pattern: numerics_phi_dichotomy.hexa (sister F-HAL-3 T2 fixture for
  the φ-dichotomy axis-cardinality check). Same _check/RUN/FAIL
  harness, same per-cell consistency scan + cross-vendor agreement check.

  **F-GPGPU-5 closure lifted: 33% → 67%** (T1 ✓ + T2 ✓; T3 deferred).
  5/6 T2 fixtures landed (83%); only numerics_gpgpu_barriers.hexa
  remaining for F-GPGPU-6 (planned v1.18.0).

  Phase G iter 9+5+5.

## [1.16.0] - 2026-05-09

### Added — `numerics_gpgpu_dispatch.hexa` F-GPGPU-4 T2 numerical (lifts to 67%)
- `numerics_gpgpu_dispatch.hexa` (~250 lines) — fourth T2 fixture for
  the GPGPU axis. Cross-checks J₂′ = σ·τ = 48 dispatch-state combination
  ceiling against the on-disk backend table.

  6 numerical checks:
    1. J₂′ = σ·τ = 12·4 = 48 algebraic re-assert
    2. compute.hexa declares fn compute_invariant_J2_prime() returning 48
    3. per-vendor stage score ≥ 3-of-4; Σ stage_count ≥ 18 floor
    4. Σ (vendor, canonical-IR) edges ≥ 6 (φ-axis projection cross-check)
    5. Σ (vendor·stage·IR) reachable states ≥ 18 floor (≤ J₂′=48 ceiling)
    6. every vendor with native IR_PRIMARY (amdgcn/msl_air/wgsl) ALSO
       declares canonical IR_FALLBACK in {ptx, spirv} — guards the
       φ=2 dichotomy projection from being undermined by native-only
       vendor backends.

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_GPGPU_DISPATCH__ PASS`.

  Pattern: numerics_handle_dispatch.hexa (sister F-HAL-4 T2 fixture —
  it scores J₂/n=4 handle-pool; this scores J₂′=48 dispatch-state
  space). Same _check/RUN/FAIL harness, same per-cell scoring + aggregate
  threshold.

  **F-GPGPU-4 closure lifted: 33% → 67%** (T1 ✓ + T2 ✓; T3 deferred).
  4/6 T2 fixtures landed; remaining 2 (numerics_gpgpu_{mem_tiers,
  barriers}.hexa) planned v1.17.0+.

  Phase G iter 9+5+4.

## [1.15.0] - 2026-05-09

### Added — `numerics_gpgpu_ir_dichotomy.hexa` F-GPGPU-3 T2 numerical (lifts to 67%)
- `numerics_gpgpu_ir_dichotomy.hexa` (~225 lines) — third T2 fixture
  for the GPGPU axis. Cross-checks the φ=2 IR substrates dichotomy
  (SPIR-V ∥ PTX) against on-disk vendor backend IR_PRIMARY/IR_FALLBACK
  declarations.

  Vendor-IR consumption mapping (canon §3 + 2026-05-08 web-search):
    cuda    → ptx primary, spirv fallback (clspv)            [PTX, SPIR-V]
    hip     → amdgcn primary, ptx fallback (HIP-on-NV)       [PTX]
    sycl    → spirv primary, ptx fallback (DPC++ NV path)    [PTX, SPIR-V]
    opencl  → spirv primary (OpenCL 3.0+ baseline)           [SPIR-V]
    metal   → msl_air primary, spirv fallback                [SPIR-V]
    webgpu  → wgsl primary, spirv fallback (Tint)            [SPIR-V]

  Native IRs (amdgcn/msl_air/wgsl) NOT counted toward φ=2; vendor-internal
  lowering targets only. φ=2 is strictly {SPIR-V, PTX} per canon §3.

  6 numerical checks:
    1. φ_gpgpu = 2 algebraic re-assert + |CANONICAL_IRS| = 2
    2. both IRs have ≥1 vendor consumer (no orphan IR)
    3. every vendor has ≥1 IR consumer (no orphan vendor)
    4. Σ (vendor, IR) edges ≥ 6 (6 vendors × 1 IR floor)
    5. cuda anchors PTX (canonical PTX-native vendor)
    6. opencl anchors SPIR-V (canonical OpenCL 3.0+ baseline)

  Expected (vendor, IR) edges sum: 8 (cuda+sycl have both; hip has PTX
  only; opencl/metal/webgpu have SPIR-V only).

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_GPGPU_IR_DICHOTOMY__ PASS`.

  Pattern: numerics_phi_dichotomy.hexa (sister F-HAL-3 T2 fixture).
  Same _check / RUN / FAIL harness, same orphan-detection scheme,
  same PASS/FAIL sentinel.

  **F-GPGPU-3 closure lifted: 33% → 67%** (T1 ✓ + T2 ✓; T3 deferred).
  3/6 T2 fixtures landed; remaining 3 (numerics_gpgpu_{dispatch,
  mem_tiers, barriers}.hexa) planned v1.16.0+.

  Phase G iter 9+5+3.

## [1.14.0] - 2026-05-09

### Added — `numerics_gpgpu_lifecycle.hexa` F-GPGPU-2 T2 numerical (lifts to 67%)
- `numerics_gpgpu_lifecycle.hexa` (~210 lines) — second T2 fixture for
  the GPGPU axis. Cross-checks the τ=4 lifecycle (compile/enqueue/
  dispatch/retire) against the on-disk vendor backend table by scoring
  each backend's lifecycle-fn surface.

  τ=4 stage → archetypal fn-suffix:
    compile  → `*_kernel_compile`
    enqueue  → `*_buffer_h2d` ∥ `*_buffer_alloc`
    dispatch → `*_dispatch`
    retire   → `*_event_wait` ∥ `*_event_release`

  6 numerical checks:
    1. 6 vendor roster cardinality
    2. τ_gpgpu = 4 stages algebraic re-assert
    3. per-vendor lifecycle score ≥ 3 of 4 stages
    4. Σ stage_count over 6 vendors ≥ 18 (= 6·3 floor)
    5. *_dispatch present on EVERY vendor backend (100% dispatch coverage)
    6. *_event_wait OR *_event_release present on EVERY backend (100%
       retire coverage)

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_GPGPU_LIFECYCLE__ PASS`.

  Pattern: numerics_lifecycle_dispatch.hexa (sister F-HAL-2 T2 fixture).
  Same _check / RUN / FAIL harness, same per-module-then-aggregate
  scoring, same PASS/FAIL sentinel scheme.

  **F-GPGPU-2 closure lifted: 33% → 67%** (T1 ✓ + T2 ✓; T3 deferred).
  2/6 T2 fixtures landed; remaining 4 (numerics_gpgpu_{ir_dichotomy,
  dispatch, mem_tiers, barriers}.hexa) planned v1.15.0+.

  Phase G iter 9+5+2.

## [1.13.0] - 2026-05-09

### Added — `numerics_gpgpu_lattice.hexa` F-GPGPU-1 T2 numerical (lifts to 67%)
- `numerics_gpgpu_lattice.hexa` (~210 lines) — first T2 fixture for the
  GPGPU axis. Cross-checks the σ=12 = 6 vendors × 2 IRs lattice
  cardinality against the on-disk backend table.

  9 numerical checks:
    1. 6 vendor roster cardinality (cuda/hip/sycl/opencl/metal/webgpu)
    2. 2 IR roster cardinality (spirv/ptx)
    3. 6 backend/<vendor>/compute.hexa files present on disk
    4. 2 backend/<ir>/compute.hexa files present on disk
    5. compute.hexa host primitive present at stdlib/hal root
    6. σ_gpgpu = 6·2 = 12 (algebraic re-assert)
    7. J₂′ = σ·τ = 12·4 = 48 (algebraic re-assert)
    8. axis distinct from HW-12 (no vendor/IR name collides with
       core/gpio/i2c/spi/uart/adc/dac/pwm/timer/intr/dma/rtc)
    9. every vendor backend's compute.hexa references ≥1 IR substrate
       (paper-tier mapping check via "PTX"/"SPIR-V" string scan)

  PASS sentinel: `__HEXA_LANG_HAL_NUMERICS_GPGPU_LATTICE__ PASS`.

  Pattern: numerics_module_topology.hexa (sister F-HAL-1 T2 fixture).
  Same _check / RUN / FAIL harness, same root resolution, same PASS/FAIL
  sentinel scheme.

  **F-GPGPU-1 closure lifted: 33% → 67%** (T1 ✓ + T2 ✓; T3 deferred per
  canon §7.5 FFI-downstream rule). 1st of 6 T2 fixtures committed in the
  preregister at v1.12.0; remaining 5 (numerics_gpgpu_{lifecycle,
  ir_dichotomy, dispatch, mem_tiers, barriers}.hexa) planned v1.14.0+.

  Phase G iter 9+5+1.

## [1.12.0] - 2026-05-08

### Added — `falsifier_gpgpu_check.hexa` F-GPGPU axis falsifier preregister + tracker
- `falsifier_gpgpu_check.hexa` (~245 lines) — companion to
  `falsifier_check.hexa` (the embedded HW-12 closure tracker).
  Preregisters **F-GPGPU-1..6** for the GPGPU axis introduced at
  v0.13.0 (compute.hexa) + populated at v1.6.0 (SPIR-V/PTX IR) +
  v1.7.0 (6 vendor backends).

  **Falsifiers registered**:
    F-GPGPU-1: σ=12 = 6 vendors × 2 IRs (lattice cardinality)
    F-GPGPU-2: 4-stage τ-lifecycle (compile/enqueue/dispatch/retire)
    F-GPGPU-3: φ=2 IR substrates (SPIR-V ∥ PTX); every vendor ≥1
    F-GPGPU-4: J₂′ = σ·τ = 48 dispatch-state combinations
    F-GPGPU-5: 4 memory tiers (private/group/device/constant)
    F-GPGPU-6: 4 barrier scopes (subgroup/workgroup/cluster/grid)

  **T1 satisfiers** (algebraic, on disk now): compute.hexa internal
  asserts + 6 backend/{cuda,hip,sycl,opencl,metal,webgpu}/compute.hexa
  files. F-GPGPU-3 specifically requires ALL 6 vendor backends present;
  the rest reuse compute.hexa.

  **T2 preregister** (planned v1.12.0+ — file names committed so future
  iters can drop them in without renaming):
    numerics_gpgpu_lattice.hexa
    numerics_gpgpu_lifecycle.hexa
    numerics_gpgpu_ir_dichotomy.hexa
    numerics_gpgpu_dispatch.hexa
    numerics_gpgpu_mem_tiers.hexa
    numerics_gpgpu_barriers.hexa

  **T3 deferred**: cross-vendor SAXPY benchmark fixture is blocked on
  actual GPU runtime FFI (canon §7.5 — FFI is downstream).

  **Closure status at v1.12.0**:
    sat-2 (every F-GPGPU has ≥ 1 T1 satisfier on disk): EXPECTED PASS
    sat-1 (every F-GPGPU ≥ 67% closure): NOT YET (pending T2 numerics)

  PASS sentinel: `__HEXA_LANG_HAL_FALSIFIER_GPGPU_CHECK__ PASS`.

  Pattern: falsifier_check.hexa (sibling for HW-12 axis). Same
  closure_pct formula (0/33/67/100), same sat_1/sat_2 saturation
  milestones, same regression-gate semantics.

  Phase G iter 9+5 (after 3-PDK ai_native set + 2 cross-repo consumers).

## [1.11.0] - 2026-05-08

### Added — `backend/ai_native/samsung_sf3p.hexa` Samsung SF3P PDK paper-tier backend (3rd / last PDK)
- `backend/ai_native/samsung_sf3p.hexa` (~175 lines) — Samsung Foundry
  SF3P 3nm GAA MBCFET PDK silicon backend stub for the AI-native
  (Beyond-GPU) axis. **Completes the 3-PDK ai_native paper backend
  set**: SKY130 (open-source baseline) → TSMC N5 (production) →
  Samsung SF3P (advanced-node production).

  **Pattern**: same as v1.9.0 (sky130) and v1.10.0 (tsmc_n5), mirrors
  `backend/cuda/compute.hexa` shape but for AI-native silicon axis
  (per-PDK area / freq / voltage table).

  **PDK metadata** (web-searched 2026-05-08):
    Samsung Foundry SF3P (3nm GAA MBCFET; world-first GAA production
    node, since late 2023; "Performance" variant of 3GAP family);
    EUV-multipatterned BEOL; Vcore 0.65V; freq band [2000, 2500] MHz;
    density ~22 M-gate/mm² (Samsung public ~178 M-tx/mm² disclosure;
    ~2.7x TSMC N5; ~44x SKY130);
    Samsung MPW shuttle ~$5-10M MOU + Korea fab partner (Hwaseong S5
    line) + IP audit gating.

  **AI-native primitive area placeholders** (canon §6 + hexa-chip §6 row "Samsung SF3P"):
    MAC array (σ²=144):   ~0.018 mm²    (dominant; ~2.7x shrink vs N5)
    prov_regfile:         ~0.0004 mm²
    promotion_counter_mmu:~0.00017 mm²
    bt_id_decoder:        ~0.000009 mm²
    TILE TOTAL:           ~0.0186 mm²
    chip (n_tiles=6):     ~0.111 mm²    (FITS Samsung MPW 4 mm² ceiling
                                          comfortably; ~215 tiles theoretical max)

  Surface: samsung_sf3p_{tile_area, chip_area, overhead_bp, freq_band, vcore_mv,
  fits_mpw_shuttle, max_tiles_in_mpw, module_meta, pdk_meta, invariant_*}.

  **Architectural guard** (canon §7.5 + roadmap §G.5): paper-spec only —
  NOT FFI to Synopsys DC / Cadence Genus / Innovus / ICC2 / Samsung
  proprietary tools. Real synthesis + P&R + tape-out is downstream
  scope; gated on Samsung Foundry PDK licence + Korea fab partner MOU +
  IP audit + ~$5-10M MPW slot.

  **Per-PDK split policy** completes from v1.9.0 / v1.10.0: 1 commit per
  PDK. Sequence done: SKY130 (v1.9.0 35b14035) → TSMC N5
  (v1.10.0 f11c560a) → Samsung SF3P (v1.11.0 — this iter).
  3-PDK ai_native paper backend set: **complete**.

  Korea-fab heritage tone (Samsung·SK·Hynix·DRAM/HBM lineage) is
  editorial framing only; no proprietary data, NDA content, or
  trade-secret material is included — only public foundry density /
  voltage disclosures.

  Phase G iter 9+3.

## [1.10.0] - 2026-05-08

### Added — `backend/ai_native/tsmc_n5.hexa` TSMC N5 PDK paper-tier backend (2nd PDK)
- `backend/ai_native/tsmc_n5.hexa` (~165 lines) — TSMC N5 5nm FinFET
  PDK silicon backend stub for the AI-native (Beyond-GPU) axis. Per-PDK
  paper-tier metadata (NO synthesis, NO P&R, NO tape-out).

  **Pattern**: same as v1.9.0 sky130.hexa, mirrors `backend/cuda/compute.hexa`
  shape but for AI-native silicon axis (per-PDK area / freq / voltage table).

  **PDK metadata** (web-searched 2026-05-08):
    TSMC N5 (5nm FinFET, EUV-multipatterned; production node since 2020);
    HD 6T standard cell; Vcore 0.75V; freq band [1500, 2000] MHz;
    density ~8 M-gate/mm² (~16x SKY130 from foundry public density
    disclosure ~173 M-tx/mm² Apple A14, gate-equiv ~22T/cell);
    TSMC MPW shuttle ~$3M MOU + foundry licence + IP audit gating.

  **AI-native primitive area placeholders** (canon §6 + hexa-chip §6 row "TSMC N5"):
    MAC array (σ²=144):   ~0.050 mm²    (dominant; 40x shrink vs SKY130)
    prov_regfile:         ~0.0011 mm²
    promotion_counter_mmu:~0.00045 mm²
    bt_id_decoder:        ~0.000025 mm²
    TILE TOTAL:           ~0.052 mm²
    chip (n_tiles=6):     ~0.31 mm²    (FITS TSMC MPW 5 mm² ceiling
                                          comfortably; ~96 tiles theoretical max)

  Surface: tsmc_n5_{tile_area, chip_area, overhead_bp, freq_band, vcore_mv,
  fits_mpw_shuttle, max_tiles_in_mpw, module_meta, pdk_meta, invariant_*}.

  **Architectural guard** (canon §7.5 + roadmap §G.5): paper-spec only —
  NOT FFI to Synopsys DC / Cadence Genus / Innovus / ICC2. Real synthesis
  + P&R + tape-out is downstream scope; gated on TSMC PDK licence +
  foundry MOU + IP audit + ~$3M MPW slot.

  **Per-PDK split policy** continues from v1.9.0: 1 commit per PDK.
  Sequence: SKY130 (v1.9.0 35b14035) → **TSMC N5 (v1.10.0 — this iter)**
  → Samsung SF3P (v1.11.0 next). Phase G iter 9+2.

## [1.9.0] - 2026-05-08

### Added — `backend/ai_native/sky130.hexa` SKY130 PDK paper-tier backend (1st PDK)
- `backend/ai_native/sky130.hexa` (~165 lines) — SkyWater SKY130 PDK
  silicon backend stub for the AI-native (Beyond-GPU) axis. Per-PDK
  paper-tier metadata (NO synthesis, NO P&R, NO tape-out).

  **Pattern**: mirrors `backend/cuda/compute.hexa` shape (per-vendor stub
  documenting API surface mapping) but for the AI-native silicon axis
  (per-PDK area / freq / voltage table, not per-vendor IR mapping).

  **PDK metadata** (web-searched 2026-05-08):
    SkyWater SKY130 (sky130A high-density library);
    130 nm bulk CMOS, 5-metal-layer standard option;
    Vcore 1.8V; freq band [200, 400] MHz typical;
    density ~0.5 M-gate/mm² (sky130_fd_sc_hd, ~50% post-P&R utilisation);
    Efabless MPW shuttle ~$25-50K, 6 mm² ceiling.

  **AI-native primitive area placeholders** (canon
  `analysis/btAI3_rtl_design.md` §6 + hexa-chip
  `ai_native_arch/doc/datasheet_ai_native_arch.md` §6 row "SKY130"):
    MAC array (σ²=144):  ~2.0 mm²    (dominant)
    prov_regfile:        ~0.042 mm²
    promotion_counter_mmu: ~0.018 mm²
    bt_id_decoder:       ~0.0009 mm²
    TILE TOTAL:          ~2.061 mm²
    chip (n_tiles=6):    ~12.37 mm²  (EXCEEDS Efabless 6 mm² ceiling;
                                       first MPW path: n_tiles=2 stripped chip)

  Surface (paper-tier; FFI to OpenLane2/Yosys/OpenROAD downstream):
    sky130_tile_area(block_id) -> int     (μ-mm², block 0..4)
    sky130_chip_area() -> int             (μ-mm²)
    sky130_overhead_bp() -> int           (= 278 bp, φ/σ_n = 1/36)
    sky130_freq_band() -> [int]
    sky130_vcore_mv() -> int
    sky130_fits_mpw_shuttle() -> bool     (false at n_tiles=6)
    sky130_max_tiles_in_mpw() -> int
    sky130_module_meta() / sky130_pdk_meta() -> [str]
    sky130_invariant_{n_tiles, overhead_bp, node_nm}() -> int

  **Architectural guard** (canon §7.5 + roadmap §G.5):
    paper-spec only — NOT FFI to SiliconCompiler / OpenLane2 / Yosys /
    OpenROAD. Real synthesis + P&R + tape-out is downstream scope.

  **Per-PDK split commit policy** (memory note from v1.7.0
  retrospective): v1.9.0+ adopts 1-commit-per-PDK split. SKY130 chosen
  first because it's the open-source PDK and Efabless MPW shuttle makes
  it the most actionable foundry candidate. v1.10.0 = TSMC N5;
  v1.11.0 = Samsung SF3P (per-PDK iteration sequence).

  Phase G iter 9+1; first PDK paper backend on the AI-native axis.

## [1.8.0] - 2026-05-08

### Added — `stdlib/hal/ai.hexa` host-side AI-native dispatch primitive
- `ai.hexa` (~155 lines) — host-side AI-native dispatch surface for
  the **Beyond-GPU** silicon-tier verb (hexa-chip Phase G iter 7).
  Mirror of `compute.hexa` shape (host-side dispatch primitive on a
  separate axis from the σ=12 embedded peripheral lattice), but for
  the provenance-aware AI accelerator class.

  **Lattice axis**: NOT σ=12 peripheral (gpio/i2c/...). NOT σ=12 GPGPU
  vendor × IR. AI-native is a **third axis**:
    σ=12 native MAC slots per tile (σ·φ = J₂ = 24 MAC/cycle)
    τ=4 pipeline stages
    φ=2 provenance kinds (FACT / HYPOTHESIS)
    σ_n=72 → provenance overhead φ/σ_n = 1/36
    n_tiles = σ/φ = 6 native tiles per HEXA-AI chip
    peak σ²·φ = 288 MAC/cycle
    bt_coverage = sopfr(n)+φ = 7 (BT_541..BT_547)

  **canon-aware** (`~/core/canon/domains/compute/ai-native-architecture/`):
    - 3 silicon primitives: provenance-bit (1-bit FACT/HYPOTHESIS,
      OR-propagated) / promotion-counter-MMU (write-barrier;
      (prov, grade) check) / bt-id-isa (3-bit ISA opcode field).
    - 4 falsifiers (F-AI1 / F-AI2-A / F-AI2-B / F-AI2c-A) + 3 RTL
      silicon-tier (F-AI3-A/B/C).

  Surface (paper-tier; FFI to silicon backend is downstream):
    ai_configure_tile(tile_id, threshold) -> int
    ai_dispatch_with_provenance(handle, prov_in, grade, bt_id) -> int
    ai_register_bt_audit(bt_id, callback_name) -> bool
    ai_query_refuse_count() -> int
    ai_clear_refuse_count() -> bool
    ai_set_threshold(tile_id, threshold) -> bool
    ai_peak_macs_per_cycle() -> int
    ai_module_meta() -> [str]
    ai_invariant_{n_tiles, macs_per_tile, macs_per_array, bt_coverage,
                  threshold_max, threshold_min}() -> int

  Constants exported:
    PROV_FACT / PROV_HYPOTHESIS                        (φ=2)
    THRESHOLD_MIN=4 / THRESHOLD_DEFAULT=8 / THRESHOLD_MAX=12  ([φ², σ])
    BT_RESERVED..BT_547                                (3-bit ISA field)
    STAGE_CONFIGURE / START / SERVE / REPORT           (τ=4)
    SIGMA / PHI / TAU / SIGMA_N / J2 / SOPFR_N         (n=6 axiom)
    N_TILES=6 / MACS_PER_TILE=24 / MACS_PER_ARRAY=288  (derived)
    BT_COVERAGE=7                                      (sopfr(n)+φ)
    DEFAULT_HANDLE_CEILING=4                            (J₂/n)

### First downstream consumer
hexa-chip `firmware/mcu/ai_native_host.hexa` (Phase G iter 6, commit
`9cff041`) currently uses `core+gpio+intr+timer+uart` directly with
TODO placeholders. Once this `ai.hexa` surface lands, the MCU host
will refactor to use `hal::ai::dispatch_with_provenance()` etc.

### F-HAL closure (no change)
This module is on a separate falsifier axis (F-AI* in canon ai-native-
architecture); it does NOT extend the F-HAL embedded peripheral
lattice. F-HAL closure stays at 67% × 5 (sat-1 ✓).

### Architectural guard reaffirmed
Per canon §7.5 + roadmap §F.6 + §G.5: **paper-spec only**, no FFI to
vendor silicon runtime. Silicon backend FFI (when it lands) lives
downstream of stdlib/hal — same architectural rule as compute.hexa
vendor backends (cuda/hip/sycl/...) and IR backends (spirv/ptx).

### Provenance
- canon SSOT: `~/core/canon/domains/compute/ai-native-architecture/
  ai-native-architecture.md` (1420 lines, parent omega-cycle 2026-04-26).
- canon RTL design notes: `analysis/btAI3_rtl_design.md` (264 lines).
- All 10 EXACT n=6 constants traceable to atlas line 526 / atlas master.

### Roadmap
- v1.9.0 candidate: `stdlib/hal/backend/ai_native/<vendor>.hexa` —
  per-foundry AI-native backend stubs (SKY130 / TSMC N5 / Samsung SF3P
  candidates per canon `target_pdk_candidates`). Paper-spec only;
  FFI/synthesis is downstream.
- v1.10.0 candidate: ESP32 family T3 scaffold (xtensa-esp-elf-gcc).
- v1.11.0 candidate: Renode 2026.x install + T3b2 run-tier.

## [1.7.0] - 2026-05-08

### Added — compute.hexa GPGPU σ=12 lattice fully populated (6 vendors)
- `backend/{cuda,hip,sycl,opencl,metal,webgpu}/compute.hexa` —
  paper-skeleton stubs for ALL 6 GPGPU vendor backends. Combined
  with the SPIR-V + PTX IR backends (v1.6.0 sibling commit), this
  fills the GPGPU σ=12 lattice (6 vendors × 2 IRs) defined in
  `~/core/canon/domains/compute/gpgpu/gpgpu.md`.

  Per-vendor details:
  - **cuda/compute.hexa** — NVIDIA CUDA 13.2 + NVRTC; libcuda.so +
    libnvrtc.so; PTX primary IR (sm_50 Maxwell → sm_120 Blackwell);
    `__syncwarp` / `__syncthreads` / `cluster.sync` (Hopper SM 9.0+) /
    `cooperative_groups::grid_group::sync`.
  - **hip/compute.hexa** — AMD HIP 7.2.53211 + HIPRTC; libamdhip64.so;
    AMDGCN primary IR (gfx900 Vega → gfx1201 RDNA4 / CDNA MI300);
    wavefront 64 (GCN) or 32 (RDNA WGP-mode).
  - **sycl/compute.hexa** — SYCL 2020 rev 11 (Intel oneAPI DPC++);
    libsycl.so; SPIR-V primary; cross-vendor (Intel Xe / Nvidia / AMD /
    CPU); `sub_group_size` is implementation-defined.
  - **opencl/compute.hexa** — OpenCL 3.1.0 (Khronos ICD loader);
    libOpenCL.so; SPIR-V via clCreateProgramWithIL (OpenCL 2.1+);
    cross-vendor (Intel/AMD/Nvidia/Apple/FPGA/DSP).
  - **metal/compute.hexa** — Apple Metal 4 (MSL 2025-10-23);
    Metal.framework; AIR primary (MSL → AIR via Apple compiler) +
    SPIR-V via SPIRV-Cross offline; Apple Silicon SIMD-group = 32.
  - **webgpu/compute.hexa** — WebGPU CR Draft (wgpu-native or Dawn);
    WGSL primary (browser-required) + SPIR-V via Tint (native only);
    cross-platform Vulkan/D3D12/Metal/OpenGL ES.

  Surface (mirrors `stdlib/hal/compute.hexa` sim):
    <vendor>_buffer_alloc(tier, n_bytes) -> int
    <vendor>_buffer_h2d / d2h / free
    <vendor>_kernel_compile(ir, n_bytes) -> int
    <vendor>_kernel_release(handle) -> bool
    <vendor>_dispatch(kern, gx, gy, gz, wx, wy, wz, scope, dep, sg_w) -> int
    <vendor>_event_wait / event_release

### GPGPU σ=12 lattice complete after v1.7.0
| vendor   | IR primary | runtime                       | tier ≤ device | scope ≤ grid     |
|:---------|:-----------|:------------------------------|:-------------:|:------------------|
| cuda     | PTX        | libcuda.so + libnvrtc.so      | ✓             | ✓ (CG grid_group) |
| hip      | AMDGCN     | libamdhip64.so + libhiprtc.so | ✓             | ✓ (CG)            |
| sycl     | SPIR-V     | libsycl.so (oneAPI DPC++)     | ✓             | partial (emul)    |
| opencl   | SPIR-V     | libOpenCL.so (Khronos ICD)    | ✓             | partial (emul)    |
| metal    | MSL → AIR  | Metal.framework               | ✓             | partial (emul)    |
| webgpu   | WGSL       | wgpu-native / Dawn / browser  | ✓             | partial (emul)    |

Cross-vendor barrier-scope coverage:
- SUBGROUP / WORKGROUP — natively supported by all 6 vendors (with
  varying SIMD/wavefront widths: 32 nominal, 64 on AMD GCN, 8/16/32
  on Intel SYCL).
- CLUSTER — native only on CUDA (Hopper SM 9.0+); emulated elsewhere.
- GRID — native via Cooperative Groups on CUDA + HIP; emulated as
  persistent kernel + atomic flag on SYCL/OpenCL/Metal/WebGPU.

### Changed
Total backend stub count for stdlib/hal:
- Embedded HW: 6 vendors × 12 σ-slots = 72 stubs (unchanged)
- GPGPU IR:    2 stubs (spirv + ptx; v1.6.0 sibling)
- GPGPU vendor: 6 stubs (this iter)
- **Total backend stubs: 80**

F-HAL closure unchanged at 67% × 5 (sat-1 ✓). compute.hexa is on
a separate falsifier axis (F-GPGPU-* TBD when GPGPU recipe lands).

### Provenance
- All 6 vendor versions web-search confirmed 2026-05-08 (per autonomy
  directive web-search mandate): CUDA 13.2, HIP 7.2.53211, SYCL 2020
  rev 11, OpenCL 3.1.0, Metal 4 (MSL 2025-10-23), WebGPU CR Draft.
- Cross-reference: `~/core/canon/domains/compute/gpgpu/gpgpu.md` §2-§5
  (vendor matrix + tier/scope mapping).

### Roadmap
- v1.8.0 candidate: ESP32 family T3 scaffold (xtensa-esp-elf-gcc) —
  first non-arm-none-eabi-gcc T3 path. Blocked: toolchain not in dev env.
- v1.9.0 candidate: Renode 2026.x install + T3b2 run-tier (lifts F-HAL T3 ✓).
- v1.10.0+: GPGPU compute.hexa T2 numerics (e.g. SAXPY benchmark
  fixture cross-vendor) — analog of HW-12 T2 for GPGPU axis.

## [1.6.0] - 2026-05-08

### Added — GPGPU IR backend skeletons (Phase F iter 9)

GPU IR substrate backends mirroring the per-vendor embedded backend pattern.
Outside the embedded σ=12 peripheral lattice — these target GPU IR consumers
of `stdlib/hal/compute.hexa` (host-side GPGPU dispatch primitive previously
landed under the prior versioning scheme; commit ba859275).

- `backend/spirv/compute.hexa` — SPIR-V GPU IR backend (paper skeleton).
  φ=0 (digital) IR substrate. Validation only; spirv-tools / spirv-val /
  spirv-opt FFI is downstream.

  Constants:
    SPIRV_MAGIC = 0x07230203
    SPIRV_HEADER_WORDS = 5
    SPIRV_VERSION_{1_0..1_6}, SPIRV_VERSION_MIN/MAX
    SPIRV_SC_{UNIFORM_CONSTANT, INPUT, UNIFORM, OUTPUT, WORKGROUP,
              CROSS_WORKGROUP, PRIVATE, FUNCTION, PUSH_CONSTANT,
              STORAGE_BUFFER}  (10-class subset mapped to τ=4)

  Surface:
    spirv_validate_magic(first_word: int) -> bool
    spirv_validate_version(version_word: int) -> bool
    spirv_validate_header(words: [int]) -> bool   (5-word header)
    spirv_storage_class_to_tier(sc: int) -> int   (-1 if unmapped)
    spirv_meta() -> [str]                         ([name, ver, magic, count])

  Storage class → τ-tier mapping (canon §4.2 alignment):
    Private/Function       → TIER_PRIVATE
    Workgroup              → TIER_GROUP
    CrossWorkgroup/Storage/Input/Output → TIER_DEVICE
    UniformConstant/Uniform/PushConstant → TIER_CONSTANT

  Web-search 2026-05-08: SPIR-V 1.6 current; consumed by SYCL 2020 rev 11,
  OpenCL 3.1.0, WebGPU (via Tint), HIP (via translator), Metal (via translator).

- `backend/ptx/compute.hexa` — NVIDIA PTX GPU IR backend (paper skeleton).
  φ=1 IR substrate. Validation only on PTX assembly strings; LLVM nvptx +
  ptxas FFI is downstream.

  Constants:
    PTX_VERSION_MAJOR = 8 / MINOR = 5     (lock-step with CUDA 13.2)
    PTX_TARGET_DEFAULT = "sm_90"          (Hopper baseline, CC ≥ 9.0 cluster)
    PTX_TARGET_LATEST  = "sm_100"         (Blackwell top end 2026-05-08)
    PTX_SS_{REG, LOCAL, SHARED, GLOBAL, PARAM, CONST}  (6 state spaces)

  Surface:
    ptx_validate_directive_header(s: str) -> bool   (.version + .target present)
    ptx_state_space_to_tier(name: str) -> int       (-1 if unmapped)
    ptx_warp_size() -> int                          (= 32, sm_75+ baseline)
    ptx_meta() -> [str]                             ([name, ver, target, count])

  State space → τ-tier mapping:
    .reg / .local           → TIER_PRIVATE
    .shared                 → TIER_GROUP
    .global / .param        → TIER_DEVICE
    .const                  → TIER_CONSTANT

  Web-search 2026-05-08: PTX 8.5 in lock-step with CUDA Toolkit 13.2
  (Programming Guide release 2026-03-04). Hopper sm_90 = thread-block
  cluster baseline; Blackwell sm_100 = current top end.

### Cross-link

Phase F iter 9 of hexa-chip GPGPU verb. canon SSOT:
`~/core/canon/domains/compute/gpgpu/gpgpu.md` @47c70cbf.
First consumer of these IR backends will be `stdlib/hal/compute.hexa`'s
`compute_kernel_compile()` once codegen FFI lands (separate iter, downstream).

## [1.5.0] - 2026-05-08

(v1.4.0 — T3b2 run-tier — deferred: Renode 2026.x not in current dev
env; brew has no formula. v1.5.0 picks up stm32h7 T3 scaffold +
compile-tier; doesn't depend on Renode.)

### Added — STM32H7 T3 scaffold + compile-tier (LIVE)
- `t3/Makefile.stm32h7`             — arm-none-eabi-gcc → Cortex-M7
                                       + FPv5-D16 hard-float.
- `t3/linker_stm32h7.ld`            — STM32H7 memory map per RM0433
                                       §2.4: FLASH 0x08000000 / 2 MB
                                       + ITCMRAM + DTCMRAM (stack
                                       here) + AXI SRAM + SRAM_D2/D3.
- `t3/boot_stm32h7.s`               — ARMv7-M reset handler with
                                       SCB_CPACR FPU enable (CP10+11
                                       full access; dsb/isb fence).
- `t3/harness_stm32h7_main.c`       — Nucleo-H743 harness: PB0 LED
                                       toggle 5x via BSRR atomic;
                                       USART3 sentinel
                                       __T3_STM32H7__ PASS gpio_toggle_5x_observed.
- `t3/numerics_t3_stm32h7_compile.hexa` — T3b1 numerical check;
                                       live-runs make + objdump + nm.

Verified live: `make` succeeds; `.text` @ 0x08000000, 1372 bytes;
boot symbols at expected offsets (_vector_table 0x08000000,
_reset_handler 0x08000400, harness_main 0x08000480, _stack_top
0x20020000 = top of 128K DTCMRAM).

### T3 vendor coverage at v1.5.0
| vendor   | CPU                  | T3a | T3b1 | T3b2  |
|:---------|:---------------------|:---:|:----:|:------|
| rp2040   | Cortex-M0+           | ✓   | ✓    | ☐     |
| stm32h7  | Cortex-M7 + FPv5-D16 | ✓   | ✓    | ☐     |

Same arm-none-eabi-gcc 16.1.0 toolchain across both vendors. The
ARMv6-M → ARMv7-M shift is handled entirely via:
1. `-mcpu / -mfpu / -mfloat-abi` flag triplet
2. linker.ld memory regions (FLASH 0x08000000 vs 0x10000000)
3. boot.s vector table size + FPU enable (M7 only)
4. harness_main.c peripheral MMIO addresses

No shared-toolchain hacks needed — scaffold model is portable.

### Updated
- `t3/README.md` — file layout reorganized for both vendor groups;
  v1.5.0 vendor coverage table added.

### Recipe-aligned closure (no F-HAL change)
F-HAL closure stays at **67% × 5 (sat-1 ✓)**. v1.5.0 doubles
compile-tier vendor count (rp2040 → +stm32h7) as evidence the model
generalizes; remaining gap is Renode (or hardware), not toolchain.

### Roadmap
- v1.6.0+: install Renode 2026.x (upstream .dmg/.pkg, not homebrew);
  run both harnesses; capture sentinels. Lifts F-HAL T3 ✓.
- v1.7.0+: ESP32 family T3 scaffold (xtensa-esp-elf-gcc — first
  non-arm-none-eabi-gcc T3 path).

## [1.3.0] - 2026-05-08

### Added
- `t3/numerics_t3_rp2040_compile.hexa` — **T3b1 (compile-tier)**
  numerical script. Live-runs the `make -f Makefile.rp2040` recipe
  via the local `arm-none-eabi-gcc` toolchain, then asserts the
  produced `t3_harness.elf` matches the ARMv6-M layout documented
  in `linker_rp2040.ld` and `boot_rp2040.s`. **First T3 sub-tier
  to actually invoke a real toolchain** (vs T3a which is paper-only).
- `t3/.gitignore` — excludes `*.o` / `*.elf` / `*.bin` / `*.uf2` /
  `*.log` (build artifacts + run logs are regenerable).

### Changed
- `t3/harness_main.c` — replaced `#include <stdint.h>` with manual
  integer typedefs (`uint8_t` / `uint16_t` / `uint32_t` / `uint64_t`).
  This removes the libc dependency and enables a fully `-nostdlib`
  cross-compile against bare arm-none-eabi-gcc (no newlib required).
- `t3/README.md` — T3 sub-tier model expanded from 2 (T3a/T3b) to
  3 (T3a / T3b1 compile / T3b2 run); v1.3.0 status block added.

### T3 sub-tier table at v1.3.0
| sub-tier | what it verifies                                    | status      |
|:--------|:----------------------------------------------------|:------------|
| T3a     | scaffold files exist on disk + sentinel string in C | ✓ (v1.2.0)  |
| T3b1    | arm-none-eabi-gcc actually builds → valid ARMv6-M ELF | ✓ (v1.3.0) |
| T3b2    | Renode runs ELF + UART log shows sentinel           | ☐ deferred  |

Local verification (this commit, 2026-05-08):
- arm-none-eabi-gcc 16.1.0 (homebrew, /opt/homebrew/bin/arm-none-eabi-gcc).
- `make -f Makefile.rp2040 t3_harness.elf` succeeds cleanly.
- ELF inspection (`arm-none-eabi-objdump -h`):
  - `.text` @ 0x10000000 (FLASH XIP), 420 bytes (0x1A4).
  - `.data` and `.bss` empty (no initialized/zero-init globals).
- ELF symbols (`arm-none-eabi-nm`):
  - `_vector_table`  @ 0x10000000
  - `_reset_handler` @ 0x10000080
  - `harness_main`   @ 0x100000f0
  - `_stack_top`     @ 0x20040000 (top of 256K SRAM)

### Recipe-aligned closure (no F-HAL change)
T3b1 compile-tier landing does NOT lift any `F<n>_T3` to ✓ in
`falsifier_check.hexa`. Per recipe §3, F-HAL T3 closure requires
T3b2 (run-tier — Renode log shows sentinel). v1.3.0 is "scaffold
proven buildable against a real toolchain; run-tier still pending".

F-HAL closure stays at **67% × 5 (sat-1 ✓)** until v1.4.0+ activates
Renode and captures the UART sentinel.

### Why split T3b into compile + run?
The original T3 spec was binary (paper vs HW-bench). After landing
T3a, the next concrete step turned out to have two distinct
verifiable phases:
1. *Does the scaffold actually compile?* — answerable with just
   arm-none-eabi-gcc; tests scaffold correctness, linker-script
   consistency, ABI compatibility (Cortex-M0+ vs M7).
2. *Does the binary actually run as documented?* — answerable only
   with an emulator (Renode) or physical board.

Splitting these gives the agent a stepping-stone proof that the
scaffold is more than just text on disk. Compile-tier alone would
catch broken Makefiles, mis-aligned vector tables, or symbol-name
typos — all real failure modes that T3a (file-presence only) cannot
catch.

### Provenance
- arm-none-eabi-gcc 16.1.0 from homebrew (`brew install
  arm-none-eabi-gcc`).
- ARMv6-M ABI per ARM ARM (DDI 0419E).
- Build verified live; no mocking.

### Roadmap
- v1.4.0: T3b2 run-tier — install Renode 2026.x, run the harness,
  capture UART log, write `numerics_t3_rp2040_renode.hexa`. THIS
  finally lifts F<n>_T3 ✓ for whichever falsifier the harness
  exercises (likely F-HAL-1 — module-presence verifiable from
  symbol table).

## [1.2.0] - 2026-05-08

### Added
- `stdlib/hal/t3/` — T3 (HW-bench) tier **scaffold** for the rp2040
  cross-compile harness. v1.2.0 lands the scaffold-tier (T3a) only;
  the run-tier (T3b) — actual Renode emulation + UART log capture —
  is gated on dev-env availability of arm-none-eabi-gcc + Renode and
  scheduled for v1.3.0+.

  T3 is the third closure tier (per recipe §3): T1 algebraic, T2
  numerical / on-disk fixture, **T3 HW-bench** (actual code execution
  against documented MMIO behavior). Lifting F-HAL closure 67% → 100%
  requires T3 ✓ for each falsifier.

  Files added:
  - `t3/README.md` — T3 tier philosophy + roadmap (T3a scaffold-tier
    vs T3b run-tier split); rp2040 chosen as first vendor (open
    toolchain, no NDA, Renode upstream support since 2024).
  - `t3/Makefile.rp2040` — arm-none-eabi-gcc cross-compile recipe
    targeting Cortex-M0+; produces `t3_harness.elf` (and `.uf2` via
    pico-sdk elf2uf2 for physical Pico flash, deferred).
  - `t3/linker_rp2040.ld` — minimal ARMv6-M linker script declaring
    FLASH @ 0x10000000 / 2 MB (XIP) + RAM @ 0x20000000 / 256 KB (6
    striped banks) + scratch X/Y; ENTRY(_reset_handler).
  - `t3/boot_rp2040.s` — ARMv6-M vector table + reset handler:
    sets MSP, copies .data from FLASH to RAM, zeros .bss, calls
    `harness_main()`. Cortex-M0+ specific (no Thumb-2; no nested IT).
  - `t3/harness_main.c` — minimal harness exercising
    `stdlib/hal/backend/rp2040/{gpio,uart}.hexa` MMIO contracts:
    configures GP25 as output (Pico LED), toggles 5 times, emits
    UART0 sentinel `__T3_RP2040__ PASS gpio_toggle_5x_observed`.
    Written in C because hexa-lang ARMv6-M backend doesn't exist
    yet (will convert to `harness_main.hexa` once it does).
  - `t3/renode_rp2040.resc` — Renode 2024.10+ platform script:
    loads `t3_harness.elf` onto rp2040, attaches UART0 to
    TerminalAnalyzer, redirects to `t3_rp2040_run.log`, runs for
    5000 ms simulated time then quits.
  - `t3/numerics_t3_rp2040_scaffold.hexa` — T3a scaffold-tier
    verification script. Asserts:
      1. all 6 scaffold files present on disk
      2. harness_main.c contains the T3 sentinel string
      3. Makefile targets `arm-none-eabi-` + `cortex-m0plus`
      4. linker_rp2040.ld declares FLASH @ 0x10000000 + RAM @ 0x20000000
      5. boot_rp2040.s declares .thumb + cortex-m0plus + _reset_handler
      6. Renode .resc declares LoadELF + uart0 + logFile

### T3 closure semantics (recipe-aligned)
Per recipe §3 closure_pct, T3 ✓ requires actual run-tier verification
(T3b — Renode log shows expected sentinel). The T3a scaffold-tier
script lands in v1.2.0 as a **precondition** but does NOT lift any
F<n>_T3 entry to ✓ in `falsifier_check.hexa`. Falsifier closure stays
at **67% × 5 (sat-1 ✓)** until v1.3.0+ when T3b run-tier activates.

This split is intentional: scaffold-tier proves the path is
**buildable on paper**; run-tier proves it's **executable in reality**.
Conflating them would falsely claim closure on un-executed code.

### Build flow (paper-tier; not yet executed)
```bash
make -f Makefile.rp2040 t3_harness.elf
renode -e "include @t3/renode_rp2040.resc; start" \
       --console-log t3_rp2040_run.log
grep -E "__T3_RP2040__ PASS" t3_rp2040_run.log
```

### Provenance
- RP2040 register addresses (SIO 0xD0000000, UART0 0x40034000) match
  `backend/rp2040/{gpio,uart}.hexa` v0.4.0+ documentation.
- ARMv6-M boot flow per ARM ARMv6-M Architecture Reference Manual
  (DDI 0419E) §B1.5.1.
- Renode rp2040 platform spec from upstream Renode 2024.10+.

### Roadmap
- v1.3.0: T3b run-tier — invoke arm-none-eabi-gcc + Renode in CI
  (or a one-off run); capture UART log; add
  `numerics_t3_rp2040_renode.hexa` that asserts log contains sentinel.
  THIS lifts F-HAL-1 (or whichever falsifier the harness is wired to)
  closure 67% → 100%.
- v1.4.0+: replicate T3 scaffold for stm32h7 (`Makefile.stm32h7` +
  `boot_stm32h7.s` + Renode platform); progressively add per-vendor
  T3 paths.

## [1.1.0] - 2026-05-08

### Added
- `backend/esp32c6/{core,gpio,i2c,spi,uart,adc,dac,pwm,timer,intr,dma,rtc}.hexa`
  — **6th vendor**, full HW-12 in a single iter. Espressif ESP32-C6
  RV32IMAC RISC-V single-core @ 160 MHz + LP_CPU (low-power RISC-V
  coprocessor) + WiFi 6 (802.11ax) + BLE 5.0 + 802.15.4 (Zigbee /
  Thread / Matter). 12 paper-skeleton stubs maintain the HW-12
  invariant.

  Per-stub highlights (RV32IMAC vs RV32IMC C3 — Atomic ext added):
  - `core.hexa`  — HP_CPU + LP_CPU (vs C3's single CPU); LP_RTC moved
                   to dedicated LP_AONCLKRST block @ 0x600B0000.
  - `gpio.hexa`  — DR_REG_GPIO_BASE 0x60091000 (moved vs C3 0x60004000);
                   31-pin envelope (GPIO0..GPIO30); GPIO0..7 are
                   **LP_GPIO** (accessible via LP controller during deep
                   sleep — new on C6).
  - `i2c.hexa`   — HP I2C @ 0x60004000 + **LP I2C @ 0x600B1000** (new
                   on C6; LP_APB domain — sensor reads w/o HP wake).
  - `spi.hexa`   — single GP-SPI (SPI2) @ 0x60080000; AES-128 HW-accel
                   for encrypted SPI flash.
  - `uart.hexa`  — HP UART0 @ 0x60000000 + UART1 + **LP UART0 @
                   0x600B1400** (new on C6; wake HP on RX threshold).
  - `adc.hexa`   — APB_SARADC @ 0x6000E000; **single ADC1 with 7
                   channels** (GPIO0..6); no ADC2 (simplification vs
                   C3's 5+1).
  - `dac.hexa`   — no native DAC; LEDC-emulation (same as C3/S3).
  - `pwm.hexa`   — LEDC @ 0x60007000; 6 channels × 4 timers.
  - `timer.hexa` — TIMG0/1 @ 0x6000A000/0x6000B000; 2 × 54-bit GP
                   timers; SYSTIMER @ 0x60023000 (52-bit, 16 MHz).
  - `intr.hexa`  — **PLIC-compatible programming model** (HP_INTPRI @
                   0x600C5000; PLIC_MX @ 0x20001000) — distinct from
                   both C3's custom matrix AND vanilla RISC-V PLIC.
                   First PLIC-class controller in stdlib/hal.
  - `dma.hexa`   — GDMA @ 0x60080800; 3 RX/TX pairs (same as C3 family).
  - `rtc.hexa`   — LP_RTC @ 0x600B0000 + LP_TIMER @ 0x600B0C00;
                   counter-class (NOT calendar); LP_CPU coprocessor
                   access during sleep (extends S3's ULP-RISC-V pattern).

### Changed
- `numerics_sim_marker_density.hexa` `CANONICAL_VENDORS` extended to 6
  entries: + esp32c6. Expected backend stub count: 5 × 12 = 60 → 6 × 12 = **72**.
- v1.1.0 vendor list: stm32h7, rp2040, esp32, esp32c3, esp32s3, **esp32c6**.

### CPU class diversity at v1.1.0
- ARM Cortex-M7 (stm32h7)
- ARM Cortex-M0+ (rp2040)
- Xtensa LX6 (esp32)
- Xtensa LX7 + ULP-RISC-V (esp32s3)
- RISC-V RV32IMC (esp32c3)
- **RISC-V RV32IMAC (esp32c6)** ← new (Atomic ext) + HP/LP_CPU split
- 6 distinct CPU classes / 4 ISAs (ARM × 2, Xtensa × 2, RISC-V × 2 variants).

### ESP32-C6 distinctive features (vs C3)
1. **LP domain peripherals**: LP_I2C, LP_UART, LP_GPIO 0..7, LP_RTC,
   LP_TIMER — all accessible during deep sleep without waking HP_CPU.
2. **WiFi 6** (802.11ax) + **802.15.4** (Zigbee / Thread / Matter) +
   BLE 5.0 — first stdlib/hal vendor with 802.15.4.
3. **PLIC-compatible interrupt model** — first vendor with standard-RV-
   adjacent interrupt controller (vs C3's custom matrix).
4. **HP_APB / LP_APB peripheral split** — most peripheral base addresses
   moved compared to C3.

### Provenance
- ESP32-C6 register layout from ESP32-C6 TRM v1.2 (web-search
  confirmed RV32IMAC; GPIO base + LP_RTC moved to LP_AON region).
- Same web-search mandate per autonomy directive memory.

### Roadmap
- v1.2.0: T3 MMIO cross-compile harness (rp2040 + Renode emulation).
- v1.3.0: compute.hexa first vendor backend (CUDA / WebGPU).
- v1.4.0+: additional sub-vendors (esp32c2 / esp32h2 / esp32p4).

## [1.0.0] - 2026-05-08 — ★ MILESTONE RELEASE ★

### Tagged
After 16 incremental releases (v0.0.1 → v0.15.0) reached **HW-12 /
100% per-vendor paper-tier coverage** in v0.15.0, this release tags
the milestone as the formal v1.0.0:

- **5 vendors × 12 σ-slots = 60 backend stub files** (all paper-tier;
  no HW physically tested).
- **5 distinct CPU classes** (ARM Cortex-M7, Cortex-M0+, Xtensa LX6,
  Xtensa LX7, RISC-V RV32IMC) unified behind one peripheral surface.
- **sat-1 ✓** (every F-HAL falsifier ≥ 67%; reached v0.3.0).
- **sat-2 ✓** (every F-HAL has ≥ 1 T1 script; reached v0.1.0).
- **sat-3 ✗** — T3 HW-bench tier deferred to v2.0.0 (requires cross-
  compile + emulation harness).
- Plus separate axis: `compute.hexa` GPGPU host primitive (added v0.13.0;
  6 vendors × 2 IRs × τ=4 × φ=2 × J₂′=48 lattice; vendor backends to come).

### Added
- `RELEASE_NOTES.md` — full v1.0.0 milestone summary including the
  60-stub coverage matrix, CPU class diversity, falsifier closure
  table, full release sequence (v0.0.1 → v1.0.0), and roadmap
  post-v1.0.0 (esp32c6 sub-vendor, T3 cross-compile harness,
  compute.hexa first vendor backend).
- `README.md` updated with v1.0.0 status callout, full per-vendor
  matrix table, GPGPU axis section, and provenance notes including
  the v1.0.0 milestone.

### Changed
- README "Hardware backends" section restructured from per-vendor
  bulleted list to a 5-row × HW-12 coverage table.
- Module-version in CHANGELOG header bumps from [0.15.0] → [1.0.0].

### Roadmap (post-milestone)
- v1.1.0 — esp32c6 sub-vendor (RV32IMAC, WiFi 6 / Zigbee / Thread /
  Matter); 6th vendor + 2nd RISC-V variant; 12 stubs to maintain HW-12.
- v1.2.0 — T3 MMIO cross-compile harness (rp2040 open toolchain +
  Renode emulation); lifts F-HAL closure 67% → 100% for that vendor.
- v1.3.0 — compute.hexa first vendor backend (CUDA / WebGPU); begins
  filling GPGPU σ=12 lattice.

## [0.15.0] - 2026-05-08 — **HW-12 / 100% per-vendor coverage milestone**

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/core.hexa` —
  σ-slot 0 (core: runtime · panic · time · critical-section · cache)
  HW-backend stubs across ALL 5 vendors. **Final per-vendor peripheral
  gap closed**; per-vendor coverage now 12/12 = 100% across all 5
  vendors. Total embedded backend stub count: 55 → 60.

  This iter spans 4 distinct CPU-level architectures (each with its
  own special-register / CSR / SR / SCB convention):

  - **stm32h7/core.hexa** — ARM Cortex-M7 with FPU + L1 cache
    (16 KB I + 16 KB D). System Control Block at architectural
    0xE000ED00 (CPUID/VTOR/AIRCR/SCR/CCR); DWT_CYCCNT @ 0xE0001004
    for sub-µs cycle timing; cache mgmt via SCB_ICIALLU + DCISW
    set/way; reset via SCB_AIRCR.SYSRESETREQ (key 0x05FA).
    Critical section: CPSID i / MSR PRIMASK.

  - **rp2040/core.hexa** — ARM Cortex-M0+ NO cache / NO FPU / NO MPU.
    Same SCB layout but simpler. NO DWT cycle counter — uses RP2040
    TIMER block (0x40054000, 64-bit µs) for now_us. RESETS @
    0x4000C000 + WATCHDOG @ 0x40058000 (preferred reset path,
    preserves SCRATCH boot reason). 8 × 32-bit WATCHDOG_SCRATCHn
    survive reset.

  - **esp32/core.hexa** — Xtensa LX6 dual-core @ 240 MHz with FPU +
    32 KB I-cache + 32 KB D-cache. Special registers via RSR/WSR
    opcodes: CCOUNT (cycle ctr) / CCOMPARE0..2 (timer compares) /
    INTENABLE / INTERRUPT / INTCLEAR / PS (intlevel). Critical
    section via RSIL <new_level> (atomic raise + return prior).
    Cache mgmt via DPORT_PRO_CACHE_CTRL_REG @ 0x3FF00000. Reset
    via RTC_CNTL_OPTIONS0_REG.SW_SYS_RST.

  - **esp32c3/core.hexa** — RV32IMC RISC-V single-core @ 160 MHz NO FPU.
    Standard RV CSRs (mhartid/mstatus/mie/mtvec/mcycle/mcycleh).
    Critical section via csrrci mstatus, 0x8 (clear MIE, return prior).
    Sleep via wfi (RISC-V wait-for-interrupt). Cache via EXT_MEM @
    0x600C4000 (16 KB I + 16 KB D). SYSTIMER block @ 0x60023000 for
    long-term µs (52-bit @ 16 MHz).

  - **esp32s3/core.hexa** — Xtensa LX7 dual-core @ 240 MHz + ULP-
    RISC-V coprocessor + **PIE (Processor Instruction Extension)** —
    128-bit vector ops (Q0..Q7 registers) for FFT / CNN inference.
    Same SR set as LX6 (CCOUNT/CCOMPARE0..2/INTENABLE/PS). Cache
    layout DISTINCT from C3: EXTMEM_DCACHE_PRELOAD_* + AUTOLOAD_* +
    TAG_POWER_*; supports cache_clean (writeback) separately from
    invalidate for PSRAM-DMA coherency. PSRAM @ 0x3C000000..0x3FFFFFFF
    (up to 32 MB).

  Surface (mirrors `stdlib/hal/core.hexa` sim):
    core_now_us() -> int
    core_sleep_us(us: int)
    core_panic(msg: str)
    core_critical_enter() -> int     (returns prior IRQ mask)
    core_critical_exit(prior: int)
    core_cache_invalidate() -> bool  (where applicable)
    core_cache_clean() -> bool       (esp32s3 + stm32h7 only)
    core_reset()

### MILESTONE: HW-12 = 100% per-vendor coverage

After v0.15.0, every registered vendor (stm32h7 / rp2040 / esp32 /
esp32c3 / esp32s3) has paper-skeleton stubs for ALL 12 σ-slots:

  σ=0  core    σ=1  gpio    σ=2  i2c    σ=3  spi
  σ=4  uart    σ=5  adc     σ=6  dac    σ=7  pwm
  σ=8  timer   σ=9  intr    σ=10 dma    σ=11 rtc

Total 5 × 12 = **60 embedded backend stub files** in
`stdlib/hal/backend/<vendor>/<peripheral>.hexa`.

ISA family + variant coverage at v0.15.0:
  - ARM Cortex-M7 (stm32h7) — FPU + cache + MPU + DSP-extensions
  - ARM Cortex-M0+ (rp2040) — minimal: no cache / no FPU / no MPU
  - Xtensa LX6 (esp32) — FPU + cache + dual-core
  - Xtensa LX7 (esp32s3) — FPU + cache + dual-core + ULP-RISC-V
                            coprocessor + PIE 128-bit vector ops
  - RISC-V RV32IMC (esp32c3) — no FPU + cache, single-core

5 distinct CPU classes, 4 ISAs (ARM × 2, Xtensa × 2, RISC-V × 1),
unified behind one stdlib/hal surface.

### Changed
- HW-backend stub file count: 55 → 60 (5 vendors × 12 peripherals).
- Per-vendor coverage: 11/12 → 12/12 = **100%** across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓ holds).

### Provenance
- STM32H7 SCB / DWT / cache from RM0433 §11.4-5 + Cortex-M7 TRM.
- RP2040 SCB / TIMER / WATCHDOG from RP2040 Datasheet §2.6/2.8/4.6.
- ESP32 LX6 SR set from ESP32 TRM §3 + Xtensa LX6 ISA Reference §4.7.
- ESP32-C3 RV CSRs + EXT_MEM from ESP32-C3 TRM §11 + RISC-V Privileged ISA.
- ESP32-S3 LX7 + PIE + EXT_MEM from ESP32-S3 TRM §11 + Xtensa LX7 ISA.

### Roadmap (post-12/12 milestone)
- v1.0.0 release candidate: full HW-12 + sat-1 + multi-ISA validated +
  GPGPU axis (compute.hexa from v0.13.0). Tag the milestone.
- v0.16.0+ — esp32c6 sub-vendor (WiFi 6 / Zigbee / Thread / Matter,
  RV32IMAC) for **6th vendor** + 2nd RISC-V variant (different intr ctrl).
- T3 tier — actual MMIO cross-compile harness (Cortex-M0+/M7 binary
  out + Renode emulation OR QEMU + DAP debug). Lifts F-HAL closure
  from 67% × 5 → 100% × 5.
- compute.hexa first vendor backend (CUDA / WebGPU) — fills GPGPU
  σ=12 lattice.

## [0.14.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/rtc.hexa` —
  σ-slot 11 (rtc) HW-backend stubs across ALL 5 vendors. Per-vendor
  coverage 10/12 → 11/12. Total embedded backend stub count: 50 → 55
  (compute.hexa from v0.13.0 is on a separate axis, not counted here).

  3 distinct RTC architectural patterns:
  - **STM32H7 calendar RTC** (stm32h7/rtc.hexa) — full hardware
    calendar IP at 0x58004000 (D3 / VBAT domain): TR + DR registers
    with BCD-encoded year/month/day/hour/min/sec; 2 alarms (A/B);
    wakeup timer; 32 × 32-bit backup registers; tamper detection;
    LSE 32.768 kHz / 128 / 256 = 1 Hz baseline. Lock/unlock via WPR
    key sequence (0xCA, 0x53). Survives main reset.
  - **RP2040 calendar RTC** (rp2040/rtc.hexa) — single instance at
    0x4005C000 with calendar (year/month/day/dotw/hour/min/sec) +
    1 match alarm + IRQ output. Programmable CLK_RTC source (typ
    XOSC=12 MHz / 256 = 46875 Hz, then /M to 1 Hz internally). Setup
    requires CTRL.RTC_ENABLE=0 → write SETUP_0/1 → CTRL.LOAD pulse.
  - **ESP32 family counter RTC** (esp32/, esp32c3/, esp32s3/rtc.hexa)
    — 48-bit free-running counter at RTC_CNTL block; **NOT a calendar
    IP**. Calendar arithmetic happens in software using epoch_base
    stored in RTC_CNTL_STOREn regs. Slow-clock sources: 150 kHz
    internal RC (default ±5%) / 32.768 kHz XTAL32K / 8 MHz ÷ 256.
    Per-variant differences:
      - esp32:    base 0x3FF48000 (DPORT region); 4 STOREn regs.
      - esp32c3:  base 0x60008000 (peri region 0x6000); 4 STOREn regs.
      - esp32s3:  base 0x60008000; **8 STOREn regs** + **ULP-RISC-V
                  coprocessor** in RTC domain (8 KB SLOW_MEM for
                  sleep-time RV firmware).
    Register OFFSETS within RTC_CNTL also shifted between ESP32
    (0x010/0x014/0x018) and ESP32-C3/S3 (0x0AC/0x0B0/0x0B4) — stubs
    reflect per-variant offset changes.

  Surface (mirrors `stdlib/hal/rtc.hexa` sim):
    rtc_configure(idx) -> int          (idx ≤ 3)
    rtc_start(handle) -> bool
    rtc_set_time(handle, y, m, d, h, mi, s) -> bool
    rtc_get_time(handle) -> str
    rtc_set_alarm(handle, h, m, s) -> bool
    rtc_clear(handle) -> bool
    rtc_report(handle) -> str

### Architecture observation: calendar IP vs counter IP
- **Calendar-class RTCs** (STM32H7 / RP2040): hardware decodes BCD
  fields directly; firmware reads y/m/d/h/m/s registers; mature MCU
  vendor pattern.
- **Counter-class RTCs** (ESP32 family): hardware just counts ticks;
  software synthesizes calendar via epoch_base + counter*period.
  Trade-off: simpler hardware (less silicon area in RTC domain) at
  the cost of ~1 KB of firmware code for calendar conversion.
- The unified `stdlib/hal/rtc.hexa` surface hides this distinction
  behind set_time / get_time wrappers.

### Changed
- HW-backend stub file count: 50 → 55 (5 vendors × 11 peripherals).
- Per-vendor coverage: 10/12 → 11/12 across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓).

### Provenance
- STM32H7 RTC 0x58004000 from RM0433 §51.
- RP2040 RTC 0x4005C000 from RP2040 Datasheet §4.8.
- ESP32 RTC_CNTL 0x3FF48000 from ESP32 TRM §28.
- ESP32-C3 RTC_CNTL 0x60008000 from ESP32-C3 TRM §10.
- ESP32-S3 RTC_CNTL 0x60008000 from ESP32-S3 TRM §10.

### Roadmap
- v0.15.0 (next, final per-vendor): **core (σ-slot 0)** — last gap
  to reach **12/12 = 100%** per-vendor HW coverage. CPU-level cache
  management / sleep modes / clock tree configuration.
- v1.0.0 milestone candidate: full HW-12 across 5 vendors + sat-1
  + multi-ISA-family validated (ARM M7 / M0+ / Xtensa LX6 / LX7 /
  RISC-V) + GPGPU axis (compute.hexa).

## [0.13.0] - 2026-05-08

### Added
- `compute.hexa` — host-side GPGPU dispatch primitive. **Outside the
  embedded σ=12 peripheral lattice** — GPGPU is a separate axis with its
  own n=6 invariant (σ=12 = 6 vendors × 2 IR substrates · τ=4 lifecycle
  · φ=2 mode · J₂′=48). Canon SSOT:
  `~/core/canon/domains/compute/gpgpu/gpgpu.md` @47c70cbf (2026-05-08).

  Surface:
    compute_buffer_alloc(tier, n_bytes) -> int    (TIER_PRIVATE/GROUP/DEVICE/CONSTANT)
    compute_buffer_h2d / d2h / free
    compute_kernel_compile(ir, n_bytes) -> int    (IR_SPIRV ‖ IR_PTX)
    compute_kernel_release(handle) -> bool
    compute_dispatch(vendor, kern, grid_xyz, wg_xyz, scope, dep, sg_w) -> event
    compute_event_wait(event) -> bool
    compute_event_release(event) -> bool

  Constants:
    TIER_{PRIVATE, GROUP, DEVICE, CONSTANT}      (τ=4)
    SCOPE_{SUBGROUP, WORKGROUP, CLUSTER, GRID}   (4 barrier scopes)
    IR_{SPIRV, PTX}                              (φ=2)
    VENDOR_{CUDA, HIP, SYCL, OPENCL, METAL, WEBGPU}  (6 backends)

  Invariant ledger:
    compute_invariant_axes()      -> 6
    compute_invariant_tiers()     -> 4
    compute_invariant_irs()       -> 2
    compute_invariant_vendors()   -> 6
    compute_invariant_J2_prime()  -> 48

  First consumer: `hexa-chip/firmware/mcu/npu_host.hexa` (Phase F iter 5)
  uses compute_dispatch to run NPU layer descriptor as GPGPU kernel.

  Web-search 2026-05-08 spec table (canon §2): CUDA 13.2, HIP 7.2.53211,
  SYCL 2020 rev 11, OpenCL 3.1.0, Metal 4 (MSL 2025-10-23), WebGPU CR Draft.

## [0.12.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/dma.hexa` —
  σ-slot 10 (dma) HW-backend stubs across ALL 5 vendors. Per-vendor
  coverage 9/12 → 10/12. Total backend stub count: 45 → 50.

  4 distinct DMA architectures abstracted under one surface:
  - **STM32H7 multi-DMA** — 3 DMA peripherals on one chip:
    MDMA (Master DMA, 16 ch, AHB+AXI master, all 7 bus masters)
    + BDMA (Basic DMA, 8 ch, D3 domain only)
    + DMA1/2 (8 streams each, multiplexed via DMAMUX1).
    Total HW envelope: 40 channels (sim caps at J₂=24).
  - **RP2040 control-block DMA** — single 12-channel controller @
    0x50000000. Distinctive features: control-block chaining
    (CHAIN_TO field — channels can program each other for arbitrary
    scatter-gather without CPU); sniff mode (CRC32/CRC16/parity sum
    computed during transfer); pacing timers for bandwidth-limited
    transfers (e.g. video timing). 41 DREQ sources.
  - **ESP32 per-peripheral DMA** — original ESP32 has NO general-
    purpose GDMA. Instead, separate DMA blocks live inside
    SPI / I2S / UART(UHCI) peripherals. The stub abstracts these as
    3 channels (SPI/I2S/UHCI). Linked-list "LL_DMA" 12-byte
    descriptor format introduced here became the ABI for all later
    ESP32 family GDMA controllers.
  - **ESP32-C3/S3 GDMA (general-purpose DMA)** — unified DMA
    controller @ 0x6003F000 with peripheral selector (PERI_SEL).
    C3: 3 RX/TX pairs (6 directional ch); S3: 5 RX/TX pairs (10 ch)
    plus PSRAM-DMA support. Both inherit the LL_DMA descriptor format
    from original ESP32.

  Surface (mirrors `stdlib/hal/dma.hexa` sim):
    dma_configure(channel, direction, width) -> int  (channel ≤ 23 = J₂)
    dma_start(handle, src, dst, n_bytes) -> bool
    dma_wait(handle) -> bool
    dma_abort(handle) -> bool
    dma_report(handle) -> str

  Channel envelope per vendor:
    - stm32h7: 40 HW (MDMA 16 + BDMA 8 + DMA1 8 + DMA2 8); sim sees ≤24
    - rp2040:  12 HW (single DMA block)
    - esp32:   3 HW (SPI + I2S + UHCI; no GDMA)
    - esp32c3: 6 HW (3 RX + 3 TX; GDMA)
    - esp32s3: 10 HW (5 RX + 5 TX; GDMA + PSRAM support)

### Architecture diversity milestone
- v0.12.0 covers 4 distinct DMA architectures under one surface:
    1. STM32H7 stream-based multi-DMA (3 DMA peripherals)
    2. RP2040 control-block-chained DMA (12 ch + sniff mode)
    3. ESP32 per-peripheral DMA (no central controller)
    4. ESP32 family GDMA (unified, LL_DMA descriptors, scaled per chip)
  Combined with v0.11.0's 4-architecture interrupt controller test,
  stdlib/hal now demonstrates that fundamentally different controller
  IPs can be unified behind a stable peripheral surface across 5 vendors.

### Changed
- HW-backend stub file count: 45 → 50 (5 vendors × 10 peripherals).
- Per-vendor coverage: 9/12 → 10/12 across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓).

### Provenance
- STM32H7 MDMA / BDMA / DMA1/2 from RM0433 §15/16/17.
- RP2040 DMA 0x50000000 from RP2040 Datasheet §2.5.
- ESP32 SPI / I2S / UHCI DMAs from ESP32 TRM §10/11/16.
- ESP32-C3 GDMA 0x6003F000 from ESP32-C3 TRM §3.
- ESP32-S3 GDMA 0x6003F000 from ESP32-S3 TRM §3.

### Roadmap
- v0.13.0: rtc (σ-slot 11) — STM32 RTC + RP2040 RTC + ESP32 RTC_CNTL.
- v0.14.0: core (σ-slot 0) — last per-vendor gap (cache mgmt / sleep
  modes / clock tree). Reaches **12/12 = 100%** per-vendor coverage.

## [0.11.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/intr.hexa` —
  σ-slot 9 (intr) HW-backend stubs across ALL 5 vendors. Per-vendor
  coverage 8/12 → 9/12. Total backend stub count: 40 → 45.

  This iter spans **4 distinct interrupt controller architectures**:
  - **ARM NVIC (M7)** in stm32h7/intr.hexa — Cortex-M7 240-IRQ NVIC
    at architectural 0xE000E100 + EXTI ext-line gating; 16 priority
    levels (4-bit NVIC_PRIO_BITS); STM32H7 maps ~150 peripheral IRQs.
  - **ARM NVIC (M0+)** in rp2040/intr.hexa — Cortex-M0+ simpler NVIC
    (32 IRQs, 2-bit priority = 4 levels matching sim exactly); dual-core
    cross-routing via SIO PROC<n>_INTR (separate NVIC per core).
  - **Xtensa LX6 interrupt matrix** in esp32/intr.hexa — DPORT-based
    matrix at 0x3FF00000; 70 peripheral sources route through per-core
    MAP regs to 32 CPU IRQ × 7 priority levels; PRO + APP CPU separate
    matrices; vector entries in IRAM @ Xtensa-level offsets (0x40000180+).
  - **RISC-V (custom Espressif matrix)** in esp32c3/intr.hexa — INTERRUPT
    block at 0x600C2000; 31 peripheral IRQs × 15 priority levels;
    standard RV32IMC CSRs (MIE/MIP/MTVEC/MCAUSE) + Espressif vendor
    extensions (MEIE/MEIP partial mask).
  - **Xtensa LX7 interrupt matrix** in esp32s3/intr.hexa — INTERRUPT
    block at 0x600C2000 (moved from DPORT vs LX6); ~99 peripheral
    sources (vs 70 on LX6); same 32 × 7 envelope; LX7-specific vector
    levels including NMI@0x40000380.

  Surface (mirrors `stdlib/hal/intr.hexa` sim):
    intr_configure(vector, priority) -> int      (vector ≤ 23 = J₂)
    intr_attach(handle, name) -> bool
    intr_enable(handle) -> bool
    intr_disable(handle) -> bool
    intr_clear(handle) -> bool
    intr_report(handle) -> str

  Sim's 4-level priority (PRIO_HIGH/REAL_T/NORMAL/LOW) maps onto each
  vendor's native scheme:
    - stm32h7: 4 of 16 NVIC levels (PRIO_HIGH=0, LOW=3, low-bit-only used)
    - rp2040:  4 = exact match (Cortex-M0+ has 2-bit = 4 levels)
    - esp32 / esp32s3: 4 of 7 Xtensa levels (HIGH→4, REAL_T→3, NORMAL→1, LOW→1)
    - esp32c3: 4 of 15 matrix levels (inverted: matrix high # = high prio)

### Changed
- HW-backend stub file count: 40 → 45 (5 vendors × 9 peripherals).
- Per-vendor coverage: 8/12 → 9/12 across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓ holds).

### Architecture coverage milestone
- v0.11.0 is the **most architecturally diverse** iter so far. Single
  σ-slot (intr) requires 4 distinct controller IPs covered:
    1. ARM Cortex-M7 NVIC (architectural SCS, 16 prio)
    2. ARM Cortex-M0+ NVIC (architectural SCS, 4 prio)
    3. Xtensa LX6/LX7 interrupt matrix (vendor-custom, 7 levels)
    4. Espressif custom RISC-V matrix (vendor-custom, 15 levels;
       NOT a standard RV-PLIC layout)
  This validates that the cfg-flag dispatch model can map a single
  surface (intr_configure / intr_enable / ...) onto fundamentally
  different controller architectures — the strongest cross-ISA
  abstraction test in stdlib/hal so far.

### Provenance
- Register sketches per vendor reference manual cross-reference:
    - STM32H7 NVIC from ARMv7-M PM0214 §4.3 + RM0433 §11.
    - RP2040 NVIC from ARMv6-M PM0223 §4.3 + RP2040 Datasheet §2.3.2.
    - ESP32 DPORT intr matrix from ESP32 TRM §6.
    - ESP32-C3 INTERRUPT block from ESP32-C3 TRM §8 + RV ISA.
    - ESP32-S3 INTERRUPT block from ESP32-S3 TRM §6.

### Roadmap
- v0.12.0: dma (σ-slot 10) — STM32H7 MDMA/BDMA + RP2040 12-channel DMA
  + ESP32 family GDMA. Different DMA architectures per vendor (channel
  count + descriptor format + chaining model).
- v0.13.0: rtc (σ-slot 11) — STM32 RTC peripheral + RP2040 RTC + ESP32
  RTC_CNTL.
- v0.14.0: core (σ-slot 0) — last gap; CPU-level cache / sleep / clock.

## [0.10.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/dac.hexa` —
  σ-slot 6 (dac, analog) HW-backend stubs across ALL 5 vendors.
  First peripheral with **non-uniform native support**: 2 of 5 vendors
  have native DAC, 3 of 5 use PWM-emulation fallback. Per-vendor
  coverage 7/12 → 8/12. Total backend stub count: 35 → 40.

  Native hardware DAC:
  - `stm32h7/dac.hexa`  — DAC1 0x40007400 (+ optional DAC2 0x58003400);
                          dual-channel **12-bit native**; output PA4/PA5;
                          ≤ 1 MSPS via DMA + TIM trigger; cosine /
                          triangle / noise wave generators built-in.
  - `esp32/dac.hexa`    — RTC_IO 0x3FF48400 + SENS 0x3FF48800;
                          2 channels × **8-bit native** (GPIO25/26);
                          ≤ 1 MSPS via I2S DMA "DAC mode"; cosine wave
                          generator (CW) via SAR_DAC_CTRL1.SW_TONE_EN.

  PWM-emulation fallback (no native DAC; LEDC/PWM + RC filter):
  - `rp2040/dac.hexa`   — routes to `rp2040_pwm` + external RC LPF;
                          8 PWM slices = 8 virtual DAC units; achievable
                          res × bw: 12b @ ≤30 kHz / 10b @ ≤122 kHz /
                          8b @ ≤488 kHz @ sys_clk=125 MHz. For ≥ 16-bit
                          precision: external SPI DAC (AD5675R / MCP4922).
  - `esp32c3/dac.hexa`  — routes to `esp32c3_pwm` (LEDC); 6 channels;
                          1..14-bit LEDC duty resolution; res × bw:
                          12b @ ≤19.5 kHz at APB=80 MHz.
  - `esp32s3/dac.hexa`  — routes to `esp32s3_pwm` (LEDC); 8 channels;
                          1..20-bit LEDC duty (highest of 5 vendors) →
                          can emulate **16-bit DAC** at ≤ 1.2 kHz BW
                          without dither (S3-specific advantage).

  Surface (mirrors `stdlib/hal/dac.hexa` sim):
    dac_configure(unit, channel, resolution) -> int
    dac_write(handle, value) -> bool
    dac_close(handle) -> bool
    dac_report(handle) -> str

### IP-cell observations / vendor pivot note
- The DAC peripheral was native on the original ESP32 (8-bit) but
  **dropped** by Espressif starting with ESP32-S2 / S3 / C3 — Espressif
  positions LEDC + RC filter as the recommended emulation path.
- STM32H7 has the strongest native DAC: 12-bit, dual-channel, hardware
  waveform generators (cosine/triangle/noise), DMA-driven up to 1 MSPS.
- RP2040 has no native DAC at all; relies entirely on PWM emulation
  or external SPI DAC ICs.

### Changed
- HW-backend stub file count: 35 → 40 (5 vendors × 8 peripherals).
- Per-vendor coverage: 7/12 → 8/12 across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓ holds).

### Provenance
- Register sketches per vendor TRM cross-reference:
    - STM32H7 DAC1 0x40007400 from RM0433 §29.
    - ESP32 RTC_IO + SENS DAC regs from ESP32 TRM §5.13 + §31.
    - RP2040: no DAC §; emulation strategy per Pico SDK examples.
    - ESP32-C3 / S3: no DAC §; LEDC §13 cross-reference.

### Roadmap
- v0.11.0: intr (σ-slot 9) — NVIC table on ARM (stm32h7, rp2040),
  RV interrupt controller on RISC-V (esp32c3), Xtensa intr matrix on
  esp32 / esp32s3.
- v0.12.0: dma (σ-slot 10) — MDMA/BDMA on STM32H7, 12-channel DMA on
  RP2040, GDMA on ESP32 family.
- v0.13.0: rtc (σ-slot 11) — final missing peripheral to reach 11/12
  per vendor (core σ-slot 0 is partially trivial; covered by sim).

## [0.9.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/pwm.hexa` —
  σ-slot 7 (pwm) HW-backend stubs added for ALL 5 vendors. Per-vendor
  coverage moves from 6/12 → 7/12. Total backend stub count: 30 → 35.
  - `stm32h7/pwm.hexa`  — TIM-PWM via TIM1/8 advanced (complementary +
                          dead-time + break) and TIM2/3 GP; PWM mode 1/2
                          via CCMRn.OCxM; freq = TIMCLK/((PSC+1)·(ARR+1));
                          duty = CCRn / (ARR+1).
  - `rp2040/pwm.hexa`   — dedicated PWM block at 0x40050000; 8 slices ×
                          2 channels (A/B) = 16 PWM outputs; 8.4-bit
                          fractional divider; freq range ~7 Hz .. ~10 MHz.
  - `esp32/pwm.hexa`    — LEDC at 0x3FF59000; 16 channels (8 HS + 8 LS) ×
                          8 timers (4 HS + 4 LS); 1..20-bit duty; MCPWM
                          motor-control out of scope.
  - `esp32c3/pwm.hexa`  — LEDC at 0x60019000; 6 channels × 4 timers
                          (smaller than ESP32; no HS/LS split); 1..14-bit duty.
  - `esp32s3/pwm.hexa`  — LEDC at 0x60019000; 8 channels × 4 timers;
                          1..20-bit duty.

  Surface (mirrors `stdlib/hal/pwm.hexa` sim):
    pwm_configure(gen, channel, freq_hz) -> int
    pwm_start(handle) / pwm_stop(handle) -> bool
    pwm_set_duty(handle, duty_x100) -> bool   (0..10000 = 0..100.00%)
    pwm_set_freq(handle, freq_hz) -> bool
    pwm_report(handle) -> str

  Each stub correctly maps the σ-slot 7 sim handle calculation
  (gen × 12 + channel) to vendor-specific channel limits:
    - stm32h7: 4 generators (TIM1/8/2/3) × 4 channels = 16 outputs.
    - rp2040:  8 slices × 2 (A/B)        = 16 outputs.
    - esp32:   8 HS channels × 1         = 8  (with 8 more LS available).
    - esp32c3: 6 channels  × 1           = 6.
    - esp32s3: 8 channels  × 1           = 8.

### Changed
- HW-backend stub file count: 30 → 35 (5 vendors × 7 peripherals).
- Per-vendor peripheral coverage: 6/12 → 7/12 across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓ holds).

### IP-cell observations
- STM32H7: PWM is a TIM mode (no separate IP) — same register cluster
  as timer.hexa backend, different OCxM bit-pattern.
- RP2040: dedicated PWM block (separate from TIMER block); cleaner
  decoupling but consumes its own MMIO region.
- ESP32 family: LEDC (LED PWM Controller) + MCPWM (Motor Control PWM)
  are 2 distinct IPs; this stub covers LEDC only — MCPWM would be a
  separate σ-slot extension if added.

### Provenance
- Register sketches from each vendor's reference manual via web-search
  + training data cross-reference (per autonomy directive web-search
  mandate). Base addresses confirmed:
    - STM32H7 TIM1/8/2/3 from RM0433 §39/40.
    - RP2040 PWM 0x40050000 from RP2040 Datasheet §4.5.
    - ESP32 LEDC 0x3FF59000 from ESP32 TRM §13.
    - ESP32-C3 LEDC 0x60019000 from ESP32-C3 TRM §13.
    - ESP32-S3 LEDC 0x60019000 from ESP32-S3 TRM §13.

### Roadmap
- v0.10.0 candidate: dac (σ-slot 6) — STM32H7 + ESP32 have native
  hardware DAC; rp2040 + ESP32-C3 + ESP32-S3 use PWM + RC filter
  emulation. Stubs will document the fallback path.
- v0.11.0 candidate: intr (σ-slot 9), dma (σ-slot 10), rtc (σ-slot 11)
  — last 3 missing peripherals to reach 12/12 per vendor.
- v0.12.0 candidate: esp32c6 sub-vendor (WiFi 6 / Zigbee / Thread, RV32IMAC).

## [0.8.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/timer.hexa` —
  σ-slot 8 (timer) HW-backend stubs added for ALL 5 registered
  vendors simultaneously. First **peripheral-axis expansion** in
  the backend tree (prior iters expanded the vendor axis); per-vendor
  coverage moves from 5/12 (HW-5 only) to 6/12 across all 5 vendors.
  - `stm32h7/timer.hexa` — TIM2 0x40000000 + TIM3 0x40000400 + TIM6
                            0x40001000 + TIM1 0x40010000 (selected
                            representatives from 16 timers in H7).
                            APB_TIM=200 MHz; period = (PSC+1)·(ARR+1)/200.
  - `rp2040/timer.hexa`  — TIMER 0x40054000 (single instance, 4 alarms,
                            64-bit µs counter; tick = 1 µs; never wraps
                            in realistic time).
  - `esp32/timer.hexa`   — TIMG0 0x3FF5F000 + TIMG1 0x3FF60000
                            (4 × 64-bit GP timers across 2 groups).
  - `esp32c3/timer.hexa` — TIMG0 0x6001F000 + TIMG1 0x60020000
                            (2 × 54-bit GP timers; smaller than ESP32).
  - `esp32s3/timer.hexa` — TIMG0 0x6001F000 + TIMG1 0x60020000
                            (4 × 54-bit GP timers; same family as ESP32-C3).

  Surface (mirrors `stdlib/hal/timer.hexa` sim):
    timer_configure(idx, mode, period_us) -> int
    timer_start(handle) -> bool
    timer_stop(handle)  -> bool
    timer_now_ticks(handle) -> int
    timer_set_callback(handle, period_us) -> bool
    timer_clear(handle) -> bool
    timer_report(handle) -> str

  4 modes per sim convention: ONESHOT / PERIODIC / CAPTURE / PWM.
  ≤ 4 timer handles per process (matches J₂/n = 4 default ceiling).

### Changed
- HW-backend stub file count: 25 (5 vendors × HW-5) → 30 (5 × 6 stubs).
- Per-vendor peripheral coverage: 5/12 → 6/12 across all 5 vendors.
- The numerics_sim_marker_density.hexa F-HAL-5 T2 ENFORCES that every
  registered vendor covers the canonical HW-5; timer is **outside**
  the canonical HW-5 set, so the stubs are documentation-tier
  additions that expand the per-vendor footprint without changing
  the falsifier-bound invariant. F-HAL closure unchanged at 67% × 5.

### ISA / vendor coverage retained
- All 5 vendors (stm32h7, rp2040, esp32, esp32c3, esp32s3) covered
  uniformly. The 4 distinct CPU classes (ARM Cortex-M7, ARM Cortex-M0+,
  Xtensa LX6, Xtensa LX7+ULP-RISC-V, RISC-V RV32IMC) all gain timer
  support in this iter.

### Provenance
- Register sketches pulled from each vendor's reference manual /
  datasheet via web-search + training data cross-reference (per
  autonomy directive web-search mandate). Base addresses confirmed:
    - STM32H7 TIM2/3/6/1 from RM0433 §39/40/43.
    - RP2040 TIMER 0x40054000 from RP2040 Datasheet §4.6.
    - ESP32 TIMG0/1 0x3FF5F000/0x3FF60000 from ESP32 TRM §17.
    - ESP32-C3 TIMG0/1 0x6001F000/0x60020000 from ESP32-C3 TRM §15.
    - ESP32-S3 TIMG0/1 0x6001F000/0x60020000 from ESP32-S3 TRM §15.
- IP cells: STM32H7 has the most varied (TIM advanced/general/basic);
  RP2040 has a single distinctive 64-bit-counter+4-alarm IP; the
  3 ESP32 family chips share the same Timer Group IP cell scaled per
  variant (4 × 64-bit on ESP32, 2 × 54-bit on C3, 4 × 54-bit on S3).

### Roadmap
- v0.9.0 candidate: extend to dac/pwm/intr/dma/rtc — picking 1 peripheral
  per iter × 5 vendors. Next likely target: pwm (motor / LED control,
  universally supported).
- v1.0.0 candidate: complete per-vendor HW-12 coverage AND first T3-tier
  cross-compile (Cortex-M0+ binary for rp2040 with Renode emulation).

## [0.7.0] - 2026-05-08

### Added
- `backend/esp32s3/{gpio,i2c,spi,uart,adc}.hexa` — fifth hardware
  vendor backend. Espressif ESP32-S3 Xtensa LX7 dual-core @ 240 MHz +
  ULP-RISC-V coprocessor + AI vector accelerator + USB-OTG.
  Peripheral region 0x6000xxxx (same family as C3; not the 0x3FF
  range of original ESP32).
  - `esp32s3/gpio.hexa`  — DR_REG_GPIO_BASE 0x60004000 + IO_MUX 0x60009000;
                           45-pin envelope (GPIO0..21 + GPIO26..48; gap at
                           22..25 reserved for flash/PSRAM); dual-bank
                           (OUT/OUT1, IN/IN1, ENABLE/ENABLE1); GPIO19/20
                           = USB-OTG D-/D+.
  - `esp32s3/i2c.hexa`   — I2C0 0x60013000 / I2C1 0x60027000; same
                           command-queue architecture as ESP32 / C3.
  - `esp32s3/spi.hexa`   — SPI2 0x60024000 / SPI3 0x60025000 (both
                           user-accessible; SPI0/1 reserved for flash+PSRAM);
                           same 16 × 32-bit shift buffer; max 80 MHz.
  - `esp32s3/uart.hexa`  — UART0/1/2 (0x60000000 / 0x60010000 / 0x6002E000);
                           same fractional divisor as ESP32 family;
                           built-in USB-Serial-JTAG on GPIO19/20.
  - `esp32s3/adc.hexa`   — APB_SARADC 0x60040000; 12-bit fixed; ADC1
                           10-ch (GPIO1..10) + ADC2 10-ch (GPIO11..20);
                           **no WiFi conflict on S3** (improvement vs ESP32).

### Changed
- `numerics_sim_marker_density.hexa` `CANONICAL_VENDORS` now 5 entries
  (stm32h7, rp2040, esp32, esp32c3, esp32s3). Expected backend stub
  count = 5 × 5 = 25.
- v0.7.0 vendor list: + esp32s3 (this).

### ISA family + variant coverage milestone
- v0.7.0 introduces the **second Xtensa variant** (LX7 vs LX6). Vendors
  now span 4 distinct CPU classes:
    - ARM Cortex-M7 (stm32h7)
    - ARM Cortex-M0+ (rp2040)
    - Xtensa LX6 (esp32)
    - Xtensa LX7 + ULP-RISC-V (esp32s3) ← new
    - RISC-V RV32IMC (esp32c3)
  ESP32-S3 is notable as the first vendor with a **secondary ULP
  coprocessor** (ULP-RISC-V) — opens a v1.0+ design question of
  whether ULP-class peripherals deserve their own σ-slot extension.

### Provenance
- ESP32-S3 register addresses confirmed via web-search + ESP32-S3 TRM.
  GPIO_BASE = 0x60004000 (matches C3 — same peri region; offsets
  differ per peripheral type/count).
- Pin envelope: 45 pins (GPIO0..21 + GPIO26..48, gap at 22..25).
- IP cells: GPIO Matrix S3-specific (45 pins, dual-bank); I2C / SPI /
  UART / SAR ADC IP cells reused from ESP32 family with bus / ch
  count adjustments.
- ULP-RISC-V coprocessor + AI accelerator + USB-OTG noted but their
  HW backends are out of v0.7.0 scope (would extend σ-slot table).

## [0.6.0] - 2026-05-08

### Added
- `backend/esp32c3/{gpio,i2c,spi,uart,adc}.hexa` — fourth hardware
  vendor backend; **first RISC-V** target in stdlib/hal (earlier
  vendors were all Xtensa LX6 or ARM Cortex-M). Espressif ESP32-C3
  RV32IMC single-core @ 160 MHz; peripheral region 0x6000xxxx
  (vs ESP32 Xtensa's 0x3FFxxxxx range — distinct memory map).
  - `esp32c3/gpio.hexa`  — DR_REG_GPIO_BASE 0x60004000 + IO_MUX 0x60009000;
                           22-pin envelope (single bank, no dual-bank
                           split; vs ESP32 40-pin); GPIO0..5=ADC1,
                           GPIO12..17=flash reserved, GPIO18..19=USB-JTAG.
  - `esp32c3/i2c.hexa`   — single I2C0 0x60013000 (vs ESP32 dual);
                           same command-queue architecture (16-deep);
                           FIFO depth 32.
  - `esp32c3/spi.hexa`   — single GP-SPI (SPI2) 0x60024000 (vs ESP32
                           dual HSPI/VSPI); same 16×32-bit shift buffer;
                           max 80 MHz with CLK_EQU_SYSCLK.
  - `esp32c3/uart.hexa`  — UART0/1 (0x60000000 / 0x60010000); same
                           CLKDIV+CLKDIV_FRAG fractional divisor as ESP32;
                           UART0 boot console; built-in USB-Serial-JTAG
                           bridge on GPIO18/19 (separate IP, out of scope).
  - `esp32c3/adc.hexa`   — APB_SARADC 0x60040000; 12-bit fixed (vs ESP32
                           9..12-bit programmable); ADC1 5-ch (GPIO0..4)
                           + ADC2 1-ch (GPIO5); **no WiFi conflict on C3**
                           (unlike ESP32's ADC2).

### Changed
- `numerics_sim_marker_density.hexa` (F-HAL-5 T2) `CANONICAL_VENDORS`
  now `["stm32h7", "rp2040", "esp32", "esp32c3"]` (was 3 vendors).
  Vendor count = 4; expected backend stub file count = 5 × 4 = 20.
- v0.6.0 vendor list: stm32h7 (v0.2.0) + rp2040 (v0.4.0) + esp32
  (v0.5.0) + esp32c3 (this).

### ISA family coverage milestone
- v0.6.0 is the **first multi-ISA-family** release of stdlib/hal.
  Vendors now span:
    - ARM Cortex-M7 (stm32h7)
    - ARM Cortex-M0+ (rp2040)
    - Xtensa LX6 (esp32)
    - **RISC-V RV32IMC (esp32c3)** ← new
  This validates the cfg-flag dispatch model across CPU ISAs, not just
  vendors — a peripheral surface (e.g. `gpio_write(pin, val)`) now
  resolves to ARM, Xtensa, OR RISC-V backend at compile time without
  any change to the consumer code.

### Provenance
- ESP32-C3 register addresses + memory map confirmed via
  ESP32-C3 Technical Reference Manual cross-reference (per autonomy
  directive web-search mandate). DR_REG_GPIO_BASE = 0x60004000.
- IP cells: GPIO Matrix is C3-specific (smaller pin count → single bank);
  I2C / SPI / UART / SAR ADC IP cells are reused from ESP32 family with
  smaller bus / peripheral counts.
- Future ESP32 sub-vendors (esp32s2, esp32s3, esp32c6, esp32h2) would
  follow the same naming convention — out of v0.6.0 scope.

## [0.5.0] - 2026-05-08

### Added
- `backend/esp32/{gpio,i2c,spi,uart,adc}.hexa` — third hardware
  vendor backend, paper-skeleton stubs covering the canonical HW-5.
  Targets the Espressif ESP32 dual Xtensa LX6 @ 240 MHz (original).
  Each stub documents the relevant DR_REG_*_BASE (0x3FF range) +
  key register offsets:
  - `esp32/gpio.hexa`  — DR_REG_GPIO_BASE 0x3FF44000 + IO_MUX 0x3FF49000;
                         40-pin envelope (GPIO0..39) with caveats: GPIO34..39
                         input-only, GPIO6..11 reserved for SPI flash;
                         dual-bank registers (OUT/OUT1, IN/IN1) for pins ≤31
                         vs ≥32; W1TS/W1TC atomic helpers (no XOR — sw RMW).
  - `esp32/i2c.hexa`   — I2C0 0x3FF53000 / I2C1 0x3FF67000; programmable
                         16-deep command queue (RSTART/WRITE/READ/STOP/END
                         opcodes) — distinct from DesignWare-class
                         fire-and-forget FIFO; std/fast/fast-plus.
  - `esp32/spi.hexa`   — HSPI 0x3FF64000 (SPI2) + VSPI 0x3FF65000 (SPI3)
                         user-accessible; SPI0/SPI1 reserved for flash;
                         16 × 32-bit shift buffer (W0..W15); max f_spi
                         = APB_CLK = 80 MHz with CLK_EQU_SYSCLK; CPOL/CPHA
                         encoded as CK_OUT_EDGE/CK_I_EDGE per TRM matrix.
  - `esp32/uart.hexa`  — UART0/1/2 (0x3FF40000 / 0x3FF50000 / 0x3FF6E000);
                         IBRD/FBRD-style baud divisor (CLKDIV + CLKDIV_FRAG
                         /16); UART0 boot-console safety note.
  - `esp32/adc.hexa`   — SAR_ADC 0x3FF48800; 9..12-bit programmable; 8-ch
                         ADC1 (GPIO32..39) + 10-ch ADC2 (WiFi-conflicted);
                         per-channel attenuation 0/2.5/6/11 dB.

### Changed
- `numerics_sim_marker_density.hexa` (F-HAL-5 T2) `CANONICAL_VENDORS`
  now `["stm32h7", "rp2040", "esp32"]` (was `["stm32h7", "rp2040"]`).
  Vendor count = 3; expected backend stub file count = 5 × 3 = 15.
- v0.5.0 vendor list: stm32h7 (v0.2.0) + rp2040 (v0.4.0) + esp32 (this).

### Provenance
- ESP32 register addresses pulled from web-search + ESP32 Technical
  Reference Manual cross-reference (per autonomy directive web-search
  mandate). DR_REG_GPIO_BASE = 0x3FF44000 confirmed.
- IP cells: ESP32 has its own GPIO Matrix (no PrimeCell reuse), custom
  command-queue I2C, custom 80-MHz SPI master, and custom UART with
  fractional divisor.
- ESP32-S2/S3 (Xtensa LX7) and ESP32-C3/C6 (RISC-V) variants would be
  separate sub-vendors (esp32s3, esp32c3) — out of v0.5.0 scope.
- No HW physically tested; paper-skeleton parity with stm32h7 + rp2040.

## [0.4.0] - 2026-05-08

### Added
- `backend/rp2040/{gpio,i2c,spi,uart,adc}.hexa` — second hardware
  vendor backend, paper-skeleton stubs covering the canonical HW-5.
  Targets the Raspberry Pi RP2040 dual Cortex-M0+ @ 133 MHz; each
  stub documents the relevant MMIO base address, key register offsets,
  default speed/clock, and `STUB`/`TODO` markers for cross-compile
  follow-on:
  - `rp2040/gpio.hexa`  — SIO 0xD0000000, IO_BANK0 0x40014000,
                          PADS_BANK0 0x4001C000; 30-pin envelope (GP0..GP29);
                          atomic SET/CLR/XOR aliases sketched.
  - `rp2040/i2c.hexa`   — I2C0 0x40044000 / I2C1 0x40048000 (DesignWare-class IP);
                          std/fast/fast-plus speed grades (100k/400k/1M).
  - `rp2040/spi.hexa`   — SPI0 0x4003C000 / SPI1 0x40040000 (PL022 SSP IP);
                          max f_spi ≈ 62.5 MHz @ peri_clk=125 MHz; 4 SPI modes.
  - `rp2040/uart.hexa`  — UART0 0x40034000 / UART1 0x40038000 (PL011 UART IP);
                          baud-divisor formula (IBRD/FBRD); 5..8-bit word length.
  - `rp2040/adc.hexa`   — ADC 0x4004C000; 12-bit, 4 ext channels (AIN0..3
                          on GP26..29) + 1 on-die T sensor (AIN4); max 500 kSPS.

### Changed
- `numerics_sim_marker_density.hexa` (F-HAL-5 T2) made parametric over
  the registered vendor set:
  - `CANONICAL_VENDORS` array (was scalar `CANONICAL_VENDOR`) — vendors
    must appear in this list AND on disk; drift in either direction
    fails T2.
  - `check_canonical_5_per_vendor()` (was `check_canonical_5`) — verifies
    every registered vendor covers the full HW-5; total expected file
    count = 5 × |vendors|.
  - `check_stub_markers()` extended to scan all registered vendors.
  - `check_coverage_ratio()` framed as "per-vendor HW coverage" since the
    sim/HW comparison is per-vendor.

  Result: the F-HAL-5 closure stays at 67% (T1 ✓ + T2 ✓), but the T2 now
  enforces a stricter invariant — every additional vendor must ship the
  HW-5 set, otherwise sim-first is violated by partial coverage.

- v0.4.0 vendor list: stm32h7 (v0.2.0) + rp2040 (this).

### Provenance
- RP2040 register addresses + IP cell info pulled via
  web-search + RP2040 Datasheet (datasheets.raspberrypi.com/rp2040)
  cross-reference (per autonomy directive web-search mandate).
- IP cells reused: PL011 UART (UART0/1), PL022 SSP (SPI0/1),
  Synopsys DesignWare-class I2C (I2C0/1) — all standard ARM PrimeCell
  / DW peripherals; offsets match published RP2040 datasheet §4.2/§4.3/§4.4/§4.9.
- No HW physically tested; this is paper-skeleton parity with stm32h7.

## [0.3.0] - 2026-05-08

### Added
- `numerics_phi_dichotomy.hexa` — T2 for F-HAL-3 (φ=2 dichotomy).
  Reads each `<module>.hexa`, extracts the `let PHI_KIND` literal,
  verifies 10 digital + 2 analog with analog set == {adc, dac}.
- `numerics_handle_dispatch.hexa` — T2 for F-HAL-4 (J₂/n handle dispatch).
  Reads each module's `<m>_module_meta()` 4th field, verifies per-module
  ceilings (10×4 + 2×24), Σ = 88, envelope J₂·τ = 96 ≥ 88, default
  floor 4·σ = 48 = 2·J₂, extension factor J₂/(J₂/n) = n = 6, and
  default:extended partition isomorphism with the φ-dichotomy.
- `numerics_sim_marker_density.hexa` — T2 for F-HAL-5 (sim-first).
  Strict 12/12 sim marker check (no exemption — tighter than T1's
  ≥11/12), no backend imports in peripheral surface, exactly 1 vendor
  (stm32h7) in `backend/`, canonical HW-5 (gpio/i2c/spi/uart/adc) stubs
  with stub markers, sim ≥ HW coverage ratio, sim-marker density floor
  ≥ σ = 12 occurrences across 12 modules.

### Changed
- F-HAL-3 closure: 33% → **67%** (T1 ✓ + T2 ✓).
- F-HAL-4 closure: 33% → **67%** (T1 ✓ + T2 ✓).
- F-HAL-5 closure: 33% → **67%** (T1 ✓ + T2 ✓).
- **sat-1 milestone reached**: all 5 F-HAL falsifiers now ≥ 67% closure
  (F-HAL-1/2/3/4/5 = 67% × 5). Phase 1 RSC saturation signals on the
  HAL substrate: sat-1 ✓ + sat-2 ✓.
- `falsifier_check.hexa` registry updated: F3_T2 / F4_T2 / F5_T2
  pointed at the 3 new scripts; status block updated to v0.3.0.
- `README.md` (separate update) reflects v0.3.0 status.

### Provenance
- All 3 new scripts mirror the `numerics_module_topology.hexa` and
  `numerics_lifecycle_dispatch.hexa` (v0.2.0) pattern: hard-coded
  n=6 lattice constants + module roster + on-disk file reads + per-
  identity `_check()` calls + sentinel-suffixed verdict.
- No HW changes; the `backend/stm32h7/` tree is unchanged from v0.2.0
  (5 stubs). v0.4.0 will add a second vendor (rp2040 or esp32).

## [0.2.0] - 2026-05-08

### Added
- `numerics_module_topology.hexa` — T2 for F-HAL-1 (σ=12 geometry).
- `numerics_lifecycle_dispatch.hexa` — T2 for F-HAL-2 (τ=4 lifecycle).
- `backend/stm32h7/{i2c,spi,uart,adc}.hexa` — 4 more stm32h7 stubs (matching gpio.hexa pattern).
- README.md notes T2 progression for F-HAL-1/2.

### Changed
- F-HAL-1 closure: 33% → **67%** (T1 ✓ + T2 ✓).
- F-HAL-2 closure: 33% → **67%** (T1 ✓ + T2 ✓).
- F-HAL-3/4/5 still 33% (no T2 yet — v0.3.0+).
- sat-1 milestone partially advanced — needs F-HAL-3/4/5 T2 to fully satisfy.

## [0.1.0] - 2026-05-08

### Added
- `calc_handle_pool.hexa` — F-HAL-4 T1 (J₂/n handle ceiling).
- `calc_sim_first.hexa` — F-HAL-5 T1 (sim-before-HW invariant).
- `backend/stm32h7/gpio.hexa` — first hardware backend skeleton stub.
- README.md "Hardware backends" section.

### Changed
- F-HAL-4/5 closure: 0% → 33% (T1 ✓).
- All 5 falsifiers now register at least 1 T1 script (sat-2 satisfied).

## [0.0.1] - 2026-05-08
- Initial brainstorm scaffold.
