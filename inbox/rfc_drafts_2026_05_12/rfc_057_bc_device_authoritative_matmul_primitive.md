# RFC 057 — Bc device-authoritative matmul primitive (true persistent residency 의 마지막 정밀 격리 architecture)

- **Status**: design-draft (2026-05-18) — DESIGN ONLY, no implementation
- **Date**: 2026-05-18
- **Severity**: CRITICAL (RFC 056 Phase 1 + flame Phase 4-D-9 모두 landed·검증됐으나 d768·12L step 1 여전히 600s 미완. fire #11 이 GPU 속도 6× (A100→H100) 무관 wall 불변을 측정 → bottleneck 은 compute 아닌 **host-authoritative Bc constraint** 로 독립 확정. 이것이 GOAL 과 현재 사이 마지막 정밀 격리 architecture.)
- **Priority**: P0 (GOAL: flame 이 forge 통해 d768·12L 을 PyTorch 보다 빠르게, 측정)
- **Builds on**: RFC 040 (device-farr+cuBLAS), RFC 044 (regime-tiered), RFC 056 (device residence API — Phase 1 landed `1f077af1`), flame Phase 4-D-9 (`b1f32d21`, A2 resident-dataflow rewire PARTIAL — 본 RFC 의 blocker 를 정밀 격리)
- **Source convergence**:
  - RFC 056 Phase 1 LANDED + flame Phase 4-D-9 LANDED (PARTIAL, byte-safe subset) — 격리 브랜치 `rfc043-flame-camp`
  - 11-fire d768·12L 캠페인 — fire #5→#11, 단조, 매 fire 다음 architecture 를 측정으로 justify
- **Source evidence (g3 — 모든 claim 이 실측 trace)**:
  - `state/flame_phase4d7_gpu_fire_2026_05_17/PHASE4D7_FIRE11_ANALYSIS.md` §2 — **fire #11 결정적 교차검증**: A100($0.87/hr) 대비 ~6× 빠른 H100-SXM($5.61/hr) 에서도 `wall=600` step 1 미완 불변 → GPU compute 속도 무관 = bottleneck 은 compute 아님
  - `…/PHASE4D7_FIRE10_ANALYSIS.md` §2 — Phase 4-D-9 정밀 진단: 공유 cuBLAS matmul primitive (`flame_phase4d6_matmul_primitives.c`, d=32 path 겸용) 가 Bc 를 **host-side 로 H2D 없이 씀** → pinned Bc 로의 dev-view 가 stale device snapshot alias → RMSNorm/RoPE/attention slab 이 매 op host-rebuild
  - `…/PHASE4D7_FIRE9_ANALYSIS.md` §3 — 구조적 per-op round-trip + CPU-glue 가 bound (duplicate-H2D 아님) 의 최초 decisive 측정
  - RFC 056 §8.2 pre-registered caveat — "residency alone may not hit WALL ... A2 deep dataflow restructure is gated work" (정확히 본 RFC 가 해소)

## 1. Status / Priority / Severity

(see header). **DESIGN ONLY**. `flame_phase4d6_matmul_primitives.c` 는 **d=32·3L byte-eq path 겸용** + forge Phase 4-D-5-3 11/11 byte-eq verified oracle 와 상호작용 → RFC-first (g7). 어떤 substrate/matmul-primitive edit 도 본 contract review 전 land 금지.

## 2. Source convergence — 11-fire 가 본 RFC 로 수렴

| fire | landed | 측정 결과 | 다음을 justify |
|---|---|---|---|
| #9 | Phase 4-D-8 (`aa6d70ba`) | halving H2D 가 step-1 못 옮김 | 구조적 round-trip bound (RFC 056) |
| #10 | RFC 056 P1 (`1f077af1`) | resident 459→727 MiB, wall 불변 | API 부족 아닌 consumer rewire (Phase 4-D-9) |
| #11 | Phase 4-D-9 (`b1f32d21`) | resident 727→885 MiB, **H100 에서도 wall 불변** | **compute 아닌 host-authoritative Bc bound (본 RFC 057)** |

각 fire 가 다음 architecture 를 측정으로 justify (design-first 금지 — 사용자 directive "아키텍쳐는 실험·검증 후 결정" 준수). fire #11 의 H100 교차검증 = RFC 057 의 measurement anchor.

## 3. Source evidence (g3 — fire #11 direct trace)

1. **GPU 속도 독립성** (RFC 057 의 핵심 anchor): A100-SXM4 sm_80 (fire #5/#8/#9/#10) 와 H100-SXM sm_90 (fire #11, ~6× 빠른 TC/대역폭) 모두 `trainer_rc=124 wall_seconds=600`, step 1 미완 동일. GPU compute throughput 을 대폭 올려도 wall 이 미동 ⇒ wall 은 compute-bound 가 아니라 host↔device 구조 + host-authoritative Bc rebuild 에 지배됨.
2. **partial gain 측정** (Phase 4-D-9 효과 실재): RFC 056 P1 fire #10 resident 727 MiB → Phase 4-D-9 fire #11 resident 885 MiB (SwiGLU dev-view 2개 byte-safe 제거의 측정된 monotone gain). 즉 dev-view 경로 자체는 작동·효과 있음 — 남은 건 그것을 Bc 전체로 확장 못 하는 단일 constraint.
3. **정밀 격리된 단일 constraint** (Phase 4-D-9 code-inspection, fire #11 로 교차검증): `flame_phase4d6_matmul_primitives.c` 의 cuBLAS matmul primitive 가 결과 Bc 를 host-side 버퍼로 download(또는 host 에서 작성)하고 device 에 authoritative 사본을 두지 않음 → 후속 RMSNorm/RoPE/attention slab 이 Bc 를 dev-view 로 잡으면 stale device snapshot. 그래서 그들은 매 op host-rebuild → per-op round-trip 지속.

## 4. Scope (DESIGN ONLY)

RFC 057 specifies:
- `flame_phase4d6_matmul_primitives.c` 의 cuBLAS matmul 결과를 **device-authoritative** 로 두는 contract: matmul 출력 farr 를 `loc=DEVICE, dirty_dev=1` 로 남기고 (RFC 056 §6.1 state machine 사용) host download 는 lazy (host reader 가 실제 touch 할 때만)
- d=768·12L (GPU-resident) path 에서만 device-authoritative; **d=32·3L 은 기존 CPU/host path 완전 불변** (dim-gated, `#ifdef HEXA_CUDA` + threshold)
- 후속 op (RMSNorm/RoPE/attention slab) 가 device-authoritative Bc 를 RFC 056 §6.2 `hexa_farr_dev_view(Bc, offset, len)` 로 소비 — host-rebuild 제거
- 7 pre-registered falsifier (Stage 2 — post-land d768 fire 로 검증)

RFC 057 does NOT specify:
- `.cu` kernel math 변경 (verified oracle — 건드리지 않음)
- RFC 056 substrate API 변경 (Phase 1 에서 이미 landed; RFC 057 은 consumer + matmul-primitive 의 device-authoritative discipline)
- flame public API (`g_flame_api_fixed`)
- d=32 path 동작 변경 (절대 불변 — 핵심 제약)

## 5. Problem — host-authoritative Bc 가 dev-view 를 무력화

RFC 056 §6.2 `dev_view` 는 base buffer 가 device-authoritative 일 때만 byte-safe (resident bytes == 직전 authoritative op 출력). 그러나 Bc 를 채우는 cuBLAS matmul primitive 가 host-side authoritative (device 사본 stale/없음) → Bc 로의 dev-view 는 잘못된 device bytes 를 가리킴. flame Phase 4-D-9 가 SwiGLU 중간(silu→mul, base 가 직전 GPU op 출력 = device-authoritative)만 dev-view 적용 가능했던 이유. RMSNorm/RoPE/attention 은 모두 Bc slice 를 입력으로 받으므로 Bc 가 host-authoritative 인 한 dev-view 불가 → 매 op host→device 재업로드. fire #11 이 이것이 (compute 아닌) dominant wall bound 임을 H100 교차검증으로 확정.

## 6. Proposal — Bc device-authoritative matmul contract

### 6.1 matmul 출력 device-authoritative (RFC 056 state machine 재사용)
`flame_phase4d6_matmul_primitives.c` 의 GPU-resident path (d>threshold) 에서 cuBLAS Dgemm 결과를 D2H 하지 않고 출력 farr 를 `loc=DEVICE, dirty_dev=1` 로 둔다 (RFC 056 §6.1 transition). host download 는 RFC 056 의 lazy D2H 규칙으로 host reader 가 실제 읽을 때만.

### 6.2 후속 slab 의 dev-view 소비
RMSNorm(fwd/bwd)/RoPE(fwd/bwd)/attention(Q·Kᵀ, P·V, softmax 외 matmul-shaped) 가 Bc slice 입력을 `hexa_farr_dev_view(Bc, off, len)` 로 — Bc 가 §6.1 device-authoritative 이므로 H2D-skip byte-safe. attention causal-masked softmax 는 byte-eq-fitting verified kernel 부재 시 CPU 유지 (Phase 4-D-9 처럼 — 날조 금지).

### 6.3 d=32 path 절대 불변 (핵심 제약)
matmul primitive 가 d=32·3L byte-eq path 겸용 → device-authoritative 변경은 `#ifdef HEXA_CUDA` + `d > FLAME_GPU_RESIDENT_THRESHOLD` dim-gate 안에서만. d=32 는 기존 CPU/host-authoritative path 그대로 (1 byte 도 안 바뀜).

### 6.4 verified oracle 보존
RFC 057 은 `.cu` kernel body 미변경. matmul 은 동일 cuBLAS Dgemm; 바뀌는 건 출력의 residence disposition (D2H 시점)뿐. resident Bc == host Bc by construction (동일 Dgemm 출력) → Phase 4-D-5-3 11/11 byte-eq + d768 수치 불변.

## 7. Falsifier battery (7 pre-registered, post-land d768 fire 검증)

- **F-RFC057-D32-BYTEEQ** (hard gate #1): `flame_phase4b3_verify_all.sh` 모든 byte-eq section `max|Δ|=0.0`, pristine-vs-changed byte-identical (revert+diff). matmul primitive 가 d=32 겸용이므로 **절대 불변** — Δ≠0 은 dim-gate 누수 버그.
- **F-RFC057-BYTEEQ-PRESERVE** (hard gate #2): Phase 4-D-5-3 12-kernel GPU oracle `max|Δ|=0.0`, 12/12 PASS (resident Bc == host Bc by construction).
- **F-RFC057-RESIDENT-MEM**: d768 fire GPU resident ≥ 3.0 GB sustained (vs fire #11 885 MiB) — Bc(346M doubles ≈ 2.6GB) device 상주.
- **F-RFC057-H2D-COUNT**: per-step `cudaMemcpy H2D` 가 O(thousands)→O(few) (Bc/Bp pinned + 입력 batch만).
- **F-RFC057-STEP-COMPLETES**: d768 step 1 완료 (post-update gn2 출력) — 캠페인 최초.
- **F-RFC057-WALL** (GOAL gate): d768 train_step wall ≤ 437.9s (F-RFC046). 정직: 첫 fire 에서 miss 가능 (attention CPU softmax 잔존 시); 그 경우 잔여를 재측정해 다음 RFC 로 (no fudge).
- **F-RFC057-GPU-INDEP**: A100 vs H100 wall 격차가 fire #11(0%) 에서 유의미하게 벌어짐 (residency 후 비로소 compute-bound 가 되어야 정상 — bound 가 transfer→compute 로 이동했다는 측정 증거).

## 8. Honest caveats (g3 / f1 / f2)

### 8.1 verified oracle + d=32 겸용 = 최고 위험 RFC
`flame_phase4d6_matmul_primitives.c` 는 d=32 byte-eq path 와 forge oracle 양쪽과 얽힘. 그래서 F-RFC057-D32-BYTEEQ + BYTEEQ-PRESERVE 가 hard gate #1/#2 (max|Δ|=0.0). kernel math 미변경, residence disposition 만.

### 8.2 RFC 057 단독으로 GOAL 보장 아님
attention causal-masked softmax 에 byte-eq-fitting verified kernel 이 없으면 CPU 잔존 → F-RFC057-WALL 첫 fire miss 가능. RFC 057 은 dominant bound(host-authoritative Bc)를 제거; 잔여 CPU-softmax 는 측정 후 별도 RFC. falsifier 가 이를 정직히 분리 (RFC 056 §8.2 와 동일 honest 구조).

### 8.3 측정-anchored, design-first 아님
RFC 057 의 모든 claim 은 fire #9/#10/#11 실측 trace. 특히 fire #11 의 H100 교차검증(GPU 6× 무관 wall 불변)이 "bound 는 compute 아닌 host-authoritative Bc" 의 결정적 독립 증거. 사용자 directive(실험·검증 후 architecture 결정) 정면 준수.

### 8.4 비용 — A100 선호 dispatch follow-up
fire #11 이 H100($5.61/hr ≈ $1.22) — dispatch offer filter reliability 우선이 H100 잡음. 동일 정보면 A100($0.19) 우선이 g3 cost-routing. RFC 057 post-land fire 전 dispatch 에 A100 선호/H100 회피 GPU 필터 추가 (별도 작은 follow-up).

### 8.5 no lattice numerology (f1/f2)
모든 threshold(≥3.0GB, ≤437.9s, H2D count)는 fire #5–#11 실측 + F-RFC046 PyTorch-eager anchor. lattice/perfect-number 상수 없음.

## 9. Non-goals
- `.cu` kernel math 변경 없음 · RFC 056 substrate API 변경 없음 · flame public API 변경 없음 (`g_flame_api_fixed`) · d=32 path 동작 변경 없음 (절대 불변) · multi-GPU 없음 · RFC 044/056 supersede 없음 (RFC 057 은 그 위 consumer+matmul discipline)

## 10. Cross-RFC dependency
- RFC 040 (device-farr+cuBLAS) — Bc matmul 의 base substrate
- RFC 056 (residence API) — RFC 057 이 §6.1 state machine + §6.2 dev_view 를 그대로 소비; RFC 056 이 prerequisite (landed)
- flame Phase 4-D-9 (`b1f32d21`) — 본 RFC 의 blocker 를 정밀 격리한 직전 작업; SwiGLU dev-view 패턴을 Bc 전체로 일반화하는 것이 RFC 057
- RFC 044 (regime-tiered) — orthogonal; 함께 compose
- 향후 (RFC 058+): attention causal-masked softmax 의 byte-eq verified kernel (RFC 057 §8.2 잔여)

## 11. Cross-link
- 격리 SSOT: `~/core/hexa-lang-flame-wt` [rfc043-flame-camp] (공유 메인 동시세션 reset/clean 회피 — 사용자 승인 2026-05-18)
- fire evidence: `state/flame_phase4d7_gpu_fire_2026_05_17/PHASE4D7_FIRE{9,10,11}_ANALYSIS.md` (#11 = H100 교차검증 decisive)
- `stdlib/flame/PLAN.md` 진행 로그 (fire #5→#11 + RFC 056 + Phase 4-D-9 + 본 RFC anchor)
- RFC 056 spec `inbox/rfc_drafts_2026_05_12/rfc_056_*.md` §6.1 §6.2 §8.2
- substrate oracle: `state/forge_phase4d_5_3_2026_05_17/PHASE4D_5_3_ANALYSIS.md` (BYTEEQ-PRESERVE target)

## Authority
- AGENTS.tape `g3` — 모든 perf claim 이 fire #5–#11 실측 trace; fire #11 H100 교차검증이 본 RFC justify (design-first 아님)
- AGENTS.tape `g5` — forge substrate C/CUDA portable artifact; RFC 057 은 residence disposition discipline, no LLVM/transpile backend
- AGENTS.tape `g7` — RFC-first (verified oracle + d=32 겸용 primitive 건드림); `inbox/rfc_drafts_2026_05_12/` 보관
- AGENTS.tape §0 `nn_stack` — forge=substrate, flame=consumer; RFC 057 = matmul-primitive 의 device-authoritative consumer discipline
- LATTICE_POLICY `f1`/`f2` — lattice numerology 없음, 모든 anchor 실측
- `g_flame_api_fixed` — flame public API 불변 · `g_forge_verify_oracle` — F-RFC057-BYTEEQ-PRESERVE 가 12-kernel oracle max|Δ|=0.0 강제, no-fake-PASS 보존
- `g_flame_compiler_only` — compiled-native, interp dispatch 없음
