# native try/catch setjmp rollback — fix VERIFIED (m12 PASS)

## Bug (measured, ghost darwin-arm64 v0.605.1, pre-fix)
`try { a = v; throw } catch {}; return a` → **0** (must be v). m12 t2=0, t4=1101, t5=0
(torn tag/payload). Carrier = the **gen2 C-transpile + clang -O2** path (darwin runs
`hexa build/run` through it; #4483 gates native --emit=obj to Linux x86_64; the own-IR
arm64 backend already all-spills via Path A′). Non-volatile C automatics modified between
setjmp/longjmp are indeterminate (C11 7.13.2.1p3); clang -O2 rolls them back.

## Fix (self/codegen.hexa) + own-IR gates
1. `returns_twice` on the darwin hxlcl_setjmp decl (x86 parity).
2. Locals of a try-containing fn emit `volatile HexaVal` (_gen2_current_fn_has_try flag +
   _gen2_body_has_try scanner + _gen2_local_decl_kw at LetStmt/hoist/boxed-cell sites).
3. own-IR x86 pool-pop gate + arm64 steal gate kept (real for the native x86 lane; no-op on
   arm64 own-IR which already spills).

## Verification (ghost, fix build)
Emitted C confirmed: `int hxlcl_setjmp(...) __attribute__((returns_twice))` + `volatile HexaVal a`.
`hexa build m12 -o bin` (bypassing the stale hexa-run cache) + run → **m12 try/catch setjmp: PASS (RC=0)**
— t1-t5 all correct (t2=7, t4=1111, t5=5). GOTCHA: `hexa run m12` returned the STALE ~/.hexa-cache
binary (M7 cache-collision class) → shows the pre-fix result; always `rm -rf ~/.hexa-cache` or build a
binary to verify a codegen fix.

## Merge gate
byteeq 3-target (self-host gen3≡gen4 reconverges; ~108 try sites in compiler/ now emit volatile,
deterministic → fixpoint holds) + shipping smoke. Follow-on: Fix B (try-stack leak on
return/break/continue in try), native-x86 CI m12 gate for both lanes.
