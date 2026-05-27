# B1 milestone — `@constant` 메모리 bank 디자인 노트

## 목표

Kernel LUT (softmax / relu / activation table) 을 PTX `.const` bank에 emit. `.shared` (per-block) 와 `.global` (per-grid) 외에 read-only kernel-invariant LUT용.

## 패턴 (Lattice: `@shared` MIR `Local.space="shared"` 와 동일)

```hexa
@gpu_kernel
fn f(...) {
    @constant let lut: [f64; 64] = [...]   // read-only LUT
    let v = lut[idx]                       // ld.const.f64
}
```

```
.const .align 8 .b8 _hexa_cn_<fn>[<N*8>];     // emit
mov.u64 %cn<id>, _hexa_cn_<fn>;               // base init
ld.const.f64 %fd_v, [%cn<id> + idx*8];        // read
```

## 구현 경로 (mirror of @shared landing PR #1313-#1322)

| Step | 작업 |
|---|---|
| 1 | `parse_let_expr` 가 `@constant` annotation 캡처 (이미 `@shared`로 한 패턴) |
| 2 | `_space_from_let_anns` 가 "constant" 인식 |
| 3 | `Local.space = "constant"` 분류 |
| 4 | `_nvptx_classify_locals` Pass 0.5 — `space=="constant"` PReg bank `NVPTX_RKIND_CONST` |
| 5 | `_emit_ptx_func` — `.const` directive emit (mirror WMMA staging) |
| 6 | IndexGet (L867+) — `ld.const.<ty>` mnemonic |

## 차이점 (@shared 와 비교)

- `.shared` per-block 가변. `.const` per-grid 고정.
- IndexSet 금지 (read-only). codegen에서 `is_const_set` 시 에러 emit.
- 초기값 필수 — `@constant let lut: [f64; N] = [c0, c1, ...]`.
- WMMA staging 과는 다른 align — `.align 4` (f32) / `.align 8` (f64).

## 다음 사이클

이 doc + 4 file edit (parse/lower/codegen) = 단일 PR. PR-C 정확 미러. silicon fire = `c[i] = lut[i % 64] * a[i]` 패턴.
