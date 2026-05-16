# forge/PLAN.md — staged roadmap (substrate layer)

> Pairs with `stdlib/flame/PLAN.md`. forge phases provide the substrate
> that flame phases consume. Same governance discipline: editable head +
> append-only `## 진행 로그`. **Nothing runs without explicit user go.**

## 0. 현재 상태 (2026-05-16)

forge = NAMING + SCAFFOLD. Code largely **already landed** across the
RFC 040 campaign — see `FORGE.tape` §X + flame's `FLAME.tape` §X for
exact branch · SHA · path · RFC# coordinates. This roadmap just stages
**what remains** under the forge label.

## 1. 단계 (staged — substrate parity → exceed)

### Phase 0 — 보존 + 통합 (paired with flame Phase 0) ⚠️ 선결, $0

Same preservation step as flame's Phase 0. forge artifacts are a
**subset of flame's** §X index (RFC 040 device-farr + cuBLAS + RFC 041
`.cu` kernel stubs). Per flame `## Log` 2026-05-16 the existing
`rfc043-hexa-torch` branch (`a8bc5e08`) is a strict linear ancestor of
all 5 campaign branches' tips + §X SHAs → **Phase 0 acceptance MET**.
forge inherits that clearance.

- Residual: `main` divergence (other-session interp-retirement R1/R2/R3
  + F6-A in-flight) — handled when those land; not a forge blocker.

### Phase 1 — RFC 040 land: device-farr + cuBLAS Dgemm

- Status: **substrate built + 4× verified**, awaiting clean land.
- Components: `HexaFarrEntry` device-farr ext (`5ae8823f`) · Phase B
  `_gpu` ops scaffold (`c0122caa`) · `runtime_cuda.c` cuBLAS impl
  (`180263d3`) · real-wire (`903c0285`) · interp-parity fix
  (`54d56e4a`).
- Acceptance = `tmp_rfc040_smoke.hexa` 5 / 5 + Phase B 6 / 6 + cuBLAS
  oracle (max\|Δ\|=4.44e-15, ≤ TOL_MATMUL 2e-9).
- Falsifier F-FORGE-CUBLAS-EQ (pre-registered):
  `farr_matmul_gpu` ≡ CPU farr_matmul at TOL_MATMUL on a fresh
  H100 / A100 fire, post-merge to main. **Hexa source unchanged** —
  CPU-bit-equal preserved by construction (no path divergence
  acceptable; `g3` honest).

### Phase 2 — RFC 041 land: real `.cu` kernels (non-matmul)

- Status: **TODO[cuda] -1 stubs everywhere except `farr_matmul_gpu`**
  — current backward path routes through the one real cuBLAS kernel
  via GEMM reshapes (Phase E2 finding `x_anima_phaseE2`). Functional
  but not optimal.
- Scope: real `.cu` for `farr_softmax_rows`, `farr_rmsnorm_rows`,
  `farr_add`, `farr_scale`, `farr_mul`, `farr_silu`, `farr_silu_grad`,
  `farr_rmsnorm_bwd`, `farr_adamw`, `farr_outer`, `farr_matmul_t`
  (= the 11-op set on `rfc040-phaseB2-complete` `017b988f`).
- Falsifier F-FORGE-KERNEL-EQ (pre-registered): each real `.cu` ≡ CPU
  reference at TOL_OP (per-op tolerance documented in RFC 041) and ≡
  prior cuBLAS-reshape path at boundary tests on a real GPU.
- This unlocks flame Phase 4 (compile-time fusion has real kernels to
  fuse against, not stubs).

### Phase 3 — fused epilogue (memory-traffic minimisation)

- Combine norm + activation + residual into the GEMM epilogue at the
  forge layer — flame Phase 4 dispatches into these. Bottleneck =
  memory bandwidth, not FLOPs (perf thesis mechanism).
- Falsifier F-FORGE-FUSED-EQ: fused kernel ≡ unfused pipeline at
  TOL_OP, with measured bandwidth ↑ vs unfused (no fabricated
  multiple; `f1` / `f2`).

### Phase 4 — (optional, later) multi-GPU primitives

- AllReduce / AllGather / Broadcast on top of NCCL — only if scale
  demands. Out of scope until single-GPU `d=768·12L` flame fire lands
  and a multi-GPU need is concrete. Listed for completeness.

## 2. 의존 (gating)

- Phase 1 ← RFC 040 design (filed) + verified oracle (`x_oracle_cublas`).
- Phase 2 ← Phase 1 + RFC 041 design (filed) + per-op TOL spec.
- Phase 3 ← Phase 2 (need real kernels before fusing them).
- Phase 4 ← demand-driven only.

flame phase ↔ forge phase mapping (paired):

| flame phase | needs forge at |
|---|---|
| Phase 1 (Tensor + autograd) | forge Phase 1 ✓ |
| Phase 2 (nn layers) | forge Phase 1 ✓ (uses cuBLAS for matmul; `.cu` stubs OK for now) |
| Phase 3 (PyTorch-parity train_step) | forge Phase 1 ✓ — feasible, slower-than-cuda on `.cu`-stubbed ops |
| Phase 4 (match eager-PyTorch) | forge Phase 2 + 3 (real `.cu` + fused epilogue) |
| Phase 5 (exceed eager-PyTorch) | forge Phase 2 + 3 fully + flame's whole-program fusion |

## 3. 진행 트리거

forge Phase 진입 = 이 PLAN `## 진행 로그` append + `FORGE.tape` 동기화
+ falsifier 사전등록 + 사용자 go. 우회 금지 (flame Phase Gating 미러).
신규 `.cu` 추가 시 oracle (CPU farr reference) 와의 byte/TOL parity
mandatory (`g_blue_closed_mandate`).

## 진행 로그

(append-only)

### 2026-05-16 — forge/ 스캐폴드 LANDED (NAMING, 코드 추가 0)
`self/forge/{README.md, PLAN.md, FORGE.tape}` 작성. 사용자 directive
2026-05-16 "forge 로 가자 세팅해줘". 기존 substrate 코드(`self/runtime.c`
GPU 부분 + `self/cuda/runtime_cuda.c`) 는 그대로 — 이 디렉토리는
**라벨 SSOT** 일 뿐 코드 이동 없음 (g3 drift-avoidance). flame ↔ forge
크로스레프는 flame 동시작업 안정화 후 후속 커밋 (이번 커밋은 forge-only,
flame WIP 무영향).
