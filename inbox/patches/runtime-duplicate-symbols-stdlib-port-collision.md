# Mac arm64 — runtime helper duplicate symbols block all `hexa build`/`hexa run` after stdlib/runtime cycles 22-30

**Severity**: critical (blocks rfc_006 §5 yosys gate measurement +
  any mac arm64 `hexa run` or `hexa build` on the current
  `origin/main` `9f2da3f6`. Independent of cycle 66 / PR #251 exec
  fix — exec restore lands but the runtime can't link)

**Layer**: hexa-native runtime / `self/runtime.c` vs stdlib/runtime
  ported helpers (RUNTIME.md step 3 cycles 22-30 — `array_for_each`,
  `as_num`, `map_from_array`, etc.)

**Reporter**: rfc_006 §5 measurement audit 2026-05-21 KST
  (`~/core/demiurge/YOSYS.md` Tier-1 mac-binary release task).
  Discovered while attempting a fresh `tool/build_hexa_cli.sh` to
  pick up cycle 66's exec/popen/env restore — fresh
  `build/hexa_cli_driver` (677 KB Mach-O arm64, 2026-05-21 03:58)
  builds + parses cleanly, but fails to JIT-link any user .hexa
  with duplicate symbols against the linked-in runtime.

**Status**: resolved-ssot (2026-05-21) — actual root cause was a stale `build/self/` shadow tree, NOT the proposed "strip C versions from `runtime.c`". The driver at `build/hexa_cli_driver` resolves the transpiler via `resolve_hexa_v2() → install_dir_from_argv0()/self/native/hexa_v2`, which for in-repo use lands at `build/self/native/hexa_v2` — and that copy was a 2026-04-25 binary emitting the legacy `#include "runtime.c"` directive (newer codegen at `codegen_c2.hexa:931` defaults to `runtime.h`). Old binary + dual TU compile (`#include "runtime.c"` inside the user TU AND `runtime.c` appended as a separate clang TU) = every `_hexa_*` symbol declared twice. Additionally `build/self/runtime.h` was absent, masking the issue: even after picking up the newer hexa_v2 manually, clang failed at `runtime.h: file not found`. Fix landed in `tool/build_hexa_cli.sh` (step 4b — shadow install-layout: sync `native/hexa_v2`, `runtime.{h,c,_core.c,_hi_gen.c}`, `native/*.{c,h}`, `forge/forge_tier_v1.{c,h}` from canonical `self/` into `build/self/`). Verified: `unset HEXA_LANG; hexa build /tmp/dup_smoke.hexa -o /tmp/x.bin && /tmp/x.bin` → `hi`. Proposed runtime.c strip (option 1) was the WRONG fix — the `#ifndef HEXA_HAS_HEXA_RT_STDLIB` two-mode guards are intentional fallbacks (aprime_cc smoke standalone-consumer path).

## Symptom

Fresh build of hexa_cli_driver per `tool/build_hexa_cli.sh`:
```bash
$ cd ~/core/hexa-lang
$ NO_SMOKE=1 bash tool/build_hexa_cli.sh
… [4/5] codesign (Darwin)
$ ls -la build/hexa_cli_driver
-rwxr-xr-x@ 1 ghost  staff  677408 May 21 03:58 build/hexa_cli_driver
$ build/hexa_cli_driver --version
hexa 0.1.0-dispatch
$ printf 'fn main() { println("hi") }\n' > /tmp/x.hexa
$ build/hexa_cli_driver parse /tmp/x.hexa
OK: /tmp/x.hexa parses cleanly
$ build/hexa_cli_driver run /tmp/x.hexa
duplicate symbol '_hexa_eprintln' in:
    /private/var/folders/.../T/hexa_run-d96fb2.o     (the user-program TU)
    /private/var/folders/.../T/runtime-907f0e.o      (self/runtime.c)
duplicate symbol '_hexa_math_tanh' in: …
duplicate symbol '_hexa_array_for_each' in: …
duplicate symbol '_hexa_as_num' in: …
duplicate symbol '_hexa_map_from_array' in: …
[clang ld error → JIT compile fail]
```

Same with `HEXA_MAC_BUILD_OK=1 hexa build /tmp/x.hexa -o /tmp/x.bin`.

## Root cause (suspected)

RUNTIME.md step 3 cycles 22-30 ported a series of runtime helpers
from C-shaped (in `self/runtime.c`) to hexa-source (in
`stdlib/runtime/*.hexa`). The intent: hexa-source canonical, C
de-duplicated.

Bisect by inspection (recent commits to `stdlib/runtime/`):
```
ef4b04bb cycle 30 — array_rotate float port
889b8aac cycle 29 — array_unique float port
baaf97bd cycle 28 — str_bytes port
6cd17eab cycle 27 — str_count_substr port
8ea4b75e cycle 66 — restore exec/popen/env stubs (this is the GOOD one)
… and more cycle-22..29 commits between 0cbb336f and ef4b04bb
```

But the C side of these helpers in `self/runtime.c` was NOT
removed. So the user-program TU (transpiled by `hexa_v2` from
`stdlib/runtime/*.hexa` ports it imports) emits `_hexa_array_for_
each`, `_hexa_as_num`, etc. as TU-local functions, AND linking in
`self/runtime.c` brings the C versions in too. clang sees both,
errors out.

## Impact map

- **rfc_006 §5 yosys area measurement**: cannot run
  `hexa run stdlib/yosys/gate_record.hexa` to validate the
  abc_map honesty fixes (PR #255), the cycle-66 exec restore,
  the cross-iter comb-loop investigation (`yosys-rr-ptr-cross-
  iteration-comb-loop.md`), or the fifo_mem 2-D LHS investigation
  (`yosys-fifo-mem-2d-array-memwr-emit.md`). All §5 work is gated.
- **anima trainer**: same blocker for `hexa run train_s185_psicouple.
  hexa` and any future `.hexa` trainer
- **pool CLI**: same blocker for `hexa run pool.hexa`
- **any hexa-native user program**: cannot build/run on mac arm64
  with the current main

## Suggested fixes (ranked surgical → ambitious)

1. **Strip the ported helpers from `self/runtime.c`** — match the
   cycles 22-30 list (`_hexa_array_for_each`, `_hexa_as_num`,
   `_hexa_map_from_array`, `_hexa_eprintln`, `_hexa_math_tanh`,
   etc.) one-to-one against the ported stdlib/runtime/*.hexa
   functions, delete from runtime.c. This is the "the C version
   was supposed to be removed at port time but wasn't" hypothesis.
2. **Mark stdlib/runtime ports as `extern "C"` so they're declarations,
   not definitions** when imported into user TUs, deferring the
   actual emit to `runtime.c`. This is the "the port emitted the
   wrong thing — should have stayed in runtime.c" hypothesis.
3. **Link-time `-Wl,-X` / `--allow-multiple-definition`** as a band-
   aid. Anti-pattern (silently picks one definition), but unblocks
   measurement while options 1 or 2 land properly.

Likely option 1 is correct — the RUNTIME.md cycle 22-30 entries
describe the ports as "C → hexa migration", which means the C
should retire as the hexa version lands. Verify by:
```bash
grep -l "_hexa_array_for_each" self/*.c
# expected: empty (after fix). Currently: self/runtime.c
```

## Verification (after patch)

```bash
$ tool/build_hexa_cli.sh
[5/5] smoke
  OK   --version
  OK   parse
  OK   build-run
$ printf 'fn main() { println(exec("echo hi").to_string().trim()) }\n' > /tmp/exec_smoke.hexa
$ HEXA_EXEC_NO_SHELL=1 hexa run /tmp/exec_smoke.hexa
hi
$ rm -f /tmp/_hexa_yosys_gate_*_out.blif
$ HEXA_EXEC_NO_SHELL=1 hexa run stdlib/yosys/gate_record.hexa | tail -5
[gate] router_d4 area=<float> µm² oracle=61763 µm² Δ=<float>% <PASS|FAIL> (±5%)
[gate] router_d6 area=<float> µm² oracle=93608.5 µm² Δ=<float>% <PASS|FAIL> (±5%)
```

## Cross-link

- `~/core/demiurge/YOSYS.md` Tier-1 mac-binary release task
- `inbox/patches/yosys-exec-runtime-regression-cycles-61-64.md`
  + sibling pool patch — same RUNTIME.md cycle era, related
- `inbox/patches/yosys-rr-ptr-cross-iteration-comb-loop.md` +
  `yosys-fifo-mem-2d-array-memwr-emit.md` — gated by this
- PR #251 (cycle 66 exec restore — partial fix, this is the next
  layer)

## Honest C3 / scope

1. Mac arm64 only. Linux may or may not hit the same — verify on
   a Linux box if available. (My local environment is mac arm64.)
2. The bisect is by inspection, not by reverting cycles. A proper
   bisect (revert each cycle 22-30 one at a time and rebuild)
   would isolate the exact regression commit.
3. The same fresh `build/hexa_cli_driver` correctly does `--version`
   and `parse`, so the build itself is sound — only the JIT/build
   pipeline that links runtime.c with a transpiled user TU is
   broken. That narrows the fix scope to the duplicate-emit-site
   question (option 1 vs 2).
