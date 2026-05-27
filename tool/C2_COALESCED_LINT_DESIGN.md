# C2 milestone — Coalesced-access diagnostic lint 디자인

## 목표

NVPTX에서 warp 32 thread 가 인접한 global memory 주소를 access 하면 한 transaction (128 byte segment) 으로 묶임. 비-coalesced 패턴은 32 × 별도 transaction → 32× 느림. lint 가 사전 경고.

## 감지 패턴

| 패턴 | 평가 |
|---|---|
| `arr[gpu_thread_id_x()]` | ✅ coalesced (stride 1) |
| `arr[gpu_thread_id_x() * 4]` | ⚠ stride 4 — 4× under-coalesced |
| `arr[gpu_thread_id_x() * N]` (N>1) | ⚠ non-coalesced |
| `arr[some_local]` (local from non-thread-id binop) | ⚠ unknown — needs flow analysis |
| `arr[i]` inside `for i in 0..n` (sequential per thread) | ❌ severe — each thread linearly reads N elements (column-major fail) |

## codegen-level 검출 (MIR 단계)

- IndexGet의 idx operand 가 `gpu_thread_id_x()` 결과 Local 인지 확인
- 만약 `mul.lo.s64` 로 N 곱하기가 됐다면 stride>1 — lint 발화
- `STMT_BINOP` 추적해 `gpu_thread_id_x() + base` 패턴은 stride 1로 인정

## 사용자 메시지 예시

```
warning: HX0511 — possibly non-coalesced global memory access
  --> kernel.hexa:42:13
   |
42 |     let v = arr[tid * 4]
   |             ^^^^^^^^^^^^
   |
   = note: stride-4 access; 4× under-coalesced on NVPTX
   = help: use linear `arr[tid]` if possible, or pad source to stride 1
   = see: tool/SHARED_BANK_PADDING.md
```

## 구현 단계

| Step | 작업 |
|---|---|
| 1 | MIR Local 의 "thread-id derived?" tracking (`derived_from_tid: bool` 추가) |
| 2 | `_nvptx_lower_stmt` IndexGet 분석 — idx operand 가 derived_from_tid 면 stride 검사 |
| 3 | stride > 1 → diagnostic emit (HX0511) |
| 4 | 사용자 `@uncoalesced_ok` annotation 으로 silencing |

## 다음 cycle

3-step impl + diag test fixture. 옵셔널 — perf 최적화 cycle 의 일부.
