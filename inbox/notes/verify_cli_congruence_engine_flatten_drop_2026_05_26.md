# verify_cli build blocked — congruence_chain_engine.hexa int-fn block dropped by flattener (2026-05-26)

## Symptom
`bash tool/build_hexa_verify.sh` (HEAD transpiler `self/native/hexa_v2` 2026-05-26
04:39 + freshly-built `build/hexa_module_loader`, `HEXA_MODULE_LOADER` wired) fails
at the clang stage with 12 errors, all undeclared-identifier on the SAME six fns:

```
build/artifacts/hexa-verify.c: use of undeclared identifier
  'is_prime_int' / 'nth_prime' / 'factorial_int' / 'catalan' / 'bell' / 'partition'
```

They are emitted as INDIRECT function-pointer calls:

```c
return __hexa_fn_arena_return(hexa_call1(is_prime_int, n));
```

with **no forward declaration and no function body** anywhere in the emitted C.

## Root cause (diagnosis)
All six are `pub fn`s defined in `compiler/atlas/symbolic/congruence_chain_engine.hexa`
(lines ~160-245), pure-integer (while-loops · `%` · `push`, no float). The module
flattener pulls in the module's FLOAT fns (e.g. `sigma_k` — emitted as a DIRECT
call `sigma_k(n, hexa_int(1))` with a body) but DROPS the integer-fn block — the
six fns above become undeclared `hexa_call1(...)` references.

So this is a flatten / reachability gap (or an int-fn codegen path that emits
indirect-without-decl) in the HEAD transpiler — NOT specific to any one caller.

## Why it is NOT a V9 (or any one feature's) regression
- VERIFY-KIT V9 added 5 float physics fns; they flatten + compile FINE (emitted
  as direct calls with bodies). The build fails *only* on the V7 int block.
- Pristine `origin/main` `tool/verify_cli.hexa` calls the same `is_prime_int(n)`
  in `_recompute`, so it would hit the identical failure.
- The deployed `bin/hexa-verify` (main repo, built 04:36) reports `is_prime`/
  `factorial`/`catalan`/`bell`/`partition` as 🟠 INSUFFICIENT — i.e. VERIFY-KIT
  V7's number-theory fns are not in any built binary either. V7 landed
  source-only (its log notes it did NOT run `hexa cc --regen`).

Net: the verify_cli binary cannot currently be rebuilt from source on Mac
(local toolchain) because of this upstream flatten/codegen bug. Both V7
(number-theory) and V9 (physics) source landings are stuck behind it.

## Repro
```
cd <worktree>
cp <main-repo>/self/native/hexa_v2 self/native/hexa_v2     # HEAD-fresh transpiler
HEXA_MAC_BUILD_OK=1 bash tool/build_hexa_module_loader.sh   # OK, self-test PASS
HEXA_MODULE_LOADER="$PWD/build/hexa_module_loader" HEXA_MAC_BUILD_OK=1 \
  HEXA_MEM_CAP_MB=16384 bash tool/build_hexa_verify.sh       # clang: 12 undeclared-id errors
```

## Fix candidates (for a transpiler-owning cycle)
1. Flattener: ensure ALL `pub fn`s of a `use`d module reach the emitted C
   regardless of int-vs-float return type (the int block of
   `congruence_chain_engine.hexa` is silently elided).
2. OR: codegen for these calls should emit a DIRECT call (matching `sigma_k`),
   which also emits the forward decl + body — not an undeclared `hexa_call1`.
3. Verify with `nth_prime`/`is_prime_int` round-trip (`hexa verify --expr is_prime 7 1`
   should report 🔵 once the build lands).

## Impact
- VERIFY-KIT V7 number-theory fns (OEIS A000040/108/142/110/41) — unreachable
  via the verify binary.
- VERIFY-KIT V9 physics fns — landed + parse-clean + numerically verified
  (independent IEEE-754 double eval; see `.verdicts/verify-kit-physics/v9.txt`),
  but not yet exercisable through `hexa verify --expr` for the same reason.
