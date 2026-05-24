# RFC 058 — forge transpose-scatter kernel (Bc fully device-authoritative 의 마지막 조각)

- **Status**: design-draft (2026-05-18) — DESIGN ONLY, no implementation
- **Date**: 2026-05-18
- **Severity**: CRITICAL (RFC 057 §6.1 landed·검증됐으나 fire #12 측정: §6.1 단독은 d768·12L wall 을 1초도 못 옮김. fire #9~#12 4연속 600s step 1 미완. 단일 잔존 blocker = projection 출력의 **host-side transpose-scatter** 가 Bc 를 host-authoritative 로 묶음. 이 kernel 이 RFC 056→057 residency 체인의 마지막 조각.)
- **Priority**: P0 (GOAL: flame 이 forge 통해 d768·12L 을 PyTorch 보다 빠르게, 측정 — F-RFC046 wall ≤437.9s)
- **Builds on**: RFC 040 (device-farr+cuBLAS), RFC 041 (Phase B/B2 `.cu` kernels), RFC 056 (residence API, landed `1f077af1`), RFC 057 (Bc device-authoritative matmul §6.1, landed `f15b6325` — 본 RFC 가 §6.2 잠금 해제)
- **Source convergence**: 12-fire d768·12L 캠페인 — fire #5→#12, 단조, 매 fire 다음 architecture 를 측정으로 justify. 격리 브랜치 `rfc043-flame-camp`.
- **Source evidence (g3 — 모든 claim 실측 trace)**:
  - `state/flame_phase4d7_gpu_fire_2026_05_17/PHASE4D7_FIRE12_ANALYSIS.md` §2 §3 — **fire #12 결정 측정**: RFC 057 §6.1 (matmul 출력 device-authoritative) 적용한 trainer 가 `wall=600` step 1 미완, resident 729 MiB. §6.1 단독은 wall 불변.
  - `…/PHASE4D7_FIRE11_ANALYSIS.md` §2 — fire #11 H100 교차검증: GPU 6× 빨라도 wall 불변 → bound 는 compute 아닌 host round-trip.
  - RFC 057 구현 agent honest verdict (`bf9dc222`): §6.2 차단 진단 — `flame_proj_batch_generic_primitive` 가 projection 출력을 `C[r·T+t]→Bc[t·d_out+r]` host-side transpose-scatter → Bc host-authoritative 유지.

## 1. Status / Priority / Severity

(see header). **DESIGN ONLY**. forge 에 새 `.cu` kernel 을 추가하므로 RFC-first (g7). transpose-scatter kernel 은 Phase 4-D-5-3 12-kernel byte-eq oracle 에 13번째 항목으로 편입 (BYTEEQ-PRESERVE 확장).

## 2. Source convergence — 12-fire 가 본 RFC 로 수렴

| fire | landed | 측정 | 다음 |
|---|---|---|---|
| #9 | Phase 4-D-8 | 구조적 round-trip bound | RFC 056 |
| #10 | RFC 056 P1 | resident 459→727, wall 불변 | Phase 4-D-9 |
| #11 | Phase 4-D-9 | H100 교차검증 host-bound 확정 | RFC 057 |
| #12 | RFC 057 §6.1 | §6.1 단독 wall 불변, resident 729 | **RFC 058 (본 RFC)** |

RFC 056→057 이 residency 를 단계적으로 늘렸으나 (API → pin → matmul-출력-device) wall 은 fire #9 이후 600s 고정. 측정이 말하는 것: residency 부분 증가로는 부족, host round-trip 이 *완전히* 끊겨야 step 완주. 그 마지막 끊김점 = transpose-scatter.

## 3. Problem — host-side transpose-scatter 가 Bc 를 host 에 묶음

`flame_phase4d6_matmul_primitives.c` 의 `flame_proj_batch_generic_primitive`:
```
cuBLAS Dgemm → C  (RFC 057 §6.1 으로 C 는 device-resident)
host loop: Y[Y_off + t·d_out + r] = C[r·T + t]   ← host-side transpose-scatter
```
matmul 출력 C 를 device 에 남겨도 (RFC 057 §6.1), caller 가 그것을 host 로 끌어내려 `C[r·T+t]→Bc[t·d_out+r]` transpose 를 host loop 으로 수행 → Bc(=Y) 는 매 projection 후 host-authoritative. 따라서 후속 RMSNorm/RoPE/attention slab 이 Bc slice 를 RFC 056 §6.2 `hexa_farr_dev_view` 로 못 잡음 (stale device snapshot alias) → 매 op host-rebuild → fire #12 의 wall 불변.

## 4. Scope (DESIGN ONLY)

RFC 058 specifies:
- forge `.cu` **transpose-scatter kernel** — device 에서 `dst[t·d_out+r] = src[r·T+t]` (또는 일반화된 (row,col) permutation) 수행
- runtime.c 의 host wrapper `hexa_farr_transpose_scatter_gpu(src_id, dst_id, rows, cols, dst_off)` (RFC 040 dispatcher 패턴)
- `flame_proj_batch_generic_primitive` 의 host transpose-scatter loop 을 이 kernel 호출로 교체 (d768 GPU-resident path 만; d=32 불변)
- Phase 4-D-5-3 byte-eq oracle 에 transpose-scatter 항목 추가 (12→13 kernel)
- 7 pre-registered falsifier

RFC 058 does NOT specify:
- 다른 `.cu` kernel math 변경 (verified oracle — 미변경)
- RFC 056/057 API 변경
- flame public API (`g_flame_api_fixed`)
- d=32 path 동작 변경 (절대 불변)
- attention causal-masked softmax kernel (RFC 057 §8.2 잔여 — 별도)

## 5. Proposal — forge transpose-scatter kernel

### 5.1 kernel (device)
순수 index permutation. `src` (rows×cols, row-major) → `dst` (cols×rows, row-major) 즉 transpose, optional `dst_off`:
```
__global__ void hexa_transpose_scatter_k(const double* src, double* dst,
                                         int rows, int cols, long dst_off) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= rows * cols) return;
    int r = idx / cols, c = idx % cols;        // src[r*cols + c]
    dst[dst_off + c * rows + r] = src[r * cols + c];
}
```
**부동소수점 연산 0** — 순수 `double` bit copy + reindex. 출력은 입력 bit 의 재배치일 뿐 → byte-eq 가 수학적으로 자명 (반올림·누적 오차 불가능).

### 5.2 host wrapper (runtime.c, RFC 040 패턴)
`hexa_farr_transpose_scatter_gpu(src_id, dst_id, rows, cols, dst_off)` — src farr 가 RFC 056 §6.1 으로 device-resident 이면 H2D-skip, dst farr 를 device 에 채우고 `loc=DEVICE, dirty_dev=1` (RFC 056 state machine). dst = Bc → Bc 가 device-authoritative 가 됨.

### 5.3 consumer 교체
`flame_proj_batch_generic_primitive` 의 host loop `Y[...] = C[r*T+t]` 를 `hexa_farr_transpose_scatter_gpu(C_id, Y_id, d_out, T, Y_off)` 호출로 (d768 GPU-resident path 만). 그러면 Bc fully device-authoritative → RFC 057 §6.2 (RMSNorm/RoPE/attention slab 이 Bc dev-view 소비) 잠금 해제.

### 5.4 d=32 절대 불변
교체는 `#ifdef HEXA_CUDA` + `d > FLAME_GPU_RESIDENT_THRESHOLD` dim-gate 안에서만. d=32 는 기존 host transpose loop 그대로.

## 6. Falsifier battery (7 pre-registered)

- **F-RFC058-D32-BYTEEQ** (hard gate #1): `flame_phase4b3_verify_all.sh` 모든 byte-eq section `max|Δ|=0.0`, revert+diff byte-identical.
- **F-RFC058-KERNEL-BYTEEQ** (hard gate #2): transpose-scatter kernel 출력이 host transpose loop 출력과 **bit-identical** (`max|Δ|=0.0`) — 순수 permutation 이라 자명하나 GPU 실측 확인. Phase 4-D-5-3 oracle 에 13번째 항목 편입.
- **F-RFC058-BYTEEQ-PRESERVE**: 기존 12-kernel oracle `max|Δ|=0.0` 불변.
- **F-RFC058-RESIDENT-MEM**: d768 fire GPU resident ≥ 3.0 GB sustained (Bc 가 device-authoritative 가 되어 상주).
- **F-RFC058-STEP-COMPLETES**: d768 step 1 완료 (post-update gn2 출력) — 캠페인 최초 가능성.
- **F-RFC058-WALL** (GOAL gate): d768 wall ≤ 437.9s. 정직: attention CPU softmax 잔존 시 첫 fire miss 가능 (§7.2).
- **F-RFC058-H2D-COUNT**: per-step `cudaMemcpy H2D` O(thousands)→O(few).

## 7. Honest caveats (g3 / f1 / f2)

### 7.1 byte-eq 가 자명한 kernel — 최저 위험 forge kernel
transpose-scatter 는 부동소수점 연산이 전혀 없는 순수 index permutation. 출력 = 입력 bit 의 재배치 → byte-eq 가 *수학적으로* 자명 (반올림·누적·순서 오차 발생 불가). RFC 057/056 의 substrate-discipline 변경보다 본질적으로 안전. F-RFC058-KERNEL-BYTEEQ 는 형식 확인.

### 7.2 RFC 058 단독으로 GOAL 보장 아님 — attention softmax 잔여
RFC 057 §8.2 + fire #12 분석 §5: attention causal-masked softmax 는 byte-eq-verified kernel 부재로 CPU 잔존. RFC 058 이 Bc 를 device-authoritative 로 만들어 projection/RMSNorm/RoPE round-trip 을 제거하지만, attention CPU softmax 가 잔존 bound 일 수 있음. RFC 058 fire 가 step 완주시키되 WALL miss 면 → attention softmax kernel (RFC 059 후보)이 다음. 양파 한 겹 더 가능성 정직히 명시 (over-claim 금지). 단 RFC 058 은 fire #9 이후 처음으로 **step 완주 가능성**을 여는 분기점.

### 7.3 측정-anchored, design-first 아님
fire #12 가 "§6.1 단독 wall 불변 + transpose-scatter 가 단일 잔존 blocker" 를 측정 확정. RFC 058 은 그 측정에 anchored (사용자 directive 준수).

### 7.4 no lattice numerology (f1/f2)
모든 threshold (≥3.0GB, ≤437.9s) 는 fire #5–#12 실측 + F-RFC046 PyTorch-eager anchor. lattice 상수 없음.

## 8. Non-goals
- 다른 `.cu` kernel math 변경 없음 · RFC 056/057 API 변경 없음 · flame public API 변경 없음 · d=32 path 변경 없음 · attention softmax kernel 없음 (RFC 059 후보) · multi-GPU 없음

## 9. Cross-RFC dependency
- RFC 040/041 — device-farr + 기존 kernel 들; transpose-scatter 가 13번째로 합류
- RFC 056 — residence API (state machine); transpose-scatter 출력이 §6.1 transition 따름
- RFC 057 — §6.1 (matmul 출력 device-resident) 이 prerequisite; RFC 058 이 §6.2 (Bc-slab dev-view) 잠금 해제
- RFC 059 (후보) — attention causal-masked softmax kernel (§7.2 잔여)

## 10. Cross-link
- 격리 SSOT: `~/core/hexa-lang-flame-wt` [rfc043-flame-camp]
- fire evidence: `state/flame_phase4d7_gpu_fire_2026_05_17/PHASE4D7_FIRE{11,12}_ANALYSIS.md`
- `stdlib/flame/PLAN.md` 진행 로그 (fire #5→#12 + RFC 056/057 + 본 RFC anchor)
- RFC 057 spec `docs/rfc/rfc_drafts_2026_05_12/rfc_057_*.md` §5 §6.2 §8.2
- substrate oracle: `state/forge_phase4d_5_3_2026_05_17/PHASE4D_5_3_ANALYSIS.md`

## Authority
- AGENTS.tape `g3` — 모든 claim fire #5–#12 실측 trace; fire #12 가 RFC 058 justify (design-first 아님)
- AGENTS.tape `g5` — forge `.cu` portable artifact (nvcc); no LLVM/transpile backend
- AGENTS.tape `g7` — RFC-first (forge 에 새 kernel 추가); `docs/rfc/rfc_drafts_2026_05_12/` 보관
- AGENTS.tape §0 `nn_stack` — forge=substrate, flame=consumer
- LATTICE_POLICY `f1`/`f2` — lattice numerology 없음
- `g_flame_api_fixed` — flame public API 불변
- `g_forge_verify_oracle` — F-RFC058-{KERNEL-BYTEEQ,BYTEEQ-PRESERVE} 가 oracle max|Δ|=0.0 강제, transpose-scatter 13번째 편입
