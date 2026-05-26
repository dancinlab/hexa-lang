# F-SHARED-512-NUMERIC — 🟢 PASS

Validates **RFC 085 Step B/C/D end-to-end** (`[T; N]` size threading from parser through to NVPTX `.shared` byte-allocation) on a non-256 array size. N=512 crosses the prior 2048 B hardcoded default, exposing the threading correctness gain.

## Verdict — 🟢 SUPPORTED-NUMERICAL (EXACT)

GPU output == `N × (N+1) / 2 = 512 × 513 / 2 = 131328.0` for ALL inputs. max_abs_err = 0, max_rel_err = 0. Integer-valued FP64, every partial sum representable, byte-exact reduction.

## Verbatim ubu-2 (RTX 5070 driver-JIT sm_120 forward-compat sm_80)

```
$ /tmp/nvptx_emit_r512 tool/sweep_pred_512.hexa sm_80
atlas: loaded 16088 nodes from embedded.gen.hexa
[nvptx] target=sm_80 src=tool/sweep_pred_512.hexa out=tool/sweep_pred_512.hexa.ptx phase=P3

$ grep .shared tool/sweep_pred_512.hexa.ptx
    .shared .align 8 .b8 _hexa_sh_sweep_pred_512[4096];   ← RFC 085 SUCCESS

$ ptxas tool/sweep_pred_512.hexa.ptx -arch=sm_80 -o /tmp/r512.cubin
PTXAS=0

$ /tmp/sweep_pred_512_host tool/sweep_pred_512.hexa.ptx
got=131328 expected=131328 max|delta|=0
PASS partial[0]=131328.000 (max|delta|=0, N=512, shared alloc=4096 B vs prior 2048 default)
RC=0
```

## 측정 dimensions

| 축 | 값 |
|---|---|
| N | 512 |
| blockDim | 512 |
| gridDim | 1 (single-block) |
| a[i] | i + 1.0 (1.0 .. 512.0) |
| **shared alloc emit** | **4096 B (= 512 × 8)** |
| Prior (pre-RFC-085) emit | 2048 B silent-undersize → kernel buffer overrun |
| Expected | 131328.0 (= 512 × 513 / 2) |
| Got | **131328.0 EXACT (max\|Δ\|=0)** |

## RFC 085 Step B/C/D end-to-end chain verified

```
parse_let_expr ──→ Expr.text "sm|Array:512"
                    │
ast_to_hir    ──→ _hir_let_name "sm" + _hir_let_type_text "Array:512"
                    │
bind.hexa     ──→ _bind_let_name "sm" (mirror)
                    │
hir_to_mir    ──→ Local.name_hint "sm:512"   ← Step C
                    │                            (_strip_mut_prefix updated
                    │                             to also strip "|<type>"
                    │                             — fix in this same PR)
                    │
nvptx Pass 0.5 ──→ byte size = 512 × 8 = 4096   ← Step D
                    │
                    ▼
       .shared .align 8 .b8 _hexa_sh_sweep_pred_512[4096];  ✅
       partial[0] = 131328.0 EXACT  ✅
```

## Regression fixes uncovered + closed in this PR

This fire surfaced 2 silent regressions in RFC 085 Step A/B/C (PR #1367 + #1396):

1. **`TokenKind::IntLit` typo** — variant doesn't exist, real name is `TokenKind::Number`. `hexa parse` (syntax-only) accepted it; bootstrap C transpile failed with `use of undeclared identifier 'TokenKind_IntLit'`. Fixed in this PR (parser.hexa).

2. **`_strip_mut_prefix` missed `|` suffix** — hir_to_mir.hexa's let-lowering uses `_strip_mut_prefix(e.text)` for the binding name (NOT `_hir_let_name`). Step B's `|<type>` suffix was leaking into `_bind`, breaking every let variable's scope lookup. Symptom: `div.rn.f64 %fd, 0, 2` (zero-literal operands from failed lookup) instead of `div.s64 %rd_stride, %rd_stride, 2`. Fixed in this PR (hir_to_mir.hexa).

3. **Pass 0.5 first-colon split** — robustness fix for any upstream lowering that prefixes the hint with `:`. Now uses LAST colon (the suffix is integer-only). Fixed in this PR (nvptx_target.hexa).

## Sweep impact

| Idiom | Status |
|---|---|
| ... 12 idioms from session 2 ... | ✅ |
| 13. **non-256 @shared array size (N=512)** | ✅ **THIS PR** (4096 B alloc + numeric exact) |

## Note on existing 256-case

The `sweep_pred.hexa` (N=256) kernel re-validated with the same binary — also emits correct PTX + ptxas RC=0 + partial[0]=32896.0 exact. The TokenKind / `_strip_mut_prefix` regressions affected BOTH cases (256 also broke after PR #1367+#1396 merged into main).

## Files in this PR

- `tool/sweep_pred_512.hexa` (kernel source)
- `tool/sweep_pred_512_host.c` (driver-API host harness)
- `compiler/parse/parser.hexa` (IntLit → Number fix)
- `compiler/lower/hir_to_mir.hexa` (_strip_mut_prefix `|` strip)
- `compiler/codegen/nvptx_target.hexa` (Pass 0.5 last-colon)
- `tool/SWEEP_PRED_512_FIRE_PASS.md` (this writeup)
