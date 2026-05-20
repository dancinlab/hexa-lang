# RFC 055 — final closure (P3c.e re-classified) — 2026-05-20

> **TRIAGED 2026-05-20**: closure note acknowledged · no action required (RFC 055 SPEC + correctness contract CLOSED via 11 PRs #82/#85/#87/#90-92/#94/#96-99; P3c.e UX polish deferred to downstream consumer demand)

## Reclassification: P3c.e is UX polish, not a missing primitive

The earlier closure note (`2026-05-20-rfc055-p3c-deploy-cycle.md`)
listed **P3c.e — cubin `.rodata` `LSection` auto-embed** as a remaining
deploy-cycle item coupled with P3c.d. With P3c.d landed (PR #99 —
`gpu_launch` host-side builtin recognized by the deployed transpiler
+ paired bootstrap regen), the picture changes:

**Every PRIMITIVE the RFC 055 §7 falsifier battery needs is now
present in source + (where applicable) deployed:**

- `@gpu_kernel` annotation + parse (055-P0/P1)
- GPU0N strict-lint validator (055-P1)
- per-Local PTX register-kind classification (055-P3b)
- Every stmt-kind generic lowering: ASSIGN / BINOP{arith,cmp} /
  RETURN / BR / BR_COND / CALL{gpu-intrinsics} / LOAD / STORE
  (055-P3b)
- MFunc.gpu_kind partition routing (055-P3c.a)
- `.visible .entry` kernel wrapping + param-bank materialisation
  (055-P3c.b/c)
- `gpu_launch(...)` host-side builtin → `_hx_cuda_launch_kernel`
  (055-P3c.d — landed deployed)
- Driver-API host launch wrapper `_hx_cuda_launch_kernel` runtime
  (055-P1 prior cycle — self/cuda/runtime_cuda.c)
- The 6-falsifier battery MEASURED PASS on real silicon (PR #82,
  RTX 5070, $0)

**What "P3c.e auto-embed" would add: convenience**, not a missing
correctness primitive. With everything above in place, a user can
arrange the cubin via:

1. **Manual ptxas + read_file pattern (available today):**
   - User runs `hexa build src.hexa --target=nvptx64-…` to emit
     `src.ptx`.
   - User runs `ptxas src.ptx -o src.cubin` externally.
   - User host code uses `read_file("src.cubin")` to load the
     bytes into a hexa value at runtime, then calls
     `gpu_launch(cubin_blob, cubin_len, "kernel_name", gx, gy,
     gz, bx, by, bz, args, …)`. Works today.

2. **The dispatch-script pattern** (the same pattern used to fire
   055-P1 vec-add and 055-P2 GEMM): `tool/dispatch_r055_p2_gemm.sh`
   automates ptxas + embeds the PTX via a host C harness +
   Driver-API call. Also works today.

What's STILL future work — a compiler-managed auto-embed where
`hexa build foo.hexa` sees `@gpu_kernel` and INTERNALLY does
PTX-emit + ptxas + LSection embed + injects the cubin symbol into
the gpu_launch call site. This is **convenience UX**, not a
correctness primitive: users don't need to arrange cubins by hand
when the compiler does it for them. The work to add it:
- self/main.hexa cmd_build pre-pass: detect `@gpu_kernel` source +
  produce per-kernel `.cubin` artifacts.
- gen2 Call-emit: when `gpu_launch(KERNEL_NAME, …)` references a
  compile-time-known kernel, rewrite the (cubin_blob, cubin_len)
  args to the auto-generated symbol.

Estimated scope: ~150 lines across self/main.hexa + 1 codegen_c2
section + bootstrap regen pair commit. Same deploy-cycle shape as
P3c.d (PR #99). Not in this session's scope — UX feature, not a
blocker for any falsifier or any RFC §7 contract.

## Summary — what's left for RFC 055

| line | status |
|---|---|
| every §7 falsifier landed + measured (where applicable) | ✅ |
| compiler/ frontend complete: HIR/MIR/codegen/emit for the §6.6 subset | ✅ |
| deployed transpiler recognizes gpu_launch | ✅ (PR #99) |
| Driver-API launch wrapper runtime | ✅ (055-P1) |
| User can arrange cubins (manual + dispatch-script) | ✅ |
| Compiler auto-embeds cubins for `hexa build foo.hexa` invocation | **UX polish — future** |

RFC 055 as a SPEC + correctness contract — **closed**. The auto-embed
UX is a downstream-driven enhancement that ships when a real
flame/forge or wilson consumer asks for it (a `@gpu_kernel` workflow
where the user doesn't want to think about cubin arrangement).

## Cross-references

- 11 PRs merged this session: #82, #85, #87, #90, #91, #92, #94, #96, #97, #98, #99.
- `compiler/PLAN.md` — full RFC 055 progress log.
- `inbox/notes/2026-05-20-rfc055-cycle-closure.md` — earlier P3a/P3b
  closure + canon promote findings.
- `inbox/notes/2026-05-20-rfc055-p3c-deploy-cycle.md` — P3c.d deploy
  plan (now executed via PR #99).

Status: **resolved-ssot** — RFC 055 closure complete; remaining work
is UX polish, not RFC scope.
