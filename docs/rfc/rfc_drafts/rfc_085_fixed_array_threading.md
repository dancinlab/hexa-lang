# RFC 085 — `[T; N]` fixed-array size threading through AST → HIR → MIR → NVPTX codegen

| 축 | 값 |
|---|---|
| 상태 | DRAFT (next-cycle implementation) |
| 깊이 | Multi-file schema-change |
| 대상 | `@shared let sm: [f64; N]` 임의 N (현재 N=256만 silent-OK) |
| Falsifier | F-FIXED-ARRAY-SIZE-NONDEFAULT (256≠N kernel ptxas-RC=0 + 정확한 element_count*8 직접 매치) |

## 동기

현재 `_nvptx_classify_locals` Pass 0.5는 모든 `space=="shared"` Local에 `_nvptx_shared_default_bytes = 2048 B`를 박아넣는다. `[f64; 256]` (= 2048 B) kernel은 정확히 맞아 떨어져 F-GPU-SWEEP-SHARED-REDUCE-NUMERIC (PR #1323)이 PASS. 그러나 `[f64; 512]` / `[f64; 128]` 등은 silent-undersize (or oversize)로 가게 됨.

## 5-surface threading plan

```
parse_type "[T; N]"          (parser.hexa)
       ▼
TypeRef.count: i64           (ast.hexa)
       ▼
_lower_item handles count    (ast_to_hir.hexa)
       ▼
HIR Item carries count       (hir.hexa)
       ▼
hir_to_mir creates Local
  with element_count          (hir_to_mir.hexa + mir.hexa)
       ▼
classify_locals Pass 0.5      (nvptx_target.hexa)
  uses Local.element_count
  * elem_size_for_kind
  instead of _nvptx_shared_default_bytes
```

## Surface별 작업량

| 파일 | 추정 변경 |
|---|---|
| `compiler/parse/ast.hexa` | `TypeRef`에 `count: i64` 필드 (default `-1` = unbounded) |
| `compiler/parse/parser.hexa` | `parse_type`에서 `[T; N]` 파싱 — `eat(Semicolon)` 후 IntLit 읽기 |
| `compiler/ir/hir.hexa` | HIR Local/Item에 element_count 또는 HIR TypeRef 동등 |
| `compiler/lower/ast_to_hir.hexa` | TypeRef.count → HIR carry |
| `compiler/ir/mir.hexa` | `Local`에 `element_count: i64` (default 0) |
| `compiler/lower/hir_to_mir.hexa` | element_count 전파 |
| `compiler/codegen/nvptx_target.hexa` | Pass 0.5에서 `_nvptx_shared_default_bytes` 대신 `lloc.element_count * elem_size` (fallback 2048) |

추정 literal ripple: ~36 TypeRef + ~49 Local = 85+ literal 업데이트. 각 default값 추가 필요.

## 권장 implementation 순서

1. **Step A** — `TypeRef.count` 필드 + 36 literals 업데이트 + parse_type `;N` 캡처. PR scope: parser+ast 단독. classify는 아직 안 읽음 (no behavior change).
2. **Step B** — `Local.element_count` 필드 + 49 literals 업데이트 + hir_to_mir 채움. PR scope: HIR/MIR threading only.
3. **Step C** — classify_locals Pass 0.5 element_count 사용. PR scope: codegen 단독. **이 PR이 첫 behavior-change.**
4. **Step D** — silicon fire `[f64; 512]` kernel + ubu-2 driver-JIT + ptxas-RC=0 + numeric-eq.

Step A/B는 byte-eq (CPU path 무영향, GPU emit 무영향) 유지 가능 — 스키마 추가만. Step C가 첫 emit 변경, Step D가 falsifier closure.

## 잠재 hazard

- 일부 TypeRef literal이 `Array:<N>` 또는 다른 prefix를 name string에 이미 인코딩 가능 — 검토 필요
- HIR/MIR layer가 type-erase하면 element_count도 손실 — 명시적 carrier 필요
- Generic `Array<T>` (parameterized)와 `[T; N]` (sized) 의 통합 vs 분리 결정

## 관련 PR

- PR #1313 piece 2+3 (annotation threading) — 같은 5-surface 패턴
- PR #1318 piece 4+5 + #1322 piece 6 (@shared codegen) — Pass 0.5 + 6 scratch reg 설계
- 메모리 `project_gpu_codegen_baseline_2026_05_26` 의 "잔여 후속" 섹션
