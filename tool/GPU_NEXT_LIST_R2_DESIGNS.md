# GPU 도메인 next-list round-2 디자인 + 런북 모음

15 milestone 종합 디자인/런북. 각 항목은 다음 dedicated cycle 시작점. 패턴은 round-1 (#1438 #1439) 의 design-note → impl 전환을 동일하게 따른다.

---

## D 군 — design → impl 4 items

### D1 — `@constant` 메모리 bank 실제 구현

B1 design (tool/B1_CONSTANT_MEM_DESIGN.md) 의 6-step 코드 구현.

| Step | 작업 | 추정 LOC |
|---|---|---|
| 1 | `_space_from_let_anns` → "constant" 인식 추가 (`@shared` 미러) | +3 |
| 2 | NVPTX_RKIND_CONST 추가 + `_nvptx_reg_const(id)` helper | +5 |
| 3 | `_nvptx_classify_locals` Pass 0.6 — `space=="constant"` PReg | +15 |
| 4 | `_emit_ptx_func` — `.const .align <a> .b8 _hexa_cn_<fn>[<N>];` directive | +10 |
| 5 | IndexGet (L867+) — `ld.const.<ty>` 분기 | +8 |
| 6 | IndexSet 시 HX0701 diag — `.const` 는 read-only | +5 |

**Fire**: `c[i] = lut[i % 64] * a[i]` 패턴, 64 entry f64 LUT, partial[0] expected match.

### D2 — `cp.async.shared.global` 실제 구현

B2 design 의 3-instr emit + sm_80 gate.

| Step | 작업 |
|---|---|
| 1 | `gpu_cp_async_shared_global(dst_shared, dst_idx, src_global, src_idx)` STMT_CALL 4-arg recognizer |
| 2 | `cp.async.ca.shared.global [%shared_addr], [%global_addr], 16;` emit (16 B copy) |
| 3 | `gpu_cp_async_commit()` → `cp.async.commit_group;` single-instr |
| 4 | `gpu_cp_async_wait(n)` → `cp.async.wait_group <n>;` |
| 5 | sm_80+ gate — sm_70 미만은 honest stub |

**Fire**: GEMM tile-overlap perf delta — 2 tile fetch + compute 동시 진행 vs 순차.

### D3 — HX0511 coalesced-access lint

C2 design 의 MIR-level idx 검사.

| Step | 작업 |
|---|---|
| 1 | MIR Local 에 `derived_from_tid: bool` 필드 추가 (또는 name_hint 인코딩) |
| 2 | `_lower_hexpr` 가 `gpu_thread_id_*()` 결과 Local 에 mark |
| 3 | `_nvptx_lower_stmt` IndexGet — idx 가 tid-derived AND multiplied by stride>1 → HX0511 emit |
| 4 | `@uncoalesced_ok` annotation 으로 silence |

**Test**: lint test fixture가 의도적 stride-4 패턴 → HX0511 trip.

### D4 — `gpu_grid_sync` 실제 구현

C3 design 의 bar.sync.aligned + cooperative launch.

| Step | 작업 |
|---|---|
| 1 | `gpu_grid_sync()` STMT_CALL → `bar.sync.aligned 0;` single emit |
| 2 | `@cooperative` annotation — kernel meta 가 cudaLaunchCooperativeKernel 분기 트리거 |
| 3 | Host runtime wrap — `cuLaunchCooperativeKernel` 호출 분기 |
| 4 | sm_70+ gate (cudaLaunchCooperativeKernel 가 sm_60 미만 fail) |

---

## E 군 — silicon fire 런북 4 items

각 fire 의 kernel/host 는 이미 land 됨 (#1438 + 기존 probe_*). 실행은 ubu-2 build pipeline 정상 시.

### E1 — A4 2D thread fire 런북

```
ssh ubu-2 'cd /tmp/r-clone && git clone --depth 1 -b nvptx-emit-current . && \
  hexa cc && hexa build self/module_loader.hexa -o build/hexa_module_loader && \
  HEXA_MODULE_LOADER=$PWD/build/hexa_module_loader hexa build compiler/cli/nvptx_emit.hexa -o /tmp/nvptx_emit && \
  /tmp/nvptx_emit tool/probe_2d_thread.hexa sm_80 && \
  ptxas tool/probe_2d_thread.hexa.ptx -arch=sm_80 -o /tmp/probe.cubin'
# Pre-build host harness from exp_f64_probe_host.c — swap N=16x16, blockDim=(16,16), kernel name.
```

### E2 — A5 f32 elem fire 런북

probe_shared_f32.hexa (#1438) + sweep_pred_host.c 변형 (N=256, expected=32896.0_f32).

### E3 — A3 f64 log fire 런북

`c[i] = log(a[i])` for `a[i] = (i+1)*0.5`. host: `expected[i] = log(a[i])` via libm `log`. tolerance `<1e-5` (polynomial 5-term truncation cap).

### E4 — B4 f32 rsqrt_rn fire 런북

probe_rsqrt_rn_f32.hexa (#1439) + sweep_pred_host.c 변형 (f32 input, expected byte-exact vs libm `1.0/sqrtf()`).

---

## F4 — f64 sin / cos polynomial

RFC 055 §13 trig family.

알고리즘:
```
x mod 2π → r ∈ [-π, π]
quadrant reduction: r → r' ∈ [-π/4, π/4] (4-way split: sin/cos/-sin/-cos)
sin(r') = r' * (1 - r'²/6 + r'⁴/120 - r'⁶/5040 + ...)
cos(r') = 1 - r'²/2 + r'⁴/24 - r'⁶/720 + ...
sign + swap from quadrant
```

PTX 추정 30-40 instr (range reduce 10 + polynomial 6 fma + sign 핸들 5 등). 각 PR ~250 lines.

| 작업 | 추정 PR |
|---|---|
| sin f64 polynomial | 1 PR (mirror of exp/log) |
| cos f64 polynomial | 1 PR (shared range-reduce path) |
| tan f64 — sin/cos division | 1 PR (combine + div) |

---

## G 군 — perf polish 3 items

### G1 — Loop fusion adjacent kernels

`@gpu_kernel fn a + fn b` 가 동일 grid에 dispatch + b 의 read-set ⊆ a 의 write-set 이면 단일 kernel로 fuse. launch overhead ~10µs × N → 1× 절감.

Impl: MIR pre-pass 가 kernel meta 분석 → SAFE_FUSE flag → codegen 가 단일 emit. (~3 PR)

### G2 — Register-pressure unroll analysis

Unroll factor N 결정 시 PTX-pre-emit register count 추정. Threshold 64 reg → refuse N>=4 unroll. 자동 fallback to factor 1. (~2 PR)

### G3 — Dead-code elimination in MIR

`STMT_ASSIGN dst.id = X` 가 이후 어디서도 read 되지 않으면 drop. PTX 사이즈 ~5-10% 감소. (~2 PR)

---

## H 군 — observability 3 items

### H1 — PTX → SASS preview

`tool/ptx_to_sass` shell — `ptxas + nvdisasm` 파이프, kernel 마다 SASS dump. Debug + perf 진단 도구. (1 PR + helper script)

### H2 — Occupancy calculator

`hexa gpu occupancy <kernel.ptx>` — register count + shared bytes + block size → SM 점유율 계산. (1 PR + doc)

### H3 — GPU runtime profiler hooks

`gpu_timer_start()` + `gpu_timer_stop()` STMT_CALL → CUDA event API. per-kernel µs reporting. (2 PR — codegen + runtime wrap)

---

## 다음 cycle 추천 순서

```
softmax/GEMM/rotation stack 활성화 →
  D1 @constant impl    (LUT-driven kernel)
  D2 cp.async impl     (GEMM 2× perf)
  F4 sin/cos polynomial (Fourier · RoPE attention)
```

이 셋 + 4 silicon fire (E1-E4) 검증 → softmax + GEMM-tile + RoPE attention 의 **end-to-end hexa-native 커널 합성** 가능.
